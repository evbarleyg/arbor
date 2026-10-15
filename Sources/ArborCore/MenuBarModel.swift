/// What Arbor's menu bar item shows: a row of small buttons for the display the camera commands act
/// on (docs/features/F10-menu-bar-and-onboarding.md). From left to right: back and forward, the
/// Desktop, everything, one button per saved view in slot order, and one that opens the menu. The
/// button for where the camera is now is drawn filled in.
///
/// The model says what each button means and `MenuBarLayout` where it sits; the app only draws them
/// and reports clicks. With no buttons the app shows its plain icon, which opens the menu.
public struct MenuBarModel: Equatable, Sendable {
  public struct Button: Equatable, Sendable, Identifiable {
    public enum ID: Hashable, Sendable, CustomStringConvertible {
      case back, forward, desktop, everything
      case view(Int)
      case menu

      /// The name the `menu-bar` command prints: `back`, `everything`, `view-2`.
      public var description: String {
        switch self {
        case .back: "back"
        case .forward: "forward"
        case .desktop: "desktop"
        case .everything: "everything"
        case .view(let slot): "view-\(slot)"
        case .menu: "menu"
        }
      }
    }

    public enum Glyph: Equatable, Sendable {
      /// An SF Symbol, by name.
      case symbol(String)
      /// A saved view's number.
      case digit(Int)
      /// Arbor's own mark (`ArborGlyph`): a whole tree of splits, which is what "everything" shows.
      case arbor
    }

    public var id: ID
    /// What a click runs. Nil opens the menu.
    public var command: Command?
    public var glyph: Glyph
    /// False when the command would fail: there is nothing to go back or forward to.
    public var isEnabled: Bool
    /// The camera is exactly here. Several buttons are current at once when they name the same
    /// node: a view saved while everything showed is everything.
    public var isCurrent: Bool
    /// What the button does, as the full menu words it: "Show Everything", "View 2: Safari, Notes".
    public var title: String
    /// The label of the shortcut that does the same, e.g. ⌃⌥Space.
    public var shortcut: String?

    /// The title and the shortcut, e.g. "Show Everything (⌃⌥Space)".
    public var tooltip: String { shortcut.map { "\(title) (\($0))" } ?? title }

    public init(
      id: ID, command: Command?, glyph: Glyph, isEnabled: Bool = true, isCurrent: Bool = false, title: String,
      shortcut: String? = nil
    ) {
      self.id = id
      self.command = command
      self.glyph = glyph
      self.isEnabled = isEnabled
      self.isCurrent = isCurrent
      self.title = title
      self.shortcut = shortcut
    }
  }

  /// What the item is when it has no buttons, and the only sign of Arbor's state once the menu is closed.
  public struct Icon: Equatable, Sendable {
    public var glyph: Button.Glyph
    /// Drawn faint, as macOS draws what is switched off.
    public var isDimmed: Bool
    /// What VoiceOver reads.
    public var label: String

    public init(_ glyph: Button.Glyph = .arbor, isDimmed: Bool = false, label: String = "Arbor") {
      self.glyph = glyph
      self.isDimmed = isDimmed
      self.label = label
    }

    public static let paused = Icon(isDimmed: true, label: "Arbor, paused")
    public static let held = Icon(.symbol("lock.rectangle"), label: "Arbor, the view is held")
    public static let holdingStill = Icon(.symbol("rectangle.split.3x1.fill"), label: "Arbor, holding still")
    public static let needsPermission = Icon(
      .symbol("exclamationmark.triangle"), label: "Arbor needs Accessibility permission")
  }

  /// The display the buttons describe. Nil when there are none.
  public var display: DisplayID?
  public var buttons: [Button]
  /// How opaque the background of a current button is, from 0 to 1 (setting `menuBarFill`).
  public var fill: Double
  public var icon = Icon()

  /// No buttons: Arbor is not arranging windows (yet, or for now), or `menuBarControls` is off.
  public init(icon: Icon = Icon()) {
    display = nil
    buttons = []
    fill = 0
    self.icon = icon
  }

  /// The buttons for `workspace`.
  /// - Parameters:
  ///   - shortcut: the label of the shortcut that runs a command.
  ///   - describe: a few words on what a saved view's node holds.
  public init(
    display: DisplayID, workspace: Workspace, historyButtons: Bool = true, fill: Double = 0.25,
    shortcut: (Command) -> String? = { _ in nil }, describe: (NodeID) -> String? = { _ in nil }
  ) {
    let tree = workspace.tree
    let camera = workspace.camera
    var buttons: [Button] = []
    if historyButtons {
      buttons.append(
        Button(
          id: .back, command: .back, glyph: .symbol("chevron.left"), isEnabled: workspace.canGoBack,
          title: "Back", shortcut: shortcut(.back)))
      buttons.append(
        Button(
          id: .forward, command: .forward, glyph: .symbol("chevron.right"), isEnabled: workspace.canGoForward,
          title: "Forward", shortcut: shortcut(.forward)))
    }
    buttons.append(
      Button(
        id: .desktop, command: .desktop, glyph: .symbol("menubar.dock.rectangle"),
        // With nothing docked the Desktop is everything, and two ticks for one place are odd to read.
        isCurrent: camera == tree.desktop && tree.desktop != tree.root, title: "Show the Desktop",
        shortcut: shortcut(.desktop)))
    buttons.append(
      Button(
        // Not over a window that fills the view, which hides everything: the command has something to do then.
        id: .everything, command: .showAll, glyph: .arbor, isCurrent: camera == tree.root && workspace.filled == nil,
        title: "Show Everything", shortcut: shortcut(.showAll)))
    for slot in 1...9 {
      // A slot that was never saved, or whose node is gone, gets no button: `view` would fail.
      guard let node = workspace.savedView(slot: slot) else { continue }
      buttons.append(
        Button(
          id: .view(slot), command: .goToView(slot), glyph: .digit(slot), isCurrent: camera == node,
          title: describe(node).map { "View \(slot): \($0)" } ?? "View \(slot)", shortcut: shortcut(.goToView(slot))))
    }
    // A right click anywhere opens the menu, which nobody can be expected to guess.
    buttons.append(
      Button(id: .menu, command: nil, glyph: .symbol("ellipsis"), title: "Menu (a right click anywhere opens it too)"))
    self.display = display
    self.buttons = buttons
    self.fill = fill.isFinite ? min(max(fill, 0), 1) : 0.25
  }

  public func button(_ id: Button.ID) -> Button? { buttons.first { $0.id == id } }
}

extension Workspace {
  /// Whether `goBack()` would move the camera. History can hold places that no longer differ from
  /// where the camera is (their windows closed), which `goBack()` skips.
  public var canGoBack: Bool { back.contains { tree.contains($0) && $0 != camera } }

  /// Whether `goForward()` would move the camera.
  public var canGoForward: Bool { forward.contains { tree.contains($0) && $0 != camera } }
}
