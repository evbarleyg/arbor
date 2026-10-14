import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 25, width: 1280, height: 775), isMain: false)

/// The menu bar item against the real controller (docs/features/F10-menu-bar-and-onboarding.md).
@Suite @MainActor struct MenuBarTests {
  typealias ID = MenuBarModel.Button.ID

  /// [Safari | Desktop | Notes] with Mail floating, started, showing everything.
  func makeHarness(settings: Settings = Settings()) -> (Harness, WindowID, WindowID, WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let c = h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 400, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b, c)
  }

  func ids(_ h: Harness) -> [ID] { h.controller.menuBarModel().buttons.map(\.id) }
  func current(_ h: Harness) -> [ID] { h.controller.menuBarModel().buttons.filter(\.isCurrent).map(\.id) }
  func enabled(_ h: Harness, _ id: ID) -> Bool? { h.controller.menuBarModel().button(id)?.isEnabled }

  // MARK: The model

  @Test func thereAreNoButtonsUntilArborArrangesWindows() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    #expect(h.controller.menuBarModel() == MenuBarModel(icon: .needsPermission), "the icon says that something is wanted")
    h.controller.accessibilityGranted = true
    #expect(h.controller.menuBarModel() == MenuBarModel(), "starting")
    let a = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(a.rawValue) left")
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .menu])
    #expect(h.controller.menuBarModel().display == h.display)
    h.controller.shutdown()
    #expect(h.controller.menuBarModel() == MenuBarModel())
  }

  /// Day one: a row of buttons with nowhere to go would only take room, and the first click should open the menu.
  @Test func withNothingDockedThereIsOnlyTheIcon() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    #expect(h.controller.menuBarModel() == MenuBarModel())
    #expect(h.run("menu-bar").message.contains("nothing is docked on this display"))
    h.run("dock \(a.rawValue) left")
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .menu])
    h.run("float \(a.rawValue)")
    #expect(h.controller.menuBarModel() == MenuBarModel())
    // The menu still words and ticks its places.
    #expect(h.controller.menuBarModel(complete: true).buttons.filter(\.isCurrent).map(\.id) == [.everything])
  }

  @Test func aPauseLeavesADimmedIcon() {
    var settings = Settings()
    let (h, _, _, _) = makeHarness()
    var updates: [MenuBarModel] = []
    let watcher = MenuBarWatcher(controller: h.controller) { updates.append($0) }
    h.run("pause")
    h.scheduler.advance(by: 0)
    #expect(updates.last == MenuBarModel(icon: .paused))
    h.run("resume")
    h.scheduler.advance(by: 0)
    #expect(updates.last?.icon == MenuBarModel.Icon())
    #expect(updates.last?.buttons.isEmpty == false)

    // As a single icon it has no buttons to lose, and still has to dim.
    settings.menuBarControls = false
    h.controller.apply(settings: settings)
    h.scheduler.advance(by: 0)
    #expect(updates.last == MenuBarModel())
    h.run("pause")
    h.scheduler.advance(by: 0)
    #expect(updates.last == MenuBarModel(icon: .paused))
    _ = watcher
  }

  /// A shortcut pressed after another goes on where the first one went (F56), so the controller remembers what the last
  /// command followed. The item is drawn again after every change, the menu is built whenever it opens, and scripts ask
  /// for both, at moments of their own: none of that is a command, and none may be remembered as one.
  @Test(arguments: ["nothing", "the item", "the menu", "menu-bar", "menu"])
  func lookingIsNotACommand(at what: String) {
    let desk = LeadTests.Desk()
    let watcher = MenuBarWatcher(controller: desk.h.controller) { _ in }
    desk.restPointerOnMainAndType(in: desk.c)
    // A shortcut is pressed and held for a moment, as for a peek (F51)…
    desk.h.system.keyDown()
    #expect(desk.h.run("out", from: .shortcut).ok)
    #expect(desk.camera(side) == desk.root(side), "the keyboard is on the side display")
    // …the pointer is nudged on the main display meanwhile, and just then something has the item drawn again.
    desk.h.scheduler.advance(by: 0.5)
    desk.h.system.cursor = CGPoint(x: 200, y: 400)
    desk.h.scheduler.advance(by: 0.1)
    switch what {
    case "nothing": break  // the control: what F56 does by itself
    case "the item": watcher.update()
    case "the menu": _ = desk.h.controller.menuModel()
    default: desk.h.run(what)
    }
    desk.h.system.keyUp()
    desk.h.scheduler.advance(by: 0.3)
    #expect(desk.h.press("in").ok)
    #expect(desk.camera(side) == desk.leaf(desk.c, side), "the next shortcut goes on where the last one went")
  }

  // MARK: A menu bar without room (a notch, many other items)

  /// A menu bar item on a Mac that leaves out whatever is wider than `room` points, or answers as `answer` says.
  @MainActor final class Item {
    var drawn: MenuBarModel
    var draws = 0
    private(set) var watcher: MenuBarWatcher?

    init(_ h: Harness, room: CGFloat = .infinity, answer: (@MainActor (Bool) -> Bool?)? = nil) {
      drawn = h.controller.menuBarModel()
      watcher = MenuBarWatcher(
        controller: h.controller,
        isShowing: { [unowned self] in
          let fits = MenuBarLayout(self.drawn).size.width <= room
          return answer.map { $0(fits) } ?? fits
        },
        onChange: { [unowned self] in
          self.drawn = $0
          self.draws += 1
        })
    }
  }

  /// One Safari window, nothing docked: the single icon, which macOS has had time to show.
  func dayOne() -> (Harness, WindowID) {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    return (h, a)
  }

  @Test func anItemThatMacOSLeavesOutBecomesTheSingleIcon() {
    let (h, a) = dayOne()
    let item = Item(h, room: 130)
    h.scheduler.advance(by: 1)
    #expect(h.controller.menuBarRoom.hasBeenSeen)
    #expect(h.controller.doctorReport().check("Menu bar item") == .init(mark: .ok, title: "Menu bar item", detail: "showing"))

    // Five buttons are 118 points wide, and fit.
    h.run("dock \(a.rawValue) left")
    h.scheduler.advance(by: 1)
    #expect(item.drawn.buttons.count == 5)
    #expect(MenuBarLayout(item.drawn).size.width == 118)

    // A saved view makes it 144.
    h.run("save-view 1")
    h.scheduler.advance(by: 0)
    #expect(item.drawn.buttons.count == 6, "drawn, since nobody can know beforehand")
    h.scheduler.advance(by: 1)
    #expect(item.drawn == MenuBarModel(), "left out, so: the single icon")
    #expect(h.run("menu-bar").message == "a single icon that opens the menu: macOS has no room in the menu bar for the buttons")
    h.scheduler.advance(by: 1)
    let check = h.controller.doctorReport().check("Menu bar item")
    #expect(check?.mark == .note)
    #expect(check?.detail.hasPrefix("showing as a single icon: macOS had no room for 144 points of buttons") == true)
    #expect(h.run("doctor").ok)

    // Everything is still in the menu, ticked and greyed out as ever.
    #expect(h.controller.menuModel().item("View 1: everything")?.isTicked == true)

    // It stays that way: no flicker with every command.
    let draws = item.draws
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    h.run("save-view 2")
    h.scheduler.advance(by: 3)
    #expect(item.draws == draws)
  }

  @Test func whatIsNarrowerIsTriedAndSoIsEverythingAfterAChangeOfSettingsOrDisplays() {
    let (h, a) = dayOne()
    let item = Item(h, room: 130)
    h.scheduler.advance(by: 1)
    h.run("dock \(a.rawValue) left")
    h.run("save-view 1")
    h.scheduler.advance(by: 2)
    #expect(item.drawn.buttons.isEmpty)

    // Without back and forward it is 96 points.
    var settings = Settings()
    settings.historyButtons = false
    h.controller.apply(settings: settings)
    h.scheduler.advance(by: 2)
    #expect(item.drawn.buttons.map(\.id) == [.desktop, .everything, .view(1), .menu])

    // With them again it is tried once more, and found too wide once more.
    h.controller.apply(settings: Settings())
    h.scheduler.advance(by: 0)
    #expect(item.drawn.buttons.count == 6)
    h.scheduler.advance(by: 1)
    #expect(item.drawn.buttons.isEmpty)

    // A display is plugged in: another menu bar.
    h.system.setDisplays([FakeWindowSystem.standardDisplay, side])
    h.scheduler.advance(by: 2)
    h.scheduler.advance(by: 0)
    #expect(h.controller.displays.count == 2)
    #expect(item.draws > 0 && h.controller.menuBarRoom.tooWide == 144, "tried again, and learnt again")
  }

  /// While the displays sleep nothing shows. What was learnt then is unlearnt when they wake.
  @Test func aNoThatHadAnotherReasonHealsWhenTheItemIsTriedAgain() {
    let (h, a) = dayOne()
    var asleep = false
    let item = Item(h, answer: { _ in !asleep })
    h.scheduler.advance(by: 1)
    h.run("dock \(a.rawValue) left")
    h.scheduler.advance(by: 1)
    asleep = true
    h.run("save-view 1")  // something has the item drawn again meanwhile
    h.scheduler.advance(by: 2)
    #expect(item.drawn.buttons.isEmpty, "taken for an item that found no room")
    asleep = false
    item.watcher?.tryAgain()
    #expect(item.drawn.buttons.count == 6)
    h.scheduler.advance(by: 2)
    #expect(item.drawn.buttons.count == 6, "and this time it is seen")
    #expect(h.controller.doctorReport().check("Menu bar item")?.detail == "showing")
  }

  /// Nobody has seen what every macOS answers. One that always says no must cost nobody their buttons.
  @Test func anAnswerThatIsAlwaysNoTakesNothingAway() {
    let (h, a) = dayOne()
    let item = Item(h, answer: { _ in false })
    h.scheduler.advance(by: 1)
    h.run("dock \(a.rawValue) left")
    h.run("save-view 1")
    h.scheduler.advance(by: 3)
    #expect(item.drawn.buttons.count == 6)
    let check = h.controller.doctorReport().check("Menu bar item")
    #expect(check?.mark == .note, "said, but not as a problem")
    #expect(check?.detail.hasPrefix("not showing, as far as macOS says") == true)
    #expect(h.run("doctor").ok)
  }

  /// A menu bar that hides itself shows no item however much room it has.
  @Test func whereItCannotBeToldNothingHappens() {
    let (h, a) = dayOne()
    let item = Item(h, answer: { _ in nil })
    h.scheduler.advance(by: 1)
    h.run("dock \(a.rawValue) left")
    h.run("save-view 1")
    h.scheduler.advance(by: 3)
    #expect(item.drawn.buttons.count == 6)
    #expect(h.controller.doctorReport().check("Menu bar item")?.detail == "unknown here")
  }

  @Test func evenTheSingleIconLeftOutIsAProblem() {
    let (h, _) = dayOne()
    var room = true
    let item = Item(h, answer: { _ in room })
    h.scheduler.advance(by: 1)
    room = false
    // Something has the item looked at again.
    h.run("pause")
    h.scheduler.advance(by: 2)
    let check = h.controller.doctorReport().check("Menu bar item")
    #expect(check?.mark == .problem)
    #expect(check?.detail.hasPrefix("not showing: no room in the menu bar") == true)
    #expect(check?.detail.contains("Opening Arbor again shows the welcome window") == true)
    _ = item
  }

  @Test func theMenuBarFollowsTheCamera() {
    let (h, a, _, _) = makeHarness()
    #expect(current(h) == [.everything])
    #expect(enabled(h, .back) == false && enabled(h, .forward) == false)

    h.run("desktop")
    #expect(current(h) == [.desktop])
    #expect(enabled(h, .back) == true && enabled(h, .forward) == false)

    h.run("zoom \(a.rawValue)")
    #expect(current(h).isEmpty, "a framed window has no button until it is saved as a view")

    h.run("back")
    #expect(current(h) == [.desktop])
    #expect(enabled(h, .back) == true && enabled(h, .forward) == true)

    h.run("back")
    #expect(current(h) == [.everything])
    #expect(enabled(h, .back) == false && enabled(h, .forward) == true)

    h.run("forward")
    #expect(current(h) == [.desktop])
  }

  @Test func savingAViewAddsItsButtonInSlotOrder() {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(b.rawValue)")
    h.run("save-view 5")
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .view(5), .menu])
    #expect(current(h) == [.view(5)])
    h.run("zoom \(a.rawValue)")
    h.run("save-view 2")
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .view(2), .view(5), .menu])
    #expect(current(h) == [.view(2)])
    h.run("view 5")
    #expect(current(h) == [.view(5)])
    // Saving over a slot moves its button's meaning, not its place.
    h.run("show-all")
    h.run("save-view 5")
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .view(2), .view(5), .menu])
    #expect(current(h) == [.everything, .view(5)])
  }

  @Test func aViewWhoseWindowClosedGoesWhereTheViewCommandGoes() {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("zoom \(c.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    #expect(h.controller.menuBarModel().button(.view(1))?.tooltip == "View 1: Mail (⌃⌥1)")

    // The column of Safari and Mail collapses into Safari, which takes the view over.
    h.system.close(c)
    #expect(ids(h).contains(.view(1)))
    #expect(h.controller.menuBarModel().button(.view(1))?.tooltip == "View 1: Safari (⌃⌥1)")
    #expect(current(h) == [.everything])
    #expect(h.run("view 1").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
    #expect(current(h) == [.view(1)])

    // With every docked window gone, the view, the Desktop and everything are one place, and the buttons go.
    h.system.close(a)
    h.system.close(b)
    #expect(ids(h).isEmpty)
    let places = h.controller.menuBarModel(complete: true)
    #expect(places.buttons.filter(\.isCurrent).map(\.id) == [.everything, .view(1)])
    #expect(places.button(.back)?.isEnabled == false, "every place in the history is where the camera already is")
    #expect(!h.run("back").ok)
  }

  @Test func startingOverClearsViewsAndHistory() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    #expect(h.run("arrange").ok)
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .menu])
    #expect(current(h) == [.everything])
    #expect(enabled(h, .back) == false)

    h.run("desktop")
    h.run("save-view 3")
    #expect(h.run("float-all").ok)
    #expect(ids(h).isEmpty)
    #expect(h.controller.menuBarModel(complete: true).button(.view(3)) == nil)
  }

  @Test func dockingThatWidensTheCameraMovesTheFilledButton() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    #expect(h.controller.menuBarModel(complete: true).buttons.filter(\.isCurrent).map(\.id) == [.everything])
    // The first dock wraps the Desktop in a split, and the camera widens to show the new window.
    h.run("dock \(a.rawValue) left")
    #expect(current(h) == [.everything])
  }

  @Test func eachDisplayHasItsOwnButtons() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    #expect(h.controller.menuBarModel().display == h.display)
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .view(1), .menu])
    #expect(current(h) == [.view(1)])
    #expect(enabled(h, .back) == true)

    // The other display has its own camera, history and views.
    h.system.cursor = CGPoint(x: 2000, y: 400)
    #expect(ids(h).isEmpty, "nothing is docked there yet")
    h.run("dock \(b.rawValue) right")
    #expect(h.controller.menuBarModel().display == side.id)
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .menu])
    #expect(current(h) == [.everything])
    #expect(enabled(h, .back) == false)
    h.run("desktop")
    h.run("save-view 4")
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .view(4), .menu])
    #expect(current(h) == [.desktop, .view(4)])

    h.system.cursor = CGPoint(x: 700, y: 400)
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .view(1), .menu])
    #expect(current(h) == [.view(1)])

    // Unplugged: the pointer can only be on the display that is left.
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(h.controller.menuBarModel().display == h.display)
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .view(1), .menu])
  }

  @Test func withoutADisplayThereIsNothingToShow() {
    let (h, _, _, _) = makeHarness()
    h.system.setDisplays([])
    #expect(h.controller.menuBarModel() == MenuBarModel())
    #expect(h.run("menu-bar").message.contains("no display"))
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    #expect(h.controller.menuBarModel(complete: true).buttons.map(\.id).starts(with: [.back, .forward, .desktop, .everything]))
  }

  @Test func theSettingsChooseWhatIsShown() {
    var settings = Settings()
    #expect(settings.menuBarControls && settings.historyButtons && settings.menuBarFill == 0.25)
    settings.historyButtons = false
    settings.menuBarFill = 0.12
    let (h, _, _, _) = makeHarness(settings: settings)
    #expect(ids(h) == [.desktop, .everything, .menu])
    #expect(h.controller.menuBarModel().fill == 0.12)

    settings.menuBarControls = false
    h.controller.apply(settings: settings)
    #expect(h.controller.menuBarModel() == MenuBarModel(), "a single icon that opens the menu")
    // The full menu still lists every place, whatever the item itself shows.
    #expect(h.controller.menuBarModel(complete: true).buttons.map(\.id) == [.back, .forward, .desktop, .everything, .menu])

    h.controller.apply(settings: Settings())
    #expect(ids(h) == [.back, .forward, .desktop, .everything, .menu])
  }

  @Test func tooltipsShowTheShortcutsThatWork() throws {
    let (h, a, b, c) = makeHarness()
    h.run("dock \(c.rawValue) beside \(a.rawValue) bottom")
    h.run("zoom-node \(h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: a)!)!.rawValue)")
    h.run("save-view 1")
    func tooltips() -> [String] { h.controller.menuBarModel().buttons.dropLast().map(\.tooltip) }
    #expect(
      tooltips() == [
        "Back (⌃⌥[)", "Forward (⌃⌥])", "Show the Desktop (⌃⌥D)", "Show Everything (⌃⌥Space)",
        "View 1: Safari and Mail (⌃⌥1)",
      ])

    // macOS refused ⌃⌥Space, and the user moved Back.
    var settings = Settings()
    settings.bindings = ["ctrl+opt+[": nil, "ctrl+opt+b": "back"]
    h.controller.apply(settings: settings)
    h.controller.registeredBindings = KeyBindings.effective(settings: settings).bindings.filter { $0.command != .showAll }
    #expect(
      tooltips() == [
        "Back (⌃⌥B)", "Forward (⌃⌥])", "Show the Desktop (⌃⌥D)", "Show Everything", "View 1: Safari and Mail (⌃⌥1)",
      ])
    #expect(h.controller.shortcut(for: .back) == MenuModel.Shortcut(try KeyChord(text: "ctrl+opt+b")))
    #expect(h.controller.shortcut(for: .showAll) == nil)

    h.controller.registeredBindings = nil
    settings.hotkeysEnabled = false
    h.controller.apply(settings: settings)
    #expect(tooltips() == ["Back", "Forward", "Show the Desktop", "Show Everything", "View 1: Safari and Mail"])
    _ = b
  }

  @Test func viewsAreDescribedInTheWordsOfArborsReplies() {
    let h = Harness()
    let windows = ["Safari", "Notes", "Mail", "Xcode", "Music"].map { h.system.open(app: $0) }
    h.start()
    h.run("dock \(windows[0].rawValue) left")
    h.run("dock \(windows[1].rawValue) beside \(windows[0].rawValue) bottom")
    let tree = { h.workspace.tree }
    let column = tree().parent(of: tree().leaf(containing: windows[0])!)!
    #expect(h.controller.describe(tree().leaf(containing: windows[0])!, on: h.display) == "Safari")
    #expect(h.controller.describe(column, on: h.display) == "Safari and Notes")
    #expect(h.controller.describe(tree().root, on: h.display) == "everything")
    #expect(h.controller.describe(tree().desktop, on: h.display) == "the Desktop")
    for window in windows.dropFirst(2) { h.run("dock \(window.rawValue) beside \(windows[0].rawValue) bottom") }
    #expect(h.controller.describe(column, on: h.display) == "5 windows")
    // No node numbers: those are for the log and for `zoom-node`.
    h.run("zoom-node \(column.rawValue)")
    #expect(h.run("save-view 1").message.contains("(\(column))"))
    #expect(h.controller.menuBarModel().button(.view(1))?.title == "View 1: 5 windows")
  }

  // MARK: Clicks

  @Test func clickingEachButtonGoesThereAndFillsItIn() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    h.run("save-view 2")
    for id in [ID.desktop, .view(1), .everything, .view(2)] {
      let layout = MenuBarLayout(h.controller.menuBarModel())
      let index = layout.buttons.firstIndex { $0.id == id }!
      guard case .run(let command) = layout.click(atX: layout.cells[index].midX, secondary: false) else {
        Issue.record("\(id) did not run a command")
        continue
      }
      #expect(h.controller.perform(command).ok)
      #expect(current(h).contains(id), "\(id)")
    }
    // Back is enabled by now, and a click on it undoes the last move that changed anything.
    let layout = MenuBarLayout(h.controller.menuBarModel())
    #expect(layout.click(atX: 11, secondary: false) == .run(.back))
    #expect(h.controller.perform(.back).ok)
    #expect(current(h) == [.view(1)])
  }

  // MARK: Keeping the item up to date

  @Test func oneCommandIsOneUpdate() {
    let (h, a, _, _) = makeHarness()
    var updates: [MenuBarModel] = []
    let watcher = MenuBarWatcher(controller: h.controller) { updates.append($0) }
    #expect(watcher.model == h.controller.menuBarModel())

    // A zoom lays the display out, moves the camera and changes the focus: three changes, one update.
    h.run("zoom \(a.rawValue)")
    #expect(updates.isEmpty, "not from inside the command")
    h.scheduler.advance(by: 0)
    #expect(updates.count == 1)
    #expect(updates.last == h.controller.menuBarModel())
    #expect(updates.last?.button(.back)?.isEnabled == true)
    #expect(watcher.model == updates.last)

    // Several commands before the run loop turns are one update too.
    h.run("save-view 1")
    h.run("show-all")
    h.run("desktop")
    h.scheduler.advance(by: 0)
    #expect(updates.count == 2)
    #expect(updates.last?.buttons.filter(\.isCurrent).map(\.id) == [.desktop])
    #expect(updates.last?.button(.view(1)) != nil)
  }

  @Test func changesThatDoNotShowAreNotReported() {
    let (h, a, b, c) = makeHarness()
    var updates = 0
    let watcher = MenuBarWatcher(controller: h.controller) { _ in updates += 1 }
    h.run("resize \(a.rawValue) right 40")
    h.system.userFocus(b)
    h.system.userMove(c, to: CGRect(x: 600, y: 300, width: 300, height: 300))
    h.run("show-all")
    h.scheduler.advance(by: 0)
    #expect(updates == 0)
    _ = watcher
  }

  @Test func startingStoppingAndSettingsAreReported() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    var updates: [MenuBarModel] = []
    let watcher = MenuBarWatcher(controller: h.controller) { updates.append($0) }
    #expect(watcher.model.buttons.isEmpty)
    h.start()
    h.scheduler.advance(by: 0)
    #expect(updates.isEmpty, "the icon stays the icon until something is docked")
    h.run("dock \(a.rawValue) left")
    h.scheduler.advance(by: 0)
    #expect(updates.last?.buttons.count == 5)

    var settings = Settings()
    settings.historyButtons = false
    h.controller.apply(settings: settings)
    h.scheduler.advance(by: 0)
    #expect(updates.last?.buttons.count == 3)

    h.controller.shutdown()
    h.scheduler.advance(by: 0)
    #expect(updates.last == MenuBarModel())
    #expect(updates.count == 3)
  }

  @Test func thePointerOnAnotherDisplayShowsAtTheNextChange() {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
    h.start()
    h.system.cursor = CGPoint(x: 700, y: 400)
    h.run("dock \(a.rawValue) left")
    h.run("save-view 1")
    var updates: [MenuBarModel] = []
    let watcher = MenuBarWatcher(controller: h.controller) { updates.append($0) }
    #expect(watcher.model.display == h.display)

    // Nothing reports the pointer moving, and Arbor does not poll for it.
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.scheduler.advance(by: 5)
    #expect(updates.isEmpty)
    // Clicking a window there is a change.
    h.system.userFocus(b)
    h.scheduler.advance(by: 0)
    #expect(updates.count == 1)
    #expect(updates.last == MenuBarModel(), "nothing is docked on that display")

    // So is a click on the item itself, which asks for an update whatever it hit.
    h.system.cursor = CGPoint(x: 700, y: 10)
    watcher.update()
    #expect(updates.count == 2)
    #expect(updates.last?.display == h.display)
  }

  // MARK: Commands

  @Test func theMenuBarCommandListsTheButtonsAndWhereTheyAre() {
    let (h, a, _, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    h.run("save-view 3")
    let result = h.run("menu-bar")
    #expect(result.ok)
    #expect(result.message == "6 buttons for display main, 144 points wide")
    #expect(
      result.text == """
        back       0 22 - Back (⌃⌥[)
        forward    22 22 disabled Forward (⌃⌥])
        desktop    48 22 - Show the Desktop (⌃⌥D)
        everything 70 22 - Show Everything (⌃⌥Space)
        view-3     96 22 current View 3: Safari (⌃⌥3)
        menu       122 22 - Menu (a right click anywhere opens it too)
        """)
  }

  @Test func theMenuBarCommandSaysWhyThereIsOnlyAnIcon() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    let waiting = h.run("menu-bar")
    #expect(waiting.ok && waiting.text == nil)
    #expect(waiting.message.contains("single icon") && waiting.message.contains("Accessibility"))

    h.controller.accessibilityGranted = true
    var settings = Settings()
    settings.menuBarControls = false
    h.controller.apply(settings: settings)
    h.start()
    #expect(h.run("menu-bar").message.contains("menuBarControls is false"))
  }

  @Test func stateAgreesWithTheHistoryButtons() {
    let (h, a, b, _) = makeHarness()
    h.run("zoom \(a.rawValue)")
    #expect(h.run("state").state?.displays[0].canGoBack == true)
    h.system.close(a)
    h.system.close(b)
    #expect(h.run("state").state?.displays[0].canGoBack == false)
    #expect(h.run("state").state?.displays[0].canGoForward == false)
  }
}
