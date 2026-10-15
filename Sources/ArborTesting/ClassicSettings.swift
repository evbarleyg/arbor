import ArborCore
import ArborKit

/// What Arbor shipped switched on in its first build and ships without since (collab/QUESTIONS.md, Q29): each thing by itself, and all of
/// them together. docs/TESTING.md, "Tests and the defaults", says which test takes which:
///
/// - a test **about** an option names it, `Harness(settings: .withRing)`: with no line to draw it would prove nothing;
/// - a test about something else whose means or numbers are the first build's takes `.classic`, if rewriting it would change what it proves;
/// - every other test follows what ships: `Harness()`.
///
/// So that the options do not rot, `make test-classic` runs every test that gives a `Harness` no settings on `classic`
/// (`Harness.settingsWhenNoneAreGiven`). In a scenario the line `classic` does what `.classic` does in a test.
///
/// One property to an option, in the order of the alphabet, and one line for it in `classic`. They chain: `Settings.withRing.withMotion`.
extension Settings {
  /// Arbor as the first build shipped it.
  public static var classic: Settings { Settings().classic }

  /// These settings, with all that the first build shipped switched on.
  public var classic: Settings {
    self
      .withBackdrop
      .withButtons
      .withDesktopColumn
      .withEveryKey
      .withFloatsMakingWay
      .withMotion
      .withRing
  }

  public static var withBackdrop: Settings { Settings().withBackdrop }
  public static var withButtons: Settings { Settings().withButtons }
  public static var withDesktopColumn: Settings { Settings().withDesktopColumn }
  public static var withEveryKey: Settings { Settings().withEveryKey }
  public static var withFloatsMakingWay: Settings { Settings().withFloatsMakingWay }
  public static var withMotion: Settings { Settings().withMotion }
  public static var withRing: Settings { Settings().withRing }

  /// The surface behind docked windows as the first build drew it (F15, F36): the wallpaper a quarter darker, a hairline round the Desktop.
  public var withBackdrop: Settings {
    var settings = self
    settings.dimBehindArranged = 0.25
    settings.desktopEdge = 0.05
    return settings
  }

  /// The row of buttons in the menu bar (F10).
  public var withButtons: Settings {
    var settings = self
    settings.menuBarControls = true
    return settings
  }

  /// The Desktop has a share of its own among docked windows: thirds at the second dock, a column after Arrange Windows.
  public var withDesktopColumn: Settings {
    var settings = self
    settings.desktopColumn = true
    return settings
  }

  /// The whole map of shortcuts instead of the nine (`shortcuts`; docs/KEYBOARD.md).
  public var withEveryKey: Settings {
    var settings = self
    settings.shortcuts = "all"
    return settings
  }

  /// Floating windows are kept on the Desktop, where docked windows push them aside and squeeze them, as until Q20.
  public var withFloatsMakingWay: Settings {
    var settings = self
    settings.floatingWindowsMakeWay = true
    return settings
  }

  /// The stage, on which stand-ins travel while the real windows go to their places under it (F02), for as long as it played in
  /// the first build.
  public var withMotion: Settings {
    var settings = self
    settings.animationDuration = Settings.usualMotionDuration
    return settings
  }

  /// The line round the focused window (F37).
  public var withRing: Settings {
    var settings = self
    settings.focusRing = true
    return settings
  }
}

extension Harness {
  /// Switches an option on in a harness that a suite's own factory has made, for the one test of the suite that is about it:
  /// `h.switchOn(\.withRing)`. As a person would: the settings are applied to an Arbor that may be running already, and
  /// where a settings file is wired they go into it first, or the next command that changes a setting would read them away.
  public func switchOn(_ option: KeyPath<Settings, Settings>) {
    let updated = controller.settings[keyPath: option]
    try? controller.saveSettings?(controller.settings, updated)
    controller.apply(settings: updated)
  }
}
