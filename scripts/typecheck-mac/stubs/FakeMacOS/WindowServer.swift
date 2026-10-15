// The model of a Mac (FakeMac.swift): the window server's list, and the screens. Never shipped.
import Foundation

extension FakeMac {
  /// Something the window server lists that is no app's ordinary window: the menu bar, the Dock, the wallpaper, Arbor's own panels.
  public struct Furniture: Equatable, Sendable {
    public var number: UInt32
    public var pid: pid_t
    public var layer: Int
    public var bounds: CGRect
    public var alpha: Double
    /// Left out with `excludeDesktopElements`.
    public var isDesktopElement: Bool
    /// Listed before the apps' windows, or after them.
    public var isInFront: Bool

    public init(
      number: UInt32, pid: pid_t, layer: Int, bounds: CGRect, alpha: Double = 1, isDesktopElement: Bool = false, isInFront: Bool = true
    ) {
      self.number = number
      self.pid = pid
      self.layer = layer
      self.bounds = bounds
      self.alpha = alpha
      self.isDesktopElement = isDesktopElement
      self.isInFront = isInFront
    }
  }

  /// One entry of `CGWindowListCopyWindowInfo`'s answer.
  public struct Listed: Equatable, Sendable {
    public var number: UInt32
    public var pid: pid_t
    public var ownerName: String
    public var layer: Int
    public var bounds: CGRect
    public var alpha: Double
    public var isOnScreen: Bool
  }

  /// A Mac at rest (macOS 26.6, docs/ARCHITECTURE.md, "the pointer is over the Desktop"): the menu bar at level 24, and, listed among what is behind
  /// everything, the Dock's window as large as the display at level 20, Finder's icons and the wallpaper at levels far below zero.
  /// The list is not sorted by level.
  func furnitureAtRest() -> [Furniture] {
    var all: [Furniture] = []
    for (index, screen) in screens.enumerated() {
      let base = UInt32(10 + index * 10)
      let bar = CGRect(x: screen.frame.minX, y: screen.frame.minY, width: screen.frame.width, height: screen.visibleFrame.minY - screen.frame.minY)
      all.append(Furniture(number: base, pid: 90, layer: 24, bounds: bar))
      all.append(Furniture(number: base + 1, pid: 91, layer: 20, bounds: screen.frame, isInFront: false))
      all.append(Furniture(number: base + 2, pid: 92, layer: -2_147_483_603, bounds: screen.frame, isDesktopElement: true, isInFront: false))
      all.append(Furniture(number: base + 3, pid: 91, layer: -2_147_483_626, bounds: screen.frame, isDesktopElement: true, isInFront: false))
    }
    return all
  }

  /// The window server's answer. Nil: it gave none.
  /// - `onScreenOnly`: what shows, front to back.
  /// - `only`: that window alone, whether it shows or not (`optionIncludingWindow` by itself).
  /// Costs no time and cannot hang: the window server is not the app.
  public func windowList(onScreenOnly: Bool, withoutDesktop: Bool, only: UInt32?) -> [Listed]? {
    guard !serverGivesNoList else { return nil }
    func listed(_ item: Furniture) -> Listed {
      Listed(
        number: item.number, pid: item.pid, ownerName: item.pid == arbor.pid ? arbor.name : "Window Server", layer: item.layer,
        bounds: item.bounds, alpha: item.alpha, isOnScreen: true)
    }
    let things = (furnitureAtRest() + furniture).filter { !(withoutDesktop && $0.isDesktopElement) }
    var all = things.filter(\.isInFront).map(listed)
    for window in stack where window.exists {
      all.append(
        Listed(
          number: window.number, pid: window.app.pid, ownerName: window.app.name, layer: 0, bounds: listedBounds(of: window), alpha: window.alpha,
          isOnScreen: isShowing(window)))
    }
    all += things.filter { !$0.isInFront }.map(listed)
    if let only { return all.filter { $0.number == only } }
    return onScreenOnly ? all.filter(\.isOnScreen) : all
  }

  // MARK: Stacking

  func raise(_ window: Window) {
    guard let index = stack.firstIndex(where: { $0 === window }), index > 0 else { return }
    stack.remove(at: index)
    stack.insert(window, at: 0)
  }

  /// ⌘Tab and the Dock bring all of an app's windows forward, in the order they had among themselves.
  func raiseAll(of app: App) {
    stack = stack.filter { $0.app === app } + stack.filter { $0.app !== app }
  }

  /// The frontmost window that shows at a point, within `reach` points of its frame: macOS's resize area lies to either side of the border.
  func windowShowing(at point: CGPoint, reach: CGFloat = 0) -> Window? {
    stack.first { isShowing($0) && $0.alpha > 0 && listedBounds(of: $0).insetBy(dx: -reach, dy: -reach).contains(point) }
  }

  // MARK: Screens

  /// The displays change. macOS says so several times in a row when one comes or goes (docs/ARCHITECTURE.md); how far apart nobody has measured.
  public func setScreens(_ new: [Screen], notices: Int = 3) {
    note("the displays change: \(new.map { "\($0.name) \($0.frame)" })")
    screens = new
    for number in 0..<max(notices, 1) { screensNotice(after: 0.01 + 0.05 * Double(number)) }
  }

  /// Another display becomes the main one: the origin of all coordinates moves, so every window has new ones, and no app posts anything about it.
  public func renumber(dx: CGFloat, dy: CGFloat) {
    for window in stack {
      window.frame = window.frame.offsetBy(dx: dx, dy: dy)
      window.bounds = window.bounds.offsetBy(dx: dx, dy: dy)
    }
    sweptTo = sweptTo?.mapValues { $0.offsetBy(dx: dx, dy: dy) }
    mouse.location.x += dx
    mouse.location.y += dy
    mouse.locationByAppKit = mouse.location
  }

  func screensNotice(after delay: TimeInterval) {
    send(after: delay, from: .screens, "→ didChangeScreenParameters") {
      NotificationCenter.default.post(name: Notification.Name("NSApplicationDidChangeScreenParametersNotification"), object: nil)
    }
  }

  /// The Dock grows and shrinks with the windows in it, and the visible frame with it: 674 points high, 676 with one window minimized
  /// (trace `minimize-restore`).
  func dockChanged(by points: CGFloat) {
    send(after: timing.dockAfterMinimizing, from: .system, "") { [self] in
      guard !screens.isEmpty else { return }
      screens[0].visibleFrame.size.height += points
      screensNotice(after: 0)
    }
  }
}
