import ArborCore
import CoreGraphics
import Foundation

/// The focus ring: a line around the window that has the keyboard (`FocusRingModel`).
///
/// Which window that is comes from `system.focusedWindow()` every time the ring is worked out, not from
/// remembered `windowFocused` events: an app in the background reports focus changes too, and only the
/// window system knows which app is in front. Events only say when to look again.
///
/// A relayout works the ring out as part of the display's scene. Everything else that can move it (focus, the
/// focused window moving by itself, the mouse button coming up) sends a fresh scene to the displays
/// whose ring is out of date, at most two of them, and moves no window.
extension Controller {
  struct FocusRingState {
    /// The display that shows the ring, and the ring; both nil when there is none.
    var display: DisplayID?
    var model: FocusRingModel?
    /// What each display was last told to draw. A display without a ring has no entry.
    var shown: [DisplayID: FocusRingModel] = [:]
    /// The window that had the ring when it was last worked out, apart from the times the mouse kept it away:
    /// a ring that returns to its window after a drag has not moved.
    var lastWindow: WindowID?
    var pulse = 0
    /// Until then, the keyboard moving to another window is Arbor's doing.
    var pulsesUntil: Date?
    /// The mouse is moving or resizing something, and the ring stays away until the button is up.
    var isHeldBack = false
    /// `display` and `model` are current, so scenes put together now need not ask the window system again.
    var isWorkedOut = false
  }

  enum FocusRingCause {
    /// The keyboard may have moved.
    case focus
    /// Frames may have changed.
    case geometry
  }

  /// How long after a command or a camera move a change of focus still counts as caused by it. The
  /// window system reports the focus changes Arbor asks for a moment later.
  static let focusRingPulseWindow: TimeInterval = 0.5

  /// Watches the controller's own changes. Called once, from `init`.
  func startFocusRing() {
    observe { [weak self] change in
      guard let self else { return }
      switch change {
      case .layout:
        // The display just laid out has its ring already. The ring may have left another one.
        self.showFocusRing()
      case .focus:
        self.keyboardFocusMoved()
      case .lifecycle:
        if !self.isRunning {
          self.scheduler.cancel("focus-ring")
          self.scheduler.cancel("focus-ring-again")
          self.focusRing = FocusRingState()
        }
      default:
        break
      }
    }
  }

  public func keyboardFocusMoved() {
    notify(.keyboard)
    // Nothing is asked of the window system during a pause.
    guard isRunning else { return }
    // One question for the two who need the answer. It goes to the app in front, which answers on its main thread, and this is called
    // three times within some thirty milliseconds when a click brings an app forward: just when the app has the press itself to see to.
    let focused = system.focusedWindow()
    noteFocus(focused)
    guard settings.focusRing else { return }
    refreshFocusRing(.focus, focused: focused)
    // macOS does not change everything at once when the keyboard moves, and an event can arrive before the window
    // system's answer has changed. A ring left on the wrong window is worse than none, so look once more.
    scheduler.schedule("focus-ring-again", after: 0.25) { [weak self] in self?.refreshFocusRing(.focus) }
  }

  /// A command is about to run or the camera to move: if the ring goes to another window now, it flashes.
  func expectFocusToMove() {
    focusRing.pulsesUntil = now().addingTimeInterval(Self.focusRingPulseWindow)
  }

  /// Called for every `windowChanged`: the ring follows its window when something other than a relayout
  /// moves it (the user, with the keyboard or another tool; the app itself; a late answer to a frame Arbor set).
  func focusRingFollows(_ window: WindowSnapshot) {
    guard let model = focusRing.model, model.window == window.id, model.frame != window.frame else { return }
    refreshFocusRing(.geometry)
  }

  /// The ring in `displayID`'s scene. Called while the scene is put together.
  func focusRingModel(on displayID: DisplayID) -> FocusRingModel? {
    if !focusRing.isWorkedOut { workOutFocusRing(.geometry, focused: system.focusedWindow()) }
    let model = focusRing.display == displayID ? focusRing.model : nil
    focusRing.shown[displayID] = model
    return model
  }

  func refreshFocusRing(_ cause: FocusRingCause) { refreshFocusRing(cause, focused: system.focusedWindow()) }

  /// `focused`: the window system's answer, for a caller that has it already. Not looked at where there is no ring to draw anyway.
  private func refreshFocusRing(_ cause: FocusRingCause, focused: @autoclosure () -> WindowID?) {
    guard isRunning else { return }
    workOutFocusRing(cause, focused: focused())
    showFocusRing()
  }

  /// Sends a fresh scene to every display that shows something other than `focusRing.model` says.
  private func showFocusRing() {
    focusRing.isWorkedOut = true
    defer { focusRing.isWorkedOut = false }
    for (displayID, layout) in layouts.sorted(by: { $0.key < $1.key })
    where focusRing.shown[displayID] != (focusRing.display == displayID ? focusRing.model : nil) {
      overlays.update(display: displayID, scene: overlayScene(for: layout, on: displayID))
    }
  }

  /// Decides where the ring is now.
  private func workOutFocusRing(_ cause: FocusRingCause, focused: @autoclosure () -> WindowID?) {
    focusRing.display = nil
    focusRing.model = nil
    guard let options = settings.focusRingOptions else {
      focusRing.isHeldBack = false
      return
    }

    // Accessibility reports a window's moves well behind the pointer, so a ring that followed a window being
    // dragged or resized would trail it. It leaves at the first sign of that and returns when the button is
    // up. A click that only moves the keyboard is not such a sign: the ring goes to the clicked
    // window at once, not when the button is released.
    let mouseIsBusy = drag != nil || edgeResize != nil || system.isMouseButtonDown()
    switch cause {
    case .geometry: focusRing.isHeldBack = mouseIsBusy
    case .focus: focusRing.isHeldBack = focusRing.isHeldBack && mouseIsBusy
    }
    if focusRing.isHeldBack {
      scheduleFocusRingReturn()
      return
    }
    // One frame at a time: peek's outline says where letting go leads, in the same colour, and two of them ask the question
    // each is there to answer. Like the mouse it only keeps the ring away: back round its window, it has not moved.
    if peeking?.peek.shownOutline != nil { return }

    let previous = focusRing.lastWindow
    focusRing.lastWindow = nil
    // Until something is docked the person has not asked Arbor for anything, and after Float All
    // Windows they have asked for a normal Mac. A line round every focused window from the first
    // second after launch would change the look of the whole Mac uninvited. Docked anywhere counts: the
    // ring must not come and go as the keyboard moves between displays. Asked first, so that a Mac with
    // nothing docked pays no Accessibility call for a change of focus.
    guard workspaces.values.contains(where: { !$0.tree.allWindows.isEmpty }) else { return }
    guard let id = windowShownAsFocused(focused()), isManaged(id), let snapshot = windows[id], snapshot.isPresent,
      !parked.contains(id), let displayID = workspaceID(containing: id), let display = display(displayID),
      let workspace = workspaces[displayID]
    else { return }
    let isDocked = workspace.isDocked(id)
    // Docked but without a frame: outside the view, inside a tile, or a tab behind another.
    if isDocked, layouts[displayID]?.windowFrames[id] == nil, !isLetBe(id) { return }
    guard
      let outerFrame = FocusRingGeometry.outerFrame(
        around: snapshot.frame, width: options.width, room: isDocked ? CGFloat(self.options(for: displayID).gap) : options.width,
        within: display.visibleFrame)
    else { return }

    if previous != id, let deadline = focusRing.pulsesUntil, now() <= deadline {
      focusRing.pulse += 1
    }
    focusRing.lastWindow = id
    focusRing.display = displayID
    focusRing.model = FocusRingModel(
      window: id, frame: snapshot.frame, outerFrame: outerFrame, width: options.width, radius: options.radius,
      colour: options.colour, pulse: focusRing.pulse)
  }

  /// Looks every tenth of a second whether the mouse has let go. No event says so in every case: the
  /// end of a seam drag is not reported at all, and dropping a floating window causes no relayout.
  private func scheduleFocusRingReturn(waited: Int = 0) {
    scheduler.schedule("focus-ring", after: 0.1) { [weak self] in
      guard let self, self.isRunning, self.focusRing.isHeldBack else { return }
      if self.system.isMouseButtonDown() {
        self.scheduleFocusRingReturn()
        return
      }
      // The event that ends a drag or a resize can arrive a moment after the button is up, and it decides
      // where the window goes. If it has not come after half a second it was lost.
      if self.drag != nil || self.edgeResize != nil, waited < 5 {
        self.scheduleFocusRingReturn(waited: waited + 1)
        return
      }
      self.focusRing.isHeldBack = false
      self.refreshFocusRing(.focus)
    }
  }
}
