import CoreGraphics

/// A read-only picture of the window manager, returned by the `state`
/// command. Tests, `arborctl state` and the end-to-end runner read it.
public struct StateSnapshot: Codable, Sendable, Equatable {
  public struct Display: Codable, Sendable, Equatable {
    public var id: DisplayID
    public var frame: CGRect
    public var visibleFrame: CGRect
    public var camera: NodeID
    public var tree: LayoutTree
    public var windowFrames: [WindowID: CGRect]
    public var tiles: [Tile]
    public var desktopFrame: CGRect?
    public var floating: [WindowID]
    public var canGoBack: Bool
    public var canGoForward: Bool
    public var savedViews: [String: NodeID]
    /// The names of this display's spaces (F20).
    public var names: [String: NodeID] = [:]
    /// What `undo` and `redo` would take back or put back on this display (`dock w101 left`);
    /// nil when there is nothing to undo or redo.
    public var undo: String?
    public var redo: String?

    public init(
      id: DisplayID, frame: CGRect, visibleFrame: CGRect, camera: NodeID, tree: LayoutTree,
      windowFrames: [WindowID: CGRect], tiles: [Tile], desktopFrame: CGRect?,
      floating: [WindowID], canGoBack: Bool, canGoForward: Bool, savedViews: [String: NodeID]
    ) {
      self.id = id
      self.frame = frame
      self.visibleFrame = visibleFrame
      self.camera = camera
      self.tree = tree
      self.windowFrames = windowFrames
      self.tiles = tiles
      self.desktopFrame = desktopFrame
      self.floating = floating
      self.canGoBack = canGoBack
      self.canGoForward = canGoForward
      self.savedViews = savedViews
    }
  }

  public struct Window: Codable, Sendable, Equatable {
    public var id: WindowID
    public var pid: Int32
    public var app: String
    public var bundleID: String?
    public var title: String
    public var frame: CGRect
    public var minimized: Bool
    public var hidden: Bool
    public var managed: Bool
    public var docked: Bool
    public var parked: Bool
    public var display: DisplayID?
    /// In macOS's own full screen, where Arbor leaves it alone.
    public var fullScreen: Bool
    /// Floating, and kept in view wherever the camera goes.
    public var pinned = false
    /// Floating, and brought over the view by `summon` until the keyboard goes elsewhere.
    public var summoned = false
    /// Floating, and out of view until it is summoned again.
    public var stashed = false
    /// The space a floating window opened over and goes in and out of view with, if not the Desktop (F57).
    public var guestOf: NodeID?

    public init(
      id: WindowID, pid: Int32, app: String, bundleID: String?, title: String, frame: CGRect,
      minimized: Bool, hidden: Bool, managed: Bool, docked: Bool, parked: Bool,
      display: DisplayID?, fullScreen: Bool = false, guestOf: NodeID? = nil
    ) {
      self.id = id
      self.pid = pid
      self.app = app
      self.bundleID = bundleID
      self.title = title
      self.frame = frame
      self.minimized = minimized
      self.hidden = hidden
      self.managed = managed
      self.docked = docked
      self.parked = parked
      self.display = display
      self.fullScreen = fullScreen
      self.guestOf = guestOf
    }
  }

  public var accessibility: Bool
  public var running: Bool
  public var focused: WindowID?
  public var displays: [Display]
  public var windows: [Window]
  /// Between `pause` and `resume`. `running` is false, `windows` is empty because Arbor is not
  /// looking, and `displays` holds the arrangement that `resume` will bring back.
  public var paused = false
  /// Places in `displays[].tree` whose window is not in `windows`: kept for a window that is expected back.
  public var waiting: [Waiting] = []

  public struct Waiting: Codable, Sendable, Equatable {
    /// The number the place has in the tree. If `open` is false it is a stand-in that no window has.
    public var id: WindowID
    public var bundleID: String?
    public var title: String
    /// The display whose arrangement has the place, connected or not.
    public var display: DisplayID?
    /// True: the window exists, out of Arbor's sight on another Space, and keeps the place for as long as it
    /// does. False: it is not open yet (after a login or a restart of its app), and the place is kept for minutes.
    public var open: Bool

    public init(id: WindowID, bundleID: String?, title: String, display: DisplayID?, open: Bool) {
      self.id = id
      self.bundleID = bundleID
      self.title = title
      self.display = display
      self.open = open
    }
  }
  /// `"view"` after `hold`, `"still"` after `hold still` or while a call's window is open; otherwise absent.
  public var held: HoldLevel?

  public init(
    accessibility: Bool, running: Bool, focused: WindowID?, displays: [Display], windows: [Window]
  ) {
    self.accessibility = accessibility
    self.running = running
    self.focused = focused
    self.displays = displays
    self.windows = windows
  }

  public func window(_ id: WindowID) -> Window? { windows.first { $0.id == id } }

  public func display(containing window: WindowID) -> Display? {
    displays.first { $0.tree.leaf(containing: window) != nil || $0.floating.contains(window) }
  }
}
