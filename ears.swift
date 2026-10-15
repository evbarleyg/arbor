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
