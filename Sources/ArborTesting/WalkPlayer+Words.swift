import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// The words, one function of scripts/mac-shell/lib-walk.sh each, in its order. Where this file and that one differ, that one is right.
extension WalkPlayer {
  /// What became of a word.
  public struct Outcome: Equatable, Sendable {
    /// How many acts it was played as. None: nothing at all has happened, on the screen or in what the player remembers.
    public var acts: Int
    /// Some part of it did not apply.
    public var leftOut: Bool
    public var notRehearsed: Bool
  }

  /// Plays one word.
  @discardableResult
  public func play(_ word: WalkWord) -> Outcome {
    let before = (acts.count, leftOut.count, notRehearsed.count)
    perform(word)
    return Outcome(acts: acts.count - before.0, leftOut: leftOut.count > before.1, notRehearsed: notRehearsed.count > before.2)
  }

  /// Plays a whole walk, from `walk_begin` to `walk_end`.
  public func play(_ walk: Walk) {
    begin()
    for word in walk.words { play(word) }
    end()
  }

  private func id(_ window: WindowID?) -> String { window.map { String($0.rawValue) } ?? "" }

  /// Some words begin by bringing a window forward, which is an act of its own, and only then find out that the rest does not apply. Whoever writes a walk asks
  /// first: whether what comes after that first act has a chance.
  public func isWorthTrying(_ word: WalkWord) -> Bool {
    // In view, and either a free point of its title bar shows or it is the window that comes to lie in front when its app is called: of an app with two
    // windows that may be the other one, which then covers it still.
    func inReach(_ app: String) -> WindowID? {
      guard present(app), let window = window(of: app), shows(window), grab(window) != nil || mainWindow(ofPid: pid(of: app)) == window else { return nil }
      return window
    }
    switch word {
    case .dragOnto(let app, let other, _):
      guard arborActs, app != other, inReach(app) != nil, present(other), let target = window(of: other) else { return false }
      return isDocked(target) && inView(target)
    case .dragOut(let app):
      guard arborActs, let window = inReach(app), isDocked(window), let desktop = runner.controller.snapshot().displays.first?.desktopFrame else { return false }
      // It gets its own size back under the pointer, and the script wants it wholly in view: where the Desktop is a strip along an edge it would hang over.
      let size = scene.windows.first { $0.app == app }?.frame.size ?? .zero
      let drop = CGPoint(x: desktop.minX + desktop.width / 2, y: desktop.minY + desktop.height / 3)
      return scene.visible.contains(CGRect(x: drop.x - size.width / 2, y: drop.y - 12, width: size.width, height: size.height))
    case .dragBy(let app, let across, let down, _):
      guard let window = inReach(app), !(arborAnswers && isDocked(window)), let frame = system.windows[window]?.snapshot.frame else { return false }
      // Where it will be taken hold of is not known yet: with a hand's breadth to spare either way.
      let (x, y) = (frame.midX + CGFloat(across), frame.minY + 12 + CGFloat(down))
      return x > screen.minX + 160 && x < screen.maxX - 160 && y > screen.minY + 90 && y < screen.maxY - 270
    case .dragEdge(let app, _): return inReach(app) != nil
    default: return true
    }
  }

  /// The apps whose first window is docked and has a place in the view.
  public var appsDockedInView: [String] { cast.filter { app in present(app) && window(of: app).map { isDocked($0) && inView($0) } == true } }

  private func perform(_ word: WalkWord) {
    switch word {
    case .switchDock(let app): switchDock(app)
    case .switchClick(let app): switchClick(app)
    case .switchTo(let app): if present(app), grab(window(of: app)) != nil { switchClick(app) } else { switchDock(app) }
    case .switchCmdTab(let times): switchCmdTab(times)
    case .switchBacktick: switchBacktick()
    case .switchMenu(let app): switchMenu(app)
    case .tileClick(let index): tileClick(index)
    case .focusKey(let arrow):
      guard arborActs else { return leaveOut("focus_key \(arrow.rawValue): Arbor is not acting") }
      // It is nothing without a key, and has no row in the menu.
      guard hasAKey("focus \(arrow.rawValue)") else { return leaveOut("focus_key \(arrow.rawValue): it has no key") }
      walkAct(.switch, "focus-\(arrow.rawValue)", way(to: "focus \(arrow.rawValue)"))
      key("focus \(arrow.rawValue)")
      pass(0.4)
      // With no window that way in view, the view goes to the neighbouring space.
      acted(["moves=any", "front=\(id(frontWindow))"])
    case .summon(let app): leaveOut("summon \(app): not played yet")
    case .openNew: openNew()
    case .closeNew: closeNew()
    case .minimize: minimize()
    case .restore(let app): restore(app)
    case .hide: hide()
    case .unhide(let app): unhide(app)
    case .quitApp(let app): quitApp(app)
    case .reopen(let app): reopen(app)
    case .dockKey(let arrow): dockKey(arrow)
    case .floatKey:
      guard arborActs else { return leaveOut("float_key: Arbor is not acting") }
      guard let window = frontWindow, isDocked(window) else { return leaveOut("float_key: the window in front is not docked") }
      walkAct(.dockKey, "float", "presses ⌃⌥F")
      key("toggle-float")
      changed()
      acted(["moves=docked", "front=\(id(window))", "restores=\(id(window))"])
    // Every window on the display is docked, so every one of them may move.
    case .arrangeKey: arrangementKey("arrange", ["moves=any"])
    // What comes back may have floated, been docked or been out of view.
    case .undo: arrangementKey("undo", ["moves=any"])
    case .redo: arrangementKey("redo", ["moves=any"])
    case .rotate: arrangementKey("rotate", ["moves=docked"])
    case .mirror: arrangementKey("mirror", ["moves=docked"])
    case .pin:
      guard arborActs else { return leaveOut("pin: Arbor is not acting") }
      guard let window = frontWindow, isManaged(window) else { return leaveOut("pin: Arbor does not arrange the window in front") }
      walkAct(.dockKey, "pin", "chooses Keep This Window in View in Arbor's menu, or takes the tick off")
      mustCtl("toggle-pin")
      changed()
      // A docked one floats first.
      acted(["moves=docked", "front=\(id(window))"])
    case .dragOnto(let app, let other, let part): dragOnto(app, other, part)
    case .dragOut(let app): dragOut(app)
    case .dragBy(let app, let across, let down, let click): dragBy(app, across, down, click: click)
    case .dragEdge(let app, let edge): dragEdge(app, edge)
    case .view(let move): view(move)
    case .peek:
      guard arborActs else { return leaveOut("peek: Arbor is not acting") }
      walkAct(.view, "peek", "holds ⌃⌥Space for a second and a half and lets go")
      samples.key(at: clock)
      does(.key("show-all", .pressed))
      pass(1.5)
      does(.key("show-all", .released))
      acted(["moves=any"])
    case .saveView(let number):
      guard arborActs else { return leaveOut("save_view \(number): Arbor is not acting") }
      walkAct(.view, "save-view-\(number)", way(to: "save-view \(number)"))
      goThatWay("save-view \(number)")
      // Remembering where one looks moves nothing.
      acted()
    case .viewN(let number):
      guard arborActs else { return leaveOut("view_n \(number): Arbor is not acting") }
      walkAct(.view, "view-\(number)", way(to: "view \(number)"))
      goThatWay("view \(number)")
      acted(["moves=any"])
    case .resizeGap(let app, let points): resizeGap(app, points)
    case .resizeKey(let size):
      guard arborActs else { return leaveOut("resize_key \(size.rawValue): Arbor is not acting") }
      guard let window = frontWindow, isDocked(window) else { return leaveOut("resize_key \(size.rawValue): the window in front is not docked") }
      walkAct(.resize, size.rawValue, way(to: size.rawValue))
      goThatWay(size.rawValue)
      changed()
      acted(["moves=docked", "front=\(id(window))"])
    case .resizeEdge(let app, let part, let points): resizeEdge(app, part, points)
    case .fullScreen(let on): fullScreen(on)
    // What macOS does to the windows at a click on the wallpaper no stand-in does yet. The frames end where they began; that the Finder is in front afterwards is not played.
    case .wallpaperClick: cannotRehearse("wallpaper_click: the stand-in's macOS does not sweep the windows aside")
    case .titleDoubleClick(let app): titleDoubleClick(app)
    case .pause:
      guard arborActs else { return leaveOut("pause: Arbor is not acting") }
      let front = frontWindow
      atPause = (front.map { [$0] } ?? []) + ids().floating
      walkAct(.wayOut, "pause", "presses ⌃⌥⎋")
      samples.key(at: clock)
      does(.command("toggle-pause"))
      (paused, beforePause, movedInPause) = (true, step - 1, [])
      changed()
      acted(["moves=any", "restores=all", "places=1", "everything=1"] + (front.map { ["front=\(id($0))"] } ?? []))
    case .resume:
      guard paused else { return leaveOut("resume: Arbor is not paused") }
      // The view may follow the keyboard to a docked window it has gone to meanwhile. With a floating one, or the one that had it, there is nothing to follow.
      if frontWindow.map(atPause.contains) != true { beforePause = nil }
      walkAct(.wayOut, "resume", "presses ⌃⌥⎋")
      samples.key(at: clock)
      does(.command("toggle-pause"))
      paused = false
      // A floating window its person moved meanwhile stays where they put it.
      acted(["moves=any"] + (beforePause.map { ["returns=\($0)"] + (movedInPause.isEmpty ? [] : ["but=\(Self.list(movedInPause))"]) } ?? []))
      beforePause = nil
    case .floatAll:
      guard arborActs else { return leaveOut("float_all: Arbor is not acting") }
      walkAct(.wayOut, "float-all", way(to: "float-all"))
      goThatWay("float-all")
      acted(["moves=any", "restores=all", "places=1", "everything=1"])
      atHome()
    case .floatAllHere:
      guard arborActs else { return leaveOut("float_all_here: Arbor is not acting") }
      walkAct(.wayOut, "float-all-here", "floats every window of this display")
      mustCtl("float-all here")
      changed()
      // With one display that is all of them.
      if second {
        acted(["moves=any"])
      } else {
        acted(["moves=any", "restores=all", "places=1", "everything=1"])
        atHome()
      }
    case .holdView: holdView()
    case .releaseView: leaveOut("release_view: hold_view lets go by itself")
    case .display(let change): display(change)
    case .sendAcross, .moveToDisplay:
      guard arborActs, second else { return leaveOut("send_across: there is no second display, or Arbor is not acting") }
      guard let window = frontWindow, isManaged(window) else { return leaveOut("send_across: Arbor does not arrange the window in front") }
      walkAct(.dockKey, "send-across", "sends the window in front to the other display")
      mustCtl("move-to-display next")
      changed()
      // Where it lands there is its place from now on.
      acted(["moves=docked,\(id(window))", "front=\(id(window))", "place=\(id(window))"])
    case .quitAndStart:
      guard withArbor, arborAnswers, fullScreen == nil else { return leaveOut("quit_and_start: Arbor is not running") }
      quit()
      // All of them at the journey's end.
      rollCall(every: 3)
      start()
    case .idleAct:
      walkAct(.idle, "leave-alone", "does nothing for half a minute")
      pass(30)
      acted()
    case .chapter(let title): chapter(title)
    }
  }

  // MARK: Switching

  private func switchDock(_ app: String) {
    guard present(app) else { return leaveOut("switch_dock \(app): it has no window to come forward") }
    walkAct(.switch, "dock-icon-\(app)", "clicks \(app)'s icon in the Dock")
    clickInTheDock()
    comesForward(app)
    acted(["front=\(id(mainWindow(ofPid: pid(of: app))))"])
  }

  private func switchClick(_ app: String) {
    guard present(app), let window = window(of: app), let point = grab(window) else {
      return leaveOut("switch_click \(app): no free point of its title bar shows")
    }
    walkAct(.switch, "click-\(app)", "clicks \(app)'s title bar")
    clickTitleBar(of: window, at: point)
    acted(["front=\(id(window))"])
  }

  /// The app that lib-day.sh's `cmd_tab` leads to. One press leads one app on. Of more, the second is a race with macOS's switcher, which is not up yet: on hosted Macs it did not
  /// count when it came 235 to 314 ms after the first (four times) and did at 394 ms (once); the third, half a second on, always did. Played here as it mostly went.
  public func appBehindCmdTab(_ times: Int) -> String? {
    let running = recentApps.filter { pid(of: $0) != nil }
    return running.isEmpty ? nil : running[max(times - 1, 1) % running.count]
  }

  private func switchCmdTab(_ times: Int) {
    walkAct(.switch, "cmd-tab-\(times)", "holds ⌘ and presses Tab \(times) time(s)")
    for _ in 0..<times {
      otherKey()
      pass(0.15)
    }
    if let app = appBehindCmdTab(times) {
      // An app that was hidden shows itself when it is chosen.
      if hidden.contains(app), let pid = pid(of: app) { does(.hide(pid: pid, false)) }
      comesForward(app)
    }
    pass(0.5)
    acted(["front=\(id(mainWindow(ofPid: frontPid)))"])
  }

  private func switchBacktick() {
    let pid = frontPid
    guard windows(ofPid: pid).count >= 2 else { return leaveOut("switch_backtick: the app in front has one window") }
    walkAct(.switch, "cmd-backtick", "presses ⌘` for the app's next window")
    otherKey()
    let pile = system.windowsFrontToBack().filter { system.windows[$0]?.snapshot.pid == pid && system.windows[$0]?.snapshot.isMinimized == false }
    if pile.count >= 2 { does(.focus(pile[1])) }
    pass(0.3)
    acted(["front=\(id(mainWindow(ofPid: pid)))"])
  }

  private func switchMenu(_ app: String) {
    guard present(app), let window = window(of: app) else { return leaveOut("switch_menu \(app): it has no window") }
    if frontPid != pid(of: app) { switchDock(app) }
    walkAct(.switch, "window-menu-\(app)", "chooses \(app)'s first window in the Window menu")
    samples.click(CGPoint(x: screen.minX + 400, y: screen.minY + 12), at: clock)
    pass(0.5)
    samples.click(CGPoint(x: screen.minX + 420, y: screen.minY + 200), at: clock)
    does(.focus(window))
    acted(["front=\(id(window))"])
  }

  private func tileClick(_ index: Int) {
    guard arborActs else { return leaveOut("tile_click: Arbor is not acting") }
    let tiles = ids().tiles
    guard tiles.indices.contains(index - 1) else { return leaveOut("tile_click \(index): no such tile stands in for a window") }
    let tile = tiles[index - 1]
    let whole = Self.whole(tile.frame)
    // A floating window may lie over the tile, and would take the click. In quarters of the tile: its middle first.
    let free = [(2, 2), (1, 2), (3, 2), (2, 1), (2, 3)].map { CGPoint(x: whole.x + whole.w * $0.0 / 4, y: whole.y + whole.h * $0.1 / 4) }
      .first { top(at: $0).isArbors }
    guard let free else { return leaveOut("tile_click \(index): something lies over the tile") }
    walkAct(.tileClick, "click-tile", "clicks the tile that stands in for a window")
    does(.cursor(free))
    samples.click(free, at: clock)
    does(.tile(tile.display, tile.node))
    acted(["moves=any", "front=\(id(tile.window))"])
  }

  // MARK: Windows come and go

  private func openNew() {
    guard let name = frontApp, cast.contains(name), let member = members[name], let pid = member.pid else {
      return leaveOut("open_new: the app in front is not of the cast")
    }
    guard member.app.opensNewWindows else { return leaveOut("open_new: ⌘N in \(name) is no new window") }
    walkAct(.openClose, "new-window-\(name)", "presses ⌘N in \(name)")
    otherKey()
    let front = mainWindow(ofPid: pid).flatMap { system.windows[$0]?.snapshot.frame }
    let size = member.app.isABrowser ? front?.size ?? member.app.opens : member.app.newWindow ?? member.app.onAHostedMac?.size ?? member.app.opens
    let new = newWindow(of: member.app, pid: pid, frame: cascaded(from: front ?? CGRect(origin: scene.visible.origin, size: size), size: size))
    pass(0.2)
    does(.open(new))
    does(.focus(new.id))
    label(new.id, "\(name)-new-\(step)")
    newWindows.insert(new.id, at: 0)
    // A new window stays where its app put it, and nothing else moves.
    acted(["front=\(id(new.id))"])
  }

  private func closeNew() {
    var window = frontWindow
    if window == nil || !newWindows.contains(window!) {
      window = newWindows.first
      guard let newest = window, let point = grab(newest) else { return leaveOut("close_new: no window that open_new opened is within reach") }
      walkAct(.switch, "click-new-window", "clicks the title bar of the window that ⌘N opened")
      clickTitleBar(of: newest, at: point)
      acted(["front=\(id(newest))"])
      guard frontWindow == newest else {
        return leaveOut("close_new: the window that ⌘N opened did not come forward, and ⌘W would close another")
      }
    }
    guard let window else { return }
    walkAct(.openClose, "close-window", "presses ⌘W")
    otherKey()
    does(.close(window))
    newWindows.removeAll { $0 == window }
    acted(["leaves=\(id(window))", "moves=docked"])
  }

  private func minimize() {
    guard let window = frontWindow, let name = frontApp, cast.contains(name), window == self.window(of: name) else {
      return leaveOut("minimize: the window in front is not a first window of the cast's")
    }
    // Stickies' notes have no yellow button, and ⌘M does something else to them.
    guard members[name]?.app.canBeMinimized != false else { return leaveOut("minimize: \(name)'s window cannot be minimized") }
    walkAct(.openClose, "minimize-\(name)", "presses ⌘M")
    leaving(name)
    otherKey()
    does(.minimize(window, true))
    minimized.append(name)
    changed()
    acted(["moves=docked", "leaves=\(id(window))"])
  }

  private func restore(_ asked: String?) {
    // A walk cannot know which window was in front: if that app is not the one, whichever was last comes back.
    guard let app = asked.flatMap({ minimized.contains($0) ? $0 : nil }) ?? minimized.last, let window = window(of: app) else {
      return leaveOut("restore: nothing is minimized")
    }
    walkAct(.openClose, "restore-\(app)", "clicks its miniature in the Dock")
    clickInTheDock()
    does(.minimize(window, false))
    does(.focus(window))
    minimized.removeAll { $0 == app }
    acted(["moves=docked", "comes=\(id(window))", "front=\(id(window))"] + cameBack(app))
  }

  private func hide() {
    guard let name = frontApp, cast.contains(name), let pid = pid(of: name) else { return leaveOut("hide: the app in front is not of the cast") }
    let gone = windows(ofPid: pid)
    walkAct(.openClose, "hide-\(name)", "presses ⌘H")
    leaving(name)
    otherKey()
    does(.hide(pid: pid, true))
    hidden.append(name)
    changed()
    acted(["moves=docked", "leaves=\(Self.list(gone))"])
  }

  private func unhide(_ asked: String?) {
    guard let app = asked.flatMap({ hidden.contains($0) ? $0 : nil }) ?? hidden.last, let pid = pid(of: app) else {
      return leaveOut("unhide: nothing is hidden")
    }
    walkAct(.openClose, "unhide-\(app)", "clicks its icon in the Dock")
    clickInTheDock()
    does(.hide(pid: pid, false))
    comesForward(app)
    hidden.removeAll { $0 == app }
    acted(["moves=docked", "comes=\(id(window(of: app)))", "front=\(id(mainWindow(ofPid: pid)))"] + cameBack(app))
  }

  private func quitApp(_ app: String) {
    // Never the Finder.
    guard ["textedit", "preview", "safari"].contains(app) else { return leaveOut("quit_app \(app): only apps whose document can be opened again") }
    guard present(app), let pid = pid(of: app) else { return leaveOut("quit_app \(app): it is not there") }
    if frontPid != pid { switchDock(app) }
    guard frontPid == pid else { return leaveOut("quit_app \(app): it did not come forward, and ⌘Q would quit another") }
    let gone = windows(ofPid: pid)
    walkAct(.openClose, "quit-\(app)", "presses ⌘Q in \(app)")
    otherKey()
    does(.quitApp(pid: pid))
    newWindows.removeAll { gone.contains($0) }
    members[app]?.window = nil
    members[app]?.pid = nil
    recentApps.removeAll { $0 == app }
    // The app that was in front before it is in front again.
    if let next = recentApps.first(where: { !hidden.contains($0) }) { comesForward(next) }
    changed()
    acted(["moves=docked", "leaves=\(Self.list(gone))"])
  }

  private func reopen(_ app: String) {
    guard cast.contains(app), let member = members[app], member.window == nil, member.app.hasADocument else {
      return leaveOut("reopen \(app): it was not quit")
    }
    walkAct(.openClose, "reopen-\(app)", "opens \(app)'s document again")
    // Where it opened in the morning, wherever it was when it quit: so TextEdit, Preview and Safari were seen to.
    let frame = scene.windows.first { $0.app == app }?.frame ?? CGRect(origin: scene.visible.origin, size: member.app.opens)
    let new = newWindow(of: member.app, pid: newPid(), frame: frame)
    pass(1)
    does(.open(new))
    does(.focus(new.id))
    members[app]?.window = new.id
    members[app]?.pid = new.pid
    label(new.id, app)
    changed()
    acted(["moves=docked", "front=\(id(new.id))"])
  }

  // MARK: Arranging

  private func dockKey(_ arrow: WalkWord.Arrow) {
    guard arborActs else { return leaveOut("dock_key \(arrow.rawValue): Arbor is not acting") }
    guard let window = frontWindow, isManaged(window) else { return leaveOut("dock_key \(arrow.rawValue): Arbor does not arrange the window in front") }
    let command = "dock \([.left: "left", .right: "right", .up: "top", .down: "bottom"][arrow]!)"
    walkAct(.dockKey, "dock-\(arrow.rawValue)", way(to: command))
    goThatWay(command)
    changed()
    want("it is docked", eventually { isDocked(window) })
    acted(["moves=docked", "front=\(id(window))"])
  }

  /// One of Arbor's commands that changes the arrangement as a whole, by its key or from the menu.
  private func arrangementKey(_ command: String, _ wants: [String]) {
    guard arborActs else { return leaveOut("\(command): Arbor is not acting") }
    walkAct(.dockKey, command, way(to: command))
    goThatWay(command)
    changed()
    acted(wants)
  }

  /// Present, in view, and a free point of its title bar shows. A window that is covered is brought forward first, as a person would.
  private func canBeDragged(_ app: String) -> Bool {
    guard present(app), let window = window(of: app), shows(window) else { return false }
    if grab(window) != nil { return true }
    switchDock(app)
    return shows(window) && grab(window) != nil
  }

  private func dragOnto(_ app: String, _ other: String, _ part: WalkWord.Part) {
    let words = "\(app) \(other) \(part.rawValue)"
    guard arborActs else { return leaveOut("drag_onto \(words): Arbor is not acting") }
    guard app != other, canBeDragged(app), present(other), let window = window(of: app), let target = self.window(of: other) else {
      return leaveOut("drag_onto \(words): nothing to take hold of")
    }
    guard isDocked(target), inView(target), let (x, y, w, h) = frameOf(target) else { return leaveOut("drag_onto \(words): \(other) is not docked and in view") }
    let point: (Int, Int) =
      switch part {
      case .left: (x + w / 6, y + h / 2)
      case .right: (x + w * 5 / 6, y + h / 2)
      case .top: (x + w / 2, y + h / 6)
      case .bottom: (x + w / 2, y + h * 5 / 6)
      }
    walkAct(.drag, "drag-\(app)-onto-\(other)-\(part.rawValue)", "drags \(app) by its title bar onto the \(part.rawValue) part of \(other) and lets go")
    drag(window, to: CGPoint(x: point.0, y: point.1))
    changed()
    want("it is docked", eventually { isDocked(window) })
    acted(["drags=\(id(window))", "moves=docked", "front=\(id(window))"])
  }

  private func dragOut(_ app: String) {
    guard arborActs else { return leaveOut("drag_out \(app): Arbor is not acting") }
    guard canBeDragged(app), let window = window(of: app), isDocked(window) else { return leaveOut("drag_out \(app): it is not docked and in reach") }
    guard let desktop = runner.controller.snapshot().displays.first?.desktopFrame else { return leaveOut("drag_out \(app): the Desktop is out of view") }
    let (x, y, w, h) = Self.whole(desktop)
    walkAct(.drag, "drag-\(app)-out", "drags \(app) out of the arrangement onto the Desktop and lets go")
    drag(window, to: CGPoint(x: x + w / 2, y: y + h / 3))
    changed()
    want("it floats", eventually { isFloating(window) })
    acted(["drags=\(id(window))", "moves=docked", "front=\(id(window))", "restores=\(id(window))", "place=\(id(window))"])
  }

  private func dragBy(_ app: String, _ across: Int, _ down: Int, click: Bool) {
    let words = "\(app) \(across) \(down)" + (click ? " click" : "")
    guard canBeDragged(app), let window = window(of: app), let hold = grab(window) else { return leaveOut("drag_by \(words): nothing to take hold of") }
    if arborAnswers, isDocked(window) { return leaveOut("drag_by \(words): it is docked") }
    // Not into the menu bar, the Dock or an edge, where macOS has ideas of its own.
    let (x, y) = (hold.x + CGFloat(across), hold.y + CGFloat(down))
    guard x > screen.minX + 60, x < screen.maxX - 60, y > screen.minY + 80, y < screen.maxY - 260 else {
      return leaveOut("drag_by \(words): that would end at an edge")
    }
    walkAct(
      .drag, "drag-\(app)-by",
      "drags \(app), which floats, by its title bar \(across) across and \(down) down" + (click ? ", and clicks there 0.3 s after letting go" : ""))
    drag(window, by: CGSize(width: across, height: down))
    if click {
      // An impatient hand.
      pass(0.3)
      self.click(system.cursor, on: window)
    }
    changed()
    if paused { movedInPause.append(window) }
    // Its size too: macOS gives a window it had tiled its earlier size back under the hand.
    acted(["drags=\(id(window))", "front=\(id(window))", "own=\(id(window))"])
  }

  private func dragEdge(_ app: String, _ edge: WalkWord.ScreenEdge) {
    guard canBeDragged(app), let window = window(of: app) else { return leaveOut("drag_edge \(app) \(edge.rawValue): nothing to take hold of") }
    let (x, y, w, h) = Self.whole(screen)
    let point: (Int, Int) =
      switch edge {
      case .left: (x, y + h / 2)
      case .right: (x + w - 1, y + h / 2)
      case .top: (x + w / 2, y)
      }
    walkAct(
      .dragWhereMacOSTiles, "drag-\(app)-to-\(edge.rawValue)-edge", "drags \(app) by its title bar against the \(edge.rawValue) edge of the screen and lets go")
    drag(window, to: CGPoint(x: point.0, y: point.1), hold: 1)
    changed()
    // Docked by Arbor, or tiled by macOS with Arbor standing aside: then that is where its person put it, and its own frame from now on.
    let own = arborAnswers && eventually { isDocked(window) } ? [] : ["own=\(id(window))"]
    acted(["drags=\(id(window))", "moves=docked", "front=\(id(window))"] + own)
  }

  private func resizeGap(_ app: String, _ points: Int) {
    let words = "\(app) \(points)"
    guard arborActs else { return leaveOut("resize_gap \(words): Arbor is not acting") }
    guard present(app), let window = window(of: app) else { return leaveOut("resize_gap \(words): it is not there") }
    guard isDocked(window), inView(window), let (x, y, w, h) = frameOf(window) else { return leaveOut("resize_gap \(words): it is not docked and in view") }
    let gap = Int(runner.controller.settings.gap.rounded())
    let point = CGPoint(x: x + w + gap / 2, y: y + h / 2)
    guard point.x < screen.maxX - 40 else { return leaveOut("resize_gap \(words): there is no gap to its right") }
    // A floating window may lie over the gap, and would take the press. So would nothing at all: the handle has to be there.
    let seams = runner.harness.overlays.seams.sorted { $0.key < $1.key }
    guard top(at: point).window == nil,
      let (display, index) = seams.lazy.compactMap({ display, seams in seams.firstIndex { $0.frame.contains(point) }.map { (display, $0) } }).first
    else { return leaveOut("resize_gap \(words): something lies over the gap") }
    walkAct(.resize, "drag-gap-beside-\(app)", "drags the gap to the right of \(app) by \(points) points")
    does(.cursor(point))
    samples.button(down: true, point, at: clock)
    pass(0.6)
    does(.seam(display, index: index, delta: Double(points)))
    pass(0.2)
    samples.button(down: false, CGPoint(x: point.x + CGFloat(points), y: point.y), at: clock)
    changed()
    acted(["moves=docked"])
  }

  private func resizeEdge(_ app: String, _ part: WalkWord.Part, _ points: Int) {
    let words = "\(app) \(part.rawValue) \(points)"
    guard arborActs else { return leaveOut("resize_edge \(words): Arbor is not acting") }
    guard present(app), let window = window(of: app) else { return leaveOut("resize_edge \(words): it is not there") }
    guard isDocked(window), inView(window), let real = system.windows[window]?.snapshot.frame else {
      return leaveOut("resize_edge \(words): it is not docked and in view")
    }
    let (x, y, w, h) = Self.whole(real)
    let (press, resized): ((Int, Int), CGRect) =
      switch part {
      case .left: ((x + 1, y + h / 2), CGRect(x: x - points, y: y, width: w + points, height: h))
      case .right: ((x + w - 1, y + h / 2), CGRect(x: x, y: y, width: w + points, height: h))
      case .top: ((x + w / 2, y + 1), CGRect(x: x, y: y - points, width: w, height: h + points))
      case .bottom: ((x + w / 2, y + h - 1), CGRect(x: x, y: y, width: w, height: h + points))
      }
    guard top(at: CGPoint(x: press.0, y: press.1)).window == window else { return leaveOut("resize_edge \(words): something lies over that edge") }
    walkAct(.resize, "drag-\(part.rawValue)-edge-of-\(app)", "drags the \(part.rawValue) edge of \(app)'s window by \(points) points")
    does(.cursor(CGPoint(x: press.0, y: press.1)))
    // In 0.6 s, as the pointer glides, then held for a moment.
    for piece in 1...6 {
      let share = CGFloat(piece) / 6
      does(
        .edge(
          window,
          CGRect(
            x: (real.minX + (resized.minX - real.minX) * share).rounded(), y: (real.minY + (resized.minY - real.minY) * share).rounded(),
            width: (real.width + (resized.width - real.width) * share).rounded(), height: (real.height + (resized.height - real.height) * share).rounded()),
          hold: true))
      pass(0.1)
    }
    pass(0.1)
    does(.release)
    changed()
    acted(["moves=docked"])
  }

  // MARK: The view

  private func view(_ move: WalkWord.View) {
    guard arborActs else { return leaveOut("view \(move.rawValue): Arbor is not acting") }
    let window = frontWindow
    var wants: [String] = []
    let command: String
    switch move {
    case .frame:
      guard let window, isManaged(window) else { return leaveOut("view frame: Arbor does not arrange the window in front") }
      (command, wants) = ("zoom", ["front=\(id(window))"])
    case .out, .in, .back, .forward, .desktop: command = move.rawValue
    case .left, .right:
      command = "neighbor \(move.rawValue)"
      // Walking to the neighbouring space is nothing without a key, and has no row in the menu.
      guard hasAKey(command) else { return leaveOut("view \(move.rawValue): it has no key") }
    case .all:
      // Show Everything is about one display.
      command = "show-all"
      if !second { wants = ["everything=1", "tiles=ok"] + backHome }
    // No row in the menu: without a key it is `arborctl home`, which the guide names.
    case .home: (command, wants) = ("home", ["everything=1", "tiles=ok"] + backHome)
    }
    walkAct(.view, "view-\(move.rawValue)", way(to: command))
    goThatWay(command)
    acted(["moves=any"] + wants)
    if move == .home || (move == .all && !second) { atHome() }
  }

  // MARK: macOS's own

  private func fullScreen(_ on: Bool) {
    if on {
      guard fullScreen == nil else { return leaveOut("full_screen on: a window is in full screen already") }
      guard present("safari") else { return leaveOut("full_screen on: played in Safari, which is not there") }
      if frontApp != "safari" { switchDock("safari") }
      guard frontApp == "safari", let window = frontWindow else { return leaveOut("full_screen on: Safari did not come forward") }
      walkAct(.macOSOwn, "full-screen", "presses ⌃⌘F in Safari")
      otherKey()
      does(.fullScreen(window, true))
      pass(2)
      fullScreen = (window, step)
      acted(["moves=any", "leaves=any", "audit=no"])
    } else {
      guard let (window, since) = fullScreen else { return leaveOut("full_screen off: nothing is in full screen") }
      walkAct(.macOSOwn, "leave-full-screen", "presses ⌃⌘F again")
      otherKey()
      does(.fullScreen(window, false))
      pass(2)
      // Every window is where it was before.
      acted(["moves=any", "leaves=any", "comes=\(id(window))", "front=\(id(window))", "returns=\(since - 1)"])
      fullScreen = nil
    }
  }

  private func titleDoubleClick(_ app: String) {
    let before = step
    guard canBeDragged(app), let window = window(of: app), let point = grab(window) else {
      return leaveOut("title_double_click \(app): no free point of its title bar shows")
    }
    walkAct(.macOSOwn, "double-click-\(app)", "double-clicks \(app)'s title bar: macOS zooms the window")
    samples.click(point, at: clock)
    samples.click(point, at: clock)
    // The clicks go where the pointer is: to the free point, not to the middle of the bar, over which another window may lie.
    does(.cursor(point))
    does(.doubleClick(window))
    does(.cursor(CGPoint(x: point.x, y: point.y + 120)))
    // macOS's frame stays, and nobody else moves.
    acted(["zooms=\(id(window))", "front=\(id(window))"])
    guard let again = grab(window) else {
      changed()
      return leaveOut("title_double_click \(app): no free point of its title bar shows for the second one")
    }
    walkAct(.macOSOwn, "double-click-\(app)-again", "double-clicks it again: macOS takes the window back")
    samples.click(again, at: clock)
    samples.click(again, at: clock)
    does(.cursor(again))
    does(.doubleClick(window))
    does(.cursor(CGPoint(x: again.x, y: again.y + 120)))
    acted(["zooms=\(id(window))", "front=\(id(window))", "returns=\(before)"])
  }

  // MARK: Displays

  /// A display comes, goes, moves or changes size: the windows on the displays concerned may move; afterwards nothing is lost.
  private func display(_ change: WalkWord.DisplayChange) {
    guard setting.display == .two, fullScreen == nil else { return leaveOut("display \(change.rawValue): this walk has one display") }
    switch change {
    case .plug: guard !second else { return leaveOut("display plug: it is plugged in") }
    case .unplug, .left, .right: guard second else { return leaveOut("display \(change.rawValue): it is not plugged in") }
    case .smaller, .larger:
      // Another size is another display in its place: two things that happen, so two acts.
      guard second else { return leaveOut("display \(change.rawValue): it is not plugged in") }
      display(.unplug)
      if change == .smaller { nextSize = CGSize(width: 1280, height: 800) }
      return display(.plug)
    }
    walkAct(.displayChange, "display-\(change.rawValue)", "the second display: \(change.rawValue)")
    switch change {
    case .plug:
      (secondSize, nextSize, secondIsOnTheLeft, second) = (nextSize ?? CGSize(width: 1920, height: 1080), nil, false, true)
    case .unplug: second = false
    case .left: secondIsOnTheLeft = true
    default: secondIsOnTheLeft = false
    }
    does(.displays(displays, .late))
    pass(2)
    changed()
    acted(["moves=any", "leaves=any"])
    // The view may be framed, with windows out of view by rights. Whether one is lost shows when everything is asked for.
    view(.home)
  }

  // MARK: The ways out

  /// Held, the view stays where it is whatever is pressed. So the three belong together: the hold, a key that would move the view and must not, the release.
  private func holdView() {
    guard arborActs else { return leaveOut("hold_view: Arbor is not acting") }
    walkAct(.wayOut, "hold", "holds the view, as for a shared screen")
    guard mustCtl("hold") else { return acted() }
    acted()
    walkAct(.view, "show-everything-while-held", "presses ⌃⌥Space, which would show everything: the view is held")
    key("show-all")
    acted()
    walkAct(.wayOut, "release", "lets the view go again")
    mustCtl("release")
    // What waited to come into view may do so now.
    acted(["moves=any"])
  }
}
