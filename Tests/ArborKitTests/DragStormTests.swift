import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// F09, by the hundred: random arrangements, random drags. What must hold however a drag goes is checked after each.
/// A failure names its seed; `storm(seed:…)` with that seed replays it.
@Suite @MainActor struct DragStormTests {
  struct Random: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0x9E37_79B9_7F4A_7C15 &+ 1 }
    mutating func next() -> UInt64 {
      state ^= state << 13
      state ^= state >> 7
      state ^= state << 17
      return state
    }
  }

  static let side = DisplaySnapshot(
    id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
    visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

  /// Six windows on two displays, some docked, perhaps one pinned, perhaps a zoomed view, perhaps a guest.
  func arrangement(_ random: inout Random, _ configure: (inout Settings) -> Void) -> (Harness, [WindowID]) {
    var settings = Settings()
    settings.tabsEnabled = Bool.random(using: &random)
    configure(&settings)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, Self.side], settings: settings)
    var windows: [WindowID] = []
    for (index, app) in ["Safari", "Notes", "Mail", "Terminal", "Music", "Finder"].enumerated() {
      let onSide = index >= 4
      let frame = CGRect(
        x: Int.random(in: 40...700, using: &random) + (onSide ? 1440 : 0), y: Int.random(in: 60...400, using: &random),
        width: Int.random(in: 250...600, using: &random), height: Int.random(in: 150...380, using: &random))
      windows.append(h.system.open(app: app, frame: frame))
    }
    if Bool.random(using: &random) {
      h.system.userMove(windows[1], to: CGRect(x: 300, y: 100, width: 450, height: 520))
      h.system.setMinimumSize(windows[1], CGSize(width: 420, height: 500))
    }
    h.start()
    let edges = ["left", "right", "top", "bottom"]
    for window in windows where Int.random(in: 0..<3, using: &random) > 0 {
      h.system.cursor = h.frame(window)!.center
      let docked = h.controller.workspaces.values.flatMap(\.tree.allWindows).sorted()
      if let other = docked.randomElement(using: &random), Bool.random(using: &random) {
        h.run("dock \(window.rawValue) beside \(other.rawValue) \(edges.randomElement(using: &random)!)")
      } else {
        h.run("dock \(window.rawValue) \(edges.randomElement(using: &random)!)")
      }
    }
    h.system.cursor = CGPoint(x: 720, y: 450)
    if Bool.random(using: &random), let floating = h.workspace.floating.keys.sorted().randomElement(using: &random) {
      h.run("pin \(floating.rawValue)")
    }
    if Int.random(in: 0..<3, using: &random) == 0, let framed = h.workspace.tree.allWindows.randomElement(using: &random) {
      h.run("zoom \(framed.rawValue)")
      if Bool.random(using: &random) {
        windows.append(h.system.open(app: "Preview", frame: CGRect(x: 500, y: 300, width: 300, height: 200)))
      }
    }
    h.scheduler.runPending()
    return (h, windows)
  }

  /// Somewhere a drag might go: screen edges, edges and middles of what is on screen, anywhere.
  func point(_ random: inout Random, _ h: Harness) -> CGPoint {
    let display = [FakeWindowSystem.standardDisplay, Self.side].randomElement(using: &random)!
    let visible = display.visibleFrame
    switch Int.random(in: 0..<4, using: &random) {
    case 0:
      return [
        CGPoint(x: visible.minX + 3, y: visible.midY), CGPoint(x: visible.maxX - 3, y: visible.midY),
        CGPoint(x: visible.midX, y: visible.minY + 3), CGPoint(x: visible.midX, y: visible.maxY - 3),
      ].randomElement(using: &random)!
    case 1, 2:
      let layout = h.controller.layouts[display.id]
      let frames = (layout?.windowFrames.sorted { $0.key < $1.key }.map(\.value) ?? []) + (layout?.tiles.map(\.frame) ?? [])
      guard let frame = frames.randomElement(using: &random) else { return visible.center }
      return [
        CGPoint(x: frame.minX + 15, y: frame.midY), CGPoint(x: frame.maxX - 15, y: frame.midY),
        CGPoint(x: frame.midX, y: frame.minY + 15), CGPoint(x: frame.midX, y: frame.maxY - 15), frame.center,
      ].randomElement(using: &random)!
    default:
      return CGPoint(
        x: Int.random(in: Int(visible.minX)...Int(visible.maxX), using: &random),
        y: Int.random(in: Int(visible.minY)...Int(visible.maxY), using: &random))
    }
  }

  func wander(_ random: inout Random, _ h: Harness) {
    for _ in 0..<Int.random(in: 1...7, using: &random) {
      if Int.random(in: 0..<6, using: &random) == 0 {
        h.system.holdModifierKeys(h.system.heldModifiers.isEmpty ? .command : [])
      } else {
        h.system.moveDrag(to: point(&random, h), holding: [0, 0.05, 0.2, 0.4].randomElement(using: &random)!)
      }
    }
  }

  struct Picture: Equatable {
    var frames: [WindowID: CGRect]
    var workspaces: [DisplayID: Workspace]
    var parked: Set<WindowID>

    /// What is different in `other`, in words; empty if nothing is.
    func differences(from other: Picture) -> [String] {
      var notes: [String] = []
      // A window within a point of its slot is left where it is (`isInPlace`), and takes the slot exactly when it is
      // next moved: a window that would go no narrower than 420 in a slot made 421 wide for it.
      func same(_ a: CGRect?, _ b: CGRect?) -> Bool {
        if let a, let b { a.approximatelyEquals(b, tolerance: 1) } else { a == b }
      }
      for window in Set(frames.keys).union(other.frames.keys).sorted() where !same(frames[window], other.frames[window]) {
        notes.append("\(window) at \(frames[window].map { "\($0)" } ?? "nowhere"), was at \(other.frames[window].map { "\($0)" } ?? "nowhere")")
      }
      for display in Set(workspaces.keys).union(other.workspaces.keys).sorted() where workspaces[display] != other.workspaces[display] {
        let (now, was) = (workspaces[display], other.workspaces[display])
        if now?.tree != was?.tree { notes.append("the tree of \(display)") }
        if now?.camera != was?.camera { notes.append("the view of \(display)") }
        if now?.floating != was?.floating { notes.append("floating on \(display): \(now?.floating ?? [:]), was \(was?.floating ?? [:])") }
        if now?.guests != was?.guests { notes.append("guests on \(display)") }
        if now?.back != was?.back || now?.forward != was?.forward { notes.append("history of \(display)") }
      }
      if parked != other.parked { notes.append("out of view \(parked.sorted()), was \(other.parked.sorted())") }
      return notes
    }
  }

  /// Everything a person can see and everything Arbor remembers, leaving out `window`.
  func picture(_ h: Harness, without window: WindowID) -> Picture {
    var workspaces = h.controller.workspaces
    for display in workspaces.keys where workspaces[display]!.isFloating(window) { workspaces[display]!.forget(window) }
    let inView = h.system.allWindows().filter { !h.controller.parked.contains($0.id) && $0.id != window }
    return Picture(
      frames: Dictionary(uniqueKeysWithValues: inView.map { ($0.id, $0.frame) }), workspaces: workspaces,
      parked: h.controller.parked.subtracting([window]))
  }

  /// What is wrong, in words. (An `#expect` on the harness prints all of it, by the page.)
  func troubles(_ h: Harness, leftByTheUser: Set<WindowID>) -> [String] {
    var notes: [String] = []
    if h.scheduler.pendingKeys.contains(where: { $0.hasPrefix("drag") }) { notes.append("a timer of the drag is left") }
    if h.overlays.preview != nil { notes.append("the preview is left") }
    for (display, workspace) in h.controller.workspaces.sorted(by: { $0.key < $1.key }) {
      notes += workspace.tree.invariantViolations()
      let layout = h.controller.layouts[display]
      // (Within a point of its slot a window is left where it is, as in `Picture`. With a column for the Desktop seed 645 is the first to
      // meet that, in a slot that a trial made 161 points high and the drop 160; without one, seed 52.)
      for (window, frame) in (layout?.windowFrames ?? [:]).sorted(by: { $0.key < $1.key })
      where h.system.windows[window]?.minimumSize == .zero && h.frame(window)?.approximatelyEquals(frame, tolerance: 1) != true
        && !h.isShortForNow(window, in: frame)
      {
        notes.append("\(window) is at \(h.frame(window)!), its slot is \(frame)")
      }
      for window in (layout?.hiddenWindows ?? []).sorted() where h.system.isVisible(window) {
        notes.append("\(window) shows and should not")
      }
      if h.overlays.seams[display] != layout?.seamsInReach { notes.append("the gap handles of \(display) are elsewhere") }
      if h.overlays.tiles[display]?.map(\.node) != layout?.tiles.map(\.node) { notes.append("the tiles of \(display) differ") }
    }
    for window in h.system.allWindows().sorted(by: { $0.id < $1.id }) {
      let holders = h.controller.workspaces.values.filter { $0.contains(window.id) }.count
      if holders != 1 { notes.append("\(window.id) is in \(holders) workspaces") }
      // Where the user lets go of a window is the user's business, half off the screen or not.
      if !leftByTheUser.contains(window.id), !h.controller.parked.contains(window.id), window.isPresent, !h.system.isVisible(window.id) {
        notes.append("\(window.id) is lost at \(window.frame): not in view and not counted as out of view")
      }
    }
    return notes
  }

  func expectNone(_ notes: [String], _ seed: UInt64, _ when: String = "") {
    if !notes.isEmpty { Issue.record("seed \(seed)\(when): \(notes.joined(separator: "; "))") }
  }

  /// A drag that is called off, however far it went and whatever the others did meanwhile, changes nothing but the
  /// place of the window itself, and not even that if it was docked.
  @Test(arguments: [false, true]) func aDragCalledOffChangesNothingElse(keepPushed: Bool) {
    for seed in UInt64(1)...250 {
      var random = Random(seed: seed)
      let (h, windows) = arrangement(&random) {
        $0.reflowWhileDragging = true
        $0.keepPushed = keepPushed
      }
      guard let dragged = windows.filter({ !h.controller.parked.contains($0) }).randomElement(using: &random) else { continue }
      let docked = h.controller.workspaces.values.contains { $0.isDocked(dragged) }
      let slot = h.frame(dragged)
      let before = picture(h, without: dragged)
      h.system.beginDrag(dragged)
      wander(&random, h)
      // The one exception: a release that Arbor never saw, macOS saw. Where it tiles, the window is its own by now, and leaves the arrangement
      // instead of being pulled back out of macOS's tile (MacTilingTests).
      if h.system.macTile(at: h.system.cursor) != nil { continue }
      h.system.loseTheReleaseOfTheDrag()
      h.system.heldModifiers = []
      expectNone(picture(h, without: dragged).differences(from: before), seed)
      if docked, let slot, h.frame(dragged)?.approximatelyEquals(slot, tolerance: 1) != true {
        Issue.record("seed \(seed): it is not back in its slot")
      }
      expectNone(troubles(h, leftByTheUser: [dragged]), seed)
      h.scheduler.runPending()
      expectNone(picture(h, without: dragged).differences(from: before), seed, ", a moment later")
    }
  }

  /// What Arbor remembers without showing it (which frames it chose itself, what it learned) is as it was too: after a
  /// docked window's drag is called off, whatever comes next goes as if there had been no drag.
  @Test func afterADragCalledOffEverythingGoesOnAsIfItHadNotBeen() {
    for seed in UInt64(1)...250 {
      func play(dragging: Bool) -> [Picture]? {
        var random = Random(seed: seed)
        let (h, windows) = arrangement(&random) { $0.reflowWhileDragging = true }
        let docked = windows.filter { window in
          !h.controller.parked.contains(window) && h.controller.workspaces.values.contains { $0.isDocked(window) }
        }
        guard let dragged = docked.randomElement(using: &random) else { return nil }
        // The same numbers are drawn either way, so that what follows is the same.
        var journey = random
        if dragging {
          h.system.beginDrag(dragged)
          wander(&journey, h)
          // As above: where macOS tiles, the drag is not without consequence.
          if h.system.macTile(at: h.system.cursor) != nil { return nil }
          h.system.loseTheReleaseOfTheDrag()
          h.system.heldModifiers = []
          h.system.cursor = CGPoint(x: 720, y: 450)
        } else {
          // Whoever takes hold of a window gives it the keyboard. That much is the press's doing and not the drag's.
          h.system.userClick(dragged)
        }
        var pictures: [Picture] = []
        for _ in 0..<5 {
          let window = windows.randomElement(using: &random)!.rawValue
          let edge = ["left", "right", "top", "bottom"].randomElement(using: &random)!
          h.run(
            [
              "dock \(window) \(edge)", "float \(window)", "zoom \(window)", "show-all", "back", "desktop", "out",
              "resize \(window) \(edge) 60",
            ].randomElement(using: &random)!)
          h.scheduler.runPending()
          pictures.append(picture(h, without: WindowID(0)))
        }
        return pictures
      }
      guard let plain = play(dragging: false), let after = play(dragging: true) else { continue }
      for (step, (now, was)) in zip(after, plain).enumerated() {
        expectNone(now.differences(from: was), seed, ", command \(step + 1) after the drag")
      }
    }
  }

  /// Commands, windows opening, closing and minimizing, displays going and coming, in the middle of drags that end in
  /// every way there is.
  @Test(arguments: [false, true]) func whateverHappensDuringADragNothingIsLostOrLeftBehind(reflow: Bool) {
    for seed in UInt64(1)...250 {
      var random = Random(seed: seed)
      let (h, opened) = arrangement(&random) { $0.reflowWhileDragging = reflow }
      var windows = opened
      var leftByTheUser: Set<WindowID> = []
      for _ in 0..<3 {
        guard let dragged = windows.filter({ !h.controller.parked.contains($0) }).randomElement(using: &random) else { break }
        leftByTheUser.insert(dragged)
        h.system.beginDrag(dragged)
        for _ in 0..<Int.random(in: 1...4, using: &random) {
          wander(&random, h)
          let other = windows.randomElement(using: &random)!
          switch Int.random(in: 0..<13, using: &random) {
          case 0: h.run("zoom \(other.rawValue)")
          case 1: h.run("show-all")
          case 2: h.run("back")
          case 3: h.run("float \(other.rawValue)")
          case 4: h.run("dock \(other.rawValue) \(["left", "right", "top", "bottom"].randomElement(using: &random)!)")
          case 5: h.run("arrange")
          case 6:
            h.system.close(other)
            windows.removeAll { $0 == other }
          case 7: windows.append(h.system.open(app: "Preview", frame: CGRect(x: 400, y: 200, width: 300, height: 200)))
          case 8: h.system.setMinimized(other, Bool.random(using: &random))
          case 9:
            h.system.setDisplays(
              Bool.random(using: &random) ? [FakeWindowSystem.standardDisplay] : [FakeWindowSystem.standardDisplay, Self.side])
          case 10: h.system.userFocus(other)
          case 11: h.run("float-all")
          default: break
          }
          if windows.isEmpty { break }
        }
        switch Int.random(in: 0..<4, using: &random) {
        case 0: h.system.loseTheReleaseOfTheDrag()
        case 1:
          // The release is lost and the next thing Arbor hears is another drag.
          if let next = windows.filter({ !h.controller.parked.contains($0) }).randomElement(using: &random),
            let frame = h.frame(next)
          {
            leftByTheUser.insert(next)
            h.system.heldModifiers = DragDocks.key
            h.controller.dragBegan(next, at: frame.center)
            h.system.mouseDown = false
            h.controller.dragEnded(next, at: frame.center)
          }
          h.system.loseTheReleaseOfTheDrag()
        default: h.system.endDrag()
        }
        h.system.heldModifiers = []
        for window in windows where h.system.windows[window]?.snapshot.isMinimized == true {
          h.system.setMinimized(window, false)
        }
        h.scheduler.runPending()
        expectNone(troubles(h, leftByTheUser: leftByTheUser), seed)
        if windows.isEmpty { break }
      }
    }
  }
}
