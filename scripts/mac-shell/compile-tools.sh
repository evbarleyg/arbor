#!/bin/bash
# Compiles the helper tools of the Mac shell scripts (scripts/mac-shell/*.swift, vdisplay.m) and runs none of them: `swift build` does not
# know them, so a mistake in one shows only when a script that needs it is already running on a Mac.
#
#   scripts/mac-shell/compile-tools.sh [tool…]        (default: all; e.g. pointer curtain)
#
# Safe on a person's Mac: it writes to .build/mac-shell and mac-shell/ and starts nothing. Prints each tool's errors and warnings
# without the checkout's path. Exit code: how many tools did not compile.
cd "$(dirname "$0")/../.." || exit 2
mkdir -p .build/mac-shell mac-shell

if [ $# -eq 0 ]; then
  set -- $(cd scripts/mac-shell && ls ./*.swift ./*.m | sed 's|^\./||; s|\.[a-z]*$||')
fi
failed=0
for tool in "$@"; do
  log="mac-shell/build-$tool.log"
  if [ -f "scripts/mac-shell/$tool.swift" ]; then
    # Language mode 5, as lib.sh compiles them: they are scripts, and strict concurrency has nothing to protect in them.
    swiftc -O -swift-version 5 "scripts/mac-shell/$tool.swift" -o ".build/mac-shell/$tool" > "$log" 2>&1
  elif [ -f "scripts/mac-shell/$tool.m" ]; then
    clang -fobjc-arc -O1 -framework Foundation -framework ApplicationServices -framework CoreGraphics -framework ColorSync \
      "scripts/mac-shell/$tool.m" -o ".build/mac-shell/$tool" > "$log" 2>&1
  else
    echo "✘ $tool: there is no scripts/mac-shell/$tool.swift or .m"
    failed=$((failed + 1))
    continue
  fi
  if [ $? -eq 0 ]; then
    echo "✔ $tool$(grep -c "warning:" "$log" | awk '$1 > 0 { print " (" $1 " warnings)" }')"
  else
    echo "✘ $tool"
    failed=$((failed + 1))
  fi
  grep -A 4 -E "(error|warning):" "$log" | sed "s|$PWD/||g" | head -n 60
done
exit "$failed"
