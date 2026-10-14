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
guard arguments.count == 7, let pid = pid_t(arguments[0]), let wanted = CGWindowID(arguments[1]),
  ["never", "now", "left", "scaffold", "landed"].contains(arguments[2]),
  let x = Double(arguments[3]), let y = Double(arguments[4]), let w = Double(arguments[5]), let h = Double(arguments[6])
else { fail("usage: fsprobe <pid> <window> never|now|left|scaffold|landed <x> <y> <w> <h> [--other <pid>] [--seconds <n>]") }
let when = arguments[2]
let target = CGRect(x: x, y: y, width: w, height: h)

let app = AXUIElementCreateApplication(pid)
let other = otherPid.map { AXUIElementCreateApplication($0) }
guard let window = windows(of: app)?.first(where: { number(of: $0) == wanted }) else { fail("pid \(pid) lists no window \(wanted)") }

var asked = false
var looking = false
var scaffolds = Set<CGWindowID>()
var lastLook = ""

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
    "ASK \(Int(x)),\(Int(y)) \(Int(w))x\(Int(h)): position \(first.rawValue) size \(second.rawValue) position \(third.rawValue), "
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

var observer: AXObserver?

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
  case "AXUIElementDestroyed":
    if when == "landed", scaffolds.contains(id), !flag(window, "AXFullScreen") { ask() }
  default:
    break
  }
  startLooking()
}

guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { fail("cannot observe pid \(pid)") }
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
