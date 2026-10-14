import ArborCore
import CoreGraphics

/// What a tile shows: enough for the UI to draw the app colour, icon and name.
public struct TileModel: Equatable, Sendable {
  public struct Item: Equatable, Sendable {
    public var window: WindowID
    public var pid: Int32
    public var bundleID: String?
    public var appName: String
    /// For group tiles: where this window sits in the miniature.
    public var miniatureFrame: CGRect?
  }

  public var display: DisplayID
  public var node: NodeID
  public var kind: Tile.Kind
  public var frame: CGRect
  public var items: [Item]
  /// The name of the space the tile stands for, if it has one (F20).
  public var name: String? = nil
  /// Whether the tile takes on its app's colour (settings `appColours`, `appColourAmount`, `tileStyle`).
  /// `TileArt` turns these into what is drawn.
  public var usesAppColour = true
  /// How much of the app's colour is mixed into the neutral grey, 0...1.
  public var colourAmount = 0.25
  public var style = TileStyle.icon

  /// The tile's caption: the space's name, or else the app name, "Desktop", or "N windows".
  public var title: String {
    if let name { return name }
    switch kind {
    case .desktop: return "Desktop"
    case .window: return items.first?.appName ?? "Window"
    case .group: return "\(items.count) windows"
    }
  }
}

/// The surface behind docked windows: where the wallpaper is darkened and blurred, and by how much.
public struct BackdropModel: Equatable, Sendable {
  /// The display's visible frame, which the surface never leaves.
  public var frame: CGRect
  /// The surface, as rectangles that do not overlap (`BackdropShape.surface`), in global coordinates.
  public var rects: [CGRect]
  /// How far the surface reaches beyond the slots lying on it.
  public var growth: CGFloat
  /// Opacity of the black laid over the wallpaper, 0...1.
  public var dim: Double
  /// How much of macOS's blur is laid over the wallpaper, 0...1.
  public var blur: Double
  /// Opacity of the accent colour laid over the black, 0...1.
  public var tint: Double
  /// The Desktop's rectangle where it is in view beside something docked, and the opacity of the hairline around it.
  public var desktop: CGRect?
  public var desktopEdge: Double

  public init(
    frame: CGRect, rects: [CGRect], growth: CGFloat, dim: Double, blur: Double, tint: Double = 0,
    desktop: CGRect? = nil, desktopEdge: Double = 0
  ) {
    self.frame = frame
    self.rects = rects
    self.growth = growth
    self.dim = dim
    self.blur = blur
    self.tint = tint
    self.desktop = desktop
    self.desktopEdge = desktopEdge
  }

  /// The one colour to fill the surface with: the tint over the black.
  public func fill(accent: RGBA) -> RGBA {
    accent.withAlpha(tint).over(RGBA.black.withAlpha(dim))
  }

  /// The middle of a line `width` thick that lies just inside the Desktop's rectangle, rounded like a window, in global
  /// coordinates. Nil where there is no line to draw.
  public func desktopOutline(width: CGFloat, radius: CGFloat = TileMetrics.cornerRadius) -> [PathElement]? {
    guard desktopEdge > 0, let desktop, width.isFinite, width > 0 else { return nil }
    let outline = RoundedPath.rect(desktop.insetBy(dx: width / 2, dy: width / 2), radius: max(radius - width / 2, 0))
    return outline.isEmpty ? nil : outline
  }

  /// The rounded outline to fill, in global coordinates. Its outer corners are concentric with those of the
  /// windows and tiles lying `growth` inside its edge, whose radius is `slotRadius`.
  public func outline(slotRadius: CGFloat = TileMetrics.cornerRadius) -> [PathElement] {
    let radius = max(slotRadius, 0) + growth
    return BackdropShape.outline(
      of: rects, cornerRadius: radius, innerRadius: BackdropShape.innerRadius(for: radius, growth: growth))
  }
}

/// Everything Arbor draws on one display while nothing is moving. A new kind of overlay is a new
/// field with an empty default, so adding one changes neither the protocol nor the other fields' users.
public struct OverlayScene: Equatable, Sendable {
  public var tiles: [TileModel]
  public var seams: [Seam]
  /// The line around the window that has the keyboard, on the one display that shows it.
  public var focusRing: FocusRingModel? = nil
  /// During a peek: the rectangle of the space that letting go would frame (Controller+Peek.swift).
  public var peekOutline: CGRect? = nil
  /// The field a name for the space in view is typed into, on the one display that shows it.
  public var namePrompt: NamePromptModel? = nil
  /// Nil when nothing docked is in view, or when neither dimming nor blur is on.
  public var backdrop: BackdropModel?
  /// Whether a seam shows its handle while the pointer is over it. It can be dragged either way.
  public var showsSeamHandles = true
  /// Seconds a tile takes to fade in when it appears and out when it goes.
  public var tileFade: Double = 0

  public init(tiles: [TileModel] = [], seams: [Seam] = []) {
    self.tiles = tiles
    self.seams = seams
  }
}

/// Arbor's own on-screen elements: drop previews, tiles and seam handles.
/// `AppKitOverlays` draws them; `FakeOverlays` records them for tests.
@MainActor
public protocol OverlayPresenter: AnyObject {
  var actions: (any OverlayActions)? { get set }

  /// Shows the drop preview at `frame`, or hides it when nil.
  func showDropPreview(_ frame: CGRect?)
  /// Replaces what is shown on `display`.
  func update(display: DisplayID, scene: OverlayScene)
  func removeAll()
  /// Plays `transition` on a stage that covers its display. The controller calls this before it
  /// moves the real windows, so the stage has to be up when the call returns. A display whose
  /// stage is already up carries on from where things are now (the items' `from` is where the real
  /// windows were, which by then is where the last transition was taking them).
  func animate(_ transition: Transition)
  /// Drops every stage at once, showing the real windows.
  func finishAnimations()

  /// Shows the finder ("Go to…") with this list and gives it the keyboard, or closes it when nil. If it is
  /// already showing, the list is replaced and what the user typed stays. `removeAll` closes it too.
  func showFinder(_ model: FinderModel?)
  /// Shows the heads-up line on `display` in place of the one there, or takes it away when nil. The controller
  /// shows one line at a time and takes it away itself when its time is up (Controller+HeadsUp.swift).
  func showHeadsUp(_ model: HeadsUpModel?, on display: DisplayID)
  /// Shows the panel of shortcuts on `display`, or puts it away when nil (Controller+CheatSheet.swift).
  func showCheatSheet(_ model: CheatSheetModel?, on display: DisplayID)
  /// Shows the minimap on `display` in place of the one there, or takes it away when nil. The controller takes it
  /// away itself when its time is up (Controller+Minimap.swift).
  func showMinimap(_ model: MinimapModel?, on display: DisplayID)
}

/// What the user did with an overlay.
@MainActor
public protocol OverlayActions: AnyObject {
  func tileActivated(display: DisplayID, node: NodeID)
  /// A seam handle was dragged by `delta` points along its axis since the last call.
  func seamDragged(display: DisplayID, seam: Seam, by delta: CGFloat)
  /// The outline of a peek was clicked.
  func peekOutlineClicked(display: DisplayID)
  /// Runs a command for a panel that is typed into or chosen from (the name field).
  @discardableResult func perform(_ command: Command) -> CommandResult

  /// The user chose a row of the finder. The finder stays as it is until `showFinder` says otherwise.
  func finderChose(_ destination: FinderDestination)
  /// The finder closed itself: Escape, or the keyboard went to another window.
  func finderDismissed()
  /// A key was pressed or the mouse clicked while the panel of shortcuts was up.
  func cheatSheetDismissed()
  /// A click in a minimap that takes clicks, at `point` in the panel's coordinates (origin top-left, y down).
  func minimapClicked(display: DisplayID, at point: CGPoint)
}
