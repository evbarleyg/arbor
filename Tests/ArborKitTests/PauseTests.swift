import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Testing

/// Pausing and resuming (docs/features/F40-pause.md).
@Suite @MainActor struct PauseTests {
  /// [a | Desktop | b / c] with d floating, framed on c: a and b are out of view. As Arbor ships d stays where it floats.
  /// `makingWay`: floating windows make way, so d is on the Desktop and out of view with it.
  func makeHarness(makingWay: Bool = false) -> (Harness, WindowID, WindowID, WindowID, WindowID) {
    var settings = Settings.withGestures  // which a pause switches off
    settings.floatingWindowsMakeWay = makingWay
    let h = Harness(settings: settings)
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    let c = h.system.open(app: "Notes")
    let d = h.system.open(app: "Slack")
    h.start()
    h.run("dock \(a.rawValue) left")
    h.run("dock \(b.rawValue) right")
    h.run("dock \(c.rawValue) beside \(b.rawValue) bottom")
    h.run("zoom \(c.rawValue)")
    return (h, a, b, c, d)
  }

  @Test(arguments: [false, true]) func pausingBringsEveryWindowBackIntoView(makingWay: Bool) {
    let (h, a, b, c, d) = makeHarness(makingWay: makingWay)
    for window in makingWay ? [a, b, d] : [a, b] { #expect(!h.system.isVisible(window), "\(window) starts out of view") }
    if !makingWay { #expect(h.system.isVisible(d), "what floats never left") }

    #expect(h.run("pause").ok)
    for window in [a, b, c, d] {
      #expect(h.frame(window)!.fractionInside(h.visibleFrame) > 0.99, "\(window) is in view")
    }
    #expect(h.controller.parked.isEmpty)
    #expect(h.overlays.scenes.isEmpty, "no tiles or seam handles are left on screen")
  }

  @Test func whilePausedArborMovesNothingWhateverHappens() {
    let (h, a, b, c, _) = makeHarness()
    h.run("pause")
    let moves = h.system.frameLog.count

    h.system.userMove(a, to: CGRect(x: 40, y: 60, width: 300, height: 200))
    h.system.drag(c, through: [CGPoint(x: 700, y: 400), CGPoint(x: 2, y: 400)])
    h.system.setMinimized(b, true)
    h.system.userFocus(a)
    let e = h.system.open(app: "Keynote")
    h.system.close(e)
    h.system.setDisplays(h.system.displayList)
    h.scheduler.runPending()

    #expect(h.system.frameLog.count == moves)
    #expect(h.overlays.preview == nil)
    #expect(h.overlays.scenes.isEmpty)
  }

  @Test func commandsSayWhyTheyDoNothingWhilePaused() {
    let (h, a, _, _, _) = makeHarness()
    h.run("pause")
    for text in ["dock \(a.rawValue) left", "show-all", "home", "arrange", "float-all", "relayout"] {
      let result = h.run(text)
      #expect(!result.ok, "\(text)")
      #expect(result.message.contains("paused") && result.message.contains("resume"), "\(text): \(result.message)")
    }
    #expect(h.run("status").message.contains("paused"))
    #expect(h.run("help").ok)
    #expect(h.run("bindings").ok)
  }

  @Test func stateSaysPausedAndShowsNoStaleFrames() {
    let (h, _, _, c, _) = makeHarness()
    #expect(h.run("state").state?.paused == false)
    h.run("pause")
    let state = h.run("state").state!
    #expect(state.paused)
    #expect(!state.running)
    #expect(state.displays[0].windowFrames.isEmpty)
    #expect(state.displays[0].tree.leaf(containing: c) != nil, "the arrangement that will come back is still listed")
  }

  @Test(arguments: [false, true]) func resumingRestoresTheArrangementAndTheCamera(makingWay: Bool) {
    let (h, a, b, c, d) = makeHarness(makingWay: makingWay)
    let before = h.workspace
    let frame = h.frame(c)
    let floating = h.frame(d)
    h.run("pause")
    #expect(h.run("resume").ok)

    #expect(h.controller.isRunning)
    #expect(!h.controller.isPaused)
    #expect(h.workspace == before)
    #expect(h.frame(c) == frame)
    for window in makingWay ? [a, b, d] : [a, b] { #expect(!h.system.isVisible(window), "\(window) is out of view again") }
    if !makingWay { #expect(h.frame(d) == floating && h.system.isVisible(d), "what floats is where it was, in view") }
    expectWindowsMatchLayout(h, on: h.display)
    #expect(h.run("back").ok, "history survives")
  }

  @Test func resumingCopesWithWhatChangedMeanwhile() {
    let (h, a, b, c, _) = makeHarness()
    h.run("pause")
    h.system.close(b)
    let e = h.system.open(app: "Keynote")
    h.system.userMove(a, to: CGRect(x: 40, y: 60, width: 300, height: 200))
    h.run("resume")

    #expect(!h.workspace.contains(b), "a window closed during the pause leaves no empty slot")
    #expect(h.workspace.isFloating(e), "a window opened during the pause floats, as at launch")
    #expect(h.workspace.isDocked(a) && h.workspace.isDocked(c))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    h.run("show-all")
    expectWindowsMatchLayout(h, on: h.display)
    #expect(h.layout?.windowFrames[a] == h.frame(a), "a window moved by hand during the pause returns to its slot")
  }

  /// The real window system stops observing during a pause, so nothing is reported at all.
  @Test func resumingCopesWithChangesNobodyReported() {
    let (h, a, b, c, d) = makeHarness()
    h.run("pause")
    h.system.events = nil
    h.system.close(b)
    h.system.close(d)
    h.system.userMove(a, to: CGRect(x: 40, y: 60, width: 300, height: 200))
    h.system.events = h.controller
    h.run("resume")

    #expect(h.controller.windows[b] == nil && h.controller.windows[d] == nil)
    #expect(!h.workspace.contains(b) && !h.workspace.contains(d))
    #expect(h.workspace.tree.invariantViolations().isEmpty)
    h.run("show-all")
    #expect(h.layout?.windowFrames.keys.sorted() == [a, c])
    expectWindowsMatchLayout(h, on: h.display)
  }

  @Test func aWindowOpenedDuringThePauseStaysInViewWhenTheViewIsFramed() {
    // Framed on a virtual machine, paused for its ⌃⌥; a note is opened meanwhile. Resuming must not sweep it away.
    let (h, _, _, c, _) = makeHarness()
    h.run("pause")
    let place = CGRect(x: 500, y: 300, width: 400, height: 300)
    let note = h.system.open(app: "Stickies", frame: place)
    h.run("resume")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: c), "the view is as it was")
    #expect(h.frame(note) == place, "\(h.frame(note)!)")
    #expect(!h.controller.parked.contains(note))
    // It belongs to the view it was opened over, like a window opened while Arbor is looking (F57).
    h.run("show-all")
    h.run("back")
    #expect(h.frame(note) == place, "and comes back with it")
  }

  /// Where floating windows make way that is one that stays in view until the view next moves. As Arbor ships it stays for good.
  @Test(arguments: [false, true]) func withGuestsOffItIsAFloatingWindowLikeAnyOther(makingWay: Bool) {
    let (h, _, _, _, _) = makeHarness(makingWay: makingWay)
    var settings = h.controller.settings
    settings.newWindowsWhileFramed = "float"
    h.controller.apply(settings: settings)
    h.run("pause")
    let place = CGRect(x: 500, y: 300, width: 400, height: 300)
    let note = h.system.open(app: "Stickies", frame: place)
    h.run("resume")
    #expect(h.frame(note) == place, "like a window that opens while Arbor is looking")
    #expect(h.workspace.guests?[note] == nil)
    h.run("out")
    h.run("back")
    if makingWay {
      #expect(!h.system.isVisible(note), "it belongs to the Desktop")
    } else {
      #expect(h.frame(note) == place, "no view takes it away")
    }
  }

  @Test func theFloatingWindowsArborKnewStillGoOutOfViewWithTheDesktop() {
    // Floating windows that make way: only they leave with the Desktop.
    let (h, _, _, _, d) = makeHarness(makingWay: true)
    h.run("pause")
    #expect(h.system.isVisible(d))
    h.run("resume")
    #expect(!h.system.isVisible(d), "the view is framed, as before the pause")
  }

  @Test func aWindowOpenedDuringThePauseWithTheDesktopInViewIsAnOrdinaryFloatingWindow() {
    let (h, _, _, _, _) = makeHarness()
    h.run("show-all")
    h.run("pause")
    let note = h.system.open(app: "Stickies", frame: CGRect(x: 600, y: 300, width: 200, height: 200))
    h.run("resume")
    #expect(h.workspace.isFloating(note))
    #expect(h.workspace.guests?[note] == nil)
  }

  @Test func aWindowOpenedWhileArborWasNotRunningStaysInViewAtLaunch() {
    let (first, a, b, c, d) = makeHarness()
    first.controller.shutdown()
    let h = Harness(saved: first.store.saved)
    for (app, id) in [("Safari", a), ("Mail", b), ("Notes", c), ("Slack", d)] { #expect(h.system.open(app: app) == id) }
    let place = CGRect(x: 500, y: 300, width: 400, height: 300)
    let note = h.system.open(app: "Stickies", frame: place)
    h.start()
    #expect(h.workspace.camera == h.workspace.tree.root, "the saved view is framed, and a launch shows everything")
    #expect(h.frame(note) == place)
    #expect(h.system.isVisible(d))
  }

  @Test(arguments: [false, true])
  func aWindowOpenedWhileArborWasDownStaysInViewWhenTheWatchdogBringsTheViewBack(makingWay: Bool) {
    let (first, _, _, c, d) = makeHarness(makingWay: makingWay)
    first.controller.saveNow()
    let h = Harness(settings: makingWay ? .makingWay : Settings(), saved: first.store.saved)
    for window in first.system.allWindows() {
      h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    let place = CGRect(x: 500, y: 300, width: 400, height: 300)
    let note = h.system.open(app: "Stickies", frame: place)
    h.controller.restartedAfterAccident = true
    h.start()
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: c), "the view of a moment ago")
    #expect(h.frame(note) == place)
    // What the arrangement knows is where the arrangement has it: out of view with the Desktop where floating windows make way,
    // and where it floats as Arbor ships.
    if makingWay {
      #expect(!h.system.isVisible(d))
    } else {
      #expect(h.frame(d) == first.frame(d) && h.system.isVisible(d))
    }
  }

  @Test func resumingDoesNotDependOnTheSavedFile() {
    let (h, _, _, c, _) = makeHarness()
    let before = h.workspace
    h.run("pause")
    h.store.saved = nil  // the disk was full, or someone tidied the folder
    h.run("resume")
    #expect(h.workspace == before)
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: c))
  }

  @Test func aLaterLaunchReadsTheFileNotThePause() {
    let (h, _, _, _, _) = makeHarness()
    h.run("pause")
    h.run("resume")
    h.run("home")
    h.controller.shutdown()
    h.controller.start()
    #expect(h.workspace.camera == h.workspace.tree.root, "what was kept for the resume is used once")
  }

  @Test func aTimedPauseEndsByItself() {
    let (h, _, _, _, _) = makeHarness()
    #expect(h.run("pause 30").message.contains("30 minutes"))
    h.scheduler.advance(by: 29 * 60)
    #expect(h.controller.isPaused)
    h.scheduler.advance(by: 61)
    #expect(!h.controller.isPaused)
    #expect(h.controller.isRunning)
  }

  @Test func aSecondPauseReplacesTheFirstOnesEnd() {
    let (h, _, _, _, _) = makeHarness()
    h.run("pause 1")
    #expect(h.run("pause 10").ok)
    h.scheduler.advance(by: 5 * 60)
    #expect(h.controller.isPaused, "the one-minute end was replaced")
    #expect(h.run("pause").ok)
    h.scheduler.advance(by: 60 * 60)
    #expect(h.controller.isPaused, "a pause without a number has no end")
  }

  @Test func resumingByHandCancelsTheTimer() {
    let (h, _, _, _, _) = makeHarness()
    h.run("pause 1")
    h.run("resume")
    h.run("pause")
    h.scheduler.advance(by: 120)
    #expect(h.controller.isPaused, "the first pause's timer must not end the second pause")
  }

  @Test func togglePauseGoesBothWays() {
    let (h, _, _, _, _) = makeHarness()
    #expect(h.run("toggle-pause").ok)
    #expect(h.controller.isPaused)
    #expect(h.run("toggle-pause").ok)
    #expect(!h.controller.isPaused)
    #expect(!h.run("resume").ok, "nothing to resume")
  }

  @Test func pausingDuringADragDropsTheDrag() {
    let (h, _, _, c, _) = makeHarness()
    h.run("show-all")
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.heldModifiers = DragDocks.key  // held by whoever means to dock, as Arbor ships
    h.controller.dragBegan(c, at: CGPoint(x: 1200, y: 600))
    h.controller.dragMoved(c, to: CGPoint(x: 3, y: 400))
    #expect(h.overlays.preview != nil)
    h.run("pause")
    #expect(h.overlays.preview == nil)
    let moves = h.system.frameLog.count
    h.controller.dragEnded(c, at: CGPoint(x: 3, y: 400))
    #expect(h.system.frameLog.count == moves)
  }

  @Test func pauseNeedsArborToBeRunning() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    let result = h.run("pause")
    #expect(!result.ok)
    #expect(result.message.contains("Accessibility"))
    #expect(!h.controller.isPaused)
  }

  @Test func quittingWhilePausedIsSafe() {
    let (h, a, b, c, d) = makeHarness()
    h.run("pause")
    h.controller.shutdown()
    for window in [a, b, c, d] { #expect(h.frame(window)!.fractionInside(h.visibleFrame) > 0.99) }
    #expect(h.store.saved?.workspaces[h.display]?.isDocked(c) == true, "the arrangement is saved for the next launch")
  }

  @Test func anIgnoredWindowStaysIgnoredAcrossAPause() {
    var settings = Settings()
    settings.rules = [AppRule(app: "com.example.zoom", action: .ignore)]
    let h = Harness(settings: settings)
    h.start()
    let call = h.system.open(app: "Zoom")
    h.run("pause")
    h.run("resume")
    #expect(!h.workspace.contains(call))
  }

  // MARK: What the app registers

  @Test func onlyTheShortcutsThatEndThePauseStayRegistered() {
    let kept = KeyBindings.whilePaused(KeyBindings.all)
    #expect(kept.map(\.chord.text) == ["ctrl+opt+escape"])
    #expect(kept.allSatisfy { $0.command == .togglePause })
    var settings = Settings()
    settings.bindings = ["ctrl+opt+cmd+r": "resume", "ctrl+opt+escape": nil]
    #expect(KeyBindings.whilePaused(KeyBindings.effective(settings: settings).bindings).map(\.command) == [.resume])
  }

  @Test func thePointerTapsAreOffWhilePaused() {
    let (h, _, _, _, _) = makeHarness()
    #expect(h.controller.inputSettings == h.controller.settings)
    h.run("pause")
    #expect(!h.controller.inputSettings.gesturesEnabled)
    #expect(h.controller.inputSettings.frameRectangleModifier == "none")
    #expect(h.controller.settings.gesturesEnabled, "the user's own settings are untouched")
    h.run("resume")
    #expect(h.controller.inputSettings == h.controller.settings)
  }

  @Test func observersHearAboutBothEnds() {
    let (h, _, _, _, _) = makeHarness()
    var seen: [Bool] = []
    h.controller.observe { [weak controller = h.controller] change in
      if change == .lifecycle, let controller { seen.append(controller.isPaused) }
    }
    h.run("pause")
    h.run("resume")
    #expect(seen == [true, false])
  }
}
