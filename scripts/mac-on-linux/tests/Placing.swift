import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// What Arbor asks of windows: a frame, the keyboard, to come out of the Dock.

@MainActor
private func stage(_ story: Story, frame: CGRect = CGRect(x: 100, y: 100, width: 400, height: 300)) -> (StoreyOne, FakeMac.Window) {
  var window: FakeMac.Window!
  let one = StoreyOne(story) { mac in window = mac.open("window", in: mac.launch("Notes"), frame: frame) }
  return (one, window)
}

private func isByUser(_ event: Heard) -> Bool { if case .changed(_, byUser: true) = event { true } else { false } }

@MainActor
func tellOfPlacing(_ book: Book) {
  // Position and size are set one after the other, and each change is reported: one to three echoes, 2 to 15 ms later (traces/README.md, row 1).
  book.story("Arbor gives a window a frame") { story in
    let (one, window) = stage(story)
    let target = CGRect(x: 12, y: 43, width: 500, height: 650)
    story.check("the layer answers with the frame the window took", one.layer.setFrame(target, of: WindowID(window.number)) == target)
    story.check("the window has it", window.frame == target, window.frame.text)
    story.check("nothing is reported before the call returns", one.heard.all.isEmpty, one.heard.texts)
    one.mac.pass(1)
    story.check("its app's reports follow, and count as echoes", !one.heard.all.isEmpty && !one.heard.all.contains(where: isByUser), one.heard.texts)
    one.heard.clear()
    let calls = one.mac.calls
    story.check("asked for the same frame again, the layer answers the same", one.layer.setFrame(target, of: WindowID(window.number)) == target)
    story.check("with fewer calls than a full move takes", one.mac.calls - calls <= 4, "\(one.mac.calls - calls) calls")
    one.mac.pass(1)
    story.check("and there is no echo of a move that changed nothing", one.heard.all.isEmpty, one.heard.texts)
  }

  // traces/README.md, rows 3 to 5.
  book.story("a window does not take the frame it is given") { story in
    let (one, window) = stage(story)
    window.minimumSize = CGSize(width: 501, height: 200)
    story.check(
      "too small a size: the layer answers with what the window took",
      one.layer.setFrame(CGRect(x: 12, y: 43, width: 244, height: 650), of: WindowID(window.number)) == CGRect(x: 12, y: 43, width: 501, height: 650))
    story.check(
      "half points: it answers in whole ones",
      one.layer.setFrame(CGRect(x: 150.5, y: 46.5, width: 600, height: 400), of: WindowID(window.number)) == CGRect(x: 150, y: 47, width: 600, height: 400))
    story.check(
      "parked past the corner: the title bar stays above the Dock",
      one.layer.setFrame(CGRect(x: 1023, y: 767, width: 600, height: 400), of: WindowID(window.number)) == CGRect(x: 1023, y: 673, width: 600, height: 400))
    one.mac.pass(1)
    story.check("none of the reports counts as the person's doing", !one.heard.all.contains(where: isByUser), one.heard.texts)
    window.isResizable = false
    story.check(
      "a window of a fixed size is moved and keeps its size",
      one.layer.setFrame(CGRect(x: 12, y: 43, width: 300, height: 300), of: WindowID(window.number)) == CGRect(x: 12, y: 43, width: 600, height: 400))
  }

  // Size, position, size: the first resize keeps a large window from being clamped when it moves to a smaller display, the second applies the size the
  // destination allows (Sources/ArborCore/FramePlan.swift).
  book.story("a window goes from a small display to a large one and back") { story in
    var window: FakeMac.Window!
    let large = FakeMac.Screen(id: 2, name: "Large", frame: CGRect(x: 1024, y: 0, width: 2560, height: 1440), visibleFrame: CGRect(x: 1024, y: 25, width: 2560, height: 1415))
    let one = StoreyOne(story) { mac in
      mac.setScreens([.hostedMac, large])
      window = mac.open("window", in: mac.launch("Notes"), frame: CGRect(x: 12, y: 43, width: 1000, height: 650))
    }
    let big = CGRect(x: 1036, y: 37, width: 2536, height: 1391)
    story.check(
      "a size that is cut to what fits at the old place is applied in full at the new one",
      one.layer.setFrame(big, of: WindowID(window.number)) == big, window.frame.text)
    let small = CGRect(x: 12, y: 43, width: 1000, height: 650)
    story.check("and back", one.layer.setFrame(small, of: WindowID(window.number)) == small, window.frame.text)
    one.mac.pass(1)
    story.check("none of the stages counts as the person's doing", !one.heard.all.contains(where: isByUser), one.heard.texts)
  }

  book.story("the frame Arbor believes a window has is out of date") { story in
    let (one, window) = stage(story)
    // Nothing is posted: the app is one that says nothing, or the report is still on its way.
    one.mac.changeSilently(window, to: CGRect(x: 100, y: 100, width: 700, height: 500))
    let target = CGRect(x: 12, y: 43, width: 400, height: 300)
    story.check(
      "a move that was thought to need no resize gets one", one.layer.setFrame(target, of: WindowID(window.number)) == target, window.frame.text)
  }

  for delay in [0.05, 0.4] {
    book.story("an app applies a new size \(delay) s after the call has returned") { story in
      let (one, window) = stage(story)
      window.app.appliesSizeAfter = delay
      let target = CGRect(x: 12, y: 43, width: 500, height: 650)
      let answer = one.layer.setFrame(target, of: WindowID(window.number))
      story.check(
        "the layer answers with what it could read back: the new place, the old size", answer == CGRect(x: 12, y: 43, width: 400, height: 300),
        "\(answer?.text ?? "nothing")")
      one.mac.pass(2)
      story.check("the window has taken the size by now", window.frame == target, window.frame.text)
      story.check("and Arbor knows", one.snapshot(window)?.frame == target, "\(one.snapshot(window)?.frame.text ?? "")")
      story.check("having been told in a way that makes it look again", one.heard.all.contains(where: isByUser), one.heard.texts)
    }
  }

  // Traces `stubborn-fast` and `stubborn-slow`.
  for delay in [0.05, 0.4] {
    book.story("a window goes back to its old frame \(delay) s after every move") { story in
      let (one, window) = stage(story)
      let home = window.frame
      window.goesBackAfter = delay
      _ = one.layer.setFrame(CGRect(x: 12, y: 43, width: 400, height: 300), of: WindowID(window.number))
      one.mac.pass(2)
      story.check("the window is back where it was", window.frame == home)
      story.check("Arbor knows where it is", one.snapshot(window)?.frame == home, "\(one.snapshot(window)?.frame.text ?? "")")
      story.check("and has been told that this was not its own doing", one.heard.all.contains(where: isByUser), one.heard.texts)
    }
  }

  // Apps with "enhanced user interface" on, which assistive tools set, animate every frame change.
  book.story("an app has the enhanced user interface on") { story in
    let (one, window) = stage(story)
    window.app.hasEnhancedUserInterface = true
    let target = CGRect(x: 12, y: 43, width: 500, height: 650)
    story.check(
      "the window takes its frame at once all the same", one.layer.setFrame(target, of: WindowID(window.number)) == target, window.frame.text)
    story.check("and the assistive tool finds its switch as it left it", window.app.hasEnhancedUserInterface)
  }

  book.story("an app with the enhanced user interface on hangs in the middle of a move") { story in
    let (one, window) = stage(story)
    window.app.hasEnhancedUserInterface = true
    // The question, the switch off, the size; then silence.
    window.app.hangsAfterCalls = 3
    story.check(
      "the layer does not know what came of the move",
      one.layer.setFrame(CGRect(x: 12, y: 43, width: 500, height: 650), of: WindowID(window.number)) == nil)
    one.mac.pass(2)
    one.mac.wake(window.app)
    one.mac.pass(2)
    story.check("when the app wakes the assistive tool's switch is on again", window.app.hasEnhancedUserInterface)
  }

  // `focus(id)` is answered by `windowFocused(id)` 5 to 20 ms later; not at all if the window had the focus (traces/README.md, row 2).
  book.story("Arbor gives the keyboard to a window of another app") { story in
    var mine: FakeMac.Window!, first: FakeMac.Window!, second: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Other")
      second = mac.open("second", in: app)
      first = mac.open("first", in: app)
      mine = mac.open("mine", in: mac.launch("Mine"))
    }
    one.layer.focus(WindowID(second.number))
    one.mac.pass(1)
    story.check("the window has the keyboard", one.mac.keyWindow === second)
    story.check(
      "it is in front",
      one.layer.windowsFrontToBack().first { [mine.number, first.number, second.number].contains($0.rawValue) }?.rawValue == second.number)
    story.check("it is reported focused, once, and no other window is", one.heard.outline == [.focused(second.number)], one.heard.texts)
  }

  // Since macOS 14 activation is only a request.
  book.story("Arbor gives the keyboard to a window whose app takes no notice of being activated") { story in
    var other: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      other = mac.open("other", in: mac.launch("Other"))
      mac.open("mine", in: mac.launch("Mine"))
    }
    other.app.ignoresActivation = true
    one.layer.focus(WindowID(other.number))
    one.mac.pass(0.2)
    story.check("at first nothing happens", one.mac.keyWindow !== other)
    one.mac.pass(1)
    story.check("a moment later the app has been asked through Accessibility, and the window has the keyboard", one.mac.keyWindow === other)
    story.check("which is reported", one.heard.all.contains(.focused(other.number)), one.heard.texts)
  }

  book.story("an app in the background changes its focused window") { story in
    var mine: FakeMac.Window!, second: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Other")
      second = mac.open("second", in: app)
      mac.open("first", in: app)
      mine = mac.open("mine", in: mac.launch("Mine"))
    }
    one.mac.appMakesKey(second)
    one.mac.pass(1)
    story.check(
      "nothing is said about the keyboard, which is where it was", one.heard.all.isEmpty && one.layer.focusedWindow()?.rawValue == mine.number,
      one.heard.texts)
  }

  book.story("Arbor minimizes a window and brings it back") { story in
    let (one, window) = stage(story)
    one.layer.setMinimized(WindowID(window.number), true)
    one.mac.pass(1)
    story.check("it is in the Dock, and reported so", window.isMinimized && one.snapshot(window)?.isMinimized == true)
    one.layer.setMinimized(WindowID(window.number), false)
    one.mac.pass(1)
    story.check("it is back, and reported so", !window.isMinimized && one.snapshot(window)?.isMinimized == false)
  }

  book.story("Arbor shows a hidden app") { story in
    var shy: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      shy = mac.open("shy", in: mac.launch("Shy"))
      mac.open("mine", in: mac.launch("Mine"))
      mac.hide(shy.app)
    }
    one.layer.unhideApp(pid: shy.app.pid)
    one.mac.pass(1)
    story.check("its window shows, and is reported so", one.mac.isShowing(shy) && one.snapshot(shy)?.isHidden == false)
  }

  // An app centres a dialog over its window; with that window parked past the corner the dialog opens out of view and the app looks hung (F47).
  book.story("a dialog opens over a window that is out of view") { story in
    let (one, window) = stage(story, frame: CGRect(x: 1023, y: 673, width: 600, height: 400))
    let dialog = one.mac.open("Save changes?", in: window.app, frame: CGRect(x: 1173, y: 773, width: 300, height: 200), subrole: "AXDialog")
    one.mac.pass(2)
    story.check("it is not announced as a window", !one.known.contains(dialog.number) && one.heard.about(dialog).isEmpty, one.heard.texts)
    story.check("it is brought into view", FakeMac.Screen.hostedMac.visibleFrame.contains(dialog.frame), dialog.frame.text)
    let home = dialog.frame
    one.mac.appMoves(dialog, to: CGRect(x: 1100, y: 700, width: 300, height: 200))
    one.mac.click(window)
    one.mac.pass(2)
    story.check("once: what its app does with it afterwards is its app's business", dialog.frame != home, dialog.frame.text)
  }

  book.story("a dialog opens in plain view") { story in
    let (one, window) = stage(story)
    let dialog = one.mac.open("Save changes?", in: window.app, frame: CGRect(x: 150, y: 150, width: 300, height: 200), subrole: "AXDialog")
    one.mac.pass(2)
    story.check("it is left where it is", dialog.frame == CGRect(x: 150, y: 150, width: 300, height: 200), dialog.frame.text)
    story.check(
      "the layer says that the keyboard has left the windows it knows",
      one.heard.all.contains(.keyboardMoved) && !one.heard.all.contains(.focused(window.number)), one.heard.texts)
    one.heard.clear()
    one.mac.close(dialog)
    one.mac.pass(1)
    story.check("when it closes the window behind it is reported focused again", one.heard.all.contains(.focused(window.number)), one.heard.texts)
  }

  // `pause` stops the layer and `resume` starts it again: nothing of one run may colour the next.
  book.story("the layer is stopped and started again") { story in
    var a: FakeMac.Window!
    let one = StoreyOne(story) { mac in a = mac.open("a", in: mac.launch("Notes")) }
    one.layer.stop()
    one.heard.clear()
    let b = one.mac.open("b", in: a.app)
    one.mac.close(a)
    one.mac.drag(from: CGPoint(x: 300, y: 110), to: CGPoint(x: 400, y: 200))
    one.mac.release()
    one.mac.pass(2)
    story.check("while it is stopped it reports nothing", one.heard.all.isEmpty, one.heard.texts)
    story.check("and knows no windows", one.known.isEmpty)
    story.check(
      "one window can be moved all the same",
      one.layer.setFrameOnce(CGRect(x: 12, y: 43, width: 300, height: 300), of: WindowID(b.number), pid: b.app.pid) == CGRect(x: 12, y: 43, width: 300, height: 300))
    one.mac.pass(1)
    story.check("without anything being reported", one.heard.all.isEmpty, one.heard.texts)
    one.layer.start()
    one.mac.pass(1)
    story.check("started again, it knows the windows there are now", one.known == [b.number], "\(one.known)")
    let c = one.mac.open("c", in: a.app)
    one.mac.pass(1)
    story.check("and reports each thing once, not twice", one.heard.outline == [.appeared(c.number), .focused(c.number)], one.heard.texts)
  }

  // The call for the window server's list can return nothing, and no answer is not the same as no windows.
  book.story("the window server gives no list for a while") { story in
    let (one, window) = stage(story)
    one.mac.serverGivesNoList = true
    one.mac.switchSpace(to: 2)
    one.mac.pass(2)
    one.mac.switchSpace(to: 1)
    one.mac.pass(2)
    one.mac.serverGivesNoList = false
    story.check(
      "no window is reported gone or new because of it", one.heard.outline.allSatisfy { if case .focused = $0 { true } else { false } },
      one.heard.texts)
    story.check("the window is known and shows", one.snapshot(window)?.isOnActiveSpace == true)
  }

  book.story("what the hands did last") { story in
    let (one, window) = stage(story)
    one.mac.pass(5)
    one.mac.click(window)
    one.mac.pass(2)
    story.check(
      "the layer knows how long ago the last click was", abs(one.layer.secondsSinceClickOrModifierKey() - 2) < 0.01,
      "\(one.layer.secondsSinceClickOrModifierKey())")
    story.check("and where the pointer is", one.layer.cursorLocation() == CGPoint(x: window.frame.midX, y: window.frame.midY))
    story.check("and that the button is up", !one.layer.isMouseButtonDown())
  }
}
