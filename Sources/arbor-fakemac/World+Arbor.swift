import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation

/// Arbor's life, and what ArborApp, SettingsFile, FileStateStore, PointerInput and arborctl do around the
/// controller. They are macOS-only code or read files, so their few decisions and their log lines are repeated
/// here; when one of them changes, this has to follow.
extension World {
  // MARK: Launching

  /// `arbor-start <pid> <bundled> home=… socket=… [watchdog=<pid>] [ARBOR_…=…]`
  func startArbor(_ words: [String]) throws -> Reply {
    guard words.count >= 2, let pid = Int32(words[0]) else {
      throw Refusal(message: "arbor-fakemac: usage: arbor-start <pid> <bundled: 0 or 1>")
    }
    var options: [String: String] = [:]
    for word in words.dropFirst(2) {
      let parts = word.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
      if parts.count == 2 { options[parts[0]] = parts[1] }
    }
    // As ArborEnvironment reads them.
    func flag(_ name: String) -> Bool {
      guard let value = options[name]?.lowercased() else { return false }
      return !["", "0", "false", "no"].contains(value)
    }
    let onlyPIDs = options["ARBOR_ONLY_PIDS"].map { list in
      Set(list.split(separator: ",").compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) })
    }
    let home = options["home"] ?? "?"
    // As `Log` reads it. A second copy leaves at once, and what follows its first line in the log is the first
    // copy's.
    launchesWithDebug.append(
      arbor == nil ? !["", "0"].contains(options["ARBOR_DEBUG"] ?? "") : launchesWithDebug.last ?? true)
    let settings = loadSettings()
    Log.info("Arbor starting, pid \(pid), home \(home)")

    // `ProcessGuards.claimSingleInstance`
    if let running = arbor {
      let advice =
        "It has no window of its own: it is the icon in the menu bar. To start it afresh, choose Quit Arbor "
        + "there (or run arborctl quit) and open it again."
      Log.error(
        "another Arbor (pid \(running.pid)) already runs from \(home); this one (pid \(pid)) is leaving")
      return Reply(err: "Arbor is already running. \(advice)\n", code: 75)
    }
    put(Data("\(pid)\n".utf8), in: "arbor.lock")

    let arbor = Arbor(
      pid: pid, bundled: words[1] == "1", noHotkeys: flag("ARBOR_NO_HOTKEYS"),
      noStatusItem: flag("ARBOR_NO_STATUS_ITEM"), onlyPIDs: onlyPIDs, settings: settings, home: home,
      world: self)
    self.arbor = arbor
    let controller = arbor.controller
    controller.saveSettings = { [weak self] in try self?.updateSettings(from: $0, to: $1) }
    controller.loadSettings = { [weak self] in try self?.readSettings() ?? Settings() }
    controller.onSettingsApplied = { [weak self] _ in
      self?.registerHotKeys()
      self?.updatePointerInput()
    }
    // Pausing and resuming change which shortcuts and taps Arbor holds. Not when quitting.
    controller.observe { [weak self, weak controller] change in
      guard change == .lifecycle || change == .input, let controller, controller.isRunning || controller.isPaused
      else { return }
      self?.registerHotKeys()
      self?.updatePointerInput()
    }
    controller.releaseFeed = LateReleaseFeed(scheduler: arbor.scheduler)
    // `UpdateWindow.show`. No Mac has listed this window: its level and its width are in the code, its height goes by the
    // words, and where `center()` puts it is AppKit's to say. In the one picture of it from a hosted Mac it was 424 by 156, a
    // quarter of the room left above it. That was another answer, "Arbor 9.9.9 is available": three lines and two buttons,
    // where the one given here has one button and, by estimate, two lines.
    controller.onUpdateDecision = { [weak self, weak arbor] _ in
      guard let self, let arbor else { return }
      let area = display.visibleFrame
      let origin = CGPoint(x: area.midX - 212, y: (area.minY + (area.height - 156) / 4).rounded(.down))
      arbor.updateWindow = (newOverlayID(), CGRect(origin: origin, size: CGSize(width: 424, height: 156)))
    }
    // A fixed day, so that what is saved does not depend on when the rehearsal runs.
    let launched = Date(timeIntervalSinceReferenceDate: 800_000_000 + elapsed)
    controller.now = { [scheduler = arbor.scheduler] in launched.addingTimeInterval(scheduler.now) }
    // As `Harness` wires them: what answers Arbor's calls arrives once the call has returned.
    arbor.scheduler.afterEach = { [system] in system.deliverEchoes() }
    system.afterEvents = { [scheduler = arbor.scheduler] in scheduler.advance(by: 0) }

    // `ArborApp.rescueAndQuit`, with permission and without the alert.
    if flag("ARBOR_RESCUE") {
      setStateAside()
      controller.start()
      Log.error("rescue: brought every window into view; quitting")
      controller.shutdown()
      terminate()
      return Reply()
    }

    // `ProcessGuards.start`
    if !flag("ARBOR_NO_WATCHDOG"), let watchdog = options["watchdog"].flatMap({ Int32($0) }) {
      arbor.watchdog = watchdog
      Log.info("watchdog started, pid \(watchdog)")
    }
    Log.info("control socket at \(options["socket"] ?? "?")")
    arbor.store.saved = loadState(into: arbor.store)
    controller.accessibilityGranted = true
    // `FrontmostAppWatcher.start` reports once at once. The keyboard layout is the US one, which is the controller's own.
    controller.reports.applicationActivated(frontmostApp)
    controller.restartedAfterAccident = !(options["ARBOR_RESTARTS"] ?? "").isEmpty
    controller.start()
    registerHotKeys()
    arbor.hasPointerInput = !arbor.noHotkeys
    updatePointerInput()
    return Reply()
  }

  // MARK: settings.json, as `SettingsFile` treats it

  /// `SettingsFile.contents`: nil if there is no file or nothing but white space in it.
  private var settingsData: Data? {
    file("settings.json").flatMap { data in
      data.allSatisfy { [0x20, 0x09, 0x0A, 0x0D].contains($0) } ? nil : data
    }
  }

  /// `SettingsFile.load`
  private func loadSettings() -> Settings {
    // `SettingsFile.upgrade`
    if let data = settingsData, String(data: data, encoding: .utf8) != nil,
      let upgraded = try? Settings.upgradedFile(String(decoding: data, as: UTF8.self))
    {
      let copy = "settings.before-format-\(Settings.format).json"
      if file(copy) == nil { put(data, in: copy) }
      put(Data(upgraded.text.utf8), in: "settings.json")
      Log.info(
        "settings.json now holds only what differs from the defaults; taken out, to follow the defaults from now on: "
          + (upgraded.stripped.isEmpty ? "nothing" : upgraded.stripped.joined(separator: ", ")))
    }
    do {
      return try readSettings()
    } catch {
      Log.error("settings.json is invalid, using defaults: \(error)")
      return Settings()
    }
  }

  /// `SettingsFile.read`
  private func readSettings() throws -> Settings {
    guard let data = settingsData else {
      createSettings(Settings())
      return Settings()
    }
    let settings = try Settings.read(data)
    for problem in settings.problemsForTheLog { Log.error("settings.json: \(problem)") }
    return settings
  }

  /// `SettingsFile.create`
  func createSettings(_ settings: Settings) {
    do {
      if settingsData == nil { put(Data(try settings.fileText.utf8), in: "settings.json") }
    } catch {
      Log.error("could not write settings: \(error)")
    }
  }

  /// `SettingsFile.update`
  private func updateSettings(from old: Settings, to new: Settings) throws {
    guard let data = settingsData else { return put(Data(try new.fileText.utf8), in: "settings.json") }
    guard String(data: data, encoding: .utf8) != nil else {
      throw Settings.FileError("the file is not UTF-8 text, so Arbor cannot change it")
    }
    let text = String(decoding: data, as: UTF8.self)
    let rewritten = try Settings.rewrite(text, from: old, to: new)
    if rewritten != text { put(Data(rewritten.utf8), in: "settings.json") }
  }

  // MARK: state.json, as `FileStateStore` treats it

  /// `FileStateStore.load`
  private func loadState(into store: MemoryStateStore) -> PersistedState? {
    guard let data = file("state.json") else { return nil }
    let notes = DecodingNotes()
    switch PersistedState.read(data, notes: notes) {
    case .loaded(let state):
      for note in notes.notes { Log.error("state.json: \(note)") }
      guard !notes.notes.isEmpty else { return state }
      // `keepACopy`, the first time.
      put(data, in: "state.before-repair.json")
      Log.error("state.json as it was before these repairs is now state.before-repair.json")
      (store.repairs, store.keptCopy) = (notes.notes, "state.before-repair.json")
      return state
    case .newer(let version):
      store.loadProblem = .newer
      Log.error(
        "state.json is from a newer Arbor (format \(version); this one reads \(PersistedState.currentVersion))")
    case .unreadable(let reason):
      store.loadProblem = .unreadable
      Log.error("could not read saved state: \(reason)")
    }
    setStateAside()
    store.keptCopy = "state.unreadable.json"
    return nil
  }

  /// `FileStateStore.setAside`
  private func setStateAside() {
    guard let data = file("state.json") else { return }
    put(data, in: "state.unreadable.json")
    put(nil, in: "state.json")
    Log.error("starting fresh; the old state is now state.unreadable.json")
  }

  /// `FileStateStore.save`, for what the controller has saved since this was last asked.
  func noteSavedState() {
    guard let arbor, arbor.store.saveCount != arbor.savesSeen, let state = arbor.store.saved else { return }
    arbor.savesSeen = arbor.store.saveCount
    put(state: state)
  }

  /// `ArborApp.registerHotKeys`, on a Mac that says yes to every shortcut, which is all a real one has been seen to do.
  private func registerHotKeys() {
    guard let arbor, arbor.controller.isRunning || arbor.controller.isPaused else { return }
    guard let bindings = arbor.controller.shortcutsToRegister() else { return }
    arbor.controller.shortcutsWereRegistered(HotKeyOutcome(held: bindings), microseconds: arbor.noHotkeys ? 0 : 900)
  }

  /// `PointerInput.update`: `GestureTap.update`, then `RectangleFramer.update`.
  private func updatePointerInput() {
    guard let arbor, arbor.hasPointerInput else { return }
    let settings = arbor.controller.inputSettings
    /// `EventTap.install` says so from the tap's thread, which reaches the log after what the main thread is
    /// doing.
    var installed: [String] = []

    arbor.router.threshold = settings.pinchThreshold
    arbor.router.zoomsWithScroll = settings.scrollZoom
    arbor.router.scrollThreshold = settings.scrollZoomThreshold
    arbor.router.zoomsOnDesktop = settings.scrollOnDesktopZooms
    if arbor.router.setContinuous(settings.continuousZoom) { drainGestures() }
    if !settings.gesturesEnabled {
      arbor.pinchTap = false
      arbor.scrollTap = false
      if arbor.router.reset() { drainGestures() }
    } else {
      if !arbor.pinchTap {
        arbor.pinchTap = true
        installed.append("pinch")
        Log.info("pinch event tap installed")
      }
      let wantsScrolls = settings.continuousZoom || settings.scrollZoom
      if wantsScrolls, !arbor.scrollTap {
        arbor.scrollTap = true
        installed.append("scroll")
        Log.info("scroll event tap installed")
      } else if !wantsScrolls {
        arbor.scrollTap = false
      }
    }

    let text = settings.frameRectangleModifier
    if !arbor.gesture.follow(settings), arbor.unreadableModifier != text {
      arbor.unreadableModifier = text
      let fallback = Settings().frameRectangleModifier
      Log.error("frameRectangleModifier \"\(text)\" is not like \"ctrl+opt\" or \"none\"; using \(fallback)")
    }
    if !arbor.gesture.isEnabled {
      arbor.rectangleTaps = false
      arbor.gesture.reset()
      arbor.band?.shown = false
    } else if !arbor.rectangleTaps {
      arbor.rectangleTaps = true
      installed += ["rectangle", "rectangle drag"]
      Log.info("rectangle event taps installed")
    }
    for name in installed { Log.debug("\(name) event tap installed") }
  }

  /// `GestureTap.visit`
  func drainGestures() {
    guard let arbor else { return }
    for update in arbor.router.drain() { arbor.controller.gesture(update) }
  }

  // MARK: Ending

  /// `applicationWillTerminate`: what `quit`, the menu's Quit Arbor and SIGTERM, SIGINT and SIGHUP lead to.
  func terminate() {
    quitRequested = false
    guard let arbor else { return }
    arbor.controller.shutdown()
    Log.info("Arbor quit")
    noteSavedState()
    forgetArbor()
  }

  /// `arbor-term <pid>`: the stand-in caught a signal.
  func terminateArbor(_ words: [String]) -> Reply {
    if let arbor, words.first == String(arbor.pid) { terminate() }
    return Reply()
  }

  /// SIGKILL: nothing is put back and nothing is saved. Arbor's own windows go with its process.
  func killArbor() -> Reply {
    system.stop()
    system.events = nil
    killedWithWatchdog = arbor.flatMap { $0.watchdog == nil ? nil : $0.pid }
    forgetArbor()
    return Reply()
  }

  /// `arbor-watchdog <pid> [ARBOR_RESTARTS=…]`: the stand-in's watchdog has seen that process end.
  /// `Watchdog.run`, from where the pipe closes. Prints what the stand-in is to do: `restart` or `rescue`, and
  /// the next ARBOR_RESTARTS.
  func watchdogActs(_ words: [String]) -> Reply {
    // Arbor wrote `q` when it quit in good order.
    guard let pid = words.first.flatMap({ Int32($0) }), killedWithWatchdog == pid else { return Reply() }
    killedWithWatchdog = nil
    let text = words.dropFirst().first { $0.hasPrefix("ARBOR_RESTARTS=") }?.dropFirst("ARBOR_RESTARTS=".count)
    // The world's clock, counted from a fixed day as the controller's is.
    let now = 1_800_000_000 + elapsed
    let history = RestartPolicy.recent(RestartPolicy.history(from: text.map(String.init)), now: now)
    let verdict: String
    switch RestartPolicy.decide(history: history, now: now) {
    case .restart:
      Log.error("Arbor (pid \(pid)) ended without quitting; starting it again")
      verdict = "restart"
    case .rescue:
      Log.error("Arbor (pid \(pid)) ended without quitting, the third time in a row; bringing the windows back")
      verdict = "rescue"
    case .giveUp:
      Log.error(
        "Arbor (pid \(pid)) ended without quitting yet again; giving up. Starting Arbor recovers its windows")
      return Reply(code: 1)
    }
    return .printing("\(verdict) \(RestartPolicy.text(for: history + [now]))")
  }

  private func forgetArbor() {
    arbor = nil
    system.afterEvents = nil
    order.removeAll { thing in
      if case .window = thing { return false }
      return true
    }
    overlayIDs = [:]
    // What the pointer held of Arbor's is gone; the button is still down.
    switch held {
    case .seam, .tile, .menuItem, .rectangle: held = .idle
    default: break
    }
  }

  // MARK: Commands

  /// `ArborApp.handle`
  @discardableResult
  func handle(_ command: Command, from source: CommandSource = .menu) -> CommandResult {
    guard let arbor else { return .failure("Arbor is not running") }
    if command == .quit { quitRequested = true }
    return arbor.controller.perform(command, from: source)
  }

  /// Sources/arborctl/main.swift and `ArborApp.handleLine`
  func arborctl(_ words: [String]) -> Reply {
    var (arguments, rawJSON) = World.arborctlArguments(words)
    if arguments.isEmpty || arguments == ["--help"] || arguments == ["-h"] { arguments = ["help"] }
    // Answered by arborctl itself, because people read the help before they have Arbor running.
    if arguments == ["help"] { return .printing(Command.helpText) }
    guard arbor != nil else {
      let advice = "start it with `open -a Arbor`"
      return Reply(err: "arborctl: Arbor is not running (no control socket at \(socket)); \(advice)\n", code: 2)
    }
    let result: CommandResult
    do {
      result = handle(try Command.parse(arguments.joined(separator: " ")), from: .script)
    } catch {
      result = .failure("\(error)")
    }
    if rawJSON || arguments.first == "state" {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let reply = (try? encoder.encode(result)).map { String(decoding: $0, as: UTF8.self) }
      return .printing(reply ?? #"{"ok":false,"message":"encoding failed"}"#)
    }
    return Reply(out: (result.text ?? result.message) + "\n", code: result.ok ? 0 : 1)
  }

  /// `open <url>` and `ArborApp.handleURLEvent`. macOS hands URLs to app bundles only, and this one does not
  /// launch any.
  func open(_ words: [String]) -> Reply {
    guard let text = words.first(where: { $0.hasPrefix("arbor:") }) else { return Reply() }
    guard let arbor, arbor.bundled else {
      let why =
        arbor == nil ? "Arbor is not running" : "Arbor was not started from its app bundle (ARBOR_BUNDLED=1)"
      return Reply(err: "open (rehearsal): no application knows how to open \(text): \(why)\n", code: 1)
    }
    // The controller decides which commands a URL may run, and logs the ones it refuses. ArborApp only beeps.
    if case .success(let command) = arbor.controller.admit(url: text) { handle(command, from: .url) }
    return Reply()
  }
}
