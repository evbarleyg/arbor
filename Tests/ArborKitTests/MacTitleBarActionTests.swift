import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// F14: framing a window replaces macOS's "make it big" at a double-click on a title bar, and nothing else. Whoever chose
/// Minimize or Do Nothing in System Settings has said what they want there.
@Suite @MainActor struct MacTitleBarActionTests {
  /// root(h)[a, Desktop, b] showing everything, on a Mac set to `action`.
  func makeHarness(_ action: MacTitleBarAction, settings: Settings = DoubleClickTests.bothOn) -> (Harness, WindowID, WindowID) {
    let h = Harness(settings: settings)
    h.system.titleBarAction = action
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b)
  }

  func titleBar(_ h: Harness, _ window: WindowID) -> CGPoint {
    let frame = h.frame(window)!
    return CGPoint(x: frame.midX, y: frame.minY + 12)
  }

  @Test func whereMacOSMakesTheWindowBigArborFramesIt() {
    for action in [MacTitleBarAction.fill, .zoom] {
      let (h, a, _) = makeHarness(action)
      #expect(h.controller.inputSettings.titleBarDoubleClick, "\(action)")
      #expect(h.system.doubleClick(at: titleBar(h, a)), "\(action)")
      #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a), "\(action)")
    }
  }

  @Test func whoeverChoseMinimizeOrNothingKeepsIt() {
    for action in [MacTitleBarAction.minimize, .nothing] {
      let (h, a, _) = makeHarness(action)
      #expect(h.controller.settings.titleBarDoubleClick, "the switch is theirs, and stays as they set it")
      #expect(!h.controller.inputSettings.titleBarDoubleClick, "\(action)")
      #expect(h.controller.doubleClickZones().displays.allSatisfy { $0.titleBars.isEmpty }, "\(action)")
      #expect(!h.system.doubleClick(at: titleBar(h, a)), "\(action)")
      #expect(h.workspace.camera == h.workspace.tree.root, "\(action)")
    }
  }

  @Test func theDesktopsDoubleClickIsNotTouchedByIt() {
    let (h, _, _) = makeHarness(.minimize)
    #expect(h.controller.inputSettings.desktopDoubleClick)
    #expect(h.controller.inputSettings.wantsDoubleClickTap)
    #expect(h.system.doubleClick(at: h.layout!.desktopFrame!.center))
    #expect(h.workspace.camera == h.workspace.tree.desktop)
  }

  @Test func withNothingLeftToTapForThereIsNoTap() {
    let (h, _, _) = makeHarness(.nothing, settings: DoubleClickTests.titleBarsOn)
    #expect(!h.controller.inputSettings.wantsDoubleClickTap)
    #expect(h.controller.doubleClickZones() == DoubleClickZones())
  }

  /// People change it while Arbor runs. The taps hear of it as of anything that changes what Arbor listens to.
  @Test func itIsReadAfreshAtEveryLayout() {
    let (h, a, _) = makeHarness(.fill, settings: DoubleClickTests.titleBarsOn)
    var heard = 0
    h.controller.observe { if $0 == .input { heard += 1 } }
    h.system.titleBarAction = .minimize
    #expect(h.controller.inputSettings.titleBarDoubleClick, "not before something is laid out")
    h.run("relayout")
    #expect(heard == 1)
    #expect(!h.controller.inputSettings.wantsDoubleClickTap)
    #expect(!h.system.doubleClick(at: titleBar(h, a)))
    h.run("relayout")
    #expect(heard == 1, "said once")

    h.system.titleBarAction = .zoom
    h.run("relayout")
    #expect(heard == 2)
    #expect(h.system.doubleClick(at: titleBar(h, a)))
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: a))
  }

  /// Minimized by macOS, as the person asked: like any window that is minimized.
  @Test func minimizingADockedWindowIsWhatItAlwaysWas() {
    let (h, a, b) = makeHarness(.minimize)
    #expect(!h.system.doubleClick(at: titleBar(h, a)))
    h.system.setMinimized(a, true)
    h.scheduler.advance(by: 1)
    #expect(h.layout?.windowFrames[a] == nil)
    #expect(h.layout?.windowFrames[b] != nil)
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func turningTheSwitchOnLooksAtOnce() {
    var settings = Settings()
    settings.pointerGestures = true
    let (h, a, _) = makeHarness(.minimize, settings: settings)
    #expect(h.run("set titleBarDoubleClick true").ok)
    #expect(!h.controller.inputSettings.titleBarDoubleClick)
    #expect(!h.system.doubleClick(at: titleBar(h, a)))
  }

  // MARK: So that nobody wonders why the switch does nothing

  @Test func doctorSaysWhyTheSwitchDoesNothing() {
    let (h, _, _) = makeHarness(.minimize)
    let check = h.controller.doctorReport().check("Double-click title bars")
    #expect(check?.mark == .note)
    #expect(check?.detail == "macOS is set to minimize at a double-click, so Arbor leaves title bars alone")
    h.system.titleBarAction = .nothing
    #expect(
      h.controller.doctorReport().check("Double-click title bars")?.detail
        == "macOS is set to do nothing at a double-click, so Arbor leaves title bars alone", "asked afresh")
  }

  /// What `doctor` says and what the taps do is one answer, whichever is asked first.
  @Test func askingDoctorBringsTheTapsUpToDate() {
    let (h, a, _) = makeHarness(.fill, settings: DoubleClickTests.titleBarsOn)
    h.system.titleBarAction = .minimize
    #expect(h.controller.inputSettings.wantsDoubleClickTap, "nothing has been laid out since")
    #expect(h.controller.doctorReport().check("Double-click title bars") != nil)
    #expect(!h.controller.inputSettings.wantsDoubleClickTap)
    #expect(!h.system.doubleClick(at: titleBar(h, a)))
    h.system.titleBarAction = .fill
    #expect(h.controller.doctorReport().check("Double-click title bars") == nil)
    #expect(h.controller.inputSettings.wantsDoubleClickTap)
  }

  @Test func betweenFillAndZoomNothingChangesForArbor() {
    let (h, _, _) = makeHarness(.fill, settings: DoubleClickTests.titleBarsOn)
    var heard = 0
    h.controller.observe { if $0 == .input { heard += 1 } }
    h.system.titleBarAction = .zoom
    h.run("relayout")
    #expect(heard == 0)
  }

  @Test func doctorSaysNothingWhereThereIsNothingToWonderAbout() {
    #expect(makeHarness(.fill).0.controller.doctorReport().check("Double-click title bars") == nil)
    #expect(makeHarness(.minimize, settings: Settings()).0.controller.doctorReport().check("Double-click title bars") == nil)
  }

  @Test func theSettingsWindowsRowSaysItToo() {
    func help(_ action: MacTitleBarAction, _ settings: Settings) -> String? {
      let (h, _, _) = makeHarness(action, settings: settings)
      let model = SettingsPanelModel(controller: h.controller, runningApps: { [] }, run: { h.controller.perform($0) })
      return SettingsSection.allCases.flatMap { model.rows(in: $0) + model.advancedRows(in: $0) }
        .first { $0.key == "titleBarDoubleClick" }?.help
    }
    let plain = help(.fill, DoubleClickTests.titleBarsOn)
    #expect(plain?.hasPrefix("Double-clicking a docked window's title bar frames the window") == true)
    #expect(
      help(.minimize, DoubleClickTests.titleBarsOn)
        == "macOS is set to minimize at a double-click, so Arbor leaves title bars alone. " + (plain ?? ""))
    #expect(help(.minimize, Settings()) == plain, "with the switch off there is nothing to explain")
  }
}
