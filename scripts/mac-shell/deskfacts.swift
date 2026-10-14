// Facts about the Desktop of this Mac, for `PointerSurface.under` and `DesktopProbe` (F60, F05), which were written from the window
// list of an idle cloud Mac. Run by desktop-facts.sh.
//
// It only reads: the window server's list, four preferences, and three questions to Finder through Accessibility. It moves no
// pointer, presses no key, starts, quits and changes nothing, and writes no file.
//
// Its output is meant to be pasted where others read it, so it says little about the person: no window titles, no window of the
// ordinary levels but their number, and no name of a process but those below, which every Mac has. Anything else is "other".
import AppKit
import ApplicationServices

let everyMacHas: Set<String> = [
  "Dock", "Window Server", "Finder", "Control Center", "Notification Center", "SystemUIServer", "Spotlight", "WindowManager",
  "TextInputMenuAgent", "Wallpaper", "WallpaperAgent", "loginwindow", "Siri", "AirPlayUIAgent", "universalAccessAuthWarn",
]

func heading(_ text: String) { print("\n== \(text)") }

struct Listed {
  var layer: Int
  var frame: CGRect
  var alpha: Double
  var owner: String
}

print("macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")

heading("displays (x y w h)")
var ids = [CGDirectDisplayID](repeating: 0, count: 16)
var count: UInt32 = 0
CGGetActiveDisplayList(UInt32(ids.count), &ids, &count)
let displays = ids.prefix(Int(count)).map { CGDisplayBounds($0) }
for display in displays {
  print(Int(display.minX), Int(display.minY), Int(display.width), Int(display.height))
}

let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
let windows = list.compactMap { info -> Listed? in
  guard let bounds = info[kCGWindowBounds as String] as? NSDictionary,
    let frame = CGRect(dictionaryRepresentation: bounds as CFDictionary)
  else { return nil }
  let owner = info[kCGWindowOwnerName as String] as? String ?? ""
  return Listed(
    layer: info[kCGWindowLayer as String] as? Int ?? 0, frame: frame, alpha: info[kCGWindowAlpha as String] as? Double ?? 1,
    owner: everyMacHas.contains(owner) ? owner : "other")
}

func show(_ window: Listed) {
  print(
    window.layer, Int(window.frame.minX), Int(window.frame.minY), Int(window.frame.width), Int(window.frame.height),
    String(format: "%.2f", window.alpha), window.owner)
}

heading("on screen above the palettes, in the list's order (level x y w h alpha owner)")
for window in windows where window.layer > 3 { show(window) }
heading("on screen below the windows, in the list's order")
for window in windows where window.layer < 0 { show(window) }
heading("on screen at levels 0 to 3")
print(windows.filter { (0...3).contains($0.layer) }.count, "windows")

heading("preferences (read; \"-\" means not set)")
for (domain, key) in [
  ("com.apple.WindowManager", "EnableStandardClickToShowDesktop"), ("com.apple.WindowManager", "StandardHideDesktopIcons"),
  ("com.apple.WindowManager", "GloballyEnabled"), ("com.apple.finder", "CreateDesktop"),
] {
  let value = CFPreferencesCopyAppValue(key as CFString, domain as CFString)
  print(domain, key, value.map { "\($0)" } ?? "-")
}

// Where nothing of level 0 or more is, apart from what covers a whole display.
heading("a place where the wallpaper shows")
func isBare(_ point: CGPoint, on display: CGRect) -> Bool {
  !windows.contains {
    $0.alpha > 0 && $0.layer >= 0 && $0.frame.contains(point) && !($0.layer > 0 && $0.frame.contains(display))
  }
}
var bare: CGPoint?
search: for display in displays {
  for y in stride(from: display.minY + 60, to: display.maxY - 120, by: 40) {
    for x in stride(from: display.minX + 20, to: display.maxX - 20, by: 40) where isBare(CGPoint(x: x, y: y), on: display) {
      bare = CGPoint(x: x, y: y)
      break search
    }
  }
}
guard let bare else {
  print("none: windows cover every display. The questions to Finder are left out")
  exit(0)
}
print(Int(bare.x), Int(bare.y))
print("below the windows there, by level:", windows.filter { $0.layer < 0 && $0.alpha > 0 && $0.frame.contains(bare) }.map(\.layer).sorted(by: >))

heading("what Finder says")
guard AXIsProcessTrusted() else {
  print("this terminal has no Accessibility permission, so Finder cannot be asked")
  exit(0)
}
guard let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
  print("Finder is not running")
  exit(0)
}
print("Finder is the frontmost app:", finder.isActive)

func timed<T>(_ body: () -> T) -> (T, String) {
  let start = DispatchTime.now().uptimeNanoseconds
  let result = body()
  return (result, String(format: "%.1f ms", Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000))
}
func attribute(_ element: AXUIElement, _ name: String) -> (AXError, CFTypeRef?) {
  var value: CFTypeRef?
  let error = AXUIElementCopyAttributeValue(element, name as CFString, &value)
  return (error, value)
}

let app = AXUIElementCreateApplication(finder.processIdentifier)
AXUIElementSetMessagingTimeout(app, 0.25)
var found: AXUIElement?
let (atPosition, took) = timed { AXUIElementCopyElementAtPosition(app, Float(bare.x), Float(bare.y), &found) }
print("element at that place: AXError \(atPosition.rawValue), \(took)")
var element = found
var depth = 0
while let current = element, depth < 6 {
  AXUIElementSetMessagingTimeout(current, 0.25)
  let ((roleError, role), roleTook) = timed { attribute(current, kAXRoleAttribute) }
  let ((parentError, parent), parentTook) = timed { attribute(current, kAXParentAttribute) }
  print("  role \(role as? String ?? "-") (AXError \(roleError.rawValue), \(roleTook)); parent: AXError \(parentError.rawValue), \(parentTook)")
  element = parent.flatMap { CFGetTypeID($0) == AXUIElementGetTypeID() ? ($0 as! AXUIElement) : nil }
  depth += 1
}

let ((focusError, focused), focusTook) = timed { attribute(app, kAXFocusedUIElementAttribute) }
print("focused element: AXError \(focusError.rawValue), \(focusTook)")
if let focused, CFGetTypeID(focused) == AXUIElementGetTypeID() {
  print("  role \(attribute(focused as! AXUIElement, kAXRoleAttribute).1 as? String ?? "-")")
}
