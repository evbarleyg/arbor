import ArborCore

/// What went off by default when Arbor learnt to do less by itself (collab/QUESTIONS.md, Q29), for the tests that are about it or that
/// need it as a means. A plain `Harness()` is Arbor as it ships (docs/TESTING.md, "What ships is what is tested").
///
/// One chaining property for each option, named for the thing, in alphabetical order, and its line in `classic`.
extension Settings {
  /// The whole map of shortcuts instead of the nine (`shortcuts`; docs/KEYBOARD.md).
  public var withEveryKey: Settings {
    var settings = self
    settings.shortcuts = "all"
    return settings
  }

  /// The same, from what ships.
  public static var withEveryKey: Settings { Settings().withEveryKey }

  /// Arbor as the first build shipped it: all of them.
  public static var classic: Settings {
    Settings()
      .withEveryKey
  }
}
