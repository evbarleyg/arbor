#!/bin/bash
# A survey for the casts of docs/VIABLE.md: which apps a hosted Mac has besides the stock ones, what each puts up when it is first opened, how its
# windows resist, and whether a second, virtual display can be had there.
#
#   scripts/mac-shell/run.sh scripts/mac-shell/survey-casts.sh          four minutes; Arbor is not built
#
# The questions only a Mac can answer: are Chrome, Firefox and Edge there, and do they open a standard window without an account and without a
# dialog in the way? Which app has a window of fixed size, which a smallest width over half a laptop's screen, which none at all? Is there a Java
# or an Electron app? Does vdisplay.m still work? What comes back: survey.tsv (app, bundle id, windows, what is in the way, limits), and the output.
#
# Only on GitHub's Macs: it opens and quits a dozen apps and plugs in a display.
source "$(dirname "${BASH_SOURCE[0]}")/lib-day.sh"
needs_throwaway_mac "open and quit two dozen real apps, and plug in a virtual display"

apps_watchdog 700
step "the Mac"
echo "macOS $(sw_vers -productVersion) ($(sw_vers -buildVersion)) on $(uname -m)"
day_build_tools
display_mode 1440x900 1600x900 1680x1050 1920x1080
apps_scratch
SURVEY="$ARBOR_OUT/survey.tsv"
printf 'app\tbundle\tstandard windows\tother windows\tin the way\tlimits\n' > "$SURVEY"

step "what is installed"
ls /Applications | sed 's/^/  /'
ls /Applications/Utilities /System/Applications /System/Applications/Utilities 2>/dev/null | tr '\n' ' ' | fold -w 180 | sed 's/^/  /'
echo
echo "Java: $(/usr/libexec/java_home 2>&1 | head -n 1)"

# look <name> <bundle id> [argument for the app…]: opens it, says what it lists, measures its first standard window, quits it.
look() {
  local name=$1 bundle=$2 pid lines standard others way limits="-" tries=0 began code path each known program
  shift 2
  step "$name ($bundle)"
  if app_running "$bundle"; then echo "it runs already"; fi
  # A large app that has never run is looked over by macOS first, which takes longer than any later start. What `open` says and how long it takes is part of the answer.
  began=$SECONDS
  # What is on the screen while `open` waits: a question nobody is there to answer?
  if [ -n "${SURVEY_ONLY:-}" ]; then (sleep 12; snap_now "survey-$name-while-open-waits" > /dev/null) 5<&- 6>&- 8>&- 9>&- & fi
  bounded "${SURVEY_OPEN_LIMIT:-90}" open -g -b "$bundle" ${1:+--args "$@"}
  code=$?
  echo "open -b: exit code $code after $((SECONDS - began)) s"
  if [ "$code" -ne 0 ]; then
    path=$(ls -d /Applications/*.app | while read -r each; do [ "$(defaults read "$each/Contents/Info" CFBundleIdentifier 2>/dev/null)" = "$bundle" ] && echo "$each"; done | head -n 1)
    [ -n "$path" ] || { printf '%s\t%s\tnot there\n' "$name" "$bundle" >> "$SURVEY"; echo "not there"; return; }
    began=$SECONDS
    bounded 90 open -g -a "$path" ${1:+--args "$@"}
    code=$?
    echo "open -a $path: exit code $code after $((SECONDS - began)) s"
    if [ "$code" -ne 0 ]; then
      # Past Launch Services altogether, as whoever drives a browser from a test does: the program inside the bundle.
      program="$path/Contents/MacOS/$(defaults read "$path/Contents/Info" CFBundleExecutable 2>/dev/null)"
      [ -x "$program" ] || { printf '%s\t%s\tdoes not open\n' "$name" "$bundle" >> "$SURVEY"; return; }
      "$program" "$@" > "$ARBOR_OUT/survey-$name.log" 2>&1 5<&- 6>&- 8>&- 9>&- &
      started "$!"
      echo "started $program itself"
    fi
  fi
  until pid=$(apptool pid "$bundle" 2>/dev/null); do
    [ "$tries" -ge 100 ] && { printf '%s\t%s\tdid not start\n' "$name" "$bundle" >> "$SURVEY"; echo "did not start"; return; }
    sleep 0.1
    tries=$((tries + 1))
  done
  apps_remember "$pid"
  lines=$(apptool wait-window "$pid" 20)
  sleep 2
  lines=$(apptool windows "$pid")
  echo "$lines" | sed 's/^/  /'
  standard=$(echo "$lines" | awk '$3 == "AXStandardWindow"' | wc -l | tr -d ' ')
  others=$(echo "$lines" | awk '$1 != 0 && $3 != "AXStandardWindow" { printf "%s ", $3 }')
  way=$(echo "$lines" | grep -Eo "sheets=[0-9]+|AXDialog|AXSystemDialog" | sort -u | tr '\n' ' ')
  if [ -n "$way" ]; then apptool tree "$pid" 6 | grep -E "AXSheet|AXButton|AXDialog" | head -n 14 | sed 's/^/    /'; fi
  if [ "$standard" -gt 0 ]; then limits=$(apptool limits "$(echo "$lines" | awk '$3 == "AXStandardWindow" { print $1; exit }')" 2>&1); echo "  limits: $limits"; fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$bundle" "$standard" "${others:--}" "${way:--}" "$limits" >> "$SURVEY"
  snap_now "survey-$name" > /dev/null
  if [ -n "${SURVEY_ONLY:-}" ] && [ "$standard" -gt 0 ]; then
    # Several windows of one app, as a cast of browsers has: does ⌘N open a second one, and what is it?
    known=$(app_windows "$pid")
    open -b "$bundle"
    sleep 1
    key cmd+n
    if app_await_window "$pid" "$known" 10; then echo "  ⌘N opened:"; apptool windows "$pid" | sed 's/^/    /'; else echo "  ⌘N opened no window"; fi
    echo "  the Window menu: $(apptool menu "$pid" Window 2>&1)"
    echo "  in the Dock: $(apptool dock "$bundle" 2>&1)"
    snap_now "survey-$name-2" > /dev/null
  fi
  app_quit "$pid"
}
# SURVEY_ONLY="chrome firefox": only these (survey-browsers.sh), and more is asked of each.
wanted() { [ -z "${SURVEY_ONLY:-}" ] || case " $SURVEY_ONLY " in *" $1 "*) ;; *) return 1 ;; esac; }

wanted chrome && look chrome com.google.Chrome --no-first-run --no-default-browser-check "file://$APPS_SCRATCH/page.html"
wanted firefox && look firefox org.mozilla.firefox "file://$APPS_SCRATCH/page.html"
wanted edge && look edge com.microsoft.edgemac --no-first-run --no-default-browser-check "file://$APPS_SCRATCH/page.html"
wanted calculator && look calculator com.apple.calculator
wanted activity && look activity com.apple.ActivityMonitor
wanted fontbook && look fontbook com.apple.FontBook
wanted script && look script com.apple.ScriptEditor2
wanted maps && look maps com.apple.Maps
wanted reminders && look reminders com.apple.reminders
wanted music && look music com.apple.Music
wanted photos && look photos com.apple.Photos
wanted books && look books com.apple.iBooksX
wanted stocks && look stocks com.apple.stocks
wanted freeform && look freeform com.apple.freeform
wanted console && look console com.apple.Console
wanted diskutility && look diskutility com.apple.DiskUtility
wanted keychain && look keychain com.apple.keychainaccess
wanted quicktime && look quicktime com.apple.QuickTimePlayerX
wanted dictionary && look dictionary com.apple.Dictionary
wanted stickies && look stickies com.apple.Stickies
wanted simulator && look simulator com.apple.iphonesimulator
wanted vscode && look vscode com.microsoft.VSCode

step "a Java app"
if java=$(/usr/libexec/java_home 2>/dev/null) && [ -x "$java/bin/jconsole" ]; then
  "$java/bin/jconsole" > /dev/null 2>&1 5<&- 6>&- 8>&- 9>&- &
  JAVA_PID=$!
  started "$JAVA_PID"
  sleep 8
  apptool windows "$JAVA_PID" | sed 's/^/  /'
  apptool apps | grep -i "java\|jconsole" | sed 's/^/  /'
  # What a click in the Dock would have to look for: the names of apps, which are nobody's secret.
  echo "  the Dock's apps: $(apptool tree "$(apptool pid com.apple.dock)" 3 | grep AXApplicationDockItem | grep -o '"[^"]*"' | tr '\n' ' ')"
  snap_now survey-jconsole > /dev/null
  kill_started "$JAVA_PID"
else
  echo "no jconsole"
fi

if [ -n "${SURVEY_ONLY:-}" ]; then
  step "the survey"
  column -t -s "$(printf '\t')" "$SURVEY"
  exit 0
fi

step "a second display"
clang -fobjc-arc -O1 -framework Foundation -framework ApplicationServices -framework CoreGraphics -framework ColorSync \
  "$ARBOR_ROOT/scripts/mac-shell/vdisplay.m" -o "$ARBOR_VDISPLAY" > "$ARBOR_OUT/build-vdisplay.log" 2>&1 || cat "$ARBOR_OUT/build-vdisplay.log"
echo "before: $(pointer displays | tr '\n' ';')"
display_add 1920 1080 right
echo "plugged in to the right: $(pointer displays | tr '\n' ';')"
display_move left
echo "moved to the left: $(pointer displays | tr '\n' ';')"
display_remove
sleep 2
echo "unplugged: $(pointer displays | tr '\n' ';')"

step "the survey"
column -t -s "$(printf '\t')" "$SURVEY" | cut -c 1-220
