import ArborCore
import CoreGraphics
import Foundation
import Testing

/// The heads-up line's decisions (docs/features/F43-say-what-happened.md): which replies earn a line, in which words, for
/// how long and where.
@Suite struct HeadsUpTests {
  // MARK: Which replies earn a line

  @Test(arguments: [CommandSource.script, .url])
  func scriptsAndURLsAreNeverAnsweredOnScreen(source: CommandSource) {
    for level in MessageLevel.allCases {
      for ok in [true, false] {
        #expect(HeadsUpPolicy.kind(of: .stepOut, ok: ok, from: source, level: level) == nil)
        #expect(HeadsUpPolicy.kind(of: .saveView(1), ok: ok, from: source, level: level) == nil)
      }
    }
  }

  @Test(arguments: [CommandSource.shortcut, .gesture, .menu])
  func aPersonHearsAboutProblemsAndUnseenChangesButNotRoutine(source: CommandSource) {
    #expect(HeadsUpPolicy.kind(of: .stepOut, ok: false, from: source, level: .helpful) == .problem)
    #expect(HeadsUpPolicy.kind(of: .saveView(2), ok: true, from: source, level: .helpful) == .change)
    for routine: Command in [.stepOut, .showAll, .zoom(nil), .dock(nil, .left), .arrange, .goToView(1), .desktop, .quit] {
      #expect(HeadsUpPolicy.kind(of: routine, ok: true, from: source, level: .helpful) == nil, "\(routine.text)")
    }
  }

  @Test func whatCannotBeSeenIsSaid() {
    let unseen: [Command] = [
      .saveView(1), .pause(minutes: nil), .pause(minutes: 5), .resume, .togglePause, .exclude(bundleID: nil),
      .include(bundleID: "com.apple.Music"), .reloadSettings, .floatAll, .floatAllHere, .passThrough(bundleID: nil),
      .pin(nil), .unpin(nil), .togglePin(nil), .name("Work"), .unname(nil), .unname("Work"), .launchAtLogin(true), .release, .toggleHold,
      .undo, .redo,
    ]
    for command in unseen { #expect(command.worksUnseen, "\(command.text)") }
  }

  @Test func allSaysEveryReplyAndOffSaysNothing() {
    #expect(HeadsUpPolicy.kind(of: .stepOut, ok: true, from: .shortcut, level: .all) == .reply)
    #expect(HeadsUpPolicy.kind(of: .saveView(1), ok: true, from: .shortcut, level: .all) == .change)
    #expect(HeadsUpPolicy.kind(of: .stepOut, ok: false, from: .shortcut, level: .off) == nil)
    #expect(HeadsUpPolicy.kind(of: .saveView(1), ok: true, from: .shortcut, level: .off) == nil)
  }

  @Test func aSuccessThatChangedNothingLooksLikeADeadKeySoItIsSaid() {
    #expect(HeadsUpPolicy.kind(of: .zoom(nil), ok: true, from: .shortcut, level: .helpful, changedNothing: true) == .change)
    #expect(HeadsUpPolicy.kind(of: .zoom(nil), ok: true, from: .shortcut, level: .helpful, changedNothing: false) == nil)
    #expect(HeadsUpPolicy.kind(of: .zoom(nil), ok: true, from: .script, level: .all, changedNothing: true) == nil)
    #expect(HeadsUpPolicy.kind(of: .zoom(nil), ok: true, from: .shortcut, level: .off, changedNothing: true) == nil)
    #expect(HeadsUpPolicy.kind(of: .showShortcuts, ok: true, from: .shortcut, level: .all, changedNothing: true) == nil)
  }

  @Test func aSuccessThatTookSomethingAlongIsSaid() {
    #expect(HeadsUpPolicy.kind(of: .arrange, ok: true, from: .shortcut, level: .helpful, namesALoss: true) == .change)
    #expect(HeadsUpPolicy.kind(of: .arrange, ok: true, from: .shortcut, level: .helpful, namesALoss: false) == nil)
    #expect(HeadsUpPolicy.kind(of: .arrange, ok: true, from: .script, level: .all, namesALoss: true) == nil)
    #expect(HeadsUpPolicy.kind(of: .arrange, ok: true, from: .menu, level: .off, namesALoss: true) == nil)
  }

  @Test func aLossIsWhatAReplySaysWentBesidesWhatWasAskedFor() {
    for reply in [
      "arranged 4 windows; 2 saved views are gone", "arranged 4 windows; 1 saved view is gone; 1 name is gone", "floated 3 windows; 2 names are gone",
      "docked w7 at the left edge and it is no longer kept in view",
    ] { #expect(HeadsUpText.namesALoss(reply), "\(reply)") }
    for reply in [
      "arranged 4 windows", "no longer keeping w7 in view", "removed the name Work from everything", "w7 is gone", "no longer arranging Safari",
      "named everything: all is gone",
    ] { #expect(!HeadsUpText.namesALoss(reply), "\(reply)") }
  }

  @Test func thePanelOfShortcutsIsItsOwnAnswer() {
    #expect(HeadsUpPolicy.kind(of: .showShortcuts, ok: true, from: .shortcut, level: .all) == nil)
    #expect(HeadsUpPolicy.kind(of: .showShortcuts, ok: false, from: .menu, level: .helpful) == .problem)
  }

  @Test func soAreTheNameFieldAndTheWelcomeWindow() {
    for command: Command in [.askName(cancel: false), .askName(cancel: true), .checkSetup, .welcome] {
      #expect(HeadsUpPolicy.kind(of: command, ok: true, from: .shortcut, level: .all, changedNothing: true) == nil, "\(command.text)")
      #expect(HeadsUpPolicy.kind(of: command, ok: false, from: .menu, level: .helpful) == .problem, "\(command.text)")
    }
  }

  // MARK: The setting

  @Test func messagesIsHelpfulUnlessTheFileSaysOtherwise() throws {
    func settings(_ json: String) throws -> Settings { try JSONDecoder().decode(Settings.self, from: Data(json.utf8)) }
    #expect(Settings().messageLevel == .helpful)
    #expect(try settings("{}").messageLevel == .helpful, "a file from before the key existed")
    #expect(try settings(#"{"messages": "all"}"#).messageLevel == .all)
    #expect(try settings(#"{"messages": "Off"}"#).messageLevel == .off)
    #expect(try settings(#"{"messages": "loud", "gap": 20}"#).messageLevel == .helpful, "a typing mistake")
    #expect(try settings(#"{"messages": "loud", "gap": 20}"#).gap == 20, "and the rest of the file still counts")
    let saved = try JSONEncoder().encode(try settings(#"{"messages": "off"}"#))
    #expect(try JSONDecoder().decode(Settings.self, from: saved).messageLevel == .off)
  }

  // MARK: The words

  /// `keys` is keyed by the command's text form.
  private func sentence(
    _ reply: String, keys: [String: String] = [:], apps: [UInt32: String] = [:], bundles: [String: String] = [:]
  ) -> String {
    HeadsUpText.sentence(
      from: reply, appName: { apps[$0.rawValue] }, bundleName: { bundles[$0] }, shortcut: { keys[$0.text] })
  }

  @Test func aReplyBecomesASentence() {
    #expect(sentence("no space to the left") == "No space to the left")
    #expect(sentence("already showing everything") == "Already showing everything")
    #expect(sentence("") == "")
  }

  @Test func nodeNumbersAreDropped() {
    #expect(sentence("saved view 2: Safari (n5)") == "Saved view 2: Safari")
    #expect(sentence("stepped in to Safari and Mail (n12)") == "Stepped in to Safari and Mail")
    #expect(sentence("nothing to step into: Safari (n3) fills the view") == "Nothing to step into: Safari fills the view")
    #expect(sentence("summoned Notes (w412)", apps: [412: "Notes"]) == "Summoned Notes", "nor is the app named twice")
    #expect(sentence("waiting (not long)") == "Waiting (not long)", "other brackets stay")
    #expect(sentence("waiting (w)") == "Waiting (w)")
    #expect(sentence("odd (n5") == "Odd (n5", "a bracket that never closes is left alone")
  }

  @Test func windowsAreCalledByTheirApp() {
    #expect(sentence("w412 fills the view; step out first", apps: [412: "Safari"]) == "Safari fills the view; step out first")
    #expect(sentence("docked w7 left of w8", apps: [7: "Mail", 8: "Notes"]) == "Docked Mail left of Notes")
    #expect(sentence("w9 is floating", apps: [9: "iTerm2"]) == "iTerm2 is floating", "an app keeps its own spelling")
    #expect(sentence("there is no window w999 (`state` lists their ids)") == "There is no window 999", "all that is known of it")
    #expect(sentence("w999 does not answer") == "The window does not answer")
    #expect(sentence("w9 is floating") == "The window is floating", "a window Arbor no longer knows")
    #expect(sentence("row2 w2x w window") == "Row2 w2x w window", "only whole words that are window ids")
    #expect(sentence("w99999999999 is odd") == "W99999999999 is odd", "no window has such a number")
  }

  @Test func appsAreCalledByTheirNamesNotTheirBundleIds() {
    let mail = ["com.apple.mail": "Mail"]
    #expect(sentence("no longer arranging com.apple.mail", bundles: mail) == "No longer arranging Mail")
    #expect(sentence("com.apple.mail is already excluded", bundles: mail) == "Mail is already excluded")
    #expect(sentence("arranging com.apple.mail, again; done", bundles: mail) == "Arranging Mail, again; done")
    #expect(sentence("no longer arranging com.unknown.app", bundles: mail) == "No longer arranging com.unknown.app")
    #expect(sentence("com.apple.mail.helper stays", bundles: mail) == "com.apple.mail.helper stays", "whole words only")
  }

  @Test func aFileOrABundleKeepsItsSmallLetter() {
    #expect(sentence("settings.json was not reloaded: line 3") == "settings.json was not reloaded: line 3")
    #expect(sentence("done. and more") == "Done. and more", "a full stop at the end of the word is not a dot in it")
  }

  @Test func quotedCommandsBecomeTheKeysInEffect() {
    let reply = "view 3 is not saved; `save-view 3` saves where you are looking"
    #expect(sentence(reply, keys: ["save-view 3": "⌃⌥⇧3"]) == "View 3 is not saved; ⌃⌥⇧3 saves where you are looking")
    #expect(sentence(reply) == "View 3 is not saved; “Save View 3” saves where you are looking", "no keys: the menu's words")
    #expect(
      sentence("nothing is docked yet: drag a window to a screen edge, or try `dock left`", keys: ["dock left": "⌃⌥⌘←"])
        == "Nothing is docked yet: drag a window to a screen edge, or try ⌃⌥⌘←")
  }

  @Test func adviceForATerminalIsLeftOut() {
    #expect(sentence("no focused window; `state` lists the windows Arbor knows") == "No focused window")
    #expect(sentence("no app has the keyboard; click one of its windows, or name it: `exclude <bundle id>`") == "No app has the keyboard")
    #expect(
      sentence("w5 is not a window Arbor arranges (`include com.apple.Music` if its app is excluded)", apps: [5: "Music"])
        == "Music is not a window Arbor arranges")
    #expect(sentence("no window has the keyboard; click one, or name one (`state` lists their ids)") == "No window has the keyboard; click one")
    #expect(sentence("red, or blue; this, or that (`state` says which); and more") == "Red, or blue; this; and more", "only the alternative the bracket explains")
    #expect(sentence("one, or two; three (`state`)") == "One, or two; three")
    #expect(sentence("try `nonsense here`") == "Try nonsense here", "what happened is said whatever it quotes")
  }

  @Test func anAppsNameCannotBreakTheLineOrTurnItRound() {
    #expect(sentence("w1 is floating", apps: [1: "Evil\nApp\u{202E}"]) == "EvilApp is floating")
    #expect(sentence("moved to Evil\u{2028}App (n4)") == "Moved to EvilApp")
  }

  @Test func anEndlessReplyIsCut() {
    let long = sentence(String(repeating: "word ", count: 100))
    #expect(long.count == 160)
    #expect(long.hasSuffix("…"))
  }

  // MARK: How long

  @Test func readOutTheLineIsTwoSentences() {
    #expect(HeadsUpModel(kind: .hint, text: "Docked", hint: "⌃⌥↩ frames it").spoken == "Docked. ⌃⌥↩ frames it")
    #expect(HeadsUpModel(kind: .problem, text: "Already showing everything").spoken == "Already showing everything")
  }

  @Test func aFewWordsGetAGlanceAndASentenceTimeToBeRead() {
    #expect(HeadsUpModel(kind: .problem, text: "No space to the left").duration == 1.5)
    let hint = HeadsUpHint.outOfView.model(facts: HeadsUpFacts(docked: 3, outOfView: 2, tiles: 0)) { _ in "⌃⌥Space" }
    #expect(hint.duration > 4 && hint.duration < 5)
    #expect(HeadsUpModel(kind: .reply, text: String(repeating: "x", count: 160)).duration == 6)
  }

  // MARK: Where

  private let visible = CGRect(x: 1440, y: 25, width: 1000, height: 775)

  @Test func theLineSitsLowAndCentredOnItsDisplay() {
    let placed = HeadsUpModel(kind: .problem, text: "No").placed(in: visible)
    #expect(placed.anchor == CGPoint(x: 1940, y: 800 - 56))
    #expect(placed.maximumWidth == 720)
    #expect(HeadsUpModel(kind: .problem, text: "No").placed(in: CGRect(x: 0, y: 0, width: 500, height: 400)).maximumWidth == 436)
  }

  @Test func theLineSitsDirectlyAboveAnotherPanelAtTheBottom() {
    let minimap = CGRect(x: 1840, y: 620, width: 200, height: 124)
    let placed = HeadsUpModel(kind: .hint, text: "Docked").placed(in: visible, above: minimap)
    #expect(placed.anchor == CGPoint(x: 1940, y: 610))
  }

  @Test func onATinyDisplayTheLineStaysInside() {
    let tiny = CGRect(x: 0, y: 0, width: 100, height: 60)
    let placed = HeadsUpModel(kind: .hint, text: "Docked").placed(in: tiny)
    #expect(tiny.contains(placed.anchor))
    #expect(placed.maximumWidth > 0)
  }

  // MARK: Teaching moments

  private func facts(_ docked: Int, _ outOfView: Int, _ tiles: Int) -> HeadsUpFacts {
    HeadsUpFacts(docked: docked, outOfView: outOfView, tiles: tiles)
  }

  @Test func momentsAreReadFromWhatChanged() {
    #expect(facts(0, 0, 0).moments(to: facts(1, 0, 0)) == [.docked])
    #expect(facts(2, 0, 0).moments(to: facts(2, 1, 0)) == [.outOfView])
    #expect(facts(2, 0, 0).moments(to: facts(2, 0, 1)) == [.tile])
    #expect(facts(2, 0, 0).moments(to: facts(2, 0, 0)) == [])
    #expect(facts(1, 0, 0).moments(to: facts(2, 1, 1)) == [.outOfView, .tile, .docked], "the most pressing first")
  }

  @Test func onlyTheMomentItselfCounts() {
    #expect(facts(3, 2, 0).moments(to: facts(3, 2, 0)) == [], "walking from one framed window to the next")
    #expect(facts(3, 1, 0).moments(to: facts(3, 2, 0)) == [], "some were out of view already")
    #expect(facts(3, 2, 1).moments(to: facts(3, 0, 2)) == [], "there was a tile already")
    #expect(facts(0, 0, 0).moments(to: facts(4, 0, 0)) == [], "after `arrange` there is no “it” to frame")
    #expect(facts(2, 0, 0).moments(to: facts(1, 0, 0)) == [])
  }

  @Test func hintsNameTheKeysInEffectOrDoWithout() {
    let two = facts(3, 2, 0)
    let keys: (Command) -> String? = { $0 == .showAll ? "⌃⌥Space" : $0 == .zoom(nil) ? "⌃⌥↩" : $0 == .find(nil) ? "⌃⌥G" : nil }
    // docs/GLOSSARY.md, "Sentences to reuse".
    #expect(HeadsUpHint.outOfView.model(facts: two, shortcut: keys).line == "Your other windows are out of view, not closed · ⌃⌥Space shows everything")
    #expect(HeadsUpHint.outOfView.model(facts: facts(2, 1, 0), shortcut: keys).text == "Your other window is out of view, not closed")
    #expect(HeadsUpHint.docked.model(facts: two, shortcut: keys).line == "Docked · ⌃⌥↩ frames it")
    #expect(HeadsUpHint.tile.model(facts: two, shortcut: keys).line == "Too small to show: click the tile to zoom in · ⌃⌥G goes there too")
    for hint in HeadsUpHint.allCases {
      let bare = hint.model(facts: two) { _ in nil }
      #expect(bare.hint == nil)
      #expect(bare.kind == .hint)
      #expect(!bare.text.isEmpty)
    }
  }
}
