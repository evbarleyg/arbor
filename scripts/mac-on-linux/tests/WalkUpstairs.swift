import ArborCore
@testable import ArborKit
import ArborTesting
import ApplicationServices
import CoreGraphics
import FakeMacOS
import Foundation

// The walk at storey two: the real `Controller` on the real `AXWindowSystem` on the model of a Mac, with commands among the steps, a pause, a quit and a new start. The rules look at the model's SCREEN, as a person
// does, and hold it against what the controller says it has in view and out of view. Running, shrinking and replaying are the walk's (Walk.swift).

enum RuleUpstairs {
  static let knows = "Arbor knows every standard window that shows"
  static let believed = "every window that shows is where Arbor believes it"
  static let place = "a docked window that Arbor has in view is in its place"
  static let lost = "no window is out of view that Arbor has in view"
  static let shows = "no window is in view that Arbor has out of view"
  static let overlap = "no two docked windows lie over each other"
  static let ghost = "Arbor keeps no place for a window that has closed"
  static let ghostWithoutAWord = "a place kept for a window that closed without a word is given up"
  static let keyboard = "the window with the keyboard is in view"
  static let tiles = "a window that is shown as a tile, for want of room, does not keep the keyboard"
  static let nothing = "where the view holds no window at all, the keyboard is with no window out of view"
  static let ring = "the focus ring is around the window with the keyboard"
  static let desktop = "with the Desktop in view, so is every floating window"
  static let unasked = "a floating window stays where it is while something else happens and the arrangement stays as it is"
  static let letGo = "with Arbor paused or quit, every window is in view"
  static let rest = "Arbor comes to rest within five seconds of whatever happens"
  static let patience = "Arbor's main thread waits at most two seconds for one hang"
  /// What a hang does to Arbor is known (the stories of slow apps), and must hide nothing else: a breach about a window whose app has hung since Arbor last started goes by a name of its own.
  static let afterAHang = ", though an app has hung"
  private static let plain = [knows, believed, place, lost, shows, overlap, ghost, ghostWithoutAWord, keyboard, tiles, nothing, ring, desktop, unasked, letGo]
  static let all = plain + plain.map { $0 + afterAHang } + [rest, patience]
}

/// Arbor from a start to a quit.
@MainActor
private final class ArborRunning {
  let layer = AXWindowSystem()
  let heard = Listener()
  let overlays = FakeOverlays()
  let controller: Controller
  private let recording: RecordingWindowSystem
  private let watcher: FrontmostAppWatcher

  init(on mac: FakeMac, store: MemoryStateStore) {
    let recorder = TraceRecorder()
    layer.recorder = recorder
    recording = RecordingWindowSystem(wrapping: layer, recorder: recorder)
    controller = Controller(
      system: recording, overlays: RecordingOverlays(wrapping: overlays, recorder: recorder), store: store,
      scheduler: RecordingScheduler(wrapping: MainQueueScheduler(), recorder: recorder), settings: Settings())
    let start = Date(timeIntervalSinceReferenceDate: 800_000_000)
    controller.now = { start.addingTimeInterval(mac.now) }
    heard.mac = mac
    heard.next = recording
    layer.events = heard
    controller.accessibilityGranted = true
    controller.accessibilityProbe = { _ in AXIsProcessTrusted() }
    let controller = self.controller
    watcher = FrontmostAppWatcher { [weak controller] app in controller?.applicationActivated(app) }
    watcher.start()
    controller.start()
  }

  func quit() {
    controller.shutdown()
    watcher.stop()
  }
}

@MainActor
final class WalkUpstairs: Walking {
  let mac = FakeMac()
  private let store = MemoryStateStore()
  private var arbor: ArborRunning?
  /// Broken in the middle of a step, where `check` does not look.
  private var found: [Breach] = []
  private var hasHung: Set<pid_t> = []
  /// Where the floating windows in view were at the last look, and what has been touched since.
  private var floats: [UInt32: CGRect] = [:]
  /// The docked windows' places and the Desktop's at the last look. Floating windows live on the Desktop, and are shifted when its extent changes.
  private var arrangement: [CGRect] = []
  private var touched: Set<UInt32> = []
  private var somethingWasAsked = false

  init(manners: WalkManners, seed: UInt64, keepsJournal: Bool) {
    FakeMac.current = mac
    mac.keepsJournal = keepsJournal
    let first = mac.launch("App1")
    mac.open("a", in: first, frame: CGRect(x: 40, y: 60, width: 420, height: 320))
    mac.open("b", in: first, frame: CGRect(x: 520, y: 80, width: 380, height: 300))
    mac.open("c", in: mac.launch("App2"), frame: CGRect(x: 200, y: 330, width: 460, height: 300))
    mac.pass(1)
    manners.apply(to: mac, seed: seed)
    start()
  }

  private func start() {
    mac.note("Arbor starts")
    mac.arborIsBack()
    hasHung = Set(mac.apps.filter(\.isHung).map(\.pid))
    arbor = ArborRunning(on: mac, store: store)
    mac.pass(1)
    somethingWasAsked = true
  }

  private func quit() {
    mac.note("Arbor is asked to quit")
    arbor?.quit()
    arbor = nil
    mac.arborIsGone()
  }

  func end() {
    arbor?.quit()
    mac.end()
  }

  func spoils(_ rule: String) -> Bool { rule != RuleUpstairs.patience }

  private var asked = 0
  func hasBeenAtWork() -> Bool {
    let now = mac.stack.reduce(0) { $0 + $1.timesAskedForAFrame }
    defer { asked = now }
    return now != asked
  }
  func noteUnrest() { found.append(Breach(rule: RuleUpstairs.rest, detail: "it is still asking windows to move")) }

  func startAfresh() {
    mac.note("ARBOR IS QUIT AND STARTED AGAIN, after a listed fault")
    mac.release()
    quit()
    mac.pass(0.5)
    // Whatever was left out of view is fetched by hand, or the fault would be found again and again.
    for window in mac.stack where window.isOpen && !window.app.isHung && mac.isShowing(window) && fraction(window) < 0.95 {
      mac.appMoves(window, to: CGRect(x: 60 + CGFloat(window.number % 5) * 40, y: 60 + CGFloat(window.number % 4) * 40, width: 400, height: 300))
    }
    mac.pass(0.5)
    found.removeAll()
    start()
  }

  // MARK: Steps

  private var apps: [FakeMac.App] { mac.apps.filter { $0 !== mac.arbor } }
  private func pick<T>(_ items: [T], _ index: Int) -> T? { items.isEmpty ? nil : items[index % items.count] }
  private var openWindows: [FakeMac.Window] { mac.stack.filter { $0.isOpen && !$0.app.isHung && $0.isBusyUntil <= mac.now }.sorted { $0.number < $1.number } }
  private var showing: [FakeMac.Window] { openWindows.filter { mac.isShowing($0) } }
  /// What a hand can get hold of.
  private var inReach: [FakeMac.Window] { showing.filter { fraction($0) > 0.5 } }
  private func frame(_ b: Int) -> CGRect {
    CGRect(x: 20 + CGFloat(b % 6) * 110, y: 40 + CGFloat(b / 6 % 5) * 70, width: 260 + CGFloat(b % 4) * 60, height: 200 + CGFloat(b % 3) * 50)
  }

  private func ask(_ text: String) {
    somethingWasAsked = true
    mac.note("arborctl \(text)")
    guard let arbor, let command = try? Command.parse(text) else { return }
    let result = arbor.controller.perform(command)
    if !result.ok { mac.note("    it fails: \(result.message)") }
  }

  func take(_ step: WalkStep) {
    let (a, b) = (step.a, step.b)
    switch step.kind {
    case .launch:
      guard apps.count < 5 else { return }
      let app = mac.launch("App\(mac.apps.count + a)")
      mac.pass(0.2)
      mac.open("w", in: app, frame: frame(b))
    case .quit: if let app = pick(apps, a) { mac.quit(app) }
    case .open: if let app = pick(apps.filter { !$0.isHung && !$0.isHidden }, a), openWindows.count < 8 { mac.open("w", in: app, frame: frame(b)) }
    case .close: if let window = pick(inReach, a) { mac.close(window) }
    case .click: if let window = pick(inReach, a) { mac.click(window) }
    case .activate: if let app = pick(apps, a) { mac.activate(app) }
    case .minimize:
      guard let window = pick(inReach, a) else { return }
      touched.insert(window.number)
      mac.minimize(window)
    case .restore:
      guard let window = pick(openWindows.filter(\.isMinimized), a) else { return }
      touched.insert(window.number)
      mac.restore(window, byHand: true)
    case .hide: if let app = pick(apps.filter { !$0.isHung }, a) { mac.hide(app) }
    case .move:
      guard let window = pick(showing, a) else { return }
      touched.insert(window.number)
      mac.appMoves(window, to: frame(b))
    case .drag:
      guard let window = pick(inReach.filter { mac.windowShowing(at: CGPoint(x: $0.frame.midX, y: $0.frame.minY + 10)) === $0 }, a), !mac.mouse.isDown else { return }
      touched.insert(window.number)
      // To the edges too, where a drop docks.
      let targets = [CGPoint(x: 2, y: 400), CGPoint(x: 1021, y: 400), CGPoint(x: 500, y: 30), CGPoint(x: 300 + CGFloat(b) * 4, y: 200 + CGFloat(b) * 3), CGPoint(x: 150 + CGFloat(b) * 6, y: 500)]
      mac.drag(from: CGPoint(x: window.frame.midX, y: window.frame.minY + 10), to: targets[b % targets.count])
      mac.release()
    case .resize:
      guard let window = pick(inReach.filter { mac.windowShowing(at: CGPoint(x: $0.frame.maxX - 1, y: $0.frame.midY)) === $0 }, a), !mac.mouse.isDown else { return }
      touched.insert(window.number)
      mac.drag(from: CGPoint(x: window.frame.maxX, y: window.frame.midY), to: CGPoint(x: window.frame.maxX + CGFloat(b % 7 - 3) * 25, y: window.frame.midY))
      mac.release()
    case .hang:
      guard let app = pick(apps.filter { !$0.isHung }, a) else { return }
      hasHung.insert(app.pid)
      mac.hang(app)
    case .wake: if let app = pick(apps.filter(\.hangsByItself), a) { mac.wake(app) }
    case .space: mac.switchSpace(to: mac.activeSpace == 1 ? 2 : 1)
    case .dock: if let window = pick(showing, a) { ask("dock \(window.number) \(["left", "right", "top", "bottom"][b % 4])") }
    case .float: if let window = pick(showing, a) { ask("float \(window.number)") }
    case .arrange: ask("arrange")
    case .zoom: if let window = pick(showing, a) { ask("zoom \(window.number)") }
    case .out: ask("out")
    case .stepIn: ask("in")
    case .back: ask("back")
    case .showAll: ask("show-all")
    case .focus: if let window = pick(showing, a) { ask("focus \(window.number)") }
    case .pause: ask("pause")
    case .resume: ask("resume")
    case .restart:
      quit()
      mac.pass(1)
      lookWithArborAway()
      start()
    default: break
    }
  }

  // MARK: The rules

  private func fraction(_ window: FakeMac.Window) -> Double {
    guard window.bounds.width > 0, window.bounds.height > 0 else { return 0 }
    let seen = mac.screens.reduce(0.0) { sum, screen in
      let part = window.bounds.intersection(screen.frame)
      return part.isNull ? sum : sum + Double(part.width * part.height)
    }
    return seen / Double(window.bounds.width * window.bounds.height)
  }

  /// `anyApp`: where the keyboard is depends on every app that was asked to take it or to give it up.
  private func breach(_ rule: String, about window: FakeMac.Window, anyApp: Bool = false, _ detail: String) {
    found.append(Breach(rule: hasHung.contains(window.app.pid) || (anyApp && !hasHung.isEmpty) ? rule + RuleUpstairs.afterAHang : rule, detail: detail))
  }

  /// What a person could expect to see: open, standard, on this Space, not minimized, not hidden, at rest, its app awake.
  private var expected: [FakeMac.Window] {
    mac.stack.filter { $0.isOpen && $0.isStandard && $0.isFrontTab && mac.isShowing($0) && !$0.app.isHung && $0.isBusyUntil <= mac.now }.sorted { $0.number < $1.number }
  }

  private func lookWithArborAway() {
    // As good as gone. What is half over the edge may have been dragged there by hand.
    for window in expected where fraction(window) < 0.25 { breach(RuleUpstairs.letGo, about: window, "w\(window.number) is at \(window.bounds.text)") }
  }

  func check() -> [Breach] {
    defer {
      found.removeAll()
      touched.removeAll()
      somethingWasAsked = false
    }
    if mac.longestWaitForOneHang > 2 { found.append(Breach(rule: RuleUpstairs.patience, detail: "\(mac.longestWaitForOneHang) s for one hang of one app")) }
    guard let arbor, arbor.controller.isRunning, !arbor.controller.isPaused else {
      lookWithArborAway()
      floats.removeAll()
      return found
    }
    let controller = arbor.controller
    var slots: [UInt32: CGRect] = [:]
    // Docked windows of spaces that are not in view, and floating ones while the Desktop is not: the controller's own book.
    var out = Set(controller.parked.map(\.rawValue))
    var desktops: [CGRect] = []
    var hasTiles = false
    for display in arbor.layer.displays().map(\.id) {
      guard let layout = controller.freshLayout(of: display) else { continue }
      for (window, slot) in layout.windowFrames { slots[window.rawValue] = slot }
      out.formUnion(layout.hiddenWindows.map(\.rawValue))
      if let desktop = layout.desktopFrame { desktops.append(desktop) }
      if !layout.tiles.isEmpty { hasTiles = true }
    }
    let arrangementNow = slots.sorted { $0.key < $1.key }.map(\.value) + desktops
    let staysAsItIs = arrangementNow == arrangement
    arrangement = arrangementNow
    var floatsNow: [UInt32: CGRect] = [:]
    for window in expected {
      let (number, at) = (window.number, "w\(window.number) is at \(window.bounds.text)")
      guard let belief = controller.windows[WindowID(number)] else {
        breach(RuleUpstairs.knows, about: window, at)
        continue
      }
      if belief.frame != window.frame { breach(RuleUpstairs.believed, about: window, "\(at), Arbor has \(belief.frame.text)") }
      if let slot = slots[number] {
        // Two points, which nobody sees: a window restored from the Dock gives the display two points back, and the docked windows are left a point off their new places.
        let off = [window.frame.minX - slot.minX, window.frame.minY - slot.minY, window.frame.maxX - slot.maxX, window.frame.maxY - slot.maxY].map(abs).max() ?? 0
        if off > 2 { breach(RuleUpstairs.place, about: window, "\(at), its place is \(slot.text)") }
      } else if out.contains(number) {
        // At a start Arbor lets the window with the keyboard be, though the kept arrangement has it out of view: nobody's window is taken from under their hands. The headless nets excuse it alike.
        if fraction(window) > 0.05, controller.windowLetBe?.rawValue != number { breach(RuleUpstairs.shows, about: window, at) }
        if !desktops.isEmpty, controller.snapshot().windows.first(where: { $0.id.rawValue == number })?.docked == false { breach(RuleUpstairs.desktop, about: window, at) }
      } else {
        // Where a hand has just left it, it is not lost.
        if fraction(window) < 0.05, !touched.contains(number) { breach(RuleUpstairs.lost, about: window, at) }
        floatsNow[number] = window.frame
        if !somethingWasAsked, staysAsItIs, !touched.contains(number), let before = floats[number], before != window.frame {
          breach(RuleUpstairs.unasked, about: window, "w\(number) was at \(before.text) and is at \(window.frame.text)")
        }
      }
    }
    floats = floatsNow
    for number in slots.keys.sorted() {
      guard let window = mac.windowThatEverWas(number), !window.isOpen else { continue }
      breach(window.closedWithoutAWord ? RuleUpstairs.ghostWithoutAWord : RuleUpstairs.ghost, about: window, "w\(number), at \(slots[number]!.text)")
    }
    let docked = expected.filter { slots[$0.number] != nil }
    for (index, first) in docked.enumerated() {
      for second in docked[(index + 1)...] where first.frame.insetBy(dx: 1, dy: 1).intersects(second.frame) {
        breach(RuleUpstairs.overlap, about: first, "w\(first.number) at \(first.frame.text) and w\(second.number) at \(second.frame.text)")
      }
    }
    if let key = mac.keyWindow, expected.contains(where: { $0 === key }), key.app.policy == .regular {
      if fraction(key) < 0.25, !touched.contains(key.number) { breach(hasTiles && out.contains(key.number) ? RuleUpstairs.tiles : slots.isEmpty && floatsNow.isEmpty ? RuleUpstairs.nothing : RuleUpstairs.keyboard, about: key, anyApp: true, "w\(key.number) has it, at \(key.bounds.text)") }
      let ring = arbor.overlays.scenes.values.compactMap(\.focusRing).first?.window.rawValue
      if let ring, ring != key.number { breach(RuleUpstairs.ring, about: key, anyApp: true, "w\(key.number) has it, the ring is around w\(ring)") }
    }
    // For whoever reads a replay: how Arbor sees it, and where the windows are.
    if !found.isEmpty, mac.keepsJournal {
      for breach in found { mac.note("✘ \(breach.rule): \(breach.detail)") }
      for line in (controller.perform(.ascii).text ?? "").split(separator: "\n") { mac.note("    | \(line)") }
      mac.note("    on the screen: " + expected.map { "w\($0.number) \($0.bounds.text)" }.joined(separator: "; "))
    }
    return found
  }
}
