import AppKit
import ArborCore

/// Converts between AppKit's coordinates (origin at the bottom-left of the
/// primary display, y up) and Arbor's global coordinates (origin at the
/// top-left of the primary display, y down). The conversion is its own inverse.
@MainActor
enum ScreenGeometry {
  static var primaryHeight: CGFloat { NSScreen.screens.first?.frame.height ?? 0 }

  static func global(fromAppKit rect: NSRect) -> CGRect {
    CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
  }

  static func appKit(fromGlobal rect: CGRect) -> NSRect {
    NSRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
  }

  static func global(fromAppKit point: NSPoint) -> CGPoint {
    CGPoint(x: point.x, y: primaryHeight - point.y)
  }

  /// `rect` in the coordinates of a view or layer that fills `container` (both global): the origin
  /// is the container's bottom-left corner and y grows upward.
  static func local(fromGlobal rect: CGRect, in container: CGRect) -> CGRect {
    CGRect(x: rect.minX - container.minX, y: container.maxY - rect.maxY, width: rect.width, height: rect.height)
  }

  /// The other way: `rect` is in the coordinates of a view or layer that fills `container`.
  static func global(fromLocal rect: CGRect, in container: CGRect) -> CGRect {
    CGRect(x: rect.minX + container.minX, y: container.maxY - rect.maxY, width: rect.width, height: rect.height)
  }

  static func screen(for display: DisplayID) -> NSScreen? {
    NSScreen.screens.first { displayID(for: $0) == display }
  }

  static func displayID(for screen: NSScreen) -> DisplayID {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    else { return DisplayID("unknown") }
    return displayID(for: CGDirectDisplayID(number.uint32Value))
  }

  static func displayID(for directID: CGDirectDisplayID) -> DisplayID {
    if let uuid = CGDisplayCreateUUIDFromDisplayID(directID)?.takeRetainedValue(),
      let text = CFUUIDCreateString(nil, uuid)
    {
      return DisplayID(text as String)
    }
    return DisplayID("display-\(directID)")
  }

  /// Whether the screen is a laptop's or an iMac's own display.
  static func isBuiltIn(_ screen: NSScreen) -> Bool {
    guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    else { return false }
    return CGDisplayIsBuiltin(CGDirectDisplayID(number.uint32Value)) != 0
  }
}
