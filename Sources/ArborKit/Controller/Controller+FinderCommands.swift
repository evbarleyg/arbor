import ArborCore
import Foundation

/// Go to… finds commands (board 0.14). With nine keys bound, everything else is in the menu and here: whoever knows what a thing is
/// called types a few letters of it.
///
/// **The rows are the menu's.** They are read from `menuModel()`, so a command is found by the name the menu gives it, with the key
/// and the tick the menu shows, greyed out when the menu greys it out, and a row added to the menu is found here without another
/// line. A row of a submenu is called by its way there: "Dock Focused Window ▸ Left". Then come the commands that have a key in the
/// whole map and no row in the menu, by `Command.title`.
///
/// The menu is about the display under the pointer, which chose it. The palette is on a display of its own, and its rows are about that
/// one, when they are read and when one is run (`on(_:_:)`): "Undo Dock" must not undo another display's Float.
///
/// A command is listed only once something is typed (`FinderModel.commands`), and only in the palette: `find <text>`, which
/// goes somewhere without showing anything, finds places and nothing else. A link may say `find`; it must not thereby run whatever it names.
extension Controller {
  /// A row and what it runs. The row holds the command as text, for whoever shows, compares and records it; not every command
  /// the menu makes can be read back from its text (an app's id with a letter `exclude` does not take).
  struct PaletteCommand {
    var row: FinderModel.Row
    var command: Command
  }

  /// Every command Go to… can run on `display`, as the menu stands now.
  func paletteCommands(on display: DisplayID) -> [PaletteCommand] {
    var found: [PaletteCommand] = []
    var names = Set<String>()
    var texts = Set<String>()
    func add(_ command: Command, name: String, shortcut: String?, isOn: Bool, isAvailable: Bool) {
      // A command the menu has under two names ("Release", "Hold Still") is found by either.
      guard isForThePalette(command), names.insert(name).inserted else { return }
      texts.insert(command.text)
      found.append(
        PaletteCommand(
          row: .command(command, name: name, shortcut: shortcut, isOn: isOn, isAvailable: isAvailable, display: display),
          command: command))
    }
    func walk(_ sections: [MenuModel.Section], under path: [String], isSubmenu: Bool) {
      for section in sections {
        // The headings of the menu itself sort it for the eye. Those of a submenu are part of what a row means: "Save This View As".
        let path = path + (isSubmenu ? [section.title].compactMap { $0 } : [])
        for item in section.items {
          if let command = item.command {
            add(
              command, name: (path + [item.title]).joined(separator: " ▸ "), shortcut: item.shortcut?.label, isOn: item.isTicked,
              isAvailable: item.isEnabled)
          }
          walk(item.sections, under: path + [item.title], isSubmenu: true)
        }
      }
    }
    // Reading the menu is asking, also in the middle of `find`, which is a command.
    walk(deciding(false) { on(display) { menuModel() } }.sections, under: [], isSubmenu: false)

    let bindings = bindingsInEffect
    for command in KeyBindings.all.map(\.command).sorted(by: { ($0.helpOrder, $0.text) < ($1.helpOrder, $1.text) })
    where !texts.contains(command.text) {
      add(command, name: command.title, shortcut: shortcut(for: command, among: bindings)?.label, isOn: false, isAvailable: true)
    }
    return found
  }

  /// Not the palette itself; and not what it lists as a place already. A row of the menu that leads to a window, a view or a named space is
  /// called by a title or a name, which are shown and never written down, and what is chosen here goes into traces.
  private func isForThePalette(_ command: Command) -> Bool {
    switch command {
    case .find, .goToView, .goToSpace, .reveal: false
    default: true
    }
  }

  /// A row that runs a command was chosen in the palette on `display`.
  ///
  /// The list is a snapshot, so the menu is read again, as a place is looked for again. What the menu greys out by now is not run: it is
  /// greyed out because it would fail, or because it would do something else than its row says (Float Focused Window, which is
  /// `toggle-float`, on a window that floats). The palette says so and stays.
  ///
  /// Otherwise it runs as its key would: on the window the palette opened over, which has the keyboard again, and answered on screen. Not
  /// as from the menu, whose rows are chosen with the pointer: the shortcut pressed next would follow the pointer, which may rest anywhere (F56).
  func runFromThePalette(_ text: String, on display: DisplayID) {
    let rows = paletteCommands(on: display).filter { $0.row.destination == .command(text) }
    guard let chosen = rows.first(where: \.row.isAvailable) else {
      Log.debug("find: \(FinderDestination.command(text)) cannot act now")
      let notice = rows.first.map { "“\($0.row.name)” can do nothing just now" } ?? "That command is not in the menu now"
      if let model = finderModel(on: display, notice: notice) {
        overlays.showFinder(model)
      } else {
        closeFinder()
      }
      return
    }
    // Closed first, as before going anywhere. `perform` would do it too, but not for a query.
    closeFinder()
    on(display) { _ = perform(chosen.command, from: .shortcut) }
  }
}
