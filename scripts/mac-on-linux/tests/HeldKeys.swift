import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Whether a shortcut is still held: what a peek, the minimap's hold and the hold's guard against a slip ask, thirty times a second, as the net under a release that
// macOS never reports. A "no" while the key is down ends a peek at its first look: a hold is a tap then.

@MainActor
func tellOfHeldKeys(_ book: Book) {
  let (space, control, option): (UInt16, UInt, UInt) = (49, 1 << 18, 1 << 19)
  let chord = KeyChord([.control, .option], .space)
  let keys: [(String, UInt16, KeyChord)] = [("⌃⌥Space", space, chord), ("⌃⌥A", 0, KeyChord([.control, .option], .a))]
  for (shortcut, code, chord) in keys {
    for (name, hides) in [("told truly", false), ("and the session's table hides the key from Arbor", true)] {
      book.story("\(shortcut) is held, \(name)") { story in
        let one = StoreyOne(story) { mac in _ = mac.open("window", in: mac.launch("Notes")) }
        one.mac.sessionsTableHidesKeys = hides
        story.check("before the press it is not held", !one.layer.isHolding(chord))
        one.mac.setModifierFlags(control | option)
        story.check("nor with ⌃⌥ alone", !one.layer.isHolding(chord))
        one.mac.pressKey(code)
        one.mac.pass(0.04)
        story.check("at the first look it is held", one.layer.isHolding(chord))
        one.mac.pass(1)
        story.check("and a second later", one.layer.isHolding(chord))
        one.mac.releaseKey(code)
        story.check("once the key is up it is not, with ⌃⌥ still down", !one.layer.isHolding(chord))
        one.mac.pressKey(code)
        one.mac.setModifierFlags(control)
        story.check("nor with the key down again and ⌥ let go", !one.layer.isHolding(chord))
        one.mac.setModifierFlags(option)
        story.check("nor with ⌃ let go", !one.layer.isHolding(chord))
        one.mac.releaseKey(code)
        one.mac.setModifierFlags(0)
      }
    }
  }
  // A GUESS, seen on no Mac: what a program posts from a source of its own is in the session's table alone. It worked before the keyboard's table was asked too.
  book.story("⌃⌥Space is held by a program that posts it") { story in
    let one = StoreyOne(story) { mac in _ = mac.open("window", in: mac.launch("Notes")) }
    one.mac.setModifierFlags(control | option)
    one.mac.pressKey(space, bySoftware: true)
    story.check("it is held", one.layer.isHolding(chord))
    one.mac.releaseKey(space)
    story.check("and not once it is up", !one.layer.isHolding(chord))
    one.mac.setModifierFlags(0)
  }

  // Upstairs: what a person sees of it. The real controller asks the real layer, thirty times a second.
  let look = KeyBinding(chord, .showAll)
  let giveUp = KeyBinding(KeyChord([.control, .option], .escape), .togglePause)
  for (name, hides) in [("told truly", false), ("and the session's table hides the key from Arbor", true)] {
    @MainActor func stage(_ story: Story) -> (StoreyTwo, FakeMac.Window, FakeMac.Window) {
      var first: FakeMac.Window!, second: FakeMac.Window!
      let two = StoreyTwo(story) { mac in
        let app = mac.launch("Notes")
        first = mac.open("first", in: app)
        second = mac.open("second", in: app)
      }
      two.mac.sessionsTableHidesKeys = hides
      two.run("dock \(first.number) left")
      two.run("dock \(second.number) right")
      two.run("zoom \(first.number)")
      story.check("one window fills the view, the other is out of view", two.isInView(first) && two.isOutOfView(second), two.whereabouts(second))
      two.mac.setModifierFlags(control | option)
      two.mac.pressKey(space)
      two.mac.note("⌃⌥Space goes down")
      two.controller.shortcut(look, .pressed)
      // Longer than a slow tap, which stays on everything by design.
      two.mac.pass(1.2)
      story.check("the hold is seen as a hold", two.controller.isPeeking)
      story.check("everything shows while it lasts", two.isInView(first) && two.isInView(second), two.whereabouts(second))
      return (two, first, second)
    }
    @MainActor func letGo(_ two: StoreyTwo) {
      two.mac.releaseKey(space)
      two.mac.setModifierFlags(0)
      two.mac.note("⌃⌥Space comes up")
      two.controller.shortcut(look, .released)
      two.mac.pass(1)
    }

    book.story("⌃⌥Space is held to look and let go, \(name)") { story in
      let (two, first, second) = stage(story)
      letGo(two)
      story.check("let go, the view is back where it was", two.isInView(first) && two.isOutOfView(second), two.whereabouts(second))
    }

    book.story("⌃⌥Space is held to look and ⌃⌥⎋ gives it up, \(name)") { story in
      let (two, first, second) = stage(story)
      two.mac.note("⌃⌥⎋")
      two.controller.shortcut(giveUp, .pressed)
      two.controller.shortcut(giveUp, .released)
      two.mac.pass(0.5)
      story.check("Arbor is not paused", !two.controller.isPaused)
      story.check("the view is back where it was, with ⌃⌥Space still down", two.isInView(first) && two.isOutOfView(second), two.whereabouts(second))
      letGo(two)
      story.check("and stays there once it is up", two.isInView(first) && two.isOutOfView(second), two.whereabouts(second))
    }
  }
}
