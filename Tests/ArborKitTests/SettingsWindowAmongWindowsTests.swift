import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// The settings window is a guest among the windows Arbor arranges. Looking at it moves nothing and asks for nobody's
/// keyboard; a change made in it moves a window once, to where it ends up. (Who has the keyboard after the window has
/// closed is macOS's answer: `make e2e` and scripts/mac-shell/shots-F12.sh ask for it.)
@Suite @MainActor struct SettingsWindowAmongWindowsTests {
  @MainActor private final class World {
    let h = Harness()
    let docked: [WindowID]
    let floating: WindowID
    let model: SettingsPanelModel
    var commands: [String] = []

    /// Safari | Desktop | (Notes / Mail), Music floating, Safari with the keyboard, and everything at rest. Music has room on the
    /// Desktop whatever the gap, unless it is `wide`: then it is as wide as the Desktop, where Arbor keeps it.
    init(wide: Bool = false) {
      let h = self.h
      var windows = ["Safari", "Notes", "Mail"].enumerated().map { index, app in
        h.system.open(app: app, frame: CGRect(x: 100 + 60 * index, y: 100 + 40 * index, width: 600, height: 400))
      }
      windows.append(h.system.open(app: "Music", frame: CGRect(x: wide ? 300 : 620, y: 300, width: wide ? 800 : 200, height: 200)))
      h.start()
      h.run("dock \(windows[0].rawValue) left")
      h.run("dock \(windows[1].rawValue) right")
      h.run("dock \(windows[2].rawValue) beside \(windows[1].rawValue) bottom")
      h.system.userFocus(windows[0])
      docked = Array(windows.prefix(3))
      floating = windows[3]
      final class Box { weak var world: World? }
      let box = Box()
      model = SettingsPanelModel(
        controller: h.controller, runningApps: { [.init(bundleID: "com.example.mail", name: "Mail")] },
        run: { command in
          box.world?.commands.append(command.text)
          return h.controller.perform(command)
        })
      box.world = self
      rest()
    }

    /// Lets every motion and every second look end, and forgets what has moved so far.
    func rest() {
      h.scheduler.advance(by: 3)
      h.system.clearFrameLog()
    }

    /// How often each window was moved since the last rest, once everything has come to rest again, besides a question put to
    /// it where it stood (Controller+AskFirst.swift). Whatever was done twice or for nothing counts.
    func moves() -> [WindowID: Int] {
      h.scheduler.advance(by: 3)
      let log = h.system.moveLog[h.system.movesWhenTheFrameLogWasCleared...]
      return Dictionary(grouping: log, by: \.window).mapValues { $0.count - Budget.tally($0).questions }.filter { $0.value > 0 }
    }

    /// The last frame each window was given since the last rest.
    func lastGiven() -> [WindowID: CGRect] {
      Dictionary(h.system.frameLog.map { ($0.window, $0.frame) }, uniquingKeysWith: { _, last in last })
    }

    /// What `SettingsWindowController` tells the model as the window closes.
    func close() {
      model.cancelRecording()
      model.handOverDrafts()
    }
  }

  @Test func lookingAroundMovesNothingAndAsksForNobodysKeyboard() throws {
    let w = World()
    var shown: [SettingsPane?] = []
    var closed = 0
    w.h.controller.onShowSettingsWindow = { shown.append($0) }
    w.h.controller.onCloseSettingsWindow = { closed += 1 }
    let (asked, raised) = (w.h.system.focusRequests.count, w.h.system.raiseLog.count)
    #expect(w.h.run("settings-window").ok && w.h.run("settings-window shortcuts").ok)
    for pane in w.model.panes {
      w.model.go(to: pane)
      if case .section(let section) = pane {
        w.model.setAdvanced(true, in: section)
        _ = w.model.rows(in: section) + w.model.advancedRows(in: section)
      }
    }
    _ = (w.model.shortcutRows, w.model.ruleRows)
    w.model.refreshApps()
    w.model.search = "gap"
    _ = w.model.found
    w.model.search = ""
    // A field is clicked into, something is typed and taken back.
    w.model.type("1", into: .setting("gap"))
    w.model.type("12", into: .setting("gap"))
    // A recording is begun and given up.
    w.model.startRecording(try #require(w.model.shortcutRows.first))
    w.close()
    #expect(w.h.run("settings-window close").ok)
    #expect(shown == [nil, .shortcuts] && closed == 1)
    #expect(w.commands.isEmpty && w.h.controller.settings == Settings())
    #expect(w.moves().isEmpty, "\(w.h.system.frameLog)")
    #expect(w.h.system.focusRequests.count == asked && w.h.system.raiseLog.count == raised)
    #expect(w.h.system.focusedWindow() == w.docked[0], "the window that had the keyboard")
    #expect(!w.h.controller.isRecordingShortcut && !w.h.controller.activeBindings.isEmpty, "Arbor has its shortcuts again")
    expectWindowsMatchLayout(w.h)
  }

  /// A slider says where it is only when it is let go of (`NumberSettingRow`), so a drag of it is one change.
  @Test func aSliderLetGoOfMovesEachDockedWindowOnceToWhereItEndsUp() {
    let w = World()
    let (asked, raised) = (w.h.system.focusRequests.count, w.h.system.raiseLog.count)
    let before = w.h.frame(w.floating)
    w.model.set("gap", to: 40.3)
    #expect(w.commands == ["set gap 40"])
    #expect(w.moves() == Dictionary(uniqueKeysWithValues: w.docked.map { ($0, 1) }), "\(w.h.system.frameLog)")
    for (window, frame) in w.lastGiven() { #expect(frame == w.h.frame(window) && frame == w.h.layout?.windowFrames[window]) }
    #expect(w.h.frame(w.floating) == before)
    #expect(w.h.system.focusRequests.count == asked && w.h.system.raiseLog.count == raised, "the keyboard stays in the field")
    expectWindowsMatchLayout(w.h)
  }

  /// A floating window that is as wide as the Desktop goes with it, and that is one move too.
  @Test func aWindowAsWideAsTheDesktopFollowsItOnce() throws {
    let w = World(wide: true)
    #expect(w.h.frame(w.floating)?.width == w.h.layout?.desktopFrame?.width)
    w.model.set("gap", to: 40.0)
    #expect(w.moves() == Dictionary(uniqueKeysWithValues: (w.docked + [w.floating]).map { ($0, 1) }), "\(w.h.system.frameLog)")
    let desktop = try #require(w.h.layout?.desktopFrame)
    #expect(w.h.frame(w.floating)?.minX == desktop.minX && w.h.frame(w.floating)?.width == desktop.width)
    expectWindowsMatchLayout(w.h)
  }

  /// Arrow keys and VoiceOver move a slider without holding it: a change for every step, and each is one move at most.
  /// (Steps of more than a point: Arbor leaves a window alone that is within a point of its place.)
  @Test func aSliderMovedByTheKeyboardIsOneMoveAStep() {
    let w = World()
    for gap in [16.0, 20, 24, 28, 24, 20] {
      w.rest()
      w.model.set("gap", to: gap)
      let moves = w.moves()
      #expect(moves.values.allSatisfy { $0 == 1 } && moves[w.floating] == nil, "gap \(gap): \(w.h.system.frameLog)")
    }
    #expect(w.commands.count == 6)
    expectWindowsMatchLayout(w.h)
  }

  @Test func whatIsTypedMovesNothingUntilItIsHandedOverAndThenOnce() {
    let w = World()
    w.model.go(to: .section(.windows))
    for text in ["3", "30"] { w.model.type(text, into: .setting("gap")) }
    #expect(w.moves().isEmpty && w.commands.isEmpty)
    // Return, then the field loses the keyboard, then the window closes.
    w.model.handOver(.setting("gap"))
    w.model.handOver(.setting("gap"))
    w.close()
    #expect(w.commands == ["set gap 30"])
    #expect(w.moves() == Dictionary(uniqueKeysWithValues: w.docked.map { ($0, 1) }), "\(w.h.system.frameLog)")
    // Typed and left standing when the window closes.
    w.rest()
    w.model.type("20", into: .setting("gap"))
    w.close()
    #expect(w.moves() == Dictionary(uniqueKeysWithValues: w.docked.map { ($0, 1) }), "\(w.h.system.frameLog)")
    expectWindowsMatchLayout(w.h)
  }

  /// Whatever the window shows, now and in time to come, taken to each of its ends and back: no window moves twice for one
  /// change, and none is asked to take the keyboard.
  @Test func noControlOfTheWindowMovesAWindowTwice() {
    for section in SettingsSection.allCases {
      let keys = World().model
      keys.setAdvanced(true, in: section)
      for row in keys.rows(in: section) + keys.advancedRows(in: section) {
        let values: [String]
        switch row.control {
        case .toggle: values = ["true", "false"]
        case .number(_, let range, _, _): values = [SettingsPanelModel.text(range.lowerBound), SettingsPanelModel.text(range.upperBound)]
        case .choice(_, let choices): values = choices.map(\.value)
        case .text, .apps, .list: values = []
        }
        for value in values {
          let w = World()
          let asked = w.h.system.focusRequests.count
          w.model.set(row.key, to: value)
          #expect(w.model.errors[row.key] == nil, "\(row.key) \(value): \(w.model.errors[row.key] ?? "")")
          #expect(w.moves().values.allSatisfy { $0 == 1 }, "\(row.key) \(value): \(w.h.system.frameLog)")
          w.rest()
          w.model.reset(row.key)
          #expect(w.moves().values.allSatisfy { $0 == 1 }, "\(row.key) back from \(value): \(w.h.system.frameLog)")
          #expect(w.h.system.focusRequests.count == asked, "\(row.key) \(value)")
          expectWindowsMatchLayout(w.h)
        }
      }
    }
  }
}
