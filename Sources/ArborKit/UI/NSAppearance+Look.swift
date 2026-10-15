import AppKit

extension NSAppearance {
  private var closest: NSAppearance.Name? {
    bestMatch(from: [.aqua, .darkAqua, .accessibilityHighContrastAqua, .accessibilityHighContrastDarkAqua])
  }

  var isDark: Bool { closest == .darkAqua || closest == .accessibilityHighContrastDarkAqua }

  /// With Increase Contrast on, macOS hands every view one of its high-contrast appearances.
  var increasesContrast: Bool {
    closest == .accessibilityHighContrastAqua || closest == .accessibilityHighContrastDarkAqua
  }
}
