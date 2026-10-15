import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// The small queries (F50, part 2): each has a text form and a JSON form, and neither holds a title unless asked.
@Suite @MainActor struct QueryTests {
  func w(_ id: UInt32) -> WindowID { WindowID(id) }

  /// 101 Safari | (102 Mail / 103 Notes), 104 Slack floating; Mail has the keyboard.
  func harness(displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay]) -> Harness {
    let h = Harness(displays: displays)
    h.system.open(app: "Safari", bundleID: "com.apple.Safari", title: "Secret plans")
    h.system.open(app: "Mail", bundleID: "com.apple.mail", title: "Payroll")
    h.system.open(app: "Notes", bundleID: "com.apple.Notes", title: "Diary")
    h.system.open(app: "Slack", bundleID: nil, title: "DMs")
    h.start()
    h.run("layout Safari | (Mail / Notes) | Desktop")
    h.system.userFocus(w(101))
    h.system.userFocus(w(102))
    return h
  }

  func rows(_ result: CommandResult) -> [[String]] {
    (result.text ?? "").split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
  }

  // MARK: windows

  @Test func windowsAsText() {
    let h = harness()
    let result = h.run("windows")
    #expect(result.ok)
    #expect(result.message == "4 windows")
    #expect(
      rows(result) == [
        ["102", "docked", "in-view", "1", "com.apple.mail", "Mail"], ["101", "docked", "in-view", "1", "com.apple.Safari", "Safari"],
        ["103", "docked", "in-view", "1", "com.apple.Notes", "Notes"], ["104", "floating", "in-view", "1", "com.example.slack", "Slack"],
      ])
  }

  @Test func windowsAsJSON() throws {
    let h = harness()
    let json = try #require(h.run("windows").json)
    let first = try #require(json[0])
    #expect(first["id"] == .int(102))
    #expect(first["docked"] == .bool(true))
    #expect(first["state"] == .string("in-view"))
    #expect(first["display"] == .int(1))
    #expect(first["displayID"] == .string("main"))
    #expect(first["bundleID"] == .string("com.apple.mail"))
    #expect(first["app"] == .string("Mail"))
    #expect(first["focused"] == .bool(true))
    #expect(first["node"] == .int(h.workspace.tree.leaf(containing: w(102))!.rawValue))
    let frame = try #require(h.frame(w(102)))
    #expect(first["frame"] == .object(["x": .int(Int(frame.minX)), "y": .int(Int(frame.minY)), "width": .int(Int(frame.width)), "height": .int(Int(frame.height))]))
    #expect(first["title"] == nil)
    #expect(json[1]?["focused"] == .bool(false))
    #expect(json[3]?["docked"] == .bool(false) && json[3]?["state"] == .string("in-view") && json[3]?["node"] == nil)
    #expect(json[4] == nil)
    // It decodes as what it was made from.
    #expect(try JSONDecoder().decode([Query.Window].self, from: Data(json.text.utf8)).map(\.id) == [w(102), w(101), w(103), w(104)])
  }

  @Test func theFirstLineWithAnAppOnItIsTheWindowItsNameMeans() {
    let h = harness()
    h.system.open(app: "Safari", bundleID: "com.apple.Safari")
    h.system.userFocus(w(105))
    h.system.userFocus(w(104))
    let first = rows(h.run("windows")).first { $0[5] == "Safari" }?[0]
    #expect(first == "105")
    h.run("dock Safari top")
    #expect(h.workspace.isDocked(w(105)))
  }

  @Test func everyWayOfNotBeingInView() {
    let h = harness()
    h.system.open(app: "Xcode", pid: 2000)
    h.system.open(app: "Zed")
    h.system.open(app: "Music")
    h.run("zoom 101")
    h.system.setMinimized(w(103), true)
    h.system.setHidden(pid: 2000, true)
    h.system.setOnActiveSpace(w(106), false)
    h.scheduler.runPending()
    var views: [String: String] = [:]
    for row in rows(h.run("windows")) { views[row[0]] = row[2] }
    #expect(views["101"] == "in-view")
    #expect(views["102"] == "out-of-view")
    #expect(views["103"] == "minimized")
    #expect(views["104"] == "out-of-view")
    #expect(views["105"] == "hidden")
    #expect(views["106"] == "other-space")
  }

  @Test func aWindowBehindATileSaysSo() {
    let h = harness()
    h.run("layout Safari | Mail:0.05 | Desktop")
    #expect(rows(h.run("windows")).first { $0[0] == "102" }?[2] == "tile")
  }

  @Test func onlyWindowsArborArrangesAreListed() {
    let h = harness()
    h.run("exclude com.apple.mail")
    #expect(!rows(h.run("windows")).contains { $0[0] == "102" })
  }

  @Test func noTitlesUnlessAskedFor() throws {
    let h = harness()
    for command in ["windows", "where", "views", "displays", "version", "help zoom"] {
      let result = h.run(command)
      let everything = result.message + (result.text ?? "") + (result.json?.text ?? "")
      for title in ["Secret", "Payroll", "Diary", "DMs"] { #expect(!everything.contains(title), "\(command)") }
    }
    let result = h.run("windows --titles")
    #expect(rows(result)[0] == ["102", "docked", "in-view", "1", "com.apple.mail", "Mail", "Payroll"])
    #expect(result.json?[0]?["title"] == .string("Payroll"))
    #expect(!result.message.contains("Payroll"))
  }

  @Test func aTabOrLineBreakInANameCannotShiftTheFields() {
    let h = Harness()
    h.system.open(app: "Odd\tApp\nName", bundleID: "x", title: "a\tb\r\nc")
    h.start()
    #expect(rows(h.run("windows --titles")) == [["101", "floating", "in-view", "1", "x", "Odd App Name", "a b c"]])
  }

  @Test func noWindowsIsAnEmptyAnswerNotAFailure() {
    let h = Harness()
    h.start()
    let result = h.run("windows")
    #expect(result.ok && result.text == "" && result.json == .array([]) && result.message == "0 windows")
    #expect(h.run("views").json == .array([]))
  }

  // MARK: where

  @Test func whereAsText() {
    let h = harness()
    #expect(rows(h.run("where")) == [["1", "everything", "\(h.workspace.tree.root)", "depth 0 of 2", "0 out of view"]])
    h.run("zoom 102")
    #expect(rows(h.run("where")) == [["1", "Mail", "\(h.workspace.camera)", "depth 2 of 2", "3 out of view"]])
    h.run("out")
    #expect(rows(h.run("where")) == [["1", "Mail and Notes", "\(h.workspace.camera)", "depth 1 of 2", "2 out of view"]])
    h.run("desktop")
    #expect(rows(h.run("where")) == [["1", "the Desktop", "n0", "depth 1 of 2", "3 out of view"]])
  }

  @Test func whereAsJSON() throws {
    let h = harness()
    h.run("zoom 102")
    h.run("out")
    let place = try #require(h.run("where").json?[0])
    #expect(place["display"] == .int(1))
    #expect(place["displayID"] == .string("main"))
    #expect(place["label"] == .string("Mail and Notes"))
    #expect(place["node"] == .int(h.workspace.camera.rawValue))
    #expect(place["kind"] == .string("group"))
    #expect(place["depth"] == .int(1) && place["deepest"] == .int(2))
    #expect(place["outOfView"] == .int(2))
    #expect(place["windows"] == .array([.int(102), .int(103)]))
    #expect(place["apps"] == .array([.string("Mail"), .string("Notes")]))
    #expect(place["canGoBack"] == .bool(true) && place["canGoForward"] == .bool(false))
    for (command, kind) in [("show-all", "everything"), ("desktop", "desktop"), ("zoom 101", "window")] {
      h.run(command)
      #expect(h.run("where").json?[0]?["kind"] == .string(kind), "\(command)")
    }
  }

  @Test func whereSpeaksAsRepliesDo() {
    let h = harness()
    h.run("zoom 102")
    let reply = h.run("out").message
    let row = rows(h.run("where"))[0]
    #expect(reply.hasSuffix("\(row[1]) (\(row[2]))"), "\(reply) against \(row)")
  }

  /// `where` is the `view` event asked for instead of waited for. Whatever happens, the two tell one story.
  @Test func whereSaysWhatTheViewEventSays() throws {
    let h = harness(displays: [FakeWindowSystem.standardDisplay, side])
    func compare(_ situation: String) throws {
      let views = h.controller.eventSummary(focused: nil).views
      guard case .array(let places)? = h.run("where").json else { return #expect(Bool(false), "no answer") }
      #expect(places.count == views.count && views.count == 2)
      for place in places {
        guard case .string(let id)? = place["displayID"] else { return #expect(Bool(false), "no displayID") }
        let view = try #require(views.first { $0.display.rawValue == id })
        let event = try #require(JSONValue(encoding: view))
        for key in ["displayID", "node", "kind", "label", "depth", "windows", "apps", "outOfView", "canGoBack", "canGoForward", "name"] {
          #expect(place[key] == event[key], "\(situation): \(key) is \(String(describing: place[key])) here and \(String(describing: event[key])) in the event")
        }
      }
    }
    try compare("everything")
    for line in ["zoom 102", "out", "name Writing", "save-view 1", "show-all", "back", "forward", "desktop", "layout Safari | Mail:0.05 | Desktop", "zoom 101", "float 101", "home"] {
      #expect(h.run(line).ok, "\(line)")
      try compare(line)
    }
    // The framed window goes to the Dock: the display shows the nearest space around it that has anything to show.
    #expect(h.run("layout (Safari / Mail) | Notes").ok && h.run("zoom Mail").ok)
    h.system.setMinimized(w(102), true)
    h.scheduler.runPending()
    try compare("the framed window is minimised")
    let place = try #require(h.run("where").json?[0])
    #expect(place["label"] == .string("Safari") && place["windows"] == .array([.int(101)]), "\(place)")
  }

  /// `label` is Arbor's word for a space and `name` a person's, as in the events. As text a space goes by its name, as in replies.
  @Test func aNamedSpaceHasBoth() throws {
    let h = harness()
    for line in ["zoom 102", "out", "name Writing", "save-view 4"] { #expect(h.run(line).ok, "\(line)") }
    for query in ["where", "views"] {
      let row = try #require(h.run(query).json?[0])
      #expect(row["label"] == .string("Mail and Notes") && row["name"] == .string("Writing"), "\(query): \(row)")
    }
    #expect(rows(h.run("where"))[0][1] == "Writing" && rows(h.run("views"))[0][2] == "Writing")
    #expect(h.run("unname").ok)
    #expect(h.run("where").json?[0]?["name"] == nil && rows(h.run("where"))[0][1] == "Mail and Notes")
  }

  /// A window behind a tile is in view, as a tile. `where` counts as `windows` lists.
  @Test func whatIsCountedOutOfViewIsWhatIsListedSo() {
    let h = harness()
    for line in ["layout Safari | Mail:0.05 | Desktop", "zoom 101", "show-all", "desktop"] {
      #expect(h.run(line).ok, "\(line)")
      let listed = rows(h.run("windows")).filter { $0[2] == "out-of-view" }.count
      #expect(rows(h.run("where"))[0][4] == "\(listed) out of view", "\(line)")
    }
  }

  @Test func whereHasOneLinePerDisplay() {
    let h = harness(displays: [side, FakeWindowSystem.standardDisplay])
    h.run("layout @2 Slack")
    h.run("zoom 104")
    let answer = rows(h.run("where"))
    #expect(answer.count == 2)
    #expect(answer[0][0...1] == ["1", "everything"])
    #expect(answer[1][0...1] == ["2", "Slack"])
  }

  // MARK: views

  @Test func viewsAsTextAndJSON() throws {
    let h = harness()
    h.run("save-view 3")
    h.run("zoom 101")
    h.run("save-view 1")
    let result = h.run("views")
    #expect(result.message == "2 saved views")
    #expect(rows(result) == [["1", "1", "Safari", "\(h.workspace.camera)", "current"], ["1", "3", "everything", "\(h.workspace.tree.root)"]])
    let json = try #require(result.json)
    #expect(
      json[0]
        == .object([
          "display": .int(1), "displayID": .string("main"), "view": .int(1), "label": .string("Safari"),
          "node": .int(h.workspace.camera.rawValue), "current": .bool(true),
        ]))
    #expect(json[1]?["current"] == .bool(false))
  }

  @Test func viewsOfEveryDisplayAreListed() {
    let h = harness(displays: [FakeWindowSystem.standardDisplay, side])
    h.run("save-view 2")
    h.system.cursor = CGPoint(x: 2000, y: 300)
    h.run("save-view 5")
    #expect(rows(h.run("views")).map { Array($0[0...1]) } == [["1", "2"], ["2", "5"]])
  }

  // MARK: displays

  @Test func displaysAsTextAndJSON() throws {
    let h = harness(displays: [side, FakeWindowSystem.standardDisplay])
    h.system.cursor = CGPoint(x: 2000, y: 300)
    let result = h.run("displays")
    #expect(result.message == "2 displays")
    // The last two are F25's: what macOS calls it, and the options it has of its own (`DisplayOptionsScenarioTests`).
    #expect(rows(result) == [["1", "main", "0,0,1440,900", "main,focus", "-", "-"], ["2", "side", "1440,0,1280,800", "pointer", "-", "-"]])
    let json = try #require(result.json)
    #expect(json[0]?["display"] == .int(1) && json[0]?["id"] == .string("main") && json[0]?["displayID"] == .string("main"))
    #expect(json[1]?["display"] == .int(2) && json[1]?["id"] == .string("side") && json[1]?["displayID"] == .string("side"))
    #expect(json[0]?["frame"] == .object(["x": .int(0), "y": .int(0), "width": .int(1440), "height": .int(900)]))
    #expect(json[0]?["visibleFrame"] == .object(["x": .int(0), "y": .int(25), "width": .int(1440), "height": .int(875)]))
    #expect(json[0]?["main"] == .bool(true) && json[0]?["pointer"] == .bool(false) && json[0]?["focus"] == .bool(true))
    #expect(json[1]?["main"] == .bool(false) && json[1]?["pointer"] == .bool(true) && json[1]?["focus"] == .bool(false))
  }

  @Test func aPinnedWindowSaysSo() throws {
    let h = harness()
    func row(_ id: Int) throws -> (text: [String], json: JSONValue) {
      let result = h.run("windows")
      let index = try #require(rows(result).firstIndex { $0[0] == String(id) })
      return (rows(result)[index], try #require(result.json?[index]))
    }
    #expect(try row(104).text[1] == "floating" && row(104).json["pinned"] == .bool(false))
    #expect(try row(101).text[1] == "docked" && row(101).json["pinned"] == .bool(false))
    #expect(h.run("pin 104").ok)
    #expect(try row(104).text[1] == "pinned")
    #expect(try row(104).json["pinned"] == .bool(true) && row(104).json["docked"] == .bool(false), "it floats, and says so")
    // A docked window floats first.
    #expect(h.run("pin 101").ok)
    #expect(try row(101).text[1] == "pinned" && row(101).json["docked"] == .bool(false) && row(101).json["node"] == nil)
    #expect(h.run("unpin 104").ok)
    #expect(try row(104).text[1] == "floating" && row(104).json["pinned"] == .bool(false))
    // Docking ends it.
    #expect(h.run("dock 101 left").ok)
    #expect(try row(101).text[1] == "docked" && row(101).json["pinned"] == .bool(false))
  }

  @Test func aSummonedWindowSaysSo() throws {
    let h = harness()
    func row(_ id: Int) throws -> (text: [String], json: JSONValue) {
      let result = h.run("windows")
      let index = try #require(rows(result).firstIndex { $0[0] == String(id) })
      return (rows(result)[index], try #require(result.json?[index]))
    }
    #expect(try row(104).json["summoned"] == .bool(false))
    #expect(h.run("summon Slack").ok)
    #expect(try row(104).text[1] == "summoned")
    #expect(try row(104).json["summoned"] == .bool(true) && row(104).json["docked"] == .bool(false) && row(104).json["pinned"] == .bool(false))
    #expect(try row(101).json["summoned"] == .bool(false))
  }

  /// A status bar has to tell a pause from a failure, and by more than the words.
  @Test(arguments: ["windows", "windows --titles", "where", "views", "displays"])
  func duringAPauseThereIsNothingToListAndThatIsNoFailure(query: String) {
    let h = harness()
    h.run("save-view 1")
    #expect(h.run("pause").ok)
    let paused = h.run(query)
    #expect(paused.ok && paused.text == "" && paused.json == .array([]), "\(paused)")
    #expect(paused.message.hasPrefix("paused"), "\(paused.message)")
    #expect(h.run("resume").ok)
    #expect(h.run(query).json != .array([]))
    #expect(paused.warning == nil, "no news to whoever asks every two seconds")
    // Not having started is one. (`displays` answers even then, by F25: `theDisplaysQueryAnswersBeforeArborStarts`.)
    let stopped = Harness()
    #expect(stopped.run(query).ok == (query == "displays"))
  }

  /// One vocabulary for scripts, in queries and events alike (collab/QUESTIONS.md): a word means one thing wherever it stands.
  @Test func theWordsAreTheOnesTheEventsUse() throws {
    let h = harness(displays: [side, FakeWindowSystem.standardDisplay])
    h.run("save-view 1")
    func list(_ query: String) throws -> [[String: JSONValue]] {
      guard case .array(let rows) = try #require(h.run(query).json) else { return [] }
      return rows.compactMap { if case .object(let fields) = $0 { fields } else { nil } }
    }
    let (windows, places, views, displays) = (try list("windows"), try list("where"), try list("views"), try list("displays"))
    #expect(!windows.isEmpty && !places.isEmpty && !views.isEmpty && displays.count == 2)
    // `name` is only a name a person gave (F20); a space in words is its `label`. Where a window is, is its `state`.
    // (A display's `name` is what macOS calls it, as in the `displays` event.)
    for row in windows + places + views { #expect(row["name"] == nil, "\(row.keys.sorted())") }
    for row in windows { #expect(row["view"] == nil, "\(row.keys.sorted())") }
    for row in places + views {
      if case .string = row["label"] {} else { Issue.record("no label in \(row.keys.sorted())") }
    }
    func string(_ value: JSONValue?) -> String? { if case .string(let text) = value { text } else { nil } }
    let states: Set = ["in-view", "out-of-view", "tile", "minimized", "hidden", "full-screen", "other-space"]
    for row in windows {
      if case .bool = row["docked"] {} else { Issue.record("docked is true or false, not \(String(describing: row["docked"]))") }
      #expect(string(row["state"]).map(states.contains) == true, "\(String(describing: row["state"]))")
    }
    // What is a window or a display has an `id`; `display` is always the number and `displayID` always the UUID, so they join.
    let numbers = Dictionary(uniqueKeysWithValues: displays.compactMap { row in string(row["displayID"]).map { ($0, row["display"]) } })
    #expect(numbers.count == 2)
    for row in displays { #expect(row["id"] == row["displayID"]) }
    for row in windows + places + views {
      let id = try #require(string(row["displayID"]))
      #expect(numbers[id] == .some(row["display"]), "\(row)")
      if case .int = row["display"] {} else { Issue.record("display is a number") }
    }
  }

  /// `state` too: in `windows` and `waiting`, `display` was the UUID, and the number in `windows --json`.
  @Test func stateSpeaksOfDisplaysAsTheQueriesDo() throws {
    let h = harness(displays: [side, FakeWindowSystem.standardDisplay])
    let reply = JSONValue(encoding: h.run("state"))
    guard case .array(let windows)? = reply?["state"]?["windows"], case .array(let listed)? = h.run("windows").json else {
      Issue.record("no windows in \(String(describing: reply))")
      return
    }
    #expect(windows.count == 4 && listed.count == 4)
    for window in windows {
      let same = try #require(listed.first { $0["id"] == window["id"] })
      #expect(window["display"] == same["display"] && window["displayID"] == same["displayID"], "\(window)")
      #expect(window["display"] == .int(1) && window["displayID"] == .string("main"))
      #expect(window["docked"] == same["docked"] && window["pinned"] == same["pinned"])
    }
    // It decodes as what it was made from.
    let state = try #require(h.run("state").state)
    #expect(try JSONDecoder().decode(StateSnapshot.self, from: JSONEncoder().encode(state)) == state)
    #expect(state.windows.allSatisfy { $0.display == DisplayID("main") && $0.displayNumber == 1 })
  }

  /// With keys of its own, a type leaves a new property out of its JSON without a word.
  @Test func everyPropertyOfTheStateIsWritten() throws {
    var window = StateSnapshot.Window(
      id: w(1), pid: 1, app: "A", bundleID: "b", title: "t", frame: .zero, minimized: false, hidden: false, managed: true, docked: false, parked: false,
      display: DisplayID("main"), fullScreen: false, guestOf: NodeID(1))
    window.displayNumber = 1
    var waiting = StateSnapshot.Waiting(id: w(1), bundleID: "b", title: "t", display: DisplayID("main"), open: false)
    waiting.displayNumber = 1
    func check<Value: Encodable>(_ value: Value) throws {
      guard case .object(let fields)? = JSONValue(encoding: value) else { return #expect(Bool(false), "\(value) is no object") }
      let renamed = ["display": "displayID", "displayNumber": "display"]
      let properties = Mirror(reflecting: value).children.compactMap(\.label).map { $0.hasPrefix("_") ? String($0.dropFirst()) : $0 }
      #expect(properties.count >= 6)
      for property in properties { #expect(fields[renamed[property] ?? property] != nil, "\(Value.self).\(property) needs a case in its CodingKeys") }
      #expect(fields.count == properties.count)
    }
    try check(window)
    try check(waiting)
  }

  @Test func theNumbersAreTheOnesLayoutTakes() {
    let h = harness(displays: [side, FakeWindowSystem.standardDisplay])
    for row in rows(h.run("displays")) {
      h.run("layout @\(row[0]) Slack")
      #expect(h.controller.workspaceID(containing: w(104))?.rawValue == row[1])
      #expect(rows(h.run("windows")).first { $0[0] == "104" }?[3] == row[0])
    }
  }

  @Test func aDisplayWithNothingOfNoteHasADash() {
    let h = harness(displays: [FakeWindowSystem.standardDisplay, side])
    #expect(rows(h.run("displays"))[1] == ["2", "side", "1440,0,1280,800", "-", "-", "-"])
  }

  // MARK: version and help

  @Test func versionAsTextAndJSON() {
    let h = Harness()
    // Also before Arbor runs: it is the first thing a script asks.
    let result = h.run("version")
    #expect(result.ok)
    #expect(result.message == "Arbor dev" && result.text == nil, "one line, for scripts, until updates were asked about (F13)")
    #expect(result.json == .object(["version": .string("dev"), "schema": .int(2)]), "what is not known is left out")
    h.controller.buildInfo = BuildInfo(version: "0.9.0", build: "214", commit: "47a2ba9")
    #expect(h.run("version").message == "Arbor 0.9.0 (build 214, 47a2ba9)")
    #expect(
      h.run("version").json
        == .object(["version": .string("0.9.0"), "build": .string("214"), "commit": .string("47a2ba9"), "schema": .int(2)]))
  }

  @Test func helpOnACommandListsTheShortcutsInEffect() {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+z": "zoom Safari", "ctrl+opt+return": nil, "ctrl+opt+cmd+left": "float"]
    let h = Harness(settings: settings)
    #expect(h.run("help zoom").text == Command.help(on: "zoom")! + "\n  shortcut: ⌃⌥Z zoom Safari")
    #expect(h.run("help dock").text?.hasSuffix("shortcuts: ⌃⌥⌘→ dock right, ⌃⌥⌘↑ dock top, ⌃⌥⌘↓ dock bottom") == true)
    #expect(h.run("help relayout").text == Command.help(on: "relayout"))
    settings.hotkeysEnabled = false
    h.controller.apply(settings: settings)
    #expect(h.run("help zoom").text == Command.help(on: "zoom"))
  }

  /// On the keyboard in use, as `bindings` and the menu show them.
  @Test func theShortcutsAreShownAsTheKeyboardHasThem() throws {
    let h = Harness()
    #expect(h.run("help back").text?.hasSuffix("shortcut: ⌃⌥[ back") == true)
    h.controller.keyboardLayoutChanged(try #require(SampleKeyLayouts.byName["german"]))
    let label = try #require(h.controller.effectiveBindings.bindings.first { $0.command == .back }?.label)
    #expect(label != "⌃⌥[")
    #expect(h.run("help back").text?.hasSuffix("shortcut: \(label) back") == true, "\(h.run("help back").text ?? "")")
  }

  /// `arborctl settings --json` takes the option for its own and sends `settings`.
  @Test func settingsCarryTheirJSONWhicheverFormWasAskedFor() throws {
    let h = Harness()
    let asked = try JSONDecoder().decode(JSONValue.self, from: Data((h.run("settings --json").text ?? "").utf8))
    #expect(h.run("settings").json == asked && h.run("settings --json").json == asked)
    #expect(asked[0]?["key"] != nil)
  }

  // MARK: When Arbor is not looking

  @Test func beforeArborRunsAndWhilePausedTheySaySo() {
    let h = Harness()
    for command in ["windows", "where", "views"] {
      #expect(!h.run(command).ok && h.run(command).message == "starting", "\(command)")
    }
    #expect(h.run("displays").message == "starting")
    h.start()
    h.run("pause")
    // Said, but not as a failure: `duringAPauseThereIsNothingToListAndThatIsNoFailure`.
    for command in ["windows", "where", "views", "displays"] { #expect(h.run(command).message.hasPrefix("paused"), "\(command)") }
    #expect(h.run("version").ok && h.run("help zoom").ok)
  }

  @Test func theyAreQueries() throws {
    for text in ["windows", "windows --titles", "where", "views", "displays", "version", "help zoom"] {
      let command = try Command.parse(text)
      #expect(command.isQuery && !command.isAllowedFromURL, "\(text)")
      #expect(command.text == text)
      #expect(try Command.parse(command.text) == command)
    }
    for text in ["windows --json", "windows now", "where am i", "views 1", "displays 2", "version 2"] {
      #expect(throws: Command.ParseError.self, "\(text)") { try Command.parse(text) }
    }
  }

  @Test func theyChangeNothing() {
    let h = harness()
    h.run("zoom 102")
    let (workspaces, frames) = (h.controller.workspaces, h.system.windows.mapValues(\.snapshot.frame))
    h.system.clearFrameLog()
    for command in ["windows", "windows --titles", "where", "views", "displays", "version", "help zoom", "layout"] { h.run(command) }
    #expect(h.controller.workspaces == workspaces)
    #expect(h.system.windows.mapValues(\.snapshot.frame) == frames)
    #expect(h.system.frameLog.isEmpty)
  }

  // MARK: state

  @Test func stateIsSchemaTwoThroughTheWholeReply() throws {
    let h = harness()
    h.run("layout Safari | Mail:0.05 | Desktop")
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let reply = String(decoding: try encoder.encode(h.run("state")), as: UTF8.self)
    #expect(reply.contains(#""schema":2"#))
    #expect(!reply.contains("[["))
    let value = try JSONDecoder().decode(JSONValue.self, from: Data(reply.utf8))
    #expect(value["state"]?["displays"]?[0]?["visibleFrame"] == .object(["x": .int(0), "y": .int(25), "width": .int(1440), "height": .int(875)]))
    #expect(value["state"]?["windows"]?[0]?["frame"]?["width"] != nil)
    #expect(try JSONDecoder().decode(CommandResult.self, from: Data(reply.utf8)).state == h.controller.snapshot().withoutTitles)
  }
}
