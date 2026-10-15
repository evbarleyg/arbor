import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation

/// The fake Mac: a display, the test apps and their windows, the pointer and the keyboard, and Arbor while it
/// runs. Windows outlive Arbor, so the window system belongs to the world and every launch of Arbor gets a new
/// controller on it.
///
/// - World.swift: the state, what is in front of what, who has the keyboard, time
/// - World+Arbor.swift: Arbor's life, arborctl, URLs, and the parts of ArborApp that are macOS-only code
/// - World+Menu.swift: the menu bar item's menu
/// - World+TestApps.swift: ArborTestWindows
/// - World+Pointer.swift: the pointer tool's command line and its questions
/// - World+Input.swift: what presses, drags, keys and pinches do
@MainActor
final class World {
  /// GitHub's macos-26 runner: a 31-point menu bar and a 63-point Dock.
  static let defaultDisplay = "1024x768 31 63"
  static let finderPID: Int32 = 362
  /// The test windows' title bar, as CI builds ArborTestWindows: a window of 480×320 measures 480×348 (`FakeWindowSystem.usualTitleBar`).
  static let titleBarHeight = FakeWindowSystem.usualTitleBar

  /// Reads `<width>x<height> <height of the menu bar> <height of the Dock>`, as in ARBOR_REHEARSAL_DISPLAY.
  static func display(_ text: String) -> DisplaySnapshot? {
    let words = text.split(separator: " ")
    let size = (words.first ?? "").lowercased().split(separator: "x").compactMap { Double($0) }
    let bars = words.dropFirst().compactMap { Double($0) }
    guard words.count == 3, size.count == 2, bars.count == 2, bars[0] >= 0, bars[1] >= 0, size[0] >= 640,
      size[0] <= 10_000, size[1] <= 10_000, size[1] - bars[0] - bars[1] >= 400
    else { return nil }
    return DisplaySnapshot(
      id: DisplayID("FA4E3AC0-0000-4000-8000-000010240768"),
      frame: CGRect(x: 0, y: 0, width: size[0], height: size[1]),
      visibleFrame: CGRect(x: 0, y: bars[0], width: size[0], height: size[1] - bars[0] - bars[1]), isMain: true)
  }

  let display: DisplaySnapshot
  let system: FakeWindowSystem
  /// Only for arborctl's message when Arbor is not running.
  let socket: String

  // MARK: Apps and windows

  struct TestApp {
    var pid: Int32
    var bundleID: String
    /// What the window server calls the owner of its windows.
    var name: String
    /// In the Dock and in ⌘Tab.
    var regular = false
    /// How many windows it has opened so far, which decides where the next one goes.
    var opened = 0
    var hidden = false
    /// The window Accessibility calls its focused one, which it keeps while another app is in front.
    var focused: UInt32?
  }

  /// A panel or a sheet. The window server has it, but Arbor's Accessibility layer reports only standard
  /// windows, so it is kept out of the `FakeWindowSystem`.
  struct ExtraWindow {
    enum Kind: Equatable {
      case panel
      case sheet(parent: WindowID)
      /// An alert: a titled panel at the ordinary level, which Accessibility calls AXDialog.
      case dialog
    }
    var id: UInt32
    var pid: Int32
    var kind: Kind
    var frame: CGRect
  }

  /// A native tab group: one window shows, the others exist but are listed nowhere.
  struct TabGroup {
    var pid: Int32
    var front: UInt32
    /// The one shown last comes last.
    var behind: [UInt32]
  }

  var apps: [Int32: TestApp] = [:]
  var tabGroups: [TabGroup] = []
  var extras: [UInt32: ExtraWindow] = [:]
  /// The test windows that were told `by-background`: a press on their content takes them along.
  var draggedByTheirBackground: Set<UInt32> = []
  /// What `WindowGrab.judge` remembers of the press that holds a window, as the Accessibility layer keeps it.
  var grabMemory = WindowGrab.Memory()
  private var nextExtraID: UInt32 = 5001
  /// What each window's content has received: down, up, dragged, key, magnify.
  var counts: [UInt32: [String: Int]] = [:]

  // MARK: In front of what

  struct SeamKey: Hashable {
    var split: NodeID
    var leading: NodeID
    var trailing: NodeID

    init(_ seam: Seam) {
      split = seam.split
      leading = seam.leading
      trailing = seam.trailing
    }
  }

  /// Something that takes clicks and has a place in the order of windows.
  enum Thing: Hashable {
    case window(UInt32)
    case tile(NodeID)
    case seam(SeamKey)
  }

  /// Front first. Panels are in it too; `stack` puts their level first.
  var order: [Thing] = []
  /// The window numbers of Arbor's own windows. AppKitOverlays keeps a panel per tile and per seam.
  var overlayIDs: [Thing: UInt32] = [:]
  private var nextOverlayID: UInt32 = 9001

  // MARK: Keyboard and pointer

  /// The app in front, most recent first. Empty, or Finder's first: no test app has the keyboard.
  var recentApps: [Int32] = [World.finderPID]
  /// The window that had the keyboard when the world last looked (`followKeyboard`).
  private var keyboardSeen: WindowID?
  /// Whether the press in progress has been reported already, among the reports of the keyboard it moved (`press(at:)`).
  var pressIsTold = false
  /// The process that Arbor was last told is in front (`tellWhoIsInFront`).
  var toldInFront: Int32?
  var held = Held.nothing
  /// Arbor's shortcuts that went down with `key … --down` and have not come up.
  var heldShortcuts: [KeyChord.Key: KeyBinding] = [:]
  /// "Click wallpaper to reveal desktop" (macOS 14 and later, on unless switched off) has swept every window
  /// aside. The window server has them at the sides of the screen; Accessibility, and so Arbor, where they
  /// are.
  var isSwept = false {
    didSet {
      guard isSwept != oldValue else { return }
      sweptFrames = [:]
      guard isSwept else { return }
      for case .window(let id) in stack { sweptFrames[id] = frame(of: id).map(swept) }
    }
  }
  /// Where the window server lists each window that was swept, for as long as the sweep lasts, whatever becomes
  /// of the window meanwhile: it is a picture. A window that opens meanwhile is not among them, and shows where it is.
  var sweptFrames: [UInt32: CGRect] = [:]
  /// Apps that do not answer (`hang`), and when on the world's clock they wake up.
  var hungUntil: [Int32: Double] = [:]

  // MARK: Arbor

  var arbor: Arbor?
  /// Whether Arbor is among the login items. macOS keeps that, not Arbor, so it outlives a launch.
  /// Whether each launch so far had ARBOR_DEBUG on, for `Session.publish`.
  var launchesWithDebug: [Bool] = []
  /// The Arbor that was killed last, if it had a watchdog that has not acted yet.
  var killedWithWatchdog: Int32?
  /// What the desktop shows (`pointer wallpaper`).
  var wallpaper: String?
  /// `quit` is answered first and obeyed afterwards.
  var quitRequested = false
  /// The process whose curtain hangs behind the test windows, as lib.sh hangs one on a person's Mac (rehearse.sh,
  /// ARBOR_REHEARSAL_AS=person). The same for every call of a run, so every replay sees the same world.
  let curtainPID = ProcessInfo.processInfo.environment["ARBOR_CURTAIN_PID"].flatMap { Int32($0) }
  /// Whether Arbor opens at login. macOS keeps that, not Arbor, so it outlives a launch.
  let loginItem = FakeLoginItem()
  /// Seconds since the world began. Controllers come and go; the clock they read does not start over.
  var elapsed: Double = 0
  /// Every trace recorded so far, by its file's name in `<Arbor home>/traces`. They outlive the Arbor that
  /// recorded them.
  var traces: [String: MemoryTraceSink] = [:]
  /// How many lines each of them had before the line that is happening now, for `Session.publish`.
  var traceLinesBefore: [String: Int] = [:]

  // MARK: The outside

  /// The files in Arbor's home folder that Arbor reads or writes, as they are at this point of the history.
  /// Arbor's own writes go here; what a script did to them in between comes in as a line's notes.
  private var home: [String: Data] = [:]
  /// What Arbor last saved, if state.json is that. Encoded only when somebody wants the bytes: nearly every
  /// line saves.
  private var freshState: PersistedState?
  /// What the line that is happening now found changed on the disk, to be written after it.
  private(set) var newNotes: [Entry.Note] = []
  /// The files a script may change behind Arbor's back, and those only Arbor writes.
  static let filesRead = ["settings.json", "state.json"]
  /// A setting of the Mac's that the world goes by, where the `defaults` stand-in keeps it
  /// (rehearse/mac-tools).
  static let clickWallpaperSetting = "defaults/com.apple.WindowManager.EnableStandardClickToShowDesktop"
  /// macOS's own tiling of dragged windows. As on a Mac, a key that is not there means on.
  static let tilingSettings = ["EnableTilingByEdgeDrag", "EnableTopTilingByEdgeDrag", "EnableTilingOptionAccelerator"].map {
    "defaults/com.apple.WindowManager.\($0)"
  }
  static let titleBarActionSetting = "defaults/-g.AppleActionOnDoubleClick"
  static let filesWritten =
    filesRead + ["settings.before-format-\(Settings.format).json", "state.unreadable.json", "state.before-repair.json", "arbor.lock"]

  init(socket: String, display: DisplaySnapshot) {
    self.socket = socket
    self.display = display
    system = FakeWindowSystem(displays: [display])
    system.cursor = CGPoint(x: 10, y: 10)
    // How long the pointer and the keyboard have been still is counted on the world's clock.
    system.clock = { [unowned self] in elapsed }
  }

  // MARK: Lines

  /// Before a line runs: what had changed outside when it first ran.
  func begin(_ entry: Entry) {
    for note in entry.notes { put(note.data, in: note.name) }
    if entry.notes.contains(where: { $0.name == "settings.json" }) { settingsFileWasSaved() }
  }

  /// Before the line that is happening now: looks at the real folder for what a script has changed since the
  /// last line (settings.json edited, state.json deleted or damaged…) and notes it, so that later replays see
  /// the same.
  func noticeChanges(in folder: String, settingsIn rehearsal: String?) {
    for name in World.filesRead + [World.clickWallpaperSetting, World.titleBarActionSetting] + World.tilingSettings {
      let path = (name.hasPrefix("defaults/") ? rehearsal ?? "/dev/null" : folder) + "/" + name
      let data = try? Data(contentsOf: URL(fileURLWithPath: path))
      guard data != file(name) else { continue }
      newNotes.append(Entry.Note(name: name, data: data))
      put(data, in: name)
    }
    if newNotes.contains(where: { $0.name == "settings.json" }) { settingsFileWasSaved() }
  }

  /// `SettingsWatcher`, as `ArborApp.watchSettingsFile` wires it: an edit applies 0.3 s after it is saved. Here
  /// that is over before the next line, even one that follows at once, as `reload-settings` does in many a
  /// script: it then finds the file applied already, which changes nothing but the log.
  private func settingsFileWasSaved() {
    guard let arbor else { return }
    arbor.controller.settingsFileMayHaveChanged()
    letTimePass(0.3)
  }

  /// A file in Arbor's home folder, as it is at this point of the history.
  func file(_ name: String) -> Data? {
    if name == "state.json", let state = freshState {
      // As `FileStateStore.save` writes it.
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      home[name] = try? encoder.encode(state)
      freshState = nil
    }
    return home[name]
  }

  func put(_ data: Data?, in name: String) {
    if name == "state.json" { freshState = nil }
    home[name] = data
  }

  /// Arbor saved.
  func put(state: PersistedState) { freshState = state }

  /// Whether a line changes nothing, so that it need not be written down.
  static func onlyAsks(_ fields: [String]) -> Bool {
    let words = Array(fields.dropFirst())
    switch fields[0] {
    case "pointer":
      if words.first == "wallpaper" { return words.count == 1 }
      return !["move", "click", "drag", "drag-on", "release", "calm", "key", "pinch"].contains(words.first ?? "")
    case "arborctl":
      // What cannot be read is refused before it gets to the controller.
      guard let command = command(ofArborctl: words) else { return true }
      return command.isQuery
    case "lsappinfo":
      return true
    case "open":
      return !words.contains { $0.hasPrefix("arbor:") }
    case "app-request":
      let verb = words.dropFirst().first?.split(separator: " ").first.map(String.init)
      return ["events", "list", "ping"].contains(verb ?? "list")
    default:
      return false
    }
  }

  /// arborctl's arguments without its own options, and whether `--json` was among them. How long it waits for an answer (`--timeout`) is nothing to
  /// this Arbor, which answers at once or is not there.
  static func arborctlArguments(_ words: [String]) -> (command: [String], rawJSON: Bool) {
    var arguments = words
    if arguments.first == "--timeout" { arguments.removeFirst(min(2, arguments.count)) }
    let rawJSON = arguments.first == "--json"
    if rawJSON { arguments.removeFirst() }
    // What follows belongs to the command, whatever it looks like.
    if arguments.first == "--" { arguments.removeFirst() }
    return (arguments, rawJSON)
  }

  static func command(ofArborctl words: [String]) -> Command? {
    let arguments = arborctlArguments(words).command
    return arguments.isEmpty ? nil : try? Command.parse(arguments.joined(separator: " "))
  }

  /// Whether a line takes none of the world's time. A word to the recorder is said about what happens and is no part of it: a script that is
  /// recorded must find the clock where the same script finds it unrecorded.
  static func takesNoTime(_ fields: [String]) -> Bool {
    guard fields[0] == "arborctl", case .trace? = command(ofArborctl: Array(fields.dropFirst())) else { return false }
    return true
  }

  func perform(_ fields: [String]) -> Reply {
    let words = Array(fields.dropFirst())
    do {
      let reply: Reply
      switch fields[0] {
      case "pointer": reply = try pointer(words)
      case "arborctl": reply = arborctl(words)
      case "open": reply = open(words)
      case "lsappinfo": reply = try lsappinfo(words)
      case "sleep": reply = try sleep(words)
      case "app-start": reply = try startApp(words)
      case "app-request": reply = try appRequest(words)
      case "app-exit": reply = try endApp(words)
      case "arbor-start": reply = try startArbor(words)
      case "arbor-term": reply = terminateArbor(words)
      case "arbor-killed": reply = killArbor()
      case "arbor-watchdog": reply = watchdogActs(words)
      default: throw Refusal(message: "arbor-fakemac: cannot replay a line that starts with \(fields[0])")
      }
      if quitRequested { terminate() }
      return reply
    } catch let refusal as Refusal {
      return Reply(err: refusal.message + "\n", code: refusal.code)
    } catch {
      return Reply(err: "arbor-fakemac: \(error)\n", code: 70)
    }
  }

  // MARK: Time

  /// The reports that follow what just happened, then a second. Saving waits 0.5 s and putting a docked window
  /// back 0.25 s (again and again while the button is down, which the end of the second bounds).
  func letTimePass(_ seconds: Double = 1) {
    system.deliverEchoes()
    // Apps that insist on a frame or wake up from a hang do so in Arbor's own rhythm, not once a second.
    let step = system.stubbornFrames.isEmpty && hungUntil.isEmpty ? seconds : 0.25
    var left = seconds
    while left > 0 {
      let span = min(step, left)
      left -= span
      system.appsSettle()
      arbor?.scheduler.advance(by: span)
      elapsed += span
      for (pid, end) in hungUntil.sorted(by: { $0.key < $1.key }) where end <= elapsed {
        hungUntil[pid] = nil
        system.setUnresponsive(pid: pid, false)
      }
      system.deliverEchoes()
    }
    followKeyboard()
    noteSavedState()
  }

  /// `sleep <seconds>`: the script waits for something that takes time, a timed pause for one. Only waits of a
  /// second or more get here (rehearse/mac-tools): the short ones are polling, and a second passes anyway.
  private func sleep(_ words: [String]) throws -> Reply {
    guard words.count == 1, let seconds = Double(words[0]), seconds >= 0, seconds <= 86_400 else {
      throw Refusal(
        message: "sleep (rehearsal): expected a number of seconds, got \(words.joined(separator: " "))")
    }
    letTimePass(max(seconds - 1, 0))
    return Reply()
  }

  // MARK: Windows

  func newExtraID() -> UInt32 {
    defer { nextExtraID += 1 }
    return nextExtraID
  }

  func overlayID(of thing: Thing) -> UInt32 {
    if let id = overlayIDs[thing] { return id }
    defer { nextOverlayID += 1 }
    overlayIDs[thing] = nextOverlayID
    return nextOverlayID
  }

  func newOverlayID() -> UInt32 {
    defer { nextOverlayID += 1 }
    return nextOverlayID
  }

  func owner(of id: UInt32) -> Int32? { system.windows[WindowID(id)]?.snapshot.pid ?? extras[id]?.pid }

  /// Where the window server has a test window. A sheet sits in the middle of its window and goes where that
  /// goes.
  func frame(of id: UInt32) -> CGRect? {
    if let frame = system.frame(of: WindowID(id)) { return frame }
    guard let extra = extras[id] else { return nil }
    if case .sheet(let parent) = extra.kind, let around = system.frame(of: parent) {
      return CGRect(
        x: (around.midX - extra.frame.width / 2).rounded(), y: (around.midY - extra.frame.height / 2).rounded(),
        width: extra.frame.width, height: extra.frame.height)
    }
    return extra.frame
  }

  func isOnScreen(_ id: UInt32) -> Bool {
    if let snapshot = system.windows[WindowID(id)]?.snapshot {
      return !snapshot.isMinimized && !snapshot.isHidden
    }
    guard let extra = extras[id], apps[extra.pid]?.hidden != true else { return false }
    if case .sheet(let parent) = extra.kind { return isOnScreen(parent.rawValue) }
    return true
  }

  func level(of thing: Thing) -> Int {
    if case .window(let id) = thing, extras[id]?.kind == .panel { return 3 }
    return 0
  }

  func frame(of thing: Thing) -> CGRect? {
    switch thing {
    case .window(let id): return isOnScreen(id) ? frame(of: id) : nil
    case .tile(let node): return arbor?.overlays.tile(node)?.frame
    case .seam(let key): return arbor?.overlays.seam(key)?.frame
    }
  }

  /// What is on screen and takes clicks, front first.
  var stack: [Thing] {
    let shown = order.filter { frame(of: $0) != nil }
    return shown.filter { level(of: $0) == 3 } + shown.filter { level(of: $0) == 0 }
  }

  func raise(_ thing: Thing) {
    order.removeAll { $0 == thing }
    order.insert(thing, at: 0)
    // A sheet stays in front of its window.
    guard case .window(let id) = thing else { return }
    for sheet in extras.values.filter({ $0.kind == .sheet(parent: WindowID(id)) }).map(\.id).sorted() {
      order.removeAll { $0 == .window(sheet) }
      order.insert(.window(sheet), at: 0)
    }
  }

  func lower(_ thing: Thing) {
    order.removeAll { $0 == thing }
    order.append(thing)
  }

  /// An app that shows again without coming forward (`unhideWithoutActivation`) brings its windows back as one block, in the order they
  /// had among themselves: right behind the window that has the keyboard, or in front of everything if none has. Seen on two hosted
  /// Macs. W1 W2 W4 W3 before the hide, W4 being another app's, came back as W1 W2 W3 W4 with Finder in front and as W4 W1 W2 W3 with
  /// W4 in use.
  func showAgainTogether(_ pid: Int32) {
    let own = order.filter { thing in
      if case .window(let id) = thing { return owner(of: id) == pid }
      return false
    }
    order.removeAll { own.contains($0) }
    let behind = system.focused.flatMap { order.firstIndex(of: .window($0.rawValue)) }.map { $0 + 1 } ?? 0
    order.insert(contentsOf: own, at: behind)
  }

  /// `NSWindow.order(.below, relativeTo:)`. Where the other is not there, `thing` stays where it is.
  func lower(_ thing: Thing, justBelow other: Thing) {
    guard thing != other, order.contains(other) else { return }
    order.removeAll { $0 == thing }
    order.insert(thing, at: order.firstIndex(of: other)! + 1)
  }

  /// The app's windows come forward together, in the order they had.
  func raiseAll(of pid: Int32) {
    let own = order.filter { thing in
      if case .window(let id) = thing { return owner(of: id) == pid }
      return false
    }
    order.removeAll { own.contains($0) }
    order.insert(contentsOf: own, at: 0)
  }

  func forget(_ thing: Thing) {
    order.removeAll { $0 == thing }
    overlayIDs[thing] = nil
  }

  /// The app's frontmost window that could take the keyboard.
  func frontWindow(of pid: Int32, except excluded: UInt32? = nil) -> WindowID? {
    for case .window(let id) in order where id != excluded && isOnScreen(id) {
      if system.windows[WindowID(id)]?.snapshot.pid == pid { return WindowID(id) }
    }
    return nil
  }

  // MARK: Who has the keyboard

  var frontApp: Int32 { recentApps.first ?? World.finderPID }

  func bringForward(app pid: Int32) {
    recentApps.removeAll { $0 == pid }
    recentApps.insert(pid, at: 0)
    tellWhoIsInFront()
  }

  /// `FrontmostAppWatcher`, which goes on looking during a pause. The workspace gives one notice for each app that comes forward and none
  /// for one that is in front already, so Arbor hears one word, by one road: the fake's own, which `userFocus` takes as well and which says
  /// nothing twice. Two processes of one app are one to the fake, which goes by the name: of the second the world tells itself. So it does during
  /// a pause, when nobody listens on the fake's road: or an Arbor that has paused for an app never hears that the app was left, and stays paused.
  func tellWhoIsInFront() {
    guard toldInFront != frontApp else { return }
    toldInFront = frontApp
    let before = system.frontmost
    let isHeard = system.events != nil
    if let app = frontmostApp { system.activate(bundleID: app.bundleID, name: app.name) }
    if !isHeard || system.frontmost == before { arbor?.controller.reports.applicationActivated(frontmostApp) }
  }

  var frontmostApp: FrontmostApp? {
    if let app = apps[frontApp] { return FrontmostApp(bundleID: app.bundleID, name: app.name) }
    return FrontmostApp(bundleID: "com.apple.finder", name: "Finder")
  }

  /// `FakeWindowSystem` decides where the keyboard goes when a window opens, closes, is minimized or hidden and
  /// when Arbor asks, and reports it. What that looks like is the world's: the window comes to the front, and
  /// its app is the one in front.
  func followKeyboard() {
    guard system.focused != keyboardSeen else { return }
    keyboardSeen = system.focused
    guard let window = system.focused, let pid = system.windows[window]?.snapshot.pid else { return }
    raise(.window(window.rawValue))
    bringForward(app: pid)
    apps[pid]?.focused = window.rawValue
    isSwept = false
  }

  /// The user, or the window's own app while it is in front, gives a window the keyboard. Arbor hears of it
  /// when that is news. `byItself`: an app in the background took it and nobody had touched anything.
  /// `byAPress`: the button has just gone down on it, which is told of in the order of a Mac.
  func giveKeyboard(to window: WindowID, byItself: Bool = false, byAPress: Bool = false) {
    guard let pid = system.windows[window]?.snapshot.pid else { return }
    raise(.window(window.rawValue))
    bringForward(app: pid)
    apps[pid]?.focused = window.rawValue
    isSwept = false
    keyboardSeen = window
    if system.focused != window {
      if byItself {
        system.comesForward(window)
      } else if byAPress, !system.heldModifiers.contains(.command) {
        pressIsTold = true
        system.press(on: window)
      } else {
        system.userFocus(window)
      }
    }
    // Arbor may have sent the keyboard back while it was told, and then that window and its app are in front.
    followKeyboard()
  }

  /// The keyboard goes to something Arbor knows no window for: the Desktop, a panel, a dialog.
  /// `number`: what macOS names meanwhile: a panel's or a dialog's own.
  func keyboardLeavesTheWindows(for number: WindowID? = nil) {
    // Which app is in front is this world's to say (`bringForward`).
    if system.focused != number { system.keyboardGoesToNoKnownWindow(named: number) }
    keyboardSeen = number
  }

  /// Another app comes to the front without any of its windows changing: ⌘Tab, a click in the Dock. No window's
  /// focus changes, but the workspace says that the app became active, and `AXWindowSystem.appCameForward`
  /// reports the window that app had focused all along. (`FakeWindowSystem.userSwitchesApp` is what macOS alone
  /// says.)
  ///
  /// `byItself`: the app activates itself, as the test app does on a signal. Then AppKit gives the keyboard to the frontmost of the app's
  /// windows, which need not be the one that had it last (one opened while the app was in the background lies before it), and only
  /// that window comes above the other apps'. Seen on a hosted Mac: W5 W4 W1 W3, where W4 is the other app's.
  func switchTo(app pid: Int32, byItself: Bool = false) {
    bringForward(app: pid)
    guard let app = apps[pid] else { return keyboardLeavesTheWindows() }
    if byItself, let window = frontWindow(of: pid) { return giveKeyboard(to: window) }
    raiseAll(of: pid)
    if let focused = app.focused, isOnScreen(focused) {
      if system.windows[WindowID(focused)] != nil {
        giveKeyboard(to: WindowID(focused))
      } else {
        keyboardLeavesTheWindows()
      }
    } else if let window = frontWindow(of: pid) {
      giveKeyboard(to: window)
    } else {
      keyboardLeavesTheWindows()
    }
  }

  /// `lsappinfo front` and `lsappinfo info -only name <what that printed>`, which is how scripts ask who is in
  /// front.
  private func lsappinfo(_ words: [String]) throws -> Reply {
    if words == ["front"] { return .printing("ASN:0x0-0x\(String(frontApp, radix: 16)):") }
    guard words.count == 4, Array(words.prefix(2)) == ["info", "-only"], ["name", "pid"].contains(words[2])
    else {
      throw Refusal(
        message: "lsappinfo (rehearsal): no stand-in for: lsappinfo \(words.joined(separator: " "))")
    }
    let digits = words[3].split(separator: "x").last?.dropLast() ?? ""
    guard let pid = Int32(digits, radix: 16) else { return Reply() }
    if words[2] == "pid" { return .printing("\"pid\"=\(pid)") }
    let name = pid == World.finderPID ? "Finder" : pid == arbor?.pid ? "Arbor" : apps[pid]?.name
    return name.map { .printing("\"LSDisplayName\"=\"\($0)\"") } ?? Reply()
  }

  /// The app hid or quit. If the keyboard went to another app's window, `followKeyboard` has brought that app
  /// forward; otherwise Finder is in front now.
  func leaveFront(_ pid: Int32) {
    followKeyboard()
    recentApps.removeAll { $0 == pid }
    if system.focused == nil { bringForward(app: World.finderPID) }
    tellWhoIsInFront()
  }
}
