#!/bin/bash
# Tests the parts of the release tooling that need no Mac: version.sh, release-notes.sh and, against a stand-in for
# GitHub's API on this machine, publish-release.sh. Part of `make check`. Everything happens in a temporary copy, so
# a real build/ is left alone and nothing reaches the network.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 2

root=$(mktemp -d) || { echo "release-tools-test.sh: no temporary folder" >&2; exit 2; }
server=""
cleanup() {
  [ -z "$server" ] || kill "$server" 2>/dev/null
  rm -rf "${root:?}"
}
trap cleanup EXIT

failed=0
check() {  # check "<what should hold>" <command…>
  local what=$1
  shift
  if "$@" >/dev/null 2>&1; then echo "  ✔ $what"; else echo "  ✘ $what"; failed=1; fi
}
contains() { grep -qF -- "$2" "$1"; }
lacks() { ! grep -qF -- "$2" "$1"; }
fails() { ! "$@"; }

mkdir -p "$root/scripts" "$root/build"
cp scripts/version.sh scripts/release-notes.sh scripts/publish-release.sh "$root/scripts/"
echo "1.2.3" > "$root/VERSION"
cat > "$root/CHANGELOG.md" <<'CHANGELOG'
# Changelog

Newest first.

## Unreleased

### Added

- **Tabs.** Drop a window on the middle
  of another to stack them.
- Second item.

A paragraph that is
wrapped in the file.

```
code stays
  as it is
```

| a | b |
|---|---|

## 1.2.2

- Old news.
CHANGELOG
# No Git in the copy, as in a source archive.
export GIT_DIR="$root/no-such-repository"
unset ARBOR_VERSION ARBOR_NOTARIZED ARBOR_DRAFT GITHUB_ACTIONS GITHUB_API_URL GITHUB_REPOSITORY GITHUB_SHA GITHUB_TOKEN

echo "version.sh"
check "the version is the VERSION file's" test "$("$root/scripts/version.sh" version)" = 1.2.3
check "without Git the build is 0 and the commit unknown" test "$("$root/scripts/version.sh")" = "1.2.3 (build 0, unknown)"
check "ARBOR_VERSION replaces it" test "$(ARBOR_VERSION=2.0.0-rc.1 "$root/scripts/version.sh" version)" = 2.0.0-rc.1
check "what is not a version is refused" fails env ARBOR_VERSION='1.0;x' "$root/scripts/version.sh" version
check "so is a path" fails env ARBOR_VERSION='1.0.0-../x' "$root/scripts/version.sh" version
check "this repository's own VERSION is accepted" ./scripts/version.sh version

echo "release-notes.sh"
printf 'abc  Arbor-1.2.3.zip\ndef  Arbor-1.2.3.dmg\n' > "$root/build/Arbor-1.2.3-checksums.txt"
notes="$root/notes.md"
"$root/scripts/release-notes.sh" > "$notes"
check "they start with the top section's first line" test "$(head -n 1 "$notes")" = "### Added"
check "wrapped list items are joined" contains "$notes" "- **Tabs.** Drop a window on the middle of another to stack them."
check "wrapped paragraphs are joined" contains "$notes" "A paragraph that is wrapped in the file."
check "the next item starts a new line" contains "$notes" "- Second item."
check "code blocks keep their lines" contains "$notes" "  as it is"
check "tables keep their rows" contains "$notes" "|---|---|"
check "older sections stay out" lacks "$notes" "Old news"
check "the heading of the section stays out" lacks "$notes" "Unreleased"
check "the first launch is explained" contains "$notes" "Open Anyway"
check "and the way around it" contains "$notes" "xattr -dr com.apple.quarantine /Applications/Arbor.app"
check "the files are named after the version" contains "$notes" "Arbor-1.2.3.dmg"
check "the checksums are listed" contains "$notes" "def  Arbor-1.2.3.dmg"
ARBOR_NOTARIZED=1 "$root/scripts/release-notes.sh" > "$root/notarized.md"
check "a notarized build's notes leave Gatekeeper out" lacks "$root/notarized.md" "Open Anyway"

echo "publish-release.sh"
check "it refuses to run before make release" fails "$root/scripts/publish-release.sh" --dry-run
cp "$notes" "$root/build/Arbor-1.2.3-notes.md"
printf 'disk image' > "$root/build/Arbor-1.2.3.dmg"
printf 'archive' > "$root/build/Arbor-1.2.3.zip"
printf 'cask' > "$root/build/arbor.rb"
export GITHUB_SHA=0123456789abcdef0123456789abcdef01234567
"$root/scripts/publish-release.sh" --dry-run > "$root/dry-run.txt" 2>&1
check "a dry run needs no token and names the tag" contains "$root/dry-run.txt" '"tag_name": "v1.2.3"'
check "a dry run says it is a draft" contains "$root/dry-run.txt" '"draft": true'
check "without a token nothing is sent" fails "$root/scripts/publish-release.sh"

finish() {
  if [ "$failed" -eq 0 ]; then echo "release tools test passed"; else echo "release tools test FAILED"; fi
  exit "$failed"
}
# The Swift image for Linux has none. macOS and the machine that publishes do.
if ! command -v curl >/dev/null; then
  echo "  (not tried against a stand-in for GitHub: there is no curl here)"
  finish
fi

# A stand-in for GitHub: answers the four calls the script makes and writes down what it was sent.
cat > "$root/github.py" <<'PYTHON'
import http.server, json, os, sys

root = sys.argv[1]

class Handler(http.server.BaseHTTPRequestHandler):
    def answer(self, status, body=None):
        data = json.dumps(body).encode() if body is not None else b""
        self.send_response(status)
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def handle_any(self):
        body = self.rfile.read(int(self.headers.get("Content-Length") or 0))
        with open(os.path.join(root, "requests.log"), "a", encoding="utf-8") as log:
            log.write(f"{self.command} {self.path} auth={self.headers.get('Authorization')} "
                      f"type={self.headers.get('Content-Type')} body={body.decode()[:4000]!r}\n")
        base = f"http://127.0.0.1:{self.server.server_address[1]}"
        if self.command == "GET" and self.path == "/repos/o/r/releases?per_page=100":
            with open(os.path.join(root, "existing.json"), encoding="utf-8") as existing:
                return self.answer(200, json.load(existing))
        if self.command == "DELETE" and self.path.startswith("/repos/o/r/releases/"):
            return self.answer(204)
        if self.command == "POST" and self.path == "/repos/o/r/releases":
            return self.answer(201, {"id": 77, "html_url": "https://example.invalid/releases/77",
                                     "upload_url": base + "/uploads/77/assets{?name,label}"})
        if self.command == "POST" and self.path.startswith("/uploads/77/assets?name="):
            return self.answer(201, {})
        self.answer(422, {"message": "the stand-in does not know this call"})

    do_GET = do_POST = do_DELETE = handle_any

    def log_message(self, *arguments):
        pass

server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
with open(os.path.join(root, "port"), "w", encoding="utf-8") as port:
    port.write(str(server.server_address[1]))
server.serve_forever()
PYTHON
python3 "$root/github.py" "$root" &
server=$!
tries=0
# A hosted Mac took more than five seconds to start Python for the first time.
while [ ! -s "$root/port" ] && [ "$tries" -lt 600 ]; do sleep 0.1; tries=$((tries + 1)); done
port=$(cat "$root/port")
export GITHUB_API_URL="http://127.0.0.1:$port" GITHUB_REPOSITORY=o/r GITHUB_TOKEN=s3cret NO_PROXY=127.0.0.1
log="$root/requests.log"

echo '[{"id": 5, "tag_name": "v1.2.2", "draft": false}, {"id": 6, "tag_name": "v1.2.3", "draft": true}]' > "$root/existing.json"
"$root/scripts/publish-release.sh" > "$root/publish.txt" 2>&1
check "it succeeds" test $? -eq 0
check "an earlier draft for the version is replaced" contains "$log" "DELETE /repos/o/r/releases/6 "
check "other releases are left alone" lacks "$log" "DELETE /repos/o/r/releases/5 "
check "the release is a draft on the commit, named after the version" contains "$log" \
  '"tag_name": "v1.2.3", "target_commitish": "0123456789abcdef0123456789abcdef01234567", "name": "Arbor 1.2.3"'
check "not a pre-release" contains "$log" '"draft": true, "prerelease": false'
check "the notes are its body" contains "$log" "Drop a window on the middle of another"
check "the disk image is uploaded as it is" contains "$log" \
  "POST /uploads/77/assets?name=Arbor-1.2.3.dmg auth=Bearer s3cret type=application/octet-stream body='disk image'"
check "so is the archive" contains "$log" "assets?name=Arbor-1.2.3.zip auth=Bearer s3cret type=application/octet-stream body='archive'"
check "so are the checksums" contains "$log" "assets?name=Arbor-1.2.3-checksums.txt "
check "so is the cask" contains "$log" "assets?name=arbor.rb "
check "every call carries the token" lacks "$log" "auth=None"
check "the token is not printed" lacks "$root/publish.txt" s3cret
check "it says where the draft is" contains "$root/publish.txt" "Created the draft release Arbor 1.2.3: https://example.invalid/releases/77"

: > "$log"
echo '[{"id": 6, "tag_name": "v1.2.3", "draft": false}]' > "$root/existing.json"
check "a published release is never replaced" fails "$root/scripts/publish-release.sh"
check "nor is anything sent after finding one" lacks "$log" "POST"

: > "$log"
echo '[]' > "$root/existing.json"
for name in dmg zip; do cp "$root/build/Arbor-1.2.3.$name" "$root/build/Arbor-1.2.4-rc.1.$name"; done
cp "$root/build/Arbor-1.2.3-notes.md" "$root/build/Arbor-1.2.4-rc.1-notes.md"
cp "$root/build/Arbor-1.2.3-checksums.txt" "$root/build/Arbor-1.2.4-rc.1-checksums.txt"
check "a release candidate can be published at once" env ARBOR_VERSION=1.2.4-rc.1 ARBOR_DRAFT=false "$root/scripts/publish-release.sh"
check "as a pre-release" contains "$log" '"draft": false, "prerelease": true'

: > "$log"
check "GitHub's refusal fails the script" fails env GITHUB_REPOSITORY=o/other "$root/scripts/publish-release.sh"

finish
