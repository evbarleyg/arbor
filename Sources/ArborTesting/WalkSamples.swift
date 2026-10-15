import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// What the screen of the stand-in showed while a walk was played, in the grammar of scripts/mac-shell/sampler.swift, with the marks of
/// scripts/mac-shell/lib-day.sh. So scripts/mac-shell/jolts.py, which judges what a hosted Mac brought back, judges a playing on Linux by the same rules, and
/// scripts/mac-shell/walk-diff.py lays the two side by side.
///
/// A sampler looks sixty times a second and may miss what comes and goes between two looks. This one misses nothing: every frame a window had is written, at the
/// moment of the walk's own clock at which it had it. There is no stage: whatever a window does on its way is seen, as on a Mac with Reduce Motion on.
@MainActor
public final class WalkSamples {
  public private(set) var lines: [String] = []
  /// The walk's clock, in seconds, when a line was last written that `quiet` waits for.
  public private(set) var lastChange = 0.0

  /// No day in particular, and the same for every walk: the same seed writes the same file.
  private static let beginning = 1_800_000_000_000.0
  /// Numbers no window of an app has.
  private static let (preview, macPreview, firstTile): (UInt32, UInt32, UInt32) = (9001, 9002, 9100)

  private var frames: [WindowID: CGRect] = [:]
  private var order: [WindowID] = []
  private var front: String?
  private var button = false
  private var pointer = CGPoint.zero
  private var displays: [DisplaySnapshot] = []
  private var panels: [UInt32: CGRect] = [:]
  /// The number each tile goes by, by its display and its node: given out as they first show.
  private var tileNumbers: [String: UInt32] = [:]
  /// Arbor's process, as long as it lives.
  var arbor: Int?

  public var text: String { lines.map { $0 + "\n" }.joined() }

  private func write(_ time: Double, _ words: String, counts: Bool = false) {
    lines.append("\(Int((Self.beginning + time * 1000).rounded())) \(words)")
    if counts { lastChange = time }
  }

  static func text(_ value: CGFloat) -> String {
    let number = Double(value)
    return number == number.rounded() ? String(Int(number)) : String(format: "%.1f", number)
  }

  static func text(_ rect: CGRect) -> String { "\(text(rect.minX)) \(text(rect.minY)) \(text(rect.width)) \(text(rect.height))" }

  func mark(_ words: String, at time: Double) { write(time, "M \(words)") }

  /// The sampler's last line. It never came late: the clock is the walk's own.
  func stop(at time: Double) { write(time, "S samples \(lines.count) seconds \(String(format: "%.1f", time)) hz 60.0 cost-ms 0.00 late 0 longest-gap-ms 0") }

  /// A key went down.
  func key(at time: Double) { write(time, "K 1", counts: true) }

  /// The button alone, for a drag of something that is no window: a gap.
  func button(down: Bool, _ point: CGPoint, at time: Double) {
    write(time, "B \(down ? "down" : "up") \(Self.text(point.x)) \(Self.text(point.y))", counts: true)
  }

  /// A press and a release that no window system hears of: on an icon in the Dock, in a menu. Both at one moment, as the sampler writes a click that began and
  /// ended between two looks.
  func click(_ point: CGPoint, at time: Double) {
    write(time, "B down \(Self.text(point.x)) \(Self.text(point.y))", counts: true)
    write(time, "B up \(Self.text(point.x)) \(Self.text(point.y))", counts: true)
  }

  /// Writes down what has changed since the last look. `moves` are the frames Arbor gave windows meanwhile, in order: a window that went elsewhere
  /// first is seen there.
  func look(at runner: ChaosRunner, moves: ArraySlice<(window: WindowID, frame: CGRect)>, time: Double) {
    let system = runner.system
    if system.displayList != displays {
      let gone = displays.filter { old in !old.isMain && !system.displayList.contains { $0.id == old.id } }
      displays = system.displayList
      for display in displays {
        if display.isMain {
          write(time, "D \(Self.text(display.frame))")
          write(time, "V \(Self.text(display.visibleFrame))")
        } else {
          write(time, "Y \(display.id.rawValue) \(Self.text(display.frame)) \(Self.text(display.visibleFrame))")
        }
      }
      for display in gone { write(time, "Y \(display.id.rawValue)") }
    }
    // The app whose window has the keyboard is in front, whoever gave it the keyboard.
    let holder = system.focused.flatMap { system.windows[$0]?.snapshot }
    if let bundle = holder?.bundleID ?? system.frontmost?.bundleID, bundle != front {
      front = bundle
      let pid = holder?.pid ?? system.windows.values.first { $0.snapshot.bundleID == bundle }?.snapshot.pid ?? 0
      write(time, "A \(pid) \(bundle)")
    }
    // Arbor's own panels, as far as a rule asks about them: the drop preview and the tiles. And macOS's preview of its own tiling.
    var showing: [UInt32: (frame: CGRect, line: String)] = [:]
    if let arbor, runner.isRunning {
      if let preview = runner.harness.overlays.preview { showing[Self.preview] = (preview, "\(arbor) 3") }
      // A tile is an ordinary window of Arbor's, behind all the others. The preview floats above them.
      for (display, tiles) in runner.harness.overlays.tiles.sorted(by: { $0.key < $1.key }) {
        for tile in tiles.sorted(by: { $0.node.rawValue < $1.node.rawValue }) {
          let name = "\(display.rawValue)/\(tile.node.rawValue)"
          let number = tileNumbers[name] ?? Self.firstTile + UInt32(tileNumbers.count)
          tileNumbers[name] = number
          showing[number] = (tile.frame, "\(arbor) 0")
        }
      }
    }
    if system.dragging != nil, let tile = system.macTile(at: system.cursor) { showing[Self.macPreview] = (tile, "77 0") }
    // What goes goes first: of two panels of which one gives way to the other in one moment, no moment shows both.
    for id in panels.keys.sorted() where showing[id] == nil {
      panels[id] = nil
      write(time, "G \(id)")
    }
    if system.mouseDown != button {
      button = system.mouseDown
      pointer = system.cursor
      write(time, "B \(button ? "down" : "up") \(Self.text(pointer.x)) \(Self.text(pointer.y))", counts: true)
    } else if button, system.cursor != pointer {
      pointer = system.cursor
      write(time, "P \(Self.text(pointer.x)) \(Self.text(pointer.y))")
    }

    // In full screen a window is on a Space of its own, which is the one that shows: the others are on one that does not.
    let alone = system.windows.values.first { $0.snapshot.isFullScreen }?.snapshot.id
    func onScreen(_ id: WindowID) -> WindowSnapshot? {
      guard let snapshot = system.windows[id]?.snapshot, !snapshot.isMinimized, !snapshot.isHidden, snapshot.isOnActiveSpace, alone == nil || alone == id
      else { return nil }
      return snapshot
    }
    func window(_ snapshot: WindowSnapshot, _ frame: CGRect) {
      guard frames[snapshot.id] != frame else { return }
      frames[snapshot.id] = frame
      let owner = snapshot.appName.replacingOccurrences(of: " ", with: "_")
      write(time, "W \(snapshot.id.rawValue) \(snapshot.pid) 0 \(Self.text(frame)) \(owner)", counts: true)
    }
    for move in moves { if let snapshot = onScreen(move.window) { window(snapshot, move.frame) } }
    for id in system.windows.keys.sorted() { if let snapshot = onScreen(id) { window(snapshot, snapshot.frame) } }
    for id in frames.keys.sorted() where onScreen(id) == nil {
      frames[id] = nil
      write(time, "G \(id.rawValue)", counts: true)
    }
    let pile = system.windowsFrontToBack().filter { frames[$0] != nil }
    if pile != order {
      order = pile
      if !pile.isEmpty { write(time, "Z \(pile.map { String($0.rawValue) }.joined(separator: ","))", counts: true) }
    }

    for (id, panel) in showing.sorted(by: { $0.key < $1.key }) where panels[id] != panel.frame {
      panels[id] = panel.frame
      write(time, "W \(id) \(panel.line) \(Self.text(panel.frame)) \(id == Self.macPreview ? "WindowManager" : "Arbor")")
    }
  }

  /// Where every window on the screen is, from the one in front to the one at the back.
  var pile: [(window: WindowID, frame: CGRect)] { order.compactMap { id in frames[id].map { (id, $0) } } }
}
