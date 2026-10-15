import AppKit
import ApplicationServices

func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
  var value: CFTypeRef?
  return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
}
func text(_ element: AXUIElement, _ name: String) -> String { (attribute(element, name) as? String) ?? "" }
func frame(_ element: AXUIElement) -> String {
  var point = CGPoint.zero, size = CGSize.zero
  guard let position = attribute(element, kAXPositionAttribute), let extent = attribute(element, kAXSizeAttribute),
    AXValueGetValue(position as! AXValue, .cgPoint, &point), AXValueGetValue(extent as! AXValue, .cgSize, &size)
  else { return "- - - -" }
  return "\(Int(point.x)) \(Int(point.y)) \(Int(size.width)) \(Int(size.height))"
}
func walk(_ element: AXUIElement, _ depth: Int) {
  let role = text(element, kAXRoleAttribute)
  // The Dock's own row of icons is not what is asked about.
  if role == "AXList" && depth <= 1 { return }
  print(
    "\(depth) \(role) \(text(element, kAXSubroleAttribute).isEmpty ? "-" : text(element, kAXSubroleAttribute)) "
      + "[\(text(element, kAXIdentifierAttribute))] \"\(text(element, kAXTitleAttribute))\" \"\(text(element, kAXDescriptionAttribute))\" \(frame(element))")
  guard depth < 9, let children = attribute(element, kAXChildrenAttribute) as? [AXUIElement] else { return }
  for child in children { walk(child, depth + 1) }
}
guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
  print("no Dock")
  exit(1)
}
walk(AXUIElementCreateApplication(dock.processIdentifier), 0)
