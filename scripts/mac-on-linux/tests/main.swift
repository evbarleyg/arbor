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
    let bounds = value().components(separatedBy: "-").compactMap { UInt64($0) }
    guard let first = bounds.first, let last = bounds.last, first <= last else {
      print("--seeds wants a range, like 1-500")
      exit(2)
    }
    book.options.walkSeeds = first...last
  case "--steps": book.options.walkSteps = Int(value()) ?? 40
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

book.readKnownFailures()
tellOfOpening(book)
tellOfOddOpenings(book)
tellOfComingForward(book)
tellOfGoing(book)
tellOfShowing(book)
tellOfDragging(book)
tellOfLostDrags(book)
tellOfPlacing(book)
tellOfArrangements(book)
tellOfTheWalk(book)
if let replay = book.options.replay { exit(replayWalk(replay)) }
exit(book.tellAll())
