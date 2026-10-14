// axfind: finds a control in a window by what Accessibility says about it, for Mac shell scripts.
//
// A window laid out by SwiftUI has no fixed places to click: they move with the macOS version, the font and the
// text. This tool reads the window as assistive software does and prints where a control is, so that
// `pointer` can click there as a person would, and what it shows, so that a script can check it without a picture.
// It only reads: it presses nothing and changes nothing.
//
// Compile it as lib.sh compiles pointer.swift: swiftc -O -swift-version 5. Needs Accessibility permission.

import AppKit
import ApplicationServices

let usage = """
  usage: axfind <pid> <command>
    tree                   every element of the app's windows, one per line, indented by depth:
                             role identifier "title or description" "value" x y w h
    point <role> <text>    x y: the middle of the first element of that role (- for any) whose identifier is <text>,
                             or else whose title, description or value contains it ("" is in all of them)
    value <role> <text>    what that element shows
    frame <role> <text>    x y w h of that element
    window <title>         the window-server number of the app's window with that title
  """

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("axfind: \(message)\n".utf8))
  exit(64)
}

/// The window-server number behind an Accessibility window; Arbor uses the same call (AXHelpers.swift).
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
  guard let value = attribute(element, name) else { return [] }
  return (value as? [AnyObject] ?? []).compactMap { item in
    CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
  }
}

/// Text, a number or a switch's state, as text on one line.
func text(_ element: AXUIElement, _ name: String) -> String {
  guard let value = attribute(element, name) else { return "" }
  if let string = value as? String { return string.replacingOccurrences(of: "\n", with: " ") }
  if let number = value as? NSNumber { return number.stringValue }
  return ""
}

func frame(of element: AXUIElement) -> CGRect {
  var origin = CGPoint.zero
  var size = CGSize.zero
  if let value = attribute(element, "AXPosition"), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgPoint, &origin)
  }
  if let value = attribute(element, "AXSize"), CFGetTypeID(value) == AXValueGetTypeID() {
    AXValueGetValue(value as! AXValue, .cgSize, &size)
  }
  return CGRect(origin: origin, size: size)
}

func name(of element: AXUIElement) -> String {
  let title = text(element, "AXTitle")
  return title.isEmpty ? text(element, "AXDescription") : title
}

/// Calls `visit` for `element` and everything under it, parents first, until it returns false. The limits are
/// there for a tree that never ends; no window of Arbor's comes near them.
var visited = 0
@discardableResult
func walk(_ element: AXUIElement, depth: Int = 0, _ visit: (AXUIElement, Int) -> Bool) -> Bool {
  visited += 1
  guard depth < 60, visited < 20000 else { return true }
  guard visit(element, depth) else { return false }
  for child in elements(element, "AXChildren") {
    guard walk(child, depth: depth + 1, visit) else { return false }
  }
  return true
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 2, let pid = pid_t(arguments[0]) else { fail(usage) }
let windows = elements(AXUIElementCreateApplication(pid), "AXWindows")

func find() -> AXUIElement {
  guard arguments.count == 4 else { fail(usage) }
  let role = arguments[2]
  let wanted = arguments[3]
  var byIdentifier: AXUIElement?
  var byText: AXUIElement?
  for window in windows {
    walk(window) { element, _ in
      guard role == "-" || text(element, "AXRole") == role else { return true }
      if text(element, "AXIdentifier") == wanted {
        byIdentifier = element
        return false
      }
      if byText == nil,
        wanted.isEmpty || name(of: element).contains(wanted) || text(element, "AXValue").contains(wanted)
      {
        byText = element
      }
      return true
    }
    if byIdentifier != nil { break }
  }
  guard let found = byIdentifier ?? byText else { fail("process \(pid) shows no \(role) “\(wanted)”") }
  return found
}

switch arguments[1] {
case "tree":
  for window in windows {
    walk(window) { element, depth in
      let rect = frame(of: element)
      let identifier = text(element, "AXIdentifier")
      print(
        String(repeating: "  ", count: depth) + text(element, "AXRole"), identifier.isEmpty ? "-" : identifier,
        "\"\(name(of: element))\"", "\"\(text(element, "AXValue"))\"", Int(rect.minX), Int(rect.minY), Int(rect.width),
        Int(rect.height))
      return true
    }
  }
case "point":
  let rect = frame(of: find())
  print(Int(rect.midX), Int(rect.midY))
case "frame":
  let rect = frame(of: find())
  print(Int(rect.minX), Int(rect.minY), Int(rect.width), Int(rect.height))
case "value":
  print(text(find(), "AXValue"))
case "window":
  guard arguments.count == 3 else { fail(usage) }
  guard let window = windows.first(where: { text($0, "AXTitle") == arguments[2] }) else {
    fail("process \(pid) has no window titled “\(arguments[2])”")
  }
  var number = CGWindowID(0)
  guard _AXUIElementGetWindow(window, &number) == .success else { fail("the window has no number") }
  print(number)
default:
  fail(usage)
}
