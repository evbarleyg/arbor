#!/bin/bash
# Builds Arbor's real Accessibility layer for Linux, on a model of a Mac, and runs the stories about it. See README.md next to this file.
#   scripts/mac-on-linux/build.sh                 build what has changed, run every story and a short walk
#   scripts/mac-on-linux/build.sh --only TEXT     the stories whose names contain TEXT   (every other argument goes to the program too: --help)
#   scripts/mac-on-linux/build.sh --self-test     does the net hold? each change in mutants.py is made to the copy, and its stories must go red
#   scripts/mac-on-linux/build.sh --build-only
#   REF=origin/fix/some-cure scripts/mac-on-linux/build.sh …   that commit's Sources, with this checkout's stand-ins, scripts and stories
#   COVERAGE=1 scripts/mac-on-linux/build.sh …                 afterwards: how much of each file of the layer the run has entered, and which lines it has not
# Exit code 0 when it builds and everything is as expected.
#
# It calls the compiler itself, as scripts/typecheck-mac/check.sh does, whose stand-ins and prepare.py it uses: Package.swift knows nothing of
# this, because on Linux it leaves the macOS-only folders out, and on a Mac the real frameworks are there.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
typecheck="$root/scripts/typecheck-mac"
work="$root/.build/mac-on-linux"
sources="$root/Sources"
if [ -n "${REF:-}" ]; then
  # A work folder of its own, so that going to and fro between two commits compiles nothing twice.
  work="$root/.build/mac-on-linux-$(git -C "$root" rev-parse --short "$REF")" || exit 2
  # Nothing is taken over from the checkout's own work folder: what the compiler notes about an object names the modules it depends on by
  # their place THERE, so in a copy it would not see that Arbor's modules have changed, and would link stories compiled for other types.
  rm -rf "$work/checkout"
  mkdir -p "$work/checkout"
  git -C "$root" archive "$REF" Sources | tar -x -C "$work/checkout" || { echo "no such commit: $REF"; exit 2; }
  sources="$work/checkout/Sources"
fi
if [ -n "${COVERAGE:-}" ]; then work="$work-coverage"; fi
if [ "$(uname)" = Darwin ]; then echo "On a Mac the real thing runs: make e2e."; exit 2; fi

# The stand-ins the layer needs, each after the ones it imports. Here they are compiled for real, not only read for what they declare.
frameworks="FakeMacOS MacFoundation Darwin CarbonSwift CoreGraphics ApplicationServices QuartzCore AppKit os"
# Arbor's own, each after the ones it imports.
libraries="ArborCore ArborIPC ArborKit ArborTesting"
# Of ArborKit: all that builds on Linux anyway, the Accessibility layer, and of the app's own files the one that listens to the workspace beside it
# and the two the layer reads its environment and macOS's settings from. UI, Input and the rest of App stay out: their stand-ins do nothing, so
# running them would show nothing.
kit="Controller Platform Support Trace AX App/FrontmostAppWatcher.swift App/ArborEnvironment.swift App/MacFacts.swift"
# These must know no clock but the model's (retime.py).
onTheModelsClock="ArborKit/AX ArborKit/App ArborKit/Support/AppLanes.swift ArborKit/Support/CallStats.swift ArborKit/Platform/Scheduler.swift"

mkdir -p "$work/modules" "$work/objects" "$work/src"
cd "$work" || exit 2
jobs=$(nproc)
flags=(-swift-version 6 -Onone -I modules -no-color-diagnostics -diagnostic-style llvm -module-cache-path "$work/module-cache")
for headers in "$typecheck"/stubs/*/include; do flags+=(-I "$headers"); done
report() { grep -E "^[^ ].*:[0-9]+:[0-9]+: error:|^error:|^<unknown>:0: error:" | sed -e "s#^$root/##" -e 's#^src/#Sources/#' | sort -u | head -40; }

# --- The stand-ins change seldom: compile them again only when they, or the compiler, have.
stamp=$( (swiftc --version 2>&1; for module in $frameworks; do find "$typecheck/stubs/$module" -type f | sort | xargs cat; done) | sha256sum | cut -d' ' -f1)
if [ "$(cat objects/stand-ins.stamp 2>/dev/null)" != "$stamp" ]; then
  echo "compiling the stand-ins…"
  # What was compiled against the old ones is void.
  rm -rf modules/* objects/*
  for module in $frameworks; do
    mkdir -p "objects/$module"
    if ! (cd "objects/$module" && swiftc "${flags[@]/#modules/..\/..\/modules}" -parse-as-library -module-name "$module" -emit-module \
      -emit-module-path "../../modules/$module.swiftmodule" -c -wmo -num-threads "$jobs" "$typecheck/stubs/$module"/*.swift) > "log-$module.txt" 2>&1
    then
      report < "log-$module.txt"
      echo "the stand-in for $module does not compile (whole output: .build/mac-on-linux/log-$module.txt)"
      exit 1
    fi
  done
  echo "$stamp" > objects/stand-ins.stamp
fi

# Makes src/ the same as staging/, touching only the files whose text differs, so that the compiler looks at those alone.
take_over() {
  python3 - <<'SYNC'
import filecmp, os, shutil
for folder, _, names in os.walk("staging"):
    target = "src" + folder[len("staging"):]
    os.makedirs(target, exist_ok=True)
    for name in names:
        if not os.path.exists(f"{target}/{name}") or not filecmp.cmp(f"{folder}/{name}", f"{target}/{name}", shallow=False):
            shutil.copyfile(f"{folder}/{name}", f"{target}/{name}")
for folder, folders, names in os.walk("src", topdown=False):
    source = "staging" + folder[len("src"):]
    for name in names:
        if not os.path.exists(f"{source}/{name}"):
            os.remove(f"{folder}/{name}")
    if not os.path.isdir(source):
        os.rmdir(folder)
SYNC
}

# --- A copy of the sources, made fit for Linux and put on the model's clock.
copy_sources() {
  rm -rf staging
  mkdir -p staging/ArborKit/App
  for target in $libraries; do
    [ "$target" = ArborKit ] || cp -R "$sources/$target" staging/
  done
  for part in $kit; do cp -R "$sources/ArborKit/$part" "staging/ArborKit/$part"; done
  "$typecheck/prepare.py" "$work/staging" | sed 's#^#Sources/#'
  [ "${PIPESTATUS[0]}" -eq 0 ] || return 1
  # shellcheck disable=SC2086
  "$here/retime.py" "$work/staging" $onTheModelsClock | sed 's#^#Sources/#'
  [ "${PIPESTATUS[0]}" -eq 0 ] || return 1
  take_over
}

# compile <module> <folder> <library|program>: incrementally, as `swift build` does.
compile() {
  local module=$1 folder=$2 kind=(-parse-as-library)
  [ "$3" = program ] && kind=()
  mkdir -p "objects/$module"
  mapfile -t files < <(find "$folder" -name '*.swift' | sort)
  python3 - "$module" "${files[@]}" > "objects/$module.json" <<'MAP'
import json, sys
module, files = sys.argv[1], sys.argv[2:]
entries = {"": {"swift-dependencies": f"objects/{module}/module.swiftdeps"}}
for path in files:
    # The folder is part of the name: two folders may each have a file of one name.
    stem = f"objects/{module}/" + "-".join(path.split("/")[-2:])[:-len(".swift")]
    entries[path] = {"object": stem + ".o", "swiftmodule": stem + "~partial.swiftmodule", "swift-dependencies": stem + ".swiftdeps"}
print(json.dumps(entries))
MAP
  # An object whose source is gone would still be linked.
  python3 - "objects/$module" "objects/$module.json" <<'SWEEP'
import json, os, sys
folder, wanted = sys.argv[1], {entry.get("object") for entry in json.load(open(sys.argv[2])).values()}
for name in os.listdir(folder):
    if name.endswith(".o") and f"{folder}/{name}" not in wanted:
        os.remove(f"{folder}/{name}")
SWEEP
  local counting=()
  [ -n "${COVERAGE:-}" ] && [ "$module" = ArborKit ] && counting=(-profile-generate -profile-coverage-mapping)
  if ! swiftc "${flags[@]}" "${counting[@]}" -incremental -output-file-map "objects/$module.json" -j "$jobs" -package-name arbor -enable-testing "${kind[@]}" \
    -module-name "$module" -emit-module -emit-module-path "modules/$module.swiftmodule" -c "${files[@]}" > "log-$module.txt" 2>&1
  then
    report < "log-$module.txt"
    echo "$module does not compile (whole output: .build/mac-on-linux/log-$module.txt)"
    return 1
  fi
}

build() {
  for target in $libraries; do compile "$target" "src/$target" library || return 1; done
  compile MacOnLinux "$here/tests" program || return 1
  local counting=()
  [ -n "${COVERAGE:-}" ] && counting=(-profile-generate)
  if ! swiftc "${counting[@]}" -o "$1" objects/*/*.o > log-link.txt 2>&1; then
    grep -E "error|undefined" log-link.txt | head -20
    echo "it does not link (whole output: .build/mac-on-linux/log-link.txt)"
    return 1
  fi
}

export ARBOR_HOME="$work/home"
mkdir -p "$ARBOR_HOME"
began=$SECONDS
copy_sources || exit 1

if [ "${1:-}" = --self-test ]; then
  rm -f self-test-failed
  # First the whole list: a list that cannot be had, or is empty, is no self-test that passed.
  "$here/mutants.py" --list > mutants.txt && [ -s mutants.txt ] || { echo "✘ scripts/mac-on-linux/mutants.py lists no change to make"; exit 1; }
  while IFS=$'\t' read -r -a fields <&3; do
    name=${fields[0]}
    expected=()
    for check in "${fields[@]:1}"; do expected+=(--expect-red "$check"); done
    take_over
    if ! "$here/mutants.py" --apply "$name" "$work/src"; then
      echo "✘ $name: the change no longer fits the sources; look at scripts/mac-on-linux/mutants.py"
    elif ! build "$work/mutant"; then
      echo "✘ $name: the changed copy does not build"
    elif ! "$work/mutant" --quiet "${expected[@]}"; then
      echo "✘ $name: not every check that should notice does"
    else
      echo "✔ without the cure the story goes red: $name"
      continue
    fi
    touch self-test-failed
  done 3< mutants.txt
  take_over
  if [ -e self-test-failed ]; then rm -f self-test-failed; exit 1; fi
  echo "all $(wc -l < mutants.txt | tr -d ' ') changes were noticed"
  exit 0
fi

build "$work/mac-on-linux" || exit 1
echo "built in $((SECONDS - began)) s"
[ "${1:-}" = --build-only ] && exit 0
if [ -n "${COVERAGE:-}" ]; then
  LLVM_PROFILE_FILE="$work/run.profraw" "$work/mac-on-linux" --quiet --known "$here/known-failures.txt" "$@"
  code=$?
  llvm-profdata merge -o run.profdata run.profraw
  # Neither rewriting step moves a line, so the copy's lines are the sources'.
  llvm-cov report "$work/mac-on-linux" -instr-profile run.profdata src/ArborKit/AX src/ArborKit/App | sed "s#$work/src/#Sources/#"
  llvm-cov show "$work/mac-on-linux" -instr-profile run.profdata src/ArborKit/AX > coverage.txt
  echo "line by line: .build/${work##*/.build/}/coverage.txt (a count of 0 marks what no story enters)"
  exit "$code"
fi
# What the layer was heard to report is kept for the checkout's own sources.
heard=()
[ -z "${REF:-}" ] && heard=(--heard "$root/collab/evidence/mac-on-linux/heard.jsonl")
exec "$work/mac-on-linux" --known "$here/known-failures.txt" "${heard[@]}" "$@"
