import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation

// arbor-sim launch [--state <file>] [--settings <file>] [--windows <n>] [--displays <0|1|2>] [--audit] [lines…]
//
// Starts Arbor the way the app starts: on a state.json and a settings.json that are really on disk, read by the code
// the app reads them with (`FileStateStore`, `SettingsFile`), so that a file is also set aside, or copied before a
// repair, as it would be. <n> windows are open already (101, 102, …: Safari, Notes, Mail, Music, Maps, Photos,
// Books, and round again). Then the lines run as in any script.
//
// It is made for `scripts/fuzz-launch.py` (docs/TESTING.md, "Launch fuzzing"), which damages the files in one place
// after another and starts a process on each: whatever the files say, Arbor must start, work, and quit with every
// window in view. So here a command that fails is nothing to exit over (half of them name windows that a damaged file
// no longer has), and each line is flushed before it runs: the last one printed says where a crash or a hang was.
//
// With --audit nothing is started. What was read is printed as it would be saved again, after what was noted:
//   STATE read | refused
//   NOTES <n> <the first few>
//   COPY <file name> | -
//   SAVED <json>
//
// Words that only make sense here, though they work in every script:
//   health              HEALTH ok, or HEALTH and what is wrong: a rule of the controller's bookkeeping that does not hold
//                       (`Controller.invariantViolations`, the chaos test's; not the rules it knows to be broken),
//                       a frame that is not finite or absurdly far, or what would be saved not reading back as it is
//   quit-check          quit; QUIT ok, or QUIT and the windows that are left out of view
//   save-state <file>   write state.json there, as the app would

struct LaunchOptions {
  var state: URL?
  var settings: URL?
  var windows = 0
  var displays = 1
  var audit = false

  static let usage = "usage: arbor-sim launch [--state <file>] [--settings <file>] [--windows <n>] [--displays <0|1|2>] "
    + "[--audit] [lines…]"
  static let apps = ["Safari", "Notes", "Mail", "Music", "Maps", "Photos", "Books"]

  /// Takes `launch` and its options off the front of `lines`. Nil if the first word is another.
  init?(taking lines: inout [String]) {
    guard lines.first == "launch" else { return nil }
    lines.removeFirst()
    func value() -> String {
      guard lines.count > 1 else {
        print(Self.usage)
        exit(2)
      }
      defer { lines.removeFirst(2) }
      return lines[1]
    }
    while let option = lines.first, option.hasPrefix("--") {
      switch option {
      case "--state": state = URL(fileURLWithPath: value())
      case "--settings": settings = URL(fileURLWithPath: value())
      case "--windows": windows = min(max(Int(value()) ?? 0, 0), 100)
      case "--displays": displays = min(max(Int(value()) ?? 1, 0), 2)
      case "--audit":
        audit = true
        lines.removeFirst()
      default:
        print(Self.usage)
        exit(2)
      }
    }
    if audit, state == nil {
      print(Self.usage)
      exit(2)
    }
  }

  /// Reads the files and opens the windows. The caller starts Arbor.
  @MainActor func harness() -> Harness {
    let settings = settings.map { SettingsFile.load(from: $0) } ?? Settings()
    var saved: PersistedState?
    if let state {
      let store = FileStateStore(url: state)
      saved = store.load()
      print("STATE \(saved == nil ? "refused" : "read")")
      print("NOTES \(store.repairs.count) \(store.repairs.prefix(3).joined(separator: " ;; "))")
      print("COPY \(store.keptCopy ?? "-")")
      fflush(nil)
      if audit {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        if let saved, let data = try? encoder.encode(saved) { print("SAVED " + String(decoding: data, as: UTF8.self)) }
        exit(0)
      }
    }
    let harness = Harness(displays: Array(simulatedDisplays.prefix(displays)), settings: settings, saved: saved)
    for index in 0..<windows { harness.system.open(app: Self.apps[index % Self.apps.count]) }
    return harness
  }
}

/// `displays`, with the main one mirrored if it is now: only `projector off` ends that.
@MainActor func keepingTheProjector(_ displays: [DisplaySnapshot], of system: FakeWindowSystem) -> [DisplaySnapshot] {
  let isMirrored = system.displays().contains(where: \.isMirrored)
  return displays.map { display in
    var display = display
    if display.isMain { display.isMirrored = isMirrored }
    return display
  }
}

/// The main display and the one `displays 2` plugs in to the right of it.
@MainActor let simulatedDisplays = [
  FakeWindowSystem.standardDisplay,
  DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1920, height: 1080), isMain: false, name: "Side Display"),
]

/// What the last `crash` gave new numbers. Nil: there was none, or it has been said.
@MainActor var reopened: [(old: WindowID, new: WindowID)]?

/// `health`: everything that must hold whatever the files said, in one line a script can look for.
@MainActor
func health(of harness: Harness) -> String {
  let timers = harness.scheduler.pendingKeys
  // A Space switch is laid out once all of its reports are in (Controller+Spaces.swift).
  let awaitingLayout = Set(harness.controller.displays.map(\.id).filter { timers.contains("space-" + $0.rawValue) })
  var problems = harness.controller.invariantViolations(awaitingLayout: awaitingLayout)
    .filter { !ChaosRunner.knownRules.contains($0.rule) }.map(\.description)
  harness.controller.saveNow()
  if let state = harness.store.saved {
    // What Arbor writes it must read back as it is. If it needs a repair on the way in, Arbor wrote damage, and
    // the next start tells the person that their arrangement was damaged.
    let notes = DecodingNotes()
    if let data = try? JSONEncoder().encode(state) {
      if PersistedState.read(data, notes: notes) != .loaded(state) || !notes.notes.isEmpty {
        problems.append("what is saved does not read back as it is" + (notes.notes.first.map { ": \($0)" } ?? ""))
      }
    } else {
      problems.append("the state cannot be written")
    }
  }
  for window in harness.system.allWindows() where !isSane(window.frame) {
    problems.append("\(window.id) is at an absurd frame")
  }
  let drawn = harness.overlays.tiles.values.joined().map(\.frame) + harness.overlays.seams.values.joined().map(\.frame)
  if !drawn.allSatisfy(isSane) { problems.append("a tile or a seam is drawn at an absurd frame") }
  if (try? JSONEncoder().encode(harness.run("state"))) == nil {
    problems.append("the reply to `state` cannot be written")
  }
  return problems.isEmpty ? "HEALTH ok" : "HEALTH \(problems.count): " + problems.prefix(3).joined(separator: " ;; ")
}

/// Finite, and nowhere near where sums of coordinates stop being exact.
private func isSane(_ frame: CGRect) -> Bool {
  [frame.minX, frame.minY, frame.width, frame.height].allSatisfy { $0.isFinite && abs($0) < 10_000_000 }
    && frame.width >= 0 && frame.height >= 0
}

/// `quit-check`: after quitting nobody is there to fetch a window.
@MainActor
func quitCheck(_ harness: Harness) -> String {
  harness.controller.shutdown()
  let displays = harness.system.displayList
  let lost = harness.system.allWindows().filter { window in
    window.isPresent && !displays.isEmpty && !displays.contains { window.frame.fractionInside($0.frame) >= 0.5 }
  }
  guard !lost.isEmpty else { return "QUIT ok" }
  return "QUIT \(lost.count) out of view: " + lost.prefix(3).map { "\($0.id)" }.joined(separator: " ")
}

/// `save-state <file>`
@MainActor
func saveState(of harness: Harness, to path: String) -> (String, Bool) {
  harness.controller.saveNow()
  guard let state = harness.store.saved else { return ("there is nothing to save", false) }
  let store = FileStateStore(url: URL(fileURLWithPath: path))
  store.save(state)
  store.flush()
  return ("saved", true)
}
