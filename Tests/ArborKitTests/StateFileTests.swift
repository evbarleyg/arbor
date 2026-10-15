import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// state.json as Arbor may find it: written by a newer version, cut short, edited by hand, or
/// damaged in a way that is still valid JSON. Arbor must start whatever it holds.
@Suite @MainActor struct StateFileTests {
  /// Safari docked left, Notes right, Mail floating; as the JSON Arbor saves.
  func savedJSON() throws -> (json: [String: Any], windows: [WindowSnapshot]) {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Notes")
    h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.run("save-view 1")
    h.run("show-all")
    h.controller.saveNow()
    let data = try JSONEncoder().encode(h.store.saved!)
    let json = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    return (json, h.system.allWindows())
  }

  /// Changes the saved workspace of the main display.
  func edit(_ json: [String: Any], _ change: (inout [String: Any]) -> Void) -> [String: Any] {
    var json = json
    var workspaces = json["workspaces"] as! [String: Any]
    var workspace = workspaces["main"] as! [String: Any]
    change(&workspace)
    workspaces["main"] = workspace
    json["workspaces"] = workspaces
    return json
  }

  /// Changes one node of the saved tree. The tree is n2 split [n1 Safari, n0 Desktop, n3 Notes].
  func editNode(_ json: [String: Any], _ node: String, _ change: (inout [String: Any]) -> Void) -> [String: Any] {
    edit(json) { workspace in
      var tree = workspace["tree"] as! [String: Any]
      var nodes = tree["nodes"] as! [String: Any]
      var value = nodes[node] as! [String: Any]
      change(&value)
      nodes[node] = value
      tree["nodes"] = nodes
      workspace["tree"] = tree
    }
  }

  /// Reads `json` as the store does, with what the decoder repaired or left out.
  func read(_ json: [String: Any]) throws -> (state: PersistedState, notes: [String])? {
    let notes = DecodingNotes()
    guard case .loaded(let state) = PersistedState.read(try JSONSerialization.data(withJSONObject: json), notes: notes) else {
      Issue.record("did not load")
      return nil
    }
    return (state, notes.notes)
  }

  /// Starts Arbor on `json` with the same windows open, runs every kind of command, and quits.
  @discardableResult
  func startAndExercise(_ json: [String: Any], windows: [WindowSnapshot]) throws -> Harness {
    let data = try JSONSerialization.data(withJSONObject: json)
    var saved: PersistedState?
    if case .loaded(let state) = PersistedState.read(data) { saved = state }
    let h = Harness(saved: saved)
    for window in windows {
      h.system.open(app: window.appName, bundleID: window.bundleID, title: window.title, frame: window.frame)
    }
    h.start()
    for command in [
      "state", "ascii", "show-all", "in", "out", "neighbor left", "back", "forward", "view 1", "desktop",
      "zoom 101", "dock 103 left", "dock 101 right", "float 102", "resize 101 left 40", "arrange", "float-all",
    ] { h.run(command) }
    h.scheduler.advance(by: Controller.pendingSlotLifetime + 1)
    for workspace in h.controller.workspaces.values {
      #expect(workspace.tree.invariantViolations().isEmpty)
      #expect(workspace.tree.contains(workspace.camera))
    }
    h.controller.shutdown()
    for window in windows { #expect(h.system.isVisible(window.id), "\(window.id)") }
    return h
  }

  // MARK: Versions and damage the decoder notices

  @Test func aFileFromThisVersionLoads() throws {
    let (json, _) = try savedJSON()
    guard case .loaded(let state) = PersistedState.read(try JSONSerialization.data(withJSONObject: json)) else {
      Issue.record("did not load")
      return
    }
    #expect(state.workspaces[DisplayID("main")]?.tree.allWindows.count == 2)
    #expect(state.version == PersistedState.currentVersion)
  }

  @Test func aFileFromANewerVersionIsNotLoaded() throws {
    var (json, _) = try savedJSON()
    json["version"] = PersistedState.currentVersion + 1
    json["somethingNew"] = ["a": 1]
    #expect(PersistedState.read(try JSONSerialization.data(withJSONObject: json)) == .newer(version: PersistedState.currentVersion + 1))
  }

  @Test func aNewerFileThatThisVersionCouldNotDecodeIsStillReportedAsNewer() throws {
    let data = Data(#"{"version": 7, "spaces": []}"#.utf8)
    #expect(PersistedState.read(data) == .newer(version: 7))
  }

  @Test func truncatedEmptyAndForeignFilesAreUnreadable() throws {
    let (json, _) = try savedJSON()
    let whole = try JSONSerialization.data(withJSONObject: json)
    for data in [whole.prefix(whole.count / 2), Data(), Data("null".utf8), Data("[1,2]".utf8), Data([0xFF, 0xFE, 0x00])] {
      guard case .unreadable = PersistedState.read(Data(data)) else {
        Issue.record("\(data.count) bytes were accepted")
        continue
      }
    }
  }

  // MARK: Damage only Arbor can notice
  //
  // Trees and workspaces repair themselves as they are decoded, or are left out (`TreeDecodingTests`,
  // `WorkspaceDecodingTests` and `DamagedStateTests` say which). What matters here is that Arbor starts, works
  // and quits with every window in view, whatever the file held.

  @Test func anUntouchedFileNeedsNoRepair() throws {
    let (json, windows) = try savedJSON()
    guard let (state, notes) = try read(json) else { return }
    #expect(notes.isEmpty)
    #expect(try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? NSDictionary == json as NSDictionary)
    let h = try startAndExercise(json, windows: windows)
    #expect(h.controller.isRunning == false)
  }

  @Test func aTreeWhoseChildrenFormACycleIsSurvived() throws {
    let (json, windows) = try savedJSON()
    // n1 becomes a split that contains its own parent.
    let damaged = editNode(json, "1") { $0["kind"] = ["split": ["axis": "vertical", "children": [2, 3]]] }
    try startAndExercise(damaged, windows: windows)
  }

  @Test func aTreeWhoseParentsFormACycleIsSurvived() throws {
    let (json, windows) = try savedJSON()
    let damaged = editNode(json, "2") { $0["parent"] = 1 }
    try startAndExercise(damaged, windows: windows)
  }

  @Test func aTreeThatListsAMissingChildIsSurvived() throws {
    let (json, windows) = try savedJSON()
    let damaged = editNode(json, "2") { $0["kind"] = ["split": ["axis": "horizontal", "children": [1, 0, 3, 99]]] }
    try startAndExercise(damaged, windows: windows)
  }

  @Test func aTreeWithoutItsRootOrDesktopIsSurvived() throws {
    let (json, windows) = try savedJSON()
    for key in ["root", "desktop"] {
      let damaged = edit(json) { workspace in
        var tree = workspace["tree"] as! [String: Any]
        tree[key] = 42
        workspace["tree"] = tree
      }
      try startAndExercise(damaged, windows: windows)
    }
  }

  @Test func aTreeThatWouldReuseNodeNumbersIsSurvived() throws {
    let (json, windows) = try savedJSON()
    let damaged = edit(json) { workspace in
      var tree = workspace["tree"] as! [String: Any]
      tree["nextRawID"] = 1
      workspace["tree"] = tree
    }
    try startAndExercise(damaged, windows: windows)
  }

  @Test func weightsThatCannotBeLaidOutAreSurvived() throws {
    let (json, windows) = try savedJSON()
    for weight in [0, -1, 1e308] {
      try startAndExercise(editNode(json, "1") { $0["weight"] = weight }, windows: windows)
    }
  }

  @Test func anEmptyStackOrAWindowListedTwiceIsSurvived() throws {
    let (json, windows) = try savedJSON()
    try startAndExercise(editNode(json, "1") { $0["kind"] = ["stack": ["windows": [], "active": 0]] }, windows: windows)
    try startAndExercise(editNode(json, "1") { $0["kind"] = ["stack": ["windows": [102], "active": 0]] }, windows: windows)
    try startAndExercise(editNode(json, "1") { $0["kind"] = ["stack": ["windows": [101], "active": 9]] }, windows: windows)
  }

  @Test func aCameraHistoryOrSavedViewOnAMissingNodeIsRepairedAndTheTreeKept() throws {
    let (json, windows) = try savedJSON()
    let damaged = edit(json) { workspace in
      workspace["camera"] = 77
      workspace["back"] = [77, 1, 78]
      workspace["forward"] = [79]
      workspace["savedViews"] = ["1": 80, "2": 3, "banana": 1]
    }
    guard let (state, notes) = try read(damaged) else { return }
    #expect(!notes.isEmpty)
    let workspace = try #require(state.workspaces[DisplayID("main")])
    #expect(workspace.tree.allWindows.count == 2, "the arrangement is kept")
    #expect(workspace.camera == workspace.tree.root)
    #expect(workspace.back == [NodeID(1)])
    #expect(workspace.forward.isEmpty)
    #expect(workspace.savedViews == ["2": NodeID(3)])
    try startAndExercise(damaged, windows: windows)
  }

  @Test func floatingFramesThatMakeNoSenseAreDropped() throws {
    let (json, windows) = try savedJSON()
    let damaged = edit(json) { workspace in
      workspace["floating"] = [
        "103": [[1e300, 0], [600, 400]], "101": [[0, 0], [600, 400]], "104": [[0, 0], [-5, 400]],
      ]
    }
    guard let (state, notes) = try read(damaged) else { return }
    #expect(!notes.isEmpty)
    #expect(state.workspaces[DisplayID("main")]?.floating.isEmpty == true, "101 is docked, the others are nonsense")
    try startAndExercise(damaged, windows: windows)
  }

  @Test func aDamagedRememberedDisplayIsDiscardedWithoutTouchingTheOthers() throws {
    var (json, windows) = try savedJSON()
    let main = (json["workspaces"] as! [String: Any])["main"] as! [String: Any]
    var broken = main
    broken["tree"] = ["nodes": [:] as [String: Any], "root": 0, "desktop": 0, "nextRawID": 1]
    json["dormant"] = ["gone": ["workspace": broken, "since": 0]]
    guard let (state, notes) = try read(json) else { return }
    #expect(notes.count == 1)
    #expect(state.dormant.isEmpty)
    #expect(state.workspaces[DisplayID("main")]?.tree.allWindows.count == 2)
    try startAndExercise(json, windows: windows)
  }

  @Test func aRememberedDisplayWithAnImpossibleDateIsSurvivable() throws {
    var (json, windows) = try savedJSON()
    let main = (json["workspaces"] as! [String: Any])["main"] as! [String: Any]
    for since in [-1e300, 1e300] {
      json["dormant"] = ["gone": ["workspace": main, "since": since]]
      try startAndExercise(json, windows: windows)
    }
  }

  // MARK: The file store

  func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-tests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  @Test func theStoreSetsAsideAFileItCannotUseInsteadOfOverwritingIt() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("state.json")
    let newer = Data(#"{"version": 9, "precious": true}"#.utf8)
    try newer.write(to: url)
    let store = FileStateStore(url: url)
    #expect(store.load() == nil)
    store.save(PersistedState(workspaces: [:], hints: [:]))
    #expect(try Data(contentsOf: folder.appendingPathComponent("state.unreadable.json")) == newer)
    #expect(store.load() != nil)
  }

  // MARK: Saying so

  @Test func theStoreSaysWhatBecameOfAFileItCouldNotUse() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("state.json")
    let store = FileStateStore(url: url)
    #expect(store.load() == nil)
    #expect(store.loadProblem == nil, "no file is a first launch, not a problem")

    try Data(#"{"version": 9, "precious": true}"#.utf8).write(to: url)
    #expect(store.load() == nil)
    #expect(store.loadProblem == .newer)

    try Data("{".utf8).write(to: url)
    #expect(store.load() == nil)
    #expect(store.loadProblem == .unreadable)

    store.save(PersistedState(workspaces: [:], hints: [:]))
    #expect(store.load() != nil)
    #expect(store.loadProblem == nil, "it is about the last load")
  }

  /// What becomes of the file is in RepairedStateIsKeptTests.
  @Test func aFileThatLoadsWithRepairsIsAProblemOfItsOwnKind() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("state.json")
    let (json, _) = try savedJSON()
    try JSONSerialization.data(withJSONObject: editNode(json, "2") { $0["weight"] = -1 }).write(to: url)
    let store = FileStateStore(url: url)
    #expect(store.load() != nil)
    #expect(store.loadProblem == .repaired)
    #expect(store.keptCopy == "state.before-repair.json")

    // A link that is rebuilt from the child lists shows nowhere: tidied, and no problem to tell anybody of.
    try JSONSerialization.data(withJSONObject: editNode(json, "2") { $0["parent"] = 1 }).write(to: url)
    #expect(store.load() != nil)
    #expect(store.loadProblem == nil && store.repairs.isEmpty)
  }

  @Test(arguments: [
    (StateLoadProblem.unreadable, "could not be read and was set aside"),
    (.newer, "is from a newer Arbor and was set aside"),
    (.repaired, "needed 0 repairs when it was read"),
    (.setAsideEarlier, "was set aside earlier"),
  ]) func statusAndTheNoticesSayWhatHappenedToTheSavedArrangement(problem: StateLoadProblem, words: String) {
    let h = Harness()
    h.system.open(app: "Safari")
    h.store.loadProblem = problem
    h.store.keptCopy = "the-copy.json"
    h.start()
    #expect(h.run("status").message.contains(words), "\(h.run("status").message)")
    #expect(h.run("status").message.contains("the-copy.json"))
    #expect(h.controller.notices.count == 1)
    #expect(h.controller.notices[0].contains(words))
    #expect(h.controller.notices[0].first?.isUppercase == true, "a line of the menu, read alone")
    // It is news about this start. A pause and resume start from memory and have nothing to add or take away.
    h.run("pause")
    h.run("resume")
    #expect(h.controller.notices.count == 1)
  }

  // What an adversarial review of the first version found.

  @Test func nothingIsSaidToBeSetAsideThatIsNot() {
    // The move failed (a folder that cannot be written): the file is still there, and the next save goes over it.
    for problem in [StateLoadProblem.unreadable, .newer] {
      let h = Harness()
      h.store.loadProblem = problem
      h.start()
      #expect(!h.controller.notices[0].contains("set aside and"), "\(h.controller.notices)")
      #expect(h.controller.notices[0].hasSuffix("it could not be set aside, and the next save replaces it"), "\(h.controller.notices)")
    }
  }

  @Test func whenNoCopyOfARepairedFileCouldBeKeptThatIsSaid() {
    let h = Harness()
    h.store.repairs = ["workspaces: skipped `side`"]
    h.start()
    #expect(h.controller.notices[0].contains("1 repair"))
    #expect(h.controller.notices[0].contains("no copy of it as it was could be kept"), "\(h.controller.notices)")
  }

  @Test func aRepairIsNotCalledDamage() {
    // A view on a space that is gone, a field a later Arbor wrote: noted, repaired, and nothing a person would miss.
    let h = Harness()
    h.store.repairs = ["workspaces.main: the camera was on n9, which does not exist"]
    h.store.keptCopy = "state.before-repair.json"
    h.start()
    #expect(!h.controller.notices[0].contains("damaged"))
    #expect(
      h.controller.notices[0]
        == "The saved arrangement needed 1 repair when it was read (arbor.log says which; state.before-repair.json has it as it was)")
  }

  @Test func aPausedArborSaysItToo() {
    let h = Harness()
    h.store.loadProblem = .unreadable
    h.store.keptCopy = "state.unreadable.json"
    h.start()
    h.run("pause")
    #expect(h.run("status").message.hasPrefix("paused: "))
    #expect(h.run("status").message.contains("could not be read and was set aside (state.unreadable.json)"))
  }

  @Test func theMenuSaysItInItsLastPlaceAmongTheStates() {
    let (saved, _, _, _) = LifecycleTests().savedPair()
    let h = Harness(saved: saved)
    h.store.loadProblem = .unreadable
    h.store.keptCopy = "state.unreadable.json"
    h.start()
    // The words before the brackets; which file has the rest is in the tooltip, and in `status`.
    let news = "The saved arrangement could not be read and was set aside"
    #expect(
      h.controller.menuModel().sections.first?.items.map(\.title)
        == ["2 places kept for windows that are not open yet", news])
    #expect(h.controller.menuModel().sections.first?.items.allSatisfy { $0.command == nil } == true, "nothing to choose")
    #expect(h.controller.menuModel().sections.dropFirst().first?.items.first?.title == "Arrange Windows")
    // Two states at most, and whatever has a command that ends it comes first.
    h.run("pause")
    #expect(
      h.controller.menuModel().sections.first?.items.map(\.title)
        == ["Arbor is paused · Resume", news])
  }

  @Test func afterARescueTheNextLaunchSaysWhereTheArrangementWent() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("state.json")
    try Data(#"{"version": 1, "workspaces": {}, "hints": {}}"#.utf8).write(to: url)
    // `ARBOR_RESCUE=1`, as `ArborApp.rescueAndQuit` does it: set aside unread, in case it was the cause; start, which
    // adopts every window; quit, which brings them into view, and saves.
    let rescue = FileStateStore(url: url)
    rescue.setAside()
    let controller = Controller(
      system: FakeWindowSystem(), overlays: FakeOverlays(), store: rescue, scheduler: ManualScheduler(), settings: Settings(),
      filter: WindowFilter(ownPID: 1))
    controller.start()
    controller.shutdown()
    #expect(FileManager.default.fileExists(atPath: url.path), "the rescue's own save, of nothing worth keeping")
    rescue.discard()

    let store = FileStateStore(url: url)
    #expect(store.load() == nil)
    #expect(store.loadProblem == .setAsideEarlier)
    #expect(store.keptCopy == "state.unreadable.json")
    // Once: from the first save on there is a file again.
    store.save(PersistedState(workspaces: [:], hints: [:]))
    #expect(store.load() != nil)
    #expect(store.loadProblem == nil)
  }

  @Test(arguments: [StateLoadProblem.unreadable, .newer, .setAsideEarlier])
  func whoeverHadAStateFileHasBeenWelcomedBefore(problem: StateLoadProblem) {
    // "Welcomed" is in the file that could not be used. A welcome window after a crash loop would add insult to injury.
    let h = Harness()
    h.store.loadProblem = problem
    h.start()
    #expect(h.controller.pageToWelcomeOn() == nil)
    h.controller.saveNow()
    #expect(h.store.saved?.welcomed == true)

    let first = Harness()
    first.start()
    #expect(first.controller.pageToWelcomeOn() != nil, "a first launch is still a first launch")
  }

  @Test func withNothingWrongThereIsNothingToSay() {
    let h = Harness()
    h.system.open(app: "Safari")
    h.start()
    #expect(h.controller.notices.isEmpty)
    #expect(h.run("status").message.hasSuffix("out of view"))
  }

  @Test func aStartThatGoesWellTakesTheNewsOfTheLastOneAway() {
    let h = Harness()
    h.store.loadProblem = .unreadable
    h.start()
    #expect(!h.controller.notices.isEmpty)
    h.controller.shutdown()
    h.store.loadProblem = nil
    h.store.keptCopy = nil
    h.start()
    #expect(h.controller.notices.isEmpty)
  }

  @Test func theNewsIsNotLostWhenTheWatchdogDidTheStarting() throws {
    // That start looks into the file for a pause first. A file that was set aside is gone at a second look.
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("state.json")
    try Data("{".utf8).write(to: url)
    let system = FakeWindowSystem()
    let controller = Controller(
      system: system, overlays: FakeOverlays(), store: FileStateStore(url: url), scheduler: ManualScheduler(),
      settings: Settings(), filter: WindowFilter(ownPID: 1))
    controller.restartedAfterAccident = true
    controller.start()
    #expect(controller.isRunning)
    #expect(controller.notices.count == 1)
  }

  @Test func aKeptPlaceIsANoticeToo() {
    let (saved, _, _, _) = LifecycleTests().savedPair()
    let h = Harness(saved: saved)
    h.store.loadProblem = .repaired
    h.start()
    #expect(h.controller.notices.count == 2)
    #expect(h.controller.notices[0] == "2 places kept for windows that are not open yet")
  }

  @Test func theStoreWritesFilesOnlyTheirOwnerCanRead() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let url = folder.appendingPathComponent("state.json")
    let store = FileStateStore(url: url)
    store.save(PersistedState(workspaces: [:], hints: [WindowID(1): WindowHint(bundleID: nil, title: "Secret")]))
    store.flush()
    let mode = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.posixPermissions] as? Int)
    #expect(mode & 0o077 == 0, "mode \(String(mode, radix: 8))")
  }

  @Test func aMissingFileIsAFreshStartAndNothingIsSetAside() throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    #expect(FileStateStore(url: folder.appendingPathComponent("state.json")).load() == nil)
    #expect(try FileManager.default.contentsOfDirectory(atPath: folder.path).isEmpty)
  }
}
