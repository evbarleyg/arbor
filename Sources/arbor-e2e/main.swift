import ArborCore
import ArborIPC
import CoreGraphics
import Darwin
import Foundation

// arbor-e2e: drives the real Arbor binary against real windows.
//
// It launches ArborTestWindows (three plain windows), launches Arbor limited
// to that process (ARBOR_ONLY_PIDS) with its own home folder, sends commands
// over the control socket, and checks the window server's view of the
// windows (CGWindowList, independent of Arbor) after every step. The user's
// own windows are never touched. After the arranging come the accidents: clients
// that hang up, a second copy of Arbor, `kill -9` with windows parked, and a crash loop.
//
// Needs Accessibility permission for the terminal it runs from (Arbor
// inherits it as a child process). Run `swift build` first; see `make e2e`.
//
// Exit codes: 0 all passed, 1 a check failed; without a verdict (Ending.swift): 2 not ready (no permission, not built), 3 somebody
// is at the Mac, 4 nobody could see it (locked, asleep), 5 set-up failed, 6 lost in mid-run, 7 out of time; 128 + n stopped by signal n.

struct Setup: Error, CustomStringConvertible { let description: String }

/// What `arborctl watch` does, on a thread of its own: collects the lines Arbor sends while the
/// scenario runs.
final class Watcher: @unchecked Sendable {
  private let lock = NSLock()
  private var collected: [String] = []
  private var outcome: ControlClient.WatchEnd?

  init(_ request: String, socket: String) {
    Thread.detachNewThread { [self] in
      let end = ControlClient.watch(
        request, socketPath: socket, print: { line in self.locked { self.collected.append(line) } },
        complain: { _ in })
      locked { outcome = end }
    }
  }

  private func locked<Result>(_ body: () -> Result) -> Result {
    lock.lock()
    defer { lock.unlock() }
    return body()
  }

  var lines: [String] { locked { collected } }
  /// How the watch ended, once it has.
  var end: ControlClient.WatchEnd? { locked { outcome } }
  /// The lines that read as events; all of them should.
  var events: [ArborEvent] { lines.compactMap { try? ArborEvent(line: $0) } }

  var views: [ArborEvent.View] { events.compactMap { if case .view(let view) = $0 { view } else { nil } } }
  var windowChanges: [ArborEvent.WindowChange] {
    events.compactMap { if case .window(let change) = $0 { change } else { nil } }
  }
}

final class Runner {
  let binaries: URL
  let home: URL
  let socket: String
  var helper: Process?
  var helperInput: Pipe?
  var helperOutput: Pipe?
  /// A second app, for the sessions in Misbehaving.swift.
  var other: OtherApp?
  var arbor: Process?
  /// Held open for as long as this process lives; see `startGuardian`.
  var guardianInput: Pipe?
  var helperPID: Int32 = 0
  var testWindows: [WindowID] = []
  var gap: CGFloat = 12
  var failures: [String] = []
  var passes = 0
  /// Whether Arbor has found the test windows: what goes wrong from there on is no failure of the set-up.
  var isUnderWay = false
  /// How many bytes of arbor.log were written before this step, or have been shown under one of its checks.
  var logShown = 0
  /// Where Arbor's log and the traces of the run are left when it is over (`ARBOR_E2E_KEEP`, which scripts/e2e.sh sets on GitHub's Macs only: a
  /// trace names every app that has a window open). Without it nothing is recorded.
  let keeps = ProcessInfo.processInfo.environment["ARBOR_E2E_KEEP"].map { URL(fileURLWithPath: $0) }
  /// The trace being recorded is `e2e-<number>` (docs/TRACES.md): a new one from every heading, so that each begins with the world as it
  /// was and is short enough to become a test (scripts/trace-to-test.py).
  var traceNumber = 0

  init() throws {
    binaries = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
    home = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("arbor-e2e-\(getpid())")
    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    socket = home.appendingPathComponent("arbor.sock").path
    for name in ["Arbor", "ArborTestWindows"] {
      guard FileManager.default.isExecutableFile(atPath: binaries.appendingPathComponent(name).path) else {
        throw Setup(description: "\(name) is not built next to arbor-e2e; run `swift build` first")
      }
    }
  }

  // MARK: Settings

  /// A settings file somebody has worked on: a number written their way, a key Arbor does not
  /// know, and a rule it cannot read. Arbor starts on it, so its gap has to be `gap`. It has the mark of a file that holds only what
  /// somebody chose (Q27), as a file has that Arbor has started on once. And the darkening behind docked windows,
  /// an option (Q29), which two steps look for on the screen.
  static let handEditedSettings = """
    {
      "format": 2,
      "gap": 12.0,
      "myNote": "kept by arbor-e2e",
      "dimBehindArranged": 0.25,
      "excludedBundleIDs": ["com.example.first"],
      "rules": [
        { "app": "com.example.typo", "action": "dock sideways" }
      ]
    }

    """

  var settingsFile: URL { home.appendingPathComponent("settings.json") }

  func settingsText() -> String { (try? String(contentsOf: settingsFile, encoding: .utf8)) ?? "(no file)" }

  // MARK: Processes

  func launchHelper() throws {
    let process = Process()
    process.executableURL = binaries.appendingPathComponent("ArborTestWindows")
    process.arguments = ["--count", "3"]
    let output = Pipe()
    let input = Pipe()
    process.standardOutput = output
    process.standardInput = input
    try process.run()
    helper = process
    helperInput = input
    helperOutput = output

    let line = readLine(from: output.fileHandleForReading)
    struct Hello: Decodable {
      let pid: Int32
      let windows: [UInt32]
    }
    guard let hello = try? JSONDecoder().decode(Hello.self, from: Data(line.utf8)), hello.windows.count == 3 else {
      throw Setup(description: "ArborTestWindows did not report its windows (got: \(line))")
    }
    helperPID = hello.pid
    testWindows = hello.windows.map { WindowID($0) }
  }

  /// With its watchdog, as a person's Arbor has one, unless told otherwise.
  @discardableResult
  func launchArbor(asSecondCopy: Bool = false, withWatchdog: Bool = true) throws -> Process {
    let process = Process()
    process.executableURL = binaries.appendingPathComponent("Arbor")
    var environment = ProcessInfo.processInfo.environment
    environment["ARBOR_NO_WATCHDOG"] = withWatchdog ? nil : "1"
    // Whatever the caller's shell has: this is a person's start.
    environment["ARBOR_RESTARTS"] = nil
    environment["ARBOR_RESCUE"] = nil
    environment["ARBOR_HOME"] = home.path
    environment["ARBOR_SOCKET"] = socket
    environment["ARBOR_ONLY_PIDS"] = ([helperPID] + (other.map { [$0.pid] } ?? [])).map(String.init).joined(separator: ",")
    environment["ARBOR_NO_HOTKEYS"] = "1"
    environment["ARBOR_NO_STATUS_ITEM"] = "1"
    environment["ARBOR_NO_PROMPT"] = "1"
    environment["ARBOR_DEBUG"] = "1"
    // With Screen Recording Arbor keeps stills of every app's windows and of the desktop for its motion, whatever
    // ARBOR_ONLY_PIDS says. On a person's Mac those are their mail and their documents.
    // And `summon` opens an app of which Arbor knows no window, which here is every app of theirs.
    if !Manners.isOnThrowawayMac {
      environment["ARBOR_NO_PICTURES"] = "1"
      environment["ARBOR_NO_OPENING"] = "1"
    }
    process.environment = environment
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    if !asSecondCopy { arbor = process }
    return process
  }

  /// The pid of the Arbor that holds the home folder's lock. After an accident that is not the
  /// process this runner launched but the one the watchdog started in its place.
  func arborPID() -> Int32? {
    guard let text = try? String(contentsOf: home.appendingPathComponent("arbor.lock"), encoding: .utf8),
      let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), kill(pid, 0) == 0
    else { return nil }
    return pid
  }

  func cleanUp() {
    // Whoever answers, not only the process launched here.
    _ = try? ControlClient.send("quit", socketPath: socket, timeout: 2)
    _ = poll(5) { self.arborPID() == nil }
    if let pid = arborPID() { kill(pid, SIGTERM) }
    if let arbor, arbor.isRunning { arbor.terminate() }
    other?.stop()
    try? helperInput?.fileHandleForWriting.close()
    if let helper, helper.isRunning {
      _ = poll(3) { !helper.isRunning }
      if helper.isRunning { helper.terminate() }
    }
    keepLogAndTraces()
    let log = home.appendingPathComponent("arbor.log")
    if !failures.isEmpty, let text = try? String(contentsOf: log, encoding: .utf8) {
      print("\n--- arbor.log (last 100 lines) ---")
      print(forOthersToRead(text))
    }
    // Where there is a guardian the folder is its to remove, when it has seen the last Arbor: one on its way would make the folder anew.
    if guardianInput == nil { try? FileManager.default.removeItem(at: home) }
  }

  // MARK: Talking to Arbor

  @discardableResult
  func send(_ line: String) throws -> CommandResult {
    let reply = try ControlClient.send(line, socketPath: socket, timeout: 5)
    return try JSONDecoder().decode(CommandResult.self, from: Data(reply.utf8))
  }

  func state() throws -> StateSnapshot {
    guard let state = try send("state").state else { throw Setup(description: "state reply had no state") }
    return state
  }

  // MARK: Observing the window server

  /// Bounds of the test windows as the window server reports them.
  func actualFrames() -> [WindowID: CGRect] {
    guard let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] else {
      return [:]
    }
    var frames: [WindowID: CGRect] = [:]
    for info in list {
      guard let number = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
        testWindows.contains(WindowID(number)),
        let bounds = info[kCGWindowBounds as String] as? NSDictionary,
        let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary)
      else { continue }
      frames[WindowID(number)] = rect
    }
    return frames
  }

  /// Whether Arbor has a window of its own on screen at that window level.
  func arborShowsPanel(atLevel level: Int) -> Bool {
    guard let pid = arbor?.processIdentifier,
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    else { return false }
    return list.contains { info in
      (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
        && (info[kCGWindowLayer as String] as? NSNumber)?.intValue == level
    }
  }

  /// Arbor's own windows that are on screen at the backdrop's level, just above the Desktop's icons.
  func backdropFrames() -> [CGRect] {
    guard let pid = arbor?.processIdentifier,
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    else { return [] }
    let level = Int(CGWindowLevelForKey(.desktopIconWindow)) + 1
    return list.compactMap { info in
      guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
        (info[kCGWindowLayer as String] as? NSNumber)?.intValue == level,
        let bounds = info[kCGWindowBounds as String] as? NSDictionary
      else { return nil }
      return CGRect(dictionaryRepresentation: bounds as CFDictionary)
    }
  }

  /// The window server's level of Arbor's settings window, told by its owner and its size (its title would take
  /// Screen Recording permission to read). Nil while it is not on screen.
  func settingsWindowLayer() -> Int? {
    guard let pid = arborPID(),
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    else { return nil }
    for info in list {
      guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
        let bounds = info[kCGWindowBounds as String] as? NSDictionary,
        let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary),
        abs(rect.width - 780) <= 1, (540...600).contains(rect.height)
      else { continue }
      return (info[kCGWindowLayer as String] as? NSNumber)?.intValue
    }
    return nil
  }

  /// Arbor's own windows at the normal level that share some of the screen with `window`, as the window server stacks them:
  /// those in front of it and those behind it. Nil if the window is not on screen. Not the focus ring's
  /// panel, which surrounds the whole window and lets the mouse through.
  func panelsSharingTheScreen(with window: WindowID) -> (over: [CGRect], under: [CGRect])? {
    // The list runs from front to back.
    guard let pid = arbor?.processIdentifier, let frame = actualFrames()[window],
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    else { return nil }
    var over: [CGRect] = []
    var under: [CGRect] = []
    var passed = false
    for info in list {
      if (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value == window.rawValue {
        passed = true
        continue
      }
      guard (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid,
        (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
        let bounds = info[kCGWindowBounds as String] as? NSDictionary,
        let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary), rect.overlaps(frame), !rect.contains(frame)
      else { continue }
      if passed { under.append(rect) } else { over.append(rect) }
    }
    return passed ? (over, under) : nil
  }

  func displayBounds() -> [CGRect] {
    var count: UInt32 = 0
    CGGetActiveDisplayList(0, nil, &count)
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetActiveDisplayList(count, &ids, &count)
    return ids.map(CGDisplayBounds)
  }

  func visibleFraction(_ window: WindowID) -> CGFloat {
    guard let frame = actualFrames()[window] else { return 0 }
    return displayBounds().map { frame.fractionInside($0) }.max() ?? 0
  }

  /// The window server applies Arbor's moves a moment after the Accessibility
  /// call returns, and `settled` only waits for windows that have a slot in the
  /// layout. Parked and restored windows are given up to three seconds.
  func leavesView(_ window: WindowID) -> Bool {
    poll(3) { self.visibleFraction(window) < 0.05 }
  }

  func comesIntoView(_ window: WindowID) -> Bool {
    poll(3) { self.visibleFraction(window) > 0.9 }
  }

  /// `0.37 at (1023,704 640×420)`, for the detail of a failed visibility check.
  func whereabouts(_ window: WindowID) -> String {
    "\(visibleFraction(window)) at \(actualFrames()[window].map(describe) ?? "missing")"
  }

  // MARK: Checks

  func check(_ name: String, _ condition: Bool, _ detail: @autoclosure () -> String = "") {
    if condition {
      passes += 1
      print("  ✔ \(name)")
      remark("✔ \(name)")
    } else {
      let message = detail()
      failures.append("\(name)\(message.isEmpty ? "" : ": \(message)")")
      print("  ✘ \(name)\(message.isEmpty ? "" : " — \(message)")")
      let recorded = remark("✘ \(name)")
      showWhatArborLogged()
      if recorded { print("    ↳ recorded in traces/\(traceName(traceNumber)).jsonl") }
      keepTheMoment()
    }
  }

  /// A step begins: what Arbor logs from here on belongs to it, and so does what is recorded.
  func noteWhereTheLogIs() {
    logShown = arborLog().utf8.count
    nextTrace()
  }

  // MARK: Recording

  func traceName(_ number: Int) -> String { "e2e-" + (number < 10 ? "0" : "") + String(number) }

  /// A word to Arbor's recorder, which Arbor takes for nothing else. Whether it was taken; nil if nobody answered within a second, as
  /// in the steps that kill Arbor.
  func recorder(_ words: String) -> Bool? {
    guard keeps != nil, let reply = try? ControlClient.send("trace " + words, socketPath: socket, timeout: 1) else { return nil }
    return (try? JSONDecoder().decode(CommandResult.self, from: Data(reply.utf8)))?.ok
  }

  /// Refused during a pause and in the middle of a drag. A number is used up only by a trace that has begun.
  func nextTrace(_ remark: String = "") {
    if recorder("next \(traceName(traceNumber + 1)) \(remark)") == true { traceNumber += 1 }
  }

  /// Whether the remark is in the trace that holds what it is about. Refused when nothing is being recorded: Arbor was started again, or a pause ended
  /// the trace. Then the next one begins here, too late for that.
  @discardableResult
  func remark(_ text: String) -> Bool {
    let noted = recorder("note \(text)")
    if noted == false { nextTrace(text) }
    return noted == true
  }

  /// What the screen looked like when a check failed, and which windows were on it: an alert of macOS's that lies over the test windows shows in no log.
  /// Where `keeps` is set, which is on GitHub's Macs: it is the whole screen. The first twenty: the twenty-first failure has the cause of one of them.
  func keepTheMoment() {
    guard let keeps, failures.count <= 20 else { return }
    let name = "failed-" + (failures.count < 10 ? "0" : "") + String(failures.count)
    try? FileManager.default.createDirectory(at: keeps, withIntermediateDirectories: true)
    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    // As the pointer tool of the Mac shell scripts lists them, from front to back: id, process, layer, frame, owner.
    let lines = list.map { info -> String in
      let rect = (info[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0 as CFDictionary) } ?? .zero
      let numbers = [kCGWindowNumber, kCGWindowOwnerPID, kCGWindowLayer].map { (info[$0 as String] as? NSNumber)?.intValue ?? 0 }
        + [rect.minX, rect.minY, rect.width, rect.height].map { Int($0) }
      return (numbers.map(String.init) + ["on", info[kCGWindowOwnerName as String] as? String ?? "?"]).joined(separator: " ")
    }
    try? Data((lines.joined(separator: "\n") + "\n").utf8).write(to: keeps.appendingPathComponent(name + ".txt"))
    let camera = Process()
    camera.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    // -x: no sound. -C: with the pointer.
    camera.arguments = ["-x", "-C", keeps.appendingPathComponent(name + ".png").path]
    if (try? camera.run()) != nil { camera.waitUntilExit() }
    print("    ↳ the screen at that moment: \(name).png, the windows on it: \(name).txt")
  }

  /// The home folder goes with the run. On a hosted Mac these are all that is left to tell what happened there.
  func keepLogAndTraces() {
    guard let keeps else { return }
    let files = FileManager.default
    try? files.createDirectory(at: keeps.appendingPathComponent("traces"), withIntermediateDirectories: true)
    for name in (try? files.contentsOfDirectory(atPath: home.path)) ?? [] where name.hasPrefix("arbor") && name.contains(".log") {
      try? files.removeItem(at: keeps.appendingPathComponent(name))
      try? files.copyItem(at: home.appendingPathComponent(name), to: keeps.appendingPathComponent(name))
    }
    let traces = home.appendingPathComponent("traces")
    for name in (try? files.contentsOfDirectory(atPath: traces.path)) ?? [] where name.hasSuffix(".jsonl") {
      // Without the date and the time: the number says the order.
      let target = keeps.appendingPathComponent("traces").appendingPathComponent(String(name.dropFirst(18)))
      try? files.removeItem(at: target)
      try? files.copyItem(at: traces.appendingPathComponent(name), to: target)
    }
  }

  /// What Arbor logged since the step began, under the check that failed. The end of the log, printed when the run is over, is
  /// several launches past most steps, and whoever reads the report has nothing else to go by. The arrow is Swift Testing's for a note
  /// under an issue: scripts/ci-step.py publishes such lines with the failure they stand under.
  func showWhatArborLogged() {
    let log = Array(arborLog().utf8)
    let new = String(decoding: log.dropFirst(log.count >= logShown ? logShown : 0), as: UTF8.self)
    logShown = log.count
    for line in forOthersToRead(new).split(separator: "\n").suffix(60) { print("    ↳ \(line)") }
  }

  /// Waits until the window server agrees with every frame Arbor says it set.
  func settled(_ state: StateSnapshot) -> Bool {
    poll(4) {
      let actual = self.actualFrames()
      for display in state.displays {
        for (window, expected) in display.windowFrames where self.testWindows.contains(window) {
          guard let frame = actual[window], frame.approximatelyEquals(expected, tolerance: 3) else { return false }
        }
      }
      return true
    }
  }

  func step(_ title: String, _ command: String, body: (StateSnapshot) throws -> Void) throws {
    print("\n▸ \(title)  (\(command))")
    noteWhereTheLogIs()
    let result = try send(command)
    check("command succeeded", result.ok, result.message)
    let state = try state()
    check("windows match Arbor's layout", settled(state), mismatchDescription(state))
    try body(state)
  }

  /// Saves the hand-edited settings.json with another `gap`, as an editor would, and waits for Arbor to
  /// take it in without being told. `written` is the number as the file spells it.
  func editSettings(gap written: String, replacingTheFile: Bool, visible: CGRect) throws {
    let newGap = Double(written) ?? -1
    let text = Self.handEditedSettings.replacingOccurrences(of: "12.0", with: written)
    try Data(text.utf8).write(to: settingsFile, options: replacingTheFile ? [.atomic] : [])
    let noticed = poll(5) { (try? self.send("get gap"))?.text.flatMap { Double($0) } == newGap }
    check("Arbor uses the new gap", noticed, (try? send("get gap"))?.text ?? "no reply")
    let state = try state()
    check("windows match Arbor's layout", settled(state), mismatchDescription(state))
    let leftmost = state.displays[0].windowFrames.values.map(\.minX).min() ?? 0
    check(
      "windows start \(written) points from the edge", abs(leftmost - visible.minX - CGFloat(newGap)) <= 3,
      "\(leftmost)")
  }

  func mismatchDescription(_ state: StateSnapshot) -> String {
    let actual = actualFrames()
    var parts: [String] = []
    for display in state.displays {
      for (window, expected) in display.windowFrames.sorted(by: { $0.key < $1.key }) {
        parts.append("\(window) expected \(describe(expected)) actual \(actual[window].map(describe) ?? "missing")")
      }
    }
    return parts.joined(separator: "; ")
  }

  func describe(_ rect: CGRect) -> String {
    "(\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))×\(Int(rect.height)))"
  }

  // MARK: The scenario

  func run() throws -> Int32 {
    try startGuardian()
    try launchHelper()
    print("test windows: \(testWindows.map(\.description).joined(separator: " ")) (pid \(helperPID))")
    // In every report: a run that passes with the screen locked says as much as one that fails.
    print("this Mac: \(MacState.now.inWords)")
    try Data(Self.handEditedSettings.utf8).write(to: settingsFile)
    try launchArbor()

    guard poll(10, { (try? self.send("status")) != nil }) else {
      throw Setup(description: "Arbor did not open its control socket")
    }
    let status = try state()
    guard status.accessibility else {
      print(
        """

        Arbor is running but has no Accessibility permission, so it cannot move windows.
        Grant it to the terminal app you are running this from:
          System Settings → Privacy & Security → Accessibility → enable your terminal
        then run `make e2e` again.
        """)
      announce(.notReady, "no Accessibility permission for the terminal this runs from")
      return Ending.notReady.rawValue
    }
    guard poll(10, { ((try? self.state())?.windows.filter(\.managed).count ?? 0) >= 3 }) else {
      throw Setup(description: "Arbor did not find the three test windows")
    }
    isUnderWay = true

    let (w1, w2, w3) = (testWindows[0], testWindows[1], testWindows[2])

    print("\n▸ start watching events  (watch)")
    noteWhereTheLogIs()
    let watcher = Watcher("watch", socket: socket)
    check("hello arrives at once", poll(5) { !watcher.lines.isEmpty })
    if case .hello(let hello)? = watcher.events.first {
      check("hello says that Arbor is running", hello.snapshot.running && hello.snapshot.accessibility)
      check("hello lists the test windows, floating", testWindows.allSatisfy { id in
        hello.snapshot.windows.contains { $0.id == id && !$0.docked }
      })
    } else {
      check("the first line is hello", false, watcher.lines.first ?? "nothing")
    }

    let start = try state()
    guard let display = start.display(containing: w1) else { throw Setup(description: "\(w1) not managed") }
    let visible = display.visibleFrame
    print("display \(display.id) visible frame \(describe(visible))")
    // Where the windows were before Arbor touched them (F48).
    let untouched = actualFrames()

    var columnFrame = CGRect.zero
    var firstHalf = CGRect.zero
    try step("dock the first window on the left", "dock \(w1.rawValue) left") { state in
      let frame = state.displays[0].windowFrames[w1]
      firstHalf = frame ?? .zero
      check("\(w1) is docked", frame != nil)
      check("\(w1) sits at the left edge", abs((frame?.minX ?? 0) - (visible.minX + gap)) <= 3)
      check("what is left over is the Desktop", state.displays[0].desktopFrame != nil)
    }
    try step("dock the second window on the right", "dock \(w2.rawValue) right") { state in
      let frames = state.displays[0].windowFrames
      check("\(w2) sits at the right edge", abs((frames[w2]?.maxX ?? 0) - (visible.maxX - gap)) <= 3)
      // Two docks are two halves (Q28): the second takes all that is left, and the first stays as it is.
      check("nothing is kept for the Desktop", state.displays[0].desktopFrame == nil, describe(state.displays[0].desktopFrame ?? .zero))
      check("one gap lies between them", abs((frames[w2]?.minX ?? 0) - (frames[w1]?.maxX ?? 0) - gap) <= 3)
      check("\(w1) has the place it had", frames[w1] == firstHalf, describe(frames[w1] ?? .zero))
    }
    try step("dock the third window below the first", "dock \(w3.rawValue) beside \(w1.rawValue) bottom") { state in
      let frames = state.displays[0].windowFrames
      columnFrame = frames[w1] ?? .zero
      check("\(w3) is below \(w1)", (frames[w3]?.minY ?? 0) > (frames[w1]?.maxY ?? .infinity))
      check("\(w3) shares \(w1)'s column", abs((frames[w3]?.minX ?? 0) - (frames[w1]?.minX ?? 1)) <= 3)
    }
    try step("look behind the docked windows", "status") { _ in
      check("the backdrop is on screen just above the Desktop's icons", poll(2) { !self.backdropFrames().isEmpty })
      let frame = backdropFrames().first ?? .zero
      check("it covers the display's visible frame", frame.approximatelyEquals(visible, tolerance: 1), describe(frame))
    }
    try step("frame the first window on its own", "zoom \(w1.rawValue)") { state in
      let expected = visible.insetBy(dx: gap, dy: gap)
      let frame = actualFrames()[w1] ?? .zero
      check("\(w1) fills the screen", frame.approximatelyEquals(expected, tolerance: 3), describe(frame))
      check("\(w2) is out of view", leavesView(w2), whereabouts(w2))
      check("\(w3) is out of view", leavesView(w3), whereabouts(w3))
    }
    try step("go back", "back") { state in
      for window in [w1, w2, w3] {
        check("\(window) is back in view", comesIntoView(window), whereabouts(window))
      }
      let frame = actualFrames()[w1] ?? .zero
      check("\(w1) is back in its slot", frame.approximatelyEquals(columnFrame, tolerance: 3), describe(frame))
    }
    try step("resize the first window by command", "resize \(w1.rawValue) right 100") { _ in
      let frame = actualFrames()[w1] ?? .zero
      check("\(w1) is 100 points wider", abs(frame.width - (columnFrame.width + 100)) <= 3, describe(frame))
    }

    // B2: this used to crash Arbor, so a missing reply is a failed check, not a failed setup.
    print("\n▸ resize by an absurd amount  (resize \(w1.rawValue) right 1e300)")
    noteWhereTheLogIs()
    let absurd = try? send("resize \(w1.rawValue) right 1e300")
    check("the command is refused", absurd?.ok == false, absurd?.message ?? "no reply")
    check("Arbor is still running", (try? send("status"))?.ok == true)

    try step("float the second window", "float \(w2.rawValue)") { state in
      check("\(w2) is floating", state.displays[0].floating.contains(w2))
      let desktop = state.displays[0].desktopFrame ?? .zero
      check("the Desktop reaches the right edge", abs(desktop.maxX - (visible.maxX - gap)) <= 3, describe(desktop))
      // All of it, whatever is docked where it lay: a floating window's frame is its person's (F48, F64).
      let old = untouched[w2]?.size ?? .zero
      let hasOldSize = poll(3) {
        let size = self.actualFrames()[w2]?.size ?? .zero
        return abs(size.width - old.width) <= 3 && abs(size.height - old.height) <= 3
      }
      check("\(w2) has its old size back", hasOldSize, "\(whereabouts(w2)), not \(Int(old.width))×\(Int(old.height))")
      // There and back is nothing: the place too.
      let place = untouched[w2]?.origin ?? .zero
      let isWhereItWas = poll(3) {
        let origin = self.actualFrames()[w2]?.origin ?? CGPoint(x: -1, y: -1)
        return abs(origin.x - place.x) <= 3 && abs(origin.y - place.y) <= 3
      }
      check("\(w2) is where it was", isWhereItWas, "\(whereabouts(w2)), not at \(Int(place.x)),\(Int(place.y))")
      check("all of it is on the display", visibleFraction(w2) > 0.99, whereabouts(w2))
    }
    try soleFloatingWindow(w2)
    // Gap handles cannot be seen and take clicks. In front of a floating window one would take a strip of its clicks.
    try step("move the floating window across two gaps", by: "the app moves \(w2) and brings it to the front") {
      let column = try state().displays[0].windowFrames[w1] ?? .zero
      let across = CGRect(x: column.maxX - 150, y: column.maxY - 100, width: 300, height: 200)
      tell("move \(w2.rawValue) \(Int(across.minX)) \(Int(across.minY)) 300 200")
      tell("front \(w2.rawValue)")
      let arrived = poll(3) { (self.actualFrames()[w2] ?? .zero).approximatelyEquals(across, tolerance: 3) }
      check("\(w2) lies across the gap below \(w1) and the gap beside it", arrived, whereabouts(w2))
    }
    try step("resize under the floating window", "resize \(w1.rawValue) right -40") { _ in
      // Both gaps changed, so both handles were shown again. A handle is as thin as the gap; the focus ring's panel is not.
      func handles(_ panels: [CGRect]) -> [CGRect] { panels.filter { min($0.width, $0.height) <= gap + 1 } }
      let settledBehind = poll(3) {
        guard let panels = self.panelsSharingTheScreen(with: w2) else { return false }
        return panels.over.isEmpty && handles(panels.under).count == 2
      }
      let panels = panelsSharingTheScreen(with: w2)
      check("two gap handles lie under \(w2)", handles(panels?.under ?? []).count == 2, "\(panels?.under.map(describe) ?? [])")
      check("and none of Arbor's panels over it", settledBehind, "\(panels?.over.map(describe) ?? [])")
    }
    try step("arrange everything", "arrange") { state in
      check("all three are docked", Set(state.displays[0].tree.allWindows) == Set([w1, w2, w3]))
      for window in [w1, w2, w3] {
        check("\(window) is in view", comesIntoView(window), whereabouts(window))
      }
    }
    try step("change the gap with a command", "set gap 40") { state in
      let leftmost = state.displays[0].windowFrames.values.map(\.minX).min() ?? 0
      check("windows start 40 points from the edge", abs(leftmost - visible.minX - 40) <= 3, "\(leftmost)")
      let expected = Self.handEditedSettings.replacingOccurrences(of: "12.0", with: "40")
      check("only the gap changed in settings.json", settingsText() == expected, settingsText())
    }
    // The titles are spelt out here because `make parity` looks for them in this file.
    print("\n▸ replace settings.json as most editors do  (no command)")
    noteWhereTheLogIs()
    try editSettings(gap: "24", replacingTheFile: true, visible: visible)
    // Back to the file Arbor started on, and so to the gap the other steps expect.
    print("\n▸ write into settings.json in place  (no command)")
    noteWhereTheLogIs()
    try editSettings(gap: "12.0", replacingTheFile: false, visible: visible)
    // Two above the floating level: `PassingPanel`.
    try step("show the shortcuts on screen", "show-shortcuts") { _ in
      check("the panel is on screen", poll(3) { self.arborShowsPanel(atLevel: 5) })
    }
    try step("put the shortcuts away", "show-shortcuts") { _ in
      check("the panel is gone", poll(3) { !self.arborShowsPanel(atLevel: 5) })
    }
    // F54: the line crosses the socket as it is typed, signs and all.
    let line = "\(w2.rawValue) | Desktop | (\(w3.rawValue) / \(w1.rawValue))"
    try step("arrange by a line of text", "layout \(line)") { state in
      let frames = state.displays[0].windowFrames
      let desktop = state.displays[0].desktopFrame ?? .zero
      check("\(w2) is left of the Desktop", (frames[w2]?.maxX ?? .infinity) < desktop.minX, describe(desktop))
      check("\(w3) is right of the Desktop", (frames[w3]?.minX ?? 0) > desktop.maxX, describe(desktop))
      check("\(w3) is above \(w1)", (frames[w3]?.maxY ?? .infinity) < (frames[w1]?.minY ?? 0))
      let printed = try send("layout --ids")
      check("`layout --ids` prints the same line", printed.text == line, printed.text ?? printed.message)
    }
    let testApp = start.windows.first { $0.id == w1 }?.app ?? "ArborTestWindows"
    try step("arrange by app name, the rest as tabs", "layout \"\(testApp)\" | \"\(testApp)\"*") { state in
      check("all three are docked", Set(state.displays[0].tree.allWindows) == Set([w1, w2, w3]))
      check("two of them show", state.displays[0].windowFrames.count == 2, "\(state.displays[0].windowFrames.keys.sorted())")
      for window in [w1, w2, w3] where state.displays[0].windowFrames[window] == nil {
        check("the tab behind, \(window), is out of view", leavesView(window), whereabouts(window))
      }
    }
    // A tab group hides a window by design. The steps that follow expect to find all three.
    try step("put the three side by side again", "arrange") { state in
      check("all three show", Set(state.displays[0].windowFrames.keys) == Set([w1, w2, w3]))
    }
    try step("show the Desktop", "desktop") { _ in
      for window in [w1, w2, w3] {
        check("\(window) is out of view", leavesView(window), whereabouts(window))
      }
    }
    try step("look behind the Desktop", "status") { _ in
      check("there is no backdrop while nothing docked is in view", poll(2) { self.backdropFrames().isEmpty })
    }

    // B1: the app's own wiring of settings.json, which no headless test reaches.
    try step("stop arranging an app", "exclude com.example.second") { _ in
      let expected = Self.handEditedSettings.replacingOccurrences(
        of: #"["com.example.first"]"#, with: #"["com.example.first", "com.example.second"]"#)
      check("only that list changed in settings.json", settingsText() == expected, settingsText())
    }
    try step("arrange it again", "include com.example.second") { _ in
      check("settings.json is as it was, byte for byte", settingsText() == Self.handEditedSettings, settingsText())
    }

    print("\n▸ reload a settings file with a typo  (reload-settings)")
    noteWhereTheLogIs()
    let typo = Self.handEditedSettings.replacingOccurrences(of: "12.0,", with: "12.0")
    try Data(typo.utf8).write(to: settingsFile)
    let reload = try send("reload-settings")
    check("the reload is refused", !reload.ok, reload.message)
    // Where the next member begins, which is where the missing comma is noticed. Counted, so that a line more in the file above does not move it.
    let noticed = typo.components(separatedBy: "\n").firstIndex { $0.contains("myNote") }.map { $0 + 1 } ?? 0
    check("the reply says where the typo is", reload.message.contains("line \(noticed), column 3"), reload.message)
    let unsaved = try send("exclude com.example.second")
    check("a change is refused meanwhile", !unsaved.ok, unsaved.message)
    check("the file with the typo is left alone", settingsText() == typo, settingsText())
    // Mended, also for the launches that follow.
    try Data(Self.handEditedSettings.utf8).write(to: settingsFile)
    let mended = try send("reload-settings")
    check("mended, it loads again", mended.ok, mended.message)

    print("\n▸ what the watcher heard  (watch)")
    noteWhereTheLogIs()
    check("the Desktop on its own, last", poll(3) { watcher.views.last?.kind == .desktop }, "\(watcher.views.last as Any)")
    check("every line is an event", watcher.events.count == watcher.lines.count)
    for window in [w1, w2, w3] {
      check("\(window) was docked", watcher.windowChanges.contains { $0.change == .docked && $0.window.id == window })
    }
    check("\(w2) was floated", watcher.windowChanges.contains { $0.change == .floated && $0.window.id == w2 })
    check(
      "\(w1) framed on its own, with a way back",
      watcher.views.contains { $0.kind == .window && $0.windows == [w1] && $0.canGoBack && $0.outOfView == 2 })
    check(
      "a layout with all three windows in view",
      watcher.events.contains { if case .layout(let layout) = $0 { layout.frames.count == 3 && layout.docked == 3 } else { false } })
    check(
      "a test window getting the keyboard",
      watcher.events.contains { if case .focus(let focus) = $0 { focus.window.map(testWindows.contains) ?? false } else { false } })
    check("no window titles, which nobody asked for", !watcher.lines.contains { $0.contains("Arbor Test") })
    check("still connected", watcher.end == nil)
    try goTo(w1, w2, w3)

    // F12: what the settings window shows is tested without it. Whether it opens, takes the keyboard and stays above
    // Arbor's own panels, and who has the keyboard after it, only a Mac can say.
    try step("show everything behind the settings window", "show-all") { _ in }
    try step("give a window the keyboard before opening the settings window", "zoom \(w1.rawValue)") { _ in
      check("\(w1) has the keyboard", poll(5) { (try? self.state())?.focused == w1 })
    }
    try step("open the settings window", "settings-window") { _ in
      check("a window of its size, Arbor's own, is on screen", poll(3) { self.settingsWindowLayer() != nil })
      check(
        "it has the keyboard, and so floats above tiles and gap handles", poll(3) { self.settingsWindowLayer() == 3 },
        "layer \(settingsWindowLayer().map(String.init) ?? "none")")
    }
    try step("change the gap behind the open settings window", "set gap 30") { _ in
      check(
        "the window is still there, above the panels that were drawn again", poll(2) { self.settingsWindowLayer() == 3 },
        "layer \(settingsWindowLayer().map(String.init) ?? "none")")
    }
    let pane = try send("settings-window shortcuts")
    check("it turns to a pane by name", pane.ok && pane.message.hasSuffix("at Shortcuts"), pane.message)
    check("a pane it does not have is refused", (try? send("settings-window nonsense"))?.ok == false)
    try step("close the settings window", "settings-window close") { _ in
      check("it is gone", poll(3) { self.settingsWindowLayer() == nil })
      check(
        "the window that had the keyboard has it again", poll(5) { (try? self.state())?.focused == w1 },
        "focused: \((try? state())?.focused.map(\.description) ?? "none")")
    }
    // Back to the file the launches that follow expect, to the byte.
    try Data(Self.handEditedSettings.utf8).write(to: settingsFile)
    _ = try send("reload-settings")

    // Without one, what is said of the watchdog after the quit would hold whatever Arbor did.
    print("\n▸ the watchdog before the quit  (no command)")
    noteWhereTheLogIs()
    let watchdog = watchdogPID()
    check("Arbor's watchdog stands by", watchdog.map { kill($0, 0) == 0 } ?? false, "pid \(watchdog.map(String.init) ?? "unknown")")

    print("\n▸ quit Arbor  (quit)")
    noteWhereTheLogIs()
    _ = try? send("quit")
    let exited = poll(5) { !(self.arbor?.isRunning ?? false) }
    check("Arbor exited", exited)
    for window in [w1, w2, w3] {
      check("\(window) is visible after quitting", comesIntoView(window), whereabouts(window))
    }
    for window in [w1, w3] {
      let isBack = poll(3) {
        untouched[window].map { self.actualFrames()[window]?.approximatelyEquals($0, tolerance: 3) == true } ?? false
      }
      check("\(window) is back where it was before Arbor", isBack, whereabouts(window))
    }

    print("\n▸ the watcher is told that Arbor quit  (watch)")
    noteWhereTheLogIs()
    check("the watch ended as arborctl's exit code 0", poll(5) { watcher.end != nil } && watcher.end == .stopped, "\(watcher.end as Any)")
    check("quitting is the last event", watcher.events.last == .quitting, watcher.lines.last ?? "nothing")

    check("the watchdog does not start Arbor again after a quit", !poll(2) { (try? self.send("status")) != nil })
    check("the watchdog has left as well", poll(5) { watchdog.map { kill($0, 0) != 0 } ?? false })

    try accidents()

    try misbehavingWindows(w1, w2, w3)
    try newWindows(w1, w3)

    print("\n\(passes) passed, \(failures.count) failed")
    return failures.isEmpty ? 0 : 1
  }

  // MARK: Accidents

  /// Waits until an Arbor other than `previous` is arranging the three test windows.
  func arborIsBack(after previous: Int32?) -> Bool {
    poll(15) {
      guard let pid = self.arborPID(), pid != previous, let state = try? self.state() else { return false }
      return state.running && state.windows.filter(\.managed).count >= 3
    }
  }

  /// Ends Arbor as a crash would: at once, with no chance to put anything back.
  func killArbor() -> Int32? {
    // Arbor saves half a second after a change.
    Thread.sleep(forTimeInterval: 1)
    guard let pid = arborPID() else { return nil }
    kill(pid, SIGKILL)
    return pid
  }

  /// What must not cost anybody a window: rude clients, a second copy, crashes, and crashing again and again.
  func accidents() throws {
    let (w1, w2, w3) = (testWindows[0], testWindows[1], testWindows[2])

    print("\n▸ start Arbor again  (launch)")
    noteWhereTheLogIs()
    try launchArbor()
    check("Arbor is arranging the windows", arborIsBack(after: nil))
    check("the arrangement is back", Set(try state().displays[0].tree.allWindows) == Set([w1, w2, w3]))
    // Whatever the steps before left behind (a tab group hides a window by design): three windows side by side.
    try step("arrange, so that what follows depends on nothing before it", "arrange") { state in
      check("all three show", Set(state.displays[0].windowFrames.keys) == Set([w1, w2, w3]))
    }

    print("\n▸ clients that hang up without reading the reply  (state)")
    noteWhereTheLogIs()
    for _ in 0..<20 { askAndHangUp(socket) }
    Thread.sleep(forTimeInterval: 0.5)
    check("Arbor is still running", arbor?.isRunning == true)
    check("Arbor still answers", (try? send("status"))?.ok == true)

    print("\n▸ a second copy of Arbor  (launch)")
    noteWhereTheLogIs()
    let before = try state()
    let second = try launchArbor(asSecondCopy: true)
    check("the second copy leaves by itself", poll(8) { !second.isRunning })
    if second.isRunning {
      second.terminate()
    } else {
      check("its exit code says that Arbor is running already", second.terminationStatus == 75, "\(second.terminationStatus)")
    }
    check("the first copy still answers", (try? send("status"))?.ok == true)
    check("nothing moved", try state().displays == before.displays)

    try step("frame the first window before the crash", "zoom \(w1.rawValue)") { _ in
      check("\(w2) is out of view", leavesView(w2), whereabouts(w2))
      check("\(w3) is out of view", leavesView(w3), whereabouts(w3))
    }
    let arranged = try state().displays[0]

    print("\n▸ kill Arbor while windows are parked  (kill -9)")
    noteWhereTheLogIs()
    var previous = killArbor()
    check("Arbor was running", previous != nil)
    check("the watchdog starts Arbor again", arborIsBack(after: previous))
    let restored = try state().displays[0]
    check("the arrangement survived", restored.tree == arranged.tree)
    check("the camera is where it was", restored.camera == arranged.camera)
    try step("show everything after the crash", "show-all") { _ in
      for window in [w1, w2, w3] {
        check("\(window) is back in view", comesIntoView(window), whereabouts(window))
      }
    }

    try step("show the Desktop before crashing again and again", "desktop") { _ in
      for window in [w1, w2, w3] {
        check("\(window) is out of view", leavesView(window), whereabouts(window))
      }
    }
    try step("pause, as for a game", "pause") { _ in
      for window in [w1, w2, w3] {
        check("\(window) is back in view", comesIntoView(window), whereabouts(window))
      }
    }
    print("\n▸ kill Arbor during the pause  (kill -9)")
    noteWhereTheLogIs()
    previous = killArbor()
    check("the watchdog starts Arbor a second time, and it is still paused", poll(15) {
      guard let pid = self.arborPID(), pid != previous, let state = try? self.state() else { return false }
      return state.paused && !state.running
    })
    Thread.sleep(forTimeInterval: 1)
    for window in [w1, w2, w3] {
      check("\(window) stays in view", visibleFraction(window) > 0.9, whereabouts(window))
    }
    try step("resume", "resume") { state in
      check("Arbor is running again", state.running && !state.paused)
      check("the arrangement is as it was", state.displays[0].tree == arranged.tree)
    }
    // A resume ends with the focused window in view, so the view need not be the one the pause began in.
    try step("show the Desktop again before the last crash", "desktop") { _ in
      for window in [w1, w2, w3] {
        check("\(window) is out of view", leavesView(window), whereabouts(window))
      }
    }
    print("\n▸ kill Arbor a third time within two minutes  (kill -9)")
    noteWhereTheLogIs()
    _ = killArbor()
    check("the third time Arbor only rescues the windows and quits", poll(15) {
      self.arborPID() == nil && [w1, w2, w3].allSatisfy { self.visibleFraction($0) > 0.9 }
    })
    for window in [w1, w2, w3] {
      check("\(window) is visible after the rescue", comesIntoView(window), whereabouts(window))
    }
    check("Arbor stays away", !poll(2) { (try? self.send("status")) != nil })
    check(
      "the saved state was set aside",
      FileManager.default.fileExists(atPath: home.appendingPathComponent("state.unreadable.json").path))

    // What follows in the run expects to find the three windows docked.
    print("\n▸ start Arbor after the rescue and arrange again  (launch, arrange, quit)")
    noteWhereTheLogIs()
    try launchArbor()
    check("Arbor starts afresh", arborIsBack(after: nil))
    check("the windows are arranged again", (try? send("arrange"))?.ok == true)
    quitArbor()
  }
}

/// Connects to the control socket at `path`, asks for `state`, and hangs up without reading the reply.
func askAndHangUp(_ path: String) {
  // Only where it runs: `make typecheck-mac` checks this file on Linux, whose sockets are typed differently.
  #if canImport(Darwin)
    guard var address = try? UnixSocket.address(for: path) else { return }
    let fd = socket(AF_UNIX, SOCK_STREAM, 0)
    let connected = withUnsafePointer(to: &address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
    if connected == 0 { _ = "state\n".withCString { write(fd, $0, 6) } }
    close(fd)
  #endif
}

/// Polls `condition` every 100 ms for up to `seconds`.
func poll(_ seconds: TimeInterval, _ condition: () -> Bool) -> Bool {
  let deadline = Date().addingTimeInterval(seconds)
  while Date() < deadline {
    if condition() { return true }
    Thread.sleep(forTimeInterval: 0.1)
  }
  return condition()
}

func readLine(from handle: FileHandle) -> String {
  var data = Data()
  while true {
    let chunk = handle.readData(ofLength: 1)
    if chunk.isEmpty || chunk.first == UInt8(ascii: "\n") { break }
    data.append(chunk)
  }
  return String(decoding: data, as: UTF8.self)
}

// Line by line also into a file or a pipe: what a run had said when it was killed is what tells how far it got.
setvbuf(stdout, nil, _IOLBF, 0)
let code: Int32
do {
  let runner = try Runner()
  let manners = Manners(runner)
  guard manners.mayStart() else {
    runner.cleanUp()
    exit(Ending.somebodyIsHere.rawValue)
  }
  manners.watch()
  do {
    code = try runner.run()
  } catch {
    // Before the clean-up, which ends what the facts are about.
    let ending: Ending
    if runner.isUnderWay {
      ending = .lostInMidRun
      announce(ending, "in the middle of the run: \(error)", facts: runner.whatTheMacSays())
    } else if let why = MacState.now.whyNothingShows {
      ending = .nobodyCouldSeeIt
      announce(ending, "\(why), and the set-up failed: \(error)", facts: runner.whatTheMacSays())
    } else {
      ending = .setupFailed
      announce(ending, "set-up failed: \(error)", facts: runner.whatTheMacSays())
    }
    runner.failures.append("\(error)")
    runner.cleanUp()
    exit(ending.rawValue)
  }
  runner.cleanUp()
} catch {
  announce(.notReady, "\(error)")
  exit(Ending.notReady.rawValue)
}
exit(code)
