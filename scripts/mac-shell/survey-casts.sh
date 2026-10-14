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
  local name=$1 bundle=$2 pid lines standard others way limits="-" tries=0
  shift 2
  step "$name ($bundle)"
  if app_running "$bundle"; then echo "it runs already"; fi
  if [ $# -gt 0 ]; then
    bounded 20 open -g -b "$bundle" --args "$@" || { printf '%s\t%s\tnot there\n' "$name" "$bundle" >> "$SURVEY"; echo "not there"; return; }
  else
    bounded 20 open -g -b "$bundle" || { printf '%s\t%s\tnot there\n' "$name" "$bundle" >> "$SURVEY"; echo "not there"; return; }
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
  app_quit "$pid"
}

look chrome com.google.Chrome --no-first-run --no-default-browser-check "file://$APPS_SCRATCH/page.html"
look firefox org.mozilla.firefox "file://$APPS_SCRATCH/page.html"
look edge com.microsoft.edgemac --no-first-run --no-default-browser-check "file://$APPS_SCRATCH/page.html"
look calculator com.apple.calculator
look activity com.apple.ActivityMonitor
look fontbook com.apple.FontBook
look script com.apple.ScriptEditor2
look maps com.apple.Maps
look reminders com.apple.reminders
look music com.apple.Music
look photos com.apple.Photos
look books com.apple.iBooksX
look stocks com.apple.stocks
look freeform com.apple.freeform
look console com.apple.Console
look diskutility com.apple.DiskUtility
look keychain com.apple.keychainaccess
look quicktime com.apple.QuickTimePlayerX
look dictionary com.apple.Dictionary
look stickies com.apple.Stickies
look simulator com.apple.iphonesimulator
look vscode com.microsoft.VSCode

step "a Java app"
if java=$(/usr/libexec/java_home 2>/dev/null) && [ -x "$java/bin/jconsole" ]; then
  "$java/bin/jconsole" > /dev/null 2>&1 5<&- 6>&- 8>&- 9>&- &
  JAVA_PID=$!
  started "$JAVA_PID"
  sleep 8
  apptool windows "$JAVA_PID" | sed 's/^/  /'
  apptool apps | grep -i "java\|jconsole" | sed 's/^/  /'
  snap_now survey-jconsole > /dev/null
  kill_started "$JAVA_PID"
else
  echo "no jconsole"
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
