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
  case "--expect-red": book.options.expectsRed = true
  case "--list": book.options.listsOnly = true
  case "--help":
    print(
      """
      --only TEXT     the stories whose names contain TEXT (may be given several times)
      --list          their names
      --verbose       what happened on the Mac, for the stories that pass as well
      --quiet         the sum only
      --known FILE    the failures that are known (known-failures.txt)
      --expect-red    succeed if a check fails: for the self-test
      """)
    exit(0)
  default:
    // The self-test names stories without further ado.
    book.options.only.append(argument)
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
tellOfPlacing(book)
tellOfArrangements(book)
exit(book.tellAll())
