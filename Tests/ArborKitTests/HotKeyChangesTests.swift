import ArborCore
import ArborKit
import ArborTesting
import Testing

/// A key of Arbor's that stays Arbor's is not let go of for a moment: the difference (`HotKeyChanges`). What is done with it,
/// step by step, is in `HotKeyTableTests`.
@Suite struct HotKeyChangesTests {
  private let all = KeyBindings.defaults

  @Test func theSameAgainChangesNothing() {
    let changes = HotKeyChanges(from: all, to: all)
    #expect(changes.isEmpty)
    #expect(changes.kept == all)
  }

  @Test func fromNothingAllAreAddedAndToNothingAllAreDropped() {
    #expect(HotKeyChanges(from: [], to: all).added == all)
    #expect(HotKeyChanges(from: [], to: all).dropped.isEmpty)
    #expect(HotKeyChanges(from: all, to: []).dropped == all)
    #expect(HotKeyChanges(from: all, to: []).added.isEmpty)
    #expect(HotKeyChanges(from: [], to: []).isEmpty)
  }

  @Test func aPauseDropsTheOthersAndKeepsItsOwn() {
    let paused = KeyBindings.whilePaused(all)
    #expect(!paused.isEmpty)
    let changes = HotKeyChanges(from: all, to: paused)
    #expect(changes.kept == paused)
    #expect(changes.added.isEmpty)
    #expect(changes.dropped.count == all.count - paused.count)
    let back = HotKeyChanges(from: paused, to: all)
    #expect(back.kept == paused)
    #expect(back.dropped.isEmpty)
    #expect(back.added.count == all.count - paused.count)
  }

  /// To macOS nothing changes, so nothing is asked of it. What is pressed next runs the new command.
  @Test func aKeyThatGetsAnotherCommandStaysRegistered() {
    let old = KeyBinding(.hyperless, .j, .arrange)
    let new = KeyBinding(.hyperless, .j, .showAll)
    let changes = HotKeyChanges(from: [old], to: [new])
    #expect(changes.isEmpty)
    #expect(changes.kept == [new])
  }

  /// On a German keyboard Y and Z have changed places: the key stays, and means the other letter's command.
  @Test func onAnotherKeyboardTheKeysThatOnlyChangeTheirMeaningStay() throws {
    let bindings = ["ctrl+opt+y": "arrange", "ctrl+opt+z": "show-all"] as [String: String?]
    var settings = Settings()
    settings.bindings = bindings
    let us = KeyBindings.effective(settings: settings, layout: SampleKeyLayouts.us).bindings
    let german = KeyBindings.effective(settings: settings, layout: SampleKeyLayouts.german).bindings
    let arrangeUS = try #require(us.first { $0.command == .arrange && $0.chord.key == .y })
    let showAllGerman = try #require(german.first { $0.command == .showAll && $0.chord.key == .z })
    #expect(HotKey(arrangeUS) == HotKey(showAllGerman))
    let changes = HotKeyChanges(from: us, to: german)
    #expect(changes.kept.contains(showAllGerman))
    #expect(!changes.dropped.contains { HotKey($0) == HotKey(arrangeUS) })
  }

  @Test func whatWasRefusedIsNotHeldAndSoIsAddedAgainAndAlone() {
    let changes = HotKeyChanges(from: all.filter { $0 != all[3] }, to: all)
    #expect(changes.added == [all[3]])
    #expect(changes.dropped.isEmpty)
  }

  /// `KeyBindings.effective` lets no two through. If it did: the second must not take the key over by being "kept".
  @Test func ofTwoThatMeanOneKeyOnlyTheFirstIsKept() {
    let first = KeyBinding(.hyperless, .j, .arrange)
    let second = KeyBinding(.hyperless, .j, .showAll)
    #expect(HotKeyChanges(from: [], to: [first, second]).added == [first, second])
    let later = HotKeyChanges(from: [first], to: [first, second])
    #expect(later.kept == [first])
    #expect(later.added == [second])
    #expect(later.dropped.isEmpty)
  }

  /// The value knows of no peek: whoever wants something kept names it (`HotKeyTable.hold`).
  @Test func whatIsHeldAndNotNamedGoes() {
    let extra = KeyBinding(KeyChord([.control, .option, .shift, .command], .escape), .showAll)
    let changes = HotKeyChanges(from: all + [extra], to: all)
    #expect(changes.dropped == [extra])
    #expect(changes.added.isEmpty)
    #expect(HotKeyChanges(from: all + [extra], to: all + [extra]).isEmpty)
  }
}
