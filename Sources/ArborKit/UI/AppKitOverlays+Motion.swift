import ArborCore

/// The moving part of `OverlayPresenter`: see `StageDirector`, `Stage` and `WindowPictures`.
extension AppKitOverlays {
  public func animate(_ transition: Transition) {
    director.play(transition, surface: backdrops.model(on: transition.display))
  }

  public func finishAnimations() { director.finish() }

  /// The recorder of traces, as `AXWindowSystem` has it: while it records, each stage logs its own frames.
  public var recorder: TraceRecorder? {
    get { director.recorder }
    set { director.recorder = newValue }
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
