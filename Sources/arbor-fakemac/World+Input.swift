import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation

/// What the left button is holding, from a press to the release. A `drag --no-release` leaves it for the lines
/// after.
enum Held {
  /// The button is up.
  case nothing
  /// Pressed on something that does nothing more with it: the Desktop, the menu bar.
  case idle
  /// `grip` is from the window's origin to the pointer. `moved`: Arbor has been told that a drag began.
  case title(WindowID, grip: CGSize, moved: Bool, clicks: Int)
  case panelTitle(UInt32, grip: CGSize)
  case resize(WindowID, edges: Set<Edge>, from: CGPoint, frame: CGRect)
  case button(WindowID, String)
  case content(UInt32)
  case seam(World.SeamKey, last: CGPoint)
  case tile(NodeID)
  /// Pressed in a minimap that takes clicks.
  case minimap
  case menuItem(Menu.Path)
  /// Arbor's rectangle tap is holding the press back until it knows whether a drag follows.
  case rectangle(start: CGPoint, clicks: Int)
  /// Pressed on the strip of a window that was swept aside, listed at `from` until then. `taken`: what the
  /// Accessibility layer has taken its way back for, once it has.
  case strip(WindowID, from: CGRect, at: CGPoint, taken: WindowGrab.Verdict)
}

/// What presses, drags, keys and pinches do, decided by what is under the pointer, frontmost first.
extension World {
  static let panelTitleBarHeight: CGFloat = 22
  /// How near a window's border a press must be to catch it, inside or outside.
  private static let borderReach: CGFloat = 4
  /// The part of the title bar that drags the window.
  private static let titleBarReach: CGFloat = 28

  /// Where the window server lists what is at `frame` while all is swept aside.
  func swept(_ frame: CGRect) -> CGRect {
    isSwept ? FakeWindowSystem.whereItWaits(frame, on: display) : frame
  }

  var isButtonDown: Bool {
    if case .nothing = held { return false }
    return true
  }

  private func count(_ kind: String, for id: UInt32, by amount: Int = 1) {
    counts[id]?[kind, default: 0] += amount
  }

  // MARK: Where things are in a window

  private enum Zone {
    case border(Set<Edge>)
    case button(String)
    case title
    case content
  }

  private static let buttonOffsets: [(name: String, x: CGFloat)] = [
    ("close", 14), ("minimize", 34), ("zoom", 54),
  ]

  /// The middle of one of the three buttons. A utility panel has the first only, and a sheet none.
  func buttonCentre(_ name: String, of id: UInt32) -> CGPoint? {
    guard let frame = frame(of: id) else { return nil }
    if extras[id] != nil {
      return extras[id]?.kind == .panel && name == "close"
        ? CGPoint(x: frame.minX + 10, y: frame.minY + 11) : nil
    }
    return World.buttonOffsets.first { $0.name == name }.map {
      CGPoint(x: frame.minX + $0.x, y: frame.minY + 14)
    }
  }

  private func zone(of frame: CGRect, at point: CGPoint) -> Zone {
    var edges: Set<Edge> = []
    if abs(point.x - frame.minX) <= World.borderReach { edges.insert(.left) }
    if abs(point.x - frame.maxX) <= World.borderReach { edges.insert(.right) }
    if abs(point.y - frame.minY) <= World.borderReach { edges.insert(.top) }
    if abs(point.y - frame.maxY) <= World.borderReach { edges.insert(.bottom) }
    if !edges.isEmpty { return .border(edges) }
    for button in World.buttonOffsets
    where abs(point.x - frame.minX - button.x) <= 7 && abs(point.y - frame.minY - 14) <= 7 {
      return .button(button.name)
    }
    return point.y < frame.minY + World.titleBarReach ? .title : .content
  }

  // MARK: The pointer

  /// The pointer cannot leave the screen, wherever an event asks it to go: a script that computes a point from
  /// the frame of a window that is parked off screen ends up at the edge.
  private func onScreen(_ point: CGPoint) -> CGPoint {
    CGPoint(
      x: min(max(point.x, display.frame.minX), display.frame.maxX - 1),
      y: min(max(point.y, display.frame.minY), display.frame.maxY - 1))
  }

  func movePointer(to target: CGPoint) {
    let point = onScreen(target)
    system.cursor = point
    hoverInMenu(at: point)
  }

  /// - Parameter right: with the right button, which is modelled on the menu bar item only.
  func press(at target: CGPoint, modifiers: RectangleGesture.Modifiers, clicks: Int, right: Bool = false) {
    let point = onScreen(target)
    system.cursor = point
    system.mouseDown = true
    if let arbor, arbor.rectangleTaps {
      // `RectangleFramer.handleDown`. ArborApp hands it the zones again whenever they may have changed.
      let zones = arbor.controller.desktopGuardZones()
      let response = arbor.gesture.mouseDown(
        at: point, modifiers: modifiers,
        onDesktop: zones.mayBeBare(point, throughPanels: !modifiers.isEmpty) && !appWindowIsUnder(point))
      switch response {
      case .ask(let press):
        // `DesktopProbe`: Finder answers long before the button comes up, and this Desktop has no icons.
        arbor.gesture.desktopAnswered(isItem: false, press: press)
        held = .rectangle(start: point, clicks: clicks)
        return
      case .hold:
        held = .rectangle(start: point, clicks: clicks)
        return
      default:
        break
      }
    }
    pressIsTold = false
    land(at: point, clicks: clicks, secondary: right || !modifiers.isDisjoint(with: [.control, .option]))
    // What the Accessibility layer's monitor of the mouse passes on. Where the press gives a window the keyboard it has its place among
    // the reports of that (`giveKeyboard`, `FakeWindowSystem.press`).
    if !pressIsTold { system.events?.pointerPressed() }
    reportDoubleClick(clicks)
  }

  /// What that monitor makes of a press that has landed, if it is the second of a pair.
  private func reportDoubleClick(_ clicks: Int) {
    if AppsDoubleClick.isCompleted(byClick: clicks), let window = pressedWindow { system.events?.doubleClickReached(window) }
  }

  /// The window of an app's that the press in progress landed on.
  private var pressedWindow: WindowID? {
    switch held {
    case .title(let window, _, _, _), .button(let window, _), .resize(let window, _, _, _): window
    case .content(let id): extras[id] == nil ? WindowID(id) : nil
    default: nil
    }
  }

  /// A press that got past Arbor's taps.
  private func land(at point: CGPoint, clicks: Int, secondary: Bool) {
    held = .idle
    arbor?.overlays.leaveNameField(for: point)
    // From here on whatever is highest is asked first: the menu, the menu bar, Arbor's panels, its update window, the windows.
    if arbor?.menu != nil {
      // A press beside an open menu closes it and does nothing else.
      if let path = menuItem(at: point) { held = .menuItem(path) } else { closeMenu() }
      return
    }
    if hasStatusItem, statusItemFrame.contains(point) {
      clickStatusItem(at: point, secondary: secondary)
      return
    }
    // A press on the panel of shortcuts puts it away and goes no further (`CheatSheetPanel.mouseDown`). One beside it lands
    // where it lands, and what ends the panel then depends on where that is: see `pressInAnotherApp`.
    if let panel = arbor?.overlays.shortcutsPanel, panel.shown, panel.frame.contains(point) {
      arbor?.overlays.dismissShortcuts(by: "a click on it")
      return
    }
    if paletteTakesPress(at: point) { return }
    if point.y < display.visibleFrame.minY { return }
    // Above every window. One that only passes by lets the press through.
    if let model = arbor?.overlays.fake.minimaps[display.id], model.takesClicks, model.frame.contains(point) {
      held = .minimap
      return
    }
    // The update window takes what lands on it, and its red button closes it: here at the press, on a Mac when the button
    // comes up. Where its other buttons are is AppKit's to say.
    if let window = arbor?.updateWindow, window.frame.contains(point) {
      if abs(point.x - window.frame.minX - 14) <= 7, abs(point.y - window.frame.minY - 14) <= 7 { arbor?.updateWindow = nil }
      return
    }
    // With the windows swept aside, the next press only brings them back, as soon as the button is down, and
    // nobody gets it. The Accessibility layer notes the window under it (`makePress`), unless `WindowGrab.hold` says that
    // the press takes hold of nothing.
    if isSwept {
      for case .window(let id) in stack {
        let reach = -World.borderReach
        guard let real = system.frame(of: WindowID(id)), let strip = sweptFrames[id],
          strip.insetBy(dx: reach, dy: reach).contains(point)
        else { continue }
        let top = WindowGrab.Top.known(WindowID(id), listed: strip, believed: real)
        let hold = WindowGrab.hold(pressedAt: point, pointerNow: point, underPress: top, underPointer: top, desktopIsShown: true)
        if let window = hold.window { held = .strip(window, from: hold.frame, at: hold.point, taken: .undecided) }
        break
      }
      isSwept = false
      return
    }

    for thing in stack where frame(of: thing)?.contains(point) == true {
      land(on: thing, at: point, clicks: clicks)
      return
    }
    for case .window(let id) in stack where system.windows[WindowID(id)] != nil {
      let reach = -World.borderReach
      if frame(of: id)?.insetBy(dx: reach, dy: reach).contains(point) == true {
        land(on: .window(id), at: point, clicks: clicks)
        return
      }
    }
    pressInAnotherApp()
    // The curtain takes the press, does nothing with it, and neither comes forward nor takes the keyboard.
    if curtainPID != nil { return }
    // The bare Desktop is Finder's.
    switchTo(app: World.finderPID)
    let setting = file(World.clickWallpaperSetting).map { String(decoding: $0, as: UTF8.self) }
    isSwept = setting?.trimmingCharacters(in: .whitespacesAndNewlines) != "0"
  }

  /// A press in another app's window or on the bare Desktop, which the panel of shortcuts hears of by itself in two ways: its
  /// monitor of other apps' events, and losing the keyboard. Whichever comes first is the cause it logs, and of two hosted
  /// Macs at the same step one logged the one and one the other. Here it is always the second. A press on a tile, a gap's
  /// handle or the minimap is neither: the real panel logs nothing, and the controller puts it away when it hears of the
  /// press (`pointerPressed`).
  private func pressInAnotherApp() {
    arbor?.overlays.dismissShortcuts(by: "losing the keyboard")
  }

  private func land(on thing: Thing, at point: CGPoint, clicks: Int) {
    switch thing {
    case .tile(let node):
      held = .tile(node)
    case .seam(let key):
      held = .seam(key, last: point)
    case .window(let id):
      pressInAnotherApp()
      guard let frame = frame(of: id) else { return }
      let grip = CGSize(width: point.x - frame.minX, height: point.y - frame.minY)
      if let extra = extras[id] {
        if let close = buttonCentre("close", of: id), abs(point.x - close.x) <= 7, abs(point.y - close.y) <= 7 {
          held = .button(WindowID(id), "close")
          return
        }
        takeKeyboard(extra: id)
        if extra.kind == .panel, grip.height < World.panelTitleBarHeight {
          held = .panelTitle(id, grip: grip)
        } else {
          count("down", for: id)
          held = .content(id)
        }
        return
      }
      let window = WindowID(id)
      switch zone(of: frame, at: point) {
      case .button(let name):
        // The three buttons work without bringing their window forward.
        held = .button(window, name)
      case .border(let edges):
        giveKeyboard(to: window, byAPress: true)
        held = .resize(window, edges: edges, from: point, frame: frame)
      case .title:
        giveKeyboard(to: window, byAPress: true)
        held = .title(window, grip: grip, moved: false, clicks: clicks)
      case .content:
        giveKeyboard(to: window, byAPress: true)
        count("down", for: id)
        held = .content(id)
      }
    }
  }

  /// A panel or a sheet gets the keyboard. The system says so, but Arbor's Accessibility layer finds that it is
  /// no standard window and passes nothing on.
  func takeKeyboard(extra id: UInt32) {
    guard let pid = extras[id]?.pid else { return }
    raise(.window(id))
    bringForward(app: pid)
    apps[pid]?.focused = id
    keyboardLeavesTheWindows()
  }

  func drag(to target: CGPoint) {
    let point = onScreen(target)
    system.cursor = point
    switch held {
    case .title(let window, var grip, let moved, let clicks):
      guard var frame = system.frame(of: window) else { return }
      let before = frame
      let pressedAt = CGPoint(x: frame.minX + grip.width, y: frame.minY + grip.height)
      // Dragged off a tile of macOS's, it has its own size again, with the pointer as far along its title bar as before.
      if !moved, let size = system.takeSizeBeforeTile(of: window) {
        grip.width *= size.width / frame.width
        frame.size = size
      }
      // The window server does not let a title bar go under the menu bar.
      frame.origin = CGPoint(x: point.x - grip.width, y: max(point.y - grip.height, display.visibleFrame.minY))
      // As the Accessibility layer does: the first move with the button down is what tells it that a drag
      // began, if `WindowGrab` agrees. The window server takes the window along either way.
      let isDragged =
        moved || WindowGrab.classify(pressedAt: pressedAt, frameAtPress: before, frameNow: frame, pointerNow: point) == .drag
      if !moved, isDragged {
        let isOn = World.tilingSettings.map { name in
          file(name).map { String(decoding: $0, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines) } != "0"
        }
        system.tiling = MacTiling(screenEdges: isOn[0], menuBar: isOn[1], optionKey: isOn[2])
        system.events?.dragBegan(window, at: point)
        held = .title(window, grip: grip, moved: true, clicks: clicks)
      }
      system.userMove(window, to: frame)
      if isDragged { system.events?.dragMoved(window, to: point) }

    case .panelTitle(let id, let grip):
      extras[id]?.frame.origin = CGPoint(
        x: point.x - grip.width, y: max(point.y - grip.height, display.visibleFrame.minY))

    case .resize(let window, let edges, let from, let start):
      var minX = start.minX
      var maxX = start.maxX
      var minY = start.minY
      var maxY = start.maxY
      if edges.contains(.left) { minX += point.x - from.x }
      if edges.contains(.right) { maxX += point.x - from.x }
      if edges.contains(.top) { minY += point.y - from.y }
      if edges.contains(.bottom) { maxY += point.y - from.y }
      // No window turns inside out, whatever its app allows.
      let size = CGSize(width: max(maxX - minX, 1), height: max(maxY - minY, 1))
      let origin = CGPoint(
        x: edges.contains(.left) ? maxX - size.width : minX, y: edges.contains(.top) ? maxY - size.height : minY
      )
      system.userResize(window, to: CGRect(origin: origin, size: size), release: false)

    case .seam(let key, let last):
      guard let arbor, let seam = arbor.overlays.seam(key) else { return }
      let delta = seam.axis == .horizontal ? point.x - last.x : point.y - last.y
      held = .seam(key, last: point)
      if delta != 0 { arbor.overlays.fake.dragSeam(seam, by: delta, on: display.id) }

    case .content(let id):
      count("dragged", for: id)

    case .rectangle(let start, let clicks):
      guard let arbor else { return }
      switch arbor.gesture.mouseDragged(to: point) {
      case .band(let rect):
        arbor.band = (arbor.band?.id ?? newOverlayID(), rect, true)
      case .replay:
        // A plain drag on the Desktop is Finder's: it gets the press it missed, then this move.
        land(at: start, clicks: clicks, secondary: false)
        drag(to: point)
      default:
        break
      }

    case .strip(let window, let from, let pressedAt, let taken):
      // As the Accessibility layer does (`lookAtPressedWindow`): it looks again with every movement, and asks.
      if taken == .drag { system.events?.dragMoved(window, to: point) }
      guard taken == .undecided, let frame = system.frame(of: window) else { return }
      let verdict = WindowGrab.classify(pressedAt: pressedAt, frameAtPress: from, frameNow: frame, pointerNow: point)
      held = .strip(window, from: from, at: pressedAt, taken: verdict)
      if verdict == .drag {
        system.events?.dragBegan(window, at: point)
        system.events?.dragMoved(window, to: point)
      } else if verdict == .resize {
        system.events?.resizeBegan(window)
      }

    case .nothing, .idle, .button, .tile, .minimap, .menuItem:
      break
    }
  }

  /// - Parameter modifiers: the keys that are down as the button comes up, if the line said.
  func lift(at target: CGPoint, modifiers: RectangleGesture.Modifiers? = nil) {
    let point = onScreen(target)
    system.cursor = point
    let released = held
    held = .nothing
    // Ends an edge resize as the Accessibility layer does, and lets go of the button either way.
    system.releaseMouse()

    switch released {
    case .title(let window, _, let moved, let clicks):
      if moved {
        let letGo = system.frame(of: window)
        system.sayWhereItIs(window)
        system.events?.dragEnded(window, at: point)
        if let letGo { system.letMacOSTile(window, letGoAt: letGo) }
      } else if AppsDoubleClick.isCompleted(byClick: clicks) {
        // System Settings → Desktop & Dock → "Double-click a window's title bar to". Not set, it fills or zooms.
        let setting = file(World.titleBarActionSetting).map { String(decoding: $0, as: UTF8.self) }
        switch setting?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "None": break
        case "Minimize": minimizeWindow(window)
        case "Fill": system.zoomAsMacOSDoes(window, andBack: false)
        default: system.zoomAsMacOSDoes(window)
        }
      }

    case .button(let window, let name):
      guard let centre = buttonCentre(name, of: window.rawValue), abs(point.x - centre.x) <= 7,
        abs(point.y - centre.y) <= 7
      else { return }
      switch name {
      case "close": closeWindow(window.rawValue)
      case "minimize": minimizeWindow(window)
      default: system.zoomAsMacOSDoes(window)
      }

    case .content(let id):
      count("up", for: id)

    case .tile(let node):
      arbor?.overlays.fake.clickTile(node, on: display.id)

    case .minimap:
      // Let go outside the panel, it was a change of mind (`MinimapView.mouseUp`).
      if let frame = arbor?.overlays.fake.minimaps[display.id]?.frame, frame.contains(point) {
        arbor?.overlays.fake.clickMinimap(at: CGPoint(x: point.x - frame.minX, y: point.y - frame.minY), on: display.id)
      }

    case .menuItem(let path):
      if menuItem(at: point) == path { choose(path) }

    case .rectangle(let start, let clicks):
      guard let arbor else { return }
      switch arbor.gesture.mouseUp(at: point, modifiers: modifiers) {
      case .replay:
        // A plain modifier-click: the app gets the press it missed, then this release.
        system.mouseDown = true
        land(at: start, clicks: clicks, secondary: false)
        reportDoubleClick(clicks)
        lift(at: point)
      case .frame(let rect):
        arbor.band?.shown = false
        handle(
          .frameRect(
            x: Double(rect.minX), y: Double(rect.minY), width: Double(rect.width), height: Double(rect.height)),
          from: .gesture)
      case .cancel:
        arbor.band?.shown = false
      default:
        break
      }

    case .strip(let window, _, _, let taken):
      guard taken == .drag || taken == .resize, let snapshot = system.windows[window]?.snapshot else { return }
      system.events?.windowChanged(snapshot, userInitiated: true)
      if taken == .drag { system.events?.dragEnded(window, at: point) } else { system.events?.resizeEnded(window) }

    case .nothing, .idle, .panelTitle, .resize, .seam:
      break
    }
  }

  // MARK: The keyboard

  /// `key <shortcut> --down`: it stays down until `--up`. Only Arbor's own shortcuts can be held: nothing here does
  /// anything with a key that an app sees go down and not come up.
  func holdKey(_ chord: KeyChord) {
    guard arbor?.menu == nil, let arbor, let binding = arbor.activeBindings.first(where: { $0.chord == chord }) else {
      return pressKey(chord)
    }
    system.hold(chord)
    heldShortcuts[chord.key] = binding
    arbor.controller.shortcut(binding, .pressed, run: { [self] in handle($0, from: .shortcut) })
  }

  /// `key <shortcut> --up`, or `key <key> --up` once the modifiers have come up by themselves.
  func letGoOfKey(_ key: KeyChord.Key, keepingModifiers: Bool) {
    guard let binding = heldShortcuts.removeValue(forKey: key) else { return }
    system.letGo(binding.chord, keepingModifiers: keepingModifiers)
    arbor?.controller.shortcut(binding, .released, run: { [self] in handle($0, from: .shortcut) })
  }

  func pressKey(_ chord: KeyChord) {
    if arbor?.menu != nil {
      // An open menu takes every key. Only Escape is modelled, and ↑ as far as it scrolls a menu that is cut off.
      if chord.key == .escape { closeMenu() }
      if chord.key == .up, chord.modifiers.isEmpty { scrollMenuToItsEnd() }
      return
    }
    // A registered hot key never reaches an app.
    // Those a peek asked for, for as long as its key is down, are registered too (`HotKeyCenter.setTemporary`).
    if let arbor, let binding = (arbor.activeBindings + arbor.controller.temporaryShortcuts).first(where: { $0.chord == chord }) {
      // `HotKeyCenter` reports the key going down and coming up; the pointer tool lets go at once. The modifiers stay down
      // for as long as another key is held with them.
      system.hold(chord)
      arbor.controller.shortcut(binding, .pressed, run: { [self] in handle($0, from: .shortcut) })
      // A key stays down for a tenth of a second or so, and the reports of what it did are in after some hundredths.
      system.deliverEchoes()
      system.letGo(chord, keepingModifiers: !heldShortcuts.isEmpty)
      self.arbor?.controller.shortcut(binding, .released, run: { [self] in handle($0, from: .shortcut) })
      return
    }
    // Arbor's name field has the keyboard while it is open, though the app behind it stays in front.
    if arbor?.overlays.typeIntoNameField(chord) == true { return }
    if paletteTakes(chord) { return }
    // So has the panel of shortcuts, which the key puts away and keeps from the app (`CheatSheetPanel.keyDown`). macOS's own
    // keys, the palette's four, never get to a window: they go on to do what they do, and the panel is taken to lose the
    // keyboard over it. That is reasoned from `CheatSheetPanel.resignKey`; nobody has pressed them on a Mac with the panel up.
    let isMacOSs = chord == KeyChord(.command, .tab) || (chord.modifiers == .control && [.left, .right, .up].contains(chord.key))
    if arbor?.overlays.dismissShortcuts(by: isMacOSs ? "losing the keyboard" : "a key") == true, !isMacOSs { return }
    system.keyDown()
    system.keyUp()
    if chord == KeyChord(.command, .tab) {
      // To the app that was in front before this one, among those that ⌘Tab shows.
      if let next = recentApps.dropFirst().first(where: {
        apps[$0]?.regular == true && apps[$0]?.hidden == false
      })
        ?? apps.values.filter({ $0.regular && !$0.hidden && $0.pid != frontApp }).map(\.pid).sorted().first
      {
        switchTo(app: next)
      }
      return
    }
    guard let app = apps[frontApp] else { return }
    let focused = system.focused.flatMap { owner(of: $0.rawValue) == app.pid ? $0 : nil }
    switch chord {
    case KeyChord(.command, .h):
      hideApp(app.pid)
    case KeyChord(.command, .m):
      if let focused, system.windows[focused] != nil { minimizeWindow(focused) }
    case KeyChord(.command, .w):
      if let focused { closeWindow(focused.rawValue) }
    default:
      if let focused { count("key", for: focused.rawValue) }
    }
  }

  // MARK: The trackpad

  /// `WindowList.appWindowIsUnder`: the window server's list, judged by `PointerSurface`.
  private func appWindowIsUnder(_ point: CGPoint) -> Bool {
    // The wallpaper and the icons on it are left out of the list.
    let windows = windowServerList().filter { $0.onScreen && $0.layer >= 0 }.map { window in
      // `WindowList.read`: a window of Arbor's with a title is an ordinary one.
      PointerSurface.Window(
        frame: window.frame, layer: window.layer, isOwn: window.pid == arbor?.pid && window.id != arbor?.updateWindow?.id)
    }
    return PointerSurface.appWindowIsUnder(point, windows: windows, display: display.frame)
  }

  func pinch(at point: CGPoint, by amount: Double, steps: Int, optionHeld: Bool) {
    movePointer(to: point)
    var events: [(phase: GestureInterpreter.Phase, raw: Int, magnification: Double)] = [(.began, 1, 0)]
    events += Array(repeating: (.changed, 4, amount / Double(steps)), count: steps)
    events.append((.ended, 8, 0))
    var passedOn = 0
    for event in events {
      guard let arbor, arbor.pinchTap else {
        passedOn += 1
        continue
      }
      let answer = arbor.router.pinch(
        event.phase, magnification: event.magnification, at: point,
        claim: optionHeld || !appWindowIsUnder(point))
      if event.phase != .changed {
        Log.debug(
          "pinch \(event.phase) (NSEvent phase \(event.raw)): \(answer.swallow ? "Arbor's" : "the app's")")
      }
      for command in answer.commands { handle(command, from: .gesture) }
      if answer.needsVisit { drainGestures() }
      if !answer.swallow { passedOn += 1 }
    }
    guard passedOn > 0 else { return }
    // To whatever is under the pointer; a tile of Arbor's does nothing with it.
    if case .window(let id) = stack.first(where: { frame(of: $0)?.contains(point) == true }) {
      count("magnify", for: id, by: passedOn)
    }
  }
}
