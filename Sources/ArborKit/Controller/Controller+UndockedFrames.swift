import ArborCore
import CoreGraphics

/// A window that leaves the arrangement gets back the size it had before it was docked
/// (docs/features/F48-floating-restores-size.md). `Workspace.undockedFrames` remembers the frame.
///
/// There are three ways out:
/// - **One window floats**, and the person is looking at it (`float`, `toggle-float`, a drag out of its
///   slot). It takes the remembered size where it is: centred on its slot, or under the pointer.
/// - **Arbor lets go** (`float-all`, quitting, pausing, excluding its app). That means "as it was", so the
///   window takes the remembered position too.
/// - **It is let go where macOS may tile it.** Arbor sets no frame there, so it goes as large as its slot, and what becomes of it shows half a second
///   later (Controller+LeftToMacOS.swift; "Out of its slot as large as the slot", below).
///
/// A window with nothing remembered (docked for as long as Arbor has known it) keeps its slot's size.
extension Controller {
  // MARK: One window floats

  /// Where an undocked window should float, decided while it is still docked: the size it floated at,
  /// centred on its slot (on the middle of the display if its slot is out of view).
  func floatingFrame(for window: WindowID, on displayID: DisplayID) -> CGRect {
    // It is in view at its own size already, and not in its slot (Controller+LetBe.swift).
    if isLetBe(window), let frame = windows[window]?.frame { return frame }
    let layout = layouts[displayID]
    let slot = layout?.windowFrames[window]
    let size =
      workspaces[displayID]?.undockedFrame(of: window)?.size ?? slot?.size ?? sizeInView(of: window)
      ?? CGSize(width: 800, height: 600)
    let visible = display(displayID)?.visibleFrame ?? CGRect(origin: .zero, size: size)
    // A tile, or the tab group whose other tab is showing, is still a place on screen.
    let place = slot ?? workspaces[displayID]?.tree.leaf(containing: window).flatMap { layout?.nodeFrames[$0] }
    let centre = (place ?? visible).center
    return CGRect(
      x: (centre.x - size.width / 2).rounded(), y: (centre.y - size.height / 2).rounded(), width: size.width,
      height: size.height
    ).fitted(into: visible)
  }

  /// Takes a docked window out of the arrangement where it is, for `float` and `toggle-float`. Returns true if the
  /// view moved to show the Desktop.
  @discardableResult
  func undock(_ window: WindowID, on displayID: DisplayID) -> Bool {
    guard var workspace = workspaces[displayID], let display = display(displayID) else { return false }
    var frame = floatingFrame(for: window, on: displayID)
    let standsWhereItFloats = isLetBe(window)
    let camera = workspace.camera
    let wasFramed = workspace.tree.leaf(containing: window) == camera && workspace.tree.windows(under: camera) == [window]
    workspace.undock(window, floatingAt: frame, shareSpace: settings.shareRemovedSpace)
    workspaces[displayID] = workspace
    misfits[window] = nil
    // The space the view was on is gone. The window lives on the Desktop now, so look there, rather
    // than at whichever neighbour closed over its slot.
    if wasFramed {
      workspaces[displayID]!.moveCamera(to: viewShowingTheDesktop(on: displayID), record: false)
    }
    // Moved by the layout, once the stage is up (`relayout`).
    var toPutBack: [(window: WindowID, frame: CGRect)] = []
    var takesDesktop = false
    if let desktop = layoutToCome(on: displayID)?.desktopFrame {
      // Onto the Desktop. A window floated by command is put there on purpose, like one that is dropped: if the
      // Desktop is smaller than it (the narrow one `arrange` makes), it keeps its own size and hangs over the docked windows.
      if !standsWhereItFloats {
        frame = floatingFrame(frame, on: roomToFloat(desktop, on: display), of: display, minimum: frame.size)
      }
      workspaces[displayID]!.floating[window] = frame
      // Alone there and about to take all of it (Controller+SoleFloat.swift), it is not made its own size first.
      takesDesktop = windowThatTakesDesktop(of: displayID) == window
      if !takesDesktop { toPutBack = [(window, frame)] }
    } else if !parked.contains(window) {
      // The Desktop is out of view and the window is not: it stays, over the docked windows, and belongs to this view.
      toPutBack = [(window, frame)]
      stayWithTheView(window, on: displayID)
    }
    // Otherwise both are out of view, and the window waits for the Desktop. Only a window that has been given a place
    // is left alone by the layout: should the Desktop come into view after all, better squeezed onto it than nowhere.
    placedOnPurpose = Set(toPutBack.map(\.window))
    defer { placedOnPurpose = [] }
    relayout(displayID, reason: .structure, puttingBack: toPutBack)
    guard workspaces[displayID]?.camera != camera else { return false }
    ensureFocusIsVisible(on: displayID)
    notify(.camera(displayID))
    return wasFramed
  }

  /// What `relayout` is about to start from, which is more than `layout(of:)`: the room the window's slot took can go
  /// to a Desktop that was a tile till now (Controller+MakeRoom.swift). Only a look: the gaps are the layout's to move.
  func layoutToCome(on displayID: DisplayID, for reason: RelayoutReason = .structure) -> Layout? {
    let (asItIs, noted, kept) = (workspaces[displayID], treesBeforeRoomWasMade[displayID], keptRoom[displayID])
    defer { (workspaces[displayID], treesBeforeRoomWasMade[displayID], keptRoom[displayID]) = (asItIs, noted, kept) }
    return roomyLayout(of: displayID, for: reason)
  }

  /// A window that starts to float while the Desktop is out of view would be gone at the next move of the view, and
  /// Back would not bring it back. Like a new window that opens over a framed one, it is a guest of the
  /// view it floats over (Controller+Guests.swift), unless the setting for those says that floating windows belong to the Desktop.
  func stayWithTheView(_ window: WindowID, on displayID: DisplayID) {
    guard settings.newWindowsWhileFramed != "float", let camera = workspaces[displayID]?.camera else { return }
    workspaces[displayID]?.receive(window, asGuestOf: camera)
  }

  /// The closest view to the current one that shows the Desktop: just wide enough to include it, or
  /// the Desktop itself if it would be a tile at that level.
  private func viewShowingTheDesktop(on displayID: DisplayID) -> NodeID {
    guard let workspace = workspaces[displayID] else { return NodeID(0) }
    let desktop = workspace.tree.desktop
    let common = Navigation.commonAncestor(workspace.camera, desktop, in: workspace.tree)
    return layout(of: displayID, camera: common)?.desktopFrame != nil ? common : desktop
  }

  /// Where a docked window dropped at `pointer` to float should be: the size it floated at, with
  /// the pointer still over its title bar, as far along it as before. Nil if nothing is remembered.
  /// Decided while it is still docked; `sizeOwed` is the size, if a command undocked it while it was in the hand, or if it floats
  /// as large as a slot it left.
  func droppedFrame(
    of window: WindowID, on displayID: DisplayID?, at pointer: CGPoint?, sizeOwed: CGSize? = nil
  ) -> CGRect? {
    guard let pointer, let dragged = windows[window]?.frame, dragged.width > 0,
      var size = sizeOwed ?? displayID.flatMap({ frameToTakeAlong(of: window, from: $0, ifDocked: true)?.size })
    else { return nil }
    // It may be dropped on a smaller display than the one it floated on.
    if let room = self.displayID(at: pointer).flatMap({ display($0) })?.visibleFrame.size {
      size = CGSize(width: min(size.width, room.width), height: min(size.height, room.height))
    }
    // The frame can be a moment older than the pointer, so neither number is taken on trust.
    let along = min(max((pointer.x - dragged.minX) / dragged.width, 0), 1)
    let below = min(max(pointer.y - dragged.minY, 0), min(Self.titleBarReach, size.height))
    var frame = CGRect(
      x: (pointer.x - along * size.width).rounded(), y: (pointer.y - below).rounded(), width: size.width,
      height: size.height)
    // A window that grows at the drop can end up hanging off the display, and it is Arbor that did the growing. It
    // slides back in as far as the pointer stays on its title bar.
    if let visible = self.displayID(at: pointer).flatMap({ display($0) })?.visibleFrame {
      frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
      frame.origin.x = min(max(frame.minX, pointer.x - frame.width), pointer.x)
      frame.origin.y = min(frame.minY, max(visible.maxY - frame.height, pointer.y - Self.titleBarHeight))
    }
    return frame
  }

  /// The part of a window's top that any window can be dragged by.
  static let titleBarHeight: CGFloat = 28

  /// How far below a window's top edge a press can be and still drag it (a tall toolbar).
  static let titleBarReach: CGFloat = 60

  /// Gives a window that was just dropped to float on `displayID`, or that macOS has left alone there, the frame `droppedFrame` chose.
  /// Returns false if its app did not answer.
  @discardableResult
  func shrinkDropped(_ window: WindowID, to frame: CGRect, on displayID: DisplayID) -> Bool {
    misfits[window] = nil
    guard let actual = system.setFrame(frame, of: window) else { return false }
    // It has its own size, and macOS gives back a size from before a tile only once.
    leftAsLargeAsTheirSlots[window] = nil
    Log.debug("\(window) is out of its slot and took its own size, \(Int(actual.width))×\(Int(actual.height))")
    windows[window]?.frame = actual
    workspaces[displayID]?.floating[window] = actual
    return true
  }

  // MARK: Arbor lets go

  /// Where a docked window goes when Arbor lets go of it: the frame it floated at. Nil if nothing is remembered.
  func frameAsItWas(of window: WindowID, on displayID: DisplayID) -> CGRect? {
    guard let frame = workspaces[displayID]?.undockedFrame(of: window), let display = display(displayID) else {
      return nil
    }
    // The note goes by the window's own display. What hung over to the next one shows less if that one has changed since.
    let showsAsMuch = chosenOnShape[window].map { areaShowing(of: frame) >= $0.showing - 1 } ?? false
    return asItWas(frame, on: display, leftThereByItsUser: showsAsMuch && wasLeftThereByItsUser(frame, of: window, on: display))
  }

  /// `frame`, where a window used to be, if that is still a place for a window on `display`. People leave
  /// windows hanging over a screen edge on purpose, so that alone is no reason to move one. If the
  /// display has changed since, so that the window would be larger than it, mostly off it, or have its
  /// title bar under the menu bar, the frame is fitted into the display. Off *it*: the question is whether the frame still
  /// belongs to this display, not how much of it can be seen.
  ///
  /// Unless its person's own hand left it there and as much of it shows as then (`wasLeftThereByItsUser`): across the border of two
  /// displays less than half of a window can be on its own, and it is in view all the same. Only with that note: a layout would
  /// fit any other in again (`floatingMoves`), and a pause and the resume after it would take the window there and back.
  func asItWas(_ frame: CGRect, on display: DisplaySnapshot, leftThereByItsUser: Bool = false) -> CGRect {
    let visible = display.visibleFrame
    let isStillGood =
      frame.width <= visible.width && frame.height <= visible.height && frame.minY >= visible.minY
      && (frame.fractionInside(display.frame) >= 0.5 || leftThereByItsUser && !showsLessThanHalf(frame))
    return isStillGood ? frame : frame.fitted(into: visible)
  }

  /// Where a floating window goes when Arbor lets go of it. What its person's own hand left on this display as it is, however little
  /// of it shows, is given back as it was, if a hand could get hold of it there: the next layout would fetch it otherwise, a second
  /// move. So would its pin, of a window that is kept in view. Of any other frame nobody knows how it came to hang there (`asItWas`).
  func whereItWasLeft(_ window: WindowID, _ preferred: CGRect, on display: DisplaySnapshot) -> CGRect {
    isWhereItWasLeft(window, preferred, on: display) ? preferred : asItWas(preferred, on: display)
  }

  /// Whether `frame` is known to be where floating `window`'s person left it, or Arbor found it, on this display as it is, and a place to
  /// leave it in: a hand could get hold of it there, and nothing of Arbor's would fetch it from there.
  func isWhereItWasLeft(_ window: WindowID, _ frame: CGRect, on display: DisplaySnapshot) -> Bool {
    wasLeftThereByItsUser(frame, of: window, on: display) && titleBarIsWithinReach(frame) && !staysInView(window)
  }

  /// Lets go of a docked window: back to where it floated, or, if that is not known, into view at `slot`.
  func letGo(of window: WindowID, on display: DisplaySnapshot, otherwiseAt slot: CGRect?) {
    // What is given back is what Arbor took. Its person's last word about this one was said to macOS (Controller+AppsDoubleClick.swift).
    guard !enforcement.leftAlone.contains(window) else { return }
    if let frame = frameAsItWas(of: window, on: display.id) {
      putBack(window, at: frame, on: display)
    } else if let slot {
      placeVisibly(window, at: slot, on: display)
    }
  }

  /// Whether a floating window is somewhere else than `preferred`, where the user left it: docked windows
  /// pushed it aside or squeezed it to keep it on the Desktop. Letting go means undoing that as well.
  /// (Also asked of a docked window, which is in its slot and not where it floated.) No floating window is pushed aside unless
  /// they make way: where one is then is where its person has it. But in another size than its own it is as Arbor had it: found in
  /// the shape of a slot after a run that did not quit (Controller+FoundAtAStart.swift). (Fitted, it is small for the displays' sake.)
  func wasPushedAside(_ window: WindowID, from preferred: CGRect) -> Bool {
    if !settings.floatingWindowsMakeWay, workspaces.values.contains(where: { $0.isFloating(window) }) {
      guard fittedFrames[window] == nil, let size = windows[window]?.frame.size else { return false }
      return abs(size.width - preferred.width) > 1 || abs(size.height - preferred.height) > 1
    }
    return windows[window].map { !$0.frame.approximatelyEquals(preferred, tolerance: 1) } ?? false
  }

  /// Moves a window to exactly `frame`, which is in view as far as it should be (`placeVisibly` would pull all
  /// of it onto the display). If its app keeps it larger than that, it is slid fully onto the display. So it is if its app
  /// keeps it so much smaller that, hanging over an edge as `frame` does, hardly anything of it shows.
  func putBack(_ window: WindowID, at frame: CGRect, on display: DisplaySnapshot) {
    guard !isStoppingWithoutMoving else { return }
    // macOS does not let a window in full screen be moved; it goes back to its own idea of its frame.
    guard windows[window]?.isFullScreen != true else { return }
    // A window being dragged stays in the user's hand, and takes the size when it is let go.
    if window == drag?.window {
      if frame.size != windows[window]?.frame.size { drag?.sizeOwed = frame.size }
      return
    }
    let wasParked = parked.remove(window) != nil
    let isThere = !wasParked && windows[window]?.frame == frame
    // A call to another app costs more than everything Arbor does itself: not for a window that is there already.
    guard var actual = isThere ? frame : system.setFrame(frame, of: window) else {
      // Its app does not answer, so it is where it was, out of view if it was. It still counts as that, or nothing
      // would ever fetch it, and it is placed when the app answers (`noteThatTheAppAnswers`).
      if wasParked { parked.insert(window) }
      unplaced.insert(window)
      noteThatItCouldNotComeBack(window, to: frame)
      return
    }
    unplaced.remove(window)
    // One that took the frame it was asked to is where its user had it, however little of it shows.
    let isSmaller = actual.width < frame.width - 2 || actual.height < frame.height - 2
    if actual.width > frame.width + 2 || actual.height > frame.height + 2
      || (isSmaller && showsLessThanHalf(actual))
    {
      actual = system.setFrame(actual.fitted(into: display.visibleFrame), of: window) ?? actual
      // That is where it floats from now on, or the next layout would send it back to a frame it cannot take. Only if
      // that frame is the one remembered: asked for another (squeezed onto a narrow Desktop, as undo restores it), what is
      // remembered is still its own.
      if isSmaller, let home = workspaceID(containing: window),
        workspaces[home]?.floating[window]?.approximatelyEquals(frame, tolerance: 1) == true
      {
        workspaces[home]?.floating[window] = actual
      }
    }
    windows[window]?.frame = actual
    // It is where its user had it, not where Arbor chose to put it: later layouts treat it accordingly.
    settled[window] = nil
    // Put back before Arbor has looked at what macOS makes of it: if it is still here then, macOS has left it alone.
    leftToMacOS[window]?.letGo = actual
  }

  // MARK: Moved by its user

  /// What to remember of a floating window that its user has moved from `before` to `frame`. A move is not a resize:
  /// a window Arbor squeezed to keep it on the Desktop has not become its user's idea of its size by being pushed a
  /// little further. It keeps its own size to go back to, from where it is now, on the display as far as `frame` is.
  /// `ownSize`: if that is not the size remembered where it floats now.
  func frameToRemember(of window: WindowID, movedFrom before: CGRect?, to frame: CGRect, ownSize: CGSize? = nil) -> CGRect {
    let isAsLargeAsTheSlotItLeft = self.ownSize(of: window, ifItIsAsLargeAsTheSlotItLeft: frame.size) != nil
    guard settings.floatingWindowsMakeWay || ownSize != nil || isAsLargeAsTheSlotItLeft, let before, abs(before.width - frame.width) <= 1,
      abs(before.height - frame.height) <= 1,
      let own = ownSize ?? workspaceID(containing: window).flatMap({ workspaces[$0]?.floating[window]?.size }), own != frame.size,
      // Squeezed, not stretched: one that fills the Desktop and is taken in hand stays as it is (Controller+SoleFloat.swift). Or still
      // as large as the slot it left.
      own.width >= frame.width && own.height >= frame.height || isAsLargeAsTheSlotItLeft
    else { return frame }
    return self.frame(ofSize: own, from: frame)
  }

  /// A frame of the size `own` from where `frame` is, on the display as far as `frame` is.
  func frame(ofSize own: CGSize, from frame: CGRect) -> CGRect {
    var remembered = CGRect(origin: frame.origin, size: own)
    guard let visible = displayID(at: frame.center).flatMap({ display($0) })?.visibleFrame else { return remembered }
    // Each way by itself. Let go a point under the Dock's line, it hangs there by its user's hand; its width must not come
    // back over the right edge for that, which the hand never took it across.
    let fitted = remembered.fitted(into: visible)
    if frame.minX >= visible.minX, frame.maxX <= visible.maxX {
      (remembered.origin.x, remembered.size.width) = (fitted.minX, fitted.width)
    }
    if frame.minY >= visible.minY, frame.maxY <= visible.maxY {
      (remembered.origin.y, remembered.size.height) = (fitted.minY, fitted.height)
    }
    return remembered
  }

  // MARK: Out of its slot as large as the slot

  /// A window that left the arrangement where macOS may tile it. Arbor stood aside and set no frame, so it went as large as its slot.
  struct LeftAsLargeAsItsSlot {
    var slot: CGSize
    /// What it had before Arbor first sized it, or what a hand has given it since.
    var own: CGSize
    /// What macOS made of it, by the window server's word when Arbor looked. Nil until then, and if macOS left it alone.
    var tile: CGSize?
  }

  /// A slot's size is never a window's own. `window`, docked till now, floats on `display` as it is, and its own size is what is remembered.
  /// (Unless macOS has sized it already, after a release that Arbor never saw: a tile's size is what a hand asked macOS for.)
  /// The note is for later. macOS may leave the window alone, as large as the slot until somebody sizes it. Or it tiles it, and
  /// gives it the slot's size again at the next drag by the title bar, whatever has become of the window since: seen on a Mac.
  func leaves(_ window: WindowID, _ sizes: LeftAsLargeAsItsSlot, on display: DisplayID) {
    guard sizes.slot != sizes.own else { return }
    leftAsLargeAsTheirSlots[window] = sizes
    if let own = windows[window].flatMap({ ownSize(of: window, ifItIsAsLargeAsTheSlotItLeft: $0.frame.size) }) {
      workspaces[display]?.floating[window]?.size = own
    }
  }

  /// Part of `windowChanged`, for a floating window. A size somebody gives it after it has left its slot is its own from then on: the green button, a key
  /// of another tool, its app. (A hand on its edges: `resizeEnded`.) Not what macOS makes of it on its way into a tile, of which a busy app can go on
  /// telling after Arbor has looked: while the window server has it as large as the tile, nobody has sized it. Nor, with the button down,
  /// on its way out of one, of which Arbor can hear before it hears of the drag.
  func noteSizeGivenSinceItLeftItsSlot(_ window: WindowSnapshot, was previous: WindowSnapshot?) {
    guard let tile = leftAsLargeAsTheirSlots[window.id]?.tile, leftToMacOS[window.id] == nil, let previous,
      abs(previous.frame.width - window.frame.width) > 1 || abs(previous.frame.height - window.frame.height) > 1,
      !system.isMouseButtonDown(), let now = system.stackedWindows().first(where: { $0.id == window.id })?.frame.size,
      abs(now.width - tile.width) > 1 || abs(now.height - tile.height) > 1
    else { return }
    leftAsLargeAsTheirSlots[window.id]?.own = window.frame.size
  }

  /// The size that is `window`'s own if `size`, which it is seen to have, is that of the slot it left so. To within two points:
  /// 325×650 came back from macOS as 326×651.
  func ownSize(of window: WindowID, ifItIsAsLargeAsTheSlotItLeft size: CGSize) -> CGSize? {
    guard let left = leftAsLargeAsTheirSlots[window], abs(left.slot.width - size.width) <= 2, abs(left.slot.height - size.height) <= 2
    else { return nil }
    return left.own
  }

  // MARK: From one display to another

  /// Hands `window` from one display's workspace to another's, on its way to being docked there. It
  /// arrives floating, at the frame it floated at (or would float at) on the display it leaves, as
  /// far from the new display's corner as it was from the old one's; docking it remembers that.
  func transfer(_ window: WindowID, from source: DisplayID, to destination: DisplayID) {
    let frame = frameAfterTransfer(of: window, from: source, to: destination)
    noteTransfer(of: window, from: source, to: destination, arrivingAt: frame)
    workspaces[source]?.forget(window, shareSpace: settings.shareRemovedSpace)
    if let frame { workspaces[destination]?.floating[window] = frame }
  }

  /// The frame `transfer` lets `window` arrive at. A drop hands it to `Drop.arrivingFrame` instead. Only a question: a
  /// drag asks it of every target it passes. Whoever lets the window go there says so with `noteTransfer`.
  func frameAfterTransfer(of window: WindowID, from source: DisplayID, to destination: DisplayID) -> CGRect? {
    guard let frame = frameToTakeAlong(of: window, from: source), let old = display(source)?.visibleFrame,
      let new = display(destination)?.visibleFrame
    else { return nil }
    return frame.offsetBy(dx: new.minX - old.minX, dy: new.minY - old.minY).fitted(into: new)
  }

  func frameToTakeAlong(of window: WindowID, from source: DisplayID, ifDocked: Bool = false) -> CGRect? {
    guard let frame = workspaces[source]?.undockedFrame(of: window) ?? (ifDocked ? nil : workspaces[source]?.floating[window])
    else { return nil }
    return CGRect(origin: frame.origin, size: sizeToTakeAlong(of: window, from: source, remembered: frame.size))
  }

  /// `window` leaves `source` for the frame `frameAfterTransfer` gave. Called while `source` still remembers it.
  func noteTransfer(of window: WindowID, from source: DisplayID, to destination: DisplayID, arrivingAt frame: CGRect?) {
    guard let frame, let own = frameToTakeAlong(of: window, from: source)?.size else { return }
    noteFit(of: window, own: own, into: frame.size, on: destination)
  }

  /// A window that came to a display too small for its own size.
  struct FittedWindow {
    /// The size it had of its own on the display it came from.
    var own: CGSize
    /// What was left of it here. While that is still what is remembered as its size, `own` is what it takes along.
    var fitted: CGSize
    var display: DisplayID

    func isStill(_ size: CGSize?) -> Bool {
      size.map { abs(fitted.width - $0.width) <= 1 && abs(fitted.height - $0.height) <= 1 } ?? false
    }
  }

  /// The size `window` goes to another display with: `size`, which is remembered as its own on this one, unless that is
  /// only what this display had room for. There and back costs a window nothing. A size somebody has given it since is its own.
  func sizeToTakeAlong(of window: WindowID, from source: DisplayID, remembered size: CGSize) -> CGSize {
    guard let trip = fittedToADisplay[window], trip.display == source, trip.isStill(size) else { return size }
    return trip.own
  }

  /// Called with the size that is remembered for a window from now on, on the display it has come to.
  func noteFit(of window: WindowID, own: CGSize, into fitted: CGSize, on display: DisplayID) {
    if fitted.width < own.width || fitted.height < own.height {
      // A place that waits for its window has a number and no window: nobody would ever clear the note away.
      if windows[window] != nil { fittedToADisplay[window] = FittedWindow(own: own, fitted: fitted, display: display) }
    } else if fittedToADisplay[window]?.display == display {
      // It has room here at the size it has by now. On any other display the note stays, and counts for nothing there: Undo
      // may take the window back to where it does.
      fittedToADisplay[window] = nil
    }
  }

  /// A hand has had `window`. The size it has made it, or has taken to another display, is the window's own from now on.
  func forgetFitUnlessItStillHolds(_ window: WindowID) {
    guard let trip = fittedToADisplay[window], let workspace = workspaces[trip.display],
      trip.isStill((workspace.undockedFrame(of: window) ?? workspace.floating[window])?.size)
    else { return fittedToADisplay[window] = nil }
  }
}
