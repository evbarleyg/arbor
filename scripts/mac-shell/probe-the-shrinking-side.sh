#!/bin/bash
# A window whose foot is off the display, or in the Dock's strip, is asked for LESS: how far does it come? ARBOR IS NOT RUNNING.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-the-shrinking-side.sh          about three minutes
#
# probe-how-far-a-window-grows.sh asked edges that lay past a line only for MORE. On a hosted Mac a TextEdit window that stood at 344,288 322×653, its foot at 941 and so off a display 768 high, was asked for 439 high and ended 480 high:
# 768 less 288 to the point. One reading: a size call puts no foot into the Dock's strip (between the visible frame's bottom and the display's): coming up from off the display it stops at the display's bottom, and once in the
# strip it is held for less as for more. Bare asks, call by call with grow.swift: the window is sized at the top of the display, put down by a position call, read, given ONE size call, and read at once and 50, 200 and 500 ms later, by
# Accessibility and by the window server. Every number is worked out from the displays as they are on the day; those below are for a display of 1024×768 with the visible bottom at 708.
#
#   ask1  stands 344,288 322×653 (foot 941, off the display), asked 439 high: its foot would be at 727, in the strip          the asker's forecast: 480, the foot at the display's bottom
#   ask2  the same stand, asked 300 high: its foot would be at 588, through the strip and out                                  300, or 480?
#   ask3  stands 300,272 400×480 (foot 752, in the strip), asked 439 high: still in it                                         forecast: 480 kept
#   ask4  the same stand, asked 400 high: foot 672, out of the strip upwards                                                   400, or kept?
#   ask5  ask1's stand and 439 high with the Dock hidden, at the left and at the right: no strip below                           free?
#   ask6  the twin in width, with the Dock at the right: the right edge 300 off the display, asked a width that ends in the Dock's strip (a) and one that ends left of it (b); the right edge in the strip, asked
#         less and still in it (c) and out of it (d)
#   ask7  feet 35 past the visible bottom, at the display's bottom, 1, 32 and 82 past it, asked 100 MORE: where between the strip and far off does an edge become free?
#   ask0  THE CONTROLS, wherever the Dock is: a window that stands wholly in view, 300,100 400×480, asked 439 high, and 300,100 400×300 asked 100 more, with room; with the Dock at the right also 100,100 700×300 asked 320 wide.
#         Each must be taken whole, or the tool is at fault and not macOS. ask5 is the control of ask1: the same stand and the same 439, where there is no strip below; the foot asked for then lies ABOVE the visible bottom, not past it: output.txt says beside every ask where its edge would end.
# A test window and TextEdit, three times each.
#
# What comes back: shrink.jsonl, as grow.swift printed it (`put`, `hand`; "label" is <app>.<where the Dock is>); output.txt, the same in words. It judges nothing. Exit code 0 unless a tool did not compile.
source "$(dirname "${BASH_SOURCE[0]}")/lib-apps.sh"
needs_throwaway_mac "move the Dock to every side and hide it, and open and quit a real app"

GROW="$ARBOR_ROOT/.build/mac-shell/grow"
RESULTS="$ARBOR_OUT/shrink.jsonl"
scratch_dir shrink STEPS
: > "$RESULTS"

mkdir -p "$ARBOR_ROOT/.build/mac-shell"
swiftc -O -swift-version 5 "$ARBOR_ROOT/scripts/mac-shell/grow.swift" -o "$GROW" > "$ARBOR_OUT/build-grow.log" 2>&1 &
GROW_COMPILER=$!
apps_build
if ! wait "$GROW_COMPILER"; then
  grep -A 6 "error:" "$ARBOR_OUT/build-grow.log" | head -n 60
  die "scripts/mac-shell/grow.swift did not compile"
fi
apps_watchdog 400

# an_ask <name> <x y w h> <w h>: two steps of grow.swift
an_ask() { printf 'put %s %s %s %s %s\nchain %s size %s %s\n' "$1" "$2" "$3" "$4" "$5" "$1" "$6" "$7"; }
thrice() { local time; for time in 1 2 3; do echo "round $1, time $time"; "$1"; done; }

in_view() {
  an_ask ask0-control-in-view-less 300 100 400 480 400 439
  an_ask ask0-control-in-view-100-more 300 100 400 300 400 400
}
below() {
  in_view
  an_ask ask1-from-off-the-display-into-the-strip 344 b1-480 322 653 322 vb1+19-b1+480
  an_ask ask2-from-off-the-display-through-the-strip 344 b1-480 322 653 322 300
  an_ask ask3-in-the-strip-less-and-still-in-it 300 b1-496 400 480 400 vb1+3-b1+496
  an_ask ask4-in-the-strip-and-out-of-it 300 b1-496 400 480 400 400
  an_ask ask7-foot-35-past-the-visible-bottom-100-more 100 vb1+35-300 320 300 320 400
  an_ask ask7-foot-at-the-bottom-of-the-display-100-more 100 b1-300 320 300 320 400
  an_ask ask7-foot-1-past-it-100-more 100 b1+1-300 320 300 320 400
  an_ask ask7-foot-32-past-it-100-more 100 b1+32-300 320 300 320 400
  an_ask ask7-foot-82-past-it-100-more 100 b1+82-300 320 300 320 400
}
no_strip_below() {
  in_view
  an_ask ask5-from-off-the-display-with-no-strip-below 344 b1-480 322 653 322 439
}
at_the_right() {
  no_strip_below
  an_ask ask0-control-in-view-narrower 100 100 700 300 320 300
  an_ask ask6a-right-edge-off-the-display-into-the-strip r1-400 100 700 300 vr1+20-r1+400 300
  an_ask ask6b-right-edge-off-the-display-through-the-strip r1-400 100 700 300 320 300
  an_ask ask6c-right-edge-in-the-strip-less-and-still-in-it r1-400 100 vr1+30-r1+400 300 vr1+10-r1+400 300
  an_ask ask6d-right-edge-in-the-strip-and-out-of-it r1-400 100 vr1+30-r1+400 300 320 300
}

brief_lines() {
  python3 -c '
import json, sys
def f(r): return "-" if r is None else " ".join(format(v, "g") for v in r)
def forecast(name, stood, asked, main):
    if stood is None or main is None: return "-"
    bottom, right = main[1] + main[3] - stood[1], main[0] + main[2] - stood[0]
    return {"ask0": "whole", "ask1": "%g high" % bottom, "ask2": "%g high, or %g" % (asked[1], bottom), "ask3": "%g high kept" % stood[3], "ask4": "%g high, or %g kept" % (asked[1], stood[3]), "ask5": "whole", "ask6a": "%g wide" % right,
            "ask6b": "%g wide, or %g" % (asked[0], right), "ask6c": "%g wide kept" % stood[2], "ask6d": "%g wide, or %g kept" % (asked[0], stood[2]), "ask7": "none: kept, or whole"}[name.split("-")[0]]
def ends(name, stood, asked, main, visible):
    # Where the edge asked for would lie in THIS place of the Dock: the same call is not the same geometry once the visible frame has moved.
    if stood is None or main is None: return "-"
    if name.startswith("ask6") or name.endswith("narrower"):
        edge = stood[0] + asked[0]
        return "right edge %g = the visible right %+g, the display%s right %+g" % (edge, edge - visible[0] - visible[2], "\x27s", edge - main[0] - main[2])
    edge = stood[1] + asked[1]
    return "foot %g = the visible bottom %+g, the display%s bottom %+g" % (edge, edge - visible[1] - visible[3], "\x27s", edge - main[1] - main[3])
stood = main = visible = None
for line in sys.stdin:
    try: o = json.loads(line)
    except ValueError:
        print("  " + line.rstrip()); continue
    k = o.get("kind")
    if k == "displays" and o["why"] != "end":
        main, visible = o["displays"][0]["frame"], o["displays"][0]["visible"]
        print("  displays (%s): " % o["why"] + "; ".join("%d: %s visible %s" % (d["n"], f(d["frame"]), f(d["visible"])) for d in o["displays"]))
    elif k == "window":
        print("  window %s of %s (%s, %s) at %s" % (o["window"], o["bundle"], o["role"], o["subrole"], f(o["frame"])))
    elif k == "put":
        stood = o["ax"]
        print("  %-52s stands %s%s" % (o["name"], f(o["ax"]), "" if o["right"] else " (WANTED %s)" % f(o["wanted"])))
    elif k == "hand":
        a = o["later"][-1]["ax"]
        print("  %-52s asked %s, which would end: %s (forecast: %s): at once %s (server %s); %s | foot %s, right edge %s | reports: %s" % ("", f(o["calls"][0]["asked"]), ends(o["name"], stood, o["calls"][0]["asked"], main, visible), forecast(o["name"], stood, o["calls"][0]["asked"], main), f(o["once"]["ax"]), f(o["once"]["ws"]),
            "; ".join("%d ms %s (server %s)" % (l["after"], f(l["ax"]), f(l["ws"])) for l in o["later"]), "-" if a is None else format(a[1] + a[3], "g"), "-" if a is None else format(a[0] + a[2], "g"),
            "; ".join("%s %.1f" % (n[1], n[0]) for n in o["notes"]) or "none"))
'
}

# ask <where the Dock is> <steps>: of the test window, then of TextEdit
ask() {
  thrice "$2" > "$STEPS/now"
  step "the test window, the Dock $1"
  limit 90 "$GROW" "$TEST" "$W1" "test-window.$1" "$STEPS/now" 2>&1 | tee -a "$RESULTS" | brief_lines
  [ -n "$TEXTEDIT" ] || return 0
  step "TextEdit, the Dock $1"
  limit 90 "$GROW" "$TEXTEDIT" "$TEXTEDIT_WINDOW" "textedit.$1" "$STEPS/now" 2>&1 | tee -a "$RESULTS" | brief_lines
}

dock_says() {
  echo "the Dock: orientation $(defaults read com.apple.dock orientation 2>/dev/null || echo "not set"), autohide $(defaults read com.apple.dock autohide 2>/dev/null || echo "not set")"
}
# dock <orientation> <autohide>
dock() {
  defaults write com.apple.dock orientation "$1"
  defaults write com.apple.dock autohide -bool "$2"
  killall Dock
  # launchd starts it again; the apps hear of the new visible frame a moment after it has drawn itself.
  sleep 5
  dock_says
}

step "the Mac"
sw_vers
dock_says
pointer displays
apps_scratch
reopen_test_windows 1
TEST=$ARBOR_WINDOWS_PID
TEXTEDIT=""
if app_open com.apple.TextEdit "$APPS_SCRATCH/oak.txt"; then TEXTEDIT=$APP_PID TEXTEDIT_WINDOW=$APP_WINDOW; else echo "TextEdit: no window to ask"; fi
sleep 3 # the Dock has grown by an icon, and the visible frame with it

echo "the forecasts beside the asks are the asker's, worked out from the stand as it was read and the display as it is: ask1 the foot stops at the display's bottom; ask3 kept; ask5 free; ask6 the same in width; ask2, ask4 and ask7 are open"
ask at-the-bottom below
DOCK_IS_OURS=yes
at_exit '[ -z "$DOCK_IS_OURS" ] || dock bottom false > /dev/null 2>&1'
dock bottom true
ask hidden no_strip_below
dock left false
ask at-the-left no_strip_below
dock right false
ask at-the-right at_the_right
shot dock-at-the-right
dock bottom false
DOCK_IS_OURS=""
[ -z "$TEXTEDIT" ] || app_quit "$TEXTEDIT"

step "done"
echo "$(grep -c '"kind":"hand"' "$RESULTS") asks in shrink.jsonl"
echo "NOT VARIED: one Mac, one macOS; one display, at scale 1; two apps, both AppKit's; windows at rest, of apps in the background; one size call at a time, 0.2 s or a little more after the position call that put the window there."
exit 0
