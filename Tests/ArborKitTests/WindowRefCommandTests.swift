import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Commands that name windows by app, `focused` or `pointer` (F50, part 1), against the controller.
@Suite @MainActor struct WindowRefCommandTests {
  func w(_ id: UInt32) -> WindowID { WindowID(id) }

  /// 101 and 102 Safari, 103 Mail, 104 Terminal, 105 Slack; 102 was used after 101.
  func harness() -> Harness {
    let h = Harness()
    h.system.open(app: "Safari", bundleID: "com.apple.Safari")
    h.system.open(app: "Safari", bundleID: "com.apple.Safari")
    h.system.open(app: "Mail", bundleID: "com.apple.mail")
    h.system.open(app: "Terminal", bundleID: "com.apple.Terminal")
    h.system.open(app: "Slack", bundleID: "com.tinyspeck.slackmacgap")
    h.start()
    h.system.userFocus(w(101))
    h.system.userFocus(w(102))
    h.system.userFocus(w(105))
    return h
  }

  @Test func theExamplesOfTheSpecActOnTheMostRecentlyFocusedWindowOfTheApp() {
    let h = harness()
    #expect(h.run("dock com.apple.Terminal right").ok)
    #expect(h.workspace.tree.allWindows == [w(104)])
    #expect(h.run("dock Safari left").ok)
    #expect(h.workspace.tree.allWindows == [w(102), w(104)])
    #expect(h.run("dock Mail beside Safari bottom").ok)
    #expect(h.workspace.tree.allWindows == [w(102), w(103), w(104)])
    #expect(h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: w(103))!) == h.workspace.tree.parent(of: h.workspace.tree.leaf(containing: w(102))!))
    #expect(h.run("zoom Safari").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: w(102)))
    #expect(h.run("float Safari").ok)
    #expect(h.workspace.isFloating(w(102)))
    // Slack floats already: the plain command's own refusal, about the window that was found.
    #expect(h.run("float Slack") == h.run("float 105"))
  }

  @Test func whichWindowIsDecidedWhenTheCommandRuns() throws {
    let h = harness()
    let command = try Command.parse("dock Safari left")
    h.system.userFocus(w(101))
    #expect(h.controller.perform(command).ok)
    #expect(h.workspace.tree.allWindows == [w(101)])
  }

  @Test func namesAreAsForgivingAsInLayout() {
    let h = harness()
    #expect(h.run("dock SAFARI left").ok)
    #expect(h.run("dock slackmacgap right").ok)
    #expect(h.workspace.tree.allWindows == [w(102), w(105)])
    h.system.open(app: "Visual Studio Code", bundleID: "com.microsoft.VSCode")
    #expect(h.run("dock \"Visual Studio Code\" top").ok)
    #expect(h.workspace.isDocked(w(106)))
    #expect(h.run("float Code").ok)
    #expect(h.workspace.isFloating(w(106)))
  }

  @Test func anAppWithoutAWindowIsSaidSo() {
    let h = harness()
    let before = h.workspace
    for command in ["zoom Notes", "dock Notes left", "dock Safari beside Notes left", "dock Notes beside Safari left", "float Notes"] {
      let result = h.run(command)
      #expect(!result.ok)
      #expect(result.message == "no window of Notes; `windows` lists them", "\(command)")
    }
    #expect(h.workspace == before)
  }

  @Test func appsArborDoesNotArrangeHaveNoWindows() {
    let h = harness()
    h.run("exclude com.apple.mail")
    #expect(h.run("zoom Mail").message == "no window of Mail; `windows` lists them")
  }

  @Test func aWindowInViewIsPreferredToAMinimisedOne() {
    let h = harness()
    h.system.setMinimized(w(102), true)
    #expect(h.run("dock Safari left").ok)
    #expect(h.workspace.tree.allWindows == [w(101)])
  }

  @Test func focusedIsTheWindowWithTheKeyboard() {
    let h = harness()
    #expect(h.run("dock focused left").ok)
    #expect(h.workspace.tree.allWindows == [w(105)])
    // Named, it is idempotent, where the bare command undoes itself when pressed twice.
    for _ in 1...2 {
      #expect(h.run("zoom focused").ok)
      #expect(h.workspace.camera == h.workspace.tree.leaf(containing: w(105)))
    }
    h.system.focused = nil
    #expect(h.run("zoom focused").message == "no focused window")
  }

  /// For a moment after `focus Mail` macOS still reports the window before. `focused` is the window a command without a window acts on.
  @Test func focusedIsWhatACommandWithoutAWindowActsOn() {
    func floated(by line: String) -> [WindowID] {
      let h = harness()
      #expect(h.run("layout Safari | Mail | Terminal").ok)
      h.system.userFocus(w(102))
      h.system.focusIsSlow = true
      #expect(h.run("focus Mail").ok)
      #expect(h.system.focusedWindow() == w(102), "the set-up: macOS has not caught up")
      #expect(h.run(line).ok)
      return [w(102), w(103), w(104)].filter(h.workspace.isFloating)
    }
    #expect(floated(by: "float") == [w(103)])
    #expect(floated(by: "float focused") == [w(103)])
  }

  /// Like `zoom 999`, a command whose name means nothing is a command that failed: Go to… closes, and it is counted.
  @Test func aNameThatMeansNothingIsACommandThatFailed() {
    for line in ["zoom 999", "zoom Nobody"] {
      let h = harness()
      #expect(h.run("find").ok && h.overlays.finder != nil)
      #expect(!h.run(line).ok)
      #expect(h.overlays.finder == nil, "\(line) leaves Go to… open")
      #expect(h.run("stats").text?.contains("zoom") == true, "\(line) is not counted")
    }
  }

  @Test func pointerIsTheWindowUnderThePointer() {
    let h = harness()
    h.run("layout Safari | Mail | Desktop")
    h.system.cursor = CGPoint(x: 100, y: 400)
    #expect(h.run("zoom pointer").ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: w(102)))
    h.run("show-all")
    h.system.cursor = CGPoint(x: 700, y: 400)
    #expect(h.run("float pointer").ok)
    #expect(h.workspace.isFloating(w(103)))
  }

  @Test func aFloatingWindowIsAboveTheDockedOneUnderIt() {
    let h = harness()
    h.run("layout Safari | Desktop")
    h.system.userMove(w(104), to: CGRect(x: 50, y: 100, width: 300, height: 200))
    h.system.userMove(w(103), to: CGRect(x: 60, y: 110, width: 300, height: 200))
    h.system.userFocus(w(103))
    h.system.userFocus(w(102))
    h.system.cursor = CGPoint(x: 100, y: 150)
    #expect(h.run("dock pointer right").ok)
    #expect(h.workspace.isDocked(w(103)) && h.workspace.isFloating(w(104)))
  }

  @Test func noWindowUnderThePointerIsSaidSo() {
    let h = harness()
    h.run("layout Safari | Desktop")
    h.run("zoom Safari")
    // The others are out of view, wherever their frames are.
    h.system.cursor = CGPoint(x: 1439, y: 899)
    h.run("desktop")
    h.system.cursor = CGPoint(x: 5, y: 30)
    #expect(h.run("zoom pointer").message == "no window under the pointer")
  }

  @Test func beforeArborRunsAndWhilePausedItSaysSo() {
    let h = Harness()
    h.system.open(app: "Safari")
    #expect(h.run("zoom Safari").message == "starting")
    h.start()
    h.run("pause")
    #expect(h.run("zoom Safari").message.hasPrefix("paused"))
  }

  // MARK: The keyboard's tiling tools (F22)

  /// A name does what the number of the window it finds does: the same reply, the same arrangement, the same keyboard.
  @Test(arguments: [
    ("swap Safari Mail", "swap 102 103"), ("swap Mail Safari", "swap 103 102"), ("swap Safari right", "swap 102 right"), ("swap Terminal left", "swap 104 left"),
    ("swap focused Mail", "swap 105 103"), ("swap com.apple.mail terminal", "swap 103 104"), ("focus Safari", "focus 102"), ("focus Mail", "focus 103"),
    ("focus com.apple.Terminal", "focus 104"), ("focus \"Terminal\"", "focus 104"), ("move-to-display next Safari", "move-to-display next 102"),
    ("move-to-display 2 Mail", "move-to-display 2 103"), ("move-to-display previous Slack", "move-to-display previous 105"),
  ]) func theTilingToolsTakeNames(named: String, numbered: String) {
    func after(_ line: String) -> (reply: CommandResult, trees: [DisplayID: LayoutTree], floating: [DisplayID: [WindowID]], keyboard: WindowID?) {
      let side = DisplaySnapshot(
        id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
        visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
      let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
      for (app, bundle) in [("Safari", "com.apple.Safari"), ("Safari", "com.apple.Safari"), ("Mail", "com.apple.mail"), ("Terminal", "com.apple.Terminal"), ("Slack", "com.tinyspeck.slackmacgap")] {
        h.system.open(app: app, bundleID: bundle)
      }
      h.start()
      for id: UInt32 in [101, 102] { h.system.userFocus(w(id)) }
      #expect(h.run("layout 102 | (103 / 104) | 105").ok)
      h.system.userFocus(w(105))
      let reply = h.run(line)
      return (reply, h.controller.workspaces.mapValues(\.tree), h.controller.workspaces.mapValues { $0.floating.keys.sorted() }, h.system.focusedWindow())
    }
    let (a, b, untouched) = (after(named), after(numbered), after("status"))
    #expect(b.reply.ok, "\(numbered): \(b.reply.message)")
    #expect(a.reply.ok == b.reply.ok && a.reply.message == b.reply.message, "\(named): \(a.reply.message); \(numbered): \(b.reply.message)")
    #expect(a.trees == b.trees && a.floating == b.floating && a.keyboard == b.keyboard, "\(named) and \(numbered) part ways")
    #expect(b.trees != untouched.trees || b.floating != untouched.floating || b.keyboard != untouched.keyboard, "\(numbered) does something, or this shows nothing")
  }

  @Test func theTilingToolsSayWhenNoWindowAnswersToTheName() {
    let h = harness()
    for line in ["focus Nobody", "swap Nobody Mail", "swap Mail Nobody", "swap Nobody left", "move-to-display next Nobody", "focus sideways"] {
      let before = h.workspace
      let reply = h.run(line)
      #expect(!reply.ok && reply.message.contains(line.contains("sideways") ? "sideways" : "Nobody"), "\(line): \(reply.message)")
      #expect(h.workspace == before, "\(line)")
    }
  }

  /// What `focus` has words of its own for keeps its meaning; in quotes it is a name.
  @Test func focusKeepsItsOwnWords() throws {
    #expect(try Command.parse("focus next") == .focus(.next))
    #expect(try Command.parse("focus LEFT") == .focus(.direction(.left)))
    #expect(try Command.parse("focus w7") == .focus(.window(w(7))))
    for word in ["next", "left", "7"] {
      guard case .naming(_, let names) = try Command.parse("focus \"\(word)\"") else { Issue.record("focus \"\(word)\" is not a name"); continue }
      #expect(names == [.app(word)])
    }
    let named = try Command.parse("focus Safari")
    #expect(named.text == "focus Safari")
    #expect(try Command.parse(named.text) == named)
    #expect(named.filling([w(7)]) == .focus(.window(w(7))))
    #expect(try Command.parse(url: "arbor://focus/Safari").isAllowedFromURL == Command.focus(.window(w(7))).isAllowedFromURL)
  }

  // MARK: A name is the number it stands for, whoever asks about the command

  /// While the view is held (F58) a command may run or not, and its windows must be in view. That is asked about the window, not the name.
  @Test(arguments: [
    ("resize Mail bottom 40", "resize 103 bottom 40"), ("float Mail", "float 103"), ("toggle-float Terminal", "toggle-float 104"),
    ("dock Mail beside Terminal right", "dock 103 beside 104 right"), ("float Safari", "float 102"), ("dock Safari left", "dock 102 left"),
    ("dock Mail beside Slack right", "dock 103 beside 105 right"), ("zoom Mail", "zoom 103"), ("zoom Safari", "zoom 102"), ("focus Safari", "focus 102"),
    ("focus Terminal", "focus 104"), ("swap Mail Terminal", "swap 103 104"), ("swap Mail Safari", "swap 103 102"), ("pin Mail", "pin 103"),
  ]) func onAHeldViewANameIsTreatedLikeItsNumber(named: String, numbered: String) {
    func after(_ line: String) -> (reply: CommandResult, workspace: Workspace, keyboard: WindowID?) {
      let h = harness()
      // Mail over Terminal fill the view; Safari and Slack are out of it.
      for step in ["layout 102 | (103 / 104) | 105", "zoom 103", "out", "hold"] { #expect(h.run(step).ok, "\(step)") }
      h.system.userFocus(w(103))
      let reply = h.run(line)
      return (reply, h.workspace, h.system.focusedWindow())
    }
    let (a, b) = (after(named), after(numbered))
    #expect(a.reply.ok == b.reply.ok && a.reply.message == b.reply.message, "\(named): \(a.reply.message); \(numbered): \(b.reply.message)")
    #expect(a.workspace == b.workspace && a.keyboard == b.keyboard, "\(named) and \(numbered) part ways")
  }

  /// So that the pairs above show something: both answers occur, and each for its reason.
  @Test func onAHeldViewBothAnswersOccur() {
    let h = harness()
    for step in ["layout 102 | (103 / 104) | 105", "zoom 103", "out", "hold"] { #expect(h.run(step).ok, "\(step)") }
    #expect(h.run("resize Mail bottom 40").ok, "allowed, and in view")
    #expect(h.run("float Safari").message.hasPrefix("w102 is out of view, and "), "allowed, and out of view")
    let moves = h.run("zoom Mail")
    #expect(!moves.ok && !moves.message.contains("out of view"), "moves the view: \(moves.message)")
    #expect(h.run("float Nobody").message == "no window of Nobody; `windows` lists them")
  }

  /// Someone who pressed a key is answered on screen (F43). What the line says, whether there is one, and on which display it stands
  /// are decided by the command and its window: for a name, by the window it stands for.
  @Test(arguments: [
    ("pin Slack", "pin 105"), ("toggle-pin Slack", "toggle-pin 105"), ("zoom Mail", "zoom 103"), ("float Mail", "float 103"), ("float Slack", "float 105"),
    ("dock Slack right", "dock 105 right"), ("zoom Notes", "zoom 106"), ("float Notes", "float 106"), ("pin Notes", "pin 106"), ("dock Notes left", "dock 106 left"),
    ("zoom focused", "zoom 103"), ("swap Mail Terminal", "swap 103 104"), ("focus Terminal", "focus 104"),
  ]) func aShortcutIsAnsweredOnScreenAsForTheNumber(named: String, numbered: String) throws {
    func after(_ line: String) throws -> (reply: CommandResult, said: [DisplayID: HeadsUpModel]) {
      let side = DisplaySnapshot(
        id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
        visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
      let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
      for (app, bundle) in [("Safari", "com.apple.Safari"), ("Safari", "com.apple.Safari"), ("Mail", "com.apple.mail"), ("Terminal", "com.apple.Terminal"), ("Slack", "com.tinyspeck.slackmacgap")] {
        h.system.open(app: app, bundleID: bundle)
      }
      // On the other display, where the keyboard and the pointer are not.
      h.system.open(app: "Notes", bundleID: "com.apple.Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
      h.start()
      #expect(h.run("layout 102 | (103 / 104)").ok)
      h.system.userFocus(w(103))
      h.scheduler.advance(by: 10)
      let reply = h.controller.perform(try Command.parse(line), from: .shortcut)
      return (reply, h.overlays.headsUp)
    }
    let (a, b) = (try after(named), try after(numbered))
    #expect(a.reply.ok == b.reply.ok && a.reply.message == b.reply.message, "\(named): \(a.reply.message); \(numbered): \(b.reply.message)")
    #expect(a.said == b.said, "\(named) is answered \(a.said), \(numbered) \(b.said)")
  }

  /// So that the pairs above show something: a line where nothing is to be seen, and a line on the window's display.
  @Test func aShortcutsAnswersAreNotAllAlike() throws {
    var answers: [String: [DisplayID: HeadsUpModel]] = [:]
    for line in ["pin Slack", "zoom Mail", "pin Notes"] {
      let side = DisplaySnapshot(
        id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
        visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
      let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
      for app in ["Safari", "Safari", "Mail", "Terminal", "Slack"] { h.system.open(app: app) }
      h.system.open(app: "Notes", frame: CGRect(x: 1600, y: 100, width: 600, height: 400))
      h.start()
      #expect(h.run("layout 102 | (103 / 104)").ok)
      h.system.userFocus(w(103))
      h.scheduler.advance(by: 10)
      #expect(h.controller.perform(try Command.parse(line), from: .shortcut).ok, "\(line)")
      answers[line] = h.overlays.headsUp
    }
    func said(_ line: String) -> [String] { (answers[line] ?? [:]).map { "\($0.key.rawValue): \($0.value.kind) \($0.value.text)" } }
    #expect(said("pin Slack") == ["main: change Keeping Slack in view"], "a pin shows only when the view next moves, so it is said")
    #expect(said("pin Notes") == ["side: change Keeping Notes in view"], "where the window is, not where the keyboard is")
    #expect(said("zoom Mail") == ["main: hint Your other windows are out of view, not closed"], "what can be seen is not said; this is Arbor teaching")
  }

  /// One keystroke is one command: from whom it came, and in a trace, which replays to the same end.
  @Test func aNamedCommandIsOneCommandInATrace() throws {
    let h = harness()
    #expect(h.run("layout 102 | 103 | 104").ok)
    h.scheduler.advance(by: 2)
    h.run("trace on names")
    #expect(h.controller.perform(try Command.parse("zoom Safari"), from: .shortcut).ok)
    h.scheduler.advance(by: 2)
    #expect(h.controller.perform(try Command.parse("swap Mail Terminal"), from: .script).ok)
    h.scheduler.advance(by: 2)
    h.run("trace off")
    let text = try #require(h.lastTrace)
    #expect(text.contains("zoom Safari") && text.contains("swap Mail Terminal"))
    #expect(!text.contains("zoom 102") && !text.contains("swap 103 104"), "the command the name stands for is not a second one")
    for mode in [TraceReplayer.Mode.strict, .free] {
      let replayer = TraceReplayer(recordedTrace(h), mode: mode)
      #expect(replayer.run().problems == [], "\(mode)")
      #expect(replayer.harness.controller.workspaces == h.controller.workspaces, "\(mode)")
    }
  }

  /// Down to every question Arbor asks macOS and everything it tells it: the trace of a name is the trace of its number, but for the
  /// command's own words and ONE question more, which is the looking up (who has the keyboard? its windows come first).
  /// (While the line on screen was decided by the wrapper, Arbor also had to ask where the person was, because it could not see the
  /// window: two reads more, and a strict replay parted from the recording.)
  @Test(arguments: [
    ("zoom Safari", "zoom 102", CommandSource.shortcut), ("zoom Safari", "zoom 102", .script), ("zoom Safari", "zoom 102", .menu), ("pin Slack", "pin 105", .shortcut),
    ("float Mail", "float 103", .shortcut), ("swap Mail Terminal", "swap 103 104", .shortcut), ("focus Terminal", "focus 104", .shortcut),
    ("dock Slack beside Mail bottom", "dock 105 beside 103 bottom", .shortcut), ("resize Mail right 40", "resize 103 right 40", .url),
  ]) func theTraceOfANameIsTheTraceOfItsNumber(named: String, numbered: String, source: CommandSource) throws {
    func trace(of line: String) throws -> [Substring] {
      let h = harness()
      #expect(h.run("layout 102 | 103 | 104").ok)
      h.scheduler.advance(by: 2)
      h.run("trace on names")
      #expect(h.controller.perform(try Command.parse(line), from: source).ok, "\(line)")
      h.scheduler.advance(by: 2)
      h.run("trace off")
      // Without the header, which holds the time of day, and the last line, which counts the lines.
      return try #require(h.lastTrace).replacingOccurrences(of: line, with: "<the command>").split(separator: "\n").dropFirst().dropLast().map { $0 }
    }
    var (a, b) = (try trace(of: named), try trace(of: numbered))
    #expect(b.count > 3 && b.contains { $0.contains("<the command>") })
    let parting = try #require(zip(a, b).enumerated().first { $0.element.0 != $0.element.1 }?.offset, "the looking up asks nothing?")
    #expect(a[parting].contains(#""call":"focusedWindow""#), "\(a[parting])")
    a.remove(at: parting)
    #expect(a == b, "they part again at line \((zip(a, b).enumerated().first { $0.element.0 != $0.element.1 }?.offset ?? min(a.count, b.count)) + 2)")
  }

  /// A link may never do more with a name than with the number. `focus <window>` is off the list on purpose: a page must not pick the
  /// window the keyboard types into. By an app's name it could aim, so with one it may not `zoom` or `dock` either, which also give
  /// the window the keyboard; `focused` and `pointer` are the person's own choice.
  @Test func aLinkMayDoNoMoreWithANameThanWithTheNumber() {
    let h = harness()
    func refusal(_ path: String) -> String? { if case .failure(let error) = h.controller.admit(url: "arbor://\(path)") { error.description } else { nil } }
    func admitted(_ path: String) -> Bool { refusal(path) == nil }
    for (named, numbered) in [
      ("focus/Safari", "focus/102"), ("focus/com.apple.Terminal", "focus/104"), ("focus/focused", "focus/105"), ("swap/Safari/left", "swap/102/left"),
      ("swap/Safari/Mail", "swap/102/103"), ("move-to-display/next/Safari", "move-to-display/next/102"), ("zoom/Safari", "zoom/102"),
      ("reveal/Safari", "reveal/102"), ("dock/Mail/left", "dock/103/left"), ("summon/Safari", "summon/com.apple.Safari"), ("zoom/pointer", "zoom/102"),
      ("dock/focused/left", "dock/105/left"), ("reveal/pointer", "reveal/102"),
    ] {
      #expect(!admitted(named) || admitted(numbered), "\(named) and \(numbered)")
    }
    #expect(!admitted("focus/Safari") && !admitted("focus/com.apple.Terminal") && !admitted("focus/412") && !admitted("focus/pointer"))
    #expect(admitted("focus/left") && admitted("focus/next") && admitted("swap/left") && admitted("zoom/102") && admitted("dock/103/left"))
    #expect(admitted("zoom/pointer") && admitted("zoom/focused") && admitted("dock/focused/left") && admitted("float/pointer"))
    #expect(!admitted("move-to-display/next/Safari") && !admitted("reveal/Safari"))
    for path in ["zoom/Terminal", "zoom/com.apple.Terminal", "dock/Terminal/left", "dock/pointer/beside/Terminal/left", "float/Terminal", "pin/Terminal"] {
      let verb = path.prefix { $0 != "/" }
      #expect(refusal(path) == "`\(verb) <app>` is not accepted from URLs; set allowAllURLCommands to true in settings.json to allow it", "\(path)")
    }
    // The keyboard stays where it is.
    #expect(h.system.focusedWindow() == w(105))
  }

  @Test func theSettingLetsALinkNameAnApp() throws {
    var settings = Settings()
    settings.allowAllURLCommands = true
    let h = harness()
    h.controller.apply(settings: settings)
    h.run("dock Safari left")
    #expect(h.controller.perform(try h.controller.admit(url: "arbor://zoom/com.apple.Safari").get(), from: .url).ok)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: w(102)))
  }

  @Test func aShortcutCanNameAnApp() throws {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+s": "zoom Safari", "ctrl+opt+v": "zoom 'Visual Studio Code'"]
    let (bindings, problems) = KeyBindings.effective(settings: settings)
    #expect(problems.isEmpty)
    #expect(bindings.contains { $0.command.text == "zoom Safari" })
    #expect(bindings.contains { $0.command.text == "zoom \"Visual Studio Code\"" })
  }

  @Test func noCombinationOfNamesCrashes() {
    let h = harness()
    h.run("layout Safari | (Mail / Terminal)")
    let words = ["Safari", "Mail", "Nothing", "focused", "pointer", "101", "999", "\"left\"", "com.apple.mail", "left", "beside", "top", "50", "-50", "1e9"]
    for verb in ["zoom", "dock", "float", "toggle-float", "resize"] {
      for a in words {
        h.run("\(verb) \(a)")
        for b in words {
          h.run("\(verb) \(a) \(b)")
          for c in words.prefix(7) {
            h.run("\(verb) \(a) \(b) \(c)")
            h.run("\(verb) \(a) beside \(b) \(c)")
          }
        }
      }
    }
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    #expect(Set(h.workspace.allWindows) == Set(h.system.windows.keys))
  }

  // MARK: Lists of apps

  /// Those lists hold bundle ids. A name put on one as it stands matches nothing, and the reply said that it had worked.
  @Test func excludeAndIncludeTakeAnAppsName() {
    let h = Harness()
    let terminal = h.system.open(app: "Terminal", bundleID: "com.apple.Terminal")
    h.system.open(app: "Safari", bundleID: "com.apple.Safari")
    h.start()
    #expect(h.run("exclude Terminal").message == "no longer arranging Terminal")
    #expect(h.controller.settings.excludedBundleIDs == ["com.apple.Terminal"])
    #expect(h.run("state").state?.window(terminal)?.managed == false, "and it is so")
    #expect(h.run("exclude terminal").message == "Arbor does not arrange Terminal already")
    #expect(h.run("exclude COM.APPLE.TERMINAL").message == "Arbor does not arrange Terminal already", "one spelling on the list")
    // Its windows are no longer arranged; its name still finds it.
    #expect(h.run("include Terminal").message == "arranging Terminal again")
    #expect(h.controller.settings.excludedBundleIDs.isEmpty && h.run("state").state?.window(terminal)?.managed == true)
  }

  @Test func anAppThatIsNotOpenGoesByItsBundleID() {
    let h = Harness()
    h.system.open(app: "Safari", bundleID: "com.apple.Safari")
    h.start()
    for command in ["exclude Terminal", "include Terminal", "pass-through Terminal", "pass-through Terminal on"] {
      let refused = h.run(command)
      #expect(!refused.ok, "\(command)")
      #expect(refused.message == "no app called Terminal has a window open; open one, or name it by its bundle id, like com.apple.Terminal", "\(command)")
    }
    #expect(h.controller.settings.excludedBundleIDs.isEmpty && h.controller.settings.passThroughApps.isEmpty, "nothing was listed")
    #expect(h.run("exclude com.apple.Terminal").ok && h.controller.settings.excludedBundleIDs == ["com.apple.Terminal"])
    // Once it is listed its name is enough, open or not: the last part of a bundle id.
    #expect(h.run("include Terminal").message == "arranging com.apple.Terminal again")
  }

  @Test func passThroughTakesAnAppsName() {
    let h = Harness()
    h.system.open(app: "Emacs", bundleID: "org.gnu.Emacs")
    h.start()
    #expect(h.run("pass-through Emacs on").ok)
    #expect(h.controller.settings.passThroughApps == ["org.gnu.Emacs"])
    #expect(h.run("pass-through emacs off").ok)
    #expect(h.controller.settings.passThroughApps.isEmpty)
  }

  @Test func aNameThatTwoAppsAnswerToIsNotGuessedAt() {
    let h = Harness()
    h.system.open(app: "Code", bundleID: "com.a.Code")
    h.system.open(app: "Code", bundleID: "com.b.Code")
    h.start()
    let refused = h.run("exclude Code")
    #expect(!refused.ok && refused.message == "Code could be com.a.Code or com.b.Code; say which")
    #expect(h.controller.settings.excludedBundleIDs.isEmpty)
    #expect(h.run("exclude com.b.Code").ok && h.controller.settings.excludedBundleIDs == ["com.b.Code"])
  }
}
