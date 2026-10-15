import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// Rule 3: a window moves once, to where it ends up. A docked window goes to the Dock, or is hidden with its app, while it is in view; the view
/// then goes elsewhere; the window is asked back: by a click in the Dock or ⌘Tab, by `reveal`, Go to… or the menu's list.
///
/// It used to be laid out with the view as it was, which sent it to the corner, and fetched from there when the view followed. And `reveal`
/// moved the view at once, to a window that was not back yet: its neighbour filled the screen until it landed. Now the view goes
/// first, when the window is back, and there is one layout.
@Suite @MainActor struct AWindowComesBackInOneMoveTests {
  enum Away: String, CaseIterable, Sendable { case minimized, hidden }
  enum Asked: String, CaseIterable, Sendable { case byHand, byName }
  /// Where the view is when the window is asked back.
  enum View: String, CaseIterable, Sendable { case onAnotherWindow, onAGroupWithoutIt, onEverything }

  /// Safari | Desktop | Notes over Mail, with Terminal floating in the middle.
  func desk() -> (Harness, safari: WindowID, notes: WindowID, mail: WindowID, terminal: WindowID) {
    let h = Harness()
    let safari = h.system.open(app: "Safari", pid: 11, frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let notes = h.system.open(app: "Notes", pid: 12, frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    let mail = h.system.open(app: "Mail", pid: 13, frame: CGRect(x: 500, y: 300, width: 600, height: 400))
    let terminal = h.system.open(app: "Terminal", pid: 14, frame: CGRect(x: 560, y: 300, width: 300, height: 200))
    h.start()
    h.run("dock \(safari.rawValue) left")
    h.run("dock \(notes.rawValue) right")
    h.run("dock \(mail.rawValue) beside \(notes.rawValue) bottom")
    h.system.userFocus(safari)
    return (h, safari, notes, mail, terminal)
  }

  /// Mail goes away in view, the view goes elsewhere, Mail is asked back. Returns the harness, Mail, and how long the log of moves was before.
  /// `prompt`: that it is back is reported while Arbor is still asking for it. No Mac is that quick.
  func play(_ away: Away, _ asked: Asked, _ view: View, prompt: Bool) -> (Harness, WindowID, Int) {
    let (h, safari, _, mail, _) = desk()
    switch away {
    case .minimized: h.system.setMinimized(mail, true)
    case .hidden: h.system.setHidden(pid: 13, true)
    }
    h.scheduler.advance(by: 2)
    switch view {
    case .onAnotherWindow: h.run("zoom \(safari.rawValue)")
    case .onAGroupWithoutIt:
      // Safari and the Desktop beside it would be a group of their own only with a name; the nearest thing is the Desktop's own view.
      h.run("desktop")
    case .onEverything: break
    }
    h.scheduler.advance(by: 2)
    let mark = h.system.moveLog.count
    h.system.restoresLate = !prompt
    switch asked {
    case .byHand:
      // A click in the Dock, ⌘Tab: macOS brings it back and gives it the keyboard, and says so in that order.
      switch away {
      case .minimized: h.system.setMinimized(mail, false)
      case .hidden:
        h.system.setHidden(pid: 13, false)
        h.system.userFocus(mail)
      }
    case .byName:
      #expect(h.run("reveal \(mail.rawValue)").ok)
    }
    h.system.deliverEchoes()
    h.system.reportFocus()
    h.system.finishRestoring()
    h.system.restoresLate = false
    h.scheduler.advance(by: 2)
    return (h, mail, mark)
  }

  @Test(arguments: Away.allCases, Asked.allCases) func nobodyIsSeenToMoveTwice(away: Away, asked: Asked) {
    for view in View.allCases {
      // Left, from either view that does not show it: an app shown again by hand whose "it shows" is reported, and laid out, before the
      // keyboard's report comes. Two reports, one act, two layouts. To wait for the second would put off the layout after every ⌘H
      // back, and no recording has that order.
      for prompt in [false, true] where !(prompt && away == .hidden && asked == .byHand && view != .onEverything) {
        let (h, _, mark) = play(away, asked, view, prompt: prompt)
        #expect(h.system.jolts(since: mark) == [], "the view \(view), \(prompt ? "told at once" : "told as a Mac tells")")
      }
    }
  }

  @Test(arguments: Away.allCases, Asked.allCases) func itEndsInViewInFrontWithTheKeyboard(away: Away, asked: Asked) {
    for view in View.allCases {
      for prompt in [false, true] {
        let (h, mail, _) = play(away, asked, view, prompt: prompt)
        for words in [["visible", "\(mail.rawValue)"], ["focused", "\(mail.rawValue)"], ["in-front", "\(mail.rawValue)"]] {
          let problem = ScenarioExpectation.check(words, harness: h, lastCommandOK: true)
          #expect(problem == nil, "the view \(view), \(prompt ? "told at once" : "told as a Mac tells")")
        }
        expectWindowsMatchLayout(h)
      }
    }
  }

  /// Framed stays framed: from a view on one window it fills the screen, as when it is switched to without having been away.
  @Test(arguments: Away.allCases, Asked.allCases) func fromAViewOnOneWindowItIsFramed(away: Away, asked: Asked) {
    for prompt in [false, true] {
      let (h, mail, _) = play(away, asked, .onAnotherWindow, prompt: prompt)
      #expect(ScenarioExpectation.check(["fills", "\(mail.rawValue)"], harness: h, lastCommandOK: true) == nil)
      #expect(h.run("back").ok, "and Back returns")
      #expect(ScenarioExpectation.check(["fills", "101"], harness: h, lastCommandOK: true) == nil)
    }
  }

  /// Where it ends does not depend on when macOS says that it is back.
  @Test(arguments: Away.allCases, Asked.allCases) func theEndIsTheSameWheneverMacOSReports(away: Away, asked: Asked) {
    for view in View.allCases {
      let (late, _, _) = play(away, asked, view, prompt: false)
      let (prompt, _, _) = play(away, asked, view, prompt: true)
      #expect(late.workspace.camera == prompt.workspace.camera, "the view \(view)")
      #expect(late.layout?.windowFrames == prompt.layout?.windowFrames, "the view \(view)")
    }
  }

  /// Until it is back nothing moves: not the view, not a neighbour.
  @Test(arguments: Away.allCases) func whileItIsOnItsWayNothingMoves(away: Away) {
    let (h, safari, _, mail, _) = desk()
    switch away {
    case .minimized: h.system.setMinimized(mail, true)
    case .hidden: h.system.setHidden(pid: 13, true)
    }
    h.run("zoom \(safari.rawValue)")
    h.scheduler.advance(by: 2)
    let (mark, camera) = (h.system.moveLog.count, h.workspace.camera)
    h.system.restoresLate = true
    #expect(h.run("reveal \(mail.rawValue)").ok)
    h.system.deliverEchoes()
    #expect(h.system.moveLog[mark...].filter { $0.before != $0.after }.isEmpty)
    #expect(h.workspace.camera == camera)
    h.system.finishRestoring()
    h.scheduler.advance(by: 2)
    #expect(ScenarioExpectation.check(["fills", "\(mail.rawValue)"], harness: h, lastCommandOK: true) == nil)
  }

  /// An app that hangs never says that its window is back. The view stays, and what was asked is forgotten: a window that comes back a
  /// minute later by itself, without the keyboard, takes nobody anywhere.
  @Test func aWindowThatComesBackMuchLaterWithoutTheKeyboardMovesNoView() {
    let (h, safari, _, mail, _) = desk()
    h.system.setMinimized(mail, true)
    h.run("zoom \(safari.rawValue)")
    h.system.restoresLate = true
    #expect(h.run("reveal \(mail.rawValue)").ok)
    h.system.userFocus(safari)
    h.scheduler.advance(by: 60)
    let camera = h.workspace.camera
    h.system.finishRestoring()
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == camera)
    expectWindowsMatchLayout(h)
  }

  /// A window that comes back without the keyboard and unasked (its app restores it in the background) moves no view, as before.
  @Test func aWindowThatComesBackUnaskedInTheBackgroundMovesNoView() {
    let (h, safari, _, mail, _) = desk()
    h.system.setMinimized(mail, true)
    h.run("zoom \(safari.rawValue)")
    h.scheduler.advance(by: 2)
    let camera = h.workspace.camera
    h.system.echoes.keyboard = false
    h.system.setMinimized(mail, false)
    h.scheduler.advance(by: 2)
    #expect(h.workspace.camera == camera)
    #expect(h.system.focusedWindow() == safari)
    expectWindowsMatchLayout(h)
  }

  /// Nothing moves a held view, and holding still goes by who asked (Controller+Hold.swift): both as before.
  @Test(arguments: ["hold", "hold still"]) func duringAHoldItGoesAsItWent(hold: String) {
    let (h, safari, _, mail, _) = desk()
    h.system.setMinimized(mail, true)
    h.run("zoom \(safari.rawValue)")
    #expect(h.run(hold).ok)
    let camera = h.workspace.camera
    h.system.restoresLate = true
    let result = h.run("reveal \(mail.rawValue)")
    h.system.deliverEchoes()
    h.system.reportFocus()
    h.system.finishRestoring()
    h.scheduler.advance(by: 2)
    if hold == "hold" {
      #expect(!result.ok)
      #expect(h.workspace.camera == camera)
    } else {
      #expect(result.ok)
      #expect(ScenarioExpectation.check(["visible", "\(mail.rawValue)"], harness: h, lastCommandOK: true) == nil)
    }
    expectWindowsMatchLayout(h)
  }
}
