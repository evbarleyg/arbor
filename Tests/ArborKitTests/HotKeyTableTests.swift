import ArborCore
import ArborKit
import ArborTesting
import Testing

/// What `HotKeyCenter` does to macOS's table of shortcuts, step by step: the real `HotKeyTable` against a `FakeHotKeyServer`.
@Suite struct HotKeyTableTests {
  private let all = KeyBindings.defaults

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
    func runs(_ binding: KeyBinding) -> Command? { number(of: binding).flatMap { table.binding(for: $0) }?.command }

    /// Arbor and macOS know of the same keys: none swallowed and dead, none believed in and gone.
    var agree: Bool { table.count == server.keys.count && server.keys.keys.allSatisfy { table.binding(for: $0) != nil } }
  }

  /// The sets a day brings, one after the other: a pause, an app that keeps its own ⌃⌥, another keyboard, none at all.
  private var day: [[KeyBinding]] {
    let german = KeyBindings.effective(settings: Settings(), layout: SampleKeyLayouts.german).bindings
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
      world.server.steps = []
      let outcome = change(&world, wanted)
      let staying = before.intersection(wanted.map(HotKey.init))
      count += staying.filter { key in world.server.steps.contains { !$0.contains(key) } }.count
      before = Set(wanted.map(HotKey.init))
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
    #expect(letGoOf { $0.holdAnew($1) } > 50)
  }

  /// The number is what macOS reports a release under: with another number a key that is down would never come up.
  @Test func aKeyThatStaysKeepsItsNumberAndOneThatComesBackGetsANewOne() throws {
    var world = World()
    _ = world.hold(all)
    let pause = try #require(KeyBindings.whilePaused(all).first)
    let arrange = try #require(all.first { $0.command == .arrange })
    let pauseNumber = try #require(world.number(of: pause))
    let arrangeNumber = try #require(world.number(of: arrange))
    _ = world.hold(KeyBindings.whilePaused(all))
    #expect(world.number(of: pause) == pauseNumber)
    #expect(world.table.binding(for: arrangeNumber) == nil, "a press of it still on its way is nobody's")
    _ = world.hold(all)
    #expect(world.number(of: pause) == pauseNumber)
    #expect(world.number(of: arrange) != arrangeNumber)
    #expect(Set(world.server.numbers).count == world.server.numbers.count, "no number is used twice")
  }

  /// To macOS nothing changes, so nothing is asked of it. What is pressed next runs the new command.
  @Test func aKeyThatGetsAnotherCommandIsNotTouched() {
    var world = World()
    let old = KeyBinding(.hyperless, .j, .arrange)
    let new = KeyBinding(.hyperless, .j, .showAll)
    _ = world.hold([old])
    world.server.steps = []
    #expect(world.hold([new]) == HotKeyOutcome(held: [new]))
    #expect(world.server.steps.isEmpty && world.server.asked == 1)
    #expect(world.runs(new) == .showAll)
  }

  @Test func theSameAgainAsksNothingOfMacOS() {
    var world = World()
    _ = world.hold(all)
    world.server.steps = []
    #expect(world.hold(all) == HotKeyOutcome(held: all))
    #expect(world.server.steps.isEmpty && world.server.asked == all.count)
  }

  // MARK: macOS says no

  /// Nothing else is touched for its sake, which is what one refused key used to cost at every change.
  @Test func whatMacOSRefusedIsTriedAgainAndAlone() {
    var world = World()
    let refused = all[3]
    world.server.refuses = [HotKey(refused)]
    let others = all.filter { $0 != refused }
    #expect(world.hold(all) == HotKeyOutcome(held: others, refused: [.init(refused, -9879)]))
    world.server.steps = []
    #expect(world.hold(all).refused.map(\.binding) == [refused])
    #expect(world.server.steps.isEmpty && world.server.asked == all.count + 1)
    world.server.refuses = []
    #expect(world.hold(all) == HotKeyOutcome(held: all))
    #expect(world.server.steps.count == 1)
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
    let arrange = try #require(all.first { $0.command == .arrange })
    let paused = KeyBindings.whilePaused(all)
    world.server.keeps = [HotKey(arrange)]
    #expect(world.hold(paused) == HotKeyOutcome(held: paused + [arrange], stuck: [.init(arrange, -1)]))
    #expect(world.agree, "not swallowed and dead")
    #expect(world.runs(arrange) == .arrange)
    #expect(world.hold(paused).stuck.map(\.binding) == [arrange], "tried again")
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
    #expect(world.server.keys.isEmpty && world.table.count == 0)
  }

  // MARK: What a peek adds for the time being

  private let extras = [
    KeyBinding(KeyChord([.control, .shift], .left), .neighbor(.left)),
    KeyBinding(KeyChord([.control, .shift], .escape), .showAll),
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
    #expect(world.server.keys.isEmpty)
  }

  /// macOS would say no, and nothing is amiss: the key is Arbor's.
  @Test func aKeyThatIsHeldAnywayIsNotAskedForTwiceNorTakenAway() {
    var world = World()
    _ = world.hold(all)
    #expect(world.setTemporary([KeyBinding(all[0].chord, .home)]) == HotKeyOutcome())
    #expect(world.server.asked == all.count)
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
          forGood = Set(outcome.held.map(HotKey.init))
        }
        #expect(world.agree)
      }
      #expect(Set(world.server.numbers).count == world.server.numbers.count)
    }
  }
}
