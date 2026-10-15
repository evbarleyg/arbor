import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics

// Displays that change, one step at a time (`displays <n>` and `display-size` in main.swift are the short forms):
//
//   plug <name> [right|left|above|below] [WxH]
//                                plug in a display beside the first one (to its right, 2560x1440), or replace the one of that name
//   unplug <name>                unplug it (the first display is `main`). If it was the main one, the next becomes main and its
//                                corner 0,0: every display, window and the pointer has new coordinates, and no window says so
//   make-main <name>             that display gets the menu bar (a lid closes or opens): the same silent shift
//   move-display <name> <x> <y>  rearranged in System Settings: its windows go with it, silently
//   quietly <one of the above>   macOS has other displays now and Arbor has not been told: on a Mac it hears only once they have
//                                settled (`DisplayChange`), and what apps report meanwhile comes first
//   report-displays              now it is told
//   max <id> <WxH>               from now on the app keeps the window no larger, and makes it smaller itself if it is larger
//   where <id>                   the window's real frame, and how much of it shows on the displays

/// Runs the lines above. Nil for any other line.
@MainActor
func simulateDisplays(_ words: [String], harness: Harness) -> (String, Bool)? {
  let system = harness.system
  func usage(_ text: String) -> (String, Bool) { ("usage: \(text)", false) }
  /// Bounded like the numbers in commands: real displays are never at infinity.
  func number(_ text: some StringProtocol) -> Double? { Double(text).flatMap { abs($0) <= 1_000_000 ? $0 : nil } }
  func size(_ text: String) -> CGSize? {
    let parts = text.lowercased().split(separator: "x").compactMap(number).filter { $0 >= 1 }
    return parts.count == 2 ? CGSize(width: parts[0], height: parts[1]) : nil
  }
  func display(_ index: Int) -> DisplaySnapshot? {
    words.count > index ? system.displayList.first { $0.id.rawValue == words[index] } : nil
  }
  var names: String { system.displayList.map(\.id.rawValue).joined(separator: ", ") }

  switch words[0] {
  case "quietly":
    let text = "quietly plug|unplug|make-main|move-display …"
    guard words.count > 1, ["plug", "unplug", "make-main", "move-display"].contains(words[1]) else { return usage(text) }
    let listener = system.events
    system.events = nil
    defer { system.events = listener }
    return simulateDisplays(Array(words.dropFirst()), harness: harness)
  case "report-displays":
    system.setDisplays(system.displayList)
    return ("reported \(system.displayList.count) display(s)", true)
  case "plug":
    guard words.count > 1 else { return usage("plug <name> [right|left|above|below] [WxH]") }
    let first = system.displayList.first?.frame ?? .zero
    let extent = words.dropFirst(2).compactMap(size).first ?? CGSize(width: 2560, height: 1440)
    var origin = CGPoint(x: first.maxX, y: first.minY)
    if words.contains("left") { origin.x = first.minX - extent.width }
    if words.contains("above") { origin = CGPoint(x: first.minX, y: first.minY - extent.height) }
    if words.contains("below") { origin = CGPoint(x: first.minX, y: first.maxY) }
    let frame = CGRect(origin: origin, size: extent)
    system.plug(DisplaySnapshot(id: DisplayID(words[1]), frame: frame, visibleFrame: frame, isMain: system.displayList.isEmpty))
    return ("plugged in \(words[1]) at \(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))", true)
  case "unplug":
    guard let leaving = display(1) else { return usage("unplug <name> (one of \(names))") }
    system.unplug(leaving.id)
    return ("unplugged \(words[1])", true)
  case "make-main":
    guard words.count == 2, let chosen = display(1) else { return usage("make-main <name> (one of \(names))") }
    system.makeMain(chosen.id)
    return ("\(words[1]) is the main display", true)
  case "move-display":
    guard words.count == 4, let moving = display(1), let x = number(words[2]), let y = number(words[3]) else {
      return usage("move-display <name> <x> <y> (one of \(names))")
    }
    system.moveDisplay(moving.id, to: CGPoint(x: x, y: y))
    return ("moved \(words[1]) to \(words[2]),\(words[3])", true)
  case "max":
    guard words.count == 3, let id = WindowID(word: words[1]), var frame = system.frame(of: id), let most = size(words[2]) else {
      return usage("max <id> <WxH>")
    }
    system.setMaximumSize(id, most)
    let old = frame
    // The top-left corner stays, as when an app resizes its own window.
    frame.size = CGSize(width: min(frame.width, most.width), height: min(frame.height, most.height))
    if frame != old { system.userMove(id, to: frame) }
    return ("\(id.rawValue) is at most \(words[2])", true)
  case "where":
    guard words.count == 2, let id = WindowID(word: words[1]), let frame = system.frame(of: id) else { return usage("where <id>") }
    let showing = frame.area > 0 ? frame.areaShowing(on: system.displayList.map(\.frame)) / frame.area : 0
    let place = "\(Int(frame.minX)),\(Int(frame.minY)) \(Int(frame.width))x\(Int(frame.height))"
    return ("\(id.rawValue) is at \(place), \(Int((showing * 100).rounded())) % of it on a display", true)
  default:
    return nil
  }
}
