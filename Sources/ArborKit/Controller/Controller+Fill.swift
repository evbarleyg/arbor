import ArborCore
import CoreGraphics

/// The key that fills the screen fills it with a floating window too (collab/QUESTIONS.md, Q29; `zoom`).
///
/// A docked window is framed: the view moves to its place. A floating window has no place to look at, so it is the window
/// that changes: it takes the frame a framed window has, and goes on floating. The view stays where it is, and nothing else is
/// moved, sized, raised or sent away. The same key again, and it is exactly where and as large as it was.
///
/// The mark is `Workspace.filled`, so it is saved, undone and redone with the arrangement. `Workspace.floating` goes on holding
/// the frame that is the window's own, as it does for a window that docked windows pushed aside: **the fill's size is Arbor's and
/// never becomes the window's.** There is one frame to go back to, whoever asks: the key, and whatever gives such a window its own
/// frame back when Arbor lets go of it (quitting, pausing, `float-all`, excluding its app; Controller+UndockedFrames.swift).
/// **The mark goes when the window is really back**, not when it was asked to be: an app that hangs leaves the key alive.
///
/// It stays filled through whatever happens by itself: `floatingMoves` neither parks it nor pushes it aside. A move of the view
/// leaves it, behind what arrives. It ends with the key, with Show Everything, with Undo, when the window is docked, and in its
/// person's hand: a size they give it is its own from then on, and moved by its title bar it comes out as a docked window does,
/// where it is let go and in its own size. Moved at its size with no button down (macOS's Window ▸ Center, another tool: at a person's
/// asking, as a rule) it is let be where it was put, and keeps the mark: Arbor reverses nothing, and still owes it its own frame.
extension Controller {
  struct Fills {
    /// Filled windows that something is moving about with the button down, and no drag was reported. They are left alone
    /// until it is up (`filledWindowIsLetGo`).
    var inHand: Set<WindowID> = []
    /// The window the command that is running could not make as large as the view, for the line on screen.
    var stoppedShort: WindowID?
    /// Those of which the line has said so. Once each: it is their app's doing and will be no different next time.
    var saidToGoNoLarger: Set<WindowID> = []
    /// Those that the layout now under way takes out of the view they filled, and where to (`endingFills`).
    var goingBack: [WindowID: CGRect] = [:]
    /// Those whose fill ended with a size that was not Arbor's doing: where the fill had put them, and the frame that was their own
    /// then (`takesUpItsFill`). For this run of Arbor. It names its display, and sleeps while that one is away.
    var gaveWay: [WindowID: (display: DisplayID, at: CGRect, own: CGRect)] = [:]
  }

  // MARK: Lookup

  public func isFilled(_ window: WindowID) -> Bool { workspaces.values.contains { $0.isFilled(window) } }

  /// What a framed window fills, and so does a filled one.
  func viewToFill(on display: DisplaySnapshot) -> CGRect {
    LayoutEngine.content(of: display.visibleFrame, options: options(for: display.id).layoutOptions)
  }

  // MARK: The command

  /// `zoom` for a window that floats on `displayID`. `again`: the shortcut, which goes back and forth. With the window named
  /// the command is idempotent, as for a docked one.
  func fillTheView(with id: WindowID, on displayID: DisplayID, again: Bool) -> CommandResult {
    refreshVisibleFrame(of: displayID)
    guard let display = display(displayID), let current = windows[id] else { return .failure("no display") }
    // A window being dragged stays in the user's hand, also where no drag was reported.
    guard !isInAHand(id) else { return .failure("\(id) is being dragged") }
    if workspaces[displayID]!.isFilled(id) {
      guard again else { return .success("\(id) fills the screen already") }
      return endFill(of: id, on: display)
    }
    guard id != drag?.window else { return .failure("\(id) is being dragged") }
    let view = viewToFill(on: display)
    // By somebody else's doing: macOS's own fill, or a hand. That frame is the window's own, and there is none to go back to.
    if current.isPresent, !parked.contains(id), current.frame.insetBy(dx: -1, dy: -1).contains(view),
      workspaces[displayID]!.floating[id].map({ !wasPushedAside(id, from: $0) }) == true
    {
      // Unless Arbor knows the way back: the key filled the screen with it, and macOS has zoomed it since. Whoever presses the key
      // again means "back", whatever happened between.
      if again, takesUpItsFill(current, on: displayID, whereverItIs: true) { return endFill(of: id, on: display) }
      return .success("\(id) fills the screen already")
    }
    fills.gaveWay[id] = nil
    // What Arbor gave up on while the window was docked (its app fought, macOS zoomed it) is over: its person asks for something else.
    enforcement.reset([id])
    // Its own frame is the view's, and Arbor has squeezed it: there it goes, and there is nothing to go back to.
    if let own = workspaces[displayID]!.floating[id], own.approximatelyEquals(view, tolerance: 1), current.isPresent {
      putBack(id, at: own, on: display)
      askForTheKeyboard(for: id)
      return .success("filled the screen with \(id)")
    }
    workspaces[displayID]!.fill(id, at: view)
    if current.isPresent { moveIntoTheView(id, on: display) }
    askForTheKeyboard(for: id)
    notify(.layout(displayID))
    scheduleSave()
    // A line or a column of text short of the view is as near as a terminal comes, and nobody misses it.
    guard let took = windows[id]?.frame, current.isPresent, !unplaced.contains(id),
      took.width < view.width - Self.largestCell || took.height < view.height - Self.largestCell
    else { return .success("filled the screen with \(id)") }
    fills.stoppedShort = id
    return .success("\(id) goes no larger than \(Int(took.width))×\(Int(took.height))")
  }

  /// What the line on screen says of a fill that stopped short, the first time it does for that window.
  func lineAboutAFill(thatStoppedShortFor id: WindowID) -> HeadsUpModel? {
    guard let window = windows[id], fills.saidToGoNoLarger.insert(id).inserted else { return nil }
    return HeadsUpModel(kind: .change, text: "\(window.appName) goes no larger")
  }

  // MARK: Moving it

  /// Takes a filled window to the view, or as near to that as its app lets it come: one that will not grow that far sits in the
  /// middle. By the road a docked window takes into its slot (`place`), and where it got to is written down.
  ///
  /// In view nobody is asked to grow where it stands: there macOS lets a window grow no further than the bottom of the visible frame and
  /// the right edge of its display, and the clipped answer would pass for a size its app refuses. It gets the view in one
  /// request. So an app that stops short goes on to the middle the first time it is met, and straight there from then on.
  func moveIntoTheView(_ id: WindowID, on display: DisplaySnapshot) {
    guard id != drag?.window else { return }
    let view = viewToFill(on: display)
    // An answer holds for the move it was given for, as in `apply`.
    defer { justAnswered[id] = nil }
    // One that is said not to change its size goes straight to the middle.
    noteFixedSizes(of: [id])
    if parked.contains(id), let current = windows[id], isStillToBePlaced(current, in: view),
      let question = questionBeforePlacing(current, in: view, on: display.id)
    {
      _ = ask(id, question, on: display.id)
    }
    _ = place(id, in: view, on: display.id)
    if let actual = windows[id]?.frame, !unplaced.contains(id) { workspaces[display.id]?.fill(id, at: actual) }
  }

  /// With the button down, and no drag reported.
  private func isInAHand(_ id: WindowID) -> Bool { fills.inHand.contains(id) && system.isMouseButtonDown() }

  /// Whether a layout has to move a filled window: the view has changed its shape, the window is back from somewhere, or its
  /// app has only now begun to answer. Not one that stopped short, or was moved and let be, and is still there (`misfits`).
  func isStillToFillTheView(_ window: WindowSnapshot, on display: DisplaySnapshot) -> Bool {
    !fills.inHand.contains(window.id) && isStillToBePlaced(window, in: viewToFill(on: display))
  }

  /// Called by every layout. What is written down is where the window is: a display that got another corner has taken it along.
  func noteWhereFillsHaveGotTo(on displayID: DisplayID) {
    guard let display = display(displayID) else { return }
    // What is kept of a fill that gave way is over when the window is docked.
    fills.gaveWay = fills.gaveWay.filter { $0.value.display != displayID || workspaces[displayID]?.isFloating($0.key) == true }
    for (window, fillsAt) in workspaces[displayID]?.filled ?? [:] {
      guard let current = windows[window], current.isPresent, current.frame != fillsAt, window != drag?.window,
        !fills.inHand.contains(window), !unplaced.contains(window), !isStillToFillTheView(current, on: display)
      else { continue }
      workspaces[displayID]?.fill(window, at: current.frame)
    }
  }

  /// Takes the mark off a window that goes on floating on `displayID`. Returns whether it had one.
  @discardableResult
  func unmarkFill(of id: WindowID, on displayID: DisplayID) -> Bool {
    guard workspaces[displayID]?.endFill(of: id) == true else { return false }
    fills.inHand.remove(id)
    misfits[id] = nil
    // It was in view whatever the view showed. With the Desktop out of view it would now be gone at the next move of the view, and
    // Back would not bring it back: like a window that starts to float there, it belongs to this view (Controller+UndockedFrames.swift).
    if layouts[displayID]?.desktopFrame == nil, workspaces[displayID]?.role(of: id) == nil, workspaces[displayID]?.guests?[id] == nil {
      stayWithTheView(id, on: displayID)
    }
    return true
  }

  /// Where the end of a fill takes a window: its own frame, exactly, hang it over an edge or not. By the measures of every layout
  /// (`reach`): mostly off the display it is a place only as its person left it there, on the displays as they are now, with
  /// enough of it showing to see and grab. What is left over from a display that has shrunk or gone is fitted, as it would
  /// have been at that change, had the window not filled the view.
  func ownFrame(of id: WindowID, on display: DisplaySnapshot) -> CGRect? {
    workspaces[display.id]?.floating[id].map { own in
      let canBeGrabbed = displays.contains {
        let showing = own.intersection($0.visibleFrame)
        return !showing.isNull && showing.width >= Self.leastStrip && showing.height >= Self.leastStrip
      }
      // (A pinned window that is mostly beyond an edge is fetched by every layout: Controller+Pin.swift. And where its app opened a
      // window is not a place anybody chose.)
      let mayHang =
        canBeGrabbed && !staysInView(id) && appPlacedFrames[id] != own && wasLeftThereByItsUser(own, of: id, on: display)
      return mayHang ? own : asItWas(own, on: display)
    }
  }

  /// Back to its own frame, in one move.
  @discardableResult
  func endFill(of id: WindowID, on display: DisplaySnapshot) -> CommandResult {
    guard let own = ownFrame(of: id, on: display), let fillsAt = workspaces[display.id]?.filled?[id] else {
      return .failure("\(id) does not fill the screen")
    }
    unmarkFill(of: id, on: display.id)
    defer {
      notify(.layout(display.id))
      scheduleSave()
    }
    // It stays in the hand, and takes its size when it is let go (`putBack`).
    let isInHand = id == drag?.window
    if windowThatTakesDesktop(of: display.id) == id, !isInHand {
      // Alone on the Desktop it has all of that (F18), which is for a layout to see to: not by way of its own frame.
      relayout(display.id, reason: .structure)
    } else if windows[id]?.isPresent == true {
      putBack(id, at: own, on: display)
    }
    // Its app does not answer, or macOS has it in full screen: it is as large as it was, and the key must go on knowing why.
    if !isInHand, windows[id]?.isPresent == true, unplaced.contains(id) || windows[id]?.isFullScreen == true {
      workspaces[display.id]?.fill(id, at: fillsAt)
      return .failure("\(id) does not answer, and goes on filling the screen")
    }
    return .success(isInHand ? "\(id) takes its own size when it is let go" : "\(id) has its own frame back")
  }

  /// Show Everything means everything: what fills the view would cover it. `show` moves the view and lays out, which takes each
  /// window that filled it to where a floating window belongs in that view, in one move: not by way of anywhere else. One that
  /// the layout would leave alone, as it does most floating windows, it takes to its own frame (`floatingMoves`): with the others,
  /// so that the motion that shows the change shows that too.
  func endingFills(on displayID: DisplayID, _ show: () -> Void) {
    // (One that is in a hand comes out when it is let go.)
    guard let display = display(displayID), let filled = workspaces[displayID]?.filled?.filter({ !isInAHand($0.key) }), !filled.isEmpty
    else { return show() }
    for window in filled.keys.sorted() {
      unmarkFill(of: window, on: displayID)
      fills.goingBack[window] = ownFrame(of: window, on: display)
    }
    show()
    fills.goingBack = [:]
    for (window, fillsAt) in filled.sorted(by: { $0.key < $1.key }) {
      guard let current = windows[window], current.isPresent, workspaces[displayID]?.isFloating(window) == true else { continue }
      // Nothing was laid out: the view is held, say.
      if current.frame.approximatelyEquals(fillsAt, tolerance: 1), !unplaced.contains(window), let own = ownFrame(of: window, on: display) {
        putBack(window, at: own, on: display)
      }
      // Its app does not answer: it is as large as it was, and the key must go on knowing why.
      if unplaced.contains(window) { workspaces[displayID]?.fill(window, at: fillsAt) }
    }
  }

  // MARK: Arbor lets go

  /// Arbor has let go of every window, or of those on `display`: each has been sent to its own frame, and no fill outlasts that. But
  /// for a window that could not be moved (its app hangs, it is in full screen): it keeps the mark, which is saved, so that
  /// the next run knows whose size that is. (A pause has put the arrangement by before it stops, marks and all.)
  func forgetFills() {
    for id in workspaces.keys {
      for window in workspaces[id]!.filledWindows {
        // (By its size, and not by `wasPushedAside`: what a stop could not fetch counts as fitted there.)
        if let own = workspaces[id]!.floating[window]?.size, let current = windows[window], current.isPresent,
          abs(current.frame.width - own.width) > 1 || abs(current.frame.height - own.height) > 1
        {
          continue
        }
        workspaces[id]!.endFill(of: window)
        misfits[window] = nil
      }
    }
    // Nor on a display that is away, which may be back in the next run.
    for id in dormant.keys { for window in dormant[id]!.workspace.filledWindows { dormant[id]!.workspace.endFill(of: window) } }
    fills.inHand.removeAll()
  }

  /// Arbor has just started, and nobody told it what happened meanwhile. A mark holds if the window is still where the fill
  /// left it (Arbor ended without quitting, or could not move it), or where the pause that is ending put it: that one fills the
  /// view again. Any other has been moved since. Its own frame is still what is remembered as that.
  func keepOnlyFillsThatStillHold() {
    fills.inHand.removeAll()
    fills.saidToGoNoLarger.formIntersection(windows.keys)
    fills.gaveWay = fills.gaveWay.filter { windows[$0.key] != nil }
    for (id, workspace) in workspaces {
      for (window, fillsAt) in workspace.filled ?? [:] {
        guard let current = windows[window] else { continue }
        if current.frame.approximatelyEquals(fillsAt, tolerance: 4) {
          // What was known of how far it goes went with the last run. A start moves nothing that is where it was left.
          noteThatItFillsAsFarAsItWill(current, on: id)
        } else if !isBackFromThePause(window) {
          workspaces[id]!.endFill(of: window)
        }
      }
    }
  }

  // MARK: The person's hand

  /// A filled window has a new frame that is not Arbor's doing, and no drag is on. Returns true if that has been seen to here.
  /// A new size is the window's own from now on, and the caller remembers it like any other. A move alone is not a size: with
  /// the button down it is a hand's, which is waited for; without, it is let be.
  func filledWindowChanged(_ window: WindowSnapshot, on display: DisplayID) -> Bool {
    guard workspaces[display]?.isFilled(window.id) == true, let fillsAt = workspaces[display]?.filled?[window.id] else {
      return takesUpItsFill(window, on: display)
    }
    // Measured on the size the fill left it in, not on the last report: an edge dragged slowly comes a point at a time.
    guard abs(fillsAt.width - window.frame.width) <= 1, abs(fillsAt.height - window.frame.height) <= 1 else {
      // A hand that sizes it gives it a size of its own, and macOS has nothing to give back but that.
      if !system.isMouseButtonDown(), !fills.inHand.contains(window.id), let own = workspaces[display]?.floating[window.id] {
        fills.gaveWay[window.id] = (display, fillsAt, own)
      }
      unmarkFill(of: window.id, on: display)
      return false
    }
    if system.isMouseButtonDown() || fills.inHand.contains(window.id) {
      fills.inHand.insert(window.id)
      filledWindowIsLetGo(window.id)
    } else {
      letBe(window, on: display)
    }
    return true
  }

  /// macOS remembers frames too. What it gives a window back after its own zoom (a second double-click on the title bar) or its own tile
  /// (Return to Previous Size) is what the window had before: the fill's frame, if that is what macOS took it out of. Remembered like any
  /// other, the fill's size would be the window's own, and its own lost for good. So a window that comes back to exactly where the
  /// fill had put it, with no button down, fills again: the mark is back, its own frame is the one from before the fill, nothing moves.
  /// `whereverItIs`: its person has named it with the key.
  private func takesUpItsFill(_ window: WindowSnapshot, on display: DisplayID, whereverItIs: Bool = false) -> Bool {
    guard let before = fills.gaveWay[window.id], before.display == display, workspaces[display]?.isFloating(window.id) == true else { return false }
    // What a hand gives it since is its own, and what it had before the fill is no longer what "back" means.
    if !whereverItIs, system.isMouseButtonDown() { fills.gaveWay[window.id] = nil }
    guard whereverItIs || (fills.gaveWay[window.id] != nil && window.frame.approximatelyEquals(before.at, tolerance: 1)) else { return false }
    fills.gaveWay[window.id] = nil
    workspaces[display]!.floating[window.id] = before.own
    workspaces[display]!.fill(window.id, at: window.frame)
    noteThatItFillsAsFarAsItWill(window, on: display)
    notify(.layout(display))
    scheduleSave()
    return true
  }

  /// It stays where it was put, at the size it has, and goes on being a window whose size is Arbor's.
  private func letBe(_ window: WindowSnapshot, on home: DisplayID) {
    let id = window.id
    var displayID = home
    // Sent to another display: all that is remembered of it goes along, its own frame as far from that display's corner.
    if let destination = self.displayID(at: window.frame.center), destination != home, workspaces[destination] != nil {
      let (role, own) = (workspaces[home]!.role(of: id), frameAfterTransfer(of: id, from: home, to: destination))
      workspaces[home]!.floating[id] = nil
      workspaces[destination]!.floating[id] = own ?? window.frame
      workspaces[destination]!.setRole(role, of: id)
      displayID = destination
      notify(.windows)
    }
    workspaces[displayID]?.fill(id, at: window.frame)
    noteThatItFillsAsFarAsItWill(window, on: displayID)
    scheduleSave()
  }

  /// No layout asks it again while the view is as it is and the window where it is.
  private func noteThatItFillsAsFarAsItWill(_ window: WindowSnapshot, on displayID: DisplayID) {
    guard let display = display(displayID) else { return }
    let view = viewToFill(on: display)
    settled[window.id] = window.frame
    misfits[window.id] = window.frame.approximatelyEquals(view, tolerance: 1) ? nil : (view, window.frame)
  }

  /// Waits for the button to be up, and then does what the end of a drag does.
  private func filledWindowIsLetGo(_ id: WindowID) {
    guard system.isMouseButtonDown() else { return comeOut(id) }
    scheduler.schedule("fill-in-hand-\(id.rawValue)", after: 0.25) { [weak self] in
      guard let self, self.isRunning, self.fills.inHand.contains(id) else { return }
      self.filledWindowIsLetGo(id)
    }
  }

  /// A filled window was moved and let go. It comes out of the fill like a docked window out of its slot: it is where it was let
  /// go, in its own size, with the pointer still on its title bar if that is where it is. Pulled into view if less than half of
  /// it would show. After a slip it fills the view as before.
  private func comeOut(_ id: WindowID) {
    fills.inHand.remove(id)
    guard let displayID = workspaceID(containing: id), let fillsAt = workspaces[displayID]!.filled?[id], let display = display(displayID),
      let current = windows[id]?.frame, let own = workspaces[displayID]!.floating[id]?.size
    else { return }
    if hypot(current.minX - fillsAt.minX, current.minY - fillsAt.minY) < Self.slip { return moveIntoTheView(id, on: display) }
    let role = workspaces[displayID]!.role(of: id)
    unmarkFill(of: id, on: displayID)
    let destination = self.displayID(at: current.center).flatMap { self.display($0) } ?? display
    var frame = Self.frame(ofSize: own, inPlaceOf: current, under: system.cursorLocation())
    if frame.fractionInside(destination.frame) < 0.5 { frame = frame.fitted(into: destination.visibleFrame) }
    if destination.id != displayID { workspaces[displayID]!.floating[id] = nil }
    workspaces[destination.id]?.floating[id] = frame
    // What it is besides goes along, as when any floating window is carried across (`windowChanged`).
    if destination.id != displayID {
      workspaces[destination.id]?.setRole(role, of: id)
      notify(.windows)
    }
    putBack(id, at: frame, on: destination)
    if let actual = windows[id]?.frame, !unplaced.contains(id) { workspaces[destination.id]?.floating[id] = actual }
    noteWhereItsUserLeftIt(id)
    notify(.layout(displayID))
    scheduleSave()
  }

  // MARK: A drag by the title bar

  /// The size a filled window takes when it is let go (`DragSession.sizeOwed`).
  func ownSizeOfFilledWindow(_ id: WindowID) -> CGSize? {
    workspaceID(containing: id).flatMap { workspaces[$0]!.isFilled(id) ? workspaces[$0]!.floating[id]?.size : nil }
  }

  /// A drag has ended and its drop has been dealt with. A window that still fills the view (the hand slipped) is back in it.
  func filledWindowDropped(_ id: WindowID) {
    guard let displayID = workspaceID(containing: id), workspaces[displayID]!.isFilled(id), let display = display(displayID)
    else { return }
    moveIntoTheView(id, on: display)
  }

  /// A window that filled the view was let go where macOS tiles, so no frame was set on it. macOS does not always take a window:
  /// thrown into the menu bar and let go at once, it stays as it is. Then it floats in its own size where it lies.
  func lookAtWhatMacOSMadeOfAFilledWindow(_ id: WindowID, letGoAt frame: CGRect) {
    scheduler.schedule("fill-in-hand-\(id.rawValue)", after: 0.5) { [weak self] in
      guard let self, self.isRunning, self.drag?.window != id, self.windows[id]?.frame == frame,
        let displayID = self.workspaceID(containing: id), let display = self.display(displayID),
        let own = self.workspaces[displayID]?.floating[id], own.size != frame.size
      else { return }
      // Not with its title bar under the menu bar, where it was thrown, and not mostly off the display.
      self.putBack(id, at: self.asItWas(own, on: display), on: display)
      if let actual = self.windows[id]?.frame, !self.unplaced.contains(id) { self.workspaces[displayID]?.floating[id] = actual }
    }
  }
}
