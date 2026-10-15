#!/bin/bash
# Can a key that Arbor shows as its own ever arrive elsewhere, and does Arbor know when it does not hold it? A probe (collab/BOARD.md, 0.1; IDEAS I16).
#
#   scripts/mac-shell/run.sh scripts/mac-shell/probe-whose-key.sh
#
# On a tester's Mac ⌃⌥A, which is `arrange`, reached the app in front, twice, and did that app's own ⌃⌥A. Three guesses: the key was never registered; it was let go of
# meanwhile; the app listens below the point where macOS takes a hot key away. This asks a Mac, with ears of every kind:
#
#   in the app in front      local    a local monitor: whatever the app is given at all
#                            equiv    its view is asked whether the key is an equivalent of its own
#                            menu     a menu item with that key equivalent fires
#                            view     keyDown in the first responder
#   in the background        global   a global monitor: what some OTHER app was given
#                            tap-hid, tap-session, tap-annotated    listen-only event taps at the three points macOS offers, from the keyboard inwards
#   on demand                rival    another process that has registered the SAME Carbon hot keys, as an Electron app's globalShortcut does
#
# And with hands of more than one kind: an ordinary press is left ⌃, left ⌥ and the key, put in at the keyboard's end. Here also the right-hand keys, a mix, both of each pair, Caps Lock on,
# fn held, flags without any modifier key going down, a key held until it repeats; and the same key put in at the two points further in, and posted to the app itself, which
# is how tools that remap keys or play macros may post.
#
# It takes the keys from `arborctl bindings`, presses each with the app in front, and prints which ears heard it and whether Arbor's log grew. Rounds: no Arbor (the
# control: every ear has to hear); from the moment of launch; running; paused; shortcuts off for the app; secure input on; Arbor stopped (a main thread that is
# busy); a rival registered after Arbor, and before it; the display asleep and awake again; Arbor killed. Then ⌃⌥A a dozen times a second through everything that might make
# Arbor let go of its keys for a moment (a reload, `set`, a panel, a hold, a pause, a switch of apps). And Arbor as a bundle that answers for its own permission: in the
# menu bar without it; granted; and replaced by a build with another hash, signed ad hoc, as `make install` leaves it where there is no signing identity.
# Not tried: real sleep and wake (a hosted Mac may not come back from it), the watchdog's restart (watchdog-bundle.sh), a finger on a real keyboard: every key here is a posted event.
#
# Only on GitHub's Macs: it presses some fifty shortcuts a dozen times over, into whatever is in front, and installs event taps that listen.
ARBOR_TIME_LIMIT=1500
source "$(dirname "$0")/lib.sh"
needs_throwaway_mac "press every shortcut into the app in front, with and without Arbor, and listen with event taps"

EARS="$ARBOR_ROOT/.build/mac-shell/ears"
EARS_APP="$ARBOR_ROOT/.build/mac-shell/ArborEars.app"
EARS_ID=dev.arbor.test.ears
HEARD="$ARBOR_OUT/ears.log"
CHORDS="$ARBOR_OUT/chords.txt"
CODES="$ARBOR_OUT/codes.txt"
FRONT_PID=""
BACK_PID=""
RIVAL_PID=""
ROUND=""

arbor_build
cat > "$ARBOR_OUT/ears.swift" <<'SWIFT'
import AppKit
import Carbon.HIToolbox

let arguments = Array(CommandLine.arguments.dropFirst())
func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("ears: \(message)\n".utf8))
  exit(64)
}
guard let command = arguments.first else { fail("front | back | rival | frontmost | press") }
if command == "frontmost" {
  print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0)
  exit(0)
}
if command == "press" {
  // press <key code> <modifier keys, comma-separated> <road> [repeats]
  //   modifier keys  lctrl rctrl lopt ropt: the key goes down, with the bit that says which hand. ctrl opt: the flag alone, no key and no hand, as many tools post.
  //                  caps fn pad: the flag alone (a Caps Lock really pressed would stay on)
  //   road           hid | session | annotated: the point at which the events are put in, from the keyboard inwards; or a process id, for postToPid
  guard arguments.count > 3, let code = CGKeyCode(arguments[1]) else { fail("press <code> <modifiers> <road> [repeats]") }
  let keys: [String: (code: CGKeyCode?, flags: UInt64)] = [
    "lctrl": (59, 0x40001), "rctrl": (62, 0x42000), "lopt": (58, 0x80020), "ropt": (61, 0x80040),
    "ctrl": (nil, 0x40000), "opt": (nil, 0x80000), "caps": (nil, 0x10000), "fn": (nil, 0x800000), "pad": (nil, 0x200000),
  ]
  let source = CGEventSource(stateID: .hidSystemState)
  func post(_ code: CGKeyCode, _ down: Bool, _ flags: UInt64, repeating: Bool = false) {
    guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { fail("no event") }
    event.flags = CGEventFlags(rawValue: flags | 0x100)
    if repeating { event.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
    switch arguments[3] {
    case "hid": event.post(tap: .cghidEventTap)
    case "session": event.post(tap: .cgSessionEventTap)
    case "annotated": event.post(tap: .cgAnnotatedSessionEventTap)
    default:
      guard let pid = pid_t(arguments[3]) else { fail("hid, session, annotated or a process id") }
      event.postToPid(pid)
    }
    usleep(8000)
  }
  var flags: UInt64 = 0
  var down: [(CGKeyCode, UInt64)] = []
  for word in arguments[2].split(separator: ",").map(String.init) {
    guard let key = keys[word] else { fail("no modifier \(word)") }
    flags |= key.flags
    if let code = key.code {
      post(code, true, flags)
      down.append((code, key.flags))
    }
  }
  post(code, true, flags)
  for _ in 0..<(arguments.count > 4 ? Int(arguments[4]) ?? 0 : 0) {
    usleep(30000)
    post(code, true, flags, repeating: true)
  }
  usleep(40000)
  post(code, false, flags)
  for (code, mine) in down.reversed() {
    // Two keys of a pair share the flag that names the pair: it goes with the last of them.
    flags &= ~(mine & 0xFFFF)
    if !down.contains(where: { $0.0 != code && $0.1 & 0xFF0000 == mine & 0xFF0000 && flags & ($0.1 & 0xFFFF) != 0 }) { flags &= ~(mine & 0xFF0000) }
    post(code, false, flags)
  }
  exit(0)
}
guard arguments.count > 1 else { fail("expected a log") }
// Several processes and the script write to one file, a whole line at a time.
let log = open(arguments[1], O_WRONLY | O_APPEND | O_CREAT, 0o644)
let formatter = DateFormatter()
formatter.dateFormat = "HH:mm:ss.SSS"
formatter.timeZone = TimeZone(identifier: "UTC")
func note(_ line: String) {
  let bytes = Array("\(formatter.string(from: Date())) \(line)\n".utf8)
  _ = write(log, bytes, bytes.count)
}
func names(_ flags: NSEvent.ModifierFlags) -> String {
  var words: [String] = []
  if flags.contains(.control) { words.append("ctrl") }
  if flags.contains(.option) { words.append("opt") }
  if flags.contains(.shift) { words.append("shift") }
  if flags.contains(.command) { words.append("cmd") }
  return words.isEmpty ? "none" : words.joined(separator: "+")
}
func lines(_ path: String) -> [String] {
  ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "").split(separator: "\n").map(String.init)
}
var sources: [DispatchSourceSignal] = []
func on(_ number: Int32, _ action: @escaping () -> Void) {
  signal(number, SIG_IGN)
  let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
  source.setEventHandler(handler: action)
  source.resume()
  sources.append(source)
}

final class Listener: NSView {
  override var acceptsFirstResponder: Bool { true }
  override func keyDown(with event: NSEvent) { note("view down code=\(event.keyCode) mods=\(names(event.modifierFlags))") }
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    note("equiv down code=\(event.keyCode) mods=\(names(event.modifierFlags))")
    return false
  }
}

final class Front: NSObject, NSApplicationDelegate {
  var window: NSWindow?
  var secure = false
  @objc func fired(_ item: NSMenuItem) { note("menu fired \(item.title)") }
  func applicationDidFinishLaunching(_ notification: Notification) {
    let numbers = arguments[2...5].compactMap(Double.init)
    let height = NSScreen.screens.first?.frame.height ?? 768
    let rect = NSRect(x: numbers[0], y: height - numbers[1] - numbers[3], width: numbers[2], height: numbers[3])
    let window = NSWindow(contentRect: rect, styleMask: [.titled], backing: .buffered, defer: false)
    window.title = "Ears"
    // Whatever Arbor does with the windows it arranges, this one is not covered.
    window.level = .floating
    let view = Listener(frame: rect)
    window.contentView = view
    window.setFrame(rect, display: true)
    window.makeKeyAndOrderFront(nil)
    window.makeFirstResponder(view)
    self.window = window

    let special: [String: String] = [
      "left": "\u{F702}", "right": "\u{F703}", "up": "\u{F700}", "down": "\u{F701}", "return": "\r", "escape": "\u{1B}", "space": " ",
    ]
    let bar = NSMenu()
    let first = NSMenuItem()
    first.submenu = NSMenu(title: "Ears")
    bar.addItem(first)
    let holder = NSMenuItem()
    let menu = NSMenu(title: "Keys")
    holder.submenu = menu
    bar.addItem(holder)
    for chord in lines(arguments[6]) {
      let words = chord.split(separator: "+").map(String.init)
      guard let key = words.last else { continue }
      let item = NSMenuItem(title: chord, action: #selector(fired(_:)), keyEquivalent: special[key] ?? key)
      var mask: NSEvent.ModifierFlags = []
      if words.contains("ctrl") { mask.insert(.control) }
      if words.contains("opt") { mask.insert(.option) }
      if words.contains("shift") { mask.insert(.shift) }
      if words.contains("cmd") { mask.insert(.command) }
      item.keyEquivalentModifierMask = mask
      item.target = self
      menu.addItem(item)
    }
    NSApp.mainMenu = bar
    NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { event in
      note("local down code=\(event.keyCode) mods=\(names(event.modifierFlags)) repeat=\(event.isARepeat) flags=\(String(event.modifierFlags.rawValue, radix: 16))")
      return event
    }
    on(SIGUSR1) { NSApp.activate(ignoringOtherApps: true) }
    on(SIGUSR2) { [weak self] in
      guard let self else { return }
      self.secure.toggle()
      let status = self.secure ? EnableSecureEventInput() : DisableSecureEventInput()
      note("front secure input \(self.secure ? "on" : "off") (status \(status), IsSecureEventInputEnabled \(IsSecureEventInputEnabled()))")
    }
    NSApp.activate(ignoringOtherApps: true)
    note("front ready pid=\(getpid())")
  }
  func applicationDidBecomeActive(_ notification: Notification) { note("front active") }
  func applicationDidResignActive(_ notification: Notification) { note("front resigned") }
}

let points: [(String, CGEventTapLocation)] = [
  ("tap-hid", .cghidEventTap), ("tap-session", .cgSessionEventTap), ("tap-annotated", .cgAnnotatedSessionEventTap),
]
func heard(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ which: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
  let name = points[Int(bitPattern: which)].0
  if type == .keyDown {
    let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue))
    note("\(name) down code=\(event.getIntegerValueField(.keyboardEventKeycode)) mods=\(names(flags)) flags=\(String(event.flags.rawValue, radix: 16))")
  } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
    note("\(name) was switched off by macOS (\(type.rawValue))")
  }
  return Unmanaged.passUnretained(event)
}

var chordOfRival: [UInt32: String] = [:]
func rivalHeard(_ next: EventHandlerCallRef?, _ event: EventRef?, _ data: UnsafeMutableRawPointer?) -> OSStatus {
  guard let event else { return OSStatus(eventNotHandledErr) }
  var id = EventHotKeyID()
  GetEventParameter(
    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
  note("rival pressed \(chordOfRival[id.id] ?? "?")")
  return noErr
}

let application = NSApplication.shared
switch command {
case "front":
  guard arguments.count > 6 else { fail("front <log> <x> <y> <w> <h> <file of chords>") }
  let delegate = Front()
  application.delegate = delegate
  application.setActivationPolicy(.regular)
  withExtendedLifetime(delegate) { application.run() }

case "back":
  application.setActivationPolicy(.accessory)
  let monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { event in
    note("global down code=\(event.keyCode) mods=\(names(event.modifierFlags))")
  }
  note("back global monitor \(monitor == nil ? "refused" : "in")")
  for (index, point) in points.enumerated() {
    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    if let tap = CGEvent.tapCreate(
      tap: point.1, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: mask, callback: heard,
      userInfo: UnsafeMutableRawPointer(bitPattern: index))
    {
      CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
      note("back \(point.0) in")
    } else {
      note("back \(point.0) refused")
    }
  }
  note("back ready pid=\(getpid())")
  application.run()

case "rival":
  guard arguments.count > 2 else { fail("rival <log> <file of codes>") }
  application.setActivationPolicy(.accessory)
  var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
  InstallEventHandler(GetEventDispatcherTarget(), rivalHeard, 1, &spec, nil, nil)
  var taken = 0
  var refused: [String] = []
  var refs: [EventHotKeyRef] = []
  for (index, line) in lines(arguments[2]).enumerated() {
    let words = line.split(separator: " ").map(String.init)
    guard words.count == 3, let code = UInt32(words[0]) else { continue }
    var flags = 0
    if words[1].contains("ctrl") { flags |= controlKey }
    if words[1].contains("opt") { flags |= optionKey }
    if words[1].contains("shift") { flags |= shiftKey }
    if words[1].contains("cmd") { flags |= cmdKey }
    var ref: EventHotKeyRef?
    let id = UInt32(index + 1)
    let status = RegisterEventHotKey(code, UInt32(flags), EventHotKeyID(signature: 0x5249_5641, id: id), GetEventDispatcherTarget(), 0, &ref)
    if status == noErr, let ref {
      taken += 1
      refs.append(ref)
      chordOfRival[id] = words[2]
    } else {
      refused.append("\(words[2]) (\(status))")
    }
  }
  note("rival ready pid=\(getpid()): registered \(taken), refused \(refused.count) \(refused.joined(separator: ", "))")
  application.run()

default:
  fail("unknown command \(command)")
}
SWIFT
swiftc -O -swift-version 5 "$ARBOR_OUT/ears.swift" -o "$EARS" > "$ARBOR_OUT/build-ears.log" 2>&1 || {
  cat "$ARBOR_OUT/build-ears.log"
  die "the ears did not compile"
}
rm -rf "$EARS_APP"
mkdir -p "$EARS_APP/Contents/MacOS"
cp "$EARS" "$EARS_APP/Contents/MacOS/ears"
cat > "$EARS_APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>$EARS_ID</string>
  <key>CFBundleExecutable</key><string>ears</string>
  <key>CFBundleName</key><string>ArborEars</string>
  <key>CFBundlePackageType</key><string>APPL</string>
</dict></plist>
PLIST
at_exit 'kill_started $FRONT_PID $BACK_PID $RIVAL_PID; rm -rf "$EARS_APP"'

# MARK: Words

says_in_log() { grep -q "$1" "$HEARD" 2>/dev/null; }
arbor_lines() { if [ -f "$ARBOR_HOME/arbor.log" ]; then wc -l < "$ARBOR_HOME/arbor.log" | tr -d ' '; else echo 0; fi; }
# What follows in the file, up to the next mark, was heard after this press. "-" is for keys the script presses to tidy up.
wall() { perl -MPOSIX -MTime::HiRes=time -e '$t = time; printf "%s.%03d", strftime("%H:%M:%S", gmtime($t)), ($t - int($t)) * 1000'; }
mark() { echo "$(wall) MARK $ROUND $1 arbor=$(arbor_lines)" >> "$HEARD"; }
# act <words…>: something is done to Arbor while the hammer goes, and when is written down beside what the ears hear.
act() {
  echo "$(wall) ACT $*" >> "$HEARD"
  "$@" > /dev/null 2>&1
  sleep 1.2
}
# holes <since>: every ⌃⌥A that some app was given, with what had been done last before it.
holes() {
  python3 - "$HEARD" "$1" <<'PY'
import sys
heard, since = sys.argv[1:3]
last, found, presses, acts = "nothing yet", [], 0, 0
for line in open(heard, encoding="utf-8", errors="replace"):
    words = line.split()
    if len(words) < 3 or words[0] < since:
        continue
    if words[1] == "ACT":
        last, acts = f"{words[0]} {' '.join(words[2:])}", acts + 1
    elif words[1] == "tap-hid" and "code=0" in words:
        presses += 1
    elif words[1] in ("local", "global") and "code=0" in words:
        found.append((words[0], words[1], last))
print(f"{presses} presses of ⌃⌥A were seen at the keyboard's end, through {acts} acts; {len(found)} were given to an app")
for when, ear, after in found[:60]:
    print(f"  {when} {ear:6} after: {after}")
PY
}
in_front() { [ "$("$EARS" frontmost)" = "$FRONT_PID" ]; }
front_again() {
  in_front && return 0
  kill -USR1 "$FRONT_PID"
  eventually in_front && return 0
  "$ARBOR_POINTER" click "$FRONT_X" "$FRONT_Y"
  eventually in_front
}
# Arbor's own panels take the keyboard, or lie over the app: away with them before the next key.
tidy() {
  [ -n "$ARBOR_PID" ] || return 0
  local levels
  levels=" $(overlays | awk '$8 == "on" { print $3 }' | sort -u | tr '\n' ' ')"
  case "$levels" in
    *" 8 "* | *" 5 "*)
      mark -
      "$ARBOR_POINTER" key escape
      sleep 0.2 ;;
  esac
  case "$levels" in
    *" 3 "*)
      mark -
      "$ARBOR_POINTER" key cmd+w
      sleep 0.3 ;;
  esac
}
# press_all <round> <chord…>
press_all() {
  local chord missed=0
  ROUND=$1
  shift
  for chord in "$@"; do
    front_again || missed=$((missed + 1))
    mark "$chord"
    "$ARBOR_POINTER" key "$chord"
    sleep 0.25
    tidy
  done
  mark -
  [ "$missed" -eq 0 ] || echo "NOTE: $missed times the app could not be brought to the front before a press"
  table "$ROUND"
}
# table <round>: who heard what. The whole of it goes into a file; here, the sums, and every key that went another way than most.
table() {
  python3 - "$HEARD" "$1" "$ARBOR_OUT/table-$1.txt" <<'PY'
import collections, re, sys
heard, wanted, out = sys.argv[1:4]
EARS = ["local", "equiv", "menu", "view", "global", "tap-hid", "tap-session", "tap-annotated", "rival"]
rows, chord, lines_before = [], None, 0
for line in open(heard, encoding="utf-8", errors="replace"):
    words = line.split()
    if len(words) < 3:
        continue
    if words[1] == "MARK":
        now = int(words[4].split("=")[1])
        if chord not in (None, "-"):
            rows[-1][2] = now - lines_before
        chord = words[3] if words[2] == wanted else None
        lines_before = now
        if chord not in (None, "-"):
            rows.append([chord, collections.Counter(), 0])
    elif chord not in (None, "-") and words[1] in EARS:
        rows[-1][1][words[1]] += 1
with open(out, "w", encoding="utf-8") as f:
    f.write(f"{'key':22}" + "".join(f"{e:>14}" for e in EARS) + f"{'Arbor log':>11}\n")
    for chord, ears, grew in rows:
        f.write(f"{chord:22}" + "".join(f"{ears[e] or '.':>14}" for e in EARS) + f"{grew or '.':>11}\n")
kinds = collections.defaultdict(list)
for chord, ears, grew in rows:
    kinds[(tuple(e for e in EARS if ears[e]), "Arbor's log grew" if grew else "Arbor's log did not grow")].append(chord)
print(f"round {wanted}: {len(rows)} keys")
for (ears, arbor), chords in sorted(kinds.items(), key=lambda item: -len(item[1])):
    print(f"  {len(chords):3} heard by [{' '.join(ears) or 'nobody'}]; {arbor}" + (": " + " ".join(chords) if len(chords) <= 12 else ""))
reached = [chord for chord, ears, grew in rows if ears["local"] or ears["global"]]
print(f"  REACHED AN APP: {len(reached)} of {len(rows)}" + (": " + " ".join(reached) if 0 < len(reached) <= 60 and len(reached) < len(rows) else ""))
PY
}
# odd_hands <state>: the few keys again, by hands and by roads that a script's ordinary press does not take. One line each: how many of the keys an app was given, and
# at how many Arbor's log grew.
HANDS="left:lctrl,lopt:hid right:rctrl,ropt:hid left-ctrl-right-opt:lctrl,ropt:hid right-ctrl-left-opt:rctrl,lopt:hid both-of-each:lctrl,rctrl,lopt,ropt:hid
  caps-lock-on:caps,lctrl,lopt:hid fn-held:fn,lctrl,lopt:hid pad-flag:pad,lctrl,lopt:hid flags-and-no-keys:ctrl,opt:hid held-to-repeat:lctrl,lopt:hid:4
  put-in-at-the-session:lctrl,lopt:session put-in-at-the-annotated-session:lctrl,lopt:annotated posted-to-the-app:lctrl,lopt:pid"
odd_hands() {
  local state=$1 hand name mods road repeats chord code
  for hand in $HANDS; do
    IFS=: read -r name mods road repeats <<< "$hand"
    [ "$road" = pid ] && road=$FRONT_PID
    ROUND="$state.$name"
    for chord in $FEW; do
      code=$(awk -v chord="$chord" '$3 == chord { print $1 }' "$CODES")
      front_again
      mark "$chord"
      "$EARS" press "$code" "$mods" "$road" ${repeats:+"$repeats"}
      sleep 0.25
      tidy
    done
    mark -
  done
  python3 - "$HEARD" "$state" <<'PY'
import collections, sys
heard, state = sys.argv[1:3]
order, rows, key, before = [], collections.defaultdict(lambda: [0, 0, 0, 0, set()]), None, 0
for line in open(heard, encoding="utf-8", errors="replace"):
    words = line.split()
    if len(words) < 3:
        continue
    if words[1] == "MARK":
        now = int(words[4].split("=")[1])
        if key:
            rows[key[0]][2] += now > before
            rows[key[0]][1] += key[2]
            rows[key[0]][3] += key[3]
        before, key = now, None
        if words[2].startswith(state + ".") and words[3] != "-":
            name = words[2][len(state) + 1:]
            if name not in order:
                order.append(name)
            rows[name][0] += 1
            key = [name, words[3], False, False]
    elif key and words[1] in ("local", "global"):
        key[2] = True
        rows[key[0]][4].update(word for word in words if word.startswith("flags="))
    elif key and words[1] == "tap-hid":
        key[3] = True
print(f"{state}: {'hand or road':34}{'keys':>5}{'seen at the keyboard end':>26}{'given to an app':>17}{'Arbor log grew':>16}   flags the app saw")
for name in order:
    keys, app, arbor, hid, flags = rows[name]
    print(f"{'':{len(state) + 2}}{name:34}{keys:>5}{hid:>26}{app:>17}{arbor:>16}   {' '.join(sorted(flags))[:60]}")
PY
}
what_arbor_says() {
  echo "what Arbor says of itself:"
  "$ARBOR_BIN/arborctl" status 2>&1 | head -n 2 | sed 's/^/  status | /'
  echo "  bindings | $("$ARBOR_BIN/arborctl" bindings 2>&1 | grep -c "→") lines with a key; the last: $("$ARBOR_BIN/arborctl" bindings 2>&1 | tail -n 1)"
  grep -E "registered [0-9]+ shortcuts|could not register|not registered" "$ARBOR_HOME/arbor.log" | tail -n 2 | cut -c 12- | sed 's/^/  log | /'
}
# hammer <seconds>: ⌃⌥A as fast as the tool goes, in the background: about a dozen a second.
hammer() {
  local until=$((SECONDS + $1))
  (while [ "$SECONDS" -lt "$until" ]; do "$ARBOR_POINTER" key ctrl+opt+a; done) 9>&- 8>&- &
  HAMMER_PID=$!
}
# timeline <since HH:MM:SS>: every ⌃⌥A (key code 0) that some app was given, beside what Arbor's log says of shortcuts and of `arrange`.
timeline() {
  echo "given to an app (local or global), key code 0:"
  awk -v since="$1" '$1 >= since && ($2 == "local" || $2 == "global") && /code=0 / { print "  " $1, $2 }' "$HEARD" | sed -n '1,4p;$p'
  echo "  in all: $(awk -v since="$1" '$1 >= since && ($2 == "local" || $2 == "global") && /code=0 /' "$HEARD" | grep -c .); seen by the tap at the keyboard: $(awk -v since="$1" '$1 >= since && $2 == "tap-hid" && /code=0 /' "$HEARD" | grep -c .)"
  echo "Arbor's log:"
  grep -E "registered [0-9]+ shortcuts|started:|arrange" "$ARBOR_HOME/arbor.log" | cut -c 12- | sed -n '1,6p' | sed 's/^/  /'
}

# MARK: The ears

step "the keys: Arbor's own list"
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
"$ARBOR_BIN/arborctl" bindings | awk '/→/ { print $1 }' > "$CHORDS"
echo "$(grep -c . "$CHORDS") keys"
arbor_stop 00-listed
# ⌃⌥⎋ pauses and resumes, so it gets rounds of its own.
ALL=$(grep -v "^ctrl+opt+escape$" "$CHORDS" | tr '\n' ' ')
# The nine of the second build, less ⌃⌥⎋, and ⌃⌥A.
FEW="ctrl+opt+a ctrl+opt+left ctrl+opt+right ctrl+opt+return ctrl+opt+space ctrl+opt+[ ctrl+opt+z ctrl+opt+f ctrl+opt+g"

step "the app in front and the listener in the background"
read -r _ dx dy dw dh _ <<< "$(pointer displays | head -n 1)"
FRONT_X=$((dx + dw / 2))
FRONT_Y=$((dy + dh - 200))
: > "$HEARD"
"$EARS_APP/Contents/MacOS/ears" front "$HEARD" $((FRONT_X - 130)) $((FRONT_Y - 60)) 260 120 "$CHORDS" 9>&- 8>&- &
FRONT_PID=$!
started "$FRONT_PID"
"$EARS" back "$HEARD" 9>&- 8>&- &
BACK_PID=$!
started "$BACK_PID"
check "the app is up" eventually says_in_log "front ready"
check "the listener is up" eventually says_in_log "back ready"
grep " back " "$HEARD" | cut -c 14- | sed 's/^/  /'

step "0  no Arbor: the control. Every key has to reach the app"
# shellcheck disable=SC2086
press_all control $ALL ctrl+opt+escape
# What each key is called further in: its code and modifiers, as the app was given them.
python3 - "$HEARD" > "$CODES" <<'PY'
import sys
chord = None
seen = set()
for line in open(sys.argv[1], encoding="utf-8", errors="replace"):
    words = line.split()
    if len(words) > 3 and words[1] == "MARK":
        chord = words[3] if words[2] == "control" else None
    elif chord not in (None, "-") and len(words) > 4 and words[1] == "local" and chord not in seen:
        seen.add(chord)
        print(words[3].split("=")[1], words[4].split("=")[1], chord)
PY
check "every key's code is known" test "$(grep -c . "$CODES")" -eq "$(grep -c . "$CHORDS")"
shot 01-control

step "0b  no Arbor, odd hands and odd roads: the control. Each has to reach the app"
odd_hands control

step "1  from the moment of launch: how long is ⌃⌥A not Arbor's?"
ROUND=launch
mark -
since=$(wall)
hammer 8
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
check "the hammer came to an end" ended "$HAMMER_PID" 150
echo "Arbor was started at or after $since"
timeline "$since"

step "2  running"
ctl arrange
sleep 1
what_arbor_says
# shellcheck disable=SC2086
press_all running $ALL
shot 02-running
ROUND=running-pause-key
front_again
press_all pause-key ctrl+opt+escape
"$ARBOR_BIN/arborctl" status | head -n 1
press_all resume-key ctrl+opt+escape
"$ARBOR_BIN/arborctl" status | head -n 1

step "2a  running, odd hands and odd roads: the right-hand keys, both of a pair, Caps Lock, fn; and keys put in further in than the keyboard"
odd_hands running
ctl show-all

step "2b  is there a moment at which Arbor lets go? ⌃⌥A a dozen times a second through whatever might register shortcuts anew"
ROUND=holes
mark -
front_again
since=$(wall)
hammer 34
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
act "$ARBOR_BIN/arborctl" show-shortcuts
act "$ARBOR_BIN/arborctl" show-all
act "$ARBOR_BIN/arborctl" minimap
act "$ARBOR_BIN/arborctl" minimap
act "$ARBOR_BIN/arborctl" hold
act "$ARBOR_BIN/arborctl" release
# shellcheck disable=SC2046
act "$ARBOR_POINTER" click $(center_of "$W1")
act kill -USR1 "$FRONT_PID"
act "$ARBOR_BIN/arborctl" pass-through "$EARS_ID" on
act "$ARBOR_BIN/arborctl" pass-through "$EARS_ID" off
act "$ARBOR_BIN/arborctl" pause
act "$ARBOR_BIN/arborctl" resume
check "the hammer came to an end" ended "$HAMMER_PID" 200
holes "$since"
echo "how often Arbor registered its shortcuts meanwhile:"
grep -E "registered [0-9]+ shortcuts" "$ARBOR_HOME/arbor.log" | awk -v since="$since" 'substr($1, 12, 12) >= since' | cut -c 12- | sed 's/^/  /' | head -n 30
ROUND=after-holes
tidy
ctl show-all

step "3  paused"
ctl pause
what_arbor_says
# shellcheck disable=SC2086
press_all paused $ALL
ctl resume

step "4  shortcuts off for the app in front"
ctl pass-through "$EARS_ID" on
front_again
sleep 0.5
what_arbor_says
# shellcheck disable=SC2086
press_all off-for-the-app $ALL
ctl pass-through "$EARS_ID" off
sleep 0.5

step "5  secure input on, as with a password field"
front_again
kill -USR2 "$FRONT_PID"
sleep 0.5
grep "secure input" "$HEARD" | tail -n 1 | cut -c 14-
ioreg -l -w 0 | grep -o "kCGSSessionSecureInputPID[^,]*" | head -n 1
what_arbor_says
# shellcheck disable=SC2086
press_all secure-input $ALL
kill -USR2 "$FRONT_PID"
sleep 0.5
grep "secure input" "$HEARD" | tail -n 1 | cut -c 14-

step "6  Arbor stopped in its tracks: a main thread that is busy"
kill -STOP "$ARBOR_PID"
saved_pid=$ARBOR_PID
# Nothing can be asked of it meanwhile.
ARBOR_PID=""
# shellcheck disable=SC2086
press_all stopped $FEW
ARBOR_PID=$saved_pid
before=$(arbor_lines)
kill -CONT "$ARBOR_PID"
sleep 2
echo "going again, Arbor's log grew by $(($(arbor_lines) - before)) lines:"
tail -n "+$((before + 1))" "$ARBOR_HOME/arbor.log" | grep " INFO " | cut -c 12- | head -n 12 | sed 's/^/  /'
ROUND=after-stopped
tidy
ctl show-all

step "7  a rival registers the same hot keys AFTER Arbor"
"$EARS" rival "$HEARD" "$CODES" 9>&- 8>&- &
RIVAL_PID=$!
started "$RIVAL_PID"
check "the rival is up" eventually says_in_log "rival ready pid=$RIVAL_PID"
grep "rival ready" "$HEARD" | tail -n 1 | cut -c 14-
# shellcheck disable=SC2086
press_all rival-after-arbor $ALL
what_arbor_says

step "8  the rival was there BEFORE Arbor"
arbor_stop 03-before-the-rival
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl arrange
what_arbor_says
# shellcheck disable=SC2086
press_all rival-before-arbor $ALL
kill_started "$RIVAL_PID"
RIVAL_PID=""
sleep 0.5
# shellcheck disable=SC2086
press_all rival-gone $FEW

step "9  Arbor killed"
echo "> kill -KILL (Arbor)"
kill -KILL "$ARBOR_PID"
ended "$ARBOR_PID"
ARBOR_PID=""
# shellcheck disable=SC2086
press_all killed $FEW
# What arbor_stop does after a quit: the log comes back, the test windows close, the next session gets a folder of its own.
arbor_log
arbor_close_windows
arbor_new_home

# MARK: A bundle that answers for its own permission

# As the probes of the permission do it: an identifier of its own, opened by Launch Services, so that one entry of the database is Arbor's alone and this script's tools keep theirs.
BUNDLE_ID=com.evbarleyg.arbor.probe-whose-key
TCC="/Library/Application Support/com.apple.TCC/TCC.db"
tcc() { sudo sqlite3 "$TCC" "$1"; }
app="$HOME/Applications/ArborProbeWhoseKey.app"
entry() { echo "the entry in the database (2 is what the switch shows as on): $(tcc "SELECT client, auth_value FROM access WHERE service = 'kTCCServiceAccessibility' AND client = '$BUNDLE_ID';" | tr '\n' ' ')"; }
hash_of_the_bundle() { codesign --display --verbose=3 "$app" 2>&1 | sed -n 's/^CDHash=//p'; }
sign_the_bundle() {
  codesign --force --sign - --identifier "$BUNDLE_ID" "$app" || die "codesign failed"
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$app" || echo "lsregister could not register the bundle"
  echo "the bundle's hash: $(hash_of_the_bundle)"
}
open_the_bundle() {
  limit 20 open -n "$app" --env ARBOR_HOME="$ARBOR_HOME" --env ARBOR_SOCKET="$ARBOR_SOCKET" --env ARBOR_DEBUG=1 \
    --env ARBOR_ONLY_PIDS="$ARBOR_WINDOWS_PID" --env ARBOR_NO_WATCHDOG=1 --env ARBOR_NO_PICTURES=1 --env ARBOR_NO_PROMPT=1 \
    --env ARBOR_NO_STATUS_ITEM=0 --env ARBOR_NO_HOTKEYS=0
  sleep 3
  ARBOR_PID=$(pgrep -f "$app/Contents/MacOS/Arbor" | head -n 1)
  [ -n "$ARBOR_PID" ] || die "the bundle did not start"
  started "$ARBOR_PID"
}
leave_the_bundle() {
  [ -n "$ARBOR_PID" ] || return 0
  "$ARBOR_BIN/arborctl" quit > /dev/null 2>&1
  ended "$ARBOR_PID" || kill_started "$ARBOR_PID"
  ARBOR_PID=""
}

step "10  the bundle"
if tcc "SELECT count(*) FROM access;" > /dev/null 2>&1; then
  # The test windows come with a session; its Arbor, a child of this shell that shares the shell's permission, makes way for the bundle.
  arbor_start 3
  "$ARBOR_BIN/arborctl" quit > /dev/null
  ended "$ARBOR_PID" || die "the session's own Arbor did not quit"
  ARBOR_PID=""
  at_exit 'rm -rf "${app:?}"'
  at_exit "tcc \"DELETE FROM access WHERE client = '$BUNDLE_ID';\""
  rm -rf "${app:?}"
  mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
  cp "$ARBOR_BIN/Arbor" "$app/Contents/MacOS/Arbor"
  cp "$ARBOR_ROOT/Resources/Info.plist" "$app/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" -c "Delete :CFBundleURLTypes" "$app/Contents/Info.plist" || die "could not edit Info.plist"
  sign_the_bundle

  step "10a  never granted: Arbor is in the menu bar. Which keys does it hold?"
  entry
  open_the_bundle
  what_arbor_says
  shot 05-no-permission
  # shellcheck disable=SC2086
  press_all never-granted $ALL ctrl+opt+escape
  leave_the_bundle

  step "10b  granted, as the switch in System Settings records it"
  codesign --display --requirements - "$app" 2>/dev/null | sed -n 's/^\(# \)\{0,1\}designated => //p' | tee "$ARBOR_SESSION_DIR/requirement.txt"
  csreq -r "$ARBOR_SESSION_DIR/requirement.txt" -b "$ARBOR_SESSION_DIR/requirement.bin" || die "csreq could not read the bundle's requirement"
  tcc "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version, csreq, indirect_object_identifier, flags, last_modified) VALUES ('kTCCServiceAccessibility', '$BUNDLE_ID', 0, 2, 3, 1, X'$(xxd -p "$ARBOR_SESSION_DIR/requirement.bin" | tr -d '\n')', 'UNUSED', 0, strftime('%s', 'now'));" \
    || die "the grant could not be written"
  sudo killall -9 tccd 2>/dev/null
  # Whoever posts events has been blocked for seconds after such a kill.
  sleep 6
  entry
  open_the_bundle
  what_arbor_says
  # shellcheck disable=SC2086
  press_all granted $FEW
  leave_the_bundle

  step "10c  replaced by another build, signed ad hoc: the entry stays, the hash is another"
  /usr/libexec/PlistBuddy -c "Add :ArborProbe string another-build" "$app/Contents/Info.plist" || die "could not edit Info.plist"
  sign_the_bundle
  entry
  open_the_bundle
  what_arbor_says
  shot 06-reinstalled
  # shellcheck disable=SC2086
  press_all reinstalled $ALL ctrl+opt+escape
  grep -iE "permission|accessib" "$ARBOR_HOME/arbor.log" | tail -n 6 | cut -c 12- | sed 's/^/  log | /'
  leave_the_bundle
else
  echo "left out: the permission database cannot be read here"
fi

# Last, because a hosted Mac may take it badly.
step "11  the display asleep, and awake again"
arbor_log
arbor_close_windows
arbor_new_home
arbor_start 3 ARBOR_NO_HOTKEYS=0 ARBOR_NO_STATUS_ITEM=0
ctl arrange
pmset displaysleepnow
sleep 4
caffeinate -u -t 2
sleep 2
what_arbor_says
# shellcheck disable=SC2086
press_all after-display-sleep $FEW
shot 04-after-display-sleep
arbor_stop 07-quit

step "when the app came to the front and left it"
grep -E " front (active|resigned)" "$HEARD" | awk '{ print $3 }' | sort | uniq -c
