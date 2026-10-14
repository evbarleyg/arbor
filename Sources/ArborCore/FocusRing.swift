import CoreGraphics
import Foundation

/// The colour of the focus ring, as `focusRingColour` in settings.json spells it.
public enum FocusRingColour: Equatable, Sendable {
  /// The accent colour chosen in System Settings → Appearance.
  case accent
  /// sRGB components, each 0 to 1.
  case rgba(red: Double, green: Double, blue: Double, alpha: Double)

  /// Reads `accent`, `#RRGGBB` or `#RRGGBBAA` (case does not matter). Nil for anything else.
  public init?(text: String) {
    let word = text.trimmingCharacters(in: .whitespaces).lowercased()
    if word == "accent" {
      self = .accent
      return
    }
    guard word.hasPrefix("#") else { return nil }
    let digits = word.dropFirst()
    // `UInt32(_:radix:)` alone would also accept a sign.
    guard digits.count == 6 || digits.count == 8, digits.allSatisfy(\.isHexDigit),
      let value = UInt32(digits, radix: 16)
    else { return nil }
    let rgba = digits.count == 6 ? (value << 8) | 0xFF : value
    func component(_ shift: UInt32) -> Double { Double((rgba >> shift) & 0xFF) / 255 }
    self = .rgba(red: component(24), green: component(16), blue: component(8), alpha: component(0))
  }
}

/// How the focus ring is drawn: the `focusRing…` settings, checked and clamped.
public struct FocusRingOptions: Equatable, Sendable {
  /// The line's thickness in points.
  public var width: CGFloat
  public var colour: FocusRingColour
  /// The radius of the windows' own corners, which the line follows. 0 leaves it to the view, which
  /// knows which macOS it runs on.
  public var radius: CGFloat

  public init(width: CGFloat = 3, colour: FocusRingColour = .accent, radius: CGFloat = 0) {
    self.width = width
    self.colour = colour
    self.radius = radius
  }
}

extension Settings {
  /// Nil when the ring is switched off.
  public var focusRingOptions: FocusRingOptions? {
    guard focusRing else { return nil }
    return FocusRingOptions(
      width: CGFloat(min(max(focusRingWidth, 1), 12)),
      colour: FocusRingColour(text: focusRingColour) ?? .accent,
      radius: CGFloat(min(max(focusRingRadius, 0), 60)))
  }

  /// What is wrong with `focusRingColour`, for the log; nil when it can be read.
  public var focusRingColourProblem: String? {
    // A colour in settings.json that cannot be read has given way to the default by the time anyone
    // asks (`SettingsSchema.sanitize`), which left this note.
    if let noted = valueProblems.first(where: { $0.hasPrefix("focusRingColour: ") }) { return noted }
    guard FocusRingColour(text: focusRingColour) == nil else { return nil }
    return "focusRingColour \"\(focusRingColour)\" is not accent, #RRGGBB or #RRGGBBAA; using accent"
  }
}

/// Where the focus ring's line goes.
public enum FocusRingGeometry {
  /// The outer edge of a line `width` thick around `window`.
  ///
  /// The line lies outside the window, so that it covers none of its content, as far as there is `room`
  /// beside it (the gap between docked windows); the rest of its thickness lies inside. Beyond `bounds` (the
  /// display minus the menu bar and the Dock) it could not be seen, so it stays within them on every side
  /// on which the window itself does: a window that fills the screen has its ring inside.
  /// Nil when the window is too small for a line around it to mean anything.
  public static func outerFrame(
    around window: CGRect, width: CGFloat, room: CGFloat, within bounds: CGRect
  ) -> CGRect? {
    guard window.width >= 4 * width, window.height >= 4 * width else { return nil }
    let outset = min(width, max(room, 0))
    let minX = max(window.minX - outset, min(bounds.minX, window.minX))
    let minY = max(window.minY - outset, min(bounds.minY, window.minY))
    let maxX = min(window.maxX + outset, max(bounds.maxX, window.maxX))
    let maxY = min(window.maxY + outset, max(bounds.maxY, window.maxY))
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }
}
