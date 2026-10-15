// typed: how many characters stand in the text of a window, for Mac shell scripts that type a letter and want to know where it landed.
//
//   typed <pid> <window id>      prints the length of the first text area's text in that window, by Accessibility; - if it has none
//
// It reads the length and nothing else: never the text. A script compiles it itself (swiftc -O -swift-version 5 scripts/mac-shell/typed.swift -o …). Needs Accessibility.

import ApplicationServices
import Foundation

@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("typed: \(message)\n".utf8))
  exit(64)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
  return value
}

func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
  (attribute(element, name) as? [AnyObject] ?? []).filter { CFGetTypeID($0) == AXUIElementGetTypeID() }.map { $0 as! AXUIElement }
}

func number(of element: AXUIElement) -> CGWindowID {
  var identifier = CGWindowID(0)
  return _AXUIElementGetWindow(element, &identifier) == .success ? identifier : 0
}

/// The first text area under the element, nearest first; a budget, because a web page has no end.
func textArea(under root: AXUIElement) -> AXUIElement? {
  var queue = [root]
  var budget = 400
  while !queue.isEmpty, budget > 0 {
    let next = queue.removeFirst()
    budget -= 1
    if attribute(next, "AXRole") as? String == "AXTextArea" { return next }
    queue.append(contentsOf: elements(next, "AXChildren"))
  }
  return nil
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 2, let pid = pid_t(arguments[0]), let id = CGWindowID(arguments[1]) else { fail("usage: typed <pid> <window id>") }
let app = AXUIElementCreateApplication(pid)
AXUIElementSetMessagingTimeout(app, 3)
guard let window = elements(app, "AXWindows").first(where: { number(of: $0) == id }) else { fail("process \(pid) lists no window \(id)") }
if let area = textArea(under: window), let count = attribute(area, "AXNumberOfCharacters") as? Int {
  print(count)
} else {
  print("-")
}
