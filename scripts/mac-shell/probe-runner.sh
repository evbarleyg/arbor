#!/bin/bash
# Asks one of GitHub's Macs what it is. Changes nothing, builds nothing.
echo "label: ${RUNNER_NAME:-?} image ${ImageOS:-?} ${ImageVersion:-?}"
sw_vers
uname -m
sysctl -n hw.model hw.ncpu hw.memsize machdep.cpu.brand_string
ls -d /Applications/Xcode*.app
xcode-select -p
swift --version 2>&1
df -h / | tail -1
system_profiler SPDisplaysDataType 2>/dev/null | grep -E "Resolution|Chipset|Displays" | head
