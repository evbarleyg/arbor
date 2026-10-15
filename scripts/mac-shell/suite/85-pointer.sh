#!/bin/bash
# The pointer gestures that need event taps: the ⌃⌥ rectangle and the trackpad pinch.
# T38 drag a rectangle to frame it (⌃⌥ anywhere, plain ⇧ from the Desktop), T36 pinch to zoom.
source "$(dirname "$0")/../lib.sh"
source "$(dirname "$0")/../lib-gestures.sh"
arbor_build
# The pinch and the rectangle need event taps, which Arbor asks for only where its person has asked for the gestures.
arbor_settings "{$ARBOR_GESTURES_ON}"
arbor_start 3 ARBOR_NO_HOTKEYS=0
ctl dock "$W1" left
ctl dock "$W2" beside "$W1" bottom
ctl dock "$W3" right
summary
# An ⌥-click on another app's window hides the app in front, so that has to be a test app: a press that Arbor's tap missed would be one.
click_window "$W3" || exit 1
check "a test app is in front" eventually front_is "$ARBOR_WINDOWS_PID" || on_throwaway_mac || exit 1

claim "⌃⌥-drag a rectangle around a window: a band follows the pointer and release frames the window"
proves T38
take "x y w h" real_frame_of "$W3"
downs=$(events_of "$W3" down)
drag "$((x + 30))" "$((y + 60))" "$((x + w - 30))" "$((y + h - 40))" --mods ctrl+opt --no-release
check "a band is on screen while the button is held" eventually has_overlay 3
echo "the band is at $(overlay_frame 3)"
release --mods ctrl+opt
check "Arbor ran frame-rect" eventually logged "frame-rect "
check "the window inside the rectangle fills the screen" eventually fills "$W3"
check "the others are out of view" eventually out_of_view "$W1"
check "the band is gone" eventually fails has_overlay 3
check "the app under the pointer saw no press" received "$W3" down -eq "$downs"
check "and no drag" received "$W3" dragged -eq 0
ctl show-all

claim "⌃⌥-drag a rectangle around a column: the camera frames the column"
proves T38
take "x y w h" real_frame_of "$W1"
take "_ y2 _ h2" real_frame_of "$W2"
drag "$((x + 20))" "$((y + 50))" "$((x + w - 20))" "$((y2 + h2 - 30))" --mods ctrl+opt
check "both windows of the column are in view" eventually in_view "$W1"
check "the lower one too" eventually in_view "$W2"
check "they are as wide as the screen" eventually at_edge "$W1" right
check "the window outside the rectangle is out of view" eventually out_of_view "$W3"
settled
ctl show-all

claim "a ⌃⌥-click without a drag still reaches the app"
proves T38
downs=$(events_of "$W3" down)
# shellcheck disable=SC2046
click $(center_of "$W3") --mods ctrl+opt
check "the app got the press" eventually received "$W3" down -gt "$downs"
check "the camera stayed" stays camera_on root

claim "a ⌃⌥-drag too small to mean anything does nothing"
proves T38
take "x y" center_of "$W1"
drag "$x" "$y" "$((x + 20))" "$((y + 15))" --mods ctrl+opt
check "the camera stayed" stays camera_on root
check "no band is left on screen" fails has_overlay 3

# To Arbor the curtain that hangs on a person's Mac is an app's window.
if desktop_is_bare; then
  claim "⇧-drag that starts on the Desktop, around a window: release frames the window"
  proves T38
  take "x y w h" real_frame_of "$W3"
  drag "$((x - 30))" "$((y + 40))" "$((x + w - 10))" "$((y + h - 10))" --mods shift --no-release
  check "a band is on screen while the button is held" eventually has_overlay 3
  release --mods shift
  check "the window inside the rectangle fills the screen" eventually fills "$W3"
  check "the band is gone" eventually fails has_overlay 3
  ctl show-all
fi

claim "⇧-drag that starts over a window belongs to the app"
proves T38
dragged=$(events_of "$W3" dragged)
take "x y" center_of "$W3"
drag "$x" "$y" "$((x + 80))" "$((y + 60))" --mods shift
check "the app saw the drag" eventually received "$W3" dragged -gt "$dragged"
check "the camera stayed" stays camera_on root
check "no band is left on screen" fails has_overlay 3

claim "an ordinary drag is none of Arbor's business"
dragged=$(events_of "$W3" dragged)
take "x y" center_of "$W3"
drag "$x" "$y" "$((x + 60))" "$((y + 40))"
check "the app saw the drag" eventually received "$W3" dragged -gt "$dragged"
check "the camera stayed" camera_on root

# No public API makes gesture events: pointer.swift fills in the fields a trackpad's events carry.
claim "hold ⌥ and spread two fingers over a window: the camera steps in toward it"
proves T36
# shellcheck disable=SC2046
pinch $(center_of "$W1") 0.3 --mods opt
check "Arbor stepped in" eventually ran in
check "the window beyond the Desktop left the screen" eventually out_of_view "$W3"
check "the column under the pointer is in view" eventually in_view "$W1"
check "the app under the pointer saw nothing of the pinch" received "$W1" magnify -eq 0

claim "hold ⌥ and pinch two fingers together: the camera steps out"
proves T36
# shellcheck disable=SC2046
pinch $(center_of "$W1") -0.3 --mods opt
check "Arbor stepped out" eventually ran out
check "everything is in view" eventually camera_on root
check "the window beyond the Desktop is back" eventually in_view "$W3"

if desktop_is_bare; then
  claim "spread two fingers over the Desktop, without ⌥: the camera steps in to it"
  proves T36
  # shellcheck disable=SC2046
  pinch $(desktop_point) 0.3
  check "Arbor stepped in" eventually ran in
  check "the camera is on the Desktop" eventually camera_on desktop
  ctl show-all
fi

claim "a pinch over a window without ⌥ belongs to the app"
proves T36
# shellcheck disable=SC2046
pinch $(center_of "$W3") 0.3
check "Arbor did nothing" stays fails ran in
check "the app got the pinch" eventually received "$W3" magnify -gt 0

claim "a long spread steps in once per threshold"
proves T36
# shellcheck disable=SC2046
pinch $(center_of "$W1") 0.6 --mods opt --steps 20
check "two steps in: the window under the pointer fills the screen" eventually fills "$W1"
ctl show-all

arbor_stop
