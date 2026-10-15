import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The arrows and ⎋ belong to a peek for as long as its key is down, from the press on (docs/features/F51-peek.md, acceptance 4; board 1.80). Of the nine
/// keys that ship, ⌃⌥↑ and ⌃⌥↓ are bound to nothing. Arbor used to ask for them only once a tap had become a hold, 0.3 s
/// after the press, and gave them back as soon as the peek was decided: before and after, with ⌃⌥Space still down, they went to the app in front.
@Suite @MainActor struct PeekKeysFromThePressTests {
  /// Three windows docked, the one on the right above another, the view on the upper one of those. The settings as they ship, unless given.
  func makeHarness(_ settings: Settings = Settings()) -> (Harness, a: WindowID, b: WindowID, c: WindowID) {
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    let c = h.system.open(app: "Notes", bundleID: "com.example.notes")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("zoom \(b.rawValue)")
    return (h, a, b, c)
  }

  func got(_ h: Harness) -> [String] { h.system.keysTheAppInFrontGot.map(\.text) }
  let space = "ctrl+opt+space"

  @Test func theControlWithoutAPeekTheyAreTheApps() {
    let (h, _, _, _) = makeHarness()
    h.key("ctrl+opt+up")
    h.key("ctrl+opt+down")
    #expect(got(h) == ["ctrl+opt+up", "ctrl+opt+down"])
  }

  @Test(arguments: [0.0, 0.1, 0.29]) func anArrowInTheFirstMomentOfAHoldIsThePeeks(after seconds: Double) {
    let (h, _, _, c) = makeHarness()
    let tree = h.workspace.tree
    h.keyDown(space)
    h.scheduler.advance(by: seconds)
    #expect(!h.controller.isPeeking, "the control: too early to tell a tap from a hold")
    h.key("ctrl+opt+down")
    #expect(got(h) == [], "it is Arbor's from the press on")
    #expect(h.controller.isPeeking, "whoever presses an arrow with the key down is holding it")
    h.keyUp(space)
    #expect(h.workspace.camera == tree.leaf(containing: c), "down from the view that was left")
    #expect(h.workspace.tree == tree)
    expectWindowsMatchLayout(h)
  }

  @Test func aTapGivesThemBackAtItsRelease() {
    let (h, _, _, _) = makeHarness()
    var asked: [[String]] = []
    h.controller.onTemporaryShortcuts = { asked.append($0.map(\.chord.text)) }
    h.keyDown(space)
    #expect(asked == [["ctrl+opt+up", "ctrl+opt+down"]], "asked for at the press")
    h.scheduler.advance(by: 0.1)
    h.keyUp(space)
    #expect(asked.last == [] && asked.count == 2)
    #expect(h.controller.temporaryShortcuts.isEmpty)
    h.key("ctrl+opt+up")
    #expect(got(h) == ["ctrl+opt+up"], "the app's again")
  }

  /// A hot key is Arbor's only once macOS has been asked, and showing everything moves every window first, each move a call into an app: tens of
  /// milliseconds with a dozen windows, and more with a busy one. The arrow that is rolled off the fingers does not wait for that.
  @Test func theyAreAskedForBeforeAnyWindowIsMoved() {
    let (h, _, _, _) = makeHarness()
    let before = h.system.frameLog.count
    var movedByThen: [Int] = []
    h.controller.onTemporaryShortcuts = { _ in movedByThen.append(h.system.frameLog.count - before) }
    h.keyDown(space)
    #expect(h.system.frameLog.count > before, "or this proves nothing")
    #expect(movedByThen == [0])
    h.keyUp(space)
  }

  /// F51, acceptance 1: pressed and let go within 0.3 s the view is on everything, with one entry in history. An arrow that leads nowhere is kept
  /// from the app and changes nothing about that.
  @Test func anEarlyArrowThatLeadsNowhereLeavesATapATap() {
    let (h, _, b, _) = makeHarness()
    let tree = h.workspace.tree
    h.keyDown(space)
    h.scheduler.advance(by: 0.1)
    h.key("ctrl+opt+up")
    #expect(got(h) == [])
    #expect(!h.controller.isPeeking)
    h.scheduler.advance(by: 0.1)
    h.keyUp(space)
    #expect(h.workspace.camera == tree.root)
    #expect(h.workspace.back.last == tree.leaf(containing: b))
  }

  // MARK: Unless the person said so themselves

  /// Decided by a click on a window of an app that keeps its own ⌃⌥, and the key still down.
  @Test func inAnAppThatKeepsItsOwnKeysTheyAreTheAppsAtOnce() {
    var settings = Settings()
    settings.passThroughApps = ["com.example.notes"]
    let (h, _, _, c) = makeHarness(settings)
    var asked: [[String]] = []
    h.controller.onTemporaryShortcuts = { asked.append($0.map(\.chord.text)) }
    h.keyDown(space)
    h.scheduler.advance(by: 0.5)
    h.system.userFocus(c)
    #expect(h.controller.isPassingThrough, "or this proves nothing")
    #expect(asked.last == [], "the app was told, at the change")
    h.key("ctrl+opt+down")
    #expect(got(h) == ["ctrl+opt+down"])
    h.keyUp(space)
    #expect(asked.count == 2)
  }

  @Test(arguments: [0.1, 0.5]) func withTheShortcutsSwitchedOffTheyAreTheAppsAtOnce(after seconds: Double) {
    let (h, _, _, _) = makeHarness()
    h.keyDown(space)
    h.scheduler.advance(by: seconds)
    h.run("set hotkeysEnabled false")
    #expect(h.controller.temporaryShortcuts.isEmpty)
    h.key("ctrl+opt+down")
    #expect(got(h) == ["ctrl+opt+down"])
    h.keyUp(space)
  }

  /// The list follows the map while the key is down: what is given a command of its own is no longer the peek's alone, and what loses its own is.
  @Test func theListFollowsTheMapWhileTheKeyIsDown() {
    let (h, _, _, _) = makeHarness()
    h.keyDown(space)
    #expect(h.controller.temporaryShortcuts.map(\.chord.text) == ["ctrl+opt+up", "ctrl+opt+down"])
    h.run("unbind ctrl+opt+left", from: .script)
    #expect(h.controller.temporaryShortcuts.map(\.chord.text) == ["ctrl+opt+left", "ctrl+opt+up", "ctrl+opt+down"])
    h.key("ctrl+opt+left")
    #expect(got(h) == [])
    h.keyUp(space)
    #expect(h.controller.temporaryShortcuts.isEmpty)
  }

  // MARK: Given back

  /// A tap whose release is never reported: the timer finds the keys up.
  @Test func aReleaseThatIsNeverReportedGivesThemBackToo() {
    let (h, _, _, _) = makeHarness()
    h.keyDown(space)
    h.keyUp(space, reported: false)
    h.scheduler.advance(by: 0.1)
    #expect(h.controller.temporaryShortcuts.isEmpty)
  }

  /// ⎋ has decided the peek, or another command has, and the key is still down: everything looks as it did a moment ago.
  @Test(arguments: ["ctrl+opt+escape", "ctrl+opt+f"]) func onceAPeekIsDecidedTheyDoNothingAndGoNowhereUntilItsKeyComesUp(ending: String) {
    let (h, _, _, _) = makeHarness()
    h.keyDown(space)
    h.scheduler.advance(by: 0.5)
    h.key(ending)
    #expect(!h.controller.isPeeking && !h.controller.isPaused)
    let (tree, camera) = (h.workspace.tree, h.workspace.camera)
    h.key("ctrl+opt+up")
    h.key("ctrl+opt+down")
    #expect(got(h) == [])
    #expect(h.workspace.tree == tree && h.workspace.camera == camera)
    h.keyUp(space)
    #expect(h.controller.temporaryShortcuts.isEmpty)
    h.key("ctrl+opt+up")
    #expect(got(h) == ["ctrl+opt+up"])
  }

  /// Decided, and then the release is never reported: the timer goes on looking for as long as anything is kept.
  @Test func afterAPeekIsDecidedAReleaseThatIsNeverReportedGivesThemBackToo() {
    let (h, _, _, _) = makeHarness()
    h.keyDown(space)
    h.scheduler.advance(by: 0.5)
    h.key("ctrl+opt+f")
    #expect(!h.controller.temporaryShortcuts.isEmpty)
    h.keyUp(space, reported: false)
    h.scheduler.advance(by: 0.1)
    #expect(h.controller.temporaryShortcuts.isEmpty)
    #expect(!h.scheduler.pendingKeys.contains("peek"))
  }

  /// A pause is the person's own word: every key but its own goes back at once, key down or not.
  @Test func aPauseGivesThemBackAtOnce() {
    let (h, _, _, _) = makeHarness()
    h.keyDown(space)
    h.run("pause", from: .menu)
    #expect(h.controller.temporaryShortcuts.isEmpty)
    h.key("ctrl+opt+up")
    #expect(got(h) == ["ctrl+opt+up"])
  }

  /// Whoever holds ⌃⌥Space and reaches for ⎋ means "never mind", and with ⌃ and ⌥ down that is ⌃⌥⎋, which pauses Arbor: every window moves, the opposite
  /// of never mind. For as long as the peek's key is down it is the peek's: early or in the hold it calls the peek off; again, it does nothing.
  @Test(arguments: ["core", "all"], [0.1, 0.5]) func escapeIsThePeeksForAsLongAsItsKeyIsDown(map: String, after seconds: Double) {
    let (h, _, _, _) = makeHarness()
    h.run("set shortcuts \(map)")
    let before = h.workspace
    h.keyDown(space)
    h.scheduler.advance(by: seconds)
    h.key("ctrl+opt+escape")
    #expect(!h.controller.isPaused && h.controller.isRunning, "it calls the peek off")
    #expect(h.workspace == before, "back where it was, and nothing in history")
    let moves = h.system.frameLog.count
    h.key("ctrl+opt+escape")
    #expect(!h.controller.isPaused, "again: nothing")
    #expect(h.workspace == before && h.system.frameLog.count == moves)
    #expect(got(h) == [])
    h.keyUp(space)
    #expect(h.workspace == before)
    expectWindowsMatchLayout(h)
    h.key("ctrl+opt+escape")
    #expect(h.controller.isPaused, "and it pauses again from the moment the key is up")
  }

  /// Someone who has given ⌃⌥⎋ back to their apps still has it to call a peek off, early as well.
  @Test func anEscapeThatIsBoundToNothingCallsThePeekOffFromThePressOn() {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+escape": nil]
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("zoom \(b.rawValue)")
    let camera = h.workspace.camera
    h.keyDown(space)
    h.scheduler.advance(by: 0.1)
    var outlines = 0
    h.overlays.onCall = { _ in if h.overlays.scenes[h.display]?.peekOutline != nil { outlines += 1 } }
    h.key("ctrl+opt+escape")
    #expect(got(h) == [])
    #expect(outlines == 0, "no outline for the length of no time")
    #expect(h.workspace.camera == camera, "back where it was")
    h.keyUp(space)
    #expect(h.workspace.camera == camera)
    expectWindowsMatchLayout(h)
  }

  /// Where there is no peek the key is the plain command's, and nothing is asked for.
  @Test func withPeekingOffNothingIsAskedFor() {
    var settings = Settings()
    settings.peek = false
    let h = Harness(settings: settings)
    h.system.open(app: "Safari")
    h.start()
    var asked = 0
    h.controller.onTemporaryShortcuts = { _ in asked += 1 }
    h.keyDown(space)
    h.key("ctrl+opt+up")
    h.keyUp(space)
    #expect(asked == 0)
    #expect(got(h) == ["ctrl+opt+up"])
  }
}
