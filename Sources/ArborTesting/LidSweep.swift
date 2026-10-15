import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// A laptop beside a big display. Its lid closes, opens and closes again, with one floating window on the desk, and that is played
/// for a window in every place along the big display and across its edges, twice each: on a Mac with Arbor, and on the same Mac without.
///
/// The walks of the chaos lab search a large space at random, and judge by rules. This searches one small space completely, and its
/// yardstick is not a rule: whatever differs between the two Macs is Arbor's doing, and has to be one of the few things Arbor means to do.
/// So it can be strict where a rule has to be lenient, at a change of displays, when macOS itself moves windows about. And
/// it gives numbers: the same columns before and after a change say what the change cured and what it cost.
///
/// What it does not play: more than one window; a docked one; displays whose tops or sides are not in line; a display that changes its size or side;
/// what macOS really does with windows when a lid closes, of which the lab has only its own idea (`ChaosRunner`'s `displays`).
///
/// `arbor-sim sweep` prints it (docs/TESTING.md, "The lid sweep").
@MainActor
public struct LidSweep {
  /// Where the big display stands, seen from the laptop.
  public enum Side: String, CaseIterable, Sendable { case right, left, above }
  /// What Arbor is doing while the displays change.
  public enum Meanwhile: String, CaseIterable, Sendable { case running, paused, quit, crashed }

  /// One way to play all the places.
  public struct Column: Sendable, CustomStringConvertible {
    public var side: Side
    public var meanwhile = Meanwhile.running
    /// Whether a hand put the window where it is, with Arbor looking on, or it has been there since before Arbor started.
    public var byHand = true
    /// How long before the lid first closes the hand let go. Arbor believes for a while a window that has spoken of its place.
    public var secondsSinceTheHand = Column.longAgo
    public static let longAgo = 300.0
    /// In which order Arbor hears of the windows and of the displays.
    public var order = ChaosAction.WindowsFollow.late

    public init(
      side: Side, meanwhile: Meanwhile = .running, byHand: Bool = true, secondsSinceTheHand: Double = Column.longAgo, order: ChaosAction.WindowsFollow = .late
    ) {
      (self.side, self.meanwhile, self.byHand, self.secondsSinceTheHand, self.order) = (side, meanwhile, byHand, secondsSinceTheHand, order)
    }

    public var description: String {
      let hand = byHand ? "by hand" + (secondsSinceTheHand == Self.longAgo ? "" : " \(Int(secondsSinceTheHand)) s before") : "untouched"
      return "\(side.rawValue), \(meanwhile.rawValue), \(hand), windows-\(order.rawValue)"
    }

    /// Every order with Arbor running, by hand and untouched; Arbor away across the change, when it hears of no order at all; and a hand
    /// that has only just let go.
    public static func all(_ sides: [Side] = Side.allCases) -> [Column] {
      sides.flatMap { side in
        ChaosAction.WindowsFollow.allCases.flatMap { order in [true, false].map { Column(side: side, byHand: $0, order: order) } }
          + [Meanwhile.paused, .quit, .crashed].map { Column(side: side, meanwhile: $0) }
          + [0, 5, 15, 29].map { Column(side: side, secondsSinceTheHand: $0) } + [Column(side: side, secondsSinceTheHand: 0, order: .first)]
      }
    }
  }

  /// What differed, each kind with the places where. A place is looked at nine times: after each of the three changes, and after ⌃⌥0 and
  /// `relayout` following each, because a window that is right until the next layout is not right. Each change is judged by itself, so
  /// one fault counts three times at most, in every column alike.
  public struct Tally: Sendable {
    /// The places that were looked at.
    public var places = 0
    /// Not looked at: Arbor moved the window when it started, which is another story, but a story.
    public var movedAtTheStart = 0
    /// Not looked at: no hand could have put the window there.
    public var outOfAHandsReach = 0
    /// What the lab refused or did not understand. Anything here, and the sweep was not the one it says it was.
    public var trouble: [String] = []
    /// In view without Arbor, out of view with it.
    public var hidden: [String] = []
    /// No hand can take hold of its title bar (`ChaosRunner.isReachable`), where without Arbor one can.
    public var outOfReach: [String] = []
    /// Wholly on a display without Arbor, so there was no reason to move it; elsewhere with Arbor.
    public var jumped: [String] = []
    /// Hangs over an edge without Arbor; elsewhere with Arbor, which may have fitted it onto a display.
    public var fitted: [String] = []
    /// Of those two, how many at each change: the lid closes, opens, closes again.
    public var jumpedAtEachChange = [0, 0, 0]
    public var fittedAtEachChange = [0, 0, 0]
    /// Began on the laptop and is on it again now that the lid is open: on purpose.
    public var homeOnTheLaptop = 0
    /// On the big display where the hand left it, or where it was found, seen from that display, where macOS alone has it elsewhere: on purpose.
    public var whereTheHandLeftIt = 0

    public var isLost: Bool { !hidden.isEmpty || !outOfReach.isEmpty }
  }

  public static let laptop = CGRect(x: 0, y: 0, width: 1728, height: 1117)
  public static let big = CGSize(width: 2560, height: 1440)
  public static let window = WindowID(101)

  public var column: Column
  /// Points from one place to the next.
  public var stride = 40
  public var widths = [600, 1400]
  /// How much of the window is on the big display in the first and the last place of a row: as little as a hand can still take hold of.
  public var margin = 40
  /// How long the lid stays as it is.
  public var secondsBetweenChanges = 120.0
  /// For the controls. False: the second Mac has no Arbor either, so nothing may differ.
  public var withArbor = true
  /// For the controls: done to the Mac with Arbor after every change, in Arbor's place.
  public var sabotage: (@MainActor (ChaosRunner) -> Void)?

  public init(_ column: Column) { self.column = column }

  var origin: (x: Int, y: Int) {
    switch column.side {
    case .right: (Int(Self.laptop.width), 0)
    case .left: (-Int(Self.big.width), 0)
    case .above: (0, -Int(Self.big.height))
    }
  }
  func open(_ order: ChaosAction.WindowsFollow) -> String {
    "displays main:0,0,\(Int(Self.laptop.width)),\(Int(Self.laptop.height)):25,0,0,0* side:\(origin.x),\(origin.y),\(Int(Self.big.width)),\(Int(Self.big.height)):0,0,0,0 windows-\(order.rawValue)"
  }
  func closed(_ order: ChaosAction.WindowsFollow) -> String {
    "displays side:0,0,\(Int(Self.big.width)),\(Int(Self.big.height)):25,0,0,0* windows-\(order.rawValue)"
  }

  /// What was refused while a place was played.
  private final class Trouble { var lines: [String] = [] }
  private let trouble = Trouble()

  private func play(_ actions: [ChaosAction], on runners: [ChaosRunner]) {
    for action in actions {
      for runner in runners {
        _ = runner.step(action)
        trouble.lines += runner.refusals.map { "`\(action.text)`: \($0)" }
      }
    }
  }
  private func play(_ text: String, on runners: ChaosRunner...) { play(ChaosAction.script(text), on: runners) }
  private func play(_ actions: ChaosAction..., on runner: ChaosRunner) { play(actions, on: [runner]) }

  /// A desk with the window at `x`, `y`.
  private func world(arbor: Bool, x: Int, y: Int, width: Int) -> ChaosRunner {
    let runner = ChaosRunner()
    let start = column.byHand ? (x: origin.x + 700, y: origin.y + 400) : (x: x, y: y)
    play("\(open(.never))\nopen 101 Notes pid 1001 at \(start.x) \(start.y) \(width) 500", on: runner)
    if arbor { play(.launch, .settle, on: runner) }
    if column.byHand { play("move 101 \(x) \(y) \(width) 500", on: runner) }
    if arbor { play(.settle, .advance(column.byHand ? column.secondsSinceTheHand : Column.longAgo), on: runner) }
    return runner
  }

  private func look(at x: Int, _ y: Int, width: Int, into tally: inout Tally) {
    let (mac, arbor) = (world(arbor: false, x: x, y: y, width: width), world(arbor: withArbor, x: x, y: y, width: width))
    let window = Self.window
    let began = CGRect(x: x, y: y, width: width, height: 500)
    guard mac.harness.frame(window) == began else {
      tally.outOfAHandsReach += 1
      return
    }
    guard arbor.harness.frame(window) == began else {
      // Moved as soon as the hand let go: that is this story.
      if column.byHand {
        tally.places += 1
        tally.fitted.append("\(width) wide at \(x),\(y): moved when the hand let go, to \(arbor.harness.frame(window)!.brief)")
      } else {
        tally.movedAtTheStart += 1
      }
      return
    }
    tally.places += 1
    let beganOnTheLaptop = began.intersection(Self.laptop).area * 2 >= began.area
    for (change, (name, line)) in [("closes", closed(column.order)), ("opens", open(column.order)), ("closes again", closed(column.order))].enumerated() {
      if withArbor {
        switch column.meanwhile {
        case .running: break
        case .paused: play(.command("pause"), .settle, on: arbor)
        case .quit: play(.command("quit"), on: arbor)
        case .crashed: play(.save, .crash, on: arbor)
        }
      }
      // Every change is judged by itself: both Macs go into it with the window in the same place. Or whatever differed after the last one, on purpose
      // or not, and whatever a pause or a quit does to a window, would be counted again as an echo.
      if arbor.harness.frame(window) != mac.harness.frame(window) { mac.system.moveSilently(window, to: arbor.harness.frame(window)!) }
      play(line, on: mac, arbor)
      if withArbor {
        switch column.meanwhile {
        case .running: break
        case .paused: play(.command("resume"), on: arbor)
        case .quit, .crashed: play(.launch, on: arbor)
        }
        play(.settle, on: arbor)
      }
      sabotage?(arbor)
      for command in ["", "home", "relayout"] {
        if !command.isEmpty, withArbor { play(.command(command), .settle, on: arbor) }
        let (with, without) = (arbor.harness.frame(window)!, mac.harness.frame(window)!)
        let place = "\(width) wide at \(x),\(y), the lid \(name)\(command.isEmpty ? "" : ", " + command): \(Int(with.minX)),\(Int(with.minY)), without Arbor \(Int(without.minX)),\(Int(without.minY))"
        let lidIsOpen = name == "opens"
        let leftByTheHand = began.offsetBy(dx: lidIsOpen ? 0 : -CGFloat(origin.x), dy: lidIsOpen ? 0 : -CGFloat(origin.y))
        // Or where it was found, which counts as left: Arbor fetched such a window at the start, when under half of it showed, until that was decided.
        if !beganOnTheLaptop, with == leftByTheHand, with != without {
          tally.whereTheHandLeftIt += 1
        } else if mac.system.isVisible(window), !arbor.system.isVisible(window) {
          tally.hidden.append(place)
        } else if mac.isReachable(without), !arbor.isReachable(with) {
          tally.outOfReach.append(place)
        } else if with != without {
          if lidIsOpen, beganOnTheLaptop, Self.laptop.overlaps(with) {
            tally.homeOnTheLaptop += 1
          } else if mac.system.displayList.contains(where: { $0.frame.contains(without) }) {
            tally.jumped.append(place)
            tally.jumpedAtEachChange[change] += 1
          } else {
            tally.fitted.append(place)
            tally.fittedAtEachChange[change] += 1
          }
        }
      }
      play([.advance(secondsBetweenChanges)], on: [mac, arbor])
    }
  }

  /// Along the big display from left of it to right of it, then from its top to its bottom.
  public func run() -> Tally {
    var tally = Tally()
    trouble.lines = []
    // Stamping and writing a line of the log for every step takes longer than the steps.
    Log.silenced {
      for width in widths {
        for x in Swift.stride(from: origin.x - width + margin, through: origin.x + Int(Self.big.width) - margin, by: stride) { look(at: x, origin.y + 300, width: width, into: &tally) }
        for y in Swift.stride(from: origin.y + margin, through: origin.y + Int(Self.big.height) - margin, by: stride) { look(at: origin.x + 500, y, width: width, into: &tally) }
      }
    }
    tally.trouble = trouble.lines
    return tally
  }

  /// One window through the lid, told stage by stage: where it is, which moves were Arbor's own, and on which display Arbor remembers it.
  public func story(x: Int, y: Int, width: Int = 600) -> [String] {
    trouble.lines = []
    let runner = Log.silenced { world(arbor: true, x: x, y: y, width: width) }
    func stage(_ name: String, _ actions: [ChaosAction]) -> String {
      let mark = runner.system.frameLog.count
      Log.silenced { play(actions + [.settle], on: [runner]) }
      let moves = runner.system.frameLog.dropFirst(mark).filter { $0.window == Self.window }.map { "\(Int($0.frame.minX)),\(Int($0.frame.minY))" }
      let home = runner.controller.workspaces.first { $0.value.floating[Self.window] != nil }
      let frame = runner.harness.frame(Self.window)!
      return "\(name): at \(Int(frame.minX)),\(Int(frame.minY)); Arbor's own moves: \(moves.isEmpty ? "none" : moves.joined(separator: " ")); "
        + "remembered \(home.map { "on \($0.key.rawValue) at \(Int($0.value.floating[Self.window]!.minX)),\(Int($0.value.floating[Self.window]!.minY))" } ?? "nowhere")"
    }
    let wait = ChaosAction.advance(secondsBetweenChanges)
    let stages = [
      stage("at the start", []), stage("the lid closes", ChaosAction.script(closed(column.order))), stage("the lid opens", [wait] + ChaosAction.script(open(column.order))),
      stage("⌃⌥0", [wait, .command("home")]),
    ]
    return stages + trouble.lines.map { "REFUSED: \($0)" }
  }
}
