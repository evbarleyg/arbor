import ArborCore
import CoreGraphics
import Foundation
import Testing

/// Keys follow the keyboard, gestures follow the pointer (docs/features/F56-keys-follow-the-keyboard.md).
@Suite struct InputLeadTests {
  /// The pointer and the keyboard were last touched this many seconds ago.
  private func hands(pointer: Double, keys: Double, presses: UInt32 = 0) -> InputActivity {
    InputActivity(pointerIdle: pointer, keyboardIdle: keys, keyPresses: presses)
  }

  private let keyboardSources: [CommandSource] = [.shortcut, .script, .url]

  @Test func aShortcutFollowsTheKeyboardWhileThePointerRests() {
    for source in keyboardSources {
      var lead = InputLead()
      #expect(
        lead.lead(for: source, rule: .auto, activity: hands(pointer: 600, keys: 0.4), focusIdle: 900) == .keyboard,
        "\(source)")
    }
  }

  @Test func aPointerThatMovedSinceTheLastKeyPressLeads() {
    for source in keyboardSources {
      var lead = InputLead()
      #expect(
        lead.lead(for: source, rule: .auto, activity: hands(pointer: 0.5, keys: 8), focusIdle: 900) == .pointer,
        "\(source)")
    }
  }

  @Test func aPointerThatMovedBeforeTheFocusChangedDoesNotLead() {
    // Nothing typed for a minute, the pointer left alone for ten seconds, and then a window took the keyboard.
    var lead = InputLead()
    lead.focusChanged()
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 10, keys: 60), focusIdle: 2) == .keyboard)
  }

  @Test func anAnswerIsWhatTheNextCommandWouldFollowAndLeavesNoTrace() {
    // A shortcut followed the pointer; then nothing but one more press.
    var lead = InputLead()
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 0.5, keys: 8, presses: 10), focusIdle: 900) == .pointer)
    let later = hands(pointer: 4, keys: 1, presses: 11)
    let before = lead
    #expect(lead.answer(for: .shortcut, rule: .auto, activity: later, focusIdle: 900) == .pointer, "it would go on")
    #expect(lead.answer(for: .shortcut, rule: .focus, activity: later, focusIdle: 900) == .keyboard)
    #expect(lead == before)
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: later, focusIdle: 900) == .pointer)
  }

  @Test func gesturesAndTheMenuFollowThePointerWhateverTheSetting() {
    for rule in StepInToward.allCases {
      for source in [CommandSource.gesture, .menu] {
        var lead = InputLead()
        #expect(
          lead.lead(for: source, rule: rule, activity: hands(pointer: 600, keys: 0.1), focusIdle: 0.1) == .pointer,
          "\(source) with \(rule)")
      }
    }
  }

  @Test func theSettingCanFixTheAnswerForShortcuts() {
    for source in keyboardSources {
      var lead = InputLead()
      #expect(lead.lead(for: source, rule: .pointer, activity: hands(pointer: 600, keys: 0.1), focusIdle: 1) == .pointer)
      #expect(lead.lead(for: source, rule: .focus, activity: hands(pointer: 0.1, keys: 600), focusIdle: 900) == .keyboard)
    }
  }

  @Test func aSecondShortcutGoesOnWhereTheFirstWent() {
    var lead = InputLead()
    // Point at something, press ⌃⌥↓…
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 0.5, keys: 20, presses: 41), focusIdle: 900) == .pointer)
    // …look, and press it again. The last key released is now the first ⌃⌥↓'s own.
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 4.5, keys: 3.9, presses: 42), focusIdle: 904) == .pointer)
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 9, keys: 4, presses: 43), focusIdle: 909) == .pointer)
  }

  @Test func aShortcutAfterAGestureStaysWithThePointer() {
    // A pinch moves no pointer, so only its command says that the hand is on the trackpad.
    var lead = InputLead()
    #expect(lead.lead(for: .gesture, rule: .auto, activity: hands(pointer: 30, keys: 5, presses: 7), focusIdle: 900) == .pointer)
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 32, keys: 7, presses: 8), focusIdle: 902) == .pointer)
  }

  @Test func typingGivesTheLeadBackToTheKeyboard() {
    var lead = InputLead()
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 0.5, keys: 20, presses: 41), focusIdle: 900) == .pointer)
    // A sentence later, with the pointer where it was.
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 30, keys: 0.3, presses: 90), focusIdle: 930) == .keyboard)
  }

  @Test func oneKeyTypedBetweenTwoShortcutsIsTyping() {
    var lead = InputLead()
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 0.5, keys: 20, presses: 41), focusIdle: 900) == .pointer)
    // One letter and the second shortcut's own press.
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 5, keys: 0.3, presses: 43), focusIdle: 905) == .keyboard)
  }

  @Test func aFocusChangeGivesTheLeadBackToTheKeyboard() {
    var lead = InputLead()
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 0.5, keys: 20, presses: 41), focusIdle: 900) == .pointer)
    lead.focusChanged()
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 5, keys: 4.4, presses: 42), focusIdle: 1) == .keyboard)
  }

  @Test func movingThePointerTakesTheLeadFromTheKeyboard() {
    var lead = InputLead()
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 60, keys: 0.3, presses: 41), focusIdle: 900) == .keyboard)
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 0.2, keys: 2, presses: 42), focusIdle: 902) == .pointer)
  }

  @Test func scriptsThatPressNoKeysGoOnWhereTheLastCommandWent() {
    var lead = InputLead()
    #expect(lead.lead(for: .script, rule: .auto, activity: hands(pointer: 0.5, keys: 20, presses: 41), focusIdle: 900) == .pointer)
    #expect(lead.lead(for: .script, rule: .auto, activity: hands(pointer: 25, keys: 44.5, presses: 41), focusIdle: 924) == .pointer)
  }

  @Test func askingTwiceGivesTheSameAnswer() {
    for (pointer, keys) in [(0.5, 20.0), (20.0, 0.5)] {
      var lead = InputLead()
      lead.focusChanged()
      let activity = hands(pointer: pointer, keys: keys, presses: 12)
      let first = lead.lead(for: .shortcut, rule: .auto, activity: activity, focusIdle: 100)
      #expect(lead.lead(for: .shortcut, rule: .auto, activity: activity, focusIdle: 100) == first)
      #expect(lead.last == first)
    }
  }

  @Test func theCountOfKeyPressesMayWrapRound() {
    var lead = InputLead()
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 0.5, keys: 20, presses: .max), focusIdle: 900) == .pointer)
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: 4.5, keys: 3.9, presses: 0), focusIdle: 904) == .pointer)
  }

  @Test func timesThatAreNotNumbersFollowTheKeyboard() {
    var lead = InputLead()
    #expect(lead.lead(for: .shortcut, rule: .auto, activity: hands(pointer: .nan, keys: .nan), focusIdle: .nan) == .keyboard)
  }

  @Test func inFromTheMenuStepsTowardTheFocusedWindow() {
    // The pointer is on the menu item.
    #expect(InputLead.stepsTowardFocus(lead: .pointer, source: .menu, rule: .auto))
    #expect(InputLead.stepsTowardFocus(lead: .pointer, source: .menu, rule: .focus))
    #expect(!InputLead.stepsTowardFocus(lead: .pointer, source: .menu, rule: .pointer))
    #expect(!InputLead.stepsTowardFocus(lead: .pointer, source: .gesture, rule: .focus))
    #expect(!InputLead.stepsTowardFocus(lead: .pointer, source: .shortcut, rule: .auto))
    #expect(InputLead.stepsTowardFocus(lead: .keyboard, source: .shortcut, rule: .auto))
  }

  // MARK: The setting

  @Test func stepInTowardIsAutoUnlessTheFileSaysOtherwise() throws {
    #expect(Settings().stepInToward == "auto")
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 8}"#.utf8))
    #expect(old.stepInToward == "auto")
    let chosen = try JSONDecoder().decode(Settings.self, from: Data(#"{"stepInToward": "focus"}"#.utf8))
    #expect(chosen.stepInToward == "focus")
    let again = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(chosen))
    #expect(again == chosen)
  }

  @Test func aValueNobodyDefinedMeansAuto() {
    #expect(StepInToward(setting: "pointer") == .pointer)
    #expect(StepInToward(setting: "Focus") == .focus)
    #expect(StepInToward(setting: "auto") == .auto)
    #expect(StepInToward(setting: "mouse") == .auto)
    #expect(StepInToward(setting: "") == .auto)
  }

  // MARK: One step toward a space

  @Test func stepInTowardASpaceTakesTheChildThatHoldsIt() {
    // root(h)[ column(v)[a, c], desktop, b ]
    var tree = LayoutTree()
    let a = tree.dock(WindowID(1), beside: tree.root, edge: .left)
    let b = tree.dock(WindowID(2), beside: tree.root, edge: .right)
    let c = tree.dock(WindowID(3), beside: a, edge: .bottom)
    let column = tree.parent(of: a)!
    let view = TreeView(tree: tree, isPresent: { _ in true })
    #expect(Navigation.stepIn(from: tree.root, toward: c, in: view) == column)
    #expect(Navigation.stepIn(from: column, toward: c, in: view) == c)
    #expect(Navigation.stepIn(from: tree.root, toward: b, in: view) == b)
    #expect(Navigation.stepIn(from: tree.root, toward: tree.desktop, in: view) == tree.desktop)
    #expect(Navigation.stepIn(from: column, toward: b, in: view) == nil, "b is not inside the column")
    #expect(Navigation.stepIn(from: c, toward: c, in: view) == nil, "a framed window has nothing inside it")
  }

  @Test func stepInTowardASpaceSkipsGroupsThatLookLikeTheirOnlyWindow() {
    // With c minimized the column looks like a, so one step from the root frames a.
    var tree = LayoutTree()
    let a = tree.dock(WindowID(1), beside: tree.root, edge: .left)
    _ = tree.dock(WindowID(2), beside: tree.root, edge: .right)
    _ = tree.dock(WindowID(3), beside: a, edge: .bottom)
    let column = tree.parent(of: a)!
    let view = TreeView(tree: tree, isPresent: { $0 != WindowID(3) })
    #expect(Navigation.stepIn(from: tree.root, toward: a, in: view) == column)
    #expect(Navigation.stepIn(from: column, toward: a, in: view) == nil)
  }
}
