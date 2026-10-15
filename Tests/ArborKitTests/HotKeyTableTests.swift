import ArborCore
import ArborKit
import ArborTesting
import Testing

/// What `HotKeyCenter` does to macOS's table of shortcuts, step by step: the real `HotKeyTable` against a `FakeHotKeyServer`.
@Suite struct HotKeyTableTests {
  private let all = KeyBindings.all

  private struct World {
    var table = HotKeyTable<UInt32>()
    let server = FakeHotKeyServer()

    mutating func hold(_ wanted: [KeyBinding]) -> HotKeyOutcome {
      table.hold(wanted, ask: server.ask, giveBack: server.giveBack)
    }

    mutating func setTemporary(_ bindings: [KeyBinding]) -> HotKeyOutcome {
      table.setTemporary(bindings, ask: server.ask, giveBack: server.giveBack)
    }

    /// As it was: all off, then all on.
    mutating func holdAnew(_ wanted: [KeyBinding]) -> HotKeyOutcome {
      _ = table.giveAllBack(server.giveBack)
      return hold(wanted)
    }

    func number(of binding: KeyBinding) -> UInt32? { server.keys.first { $0.value == HotKey(binding) }?.key }

    /// The key goes down and comes up, as a Mac reported it: all that fire go down, then all come up. What the controller is told to run.
    mutating func press(_ binding: KeyBinding, fn: Bool = false) -> [Command] {
      let numbers = server.fires(HotKey(binding), fn: fn)
      let told = numbers.compactMap { table.heard($0, .pressed)?.command }
      for number in numbers { _ = table.heard(number, .released) }
      return told
    }
    func runs(_ binding: KeyBinding) -> Command? { number(of: binding).flatMap { table.binding(for: $0) }?.command }

    /// Arbor and macOS know of the same keys, with fn and without: none swallowed and dead, none believed in and gone.
    var agree: Bool {
      table.count == server.keys.count && table.registrations == server.registrations.count
        && server.registrations.keys.allSatisfy { table.binding(for: $0) != nil }
    }
  }

  private func twins(_ bindings: [KeyBinding]) -> Set<HotKey> { Set(bindings.filter(\.chord.hasFnTwin).map(HotKey.init)) }

  /// The sets a day brings, one after the other: a pause, an app that keeps its own ⌃⌥, another keyboard, none at all.
  private var day: [[KeyBinding]] {
    let german = KeyBindings.effective(settings: .withEveryKey, layout: SampleKeyLayouts.german).bindings
    return [
      all, KeyBindings.whilePaused(all), all, KeyBindings.whilePassingThrough(all), all, german, all, [], all,
      KeyBindings.whileWindowsAreOutOfReach(all), all,
    ]
  }

  /// How many keys were wanted before and after a change, and out of macOS's table at some step between.
  private func letGoOf(_ change: (inout World, [KeyBinding]) -> HotKeyOutcome) -> Int {
    var world = World()
    var count = 0
    var before: Set<HotKey> = []
    for wanted in day {
      (world.server.steps, world.server.twinSteps) = ([], [])
      let outcome = change(&world, wanted)
      let staying = before.intersection(wanted.map(HotKey.init))
      count += staying.filter { key in world.server.steps.contains { !$0.contains(key) } }.count
      // And with fn.
      count += staying.intersection(twins(wanted)).filter { key in world.server.twinSteps.contains { !$0.contains(key) } }.count
      before = Set(wanted.map(HotKey.init))
      #expect(world.server.twins == twins(wanted), "a twin comes and goes with its key")
      #expect(outcome == HotKeyOutcome(held: wanted))
      #expect(world.server.held == before)
      #expect(world.agree)
      #expect(wanted.allSatisfy { world.runs($0) == $0.command })
    }
    return count
  }

  @Test func throughADayNoKeyThatStaysIsEverOutOfMacOSsTable() {
    #expect(letGoOf { $0.hold($1) } == 0)
  }

  /// The control: the same net catches the way it was.
  @Test func allOffAndAllOnLetsGoOfEveryKeyThatStays() {
    #expect(letGoOf { $0.holdAnew($1) } > 100)
  }

  /// The number is what macOS reports a release under: with another number a key that is down would never come up.
  @Test func aKeyThatStaysKeepsItsNumberAndOneThatComesBackGetsANewOne() throws {
    var world = World()
    _ = world.hold(all)
    let pause = try #require(KeyBindings.whilePaused(all).first)
    let float = try #require(all.first { $0.command == .toggleFloat(nil) })
    let pauseNumber = try #require(world.number(of: pause))
    let floatNumber = try #require(world.number(of: float))
    _ = world.hold(KeyBindings.whilePaused(all))
    #expect(world.number(of: pause) == pauseNumber)
    #expect(world.table.binding(for: floatNumber) == nil, "a press of it still on its way is nobody's")
    _ = world.hold(all)
    #expect(world.number(of: pause) == pauseNumber)
    #expect(world.number(of: float) != floatNumber)
    #expect(Set(world.server.numbers).count == world.server.numbers.count, "no number is used twice")
  }

  /// To macOS nothing changes, so nothing is asked of it. What is pressed next runs the new command.
  @Test func aKeyThatGetsAnotherCommandIsNotTouched() {
    var world = World()
    let old = KeyBinding(.hyperless, .j, .arrange)
    let new = KeyBinding(.hyperless, .j, .showAll)
    _ = world.hold([old])
    let asked = world.server.asked
    world.server.steps = []
    #expect(world.hold([new]) == HotKeyOutcome(held: [new]))
    #expect(world.server.steps.isEmpty && world.server.asked == asked)
    #expect(world.runs(new) == .showAll)
    #expect(world.server.fires(HotKey(new), fn: true).map { world.table.binding(for: $0)?.command } == [.showAll], "with fn as well")
  }

  @Test func theSameAgainAsksNothingOfMacOS() {
    var world = World()
    _ = world.hold(all)
    let asked = world.server.asked
    world.server.steps = []
    #expect(world.hold(all) == HotKeyOutcome(held: all))
    #expect(world.server.steps.isEmpty && world.server.asked == asked)
  }

  // MARK: macOS says no

  /// Nothing else is touched for its sake, which is what one refused key used to cost at every change.
  @Test func whatMacOSRefusedIsTriedAgainAndAlone() {
    var world = World()
    let refused = all.first { $0.command == .toggleFloat(nil) }!
    #expect(refused.chord.hasFnTwin)
    world.server.refuses = [HotKey(refused)]
    let others = all.filter { $0 != refused }
    #expect(world.hold(all) == HotKeyOutcome(held: others, refused: [.init(refused, -9879)]))
    #expect(!world.server.twins.contains(HotKey(refused)), "no twin for a key that is not Arbor's")
    let asked = world.server.asked
    world.server.steps = []
    #expect(world.hold(all).refused.map(\.binding) == [refused])
    #expect(world.server.steps.isEmpty && world.server.asked == asked + 1)
    world.server.refuses = []
    #expect(world.hold(all) == HotKeyOutcome(held: all))
    #expect(world.server.steps.allSatisfy { $0.isSuperset(of: others.map(HotKey.init)) })
    #expect(world.server.held == Set(all.map(HotKey.init)) && world.server.twins == twins(all))
    #expect(world.agree)
  }

  /// `KeyBindings.effective` lets no two through. If it did: the first has the key, now and at every later change.
  @Test func ofTwoThatMeanOneKeyTheFirstHasIt() {
    var world = World()
    let first = KeyBinding(.hyperless, .j, .arrange)
    let second = KeyBinding(.hyperless, .j, .showAll)
    for _ in 0..<2 {
      #expect(world.hold([first, second]) == HotKeyOutcome(held: [first], refused: [.init(second, -9878)]))
      #expect(world.runs(first) == .arrange)
    }
  }

  /// The key is still taken from every app. So it is still known, says so, does what it did, and is given back at the next occasion.
  @Test func aKeyThatMacOSWillNotTakeBackIsNotForgotten() throws {
    var world = World()
    _ = world.hold(all)
    let float = try #require(all.first { $0.command == .toggleFloat(nil) })
    let paused = KeyBindings.whilePaused(all)
    world.server.keeps = [HotKey(float)]
    #expect(world.hold(paused) == HotKeyOutcome(held: paused + [float], stuck: [.init(float, -1)]))
    #expect(world.agree, "not swallowed and dead")
    #expect(world.runs(float) == .toggleFloat(nil))
    #expect(world.hold(paused).stuck.map(\.binding) == [float], "tried again")
    world.server.keeps = []
    #expect(world.hold(paused) == HotKeyOutcome(held: paused))
    #expect(world.server.held == Set(paused.map(HotKey.init)))
    #expect(world.agree)
  }

  @Test func atQuitEverythingGoesBack() {
    var world = World()
    _ = world.hold(all)
    _ = world.setTemporary([KeyBinding(KeyChord([.control, .shift], .escape), .showAll)])
    #expect(world.table.giveAllBack(world.server.giveBack) == HotKeyOutcome())
    #expect(world.server.registrations.isEmpty && world.table.count == 0 && world.table.registrations == 0)
  }

  // MARK: What a peek adds for the time being

  private let extras = [
    KeyBinding(KeyChord([.control, .option, .shift, .command], .left), .neighbor(.left)),
    KeyBinding(KeyChord([.control, .option, .shift, .command], .escape), .showAll),
  ]

  @Test func theyComeOnTopAndGoWithoutTouchingTheOthers() {
    var world = World()
    _ = world.hold(all)
    world.server.steps = []
    #expect(world.setTemporary(extras) == HotKeyOutcome())
    #expect(world.server.held == Set((all + extras).map(HotKey.init)))
    #expect(world.setTemporary([]) == HotKeyOutcome())
    #expect(world.server.held == Set(all.map(HotKey.init)))
    #expect(world.server.steps.allSatisfy { $0.isSuperset(of: all.map(HotKey.init)) })
    #expect(world.agree)
  }

  /// A settings file saved, a key tried again: for the rest of the peek its arrows and ⎋ would be the app's in front, and the
  /// controller, which asked for them once, would never know.
  @Test func aRegistrationInTheMiddleOfAPeekLeavesThemAlone() {
    var world = World()
    _ = world.hold(all)
    _ = world.setTemporary(extras)
    world.server.steps = []
    #expect(world.hold(all) == HotKeyOutcome(held: all), "they are not among what is held for good")
    #expect(world.hold(KeyBindings.whilePaused(all)).held == KeyBindings.whilePaused(all))
    #expect(world.server.steps.allSatisfy { $0.isSuperset(of: extras.map(HotKey.init)) })
    #expect(extras.allSatisfy { world.runs($0) == $0.command })
    _ = world.setTemporary([])
    #expect(world.server.held == Set(KeyBindings.whilePaused(all).map(HotKey.init)), "and they still go when the peek ends")
    #expect(world.agree)
  }

  @Test func oneThatIsWantedForGoodMeanwhileIsNoLongerThePeeksToTakeAway() {
    var world = World()
    _ = world.hold(all)
    _ = world.setTemporary(extras)
    let bound = KeyBinding(extras[0].chord, .arrange)
    world.server.steps = []
    #expect(world.hold(all + [bound]) == HotKeyOutcome(held: all + [bound]))
    #expect(world.server.steps.isEmpty, "macOS has it already")
    #expect(world.runs(bound) == .arrange)
    _ = world.setTemporary([])
    #expect(world.server.held == Set((all + [bound]).map(HotKey.init)))
    #expect(world.agree)
  }

  @Test func oneThatBothCallsNameStays() {
    var world = World()
    _ = world.setTemporary(extras)
    world.server.steps = []
    _ = world.setTemporary([extras[1]])
    #expect(world.server.steps.allSatisfy { $0.contains(HotKey(extras[1])) })
    #expect(world.server.held == [HotKey(extras[1])])
    _ = world.setTemporary([])
    #expect(world.server.registrations.isEmpty)
  }

  /// macOS would say no, and nothing is amiss: the key is Arbor's.
  @Test func aKeyThatIsHeldAnywayIsNotAskedForTwiceNorTakenAway() {
    var world = World()
    _ = world.hold(all)
    let asked = world.server.asked
    #expect(world.setTemporary([KeyBinding(all[0].chord, .home)]) == HotKeyOutcome())
    #expect(world.server.asked == asked)
    #expect(world.runs(all[0]) == all[0].command)
    _ = world.setTemporary([])
    #expect(world.server.held == Set(all.map(HotKey.init)))
  }

  @Test func oneThatMacOSRefusesIsReported() {
    var world = World()
    world.server.refuses = [HotKey(extras[0])]
    #expect(world.setTemporary(extras).refused == [.init(extras[0], -9879)])
    #expect(world.server.held == [HotKey(extras[1])])
    #expect(world.agree)
  }

  // MARK: With fn or without

  private func binding(_ key: KeyChord.Key) -> KeyBinding { KeyBinding(.hyperless, key, .arrange) }
  /// By the key's code and the stand-in's own list, not by what Arbor thinks: a real key of these kinds sends fn's flag whatever the fingers do.
  private func carriesFn(_ key: KeyChord.Key) -> Bool { FakeHotKeyServer.carriesFn(key.code) }

  /// A command run twice is worse than the hole the twin closes.
  @Test func noPressOfAnyKeyEverRunsItsCommandTwiceAndNoKeyThatCarriesFnByNatureGetsATwin() {
    for key in KeyChord.Key.allCases {
      var world = World()
      #expect(world.hold([binding(key)]) == HotKeyOutcome(held: [binding(key)]))
      let hotKey = HotKey(binding(key))
      #expect(world.server.fires(hotKey, fn: false).count == 1, "\(key)")
      #expect(world.server.fires(hotKey, fn: true).count <= 1, "\(key)")
      if carriesFn(key) { #expect(world.server.twins.isEmpty && !key.hasFnTwin, "\(key)") }
      #expect(carriesFn(key) == HotKey(binding(key)).carriesFn, "Arbor's list of codes and the stand-in's agree: \(key)")
      #expect(world.server.twins.contains(hotKey) == key.hasFnTwin, "\(key)")
      #expect(world.table.count == 1 && world.table.registrations == (key.hasFnTwin ? 2 : 1), "\(key)")
    }
  }

  /// The control: the stand-in does play the fault. Asked for both ways, as a Mac was, an arrow fires both.
  @Test func heldBothWaysAnArrowFiresTwiceAndALetterOnce() {
    let server = FakeHotKeyServer()
    for (number, key) in [KeyChord.Key.left, .f5, .a].enumerated() {
      #expect(server.ask(binding(key), UInt32(2 * number + 1), false).1 == 0)
      #expect(server.ask(binding(key), UInt32(2 * number + 2), true).1 == 0, "macOS says yes")
    }
    #expect(server.fires(HotKey(binding(.left)), fn: false) == [1, 2])
    #expect(server.fires(HotKey(binding(.f5)), fn: true) == [3, 4])
    #expect(server.fires(HotKey(binding(.a)), fn: false) == [5])
    #expect(server.fires(HotKey(binding(.a)), fn: true) == [6])
  }

  /// fn ⌃ F fills the screen and fn ⌃ C centres a window: macOS's own. Somebody's `ctrl+f` takes ⌃F, as they asked, and no more.
  @Test func aShortcutOfSomebodysOwnWithoutControlAndOptionTakesNothingWithFn() {
    var world = World()
    let own = [
      KeyBinding(KeyChord(.control, .f), .arrange), KeyBinding(KeyChord([.control, .shift], .c), .showAll),
      KeyBinding(KeyChord([.option, .command], .r), .home), KeyBinding(KeyChord([.control, .command], .escape), .back),
    ]
    #expect(world.hold(own) == HotKeyOutcome(held: own))
    #expect(world.server.twins.isEmpty && world.table.registrations == own.count)
    for binding in own {
      #expect(world.press(binding) == [binding.command])
      #expect(world.press(binding, fn: true).isEmpty, "macOS's, or the app's: \(binding.label)")
    }
  }

  /// Not by the name alone: a layout of somebody's own making could put a letter on an arrow's key, and macOS goes by the code.
  @Test func aLetterOnAnArrowsKeyGetsNoTwin() throws {
    let odd = KeyLayout(name: "Odd", plain: [123: "a"], shifted: [123: "A"])
    let letter = KeyBinding(KeyChord(.hyperless, .a), .arrange, layout: odd)
    try #require(letter.keyCode == 123 && letter.chord.hasFnTwin)
    var world = World()
    #expect(world.hold([letter]) == HotKeyOutcome(held: [letter]))
    #expect(world.server.twins.isEmpty)
    #expect(world.press(letter) == [.arrange])
  }

  /// What it is for: fn sits beside ⌃, and with its flag on the event the plain registration is deaf. Said of the keys that have a twin. What a
  /// real fn makes of an arrow, of ↩ or of ⌫ is another key altogether, and no Mac has been asked with a keyboard.
  @Test func withFnDownAKeyOfArborsIsStillArbors() {
    var world = World()
    _ = world.hold(all)
    for binding in all {
      let ran = world.press(binding, fn: true)
      if binding.chord.hasFnTwin { #expect(ran == [binding.command], "\(binding.label)") }
      #expect(ran.count <= 1, "\(binding.label)")
      #expect(world.press(binding) == [binding.command], "\(binding.label)")
    }
    // Without the twins, as it was: every key that does not carry the flag by nature is the app's.
    let plain = FakeHotKeyServer()
    for (number, binding) in all.enumerated() { _ = plain.ask(binding, UInt32(number), false) }
    #expect(all.filter { plain.fires(HotKey($0), fn: true).isEmpty }.count == twins(all).count)
    #expect(twins(all).count > 30)
  }

  // MARK: One press, one command

  /// macOS 15 and 26 know the bit; 14 has not been asked. One that does not know it would, by what they did with bits they do not know, take
  /// every twin for its plain key and fire both at every press: ⌃⌥F would float and unfloat, ⌃⌥⎋ pause and resume.
  @Test func onAMacOSThatIgnoresTheBitEveryCommandStillRunsOnce() {
    var world = World()
    world.server.ignoresTheFnBit = true
    #expect(world.hold(all) == HotKeyOutcome(held: all))
    #expect(all.filter { world.server.fires(HotKey($0), fn: false).count == 2 }.count == twins(all).count, "the fault is played")
    for binding in all { #expect(world.press(binding) == [binding.command], "\(binding.label)") }
    // Twice over: nothing is left behind by the first round.
    for binding in all { #expect(world.press(binding) == [binding.command], "\(binding.label)") }
  }

  @Test func whileAKeyIsDownUnderOneNumberWhatComesUnderTheOtherIsNobodys() throws {
    var world = World()
    let key = binding(.a)
    _ = world.hold([key])
    let plain = try #require(world.server.fires(HotKey(key), fn: false).first)
    let twin = try #require(world.server.fires(HotKey(key), fn: true).first)
    // As a Mac reported a press that fired both: down, down, up, up. In either order.
    for (first, second) in [(plain, twin), (twin, plain)] {
      #expect(world.table.heard(first, .pressed) == key)
      #expect(world.table.heard(second, .pressed) == nil)
      #expect(world.table.heard(first, .pressed) == key, "auto-repeat is passed on")
      #expect(world.table.heard(second, .pressed) == nil)
      #expect(world.table.heard(first, .released) == key)
      #expect(world.table.heard(second, .released) == nil, "one release for one press")
    }
    // Up in the other order.
    #expect(world.table.heard(plain, .pressed) == key)
    #expect(world.table.heard(twin, .pressed) == nil)
    #expect(world.table.heard(twin, .released) == nil)
    #expect(world.table.heard(plain, .released) == key)
    // One after the other they are two presses.
    #expect(world.table.heard(plain, .pressed) == key && world.table.heard(plain, .released) == key)
    #expect(world.table.heard(twin, .pressed) == key && world.table.heard(twin, .released) == key)
  }

  /// macOS does not report every key that comes up. It costs one press with the other hand, not the key.
  @Test func aReleaseThatIsNeverReportedCostsOnePressAtMost() throws {
    var world = World()
    let key = binding(.a)
    _ = world.hold([key])
    let plain = try #require(world.server.fires(HotKey(key), fn: false).first)
    let twin = try #require(world.server.fires(HotKey(key), fn: true).first)
    #expect(world.table.heard(plain, .pressed) == key)
    #expect(world.table.heard(plain, .pressed) == key, "the same hand again: nothing is lost")
    #expect(world.table.heard(twin, .pressed) == nil)
    #expect(world.table.heard(twin, .released) == nil)
    #expect(world.table.heard(twin, .pressed) == key, "and all is well again")
    #expect(world.table.heard(twin, .released) == key)
  }

  @Test func aNumberThatIsNobodysAnyMoreTellsNothing() throws {
    var world = World()
    let key = binding(.a)
    _ = world.hold([key])
    let numbers = world.server.fires(HotKey(key), fn: false) + world.server.fires(HotKey(key), fn: true)
    _ = world.hold([])
    for number in numbers { #expect(world.table.heard(number, .pressed) == nil && world.table.heard(number, .released) == nil) }
  }

  // MARK: macOS says no to a twin

  /// The key is Arbor's all the same. Tried again whenever the table is asked, and the key is not touched for it.
  @Test func aTwinThatMacOSRefusesIsReportedApartAndTriedAgain() throws {
    var world = World()
    let float = try #require(all.first { $0.command == .toggleFloat(nil) })
    world.server.refusesTwins = [HotKey(float)]
    #expect(world.hold(all) == HotKeyOutcome(held: all, withoutTwin: [.init(float, -9879)]))
    #expect(world.runs(float) == .toggleFloat(nil))
    #expect(world.server.fires(HotKey(float), fn: true).isEmpty)
    let asked = world.server.asked
    world.server.steps = []
    #expect(world.hold(all).withoutTwin.map(\.binding) == [float])
    #expect(world.server.asked == asked + 1 && world.server.steps.isEmpty)
    world.server.refusesTwins = []
    #expect(world.hold(all) == HotKeyOutcome(held: all))
    #expect(world.server.twins == twins(all))
    #expect(world.server.steps.allSatisfy { $0 == Set(all.map(HotKey.init)) }, "no plain key was touched")
    #expect(world.agree)
  }

  /// A person gave the key away: with fn and without.
  @Test func aKeyIsNeverGivenAwayWhileArborStillTakesItWithFn() throws {
    var world = World()
    _ = world.hold(all)
    (world.server.steps, world.server.twinSteps) = ([], [])
    _ = world.hold(KeyBindings.whilePaused(all))
    for (plain, withFn) in zip(world.server.steps, world.server.twinSteps) {
      #expect(withFn.isSubset(of: plain))
    }
    #expect(world.server.twins == twins(KeyBindings.whilePaused(all)))
  }

  /// macOS lets the plain key go and keeps the twin, or the other way round. Nothing leaks, and it is put right at the next occasion.
  @Test func ifMacOSKeepsOnlyOneOfTheTwoNothingLeaksAndItIsPutRightLater() throws {
    let float = try #require(all.first { $0.command == .toggleFloat(nil) })
    let paused = KeyBindings.whilePaused(all)
    var world = World()
    _ = world.hold(all)
    world.server.keepsTwins = [HotKey(float)]
    #expect(world.hold(paused).stuck == [.init(float, -1)])
    #expect(world.server.held.contains(HotKey(float)), "the key stays with its twin: never given away while Arbor takes it with fn")
    #expect(world.agree)
    world.server.keepsTwins = []
    #expect(world.hold(paused) == HotKeyOutcome(held: paused))
    #expect(world.server.held == Set(paused.map(HotKey.init)) && world.server.twins == twins(paused))
    #expect(world.agree)
  }

  @Test func aTemporaryWithATwinThatIsWantedForGoodKeepsBoth() {
    var world = World()
    _ = world.hold(all)
    _ = world.setTemporary(extras)
    let bound = KeyBinding(extras[1].chord, .arrange)
    #expect(bound.chord.hasFnTwin)
    (world.server.steps, world.server.twinSteps) = ([], [])
    #expect(world.hold(all + [bound]) == HotKeyOutcome(held: all + [bound]))
    #expect(world.server.steps.isEmpty, "macOS has both already")
    #expect(world.press(bound) == [.arrange] && world.press(bound, fn: true) == [.arrange])
    _ = world.setTemporary([])
    #expect(world.server.twins == twins(all + [bound]))
    #expect(world.agree)
  }

  /// ⎋ in a peek has its twin, the arrows have none.
  @Test func whatAPeekAddsFollowsTheSameRule() {
    var world = World()
    _ = world.hold(all)
    _ = world.setTemporary(extras)
    #expect(world.server.twins == twins(all + extras))
    #expect(world.server.twins.contains(HotKey(extras[1])) && !world.server.twins.contains(HotKey(extras[0])))
    _ = world.setTemporary([])
    #expect(world.server.twins == twins(all))
    #expect(world.agree)
  }

  // MARK: Whatever comes

  /// Any order of changes, on a Mac that says no at whim: Arbor and macOS always know of the same keys, a key that is held for
  /// good and stays wanted is never out of the table, and what is reported is what is so.
  @Test func inAnyOrderNothingLeaksAndNothingThatStaysIsLetGoOf() {
    var random = ChaosRandom(seed: 23)
    let pool = all + extras + [KeyBinding(.hyperless, .j, .arrange), KeyBinding(.hyperless, .j, .showAll)]
    for _ in 0..<300 {
      var world = World()
      var forGood: Set<HotKey> = []
      for _ in 0..<30 {
        world.server.refuses = Set(pool.filter { _ in random.next() % 11 == 0 }.map(HotKey.init))
        world.server.keeps = Set(pool.filter { _ in random.next() % 17 == 0 }.map(HotKey.init))
        world.server.refusesTwins = Set(pool.filter { _ in random.next() % 13 == 0 }.map(HotKey.init))
        let some = pool.filter { _ in random.next() % 3 != 0 }
        world.server.steps = []
        if random.next() % 3 == 0 {
          _ = world.setTemporary(Array(some.prefix(4)))
          #expect(world.server.steps.allSatisfy { $0.isSuperset(of: forGood) })
        } else {
          let outcome = world.hold(some)
          let staying = forGood.intersection(some.map(HotKey.init))
          #expect(world.server.steps.allSatisfy { $0.isSuperset(of: staying) })
          #expect(outcome.held.allSatisfy { world.server.held.contains(HotKey($0)) })
          #expect(outcome.held.allSatisfy { world.runs($0) == $0.command })
          #expect(outcome.refused.allSatisfy { world.runs($0.binding) != $0.binding.command })
          // Every key that is to have a twin has it, or it is said that it has not.
          let excused = Set((outcome.withoutTwin + outcome.stuck).map { HotKey($0.binding) })
          #expect(twins(outcome.held).subtracting(world.server.twins).isSubset(of: excused))
          forGood = Set(outcome.held.map(HotKey.init))
        }
        #expect(world.agree)
        #expect(world.server.twins.isSubset(of: world.server.held), "never a twin without its key")
        #expect(world.server.twins.isSubset(of: twins(pool)), "never a twin for a key of the wrong kind")
        let once = pool.allSatisfy { world.press($0).count <= 1 && world.press($0, fn: true).count <= 1 }
        #expect(once, "one press, one command")
        // A walk that has failed fails ten thousand times over, which takes minutes to write down.
        guard world.agree, once else { return }
      }
      #expect(Set(world.server.numbers).count == world.server.numbers.count)
    }
  }
}
