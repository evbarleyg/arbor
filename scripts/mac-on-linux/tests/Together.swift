import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Several windows get their frames in one act (`moveTogether`): their apps are asked side by side, and Arbor waits for the slowest instead of for one after the other.
//
// How long real apps take to answer one `setFrame` is in the recordings of whole days on hosted Macs: 4 to 60 ms as a rule, up to 150; one after the other, 185 ms for a layout of
// seven as a rule and up to 482. That the calls may be made from several threads at once was tried there as well, with windows of four processes.

private func isByUser(_ event: Heard) -> Bool { if case .changed(_, byUser: true) = event { true } else { false } }

/// Three apps: the first with two windows, the others with one. Each call to any of them takes `answersIn`.
@MainActor
private func stage(_ story: Story, answersIn: TimeInterval? = nil) -> (StoreyOne, [FakeMac.Window]) {
  var windows: [FakeMac.Window] = []
  let one = StoreyOne(story) { mac in
    let first = mac.launch("First")
    windows = [
      mac.open("a", in: first, frame: CGRect(x: 40, y: 60, width: 300, height: 300)),
      mac.open("b", in: first, frame: CGRect(x: 60, y: 80, width: 300, height: 300)),
      mac.open("c", in: mac.launch("Second"), frame: CGRect(x: 80, y: 100, width: 300, height: 300)),
      mac.open("d", in: mac.launch("Third"), frame: CGRect(x: 100, y: 120, width: 300, height: 300)),
    ]
  }
  for window in windows { window.app.answersIn = answersIn }
  one.heard.clear()
  return (one, windows)
}

/// A quarter of the screen for each.
private let quarters = [
  CGRect(x: 12, y: 43, width: 500, height: 300), CGRect(x: 520, y: 43, width: 480, height: 300), CGRect(x: 12, y: 350, width: 500, height: 300),
  CGRect(x: 520, y: 350, width: 480, height: 300),
]

@MainActor
private func forecast(_ windows: [FakeMac.Window], _ frames: [CGRect] = quarters) -> [(window: WindowID, frame: CGRect)] {
  zip(windows, frames).map { (WindowID($0.number), $1) }
}

@MainActor
private func places(_ windows: [FakeMac.Window]) -> String { windows.map { "w\($0.number) \($0.frame.text)" }.joined(separator: "; ") }

@MainActor
func tellOfMovingTogether(_ book: Book) {
  book.story("four windows of three slow apps are moved together") { story in
    // What it costs one after the other, on a Mac of its own.
    let (apart, others) = stage(story, answersIn: 0.01)
    var began = apart.mac.now
    for (window, frame) in forecast(others) { _ = apart.layer.setFrame(frame, of: window) }
    let oneByOne = apart.mac.now - began

    let (one, windows) = stage(story, answersIn: 0.01)
    began = one.mac.now
    one.layer.moveTogether(forecast(windows))
    let together = one.mac.now - began
    story.check("they are where they belong when the call returns", zip(windows, quarters).allSatisfy { $0.frame == $1 }, places(windows))
    story.check(
      "Arbor has waited for the app with two windows, and not for all three", together < oneByOne * 0.55 && together >= oneByOne * 0.45,
      "\(together) s against \(oneByOne) s one by one")
    story.check("nothing is reported before the call returns", one.heard.all.isEmpty, one.heard.texts)
    let calls = one.mac.calls, now = one.mac.now
    let answers = forecast(windows).map { one.layer.setFrame($0.frame, of: $0.window) }
    story.check("each setFrame that follows is answered with the frame the window took", answers == quarters, "\(answers)")
    story.check("and asks no app anything", one.mac.calls == calls && one.mac.now == now, "\(one.mac.calls - calls) calls")
    story.check("the layer knows where they are", zip(windows, quarters).allSatisfy { one.snapshot($0)?.frame == $1 })
    one.mac.pass(1)
    story.check("the apps' reports follow, and count as echoes", !one.heard.all.isEmpty && !one.heard.all.contains(where: isByUser), one.heard.texts)
  }

  book.story("the windows of one app are moved in the order foretold") { story in
    let (one, windows) = stage(story)
    var order: [UInt32] = []
    one.heard.onEvent = { if let window = $0.window, !order.contains(window) { order.append(window) } }
    let foretold = forecast([windows[1], windows[2], windows[0]])
    one.layer.moveTogether(foretold)
    for (window, frame) in foretold { _ = one.layer.setFrame(frame, of: window) }
    one.mac.pass(1)
    let ofTheFirst = order.filter { $0 == windows[0].number || $0 == windows[1].number }
    story.check("b before a", ofTheFirst == [windows[1].number, windows[0].number], "\(order)")
  }

  book.story("windows of one app alone are foretold") { story in
    let (one, windows) = stage(story)
    let calls = one.mac.calls
    one.layer.moveTogether(forecast(Array(windows[0...1])))
    story.check("nothing is asked ahead: there is nobody to work beside", one.mac.calls == calls, "\(one.mac.calls - calls) calls")
    story.check("setFrame moves them as always", forecast(Array(windows[0...1])).allSatisfy { one.layer.setFrame($0.frame, of: $0.window) == $0.frame }, places(windows))
  }

  book.story("a layer that is told to ask one by one is foretold moves") { story in
    var windows: [FakeMac.Window] = []
    let one = StoreyOne(story, layer: AXWindowSystem(oneByOne: true)) { mac in
      windows = (0..<3).map { mac.open("w\($0)", in: mac.launch("App \($0)"), frame: CGRect(x: 40 + 20 * CGFloat($0), y: 60, width: 300, height: 300)) }
    }
    let calls = one.mac.calls
    one.layer.moveTogether(forecast(windows))
    story.check("nothing is asked ahead", one.mac.calls == calls, "\(one.mac.calls - calls) calls")
    story.check("setFrame moves them as always", forecast(windows).allSatisfy { one.layer.setFrame($0.frame, of: $0.window) == $0.frame }, places(windows))
  }

  book.story("a window is foretold one frame and asked for another") { story in
    let (one, windows) = stage(story)
    one.layer.moveTogether(forecast(windows))
    let other = CGRect(x: 200, y: 200, width: 420, height: 320)
    story.check("the layer answers with the other", one.layer.setFrame(other, of: WindowID(windows[2].number)) == other)
    story.check("the window has it", windows[2].frame == other, windows[2].frame.text)
    story.check("asked for the foretold frame after all, it moves the window there", one.layer.setFrame(quarters[2], of: WindowID(windows[2].number)) == quarters[2] && windows[2].frame == quarters[2], windows[2].frame.text)
    one.mac.pass(1)
    story.check("nothing of it counts as the person's doing", !one.heard.all.contains(where: isByUser), one.heard.texts)
  }

  book.story("a window is foretold two frames at once") { story in
    let (one, windows) = stage(story)
    let later = CGRect(x: 200, y: 200, width: 420, height: 320)
    one.layer.moveTogether(forecast(windows) + [(WindowID(windows[2].number), later)])
    story.check("it has the first", windows[2].frame == quarters[2], windows[2].frame.text)
    story.check("the first setFrame is answered with it", one.layer.setFrame(quarters[2], of: WindowID(windows[2].number)) == quarters[2])
    story.check("the second moves it", one.layer.setFrame(later, of: WindowID(windows[2].number)) == later && windows[2].frame == later, windows[2].frame.text)
  }

  book.story("moves are foretold and nobody asks for them") { story in
    let (one, windows) = stage(story)
    // So that nothing but the layer itself can have spoken.
    for window in windows { window.app.reportsLateBy = 0.5 }
    one.layer.moveTogether(forecast(windows))
    _ = one.layer.setFrame(quarters[0], of: WindowID(windows[0].number))
    story.check("nothing is reported as long as they may still be asked for", one.heard.all.isEmpty, one.heard.texts)
    one.mac.pass(0.0001)
    story.check(
      "as soon as whoever foretold them is done, the three that were not asked for are reported where they are, as Arbor's own doing",
      one.heard.all == windows[1...].map { .changed($0.number, byUser: false) } && zip(windows, quarters).dropFirst().allSatisfy { one.heard.latest[$0.number]?.frame == $1 },
      one.heard.texts)
    one.mac.pass(2)
    one.heard.clear()
    one.layer.moveTogether([])
    one.mac.pass(1)
    story.check("once", one.heard.all.isEmpty, one.heard.texts)
  }

  book.story("moves are foretold, nobody asks for them, and more are foretold at once") { story in
    let (one, windows) = stage(story)
    for window in windows { window.app.reportsLateBy = 0.5 }
    one.layer.moveTogether(forecast(windows))
    one.layer.moveTogether([])
    story.check("nothing is reported from inside the call: whoever foretells is in the middle of a layout", one.heard.all.isEmpty, one.heard.texts)
    let calls = one.mac.calls
    _ = one.layer.setFrame(quarters[0], of: WindowID(windows[0].number))
    story.check("the first forecast's answers are not given any more: the app is asked", one.mac.calls > calls)
    one.mac.pass(0.0001)
    story.check("afterwards all four are reported where they are", one.heard.all == windows.map { .changed($0.number, byUser: false) }, one.heard.texts)
  }

  book.story("one app of three hangs while they are moved together, and nobody asks what came of it") { story in
    let (one, windows) = stage(story)
    // Later than the second the hang takes, so that nothing but the layer itself can have spoken.
    for window in windows { window.app.reportsLateBy = 2 }
    one.mac.hang(windows[0].app)
    one.layer.moveTogether(forecast(windows))
    one.mac.pass(0.0001)
    story.check(
      "the others are reported where they are, the app's windows not: a report would say that it answers",
      one.heard.all == windows[2...].map { .changed($0.number, byUser: false) }, one.heard.texts)
  }

  book.story("a move is foretold, nobody asks for it, and the window's app takes it elsewhere") { story in
    let (one, windows) = stage(story)
    one.layer.moveTogether(forecast(windows))
    one.mac.pass(1)
    one.mac.appMoves(windows[2], to: CGRect(x: 300, y: 300, width: 300, height: 300))
    one.mac.pass(1)
    let calls = one.mac.calls
    story.check(
      "asked for the frame that was foretold, the layer asks the app, and the window goes there",
      one.layer.setFrame(quarters[2], of: WindowID(windows[2].number)) == quarters[2] && one.mac.calls > calls && windows[2].frame == quarters[2], windows[2].frame.text)
  }

  book.story("one app of three hangs while they are moved together") { story in
    let (one, windows) = stage(story)
    one.mac.hang(windows[0].app)
    let began = one.mac.now
    one.layer.moveTogether(forecast(windows))
    story.check("Arbor waits for one call, a second, and not once for each of the app's windows", abs(one.mac.now - began - 1) < 0.02, "\(one.mac.now - began) s")
    story.check("the others are where they belong", zip(windows, quarters).dropFirst(2).allSatisfy { $0.frame == $1 }, places(windows))
    let now = one.mac.now
    let answers = forecast(windows).map { one.layer.setFrame($0.frame, of: $0.window) }
    story.check("of the app's windows the layer says that it does not know what came of it", answers[0] == nil && answers[1] == nil, "\(answers)")
    story.check("of the others, where they are", Array(answers[2...]) == Array(quarters[2...]), "\(answers)")
    story.check("and nothing waits for the app again", one.mac.now == now, "\(one.mac.now - now) s")
    one.mac.pass(3)
    one.heard.clear()
    one.mac.wake(windows[0].app)
    one.mac.pass(1)
    story.check(
      "once it wakes both its windows are reported, so that they can be placed",
      one.heard.all.contains(.changed(windows[0].number, byUser: true)) && one.heard.all.contains(.changed(windows[1].number, byUser: true)), one.heard.texts)
    story.check("and can be moved again", one.layer.setFrame(quarters[1], of: WindowID(windows[1].number)) == quarters[1])
  }

  book.story("two apps of three hang while they are moved together") { story in
    let (one, windows) = stage(story)
    one.mac.hang(windows[0].app)
    one.mac.hang(windows[2].app)
    let began = one.mac.now
    one.layer.moveTogether(forecast(windows))
    story.check("Arbor waits one second for both, where it used to wait two", abs(one.mac.now - began - 1) < 0.02, "\(one.mac.now - began) s")
    story.check("the third is where it belongs", windows[3].frame == quarters[3], places(windows))
  }

  book.story("an app is gone, unannounced, when it is to be moved with others that are slow") { story in
    let (one, windows) = stage(story)
    // Slow enough that the batch as a whole lasts longer than it takes to call an app hung.
    windows[0].app.answersIn = 0.1
    one.mac.quit(windows[2].app, announced: false)
    one.layer.moveTogether(forecast(windows))
    one.mac.pass(1)
    story.check(
      "its window is reported gone: it failed at once, however long the others took", one.heard.all.contains(.destroyed(windows[2].number)), one.heard.texts)
  }

  book.story("the permission is taken away before windows are moved together") { story in
    let (one, windows) = stage(story)
    one.mac.isTrusted = false
    one.layer.moveTogether(forecast(windows))
    story.check("Arbor hears that it was refused", one.heard.all.contains(.refused), one.heard.texts)
    story.check("no app is taken for hung or gone", !one.heard.all.contains { if case .destroyed = $0 { true } else { false } }, one.heard.texts)
    story.check("the layer does not say that a window took its frame", forecast(windows).allSatisfy { one.layer.setFrame($0.frame, of: $0.window) == nil })
    one.mac.isTrusted = true
    story.check("given back, the windows move again", forecast(windows).allSatisfy { one.layer.setFrame($0.frame, of: $0.window) == $0.frame }, places(windows))
  }

  book.story("an app with the enhanced user interface on is moved with others") { story in
    let (one, windows) = stage(story)
    windows[0].app.hasEnhancedUserInterface = true
    one.layer.moveTogether(forecast(windows))
    story.check("its windows are where they belong", zip(windows, quarters).prefix(2).allSatisfy { $0.frame == $1 }, places(windows))
    story.check("and it has it on again", windows[0].app.hasEnhancedUserInterface)
  }

  book.story("a window will not take the size it is foretold") { story in
    let (one, windows) = stage(story)
    windows[3].minimumSize = CGSize(width: 600, height: 400)
    one.layer.moveTogether(forecast(windows))
    let answer = one.layer.setFrame(quarters[3], of: WindowID(windows[3].number))
    story.check("the setFrame that follows says what it took", answer == windows[3].frame && answer?.size == CGSize(width: 600, height: 400), "\(answer?.text ?? "nothing")")
  }

  book.story("Arbor is paused and resumed in one go, with answers nobody has asked for") { story in
    let (one, windows) = stage(story)
    one.layer.moveTogether(forecast(windows))
    one.layer.stop()
    one.mac.changeSilently(windows[2], to: CGRect(x: 300, y: 300, width: 300, height: 300))
    one.layer.start()
    let calls = one.mac.calls
    story.check(
      "it asks the app, and the window moves",
      one.layer.setFrame(quarters[2], of: WindowID(windows[2].number)) == quarters[2] && one.mac.calls > calls && windows[2].frame == quarters[2], windows[2].frame.text)
  }

  // They have to grow, which each is asked where it stands, all of them in one forecast; then they go to their places, in another (Controller+AskFirst.swift). Windows that
  // have to become smaller than they were ever seen are asked one at a time, on purpose, and gain nothing here until they are moved.
  for count in [4, 8] {
    book.story("\(count) small windows of \(count) slow apps are arranged") { story in
      var windows: [FakeMac.Window] = []
      let two = StoreyTwo(story) { mac in
        windows = (0..<count).map { mac.open("w\($0)", in: mac.launch("App \($0)"), frame: CGRect(x: 40 + 20 * CGFloat($0), y: 60 + 20 * CGFloat($0), width: 200, height: 150)) }
      }
      for window in windows { window.app.answersIn = 0.005 }
      let began = two.mac.now, calls = two.mac.calls
      let result = two.controller.perform(.arrange)
      let took = two.mac.now - began
      story.check("they are arranged", result.ok && windows.allSatisfy { two.isDocked($0) })
      // Twelve calls to a window, 5 ms each: 60 ms for one, 240 and 480 ms for all of them one after the other.
      story.check("in little more than it takes one of them", took < 0.06 * 2, "\(took) s, \(two.mac.calls - calls) calls")
      two.mac.pass(2)
      story.check("and stay docked", windows.allSatisfy { two.isDocked($0) })
    }
  }
}
