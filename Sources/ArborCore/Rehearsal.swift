/// What a presenter is told ahead of the next motion (`OverlayPresenter.rehearse`): where it may play and whose windows
/// may be in it.
///
/// A motion begins before the real windows move, so whatever the presenter has to make or look up for it is time
/// between the key and the first move. On a Mac that is a panel over the whole display, the picture behind it, and an
/// icon and a colour for every app on screen: two seconds, measured, the first time, and milliseconds ever after.
public struct Rehearsal: Equatable, Sendable {
  /// What a stand-in's colour and icon are looked up by (`Transition.Item.pid` and `bundleID`).
  public struct App: Hashable, Sendable {
    public var pid: Int32
    public var bundleID: String?

    public init(pid: Int32, bundleID: String?) {
      self.pid = pid
      self.bundleID = bundleID
    }
  }

  public var displays: [DisplayID]
  public var apps: [App]

  public init(displays: [DisplayID], apps: [App]) {
    self.displays = displays
    self.apps = apps
  }
}

extension Transition.Item {
  public var app: Rehearsal.App { Rehearsal.App(pid: pid, bundleID: bundleID) }
}
