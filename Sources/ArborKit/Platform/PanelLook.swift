import ArborCore
import CoreGraphics

/// How Arbor's panels look, as far as that can be decided without a screen: one table of corners, what lies between
/// macOS's material and the words, and the inks the words are in. The UI draws with these and decides nothing
/// (`UI/PanelGround.swift`), so the numbers are covered by tests that run anywhere (`PanelLookTests`).
///
/// **The measure** (the product owner's, 2026-10-15): in the look that ships, over the worst there is behind a panel (a
/// saturated red, a saturated blue, white, black), words a person must read to act stand out by at least 4.5 to 1 on
/// a picture, all other words by at least 3, and nothing is drawn as text below that.
public enum PanelLook {
  // MARK: Corners

  /// The one table of corner radii. What stands for a window or lies round one (a tile, a card, the drop preview, the
  /// focus ring, the surface) is not in it: that takes the radius of real windows (`TileMetrics.cornerRadius`, and in
  /// the UI `ContinuousCorners.windowRadius` for the macOS it runs on).
  public enum Corner {
    /// The panel of shortcuts, Go to…, the field for a name, the minimap. About what macOS 26 gives its own.
    public static let panel: CGFloat = 20

    /// The line on screen: a capsule while it is one line of text, and a panel's corners when it wraps.
    public static func line(height: CGFloat) -> CGFloat { min(height / 2, panel) }

    /// For what lies `inset` points inside a corner of `outer`: the two curves run side by side.
    public static func inside(_ outer: CGFloat, inset: CGFloat) -> CGFloat { max(outer - inset, 2) }
  }

  // MARK: The ground

  /// What is laid over the material, under the words. A material takes on about half of what lies behind the panel:
  /// over a red window it is red, and in the dark look over a white one it is a middling grey, on which no ink can be
  /// read. This takes half of that away again. The panel still says what it floats over; the words no longer depend
  /// on it.
  public static func veil(isDark: Bool) -> RGBA {
    isDark ? RGBA(white: 0.12, alpha: 0.6) : RGBA(white: 0.93, alpha: 0.5)
  }

  // MARK: Ink

  public enum Ink: CaseIterable, Sendable {
    /// Words a person must read to act: a shortcut, a window's title, what the line says.
    case main
    /// All other words: headings over groups of rows, notes beside a title, a placeholder under a heading.
    case second
  }

  /// Black or white, as translucent as it may be. Not macOS's secondary and tertiary label colours: drawn by hand those
  /// are greys that stay as they are whatever the ground has become (seen on a hosted Mac: 1.1 to 2.4 to 1 over a red
  /// window). Nor a red for what is wrong: no red can be read on red. A problem is said in the main ink.
  public static func ink(_ ink: Ink, isDark: Bool, increasesContrast: Bool = false) -> RGBA {
    let alpha: Double
    switch (ink, increasesContrast) {
    case (.main, false): alpha = 0.85
    case (.main, true): alpha = 1
    case (.second, false): alpha = 0.65
    case (.second, true): alpha = 0.85
    }
    return RGBA(white: isDark ? 1 : 0, alpha: alpha)
  }

  /// The ink on a selected row filled with `fill`: white, as everywhere in macOS, wherever white can be read, and else
  /// whichever of black and white reads better (a yellow or a green accent colour).
  public static func ink(onSelection fill: RGBA) -> RGBA {
    RGBA.white.contrast(with: fill) >= 4.5 ? .white : fill.ink
  }

  /// The field for a name. What counts is what words are for: the heading is the field's only label, and the note alone says
  /// which space gets the name, so both are read to act (in the second ink 4.1 to 1 in the dark look over a white window, by the
  /// judges' ruler on a hosted Mac). The heading lets the placeholder off.
  public enum NameField {
    public static let heading = Ink.main
    public static let note = Ink.main
    public static let placeholder = Ink.second
  }

  /// The line under Go to…'s field. Not macOS's separator colour, one grey whatever the ground: with Reduce Transparency that stood out
  /// by 1.01 to 1.
  public static func rule(isDark: Bool, increasesContrast: Bool = false) -> RGBA {
    RGBA(white: isDark ? 1 : 0, alpha: increasesContrast ? 0.6 : 0.25)
  }

  // MARK: The minimap

  /// How strong things on the minimap are. The lines' are shares of black or white, whichever the look's ink is.
  public enum Map {
    /// Of its app's colour, in a window out of view: still there, only fainter.
    public static let fillOutOfView = 0.45

    /// Of the line round a window; nil: it has none. Fainter must not mean gone: at 0.3 a window of the ground's own brightness was
    /// still not there, 1.02 to 1 its fill and 1.9 its line in the light look over black (the judges' ruler, on a hosted Mac). With
    /// Increase Contrast every window has a line, and a whole one.
    public static func line(isInView: Bool, increasesContrast: Bool) -> Double? {
      if increasesContrast { return 1 }
      return isInView ? nil : 0.6
    }

    /// Of the Desktop's outline.
    public static func desktopLine(isInView: Bool, increasesContrast: Bool) -> Double {
      if increasesContrast { return 1 }
      return isInView ? 0.6 : 0.3
    }
  }

  // MARK: Lines on other apps' windows

  /// With Increase Contrast: the lines outside the accent's, each a point wide, from the outside in. Of two tones R to 1 apart the better
  /// one stands out from the worst ground by the root of R: the accent and white, 4.6 apart in the dark look, left every ground of
  /// middling brightness under 3 (a bright red window 2.9, a cyan one 2.8). Black and white are 21 apart: 4.58 on anything.
  public static let strongLines: [RGBA] = [.black, .white]
}
