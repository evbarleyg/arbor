import FakeMacOS
import Foundation

// Arbor's real Accessibility layer on a model of a Mac (../README.md). `make mac-on-linux` builds and runs this.

// Before the first task is made.
Pump.install()

let book = Book()
var arguments = Array(CommandLine.arguments.dropFirst())
while !arguments.isEmpty {
  let argument = arguments.removeFirst()
  func value() -> String {
    guard !arguments.isEmpty else {
      print("\(argument) wants a value")
      exit(2)
    }
    return arguments.removeFirst()
  }
  switch argument {
  case "--only": book.options.only.append(value())
  case "--known": book.options.knownFailuresFile = value()
  case "--verbose": book.options.isVerbose = true
  case "--quiet": book.options.isQuiet = true
  case "--expect-red":
    // "story: check". The story is told, and no other.
    let key = value()
    book.options.expectsRed.append(key)
    book.options.only.append(key.components(separatedBy: ": ")[0])
  case "--list": book.options.listsOnly = true
  case "--seeds":
    let words = value().components(separatedBy: "-")
    let bounds = words.compactMap { UInt64($0) }
    guard bounds.count == words.count, (1...2).contains(bounds.count), let first = bounds.first, let last = bounds.last, first <= last else {
      print("--seeds wants a range, like 1-500, or one seed")
      exit(2)
    }
    book.options.walkSeeds = first...last
  case "--steps":
    guard let steps = Int(value()), steps > 0 else {
      print("--steps wants a number of steps, 1 or more")
      exit(2)
    }
    book.options.walkSteps = steps
  case "--replay": book.options.replay = value()
  case "--heard": book.options.heardFile = value()
  case "--help":
    print(
      """
      --only TEXT     the stories whose names contain TEXT (may be given several times)
      --list          their names
      --verbose       what happened on the Mac, for the stories that pass as well
      --quiet         the sum only
      --known FILE    the failures that are known (known-failures.txt)
      --expect-red "STORY: CHECK"   succeed if that check fails (may be given several times): for the self-test
      --seeds 1-500   the seeds of the rude walk (1-40), with --only walk for the walk alone
      --steps 40      how many steps each walk has
      --replay TEXT   one walk, as a failing one prints it, with everything that happened
      --heard FILE    the file of what the layer was heard to report; a run of everything rewrites it if it is out of date, and fails that once
      """)
    exit(0)
  default:
    print("what is \(argument)? (--help)")
    exit(2)
  }
}

/// Everything rests on the pump's running whatever is runnable, in order, on this thread. A toolchain that queues jobs some other way must not pass
/// for a Mac on which nothing happens.
func checkThePump() {
  let mac = FakeMac()
  FakeMac.current = mac
  nonisolated(unsafe) var seen: [String] = []
  Task { @MainActor in
    for _ in 0..<100 { await Task.yield() }
    seen.append("a hundred turns")
    try? await FakeMac.sleep(nanoseconds: 2_000_000_000)
    seen.append("two seconds at \(FakeMac.uptime - mac.now)")
  }
  Task.detached {
    seen.append("elsewhere, off the main thread: \(Pump.isOffTheMainThread), really: \(!Thread.isMainThread)")
    try? await FakeMac.sleep(nanoseconds: 1_000_000_000)
    await MainActor.run { seen.append("one second, back on the main actor: \(!Pump.isOffTheMainThread)") }
  }
  let began = Date()
  mac.pass(3)
  mac.end()
  let expected = [
    "elsewhere, off the main thread: true, really: false", "a hundred turns", "one second, back on the main actor: true", "two seconds at 0.0",
  ]
  guard seen == expected, Date().timeIntervalSince(began) < 1 else {
    print("the pump does not work with this toolchain (scripts/typecheck-mac/stubs/FakeMacOS/Pump.swift): \(seen)")
    exit(3)
  }
}
checkThePump()

/// Likewise the threads that pass one baton (stubs/FakeMacOS/Threads.swift): a queue's call to an app that hangs takes a second of the model's time, during which the main thread waits only as long as it
/// said it would, goes on, and hears of the outcome later; two queues wait side by side, not one after the other.
func checkTheThreads() {
  let mac = FakeMac()
  FakeMac.current = mac
  let (hung, well) = (mac.launch("Hung"), mac.launch("Well"))
  mac.open("a", in: hung)
  mac.open("b", in: well)
  mac.pass(1)
  mac.hang(hung)
  nonisolated(unsafe) var seen: [String] = []
  let start = mac.now
  @Sendable func at() -> String { String(format: "%.2f", mac.now - start) }
  let done = FakeDispatchSemaphore(value: 0)
  let all = FakeDispatchGroup()
  for app in [hung, well, hung] {
    // Two queues for the app that hangs: their waits must overlap.
    let (pid, name) = (app.pid, app.name)
    FakeDispatchQueue(label: "check.\(seen.count)").async(group: all) {
      let answer = mac.read("AXRole", of: .app(pid), timeout: 1).answer
      seen.append("\(name) \(answer) at \(at()), on the main thread: \(Thread.isMainThread)")
      FakeMac.mainAsync { seen.append("the main queue hears of \(name) at \(at())") }
      if name == "Well" { done.signal() }
    }
  }
  seen.append("the semaphore: \(done.wait(timeout: .now() + 0.15)) at \(at())")
  seen.append("the group after 0.15 s more: \(all.wait(timeout: .now() + 0.15)) at \(at())")
  let began = Date()
  mac.pass(2)
  seen.append("the group in the end: \(all.wait(timeout: .now())) at \(at())")
  mac.end()
  let expected = [
    "Well success at 0.00, on the main thread: false", "the semaphore: success at 0.00", "the group after 0.15 s more: timedOut at 0.15", "the main queue hears of Well at 0.15",
    "Hung cannotComplete at 1.00, on the main thread: false", "Hung cannotComplete at 1.00, on the main thread: false", "the main queue hears of Hung at 1.00",
    "the main queue hears of Hung at 1.00", "the group in the end: success at 2.15",
  ]
  guard seen == expected, Date().timeIntervalSince(began) < 1 else {
    print("the threads of the model do not work with this toolchain (scripts/typecheck-mac/stubs/FakeMacOS/Threads.swift):\n  " + seen.joined(separator: "\n  "))
    exit(3)
  }
}
checkTheThreads()

book.readKnownFailures()
tellOfOpening(book)
tellOfOddOpenings(book)
tellOfComingForward(book)
tellOfSheets(book)
tellOfGoing(book)
tellOfShowing(book)
tellOfDragging(book)
tellOfLostDrags(book)
tellOfLatePresses(book)
tellOfHeldKeys(book)
tellOfTheDesktopShown(book)
tellOfTheJudge(book)
tellOfTheJudgesRandomGestures(book)
tellOfTheJudgesSecondRound(book)
tellOfTheJudgesSecondRandomGestures(book)
tellOfPlacing(book)
tellOfArrangements(book)
tellOfSlowApps(book)
tellOfTheFlightToTheDock(book)
tellOfTwoDisplays(book)
tellOfTheRoadsOfN19(book)
tellOfWhatTheWalkFoundUpstairs(book)
tellOfTheWalk(book)
if let replay = book.options.replay { exit(replayWalk(replay)) }
exit(book.tellAll())
