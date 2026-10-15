import ArborCore
import Foundation

/// What is in Arbor's menu. **docs/MENU.md decides the order, the grouping and the titles**; this file writes them down,
/// and `StatusMenu` shows the result and reports what was chosen (docs/ARCHITECTURE.md, "The menu").
///
/// **To add an item, find its row in docs/MENU.md and add one line in the same place here:**
///
///     Item.command("Balance Sizes", .equalize(all: false))                      // runs a command, shows its shortcut
///     Item.command("Step In", .stepIn).enabled(canStep.in)                      // greyed out when it would fail
///     Item.command("Keep This Window in View", .togglePin(nil)).ticked(isPinned) // a switch
///     Item.news("Arbor is starting…")                                           // says something, cannot be chosen
///     Item.submenu("Tab Group") { … }                                           // the same lines, one level down
///     if displays.count > 1 { … }                                               // for what may not exist at all
///
/// Then add the line to `MenuTests.theWholeMenu`, which is the menu written out and fails until it agrees. Nothing in
/// `StatusMenu` changes. A row that cannot act now is greyed out, not left out, so that it is found where it was.
///
/// **The top level stays at 18 rows** (docs/MENU.md, rule 3): in the state with the most lines the menu is 545 points high, and
/// it may be 600, so that Pause Arbor and Quit Arbor are never below the fold of a small display. `MenuHeightTests`
/// counts. The room for two more rows is kept free. A new row goes into the submenu that ends its group.
extension Controller {
  private typealias Item = MenuModel.Item
  private typealias Section = MenuModel.Section

  /// The menu as it would open now: for the display under the pointer and the focused window.
  public func menuModel() -> MenuModel {
    var sections = [stateSection()]
    if isRunning {
      sections += [viewSection(), windowSection(), arrangementSection(), arborSection()]
      sections.append(
        Section {
          Item.command("Pause Arbor", .togglePause)
          quit
        })
    } else {
      // Nothing that would need a running Arbor: what it waits for is above, and these always work. Settings… shows its shortcut where
      // Arbor holds it: not in a pause.
      sections += [
        Section {
          settingsWindow
          help
        }, Section { quit },
      ]
    }
    // Worked out once: before the app has registered any, every asking reads the whole of the settings' bindings again.
    let bindings = bindingsInEffect
    return MenuModel(sections).showingShortcuts { self.shortcut(for: $0, among: bindings) }
      // Arbor does not write to a file it cannot read. Greyed out under the row that says so and opens the file.
      .mapItems { settingsFileProblem != nil && $0.command?.changesSettings == true ? $0.enabled(false) : $0 }
      .mapItems { item in
        guard holdLevel == .view else { return item }
        // They open a window, Arbor's own or another app's, over what is being shown. Quitting is a way out.
        if case .app(let action) = item.action, action != .quit { return item.enabled(mayShowPanels) }
        guard let command = item.command else { return item }
        // Greyed out under the line that says why.
        var item = item.enabled(!holdWouldRefuse(command))
        // From here they are ways out. Their keys are not: one releases instead, and is shown at Release, the other is refused.
        if command.bringsEverythingIntoView { item.shortcut = nil }
        return item
      }
  }

  /// A line about holding the view (Controller+Hold.swift decides them, docs/MENU.md where they go).
  private func item(_ entry: HoldMenuEntry) -> Item {
    guard let command = entry.command else { return Item.text(entry.title) }
    var item = Item.command(entry.title, command).ticked(entry.isOn).help(entry.help).enabled(entry.isEnabled)
    // The key that pauses lets go of a held view first.
    if holdLevel == .view, entry.title.hasSuffix(Self.release), shortcut(for: command) == nil { item.shortcut = shortcut(for: .togglePause) }
    return item
  }

  /// `menu`: the menu as text. A query, so it works before `start()` and during a pause.
  func menuReport() -> CommandResult {
    let model = menuModel()
    let message = "\(model.allItems.count) items, \(Int(model.height)) points high"
    return CommandResult(ok: true, message: message, text: model.text)
  }

  // MARK: States

  /// What Arbor is doing that is out of the ordinary, each in one row: plain words, and after " · " the command that ends it, which
  /// choosing the row runs ("Arbor is paused · Resume"). macOS draws a line of text too faintly for what a person opened the menu to
  /// find out. In the order of precedence of docs/MENU.md, "States"; empty on an ordinary day.
  private func stateSection() -> Section {
    var states: [[Item]] = []
    if !accessibilityGranted {
      // Taken away while Arbor ran (F63): what happened, how many windows are out of view, that they come back with it.
      let lines = permissionMenuLines.isEmpty ? ["Arbor needs Accessibility permission"] : permissionMenuLines
      // Check Setup and not System Settings: with a new build over an old grant the switch there looks on, and only Check Setup says so.
      states.append([Item.command(lines[0] + " · Check Setup…", .checkSetup)] + lines.dropFirst().map { Item.news($0) })
    } else if isPaused {
      states.append([Item.command(pausedLine + " · Resume", .togglePause).help("While paused, Arbor leaves windows and shortcuts alone")])
    } else if !isRunning {
      states.append([Item.news("Arbor is starting…")])
    }
    if !holdState.isEmpty { states.append(holdState.map(item)) }
    // Before the state that only a change of settings ends: the topmost way out is never greyed out.
    if let problem = settingsFileProblem {
      // Where, not what: "line 3, column 3". The file's own editor and `doctor` have room for the rest.
      let place = problem.split(separator: ":", maxSplits: 1).first.map(String.init) ?? problem
      states.append([Item.app("Settings.json has a mistake: \(place) · Settings File…", .openSettingsFile)])
    }
    // What the ticked row in Focused Window ▸ does: that is a submenu, and in this state no key helps.
    if let notice = passThroughNotice {
      states.append([shortcutsOffInThisApp.command.map { Item.command(notice + " · Turn On", $0).withoutShortcut() } ?? Item.news(notice)])
    }
    // What no command ends. The words before the brackets are the news, and as long as a menu's line should be; which file has the rest
    // is in the tooltip, and in `status`.
    for notice in notices {
      let news = notice.split(separator: "(", maxSplits: 1).first.map { $0.trimmingCharacters(in: .whitespaces) } ?? notice
      states.append([news == notice ? Item.news(notice) : Item.news(news).help(notice)])
    }
    // More than two would push the first commands, among them the way back, out of their places.
    return Section { states.prefix(2).flatMap { $0 } }
  }

  /// docs/MENU.md, state 3. In the words of `status` and the replies: "paused for Game".
  private var pausedLine: String {
    if isPausedForApp { return "Arbor is paused for “\(frontmostAppName)”" }
    guard let pauseEnd else { return "Arbor is paused" }
    return "Arbor is paused until \(pauseEnd.formatted(date: .omitted, time: .shortened))"
  }

  // MARK: View

  /// The three things people open the menu for, then where the view can go. Arrange Windows is the first command: ⌃⌥A is never to be
  /// bound again (QUESTIONS Q29, point 2), so this is where it is run from. Under it the two answers to "where has my window gone".
  private func viewSection() -> Section {
    // The places of the display under the pointer, which is the one these commands act on, worded, greyed out
    // and ticked as the menu bar's buttons are.
    let places = menuBarModel(complete: true)
    let focused = focusedWindowInHand
    let map = minimapInMenu
    return Section {
      Item.command("Arrange Windows", .arrange).enabled(canArrange)
      // Controller+OpenWindows.swift.
      Item.submenu("Windows") { windowListItems() }
      Item.command("Show Everything", .showAll).like(places.button(.everything))
      Item.command("Frame Focused Window", .zoom(nil)).enabled(focused.map(canFrame) ?? false).ticked(focused?.isFramed == true)
      Item.command("Go to…", .find(nil)).enabled(!finderRows().isEmpty)
      Item.submenu("Saved Views", sections: savedViewSections(places))
      Item.submenu(
        "View",
        sections: [
          Section {
            Item.command("Show the Desktop", .desktop).like(places.button(.desktop))
            Item.command("Step Out", .stepOut).enabled(canStep.out)
            Item.command("Step In", .stepIn).enabled(canStep.in)
            Item.command("Back", .back).like(places.button(.back))
            Item.command("Forward", .forward).like(places.button(.forward))
          },
          Section { Item.command("Show Minimap", .minimap).enabled(map.canToggle).ticked(map.isUp) },
          Section { holdRows.map(item) },
        ])
    }
  }

  /// Whether there is a wider and a closer view than this one, by the rules `step-out` and `step-in` go by.
  private var canStep: (out: Bool, in: Bool) {
    guard let (display, workspace) = menuDisplay, let view = treeView(display), let layout = layouts[display] else {
      return (false, false)
    }
    return (
      Navigation.stepOut(from: workspace.camera, in: view) != nil,
      Navigation.stepIn(
        from: workspace.camera, toward: nil, focused: system.focusedWindow(), in: view, layout: layout) != nil
    )
  }

  private func savedViewSections(_ places: MenuBarModel) -> [Section] {
    var saved: [Int: MenuBarModel.Button] = [:]
    for button in places.buttons {
      if case .view(let slot) = button.id { saved[slot] = button }
    }
    let names = namedSpacesMenu()
    return [
      Section("Go To") {
        for slot in saved.keys.sorted() {
          if let button = saved[slot] { Item.command(button.title, .goToView(slot)).like(button) }
        }
        // Named spaces come after the numbers (F20).
        for space in names where !space.startsSection { Item.command(space.title, space.command).ticked(space.isTicked) }
      },
      Section("Save This View As") {
        for slot in 1...9 {
          Item.command(saved[slot] == nil ? "View \(slot)" : "View \(slot) (replace)", .saveView(slot))
        }
      },
      Section {
        for row in names where row.startsSection { Item.command(row.title, row.command) }
      },
    ]
  }

  // MARK: Focused Window

  private struct FocusedWindow {
    var window: WindowSnapshot
    var display: DisplayID
    var workspace: Workspace
    /// Its place in the arrangement. Nil while it floats.
    var leaf: NodeID?
    var isFramed: Bool { leaf != nil && workspace.camera == leaf }
  }

  /// The focused window, if commands that name no window would take it (`target(_:)`).
  private var focusedWindowInHand: FocusedWindow? {
    guard let id = keyboardFocus(), let window = windows[id], filter.manages(window), !window.isFullScreen,
      !window.isMinimized, !window.isHidden, let display = workspaceID(containing: id), let workspace = workspaces[display]
    else { return nil }
    return FocusedWindow(window: window, display: display, workspace: workspace, leaf: workspace.tree.leaf(containing: id))
  }

  /// Whether `zoom` would do anything for the focused window, by its own rules and in their order.
  private func canFrame(_ focused: FocusedWindow) -> Bool {
    let (id, workspace) = (focused.window.id, focused.workspace)
    let (tree, camera) = (workspace.tree, workspace.camera)
    if workspace.isStashed(id) { return true }
    // Kept in view or summoned, it has no place to frame. The key un-frames what lies beneath it, if that is framed.
    if workspace.staysInView(id) {
      return camera != tree.root && (tree.isStack(camera) || camera == tree.desktop) && canUnframe(camera, on: focused.display)
    }
    // Framed already, the key goes back.
    let space = focused.leaf ?? workspace.guests?[id] ?? tree.desktop
    return camera != space || space == tree.root || canUnframe(space, on: focused.display)
  }

  /// Every row is about the focused window or its app, and all are greyed out when there is none.
  private func windowSection() -> Section {
    let focused = focusedWindowInHand
    return Section {
      Item.submenu(
        "Dock Focused Window",
        sections: [
          Section {
            for edge in Edge.allCases {
              Item.command(edge.rawValue.capitalized, .dock(nil, edge))
                .enabled(focused.map { !isAsFarAsItGoes($0, toward: edge) } ?? false)
            }
          },
          Section {
            if displays.count > 1 { Item.command("Move to Next Display", .moveToDisplay(.next, nil)).enabled(focused != nil) }
          },
        ])
      // The command the shortcut runs. On a window that floats it would dock it, which is not what the row says.
      Item.command("Float Focused Window", .toggleFloat(nil)).enabled(focused?.leaf != nil)
      Item.submenu(
        "Focused Window",
        sections: [
          Section {
            // No app's name: it pins a window. The app is what a rule is for.
            Item.command("Keep This Window in View", .togglePin(nil)).enabled(focused != nil)
              .ticked(focused.map { isPinned($0.window.id) } ?? false)
              .help(
                "It keeps its place wherever you zoom. Dragging moves it and never docks it: to dock it, use Dock Focused "
                  + "Window, or turn this off first.")
          },
          Section {
            if let window = focused?.window, let bundle = window.bundleID {
              Item.command("Don’t Arrange “\(window.appName)”", .exclude(bundleID: bundle))
            } else {
              Item.text("Don’t Arrange This App")
            }
            shortcutsOffInThisApp
          },
        ])
    }
  }

  /// About the app in front, whether or not Arbor arranges its windows. Never about Arbor itself.
  private var shortcutsOffInThisApp: Item {
    guard let front = frontmostApp, let bundle = front.bundleID, bundle != Bundle.main.bundleIdentifier else {
      return Item.text("Shortcuts Off in This App")
    }
    return Item.command("Shortcuts Off in “\(front.name)”", .passThrough(bundleID: bundle)).withoutShortcut()
      .ticked(settings.passesThrough(bundle))
  }

  /// `dock` has nowhere to take a docked window: asked as `dock` asks it.
  private func isAsFarAsItGoes(_ focused: FocusedWindow, toward edge: Edge) -> Bool {
    guard let leaf = focused.leaf else { return false }  // it floats, and can dock at any edge
    if case .refused = moving(focused.window.id, at: leaf, toward: edge, in: focused.workspace, on: focused.display) { return true }
    return false
  }

  // MARK: Arrangement

  /// Whether `arrange`, which is for the display under the pointer, would find anything to take. Windows kept in view, and those that come and go
  /// with `summon`, accompany the arrangement and are not part of it; a place kept for a window that is not open yet is forgotten first.
  private var canArrange: Bool {
    guard let workspace = menuDisplay?.1 else { return false }
    return workspace.tree.allWindows.contains { !pendingSlots.contains($0) }
      || workspace.floating.keys.contains { windows[$0]?.isPresent == true && workspace.role(of: $0) == nil }
  }

  /// What else changes the whole arrangement.
  private func arrangementSection() -> Section {
    let here = menuDisplay?.1
    // They name the step they would take back or put back; plain and grey when there is none (Controller+Undo.swift).
    let (undoTitle, redoTitle) = (nextStepTitle(.undo), nextStepTitle(.redo))
    let focused = focusedWindowInHand
    // `balance` evens out the groups in view, `rotate` and `mirror` the focused window's (Controller+Tiling.swift).
    let groupsInView = here.map { workspace in workspace.tree.preorder(from: workspace.camera).contains(where: workspace.tree.isSplit) }
    var hasGroup = false
    if case .group = focusedGroup() { hasGroup = true }
    return Section {
      Item.command(undoTitle.map { "Undo \($0)" } ?? "Undo", .undo).enabled(undoTitle != nil)
      Item.command(redoTitle.map { "Redo \($0)" } ?? "Redo", .redo).enabled(redoTitle != nil)
      // One of the ways back, which are never greyed out: nobody should have to wonder why.
      Item.command("Float All Windows", .floatAll)
      Item.submenu(
        "Arrangement",
        sections: [
          Section {
            Item.command("Grow", .grow(nil)).enabled(focused.map { hasRoomToTrade($0.window.id) } ?? false)
            Item.command("Shrink", .shrink(nil)).enabled(focused.map { hasRoomToTrade($0.window.id) } ?? false)
            Item.command("Balance Sizes", .equalize(all: false)).enabled(groupsInView == true)
          },
          Section {
            Item.command("Rotate Group", .rotate).enabled(hasGroup)
            Item.command("Mirror Group", .mirror).enabled(hasGroup)
          },
          Section { Item.command("Lay Out Again", .relayout) },
          Section { Item.command("Dock New Windows", .toggleAutoDock).ticked(settings.docksNewWindows) },
          // Last, because it grows.
          Section("Arrange Again") {
            for app in excludedApps { Item.command(app.name, .include(bundleID: app.bundleID)) }
          },
        ])
    }
  }

  /// The apps Arbor was told not to arrange, by name.
  private var excludedApps: [(name: String, bundleID: String)] {
    // A list edited by hand can name an app twice.
    var seen = Set<String>()
    return settings.excludedBundleIDs.filter { seen.insert($0.lowercased()).inserted }.map { bundle in
      let met = appName(forBundleID: bundle)
      // Neither open nor installed: the last part of its id is the nearest thing to a name.
      let name = met != bundle ? met : nameOfApp?(bundle) ?? bundle.split(separator: ".").last.map(String.init) ?? bundle
      return (name, bundle)
    }.sorted { ($0.name.lowercased(), $0.bundleID) < ($1.name.lowercased(), $1.bundleID) }
  }

  // MARK: Arbor

  private func arborSection() -> Section {
    Section {
      settingsWindow
      help
    }
  }

  /// In every state, so that nobody is locked out with shortcuts switched off or ⌃⌥, unbound.
  private var settingsWindow: Item { Item.command("Settings…", .settings(.showWindow())) }

  /// Everything about Arbor itself that is wanted once in a while. It is there in every state.
  private var help: Item {
    return Item.submenu(
      "Help",
      sections: [
        Section {
          // With none to show the panel does not come (`toggleCheatSheet`), nor from an Arbor that is not running.
          Item.command("Keyboard Shortcuts…", .showShortcuts)
            .enabled(isRunning && settings.hotkeysEnabled)
            .enabled(!(isPassingThrough ? effectiveBindings.bindings : activeBindings).isEmpty)
          Item.command("Welcome…", .welcome)
          Item.command("Check Setup…", .checkSetup)
        },
        Section {
          Item.app("Settings File…", .openSettingsFile)
          Item.command("Reload Settings", .reloadSettings).enabled(isRunning)
          Item.app("Show Log", .showLog)
        },
        Section {
          // "Update Available…" once an automatic check has found one: nothing else says so.
          Item.command(updateMenuTitle, .checkForUpdates).withoutShortcut()
          Item.app("About Arbor", .showAbout)
        },
      ])
  }

  /// Always the last row.
  /// The one time quitting does not bring every window back, its title says so (F63).
  private var quit: Item { Item.app(quitTitle, .quit).shortcut(KeyChord(.command, .q)) }
}
