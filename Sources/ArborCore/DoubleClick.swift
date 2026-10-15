import CoreGraphics

/// Where a double-click means something to Arbor, and what it means there
/// (docs/features/F14-double-click-actions.md).
///
/// The controller makes one of these from its layouts (`Controller.doubleClickZones()`). It is a plain
/// value, so the event tap that watches real clicks keeps the latest copy and decides from that, on
/// whatever thread it runs, without calling into the controller while macOS holds the click back.
public struct DoubleClickZones: Equatable, Sendable {
  /// What fills a display's view, as far as double-clicks care.
  public enum Framed: Equatable, Sendable {
    /// One docked window on its own.
    case window(WindowID)
    case desktop
    /// A group of spaces, or everything.
    case group
  }

  /// The strip along the top of a visible docked window.
  public struct TitleBar: Equatable, Sendable {
    public var window: WindowID
    public var frame: CGRect

    /// The top `height` points of a window at `windowFrame`.
    public init(window: WindowID, windowFrame: CGRect, height: CGFloat) {
      self.window = window
      frame = CGRect(
        x: windowFrame.minX, y: windowFrame.minY, width: windowFrame.width,
        height: min(max(height, 0), windowFrame.height))
    }
  }

  public struct Display: Equatable, Sendable {
    public var id: DisplayID
    /// The whole display, menu bar and Dock included.
    public var frame: CGRect
    /// Empty when `titleBarDoubleClick` is off.
    public var titleBars: [TitleBar]
    /// The Desktop's part of the view. Nil when it is out of view or a tile, or `desktopDoubleClick` is off.
    public var desktop: CGRect?
    /// Tiles take their own clicks.
    public var tiles: [CGRect]
    /// Visible floating windows, and windows Arbor does not arrange. They cover whatever is under them and
    /// keep macOS's behaviour.
    public var floating: [CGRect]
    public var framed: Framed
    /// What leaves the framed thing for a wider view (`back`, `out` or `show-all`), as pressing ⌃⌥↩ again would
    /// (`Controller.wayOut(of:on:)`). Nil when nothing is wider: a double-click on it then does nothing.
    public var unframe: Command?

    public init(
      id: DisplayID, frame: CGRect, titleBars: [TitleBar] = [], desktop: CGRect? = nil, tiles: [CGRect] = [],
      floating: [CGRect] = [], framed: Framed = .group, unframe: Command? = nil
    ) {
      self.id = id
      self.frame = frame
      self.titleBars = titleBars
      self.desktop = desktop
      self.tiles = tiles
      self.floating = floating
      self.framed = framed
      self.unframe = unframe
    }
  }

  /// A tile that a click has just opened. Someone used to double-clicking tiles (TrellisWM's way) clicks again, and
  /// by then the window that was framed is under the pointer. That second click belongs to nobody.
  public struct OpenedTile: Equatable, Sendable {
    /// Where the tile was.
    public var frame: CGRect
    /// When it opened, in seconds since the reference date (`Controller.now()`).
    public var time: Double

    public init(frame: CGRect, time: Double) {
      self.frame = frame
      self.time = time
    }
  }

  /// What was double-clicked.
  public enum Target: Equatable, Sendable {
    case titleBar(WindowID)
    case desktop(DisplayID)
    /// The place of a tile that the first click of the pair opened.
    case openedTile
  }

  /// A double-click that is Arbor's.
  public struct Hit: Equatable, Sendable {
    public var target: Target
    /// What to run. Nil for a click that only has to disappear.
    public var command: Command?

    public init(target: Target, command: Command?) {
      self.target = target
      self.command = command
    }

    /// Whether the app under the pointer must not see the click. A title bar's own double-click action
    /// (zoom or minimize) would run as well. A double-click on bare wallpaper does nothing in Finder, and
    /// with "Click wallpaper to reveal desktop" on, macOS needs the second click to undo what the first did.
    public var hidesClickFromApps: Bool {
      switch target {
      case .titleBar, .openedTile: true
      case .desktop: false
      }
    }

    /// Whether it matters what is really under the pointer (`PointerCover`, `isBackground`). Whatever has
    /// come to lie where a tile was, the click was not meant for it.
    public var dependsOnWhatIsThere: Bool { target != .openedTile }
  }

  /// macOS's double-click time unless the user has changed it (`NSEvent.doubleClickInterval`).
  public static let usualInterval = 0.5

  public var displays: [Display]
  public var openedTile: OpenedTile?

  public init(displays: [Display] = [], openedTile: OpenedTile? = nil) {
    self.displays = displays
    self.openedTile = openedTile
  }

  /// The command a double-click at `point` (global coordinates) runs, or nil when there is none:
  /// inside a window's content, on a floating window, on a tile, in the gaps between docked windows.
  public func action(at point: CGPoint) -> Command? {
    hit(at: point)?.command
  }

  /// What the second click of a double-click at `point` means to Arbor; nil when it is not Arbor's.
  ///
  /// - Parameters:
  ///   - time: now, counted as `OpenedTile.time` is. Without it no tile counts as just opened.
  ///   - interval: how long after a click another still makes a double-click.
  ///   - floatingWindowsCover: whether `floating` hides what is under it. The event tap passes
  ///     false, because it goes on to ask the window server what is really under the pointer
  ///     (`PointerCover`). That answer knows which window is in front and where the user has
  ///     dragged a floating window since the last layout; these frames do not.
  public func hit(
    at point: CGPoint, time: Double? = nil, interval: Double = DoubleClickZones.usualInterval,
    floatingWindowsCover: Bool = true
  ) -> Hit? {
    // First, because the window a tile opened into fills the view, title bar and all: taken for a
    // double-click on that, the second click would undo what the first did.
    if let time, let openedTile, openedTile.frame.contains(point), abs(time - openedTile.time) < interval {
      return Hit(target: .openedTile, command: nil)
    }
    // A floating window can hang over the edge of a neighbouring display, so look at all of them first.
    if floatingWindowsCover, displays.contains(where: { $0.floating.contains { $0.contains(point) } }) {
      return nil
    }
    for display in displays {
      if display.tiles.contains(where: { $0.contains(point) }) { return nil }
      if let bar = display.titleBars.first(where: { $0.frame.contains(point) }) {
        // With nothing wider to go to there is nothing to run, but the click is Arbor's all the same: macOS
        // would zoom or minimize a docked window, and Arbor would have to put it back.
        let command = display.framed == .window(bar.window) ? display.unframe : .zoom(bar.window)
        return Hit(target: .titleBar(bar.window), command: command)
      }
      if let desktop = display.desktop, desktop.contains(point) {
        let command = display.framed == .desktop ? display.unframe : .desktop
        return command.map { Hit(target: .desktop(display.id), command: $0) }
      }
    }
    return nil
  }
}

// MARK: What is really under the pointer

/// One window as the window server lists it (`CGWindowListCopyWindowInfo`).
public struct ListedWindow: Equatable, Sendable {
  public var id: WindowID
  public var pid: Int32
  /// 0 for ordinary windows, above 0 for panels, menus and the Dock, below 0 for the wallpaper and Desktop icons.
  public var layer: Int
  public var frame: CGRect
  public var alpha: Double

  public init(id: WindowID, pid: Int32, layer: Int, frame: CGRect, alpha: Double = 1) {
    self.id = id
    self.pid = pid
    self.layer = layer
    self.frame = frame
    self.alpha = alpha
  }
}

/// What a click at some point would land on, judged from the window server's list. Arbor's zones
/// only know the windows it arranges; this is what keeps it from taking clicks meant for the others.
public enum PointerCover: Equatable, Sendable {
  /// An ordinary window, and the process that owns it.
  case window(WindowID, pid: Int32)
  /// No window: the Desktop. `pid` owns what is drawn there (Finder's icons, otherwise the wallpaper).
  case desktop(pid: Int32?)
  /// Something above the ordinary windows (a menu, a floating panel, a video in a corner), or
  /// one of Arbor's own tiles and handles.
  case somethingElse

  /// The process to ask what exactly is under the pointer, if there is one.
  public var owner: Int32? {
    switch self {
    case .window(_, let pid): pid
    case .desktop(let pid): pid
    case .somethingElse: nil
    }
  }

  /// - Parameters:
  ///   - windows: every window on screen, front to back, Desktop elements included.
  ///   - ownPID: Arbor's process. Its windows are looked through (previews and backdrops ignore the
  ///     mouse) unless they are in `ownClickable`.
  ///   - ownClickable: the windows of Arbor's that take clicks.
  ///   - displays: the displays' frames. The Dock keeps a window as large as each display above the ordinary ones, which is
  ///     looked through. Nothing else up there is: a click is about to be kept from everybody, so this knows what is harmless
  ///     and leaves the rest its clicks (docs/ARCHITECTURE.md, "Pointer input"). Where that is wrong the double-click is macOS's.
  ///     Below the windows, what belongs to the Desktop itself is as large as the display, and anything smaller is a widget.
  public static func at(
    _ point: CGPoint, windows: [ListedWindow], ownPID: Int32, ownClickable: Set<WindowID> = [],
    displays: [CGRect] = []
  ) -> PointerCover {
    for window in windows where window.alpha > 0 && window.frame.contains(point) {
      if window.pid == ownPID {
        if ownClickable.contains(window.id) { return .somethingElse }
        continue
      }
      if window.layer > 0 {
        if window.layer == PointerSurface.dockLevel, displays.contains(where: { window.frame.contains($0) }) { continue }
        return .somethingElse
      }
      if window.layer == 0 { return .window(window.id, pid: window.pid) }
      return displays.contains(where: { window.frame.contains($0) }) ? .desktop(pid: window.pid) : .somethingElse
    }
    return .desktop(pid: nil)
  }
}

extension DoubleClickZones.Hit {
  /// Whether the click would really land on what the zones say is there.
  public func lands(on cover: PointerCover) -> Bool {
    switch (target, cover) {
    case (.titleBar(let expected), .window(let window, _)): window == expected
    case (.desktop, .desktop), (.openedTile, _): true
    default: false
    }
  }

  /// Whether the Accessibility element under the pointer is plain background rather than something
  /// with a use for the click.
  ///
  /// - Parameters:
  ///   - roles: the element's role, then its parent's, and so on up to the window or for a few levels. Empty
  ///     when the app did not answer, or not all the way.
  ///   - windowHasButtons: whether the window has a close, minimize or zoom button; nil when unknown.
  public func isBackground(roles: [String], windowHasButtons: Bool? = nil) -> Bool {
    switch target {
    case .titleBar:
      // Browsers and unified toolbars put real controls in the top of the window: a double-click in
      // an address field selects a word, two quick clicks on a Back button go back twice. So only
      // roles known to be scenery count, all the way up: text inside a button is not scenery.
      // No answer is a no. An app that cannot say what is under the pointer is busy, and what keeps it
      // busy is most likely what the first click set off: a sidebar that slides out, say.
      // A window without buttons has its title bar hidden (terminals are often set up that way),
      // and its top 28 points are content, whatever they call themselves.
      guard !roles.isEmpty, roles.allSatisfy(Self.titleBarScenery.contains), windowHasButtons == true else {
        return false
      }
      // A group says nothing by itself. Apps that draw their own title bar beside real traffic lights (Electron)
      // have buttons there that Accessibility may know only as a group; in a toolbar or a split group it is AppKit's.
      if roles.contains("AXGroup"), !roles.contains(where: Self.groupHolders.contains) { return false }
      // A window's title is text right under the window. Text any deeper labels something: the address in
      // Safari's field, while nobody is typing there, is static text in a group beside the field.
      return roles.first != "AXStaticText" || (roles.count > 1 && Self.titleHolders.contains(roles[1]))
    case .desktop:
      // The click still reaches Finder, so a wrong yes costs one camera move and a wrong no makes the
      // feature dead (with Finder's icons switched off, whoever draws the wallpaper has nothing to
      // say). Only what is known to be an item on the Desktop says no.
      return !roles.contains(where: Self.desktopItems.contains)
    case .openedTile:
      return true
    }
  }

  /// Whether it is worth asking on, given the roles so far, from the element under the pointer upwards. Every question holds
  /// the click back a little longer, and a click on a control, which is the one that is not Arbor's, is known for one at the
  /// first answer. False means that `isBackground` says no whatever follows.
  public func canStillBeBackground(rolesSoFar roles: [String]) -> Bool {
    switch target {
    case .titleBar:
      guard roles.allSatisfy(Self.titleBarScenery.contains) else { return false }
      // Text any deeper than right under the window or the toolbar labels something.
      return roles.first != "AXStaticText" || roles.count < 2 || Self.titleHolders.contains(roles[1])
    case .desktop: return !roles.contains(where: Self.desktopItems.contains)
    case .openedTile: return true
    }
  }

  /// The empty parts of a toolbar are the toolbar or a group in it; above a sidebar there is a split group.
  /// `scripts/mac-shell/ax-roles.swift` prints what an app really has there.
  static let titleBarScenery: Set<String> = [
    "AXWindow", "AXToolbar", "AXGroup", "AXStaticText", "AXSplitGroup", "AXApplication",
  ]

  static let titleHolders: Set<String> = ["AXWindow", "AXToolbar"]

  static let groupHolders: Set<String> = ["AXToolbar", "AXSplitGroup"]

  static let desktopItems = PointerSurface.desktopItems
}

// MARK: The clicks

/// Follows the left mouse button and says what to do with each of its events, for the event tap
/// (`Input/DoubleClickTap.swift`).
///
/// The first click of a pair has already gone to the app by the time the second arrives, which is
/// fine: it focuses the window. Whether the second press is a click is known only when the button comes up:
/// someone who clicks a title bar and at once starts to drag it, or drags with a double tap on a trackpad set up for
/// that, presses a second time too, and dragging a docked window by its title bar is how it is docked elsewhere. macOS's
/// own title-bar action waits for the mouse-up as well. So a press that may be Arbor's is held back. If the button
/// comes up where it went down, both halves are hidden and the command runs: macOS's action may run on either, and
/// an app that saw a mouse-down without its mouse-up would think the button was still held. If the pointer
/// moves away first, the app is given the mouse-down it missed and everything after it.
public struct DoubleClickGesture: Equatable, Sendable {
  /// What to do with one mouse event.
  public enum Response: Equatable, Sendable {
    /// Let it through untouched.
    case pass
    /// Let the mouse-down through, and go on watching: what follows says whether it was a click.
    case watch
    /// Hide the mouse-down from apps and keep a copy: what follows says whether to give it back.
    case hold
    /// Hide it from apps.
    case swallow
    /// A drag after all: give the app the mouse-down that was held back, then let this event through.
    case replay
    /// Run the command, and hide the event from apps or let it through.
    case run(Command, swallow: Bool)

    public var swallows: Bool {
      switch self {
      case .pass, .watch, .replay: false
      case .hold, .swallow: true
      case .run(_, let swallow): swallow
      }
    }
  }

  /// How many points the pointer may stray between mouse-down and mouse-up of a click, as for `RectangleGesture`.
  public static let slack: CGFloat = 4

  private struct Press: Equatable, Sendable {
    var hit: DoubleClickZones.Hit
    var start: CGPoint
  }

  /// The second press of a pair that may be Arbor's, until the button comes up or the pointer moves away.
  private var press: Press?

  /// Whether the events that follow still matter.
  public var isFollowing: Bool { press != nil }

  public init() {}

  /// Whether a mouse-down completes a double-click, by the rule that holds for those that are not Arbor's.
  public static func isDoubleClick(clicks: Int) -> Bool { AppsDoubleClick.isCompleted(byClick: clicks) }

  /// - Parameters:
  ///   - clicks: the event's click count.
  ///   - modifiersHeld: whether ⌃, ⌥, ⇧ or ⌘ is down. Modified double-clicks stay with the apps.
  ///   - hit: what the zones say about the point.
  ///   - confirm: the slower checks of what is really under the pointer. Both are evaluated only
  ///     for an unmodified double-click, and `confirm` only inside a zone where it matters.
  public mutating func mouseDown(
    at point: CGPoint, clicks: Int, modifiersHeld: Bool, hit: @autoclosure () -> DoubleClickZones.Hit?,
    confirm: (DoubleClickZones.Hit) -> Bool = { _ in true }
  ) -> Response {
    // A mouse-down while waiting for a mouse-up means the mouse-up was missed: start over.
    press = nil
    guard Self.isDoubleClick(clicks: clicks), !modifiersHeld, let hit = hit(),
      hit.hidesClickFromApps || hit.command != nil, !hit.dependsOnWhatIsThere || confirm(hit)
    else { return .pass }
    press = Press(hit: hit, start: point)
    return hit.hidesClickFromApps ? .hold : .watch
  }

  /// The pointer moved with the button down.
  public mutating func mouseDragged(to point: CGPoint) -> Response {
    guard let press else { return .pass }
    let moved = max(abs(point.x - press.start.x), abs(point.y - press.start.y))
    guard moved > Self.slack else { return press.hit.hidesClickFromApps ? .swallow : .pass }
    self.press = nil
    return press.hit.hidesClickFromApps ? .replay : .pass
  }

  public mutating func mouseUp() -> Response {
    guard let press else { return .pass }
    self.press = nil
    guard let command = press.hit.command else { return .swallow }
    return .run(command, swallow: press.hit.hidesClickFromApps)
  }

  /// Forgets the click in progress, for when events may have been missed or the taps go away.
  ///
  /// A press that was held back and whose button is still down is given back (`.replay`): its mouse-up is yet to come
  /// and will reach the app, which would make nothing of it alone, and the person's click would be lost. The click is
  /// then the app's, and macOS's: nothing of Arbor's runs. With the button up the mouse-up was among the events that
  /// were missed, and a press sent on now would leave the app in a drag.
  @discardableResult
  public mutating func reset(buttonIsDown: Bool = false) -> Response {
    defer { press = nil }
    guard let press, press.hit.hidesClickFromApps, buttonIsDown else { return .pass }
    return .replay
  }
}

// MARK: What macOS does there itself

/// What macOS itself does at a double-click on a title bar: System Settings → Desktop & Dock → "Double-click a window's
/// title bar to".
///
/// Framing a window replaces "make it big" and nothing else. Whoever chose Minimize or Do Nothing has said what they want
/// there, and Arbor leaves title bars alone, whatever its own switch says.
public enum MacTitleBarAction: String, Codable, Sendable, CaseIterable {
  case fill, zoom, minimize, nothing

  /// From the global default `AppleActionOnDoubleClick`. Not set, or set to something nobody has heard of, is macOS as
  /// it comes.
  public init(setting: String?) {
    switch setting {
    case "Minimize": self = .minimize
    case "None": self = .nothing
    case "Maximize": self = .zoom
    default: self = .fill
    }
  }

  public var makesTheWindowBig: Bool { self == .fill || self == .zoom }

  /// For `doctor` and the settings window, so that nobody wonders why the switch does nothing. Nil while it does something.
  public var whyArborLeavesTitleBarsAlone: String? {
    switch self {
    case .fill, .zoom: nil
    case .minimize: "macOS is set to minimize at a double-click, so Arbor leaves title bars alone"
    case .nothing: "macOS is set to do nothing at a double-click, so Arbor leaves title bars alone"
    }
  }
}

// MARK: Settings

extension Settings {
  public static let titleBarHeightRange: ClosedRange<Double> = 10...80

  /// `titleBarHeight` kept within `titleBarHeightRange`, so that a slip of the hand neither turns the
  /// feature off nor hands Arbor every double-click in a window.
  public var effectiveTitleBarHeight: CGFloat {
    guard titleBarHeight.isFinite else { return CGFloat(Settings().titleBarHeight) }
    let range = Self.titleBarHeightRange
    return CGFloat(min(max(titleBarHeight, range.lowerBound), range.upperBound))
  }

  /// Whether any of this needs the event tap. A tile's second click is swallowed only while it is there.
  public var wantsDoubleClickTap: Bool { titleBarDoubleClick || desktopDoubleClick }
}
