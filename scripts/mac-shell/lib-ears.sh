# Ears of every kind for a key, and hands of more than one, for Mac shell scripts. Source it after lib.sh; do not run it.
#
#   source "$(dirname "$0")/lib.sh"
#   needs_throwaway_mac "…"
#   source "$(dirname "$0")/lib-ears.sh"          # builds Arbor and the tool
#   echo ctrl+opt+a > "$CHORDS"; ears_open
#   press_all <round> <chord…>                    # each pressed with the app in front; then who heard it, and whether Arbor's log grew
#
# probe-whose-key.sh says what the ears are and is the long example. Everything the ears hear and the script marks goes into one file, $HEARD, a line at a time.
# Only on GitHub's Macs: event taps that listen, and keys pressed into whatever is in front.
needs_throwaway_mac "listen with event taps, and press keys into whatever is in front"
# Every launch is recorded (docs/TRACES.md).
ARBOR_RECORD=${ARBOR_RECORD:-1}

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
guard let command = arguments.first else { fail("front | back | rival | frontmost | press | hammer | announce") }
if command == "frontmost" {
  print(NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0)
  exit(0)
}
if command == "announce" {
  // What the switch in System Settings sends and a write to the permission database does not: a process that runs hears of a grant or a loss through this alone.
  DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.apple.accessibility.api"), object: nil, userInfo: nil, deliverImmediately: true)
  exit(0)
}
// press <key code> <modifier keys, comma-separated> <road> [repeats]
// hammer <key code> <modifier keys> <road> <seconds> <presses a second>: the same press over and over, in one process
//   modifier keys  lctrl rctrl lopt ropt fnkey: the key goes down, with the bit that says which. fnfirst: an fn key that comes up again BEFORE the key does. fnlate: one that goes down only AFTER the key has (repeats come after it). ctrl opt: the flag alone, no key and no hand, as many tools post.
//                  caps fn pad: the flag alone (a Caps Lock really pressed would stay on)
//   road           hid | session | annotated: the point at which the events are put in, from the keyboard inwards; or a process id, for postToPid
func press(_ code: CGKeyCode, _ modifiers: String, _ road: String, repeats: Int = 0, pause: useconds_t = 8000, hold: useconds_t = 40000) {
  let keys: [String: (code: CGKeyCode?, flags: UInt64)] = [
    "lctrl": (59, 0x40001), "rctrl": (62, 0x42000), "lopt": (58, 0x80020), "ropt": (61, 0x80040), "fnkey": (63, 0x800000), "fnfirst": (63, 0x800000),
    "ctrl": (nil, 0x40000), "opt": (nil, 0x80000), "caps": (nil, 0x10000), "fn": (nil, 0x800000), "pad": (nil, 0x200000),
  ]
  let source = CGEventSource(stateID: .hidSystemState)
  func post(_ code: CGKeyCode, _ down: Bool, _ flags: UInt64, repeating: Bool = false) {
    guard let event = CGEvent(keyboardEventSource: source, virtualKey: code, keyDown: down) else { fail("no event") }
    event.flags = CGEventFlags(rawValue: flags | 0x100)
    if repeating { event.setIntegerValueField(.keyboardEventAutorepeat, value: 1) }
    switch road {
    case "hid": event.post(tap: .cghidEventTap)
    case "session": event.post(tap: .cgSessionEventTap)
    case "annotated": event.post(tap: .cgAnnotatedSessionEventTap)
    default:
      guard let pid = pid_t(road) else { fail("hid, session, annotated or a process id") }
      event.postToPid(pid)
    }
    usleep(pause)
  }
  var flags: UInt64 = 0
  var down: [(CGKeyCode, UInt64)] = []
  let late = modifiers.split(separator: ",").contains("fnlate")
  for word in modifiers.split(separator: ",").map(String.init) where word != "fnlate" {
    guard let key = keys[word] else { fail("no modifier \(word)") }
    flags |= key.flags
    if let code = key.code {
      post(code, true, flags)
      down.append((code, key.flags))
    }
  }
  post(code, true, flags)
  if late {
    usleep(hold)
    flags |= 0x800000
    post(63, true, flags)
    down.append((63, 0x800000))
  }
  for _ in 0..<repeats {
    usleep(30000)
    post(code, true, flags, repeating: true)
  }
  usleep(hold)
  if modifiers.split(separator: ",").contains("fnfirst") {
    flags &= ~0x800000
    post(63, false, flags)
    down.removeAll { $0.0 == 63 }
    usleep(hold)
  }
  post(code, false, flags)
  for (code, mine) in down.reversed() {
    // Two keys of a pair share the flag that names the pair: it goes with the last of them.
    flags &= ~(mine & 0xFFFF)
    if !down.contains(where: { $0.0 != code && $0.1 & 0xFF0000 == mine & 0xFF0000 && flags & ($0.1 & 0xFFFF) != 0 }) { flags &= ~(mine & 0xFF0000) }
    post(code, false, flags)
  }
}
if command == "press" {
  guard arguments.count > 3, let code = CGKeyCode(arguments[1]) else { fail("press <code> <modifiers> <road> [repeats]") }
  press(code, arguments[2], arguments[3], repeats: arguments.count > 4 ? Int(arguments[4]) ?? 0 : 0)
  exit(0)
}
if command == "hammer" {
  guard arguments.count > 5, let code = CGKeyCode(arguments[1]), let seconds = Double(arguments[4]), let rate = Double(arguments[5]), rate > 0 else {
    fail("hammer <code> <modifiers> <road> <seconds> <presses a second>")
  }
  let end = Date().addingTimeInterval(seconds)
  var count = 0
  while Date() < end {
    let next = Date().addingTimeInterval(1 / rate)
    press(code, arguments[2], arguments[3], pause: 1000, hold: 4000)
    count += 1
    let rest = next.timeIntervalSinceNow
    if rest > 0 { usleep(useconds_t(rest * 1_000_000)) }
  }
  print("\(count) presses in \(seconds) s")
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
  note("rival \(GetEventKind(event) == UInt32(kEventHotKeyReleased) ? "released" : "pressed") \(chordOfRival[id.id] ?? "?")")
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
  var specs = [
    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
  ]
  InstallEventHandler(GetEventDispatcherTarget(), rivalHeard, 2, &specs, nil, nil)
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
    // fn: kEventKeyModifierFnMask. The others are guesses, for where that one is not heard.
    let extras = words[1].split(separator: "+").map(String.init)
    if extras.contains("fn") { flags |= 1 << 17 }
    if extras.contains("bit23") { flags |= 1 << 23 }
    if extras.contains("bit16") { flags |= 1 << 16 }
    let options: OptionBits = extras.contains("exclusive") ? OptionBits(kEventHotKeyExclusive) : 0
    var ref: EventHotKeyRef?
    let id = UInt32(index + 1)
    let status = RegisterEventHotKey(code, UInt32(flags), EventHotKeyID(signature: 0x5249_5641, id: id), GetEventDispatcherTarget(), options, &ref)
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
    elif chord not in (None, "-") and words[1] in EARS and words[2] != "released":
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
# hammer <seconds> [a second]: ⌃⌥A over and over in the background, by one process: twenty-five a second unless told otherwise. By flags alone, with no modifier key going down or
# up, so that it does not let go of keys that something else holds down. (A press by a process of its own each time made two a second, at the first run.)
hammer() {
  "$EARS" hammer 0 ctrl,opt hid "$1" "${2:-25}" 9>&- 8>&- &
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

# ears_open: the app in front and the listener in the background. $CHORDS has to hold the keys the app's menu is to have.
ears_open() {
  local dx dy dw dh
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
}
