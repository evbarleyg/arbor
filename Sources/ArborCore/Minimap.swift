import CoreGraphics

/// The minimap (docs/features/F26-minimap.md): a display's whole arrangement in miniature, with the space the view is
/// on marked. It answers "where am I?", which zooming raises every time.
///
/// Everything that can be decided without a screen is decided here: `Minimap` is the geometry, `MinimapModel` the panel
/// that a view draws without a thought of its own. The controller decides when it shows (Controller+Minimap.swift).

/// The geometry, in the map's own coordinates: points, origin at its top-left corner, y down.
public struct Minimap: Equatable, Sendable {
  /// A docked window's place.
  public struct Place: Equatable, Sendable {
    /// The window that shows there: of a tab group, the one in front.
    public var window: WindowID
    /// The space to frame to get there.
    public var space: NodeID
    public var frame: CGRect
    public var isInView: Bool
  }

  /// The map's size: the display's proportions, as large as fits `maximumSize`.
  public var size: CGSize
  /// In tree order (left to right, top to bottom), so that whoever draws them draws them in one order.
  public var places: [Place]
  public var desktop: CGRect?
  public var desktopSpace: NodeID
  public var desktopIsInView: Bool
  /// The space that fills the view, and where it is on the map.
  public var view: NodeID
  public var highlight: CGRect

  public static let maximumSize = CGSize(width: 220, height: 140)
  /// Between neighbours on the map: enough to tell two windows of one app apart.
  static let gap: CGFloat = 2

  /// The map of `tree` for a display whose usable area has the proportions of `area`. Nil when there is nothing to find
  /// one's way in: no docked window takes up space, or the display has no area.
  public static func make(
    _ tree: LayoutTree, camera: NodeID, area: CGSize, maximumSize: CGSize = Minimap.maximumSize,
    isPresent: @escaping (WindowID) -> Bool
  ) -> Minimap? {
    guard area.width.isFinite, area.height.isFinite, area.width >= 1, area.height >= 1 else { return nil }
    let scale = min(maximumSize.width / area.width, maximumSize.height / area.height)
    let size = CGSize(width: max((area.width * scale).rounded(), 1), height: max((area.height * scale).rounded(), 1))
    let whole = CGRect(origin: .zero, size: size)

    // The real engine at the root, so that the map cannot disagree with what Show Everything would show. Nothing is
    // too small to draw here, so nothing becomes a tile. At the root nothing is out of view either, so `placement` will do.
    let layout = LayoutEngine.placement(
      tree, camera: tree.root, in: whole, options: LayoutOptions(gap: gap, outerGap: 0, minimumUsableSize: .zero),
      isPresent: isPresent)
    guard !layout.windowFrames.isEmpty else { return nil }

    // What fills the view is the camera, or the nearest space around it that has anything to show.
    let treeView = TreeView(tree: tree, isPresent: isPresent)
    let view = treeView.effectiveAncestor(of: camera)
    let places = tree.preorder().compactMap { leaf -> Place? in
      guard let window = treeView.visibleWindow(of: leaf), let frame = layout.windowFrames[window] else { return nil }
      return Place(window: window, space: leaf, frame: frame, isInView: tree.subtree(view, contains: leaf))
    }
    return Minimap(
      size: size, places: places, desktop: layout.desktopFrame, desktopSpace: tree.desktop,
      desktopIsInView: tree.subtree(view, contains: tree.desktop), view: view,
      highlight: layout.nodeFrames[view] ?? whole)
  }
}

/// What the minimap's panel draws. `frame` is in global coordinates; every other rectangle is in the panel's own: points,
/// origin at its top-left corner, y down.
public struct MinimapModel: Equatable, Sendable {
  public struct Item: Equatable, Sendable {
    public var window: WindowID
    public var space: NodeID
    /// For the app's colour, which the view takes from its icon.
    public var pid: Int32
    public var bundleID: String?
    public var frame: CGRect
    /// What is out of view is still there, only fainter.
    public var isInView: Bool
  }

  public var display: DisplayID
  public var frame: CGRect
  public var items: [Item]
  /// The Desktop, drawn as an outline.
  public var desktop: CGRect?
  public var desktopSpace: NodeID
  public var desktopIsInView: Bool
  /// The space that fills the view, framed in the accent colour.
  public var highlight: CGRect
  /// The space's name, or the saved view that leads to it. Most spaces have neither.
  public var caption: String?
  /// One line above the map. Empty without a caption.
  public var captionFrame: CGRect
  /// Whether it was asked for (`minimap`): then a click goes to the space under it. One that only passes by lets every
  /// click through to what is below.
  public var takesClicks: Bool
  /// The space under the pointer, outlined: what a click, or letting go of the keys that are holding the minimap up, would
  /// frame. Only in one that takes clicks.
  public var hover: CGRect? = nil

  /// Around the map, inside the panel. Also room for the highlight, which is drawn around its space.
  public static let padding: CGFloat = 10
  public static let captionHeight: CGFloat = 18
  /// From the bottom of the display's usable area to the lowest of Arbor's passing panels: clear of the Dock, near where
  /// the eyes rest. The heads-up line (F43) uses the same number, and sits above the minimap when both show.
  public static let bottomMargin = HeadsUpModel.bottomMargin
  static let longestCaption = 64

  /// Puts `map` in a panel low on a display, centred. The panel's bottom edge and the map in it stay where they are
  /// whether there is a caption or not: a caption makes the panel taller at the top.
  /// `app` gives a window's process and bundle id; a window it does not know is left out.
  public init(
    _ map: Minimap, on display: DisplayID, in visibleFrame: CGRect, caption: String? = nil, takesClicks: Bool = false,
    app: (WindowID) -> (pid: Int32, bundleID: String?)?
  ) {
    let caption = caption.flatMap(Self.oneLine)
    let top = Self.padding + (caption == nil ? 0 : Self.captionHeight)
    let size = CGSize(width: map.size.width + 2 * Self.padding, height: top + map.size.height + Self.padding)
    func inPanel(_ rect: CGRect) -> CGRect { rect.offsetBy(dx: Self.padding, dy: top) }

    self.display = display
    frame = CGRect(
      x: (visibleFrame.midX - size.width / 2).rounded(),
      y: (visibleFrame.maxY - Self.bottomMargin - size.height).rounded(), width: size.width, height: size.height
    ).fitted(into: visibleFrame)
    items = map.places.compactMap { place in
      app(place.window).map {
        Item(
          window: place.window, space: place.space, pid: $0.pid, bundleID: $0.bundleID, frame: inPanel(place.frame),
          isInView: place.isInView)
      }
    }
    desktop = map.desktop.map(inPanel)
    desktopSpace = map.desktopSpace
    desktopIsInView = map.desktopIsInView
    highlight = inPanel(map.highlight)
    self.caption = caption
    captionFrame =
      caption == nil
      ? .zero : CGRect(x: Self.padding, y: Self.padding - 4, width: map.size.width, height: Self.captionHeight)
    self.takesClicks = takesClicks
  }

  /// People name spaces, and a name can be anything. The caption has one line.
  private static func oneLine(_ text: String) -> String? {
    guard let line = text.split(whereSeparator: \.isNewline).first, !line.isEmpty else { return nil }
    return line.count > longestCaption ? line.prefix(longestCaption - 1) + "…" : String(line)
  }

  /// The space a click at `point`, in the panel's coordinates, means, or nil beside the map. Half of each gap counts
  /// towards its neighbour: these are small things to hit.
  public func space(at point: CGPoint) -> NodeID? {
    let reach = -Minimap.gap / 2
    if let item = items.first(where: { $0.frame.insetBy(dx: reach, dy: reach).contains(point) }) { return item.space }
    if let desktop, desktop.insetBy(dx: reach, dy: reach).contains(point) { return desktopSpace }
    return nil
  }

  /// The same minimap with the pointer at `point`, in the panel's coordinates.
  public func pointing(at point: CGPoint) -> MinimapModel {
    var model = self
    let space = takesClicks ? space(at: point) : nil
    model.hover = space.flatMap { space in space == desktopSpace ? desktop : items.first { $0.space == space }?.frame }
    return model
  }

  /// The map in words, as arbor-sim and tests show it: `[w101] >w102 desktop "View 3"`, what is in view in brackets and
  /// what the pointer is over after a `>`.
  public var line: String {
    func mark(_ text: String, _ isInView: Bool, _ frame: CGRect?) -> String {
      (frame != nil && frame == hover ? ">" : "") + (isInView ? "[\(text)]" : text)
    }
    var words = items.map { mark("\($0.window)", $0.isInView, $0.frame) }
    if desktop != nil { words.append(mark("desktop", desktopIsInView, desktop)) }
    if let caption { words.append("\"\(caption)\"") }
    if takesClicks { words.append("(takes clicks)") }
    return words.joined(separator: " ")
  }
}
