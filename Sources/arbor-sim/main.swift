import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation

// arbor-sim: drive the real controller against a fake window system and
// print the layout after every step. No permissions, no real windows.
//
//   swift run arbor-sim "open Safari" "open Notes" "dock 101 left" "dock 102 right" "zoom 101"
//   echo "open Mail\ndock 101 left" | swift run arbor-sim
//   swift run arbor-sim --serve /tmp/sim.sock     # take commands from arborctl instead (Serve.swift)
//
// Besides every arborctl command (see `help`), the simulator understands:
//   open <App> [WxH] [min WxH] [fixed]
//                                open a window (ids start at 101); `fixed`: its size cannot be changed
//   open <App> [<WxH>] [at <x> <y>] …   `at` says where the window opens
//   close <id> | minimize <id> | restore <id>
//   focus <id>                   click a window (`focus left`, `focus next`… are Arbor's own commands)
//   cursor <x> <y>               move the pointer (camera commands use it)
//   press <command>              press and release a shortcut bound to that command
//   from <source> <command>      run it as a shortcut, menu, gesture, script or url would (plain commands: script)
//   menu-choose <title…>         open Arbor's menu and click the first row, in a submenu or not, whose title begins so (`menu` prints them)
//   keydown | keyup | key <shortcut>   a shortcut by its keys (ctrl+opt+space): press and hold, let go, or both
//   mouse down|up                press or release the mouse button where the pointer is
//   type                         type a few characters into the focused window
//   wait <seconds>               let that much time pass, running the scheduled work that falls due
//   drag <id> <x> <y> [quick] [cmd]
//                                drag a window by its title bar to a point and hold it there
//                                before letting go; `quick` lets go at once, `cmd` holds ⌘
//   pick-up <id> <x> <y>         the first half of a drag: the window is held at that point, with the button down
//   let-go                       the second half
//   mac-tiling on|off            macOS's own tiling of dragged windows: on, as a Mac comes and every run begins, or off. With it on the
//                                left, right and top edges of the screen are macOS's, which tiles a window let go at their last point
//   move <id> <x> <y> <w> <h>    move/resize a window without the mouse
//   shove <id> <x> <y> [then <x> <y>]
//                                what no command does: the window is moved the way Arbor moves windows, behind the
//                                controller's back. For the tools' own test, which needs a window that is moved twice
//   pull <id> <edge> <points> [<edge> <points>]
//                                drag a window's edges with the mouse (positive grows it)
//   seam <index> <delta>         drag the index-th seam handle
//   tile <node>                  click a tile
//   flush                        run pending scheduled work (saves, enforcement)
//   quiet | loud                 stop/start printing the layout after each step
//   display <match> <key> <value>  add an entry to the per-display options, e.g. display main gap 30
//   title <id> <text>            the app changes a window's title (it opens as "Terminal 101")
//   settings-file <path>         use this settings.json as the app uses its own: load it now
//                                (writing one if there is none), save changes to it
//                                (set, bind, rule, exclude…), and read it again on reload-settings
//   revoke | grant               take Accessibility permission away from Arbor, give it back; nobody tells it:
//                                it finds out at the next command, or within three seconds of `wait`. A loss of
//                                under three seconds, counted from when Arbor noticed, is taken for a false
//                                alarm and the view stays as it was: play a real one with `wait 10`
//   keyboard <name>              select a keyboard layout: us, german, french, dvorak, russian
//   macos defaults|tidy          Desktop & Dock is set as macOS comes (its own tiling and the wallpaper click are on), or
//                                with nothing in Arbor's way; `doctor` says what it makes of it
//   What Arbor says on screen after a step (a `press`, a drag, a click on a tile) is printed as `on screen: …`.
//   expect <form>                check the layout (collab/README.md, "Scenarios"); a form
//                                that does not hold prints EXPECTATION FAILED and makes
//                                arbor-sim exit with code 1 at the end
//   hide <App> | unhide <App>    hide or show an app (⌘H); each app name is its own process
//   background-focus <id>        an app that is not frontmost changes its focused window
//   displays <0|1|2> [below]     unplug or plug in a 1920x1080 display to the right of the main one, or below it; 0: none at all
//   macos-moves <id> <x> <y>     macOS moves the window, as when its display goes, and its app says so: no hand did it. Before `displays`
//   display-size <WxH> [<bar>]   the main display is this large, with a menu bar that high (1440x900 and 25 to begin with)
//   plug | unplug | make-main | move-display | quietly … | report-displays | max | where
//                                displays that change, one step at a time, told to Arbor at once or later: see Displays.swift
//   min <id> <WxH>               from now on the window refuses to be smaller (0x0: any size will do)
//   wait <seconds>               let time pass, running the scheduled work that falls due
//   watch [events…] [--titles]   from here on, print the lines `arborctl watch` would send after each step
//   fullscreen <id> on|off [where-it-was]
//                                the green button: the window gets a macOS Space to itself, so the other windows
//                                of its display are on a Space that does not show; off brings all of it back, as a Mac
//                                does (FakeWindowSystem.enterFullScreen, leaveFullScreen), and says where a person saw the window
//                                meanwhile, and which others they saw move.
//                                It lands at the frame it had before Arbor moved it; `where-it-was`: at the one it had last
//   comes-forward <id>           the window's app brings itself forward: nobody clicked or pressed anything
//   hold-still-for <bundle id> [title words…]
//                                add an entry to the `holdStillFor` setting
//   transitions                  start/stop printing the motion each step is shown with: one line
//                                per window drawn, back to front, `w101 (from) -> (to)`
//   rehearse-stage               from here on, while a trace is recorded, a stage that does everything right logs its
//                                frames into it as the real one does on a Mac, for `arbor-sim stage-judge` (RehearsedStage)
//   finder-type [text]           replace the text in the field of Go to… (`find` opens it)
//   finder-move <rows>           move its selection down, or with a negative number up
//   finder-choose [n]            press Return, or choose the n-th row that shows
//   finder-cancel                press Escape
//   scene                        list what Arbor draws at rest: the backdrop, tiles and seams
// `open Terminal` has the bundle id com.example.terminal, for `rule add` and `exclude`.
//   trace on [name] | trace off  record the session as a trace file in $ARBOR_HOME/traces
//   field-type [text]            type into the name field (`ask-name`) and press ↩
//   field-cancel                 press ⎋ in the name field
//   relaunch                     quit Arbor and start it again: every window comes back into view, then a new process
//                                that knows what was saved and nothing else. A trace or a `watch` ends with the quit
//   relaunch quit | relaunch start   the two halves apart: what comes between them happens while Arbor is not running
//   crash [<id>…]                Arbor dies as it stands and is started again: no window comes back first, what was not saved
//                                yet (`flush`) is lost, and a trace is cut off. The windows named are closed and opened again by
//                                their apps meanwhile: each is where it was, under the next number
//
// `arbor-sim replay <file.jsonl> [--strict] [--verbose]` replays a trace instead (Replay.swift).
// `arbor-sim stage-judge [<file.jsonl>…] [<limit>=<value>…]` judges the motion in traces from a Mac (StageJudge.swift).
//   map <id>|desktop|beside      click in the minimap: on a window, on the Desktop's outline, beside the map.
//                                Whenever the minimap changes it is printed as `minimap: [w101] w102 desktop`, with
//                                what is in view in brackets, or `minimap: gone`
// `arbor-sim film <script.txt> [--out <frames.jsonl>] [--fps <n>]` writes a script down frame by frame (Film.swift, docs/FILM.md).
// `arbor-sim launch [--state <file>] [--settings <file>] … [lines…]` starts on real files first (Launch.swift).
// `arbor-sim first-launch [--permitted] [lines…]` plays the first five minutes, welcome window and all (FirstLaunch.swift).
//
// A command that fails (a misspelt verb, a window that does not exist) also makes arbor-sim exit with
// code 1, unless the next line is `expect fail`: a script that does not do what it says proves nothing.
// So does a line after which a display's last layout is not what a layout would give now (LAYOUT OUT OF DATE):
// something changed the arrangement or the view and forgot to lay out.
// And so does a line during which Arbor moved a window twice where once would have done (MOVED TWICE; ArborTesting/Jolts.swift),
// unless `expect jolt <id>` follows, which is for a fault that is known and on the board.
//
//   swift run -c release arbor-sim bench [sizes…]   count and time everyday commands (Bench.swift)
// `arbor-sim chaos|hunt|shrink …`, and `replay` without a file, are the chaos test's modes: see ChaosModes.swift.
// `arbor-sim walk …` writes walks for a hosted Mac and plays them here: see WalkModes.swift.

@MainActor
func runSimulation() {
  var lines = Array(CommandLine.arguments.dropFirst())
  if lines.first == "--serve" {
    guard lines.count == 2 else {
      print("usage: arbor-sim --serve <socket path>")
      exit(2)
    }
    SimulatorServer().run(at: lines[1])
  }
  if lines.first == "bench" {
    runBenchmarks(Array(lines.dropFirst()))
    return
  }
  // `replay <file>` replays a trace; `replay` alone, a chaos script from standard input.
  if lines.first == "replay", lines.dropFirst().contains(where: { !$0.hasPrefix("--") }) { runReplay(Array(lines.dropFirst())) }
  if lines.first == "film" { runFilm(Array(lines.dropFirst())) }
  if lines.first == "stage-judge" { runStageJudge(Array(lines.dropFirst())) }
  if let code = runChaosMode(lines) { exit(code) }
  if lines.first == "sweep" { exit(runSweep(Array(lines.dropFirst()))) }
  if let code = runWalkMode(lines) { exit(code) }
  let launch = LaunchOptions(taking: &lines)
  let firstLaunch = FirstLaunch(taking: &lines)
  if lines.isEmpty, launch?.audit != true {
    while let line = readLine() { lines.append(line) }
  }

  var harness = firstLaunch?.harness ?? launch?.harness() ?? Harness()
  // A first launch has begun already, and starts when the permission arrives.
  begin(harness, starting: firstLaunch == nil)
  // As the app does in its launch: what `doctor` finds wrong goes into the log, whoever asked or did not, and so do the shortcuts skipped.
  if launch != nil {
    harness.controller.logSkippedBindings()
    harness.controller.logSetupProblems()
  }
  var printLayout = true
  var lastCommandOK = true
  var lastReply = ""
  var failedExpectations = 0
  /// The last command, if it failed and no `expect fail` has answered for it yet.
  var unexpectedFailure: String?
  var unexpectedFailures = 0
  /// The windows the last line moved twice, for which no `expect jolt` has answered yet.
  var unexpectedJolts: [Jolt] = harness.jolts.filter { !$0.whileLearning }
  for jolt in unexpectedJolts { print("moved twice at the start: \(jolt)") }
  var jolts = 0
  func settleFailure() {
    for jolt in unexpectedJolts {
      jolts += 1
      print("MOVED TWICE: \(jolt) (a known fault is answered for with `expect jolt \(jolt.window.rawValue)`)\n")
    }
    unexpectedJolts = []
    guard let line = unexpectedFailure else { return }
    unexpectedFailure = nil
    unexpectedFailures += 1
    print("COMMAND FAILED: `\(line)` (follow it with `expect fail` if it is meant to)\n")
  }
  var printTransitions = false
  var rehearsedStage: RehearsedStage?
  var watcher = SimulatedWatcher(harness: harness)
  var staleLayouts = 0
  var linesPrinted = 0
  var hasQuit = false
  /// Who hears of the windows once the next process has started: not the controller itself, or a trace would record no event.
  var whoHears: (any WindowSystemEvents)?
  var minimapsPrinted = 0

  for rawLine in lines {
    let line = rawLine.trimmingCharacters(in: .whitespaces)
    if line.isEmpty || line.hasPrefix("#") { continue }
    let words = line.split(separator: " ").map(String.init)
    if words[0] != "expect" { settleFailure() }
    print("> \(line)")
    // The last line printed says where a crash or a hang was.
    if launch != nil { fflush(nil) }
    if words[0] == "expect" {
      if words.count == 2, words[1].lowercased() == "fail" { unexpectedFailure = nil }
      // `expect jolt <id>` answers for a fault that is known and on the board. It fails once the fault is mended.
      if words.count == 3, words[1].lowercased() == "jolt", let id = WindowID(word: words[2]) {
        unexpectedJolts.removeAll { $0.window == id }
      }
      // Expectations check the previous command; they do not count as one.
      if let problem = ScenarioExpectation.check(
        Array(words.dropFirst()), harness: harness, lastCommandOK: lastCommandOK, lastReply: lastReply)
      {
        failedExpectations += 1
        print("EXPECTATION FAILED: \(problem)")
      } else {
        print("ok")
      }
      print("")
      continue
    }
    if words[0] == "transitions" {
      printTransitions.toggle()
      print("transition printing \(printTransitions ? "on" : "off")\n")
      // This is the line before now, for the expectations that look at it.
      harness.beginStep()
      lastReply = ""
      continue
    }
    if words[0] == "rehearse-stage" {
      rehearsedStage = rehearsedStage ?? RehearsedStage(recorder: harness.recorder, scheduler: harness.scheduler, overlays: harness.overlays)
      continue
    }
    harness.overlays.clearTransitions()
    if words[0] == "watch", case .watch(let options)? = try? Command.parse(words: words) {
      harness.beginStep()
      lastReply = ""
      watcher.watch(options)
      watcher.printLines()
      print("")
      continue
    }
    if firstLaunch == nil, words == ["relaunch"] || words == ["relaunch", "quit"] {
      // As the app does: `quit` is answered, then the app ends, which shuts the controller down. Then somebody starts Arbor.
      _ = harness.run("quit")
      harness.controller.shutdown()
      watcher.printLines()
      // The process is gone, its timers with it. The next one is not started yet, and nobody hears what happens to the windows meanwhile.
      harness = successor(of: harness)
      (whoHears, harness.system.events) = (harness.system.events, nil)
      hasQuit = true
    }
    let startsAgain = hasQuit && (words == ["relaunch"] || words == ["relaunch", "start"])
    if startsAgain {
      hasQuit = false
      // The step that is judged is the start (`begin`): the quit before it is an act of its own.
      (harness.system.events, whoHears) = (whoHears, nil)
      begin(harness)
      watcher = SimulatedWatcher(harness: harness)
      // The new process has stages of its own.
      if rehearsedStage != nil {
        rehearsedStage = RehearsedStage(recorder: harness.recorder, scheduler: harness.scheduler, overlays: harness.overlays)
      }
      (linesPrinted, minimapsPrinted) = (0, 0)
    } else {
      harness.beginStep()
    }
    // A number that is no window's is a slip in the script: nothing happens, and `simulate` says so.
    if words[0] == "crash", firstLaunch == nil, words.dropFirst().allSatisfy({ WindowID(word: $0).map { harness.system.windows[$0] != nil } ?? false }) {
      harness = relaunched(harness) { system in
        reopened = words.dropFirst().compactMap { WindowID(word: $0) }.compactMap { old in system.renumber(old).map { (old, $0) } }
      }
      watcher = SimulatedWatcher(harness: harness)
      (linesPrinted, minimapsPrinted) = (0, 0)
    }
    var (message, ok) = firstLaunch?.simulate(words) ?? simulate(words, harness: harness, printLayout: &printLayout)
    if words == ["relaunch", "start"], !startsAgain { (message, ok) = ("Arbor has not been quit with `relaunch quit`", false) }
    // macOS reports the focus changes Arbor asked for back to it.
    harness.system.deliverEchoes()
    // What Arbor puts off only until the command or event is over (raising pinned windows) happens now.
    harness.scheduler.advance(by: 0)
    lastCommandOK = ok
    lastReply = message
    if !ok { unexpectedFailure = line }
    print(message)
    for said in harness.overlays.messages.dropFirst(linesPrinted) { print("on screen: \(said.model.line)") }
    linesPrinted = harness.overlays.messages.count
    // Whatever the line did, a display whose arrangement or view changed has been laid out, or will be by a timer.
    // Not while macOS has displays that Arbor has not been told of (`quietly`): it cannot have laid them out.
    if harness.controller.isRunning, !harness.scheduler.pendingKeys.contains(where: { $0.hasPrefix("space-") }),
      harness.controller.displays == harness.system.displayList
    {
      for problem in harness.staleLayouts() {
        staleLayouts += 1
        print("LAYOUT OUT OF DATE: \(problem)")
      }
    }
    // Whatever the line did, each window went straight to where it ended up, unless an app's answer taught Arbor better.
    unexpectedJolts = harness.jolts.filter { !$0.whileLearning }
    for jolt in unexpectedJolts { print("moved twice: \(jolt)") }
    for shown in harness.overlays.minimapHistory.dropFirst(minimapsPrinted) {
      print("minimap: \(shown.model?.line ?? "gone")")
    }
    minimapsPrinted = harness.overlays.minimapHistory.count
    if printTransitions {
      for transition in harness.overlays.transitions { print(transition) }
    }
    watcher.printLines()
    firstLaunch?.aSecondPasses()
    if printLayout, !["quiet", "loud", "help", "state", "ascii", "settings", "get", "spaces", "scene"].contains(words[0]) {
      print(harness.ascii(columns: 64, rows: 16))
    }
    print("")
  }

  settleFailure()
  if failedExpectations > 0 { print("\(failedExpectations) expectation(s) failed") }
  if unexpectedFailures > 0 { print("\(unexpectedFailures) command(s) failed") }
  if staleLayouts > 0 { print("\(staleLayouts) time(s) a display was not laid out again") }
  if jolts > 0 { print("\(jolts) time(s) a window was moved twice where once would have done") }
  // On damaged files half the script fails, and is meant to. Whoever reads the output looks for the rest.
  if launch != nil { exit(failedExpectations + jolts > 0 ? 1 : 0) }
  if failedExpectations + unexpectedFailures + staleLayouts + jolts > 0 { exit(1) }
}

/// Starts a harness as every run of the simulator's Arbor starts.
@MainActor
func begin(_ harness: Harness, starting: Bool = true) {
  // The clock is the script's: an hour of `wait` is no reason to stop.
  harness.recorder.limits.seconds = .infinity
  harness.recorder.openSink = TraceRecorder.openFile
  guard starting else { return }
  harness.watchAccessibility()
  harness.beginStep()
  // After `revoke`, a `relaunch` is a start without the permission.
  harness.launch()
}

/// The new process of `relaunch` and `crash`, not started yet. It uses the settings file the old one used (`settings-file`).
/// `meanwhile` is what happens to the windows while no Arbor runs.
@MainActor
func successor(of old: Harness, meanwhile: (FakeWindowSystem) -> Void = { _ in }) -> Harness {
  let new = old.newProcess()
  meanwhile(new.system)
  new.controller.saveSettings = old.controller.saveSettings
  new.controller.loadSettings = old.controller.loadSettings
  new.controller.replaceSettingsFile = old.controller.replaceSettingsFile
  new.controller.keepCopyOfSettingsFile = old.controller.keepCopyOfSettingsFile
  return new
}

/// The same, started.
@MainActor
func relaunched(_ old: Harness, meanwhile: (FakeWindowSystem) -> Void = { _ in }) -> Harness {
  let new = successor(of: old, meanwhile: meanwhile)
  begin(new)
  return new
}

/// `watch` in the simulator: the real `EventFeed`, with standard output in place of a socket.
@MainActor
final class SimulatedWatcher {
  private let harness: Harness
  private let feed: EventFeed
  private var subscription: Int?
  private var lines: [String] = []

  init(harness: Harness) {
    self.harness = harness
    feed = EventFeed(controller: harness.controller)
  }

  func watch(_ options: WatchOptions) {
    if let subscription { feed.unsubscribe(subscription) }
    subscription = feed.subscribe(options) { [weak self] line in self?.lines.append(line) }
  }

  /// Lets the main loop come round, which is when the feed sends, and prints what it sent.
  func printLines() {
    guard subscription != nil else { return }
    harness.scheduler.advance(by: 0)
    for line in lines { print(line) }
    lines.removeAll()
  }
}

/// Runs one line and returns what to print and whether it succeeded.
@MainActor
func simulate(_ words: [String], harness: Harness, printLayout: inout Bool) -> (String, Bool) {
  if let done = simulateDisplays(words, harness: harness) { return done }
  let system = harness.system
  func window(_ index: Int) -> WindowID? { words.count > index ? WindowID(word: words[index]) : nil }
  /// Bounded like the numbers in commands: real windows and pointers are never at infinity.
  func bounded(_ text: some StringProtocol) -> Double? { Double(text).flatMap { abs($0) <= 1_000_000 ? $0 : nil } }
  func number(_ index: Int) -> Double? { words.count > index ? bounded(words[index]) : nil }
  func size(_ text: String) -> CGSize? {
    let parts = text.lowercased().split(separator: "x").compactMap(bounded)
    return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
  }
  func usage(_ text: String) -> (String, Bool) { ("usage: \(text)", false) }
  /// `<WxH> [down] [margin WxH]`, and the index of the word after it.
  func cellWords(from first: Int) -> (cell: CGSize, down: Bool, margin: CGSize, next: Int)? {
    guard words.count > first, let cell = size(words[first]), cell.width >= 0, cell.height >= 0 else { return nil }
    var (down, margin, next) = (false, CGSize.zero, first + 1)
    if words.count > next, words[next] == "down" { (down, next) = (true, next + 1) }
    if words.count > next + 1, words[next] == "margin", let parsed = size(words[next + 1]) { (margin, next) = (parsed, next + 2) }
    return (cell, down, margin, next)
  }

  switch words[0] {
  case "open":
    let app = words.count > 1 ? words[1] : "App"
    var frame = CGRect(x: 300, y: 200, width: 640, height: 420)
    var minimum = CGSize.zero
    var isResizable = true
    var cells: (cell: CGSize, down: Bool, margin: CGSize)?
    var index = 2
    while index < words.count {
      if words[index] == "min", index + 1 < words.count, let parsed = size(words[index + 1]) {
        minimum = parsed
        index += 2
      } else if words[index] == "cell", let parsed = cellWords(from: index + 1) {
        cells = (parsed.cell, parsed.down, parsed.margin)
        index = parsed.next
      } else if words[index] == "fixed" {
        isResizable = false
        index += 1
      } else if words[index] == "at", let x = number(index + 1), let y = number(index + 2) {
        frame.origin = CGPoint(x: x, y: y)
        index += 3
      } else if let parsed = size(words[index]) {
        frame.size = parsed
        index += 1
      } else {
        index += 1
      }
    }
    let id = system.open(
      app: app, pid: pid(ofApp: app), frame: frame, minimumSize: minimum, isResizable: isResizable,
      sizeStep: cells.flatMap { $0.cell.width >= 1 && $0.cell.height >= 1 ? $0.cell : nil }, stepsRoundDown: cells?.down ?? false,
      sizeMargin: cells?.margin ?? .zero)
    return ("opened \(id.rawValue) (\(app))", true)
  case "close":
    guard let id = window(1) else { return usage("close <id>") }
    // With a window in full screen its Space goes, and macOS shows the one it came from.
    let display = harness.controller.workspaceID(containing: id)
    let comeBack =
      system.windows[id]?.snapshot.isFullScreen != true
      ? []
      : system.windows.keys.sorted().filter {
        $0 != id && harness.controller.workspaceID(containing: $0) == display
          && system.windows[$0]?.snapshot.isFullScreen == false
      }
    system.clearSightings()
    system.close(id)
    guard !comeBack.isEmpty else { return ("closed \(id.rawValue)", true) }
    for other in comeBack { system.setOnActiveSpace(other, true) }
    harness.scheduler.advance(by: 2)
    let moves = comeBack.map { "\($0.rawValue) \(system.sightings(of: $0).count)×" }.joined(separator: ", ")
    return ("closed \(id.rawValue) in full screen; seen to move when their Space came back: \(moves)", true)
  case "minimize", "restore":
    guard let id = window(1) else { return usage("\(words[0]) <id>") }
    system.setMinimized(id, words[0] == "minimize")
    return ("\(words[0])d \(id.rawValue)", true)
  case "focus" where window(1) != nil:
    // With anything but a window id (`focus left`, `focus next`) it is Arbor's own command, below.
    guard let id = window(1) else { return usage("focus <id>") }
    system.userFocus(id)
    return ("focused \(id.rawValue)", true)
  case "cursor":
    guard let x = number(1), let y = number(2) else { return usage("cursor <x> <y>") }
    system.cursor = CGPoint(x: x, y: y)
    return ("pointer at \(Int(x)),\(Int(y))", true)
  case "drag":
    let extras = Set(words.dropFirst(4))
    guard let id = window(1), let x = number(2), let y = number(3), let start = system.frame(of: id),
      extras.isSubset(of: ["quick", "cmd"])
    else { return usage("drag <id> <x> <y> [quick] [cmd]") }
    let grab = CGPoint(x: start.midX, y: start.minY + 10)
    let end = CGPoint(x: x, y: y)
    let middle = CGPoint(x: (grab.x + end.x) / 2, y: (grab.y + end.y) / 2)
    system.heldModifiers = extras.contains("cmd") ? .command : []
    if extras.contains("quick") {
      system.drag(id, through: [grab, middle, end], holding: 0)
    } else {
      system.drag(id, through: [grab, middle, end])
    }
    system.heldModifiers = []
    return ("dragged \(id.rawValue) to \(Int(x)),\(Int(y))", true)
  case "mac-tiling":
    guard words.count == 2, words[1] == "on" || words[1] == "off" else { return usage("mac-tiling on|off") }
    system.tiling = words[1] == "on" ? .on : .off
    return ("macOS’s own tiling is \(words[1])", true)
  case "move":
    guard let id = window(1), let x = number(2), let y = number(3), let w = number(4), let h = number(5) else {
      return usage("move <id> <x> <y> <w> <h>")
    }
    system.userMove(id, to: CGRect(x: x, y: y, width: w, height: h))
    return ("moved \(id.rawValue)", true)
  case "pull":
    let text = "pull <id> <edge> <points> [<edge> <points>] (positive grows the window)"
    guard let id = window(1), var frame = system.frame(of: id), words.count >= 4, words.count % 2 == 0 else {
      return usage(text)
    }
    for index in stride(from: 2, to: words.count, by: 2) {
      guard let edge = Edge(word: words[index]), let points = number(index + 1).map({ CGFloat($0) }) else {
        return usage(text)
      }
      switch edge {
      case .left:
        frame.origin.x -= points
        frame.size.width += points
      case .right:
        frame.size.width += points
      case .top:
        frame.origin.y -= points
        frame.size.height += points
      case .bottom:
        frame.size.height += points
      }
    }
    system.userResize(id, to: frame)
    return ("pulled the edges of \(id.rawValue)", true)
  case "seam":
    guard let index = number(1).map(Int.init), let delta = number(2),
      let seams = harness.overlays.seams[harness.display], seams.indices.contains(index)
    else { return usage("seam <index> <delta> (see the seams in `state`)") }
    harness.overlays.dragSeam(seams[index], by: CGFloat(delta))
    return ("dragged seam \(index) by \(Int(delta))", true)
  case "tile":
    guard words.count > 1, let node = NodeID(word: words[1]) else { return usage("tile <node>") }
    harness.overlays.clickTile(node)
    return ("clicked tile \(node)", true)
  case "flush":
    harness.scheduler.runPending()
    return ("ran pending work", true)
  case "quiet":
    printLayout = false
    return ("layout printing off", true)
  case "loud":
    printLayout = true
    return ("layout printing on", true)
  case "title":
    guard let id = window(1), words.count >= 3, system.frame(of: id) != nil else {
      return usage("title <id> <text>")
    }
    system.setTitle(id, words.dropFirst(2).joined(separator: " "))
    return ("retitled \(id.rawValue)", true)
  case "settings-file":
    guard words.count >= 2 else { return usage("settings-file <path to a settings.json>") }
    let file = URL(fileURLWithPath: words.dropFirst().joined(separator: " "))
    harness.controller.saveSettings = { try SettingsFile.update(from: $0, to: $1, at: file) }
    harness.controller.loadSettings = { try SettingsFile.read(from: file) }
    harness.controller.replaceSettingsFile = { try SettingsFile.replace(with: $0, at: file) }
    harness.controller.keepCopyOfSettingsFile = { try SettingsFile.keepCopy(of: file) }
    let result = harness.run("reload-settings")
    return ((result.ok ? "" : "error: ") + result.message, result.ok)
  case "hide", "unhide":
    guard words.count > 1 else { return usage("\(words[0]) <App>") }
    system.setHidden(pid: pid(ofApp: words[1]), words[0] == "hide")
    return ("\(words[0] == "hide" ? "hid" : "showed") \(words[1])", true)
  case "background-focus":
    guard let id = window(1) else { return usage("background-focus <id>") }
    system.backgroundFocus(id)
    return ("\(id.rawValue) became its app's focused window, in the background", true)
  // `displays` on its own is Arbor's query (the displays and the options in effect on each).
  case "displays" where words.count > 1:
    guard let count = Int(words[1]), (0...2).contains(count), words.count == 2 || words.dropFirst(2) == ["below"] else {
      return usage("displays <0|1|2> [below]")
    }
    var list = Array(simulatedDisplays.prefix(count))
    if words.count == 3, count == 2 {
      let corner = CGPoint(x: list[0].frame.minX, y: list[0].frame.maxY)
      (list[1].frame.origin, list[1].visibleFrame.origin) = (corner, corner)
    }
    system.setDisplays(list)
    return ("\(count) display(s)", true)
  case "macos":
    // What `doctor` and the welcome window are told about this Mac. Until this line: nothing ("unknown here").
    guard words.count == 2, ["defaults", "tidy"].contains(words[1]) else { return usage("macos defaults|tidy") }
    let switches = words[1] == "defaults" ? MacSwitch.inTheWay(macOS: 26) { _ in nil } : []
    harness.controller.systemFacts = { [system] in
      SystemFacts(
        accessibility: !system.isDenied, screenRecording: false, switches: switches, eventTaps: ["pinch", "scroll", "rectangle"])
    }
    return (words[1] == "defaults" ? "macOS is set as it comes" : "none of macOS's switches is in Arbor's way", true)
  case "pick-up":
    guard let id = window(1), let x = number(2), let y = number(3), system.frame(of: id) != nil, system.dragging == nil else {
      return usage("pick-up <id> <x> <y>")
    }
    system.beginDrag(id)
    system.moveDrag(to: CGPoint(x: x, y: y), holding: 0.5)
    return ("\(id.rawValue) is in the hand at \(Int(x)),\(Int(y))", true)
  case "let-go":
    guard let id = system.dragging else { return ("error: nothing is in the hand", false) }
    system.endDrag()
    return ("let go of \(id.rawValue)", true)
  case "shove":
    let text = "shove <id> <x> <y> [then <x> <y>]"
    guard let id = window(1), let x = number(2), let y = number(3), let size = system.frame(of: id)?.size,
      words.count == 4 || (words.count == 7 && words[4] == "then")
    else { return usage(text) }
    _ = system.setFrame(CGRect(origin: CGPoint(x: x, y: y), size: size), of: id)
    if words.count == 7 {
      guard let x = number(5), let y = number(6) else { return usage(text) }
      _ = system.setFrame(CGRect(origin: CGPoint(x: x, y: y), size: size), of: id)
    }
    return ("\(id.rawValue) was moved the way Arbor moves windows", true)
  case "macos-moves":
    guard let id = window(1), let x = number(2), let y = number(3), let size = system.frame(of: id)?.size else {
      return usage("macos-moves <id> <x> <y>")
    }
    system.moveSilently(id, to: CGRect(origin: CGPoint(x: x, y: y), size: size))
    // Said, so that a trace has it: a replay answers `allWindows` from the events it has played, not from what was recorded.
    system.report(id, userInitiated: false)
    return ("macOS moved \(id.rawValue)", true)
  case "health":
    return (health(of: harness), true)
  case "quit-check":
    return (quitCheck(harness), true)
  case "save-state":
    guard words.count > 1 else { return usage("save-state <file>") }
    return saveState(of: harness, to: words[1])
  case "relaunch" where words.count == 1:
    // The loop has done it: this is the new process.
    return harness.controller.accessibilityGranted
      ? ("quit, and started again", harness.controller.isRunning) : ("quit, and started again: \(harness.run("status").message)", true)
  case "crash":
    // The loop has done it: this is the new process.
    guard let windows = reopened else { return usage("crash [<id>…]: windows that are open") }
    reopened = nil
    return ((["died, and started again"] + windows.map { "\($0.old) is \($0.new) now" }).joined(separator: "; "), harness.controller.isRunning)
  case "relaunch" where words == ["relaunch", "quit"]:
    return ("quit", !harness.controller.isRunning)
  case "relaunch" where words == ["relaunch", "start"]:
    return ("started", harness.controller.isRunning)
  case "revoke":
    harness.revokeAccessibility()
    return ("Accessibility permission taken away", true)
  case "grant":
    harness.grantAccessibility()
    return ("Accessibility permission granted", true)
  case "display-size":
    guard words.count > 1, let size = size(words[1]), size.width >= 640, size.height >= 400 else {
      return usage("display-size <WxH> [<menu bar height>]")
    }
    let bar = words.count > 2 ? Double(words[2]).map { CGFloat($0) } ?? 25 : 25
    system.setDisplays([
      DisplaySnapshot(
        id: FakeWindowSystem.standardDisplay.id, frame: CGRect(origin: .zero, size: size),
        visibleFrame: CGRect(x: 0, y: bar, width: size.width, height: size.height - bar), isMain: true)
    ])
    return ("the main display is \(words[1])", true)
  case "min":
    guard let id = window(1), words.count > 2, let minimum = size(words[2]) else { return usage("min <id> <WxH>") }
    system.setMinimumSize(id, minimum)
    return ("\(id.rawValue) refuses to be smaller than \(words[2])", true)
  case "cell":
    guard let id = window(1), let parsed = cellWords(from: 2), parsed.next == words.count else {
      return usage("cell <id> <WxH> [down] [margin WxH]")
    }
    guard system.windows[id] != nil else { return ("error: there is no window \(id.rawValue)", false) }
    let none = parsed.cell.width < 1 || parsed.cell.height < 1
    system.setSizeStep(id, none ? nil : parsed.cell, down: parsed.down, margin: parsed.margin)
    return (none ? "\(id.rawValue) takes any size" : "\(id.rawValue) comes in cells of \(words[2])", true)
  case "wait":
    guard words.count > 1, let seconds = Double(words[1]), seconds >= 0, seconds <= 1_000_000 else {
      return usage("wait <seconds>")
    }
    harness.scheduler.advance(by: seconds)
    return ("\(words[1]) s later", true)
  case "keyboard":
    guard words.count == 2, let layout = SampleKeyLayouts.byName[words[1].lowercased()] else {
      return usage("keyboard \(SampleKeyLayouts.byName.keys.sorted().joined(separator: "|"))")
    }
    harness.controller.keyboardLayoutChanged(layout)
    return ("keyboard layout: \(layout.name)", true)
  case "fullscreen":
    guard let id = window(1), words.count == 3 || Array(words.dropFirst(2)) == ["off", "where-it-was"],
      ["on", "off"].contains(words[2])
    else {
      return usage("fullscreen <id> on|off [where-it-was]")
    }
    guard system.windows[id] != nil else { return ("error: there is no window \(id.rawValue)", false) }
    let on = words[2] == "on"
    // Each display has Spaces of its own. Asked before the window moves: in full screen it covers its display.
    // A window Arbor does not arrange is in no workspace, and on a display all the same.
    let frame = system.windows[id]!.snapshot.frame
    let display =
      harness.controller.workspaceID(containing: id)
      ?? system.displayList.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }?.id
    let others = system.windows.keys.sorted().filter {
      $0 != id && harness.controller.workspaceID(containing: $0) == display
    }
    let onItsSpace = others.filter { system.windows[$0]?.snapshot.isFullScreen == false }
    // In the order and at the times of a Mac, where the others are in sight on the way in, and the window is seen before it is reported back.
    system.clearSightings()
    if on {
      system.enterFullScreen(id, leaving: onItsSpace)
    } else {
      system.leaveFullScreen(id, with: onItsSpace, whereItWas: words.count == 4)
    }
    // macOS reports each window by itself; Arbor lays out once they have all been heard of.
    harness.scheduler.advance(by: 2)
    let seen = system.sightings(of: id).map { "\(Int($0.minX)),\(Int($0.minY)) \(Int($0.width))×\(Int($0.height))" }
    let sighted = on || seen.isEmpty ? "" : " and was seen at \(seen.joined(separator: ", then at "))"
    let movers = Set(system.sightings.map(\.window.rawValue)).subtracting([id.rawValue]).sorted()
    let moved = movers.isEmpty ? "" : "; seen to move meanwhile: \(movers.map(String.init).joined(separator: ", "))"
    return ("\(id.rawValue) \(on ? "went into" : "left") full screen\(sighted)\(moved)", true)
  case "field-type":
    guard let prompt = harness.overlays.namePrompt else { return ("the name field is not open", false) }
    let text = words.dropFirst().joined(separator: " ")
    guard let result = harness.overlays.submitName(text) else { return (prompt.answer(to: text).note, false) }
    return ((result.ok ? "" : "error: ") + result.message, result.ok)
  case "field-cancel":
    guard harness.overlays.namePrompt != nil else { return ("the name field is not open", false) }
    harness.overlays.cancelName()
    return ("pressed ⎋", true)
  case "comes-forward":
    guard let id = window(1) else { return usage("comes-forward <id>") }
    system.comesForward(id)
    return ("\(id.rawValue) came forward by itself", true)
  case "hold-still-for":
    guard words.count > 1 else { return usage("hold-still-for <bundle id> [title words…]") }
    var settings = harness.controller.settings
    settings.holdStillFor.append(words.dropFirst().joined(separator: " "))
    harness.controller.apply(settings: settings)
    return ("holding still for \(settings.holdStillFor.count) kind(s) of window", true)
  case "finder-type", "finder-move", "finder-choose", "finder-tick", "finder-cancel":
    let overlays = harness.overlays
    guard overlays.finder != nil else { return ("error: Go to… is not open; `find` opens it", false) }
    switch words[0] {
    case "finder-type":
      overlays.typeInFinder(words.dropFirst().joined(separator: " "))
    case "finder-move":
      guard let rows = words.count > 1 ? Int(words[1]) : nil else { return usage("finder-move <rows>") }
      overlays.moveFinderSelection(by: rows)
    case "finder-choose":
      let row = words.count > 1 ? Int(words[1]) : nil
      guard words.count == 1 || row != nil else { return usage("finder-choose [n]") }
      guard overlays.chooseInFinder(row: row) else { return ("error: nothing to choose there", false) }
    case "finder-tick":
      let row = words.count > 1 ? Int(words[1]) : nil
      guard words.count == 1 || row != nil else { return usage("finder-tick [n]") }
      guard overlays.tickInFinder(row: row) else {
        return ("error: \(overlays.finder?.message ?? "nothing to tick there")", false)
      }
    default:
      overlays.dismissFinder()
    }
    return (overlays.finder?.text ?? "Go to… closed", true)
  case "display":
    let text = "display <match> <key> <value>, e.g. display main gap 30 (then `displays` shows what is in effect)"
    guard words.count == 4, let value = Double(words[3]) else { return usage(text) }
    // Through settings.json's own reader, so that what it refuses is refused here, for the same reason.
    let list: [String: Any] = ["displays": [["match": words[1], words[2]: value]]]
    guard let data = try? JSONSerialization.data(withJSONObject: list),
      let read = try? JSONDecoder().decode(Settings.self, from: data)
    else { return usage(text) }
    guard let entry = read.displays.first, !entry.keysSet.isEmpty else {
      return ("error: \(read.skippedDisplays.first ?? "`\(words[2])` is not a key that can differ from display to display")", false)
    }
    var settings = harness.controller.settings
    settings.displays.append(entry)
    harness.controller.apply(settings: settings)
    return ("entry \(settings.displays.count): \(entry.match) sets \(words[2]) to \(words[3])", true)
  case "scene":
    return (describe(harness.overlays.scenes[harness.display] ?? OverlayScene()), true)
  case "map":
    guard words.count == 2 else { return usage("map <id>|desktop|beside") }
    guard let model = harness.overlays.minimaps[harness.display] else { return ("error: no minimap is showing", false) }
    guard model.takesClicks else { return ("error: the click goes through: nobody asked for this minimap", false) }
    let spot: CGPoint?
    switch words[1].lowercased() {
    case "desktop": spot = model.desktop?.center
    case "beside": spot = CGPoint(x: 1, y: 1)
    default: spot = window(1).flatMap { id in model.items.first { $0.window == id }?.frame.center }
    }
    guard let spot else { return ("error: \(words[1]) is not on the minimap", false) }
    harness.overlays.clickMinimap(at: spot)
    return ("clicked \(words[1]) in the minimap", true)
  default:
    if let outcome = simulateHands(words, harness: harness) { return outcome }
    let result = harness.run(words.joined(separator: " "))
    if words[0] == "find", result.ok, let finder = harness.overlays.finder { return (finder.text, true) }
    if let text = result.text { return (text, result.ok) }
    if let state = result.state {
      return (describe(state), result.ok)
    }
    return ((result.ok ? "" : "error: ") + result.message, result.ok)
  }
}

/// Every app name gets a process of its own, so `hide` hides one app's windows.
func pid(ofApp app: String) -> Int32 {
  Int32(2000 + app.lowercased().unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) % 10_000 })
}

func describe(_ state: StateSnapshot) -> String {
  var lines: [String] = []
  for display in state.displays {
    lines.append("display \(display.id): camera \(display.camera), floating \(display.floating.map(\.rawValue))")
    for window in display.floating {
      if let host = state.window(window)?.guestOf { lines.append("  \(window.rawValue) is a guest of \(host)") }
    }
    for window in state.windows where window.letBe && !window.parked && window.display == display.id {
      lines.append("  \(window.id.rawValue) is let be where it stands")
    }
    for id in display.tree.preorder() {
      guard let node = display.tree[id] else { continue }
      let indent = String(repeating: "  ", count: display.tree.depth(of: id) + 1)
      let name = display.names?.first { $0.value == id }.map { " \"\($0.key)\"" } ?? ""
      switch node.kind {
      case .split(let axis, _):
        let kept = node.keeps.map { " kept for \($0)" } ?? ""
        lines.append("\(indent)\(id) split \(axis.rawValue) w=\(node.weight)\(kept)\(name)")
      case .stack(let windows, let active):
        lines.append("\(indent)\(id) stack \(windows.map(\.rawValue)) active=\(active) w=\(node.weight)\(name)")
      case .desktop: lines.append("\(indent)\(id) desktop w=\(node.weight)\(name)")
      }
    }
  }
  return lines.joined(separator: "\n")
}

func describe(_ scene: OverlayScene) -> String {
  func text(_ value: CGFloat) -> String {
    value == value.rounded() && abs(value) < 1_000_000 ? String(Int(value)) : "\(value)"
  }
  func text(_ rect: CGRect) -> String {
    "\(text(rect.minX)),\(text(rect.minY)) \(text(rect.width))x\(text(rect.height))"
  }
  var lines: [String] = []
  if let backdrop = scene.backdrop {
    lines.append(
      "backdrop: dim \(backdrop.dim), blur \(backdrop.blur), tint \(backdrop.tint), reaching \(text(backdrop.growth)) beyond the slots")
    lines += backdrop.rects.map { "  \(text($0))" }
    if let desktop = backdrop.desktop { lines.append("  a line of \(backdrop.desktopEdge) around the Desktop, \(text(desktop))") }
  } else {
    lines.append("backdrop: none")
  }
  lines.append("tiles: \(scene.tiles.count), fading for \(scene.tileFade) s")
  for tile in scene.tiles {
    let colour = tile.usesAppColour ? "app colour \(tile.colourAmount)" : "grey"
    lines.append("  \(tile.node) \(tile.kind.rawValue) \(text(tile.frame)) \"\(tile.title)\": \(tile.style.rawValue), \(colour)")
  }
  lines.append("seams: \(scene.seams.count), handles \(scene.showsSeamHandles ? "shown under the pointer" : "never shown")")
  return lines.joined(separator: "\n")
}

MainActor.assumeIsolated {
  runSimulation()
}
