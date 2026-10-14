import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A file that could be read in part counts as read, and Arbor saves soon after starting. So what could not be
/// read, a display's whole arrangement for one, used to be gone for good a moment later, with a line in the log.
@MainActor @Suite struct RepairedStateIsKeptTests {
  /// A folder of its own, with `state.json` as a session with two displays saved it.
  private final class Home {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-home-\(UUID().uuidString)")
    var url: URL { folder.appendingPathComponent("state.json") }
    init() throws { try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true) }
    deinit { try? FileManager.default.removeItem(at: folder) }

    var files: [String] { ((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []).sorted() }
    func bytes(_ name: String) -> Data? { try? Data(contentsOf: folder.appendingPathComponent(name)) }
  }

  private static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

  private func savedSession() throws -> [String: Any] {
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side])
    let a = h.system.open(app: "A")
    let b = h.system.open(app: "B", frame: CGRect(x: 1600, y: 100, width: 500, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) left")
    h.controller.saveNow()
    let data = try JSONEncoder().encode(try #require(h.store.saved))
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  }

  /// The side display's tree without its root: refused, so that display is left out.
  private func withoutTheSideDisplaysRoot(_ object: [String: Any]) throws -> Data {
    var object = object
    var workspaces = try #require(object["workspaces"] as? [String: Any])
    var side = try #require(workspaces["side"] as? [String: Any])
    var tree = try #require(side["tree"] as? [String: Any])
    tree["root"] = 4711
    side["tree"] = tree
    workspaces["side"] = side
    object["workspaces"] = workspaces
    return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
  }

  // MARK: Keys of a later version

  private func loaded(_ result: PersistedState.ReadResult) -> PersistedState? {
    if case .loaded(let state) = result { state } else { nil }
  }

  /// `object` with `value` at `path`.
  private func setting(_ value: Any, at path: [String], in object: [String: Any]) -> [String: Any] {
    var object = object
    if path.count == 1 {
      object[path[0]] = value
    } else {
      object[path[0]] = setting(value, at: Array(path.dropFirst()), in: object[path[0]] as? [String: Any] ?? [:])
    }
    return object
  }

  /// A later Arbor may add keys without raising the format. This one would save without them a moment after starting.
  @Test(arguments: [
    ["later"], ["workspaces", "main", "later"], ["workspaces", "main", "tree", "later"],
    ["workspaces", "main", "tree", "nodes", "0", "later"], ["hints", "101", "later"],
  ]) func aFileWithAKeyThisVersionDoesNotReadIsKeptAsItWas(path: [String]) throws {
    let home = try Home()
    let file = try JSONSerialization.data(
      withJSONObject: setting(["a": 1], at: path, in: try savedSession()), options: [.sortedKeys])
    try file.write(to: home.url)

    let store = FileStateStore(url: home.url)
    let state = try #require(store.load())
    #expect(store.repairs == ["\(path.joined(separator: ".")) is not read by this version, and will not be saved again"])
    #expect(
      state == loaded(PersistedState.read(try JSONSerialization.data(withJSONObject: try savedSession()))), "all else is read")
    store.save(state)
    store.flush()
    #expect(home.bytes("state.before-repair.json") == file)

    // What Arbor saved has nothing of the kind, so the next start has nothing to say.
    #expect(store.load() == state && store.repairs.isEmpty)
    #expect(home.files == ["state.before-repair.json", "state.json"])
  }

  @Test func nothingIsSaidAboutAFileArborWroteOrAboutKeysThatHoldNothing() throws {
    let home = try Home()
    var object = try savedSession()
    for (key, nothing) in [("a", NSNull() as Any), ("b", [Any]()), ("c", [String: Any]())] { object[key] = nothing }
    try JSONSerialization.data(withJSONObject: object).write(to: home.url)
    let store = FileStateStore(url: home.url)
    #expect(store.load() != nil && store.repairs.isEmpty && store.keptCopy == nil)
    #expect(home.files == ["state.json"])
  }

  /// With everything a workspace can hold, so that a field that is read and not written, or written under another
  /// name, shows up here.
  @Test func nothingIsSaidAboutAFullSession() throws {
    var settings = Settings()
    settings.tabsEnabled = true
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side], settings: settings)
    for app in ["Safari", "Notes", "Mail", "Music", "Maps", "Photos"] { h.system.open(app: app) }
    h.start()
    for line in [
      "dock 101 left", "dock 103 right", "dock 102 beside 103 bottom", "save-view 1", "zoom 101", "name web", "back",
      "pin 106", "zoom 101",
    ] { #expect(h.run(line).ok, "\(line)") }
    h.system.open(app: "Books")
    h.scheduler.runPending()
    #expect(h.run("summon Music").ok)
    h.system.setDisplays([FakeWindowSystem.standardDisplay])
    h.scheduler.runPending()
    h.controller.saveNow()
    let saved = try #require(h.store.saved)
    #expect(saved.workspaces.values.contains { $0.guests?.isEmpty == false && !$0.names.isEmpty && $0.summoned != nil })
    let notes = DecodingNotes()
    #expect(loaded(PersistedState.read(try JSONEncoder().encode(saved), notes: notes)) == saved)
    #expect(notes.notes == [])
  }

  /// What main's build of 2026-10-14 wrote after zoom, close and quit, in 6 of 120 everyday sessions (found by R3). The
  /// candidate greeted its owner with the repair notice as the menu's first line and an ERROR in the log.
  @Test func aFileThatOnlyNeedsTidyingRaisesNoAlarm() throws {
    let home = try Home()
    var object = try savedSession()
    let camera = try #require(((object["workspaces"] as? [String: Any])?["main"] as? [String: Any])?["camera"] as? Int)
    object = setting([camera], at: ["workspaces", "main", "back"], in: object)
    try JSONSerialization.data(withJSONObject: object).write(to: home.url)

    let store = FileStateStore(url: home.url)
    let state = try #require(store.load())
    #expect(state.workspaces[FakeWindowSystem.standardDisplay.id]?.back == [])
    #expect(store.repairs.isEmpty && store.loadProblem == nil)

    let h = Harness(saved: state)
    h.store.repairs = store.repairs
    h.store.loadProblem = store.loadProblem
    h.start()
    #expect(h.controller.notices.allSatisfy { !$0.contains("saved arrangement") }, "\(h.controller.notices)")
    #expect(h.run("status").message.contains("saved arrangement") == false)
  }

  /// Found by `scripts/fuzz-launch.py audit`. `floating` is null, which counts as absent and earns no note; the pin, the guest and
  /// the summoned window then "do not float here", which is tidying. Nobody is told; but it is somebody's, so it is kept.
  @Test func whatIsOnlyTidiedIsKeptAllTheSame() throws {
    let home = try Home()
    var object = try savedSession()
    object = setting(NSNull(), at: ["workspaces", "main", "floating"], in: object)
    object = setting([4711], at: ["workspaces", "main", "pinned"], in: object)
    let file = try JSONSerialization.data(withJSONObject: object)
    try file.write(to: home.url)
    let store = FileStateStore(url: home.url)
    let state = try #require(store.load())
    #expect(store.repairs.isEmpty && store.loadProblem == nil)
    store.save(state)
    store.flush()
    #expect(home.bytes("state.before-repair.json") == file)
  }

  /// For whoever decides what to tell the person (`DecodingNotes.losses`).
  @Test func aDisplayLeftOutAFieldOfALaterVersionAndAPauseAreLosses() throws {
    var object = setting(["a": 1], at: ["later"], in: try savedSession())
    let notes = DecodingNotes()
    _ = PersistedState.read(try JSONSerialization.data(withJSONObject: object), notes: notes)
    #expect(notes.losses == notes.notes && notes.losses.count == 1)

    object = setting("tomorrow", at: ["pause"], in: try savedSession())
    let more = DecodingNotes()
    _ = PersistedState.read(try withoutTheSideDisplaysRoot(object), notes: more)
    #expect(more.losses == more.notes && more.losses.count == 2, "\(more.notes)")
  }

  /// How often a hint was shown. They start again, and nobody is told that anything was damaged.
  @Test func countsThatCannotBeReadAreTidied() throws {
    let notes = DecodingNotes()
    let object = setting(["peek": "twice"], at: ["hintsShown"], in: try savedSession())
    let state = try #require(loaded(PersistedState.read(try JSONSerialization.data(withJSONObject: object), notes: notes)))
    #expect(state.hintsShown.isEmpty && !state.workspaces.isEmpty)
    #expect(notes.losses.isEmpty && notes.tidied == ["`hintsShown` could not be read"])
  }

  @Test func aPauseThatCannotBeReadIsNoted() throws {
    let notes = DecodingNotes()
    let object = setting(["until": "tomorrow", "forApp": false], at: ["pause"], in: try savedSession())
    let state = try #require(loaded(PersistedState.read(try JSONSerialization.data(withJSONObject: object), notes: notes)))
    #expect(state.pause == nil && !state.workspaces.isEmpty)
    #expect(notes.notes == ["`pause` could not be read"])
  }

  /// A guest whose space is gone, say: Arbor can write that itself, the decoder drops it without a word, and nobody
  /// misses it. "The saved arrangement was damaged" would be a false alarm. (And a name is a key too: not for the log.)
  @Test(arguments: [["guests", "101"], ["savedViews", "7"], ["undockedFrames", "4711"]])
  func anEntryTheDecodersDropIsTheirBusiness(path: [String]) throws {
    let notes = DecodingNotes()
    let value: Any = path[0] == "undockedFrames" ? [[0, 0], [100, 100]] : 4711
    let object = setting(value, at: ["workspaces", "main"] + path, in: try savedSession())
    let state = try #require(loaded(PersistedState.read(try JSONSerialization.data(withJSONObject: object), notes: notes)))
    #expect(notes.notes.allSatisfy { !$0.contains("not read by this version") }, "\(notes.notes)")
    #expect(state.workspaces[FakeWindowSystem.standardDisplay.id] != nil)
  }

  @Test func aDisplayThatCouldNotBeReadIsStillOnDiskAfterTheNextSave() throws {
    let home = try Home()
    let damaged = try withoutTheSideDisplaysRoot(try savedSession())
    try damaged.write(to: home.url)

    let store = FileStateStore(url: home.url)
    let state = try #require(store.load())
    #expect(Array(state.workspaces.keys) == [FakeWindowSystem.standardDisplay.id], "the other one is not lost with it")
    store.save(state)
    store.flush()

    #expect(home.bytes("state.json") != damaged, "saved over, as after every launch")
    #expect(home.bytes("state.before-repair.json") == damaged, "\(home.files)")
    #expect(!store.repairs.isEmpty && store.keptCopy == "state.before-repair.json")
  }

  @Test func soIsATreeThatWasOnlyRepaired() throws {
    let home = try Home()
    var object = try savedSession()
    var workspaces = try #require(object["workspaces"] as? [String: Any])
    var side = try #require(workspaces["side"] as? [String: Any])
    side["camera"] = 4711
    workspaces["side"] = side
    object["workspaces"] = workspaces
    let damaged = try JSONSerialization.data(withJSONObject: object)
    try damaged.write(to: home.url)
    let store = FileStateStore(url: home.url)
    #expect(store.load()?.workspaces.count == 2)
    #expect(home.bytes("state.before-repair.json") == damaged)
  }

  @Test func aFileWithNothingWrongLeavesNothingBehind() throws {
    let home = try Home()
    try JSONSerialization.data(withJSONObject: try savedSession()).write(to: home.url)
    let store = FileStateStore(url: home.url)
    #expect(store.load()?.workspaces.count == 2)
    #expect(home.files == ["state.json"] && store.repairs.isEmpty && store.keptCopy == nil)
  }

  /// The first is the one that matters: later ones may be Arbor's own saves of what it had repaired.
  @Test func theFirstCopyIsNeverWrittenOverAndThereAreNeverMoreThanThree() throws {
    let home = try Home()
    let object = try savedSession()
    var written: [Data] = []
    for round in 1...5 {
      var object = object
      object["round"] = round
      written.append(try withoutTheSideDisplaysRoot(object))
      try written.last!.write(to: home.url)
      _ = FileStateStore(url: home.url).load()
    }
    #expect(
      home.files == [
        "state.before-repair.2.json", "state.before-repair.3.json", "state.before-repair.json", "state.json",
      ])
    #expect(home.bytes("state.before-repair.json") == written[0])
    #expect(home.bytes("state.before-repair.2.json") == written[1])
    #expect(home.bytes("state.before-repair.3.json") == written[4], "the last place holds the latest")
  }

  /// Window titles are in there.
  @Test func theCopyIsForItsOwnerOnly() throws {
    let home = try Home()
    try withoutTheSideDisplaysRoot(try savedSession()).write(to: home.url)
    _ = FileStateStore(url: home.url).load()
    let path = home.folder.appendingPathComponent("state.before-repair.json").path
    let permissions = try FileManager.default.attributesOfItem(atPath: path)[.posixPermissions] as? Int
    #expect(permissions == 0o600)
  }

  @Test func aFileThatCannotBeReadAtAllIsSetAsideAsBefore() throws {
    let home = try Home()
    try Data("not json".utf8).write(to: home.url)
    let store = FileStateStore(url: home.url)
    #expect(store.load() == nil)
    #expect(home.files == ["state.unreadable.json"] && store.keptCopy == "state.unreadable.json")
  }

  // MARK: A word

  @Test func statusSaysSoUntilTheNextLaunch() {
    let h = Harness()
    h.store.repairs = ["workspaces: skipped `side`: the tree's root n4711 is missing"]
    h.store.keptCopy = "state.before-repair.json"
    h.start()
    let status = h.run("status").message
    #expect(status.contains("state.before-repair.json") && status.contains("1 "), "\(status)")
  }

  @Test func statusSaysNothingWhenThereIsNothingToSay() {
    let h = Harness()
    h.start()
    #expect(!h.run("status").message.contains("state"))
  }
}
