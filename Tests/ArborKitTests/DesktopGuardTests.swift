import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// F60: where the controller says a plain click might land on bare Desktop inside Arbor's view.
@Suite @MainActor struct DesktopGuardTests {
  /// root(h)[a, desktop, b], showing everything.
  func makeHarness() -> (Harness, WindowID, WindowID) {
    // ⇧-drag on the Desktop asks the same question as the guard, and is what asks it in most of these tests.
    let h = Harness(settings: .withGestures)
    let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    return (h, a, b)
  }

  @Test func theDesktopAndTheGapsOfTheCurrentLayoutAreGuarded() {
    let (h, a, b) = makeHarness()
    let zones = h.controller.desktopGuardZones()
    #expect(zones.mayBeBare(h.layout!.desktopFrame!.center), "the Desktop")
    let edge = CGPoint(x: h.visibleFrame.minX + 3, y: h.visibleFrame.midY)
    #expect(zones.mayBeBare(edge), "the gap between a window and the edge of the display")
    #expect(!zones.mayBeBare(h.frame(a)!.center))
    #expect(!zones.mayBeBare(h.frame(b)!.center))
  }

  @Test func gapHandlesKeepTheirPresses() {
    // A press there is the beginning of a resize, and lands on Arbor's panel, not on the wallpaper.
    let (h, _, _) = makeHarness()
    let zones = h.controller.desktopGuardZones()
    #expect(!h.layout!.seams.isEmpty)
    for seam in h.layout!.seams {
      #expect(!zones.mayBeBare(seam.frame.center))
      #expect(zones.mayBeBare(seam.frame.center, throughPanels: true), "a rectangle may start there")
    }
  }

  @Test func theWallpaperAroundAWindowThatCannotFillItsSlotIsGuarded() {
    // Calculator, System Settings: centred in their slot, with wallpaper all round, inside what looks like
    // Arbor's territory.
    let h = Harness(settings: .withGestures)
    let a = h.system.open(app: "Calculator", frame: CGRect(x: 100, y: 100, width: 200, height: 300))
    h.system.setMaximumSize(a, CGSize(width: 200, height: 300))
    h.start()
    h.run("dock \(a.rawValue) left")
    h.scheduler.runPending()
    let slot = h.layout!.windowFrames[a]!
    let real = h.frame(a)!
    #expect(real.width <= 200 && slot.width > 300)
    let zones = h.controller.desktopGuardZones()
    #expect(!zones.mayBeBare(real.center), "the window itself")
    #expect(zones.mayBeBare(CGPoint(x: slot.minX + 5, y: slot.minY + 5)), "its slot's corner, where the wallpaper shows")
  }

  @Test func floatingWindowsAreAWayOutToo() {
    let (h, _, _) = makeHarness()
    let desktop = h.layout!.desktopFrame!
    let floating = h.system.open(app: "Mail", frame: desktop.insetBy(dx: 40, dy: 200))
    h.scheduler.runPending()
    let zones = h.controller.desktopGuardZones()
    #expect(!zones.mayBeBare(h.frame(floating)!.center))
    #expect(zones.mayBeBare(CGPoint(x: desktop.midX, y: desktop.maxY - 20)), "below it")
  }

  @Test func aPinnedWindowIsAWayOutThroughEveryCameraMove() {
    // F49: it stays in view when the floating windows leave with the Desktop, so a click on it stays its own.
    let (h, a, _) = makeHarness()
    let desktop = h.layout!.desktopFrame!
    let call = h.system.open(app: "Zoom", frame: CGRect(x: desktop.midX - 100, y: desktop.midY - 80, width: 200, height: 160))
    h.scheduler.runPending()
    h.run("pin \(call.rawValue)")
    var published = h.controller.desktopGuardZones()
    h.controller.observe { if $0.mayChangeDesktopGuardZones { published = h.controller.desktopGuardZones() } }
    for command in ["zoom \(a.rawValue)", "back", "desktop", "show-all"] {
      h.run(command)
      h.scheduler.advance(by: 1)
      #expect(!published.isEmpty, "after \(command)")
      #expect(!published.mayBeBare(h.frame(call)!.center), "after \(command)")
    }
    h.run("unpin \(call.rawValue)")
    #expect(published == h.controller.desktopGuardZones(), "after unpin")
  }

  @Test func aPinnedWindowAloneIsNothingDocked() {
    let h = Harness(settings: .withGestures)
    let call = h.system.open(app: "Zoom", frame: CGRect(x: 100, y: 100, width: 320, height: 240))
    h.start()
    h.run("pin \(call.rawValue)")
    #expect(h.controller.desktopGuardZones().isEmpty)
  }

  @Test func windowsOutOfViewAreNoWayOut() {
    // They wait past a corner of the display; what Arbor last knew of their frames must not punch holes.
    let (h, a, b) = makeHarness()
    let wasAt = h.frame(b)!.center
    h.run("desktop")
    #expect(!h.system.isVisible(a) && !h.system.isVisible(b))
    #expect(h.controller.desktopGuardZones().mayBeBare(wasAt))
    h.run("show-all")
    h.system.setMinimized(b, true)
    h.scheduler.runPending()
    #expect(h.controller.desktopGuardZones().displays.allSatisfy { $0.windows.count == 1 })
  }

  @Test func tilesKeepTheirClicks() {
    let (h, _, b) = makeHarness()
    let big = h.system.open(app: "Xcode", frame: CGRect(x: 400, y: 200, width: 700, height: 500))
    h.system.setMinimumSize(big, CGSize(width: 1250, height: 700))
    h.run("dock \(big.rawValue) beside \(b.rawValue) bottom")
    let tile = h.layout!.tiles.first!
    #expect(!h.controller.desktopGuardZones().mayBeBare(tile.frame.center))
    #expect(h.controller.desktopGuardZones().mayBeBare(tile.frame.center, throughPanels: true))
  }

  @Test func theMenuBarAndTheDockAreOutsideTheView() {
    let (h, _, _) = makeHarness()
    let display = h.system.displayList[0]
    #expect(display.frame != display.visibleFrame)
    #expect(!h.controller.desktopGuardZones().mayBeBare(CGPoint(x: display.frame.midX, y: display.frame.minY + 2)))
  }

  @Test func theZonesFollowTheView() {
    let (h, a, b) = makeHarness()
    let desktop = h.layout!.desktopFrame!.center
    h.run("zoom \(a.rawValue)")
    #expect(!h.controller.desktopGuardZones().mayBeBare(desktop), "the framed window is there now")
    h.run("desktop")
    // Only the Desktop is in view, but windows are docked, and a sweep would take the floating ones.
    #expect(h.controller.desktopGuardZones().mayBeBare(desktop))
    #expect(h.controller.desktopGuardZones().mayBeBare(CGPoint(x: h.visibleFrame.minX + 60, y: h.visibleFrame.midY)))
    _ = b
  }

  @Test func withNothingDockedNothingIsGuarded() {
    let h = Harness(settings: .withGestures)
    _ = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    h.start()
    #expect(h.controller.desktopGuardZones().isEmpty)
  }

  @Test func afterFloatAllNothingIsGuarded() {
    let (h, _, _) = makeHarness()
    #expect(!h.controller.desktopGuardZones().isEmpty)
    h.run("float-all")
    #expect(h.controller.desktopGuardZones().isEmpty)
  }

  @Test func whilePausedNothingIsGuarded() {
    let (h, _, _) = makeHarness()
    h.run("pause")
    #expect(h.controller.desktopGuardZones().isEmpty)
    #expect(!h.controller.inputSettings.guardDesktopClicks)
    h.run("resume")
    #expect(!h.controller.desktopGuardZones().isEmpty)
  }

  @Test func whileAnAppThatKeepsItsOwnKeysIsInFrontNothingIsGuarded() {
    // F41: no event may pass through Arbor then, so the guard goes with the rest, and the tap's copy hears of it.
    var settings = Settings.withGestures
    settings.passThroughApps = ["com.example.emacs"]
    let h = Harness(settings: settings)
    let emacs = h.system.open(app: "Emacs")
    let safari = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(emacs.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.userFocus(safari)
    var published = h.controller.desktopGuardZones()
    h.controller.observe { if $0.mayChangeDesktopGuardZones { published = h.controller.desktopGuardZones() } }
    #expect(!published.isEmpty)

    h.system.userFocus(emacs)
    #expect(h.controller.isPassingThrough)
    #expect(h.controller.desktopGuardZones().isEmpty)
    #expect(published.isEmpty, "the tap's copy")
    var gesture = RectangleGesture()
    gesture.follow(h.controller.inputSettings)
    #expect(!gesture.isEnabled, "the taps go")

    h.system.userFocus(safari)
    #expect(!published.isEmpty)
    #expect(published == h.controller.desktopGuardZones())
  }

  @Test func theZonesAreThereForWhicheverOfTheTwoWantsThem() {
    // The guard and ⇧-drag ask the same question.
    let (h, _, _) = makeHarness()
    var settings = h.controller.settings
    settings.guardDesktopClicks = false
    h.controller.apply(settings: settings)
    #expect(!h.controller.desktopGuardZones().isEmpty, "⇧-drag is still on")
    settings.frameRectangleOnDesktop = false
    h.controller.apply(settings: settings)
    #expect(h.controller.desktopGuardZones().isEmpty)
    settings.guardDesktopClicks = true
    h.controller.apply(settings: settings)
    #expect(!h.controller.desktopGuardZones().isEmpty)
  }

  /// F55's `scrollOnDesktopZooms` asks the same question of a scroll.
  @Test func theZonesAreThereForAScrollOnTheDesktopToo() {
    let (h, a, _) = makeHarness()
    var settings = h.controller.settings
    settings.guardDesktopClicks = false
    settings.frameRectangleOnDesktop = false
    settings.scrollOnDesktopZooms = true
    h.controller.apply(settings: settings)
    let zones = h.controller.desktopGuardZones()
    #expect(zones.mayBeBare(h.layout!.desktopFrame!.center, throughPanels: true))
    #expect(!zones.mayBeBare(h.frame(a)!.center, throughPanels: true), "a window Arbor knows: nobody need read the window list")
    // Not if a scroll cannot zoom anyway.
    for off in [\Settings.scrollZoom, \Settings.gesturesEnabled, \Settings.pointerGestures] {
      var without = settings
      without[keyPath: off] = false
      h.controller.apply(settings: without)
      #expect(h.controller.desktopGuardZones().isEmpty)
    }
    h.controller.apply(settings: settings)
    h.run("pause")
    #expect(h.controller.desktopGuardZones().isEmpty)
  }

  /// The tap decides from a copy. Whatever switches the scroll on or off has to bring a new one.
  @Test func switchedOnAndOffByCommandTheTapsCopyFollows() {
    let (h, _, _) = makeHarness()
    var settings = h.controller.settings
    settings.guardDesktopClicks = false
    settings.frameRectangleOnDesktop = false
    h.controller.apply(settings: settings)
    var published = h.controller.desktopGuardZones()
    h.controller.observe { [unowned controller = h.controller] in
      if $0.mayChangeDesktopGuardZones { published = controller.desktopGuardZones() }
    }
    #expect(published.isEmpty)
    #expect(h.run("set scrollOnDesktopZooms true").ok)
    #expect(!published.isEmpty)
    for command in [
      "set scrollZoom false", "set scrollZoom true", "set gesturesEnabled false", "set gesturesEnabled true", "pause", "resume",
      "set pointerGestures false", "set pointerGestures true",
      "set scrollOnDesktopZooms false",
    ] {
      h.run(command)
      #expect(published == h.controller.desktopGuardZones(), "after \(command)")
    }
    #expect(published.isEmpty)
  }

  /// Arbor runs, and gestures are the app's: `inputSettings` decides, not the settings as they are written.
  @Test func inAnAppThatKeepsItsKeysThereAreNoZonesForAScrollEither() {
    var settings = Settings.withGestures
    settings.passThroughApps = ["com.example.emacs"]
    settings.guardDesktopClicks = false
    settings.frameRectangleOnDesktop = false
    settings.scrollOnDesktopZooms = true
    let h = Harness(settings: settings)
    let emacs = h.system.open(app: "Emacs")
    let safari = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(emacs.rawValue) left")
    h.run("dock \(safari.rawValue) right")
    h.system.userFocus(safari)
    #expect(!h.controller.desktopGuardZones().isEmpty)
    h.system.userFocus(emacs)
    #expect(h.controller.isRunning && h.controller.isPassingThrough)
    #expect(h.controller.desktopGuardZones().isEmpty)
  }

  @Test func beforeTheStartNothingIsGuarded() {
    #expect(Harness(settings: .withGestures).controller.desktopGuardZones().isEmpty)
  }

  @Test func onlyDisplaysWithSomethingDockedAreGuarded() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
      visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side], settings: .withGestures)
    let main = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
    _ = h.system.open(app: "Notes", frame: CGRect(x: 1500, y: 100, width: 500, height: 400))
    h.start()
    h.run("dock \(main.rawValue) left")
    let zones = h.controller.desktopGuardZones()
    #expect(zones.displays.count == 1)
    #expect(zones.mayBeBare(h.layout!.desktopFrame!.center))
    #expect(!zones.mayBeBare(CGPoint(x: 2400, y: 600)))
  }

  @Test func theAnswerDoesNotDependOnTheOrderOfADictionary() {
    let (h, _, _) = makeHarness()
    #expect(h.controller.desktopGuardZones() == h.controller.desktopGuardZones())
  }

  @Test func observersHearWheneverTheZonesChange() {
    // The tap's copy is refreshed from an observer, so every change must announce itself.
    let (h, a, _) = makeHarness()
    var published = h.controller.desktopGuardZones()
    h.controller.observe { if $0.mayChangeDesktopGuardZones { published = h.controller.desktopGuardZones() } }
    for command in ["zoom \(a.rawValue)", "back", "desktop", "show-all", "float-all", "arrange", "pause", "resume"] {
      h.run(command)
      #expect(published == h.controller.desktopGuardZones(), "after \(command)")
    }
    var settings = h.controller.settings
    settings.guardDesktopClicks = false
    settings.frameRectangleOnDesktop = false
    h.controller.apply(settings: settings)
    #expect(published == h.controller.desktopGuardZones(), "after the settings changed")
  }

  @Test func observersHearOfAWindowThatOpensOverTheDesktop() {
    // It floats where its app put it: no layout, and until 2026-10-14 no word to observers.
    let (h, _, _) = makeHarness()
    let desktop = h.layout!.desktopFrame!
    var published = h.controller.desktopGuardZones()
    h.controller.observe { if $0.mayChangeDesktopGuardZones { published = h.controller.desktopGuardZones() } }
    #expect(published.mayBeBare(desktop.center))
    h.system.open(app: "Mail", frame: desktop.insetBy(dx: 40, dy: 200))
    h.scheduler.advance(by: 0)
    #expect(published == h.controller.desktopGuardZones())
    #expect(!published.mayBeBare(desktop.center))
  }

  @Test func observersHearWhenAWindowArborDoesNotArrangeGoes() {
    // It is in the zones like any window Arbor knows to be in view, and in no arrangement, so nothing is laid out when it
    // closes. Left in the copy, a drag with ⇧ would not start where it used to be.
    let (h, _, _) = makeHarness()
    let desktop = h.layout!.desktopFrame!
    h.run("exclude com.example.mail")
    let mail = h.system.open(app: "Mail", frame: desktop.insetBy(dx: 40, dy: 200))
    h.scheduler.advance(by: 0)
    var published = h.controller.desktopGuardZones()
    h.controller.observe { if $0.mayChangeDesktopGuardZones { published = h.controller.desktopGuardZones() } }
    #expect(!published.mayBeBare(desktop.center))
    h.system.close(mail)
    h.scheduler.advance(by: 0)
    #expect(published == h.controller.desktopGuardZones())
    #expect(published.mayBeBare(desktop.center))
  }

  @Test func nothingStaysScheduledWhenObserversWereToldAnyway() {
    let (h, a, _) = makeHarness()
    h.scheduler.runPending()
    for command in ["zoom \(a.rawValue)", "back", "desktop", "show-all"] {
      h.run(command)
      #expect(!h.scheduler.pendingKeys.contains("desktop-guard-zones"), "after \(command)")
    }
  }

  @Test func observersHearWhenTheUserMovesOrClosesAWindow() {
    // No new layout follows, and a frame gone stale would let a click through where the window used to be.
    let (h, _, _) = makeHarness()
    let desktop = h.layout!.desktopFrame!
    let floating = h.system.open(app: "Mail", frame: desktop.insetBy(dx: 40, dy: 200))
    h.scheduler.runPending()
    var published = h.controller.desktopGuardZones()
    h.controller.observe { if $0.mayChangeDesktopGuardZones { published = h.controller.desktopGuardZones() } }
    let wasAt = h.frame(floating)!.center
    h.system.userMove(floating, to: h.frame(floating)!.offsetBy(dx: 0, dy: 190))
    #expect(published == h.controller.desktopGuardZones(), "after a move")
    #expect(published.mayBeBare(CGPoint(x: wasAt.x, y: desktop.minY + 30)), "where its top used to be")
    h.system.setMinimized(floating, true)
    #expect(published == h.controller.desktopGuardZones(), "after minimizing")
    h.system.setMinimized(floating, false)
    #expect(published == h.controller.desktopGuardZones(), "after restoring")
    h.system.close(floating)
    #expect(published == h.controller.desktopGuardZones(), "after closing")
    #expect(published.mayBeBare(desktop.center))
  }
}
