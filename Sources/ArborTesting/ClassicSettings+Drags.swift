import ArborCore

extension Settings {
  /// These settings with a plain drag docking wherever there is a target, and ⌘ turning that off, as in the first build
  /// (`dragDocks` "always"). For tests about that setting. A test that merely docks by a drag needs none: the harnesses'
  /// hand holds what Arbor is set to ask for (`FakeWindowSystem.drag`, docs/TESTING.md).
  public var withPlainDragsDocking: Settings {
    var settings = self
    settings.dragDocks = DragDocks.always.rawValue
    return settings
  }

  public static var withPlainDragsDocking: Settings { Settings().withPlainDragsDocking }
}
