import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// `state.json` as a person, another version or a crash might leave it. Arbor reads it at every launch,
/// so a file it cannot cope with would stop it from ever starting again.
@MainActor @Suite struct DamagedStateTests {
  /// Two docked windows and a floating one on the standard display, as saved by a real session.
  private func savedSession() throws -> (object: [String: Any], display: String) {
    let h = Harness()
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B")
    h.system.open(app: "C")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.controller.saveNow()
    let data = try JSONEncoder().encode(try #require(h.store.saved))
    return (try #require(JSONSerialization.jsonObject(with: data) as? [String: Any]), h.display.rawValue)
  }

  /// Writes `object` where a `FileStateStore` reads it, and reads it.
  private func load(_ object: [String: Any]) throws -> PersistedState? {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-state-\(UUID().uuidString).json")
    defer { try? FileManager.default.removeItem(at: url) }
    try JSONSerialization.data(withJSONObject: object).write(to: url)
    return FileStateStore(url: url).load()
  }

  /// Starts Arbor on the same three windows with `state`, and checks it is in working order.
  private func launch(with state: PersistedState?) -> Harness {
    let h = Harness(saved: state)
    for app in ["A", "B", "C"] { h.system.open(app: app) }
    h.start()
    #expect(h.workspace.tree.invariantViolations() == [])
    #expect(Set(h.workspace.allWindows) == Set(h.system.allWindows().map(\.id)), "every window is docked or floating")
    #expect(h.run("arrange").ok)
    #expect(h.run("state").ok)
    #expect(h.run("float-all").ok)
    return h
  }

  @Test func aSavedSessionComesBack() throws {
    let (object, _) = try savedSession()
    let h = Harness(saved: try load(object))
    for app in ["A", "B", "C"] { h.system.open(app: app) }
    h.start()
    #expect(h.workspace.tree.allWindows.count == 2)
    #expect(h.workspace.floating.count == 1)
  }

  @Test func oneDisplayThatCannotBeReadDoesNotCostTheOthers() throws {
    var (object, display) = try savedSession()
    var workspaces = try #require(object["workspaces"] as? [String: Any])
    workspaces["other-display"] = ["tree": "oak"]
    workspaces["third-display"] = 7
    object["workspaces"] = workspaces
    let state = try #require(try load(object))
    #expect(state.workspaces.keys.map(\.rawValue) == [display])
    #expect(launch(with: state).workspace.tree.contains(NodeID(0)))
  }

  @Test func oneHintOrDormantDisplayThatCannotBeReadDoesNotCostTheRest() throws {
    var (object, _) = try savedSession()
    var hints = try #require(object["hints"] as? [String: Any])
    let good = hints.count
    hints["77"] = ["title": 5]
    hints["not a window"] = ["title": "x"]
    object["hints"] = hints
    object["dormant"] = ["gone": ["since": "yesterday"], "also-gone": []]
    let state = try #require(try load(object))
    #expect(state.hints.count == good)
    #expect(state.dormant.isEmpty)
    #expect(state.workspaces.count == 1)
  }

  @Test func aDamagedTreeIsRepairedAndItsWindowsAreAllStillManaged() throws {
    let (object, display) = try savedSession()
    func damaged(_ change: (inout [String: Any], inout [String: Any]) -> Void) throws -> PersistedState? {
      var object = object
      var workspaces = object["workspaces"] as! [String: Any]
      var workspace = workspaces[display] as! [String: Any]
      var tree = workspace["tree"] as! [String: Any]
      change(&workspace, &tree)
      workspace["tree"] = tree
      workspaces[display] = workspace
      object["workspaces"] = workspaces
      return try load(object)
    }
    let root = ((object["workspaces"] as! [String: Any])[display] as! [String: Any])["tree"] as! [String: Any]
    let rootID = root["root"] as! Int
    _ = launch(with: try damaged { _, tree in tree["nextRawID"] = 0 })
    _ = launch(with: try damaged { _, tree in tree["root"] = 999 })
    _ = launch(with: try damaged { _, tree in tree["desktop"] = 999 })
    _ = launch(with: try damaged { workspace, _ in workspace["camera"] = 999 })
    _ = launch(with: try damaged { workspace, _ in workspace["floating"] = ["101": [[0, 0], [1e300, -5]], "102": [[0, 0], [10, 10]]] })
    _ = launch(with: try damaged { _, tree in
      var nodes = tree["nodes"] as! [String: Any]
      nodes[String(rootID)] = ["id": rootID, "weight": 0, "kind": ["split": ["axis": "horizontal", "children": [rootID, 0, 0, 55]]]]
      tree["nodes"] = nodes
    })
    _ = launch(with: try damaged { _, tree in
      var nodes = tree["nodes"] as! [String: Any]
      nodes["0"] = nil
      tree["nodes"] = nodes
    })
  }

  @Test func aFileThatIsNotStateAtAllMeansAFreshStart() throws {
    #expect(try load([:]) == nil)
    #expect(try load(["version": 1]) == nil)
    #expect(try load(["version": 1, "workspaces": "none", "hints": [:] as [String: Any]]) == nil)
    _ = launch(with: nil)
  }
}
