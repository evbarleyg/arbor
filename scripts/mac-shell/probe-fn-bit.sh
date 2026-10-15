#!/bin/bash
# A key with fn's flag on it passes a hot key by. Does a second registration, with Carbon's fn bit, hear it? A probe (collab/BOARD.md, 0.1; IDEAS I16).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-fn-bit.sh
#
# probe-whose-key.sh showed on a hosted Mac on 2026-10-15: with the flag that a held fn key sets (0x800000) on the key event, ⌃⌥A and six more of Arbor's keys reached the app in
# front, with Arbor running and none the wiser; the arrows, which carry that flag by nature, went to Arbor, and posted without it to the app. So macOS compares the flag when it
# looks for a hot key. On a laptop fn sits beside ⌃.
#
# Part 1 needs no Arbor: a process registers hot keys as Arbor does, in three ways: plainly; with kEventKeyModifierFnMask (1 << 17); both. Each key is then pressed plainly, with fn's flag alone, and
# with an fn key going down before it (and once coming up again before the key does, once going down only after the key has, and once with a repeat of the key after that). Who hears, the press and the release: the plain registration, the one with the bit, the app in front?
# Part 2, with Arbor: ⌃⌥A twenty-five times a second, by one process, through what might make Arbor let go of its keys for a moment. At the first run the hammer made two a second, too
# few to find a hole of less than half a second. A peek (⌃⌥Space held), whose shortcuts come and go, is among it now.
#
# Every key is a posted event. Whether a real fn key puts the flag on a letter's event where macOS looks, no hosted Mac can say.
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "register hot keys, press them into the app in front and listen with event taps"
source "$(dirname "$0")/lib-ears.sh"

# The nine of the second build, and ⌃⌥A.
KEYS="ctrl+opt+a ctrl+opt+return ctrl+opt+space ctrl+opt+[ ctrl+opt+z ctrl+opt+f ctrl+opt+g ctrl+opt+escape ctrl+opt+left ctrl+opt+right"
echo "$KEYS" | tr ' ' '\n' > "$CHORDS"
ears_open

step "0  nobody has registered anything: the control, and what each key is called"
# shellcheck disable=SC2086
press_all control $KEYS
python3 - "$HEARD" > "$CODES" <<'PY'
import sys
chord, seen = None, set()
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    words = line.split()
    if len(words) > 3 and words[1] == "MARK":
        chord = words[3] if words[2] == "control" else None
    elif chord not in (None, "-") and len(words) > 4 and words[1] == "local" and chord not in seen:
        seen.add(chord)
        print(words[3].split("=")[1], words[4].split("=")[1], chord)
PY
check "every key's code is known" test "$(grep -c . "$CODES")" -eq "$(grep -c . "$CHORDS")"
# An F key carries fn's flag by nature, as the arrows do, and so do Home, End, Page Up, Page Down and forward delete. None is Arbor's; they are here for the rule.
printf '%s\n' "96 ctrl+opt ctrl+opt+f5" "115 ctrl+opt ctrl+opt+home" "119 ctrl+opt ctrl+opt+end" "116 ctrl+opt ctrl+opt+pageup" "121 ctrl+opt ctrl+opt+pagedown" \
  "117 ctrl+opt ctrl+opt+forwarddelete" >> "$CODES"
KEYS="$KEYS ctrl+opt+f5 ctrl+opt+home ctrl+opt+end ctrl+opt+pageup ctrl+opt+pagedown ctrl+opt+forwarddelete"

# registered <name> <file of codes>: a process that holds those hot keys; then every key by seven hands; then it goes.
registered() {
  local name=$1 hand mods chord code repeats
  "$EARS" rival "$HEARD" "$2" 9>&- 8>&- &
  RIVAL_PID=$!
  started "$RIVAL_PID"
  check "$name: the process is up" eventually says_in_log "rival ready pid=$RIVAL_PID"
  grep "rival ready pid=$RIVAL_PID" "$HEARD" | cut -c 14-
  for hand in plain:lctrl,lopt fn-flag:fn,lctrl,lopt fn-key:fnkey,lctrl,lopt fn-up-before-the-key:fnfirst,lctrl,lopt pad-flag:pad,lctrl,lopt \
    fn-down-after-the-key:fnlate,lctrl,lopt fn-down-then-a-repeat:fnlate,lctrl,lopt:1; do
    IFS=: read -r hand mods repeats <<< "$hand"
    ROUND="$name.$hand"
    for chord in $KEYS; do
      code=$(awk -v chord="$chord" '$3 == chord { print $1 }' "$CODES")
      front_again
      mark "$chord"
      "$EARS" press "$code" "$mods" hid "${repeats:-0}"
      sleep 0.2
    done
    mark -
  done
  kill_started "$RIVAL_PID"
  RIVAL_PID=""
  sleep 0.3
}
awk '{ print $1, $2, $3 ":plain" }' "$CODES" > "$ARBOR_OUT/codes-plain.txt"
awk '{ print $1, $2 "+fn", $3 ":with-the-bit" }' "$CODES" > "$ARBOR_OUT/codes-bit.txt"
cat "$ARBOR_OUT/codes-plain.txt" "$ARBOR_OUT/codes-bit.txt" > "$ARBOR_OUT/codes-both.txt"
awk '{ print $1, $2 "+fn+exclusive", $3 ":with-the-bit" }' "$CODES" > "$ARBOR_OUT/codes-exclusive.txt"
awk '{ print $1, $2 "+bit23", $3 ":with-the-bit" }' "$CODES" > "$ARBOR_OUT/codes-bit23.txt"
awk '{ print $1, $2 "+bit16", $3 ":with-the-bit" }' "$CODES" > "$ARBOR_OUT/codes-bit16.txt"

step "1  registered plainly, as Arbor does"
registered plainly "$ARBOR_OUT/codes-plain.txt"
step "2  registered with the fn bit only"
registered with-the-bit "$ARBOR_OUT/codes-bit.txt"
step "3  registered both ways"
registered both-ways "$ARBOR_OUT/codes-both.txt"

step "3b  other words for it, in case that bit is not heard: the same bit and exclusive; bit 23, which is the flag's own place; bit 16, Carbon's for Num Lock"
registered bit-17-exclusive "$ARBOR_OUT/codes-exclusive.txt"
registered bit-23 "$ARBOR_OUT/codes-bit23.txt"
registered bit-16 "$ARBOR_OUT/codes-bit16.txt"

step "who heard what, and how often"
python3 - "$HEARD" <<'PY'
import collections, sys
rows, ups, key = collections.OrderedDict(), {}, None
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    words = line.split()
    if len(words) < 3:
        continue
    if words[1] == "MARK":
        key = None
        if "." in words[2] and words[3] != "-" and words[2].split(".")[0] in ("plainly", "with-the-bit", "both-ways", "bit-17-exclusive", "bit-23", "bit-16"):
            key = (words[2], words[3])
            rows[key] = collections.Counter()
            ups[key] = collections.Counter()
    elif key and words[1] == "rival" and words[2] == "pressed":
        rows[key][words[3].rsplit(":", 1)[1]] += 1
    elif key and words[1] == "rival" and words[2] == "released":
        ups[key][words[3].rsplit(":", 1)[1]] += 1
    elif key and words[1] == "local":
        rows[key]["THE-APP"] += 1
sums = collections.OrderedDict()
for (round_, chord), heard in rows.items():
    kind = "an arrow" if chord.endswith(("left", "right")) else "F5, Home and kin" if chord.endswith(("f5", "home", "end", "pageup", "pagedown", "forwarddelete")) else "a letter or sign"
    up = ups[(round_, chord)]
    said = " and ".join(f"{who} x{times}" + (f" (up x{up[who]})" if who != "THE-APP" else "") for who, times in sorted(heard.items())) or "nobody"
    sums.setdefault((round_, kind), collections.Counter())[said] += 1
print(f"{'registered . pressed':40}{'key':18}heard by (how many keys)")
for (round_, kind), counts in sums.items():
    print(f"{round_:40}{kind:18}" + "; ".join(f"{who}: {count}" for who, count in counts.items()))
odd = [(r, c, h) for (r, c), h in rows.items() if sum(h.values()) != 1]
print("heard by none, by more than one, or more than once:" if odd else "each press was heard once, by one")
for round_, chord, heard in odd:
    print(f"  {round_} {chord}: " + (" and ".join(f"{who} x{times}" for who, times in sorted(heard.items())) or "nobody"))
PY

step "4  with Arbor: ⌃⌥A twenty-five times a second through whatever might make it let go"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl arrange
ROUND=holes
mark -
front_again
since=$(wall)
hammer 24
sleep 1
act "$ARBOR_BIN/arborctl" reload-settings
arbor_settings '{"gap": 14}'
act "$ARBOR_BIN/arborctl" reload-settings
act "$ARBOR_BIN/arborctl" set gap 12
act "$ARBOR_BIN/arborctl" set shortcutsFollowLayout false
act "$ARBOR_BIN/arborctl" set shortcutsFollowLayout true
act "$ARBOR_BIN/arborctl" ask-name
act "$ARBOR_BIN/arborctl" ask-name cancel
act "$ARBOR_BIN/arborctl" find
act "$ARBOR_BIN/arborctl" show-all
# A peek: ⌃⌥Space goes down and stays down, Arbor adds shortcuts for as long, and takes them away when it comes up.
act "$ARBOR_POINTER" key ctrl+opt+space --down
act "$ARBOR_POINTER" key ctrl+opt+space --up
act "$ARBOR_BIN/arborctl" hold
act "$ARBOR_BIN/arborctl" release
act "$ARBOR_BIN/arborctl" pause
act "$ARBOR_BIN/arborctl" resume
check "the hammer came to an end" ended "$HAMMER_PID" 200
holes "$since"
echo "how often Arbor registered its shortcuts meanwhile:"
grep -E "registered [0-9]+ shortcuts|peek" "$ARBOR_HOME/arbor.log" | awk -v since="$since" 'substr($1, 12, 12) >= since' | cut -c 12- | sed 's/^/  /' | head -n 30
echo "how often Arbor ran arrange meanwhile: $(grep -c "arrange: " "$ARBOR_HOME/arbor.log")"
ROUND=after-holes
tidy
arbor_stop 01-quit
