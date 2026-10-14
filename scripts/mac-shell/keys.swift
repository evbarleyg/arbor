// keys: who gets a key press, what shortcuts cost, and which keyboard layout is on, for Mac shell scripts.
//
// Arbor's shortcuts are taken from every app, so whether a press reached the app in front cannot be read from
// Arbor. `keys app` is that app: put into a bundle (it needs a bundle id to go on Arbor's lists) it opens one
// window and writes down every key event it is given. The other commands measure Carbon hot keys, list event
// taps, and read and switch keyboard layouts.
//
// scripts/mac-shell/check-F41.sh compiles it (swiftc -O -swift-version 5) and shows how it is used.

import AppKit
import Carbon.HIToolbox
import Foundation

setvbuf(stdout, nil, _IOLBF, 0)

let usage = """
  usage: keys <command>
    app <log> [x y w h]           an app with one window (global top-left coordinates) that appends every key event it
                                  receives to <log>, and when it comes to the front and leaves it; SIGUSR1 brings it forward
    bench <keys> <rounds>         how long registering and unregistering that many Carbon hot keys takes
    repost <seconds>              hold ⌃⌥J as a hot key and pass each press on to the frontmost app with postToPid
    taps <pid>                    how many event taps that process has
    frontmost                     the frontmost app's bundle id, or its name in brackets
    layout                        the keyboard layout in use, and the ASCII-capable one macOS pairs with it
    layouts [all]                 the layouts switched on in the Input menu, or every layout installed
    select <id>                   switch that layout on and select it, e.g. com.apple.keylayout.German
    remove <id>                   take it out of the Input menu again
    watch <seconds>               print every "selected keyboard input source changed" notification
    dump <id>…                    what each key types in that layout: one line of JSON per layout
    hotkeys                       macOS's own shortcuts as CopySymbolicHotKeys lists them: key code, modifiers (hex), on or off
  """

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("keys: \(message)\n".utf8))
  exit(64)
}

func uptimeMicroseconds() -> UInt64 { clock_gettime_nsec_np(CLOCK_UPTIME_RAW) / 1000 }

/// The time of day as arbor.log writes it (UTC, to the millisecond), to line the two up.
func wallClock() -> String {
  let formatter = DateFormatter()
  formatter.dateFormat = "HH:mm:ss.SSS"
  formatter.timeZone = TimeZone(identifier: "UTC")
  return formatter.string(from: Date())
}

func modifiers(_ flags: NSEvent.ModifierFlags) -> String {
  var names: [String] = []
  if flags.contains(.control) { names.append("ctrl") }
  if flags.contains(.option) { names.append("opt") }
  if flags.contains(.shift) { names.append("shift") }
  if flags.contains(.command) { names.append("cmd") }
  return names.isEmpty ? "none" : names.joined(separator: "+")
}

// MARK: The app that writes down its keys

final class Witness: NSObject, NSApplicationDelegate {
  let log: FileHandle
  let frame: CGRect
  var window: NSWindow?
  var signalSource: DispatchSourceSignal?

  init(log: FileHandle, frame: CGRect) {
    self.log = log
    self.frame = frame
  }

  func write(_ line: String) {
    log.write(Data("\(wallClock()) \(line)\n".utf8))
  }

  func applicationDidFinishLaunching(_ notification: Notification) {
    let height = NSScreen.screens.first?.frame.height ?? 768
    let rect = NSRect(x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height)
    let window = NSWindow(contentRect: rect, styleMask: [.titled, .resizable], backing: .buffered, defer: false)
    window.title = "Keys"
    window.setFrame(rect, display: true)
    window.makeKeyAndOrderFront(nil)
    self.window = window
    // Before anything in the app can act on the event, and swallowed, so that nothing beeps.
    NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
      let text = (event.charactersIgnoringModifiers ?? "").unicodeScalars.map { String($0.value, radix: 16) }
      self?.write(
        "\(event.type == .keyDown ? "down" : "up") code=\(event.keyCode) mods=\(modifiers(event.modifierFlags)) "
          + "chars=\(text.joined(separator: ",")) repeat=\(event.isARepeat)")
      return nil
    }
    signal(SIGUSR1, SIG_IGN)
    let source = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
    source.setEventHandler { NSApp.activate(ignoringOtherApps: true) }
    source.resume()
    signalSource = source
    NSApp.activate(ignoringOtherApps: true)
    write("ready pid=\(getpid()) bundle=\(Bundle.main.bundleIdentifier ?? "none")")
  }

  func applicationDidBecomeActive(_ notification: Notification) { write("active") }
  func applicationDidResignActive(_ notification: Notification) { write("resigned") }
}

func runWitness(_ arguments: [String]) -> Never {
  guard let path = arguments.first else { fail(usage) }
  FileManager.default.createFile(atPath: path, contents: nil)
  guard let log = FileHandle(forWritingAtPath: path) else { fail("cannot write \(path)") }
  let numbers = arguments.dropFirst().compactMap(Double.init)
  let frame = numbers.count == 4 ? CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    : CGRect(x: 380, y: 300, width: 260, height: 160)
  let delegate = Witness(log: log, frame: frame)
  let application = NSApplication.shared
  application.delegate = delegate
  application.setActivationPolicy(.regular)
  withExtendedLifetime(delegate) { application.run() }
  exit(0)
}

// MARK: What hot keys cost

/// Key codes of letters, digits and punctuation: enough for a hundred hot keys with two sets of modifiers.
let benchCodes: [UInt32] = Array(0...9) + Array(11...47)

func bench(keys: Int, rounds: Int) {
  _ = NSApplication.shared  // a connection to the window server, as Arbor has
  var registering: [UInt64] = []
  var unregistering: [UInt64] = []
  for _ in 0..<rounds {
    var refs: [EventHotKeyRef] = []
    let start = uptimeMicroseconds()
    for index in 0..<keys {
      var ref: EventHotKeyRef?
      // ⌃⌥⇧⌘, which nothing on the Mac holds, and ⌃⇧⌘ for the second half.
      let flags = UInt32(index < benchCodes.count ? controlKey | optionKey | shiftKey | cmdKey : controlKey | shiftKey | cmdKey)
      let status = RegisterEventHotKey(
        benchCodes[index % benchCodes.count], flags, EventHotKeyID(signature: 0x4B45_5953, id: UInt32(index + 1)),
        GetEventDispatcherTarget(), 0, &ref)
      if status == noErr, let ref { refs.append(ref) }
    }
    let middle = uptimeMicroseconds()
    for ref in refs { UnregisterEventHotKey(ref) }
    let end = uptimeMicroseconds()
    guard refs.count == keys else { fail("only \(refs.count) of \(keys) hot keys registered") }
    registering.append(middle - start)
    unregistering.append(end - middle)
  }
  func summary(_ values: [UInt64]) -> String {
    let sorted = values.sorted()
    return "min \(sorted[0]) median \(sorted[sorted.count / 2]) max \(sorted[sorted.count - 1]) µs"
  }
  print("register \(keys) hot keys: \(summary(registering))")
  print("unregister \(keys) hot keys: \(summary(unregistering))")
}

// MARK: Keeping a hot key and passing the press on

func repostHandler(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
  guard let event else { return OSStatus(eventNotHandledErr) }
  let down = GetEventKind(event) == UInt32(kEventHotKeyPressed)
  guard let front = NSWorkspace.shared.frontmostApplication,
    let copy = CGEvent(keyboardEventSource: CGEventSource(stateID: .hidSystemState), virtualKey: 38, keyDown: down)
  else { return noErr }
  copy.flags = [.maskControl, .maskAlternate]
  copy.postToPid(front.processIdentifier)
  print("\(wallClock()) hot key \(down ? "pressed" : "released"): passed on to pid \(front.processIdentifier)")
  return noErr
}

func repost(seconds: Double) {
  let application = NSApplication.shared
  application.setActivationPolicy(.accessory)
  var specs = [
    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
    EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
  ]
  InstallEventHandler(GetEventDispatcherTarget(), repostHandler, 2, &specs, nil, nil)
  var ref: EventHotKeyRef?
  let status = RegisterEventHotKey(
    38, UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x4B45_5953, id: 1), GetEventDispatcherTarget(), 0, &ref)
  guard status == noErr else { fail("could not register ⌃⌥J (\(status))") }
  print("holding ⌃⌥J")
  DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { exit(0) }
  application.run()
}

// MARK: Event taps

func taps(of pid: pid_t) {
  var count: UInt32 = 0
  CGGetEventTapList(0, nil, &count)
  var list = [CGEventTapInformation](repeating: CGEventTapInformation(), count: Int(count))
  CGGetEventTapList(count, &list, &count)
  print(list.prefix(Int(count)).filter { $0.tappingProcess == pid }.count)
}

// MARK: Keyboard layouts

func text(_ source: TISInputSource, _ key: CFString) -> String {
  guard let pointer = TISGetInputSourceProperty(source, key) else { return "?" }
  return Unmanaged<CFString>.fromOpaque(pointer).takeUnretainedValue() as String
}

func identifier(_ source: TISInputSource) -> String { text(source, kTISPropertyInputSourceID) }

func layouts(includingAllInstalled all: Bool) -> [TISInputSource] {
  let filter = [kTISPropertyInputSourceType as String: kTISTypeKeyboardLayout as String] as CFDictionary
  guard let list = TISCreateInputSourceList(filter, all) else { return [] }
  return list.takeRetainedValue() as! [TISInputSource]
}

func layout(named id: String) -> TISInputSource {
  guard let source = layouts(includingAllInstalled: true).first(where: { identifier($0) == id }) else {
    fail("no keyboard layout \(id)")
  }
  return source
}

/// As the scripts refuse it too: which layouts are in the Input menu, and which is on, is the person's, except on a Mac that is thrown away.
func refuseOnSomebodysMac() {
  // Both, as in lib.sh: a runner on a person's own Mac sets the variable too; GitHub's Macs run jobs as `runner`.
  if ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] != "true" || NSUserName() != "runner" {
    fail("this Mac is somebody's: keyboard layouts are switched only on GitHub's throwaway Macs")
  }
}

func currentLayouts() -> String {
  let selected = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
  let layout = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
  let ascii = TISCopyCurrentASCIICapableKeyboardLayoutInputSource().takeRetainedValue()
  return "selected \(identifier(selected)) layout \(identifier(layout)) ascii \(identifier(ascii))"
}

/// What every key types with these modifiers held (Carbon's modifier bits, shifted as UCKeyTranslate wants them).
func table(_ source: TISInputSource, modifiers: Int) -> [String: String] {
  guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return [:] }
  let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
  var result: [String: String] = [:]
  data.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
    guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return }
    for code in 0..<128 {
      var deadKeys: UInt32 = 0
      var length = 0
      var characters = [UniChar](repeating: 0, count: 4)
      let status = UCKeyTranslate(
        layout, UInt16(code), UInt16(kUCKeyActionDisplay), UInt32((modifiers >> 8) & 0xFF), UInt32(LMGetKbdType()),
        OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, characters.count, &length, &characters)
      guard status == noErr, length > 0 else { continue }
      let typed = String(utf16CodeUnits: characters, count: length)
      // Control characters are the keys that type nothing: return, tab, the arrows, the F-keys.
      guard typed.unicodeScalars.allSatisfy({ $0.value > 0x20 && $0.value != 0x7F && !(0xF700...0xF8FF).contains($0.value) })
      else { continue }
      result[String(code)] = typed
    }
  }
  return result
}

func dump(_ ids: [String]) {
  let installed = layouts(includingAllInstalled: true)
  for id in ids {
    guard let source = installed.first(where: { identifier($0) == id }) else {
      FileHandle.standardError.write(Data("keys: no keyboard layout \(id)\n".utf8))
      continue
    }
    let object: [String: Any] = [
      "id": id, "name": text(source, kTISPropertyLocalizedName), "keyboardType": Int(LMGetKbdType()),
      "plain": table(source, modifiers: 0), "shift": table(source, modifiers: shiftKey),
      "cmd": table(source, modifiers: cmdKey), "ctrlopt": table(source, modifiers: controlKey | optionKey),
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { continue }
    print(String(decoding: data, as: UTF8.self))
  }
}

func watch(seconds: Double) {
  let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
  let token = DistributedNotificationCenter.default().addObserver(forName: name, object: nil, queue: .main) { _ in
    print("\(wallClock()) changed: \(currentLayouts())")
  }
  print("\(wallClock()) watching: \(currentLayouts())")
  RunLoop.main.run(until: Date().addingTimeInterval(seconds))
  DistributedNotificationCenter.default().removeObserver(token)
}

// MARK: Main

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail(usage) }
let rest = Array(arguments.dropFirst())

switch command {
case "app":
  runWitness(rest)
case "bench":
  guard rest.count == 2, let keys = Int(rest[0]), let rounds = Int(rest[1]), (1...94).contains(keys), rounds > 0 else { fail(usage) }
  bench(keys: keys, rounds: rounds)
case "repost":
  guard let seconds = rest.first.flatMap(Double.init) else { fail(usage) }
  repost(seconds: seconds)
case "taps":
  guard let pid = rest.first.flatMap({ pid_t($0) }) else { fail(usage) }
  taps(of: pid)
case "frontmost":
  let front = NSWorkspace.shared.frontmostApplication
  print(front?.bundleIdentifier ?? "[\(front?.localizedName ?? "nobody")]")
case "layout":
  print(currentLayouts())
case "layouts":
  for source in layouts(includingAllInstalled: rest.first == "all") { print(identifier(source)) }
case "select":
  guard let id = rest.first else { fail(usage) }
  refuseOnSomebodysMac()
  let source = layout(named: id)
  let enabled = TISEnableInputSource(source)
  let selected = TISSelectInputSource(source)
  print("enable \(enabled) select \(selected): \(currentLayouts())")
  exit(selected == noErr ? 0 : 1)
case "remove":
  guard let id = rest.first else { fail(usage) }
  refuseOnSomebodysMac()
  print("disable \(TISDisableInputSource(layout(named: id)))")
case "watch":
  guard let seconds = rest.first.flatMap(Double.init) else { fail(usage) }
  watch(seconds: seconds)
case "dump":
  dump(rest)
case "hotkeys":
  var list: Unmanaged<CFArray>?
  guard CopySymbolicHotKeys(&list) == noErr, let entries = list?.takeRetainedValue() as? [[String: Any]] else {
    fail("CopySymbolicHotKeys failed")
  }
  for entry in entries {
    let code = entry[kHISymbolicHotKeyCode] as? Int ?? -1
    let modifiers = entry[kHISymbolicHotKeyModifiers] as? Int ?? -1
    let isOn = entry[kHISymbolicHotKeyEnabled] as? Bool ?? false
    print("key \(code) modifiers 0x\(String(modifiers, radix: 16)) \(isOn ? "on" : "off")")
  }
default:
  fail(usage)
}
