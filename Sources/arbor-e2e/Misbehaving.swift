import ArborCore
import ArborIPC
import CoreGraphics
import Foundation

// The sessions after the first: real windows that do what real apps and their users do.
//
// The first session (main.swift) arranges well-behaved windows with commands. These start Arbor again in the same
// home folder, so each start restores what the last one saved, and have the windows minimize, move themselves, insist
// on a frame, open native tabs, hang, refuse to shrink, close and hide, while a second app comes forward.
// ArborTestWindows takes commands on stdin for that (Commands.swift there). Every step is one that would have caught
// a finding of the review of the Accessibility layer (collab/reports/2026-10-14-review-ax.md).
//
// `--full-screen` adds macOS's full-screen mode, which takes over the screen for some seconds.

/// A second ArborTestWindows process, for the steps in which apps are switched.
final class OtherApp {
  let process = Process()
  private let input = Pipe()
  private(set) var pid: Int32 = 0
  private(set) var window = WindowID(0)

  init(_ executable: URL) throws {
    let output = Pipe()
    process.executableURL = executable
    process.arguments = ["--count", "1"]
    process.standardOutput = output
    process.standardInput = input
    try process.run()
    struct Hello: Decodable {
      let pid: Int32
      let windows: [UInt32]
    }
    let line = readLine(from: output.fileHandleForReading)
    guard let hello = try? JSONDecoder().decode(Hello.self, from: Data(line.utf8)), let first = hello.windows.first else {
      throw Setup(description: "the second ArborTestWindows did not report its window (got: \(line))")
    }
    pid = hello.pid
    window = WindowID(first)
  }

  func send(_ command: String) {
    // Not `write(_:)`, which brings the runner down, with Arbor still running, when the app has died.
    try? input.fileHandleForWriting.write(contentsOf: Data((command + "\n").utf8))
  }

  func stop() {
    try? input.fileHandleForWriting.close()
    guard process.isRunning else { return }
    _ = poll(3) { !self.process.isRunning }
    if process.isRunning { process.terminate() }
  }
}

extension Runner {
  var withFullScreen: Bool { CommandLine.arguments.contains("--full-screen") }

  // MARK: The test windows' app

  /// Makes the test windows do something; see ArborTestWindows/Commands.swift.
  func tell(_ command: String) {
    try? helperInput?.fileHandleForWriting.write(contentsOf: Data((command + "\n").utf8))
  }

  /// Opens a native tab in front of `window` and returns the tab's window.
  func openTab(in window: WindowID) throws -> WindowID { try open("tab", window) }

  /// Sends a command that opens a window (`tab`, `dialog`) and returns that window.
  func open(_ what: String, _ window: WindowID) throws -> WindowID {
    tell("\(what) \(window.rawValue)")
    struct Reply: Decodable { let window: UInt32 }
    let line = helperOutput.map { readLine(from: $0.fileHandleForReading) } ?? ""
    guard let reply = try? JSONDecoder().decode(Reply.self, from: Data(line.utf8)) else {
      throw Setup(description: "ArborTestWindows did not report its new \(what) (got: \(line))")
    }
    return WindowID(reply.window)
  }

  // MARK: Arbor

  func arborLog() -> String {
    (try? String(contentsOf: home.appendingPathComponent("arbor.log"), encoding: .utf8)) ?? ""
  }

  /// Starts Arbor and waits until it manages `count` windows. Without its watchdog, which is not what these sessions try: an Arbor that
  /// ends in one of them stays away and is missed, where one started in its place might pass for it.
  func startArbor(managing count: Int) throws {
    try launchArbor(withWatchdog: false)
    guard poll(10, { (try? self.send("status")) != nil }) else {
      throw Setup(description: "Arbor did not open its control socket")
    }
    guard poll(10, { ((try? self.state())?.windows.filter(\.managed).count ?? 0) >= count }) else {
      throw Setup(description: "Arbor did not find the \(count) test windows")
    }
  }

  /// Quits Arbor and checks that it went.
  func quitArbor() {
    _ = try? send("quit")
    let exited = poll(5) { !(self.arbor?.isRunning ?? false) }
    check("Arbor exited", exited)
  }

  // MARK: Steps

  /// A step set off by something other than a command to Arbor.
  func step(_ title: String, by what: String, body: () throws -> Void) rethrows {
    print("\n▸ \(title)  (\(what))")
    noteWhereTheLogIs()
    // Nobody is this quick: for 0.15 s after moving a window, Arbor takes any report about it for an echo.
    Thread.sleep(forTimeInterval: 0.5)
    try body()
  }

  /// Something nobody has seen on a Mac yet: says how it went without failing the run. Make it a `check` once it has held.
  func observe(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    print(condition ? "  ✔ \(name)" : "  ? \(name): not so (\(detail())); not counted")
  }

  /// Waits until Arbor's state satisfies `condition`.
  func eventually(_ seconds: TimeInterval = 5, _ condition: (StateSnapshot) -> Bool) -> Bool {
    poll(seconds) { (try? self.state()).map(condition) ?? false }
  }

  /// Waits until Arbor's layout is `frames` again and the windows are there.
  func layoutReturns(to frames: [WindowID: CGRect], within seconds: TimeInterval = 6) -> Bool {
    eventually(seconds) { $0.displays[0].windowFrames == frames } && ((try? state()).map(settled) ?? false)
  }

  func mismatch() -> String { (try? state()).map(mismatchDescription) ?? "no state" }

  // MARK: What real apps do

  func misbehavingWindows(_ w1: WindowID, _ w2: WindowID, _ w3: WindowID) throws {
    let other = try OtherApp(binaries.appendingPathComponent("ArborTestWindows"))
    self.other = other
    let x = other.window
    testWindows.append(x)
    print("\nsecond app: \(x) (pid \(other.pid))")

    try step("start again", by: "Arbor, same home folder") {
      try startArbor(managing: 4)
      let state = try state()
      check("the arrangement survived", Set(state.displays[0].tree.allWindows) == Set([w1, w2, w3]))
      check("the other app's window floats", state.displays[0].floating.contains(x))
    }
    var slots: [WindowID: CGRect] = [:]
    try step("show everything", "show-all") { state in
      slots = state.displays[0].windowFrames
      check("all three have a slot", Set(slots.keys) == Set([w1, w2, w3]))
    }
    let visible = try state().displays[0].visibleFrame
    let elsewhere = CGRect(x: visible.minX + 180, y: visible.minY + 140, width: 320, height: 240)
    let words = "\(Int(elsewhere.minX)) \(Int(elsewhere.minY)) \(Int(elsewhere.width)) \(Int(elsewhere.height))"

    try step("minimize a docked window", by: "the app minimizes \(w2)") {
      tell("minimize \(w2.rawValue)")
      check("Arbor sees it", eventually { $0.window(w2)?.minimized == true })
      let state = try state()
      check("it takes no space", state.displays[0].windowFrames[w2] == nil)
      check("it keeps its place in the tree", state.displays[0].tree.allWindows.contains(w2))
      check("the others share the space", settled(state), mismatchDescription(state))
    }
    step("restore it", by: "the app restores \(w2)") {
      tell("restore \(w2.rawValue)")
      check("every window is back in its slot", layoutReturns(to: slots), mismatch())
    }
    step("move a docked window from outside", by: "the app moves \(w1)") {
      tell("move \(w1.rawValue) \(words)")
      check("it left its slot", poll(2) { self.actualFrames()[w1]?.approximatelyEquals(elsewhere, tolerance: 3) == true })
      check(
        "Arbor puts it back", poll(4) { self.actualFrames()[w1]?.approximatelyEquals(slots[w1] ?? .zero, tolerance: 3) == true },
        whereabouts(w1))
    }
    try step("an app that insists on its own frame", by: "the app keeps moving \(w1) back") {
      tell("insist \(w1.rawValue) \(words)")
      check("Arbor gives up on it", poll(10) { self.arborLog().contains("\(w1) keeps moving itself") })
      var still = true
      for _ in 0..<15 {
        Thread.sleep(forTimeInterval: 0.1)
        if actualFrames()[w1]?.approximatelyEquals(elsewhere, tolerance: 3) != true { still = false }
      }
      check("and the window is left in peace", still, whereabouts(w1))
      check("it is still docked", try state().displays[0].tree.allWindows.contains(w1))
      tell("relent \(w1.rawValue)")
    }
    try step("lay out again once it has calmed down", "relayout") { _ in
      check("every window is back in its slot", layoutReturns(to: slots), mismatch())
    }
    try step("an app that answers every move at once", by: "the app moves \(w1) back within 0.05 s") {
      func timesGivenUp() -> Int { arborLog().components(separatedBy: "\(w1) keeps moving itself").count - 1 }
      let before = timesGivenUp()
      tell("insist \(w1.rawValue) \(words) quick")
      check("Arbor notices, and gives up on it too", poll(10) { timesGivenUp() > before })
      check("it is still docked", try state().displays[0].tree.allWindows.contains(w1))
      tell("relent \(w1.rawValue)")
    }
    try step("lay out again after that", "relayout") { _ in
      check("every window is back in its slot", layoutReturns(to: slots), mismatch())
    }

    var tab = w1
    try step("open a native tab in a docked window", by: "the app opens a tab in \(w1)") {
      tab = try openTab(in: w1)
      testWindows.append(tab)
      check("the tab takes over the slot", eventually { $0.displays[0].windowFrames[tab] == slots[w1] })
      let state = try state()
      check("the covered tab leaves no ghost", !state.displays[0].tree.allWindows.contains(w1))
      check("nothing else changed", state.displays[0].windowFrames[w2] == slots[w2] && state.displays[0].windowFrames[w3] == slots[w3])
      check("windows match Arbor's layout", settled(state), mismatchDescription(state))
    }
    try step("choose the first tab again", by: "the app selects \(w1)") {
      tell("select \(w1.rawValue)")
      check("it has its slot back", eventually { $0.displays[0].windowFrames[w1] == slots[w1] })
      check("the other tab leaves no ghost", !(try state().displays[0].tree.allWindows.contains(tab)))
    }
    step("close the tab in front", by: "the app selects \(tab) and closes it") {
      tell("select \(tab.rawValue)")
      check("the second tab is in the slot", eventually { $0.displays[0].windowFrames[tab] == slots[w1] })
      tell("close \(tab.rawValue)")
      check("the remaining tab inherits the slot", layoutReturns(to: slots), mismatch())
      testWindows.removeAll { $0 == tab }
    }

    if withFullScreen {
      try step("make a docked window full screen", by: "the app toggles full screen for \(w2)") {
        tell("full-screen \(w2.rawValue)")
        check("it gives up its slot", eventually(8) { $0.displays[0].windowFrames[w2] == nil })
        check("it keeps its place in the tree", try state().displays[0].tree.allWindows.contains(w2))
        Thread.sleep(forTimeInterval: 2)
      }
      try step("leave full screen", by: "the app toggles full screen for \(w2)") {
        tell("full-screen \(w2.rawValue)")
        check("every window is back in its slot", layoutReturns(to: slots, within: 12), mismatch())
        check("it is a window, not a tile", !(try state().displays[0].tiles.contains { $0.windows.contains(w2) }))
      }
    }

    step("move the camera while the app hangs", by: "the app hangs for 6 s; zoom \(w3.rawValue)") {
      tell("hang 6")
      Thread.sleep(forTimeInterval: 0.4)
      let began = Date()
      let result = try? send("zoom \(w3.rawValue)")
      let waited = Date().timeIntervalSince(began)
      check("Arbor answers all the same", result?.ok == true)
      check("within three seconds", waited < 3, String(format: "%.1f s", waited))
      check("and goes on answering", (try? send("status"))?.ok == true)
      let settledAfterwards = poll(15) {
        guard let state = try? self.state() else { return false }
        return self.settled(state) && self.visibleFraction(w1) < 0.05 && self.visibleFraction(w2) < 0.05
      }
      check("the windows are placed once the app wakes up", settledAfterwards, mismatch())
    }
    try step("show everything after the hang", "show-all") { _ in
      check("every window is back in its slot", layoutReturns(to: slots), mismatch())
    }

    try step("dock the other app's window", "dock \(x.rawValue) right") { state in
      check("\(x) is docked", state.displays[0].windowFrames[x] != nil)
    }
    // Ten times. One switch in three went unnoticed, by a race inside macOS, so one that is followed says little.
    func timesBehind() -> Int { arborLog().components(separatedBy: "macOS still names another app as the one in front").count - 1 }
    let behindBefore = timesBehind()
    for _ in 1...10 {
      try step("frame a window of the first app", "zoom \(w1.rawValue)") { _ in
        check("\(x) is out of view", leavesView(x), whereabouts(x))
        check("the keyboard crossed over to the first app", eventually { $0.focused == w1 })
      }
      step("switch to the other app", by: "the other app activates itself") {
        other.send("activate")
        let followed = eventually { $0.displays[0].windowFrames[x] != nil }
        let front = frontmostPID()
        if !followed, front != other.pid {
          // macOS can turn down an app that asks to come forward, and then there was nothing to follow.
          observe("macOS lets it come forward", false, "pid \(front ?? -1) is in front")
          return
        }
        check("the camera moves to show its window", followed, "its app is in front")
        check("\(x) is in view", comesIntoView(x), whereabouts(x))
      }
    }
    // Both ways: Arbor's own `zoom` brings the first app forward.
    print("\n(in those twenty switches macOS named the app in front late \(timesBehind() - behindBefore) time(s))")
    try step("frame the other app's window", "zoom \(x.rawValue)") { _ in
      check("\(w2) is out of view", leavesView(w2), whereabouts(w2))
      check("the keyboard is with the other app", eventually { $0.focused == x })
    }
    try step("a dialog opens over a window that is out of view", by: "the first app opens a dialog over \(w2)") {
      let dialog = try open("dialog", w2)
      testWindows.append(dialog)
      observe("Arbor brings it into view", comesIntoView(dialog), whereabouts(dialog))
      tell("close \(dialog.rawValue)")
      testWindows.removeAll { $0 == dialog }
    }
    try step("an app in the background changes its focused window", by: "the first app makes \(w2) its key window") {
      let camera = try state().displays[0].camera
      tell("key \(w2.rawValue)")
      Thread.sleep(forTimeInterval: 1.5)
      check("the camera stays where the user is", try state().displays[0].camera == camera)
    }
    try step("show everything before docking a large window", "show-all") { _ in }

    try step("float the third window", "float \(w3.rawValue)") { _ in }
    // Taller than the window above it could make room for, whatever the display: for less than that Arbor moves the gaps (F61).
    let tall = Int(try state().displays[0].visibleFrame.height) - 150
    step("a window stops accepting small sizes", by: "the app sets a minimum size of 700 × \(tall) for \(w3)") {
      tell("min-size \(w3.rawValue) 700 \(tall)")
      // Nothing reports this, so give the app time to read the command.
      Thread.sleep(forTimeInterval: 0.5)
    }
    // As Arbor ships nobody leaves the view for it (F69).
    try step("dock a window that cannot shrink to its slot: it stays in view and hangs over", "dock \(w3.rawValue) beside \(w1.rawValue) bottom") { state in
      check("no tile stands in for it", !state.displays[0].tiles.contains { $0.windows.contains(w3) })
      check("the state says how far it hangs over its place", (state.window(w3)?.overItsPlaceBy?.height ?? 0) > 0)
      check("it is in view", comesIntoView(w3), whereabouts(w3))
      check("\(w1) is still in view", comesIntoView(w1), whereabouts(w1))
      check("it has the keyboard, which brings it to the front", eventually { $0.focused == w3 })
    }
    try step("float it again", "float \(w3.rawValue)") { _ in }
    try step("ask for tiles, as it was", "set windowsThatDoNotFit tile") { _ in }
    // Where room is made, the window with the keyboard gets it at its neighbours' cost and is never the tile: they are.
    try step("and for no room to be made", "set makeRoom false") { _ in }
    try step("dock a window that cannot shrink to its slot", "dock \(w3.rawValue) beside \(w1.rawValue) bottom") { state in
      check("it becomes a tile", state.displays[0].tiles.contains { $0.windows == [w3] })
      check("the window itself is out of view", leavesView(w3), whereabouts(w3))
      Thread.sleep(forTimeInterval: 0.7)
      let later = try self.state()
      check("the camera stays where it was", later.displays[0].camera == state.displays[0].camera)
      check("\(w1) is still in view", comesIntoView(w1), whereabouts(w1))
    }

    try step("close a docked window", by: "the app closes \(w2)") {
      tell("close \(w2.rawValue)")
      check("it leaves the tree", eventually { !$0.displays[0].tree.allWindows.contains(w2) && $0.window(w2) == nil })
      testWindows.removeAll { $0 == w2 }
      let state = try state()
      check("the others share the space", settled(state), mismatchDescription(state))
    }

    try step("frame one window before quitting", "zoom \(x.rawValue)") { _ in
      check("\(w1) is out of view", leavesView(w1), whereabouts(w1))
    }
    step("minimize a window that is in the tree", by: "the app minimizes \(w1)") {
      tell("minimize \(w1.rawValue)")
      check("Arbor sees it", eventually { $0.window(w1)?.minimized == true })
    }
    step("quit while zoomed in", by: "quit") {
      quitArbor()
      for window in [w1, w3, x] {
        check("\(window) is on screen after quitting", comesIntoView(window), whereabouts(window))
      }
    }

    try step("start with a minimized window", by: "Arbor, same home folder") {
      try startArbor(managing: 3)
      check("it kept its place in the tree", try state().displays[0].tree.allWindows.contains(w1))
      check("a launch shows everything", try state().displays[0].camera == state().displays[0].tree.root)
    }
    try step("show everything with the window still minimized", "show-all") { state in
      check("it takes no space", state.displays[0].windowFrames[w1] == nil)
    }
    try step("restore the window that was minimized at the start", by: "the app restores \(w1)") {
      tell("restore \(w1.rawValue)")
      check("it gets its slot", eventually(6) { $0.displays[0].windowFrames[w1] != nil })
      Thread.sleep(forTimeInterval: 1.2)
      let state = try state()
      check("and keeps it", state.displays[0].windowFrames[w1] != nil)
      check("windows match Arbor's layout", settled(state), mismatchDescription(state))
    }

    step("the other app is killed", by: "SIGTERM to pid \(other.pid)") {
      // Nothing reports the end of an accessory app started from a shell: no notification from Accessibility or NSWorkspace.
      other.process.terminate()
      check("it is gone", poll(5) { !other.process.isRunning })
      testWindows.removeAll { $0 == x }
    }
    try step("frame a window, which sends the others out of view", "zoom \(w3.rawValue)") { _ in
      check(
        "the dead app's window leaves the tree",
        eventually { !$0.displays[0].tree.allWindows.contains(x) && $0.window(x) == nil })
      check("\(w1) is out of view", leavesView(w1), whereabouts(w1))
    }
    step("hide the app whose windows are out of view, then quit", by: "the app hides; quit; the app unhides") {
      tell("hide")
      check("Arbor sees it", eventually { $0.window(w1)?.hidden == true })
      quitArbor()
      tell("unhide")
      for window in [w1, w3] {
        check("\(window) is on screen when the app shows again", comesIntoView(window), whereabouts(window))
      }
    }
  }
}
