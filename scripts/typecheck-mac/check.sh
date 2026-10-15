#!/bin/bash
# Type-checks all of Arbor's macOS-only code on Linux, the tests and the Mac shell's helper tools included. See README.md next to this file.
#   scripts/typecheck-mac/check.sh                    the checkout
#   scripts/typecheck-mac/check.sh origin/feat/F99    that commit's Sources, Tests and helpers, with this checkout's stand-ins
#   scripts/typecheck-mac/check.sh --sources DIR      the Sources folder DIR, with Tests and scripts/mac-shell beside it if they are there
#                                                     (selftest.py uses this)
# Prints the errors and warnings about Arbor's files. Exit code 0 when it all type-checks.
#
# It calls the compiler itself, one whole-module -typecheck per target. `swift build` stops at the first stage that fails, so a wrong
# override hid every mistake inside a function, and one broken executable kept the others from being looked at (selftest.py).
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
work="$root/.build/typecheck-mac"
if [ "$(uname)" = Darwin ]; then echo "On a Mac, swift build checks the real thing."; exit 2; fi

# The stand-ins, each after the ones it imports.
frameworks="FakeMacOS MacFoundation Darwin CarbonSwift CoreGraphics ApplicationServices QuartzCore AppKit os ServiceManagement Combine SwiftUI
  CoreVideo CoreMedia ScreenCaptureKit ImageIO UniformTypeIdentifiers UserNotifications CoreAudio CoreMediaIO"
# Arbor's targets as the real manifest declares them on macOS, each after the ones it imports. The libraries first.
libraries="ArborCore ArborIPC ArborKit ArborTesting"
# `make check` compiles these whole, on Linux. What imports them wants only what they declare, so that is written first; their functions' bodies
# are checked beside everything else, for the one thing Linux lets pass and a Mac does not (hashed geometry, below).
headless="ArborCore ArborTesting"
executables="Arbor arborctl ArborTestWindows arbor-e2e"
# Of the tests, the files with something in them for the Mac alone, which no compiler on Linux looks at; and of those that make sets, dictionaries
# or hashes, which may be of geometry, the ones the branch has changed since it left the trunk, which has passed this check. ALL=1 looks at
# all of them (half a minute more); BASE=<ref> names another trunk. `make check` compiles the others.
tests="ArborCoreTests ArborKitTests"
mayHash='\bSet\(|\bDictionary\(|\.combine\('
macOnly='^[[:space:]]*#(if|elseif) .*(os\(macOS\)|canImport\((AppKit|Carbon|QuartzCore|SwiftUI|ApplicationServices|ScreenCaptureKit|Darwin|os)\))|^(@testable )?import (AppKit|Carbon|QuartzCore|SwiftUI|ApplicationServices)'
# Built on Linux as they are, by `make check`.
elsewhere="arbor-sim arbor-fakemac LinuxShims"

mkdir -p "$work/modules" "$work/modules5"
rm -rf "$work/src" "$work/tests" "$work/helpers" "$work/all"
mkdir -p "$work/src" "$work/tests" "$work/helpers" "$work/all"
tools="$root/scripts/mac-shell"
if [ "${1:-}" = --sources ]; then
  cp -R "$2" "$work/all/Sources"
  if [ -d "$2/../Tests" ]; then cp -R "$2/../Tests" "$work/all/Tests"; fi
  tools="$2/../scripts/mac-shell"
elif [ $# -gt 0 ]; then
  git -C "$root" archive "$1" Sources Tests scripts/mac-shell | tar -x -C "$work/all" || { echo "no such commit: $1"; exit 2; }
  tools="$work/all/scripts/mac-shell"
else
  cp -R "$root/Sources" "$root/Tests" "$work/all/"
fi
# The Mac shell's helper tools: each is a program of one file that a script compiles ON the Mac (`swiftc -swift-version 5`, lib.sh)
# before it does anything else. `swift build` never sees them, so a slip in one costs a whole run on a Mac.
for tool in "$tools"/*.swift; do
  [ -f "$tool" ] || continue
  mkdir -p "$work/helpers/$(basename "$tool" .swift)"
  cp "$tool" "$work/helpers/$(basename "$tool" .swift)/main.swift"
done
for target in $libraries $executables; do mv "$work/all/Sources/$target" "$work/src/" || exit 2; done
for target in $tests; do if [ -d "$work/all/Tests/$target" ]; then mv "$work/all/Tests/$target" "$work/tests/"; fi; done
for folder in "$work"/all/Sources/*/; do
  name=$(basename "$folder")
  case " $elsewhere " in *" $name "*) ;; *) echo "note: Sources/$name is not checked: add it to scripts/typecheck-mac/check.sh" ;; esac
done
rm -rf "$work/all"
cd "$work" || exit 2

flags=(-swift-version 6 -I modules -no-color-diagnostics
  -diagnostic-style llvm -module-cache-path "$work/module-cache")
# The stand-ins written in C.
for headers in "$here"/stubs/*/include; do flags+=(-I "$headers"); done
# Only deprecated in the stand-ins, because that is all they can do, but refused on the Mac (stubs/MacFoundation/HashedGeometry.swift).
refused="only available in macOS 15.0 or newer"
# On the Mac these are `@convention(c)`: whatever is passed for one must capture nothing. Linux refuses that convention for functions that take classes, so in the stand-ins they
# are plain closure types. In the helpers' copy of the stand-ins (below) they are `@convention(thin)`, which the type checker lets pass like the other; the stage after it (SILGen)
# refuses a closure or a local function with a context, in words of its own. So files that speak of such a callback go one stage further than -typecheck. In language mode 5, the
# helpers' own: in mode 6 that stage refuses a named function as well.
callbacks='AXObserverCallback|CGEventTapCallBack|CFNotificationCallback|CGDisplayReconfigurationCallBack'
makesCallbacks="$callbacks|AXObserverCreate|tapCreate|CGDisplayRegisterReconfigurationCallback|CGDisplayRemoveReconfigurationCallback|CFNotificationCenterAddObserver"
captures='INTERNAL ERROR: feature not implemented: nontrivial thin function reference'
# Each message once, with the path a person would open; the stand-ins' own warnings are nobody's business, and what is said about
# a macro's expansion is said about the line with the macro as well.
report() {
  grep -E "^[^ ].*:[0-9]+:[0-9]+: (error|warning):" | sed -e 's/ \[#.*$//' -e "s#^$here/#scripts/typecheck-mac/#" -e 's#^src/#Sources/#' -e 's#^tests/#Tests/#' \
    -e 's#^helpers/\([^/]*\)/main\.swift#scripts/mac-shell/\1.swift#' -e "s#^stubs5/#scripts/typecheck-mac/stubs/#" \
    -e "s/: warning: .* is deprecated: \(.*$refused\)/: error: \1/" \
    -e "s/$captures/a C function pointer cannot be formed from a closure or a local function that captures context/" \
    | grep -v -e "^scripts/typecheck-mac/.*warning:" -e "^/tmp/swift-generated-sources/.*warning:" -e "^/tmp/swift-generated-sources/.*$refused" | sort -u
}
failed=0

# The stand-ins change seldom: build their modules again only when they, or the compiler, have.
stamp=$( (swiftc --version 2>&1; find "$here/stubs" -type f | sort | xargs cat) | sha256sum | cut -d' ' -f1)
if [ "$(cat modules/stamp 2>/dev/null)" != "$stamp" ]; then
  rm -f modules/*
  for module in $frameworks; do
    if ! swiftc "${flags[@]}" -emit-module -parse-as-library -module-name "$module" -emit-module-path "modules/$module.swiftmodule" \
      "$here/stubs/$module"/*.swift > "log-$module.txt" 2>&1
    then
      report < "log-$module.txt"
      echo "the stand-in for $module does not compile (whole output: .build/typecheck-mac/log-$module.txt)"
      exit 1
    fi
  done
  echo "$stamp" > modules/stamp
fi

# The same stand-ins once more for the helpers, with every `@MainActor` marked `@preconcurrency`. That is what the SDK's is, coming from
# Objective-C: in language mode 5 top-level code may call `NSApplication.shared.run()` without further ado. In the modules above it would
# turn mistakes in Arbor's own Swift 6 code into warnings.
flags5=()
for flag in "${flags[@]}"; do
  case "$flag" in
    6) flags5+=(5) ;;
    modules) flags5+=(modules5) ;;
    *) flags5+=("$flag") ;;
  esac
done
if [ "$(cat modules5/stamp 2>/dev/null)" != "$stamp" ]; then
  rm -rf modules5/* stubs5
  cp -R "$here/stubs" stubs5
  find stubs5 -name '*.swift' -exec sed -i -E -e 's/^( *)@MainActor (public|open) /\1@preconcurrency @MainActor \2 /' \
    -e "s/^public typealias ($callbacks) = \(/public typealias \1 = @convention(thin) (/" {} +
  if [ "$(grep -rhE "^public typealias ($callbacks) = @convention\(thin\)" stubs5 | wc -l)" -ne 4 ]; then
    echo "the stand-ins' C callbacks are not written as check.sh expects them: a capture would go unnoticed"
    exit 1
  fi
  for module in $frameworks; do
    # Still in mode 6, as the first set: only the mark differs.
    if ! swiftc "${flags5[@]/#5/6}" -emit-module -parse-as-library -module-name "$module" -emit-module-path "modules5/$module.swiftmodule" \
      "stubs5/$module"/*.swift > "log-$module-5.txt" 2>&1
    then
      report < "log-$module-5.txt"
      echo "the stand-in for $module does not compile for the helpers (whole output: .build/typecheck-mac/log-$module-5.txt)"
      exit 1
    fi
  done
  echo "$stamp" > modules5/stamp
fi

# Before prepare.py answers the conditions.
base=${BASE:-}
for ref in origin/swarm/trunk origin/main; do
  if [ -z "$base" ] && git -C "$root" rev-parse -q --verify "$ref" > /dev/null; then base=$ref; fi
done
# Where this branch left it: what the trunk has changed since is the trunk's, and has passed.
branch=HEAD
if [ $# -gt 0 ] && [ "$1" != --sources ]; then branch=$1; fi
if [ -n "$base" ]; then base=$(git -C "$root" merge-base "$base" "$branch" 2> /dev/null || echo "$base"); fi
{
  grep -rlE "$macOnly" tests --include='*.swift'
  grep -rlE "$mayHash" tests --include='*.swift' | while read -r file; do
    if [ -n "${ALL:-}" ] || [ -z "$base" ] \
      || [ "$(git -C "$root" rev-parse -q --verify "$base:Tests/${file#tests/}")" != "$(git -C "$root" hash-object "$work/$file")" ]
    then echo "$file"; fi
  done
} | sort -u > checked-tests.txt
"$here/prepare.py" "$work/src" | sed 's#^#Sources/#'
[ "${PIPESTATUS[0]}" -eq 0 ] || failed=1
"$here/prepare.py" "$work/tests" | sed 's#^#Tests/#'
[ "${PIPESTATUS[0]}" -eq 0 ] || failed=1
"$here/prepare.py" "$work/helpers" | sed 's#^\([^/]*\)/main\.swift#scripts/mac-shell/\1.swift#'
[ "${PIPESTATUS[0]}" -eq 0 ] || failed=1

bodies=()
for target in $libraries $executables $tests; do
  module=${target//-/_}
  folder="src/$target"
  case " $tests " in *" $target "*) folder="tests/$target" ;; esac
  [ -d "$folder" ] || continue
  mapfile -t files < <(find "$folder" -name '*.swift' | sort)
  kind=(-parse-as-library)
  case " $executables " in *" $target "*) kind=() ;; esac
  case " $tests " in
  *" $target "*)
    # The bodies of these files are checked; the rest of the target is only read for what it declares, which takes
    # seconds where checking 30,000 lines of tests, with a macro in every other one, takes minutes. One compiler to a core.
    grep -q "^$folder/" checked-tests.txt || continue
    cores=$(nproc)
    pids=()
    for ((part = 0; part < cores; part++)); do
      arguments=()
      turn=0
      for file in "${files[@]}"; do
        if grep -qxF "$file" checked-tests.txt && [ $((turn++ % cores)) -eq "$part" ]; then arguments+=(-primary-file "$file"); else arguments+=("$file"); fi
      done
      # Fewer files than cores. Without a primary file the compiler would check the whole target: minutes.
      case " ${arguments[*]} " in *" -primary-file "*) ;; *) continue ;; esac
      swiftc -frontend -typecheck "${flags[@]}" -plugin-path "$(dirname "$(dirname "$(readlink -f "$(command -v swiftc)")")")/lib/swift/host/plugins" \
        -package-name arbor -module-name "$module" -parse-as-library "${arguments[@]}" > "log-$target-$part.txt" 2>&1 &
      pids+=($!)
    done
    code=0
    for pid in "${pids[@]}"; do wait "$pid" || code=1; done
    cat "log-$target"-[0-9]*.txt > "log-$target.txt"
    rm -f "log-$target"-[0-9]*.txt
    : "$code" ;;
  *)
    writing=
    case " $libraries " in *" $target "*)
      # What imports it needs its module, which holds no bodies: written beside the check, not after it. The tests say `@testable import`.
      swiftc "${flags[@]}" -emit-module -wmo -enable-testing -Xfrontend -experimental-skip-non-inlinable-function-bodies-without-types \
        -package-name arbor -parse-as-library -module-name "$module" -emit-module-path "modules/$module.swiftmodule" "${files[@]}" \
        > "log-$target-module.txt" 2>&1 &
      writing=$! ;;
    esac
    code=0
    case " $headless " in
    *" $target "*)
      : > "log-$target.txt"
      swiftc "${flags[@]}" -typecheck -wmo -package-name arbor -module-name "$module" "${kind[@]}" "${files[@]}" > "log-$target-bodies.txt" 2>&1 &
      bodies+=("$target:$!") ;;
    *)
      swiftc "${flags[@]}" -typecheck -wmo -package-name arbor -module-name "$module" "${kind[@]}" "${files[@]}" > "log-$target.txt" 2>&1
      code=$? ;;
    esac
    if [ -n "$writing" ] && ! wait "$writing" && [ "$code" -eq 0 ]; then
      # Only what it declares was looked at, and that is wrong.
      cp "log-$target-module.txt" "log-$target.txt"
      code=1
    fi ;;
  esac
  # Callbacks that capture. File by file, whatever became of the rest of the target: a file that does not type-check itself gets no further, and says nothing here.
  case " $tests " in *" $target "*) ;; *)
    for file in $(grep -lE "$makesCallbacks" "${files[@]}"); do
      others=()
      for other in "${files[@]}"; do [ "$other" = "$file" ] || others+=("$other"); done
      found=$(swiftc -frontend -emit-silgen "${flags5[@]}" -I modules -package-name arbor -module-name "$module" "${kind[@]}" -primary-file "$file" "${others[@]}" -o /dev/null 2>&1 \
        | grep -F "$captures")
      if [ -n "$found" ]; then echo "$found" >> "log-$target.txt"; code=1; fi
    done ;;
  esac
  report < "log-$target.txt"
  # The compiler was content, so what imports this can still be looked at.
  if grep -q "$refused" "log-$target.txt"; then failed=1; fi
  if [ "$code" -ne 0 ]; then
    failed=1
    # A failure that names no line must not pass for silence.
    grep -qE ":[0-9]+:[0-9]+: error:" "log-$target.txt" || grep -E "error:" "log-$target.txt" | head
    case " $libraries " in *" $target "*)
      echo "note: $target does not type-check, so what imports it was not looked at"
      break ;;
    esac
    continue
  fi
done
for entry in "${bodies[@]}"; do
  wait "${entry#*:}" || failed=1
  report < "log-${entry%:*}-bodies.txt"
  if grep -q "$refused" "log-${entry%:*}-bodies.txt"; then failed=1; fi
done
rm -f modules/Arbor*.swiftmodule modules/Arbor*.swiftdoc modules/Arbor*.swiftsourceinfo modules/Arbor*.abi.json

# They import nothing of Arbor's, so they are looked at whatever became of the targets above, and each whatever became of the others.
for tool in helpers/*/; do
  [ -d "$tool" ] || continue
  name=$(basename "$tool")
  swiftc "${flags5[@]}" -typecheck -module-name "${name//-/_}" "helpers/$name/main.swift" > "log-helper-$name.txt" 2>&1
  code=$?
  if [ "$code" -eq 0 ] && grep -qE "$makesCallbacks" "helpers/$name/main.swift"; then
    found=$(swiftc "${flags5[@]}" -emit-silgen -module-name "${name//-/_}" "helpers/$name/main.swift" -o /dev/null 2>&1 | grep -F "$captures")
    if [ -n "$found" ]; then echo "$found" >> "log-helper-$name.txt"; code=1; fi
  fi
  # What comes from C and Objective-C may be called for its effect alone; Foundation on Linux is written in Swift and says otherwise.
  report < "log-helper-$name.txt" | grep -v "warning: result of call to .* is unused"
  if [ "$code" -ne 0 ]; then
    failed=1
    grep -qE ":[0-9]+:[0-9]+: error:" "log-helper-$name.txt" || grep -E "error:" "log-helper-$name.txt" | head
  fi
done

if [ "$failed" -eq 0 ]; then echo "type-checks against the stand-ins"; exit 0; fi
echo "does not type-check (the compiler's whole output: .build/typecheck-mac/log-<target>.txt)"
exit 1
