import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics

/// One launch of Arbor: the real controller on the world's windows, and the state that ArborApp and the classes
/// in ArborKit's macOS-only folders keep around it.
@MainActor
final class Arbor {
  let pid: Int32
  /// Started from Arbor.app: macOS delivers URLs to it, and it can be opened at login.
  let bundled: Bool
  let noHotkeys: Bool
  let noStatusItem: Bool
  /// The process that starts Arbor again should it end without quitting, unless ARBOR_NO_WATCHDOG is set.
  var watchdog: Int32?

  let controller: Controller
  let overlays: WatchedOverlays
  let store: MemoryStateStore
  let scheduler: ManualScheduler
  /// `trace on` records here as it does in the app (docs/TRACES.md). The lines stay in memory, in the world's
  /// `traces`: every invocation replays the session from its start, and `Session.publish` writes a trace out
  /// whole.
  let recorder = TraceRecorder()
  /// How many of the store's saves have been written to state.json.
  var savesSeen = 0

  // ArborApp
  /// What `HotKeyCenter` holds: the menu, tooltips and `doctor` go by it too.
  var activeBindings: [KeyBinding] { controller.registeredBindings ?? [] }
  /// `UpdateWindow`: the answer to an update check that somebody asked for. An ordinary window with a title bar, which floats
  /// above the apps' windows. Nothing keeps it once it is closed, and every answer gets a new one. It never has the keyboard
  /// here: the real one activates Arbor and makes itself key, which macOS grants when it was asked for from the menu.
  var updateWindow: (id: UInt32, frame: CGRect)?

  // PointerInput, GestureTap and RectangleFramer
  /// ArborApp makes its `PointerInput` once the controller has started, unless ARBOR_NO_HOTKEYS is set.
  var hasPointerInput = false
  var pinchTap = false
  var scrollTap = false
  var rectangleTaps = false
  /// The last `frameRectangleModifier` that could not be read, so that it is logged once.
  var unreadableModifier: String?
  var gesture = RectangleGesture()
  var router = GestureRouter()
  /// The rubber band's panel, which stays in the window server's list once it has been shown.
  var band: (id: UInt32, frame: CGRect, shown: Bool)?

  /// The menu bar item's menu while it is open.
  var menu: Menu?

  init(
    pid: Int32, bundled: Bool, noHotkeys: Bool, noStatusItem: Bool, onlyPIDs: Set<Int32>?, settings: Settings,
    home: String, world: World
  ) {
    self.pid = pid
    self.bundled = bundled
    self.noHotkeys = noHotkeys
    self.noStatusItem = noStatusItem
    overlays = WatchedOverlays(world: world)
    store = MemoryStateStore()
    scheduler = ManualScheduler()
    // The world's clock, and no word about where it runs: the same session gives the same bytes every time.
    recorder.clock = { [scheduler] in scheduler.now }
    recorder.arborVersion = "rehearsal"
    recorder.osVersion = "rehearsal"
    // The clock is the script's, as in arbor-sim: a second passes with every line, however long a Mac takes.
    recorder.limits.seconds = .infinity
    recorder.openSink = { [unowned world] name in
      let sink = MemoryTraceSink(location: "\(home)/traces/\(name)")
      world.traces[name] = sink
      return sink
    }
    // Through the recording decorators, as `ArborApp` wires them.
    controller = Controller(
      system: RecordingWindowSystem(wrapping: WatchedSystem(world: world), recorder: recorder),
      overlays: RecordingOverlays(wrapping: overlays, recorder: recorder), store: store,
      scheduler: RecordingScheduler(wrapping: scheduler, recorder: recorder), settings: settings,
      filter: WindowFilter(onlyPIDs: onlyPIDs, ownPID: pid))
    controller.shortcutsAreDisabled = noHotkeys
    // `SystemLoginItem`: only an app in a bundle can be a login item.
    if bundled { controller.loginItem = world.loginItem }
    // The little of `ArborApp.systemFacts()` that this Mac has an answer to.
    controller.systemFacts = { [unowned controller] in
      SystemFacts(
        accessibility: controller.accessibilityGranted, screenRecording: true, switches: nil,
        opensAtLogin: bundled ? false : nil, inputDisabled: noHotkeys)
    }
  }
}

/// `GitHubReleaseFeed`, where no release has been published. The answer comes once the command has replied, as GitHub's does.
/// Whatever ARBOR_RELEASES_URL says: nobody is asked.
@MainActor
final class LateReleaseFeed: ReleaseFeed {
  private let scheduler: ManualScheduler

  init(scheduler: ManualScheduler) { self.scheduler = scheduler }

  func latestRelease(_ completion: @escaping @MainActor @Sendable (ReleaseLookup) -> Void) {
    scheduler.schedule("release-feed", after: 0.5) { completion(.nothingPublished) }
  }
}

/// The world's `FakeWindowSystem` as Arbor sees it. The fake answers as macOS does (echoes, whole points, title
/// bars that stay in reach); what is added here is what shows on screen, and silence while Arbor is not
/// listening.
@MainActor
final class WatchedSystem: WindowSystem {
  private unowned let world: World
  private var fake: FakeWindowSystem { world.system }

  init(world: World) { self.world = world }

  /// The controller. `FakeWindowSystem` reports to whoever listens whether or not it has been started; the real
  /// layer takes its observers down when it is stopped, so that a paused Arbor hears nothing at all.
  weak var events: (any WindowSystemEvents)? {
    didSet { if fake.started { fake.events = events } }
  }

  func start() {
    fake.start()
    fake.events = events
  }

  func stop() {
    fake.stop()
    fake.events = nil
  }

  func allWindows() -> [WindowSnapshot] { fake.allWindows() }
  func displays() -> [DisplaySnapshot] { fake.displays() }
  func setFrame(_ frame: CGRect, of window: WindowID) -> CGRect? { fake.setFrame(frame, of: window) }
  func setFrameOnce(_ frame: CGRect, of window: WindowID, pid: Int32) -> CGRect? {
    fake.setFrameOnce(frame, of: window, pid: pid)
  }
  func focusedWindow() -> WindowID? { fake.focusedWindow() }
  func cursorLocation() -> CGPoint { fake.cursorLocation() }
  func isMouseButtonDown() -> Bool { fake.isMouseButtonDown() }
  func modifierKeysDown() -> KeyChord.Modifiers { fake.modifierKeysDown() }
  func macTiling() -> MacTiling { fake.macTiling() }
  func existingWindowIDs() -> Set<WindowID> { fake.existingWindowIDs() }
  func inputActivity() -> InputActivity { fake.inputActivity() }
  func isHolding(_ chord: KeyChord) -> Bool { fake.isHolding(chord) }
  func secondsSinceClickOrModifierKey() -> Double { fake.secondsSinceClickOrModifierKey() }
  func leaveStrayDialogs(_ leave: Bool, exceptOfApp inUse: String?) { fake.leaveStrayDialogs(leave, exceptOfApp: inUse) }
  func bringInStrayDialogs(ofApp bundleID: String?) { fake.bringInStrayDialogs(ofApp: bundleID) }
  func strayDialogsWaiting() -> Int { fake.strayDialogsWaiting() }

  /// `AXWindowSystem.openApplication` looks for a bundle id, for a running app of that name, then in the folders apps are
  /// installed in. In this world the test apps are all there is to find.
  func openApplication(_ app: String) -> Bool {
    let wanted = app.lowercased()
    guard world.apps.values.contains(where: { $0.bundleID.lowercased() == wanted || $0.name.lowercased() == wanted })
    else { return false }
    return fake.openApplication(app)
  }
  func launchApp(_ name: String) -> Bool { fake.launchApp(name) }
  func moveTogether(_ frames: [(window: WindowID, frame: CGRect)]) { fake.moveTogether(frames) }
  func finishMoves(timeout: Double, arborLivesOn: Bool) { fake.finishMoves(timeout: timeout, arborLivesOn: arborLivesOn) }

  func raise(_ window: WindowID) {
    guard fake.windows[window] != nil else { return }
    fake.raise(window)
    world.raise(.window(window.rawValue))
  }

  /// The window server's order, which is the world's: the fake knows nothing of clicks and of apps coming forward.
  func windowsFrontToBack() -> [WindowID] {
    world.order.compactMap { thing in
      if case .window(let id) = thing { return WindowID(id) }
      return nil
    }
  }

  /// In the world's order as well. There is nothing in this world that Arbor cannot see.
  func stackedWindows() -> [StackedWindow] {
    windowsFrontToBack().compactMap { id in
      guard let snapshot = fake.windows[id]?.snapshot, snapshot.isPresent else { return nil }
      return StackedWindow(id: id, frame: world.sweptFrames[id.rawValue] ?? snapshot.frame)
    }
  }

  func setMinimized(_ window: WindowID, _ minimized: Bool) {
    guard fake.windows[window] != nil else { return }
    fake.setMinimized(window, minimized)
    if !minimized { world.raise(.window(window.rawValue)) }
    world.followKeyboard()
  }

  func unhideApp(pid: Int32) {
    world.apps[pid]?.hidden = false
    fake.unhideApp(pid: pid)
    world.followKeyboard()
  }

  /// The window also comes to the front, even if it had the keyboard already.
  func focus(_ window: WindowID) {
    guard fake.windows[window] != nil else { return }
    fake.focus(window)
    world.raise(.window(window.rawValue))
    world.followKeyboard()
  }
}

/// `FakeOverlays`, plus what AppKitOverlays does to the order of windows: every tile and seam is a panel at the
/// ordinary level that comes to the front whenever the layout is shown again.
@MainActor
final class WatchedOverlays: OverlayPresenter {
  let fake = FakeOverlays()
  private unowned let world: World
  /// The drop preview's panel, which stays in the window server's list once it has been shown.
  private(set) var previewPanel: (id: UInt32, frame: CGRect)?
  /// The focus ring's panel, likewise. It lets clicks through and keeps itself directly above its window
  /// (`FocusRingPanel`), so it has no place of its own in the order of windows.
  private(set) var ringPanel: (id: UInt32, frame: CGRect, window: WindowID, shown: Bool)?
  /// `PeekOutlines` keeps one panel too, five points (`PeekOutlineView.reach`) larger all round than the space it outlines.
  private(set) var outlinePanel: (id: UInt32, frame: CGRect, shown: Bool)?
  /// The field a name is typed into (`NamePanel`): its panel, which also stays in the list, what is in the field, and
  /// whether all of that is selected, as it is when the field opens.
  private(set) var namePanel: (id: UInt32, frame: CGRect, shown: Bool)?
  private var typed = (text: "", isSelected: false)
  /// The minimap's panel, which is kept too (`MinimapPanel`), above every window.
  private(set) var minimapPanel: (id: UInt32, frame: CGRect)?

  /// The palette of Go to…, kept once made.
  private(set) var palettePanel: UInt32?
  /// The surface behind docked windows (`BackdropPanel`): one panel as large as the display's visible frame, whatever the
  /// shape drawn in it, just above the Desktop's icons. Kept once made, and the mouse goes straight through it.
  private(set) var backdropPanel: (id: UInt32, frame: CGRect, shown: Bool)?
  /// The heads-up line (`HeadsUpPanel`), of which there is one, kept once made. No click can hit it.
  private(set) var linePanel: (id: UInt32, frame: CGRect, shown: Bool)?
  /// The panel of shortcuts (`CheatSheetPanel`), likewise, but that it has the keyboard and takes clicks while it is up.
  private(set) var shortcutsPanel: (id: UInt32, frame: CGRect, shown: Bool)?

  init(world: World) { self.world = world }

  var actions: (any OverlayActions)? {
    get { fake.actions }
    set { fake.actions = newValue }
  }

  func showDropPreview(_ frame: CGRect?) {
    fake.showDropPreview(frame)
    if let frame { previewPanel = (previewPanel?.id ?? world.newOverlayID(), frame) }
  }

  func showMinimap(_ model: MinimapModel?, on display: DisplayID) {
    fake.showMinimap(model, on: display)
    if let model { minimapPanel = (minimapPanel?.id ?? world.newOverlayID(), model.frame) }
  }

  func update(display: DisplayID, scene: OverlayScene) {
    fake.update(display: display, scene: scene)
    if let ring = scene.focusRing {
      // Room for the flash.
      let area = ring.outerFrame.insetBy(dx: -ring.flashReach, dy: -ring.flashReach)
      ringPanel = (ringPanel?.id ?? world.newOverlayID(), area, ring.window, true)
    } else {
      ringPanel?.shown = false
    }
    if let outline = scene.peekOutline {
      outlinePanel = (outlinePanel?.id ?? world.newOverlayID(), outline.insetBy(dx: -5, dy: -5), true)
    } else {
      outlinePanel?.shown = false
    }
    if let prompt = scene.namePrompt {
      if namePanel?.shown != true { typed = (prompt.initial, true) }
      namePanel = (namePanel?.id ?? world.newOverlayID(), prompt.frame, true)
    } else {
      namePanel?.shown = false
    }
    var shown: Set<World.Thing> = []
    for tile in scene.tiles { shown.insert(.tile(tile.node)) }
    for seam in drawn(scene.seams) { shown.insert(.seam(World.SeamKey(seam))) }
    for thing in panels where !shown.contains(thing) { world.forget(thing) }
    for tile in scene.tiles { show(.tile(tile.node)) }
    for seam in drawn(scene.seams) { show(.seam(World.SeamKey(seam))) }
    // Last, as in `AppKitOverlays.update`: on a Mac the backdrop's number follows that of the first gap's handle.
    if let backdrop = scene.backdrop {
      backdropPanel = (backdropPanel?.id ?? world.newOverlayID(), backdrop.frame, true)
    } else {
      backdropPanel?.shown = false
    }
  }

  /// A new panel gets its window number now, so that the number does not depend on who asks for the list of
  /// windows first.
  private func show(_ thing: World.Thing) {
    _ = world.overlayID(of: thing)
    // `OverlayPanel.orderInBehind`: tiles and gap handles go behind whatever else lies there.
    world.lower(thing)
  }

  /// Recorded and not shown: nothing in this world takes time, so the stage would be down again before anyone could look.
  func animate(_ transition: Transition) { fake.animate(transition) }
  func finishAnimations() { fake.finishAnimations() }
  func rehearse(_ rehearsal: Rehearsal) { fake.rehearse(rehearsal) }

  /// `HeadsUpPanel.placement`. The model says where the middle of the bottom edge is and how wide the line may get; how wide
  /// its words are only AppKit can measure. On a hosted Mac a line was 38 points high, and 231 wide with 26 characters and
  /// 525 with 66: the padding of 10 and 18 points a side, and about seven and a half points a character. That is a guess at
  /// the width, within some 50 points of what hosted Macs have listed: "Resumed" was 102 wide and is 89 here, a line of 65
  /// characters 493 and is 524. A hint is also drawn after a separator of five characters, where `line` has three. The height
  /// holds for a line that wraps: one of 153 characters was listed 713 by 56, and is 720 by 56 here. The controller takes the
  /// line down when its time is up; the real one then fades for a quarter of a second, and nothing in this world takes time.
  func showHeadsUp(_ model: HeadsUpModel?, on display: DisplayID) {
    fake.showHeadsUp(model, on: display)
    guard let model else {
      linePanel?.shown = false
      return
    }
    let words = (CGFloat(model.line.count) * 7.5).rounded(.up)
    let room = model.maximumWidth - 36
    let size = CGSize(width: min(words, room) + 36, height: (words / room).rounded(.up) * 18 + 20)
    let origin = CGPoint(x: (model.anchor.x - size.width / 2).rounded(), y: (model.anchor.y - size.height).rounded())
    linePanel = (linePanel?.id ?? world.newOverlayID(), CGRect(origin: origin, size: size), true)
  }

  /// `CheatSheetPanel.show`: in the middle of the model's area. Its size is the measure of its words, which only AppKit can
  /// take: 967 by 446 on a hosted Mac's display of 1024 by 768, with the shortcuts as they shipped then, before two of its
  /// headings were respelled. That size here, whatever the shortcuts and the display, but for the 24 points that the real one
  /// keeps from the area's edges. Where it does not fit, the real one draws all of it smaller by one factor
  /// (`CheatSheetPanel.layout`); here each side is cut to the room by itself.
  func showCheatSheet(_ model: CheatSheetModel?, on display: DisplayID) {
    fake.showCheatSheet(model, on: display)
    guard let model else {
      shortcutsPanel?.shown = false
      return
    }
    let size = CGSize(width: min(967, model.area.width - 48), height: min(446, model.area.height - 48))
    let origin = CGPoint(x: (model.area.midX - size.width / 2).rounded(), y: (model.area.midY - size.height / 2).rounded())
    shortcutsPanel = (shortcutsPanel?.id ?? world.newOverlayID(), CGRect(origin: origin, size: size), true)
    Log.debug("the panel of shortcuts is up, with the keyboard")
  }

  /// `CheatSheetPanel.dismiss`: a key or a click ends the panel. False if it is not up.
  @discardableResult
  func dismissShortcuts(by cause: String) -> Bool {
    guard shortcutsPanel?.shown == true else { return false }
    Log.debug("the panel of shortcuts is put away by \(cause)")
    fake.dismissCheatSheet()
    shortcutsPanel?.shown = false
    return true
  }

  func removeAll() {
    fake.removeAll()
    for thing in panels { world.forget(thing) }
    previewPanel = nil
    ringPanel = nil
    outlinePanel = nil
    minimapPanel = nil
    namePanel = nil
    palettePanel = nil
    backdropPanel = nil
    linePanel = nil
    shortcutsPanel = nil
  }

  /// A key pressed while the name field has the keyboard, as `NamePanel` and its field editor treat it. False if the
  /// field is not open.
  func typeIntoNameField(_ chord: KeyChord) -> Bool {
    guard namePanel?.shown == true, fake.namePrompt != nil else { return false }
    switch (chord.modifiers, chord.key) {
    case ([.command], .tab), ([.control], .left), ([.control], .right), ([.control], .up):
      // macOS's own, as for the palette (`paletteTakes`): the field loses the keyboard and closes, and the key does what it does.
      fake.cancelName()
      return false
    default: break
    }
    switch chord.key {
    case .returnKey: fake.submitName(typed.text)
    case .escape: fake.cancelName()
    case .delete: typed = (typed.isSelected ? "" : String(typed.text.dropLast()), false)
    default:
      guard chord.modifiers.subtracting(.shift).isEmpty, let character = chord.key == .space ? " " : chord.key.character
      else { return true }
      let text = chord.modifiers.contains(.shift) ? String(character).uppercased() : String(character)
      typed = ((typed.isSelected ? "" : typed.text) + text, false)
    }
    return true
  }

  /// A press anywhere but on the field takes the keyboard away from it.
  func leaveNameField(for point: CGPoint) {
    if let panel = namePanel, panel.shown, !panel.frame.contains(point) { fake.cancelName() }
  }

  /// World+GoTo.swift has the keys and clicks.
  func showFinder(_ model: FinderModel?) {
    fake.showFinder(model)
    if model != nil, palettePanel == nil { palettePanel = world.newOverlayID() }
  }

  private var panels: [World.Thing] {
    world.order.filter { thing in
      if case .window = thing { return false }
      return true
    }
  }

  /// AppKitOverlays leaves out seams too thin to catch.
  private func drawn(_ seams: [Seam]) -> [Seam] { seams.filter { $0.frame.width >= 2 && $0.frame.height >= 2 } }

  func tile(_ node: NodeID) -> TileModel? { fake.scenes[world.display.id]?.tiles.first { $0.node == node } }

  func seam(_ key: World.SeamKey) -> Seam? {
    fake.scenes[world.display.id].flatMap { scene in drawn(scene.seams).first { World.SeamKey($0) == key } }
  }
}
