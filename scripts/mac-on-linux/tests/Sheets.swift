import ArborCore
@testable import ArborKit
import ArborTesting
import CoreGraphics
import FakeMacOS
import Foundation

// The keyboard is in a sheet, or in a free-standing panel.
//
// What macOS names as the app's focused window meanwhile was written down on a hosted Mac on 2026-10-15 (scripts/mac-shell/check-moves-of-the-view.sh): a sheet by a
// number of its own, role AXSheet, with its window as its parent, its AXWindow and the main window (a test window's; TextEdit's Save As…); a utility panel by its
// own number, AXWindow and AXFloatingWindow, with the app as its parent. The layer passed those numbers on as they came, and nobody above it knew them. A sheet is where its window is, so the layer
// answers it with its window's number. A panel stays on screen whatever the view does: its number is passed on, and whoever has it keeps the keyboard.

@MainActor
func tellOfSheets(_ book: Book) {
  book.story("a sheet comes down over the window that has the keyboard, and is answered") { story in
    var mine: FakeMac.Window!, other: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 40, y: 80, width: 400, height: 300))
      other = mac.open("other", in: mine.app, frame: CGRect(x: 520, y: 80, width: 400, height: 300))
    }
    one.mac.click(mine)
    one.mac.pass(1)
    story.check(
      "to begin with the keyboard is in the window, and the layer has said so",
      one.layer.focusedWindow()?.rawValue == mine.number && one.heard.all.contains(.focused(mine.number)) && other.isOpen, one.heard.texts)
    one.heard.clear()
    let sheet = one.mac.openSheet(on: mine)
    one.mac.pass(1)
    story.check("the Mac has the keyboard in the sheet", one.mac.keyWindow === sheet)
    story.check("asked where the keyboard is, the layer names the sheet's window", one.layer.focusedWindow()?.rawValue == mine.number)
    story.check("nothing is said: to whoever listens the keyboard has not moved", one.heard.all.isEmpty, one.heard.texts)
    one.mac.closeSheet(sheet)
    one.mac.pass(1)
    story.check("the sheet is answered, and the Mac has the keyboard in the window", one.mac.keyWindow === mine)
    story.check("the layer names the window as before", one.layer.focusedWindow()?.rawValue == mine.number)
    story.check("and nothing is said of that either", one.heard.all.isEmpty, one.heard.texts)
  }

  // Which window is the sheet's is not to be guessed from which is the main one: that changes 44 ms after the sheet has come.
  book.story("two documents, and a sheet comes down over the other one") { story in
    var first: FakeMac.Window!, second: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      let app = mac.launch("Editor")
      second = mac.open("second", in: app, frame: CGRect(x: 520, y: 80, width: 400, height: 300))
      first = mac.open("first", in: app, frame: CGRect(x: 40, y: 80, width: 400, height: 300))
    }
    story.check("to begin with the keyboard is in the first", one.layer.focusedWindow()?.rawValue == first.number)
    one.heard.clear()
    let sheet = one.mac.openSheet(on: second)
    one.mac.pass(0.02)
    story.check("the Mac has the keyboard in the sheet, and the first is still the main window", one.mac.keyWindow === sheet && first.app.main === first)
    story.check("asked at once, the layer names the second", one.layer.focusedWindow()?.rawValue == second.number)
    one.mac.pass(1)
    story.check("a second later too", one.layer.focusedWindow()?.rawValue == second.number)
    story.check("the second is reported focused", one.heard.all.contains(.focused(second.number)), one.heard.texts)
    story.check("the first never is", !one.heard.all.contains(.focused(first.number)), one.heard.texts)
  }

  book.story("a sheet comes down over a panel") { story in
    var mine: FakeMac.Window!
    let one = StoreyOne(story) { mac in mine = mac.open("mine", in: mac.launch("Mine")) }
    let panel = one.mac.open("panel", in: mine.app, frame: CGRect(x: 600, y: 400, width: 260, height: 200), subrole: "AXFloatingWindow")
    one.mac.pass(1)
    let sheet = one.mac.openSheet(on: panel)
    one.mac.pass(1)
    story.check("the Mac has the keyboard in the sheet", one.mac.keyWindow === sheet)
    story.check("the layer names no window it knows: somebody has the keyboard, in plain sight", one.layer.focusedWindow()?.rawValue == sheet.number)
  }

  book.story("a click on the sheet of another window") { story in
    var mine: FakeMac.Window!, other: FakeMac.Window!
    let one = StoreyOne(story) { mac in
      other = mac.open("other", in: mac.launch("Other"), frame: CGRect(x: 520, y: 80, width: 400, height: 300))
      mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 40, y: 80, width: 400, height: 300))
    }
    let sheet = one.mac.openSheet(on: other)
    one.mac.pass(1)
    story.check("an app in the background opens a sheet, and the keyboard stays", one.layer.focusedWindow()?.rawValue == mine.number)
    one.heard.clear()
    one.mac.click(sheet)
    one.mac.pass(2)
    story.check("the Mac has the keyboard in the sheet", one.mac.keyWindow === sheet)
    story.check("the sheet's window is reported focused", one.heard.all.contains(.focused(other.number)), one.heard.texts)
    story.check("asked where the keyboard is, the layer names it", one.layer.focusedWindow()?.rawValue == other.number)
  }

  book.story("a free-standing panel takes the keyboard") { story in
    var mine: FakeMac.Window!
    let one = StoreyOne(story) { mac in mine = mac.open("mine", in: mac.launch("Mine")) }
    one.heard.clear()
    let panel = one.mac.open("panel", in: mine.app, frame: CGRect(x: 600, y: 400, width: 220, height: 140), subrole: "AXFloatingWindow")
    one.mac.pass(1)
    story.check("the Mac has the keyboard in the panel", one.mac.keyWindow === panel)
    story.check("the layer says that the keyboard has left the windows it knows", one.heard.all.contains(.keyboardMoved), one.heard.texts)
    story.check("asked where the keyboard is, it names the panel's own number", one.layer.focusedWindow()?.rawValue == panel.number)
  }

  // [mine | Desktop | other], a third window floating on the Desktop, the view on `mine`.
  @MainActor func desk(_ story: Story) -> (StoreyTwo, mine: FakeMac.Window, floating: FakeMac.Window) {
    var mine: FakeMac.Window!, other: FakeMac.Window!, floating: FakeMac.Window!
    let two = StoreyTwo(story, settings: .withDesktopColumn) { mac in
      other = mac.open("other", in: mac.launch("Other"), frame: CGRect(x: 700, y: 100, width: 400, height: 300))
      floating = mac.open("floating", in: mac.launch("Third"), frame: CGRect(x: 560, y: 300, width: 300, height: 260))
      mine = mac.open("mine", in: mac.launch("Mine"), frame: CGRect(x: 60, y: 100, width: 400, height: 300))
    }
    story.check("two windows are docked", two.run("dock \(mine.number) left").ok && two.run("dock \(other.number) right").ok)
    story.check("one is framed and has the keyboard", two.run("zoom \(mine.number)").ok && two.mac.keyWindow === mine)
    return (two, mine, floating)
  }

  book.story("a sheet, and Show Everything: its window stays in view") { story in
    let (two, mine, _) = desk(story)
    let sheet = two.mac.openSheet(on: mine)
    two.mac.pass(1)
    story.check("everything shows", two.run("show-all").ok && two.isInView(mine), two.whereabouts(mine))
    story.check("the keyboard is still in the sheet", two.mac.keyWindow === sheet)
  }

  book.story("a sheet, and a neighbour: its window goes out of view") { story in
    let (two, mine, floating) = desk(story)
    let sheet = two.mac.openSheet(on: mine)
    two.mac.pass(1)
    story.check("the view moves on", two.run("neighbor right").ok && two.isOutOfView(mine), two.whereabouts(mine))
    story.check("the keyboard is no longer in the sheet, where Return would answer a question nobody sees", two.mac.keyWindow !== sheet)
    story.check("it is in the window in view", two.mac.keyWindow === floating)
  }

  book.story("a panel, and a neighbour: its app's window goes out of view, and the panel is still there") { story in
    let (two, mine, _) = desk(story)
    let panel = two.mac.open("panel", in: mine.app, frame: CGRect(x: 600, y: 500, width: 220, height: 140), subrole: "AXFloatingWindow")
    two.mac.pass(1)
    story.check("the keyboard is in the panel", two.mac.keyWindow === panel)
    story.check("everything shows, and the panel keeps the keyboard", two.run("show-all").ok && two.mac.keyWindow === panel)
    story.check("Back frames the window again, and the panel keeps it", two.run("back").ok && two.isInView(mine) && two.mac.keyWindow === panel)
    story.check("the view moves on", two.run("neighbor right").ok && two.isOutOfView(mine), two.whereabouts(mine))
    story.check("the panel keeps the keyboard, in plain sight", two.mac.keyWindow === panel && two.isInView(panel), two.whereabouts(panel))
  }

  book.story("a panel, and a saved view: what names a place takes the keyboard there") { story in
    let (two, mine, _) = desk(story)
    story.check("the view on the window is saved", two.run("save-view 1").ok)
    story.check("the view goes to the Desktop", two.run("desktop").ok && two.isOutOfView(mine), two.whereabouts(mine))
    let panel = two.mac.open("panel", in: mine.app, frame: CGRect(x: 600, y: 500, width: 220, height: 140), subrole: "AXFloatingWindow")
    two.mac.click(panel)
    two.mac.pass(1)
    story.check("the keyboard is in a panel", two.mac.keyWindow === panel)
    story.check("the saved view comes back", two.run("view 1").ok && two.isInView(mine), two.whereabouts(mine))
    story.check("and its window has the keyboard", two.mac.keyWindow === mine)
  }
}
