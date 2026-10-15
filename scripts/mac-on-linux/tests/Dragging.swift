import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// The mouse: drags by the title bar, resizes by an edge, presses on Arbor's own panels.
//
// The window server moves a dragged window itself and knows its place at once. The app learns of it about a tenth of a second later and posts eight to ten
// "moved" a second; some apps post none until the drag is over (traces `drag-to-edge`, `flick-to-edge`).

@MainActor
private func stage(_ story: Story) -> (StoreyOne, FakeMac.Window, FakeMac.Window) {
  var window: FakeMac.Window!, other: FakeMac.Window!
  let one = StoreyOne(story) { mac in
    let app = mac.launch("Notes")
    other = mac.open("other", in: app, frame: CGRect(x: 600, y: 400, width: 300, height: 200))
    window = mac.open("window", in: app, frame: CGRect(x: 100, y: 100, width: 400, height: 300))
  }
  return (one, window, other)
}

private let grip = CGPoint(x: 300, y: 112)

@MainActor
func tellOfDragging(_ book: Book) {
  for silent in [false, true] {
    for release in [FakeMac.Release.seen, .seenTwice] {
      let words = (silent ? ", and its app says nothing until it is over" : "") + (release == .seenTwice ? ", the release heard twice" : "")
      book.story("a window is dragged by its title bar\(words)") { story in
        let (one, window, _) = stage(story)
        window.app.isSilentDuringDrags = silent
        one.mac.drag(from: grip, to: CGPoint(x: 500, y: 262))
        story.check("the drag is reported to begin, once", one.heard.all.filter { $0 == .dragBegan(window.number) }.count == 1, one.heard.texts)
        story.check("and to go on", one.heard.all.filter { $0 == .dragMoved(window.number) }.count >= 5, one.heard.texts)
        story.check("it is not taken for a resize", !one.heard.all.contains(.resizeBegan(window.number)))
        one.mac.release(release)
        one.mac.pass(0.01)
        story.check("at the release the drag is reported to end", one.heard.outline.last == .dragEnded(window.number), one.heard.texts)
        story.check(
          "Arbor has the place the window was left at, though its app may not have heard yet",
          one.snapshot(window)?.frame == CGRect(x: 300, y: 250, width: 400, height: 300), "\(one.snapshot(window)?.frame.text ?? "")")
        one.mac.pass(3)
        story.check(
          "it ends once, and is not cancelled",
          one.heard.all.filter { $0 == .dragEnded(window.number) }.count == 1 && !one.heard.all.contains(.dragCancelled(window.number)),
          one.heard.texts)
        story.check("nothing begins afterwards", one.heard.outline.last == .dragEnded(window.number), one.heard.texts)
        story.check("and the frame is still right", one.snapshot(window)?.frame == window.frame, "\(one.snapshot(window)?.frame.text ?? "")")
      }
    }
  }

  // After a quick flick the last frame the app reported was 170 points behind.
  book.story("a window is flicked and let go at once") { story in
    let (one, window, _) = stage(story)
    one.mac.drag(from: grip, to: CGPoint(x: 700, y: 400), steps: 4, interval: 0.03)
    one.mac.release()
    one.mac.pass(0.005)
    story.check("the drag began and ended", one.heard.outline == [.dragBegan(window.number), .dragEnded(window.number)], one.heard.texts)
    story.check("the app is still behind", window.frame != window.bounds)
    story.check(
      "Arbor goes by the window server", one.snapshot(window)?.frame == window.bounds,
      "\(one.snapshot(window)?.frame.text ?? "") against \(window.bounds.text)")
    one.mac.pass(2)
    story.check(
      "the reports that trickle in afterwards start no second drag", one.heard.outline == [.dragBegan(window.number), .dragEnded(window.number)],
      one.heard.texts)
    story.check(
      "and leave the frame right", one.snapshot(window)?.frame == window.bounds,
      "\(one.snapshot(window)?.frame.text ?? "") against \(window.bounds.text)")
  }

  // Another tool's event tap can swallow the release, or it goes to a window of Arbor's own.
  book.story("a window is dragged and the release is never heard") { story in
    let (one, window, _) = stage(story)
    one.mac.drag(from: grip, to: CGPoint(x: 500, y: 262))
    one.mac.release(.lost)
    one.mac.pass(0.4)
    story.check(
      "for a moment the drag counts as going on",
      !one.heard.all.contains(.dragCancelled(window.number)) && !one.heard.all.contains(.dragEnded(window.number)), one.heard.texts)
    one.mac.pass(1.5)
    story.check(
      "then it is called off: nobody knows where the window was meant to go", one.heard.outline.last == .dragCancelled(window.number),
      one.heard.texts)
    story.check("Arbor has the window's frame", one.snapshot(window)?.frame == window.frame, "\(one.snapshot(window)?.frame.text ?? "")")
  }

  book.story("a window is dragged, the release is never heard, and the button goes down again at once") { story in
    let (one, window, other) = stage(story)
    one.mac.drag(from: grip, to: CGPoint(x: 500, y: 262))
    one.mac.release(.lost)
    one.mac.pass(0.1)
    one.mac.press(at: CGPoint(x: other.frame.midX, y: other.frame.midY))
    one.mac.pass(0.05)
    story.check("a button cannot go down twice: the drag is called off", one.heard.all.contains(.dragCancelled(window.number)), one.heard.texts)
    one.mac.release()
    one.mac.pass(2)
    story.check(
      "once, and it does not end as well",
      one.heard.all.filter { $0 == .dragCancelled(window.number) }.count == 1 && !one.heard.all.contains(.dragEnded(window.number)), one.heard.texts)
  }

  book.story("a press and a release on a title bar, without moving") { story in
    let (one, window, _) = stage(story)
    one.mac.press(at: grip)
    one.mac.pass(0.12)
    one.mac.release(.seenTwice)
    one.mac.pass(2)
    story.check("nothing is reported but the press", one.heard.all == [.pressed], one.heard.texts)
    _ = window
  }

  // Trace `drag-onto-window`: pressing on a window that has not got the keyboard reports the focus first.
  book.story("a window that has not got the keyboard is dragged") { story in
    let (one, _, other) = stage(story)
    one.mac.drag(from: CGPoint(x: other.frame.midX, y: other.frame.minY + 10), to: CGPoint(x: 400, y: 500))
    one.mac.release()
    one.mac.pass(1)
    story.check(
      "it is reported focused, then dragged", one.heard.outline == [.focused(other.number), .dragBegan(other.number), .dragEnded(other.number)],
      one.heard.texts)
  }

  book.story("a window of an app that hangs is dragged") { story in
    let (one, window, _) = stage(story)
    one.mac.hang(window.app)
    one.mac.drag(from: grip, to: CGPoint(x: 500, y: 262))
    story.check(
      "the window server moves it all the same, and the drag is reported", one.heard.all.contains(.dragBegan(window.number)), one.heard.texts)
    one.mac.release()
    one.mac.pass(0.1)
    story.check("and ends", one.heard.all.contains(.dragEnded(window.number)), one.heard.texts)
    story.check("Arbor has the place it was left at", one.snapshot(window)?.frame == window.bounds, "\(one.snapshot(window)?.frame.text ?? "")")
    story.check("and did not wait for the app", one.mac.secondsWaitedInVain <= 1, "\(one.mac.secondsWaitedInVain) s")
  }

  book.story("the window that is being dragged closes") { story in
    let (one, window, _) = stage(story)
    one.mac.drag(from: grip, to: CGPoint(x: 500, y: 262))
    one.mac.close(window)
    one.mac.pass(0.5)
    story.check("it is reported gone", one.heard.all.contains(.destroyed(window.number)), one.heard.texts)
    one.heard.clear()
    one.mac.moveMouse(to: CGPoint(x: 520, y: 270))
    one.mac.pass(0.1)
    one.mac.release()
    one.mac.pass(2)
    story.check("and nothing more is said about it", one.heard.about(window).isEmpty, one.heard.texts)
  }

  // Trace `edge-resize`.
  for edge in ["right", "left", "bottom"] {
    book.story("a window is resized by its \(edge) edge") { story in
      let (one, window, _) = stage(story)
      let start = edge == "right" ? CGPoint(x: 500, y: 250) : edge == "left" ? CGPoint(x: 100, y: 250) : CGPoint(x: 300, y: 400)
      let end = edge == "bottom" ? CGPoint(x: 300, y: 460) : CGPoint(x: start.x + 60, y: 250)
      one.mac.drag(from: start, to: end, steps: 8)
      story.check("the resize is reported to begin, once", one.heard.all.filter { $0 == .resizeBegan(window.number) }.count == 1, one.heard.texts)
      story.check("it is not taken for a drag", !one.heard.all.contains(.dragBegan(window.number)), one.heard.texts)
      one.mac.release()
      one.mac.pass(1)
      story.check(
        "at the release it is reported to end", one.heard.outline == [.resizeBegan(window.number), .resizeEnded(window.number)], one.heard.texts)
      story.check(
        "Arbor has the frame it ended at", one.snapshot(window)?.frame == window.frame,
        "\(one.snapshot(window)?.frame.text ?? "") against \(window.frame.text)")
    }
  }

  book.story("a window is resized by an edge and the release is never heard") { story in
    let (one, window, _) = stage(story)
    one.mac.drag(from: CGPoint(x: 500, y: 250), to: CGPoint(x: 560, y: 250), steps: 8)
    one.mac.release(.lost)
    one.mac.pass(2)
    story.check(
      "the resize is finished all the same: the frame says how it ended",
      one.heard.outline == [.resizeBegan(window.number), .resizeEnded(window.number)], one.heard.texts)
  }

  // Trace `calculator-edge`.
  book.story("the edge of a window that cannot be resized is dragged") { story in
    let (one, window, _) = stage(story)
    window.isResizable = false
    one.mac.drag(from: CGPoint(x: 499, y: 250), to: CGPoint(x: 560, y: 250), steps: 8)
    one.mac.release()
    one.mac.pass(1)
    story.check("nothing is reported but the press", one.heard.all == [.pressed], one.heard.texts)
  }

  book.story("text is selected in a window, with the button down for a long way") { story in
    let (one, _, _) = stage(story)
    one.mac.drag(from: CGPoint(x: 200, y: 250), to: CGPoint(x: 450, y: 350))
    one.mac.release()
    one.mac.pass(1)
    story.check("nothing is reported but the press", one.heard.all == [.pressed], one.heard.texts)
  }

  // A global monitor hears only what goes to other apps: clicks on Arbor's tiles, gap handles and menu pass it by.
  book.story("the button goes down on a panel of Arbor's, and Arbor moves windows while it is down") { story in
    let (one, window, _) = stage(story)
    one.mac.press(at: CGPoint(x: 505, y: 250), onArborsPanel: true)
    one.mac.pass(0.05)
    story.check("the press is reported", one.heard.all == [.pressed], one.heard.texts)
    for step in 1...5 {
      one.mac.moveMouse(to: CGPoint(x: 505 + CGFloat(step) * 10, y: 250))
      _ = one.layer.setFrame(CGRect(x: 100, y: 100, width: 400 + CGFloat(step) * 10, height: 300), of: WindowID(window.number))
      one.mac.pass(0.08)
    }
    one.mac.release()
    one.mac.pass(2)
    story.check("no drag and no resize of the person's is made of it", !one.heard.outline.contains { $0 != .pressed }, one.heard.texts)
    story.check(
      "every report of the window's size counts as an echo", !one.heard.all.contains(.changed(window.number, byUser: true)), one.heard.texts)
  }

  // People let go of the key and the button together, and the key can be up by the time the mouse-up arrives.
  book.story("⌘ is held to the end of a drag and let go together with the button") { story in
    let (one, window, _) = stage(story)
    final class Keys: @unchecked Sendable { var atTheEnd: KeyChord.Modifiers? }
    let keys = Keys()
    let probe = Probe(onDragEnded: { [layer = one.layer] in keys.atTheEnd = layer.modifierKeysDown() })
    one.heard.next = probe
    one.mac.setModifierFlags(1 << 20)
    one.mac.drag(from: grip, to: CGPoint(x: 500, y: 262))
    one.mac.release()
    one.mac.setModifierFlags(0)
    one.mac.pass(1)
    story.check("when the end of the drag is reported, ⌘ counts as held", keys.atTheEnd == .command, "\(String(describing: keys.atTheEnd))")
    story.check("afterwards it does not", one.layer.modifierKeysDown().isEmpty)
    _ = window
  }
}

/// Listens for one thing.
@MainActor
private final class Probe: WindowSystemEvents {
  let onDragEnded: @MainActor () -> Void
  init(onDragEnded: @escaping @MainActor () -> Void) { self.onDragEnded = onDragEnded }
  func windowAppeared(_ window: WindowSnapshot) {}
  func windowDestroyed(_ id: WindowID) {}
  func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {}
  func windowFocused(_ id: WindowID) {}
  func applicationActivated(_ app: FrontmostApp?) {}
  func accessibilityWasRefused() {}
  func dragBegan(_ id: WindowID, at point: CGPoint) {}
  func dragMoved(_ id: WindowID, to point: CGPoint) {}
  func dragEnded(_ id: WindowID, at point: CGPoint) { onDragEnded() }
  func displaysChanged() {}
  func resizeBegan(_ id: WindowID) {}
  func resizeEnded(_ id: WindowID) {}
  func keyboardFocusMoved() {}
  func dragCancelled(_ id: WindowID) {}
  func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {}
  func pointerPressed() {}
}
