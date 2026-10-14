// axtool: does to a test window what a person does with its title bar buttons, the Dock and ⌘Tab, for Mac
// shell scripts: minimize and restore, macOS's own full screen, giving another window of an app the
// keyboard, bringing an app to the front. These reach Arbor as Accessibility notifications in whatever order
// macOS sends them, which is what the scripts are after.
//
// A script compiles it itself (swiftc -O -swift-version 5 scripts/mac-shell/axtool.swift -o …). Needs Accessibility.

import AppKit
import ApplicationServices

let usage = """
  usage: axtool <command>
    list <pid>                                 id main minimized fullscreen x y w h, one line per window the app lists
    set <pid> <window id> <attribute> <yes|no> AXMinimized, AXFullScreen or AXMain; prints the AXError (0 is success)
    raise <pid> <window id>                    AXMain and AXRaise: the window becomes its app's focused window
    activate <pid>                             bring the app to the front, as ⌘Tab or a click in the Dock does
    front                                      the frontmost app's pid and its focused window's id (0 if none)
  """

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("axtool: \(message)\n".utf8))
  exit(64)
}

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func word(_ element: AXUIElement, _ name: String) -> String {
  guard let value = attribute(element, name), CFGetTypeID(value) == CFBooleanGetTypeID() else { return "?" }
  return CFBooleanGetValue((value as! CFBoolean)) ? "yes" : "no"
}

func number(of element: AXUIElement) -> CGWindowID {
  var id = CGWindowID(0)
  _ = _AXUIElementGetWindow(element, &id)
  return id
}

func windows(of pid: pid_t) -> [AXUIElement] {
  guard let value = attribute(AXUIElementCreateApplication(pid), kAXWindowsAttribute),
    CFGetTypeID(value) == CFArrayGetTypeID()
  else { return [] }
  return (value as? [AnyObject] ?? []).compactMap { item in
    CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
  }
}

func frame(of element: AXUIElement) -> CGRect {
  var origin = CGPoint.zero
  var size = CGSize.zero
  if let value = attribute(element, kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgPoint, &origin)
  }
  if let value = attribute(element, kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgSize, &size)
  }
  return CGRect(origin: origin, size: size)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard let command = arguments.first else { fail(usage) }

func pid(at index: Int) -> pid_t {
  guard arguments.count > index, let pid = pid_t(arguments[index]) else { fail("expected a process id\n\(usage)") }
  return pid
}

func window(at index: Int, of pid: pid_t) -> AXUIElement {
  guard arguments.count > index, let id = CGWindowID(arguments[index]) else { fail("expected a window id\n\(usage)") }
  guard let element = windows(of: pid).first(where: { number(of: $0) == id }) else {
    fail("process \(pid) lists no window \(id)")
  }
  return element
}

switch command {
case "list":
  for element in windows(of: pid(at: 1)) {
    let rect = frame(of: element)
    print(
      number(of: element), word(element, kAXMainAttribute), word(element, kAXMinimizedAttribute),
      word(element, "AXFullScreen"), Int(rect.minX), Int(rect.minY), Int(rect.width), Int(rect.height))
  }

case "set":
  let element = window(at: 2, of: pid(at: 1))
  guard arguments.count > 4, ["yes", "no"].contains(arguments[4]) else { fail(usage) }
  let value: CFBoolean = arguments[4] == "yes" ? kCFBooleanTrue : kCFBooleanFalse
  print(AXUIElementSetAttributeValue(element, arguments[3] as CFString, value).rawValue)

case "raise":
  let element = window(at: 2, of: pid(at: 1))
  let main = AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
  let raise = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
  print(main.rawValue, raise.rawValue)

case "activate":
  let target = pid(at: 1)
  let result = AXUIElementSetAttributeValue(
    AXUIElementCreateApplication(target), kAXFrontmostAttribute as CFString, kCFBooleanTrue)
  let activated = NSRunningApplication(processIdentifier: target)?.activate(options: []) ?? false
  print(result.rawValue, activated)

case "front":
  guard let app = NSWorkspace.shared.frontmostApplication else { fail("no frontmost app") }
  var focused = CGWindowID(0)
  if let value = attribute(AXUIElementCreateApplication(app.processIdentifier), kAXFocusedWindowAttribute),
    CFGetTypeID(value) == AXUIElementGetTypeID()
  {
    focused = number(of: value as! AXUIElement)
  }
  print(app.processIdentifier, focused)

default:
  fail("unknown command \(command)\n\(usage)")
}
