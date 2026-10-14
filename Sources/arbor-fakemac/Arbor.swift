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
  /// How many of the store's saves have been written to state.json.
  var savesSeen = 0

  // ArborApp
  var activeBindings: [KeyBinding] = [] {
    // As `ArborApp` does: the menu, tooltips and `doctor` go by what is registered.
    didSet { controller.registeredBindings = activeBindings }
  }
  var lastBindings: (bindings: [KeyBinding], problems: [String])?

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
    world: World
  ) {
    self.pid = pid
    self.bundled = bundled
    self.noHotkeys = noHotkeys
    self.noStatusItem = noStatusItem
    overlays = WatchedOverlays(world: world)
    store = MemoryStateStore()
    scheduler = ManualScheduler()
    controller = Controller(
      system: WatchedSystem(world: world), overlays: overlays, store: store, scheduler: scheduler,
      settings: settings,
      filter: WindowFilter(onlyPIDs: onlyPIDs, ownPID: pid))
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

  /// Recorded and not listed among the windows yet: no script asks where the line or the panel of shortcuts is.
  func showHeadsUp(_ model: HeadsUpModel?, on display: DisplayID) { fake.showHeadsUp(model, on: display) }
  func showCheatSheet(_ model: CheatSheetModel?, on display: DisplayID) { fake.showCheatSheet(model, on: display) }

  func removeAll() {
    fake.removeAll()
    for thing in panels { world.forget(thing) }
    previewPanel = nil
    ringPanel = nil
    outlinePanel = nil
    minimapPanel = nil
    namePanel = nil
    palettePanel = nil
  }

  /// A key pressed while the name field has the keyboard, as `NamePanel` and its field editor treat it. False if the
  /// field is not open.
  func typeIntoNameField(_ chord: KeyChord) -> Bool {
    guard namePanel?.shown == true, fake.namePrompt != nil else { return false }
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
