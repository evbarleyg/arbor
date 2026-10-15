import ArborCore
import CoreGraphics

/// A window that leaves the arrangement gets back the size it had before it was docked
/// (docs/features/F48-floating-restores-size.md). `Workspace.undockedFrames` remembers the frame.
///
/// There are two ways out:
/// - **One window floats**, and the person is looking at it (`float`, `toggle-float`, a drag out of its
///   slot). It takes the remembered size where it is: centred on its slot, or under the pointer.
/// - **Arbor lets go** (`float-all`, quitting, pausing, excluding its app). That means "as it was", so the
///   window takes the remembered position too.
///
/// A window with nothing remembered (docked for as long as Arbor has known it) keeps its slot's size.
extension Controller {
  // MARK: One window floats

  /// Where an undocked window should float, decided while it is still docked: the size it floated at,
  /// centred on its slot (on the middle of the display if its slot is out of view).
  func floatingFrame(for window: WindowID, on displayID: DisplayID) -> CGRect {
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
      frame = floatingFrame(frame, on: floatingRegion(desktop, on: display), of: display, minimum: frame.size)
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
  private func layoutToCome(on displayID: DisplayID) -> Layout? {
    let (asItIs, noted) = (workspaces[displayID], treesBeforeRoomWasMade[displayID])
    defer { (workspaces[displayID], treesBeforeRoomWasMade[displayID]) = (asItIs, noted) }
    return roomyLayout(of: displayID, for: .structure)
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
  /// Decided while it is still docked; `sizeOwed` is the size, if a command undocked it while it was in the hand.
  func droppedFrame(
    of window: WindowID, on displayID: DisplayID?, at pointer: CGPoint?, sizeOwed: CGSize? = nil
  ) -> CGRect? {
    guard let pointer, let dragged = windows[window]?.frame, dragged.width > 0,
      var size = sizeOwed ?? displayID.flatMap({ workspaces[$0]?.undockedFrame(of: window)?.size })
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

  /// Gives a window that was just dropped to float on `displayID` the frame `droppedFrame` chose.
  func shrinkDropped(_ window: WindowID, to frame: CGRect, on displayID: DisplayID) {
    misfits[window] = nil
    guard let actual = system.setFrame(frame, of: window) else { return }
    Log.debug("\(window) was dropped out of its slot and took its own size, \(Int(actual.width))×\(Int(actual.height))")
    windows[window]?.frame = actual
    workspaces[displayID]?.floating[window] = actual
  }

  // MARK: Arbor lets go

  /// Where a docked window goes when Arbor lets go of it: the frame it floated at. Nil if nothing is remembered.
  func frameAsItWas(of window: WindowID, on displayID: DisplayID) -> CGRect? {
    guard let frame = workspaces[displayID]?.undockedFrame(of: window), let display = display(displayID) else {
      return nil
    }
    return asItWas(frame, on: display)
  }

  /// `frame`, where a window used to be, if that is still a place for a window on `display`. People leave
  /// windows hanging over a screen edge on purpose, so that alone is no reason to move one. If the
  /// display has changed since, so that the window would be larger than it, mostly off it, or have its
  /// title bar under the menu bar, the frame is fitted into the display.
  func asItWas(_ frame: CGRect, on display: DisplaySnapshot) -> CGRect {
    let visible = display.visibleFrame
    let isStillGood =
      frame.width <= visible.width && frame.height <= visible.height && frame.minY >= visible.minY
      && frame.fractionInside(display.frame) >= 0.5
    return isStillGood ? frame : frame.fitted(into: visible)
  }

  /// Lets go of a docked window: back to where it floated, or, if that is not known, into view at `slot`.
  func letGo(of window: WindowID, on display: DisplaySnapshot, otherwiseAt slot: CGRect?) {
    if let frame = frameAsItWas(of: window, on: display.id) {
      putBack(window, at: frame, on: display)
    } else if let slot {
      placeVisibly(window, at: slot, on: display)
    }
  }

  /// Whether a floating window is somewhere else than `preferred`, where the user left it: docked windows
  /// pushed it aside or squeezed it to keep it on the Desktop. Letting go means undoing that as well.
  func wasPushedAside(_ window: WindowID, from preferred: CGRect) -> Bool {
    windows[window].map { !$0.frame.approximatelyEquals(preferred, tolerance: 1) } ?? false
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
      || (isSmaller && displays.allSatisfy({ actual.fractionInside($0.frame) < 0.5 }))
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
  }

  // MARK: Moved by its user

  /// What to remember of a floating window that its user has moved from `before` to `frame`. A move is not a resize:
  /// a window Arbor squeezed to keep it on the Desktop has not become its user's idea of its size by being pushed a
  /// little further. It keeps its own size to go back to, from where it is now, on the display as far as `frame` is.
  func frameToRemember(of window: WindowID, movedFrom before: CGRect?, to frame: CGRect) -> CGRect {
    guard let before, abs(before.width - frame.width) <= 1, abs(before.height - frame.height) <= 1,
      let own = workspaceID(containing: window).flatMap({ workspaces[$0]?.floating[window]?.size }), own != frame.size,
      // Squeezed, not stretched: one that fills the Desktop and is taken in hand stays as it is (Controller+SoleFloat.swift).
      own.width >= frame.width, own.height >= frame.height
    else { return frame }
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

  // MARK: From one display to another

  /// Hands `window` from one display's workspace to another's, on its way to being docked there. It
  /// arrives floating, at the frame it floated at (or would float at) on the display it leaves, as
  /// far from the new display's corner as it was from the old one's; docking it remembers that.
  func transfer(_ window: WindowID, from source: DisplayID, to destination: DisplayID) {
    let frame = frameAfterTransfer(of: window, from: source, to: destination)
    workspaces[source]?.forget(window, shareSpace: settings.shareRemovedSpace)
    if let frame { workspaces[destination]?.floating[window] = frame }
  }

  /// The frame `transfer` lets `window` arrive at. A drop hands it to `Drop.arrivingFrame` instead.
  func frameAfterTransfer(of window: WindowID, from source: DisplayID, to destination: DisplayID) -> CGRect? {
    guard let frame = workspaces[source]?.undockedFrame(of: window) ?? workspaces[source]?.floating[window],
      let old = display(source)?.visibleFrame, let new = display(destination)?.visibleFrame
    else { return nil }
    return frame.offsetBy(dx: new.minX - old.minX, dy: new.minY - old.minY).fitted(into: new)
  }
}
