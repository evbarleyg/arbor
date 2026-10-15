import ArborCore
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let main = DisplayID("main")
private let side = DisplayID("side")
private let spot = CGRect(x: 40, y: 60, width: 300, height: 200)

/// main: [a | Desktop | b] with c floating; side: empty.
private func workspaces() -> [DisplayID: Workspace] {
  var workspace = Workspace()
  workspace.dock(a, at: .cameraEdge(.left))
  workspace.dock(b, at: .cameraEdge(.right))
  workspace.floating[c] = CGRect(x: 500, y: 300, width: 400, height: 300)
  return [main: workspace, side: Workspace()]
}

/// When a dragged window docks (`dragDocks`).
@Suite struct DragDocksTests {
  @Test func aPlainDragDocksOnlyWhereThatIsSet() {
    let keys: [(KeyChord.Modifiers, isTheKey: Bool)] = [
      ([], false), (.command, true), ([.command, .shift], true), ([.command, .option], true), ([.command, .control], true),
      ([.control, .option, .command], false), ([.control, .option, .shift, .command], false),
      (.option, false), (.shift, false), (.control, false), ([.control, .option], false),
    ]
    for (held, isTheKey) in keys {
      #expect(DragDocks.isKeyHeld(held) == isTheKey, "\(held)")
      #expect(DragDocks.held.docks(holding: held) == isTheKey, "\(held)")
      #expect(DragDocks.always.docks(holding: held) == !isTheKey, "\(held)")
      #expect(!DragDocks.never.docks(holding: held), "\(held)")
    }
  }

  @Test func arborShipsWithTheKeyAndTakesNonsenseForThat() {
    #expect(Settings().dragDocks == "held")
    #expect(DragDocks(setting: Settings().dragDocks) == .held)
    for setting in DragDocks.allCases { #expect(DragDocks(setting: setting.rawValue) == setting) }
    for nonsense in ["", "Held", "sometimes", "true"] { #expect(DragDocks(setting: nonsense) == .held, "\(nonsense)") }
  }

  /// A file written by a build that did not know the key: it loads, and the drag is as Arbor ships now.
  @Test func aSettingsFileWithoutTheKeyLoads() throws {
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 12, "previewDrags": false}"#.utf8))
    #expect(old.gap == 12)
    #expect(old.dragDocks == "held")
    let chosen = try JSONDecoder().decode(Settings.self, from: Data(#"{"dragDocks": "always"}"#.utf8))
    #expect(chosen.dragDocks == "always")
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(chosen)) == chosen)
  }
}

/// F09: which targets have to be held, and for how long.
@Suite struct DropDwellTests {
  @Test func onlyWindowsAndTilesHaveToBeHeld() {
    let node = NodeID(3)
    #expect(DropTarget.beside(node, .left).needsDwell)
    #expect(DropTarget.stack(node).needsDwell)
    #expect(!DropTarget.cameraEdge(.top).needsDwell)
    #expect(!DropTarget.float.needsDwell)
    #expect(!DropTarget.none.needsDwell)

    let options = DropOptions(dwell: 0.4)
    #expect(options.dwell(for: .beside(node, .left)) == 0.4)
    #expect(options.dwell(for: .cameraEdge(.left)) == 0)
    #expect(DropOptions(dwell: -1).dwell(for: .stack(node)) == 0)
    #expect(DropOptions().dwell == 0.15)
  }

  @Test func theDwellSettingStaysBetweenNothingAndTwoSeconds() {
    var settings = Settings()
    #expect(settings.dropOptions.dwell == 0.15)
    let cases: [(Double, Double)] = [(0.4, 0.4), (0, 0), (-3, 0), (2, 2), (60, 2), (.infinity, 0.15), (.nan, 0.15)]
    for (value, expected) in cases {
      settings.dropDwell = value
      #expect(settings.dropOptions.dwell == expected, "\(value)")
    }
  }

  @Test func theDragSettingsLoadAndOldFilesGetTheirDefaults() throws {
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 8}"#.utf8))
    #expect(old.dropDwell == 0.15)
    #expect(!old.reflowWhileDragging)
    #expect(old.keepPushed)
    #expect(old.previewDrags)

    let json = #"{"dropDwell": 0.5, "reflowWhileDragging": true, "keepPushed": false, "previewDrags": false}"#
    let edited = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    #expect(edited.dropDwell == 0.5)
    #expect(edited.reflowWhileDragging)
    #expect(!edited.keepPushed)
    #expect(!edited.previewDrags)
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(edited)) == edited)
  }
}

/// F09: `Drop.apply`, which both the real drop and live reflow's trial layouts go through.
@Suite struct DropApplyTests {
  @Test func floatingADockedWindowUndocksItWhereItIs() {
    var all = workspaces()
    let changed = Drop(window: a, target: .float, display: main, frame: spot).apply(to: &all)
    #expect(changed == [main])
    #expect(all[main]!.tree.allWindows == [b])
    #expect(all[main]!.floating[a] == spot)
    #expect(all[main]!.tree.invariantViolations().isEmpty)
  }

  @Test func aFloatingWindowThatStillFloatsChangesNoLayout() {
    var all = workspaces()
    let tree = all[main]!.tree
    #expect(Drop(window: c, target: .float, display: main, frame: spot).apply(to: &all) == [])
    #expect(all[main]!.floating[c] == spot)
    #expect(all[main]!.tree == tree)

    #expect(Drop(window: c, target: .float, display: side, frame: spot).apply(to: &all) == [])
    #expect(!all[main]!.contains(c))
    #expect(all[side]!.floating[c] == spot)
  }

  @Test func floatingOnAnotherDisplayLaysOutOnlyTheOneItWasDockedOn() {
    var all = workspaces()
    #expect(Drop(window: a, target: .float, display: side, frame: spot).apply(to: &all) == [main])
    #expect(!all[main]!.contains(a))
    #expect(all[side]!.floating[a] == spot)
  }

  @Test func dockingMovesTheWindowFromWhereverItWas() {
    var all = workspaces()
    let leafB = all[main]!.tree.leaf(containing: b)!
    #expect(Drop(window: c, target: .beside(leafB, .bottom), display: main, frame: spot).apply(to: &all) == [main])
    #expect(all[main]!.isDocked(c) && !all[main]!.isFloating(c))

    #expect(Drop(window: a, target: .cameraEdge(.left), display: side, frame: spot).apply(to: &all) == [main, side])
    #expect(!all[main]!.contains(a))
    #expect(all[side]!.tree.allWindows == [a])
    for workspace in all.values { #expect(workspace.tree.invariantViolations().isEmpty) }
  }

  @Test func goingBackToItsOwnSlotChangesNothingButIsLaidOut() {
    var all = workspaces()
    #expect(Drop(window: a, target: .none, display: main, frame: spot).apply(to: &all) == [main])
    #expect(all == workspaces())
  }

  @Test func aDisplayThatIsGoneChangesNothing() {
    var all = workspaces()
    for target in [DropTarget.float, .none, .cameraEdge(.left)] {
      #expect(Drop(window: a, target: target, display: DisplayID("gone"), frame: spot).apply(to: &all) == [])
    }
    #expect(all == workspaces())
  }

  /// Live reflow matches the pointer against the tree without the dragged window, then drops on
  /// the tree that still has it. The nodes that survive the removal keep their ids, so both agree.
  @Test func aTargetFoundWithoutTheWindowMeansTheSameWithIt() {
    var start = workspaces()[main]!
    start.dock(c, at: .beside(start.tree.leaf(containing: a)!, .bottom))
    var lifted = start
    lifted.forget(a)
    for node in lifted.tree.preorder() {
      for target in [DropTarget.beside(node, .left), .beside(node, .top), .stack(node), .cameraEdge(.right)] {
        var real = start
        var trial = lifted
        real.dock(a, at: target)
        trial.dock(a, at: target)
        #expect(real == trial, "\(target)")
      }
    }
  }
}
