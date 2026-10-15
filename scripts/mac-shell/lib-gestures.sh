# For a script about a gesture that needs an event tap, or about the taps themselves. Source it after lib.sh; do not run it.
#
#   source "$(dirname "$0")/lib.sh"
#   source "$(dirname "$0")/lib-gestures.sh"
#   arbor_settings "{$ARBOR_GESTURES_ON}"                 before arbor_start
#   arbor_settings "{\"gap\": 24, $ARBOR_GESTURES_ON}"    with more besides
#
# The pinch, ⌃⌥ + scroll, the ⌃⌥ rectangle and ⇧-drag on the Desktop each need a tap. Whoever is about one of them asks for all four and for
# the switch above them (`pointerGestures`), and so goes on asking the same of Arbor whatever it ships with. Every session has a home of
# its own: every session asks again.

# To go between the braces of a settings.json.
# shellcheck disable=SC2034
ARBOR_GESTURES_ON='"pointerGestures": true, "gesturesEnabled": true, "scrollZoom": true, "frameRectangleModifier": "ctrl+opt", "frameRectangleOnDesktop": true'
