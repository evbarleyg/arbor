#!/bin/bash
# Prints the notes of a release, in Markdown: the top section of CHANGELOG.md, how to install the download and get
# it past its first launch, and the checksums when `make release` has made them.
#
#   scripts/release-notes.sh > notes.md
#
# ARBOR_NOTARIZED=1 leaves out the part about Gatekeeper, which a notarized build does not meet.
set -euo pipefail
cd "$(dirname "$0")/.."

version=$(./scripts/version.sh version)

# From the first "## " heading, without it, to the next. GitHub shows a release's notes with every line break kept, so
# paragraphs and list items that are wrapped in the file are joined up again; headings, list items, tables,
# code blocks and blank lines start afresh.
awk '
  /^## / { section += 1; next }
  section != 1 { next }
  /^```/ { fenced = !fenced; emit($0); joinable = 0; next }
  fenced { emit($0); next }
  /^[[:space:]]*$/ { emit(""); joinable = 0; next }
  /^#/ || /^[[:space:]]*\|/ { emit($0); joinable = 0; next }
  /^[[:space:]]*([-*+]|[0-9]+\.)[[:space:]]/ { emit($0); joinable = 1; next }
  joinable { sub(/^[[:space:]]+/, ""); lines[count] = lines[count] " " $0; next }
  { emit($0); joinable = 1 }
  function emit(line) { lines[++count] = line }
  END {
    first = 1
    while (first <= count && lines[first] == "") first++
    while (count >= first && lines[count] == "") count--
    for (i = first; i <= count; i++) print lines[i]
  }
' CHANGELOG.md

# One line per paragraph here too.
cat <<NOTES

## Installing

Arbor needs macOS 14 or later. The download runs on Apple silicon and Intel.

1. Open \`Arbor-$version.dmg\` and drag Arbor onto Applications (or unpack \`Arbor-$version.zip\` and move it there).
NOTES

if [ "${ARBOR_NOTARIZED:-}" = 1 ]; then
  cat <<NOTES
2. Open Arbor and give it **Accessibility** permission when it asks (System Settings → Privacy & Security → Accessibility). It needs that to move other apps' windows.
NOTES
else
  cat <<NOTES
2. **The first launch takes a detour.** This build is not notarized by Apple, which takes a paid developer account, so macOS refuses a downloaded copy at first: "Apple could not verify "Arbor" is free of malware". Click **Done**, open System Settings → Privacy & Security, scroll down to "Arbor was blocked to protect your Mac" and click **Open Anyway**. (Right-click → Open no longer gets past this on current macOS.) Or take the download's mark off in Terminal: \`xattr -dr com.apple.quarantine /Applications/Arbor.app\`
3. Give Arbor **Accessibility** permission when it asks (System Settings → Privacy & Security → Accessibility). It needs that to move other apps' windows. macOS ties the permission to the signature, and this build's signature is its own, so after replacing Arbor with a later download, remove its entry there and let it ask again.

Building from source avoids both the detour and the repeated permission, in three commands: [docs/INSTALL.md](https://github.com/evbarleyg/arbor/blob/main/docs/INSTALL.md).
NOTES
fi

checksums=build/Arbor-$version-checksums.txt
if [ -f "$checksums" ]; then
  echo
  echo "## SHA-256"
  echo
  echo '```'
  cat "$checksums"
  echo '```'
fi
