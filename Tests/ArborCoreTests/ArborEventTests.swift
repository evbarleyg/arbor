import ArborCore
import CoreGraphics
import Foundation
import Testing

private let main = DisplayID("main")
private let side = DisplayID("side")

private func window(
  _ id: UInt32, _ app: String = "Safari", on display: DisplayID = main, docked: Bool = false,
  state: ArborEvent.Window.State = .inView, title: String? = nil
) -> ArborEvent.Window {
  ArborEvent.Window(
    id: WindowID(id), app: app, bundleID: "com.example.\(app.lowercased())", display: display, docked: docked,
    state: state, title: title)
}

private func view(_ node: Int, _ kind: ArborEvent.View.Kind, on display: DisplayID = main) -> ArborEvent.View {
  ArborEvent.View(
    display: display, node: NodeID(node), kind: kind, label: kind.rawValue, depth: 0, windows: [], apps: [], outOfView: 0,
    canGoBack: false, canGoForward: false)
}

private func change(_ change: ArborEvent.WindowChange.Change, _ window: ArborEvent.Window) -> ArborEvent {
  .window(ArborEvent.WindowChange(change, window))
}

private func running() -> ArborEvent.Summary { ArborEvent.Summary(running: true, accessibility: true) }
private func notRunning() -> ArborEvent.Summary { ArborEvent.Summary(running: false, accessibility: true) }
private func paused() -> ArborEvent.Summary {
  var summary = notRunning()
  summary.paused = true
  return summary
}

/// A state with one of everything, every optional field filled in.
private let full: ArborEvent.Summary = {
  var state = running()
  state.displays = [
    ArborEvent.Display(
      display: main, main: true, frame: CGRect(x: 0, y: 0, width: 1440, height: 900), name: "Built-in Display", builtIn: true)
  ]
  state.windows = [window(101, docked: true, title: "Apple")]
  state.notArranged = [WindowID(7)]
  state.layouts = [
    ArborEvent.Arrangement(
      display: main, docked: 1, floating: 0, tiles: 0, frames: [WindowID(101): CGRect(x: 12, y: 37, width: 702, height: 851)])
  ]
  state.views = [view(2, .everything)]
  state.focus = ArborEvent.Focus(window: WindowID(101), app: "Safari", bundleID: "com.example.safari", display: main, title: "Apple")
  return state
}()

/// One event of each kind.
private let samples: [ArborEvent] = [
  .hello(ArborEvent.Hello(version: "1.2.3", protocol: 1, snapshot: full)),
  .displays(full.displays),
  change(.docked, full.windows[0]),
  .layout(full.layouts[0]),
  .view(
    ArborEvent.View(
      display: main, node: NodeID(4), kind: .group, label: "Safari and Notes", depth: 1, windows: [WindowID(101), WindowID(102)],
      apps: ["Safari", "Notes"], outOfView: 3, canGoBack: true, canGoForward: false, savedView: 2, name: "Writing")),
  .focus(full.focus),
  .settings(changed: ["gap", "rules"]),
  .started,
  .quitting,
  .paused,
  .resumed,
]

@Suite struct ArborEventLineTests {
  /// Scripts are written against these exact names. A change here breaks them: add fields, never rename.
  @Test func everyEventKeepsItsFieldNames() {
    #expect(
      samples.dropFirst().map(\.line) == [
        #"{"event":"displays","displays":[{"builtIn":true,"displayID":"main","frame":{"height":900,"width":1440,"x":0,"y":0},"main":true,"name":"Built-in Display"}]}"#,
        #"{"event":"window","app":"Safari","bundleID":"com.example.safari","change":"docked","displayID":"main","docked":true,"state":"in-view","title":"Apple","window":101}"#,
        #"{"event":"layout","displayID":"main","dockedCount":1,"floatingCount":0,"frames":{"101":{"height":851,"width":702,"x":12,"y":37}},"tileCount":0}"#,
        #"{"event":"view","apps":["Safari","Notes"],"canGoBack":true,"canGoForward":false,"depth":1,"displayID":"main","kind":"group","label":"Safari and Notes","name":"Writing","node":4,"outOfView":3,"savedView":2,"windows":[101,102]}"#,
        #"{"event":"focus","app":"Safari","bundleID":"com.example.safari","displayID":"main","title":"Apple","window":101}"#,
        #"{"event":"settings","changed":["gap","rules"]}"#,
        #"{"event":"started"}"#,
        #"{"event":"quitting"}"#,
        #"{"event":"paused"}"#,
        #"{"event":"resumed"}"#,
      ])
    #expect(
      samples[0].line
        == #"{"event":"hello","protocol":1,"snapshot":{"accessibility":true,"#
        + #""displays":[{"builtIn":true,"displayID":"main","frame":{"height":900,"width":1440,"x":0,"y":0},"main":true,"name":"Built-in Display"}],"#
        + #""focus":{"app":"Safari","bundleID":"com.example.safari","displayID":"main","title":"Apple","window":101},"#
        + #""layouts":[{"displayID":"main","dockedCount":1,"floatingCount":0,"frames":{"101":{"height":851,"width":702,"x":12,"y":37}},"tileCount":0}],"#
        + #""notArranged":[7],"paused":false,"running":true,"#
        + #""views":[{"apps":[],"canGoBack":false,"canGoForward":false,"depth":0,"displayID":"main","kind":"everything","label":"everything","node":2,"outOfView":0,"windows":[]}],"#
        + #""windows":[{"app":"Safari","bundleID":"com.example.safari","displayID":"main","docked":true,"state":"in-view","title":"Apple","window":101}]},"#
        + #""version":"1.2.3"}"#)
  }

  @Test func theWordsAreTheGlossarys() {
    #expect(ArborEvent.Kind.allCases.map(\.rawValue) == [
      "hello", "displays", "window", "layout", "view", "focus", "settings", "started", "quitting", "paused", "resumed",
    ])
    #expect([ArborEvent.View.Kind.everything, .desktop, .window, .group].map(\.rawValue) == ["everything", "desktop", "window", "group"])
    #expect(
      [ArborEvent.Window.State.inView, .outOfView, .tile, .minimized, .hidden, .fullScreen, .otherSpace].map(\.rawValue)
        == ["in-view", "out-of-view", "tile", "minimized", "hidden", "full-screen", "other-space"])
    #expect(
      [ArborEvent.WindowChange.Change.opened, .closed, .adopted, .released, .docked, .floated, .state, .title].map(\.rawValue)
        == ["opened", "closed", "adopted", "released", "docked", "floated", "state", "title"])
  }

  @Test func fieldsWithNothingToSayAreLeftOut() {
    #expect(ArborEvent.focus(ArborEvent.Focus()).line == #"{"event":"focus"}"#)
    #expect(
      ArborEvent.view(view(0, .desktop)).line
        == #"{"event":"view","apps":[],"canGoBack":false,"canGoForward":false,"depth":0,"displayID":"main","kind":"desktop","label":"desktop","node":0,"outOfView":0,"windows":[]}"#)
  }

  @Test func everyLineReadsBackAsTheSameEvent() throws {
    #expect(Set(samples.map(\.kind)) == Set(ArborEvent.Kind.allCases), "a sample of every kind")
    for event in samples {
      #expect(try ArborEvent(line: event.line) == event)
      // The ordinary encoder writes the same object, with `event` sorted in among the other keys.
      #expect(try JSONDecoder().decode(ArborEvent.self, from: JSONEncoder().encode(event)) == event)
    }
  }

  @Test func aLineIsOneLineWhateverATitleHolds() throws {
    let awkward = "two\nlines \"quoted\" \\ / {\"event\":\"quitting\"} ⌘"
    let event = ArborEvent.focus(ArborEvent.Focus(window: WindowID(7), app: "Notes", title: awkward))
    #expect(!event.line.contains("\n"))
    #expect(event.line.hasPrefix(#"{"event":"focus","#))
    #expect(try ArborEvent(line: event.line) == event)
  }

  @Test func unknownEventsAndFieldsFromALaterArbor() {
    #expect(throws: (any Error).self) { try ArborEvent(line: #"{"event":"teleport"}"#) }
    #expect(throws: (any Error).self) { try ArborEvent(line: "{}") }
    #expect((try? ArborEvent(line: #"{"event":"started","because":"you asked"}"#)) == .started, "new fields are ignored")
  }

  @Test func theSamplesInTheScriptingGuideAreExactlyWhatArborSends() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let guide = try String(contentsOf: root.appendingPathComponent("docs/SCRIPTING.md"), encoding: .utf8)
    let samples = guide.split(separator: "\n").map(String.init).filter { $0.hasPrefix(#"{"event":"#) }
    #expect(samples.count >= 12)
    for sample in samples {
      #expect(try ArborEvent(line: sample).line == sample)
    }
    #expect(Set(try samples.map { try ArborEvent(line: $0).kind }) == Set(ArborEvent.Kind.allCases), "a sample of every kind")
  }
}

@Suite struct ArborEventChangesTests {
  @Test func nothingChangedMeansNoEvents() {
    #expect(ArborEvent.changes(from: full, to: full).isEmpty)
  }

  @Test func windowsOpenCloseDockAndFloat() {
    var old = running()
    old.windows = [window(101), window(102, "Notes", docked: true), window(103, "Mail")]
    var new = running()
    new.windows = [window(101, docked: true), window(102, "Notes"), window(104, "Xcode")]
    #expect(
      ArborEvent.changes(from: old, to: new) == [
        change(.closed, window(103, "Mail")), change(.docked, window(101, docked: true)),
        change(.floated, window(102, "Notes")), change(.opened, window(104, "Xcode")),
      ])
  }

  @Test func aWindowThatOpensDockedIsReportedAsBoth() {
    var new = running()
    new.windows = [window(101, docked: true)]
    #expect(
      ArborEvent.changes(from: running(), to: new) == [
        change(.opened, window(101, docked: true)), change(.docked, window(101, docked: true)),
      ])
  }

  @Test func aWindowArborLetsGoOfIsReleasedNotClosedAndTakenBackIsAdoptedNotOpened() {
    var arranged = running()
    arranged.windows = [window(101), window(102, "Notes", docked: true)]
    var excluded = running()
    excluded.windows = [window(101)]
    excluded.notArranged = [WindowID(102)]
    #expect(ArborEvent.changes(from: arranged, to: excluded) == [change(.released, window(102, "Notes", docked: true))])
    var back = arranged
    back.windows[1].docked = false
    #expect(ArborEvent.changes(from: excluded, to: back) == [change(.adopted, window(102, "Notes"))])
  }

  @Test func aWindowThatChangesDisplayIsReportedWhereItIsNow() {
    var old = running()
    old.windows = [window(101), window(102, docked: true)]
    var new = running()
    new.windows = [window(101, on: side), window(102, on: side, docked: true)]
    #expect(
      ArborEvent.changes(from: old, to: new) == [
        change(.floated, window(101, on: side)), change(.docked, window(102, on: side, docked: true)),
      ])
  }

  @Test func aWindowsStateIsNews() {
    var old = running()
    old.windows = [window(101, docked: true), window(102, docked: true), window(103)]
    var new = running()
    new.windows = [window(101, docked: true), window(102, docked: true, state: .outOfView), window(103, docked: true, state: .tile)]
    #expect(
      ArborEvent.changes(from: old, to: new) == [
        change(.state, window(102, docked: true, state: .outOfView)),
        change(.docked, window(103, docked: true, state: .tile)), change(.state, window(103, docked: true, state: .tile)),
      ])
  }

  @Test func onlyTheDisplaysThatChangedAreReported() {
    var old = running()
    old.views = [view(1, .window), view(0, .everything, on: side)]
    old.layouts = [
      ArborEvent.Arrangement(display: main, docked: 1, floating: 0, tiles: 0, frames: [:]),
      ArborEvent.Arrangement(display: side, docked: 0, floating: 0, tiles: 0, frames: [:]),
    ]
    var new = old
    new.views[0] = view(2, .everything)
    new.layouts[1].floating = 1
    #expect(ArborEvent.changes(from: old, to: new) == [.layout(new.layouts[1]), .view(new.views[0])])
  }

  @Test func movedFramesCountAsAChangeOfLayout() {
    var new = full
    new.layouts[0].frames[WindowID(101)]?.width = 600
    #expect(ArborEvent.changes(from: full, to: new) == [.layout(new.layouts[0])])
  }

  @Test func startingReportsTheWholeStateAfterStarted() {
    #expect(
      ArborEvent.changes(from: ArborEvent.Summary(running: false, accessibility: false), to: full) == [
        .started, .displays(full.displays), change(.adopted, full.windows[0]), change(.docked, full.windows[0]),
        .layout(full.layouts[0]), .view(full.views[0]), .focus(full.focus),
      ], "the windows were there before Arbor was: adopted, not opened")
  }

  @Test func thatTheControllerStoppedDoesNotSayThatArborIsQuitting() {
    #expect(ArborEvent.changes(from: full, to: notRunning()).isEmpty, "the app says `quitting` when it is")
    #expect(ArborEvent.changes(from: notRunning(), to: notRunning()).isEmpty)
    #expect(ArborEvent.changes(from: ArborEvent.Summary(running: false, accessibility: false), to: notRunning()).isEmpty)
  }

  @Test func aPauseIsNotTheEndAndResumingReportsTheStateAfresh() {
    #expect(ArborEvent.changes(from: full, to: paused()) == [.paused])
    #expect(ArborEvent.changes(from: paused(), to: paused()).isEmpty)
    #expect(
      ArborEvent.changes(from: paused(), to: full) == [
        .resumed, .displays(full.displays), change(.adopted, full.windows[0]), change(.docked, full.windows[0]),
        .layout(full.layouts[0]), .view(full.views[0]), .focus(full.focus),
      ])
    #expect(ArborEvent.changes(from: paused(), to: notRunning()).isEmpty)
  }

  @Test func focusMovesAndGoesAway() {
    var old = running()
    old.focus = ArborEvent.Focus(window: WindowID(101), app: "Safari")
    var new = running()
    new.focus = ArborEvent.Focus(window: WindowID(102), app: "Notes")
    #expect(ArborEvent.changes(from: old, to: new) == [.focus(new.focus)])
    #expect(ArborEvent.changes(from: new, to: running()) == [.focus(ArborEvent.Focus())])
  }

  @Test func titlesAreGoneFromEverythingWithoutTitles() throws {
    #expect(samples[0].line.contains("Apple"))
    let plain = ArborEvent.hello(ArborEvent.Hello(version: "1", snapshot: full.withoutTitles)).line
    #expect(!plain.contains("Apple"))
    #expect(!plain.contains("title"))
  }

  @Test func aNewTitleIsAnEventOnlyWhereTitlesAreTold() {
    var new = full
    new.windows[0].title = "Swift.org"
    new.focus.title = "Swift.org"
    #expect(ArborEvent.changes(from: full, to: new) == [change(.title, new.windows[0]), .focus(new.focus)])
    #expect(ArborEvent.changes(from: full.withoutTitles, to: new.withoutTitles).isEmpty)
  }
}

@Suite struct ChangedSettingsTests {
  @Test func theKeysThatDifferAreNamed() {
    let old = Settings()
    #expect(old.keysThatDiffer(from: old).isEmpty)
    var new = old
    new.gap = 20
    #expect(new.keysThatDiffer(from: old) == ["gap"])
    #expect(old.keysThatDiffer(from: new) == ["gap"])
    new.rules = [AppRule(app: "com.apple.Terminal", action: .dock(.right))]
    new.excludedBundleIDs = ["com.apple.Music"]
    new.bindings = ["ctrl+opt+h": "dock left", "ctrl+opt+d": nil]
    new.tabsEnabled.toggle()
    #expect(new.keysThatDiffer(from: old) == ["bindings", "excludedBundleIDs", "gap", "rules", "tabsEnabled"])
  }

  @Test func theyAreTheNamesInSettingsJSON() throws {
    let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(Settings())) as? [String: Any]
    var new = Settings()
    new.minimumUsableWidth += 1
    new.windowEdgeFraction += 0.1
    #expect(new.keysThatDiffer(from: Settings()).count == 2)
    for key in new.keysThatDiffer(from: Settings()) { #expect(object?[key] != nil, "\(key)") }
  }
}

@Suite struct WatchCommandTests {
  @Test func watchParsesItsEventsAndTitles() throws {
    #expect(try Command.parse("watch") == .watch(WatchOptions()))
    #expect(try Command.parse("watch view focus") == .watch(WatchOptions(kinds: [.view, .focus])))
    #expect(try Command.parse("watch --titles") == .watch(WatchOptions(titles: true)))
    #expect(try Command.parse("WATCH Focus --TITLES view focus") == .watch(WatchOptions(kinds: [.view, .focus], titles: true)))
    #expect(try Command.parse("watch/layout") == .watch(WatchOptions(kinds: [.layout])), "as a URL path")
  }

  @Test func watchRoundTripsThroughItsText() throws {
    for text in ["watch", "watch --titles", "watch view focus", "watch window layout view --titles"] {
      #expect(try Command.parse(text).text == text)
    }
    #expect(try Command.parse("watch focus view focus").text == "watch view focus", "one order, no repeats")
  }

  @Test func anUnknownEventIsRefusedWithTheListOfEvents() {
    var message = ""
    do {
      _ = try Command.parse("watch views")
    } catch {
      message = "\(error)"
    }
    #expect(message.contains("`views`"))
    for kind in ArborEvent.Kind.allCases { #expect(message.contains(kind.rawValue)) }
    #expect(message.contains("--titles"))
  }

  @Test func watchIsAQuerySoItCannotBeBoundToAKeyOrOpenedAsAURL() throws {
    #expect(try Command.parse("watch view").isQuery)
    #expect(try !Command.parse("watch view").isAllowedFromURL)
  }

  @Test func aFilterNeverHoldsBackWhetherArborIsThere() {
    let everything = WatchOptions()
    let some = WatchOptions(kinds: [.view])
    for kind in ArborEvent.Kind.allCases {
      #expect(everything.includes(kind))
      #expect(some.includes(kind) == [.hello, .view, .quitting, .paused, .resumed].contains(kind), "\(kind)")
    }
  }
}
