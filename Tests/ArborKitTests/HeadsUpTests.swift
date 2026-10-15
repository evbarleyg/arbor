import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

private let side = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1000, height: 800),
  visibleFrame: CGRect(x: 1440, y: 25, width: 1000, height: 775), isMain: false)

/// Saying what happened (docs/features/F43-say-what-happened.md): the heads-up line as the controller shows it.
@Suite @MainActor struct HeadsUpTests {
  private func settings(_ change: (inout Settings) -> Void) -> Settings {
    var settings = Settings()
    change(&settings)
    return settings
  }

  /// Safari, Mail and Notes, floating. Hints are out of the way unless a test asks for them.
  private func makeHarness(
    settings: Settings = Settings(), displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay], taught: Bool = true
  ) -> (Harness, WindowID, WindowID, WindowID) {
    var saved = PersistedState(workspaces: [:], hints: [:])
    if taught { for hint in HeadsUpHint.allCases { saved.hintsShown[hint.rawValue] = HeadsUpHint.timesShown } }
    let h = Harness(displays: displays, settings: settings, saved: saved)
    let a = h.system.open(app: "Safari", title: "Secret plans")
    let b = h.system.open(app: "Mail", title: "Re: salary")
    let c = h.system.open(app: "Notes", title: "Diary")
    h.start()
    h.system.userFocus(a)
    return (h, a, b, c)
  }

  private func lines(_ h: Harness) -> [String] { h.overlays.messages.map(\.model.line) }

  // MARK: Acceptance 1: who is answered, and where

  @Test func aFailingShortcutIsExplainedOnTheDisplayItActedOn() {
    let (h, _, _, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.cursor = CGPoint(x: 2000, y: 400)

    #expect(!h.run("out", from: .shortcut).ok)

    #expect(h.overlays.messages.count == 1)
    #expect(h.overlays.messages[0].display == side.id)
    let model = h.overlays.messages[0].model
    #expect(model.kind == .problem)
    #expect(model.text == "Already showing everything", "which display is what the line's place says")
    #expect(side.visibleFrame.contains(model.anchor))
    #expect(model.anchor.x == side.visibleFrame.midX)
  }

  @Test func aShortcutIsAnsweredWhereTheKeyboardIsAndAPinchWhereThePointerIs() {
    let (h, a, _, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.cursor = CGPoint(x: 2000, y: 400)  // the pointer was left on the other display…
    h.scheduler.advance(by: 5)
    h.system.userFocus(a)
    h.system.type()  // …and the user is typing on this one (F56)

    h.press("out")
    #expect(h.overlays.messages.last?.display == h.display)
    h.run("out", from: .gesture)
    #expect(h.overlays.messages.last?.display == side.id)
  }

  /// F58: what an audience sees stays as it is. A key that does nothing is still explained, or it would seem dead.
  @Test(arguments: ["hold", "hold still"]) func duringAHoldOnlyWhatFailedIsSaid(hold: String) {
    let (h, a, b, _) = makeHarness(settings: settings { $0.messages = "all" }, taught: false)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run(hold)
    let before = h.overlays.messages.count
    // Rearranging what is in view is allowed by both, and at this level it would be answered, and taught.
    #expect(h.run("dock \(a.rawValue) right", from: .shortcut).ok)
    #expect(h.overlays.messages.count == before, "neither a reply nor a hint: \(lines(h).suffix(1))")
    #expect(!h.run("zoom 999", from: .shortcut).ok)
    #expect(h.overlays.messages.count == before + 1)
    #expect(h.overlays.messages.last?.model.kind == .problem)
    // The control: once released, the same success is answered.
    h.run("release")
    let released = h.overlays.messages.count
    #expect(h.run("dock \(a.rawValue) left", from: .shortcut).ok)
    #expect(h.overlays.messages.count == released + 1)
  }

  @Test func aHoldTakesAwayWhatWasSaidBeforeItBegan() {
    // By command, and by itself when a call's window opens.
    let begin: [(String, (Harness) -> Void)] = [
      ("hold", { $0.run("hold") }), ("hold still", { $0.run("hold still") }),
      ("a call", { $0.system.open(app: "Zoom", bundleID: "us.zoom.xos", title: "Zoom Meeting") }),
    ]
    for (name, begin) in begin {
      let (h, _, _, _) = makeHarness(settings: settings { $0.holdStillFor = ["us.zoom.xos Zoom Meeting"] })
      h.run("arrange")
      h.run("save-view 1", from: .shortcut)
      #expect(h.overlays.headsUp.count == 1, "or this proves nothing")
      begin(h)
      #expect(h.controller.isHeld, "\(name)")
      #expect(h.overlays.headsUp.isEmpty, "\(name)")
      #expect(!h.scheduler.pendingKeys.contains("heads-up"), "\(name)")
    }
  }

  @Test func whatHoldingStillTurnsAwayIsSaidOncePerAppAndHold() {
    let (h, a, b, c) = makeHarness()
    h.run("arrange")
    h.run("zoom \(a.rawValue)")
    h.run("hold still")

    h.system.comesForward(c)
    #expect(h.system.focused == a, "or this proves nothing")
    #expect(lines(h) == ["Notes is out of view: holding still · ⌘Tab or ⌃⌥G goes there"])
    #expect(h.overlays.messages.last?.model.kind == .problem, "which is what may be said during a hold")
    h.scheduler.advance(by: 10)
    h.system.comesForward(c)
    #expect(h.overlays.messages.count == 1, "once per app")
    h.system.comesForward(b)
    #expect(lines(h).last == "Mail is out of view: holding still · ⌘Tab or ⌃⌥G goes there")

    h.run("release")
    h.run("hold still")
    h.scheduler.advance(by: 10)
    h.system.comesForward(c)
    #expect(h.overlays.messages.count == 3, "and hold")
  }

  @Test func aHeldViewTurnsAwayInSilenceAndSoDoesWhoeverSwitchedTheLineOff() {
    for (hold, messages) in [("hold", "helpful"), ("hold still", "off")] {
      let (h, a, _, c) = makeHarness(settings: settings { $0.messages = messages })
      h.run("arrange")
      h.run("zoom \(a.rawValue)")
      h.run(hold)
      h.system.comesForward(c)
      #expect(h.system.focused == a, "or this proves nothing")
      #expect(h.overlays.messages.isEmpty, "\(hold), \(messages)")
    }
  }

  @Test func whyAKeyDidNothingOutlivesTheBeginningOfAHold() {
    let (h, _, _, _) = makeHarness()
    h.run("arrange")
    h.run("out", from: .shortcut)
    h.run("hold still")
    #expect(h.overlays.headsUp[h.display]?.line == "Already showing everything")
  }

  @Test func aKeyThatAHeldViewRefusesIsExplainedInFewWords() {
    let (h, _, _, _) = makeHarness()
    h.run("arrange")
    h.run("hold")
    #expect(!h.run("out", from: .shortcut).ok)
    #expect(lines(h).last == "The view is held · ⌃⌥⎋ releases it")
    #expect(h.overlays.messages.last?.model.kind == .problem)

    let (own, _, _, _) = makeHarness(settings: settings { $0.bindings = ["ctrl+opt+escape": nil, "ctrl+opt+h": "toggle-hold"] })
    own.run("arrange")
    own.run("hold")
    own.run("out", from: .shortcut)
    #expect(lines(own).last == "The view is held · ⌃⌥H releases it")

    let (none, _, _, _) = makeHarness(settings: settings { $0.bindings = ["ctrl+opt+escape": nil] })
    none.run("arrange")
    none.run("hold")
    none.run("out", from: .menu)
    #expect(lines(none).last == "The view is held · Release it from Arbor’s menu")
  }

  @Test func aReplyThatEndsInTheHeldMessageEndsInTheSameFewWords() {
    let (h, a, _, _) = makeHarness()
    h.run("arrange")
    h.run("zoom \(a.rawValue)")
    h.run("hold")
    #expect(h.run("dock left", from: .shortcut).message.hasSuffix("or with `release`"), "or this proves nothing")
    #expect(lines(h).last == "Safari fills the view, and the view is held · ⌃⌥⎋ releases it")
    #expect(h.overlays.messages.last?.model.kind == .problem)
    #expect(h.controller.headsUp.logged == lines(h).last)
  }

  @Test func lettingGoOfAHoldIsConfirmedAndItsBeginningIsNot() {
    let (h, _, _, _) = makeHarness()
    h.run("arrange")
    h.run("toggle-hold", from: .menu)
    #expect(h.overlays.messages.isEmpty)
    h.run("toggle-hold", from: .menu)
    #expect(lines(h) == ["Released"])
    #expect(h.overlays.messages.last?.model.kind == .change)
  }

  @Test func goToIsItsOwnAnswerAndGoingSomewhereIsNot() {
    let (h, _, b, _) = makeHarness(settings: settings { $0.messages = "all" })
    h.run("arrange")
    #expect(h.run("find", from: .shortcut).ok)
    #expect(h.run("find", from: .shortcut).ok)
    #expect(h.overlays.messages.isEmpty, "\(lines(h))")
    h.run("zoom \(b.rawValue)")
    #expect(h.run("find Safari", from: .shortcut).ok)
    #expect(h.overlays.messages.count == 1)
  }

  @Test func theSameCommandFromAScriptIsAnsweredOnlyInItsReply() {
    let (h, _, _, _) = makeHarness()
    #expect(h.run("out").message == "already showing everything")
    #expect(h.controller.perform(.stepOut).ok == false)
    #expect(!h.run("out", from: .url).ok, "nor can a web page put words on the screen")
    #expect(h.overlays.messages.isEmpty)
  }

  @Test(arguments: [CommandSource.gesture, .menu])
  func gesturesAndTheMenuAreAnsweredLikeShortcuts(source: CommandSource) {
    let (h, _, _, _) = makeHarness()
    h.run("out", from: source)
    #expect(lines(h) == ["Already showing everything"])
  }

  @Test func aCommandOnAWindowIsAnsweredOnTheWindowsDisplay() {
    let (h, a, _, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.system.cursor = CGPoint(x: 2000, y: 400)  // the pointer was left on the other display

    h.run("dock left", from: .shortcut)

    #expect(lines(h) == ["Safari fills the view; step out first"])
    #expect(h.overlays.messages[0].display == h.display)
  }

  @Test func theReplyIsTheSameWhoeverAsked() {
    let (h, _, _, _) = makeHarness()
    #expect(h.run("in", from: .shortcut) == h.run("in"))
  }

  // MARK: What earns a line

  @Test func routineSuccessesStaySilent() {
    let (h, a, b, _) = makeHarness()
    for text in ["dock left", "zoom", "out", "desktop", "show-all", "zoom", "home", "back", "forward", "toggle-float", "arrange"] {
      #expect(h.run(text, from: .shortcut).ok, "\(text)")
      #expect(lines(h) == [], "\(text)")
    }
    _ = (a, b)
  }

  @Test func aSuccessThatLeftEverythingAsItWasIsSaidBecauseItLooksLikeADeadKey() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    for text in ["show-all", "home", "relayout"] { h.run(text, from: .shortcut) }
    #expect(lines(h) == ["Showing everything", "Showing everything", "Laid out again"])
    #expect(h.overlays.messages.allSatisfy { $0.model.kind == .change })
    h.run("show-all")
    #expect(h.overlays.messages.count == 3, "a script reads its reply")
  }

  @Test func theFrameShortcutOnAFloatingWindowSaysWhatToDoFirst() {
    let (h, _, _, _) = makeHarness()
    #expect(h.run("zoom", from: .shortcut).ok)
    #expect(lines(h) == ["Safari floats · ⌃⌥⌘← docks it, then ⌃⌥↩ frames it"])

    let (bare, _, _, _) = makeHarness(settings: settings { $0.bindings = ["ctrl+opt+cmd+left": nil] })
    bare.run("zoom", from: .menu)
    #expect(lines(bare) == ["Safari floats"])
  }

  @Test func anAppArborDoesNotArrangeIsCalledThatAndByItsName() {
    let (h, _, _, _) = makeHarness()
    h.run("exclude", from: .menu)
    h.run("dock left", from: .shortcut)
    h.run("zoom", from: .shortcut)
    h.run("include com.example.safari", from: .menu)
    #expect(
      lines(h) == [
        "No longer arranging Safari", "Arbor does not arrange Safari · Arrangement → Arrange Again in the menu",
        "Arbor does not arrange Safari · Arrangement → Arrange Again in the menu", "Arranging Safari again",
      ])
    #expect(h.overlays.messages.map(\.model.kind) == [.change, .problem, .problem, .change])
  }

  @Test func whatChangedUnseenIsSaid() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.run("save-view 2", from: .shortcut)
    h.run("show-all")
    h.run("float-all", from: .shortcut)
    h.run("exclude", from: .menu)
    h.run("include com.example.safari", from: .menu)
    #expect(
      lines(h) == [
        "Saved view 2: Safari", "Floated 1 window; 1 saved view is gone · ⌃⌥Z takes it back", "No longer arranging Safari",
        "Arranging Safari again",
      ])
    #expect(h.overlays.messages.allSatisfy { $0.model.kind == .change })
  }

  // MARK: Acceptance 3: the setting

  @Test func offSaysNothing() {
    let (h, _, _, _) = makeHarness(settings: settings { $0.messages = "off" }, taught: false)
    for text in ["out", "dock left", "zoom", "save-view 1", "toggle-pause", "toggle-pause"] { h.run(text, from: .shortcut) }
    #expect(h.overlays.messages.isEmpty)
    #expect(h.store.saved?.hintsShown.isEmpty != false, "and a hint nobody saw does not count as shown")
  }

  @Test func allSaysEveryReply() {
    let (h, _, _, _) = makeHarness(settings: settings { $0.messages = "all" })
    for text in ["dock left", "zoom", "out", "out"] { h.run(text, from: .shortcut) }
    #expect(lines(h) == ["Docked Safari at the left edge", "Framed Safari", "Stepped out to everything", "Already showing everything"])
    #expect(h.overlays.messages.map(\.model.kind) == [.reply, .reply, .reply, .problem])
  }

  @Test func theSettingTakesEffectWhenSettingsAreApplied() {
    let (h, _, _, _) = makeHarness()
    h.controller.apply(settings: settings { $0.messages = "off" })
    h.run("out", from: .shortcut)
    #expect(h.overlays.messages.isEmpty)
  }

  // MARK: Coming and going

  @Test func theLineGoesWhenItsTimeIsUp() {
    let (h, _, _, _) = makeHarness()
    h.run("out", from: .shortcut)
    h.scheduler.advance(by: 1.4)
    #expect(h.overlays.headsUp[h.display] != nil)
    h.scheduler.advance(by: 0.2)
    #expect(h.overlays.headsUp.isEmpty)
  }

  @Test func theNextLineReplacesTheLastAtOnceAndStaysItsFullTime() {
    let (h, _, _, _) = makeHarness()
    h.run("out", from: .shortcut)
    h.scheduler.advance(by: 1.0)
    h.run("back", from: .shortcut)
    #expect(h.overlays.headsUp[h.display]?.text == "Nothing to go back to")
    h.scheduler.advance(by: 1.0)
    #expect(h.overlays.headsUp[h.display]?.text == "Nothing to go back to", "the first line's end does not take it away")
    h.scheduler.advance(by: 0.6)
    #expect(h.overlays.headsUp.isEmpty)
  }

  @Test func thereIsOneLineAtATimeAcrossDisplays() {
    let (h, _, _, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
    h.run("out", from: .shortcut)
    h.system.cursor = CGPoint(x: 2000, y: 400)
    h.run("out", from: .shortcut)
    #expect(Array(h.overlays.headsUp.keys) == [side.id])
  }

  /// Until 2026-10-14 a command that needs no line of its own left the last one up (`aSilentCommandLeavesTheLineAlone`).
  /// Seen on a hosted Mac: "Your other windows are out of view, not closed" with every window in view again. The product
  /// owner overruled it: a line answers the last thing asked, and after the next it may be a false statement on screen.
  @Test func theNextThingAPersonAsksForPutsTheLineAway() {
    let (h, a, _, _) = makeHarness(taught: false)
    h.run("dock \(a.rawValue) left")
    h.run("zoom", from: .shortcut)
    #expect(h.overlays.headsUp[h.display]?.text == "Your other windows are out of view, not closed")
    h.run("show-all", from: .shortcut)
    #expect(h.overlays.headsUp.isEmpty, "they are in view")
  }

  @Test func andItsTimeDoesNotRunOnIntoTheNextLines() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("out", from: .shortcut)
    #expect(h.overlays.headsUp[h.display]?.text == "Already showing everything")
    h.run("desktop", from: .menu)
    #expect(h.overlays.headsUp.isEmpty, "it no longer is")
    h.scheduler.advance(by: 1.0)
    h.run("forward", from: .shortcut)
    let line = h.overlays.headsUp[h.display]
    #expect(line != nil)
    h.scheduler.advance(by: 1.4)
    #expect(h.overlays.headsUp[h.display] == line)
  }

  @Test func whatChangesNothingAndWhatNoPersonAskedForLeaveTheLineAlone() {
    let (h, a, _, _) = makeHarness()
    h.run("dock \(a.rawValue) left")
    h.run("out", from: .shortcut)
    let line = h.overlays.headsUp[h.display]
    #expect(line?.text == "Already showing everything")
    h.run("status")
    h.run("state", from: .shortcut)
    #expect(h.overlays.headsUp[h.display] == line, "a question changes nothing")
    h.run("desktop")
    h.run("show-all")
    #expect(h.overlays.headsUp[h.display] == line, "a script is not the person the line was said to")
    // A panel that opens is its own answer, and leaves everything the line may be about as it is.
    h.run("find", from: .shortcut)
    #expect(h.overlays.headsUp[h.display] == line)
  }

  // MARK: Pausing and quitting

  @Test func pausingClearsTheScreenAndThenSaysSo() {
    let (h, _, _, _) = makeHarness()
    h.run("out", from: .shortcut)
    h.run("show-shortcuts")

    h.run("toggle-pause", from: .shortcut)

    #expect(h.overlays.cheatSheets.isEmpty)
    #expect(h.overlays.headsUp[h.display]?.line == "Arbor is paused: its keys are the apps’ again · ⌃⌥⎋ resumes")
    h.scheduler.advance(by: 10)
    #expect(h.overlays.headsUp.isEmpty, "and nothing of Arbor's is left on screen")
    #expect(h.scheduler.pendingKeys.isEmpty, "nor any timer")

    h.run("toggle-pause", from: .shortcut)
    #expect(h.overlays.headsUp[h.display]?.line == "Resumed")
  }

  /// One harness with the line up, one with the panel of shortcuts: the panel takes the line's place.
  private func withEachPanelUp(_ body: (Harness) -> Void) {
    // With the gestures on: the zones they ask for have a timer of their own, and "nor any timer" is about every timer.
    let (line, _, _, _) = makeHarness(settings: .withGestures)
    line.run("out", from: .shortcut)
    #expect(line.overlays.headsUp.count == 1)
    body(line)
    let (panel, _, _, _) = makeHarness(settings: .withGestures)
    panel.run("show-shortcuts", from: .shortcut)
    #expect(panel.overlays.cheatSheets.count == 1)
    body(panel)
  }

  @Test func resumedIsSaidWherePausedWas() {
    let (h, a, _, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
    h.system.cursor = CGPoint(x: 2000, y: 400)  // the pointer was left on the other display
    h.scheduler.advance(by: 5)
    h.system.userFocus(a)
    h.system.type()
    h.press("toggle-pause")
    h.press("toggle-pause")
    #expect(h.overlays.messages.map(\.display) == [h.display, h.display])
  }

  @Test func aPauseFromAScriptLeavesNothingOnScreen() {
    withEachPanelUp { h in
      h.run("pause")
      #expect(h.overlays.headsUp.isEmpty)
      #expect(h.overlays.cheatSheets.isEmpty)
      #expect(h.scheduler.pendingKeys.isEmpty, "nor any timer")
    }
  }

  @Test func quittingTakesBothPanelsAway() {
    withEachPanelUp { h in
      h.controller.shutdown()
      #expect(h.overlays.headsUp.isEmpty)
      #expect(h.overlays.cheatSheets.isEmpty)
      #expect(h.scheduler.pendingKeys.isEmpty, "nor any timer")
      // Started again, nothing is left over from before: the shortcut shows the panel rather than hiding it.
      h.start()
      h.run("show-shortcuts", from: .shortcut)
      #expect(h.overlays.cheatSheets.count == 1)
    }
  }

  // MARK: Acceptance 2: teaching moments

  @Test func theFirstDockTheFirstWindowsOutOfViewAndTheFirstTileAreExplained() {
    let (h, _, b, _) = makeHarness(taught: false)
    h.run("dock left", from: .shortcut)
    #expect(lines(h).last == "Docked · ⌃⌥↩ frames it")
    h.run("zoom", from: .shortcut)
    #expect(lines(h).last == "Your other windows are out of view, not closed · ⌃⌥Space shows everything")
    h.run("show-all", from: .shortcut)
    #expect(lines(h).count == 2)

    // Xcode refuses to be as small as its slot, so a tile stands in for it.
    let big = h.system.open(app: "Xcode", minimumSize: CGSize(width: 1200, height: 700))
    h.system.userFocus(big)
    h.run("dock right", from: .shortcut)
    #expect(lines(h).last == "Too small to show: click the tile to zoom in · ⌃⌥G goes there too")
    #expect(h.overlays.messages.allSatisfy { $0.model.kind == .hint })
    _ = b
  }

  /// Runs the moment `times` times and returns how often the hint was shown.
  private func frameAndReturn(_ h: Harness, times: Int) -> Int {
    let before = h.overlays.messages.count
    for _ in 0..<times {
      h.run("zoom", from: .shortcut)
      h.run("show-all", from: .shortcut)
    }
    return h.overlays.messages.count - before
  }

  /// A line of text is mostly run from a shortcut or the menu, where its reply is not read. What it ends unseen is said on screen,
  /// by the app's name: nobody knows a window's number.
  @Test func aRoleThatALineEndsIsSaidOnScreen() {
    let (h, a, b, c) = makeHarness(taught: true)
    h.run("pin \(a.rawValue)")
    h.run("layout \(a.rawValue) | \(b.rawValue)", from: .shortcut)
    #expect(lines(h) == ["Arranged 2 windows; Safari is no longer kept in view · ⌃⌥Z takes it back"])
    #expect(h.overlays.messages.last?.model.kind == .change)
    h.run("layout Desktop")
    h.run("summon \(h.system.windows[c]!.snapshot.appName)")
    h.run("layout \(c.rawValue)", from: .menu)
    #expect(lines(h).last == "Arranged 1 window; \(h.system.windows[c]!.snapshot.appName) no longer comes and goes with its key · ⌃⌥Z takes it back")
  }

  /// So is the one `dock` ends, whichever it was.
  @Test func dockingAWindowThatCameAndWentWithItsKeyIsSaidOnScreen() {
    let (h, a, _, _) = makeHarness(taught: true)
    h.run("summon Safari")
    #expect(h.workspace.isSummoned(a))
    h.run("dock \(a.rawValue) left", from: .shortcut)
    #expect(lines(h) == ["Docked Safari at the left edge and it no longer comes and goes with its key · ⌃⌥Z takes it back"])
    #expect(h.overlays.messages.last?.model.kind == .change)
  }

  @Test func whatWasLostComesBeforeAnyHintAndIsSaidToAnOldHandToo() {
    for taught in [false, true] {
      let (h, a, _, _) = makeHarness(taught: taught)
      h.run("dock \(a.rawValue) left")
      h.run("zoom \(a.rawValue)")
      h.run("save-view 1")
      h.run("name Work")
      h.run("show-all")
      let shown = h.controller.headsUp.hintsShown

      #expect(h.run("arrange", from: .shortcut).message == "arranged 3 windows; 1 saved view is gone; 1 name is gone")

      #expect(lines(h) == ["Arranged 3 windows; 1 saved view is gone; 1 name is gone · ⌃⌥Z takes it back"], "taught: \(taught)")
      #expect(h.overlays.messages.last?.model.kind == .change)
      #expect(h.controller.headsUp.hintsShown == shown, "the hint keeps its showing")
      // And it does.
      h.run("undo", from: .shortcut)
      #expect(h.workspace.savedView(slot: 1) != nil)
      #expect(h.workspace.node(named: "Work") != nil)
    }
  }

  @Test func aPinLostByDockingIsSaidAndUndoBringsItBack() {
    let (h, a, _, _) = makeHarness(taught: false)
    h.run("pin \(a.rawValue)")
    h.run("dock left", from: .shortcut)
    #expect(lines(h) == ["Docked Safari at the left edge and it is no longer kept in view · ⌃⌥Z takes it back"])
    h.run("undo")
    #expect(h.controller.isPinned(a))
  }

  @Test func withoutAShortcutForUndoTheLossIsSaidWithoutIt() {
    let (h, a, _, _) = makeHarness(settings: settings { $0.bindings = ["ctrl+opt+z": nil] })
    h.run("pin \(a.rawValue)")
    h.run("dock left", from: .shortcut)
    #expect(lines(h) == ["Docked Safari at the left edge and it is no longer kept in view"])
  }

  @Test func theDesktopWithNothingOnItIsNotTheFirstTile() {
    let small = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 900, height: 600),
      visibleFrame: CGRect(x: 0, y: 25, width: 900, height: 575), isMain: true)
    var saved = PersistedState(workspaces: [:], hints: [:])
    for hint in [HeadsUpHint.docked, .outOfView] { saved.hintsShown[hint.rawValue] = HeadsUpHint.timesShown }
    let h = Harness(displays: [small], saved: saved)
    let a = h.system.open(app: "Safari", minimumSize: CGSize(width: 380, height: 300))
    let b = h.system.open(app: "Mail", minimumSize: CGSize(width: 380, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left", from: .shortcut)
    h.run("dock \(b.rawValue) right", from: .shortcut)
    #expect(h.layout?.tiles.map(\.kind) == [.desktop], "or this proves nothing")
    #expect(h.overlays.messages.isEmpty, "\(lines(h))")
    #expect(h.controller.headsUp.hintsShown[HeadsUpHint.tile.rawValue] == nil)
  }

  @Test func aPlaceThatAutomaticDockingTriesAndTakesBackTeachesNothing() {
    let small = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1000, height: 600),
      visibleFrame: CGRect(x: 0, y: 25, width: 1000, height: 575), isMain: true)
    let h = Harness(displays: [small], settings: settings { $0.newWindows = "dock" })
    h.start()
    let a = h.system.open(app: "Safari")
    #expect(lines(h) == ["Docked · ⌃⌥↩ frames it"])
    // Arbor learns of this only when it asks Safari to be smaller.
    h.system.setMinimumSize(a, CGSize(width: 800, height: 400))
    let mail = h.system.open(app: "Mail")
    // Where Mail ends up is automatic docking's business, and that of making room (F61). Whatever was tried on the way: if it stays
    // docked that is one event and one hint, and if it floats in the end, as though nothing had been tried, nothing is said.
    let stayed = h.workspace.isDocked(mail)
    #expect(h.overlays.messages.count == (stayed ? 2 : 1), "Mail \(stayed ? "stayed docked" : "floats"): \(lines(h))")
  }

  @Test func eachHintIsShownThreeTimesAndNeverAgain() {
    let (h, a, _, _) = makeHarness(taught: false)
    h.run("dock \(a.rawValue) left")
    #expect(frameAndReturn(h, times: 5) == 3)

    var docks = 0
    for _ in 0..<5 {
      h.run("float \(a.rawValue)")
      let before = h.overlays.messages.count
      h.run("dock left", from: .shortcut)
      docks += h.overlays.messages.count - before
    }
    #expect(docks == 3)
  }

  @Test func theCountSurvivesARestart() throws {
    let (first, a, _, _) = makeHarness(taught: false)
    first.run("dock \(a.rawValue) left")
    #expect(frameAndReturn(first, times: 2) == 2)
    first.controller.shutdown()

    // Through JSON, as the file would.
    let file = try JSONEncoder().encode(try #require(first.store.saved))
    let h = Harness(saved: try JSONDecoder().decode(PersistedState.self, from: file))
    let b = h.system.open(app: "Safari")
    h.system.open(app: "Mail")
    h.start()
    h.run("dock \(b.rawValue) left")
    h.system.userFocus(b)
    #expect(frameAndReturn(h, times: 3) == 1)
  }

  @Test func theCountSurvivesAPause() {
    let (h, a, _, _) = makeHarness(taught: false)
    h.run("dock \(a.rawValue) left")
    #expect(frameAndReturn(h, times: 3) == 3)
    h.run("pause")
    h.run("resume")
    h.system.userFocus(a)
    #expect(frameAndReturn(h, times: 2) == 0)
  }

  @Test func aStateFileFromBeforeTheCountsStillLoadsAndSoDoesOneWithNonsenseInThem() throws {
    let old = #"{"version":1,"workspaces":{},"hints":{}}"#
    #expect(try JSONDecoder().decode(PersistedState.self, from: Data(old.utf8)).hintsShown == [:])
    let odd = #"{"version":1,"workspaces":{},"hints":{},"hintsShown":"often"}"#
    #expect(try JSONDecoder().decode(PersistedState.self, from: Data(odd.utf8)).hintsShown == [:])
    let huge = #"{"version":1,"workspaces":{},"hints":{},"hintsShown":{"docked":9223372036854775807,"outOfView":-5,"else":1}}"#
    let h = Harness(saved: try JSONDecoder().decode(PersistedState.self, from: Data(huge.utf8)))
    let a = h.system.open(app: "Safari")
    h.system.open(app: "Mail")
    h.start()
    h.system.userFocus(a)
    h.run("dock left", from: .shortcut)
    #expect(h.overlays.messages.isEmpty)
    h.run("zoom", from: .shortcut)
    #expect(h.overlays.messages.count == 1)
  }

  @Test func aDropAndAClickOnATileTeachToo() {
    let (h, a, b, _) = makeHarness(taught: false)
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(a, through: [CGPoint(x: 600, y: 210), CGPoint(x: 300, y: 400), CGPoint(x: 2, y: 400)])
    #expect(lines(h) == ["Docked · ⌃⌥↩ frames it"])

    h.run("dock \(b.rawValue) right")
    h.overlays.clickTile(h.workspace.tree.leaf(containing: a)!)  // as a click on a tile would: the view moves there
    #expect(lines(h).last == "Your other windows are out of view, not closed · ⌃⌥Space shows everything")
  }

  @Test func turningToAWindowThatIsOutOfViewDoesNotRepeatTheHint() {
    let (h, a, b, _) = makeHarness(taught: false)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    h.system.userFocus(b)  // ⌘Tab: the view follows
    #expect(h.overlays.messages.isEmpty, "windows were out of view before and after")
  }

  @Test func whatAScriptDoesTeachesNobodyAndIsNotBlamedOnTheNextEvent() {
    let (h, a, b, c) = makeHarness(taught: false)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(a.rawValue)")
    #expect(h.overlays.messages.isEmpty)

    h.system.setMinimized(c, true)  // something unrelated lays the display out again
    h.run("relayout", from: .shortcut)
    #expect(!h.overlays.messages.contains { $0.model.kind == .hint })
    #expect(h.store.saved?.hintsShown.isEmpty != false)
  }

  @Test func whatArborRestoresAtLaunchIsNotAMoment() throws {
    let (first, a, _, _) = makeHarness(taught: false)
    first.run("dock \(a.rawValue) left")
    first.run("zoom \(a.rawValue)")
    first.controller.saveNow()

    // The watchdog's start, which brings the view back. (A launch shows everything.)
    let h = first.newProcess(byTheWatchdog: true)
    h.start()
    #expect(!h.controller.parked.isEmpty, "the view is restored, with Mail out of view")
    #expect(h.overlays.messages.isEmpty)

    h.controller.shutdown()
    let launched = h.newProcess()
    launched.start()
    #expect(launched.layout?.windowFrames[a] != nil, "the arrangement is restored")
    #expect(launched.overlays.messages.isEmpty)
  }

  @Test func aProblemComesBeforeAnyHint() {
    let (h, _, _, _) = makeHarness(taught: false)
    h.run("in", from: .shortcut)
    #expect(h.overlays.messages.map(\.model.kind) == [.problem])
  }

  // MARK: Acceptance 4: the user's own shortcuts

  @Test func aReboundShortcutIsNamedByTheUsersKeys() {
    let own = settings { $0.bindings = ["ctrl+opt+e": "show-all", "ctrl+opt+cmd+h": "dock left", "ctrl+opt+shift+3": "save-view 3"] }
    let (h, _, _, _) = makeHarness(settings: own, taught: false)
    h.run("in", from: .shortcut)
    #expect(lines(h).last == "Nothing is docked yet: drag a window to a screen edge, or try ⌃⌥⌘H")
    h.run("dock left", from: .shortcut)
    h.run("zoom", from: .shortcut)
    #expect(lines(h).last == "Your other windows are out of view, not closed · ⌃⌥E shows everything")
  }

  @Test func aRemovedShortcutIsLeftOutOfTheSentence() {
    let removed = settings { $0.bindings = ["ctrl+opt+return": nil, "ctrl+opt+space": nil, "ctrl+opt+0": nil] }
    let (h, _, _, _) = makeHarness(settings: removed, taught: false)
    h.run("dock left", from: .menu)
    #expect(h.overlays.messages.last?.model.line == "Docked")
    h.run("zoom", from: .menu)
    #expect(h.overlays.messages.last?.model.line == "Your other windows are out of view, not closed")
  }

  @Test func anotherShortcutThatDoesTheJobStandsIn() {
    let (h, _, _, _) = makeHarness(settings: settings { $0.bindings = ["ctrl+opt+space": nil] }, taught: false)
    h.run("dock left", from: .shortcut)
    h.run("zoom", from: .shortcut)
    #expect(lines(h).last == "Your other windows are out of view, not closed · ⌃⌥0 shows everything")
  }

  @Test func keysAreNamedAsTheKeyboardInUseLabelsThem() {
    let own = settings { $0.bindings = ["ctrl+opt+z": "save-view 3", "ctrl+opt+shift+3": nil] }
    let (h, _, _, _) = makeHarness(settings: own)
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    h.run("view 3", from: .shortcut)
    #expect(lines(h).last == "View 3 is not saved; ⌃⌥Z saves where you are looking")
    h.run("show-shortcuts")
    let rows = h.overlays.cheatSheets.values.flatMap(\.sections).flatMap(\.rows)
    #expect(rows.contains(CheatSheetModel.Row(keys: "⌃⌥Ü", title: "Back")), "the key right of P, as it is labelled there (F44)")
  }

  @Test func inAnAppThatKeepsItsOwnKeysOnlyTheShortcutsStillHeldAreNamed() {
    var own = Settings.withGestures  // which go with the keys, further down
    own.passThroughApps = ["org.gnu.Emacs"]
    let (h, _, _, _) = makeHarness(settings: own, taught: false)
    h.controller.applicationActivated(FrontmostApp(bundleID: "org.gnu.Emacs", name: "Emacs"))
    h.run("dock left", from: .menu)
    #expect(lines(h) == ["Docked"], "⌃⌥↩ is Emacs's for now (F41)")
    let result = h.run("show-shortcuts", from: .menu)
    let model = h.overlays.cheatSheets[h.display]
    #expect(model?.title == "Off in Emacs, except ⌃⌥⎋", "the whole list, under a heading that says what it is worth here")
    let rows = model?.sections.flatMap(\.rows) ?? []
    #expect(rows.map(\.title).contains("Show Everything"))
    #expect(!rows.contains { $0.keys.contains("pinch") }, "gestures are off there too")
    #expect(result.message.contains("off in Emacs except ⌃⌥⎋"))
    #expect(result.text?.hasPrefix("Off in Emacs, except ⌃⌥⎋\n\nLook") == true)
  }

  @Test func landingInSuchAnAppByArborsOwnCommandSaysThatItsKeysEndHere() {
    let (h, a, _, _) = makeHarness(settings: settings { $0.passThroughApps = ["org.gnu.Emacs"] })
    h.run("dock \(a.rawValue) left")
    let emacs = FrontmostApp(bundleID: "org.gnu.Emacs", name: "Emacs")

    h.run("desktop", from: .shortcut)
    h.scheduler.advance(by: 0.2)  // macOS reports the app a moment later
    h.controller.applicationActivated(emacs)
    #expect(lines(h) == ["Shortcuts are off in Emacs · ⌘Tab leaves, ⌃⌥⎋ pauses"])

    // Someone who switched there knows where they are.
    h.controller.applicationActivated(nil)
    h.scheduler.advance(by: 5)
    h.controller.applicationActivated(emacs)
    #expect(h.overlays.messages.count == 1)

    // And a script's doing is nobody's news.
    h.controller.applicationActivated(nil)
    h.run("show-all")
    h.controller.applicationActivated(emacs)
    #expect(h.overlays.messages.count == 1)
  }

  @Test func givingAnAppItsKeysBackIsConfirmed() {
    let (h, _, _, _) = makeHarness()
    h.controller.applicationActivated(FrontmostApp(bundleID: "org.gnu.Emacs", name: "Emacs"))
    h.run("pass-through", from: .menu)
    #expect(h.overlays.messages.last?.model.kind == .change)
    #expect(lines(h).last?.hasPrefix("Shortcuts and gestures are off in Emacs") == true)
  }

  @Test func withShortcutsSwitchedOffNoKeysAreNamed() {
    let (h, _, _, _) = makeHarness(settings: settings { $0.hotkeysEnabled = false }, taught: false)
    h.run("dock left", from: .menu)
    #expect(lines(h) == ["Docked"])
    h.run("view 3", from: .menu)
    #expect(lines(h).last == "View 3 is not saved; “Save View 3” saves where you are looking")
  }

  // MARK: Doing no harm

  @Test func windowsEndUpInTheSamePlacesWhateverIsSaid() {
    func frames(_ level: String, _ source: CommandSource) -> [CGRect?] {
      let (h, a, b, c) = makeHarness(settings: settings { $0.messages = level }, taught: false)
      for text in ["dock left", "zoom", "show-all", "arrange", "in", "out", "out", "toggle-float", "save-view 1", "float-all"] {
        h.run(text, from: source)
      }
      h.scheduler.runPending()
      return [a, b, c].map { h.frame($0) }
    }
    // Source by source: where a command came from decides what `in` steps toward (F56), what is said decides nothing.
    for source in CommandSource.allCases {
      let silent = frames("off", source)
      #expect(frames("all", source) == silent, "\(source)")
      #expect(frames("helpful", source) == silent, "\(source)")
    }
  }

  @Test func noCommandHoweverOddBreaksTheSentenceTheTitleOrThePanel() {
    let (h, _, _, _) = makeHarness(settings: settings { $0.messages = "all" }, taught: false)
    var performed = 0
    for verb in HostileCommandTests.verbs + ["home", "pause", "resume", "toggle-pause", "show-shortcuts", "resize"] {
      for first in [nil] + HostileCommandTests.words.map(Optional.some) {
        for second in [nil, "left", "1e308", "-5"] {
          guard let command = try? Command.parse(words: [verb, first, second].compactMap { $0 }) else { continue }
          performed += 1
          #expect(!command.title.isEmpty, "\(command.text)")
          _ = command.group
          _ = CheatSheetModel(shortcuts: [(KeyChord([.control], .a), command)]).text
          h.controller.perform(command, from: .shortcut)
        }
      }
    }
    #expect(performed > 100)
    for message in h.overlays.messages {
      #expect(!message.model.text.isEmpty)
      #expect(message.model.line.count <= 200)
      #expect(message.model.duration >= 1.5 && message.model.duration <= 6)
      #expect(!message.model.line.contains("\n"))
    }
  }

  // MARK: The neighbours' commands

  @Test func namingASpaceAndTakingTheNameOffAreConfirmed() {
    let (h, _, _, _) = makeHarness()
    h.run("arrange")

    h.run("name Work", from: .shortcut)
    #expect(h.overlays.messages.last?.model.kind == .change)
    #expect(lines(h).last == "Named everything: Work")
    h.run("unname", from: .menu)
    #expect(h.overlays.messages.last?.model.kind == .change)
    #expect(lines(h).last == "Removed the name Work from everything")
  }

  @Test func aNameThatReadsLikeArborsShorthandIsSaidAsItWasWritten() {
    let (h, _, _, _) = makeHarness()
    h.run("arrange")
    for name in ["w12", "w101", "(n5)", "`quit`", "Work (n5)", "com.apple.Safari"] {
      h.controller.perform(.name(name), from: .shortcut)
      #expect(lines(h).last == "Named everything: \(name)")
      h.run("out", from: .shortcut)
      h.controller.perform(.unname(nil), from: .shortcut)
      #expect(lines(h).last == "Removed the name \(name) from everything")
    }
    // The shorthand around it is still put into words.
    h.controller.perform(.name("w12"), from: .shortcut)
    h.controller.perform(.goToSpace("w12"), from: .shortcut)
    #expect(lines(h).last == "Already showing w12", "without (n2)")
  }

  @Test func theNameFieldIsItsOwnAnswer() {
    let (h, _, _, _) = makeHarness(settings: settings { $0.messages = "all" })
    h.run("arrange")

    #expect(h.run("ask-name", from: .shortcut).ok)
    #expect(h.overlays.namePrompt != nil, "or this proves nothing")
    #expect(h.run("ask-name cancel", from: .shortcut).ok)
    #expect(h.overlays.messages.isEmpty)
  }

  @Test func aWindowSentAwayBySummonIsNotTakenForOneThatSeemsToHaveGone() {
    let (h, a, b, _) = makeHarness(taught: false)
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")

    #expect(h.run("summon Notes", from: .shortcut).message.hasPrefix("summoned"))
    #expect(h.run("summon Notes", from: .shortcut).message.hasPrefix("sent Notes away"))

    #expect(h.overlays.messages.isEmpty, "⌃⌥Space would not bring it back: \(lines(h))")
    h.run("zoom \(a.rawValue)", from: .shortcut)
    #expect(lines(h) == ["Your other window is out of view, not closed · ⌃⌥Space shows everything"], "Mail, and only Mail")
  }

  @Test func aDisplayThatIsUnpluggedTakesTheLineAndThePanelAlong() {
    for command in ["out", "show-shortcuts"] {
      let (h, _, _, _) = makeHarness(displays: [FakeWindowSystem.standardDisplay, side])
      h.system.cursor = CGPoint(x: 2000, y: 400)
      h.run(command, from: .shortcut)
      #expect(Array(h.overlays.headsUp.keys) + Array(h.overlays.cheatSheets.keys) == [side.id], "\(command)")

      h.system.setDisplays([FakeWindowSystem.standardDisplay])

      #expect(h.overlays.headsUp.isEmpty && h.overlays.cheatSheets.isEmpty, "\(command)")
      #expect(!h.scheduler.pendingKeys.contains("heads-up"), "\(command)")
      h.system.cursor = CGPoint(x: 400, y: 400)
      #expect(h.run("show-shortcuts", from: .shortcut).message.hasPrefix("showing"), "not “put away”: \(command)")
    }
  }

  @Test func soDoesTheLastDisplayAndOneThatChangesShape() {
    let smaller = DisplaySnapshot(
      id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: 1024, height: 640),
      visibleFrame: CGRect(x: 0, y: 25, width: 1024, height: 615), isMain: true)
    for displays in [[], [smaller]] {
      for command in ["out", "show-shortcuts"] {
        let (h, _, _, _) = makeHarness()
        h.run(command, from: .shortcut)
        #expect(h.overlays.headsUp.count + h.overlays.cheatSheets.count == 1, "or this proves nothing")
        h.system.setDisplays(displays)
        #expect(h.overlays.headsUp.isEmpty && h.overlays.cheatSheets.isEmpty, "\(command), \(displays.count) display(s)")
        #expect(!h.scheduler.pendingKeys.contains("heads-up"))
      }
    }
    let (paused, _, _, _) = makeHarness()
    paused.run("toggle-pause", from: .shortcut)
    #expect(paused.overlays.headsUp.count == 1, "or this proves nothing")
    paused.controller.displaysChanged()
    #expect(paused.overlays.headsUp.isEmpty, "a pause does not listen, but its line is Arbor's")
  }

  @Test func lettingGoOfAPeekTeachesNothingAndUsesNoHintUp() {
    let (h, a, b, _) = makeHarness(taught: false)
    h.run("arrange")
    h.system.userFocus(a)
    h.key("ctrl+opt+return")
    #expect(lines(h) == ["Your other windows are out of view, not closed · ⌃⌥Space shows everything"])
    h.scheduler.advance(by: 10)

    h.keyDown("ctrl+opt+space")
    h.scheduler.advance(by: 1)
    #expect(h.controller.isPeeking, "or this proves nothing")
    h.keyUp("ctrl+opt+space")

    #expect(h.workspace.camera != h.workspace.tree.root, "back where it began")
    #expect(h.overlays.messages.count == 1, "\(lines(h))")
    #expect(h.controller.headsUp.hintsShown[HeadsUpHint.outOfView.rawValue] == 1)
    // The baseline moved all the same: turning to a window that is out of view is compared with the view as it is now.
    h.system.userFocus(b)
    #expect(h.overlays.messages.count == 1, "\(lines(h))")
  }

  // MARK: The log

  @Test func theLogGetsTheLineWithoutTheNamesOfSpaces() {
    let (h, _, _, _) = makeHarness(settings: settings { $0.messages = "all" })
    h.run("arrange")
    var logged: [String] = []
    for text in ["name Acme takeover", "in", "out", "go Acme", "go Acme takeover", "go Nowhere special", "unname", "unname Acme takeover"] {
      let said = h.overlays.messages.count
      h.run(text, from: .shortcut)
      #expect(h.overlays.messages.count == said + 1, "\(text) is answered")
      logged.append(h.controller.headsUp.logged)
    }
    #expect(lines(h).filter { $0.contains("Acme takeover") }.count >= 4, "on screen a space is called by its name: \(lines(h))")
    for line in logged {
      for word in ["Acme", "takeover", "Nowhere"] { #expect(!line.contains(word), "\(line)") }
    }
    #expect(logged[0] == "Named everything: ‹name›")
    #expect(logged[6] == "Removed the name ‹name› from everything", "a name that is gone by the time the line is made")

    // Tidied on the way in, so the name there is afterwards is not the text of the command.
    h.controller.perform(.name("  Acme   takeover "), from: .shortcut)
    #expect(lines(h).last == "Named everything: Acme takeover")
    #expect(h.controller.headsUp.logged == "Named everything: ‹name›")
  }

  @Test func theLogGetsNoWordOfTheReplyToACommandThatChangesSettings() {
    let (h, _, _, _) = makeHarness()

    h.run("rule add com.apple.Safari float title Secret plans", from: .menu)

    #expect(lines(h).last?.contains("Secret plans") == true, "the person's own words, back to them: \(lines(h))")
    #expect(h.controller.headsUp.logged == "the reply to `rule`")
  }

  @Test func theLogGetsNoWordOfWhatGoToWasAskedForInVain() {
    let (h, _, _, _) = makeHarness()
    h.run("find Secret plans for Acme", from: .shortcut)
    #expect(lines(h).last?.hasSuffix("matches “Secret plans for Acme”") == true, "the person's own words, back to them: \(lines(h))")
    #expect(h.controller.headsUp.logged == "the reply to `find`")
  }

  @Test func whatArborSaysInItsOwnWordsIsLoggedAsSaid() {
    let (h, a, _, _) = makeHarness(taught: false)
    h.run("dock \(a.rawValue) left", from: .shortcut)
    #expect(h.controller.headsUp.logged == "Docked · ⌃⌥↩ frames it")
    h.run("save-view 2", from: .shortcut)
    #expect(h.controller.headsUp.logged == lines(h).last)
    #expect(h.controller.headsUp.logged.hasPrefix("Saved view 2"))
  }

  // MARK: Acceptance 5: titles

  @Test func windowTitlesNeverAppear() {
    let (h, a, b, c) = makeHarness(settings: settings { $0.messages = "all" }, taught: false)
    let texts = [
      "dock left", "zoom", "in", "out", "out", "dock right", "dock left", "dock left", "neighbor left", "neighbor right", "save-view 1",
      "view 1", "view 2", "back", "forward", "desktop", "toggle-float", "toggle-float", "resize left 40", "resize right 40", "arrange",
      "in", "in", "in", "zoom", "zoom", "float-all", "float-all", "exclude", "toggle-pause", "toggle-pause",
    ]
    for (index, text) in texts.enumerated() {
      h.system.userFocus([a, b, c][index % 3])
      h.run(text, from: .shortcut)
    }
    #expect(h.overlays.messages.count > 20)
    for line in lines(h) {
      for title in ["Secret", "plans", "salary", "Diary"] { #expect(!line.contains(title), "\(line)") }
      #expect(line.range(of: #"\bw\d+\b|\(n\d+\)|`"#, options: .regularExpression) == nil, "terminal talk in “\(line)”")
      #expect(line.first?.isLowercase != true, "\(line)")
    }
  }
}
