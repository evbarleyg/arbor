// Who would get a key if one were pressed now? Reads, and presses nothing. For scripts/mac-shell/probe-keyboard.sh and
// probe-finder-gets-the-keyboard.sh.
//
//   whohaskeys report [name=pid…]            one line: who is in front, whose menus the menu bar shows, who has the keyboard
//   whohaskeys take <seconds> [name=pid…]    becomes what Arbor is (an accessory app whose only window cannot take the
//                                            keyboard), activates ITSELF, reports after 0.05, 0.3 and 1 s and then
//                                            every second, and ends
//   whohaskeys activate <pid>                brings that app forward, as a click on its Dock icon does
//   whohaskeys give <way[+way…]> <pid> [x y] becomes what Arbor is (an accessory app that is not in front) and gives that app the keyboard, one
//                                            way after the other, saying what each call answered:
//                                              activate   NSRunningApplication.activate with no options
//                                              frontmost  AXFrontmost on the app's own element
//                                              element    AXFocused on the element the app has at x y (Finder's, where the wallpaper shows: the
//                                                         Desktop's own), or on the nearest of its parents that takes it
//
// Processes are called by the names given and "other" otherwise, and no title is ever read: on somebody's Mac it is nobody's business
// what else is open. Compiled on the Mac by the script, in language mode 5.
import AppKit
import ApplicationServices

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

let arguments = Array(CommandLine.arguments.dropFirst())
var names: [pid_t: String] = [getpid(): "the-probe"]
for word in arguments {
  let parts = word.split(separator: "=")
  if parts.count == 2, let pid = pid_t(parts[1]) { names[pid] = String(parts[0]) }
}

func name(_ pid: pid_t?) -> String {
  guard let pid else { return "nobody" }
  return names[pid] ?? "other"
}

func attribute(_ element: AXUIElement, _ name: String) -> (value: CFTypeRef?, error: AXError) {
  var value: CFTypeRef?
  let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
  return (value, error)
}

func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
  guard let value = attribute(element, name).value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
  return (value as! AXUIElement)
}

func report() -> String {
  let workspace = NSWorkspace.shared
  let everything = AXUIElementCreateSystemWide()
  AXUIElementSetMessagingTimeout(everything, 0.5)
  var words = [
    "front=\(name(workspace.frontmostApplication?.processIdentifier))",
    "menu-bar=\(name(workspace.menuBarOwningApplication?.processIdentifier))",
  ]
  // What Accessibility calls the focused application is the one keys go to.
  if let app = element(everything, kAXFocusedApplicationAttribute) {
    var pid: pid_t = 0
    AXUIElementGetPid(app, &pid)
    words.append("keys-go-to=\(name(pid))")
    if let window = element(app, kAXFocusedWindowAttribute) {
      var number: CGWindowID = 0
      words.append("its-window=\(_AXUIElementGetWindow(window, &number) == .success ? String(number) : "?")")
    } else {
      words.append("its-window=none")
    }
    let focused = element(app, kAXFocusedUIElementAttribute)
    words.append("its-element=\(focused.flatMap { attribute($0, kAXRoleAttribute).value as? String } ?? "none")")
  } else {
    words.append("keys-go-to=nobody (\(attribute(everything, kAXFocusedApplicationAttribute).error.rawValue))")
  }
  return words.joined(separator: " ")
}

final class Bystander: NSPanel {
  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

@MainActor
final class Taker {
  let seconds: Double
  let began = ProcessInfo.processInfo.systemUptime
  var moments: [Double]
  // Like a tile or the focus ring: on screen, in nobody's way, and not for the keyboard.
  let panel = Bystander(
    contentRect: NSRect(x: 40, y: 40, width: 24, height: 24), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)

  init(seconds: Double) {
    self.seconds = seconds
    moments = [0.05, 0.3] + Array(stride(from: 1.0, to: seconds, by: 1.0))
  }

  func run() {
    let app = NSApplication.shared
    app.setActivationPolicy(.accessory)
    panel.ignoresMouseEvents = true
    panel.alphaValue = 0.2
    panel.orderFrontRegardless()
    // The newer `activate()` is a request that macOS does not grant an accessory app in the background (M4).
    app.activate(ignoringOtherApps: true)
    _ = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in MainActor.assumeIsolated { self.tick() } }
    app.run()
  }

  func tick() {
    let elapsed = ProcessInfo.processInfo.systemUptime - began
    if let next = moments.first, elapsed >= next {
      moments.removeFirst()
      print(String(format: "  after %.2f s: ", elapsed) + report() + " active=\(NSApp.isActive) key-window=\(NSApp.keyWindow == nil ? "none" : "one")")
      fflush(stdout)
    }
    if elapsed >= seconds { exit(0) }
  }
}

switch arguments.first {
case "report":
  print(report())

case "activate":
  guard arguments.count > 1, let pid = pid_t(arguments[1]), let app = NSRunningApplication(processIdentifier: pid) else { exit(64) }
  app.activate(options: [])

case "give":
  guard arguments.count > 2, let pid = pid_t(arguments[2]), let app = NSRunningApplication(processIdentifier: pid) else { exit(64) }
  NSApplication.shared.setActivationPolicy(.accessory)
  let target = AXUIElementCreateApplication(pid)
  AXUIElementSetMessagingTimeout(target, 1)
  for way in arguments[1].split(separator: "+") {
    switch way {
    case "activate":
      print("  activate(options: []) answers \(app.activate(options: []))")
    case "frontmost":
      print("  AXFrontmost answers \(AXUIElementSetAttributeValue(target, kAXFrontmostAttribute as CFString, kCFBooleanTrue).rawValue)")
    case "element":
      guard arguments.count > 4, let x = Float(arguments[3]), let y = Float(arguments[4]) else { exit(64) }
      var found: AXUIElement?
      print("  the element at \(Int(x)) \(Int(y)): AXError \(AXUIElementCopyElementAtPosition(target, x, y, &found).rawValue)")
      var depth = 0
      while let current = found, depth < 5 {
        AXUIElementSetMessagingTimeout(current, 1)
        var settable: DarwinBoolean = false
        let asked = AXUIElementIsAttributeSettable(current, kAXFocusedAttribute as CFString, &settable)
        let role = attribute(current, kAXRoleAttribute).value as? String ?? "-"
        print("    \(role): AXFocused can be set: \(settable.boolValue) (AXError \(asked.rawValue))")
        if settable.boolValue {
          print("    AXFocused on it answers \(AXUIElementSetAttributeValue(current, kAXFocusedAttribute as CFString, kCFBooleanTrue).rawValue)")
          break
        }
        found = element(current, kAXParentAttribute)
        depth += 1
      }
    default:
      exit(64)
    }
    // One call is on its way before the next is made, as it would be in Arbor, which makes them in a row.
    Thread.sleep(forTimeInterval: 0.05)
  }

case "take":
  guard arguments.count > 1, let seconds = Double(arguments[1]) else { exit(64) }
  MainActor.assumeIsolated { Taker(seconds: seconds).run() }

default:
  FileHandle.standardError.write(Data("usage: whohaskeys report | take <seconds> | activate <pid> | give <way[+way…]> <pid> [x y]  [name=pid…]\n".utf8))
  exit(64)
}
