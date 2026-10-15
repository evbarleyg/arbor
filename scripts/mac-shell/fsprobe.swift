// fsprobe: asks a window for a frame at a chosen moment of its way into or out of macOS's full screen, and writes down what
// Accessibility says about it meanwhile. The window server's side of the story is the sampler's (sampler.swift): both stamp their
// lines with milliseconds since 1970.
//
//   fsprobe <pid> <window> <when> <x> <y> <w> <h> [--other <pid>] [--seconds <n>]
//
//   <when>   never         ask for nothing: the control
//            now           at once (while it is in full screen, say), then go on looking
//            left          when it reports a resize and is no longer in full screen: the way out has only begun
//            scaffold      when its app reports a new window while it is in full screen: macOS's stand-in for the way out
//            landed        when that stand-in is destroyed: the way out is over
//            insist        as `left`, and again every 100 ms for as long as it is somewhere else, seven times at the most
//   --other  an app whose list of windows is read along, to see when the windows of the Space that comes back are listed again
//
// One line per report and per look (every 25 ms from the first report on):
//   <ms> REPORT <name> w<id> <subrole> <frame> [full-screen]
//   <ms> ASK <frame>: position <error> size <error> position <error>, took <ms> ms, has <frame>
//   <ms> LOOK <frame> [full-screen] listed|unlisted, its app lists <ids>, the other lists <n>, took <ms> ms
// A look that says what the last one said, and took no longer than 40 ms, is not printed.
//
// Compile it as lib.sh compiles pointer.swift: swiftc -O -swift-version 5. Needs Accessibility permission.

import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func now() -> Int { Int(Date().timeIntervalSince1970 * 1000) }

func say(_ text: String) {
  print("\(now()) \(text)")
  fflush(stdout)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func flag(_ element: AXUIElement, _ name: String) -> Bool {
  guard let value = attribute(element, name), CFGetTypeID(value) == CFBooleanGetTypeID() else { return false }
  return CFBooleanGetValue((value as! CFBoolean))
}

func number(of element: AXUIElement) -> CGWindowID {
  var identifier = CGWindowID(0)
  return _AXUIElementGetWindow(element, &identifier) == .success ? identifier : 0
}

func windows(of app: AXUIElement) -> [AXUIElement]? {
  guard let value = attribute(app, "AXWindows") else { return nil }
  return (value as? [AnyObject] ?? []).compactMap { item in
    CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
  }
}

func frame(of window: AXUIElement) -> String {
  var origin = CGPoint.zero
  var size = CGSize.zero
  guard let position = attribute(window, "AXPosition"), CFGetTypeID(position) == AXValueGetTypeID(),
    let extent = attribute(window, "AXSize"), CFGetTypeID(extent) == AXValueGetTypeID()
  else { return "no-frame" }
  AXValueGetValue(position as! AXValue, .cgPoint, &origin)
  AXValueGetValue(extent as! AXValue, .cgSize, &size)
  return "\(Int(origin.x)),\(Int(origin.y)) \(Int(size.width))x\(Int(size.height))"
}

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("fsprobe: \(message)\n".utf8))
  exit(64)
}

var arguments = Array(CommandLine.arguments.dropFirst())
var otherPid: pid_t?
var seconds = 12.0
if let index = arguments.firstIndex(of: "--other"), index + 1 < arguments.count {
  otherPid = pid_t(arguments[index + 1])
  arguments.removeSubrange(index...(index + 1))
}
if let index = arguments.firstIndex(of: "--seconds"), index + 1 < arguments.count {
  seconds = Double(arguments[index + 1]) ?? seconds
  arguments.removeSubrange(index...(index + 1))
}
let usage = "usage: fsprobe <pid> <window> never|now|left|scaffold|landed|insist <x> <y> <w> <h> [--other <pid>] [--seconds <n>]"
if arguments.count != 7 { fail(usage) }
// Plain globals, none of them bound by a `guard`: what a `guard` binds at the top level is a local variable, and a function that
// reads one cannot be handed to C as a callback.
let pid = pid_t(arguments[0]) ?? 0
let wanted = CGWindowID(arguments[1]) ?? 0
let when = arguments[2]
let numbers = arguments[3...6].map { Double($0) ?? -1 }
if pid == 0 || wanted == 0 || !["never", "now", "left", "scaffold", "landed", "insist"].contains(when) || numbers[2] <= 0 || numbers[3] <= 0 {
  fail(usage)
}
let target = CGRect(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])

let app = AXUIElementCreateApplication(pid)
let other = otherPid.map { AXUIElementCreateApplication($0) }
let found = windows(of: app)?.first(where: { number(of: $0) == wanted })
if found == nil { fail("pid \(pid) lists no window \(wanted)") }
let window = found!

var asked = false
var looking = false
var scaffolds = Set<CGWindowID>()
var lastLook = ""

var asks = 0

func wanting() -> String { "\(Int(target.minX)),\(Int(target.minY)) \(Int(target.width))x\(Int(target.height))" }

func insist() {
  asks += 1
  if frame(of: window) != wanting() {
    asked = false
    ask()
  }
  if asks < 7 { Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in insist() } }
}

func ask() {
  guard !asked else { return }
  asked = true
  var origin = target.origin
  var size = target.size
  let began = now()
  let position = AXValueCreate(.cgPoint, &origin)!
  let extent = AXValueCreate(.cgSize, &size)!
  // As Arbor's full plan does it: a window at a display's edge cannot grow before it has moved, nor always move before it has shrunk.
  let first = AXUIElementSetAttributeValue(window, "AXPosition" as CFString, position)
  let second = AXUIElementSetAttributeValue(window, "AXSize" as CFString, extent)
  let third = AXUIElementSetAttributeValue(window, "AXPosition" as CFString, position)
  say(
    "ASK \(Int(target.minX)),\(Int(target.minY)) \(Int(target.width))x\(Int(target.height)): position \(first.rawValue) size \(second.rawValue) position \(third.rawValue), "
      + "took \(now() - began) ms, has \(frame(of: window))")
}

func look() {
  let began = now()
  let has = frame(of: window)
  let full = flag(window, "AXFullScreen") ? " full-screen" : ""
  let listed = windows(of: app)?.map { number(of: $0) }
  let others = other.flatMap { windows(of: $0)?.count }
  let seen =
    "LOOK \(has)\(full) \(listed?.contains(wanted) == true ? "listed" : "unlisted"), its app lists "
    + "\(listed.map { $0.map { "w\($0)" }.joined(separator: ",") } ?? "nothing: no answer"), the other lists "
    + "\(others.map(String.init) ?? "-")"
  let took = now() - began
  guard seen != lastLook || took > 40 else { return }
  lastLook = seen
  say("\(seen), took \(took) ms")
}

func startLooking() {
  guard !looking else { return }
  looking = true
  Timer.scheduledTimer(withTimeInterval: 0.025, repeats: true) { _ in look() }
}

func callback(
  _ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?
) {
  let name = notification as String
  let id = refcon.map { CGWindowID(truncatingIfNeeded: UInt(bitPattern: $0)) } ?? number(of: element)
  let full = flag(element, "AXFullScreen")
  let subrole = name == "AXUIElementDestroyed" ? "-" : attribute(element, "AXSubrole") as? String ?? "-"
  say("REPORT \(name) w\(id) \(subrole) \(name == "AXUIElementDestroyed" ? "-" : frame(of: element))\(full ? " full-screen" : "")")
  switch name {
  case "AXWindowCreated":
    guard id != 0, id != wanted else { break }
    scaffolds.insert(id)
    AXObserverAddNotification(observer, element, "AXUIElementDestroyed" as CFString, UnsafeMutableRawPointer(bitPattern: UInt(id)))
    if when == "scaffold" { ask() }
  case "AXResized":
    if when == "left", id == wanted, !full { ask() }
    if when == "insist", id == wanted, !full, asks == 0 { insist() }
  case "AXUIElementDestroyed":
    if when == "landed", scaffolds.contains(id), !flag(window, "AXFullScreen") { ask() }
  default:
    break
  }
  startLooking()
}

var created: AXObserver?
if AXObserverCreate(pid, callback, &created) != .success || created == nil { fail("cannot observe pid \(pid)") }
let observer = created!
AXObserverAddNotification(observer, app, "AXWindowCreated" as CFString, nil)
for name in ["AXMoved", "AXResized", "AXUIElementDestroyed"] {
  AXObserverAddNotification(observer, window, name as CFString, UnsafeMutableRawPointer(bitPattern: UInt(wanted)))
}
CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
_ = NSWorkspace.shared.notificationCenter.addObserver(
  forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
) { _ in say("REPORT activeSpaceDidChange") }

say("BEGIN \(when) w\(wanted) has \(frame(of: window))\(flag(window, "AXFullScreen") ? " full-screen" : "")")
if when == "now" {
  ask()
  startLooking()
}
Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { _ in
  say("END has \(frame(of: window))\(flag(window, "AXFullScreen") ? " full-screen" : "")")
  exit(0)
}
RunLoop.main.run()
