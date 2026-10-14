import CoreGraphics

/// One motion on one display: every window drawn while it lasts, where it starts and where it ends.
///
/// Real windows cannot be animated through the Accessibility API. They go straight to their final
/// frames while a stage covers the display, and stand-ins drawn on the stage make this journey.
/// The stage hides every real window on the display, so a window that stays where it is has an item too.
public struct Transition: Equatable, Sendable {
  public typealias Look = Plane.Look

  /// The curve of every motion in Arbor, as the control points of a cubic Bézier timing function:
  /// a fast start and a gentle settle, without overshoot.
  public static let curve: (x1: Double, y1: Double, x2: Double, y2: Double) = (0.2, 0, 0, 1)

  public struct Item: Equatable, Sendable {
    public var window: WindowID
    /// Global coordinates, like every frame in Arbor. Either end may lie beyond the display.
    public var from: CGRect
    public var to: CGRect
    public var fromLook: Look
    public var toLook: Look
    /// 0 at an end where the window cannot be seen although its frame is in view: an inactive tab, or
    /// a window with nowhere to come from or go to.
    public var fromOpacity: Double
    public var toOpacity: Double
    /// The window's app, for the cover's colour and icon. The planner leaves them empty.
    public var pid: Int32
    public var bundleID: String?

    public init(
      window: WindowID, from: CGRect, to: CGRect, fromLook: Look = .picture, toLook: Look = .picture,
      fromOpacity: Double = 1, toOpacity: Double = 1, pid: Int32 = 0, bundleID: String? = nil
    ) {
      self.window = window
      self.from = from
      self.to = to
      self.fromLook = fromLook
      self.toLook = toLook
      self.fromOpacity = fromOpacity
      self.toOpacity = toOpacity
      self.pid = pid
      self.bundleID = bundleID
    }

    /// Whether the window ends more than a point from where it starts.
    public var moves: Bool { !from.approximatelyEquals(to, tolerance: 1) }

    /// Whether the stand-in would be a still picture of a window that is really there all the while.
    public var isStill: Bool {
      !moves && fromLook == .picture && toLook == .picture && fromOpacity == 1 && toOpacity == 1
    }
  }

  public var display: DisplayID
  /// The display's full frame, which the stage covers.
  public var frame: CGRect
  /// Seconds.
  public var duration: Double
  /// Back to front.
  public var items: [Item]
  /// Where the stage stays open, so that the real window there is seen, live, in front of everything
  /// that moves (`leaveOpen`). They may overlap.
  public var holes: [CGRect]

  public init(display: DisplayID, frame: CGRect, duration: Double, items: [Item], holes: [CGRect] = []) {
    self.display = display
    self.frame = frame
    self.duration = duration
    self.items = items
    self.holes = holes
  }

  public subscript(window: WindowID) -> Item? { items.first { $0.window == window } }

  /// Whether anything moves. A transition in which nothing does is not worth a stage.
  public var hasMotion: Bool { items.contains(where: \.moves) }

  /// Puts the items in the order the real windows are stacked in. Windows `frontToBack` does not
  /// list go to the back, lowest number first.
  public mutating func stack(frontToBack: [WindowID]) {
    var depth: [WindowID: Int] = [:]
    for (index, window) in frontToBack.enumerated() where depth[window] == nil { depth[window] = index }
    items.sort { a, b in
      let (da, db) = (depth[a.window] ?? .max, depth[b.window] ?? .max)
      return da != db ? da > db : a.window < b.window
    }
  }

  /// Opens the stage over windows that do not take part in the motion, instead of covering them.
  ///
  /// The stage hides every real window below the floating level, also the ones Arbor knows nothing about:
  /// dialogs, sheets, panels, Arbor's own windows. For half a second they would be gone. Windows
  /// Arbor knows but does not move would be swapped for a still picture, or for a coloured card.
  /// Where such a window is in front, a hole does better: it shows the real thing.
  ///
  /// Through a hole one sees the real screen, where the windows that move are already at their final
  /// frames. So a window gets a hole only if nothing stacked in front of it crosses its frame at
  /// any moment of the motion. What is stacked behind it passes behind it, as it should.
  ///
  /// - Parameters:
  ///   - stack: the real windows on screen at the normal level, frontmost first.
  ///   - known: the windows Arbor knows. One of them without an item is out of view, not a stranger.
  public mutating func leaveOpen(stack: [StackedWindow], known: Set<WindowID>) {
    let stacked = Set(stack.map(\.id))
    // Where a window is in the stack is what the rule rests on. One that is not listed could be anywhere.
    var inFront = items.filter { !stacked.contains($0.window) }
    var opened = Set<WindowID>()
    holes = []
    for window in stack {
      let item = self[window.id]
      if item == nil, known.contains(window.id) { continue }
      let area = item?.to ?? window.frame
      if item.map(\.isStill) ?? true, area.isFinite, area.overlaps(frame),
        !inFront.contains(where: { TransitionPlanner.crosses($0.from, $0.to, area) })
      {
        holes.append(area)
        opened.insert(window.id)
      } else if let item {
        inFront.append(item)
      }
    }
    items.removeAll { opened.contains($0.window) }
  }

  /// Whether both show the same windows, in the same order, ending in the same places (within a
  /// point) with the same look, around the same holes.
  public func endsLike(_ other: Transition) -> Bool {
    items.count == other.items.count && holes == other.holes
      && zip(items, other.items).allSatisfy { a, b in
        a.window == b.window && a.toLook == b.toLook && a.toOpacity == b.toOpacity
          && a.to.approximatelyEquals(b.to, tolerance: 1)
      }
  }
}

// MARK: Text form

extension Transition.Item: CustomStringConvertible {
  /// `w101 (12,37 464x851) -> (12,37 1416x851)`, followed by whatever is not plain: `cover`,
  /// `cover -> picture`, `fades in`, `fades out`.
  public var description: String {
    var text = "\(window) \(Self.describe(from)) -> \(Self.describe(to))"
    if fromLook != toLook {
      text += " \(fromLook.rawValue) -> \(toLook.rawValue)"
    } else if fromLook == .cover {
      text += " cover"
    }
    if fromOpacity < toOpacity { text += " fades in" }
    if fromOpacity > toOpacity { text += " fades out" }
    return text
  }

  fileprivate static func describe(_ rect: CGRect) -> String {
    "(\(whole(rect.minX)),\(whole(rect.minY)) \(whole(rect.width))x\(whole(rect.height)))"
  }

  private static func whole(_ value: CGFloat) -> String {
    guard value.isFinite, abs(value) < 1e15 else { return "\(value)" }
    return String(Int(value.rounded()))
  }
}

extension Transition: CustomStringConvertible {
  /// One line for the transition, then one per item, back to front, then one per hole.
  public var description: String {
    (["transition on \(display), \(duration) s"] + items.map { "  \($0)" }
      + holes.map { "  open \(Item.describe($0))" }).joined(separator: "\n")
  }
}

// MARK: Planning

/// A real window on screen, as the window server sees it: Arbor may know nothing else about it.
public struct StackedWindow: Equatable, Sendable, Codable {
  public var id: WindowID
  public var frame: CGRect

  public init(id: WindowID, frame: CGRect) {
    self.id = id
    self.frame = frame
  }
}

/// One display standing still: what a transition starts from or ends at.
public struct Keyframe: Equatable, Sendable {
  public var tree: LayoutTree
  /// The display's layout of `tree`. Its camera is where the camera is.
  public var layout: Layout
  /// The windows that exist and take up space (not minimized, hidden or on another Space),
  /// whether Arbor arranges them or not. `layout` was made with these.
  public var present: Set<WindowID>
  /// Where every window that shows as itself on this display really is: docked windows in their
  /// slots (or wherever the user dropped them), floating windows, and windows Arbor leaves alone.
  /// Windows moved out of view are not in it.
  public var visible: [WindowID: CGRect]

  public init(tree: LayoutTree, layout: Layout, present: Set<WindowID>, visible: [WindowID: CGRect]) {
    self.tree = tree
    self.layout = layout
    self.present = present
    self.visible = visible
  }

  /// Every window the display shows, as itself or inside a tile.
  var shownWindows: Set<WindowID> {
    layout.tiles.reduce(into: Set(visible.keys)) { $0.formUnion($1.windows) }
  }
}

/// Works out the motion that leads from one keyframe to another.
public enum TransitionPlanner {
  /// Every window is taken from where it is to where it goes:
  ///
  /// - A window that shows as itself is where it really is (`Keyframe.visible`); one inside a tile
  ///   is at its place in the tile, as a cover.
  /// - A docked window out of view is where the plane puts it (see `Plane`), slid on until none of
  ///   it is left on the display. Each end's plane is just wide enough to hold what the other end
  ///   shows: for a camera move that is the common ancestor of the two cameras, so zooming in pushes
  ///   the other windows out past the screen edges and zooming out brings them back from there.
  /// - A floating window out of view rides on the Desktop: its frame at the end where it shows is
  ///   carried along from the Desktop's rectangle there to the Desktop's rectangle at the other end.
  /// - A window with nowhere to come from or go to fades in or out where it is.
  ///
  /// Windows that are gone or absent at the end (closed, minimized) have no item, nor do windows that
  /// are never in view. A window out of view at both ends has one if the motion takes it across
  /// the display.
  ///
  /// - Parameters:
  ///   - screen: the display's full frame.
  ///   - options: what both layouts were made with.
  ///   - frontToBack: how the real windows are stacked. Windows it does not list are drawn at the back.
  public static func plan(
    display: DisplayID, frame screen: CGRect, from before: Keyframe, to after: Keyframe,
    options: LayoutOptions, duration: Double, frontToBack: [WindowID] = []
  ) -> Transition {
    let start = plane(of: before, wideEnoughFor: after, options: options)
    let end = plane(of: after, wideEnoughFor: before, options: options)
    let sameTree = before.tree == after.tree

    var candidates = Set(before.visible.keys).union(after.visible.keys)
    candidates.formUnion(start.windows.keys)
    candidates.formUnion(end.windows.keys)

    var items: [Transition.Item] = []
    for window in candidates where after.present.contains(window) {
      var first = spot(of: window, in: before, on: start)
      var last = spot(of: window, in: after, on: end)
      if let seen = first, last == nil {
        last = carried(
          seen, from: start, desktop: before.tree.desktop, to: end, desktop: after.tree.desktop,
          sameTree: sameTree)
      } else if let seen = last, first == nil {
        first = carried(
          seen, from: end, desktop: after.tree.desktop, to: start, desktop: before.tree.desktop,
          sameTree: sameTree)
      }
      guard let first, let last else { continue }

      let seenFirst = first.visibility == .inView
      let seenLast = last.visibility == .inView
      guard seenFirst || seenLast || (first.visibility == .outside && last.visibility == .outside) else {
        continue
      }
      let (from, fromOpacity) = staged(first, on: start, screen: screen)
      let (to, toOpacity) = staged(last, on: end, screen: screen)
      guard fromOpacity > 0 || toOpacity > 0, from.isFinite, to.isFinite, crosses(from, to, screen) else {
        continue
      }
      // Out of view a window looks as it does at the end where it can be seen, so that nothing
      // changes its look on the way in or out.
      items.append(
        Transition.Item(
          window: window, from: from, to: to,
          fromLook: seenFirst ? first.look : seenLast ? last.look : .picture,
          toLook: seenLast ? last.look : seenFirst ? first.look : .picture,
          fromOpacity: fromOpacity, toOpacity: toOpacity))
    }

    var transition = Transition(display: display, frame: screen, duration: duration, items: items)
    transition.stack(frontToBack: frontToBack)
    return transition
  }

  /// The plane as `keyframe` sees it, holding everything `other` shows.
  private static func plane(of keyframe: Keyframe, wideEnoughFor other: Keyframe, options: LayoutOptions) -> Plane {
    let tree = keyframe.tree
    var ancestor = keyframe.layout.camera
    for window in other.shownWindows {
      if let leaf = tree.leaf(containing: window) {
        ancestor = Navigation.commonAncestor(ancestor, leaf, in: tree)
      }
    }
    // Floating windows the other end shows need to know where the Desktop is at this end.
    if other.layout.nodeFrames[other.tree.desktop] != nil {
      ancestor = Navigation.commonAncestor(ancestor, tree.desktop, in: tree)
    }
    let present = keyframe.present
    return Plane(
      tree: tree, layout: keyframe.layout, ancestor: ancestor, options: options,
      isPresent: { present.contains($0) })
  }

  /// Where `window` is in `keyframe`, or nil if it is not on the plane there.
  private static func spot(of window: WindowID, in keyframe: Keyframe, on plane: Plane) -> Plane.Spot? {
    if let frame = keyframe.visible[window] {
      return Plane.Spot(frame: frame, look: .picture, visibility: .inView)
    }
    guard let spot = plane.windows[window] else { return nil }
    // The layout shows it as itself, but it is not there: it was away when that layout was
    // applied, or its app did not let it be moved.
    if spot.visibility == .inView, spot.look == .picture { return nil }
    return spot
  }

  /// Where a window seen at one end is at the other end, where it is neither showing nor docked:
  /// pinned to the plane and carried along with the Desktop, where floating windows live. If
  /// the Desktop is not on both planes, a camera move carries it along with the view it was seen in.
  /// Failing that it stays where it is, unseen.
  private static func carried(
    _ seen: Plane.Spot, from source: Plane, desktop sourceDesktop: NodeID, to target: Plane,
    desktop targetDesktop: NodeID, sameTree: Bool
  ) -> Plane.Spot {
    var references = [(sourceDesktop, targetDesktop)]
    if sameTree { references.append((source.camera, source.camera)) }
    for (here, there) in references {
      if let from = source.nodes[here], let to = target.nodes[there],
        let map = PlaneMap(carrying: from, onto: to)
      {
        return Plane.Spot(frame: map.apply(seen.frame).integralRounded, look: seen.look, visibility: .outside)
      }
    }
    return Plane.Spot(frame: seen.frame, look: seen.look, visibility: .behind)
  }

  /// The frame and opacity to draw a spot with.
  private static func staged(_ spot: Plane.Spot, on plane: Plane, screen: CGRect) -> (CGRect, Double) {
    switch spot.visibility {
    case .inView:
      return (spot.frame, 1)
    case .behind:
      return (spot.frame, 0)
    case .outside:
      if let frame = pushed(spot.frame, off: screen, awayFrom: plane.content) { return (frame, 1) }
      return (spot.frame, 0)
    }
  }

  /// Slides `rect`, which lies beside `content`, straight on until none of it is left on `screen`.
  ///
  /// The plane puts a window out of view beyond the content rectangle, but the display reaches
  /// further: the outer gap, the menu bar, the Dock. What is left there would stay in sight until
  /// the stage lifts and then vanish. Nil if `rect` is not clear of `content` on any side.
  static func pushed(_ rect: CGRect, off screen: CGRect, awayFrom content: CGRect) -> CGRect? {
    guard rect.overlaps(screen) else { return rect }
    var slides: [CGPoint] = []
    if rect.minX >= content.maxX { slides.append(CGPoint(x: screen.maxX - rect.minX, y: 0)) }
    if rect.maxX <= content.minX { slides.append(CGPoint(x: screen.minX - rect.maxX, y: 0)) }
    if rect.minY >= content.maxY { slides.append(CGPoint(x: 0, y: screen.maxY - rect.minY)) }
    if rect.maxY <= content.minY { slides.append(CGPoint(x: 0, y: screen.minY - rect.maxY)) }
    guard let slide = slides.min(by: { abs($0.x) + abs($0.y) < abs($1.x) + abs($1.y) }) else { return nil }
    return rect.offsetBy(dx: slide.x, dy: slide.y)
  }

  /// Whether a rectangle gliding from `from` to `to` overlaps `screen` at some moment.
  static func crosses(_ from: CGRect, _ to: CGRect, _ screen: CGRect) -> Bool {
    // Overlapping is four inequalities, each linear in time. Narrow down the span of time
    // (0 at `from`, 1 at `to`) in which all of them hold.
    var low: CGFloat = 0
    var high: CGFloat = 1
    for (a, b) in [
      (screen.maxX - from.minX, screen.maxX - to.minX), (from.maxX - screen.minX, to.maxX - screen.minX),
      (screen.maxY - from.minY, screen.maxY - to.minY), (from.maxY - screen.minY, to.maxY - screen.minY),
    ] {
      // Needed: a + (b - a) t > 0.
      if a <= 0, b <= 0 { return false }
      if a <= 0 { low = max(low, a / (a - b)) }
      if b <= 0 { high = min(high, a / (a - b)) }
    }
    return low < high
  }
}
