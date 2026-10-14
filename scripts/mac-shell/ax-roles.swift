// ax-roles: what the Accessibility API says is under a point, for tuning which double-clicks are Arbor's.
//
// A double-click in the top of a docked window is Arbor's only when the element under the pointer is scenery
// (`DoubleClickZones.Hit.isBackground` in ArborCore lists the roles). This tool prints what real apps put
// there, asked the way `PointerProbe` in Input/DoubleClickTap.swift asks. It needs Accessibility permission.
//
//   swiftc -O -swift-version 5 scripts/mac-shell/ax-roles.swift -o /tmp/ax-roles
//   /tmp/ax-roles strip $(pgrep -x Safari)     the top of the app's first window, row by row
//   /tmp/ax-roles at $(pgrep -x Finder) 500 400
//   /tmp/ax-roles icons                        where Finder's Desktop icons are: x y of each one's middle
//
// Roles only, never titles or values: the output goes into logs.

import ApplicationServices
import Foundation

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("ax-roles: \(message)\n".utf8))
  exit(64)
}

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}

func role(_ element: AXUIElement) -> String { attribute(element, kAXRoleAttribute) as? String ?? "?" }

func elements(_ element: AXUIElement, _ name: String) -> [AXUIElement] {
  (attribute(element, name) as? [AnyObject] ?? []).filter { CFGetTypeID($0) == AXUIElementGetTypeID() }
    .map { $0 as! AXUIElement }
}

func frame(_ element: AXUIElement) -> CGRect? {
  guard let position = attribute(element, kAXPositionAttribute), let size = attribute(element, kAXSizeAttribute),
    CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID()
  else { return nil }
  var origin = CGPoint.zero
  var extent = CGSize.zero
  guard AXValueGetValue(position as! AXValue, .cgPoint, &origin), AXValueGetValue(size as! AXValue, .cgSize, &extent)
  else { return nil }
  return CGRect(origin: origin, size: extent)
}

/// The role of the element at the point, then its parent's, and so on.
func chain(_ app: AXUIElement, _ x: CGFloat, _ y: CGFloat, depth: Int = 6) -> String {
  var found: AXUIElement?
  let error = AXUIElementCopyElementAtPosition(app, Float(x), Float(y), &found)
  guard error == .success, var element = found else { return "(no answer: error \(error.rawValue))" }
  var roles: [String] = []
  while roles.count < depth {
    roles.append(role(element))
    guard roles.last != kAXWindowRole, let parent = attribute(element, kAXParentAttribute),
      CFGetTypeID(parent) == AXUIElementGetTypeID()
    else { break }
    element = parent as! AXUIElement
  }
  return roles.joined(separator: " < ")
}

func application(_ word: String?) -> AXUIElement {
  guard let word, let pid = pid_t(word) else { fail("expected a process id") }
  let app = AXUIElementCreateApplication(pid)
  AXUIElementSetMessagingTimeout(app, 2)
  return app
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard AXIsProcessTrusted() else { fail("no Accessibility permission") }

switch arguments.first {
case "at":
  guard arguments.count == 4, let x = Double(arguments[2]), let y = Double(arguments[3]) else { fail("at <pid> <x> <y>") }
  print(chain(application(arguments[1]), CGFloat(x), CGFloat(y)))

case "strip":
  let app = application(arguments.count > 1 ? arguments[1] : nil)
  guard let window = elements(app, kAXWindowsAttribute).first(where: { frame($0) != nil }), let bounds = frame(window)
  else { fail("the app has no window") }
  let buttons = [kAXCloseButtonAttribute, kAXZoomButtonAttribute, kAXMinimizeButtonAttribute]
    .filter { attribute(window, $0) != nil }
  print("window \(Int(bounds.width))×\(Int(bounds.height)), subrole \(attribute(window, kAXSubroleAttribute) as? String ?? "?"), buttons \(buttons)")
  for offset in [4, 12, 20, 27, 40] as [CGFloat] {
    // Runs of the same answer along the row, as offsets from the window's left edge.
    var runs: [(from: Int, to: Int, roles: String)] = []
    for x in stride(from: CGFloat(4), to: bounds.width - 2, by: 8) {
      let roles = chain(app, bounds.minX + x, bounds.minY + offset)
      if let last = runs.last, last.roles == roles {
        runs[runs.count - 1].to = Int(x)
      } else {
        runs.append((Int(x), Int(x), roles))
      }
    }
    print("  \(Int(offset)) points down:")
    for run in runs { print("    x \(run.from)…\(run.to): \(run.roles)") }
  }

case "icons":
  // Finder's Desktop is a scroll area of the application itself, holding a group of images.
  guard let finder = finderPID() else { fail("Finder is not running") }
  let app = application(String(finder))
  var pending = elements(app, kAXChildrenAttribute).filter { role($0) != kAXWindowRole && role($0) != kAXMenuBarRole }
  var depth = 0
  while !pending.isEmpty, depth < 4 {
    for element in pending where role(element) == kAXImageRole {
      if let bounds = frame(element) { print("\(Int(bounds.midX)) \(Int(bounds.midY))") }
    }
    pending = pending.flatMap { elements($0, kAXChildrenAttribute) }
    depth += 1
  }

default:
  fail("usage: ax-roles strip <pid> | at <pid> <x> <y> | icons")
}

/// Without AppKit: ask `pgrep`, which every Mac has.
func finderPID() -> pid_t? {
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
  process.arguments = ["-x", "Finder"]
  let pipe = Pipe()
  process.standardOutput = pipe
  guard (try? process.run()) != nil else { return nil }
  process.waitUntilExit()
  let text = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
  return text.split(separator: "\n").first.flatMap { pid_t($0) }
}
