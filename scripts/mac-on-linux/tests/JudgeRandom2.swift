import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// The second round: top edge, corners, edges taken anywhere, taller title bars, longer throws.
// An independent reviewer's random gestures: what the hand really did (by what became of the windows on the model) against what the layer reported. Many come out wrong, on any layer so
// far: this is a measure to hold two layers against each other, not a net. So it is told only when asked for:
//   make mac-on-linux ARGS='--only "judge2: R" --quiet' | grep -c "✔ it comes out right"        and the same with REF=origin/swarm/trunk

private struct Dice2 {
  var state: UInt64
  mutating func next() -> UInt64 {
    state &+= 0x9E37_79B9_7F4A_7C15
    var z = state
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    return z ^ (z >> 31)
  }
  mutating func int(_ n: Int) -> Int { Int(next() % UInt64(n)) }
  mutating func real(_ low: Double, _ high: Double) -> Double { low + (high - low) * Double(next() >> 11) / Double(1 << 53) }
  mutating func pick<T>(_ all: [T]) -> T { all[int(all.count)] }
}

@MainActor
func tellOfTheJudgesSecondRandomGestures(_ book: Book) {
  // Two are always told: real drags that `hold` once lost and the layer before it saw, a window that trails a hand going up.
  let asked = book.options.only.contains { $0.hasPrefix("judge2: R") }
  for seed in asked ? Array(1...4000) : [1048, 1746] {
    book.story("judge2: R \(seed)") { story in
      var dice = Dice2(state: UInt64(seed) &* 104729)
      let scene = dice.int(4)
      var window: FakeMac.Window!, other: FakeMac.Window?
      let tile = CGRect(x: 518, y: 43, width: 494, height: 600)
      let free = CGRect(x: CGFloat(dice.int(300) + 150), y: CGFloat(dice.int(150) + 90), width: CGFloat(dice.int(150) + 350), height: CGFloat(dice.int(150) + 250))
      let one = StoreyOne(story) { mac in
        switch scene {
        case 0: window = mac.open("window", in: mac.launch("Notes"), frame: free)
        case 1:
          other = mac.open("below", in: mac.launch("Safari"), frame: CGRect(x: 40, y: 60, width: 900, height: 600))
          window = mac.open("window", in: mac.launch("Notes"), frame: free)
        default:
          other = mac.open("neighbour", in: mac.launch("Safari"), frame: CGRect(x: 12, y: 43, width: 494, height: 600))
          window = mac.open("window", in: mac.launch("Notes"), frame: tile)
        }
      }
      let mac = one.mac
      let frame = window.bounds
      var start: CGPoint
      var place: String
      if scene == 3 {
        mac.pressShowDesktopKey()
        mac.pass(1)
        start = CGPoint(x: CGFloat(dice.int(1020) + 2), y: CGFloat(dice.int(700) + 40))
        place = "desktop shown"
      } else {
        window.titleBarHeight = dice.pick([32, 32, 52, 90])
        let (w, h) = (Int(frame.width), Int(frame.height))
        func jitter() -> CGFloat { CGFloat(dice.int(5)) - 2 }
        switch dice.int(12) {
        case 0, 1, 2, 3:
          start = CGPoint(x: frame.minX + 12 + CGFloat(dice.int(w - 24)), y: frame.minY + 5 + CGFloat(dice.int(Int(window.titleBarHeight) - 6)))
          place = "title bar of \(Int(window.titleBarHeight)), \(Int(start.y - frame.minY)) down"
        case 4: (start, place) = (CGPoint(x: frame.minX + jitter(), y: frame.minY + 8 + CGFloat(dice.int(h - 16))), "left edge")
        case 5: (start, place) = (CGPoint(x: frame.maxX + jitter(), y: frame.minY + 8 + CGFloat(dice.int(h - 16))), "right edge")
        case 6: (start, place) = (CGPoint(x: frame.minX + 30 + CGFloat(dice.int(w - 60)), y: frame.maxY + jitter()), "bottom edge")
        case 7: (start, place) = (CGPoint(x: frame.minX + 30 + CGFloat(dice.int(w - 60)), y: frame.minY + jitter()), "top edge")
        case 8:
          let (left, top) = (dice.int(2) == 0, dice.int(2) == 0)
          (start, place) = (CGPoint(x: (left ? frame.minX : frame.maxX) + jitter(), y: (top ? frame.minY : frame.maxY) + jitter()), "\(top ? "top" : "bottom") \(left ? "left" : "right") corner")
        case 9, 10: (start, place) = (CGPoint(x: frame.minX + 12 + CGFloat(dice.int(w - 24)), y: frame.minY + window.titleBarHeight + 3 + CGFloat(dice.int(h - Int(window.titleBarHeight) - 18))), "content")
        default: (start, place) = (CGPoint(x: CGFloat(dice.int(1000) + 10), y: CGFloat(dice.int(60) + 690)), "wallpaper")
        }
      }
      let lateness = dice.int(14)
      var late = "on time"
      switch lateness {
      case 0, 1: break
      case 2...5:
        let by = [0.05, 0.1, 0.3, 0.5][lateness - 2]
        mac.mouseDownIsLateBy = by
        late = "press \(by) late"
      default:
        let length = [0.1, 0.3, 0.5][(lateness - 6) % 3]
        let order = dice.pick([FakeMac.Backlog.byTime, .accessibilityFirst, .mouseFirst])
        mac.arborIsBusy(for: length, then: order)
        late = "busy \(length) \(order)"
      }
      mac.serverFollowsPointerAfter = dice.pick([0, 0, 0, 0, 0.1, 0.4])
      mac.serverLagsPointerBy = dice.pick([0, 0, 0, 0, 0.05, 0.1])
      window.app.isSilentDuringDrags = dice.int(6) == 0
      mac.serverRunsAStepAhead = dice.int(10) == 0
      let manners = "starts \(mac.serverFollowsPointerAfter) lags \(mac.serverLagsPointerBy)\(window.app.isSilentDuringDrags ? " silent" : "")\(mac.serverRunsAStepAhead ? " ahead" : "")"
      one.heard.clear()
      let before = [window.bounds, other?.bounds ?? .zero]

      func clamp(_ point: CGPoint) -> CGPoint { CGPoint(x: min(max(point.x, 2), 1022), y: min(max(point.y, 3), 765)) }
      let angle = dice.real(0, 2 * .pi)
      let distance = dice.real(30, 700)
      let end = clamp(CGPoint(x: (start.x + CGFloat(cos(angle) * distance)).rounded(), y: (start.y + CGFloat(sin(angle) * distance)).rounded()))
      mac.drag(from: start, to: end, steps: dice.int(11) + 2, interval: dice.real(0.01, 0.08), rest: dice.real(0, 0.15))
      mac.pass(dice.pick([0, 0, 0.1, 0.3, 0.6]))
      var last = end
      if dice.int(2) == 0 {
        let turn = angle + dice.real(-1, 1)
        let more = dice.real(30, 200)
        last = clamp(CGPoint(x: (end.x + CGFloat(cos(turn) * more)).rounded(), y: (end.y + CGFloat(sin(turn) * more)).rounded()))
        let steps = dice.int(6) + 3
        for step in 1...steps {
          mac.moveMouse(to: CGPoint(x: end.x + (last.x - end.x) * CGFloat(step) / CGFloat(steps), y: end.y + (last.y - end.y) * CGFloat(step) / CGFloat(steps)))
          mac.pass(0.06)
        }
        mac.pass(dice.pick([0, 0.1, 0.3]))
      }
      mac.release()
      mac.pass(0.5)
      if mac.sweptTo != nil { mac.pressShowDesktopKey() }
      mac.pass(3)

      let after = [window.bounds, other?.bounds ?? .zero]
      var truth = "nothing"
      for (index, number) in [window.number, other?.number ?? 0].enumerated() where before[index] != after[index] {
        truth = (before[index].size != after[index].size ? "resize" : "drag") + " w\(number)"
      }
      var heard: [String] = []
      for event in one.heard.all {
        switch event {
        case .dragBegan(let id): heard.append("drag w\(id)")
        case .resizeBegan(let id): heard.append("resize w\(id)")
        default: break
        }
      }
      let ended = one.heard.all.filter { if case .dragEnded = $0 { true } else if case .resizeEnded = $0 { true } else { false } }.count
      let made = heard.isEmpty ? "nothing" : heard.joined(separator: "+")
      let right = made == truth && ended == heard.count
      let kind = right ? "right" : made == "nothing" ? "LOST" : truth == "nothing" ? "FALSE" : "WRONG"
      story.check("it comes out right", right, "\(kind) | truth \(truth) | heard \(made), \(ended) ended | scene \(scene) \(place) \(Int(start.x)),\(Int(start.y)) to \(Int(end.x)),\(Int(end.y)) to \(Int(last.x)),\(Int(last.y)) | \(late) | \(manners)")
    }
  }
}
