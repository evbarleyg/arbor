import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Random desks on which apps quit and are opened again. Whatever the arrangement, whichever way the app ends and in whatever
/// order its windows come back: afterwards everybody is exactly where they were, and on the way nobody was moved twice.
@Suite @MainActor struct RelaunchedAppWalkTests {
  struct Random {
    var state: UInt64
    mutating func next(_ bound: Int) -> Int {
      state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
      return Int((state >> 33) % UInt64(bound))
    }
    mutating func pick<T>(_ values: [T]) -> T { values[next(values.count)] }
  }

  static let apps = ["Safari", "Notes", "Mail", "Terminal"]

  /// One desk, and the lines that made it, for whoever has to play it again.
  @MainActor final class Desk {
    let h: Harness
    var script: [String] = []
    var nextPID: Int32 = 3000
    var minimums: [String: CGSize] = [:]

    init(_ random: inout Random) {
      let width = random.pick([1440, 1920, 2560])
      h = Harness(displays: [
        DisplaySnapshot(
          id: FakeWindowSystem.standardDisplay.id, frame: CGRect(x: 0, y: 0, width: width, height: 1100),
          visibleFrame: CGRect(x: 0, y: 25, width: width, height: 1075), isMain: true)
      ])
      script.append("display \(width)")
      for app in RelaunchedAppWalkTests.apps {
        minimums[app] = CGSize(width: random.pick([0, 0, 200, 420, 574]), height: random.pick([0, 100, 300]))
      }
      var opened: [WindowID] = []
      for index in 0..<(3 + random.next(4)) {
        let app = random.pick(RelaunchedAppWalkTests.apps)
        opened.append(open(app, title: "\(app) \(index)", pid: Int32(2000 + RelaunchedAppWalkTests.apps.firstIndex(of: app)!)))
      }
      h.start()
      var docked: [WindowID] = []
      for window in opened where docked.isEmpty || random.next(5) > 0 {
        let edge = random.pick(["left", "right", "top", "bottom"])
        run(docked.isEmpty || random.next(3) == 0 ? "dock \(window.rawValue) \(edge)" : "dock \(window.rawValue) beside \(random.pick(docked).rawValue) \(edge)")
        if h.workspace.isDocked(window) { docked.append(window) }
      }
      if random.next(2) == 0 { run("resize \(random.pick(docked).rawValue) \(random.pick(["left", "right", "top", "bottom"])) \(40 + random.next(120))") }
      run("show-all")
    }

    @discardableResult func open(_ app: String, title: String, pid: Int32) -> WindowID {
      script.append("open \(app) \(title) pid \(pid) min \(Int(minimums[app]!.width))x\(Int(minimums[app]!.height))")
      return h.system.open(
        app: app, title: title, pid: pid, frame: CGRect(x: 200, y: 150, width: 640, height: 420), minimumSize: minimums[app]!)
    }

    func run(_ line: String) {
      script.append(line)
      h.run(line)
      h.scheduler.advance(by: 2)
    }

    var knownMinimums: [String: CGSize] {
      Dictionary(uniqueKeysWithValues: h.controller.minimumSizes.compactMap { window, size in h.controller.windows[window].map { ($0.title, size) } })
    }

    /// Where every docked window is, by title, for its number changes: nil for one that is a tile, since where that lies out of view, and
    /// how large, is nobody's business. And where every space is, the Desktop and the tiles with them: their numbers come back.
    var places: [String: CGRect?] {
      var places = Dictionary(uniqueKeysWithValues: h.workspace.tree.allWindows.map { window in
        (h.controller.windows[window]?.title ?? "\(window)", h.layout!.windowFrames[window].flatMap { _ in h.frame(window) })
      })
      for (node, frame) in h.layout!.nodeFrames { places["\(node)"] = frame }
      return places
    }
  }

  /// An app with a docked window quits and is opened again. Returns what went wrong on the way.
  func thereAndBack(_ desk: Desk, _ random: inout Random, lookingAbout: Bool, meanwhile: () -> Void = {}) -> [String] {
    let h = desk.h
    var problems: [String] = []
    let docked = h.workspace.tree.allWindows.compactMap { h.controller.windows[$0] }
    let app = random.pick(docked)
    var gone = h.system.allWindows().filter { $0.pid == app.pid }
    let knownOfThoseThatWent = desk.knownMinimums
    let windowsFirst = random.next(2) == 0
    desk.script.append("\(windowsFirst ? "quit" : "kill") \(app.appName)")
    h.system.quit(pid: app.pid, windowsFirst: windowsFirst)
    h.scheduler.advance(by: 2)
    if lookingAbout, let other = h.workspace.tree.allWindows.first {
      desk.run("zoom \(other.rawValue)")
      desk.run("show-all")
    }
    meanwhile()
    desk.nextPID += 1
    while !gone.isEmpty {
      let window = gone.remove(at: random.next(gone.count))
      let (mark, view, known) = (h.system.moveLog.count, h.workspace.camera, h.controller.minimumSizes)
      let wasDocked = docked.contains { $0.id == window.id }
      let again = desk.open(window.appName, title: window.title, pid: desk.nextPID)
      h.scheduler.advance(by: 2)
      if wasDocked, !h.workspace.isDocked(again) { problems.append("\(window.title) is not back in its place") }
      // Not where the view moved as well (a window that comes back as a tile and has the keyboard is framed), nor where Arbor
      // learns how small a window goes: it is asked, refuses, and room is made for it (F61).
      guard h.workspace.camera == view, h.controller.minimumSizes.filter({ $0.key != again }) == known,
        h.controller.minimumSizes[again] == knownOfThoseThatWent[window.title]
      else { continue }
      var moves: [WindowID: Int] = [:]
      for move in h.system.moveLog[mark...] where move.before != move.after { moves[move.window, default: 0] += 1 }
      // Docked windows: a window that held the place until the right one came floats again where it opened, as after a login.
      for (moved, times) in moves.sorted(by: { $0.key < $1.key }) where times > 1 && h.workspace.isDocked(moved) {
        problems.append("\(h.controller.windows[moved]?.title ?? "\(moved)") was moved \(times) times when \(window.title) came back")
      }
    }
    desk.run("show-all")
    // To the point: a window that is a point from its place counts as in it, and is not moved for that (`isInPlace`).
    for (window, slot) in h.controller.freshLayout(of: h.display)!.windowFrames.sorted(by: { $0.key < $1.key })
    where h.frame(window)?.approximatelyEquals(slot, tolerance: 1) != true {
      problems.append("\(window) is at \(String(describing: h.frame(window))), and its place is \(slot)")
    }
    problems += h.workspace.tree.invariantViolations()
    problems += h.controller.invariantViolations().map { "\($0)" }
    return problems
  }

  static func same(_ after: [String: CGRect?], _ before: [String: CGRect?]) -> Bool {
    after.keys == before.keys && after.allSatisfy { title, frame in
      guard let frame, let earlier = before[title]! else { return frame == nil && before[title]! == nil }
      return frame.approximatelyEquals(earlier, tolerance: 1)
    }
  }

  @Test(arguments: 0..<8) func thereAndBackIsNothing(block: Int) {
    var compared = 0
    for seed in (block * 40)..<(block * 40 + 40) {
      var random = Random(state: UInt64(seed) &* 2_654_435_761 &+ 17)
      let desk = Desk(&random)
      guard !desk.h.workspace.tree.allWindows.isEmpty else { continue }
      // The first time round Arbor still learns how small the windows go, and makes room it had not made.
      _ = thereAndBack(desk, &random, lookingAbout: false)
      for _ in 0..<3 {
        // What the Desktop is owed it gets as soon as something moves anyway (F61): such a desk is not at rest.
        guard desk.h.workspace.desktopIsOwedRoom == nil else { break }
        // Where not everybody has room, whoever has the keyboard is served first, and an app that was just opened has it.
        guard desk.h.layout!.tiles.isEmpty else { break }
        let (before, known) = (desk.places, desk.knownMinimums)
        let problems = thereAndBack(desk, &random, lookingAbout: random.next(2) == 0)
        #expect(problems == [], "seed \(seed): \(desk.script.joined(separator: " ; "))")
        // With more room for a while, a window that was a tile has shown how small it goes. Room is made on what is known (F61).
        guard desk.knownMinimums == known else { break }
        compared += 1
        let same = Self.same(desk.places, before)
        #expect(same, "seed \(seed): \(desk.script.joined(separator: " ; "))")
        if !problems.isEmpty || !same { break }
      }
    }
    // A net that seldom asks catches little. Of 120 at most, 66 to 90 were compared in each forty desks when this was written.
    #expect(compared >= 40, "\(compared)")
  }

  /// The control: the same walk, and a gap moved by hand while the app is away. The net has to see that, and the app is back all the same.
  @Test func theNetSeesAGapThatWasMovedMeanwhile() {
    var (seen, asked) = (0, 0)
    for seed in 0..<40 {
      var random = Random(state: UInt64(seed) &* 2_654_435_761 &+ 17)
      let desk = Desk(&random)
      guard !desk.h.workspace.tree.allWindows.isEmpty else { continue }
      _ = thereAndBack(desk, &random, lookingAbout: false)
      let before = desk.places
      var moved = false
      let problems = thereAndBack(desk, &random, lookingAbout: false) {
        guard let seam = desk.h.layout?.seams.first else { return }
        let tree = desk.h.workspace.tree
        desk.h.controller.seamDragged(display: desk.h.display, seam: seam, by: 90)
        desk.h.scheduler.advance(by: 2)
        moved = !desk.h.workspace.tree.hasSameArrangement(as: tree)
      }
      guard moved else { continue }
      asked += 1
      #expect(!problems.contains { $0.hasSuffix("is not back in its place") }, "seed \(seed): \(problems)")
      if !Self.same(desk.places, before) { seen += 1 }
    }
    #expect(asked > 10)
    // Not all: where the windows are as small as they go, that decides where the gap is, with the app back as before it went.
    #expect(seen * 4 > asked * 3, "\(seen) of \(asked)")
  }

  /// A net that never asks catches nothing: the chaos lab's ordinary walks quit apps and open them again, and often enough one of
  /// them had a docked window, nothing was rearranged meanwhile, and it goes back to its place.
  @Test func theChaosLabsOrdinaryWalksReachAReturn() {
    var (reopened, returned) = (0, 0)
    for seed in UInt64(1)...40 {
      let runner = ChaosRunner()
      var generator = ChaosGenerator(seed: seed, ordinary: true)
      var titlesThatWent: Set<String> = []
      for _ in 0..<200 {
        let action = generator.next(runner)
        if case .quitApp(let pid) = action {
          titlesThatWent.formUnion(runner.system.windows.values.filter { $0.snapshot.pid == pid }.map(\.snapshot.title))
        }
        _ = runner.step(action)
        guard case .open(let new) = action, let title = new.title, titlesThatWent.remove(title) != nil else { continue }
        reopened += 1
        if runner.controller.workspaces.values.contains(where: { $0.isDocked(new.id) }) { returned += 1 }
      }
    }
    // The floors are half of what these forty walks gave when this was written: 20 of 61.
    #expect(reopened >= 30 && returned >= 10, "\(returned) of \(reopened)")
  }
}
