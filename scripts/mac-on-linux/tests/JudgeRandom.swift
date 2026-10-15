import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// An independent reviewer's random gestures: what the hand really did (by what became of the windows on the model) against what the layer reported. Many come out wrong, on any layer so
// far: this is a measure to hold two layers against each other, not a net. So it is told only when asked for:
//   make mac-on-linux ARGS='--only "judge: R" --quiet' | grep -c "✔ it comes out right"        and the same with REF=origin/swarm/trunk

private struct Dice {
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
func tellOfTheJudgesRandomGestures(_ book: Book) {
  guard book.options.only.contains(where: { $0.hasPrefix("judge: R") }) else { return }
  for seed in 1...4000 {
    book.story("judge: R \(seed)") { story in
      var dice = Dice(state: UInt64(seed) &* 7919)
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
        switch dice.int(8) {
        case 0, 1, 2:
          start = CGPoint(x: frame.minX + 12 + CGFloat(dice.int(Int(frame.width) - 24)), y: frame.minY + 5 + CGFloat(dice.int(20)))
          place = "title bar"
        case 3: (start, place) = (CGPoint(x: frame.minX + CGFloat(dice.int(5)) - 2, y: frame.minY + 40 + CGFloat(dice.int(Int(frame.height) - 60))), "left edge")
        case 4: (start, place) = (CGPoint(x: frame.maxX + CGFloat(dice.int(5)) - 2, y: frame.minY + 40 + CGFloat(dice.int(Int(frame.height) - 60))), "right edge")
        case 5: (start, place) = (CGPoint(x: frame.minX + 30 + CGFloat(dice.int(Int(frame.width) - 60)), y: frame.maxY + CGFloat(dice.int(5)) - 2), "bottom edge")
        case 6: (start, place) = (CGPoint(x: frame.minX + 12 + CGFloat(dice.int(Int(frame.width) - 24)), y: frame.minY + 35 + CGFloat(dice.int(Int(frame.height) - 50))), "content")
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
      let distance = dice.real(30, 450)
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
