import ArborCore
import CoreGraphics

/// What the controller knows about one window at a moment in time.
public struct WindowSnapshot: Equatable, Sendable {
  public var id: WindowID
  public var pid: Int32
  public var bundleID: String?
  public var appName: String
  public var title: String
  /// Global top-left-origin coordinates.
  public var frame: CGRect
  public var isMinimized: Bool
  /// The window's app is hidden (⌘H).
  public var isHidden: Bool
  /// False while the window is on a Space that is not showing. The
  /// Accessibility API stops listing such windows, but they still exist.
  public var isOnActiveSpace: Bool
  /// The window is in macOS's own full screen (the green button). It has a Space to itself and
  /// cannot be moved or resized until it leaves.
  public var isFullScreen: Bool
  /// False if the window's size cannot be changed at all (Calculator, "About" boxes, most settings windows).
  /// True says little: the window may still have a minimum, a maximum or one fixed side.
  public var isResizable: Bool

  public init(
    id: WindowID, pid: Int32, bundleID: String?, appName: String, title: String, frame: CGRect,
    isMinimized: Bool = false, isHidden: Bool = false, isOnActiveSpace: Bool = true, isFullScreen: Bool = false,
    isResizable: Bool = true
  ) {
    self.id = id
    self.pid = pid
    self.bundleID = bundleID
    self.appName = appName
    self.title = title
    self.frame = frame
    self.isMinimized = isMinimized
    self.isHidden = isHidden
    self.isOnActiveSpace = isOnActiveSpace
    self.isFullScreen = isFullScreen
    self.isResizable = isResizable
  }

  /// Whether the window takes up space in the layout.
  public var isPresent: Bool { !isMinimized && !isHidden && isOnActiveSpace && !isFullScreen }
}

public struct DisplaySnapshot: Equatable, Sendable {
  public var id: DisplayID
  /// Full bounds, global top-left-origin coordinates.
  public var frame: CGRect
  /// Bounds minus the menu bar and Dock.
  public var visibleFrame: CGRect
  /// The display with the menu bar.
  public var isMain: Bool
  /// What macOS calls the display ("Studio Display"), for telling displays apart in what users read.
  public var name: String?
  /// A laptop's or an iMac's own display.
  public var isBuiltIn: Bool

  /// What it shows is shown on another display as well: a projector, a television, AirPlay. Of such a set macOS
  /// lists one display.
  public var isMirrored: Bool

  public init(
    id: DisplayID, frame: CGRect, visibleFrame: CGRect, isMain: Bool, name: String? = nil, isBuiltIn: Bool = false,
    isMirrored: Bool = false
  ) {
    self.id = id
    self.frame = frame
    self.visibleFrame = visibleFrame
    self.isMain = isMain
    self.name = name
    self.isBuiltIn = isBuiltIn
    self.isMirrored = isMirrored
  }

  /// What the `displays` entries of settings.json are matched against.
  public var traits: DisplayTraits {
    DisplayTraits(id: id, name: name ?? "", isMain: isMain, isBuiltIn: isBuiltIn, size: frame.size)
  }
}

/// The seam between Arbor's logic and macOS. `AXWindowSystem` implements it
/// with the Accessibility API; `FakeWindowSystem` (ArborTesting) implements it
/// in memory so the controller can be tested without permissions or windows.
@MainActor
public protocol WindowSystem: AnyObject {
  var events: (any WindowSystemEvents)? { get set }

  /// Begins observing apps and windows. Window events flow to `events` from here on.
  func start()
  func stop()

  /// Every standard window the system can currently see.
  func allWindows() -> [WindowSnapshot]
  func displays() -> [DisplaySnapshot]

  /// Moves and resizes a window. Returns the frame the window actually took
  /// (apps can refuse sizes below their minimum), or nil if the window is gone
  /// or its app is not answering, in which case nothing is known about where it is.
  @discardableResult
  func setFrame(_ frame: CGRect, of window: WindowID) -> CGRect?

  /// Raises the window and activates its app.
  func focus(_ window: WindowID)
  func focusedWindow() -> WindowID?

  func cursorLocation() -> CGPoint
  func isMouseButtonDown() -> Bool

  /// The numbers of all windows that exist, including those `allWindows()` cannot see because their
  /// Space is not showing. Arbor keeps the saved slot of a window that is only out of sight
  /// (Controller+PendingSlots.swift). May include windows Arbor would never arrange.
  func existingWindowIDs() -> Set<WindowID>
  /// What the user's hands did last: how long the pointer and the keyboard have been still.
  func inputActivity() -> InputActivity

  /// Whether the shortcut's key and all its modifier keys are down right now, whichever app has the keyboard.
  func isHolding(_ chord: KeyChord) -> Bool

  /// Brings the window in front of the others. Unlike `focus`, the keyboard stays where it is
  /// and the window's app is not activated. Only for a window kept in view: the order is macOS's, and Arbor
  /// raises nothing else (collab/QUESTIONS.md, Q20 and Q25). It cannot lift a window over the active app's key window.
  func raise(_ window: WindowID)

  /// How the windows on screen are stacked, frontmost first. It may list windows nobody asked
  /// about and leave out windows it cannot place. Stand-ins are stacked like the windows they stand for.
  func windowsFrontToBack() -> [WindowID]

  /// How long ago the user last pressed or let go of a mouse button or a modifier key, in seconds.
  /// What happens right afterwards (an app coming forward) is probably what they asked for.
  func secondsSinceClickOrModifierKey() -> Double

  /// While `leave` is true, dialogs that open out of view stay there; when it turns false, those that are still
  /// open are brought into view (F47, F58). Those of the app `inUse` never wait: it would look hung to whoever is in it.
  func leaveStrayDialogs(_ leave: Bool, exceptOfApp inUse: String?)
  /// Brings the dialogs of one app that are waiting into view, while those of other apps go on waiting.
  func bringInStrayDialogs(ofApp bundleID: String?)
  /// How many dialogs are waiting out of view and still open.
  func strayDialogsWaiting() -> Int
  /// Every window on screen at the normal level, frontmost first, with its frame: also the ones that
  /// are not in `allWindows()` (dialogs, sheets, panels, apps that are not observed, Arbor's own
  /// windows), but not Arbor's overlays. What is drawn over the screen has to reckon with all of them.
  func stackedWindows() -> [StackedWindow]

  /// Brings the app with this bundle id or name to the front as a click on its Dock icon does: it is
  /// launched if it is not running, shown if it is hidden, and asked for a window if it has none. What comes
  /// of it arrives as events. Returns false if there is no such app.
  func openApplication(_ app: String) -> Bool

  /// The modifier keys held right now, whichever app has the keyboard.
  func modifierKeysDown() -> KeyChord.Modifiers
  /// Opens an app, given its name or bundle id, **without** bringing it to the front, which is where it differs from
  /// `openApplication`: `layout --open` may open several, and none of them is to take the keyboard. Its windows arrive as
  /// `windowAppeared` when it is ready. Returns false if the attempt could not even be made; an
  /// app that does not exist is found out later, and only logged.
  func launchApp(_ name: String) -> Bool

  /// Minimizes a window or brings it back from the Dock. `windowChanged` says when it has happened,
  /// which on macOS is a moment later.
  func setMinimized(_ window: WindowID, _ minimized: Bool)
  /// Shows a hidden app (⌘H) again. Each of its windows reports `windowChanged`, a moment later too.
  func unhideApp(pid: Int32)

  /// Says which `setFrame` calls are about to follow, so that they need not wait for one app after the other. A window
  /// system that can moves these windows now, those of different apps side by side, waits only so long for all of them
  /// together, and keeps what came of each move as the answer to the next `setFrame` of that window with that very
  /// frame. A call with another frame moves the window as always. Answers nobody asks for are dropped at
  /// the next `moveTogether`, and the windows reported where they are. It changes what the calls cost, never what
  /// they return. The default does nothing.
  func moveTogether(_ frames: [(window: WindowID, frame: CGRect)])

  /// `setFrame` for one window of the app `pid` while the window system is stopped (a pause), without starting it:
  /// starting asks every running app for its windows, and one that hangs, which is a reason to pause, makes
  /// everybody wait. Nothing is observed or reported because of it. The default starts, moves and stops.
  func setFrameOnce(_ frame: CGRect, of window: WindowID, pid: Int32) -> CGRect?

  /// Which parts of macOS's own tiling of dragged windows are switched on right now. Asked when a drag begins: where
  /// macOS takes the window, Arbor stands aside (`MacTiling`). No default: in a wrapper that forgot to pass it on, the fight
  /// over the window would be back in silence.
  func macTiling() -> MacTiling
}

extension WindowSystem {
  /// A window system that cannot tell: saved slots then wait a few minutes, by app and title.
  public func existingWindowIDs() -> Set<WindowID> { [] }

  /// A window system that moves no dialogs has none to leave.
  public func leaveStrayDialogs(_ leave: Bool, exceptOfApp inUse: String?) {}
  public func bringInStrayDialogs(ofApp bundleID: String?) {}
  public func strayDialogsWaiting() -> Int { 0 }

  /// A window system that cannot tell says that the pointer has just moved, so every command follows it.
  public func inputActivity() -> InputActivity {
    InputActivity(pointerIdle: 0, keyboardIdle: .infinity, keyPresses: 0)
  }

  /// A window system that cannot tell leaves it to the key's own release to say so.
  public func isHolding(_ chord: KeyChord) -> Bool { true }


  public func moveTogether(_ frames: [(window: WindowID, frame: CGRect)]) {}

  public func setFrameOnce(_ frame: CGRect, of window: WindowID, pid: Int32) -> CGRect? {
    start()
    defer { stop() }
    return setFrame(frame, of: window)
  }
}

/// Notifications from a `WindowSystem`. All arrive on the main actor.
@MainActor
public protocol WindowSystemEvents: AnyObject {
  func windowAppeared(_ window: WindowSnapshot)
  func windowDestroyed(_ id: WindowID)
  /// The window moved, resized, minimized, was hidden, or changed title.
  /// `userInitiated` is false when the change matches a frame Arbor just set.
  func windowChanged(_ window: WindowSnapshot, userInitiated: Bool)
  func windowFocused(_ id: WindowID)
  /// Another app came to the front, or nil if nobody knows which. Also sent once at launch, and, unlike
  /// everything else here, while the window system is stopped: a pause may be waiting for it.
  func applicationActivated(_ app: FrontmostApp?)
  /// macOS refused a call because Accessibility is disabled for Arbor (`apiDisabled`). May be sent from inside
  /// `setFrame` or `focus`, and as often as it happens.
  func accessibilityWasRefused()
  /// The user started dragging a window by its title bar.
  func dragBegan(_ id: WindowID, at point: CGPoint)
  func dragMoved(_ id: WindowID, to point: CGPoint)
  func dragEnded(_ id: WindowID, at point: CGPoint)
  func displaysChanged()
  /// The user started resizing a window by dragging its edges with the mouse.
  func resizeBegan(_ id: WindowID)
  /// The user released the mouse after resizing a window by its edges. A
  /// `windowChanged` with the frame the window ended at arrives just before.
  func resizeEnded(_ id: WindowID)
  /// The keyboard may be somewhere else now, and no `windowFocused` says so: another app came to the
  /// front (which changes no app's own focused window), or the keyboard went to something that is not in
  /// `allWindows()`, like a sheet, a panel or the desktop. `focusedWindow()` says where it is.
  func keyboardFocusMoved()
  /// The drag is over but nobody saw where the button was released (another tool swallowed the event,
  /// say), so there is no drop to act on.
  func dragCancelled(_ id: WindowID)
  /// `window` has taken the place of `old` on screen: another tab of a native macOS tab group came to
  /// the front. `old` still exists but is not shown, and nothing more is reported about it unless it
  /// shows again, which is reported with this method or, if it got a window of its own, `windowAppeared`.
  func windowReplaced(_ old: WindowID, by window: WindowSnapshot)
  /// The left mouse button went down, on anything. A click brings the window under it to the front, also one
  /// that has the keyboard already, and nothing else reports that change of stacking.
  func pointerPressed()
  /// A window that was open all along has come to notice: its macOS Space is showing for the first time
  /// since `start()`. Nobody just opened it, which is what `windowAppeared` says.
  func windowFound(_ window: WindowSnapshot)
}

extension WindowSystemEvents {
  /// To a listener that makes no difference between the two, a window that was found is one more window.
  public func windowFound(_ window: WindowSnapshot) { windowAppeared(window) }
}
