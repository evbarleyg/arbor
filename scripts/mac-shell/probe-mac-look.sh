#!/bin/bash
# What a script of a list finds: the settings scripts/ci-mac-shell.sh puts back between two scripts. Only reads.
source "$(dirname "$0")/lib.sh"
arbor_build
step "what this script finds"
macos_tiling
macos_click_wallpaper
macos_reduce_motion
echo "appearance: $("$ARBOR_VDISPLAY" appearance 2>&1)"
echo "Accessibility: $("$ARBOR_POINTER" ax-access)"
spaces
echo "questions macOS has on the screen: $("$ARBOR_POINTER" windows | grep -cE " on (UserNotificationCenter|CoreServicesUIAgent|SecurityAgent|universalAccessAuthWarn)$")"
echo "share: ${MAC_SHELL_SHARE:-unset}; playing ${MAC_SHELL_PART:-?} of ${MAC_SHELL_PARTS:-?}"
