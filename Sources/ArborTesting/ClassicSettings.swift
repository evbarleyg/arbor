import ArborCore

/// What went off by default when Arbor learnt to do less by itself (collab/QUESTIONS.md, Q29), for the tests that are about it or that
/// need it as a means. A plain `Harness()` is Arbor as it ships (docs/TESTING.md, "What ships is what is tested").
///
/// One chaining property for each option, named for the thing, in alphabetical order, and its line in `classic`.
extension Settings {
  /// The Desktop has a share of its own among docked windows: thirds at the second dock, a column after Arrange Windows.
  public var withDesktopColumn: Settings {
    var settings = self
    settings.desktopColumn = true
    return settings
  }

  /// The same, from what ships.
  public static var withDesktopColumn: Settings { Settings().withDesktopColumn }

  /// The whole map of shortcuts instead of the nine (`shortcuts`; docs/KEYBOARD.md).
  public var withEveryKey: Settings {
    var settings = self
    settings.shortcuts = "all"
    return settings
  }

  /// The same, from what ships.
  public static var withEveryKey: Settings { Settings().withEveryKey }

  /// Floating windows are kept on the Desktop, where docked windows push them aside and squeeze them, as until Q20.
  public var withFloatsMakingWay: Settings {
    var settings = self
    settings.floatingWindowsMakeWay = true
    return settings
  }

  /// The same, from what ships.
  public static var withFloatsMakingWay: Settings { Settings().withFloatsMakingWay }

  /// A docked window too large for its place goes out of view and a tile stands there, as until board 0.26 (`windowsThatDoNotFit`, F69). A test says
  /// `@Test(.withTiles)` or `@Suite(.withTiles)` at its head, which reaches every harness it makes (`Harness.makesTiles`).
  public var withTiles: Settings {
    var settings = self
    settings.windowsThatDoNotFit = "tile"
    return settings
  }

  /// The same, from what ships.
  public static var withTiles: Settings { Settings().withTiles }

  /// Arbor as the first build shipped it: all of them.
  public static var classic: Settings {
    Settings()
      .withDesktopColumn
      .withEveryKey
      .withFloatsMakingWay
      .withTiles
  }
}
