import ArborCore

/// What the settings window says in colour, as far as that can be decided without a screen. The UI draws with these and decides
/// nothing (`UI/SettingsViews.swift`), so the numbers are covered by tests that run anywhere (`SettingsLookTests`).
///
/// As on the panels (`PanelLook`), what is wrong is said in the ink everything else is in. macOS's orange and red are
/// colours for shapes: as words of ten points on a form's card they came to 2.0 and 3.1 to 1 on a hosted Mac, where 4.5 is
/// asked. So the colour goes into a mark before the words, and the mark has a shape of its own, for whoever cannot tell the colours apart.
public enum SettingsLook {
  public enum Mark: CaseIterable, Sendable {
    /// Something to mind: it works, but perhaps not as meant.
    case caution
    /// What was asked for has not been done: a change is refused, a file is not read.
    case refusal

    /// The name of one of macOS's symbols.
    public var symbol: String {
      switch self {
      case .caution: "exclamationmark.triangle.fill"
      case .refusal: "exclamationmark.circle.fill"
      }
    }
  }

  /// Darker than macOS's own in the light look, where those stand out from a card by 2.0 and 3.2 to 1; in the dark look its orange,
  /// and the lighter of its reds.
  public static func colour(of mark: Mark, isDark: Bool) -> RGBA {
    switch (mark, isDark) {
    case (.caution, false): RGBA(red: 196.0 / 255, green: 85.0 / 255, blue: 0)
    case (.caution, true): RGBA(red: 1, green: 159.0 / 255, blue: 10.0 / 255)
    case (.refusal, false): RGBA(red: 200.0 / 255, green: 30.0 / 255, blue: 30.0 / 255)
    case (.refusal, true): RGBA(red: 1, green: 105.0 / 255, blue: 97.0 / 255)
    }
  }
}
