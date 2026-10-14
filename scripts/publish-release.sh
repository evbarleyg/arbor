#!/bin/bash
# Puts what `make release` left in build/ on GitHub as a release, a draft unless told otherwise. The release
# workflow runs it; it needs only curl and python3, and talks to GitHub's REST API.
#
#   scripts/publish-release.sh             create the release and upload the files
#   scripts/publish-release.sh --dry-run   say what would be sent, and send nothing
#
#   GITHUB_TOKEN        a token that may write the repository's contents
#   GITHUB_REPOSITORY   owner/name (default evbarleyg/arbor)
#   GITHUB_SHA          the commit the tag v<version> is put on when the draft is published (default HEAD)
#   GITHUB_API_URL      default https://api.github.com
#   ARBOR_DRAFT         false publishes at once (default true)
#
# A version with a suffix (0.9.0-rc.1) becomes a pre-release, which update checks do not offer. A draft left by
# an earlier run for the same version is replaced; a published release is never touched.
set -euo pipefail
cd "$(dirname "$0")/.."

dry_run=no
case "${1:-}" in
  "") ;;
  --dry-run) dry_run=yes ;;
  *) echo "usage: scripts/publish-release.sh [--dry-run]" >&2; exit 64 ;;
esac

version=$(./scripts/version.sh version)
tag=v$version
repository=${GITHUB_REPOSITORY:-evbarleyg/arbor}
api=${GITHUB_API_URL:-https://api.github.com}/repos/$repository
commit=${GITHUB_SHA:-$(git rev-parse HEAD)}
draft=${ARBOR_DRAFT:-true}
case "$draft" in true | false) ;; *) echo "publish-release.sh: ARBOR_DRAFT must be true or false" >&2; exit 64 ;; esac
case "$version" in *-*) prerelease=true ;; *) prerelease=false ;; esac

notes=build/Arbor-$version-notes.md
files=("build/Arbor-$version.dmg" "build/Arbor-$version.zip" "build/Arbor-$version-checksums.txt" build/arbor.rb)
for file in "$notes" "${files[@]}"; do
  [ -f "$file" ] || { echo "publish-release.sh: there is no $file; run \`make release\` first" >&2; exit 1; }
done

work=$(mktemp -d) || { echo "publish-release.sh: no temporary folder" >&2; exit 1; }
trap 'rm -rf "${work:?}"' EXIT

python3 - "$tag" "$commit" "$version" "$draft" "$prerelease" "$notes" > "$work/release.json" <<'PYTHON'
import json, sys
tag, commit, version, draft, prerelease, notes = sys.argv[1:]
with open(notes, encoding="utf-8") as handle:
    body = handle.read()
json.dump({"tag_name": tag, "target_commitish": commit, "name": f"Arbor {version}", "body": body,
           "draft": draft == "true", "prerelease": prerelease == "true"}, sys.stdout)
PYTHON

if [ "$dry_run" = yes ]; then
  echo "Would create at $api/releases:"
  python3 -c 'import json, sys
release = json.load(open(sys.argv[1], encoding="utf-8"))
release["body"] = "(%d characters from %s)" % (len(release["body"]), sys.argv[2])
print(json.dumps(release, indent=2))' "$work/release.json" "$notes"
  echo "Would upload:"
  ls -l "${files[@]}"
  exit 0
fi

[ -n "${GITHUB_TOKEN:-}" ] || { echo "publish-release.sh: GITHUB_TOKEN is not set" >&2; exit 1; }
# In a file only this user can read, so that the token is on no command line.
(umask 077 && printf 'Authorization: Bearer %s\n' "$GITHUB_TOKEN" > "$work/authorization")

# github <method> <url> [curl arguments…]: prints the answer; an error status fails, with GitHub's explanation shown.
github() {
  local method=$1 url=$2
  shift 2
  curl --silent --show-error --fail-with-body --request "$method" --header @"$work/authorization" \
    --header "Accept: application/vnd.github+json" --header "X-GitHub-Api-Version: 2022-11-28" "$@" "$url"
}

# field <name> < json: one field of an object.
field() { python3 -c 'import json, sys; print(json.load(sys.stdin)[sys.argv[1]])' "$1"; }

github GET "$api/releases?per_page=100" > "$work/releases.json"
existing=$(python3 -c 'import json, sys
for release in json.load(open(sys.argv[1], encoding="utf-8")):
    if release["tag_name"] == sys.argv[2]:
        print(release["id"], "draft" if release["draft"] else "published")' "$work/releases.json" "$tag")
while read -r id state; do
  [ -n "$id" ] || continue
  if [ "$state" = published ]; then
    echo "publish-release.sh: $tag is published already; raise VERSION for a new release" >&2
    exit 1
  fi
  echo "Replacing the draft $id left for $tag by an earlier run"
  github DELETE "$api/releases/$id"
done <<< "$existing"

github POST "$api/releases" --header "Content-Type: application/json" --data-binary @"$work/release.json" > "$work/created.json"
# GitHub gives the address as a template: https://uploads.github.com/…/assets{?name,label}
upload=$(field upload_url < "$work/created.json")
upload=${upload%%\{*}
for file in "${files[@]}"; do
  echo "Uploading $file"
  github POST "$upload?name=$(basename "$file")" --header "Content-Type: application/octet-stream" \
    --data-binary @"$file" > /dev/null
done

page=$(field html_url < "$work/created.json")
if [ "$draft" = true ]; then kind="draft release"; else kind="release"; fi
echo "Created the $kind Arbor $version: $page"
if [ -n "${GITHUB_ACTIONS:-}" ]; then echo "::notice title=$kind::Arbor $version: $page"; fi  # safe anywhere: only how a line is printed
