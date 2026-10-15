import ArborCore
import ArborKit
import ArborTesting
import Testing

/// A key of Arbor's that is not Arbor's at this moment is known and said: `bindings`, `doctor`, Check Setup, the log.
@Suite @MainActor struct KeysHeldTests {
  private let map = KeyBindings.defaults
  private var count: Int { map.count }

  private static let healthy = SystemFacts(
    accessibility: true, screenRecording: true, switches: [], separateSpaces: true, voiceOver: false, inputSources: 1,
    eventTaps: ["pinch", "scroll", "rectangle"])

  /// A started Arbor whose app has registered what the controller wants, as `ArborApp.registerHotKeys` does at every change.
  private func makeHarness(settings: Settings = Settings()) -> Harness {
    let h = Harness(settings: settings)
    h.controller.systemFacts = { Self.healthy }
    h.start()
    register(h)
    return h
  }

  /// What the app does when it is told that the answer may have changed, on a Mac that refuses `refusing`.
  private func register(_ h: Harness, refusing: [Command] = []) {
    let wanted = h.controller.activeBindings
    h.controller.refusedBindings = wanted.filter { refusing.contains($0.command) }
    h.controller.registeredBindings = wanted.filter { !refusing.contains($0.command) }
  }

  private func shortcuts(_ h: Harness) -> DoctorReport.Check? { h.controller.doctorReport().check("Shortcuts") }
  private func row(_ h: Harness) -> OnboardingModel.Row? { h.controller.onboardingModel(Self.healthy).row(.lostShortcuts) }
  private func line(_ h: Harness, _ command: String) -> String? {
    h.run("bindings").text?.split(separator: "\n").map(String.init).first { $0.contains(" → \(command)") }
  }

  // MARK: The value

  @Test func eachKeyHasOneOfFourFates() {
    let wanted = Array(map.dropFirst(2))
    let held = KeysHeld(map: map, wanted: wanted, registered: Array(wanted.dropFirst(2)), refused: [wanted[0]])
    #expect(held.keys.map(\.binding) == map, "every key of the map, in its order")
    #expect(held.all(.handedOver) == Array(map.prefix(2)))
    #expect(held.all(.refused) == [wanted[0]])
    #expect(held.all(.missing) == [wanted[1]])
    #expect(held.all(.held) == Array(wanted.dropFirst(2)))
    #expect(held.lost == [wanted[0], wanted[1]], "what nobody asked to be the apps'")
  }

  @Test func untilTheAppHasSaidWhatIsWantedCountsAsHeld() {
    let held = KeysHeld(map: map, wanted: Array(map.prefix(3)), registered: nil, refused: [])
    #expect(held.all(.held) == Array(map.prefix(3)))
    #expect(held.all(.handedOver).count == count - 3)
    #expect(held.lost.isEmpty)
  }

  /// A key is held for a command. On the right key with the wrong command it would do something else than the menu says.
  @Test func aKeyThatIsRegisteredForAnotherCommandIsNotHeld() {
    let wanted = KeyBinding(.hyperless, .j, .arrange)
    let stale = KeyBinding(.hyperless, .j, .showAll)
    #expect(KeysHeld(map: [wanted], wanted: [wanted], registered: [stale], refused: []).all(.missing) == [wanted])
  }

  @Test func thereIsNoNewsWhileArborHoldsTheWholeMap() {
    #expect(KeysHeld(map: map, wanted: map, registered: map, refused: []).news(why: nil) == nil)
    #expect(KeysHeld(map: [], wanted: [], registered: [], refused: []).news(why: nil) == nil)
  }

  @Test func theNewsNamesWhatIsLostAndCountsWhatWasHandedOver() {
    let a = KeyBinding(.hyperless, .a, .arrange)
    let j = KeyBinding(.hyperless, .j, .showAll)
    let k = KeyBinding(.hyperless, .k, .home)
    let held = KeysHeld(map: [a, j, k], wanted: [a, j], registered: [], refused: [a])
    #expect(
      held.news(why: "while Arbor is paused")
        == "1 of the map's 3 are the apps' while Arbor is paused; macOS refused ⌃⌥A; ⌃⌥J wanted and not registered")
    #expect(KeysHeld(map: map, wanted: map, registered: [], refused: []).news(why: nil) == "\(count) wanted and not registered")
  }

  // MARK: An ordinary day says nothing

  @Test func withEveryKeyHeldNothingIsSaidAnywhere() {
    let h = makeHarness()
    #expect(h.controller.keysHeld.all(.held).count == count)
    #expect(h.run("bindings").message == "\(count) shortcuts")
    #expect(h.run("bindings").text?.contains("(") == false)
    #expect(shortcuts(h)?.mark == .ok)
    #expect(shortcuts(h)?.detail == "\(count) registered")
    // What the tick is worth. A hosted Mac said yes to Arbor whoever else held the key.
    #expect(
      shortcuts(h)?.notes == ["macOS does not tell Arbor when another program has registered the same key: then both get it, or the other alone"])
    #expect(row(h) == nil)
    #expect(h.controller.keysHeldForTheLog == nil)
  }

  // MARK: Refused

  @Test func aKeyThatMacOSRefusedIsSaidEverywhere() {
    let h = makeHarness()
    register(h, refusing: [.arrange])
    #expect(h.controller.keysHeld.all(.refused).map(\.label) == ["⌃⌥A"])
    let result = h.run("bindings")
    #expect(result.ok, "a query")
    #expect(result.message == "\(count) shortcuts, 1 not Arbor's")
    #expect(line(h, "arrange")?.hasSuffix(" → arrange  (macOS refused it: Arbor does not hear it)") == true)
    #expect(result.text?.contains("\n\n⌃⌥A is not Arbor's, though nobody asked for that: Arbor does not hear what is pressed there") == true)
    #expect(line(h, "show-all")?.hasSuffix(" → show-all") == true, "the others are")
    #expect(shortcuts(h)?.mark == .problem)
    #expect(shortcuts(h)?.detail == "\(count - 1) registered; macOS refused ⌃⌥A, which Arbor so does not hear")
    #expect(!h.run("doctor").ok)
    #expect(h.controller.setupProblemLines.contains { $0.hasPrefix("setup: Shortcuts: \(count - 1) registered; macOS refused ⌃⌥A") })
    #expect(row(h)?.title == "⌃⌥A is not Arbor’s")
    #expect(row(h)?.needsAttention == true)
    #expect(h.controller.onboardingModel(Self.healthy).title == "One thing is in the way")
    #expect(h.controller.keysHeldForTheLog == "macOS refused ⌃⌥A")
    #expect(h.controller.shortcut(for: .arrange) == nil, "and the menu does not show it")
    // It is tried again at every change, and one day macOS says yes.
    register(h)
    #expect(h.run("bindings").message == "\(count) shortcuts")
    #expect(shortcuts(h)?.mark == .ok)
    #expect(row(h) == nil)
  }

  @Test func manyLostKeysAreCountedInTheWindowsTitle() {
    let h = makeHarness()
    register(h, refusing: [.arrange, .showAll, .home])
    #expect(row(h)?.title == "⌃⌥Space, ⌃⌥A and ⌃⌥0 are not Arbor’s")
    register(h, refusing: map.map(\.command))
    #expect(row(h)?.title == "\(count) shortcuts are not Arbor’s")
  }

  // MARK: Missing

  /// What used to get a tick: Arbor runs, shows fifty keys in its menu's place, and holds none.
  @Test func anArborThatRunsAndHoldsNothingIsAProblemAndNotATick() {
    let h = makeHarness()
    h.controller.registeredBindings = []
    #expect(h.controller.keysHeld.all(.missing).count == count)
    #expect(shortcuts(h)?.mark == .problem)
    #expect(shortcuts(h)?.detail == "0 registered; \(count) that Arbor wants are not, and reach the app in front")
    #expect(shortcuts(h)?.notes == ["Quit Arbor and open it again; its log says what macOS answered"])
    #expect(h.run("bindings").text?.contains("\n\n\(count) shortcuts are not Arbor's, though nobody asked for that") == true)
    #expect(!h.run("doctor").ok)
    #expect(h.run("bindings").message == "\(count) shortcuts, \(count) not Arbor's")
    #expect(line(h, "arrange")?.hasSuffix("(not registered: the app in front gets it)") == true)
    #expect(row(h)?.title == "\(count) shortcuts are not Arbor’s")
  }

  @Test func oneMissingKeyIsAProblemToo() {
    let h = makeHarness()
    h.controller.registeredBindings = map.filter { $0.command != .arrange }
    #expect(shortcuts(h)?.detail == "\(count - 1) registered; 1 that Arbor wants is not, and reaches the app in front")
    #expect(h.controller.keysHeldForTheLog == "⌃⌥A wanted and not registered")
  }

  // MARK: Handed over, because the person said so: known and said, and nothing is wrong

  @Test func aPauseHandsKeysOverAndThatIsSaidAndIsNoProblem() {
    let h = makeHarness()
    h.run("pause")
    register(h)
    let kept = h.controller.activeBindings.count
    #expect(kept < count)
    #expect(h.controller.keysHeld.all(.handedOver).count == count - kept)
    #expect(h.controller.keysHeld.lost.isEmpty)
    #expect(h.run("bindings").message == "\(count) shortcuts, all but \(kept) off while Arbor is paused")
    #expect(line(h, "arrange")?.hasSuffix(" → arrange  (the apps' now)") == true)
    #expect(shortcuts(h)?.mark == .ok)
    #expect(row(h) == nil)
    #expect(h.controller.keysHeldForTheLog == "\(count - kept) of the map's \(count) are the apps' while Arbor is paused")
    h.run("resume")
    register(h)
    #expect(h.controller.keysHeldForTheLog == nil)
  }

  @Test func inAnAppThatKeepsItsOwnKeysTheLogNamesNoApp() {
    let h = makeHarness()
    h.system.activate(bundleID: "org.gnu.Emacs", name: "Emacs")
    h.run("pass-through org.gnu.Emacs on")
    register(h)
    let kept = h.controller.activeBindings.count
    #expect(h.run("bindings").message == "\(count) shortcuts, all but \(kept) off in Emacs")
    #expect(h.controller.keysHeldForTheLog == "\(count - kept) of the map's \(count) are the apps' in the app in front")
    #expect(h.controller.keysHeld.lost.isEmpty)
    #expect(row(h) == nil)
  }

  @Test func withShortcutsSwitchedOffAllAreTheApps() {
    var settings = Settings()
    settings.hotkeysEnabled = false
    let h = makeHarness(settings: settings)
    #expect(h.controller.keysHeld.all(.handedOver).count == count)
    #expect(h.controller.keysHeldForTheLog == "\(count) of the map's \(count) are the apps' because hotkeysEnabled is false")
    #expect(h.run("bindings").text?.hasSuffix("\n\nRight now: all off because hotkeysEnabled is false.") == true)
    #expect(row(h) == nil)
  }

  @Test func whileAShortcutIsRecordedThatIsTheReason() {
    let h = makeHarness()
    h.controller.isRecordingShortcut = true
    register(h)
    #expect(h.run("bindings").message == "\(count) shortcuts, all off while a shortcut is being recorded")
    #expect(h.controller.keysHeld.lost.isEmpty)
    // Arbor is there and its keys are not: no tick, and the reason.
    #expect(
      shortcuts(h) == .init(mark: .note, title: "Shortcuts", detail: "0 registered; the others are the apps’ while a shortcut is being recorded"))
    #expect(h.run("doctor").ok, "nothing is wrong")
    h.controller.isRecordingShortcut = false
    register(h)
    #expect(h.run("bindings").message == "\(count) shortcuts")
  }

  /// The words follow what `activeBindings` answers: whatever rule decides there, a state in which Arbor asks for all its keys is
  /// not called one in which they are off.
  @Test func noReasonIsGivenWhileArborAsksForAllItsKeys() {
    let h = makeHarness()
    #expect(h.controller.activeBindings.count == count)
    #expect(h.run("bindings").text?.contains("Right now") == false)
  }

  /// `ARBOR_NO_HOTKEYS`, as nearly every script and the end-to-end runner start Arbor: asked for, so nothing is lost.
  @Test func whoeverStartedArborWithoutShortcutsIsToldSoAndNotThatFiftyAreMissing() {
    var facts = Self.healthy
    facts.inputDisabled = true
    let h = Harness()
    h.controller.systemFacts = { facts }
    h.controller.shortcutsAreDisabled = true
    let app = FakeHotKeys(h.controller)
    h.start()
    app.register()
    #expect(app.lines == ["registered 0 shortcuts in 0 µs: \(count) of the map's \(count) are the apps' because ARBOR_NO_HOTKEYS is set"])
    #expect(app.registrations == 0 && app.server.asked == 0, "nobody talks to macOS")
    #expect(h.controller.keysHeld.all(.handedOver).count == count)
    #expect(h.controller.keysHeld.lost.isEmpty)
    #expect(h.run("bindings").message == "\(count) shortcuts, all off because ARBOR_NO_HOTKEYS is set")
    #expect(h.run("bindings").text?.hasSuffix("\n\nRight now: all off because ARBOR_NO_HOTKEYS is set.") == true)
    #expect(line(h, "arrange")?.hasSuffix(" → arrange  (the apps' now)") == true)
    #expect(shortcuts(h)?.detail == "off (ARBOR_NO_HOTKEYS)")
    #expect(h.controller.onboardingModel(facts).row(.lostShortcuts) == nil)
    h.run("pause")
    h.run("resume")
    #expect(app.lines.count == 1, "and that is said once")
  }

  // MARK: The app and the controller together: what is asked of macOS, and what goes into the log

  /// A started Arbor with the part of the app that holds shortcuts wired in as in life.
  private func makeApp(settings: Settings = Settings(), prepare: (FakeHotKeys) -> Void = { _ in }) -> (Harness, FakeHotKeys) {
    let h = Harness(settings: settings)
    h.controller.systemFacts = { Self.healthy }
    h.watchAccessibility()
    let app = FakeHotKeys(h.controller)
    prepare(app)
    h.system.open(app: "Safari")
    h.start()
    app.register()
    return (h, app)
  }

  @Test func everyChangeOfWhatIsHeldGetsALineAlsoWhenThatIsNothing() {
    let (h, app) = makeApp()
    #expect(app.lines == ["registered \(count) shortcuts in 900 µs"])
    h.run("pause")
    let kept = h.controller.activeBindings.count
    #expect(app.lines.last == "registered \(kept) shortcuts in 900 µs: \(count - kept) of the map's \(count) are the apps' while Arbor is paused")
    h.run("resume")
    #expect(app.lines.last == "registered \(count) shortcuts in 900 µs")
    h.run("set hotkeysEnabled false")
    #expect(app.lines.last == "registered 0 shortcuts in 900 µs: \(count) of the map's \(count) are the apps' because hotkeysEnabled is false")
    #expect(app.server.keys.isEmpty)
    h.run("set hotkeysEnabled true")
    #expect(app.lines.last == "registered \(count) shortcuts in 900 µs")
    #expect(app.lines.count == 5)
  }

  @Test func whatLeavesTheShortcutsAsTheyAreAsksNothingOfMacOSAndSaysNothing() {
    let (h, app) = makeApp()
    let (registrations, asked) = (app.registrations, app.server.asked)
    h.run("set gap 20")
    h.run("exclude com.example.notes")
    h.system.activate(bundleID: "com.example.notes", name: "Notes")
    h.run("hold")
    h.run("release")
    #expect(app.registrations == registrations && app.server.asked == asked)
    #expect(app.lines.count == 1)
  }

  @Test func aRefusalIsLoggedWithItsNumberOnceAndTriedAgainInSilenceUntilItGoesOtherwise() throws {
    let arrange = try #require(map.first { $0.command == .arrange })
    let (h, app) = makeApp { $0.server.refuses = [HotKey(arrange)] }
    #expect(
      app.lines == [
        "shortcuts: macOS said no to ⌃⌥A (error -9879)", "registered \(count - 1) shortcuts in 900 µs: macOS refused ⌃⌥A",
      ])
    #expect(h.controller.keysHeld.all(.refused) == [arrange])
    let asked = app.server.asked
    app.server.steps = []
    h.run("hold")
    h.run("release")
    #expect(app.server.asked == asked + 2, "tried again at each occasion, and alone")
    #expect(app.server.steps.isEmpty, "no other key is touched for it")
    #expect(app.lines.count == 2, "and nothing is said twice")
    app.server.refuses = []
    h.run("hold")
    #expect(app.lines.last == "registered \(count) shortcuts in 900 µs")
    #expect(app.lines.count == 3)
    #expect(h.controller.keysHeld.lost.isEmpty)
  }

  /// Not fifty refusals, whose cure would be fifty other shortcuts.
  @Test func anArborThatCannotListenHoldsNothingSaysSoAndTriesAgain() {
    let (h, app) = makeApp { $0.isDeaf = true }
    #expect(app.lines == ["registered 0 shortcuts in 900 µs: \(count) wanted and not registered"])
    #expect(app.server.keys.isEmpty, "a key nobody hears is taken from nobody")
    #expect(h.controller.keysHeld.all(.missing).count == count)
    #expect(h.controller.refusedBindings.isEmpty)
    #expect(shortcuts(h)?.mark == .problem)
    #expect(row(h)?.title == "\(count) shortcuts are not Arbor’s")
    h.run("hold")
    h.run("release")
    #expect(app.lines.count == 1, "trying again is not news")
    app.isDeaf = false
    h.run("hold")
    #expect(app.lines.last == "registered \(count) shortcuts in 900 µs")
    #expect(h.controller.keysHeld.lost.isEmpty)
  }

  @Test func aKeyThatMacOSWillNotTakeBackIsSaidAndCountsAsHeld() throws {
    let arrange = try #require(map.first { $0.command == .arrange })
    let (h, app) = makeApp()
    app.server.keeps = [HotKey(arrange)]
    h.run("pause")
    let kept = h.controller.activeBindings.count
    #expect(app.lines.suffix(2).first == "shortcuts: macOS said would not take back ⌃⌥A (error -1)")
    #expect(app.lines.last?.hasPrefix("registered \(kept + 1) shortcuts in 900 µs: \(count - kept - 1) of the map's") == true)
    #expect(h.controller.keysHeld.all(.held).contains(arrange), "the truth: no app gets it")
    #expect(app.leaked.isEmpty)
  }

  // MARK: A key and its twin with fn are one

  /// A person sees fifty-two, or nine: keys, not registrations.
  @Test func everythingCountsKeysAndNotRegistrations() {
    let (h, app) = makeApp()
    #expect(app.server.registrations.count > count + 30, "most keys are registered twice")
    #expect(app.table.count == count)
    #expect(app.lines == ["registered \(count) shortcuts in 900 µs"])
    #expect(h.run("bindings").message == "\(count) shortcuts")
    #expect(h.run("bindings").text?.split(separator: "\n").filter { $0.contains(" → ") }.count == count)
    #expect(shortcuts(h)?.detail == "\(count) registered")
    #expect(h.controller.registeredBindings?.count == count)
  }

  /// The key is Arbor's. What is amiss is for whoever reads the log.
  @Test func aTwinThatMacOSRefusesIsLoggedAndIsNoProblem() throws {
    let arrange = try #require(map.first { $0.command == .arrange })
    let (h, app) = makeApp { $0.server.refusesTwins = [HotKey(arrange)] }
    #expect(app.lines == ["shortcuts: macOS said no to fn ⌃⌥A (error -9879)", "registered \(count) shortcuts in 900 µs"])
    #expect(h.controller.keysHeld.all(.held).count == count)
    #expect(h.controller.keysHeld.lost.isEmpty && h.controller.refusedBindings.isEmpty)
    #expect(shortcuts(h)?.mark == .ok)
    #expect(h.run("doctor").ok)
    #expect(row(h) == nil)
    #expect(h.run("bindings").message == "\(count) shortcuts")
    #expect(app.runs(HotKey(arrange)).map(\.command) == [.arrange])
    // Tried again at every occasion, alone, and in silence while the answer is the same.
    let asked = app.server.asked
    app.server.steps = []
    h.run("hold")
    h.run("release")
    #expect(app.server.asked == asked + 2 && app.server.steps.isEmpty)
    #expect(app.lines.count == 2)
    h.run("pause")
    h.run("resume")
    #expect(app.lines.filter { $0.contains("fn ⌃⌥A") }.count == 2, "said again when the key came back and the twin did not")
    app.server.refusesTwins = []
    h.run("hold")
    #expect(app.runs(HotKey(arrange), fn: true).map(\.command) == [.arrange])
    let registrations = app.registrations
    h.run("release")
    #expect(app.registrations == registrations, "and then macOS is left in peace")
  }

  /// What a macOS that will have none of them would make of it: one short line, the same whatever the order, and every key Arbor's.
  @Test func ifMacOSRefusesEveryTwinTheLogHasOneShortLineAndNothingIsWrong() {
    let (h, app) = makeApp { $0.server.refusesTwins = Set(KeyBindings.defaults.map(HotKey.init)) }
    let twins = map.filter(\.chord.hasFnTwin).count
    #expect(app.lines.count == 2)
    #expect(app.lines.first?.hasPrefix("shortcuts: macOS said no to \(twins) shortcuts with fn, ") == true)
    #expect((app.lines.first?.count ?? 999) < 100)
    #expect(app.lines.last == "registered \(count) shortcuts in 900 µs")
    #expect(h.run("doctor").ok && row(h) == nil)
    h.run("hold")
    h.run("release")
    #expect(app.lines.count == 2)
  }

  /// Two keys without a twin come back from a pause in another order than they were in at launch. That is no news.
  @Test func theSameRefusalsInAnotherOrderAreNotSaidAgain() throws {
    let arrange = try #require(map.first { $0.command == .arrange })
    let pause = try #require(KeyBindings.whilePaused(map).first)
    #expect(pause.chord.hasFnTwin)
    let (h, app) = makeApp { $0.server.refusesTwins = [HotKey(arrange), HotKey(pause)] }
    h.run("pause")
    h.run("resume")
    let said = app.lines.filter { $0.hasPrefix("shortcuts: ") }
    h.run("set gap 20")
    h.run("hold")
    h.run("release")
    #expect(app.lines.filter { $0.hasPrefix("shortcuts: ") } == said)
    #expect(Set(said).count == 2, "both; the pause's own alone; and both again")
  }

  /// Only macOS 26 has been asked about the bit (`FakeHotKeyServer.ignoresTheFnBit`).
  @Test func onAMacOSThatIgnoresTheBitEveryKeyRunsItsCommandOnce() {
    let (h, app) = makeApp { $0.server.ignoresTheFnBit = true }
    for binding in h.controller.activeBindings { #expect(app.runs(HotKey(binding)) == [binding], "\(binding.label)") }
    #expect(app.lines == ["registered \(count) shortcuts in 900 µs"])
  }

  // MARK: Nothing is ever missing

  /// What `KeysHeld` is worth hangs on this: whatever changes the answer of `activeBindings`, the app hears of it in the same
  /// turn. Otherwise `doctor` would cry wolf, or worse, a key would be the app's in front and nobody the wiser.
  private func expectInStep(_ h: Harness, _ app: FakeHotKeys, _ what: String) {
    let wanted = h.controller.activeBindings
    #expect(h.controller.keysHeld.all(.missing).isEmpty, "\(what)")
    #expect(h.controller.registeredBindings == wanted, "\(what)")
    let all = wanted + h.controller.temporaryShortcuts
    #expect(app.server.held == Set(all.map(HotKey.init)), "\(what)")
    #expect(app.server.twins == Set(all.filter(\.chord.hasFnTwin).map(HotKey.init)), "a twin comes and goes with its key: \(what)")
    #expect(app.leaked.isEmpty, "\(what)")
    // Arbor's, and once. With fn as well, of the keys that have a twin; of the others, never more than once.
    #expect(wanted.allSatisfy { app.runs(HotKey($0)).map(\.command) == [$0.command] }, "\(what)")
    #expect(wanted.filter(\.chord.hasFnTwin).allSatisfy { app.runs(HotKey($0), fn: true).map(\.command) == [$0.command] }, "\(what)")
    #expect(wanted.allSatisfy { app.runs(HotKey($0), fn: true).count <= 1 }, "\(what)")
    // And what was given away is the app's, with fn or without.
    let givenAway = h.controller.effectiveBindings.bindings.filter { binding in !all.contains { HotKey($0) == HotKey(binding) } }
    #expect(givenAway.allSatisfy { app.runs(HotKey($0)).isEmpty && app.runs(HotKey($0), fn: true).isEmpty }, "\(what)")
  }

  @Test func whateverChangesWhatArborWantsTheAppHearsOfItAtOnce() {
    let (h, app) = makeApp()
    let steps: [(String, () -> Void)] = [
      ("pause", { h.run("pause") }), ("resume", { h.run("resume") }),
      ("pause 5", { h.run("pause 5") }), ("the pause ends", { h.scheduler.advance(by: 301) }),
      ("Emacs comes forward", { h.system.activate(bundleID: "org.gnu.Emacs", name: "Emacs") }),
      ("pass-through on", { h.run("pass-through org.gnu.Emacs on") }),
      ("Safari comes forward", { h.system.activate(bundleID: "com.example.safari", name: "Safari") }),
      ("Emacs again", { h.system.activate(bundleID: "org.gnu.Emacs", name: "Emacs") }),
      ("pass-through off", { h.run("pass-through org.gnu.Emacs off") }),
      ("a game is listed", { h.run("set pauseForApps com.example.game") }),
      ("the game comes forward", { h.system.activate(bundleID: "com.example.game", name: "Game") }),
      ("and goes", { h.system.activate(bundleID: "com.example.safari", name: "Safari") }),
      ("German", { h.controller.keyboardLayoutChanged(SampleKeyLayouts.german) }),
      ("places, not letters", { h.run("set shortcutsFollowLayout false") }),
      ("US", { h.controller.keyboardLayoutChanged(SampleKeyLayouts.us) }),
      ("recording", { h.controller.isRecordingShortcut = true }), ("recorded", { h.controller.isRecordingShortcut = false }),
      ("bind", { h.run("bind ctrl+opt+cmd+j arrange") }), ("unbind", { h.run("unbind ctrl+opt+a") }),
      ("off", { h.run("set hotkeysEnabled false") }), ("on", { h.run("set hotkeysEnabled true") }),
      ("hold", { h.run("hold") }), ("release", { h.run("release") }),
      ("the permission goes", { h.revokeAccessibility(); h.scheduler.advance(by: 3) }),
      ("and returns", { h.grantAccessibility(); h.scheduler.advance(by: 3) }),
      ("paused when it goes", { h.run("pause"); h.revokeAccessibility(); h.scheduler.advance(by: 3) }),
      ("and returns again", { h.grantAccessibility(); h.scheduler.advance(by: 3) }),
      // A pause nobody asked for: an app can cancel the logout, and the keys must not have gone meanwhile.
      ("a logout begins", { h.controller.sessionIsEnding() }), ("and is cancelled", { h.run("resume") }),
      ("a logout begins in a pause", { h.run("pause"); h.controller.sessionIsEnding() }), ("resumed", { h.run("resume") }),
    ]
    expectInStep(h, app, "started")
    for (what, step) in steps {
      step()
      expectInStep(h, app, what)
    }
    #expect(app.lines.count > 15, "the walk did change what is held")
  }

  /// The same in any order, a thousand steps of it.
  @Test func inAnyOrderNothingIsEverMissing() {
    var random = ChaosRandom(seed: 32)
    for _ in 0..<25 {
      let (h, app) = makeApp()
      let apps = [("org.gnu.Emacs", "Emacs"), ("com.example.safari", "Safari"), ("com.example.game", "Game")]
      h.run("set pauseForApps com.example.game")
      var script: [String] = []
      for _ in 0..<40 {
        let what: String
        switch random.next() % 14 {
        case 0: what = "pause"; h.run("pause")
        case 1: what = "resume"; h.run("resume")
        case 2: what = "toggle-pause"; h.run("toggle-pause")
        case 3: what = "pause 1"; h.run("pause 1")
        case 4: what = "a minute"; h.scheduler.advance(by: 61)
        case 5, 6:
          let (bundle, name) = apps[Int(random.next() % 3)]
          what = name
          h.system.activate(bundleID: bundle, name: name)
        case 7: what = "pass-through"; h.run("pass-through org.gnu.Emacs")
        case 8:
          what = "layout"
          h.controller.keyboardLayoutChanged(random.next() % 2 == 0 ? SampleKeyLayouts.german : SampleKeyLayouts.us)
        case 9: what = "record"; h.controller.isRecordingShortcut.toggle()
        case 10: what = "hotkeys"; h.run("set hotkeysEnabled \(random.next() % 2 == 0)")
        case 11: what = "revoke"; h.revokeAccessibility(); h.scheduler.advance(by: 3)
        case 12: what = "grant"; h.grantAccessibility(); h.scheduler.advance(by: 3)
        default: what = "bind"; h.run(random.next() % 2 == 0 ? "bind ctrl+opt+cmd+j arrange" : "unbind ctrl+opt+cmd+j")
        }
        script.append(what)
        expectInStep(h, app, script.joined(separator: ", "))
        // A walk that has failed fails at every step after, which takes minutes to write down.
        guard h.controller.registeredBindings == h.controller.activeBindings, app.leaked.isEmpty else { return }
      }
    }
  }
}
