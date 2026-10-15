import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// What Arbor takes of a Mac by itself, as it ships, held to a budget (collab/IDEAS.md, I25 c, from I22 and I23). The parity score
/// rises with every feature and never falls for clutter: that is how Arbor came to bind some fifty keys. These numbers only
/// fall.
///
/// - **Keys:** at most ten shortcuts, each ⌃⌥ and one key. A global shortcut is taken from every app on the Mac.
/// - **The menu bar:** one thing, and its width never changes.
///
/// Both halves hold: the keys since the nine (`KeyBindings.core`), the menu bar since `menuBarControls` ships false. Each was a known issue that
/// said its numbers until the change that brought it within its budget.
@MainActor @Suite struct LessByDefaultTests {
  static let mostKeys = 10
  static let mostInTheMenuBar = 1

  /// The shortcuts of somebody who has changed nothing.
  var keys: [KeyBinding] { KeyBindings.effective(settings: Settings()).bindings }
  var keysWithMoreThanControlOption: [KeyBinding] { keys.filter { $0.modifiers != [.control, .option] } }

  /// What the menu bar item shows in the course of an ordinary hour, as Arbor ships: nothing docked, two windows docked, one framed,
  /// everything again, views saved, a pause.
  func menuBarThroughAnHour() -> [MenuBarModel] {
    let h = Harness(settings: Settings())
    let windows = ["Safari", "Mail", "Notes"].map { h.system.open(app: $0) }
    h.start()
    var seen = [h.controller.menuBarModel()]
    var lines = ["dock \(windows[0].rawValue) left", "dock \(windows[1].rawValue) right", "zoom \(windows[0].rawValue)", "show-all"]
    lines += (1...9).map { "save-view \($0)" } + ["pause", "resume", "float-all"]
    for line in lines {
      #expect(h.run(line).ok, "\(line)")
      seen.append(h.controller.menuBarModel())
    }
    return seen
  }

  /// An item without buttons is Arbor's one icon.
  func things(in model: MenuBarModel) -> Int { max(model.buttons.count, 1) }
  func width(of model: MenuBarModel) -> CGFloat { max(MenuBarLayout(model).size.width, MenuBarLayout.pitch) }

  /// One line for whoever sums up a day's work, before and after.
  @Test func theNumbers() {
    let hour = menuBarThroughAnHour()
    print(
      "BUDGET default bindings: \(keys.count) of \(Self.mostKeys); with a third modifier: \(keysWithMoreThanControlOption.count); "
        + "menu bar items: up to \(hour.map(things).max() ?? 0) of \(Self.mostInTheMenuBar), in \(Set(hour.map(width)).count) widths")
  }

  @Test func atMostTenShortcutsEachControlOptionAndOneKey() {
    #expect(keys.count <= Self.mostKeys, "default bindings: \(keys.count) of \(Self.mostKeys)")
    let labels = keysWithMoreThanControlOption.map(\.label).joined(separator: " ")
    #expect(keysWithMoreThanControlOption.isEmpty, "with a third modifier: \(keysWithMoreThanControlOption.count): \(labels)")
  }

  @Test func oneThingInTheMenuBarAndItsWidthNeverChanges() {
    let hour = menuBarThroughAnHour()
    let most = hour.map(things).max() ?? 0
    #expect(most <= Self.mostInTheMenuBar, "menu bar items: up to \(most) of \(Self.mostInTheMenuBar)")
    let widths = Set(hour.map(width)).sorted()
    #expect(widths.count == 1, "the item's widths in points: \(widths)")
  }
}
