import ArborCore

/// The moving part of `OverlayPresenter`: see `StageDirector`, `Stage` and `WindowPictures`.
extension AppKitOverlays {
  public func animate(_ transition: Transition) {
    director.play(transition, surface: backdrops.model(on: transition.display))
  }

  public func finishAnimations() { director.finish() }

  public func rehearse(_ rehearsal: Rehearsal) { director.rehearse(rehearsal) }

  /// Called when what was got ready, or was not, no longer fits: with Reduce Motion on there is no motion to get ready for,
  /// and it has just been switched on or off.
  public var onRehearsalOutdated: (() -> Void)? {
    get { director.onDisplayOptionsChanged }
    set { director.onDisplayOptionsChanged = newValue }
  }

  /// The `windowPictures` setting: whether stand-ins may be pictures of their windows.
  public var takesPicturesOfWindows: Bool {
    get { director.pictures.isWanted }
    set { director.pictures.isWanted = newValue }
  }

  /// Tells the overlays that the user turned to another window, which is a good moment to take
  /// pictures: of the window they left and of the one they are about to work with.
  public func windowFocused(_ window: WindowID) { director.windowFocused(window) }

  /// Tells the overlays that a display was laid out, so windows may have appeared or changed size.
  public func windowsWereLaidOut() { director.windowsWereLaidOut() }
}
