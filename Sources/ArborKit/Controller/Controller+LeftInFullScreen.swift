import ArborCore
import CoreGraphics
import Foundation

/// A window in macOS's full screen cannot be moved, and when it leaves full screen macOS gives it the frame it had before.
/// If it went into full screen while it was out of view, that frame is the corner Arbor keeps such windows in. While
/// Arbor runs that is no harm: the window is reported back and laid out. But a pause or a quit brings everything
/// into view except this window, and later it comes back to a corner where nobody looks for it.
///
/// So the pause remembers which windows those are and where they belong, and goes on looking for them, and for nothing
/// else: once a second it asks the window server (not the apps) where they are. One that turns up out of view is put
/// where the pause would have put it, which takes a word with its app and no other. After a quit the next launch does
/// it, as for any window found in the corner.
extension Controller {
  struct LeftInFullScreen {
    struct Note {
      /// Where the window goes when it is back.
      var frame: CGRect
      var pid: Int32
      /// How often it has been asked and did not go: it may still be on its way.
      var attempts = 0
    }
    var notes: [WindowID: Note] = [:]
    /// How often this pause has looked for them.
    var looks = 0
  }

  static let lookForFullScreenReturnsKey = "back-from-full-screen"

  /// The windows Arbor could not bring into view when it let go of them, and will when they leave full screen. The only
  /// windows it ever moves without arranging them.
  public var windowsOwedAPlace: Set<WindowID> { Set(leftInFullScreen.notes.keys) }

  /// Called by `shutdown` while it still knows what is out of view.
  func noteWindowsLeftInFullScreen() {
    // What is owed to windows Arbor no longer arranges (below) is still owed.
    leftInFullScreen = LeftInFullScreen(notes: leftInFullScreen.notes.filter { windows[$0.key]?.isFullScreen == true })
    for window in parked.sorted() {
      guard let snapshot = windows[window], snapshot.isFullScreen, let id = workspaceID(containing: window),
        let workspace = workspaces[id], let display = display(id)
      else { continue }
      // Whoever reads the note takes a frame of which less than half shows for one out of view, and fits it into the main display.
      let frame =
        (frameAsItWas(of: window, on: id) ?? workspace.floating[window].map { asItWas($0, on: display) })
        .map { showsLessThanHalf($0) ? asItWas($0, on: display) : $0 }
        ?? slotWithEverythingInView(of: window, in: workspace, on: display)
      if let frame { leftInFullScreen.notes[window] = LeftInFullScreen.Note(frame: frame, pid: snapshot.pid) }
    }
  }

  private func slotWithEverythingInView(of window: WindowID, in workspace: Workspace, on display: DisplaySnapshot) -> CGRect? {
    var options = options(for: display.id).layoutOptions
    options.minimumUsableSize = .zero
    let layout = LayoutEngine.layout(
      workspace.tree, camera: workspace.tree.root, in: display.visibleFrame, options: options, isPresent: { _ in true })
    return workspace.tree.leaf(containing: window).flatMap { layout.nodeFrames[$0] }
  }

  // MARK: Windows Arbor stops arranging

  /// Arbor stops arranging a window that is out of view (its app was excluded), and cannot bring it into view first.
  /// `frame` is where it would have gone. Arbor goes on hearing of it, and puts it there when it leaves full screen.
  func noteIfInFullScreen(_ window: WindowID, belongsAt frame: CGRect?, on display: DisplaySnapshot) {
    guard let snapshot = windows[window], snapshot.isFullScreen else { return }
    // The size it has in the corner, in the middle of the display, as for any such window.
    let visible = display.visibleFrame
    let size = settled[window]?.size ?? CGSize(width: visible.width / 2, height: visible.height / 2)
    let centred = CGRect(
      x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height)
    leftInFullScreen.notes[window] = LeftInFullScreen.Note(frame: frame ?? centred.fitted(into: visible), pid: snapshot.pid)
  }

  /// Called with every report about a window.
  func putBackIfItLeftFullScreen(_ window: WindowSnapshot, was previous: WindowSnapshot?) {
    guard isRunning, previous?.isFullScreen == true, !window.isFullScreen else { return }
    putBackNow(window.id)
  }

  private func putBackNow(_ window: WindowID) {
    guard isRunning, var note = leftInFullScreen.notes[window] else { return }
    // Arranged again meanwhile, it is seen to like every window. Closed, there is nothing to do.
    guard windows[window] != nil, !isManaged(window), isMostlyOffScreen(window), let main = mainDisplayID.flatMap(display)
    else {
      leftInFullScreen.notes[window] = nil
      return
    }
    let fits = !showsLessThanHalf(note.frame)
    if let actual = give(fits ? note.frame : note.frame.fitted(into: main.visibleFrame), to: window)?.frame {
      windows[window]?.frame = actual
    }
    guard isMostlyOffScreen(window) else {
      leftInFullScreen.notes[window] = nil
      return
    }
    // Still on its way (Controller+OnTheWayBack.swift).
    note.attempts += 1
    leftInFullScreen.notes[window] = note.attempts < 5 ? note : nil
    scheduler.schedule("\(Self.lookForFullScreenReturnsKey)-\(window.rawValue)", after: 0.5) { [weak self] in
      self?.putBackNow(window)
    }
  }

  // MARK: During a pause

  /// Called when a pause has begun.
  func lookOutForWindowsLeftInFullScreen() {
    guard isPaused, !leftInFullScreen.notes.isEmpty else { return }
    // A film can last for hours, and a pause should cost next to nothing: after the first minute Arbor looks less often.
    scheduler.schedule(Self.lookForFullScreenReturnsKey, after: leftInFullScreen.looks < 60 ? 1 : 3) { [weak self] in
      self?.putBackWhatLeftFullScreen()
      self?.lookOutForWindowsLeftInFullScreen()
    }
  }

  /// Called by `start()` once it knows the windows there are. What Arbor arranges is seen to by every start. After a pause
  /// a window it does not arrange, still in full screen, is still owed its place. A launch owes nothing: the note
  /// does not outlive Arbor.
  func keepOnlyWhatIsStillOwedAfterAStart() {
    let notes = isResuming ? leftInFullScreen.notes.filter { windows[$0.key]?.isFullScreen == true && !isManaged($0.key) } : [:]
    leftInFullScreen = LeftInFullScreen(notes: notes)
  }

  /// Called when Arbor quits during a pause.
  func forgetWindowsLeftInFullScreen() {
    leftInFullScreen = LeftInFullScreen()
    scheduler.cancel(Self.lookForFullScreenReturnsKey)
    forgetWhatCouldNotComeBack()
  }

  private func putBackWhatLeftFullScreen() {
    guard isPaused else { return }
    leftInFullScreen.looks += 1
    // The list of every window there is costs the most, and a window that has closed can wait to be forgotten.
    if leftInFullScreen.looks % 5 == 0 {
      let existing = system.existingWindowIDs()
      leftInFullScreen.notes = leftInFullScreen.notes.filter { existing.contains($0.key) }
    }
    let listed = system.stackedWindows().filter { leftInFullScreen.notes[$0.id] != nil }
    let screens = system.displays()
    guard !listed.isEmpty, let main = screens.first(where: \.isMain) ?? screens.first else { return }
    func isOutOfView(_ frame: CGRect) -> Bool { frame.showsLessThanHalf(on: screens.map(\.frame)) }
    // In full screen, and on the way out of it, it is in view or not listed.
    for window in listed.filter({ isOutOfView($0.frame) }).map(\.id).sorted() {
      guard var note = leftInFullScreen.notes[window] else { continue }
      // The display it was meant for may have gone during the pause.
      let target = isOutOfView(note.frame) ? note.frame.fitted(into: main.visibleFrame) : note.frame
      if let actual = system.setFrameOnce(target, of: window, pid: note.pid), !isOutOfView(actual) {
        leftInFullScreen.notes[window] = nil
        Log.info("\(window) left full screen during the pause and came back into view")
        continue
      }
      note.attempts += 1
      leftInFullScreen.notes[window] = note.attempts < 5 ? note : nil
    }
  }
}
