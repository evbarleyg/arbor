import ArborCore
import CoreGraphics

/// The menu bar item (docs/features/F10-menu-bar-and-onboarding.md). The controller says what it shows;
/// `StatusMenu` draws that and turns clicks back into commands.
extension Controller {
  /// What the menu bar item shows now: the buttons for the display camera commands act on (the one
  /// under the pointer), or none while Arbor is not arranging windows (it waits for permission, or is paused),
  /// while nothing is docked on that display, or when `menuBarControls` is off.
  /// - Parameter complete: true for every button whatever the settings hide. The full menu goes by
  ///   that, so that it ticks, greys out and words the same places the same way.
  public func menuBarModel(complete: Bool = false) -> MenuBarModel {
    guard isRunning, complete || settings.menuBarControls, let (display, workspace) = menuDisplay else {
      return MenuBarModel(icon: !accessibilityGranted ? .needsPermission : isPaused ? .paused : holdIcon)
    }
    // Every button moves the view, which a held view refuses. A lock says so with the menu closed, and a click on it opens
    // the menu, where Release comes first.
    guard complete || holdLevel != .view else { return MenuBarModel(icon: holdIcon) }
    // With nothing docked the Desktop is everything, and there is nowhere to go: a row of buttons would only take
    // room in the menu bar, and a newcomer's first click should open the menu.
    guard complete || !workspace.tree.allWindows.isEmpty else { return MenuBarModel(icon: holdIcon) }
    let bindings = bindingsInEffect
    let model = MenuBarModel(
      display: display, workspace: workspace, historyButtons: complete || settings.historyButtons,
      fill: settings.menuBarFill,
      shortcut: { KeyBindings.label(for: $0, in: bindings) },
      describe: { self.describe($0, on: display) })
    // macOS left an item this wide out of the menu bar: better a single icon than no face at all.
    guard complete || menuBarRoom.fits(MenuBarLayout(model).size.width) else { return MenuBarModel(icon: holdIcon) }
    return model
  }

  /// The single icon of an Arbor that is running. While the buttons show, which work as ever then, nothing says that it is holding still.
  private var holdIcon: MenuBarModel.Icon {
    switch holdLevel {
    case .view: .held
    case .still: .holdingStill
    case nil: MenuBarModel.Icon()
    }
  }

  /// The display the item's buttons and the menu's rows are about: the one under the pointer, which is the one a command
  /// from the menu acts on (F56). Not `cameraDisplay()`: that decides for a command and remembers what it decided, and
  /// drawing the item is no command.
  var menuDisplay: (DisplayID, Workspace)? {
    guard let id = pointerDisplayID, let workspace = workspaces[id] else { return nil }
    return (id, workspace)
  }

  /// The shortcuts that work now: the ones the app registered or, until it has said, the ones the
  /// settings describe.
  var bindingsInEffect: [KeyBinding] {
    registeredBindings ?? activeBindings
  }

  /// The shortcut that runs `command`, for menus and tooltips.
  public func shortcut(for command: Command) -> MenuModel.Shortcut? { shortcut(for: command, among: bindingsInEffect) }

  /// For whoever asks about many commands at once.
  func shortcut(for command: Command, among bindings: [KeyBinding]) -> MenuModel.Shortcut? {
    bindings.first { $0.command == command }.map { MenuModel.Shortcut($0.chord, layout: layoutInEffect) }
  }

  /// A few words on what a space holds, so that a saved view is more than a number: "the Desktop", "everything",
  /// "Safari and Mail", "5 windows". The words of Arbor's replies (Controller+Words.swift), without the node number
  /// that follows them there for the log and for `zoom-node`: nobody logs a tooltip or types it back.
  public func describe(_ node: NodeID, on display: DisplayID) -> String {
    let name = name(of: node, on: display)
    let number = " (\(node))"
    return name.hasSuffix(number) ? String(name.dropLast(number.count)) : name
  }

  /// `menu-bar`: one line per button with its name, where it starts in the item's image and how wide
  /// it is (in points), its state and its tooltip. Scripts use it to check what the item shows and to
  /// aim real clicks. A query, so it works before `start()`.
  func menuBarReport() -> CommandResult {
    let model = menuBarModel()
    guard let display = model.display, !model.buttons.isEmpty else {
      let why =
        !isRunning
        ? statusText
        : holdLevel == .view
          ? "the view is held"
        : !settings.menuBarControls
          ? "menuBarControls is false"
          : menuDisplay == nil
            ? "there is no display"
            : menuDisplay?.1.tree.allWindows.isEmpty == true
              ? "nothing is docked on this display" : "macOS has no room in the menu bar for the buttons"
      return .success("a single icon that opens the menu: \(why)")
    }
    let layout = MenuBarLayout(model)
    let lines = zip(layout.buttons, layout.cells).map { button, cell in
      let name = button.id.description
      let state = [button.isCurrent ? "current" : nil, button.isEnabled ? nil : "disabled"].compactMap { $0 }
      return [
        name + String(repeating: " ", count: max(10 - name.count, 0)), "\(Int(cell.minX))", "\(Int(cell.width))",
        state.isEmpty ? "-" : state.joined(separator: ","), button.tooltip,
      ].joined(separator: " ")
    }
    return CommandResult(
      ok: true,
      message: "\(model.buttons.count) buttons for display \(display), \(Int(layout.size.width)) points wide",
      text: lines.joined(separator: "\n"))
  }
}

/// Keeps a menu bar item in step with a controller: calls `onChange` with the new model after
/// anything that changes what the item shows, and only then. One command reports several changes (a
/// layout, the camera, a focus), so the model is rebuilt once, after the command has finished.
///
/// The model follows the pointer from display to display, but nothing reports the pointer moving, so
/// that shows at the next change or `update()`. Make one per controller.
///
/// It also finds out whether macOS has room for what was drawn (`MenuBarRoom`): a moment after every change it asks
/// `isShowing`, and an item that was left out is drawn again as the single icon.
@MainActor
public final class MenuBarWatcher {
  /// What `onChange` was last given (at first, what the controller showed when the watcher was made).
  public private(set) var model: MenuBarModel
  private weak var controller: Controller?
  private let isShowing: @MainActor () -> Bool?
  private let onChange: @MainActor (MenuBarModel) -> Void
  /// The displays there were when room was last looked for.
  private var displays: [DisplayID]

  /// How long macOS is given to lay the menu bar out again before it is asked.
  static let settleTime = 1.0

  /// - Parameter isShowing: whether macOS shows the item now, nil if that cannot be told.
  public init(
    controller: Controller, isShowing: @escaping @MainActor () -> Bool? = { nil },
    onChange: @escaping @MainActor (MenuBarModel) -> Void
  ) {
    self.controller = controller
    self.isShowing = isShowing
    self.onChange = onChange
    model = controller.menuBarModel()
    displays = controller.displays.map(\.id)
    controller.observe { [weak self] change in self?.changed(change) }
    lookForRoomSoon()
  }

  private func changed(_ change: Controller.Change) {
    guard let controller else { return }
    // Another menu bar, or other buttons: what did not fit may fit now.
    let now = controller.displays.map(\.id)
    if change == .settings || now != displays {
      displays = now
      controller.menuBarRoom.forget()
    }
    controller.scheduler.schedule("menu-bar", after: 0) { [weak self] in self?.update() }
  }

  /// Rebuilds the model now, and reports it if it differs from the last one.
  public func update() {
    guard let controller else { return }
    let current = controller.menuBarModel()
    guard current != model else { return }
    model = current
    onChange(current)
    lookForRoomSoon()
  }

  /// Whatever was found too wide is drawn once more. For when "not showing" may have had another reason than a full menu
  /// bar: while the displays sleep nothing shows.
  public func tryAgain() {
    controller?.menuBarRoom.forget()
    update()
    lookForRoomSoon()
  }

  private func lookForRoomSoon() {
    controller?.scheduler.schedule("menu-bar-room", after: Self.settleTime) { [weak self] in self?.lookForRoom() }
  }

  private func lookForRoom() {
    guard let controller else { return }
    let width = model.buttons.isEmpty ? ArborGlyph.iconSize.width : MenuBarLayout(model).size.width
    let before = controller.menuBarRoom.tooWide
    controller.menuBarRoom.observe(width: width, isShowing: isShowing())
    // Only for what was learnt: this is no occasion to follow the pointer or anything else.
    if controller.menuBarRoom.tooWide != before { update() }
  }
}
