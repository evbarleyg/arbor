import AppKit
import ApplicationServices
import ArborCore
import ArborIPC
import ServiceManagement

/// The composition root: builds the real window system, overlays, controller,
/// control socket, menu bar item and hotkeys, and handles the app lifecycle.
@MainActor
public final class ArborApp: NSObject, NSApplicationDelegate {
  /// Runs the app. Call from `main.swift`.
  public static func run() {
    let arguments = CommandLine.arguments
    if arguments.dropFirst().first == Watchdog.argument { Watchdog.run(arguments: arguments) }
    ProcessGuards.prepareProcess()
    if let code = LaunchArguments.run(Array(arguments.dropFirst())) { exit(code) }
    let application = NSApplication.shared
    let delegate = ArborApp()
    application.delegate = delegate
    application.setActivationPolicy(.accessory)
    withExtendedLifetime(delegate) { application.run() }
  }

  let environment: ArborEnvironment
  let controller: Controller
  /// The events of `arborctl watch`.
  private let feed: EventFeed
  private var server: ControlServer?
  private var statusMenu: StatusMenu?
  private var hotKeys: HotKeyCenter?
  /// The shortcuts registered now. The controller is told, for menus, tooltips and `doctor`.
  private(set) var activeBindings: [KeyBinding] = [] {
    didSet { controller.registeredBindings = activeBindings }
  }
  /// What was last registered and logged, so applying settings that leave the shortcuts as they
  /// were (`exclude`, say) neither registers them all again nor repeats the log lines. Shortcuts
  /// that failed to register (another app holds them) are tried again.
  private var lastBindings: (bindings: [KeyBinding], problems: [String])?
  private var permissionTimer: Timer?
  private var signalSources: [DispatchSourceSignal] = []
  private var pointerInput: PointerInput?
  private let guards = ProcessGuards()
  private var onboarding: OnboardingWindow?
  private var frontmostApp: FrontmostAppWatcher?
  private var keyboardLayout: KeyboardLayoutWatcher?
  private var callSensor: CallSensor?
  private let updateWindow = UpdateWindow()
  private var settingsWatcher: SettingsWatcher?
  private var settingsWindow: SettingsWindowController?
  /// What was last beeped about.
  private var lastSettingsFileProblem: String?

  override init() {
    let environment = ArborEnvironment.current
    let settings = SettingsFile.load()
    self.environment = environment
    let overlays = AppKitOverlays()
    overlays.takesPicturesOfWindows = settings.windowPictures
    // Each seam is wrapped in a decorator that records what crosses it while `trace on` is in effect
    // (docs/TRACES.md) and otherwise only passes it on.
    let recorder = TraceRecorder()
    let windowSystem = AXWindowSystem(onlyPIDs: environment.onlyPIDs)
    windowSystem.recorder = recorder
    overlays.recorder = recorder
    let controller = Controller(
      system: RecordingWindowSystem(wrapping: windowSystem, recorder: recorder),
      overlays: RecordingOverlays(wrapping: overlays, recorder: recorder),
      store: FileStateStore(), scheduler: RecordingScheduler(wrapping: MainQueueScheduler(), recorder: recorder),
      settings: settings, filter: WindowFilter(onlyPIDs: environment.onlyPIDs))
    self.controller = controller
    feed = EventFeed(controller: controller)
    super.init()
    controller.saveSettings = { try SettingsFile.update(from: $0, to: $1) }
    controller.loadSettings = { try SettingsFile.read() }
    controller.systemShortcuts = { SystemShortcutReader.read() }
    controller.onTemporaryShortcuts = { [weak self] in self?.hotKeys?.setTemporary($0) }
    controller.replaceSettingsFile = { try SettingsFile.replace(with: $0) }
    controller.keepCopyOfSettingsFile = { try SettingsFile.keepCopy() }
    controller.onShowSettingsWindow = { [weak self] pane in self?.showSettingsWindow(at: pane) }
    controller.onCloseSettingsWindow = { [weak self] in self?.settingsWindow?.close() }
    controller.onSettingsApplied = { [weak self, weak overlays] applied in
      self?.registerHotKeys()
      self?.pointerInput?.update()
      overlays?.takesPicturesOfWindows = applied.windowPictures
      self?.updateCallSensor()
    }
    // Pausing and resuming change which shortcuts and taps Arbor holds, and so do an app that keeps
    // its own ⌃⌥ coming to the front and holding the view. Not when quitting, which also stops the
    // controller: the taps are already gone then and must stay gone.
    controller.observe { [weak self] change in
      guard change == .lifecycle || change == .input || change == .hold, let self else { return }
      guard self.controller.isInBusiness else { return }
      self.registerHotKeys()
      self.pointerInput?.update()
    }
    // The controller belongs to this object, so it cannot outlive it.
    controller.systemFacts = { [unowned self] in self.systemFacts() }
    controller.openWelcomeWindow = { [unowned self] page in self.showWelcomeWindow(page) }
    controller.nameOfApp = { MacFacts.name(ofApp: $0) }
    // The mouse-down tap decides from a copy of where bare Desktop might be, so it gets a new one whenever a
    // layout, the view, a window's move, the settings, a pause or the app in front may have changed that.
    controller.observe { [weak self] change in
      guard change.mayChangeDesktopGuardZones, let self else { return }
      self.pointerInput?.publish(self.controller.desktopGuardZones())
    }
    // When to take new pictures of windows for the next motion.
    controller.observe { [weak overlays] change in
      switch change {
      case .focus(let window): overlays?.windowFocused(window)
      case .layout: overlays?.windowsWereLaidOut()
      default: break
      }
    }
    overlays.onRehearsalOutdated = { [weak controller] in controller?.rehearseAfresh() }
    let build = BuildInfo(infoDictionary: Bundle.main.infoDictionary)
    controller.buildInfo = build
    controller.releaseFeed = GitHubReleaseFeed(
      address: environment.releasesURL ?? UpdateCheck.latestReleaseAPI, version: build.version)
    controller.onUpdateDecision = { [weak self] decision in
      self?.updateWindow.show(decision, current: build)
    }
    controller.loginItem = SystemLoginItem()
    // From the first start on the controller watches the permission itself (Controller+Permission.swift).
    // The taps' own check: the flag, and a tap made and thrown away. It talks to no app, so none can keep it waiting.
    controller.accessibilityProbe = { thoroughly in thoroughly ? EventTap.isPermitted() : AXIsProcessTrusted() }
    // The window explains first; macOS's own prompt comes when the user clicks its button.
    controller.askForAccessibility = { [weak self] in
      if self?.environment.noPrompt == false { self?.showWelcomeWindow() }
    }
  }

  // MARK: Lifecycle

  public func applicationDidFinishLaunching(_ notification: Notification) {
    Log.info("Arbor \(controller.buildInfo.text) starting, pid \(getpid()), home \(ArborPaths.home.path)")
    guards.claimSingleInstance(prompt: !environment.noPrompt)
    if environment.rescue {
      rescueAndQuit()
      return
    }
    guards.start(environment: environment) { [weak self] in self?.controller.sessionIsEnding() }
    if let dark = environment.darkAppearance { NSApp.appearance = NSAppearance(named: dark ? .darkAqua : .aqua) }
    startServer()
    watchSettingsFile()
    installSignalHandlers()
    NSAppleEventManager.shared().setEventHandler(
      self, andSelector: #selector(handleURLEvent(_:reply:)), forEventClass: AEEventClass(kInternetEventClass),
      andEventID: AEEventID(kAEGetURL))
    // Said before the menu bar item is made, which shows it: nothing announces a change of this.
    let permitted = AXIsProcessTrusted()
    controller.accessibilityGranted = permitted
    if !environment.noStatusItem { statusMenu = StatusMenu(app: self) }

    if permitted {
      startController()
    } else {
      waitForAccessibility()
    }
  }

  /// Arbor was opened again while running (from Finder, Spotlight or `open`). It has no Dock icon, and on a
  /// crowded menu bar macOS hides its item behind the notch, so this may be the only way to reach it.
  public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    showWelcomeWindow()
    return false
  }

  public func applicationWillTerminate(_ notification: Notification) {
    // First, so no pinch or click waits on Arbor while it puts windows back.
    pointerInput?.stop()
    frontmostApp?.stop()
    keyboardLayout?.stop()
    callSensor?.stop()
    settingsWatcher?.stop()
    controller.shutdown()
    hotKeys?.unregisterAll()
    // Last, so that a script that waits for `quitting` finds every window back in view.
    feed.stop()
    server?.stop()
    guards.standDown()
    Log.info("Arbor quit")
  }

  /// `ARBOR_RESCUE=1`: Arbor kept ending without quitting, so whatever it does at launch may be the
  /// cause. This does the least that gets people's windows back: no saved state, no socket, hotkeys,
  /// menu or event taps. Starting adopts every window, and quitting puts those out of view back in it.
  private func rescueAndQuit() {
    let store = FileStateStore()
    store.setAside()
    if AXIsProcessTrusted() {
      controller.start()
      Log.error("rescue: brought every window into view; quitting")
    } else {
      Log.error("rescue: no Accessibility permission, so windows cannot be moved; quitting")
    }
    controller.shutdown()
    // Quitting saved: every window floating, nothing worth keeping. With no file the next launch sees that one was set aside.
    store.discard()
    if !environment.noPrompt {
      let alert = NSAlert()
      alert.messageText = "Arbor stopped unexpectedly several times"
      alert.informativeText = """
        Your windows are back in view and Arbor has quit. Its saved arrangement was set aside, in case \
        that was the cause. The log is at \(ArborPaths.logFile.path).
        """
      NSApp.activate()
      alert.runModal()
    }
    NSApp.terminate(nil)
  }

  private func startController() {
    controller.accessibilityGranted = true
    // First, so that launching behind an app that keeps its own ⌃⌥ takes nothing from it even for a moment.
    let watcher = FrontmostAppWatcher { [weak self] app in self?.controller.applicationActivated(app) }
    watcher.start()
    frontmostApp = watcher
    // And so that the first registration is already on the right keys.
    let layouts = KeyboardLayoutWatcher { [weak self] layout in self?.controller.keyboardLayoutChanged(layout) }
    layouts.start()
    keyboardLayout = layouts
    controller.restartedAfterAccident = environment.restarted
    controller.start()
    registerHotKeys()
    if !environment.noHotkeys {
      let input = PointerInput(
        settings: { [weak self] in self?.controller.inputSettings ?? Settings() },
        onCommand: { [weak self] command in self?.handle(command, from: .gesture) },
        onGesture: { [weak self] update in self?.controller.gesture(update) },
        // A press that a tap holds back reaches no monitor, and a press ends a motion all the same.
        onPress: { [weak self] in self?.controller.pointerPressed() })
      // Its watchdog looks once a second, and what it finds out about the permission concerns more than the taps.
      input.onPermissionChange = { [weak self] in self?.controller.askAboutAccessibility(beyondDoubt: true) }
      input.update()
      input.publish(controller.desktopGuardZones())
      pointerInput = input
    }
    // Not in a session limited to test windows: what the Mac's camera is doing must not change a test's outcome.
    if environment.onlyPIDs == nil {
      callSensor = CallSensor { [weak self] signals in self?.controller.callSignalsChanged(signals) }
      updateCallSensor()
    }
    // Last, so that shortcuts macOS refused and event taps that did not install are among them.
    // Not under test: an Arbor that is limited to some processes is somebody's tool on what may be somebody else's Mac, and its log is
    // quoted in reports. Which window managers run there and how Desktop & Dock is set is nobody's business. `doctor` still says it.
    if environment.onlyPIDs == nil { controller.logSetupProblems() }
    // Once in a lifetime: with the permission already there, nothing else would show that Arbor has started.
    if !environment.noPrompt, let page = controller.pageToWelcomeOn() { showWelcomeWindow(page) }
  }

  private func updateCallSensor() {
    callSensor?.update(
      camera: controller.settings.holdStillWhileCameraIsOn, microphone: controller.settings.holdStillWhileMicrophoneIsOn)
  }

  /// Registers the shortcuts the controller wants held now (`Controller.activeBindings`) in place of the
  /// ones registered before, and logs the `bindings` entries that were skipped. Runs at start, after
  /// every settings change, which is how `reload-settings` picks up edited bindings, and when a
  /// pause, the frontmost app or another keyboard layout changes the answer.
  private func registerHotKeys() {
    guard controller.isInBusiness else { return }
    let bindings = environment.noHotkeys ? [] : controller.activeBindings
    let problems = controller.effectiveBindings.problems
    if let last = lastBindings, last.bindings == bindings, last.problems == problems,
      activeBindings == bindings
    {
      return
    }
    lastBindings = (bindings, problems)
    controller.logSkippedBindings()
    controller.logSystemShortcutClashes()

    guard !bindings.isEmpty else {
      hotKeys?.unregisterAll()
      controller.refusedBindings = []
      activeBindings = []
      return
    }
    let center = hotKeys ?? HotKeyCenter { [weak self] binding, phase in
      guard let self else { return }
      let result = self.controller.shortcut(binding, phase, run: { self.handle($0, from: .shortcut) })
      // Only without the permission. Why any other key did nothing is said on screen, and `handle` has the beep for those who
      // switched that off, and knows when to keep quiet.
      guard result?.ok == false, !self.controller.accessibilityGranted else { return }
      NSSound.beep()
      // The ways home are held without the permission only to lead to where it is granted.
      if self.controller.shouldOpenAccessibilitySettings() { self.openAccessibilitySettings() }
    }
    hotKeys = center
    let began = DispatchTime.now().uptimeNanoseconds
    let failed = center.register(bindings)
    controller.refusedBindings = failed
    let microseconds = (DispatchTime.now().uptimeNanoseconds - began) / 1000
    activeBindings = bindings.filter { !failed.contains($0) }
    Log.info("registered \(activeBindings.count) shortcuts in \(microseconds) µs")
  }

  /// Applies edits to settings.json as they are saved.
  private func watchSettingsFile() {
    // The settings are the ones just read at launch, so this changes nothing; but if the file could not
    // be read, the controller now knows, and will not save the defaults over it.
    controller.takeInSettingsFile()
    lastSettingsFileProblem = controller.settingsFileProblem
    // Someone who has just saved a mistake is looking at an editor, not at Arbor's log.
    controller.observe { [weak self] change in
      guard change == .settings, let self else { return }
      let problem = self.controller.settingsFileProblem
      if let problem, problem != self.lastSettingsFileProblem { NSSound.beep() }
      self.lastSettingsFileProblem = problem
    }
    let watcher = SettingsWatcher(file: ArborPaths.settingsFile) { [weak self] in
      self?.controller.settingsFileMayHaveChanged()
    }
    watcher.start()
    settingsWatcher = watcher
  }

  // MARK: The settings window

  /// `settings-window`, ⌃⌥, and Settings… in the menu.
  private func showSettingsWindow(at pane: SettingsPane?) {
    let window = settingsWindow ?? makeSettingsWindow()
    settingsWindow = window
    window.show(at: pane)
  }

  private func makeSettingsWindow() -> SettingsWindowController {
    let model = SettingsPanelModel(
      controller: controller,
      runningApps: { SettingsWindowController.runningApps() },
      run: { [weak self] command in self?.handle(command) ?? .failure("Arbor is quitting") })
    return SettingsWindowController(
      model: model, openFile: { [weak self] in self?.openSettingsFile() },
      openLoginItems: { SMAppService.openSystemSettingsLoginItems() })
  }

  private func waitForAccessibility() {
    controller.accessibilityGranted = false
    Log.info("waiting for Accessibility permission")
    // The window explains first; macOS's own prompt comes when the user clicks its button.
    if !environment.noPrompt { showWelcomeWindow() }
    permissionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated {
        guard AXIsProcessTrusted() else { return }
        self?.permissionTimer?.invalidate()
        self?.permissionTimer = nil
        Log.info("Accessibility permission granted")
        self?.startController()
      }
    }
  }

  // MARK: Commands

  /// Runs a command from any source. `quit` terminates after replying. Arbor's own menu and windows
  /// need not say who they are.
  @discardableResult
  func handle(_ command: Command, from source: CommandSource = .menu) -> CommandResult {
    if command == .quit {
      DispatchQueue.main.async { NSApp.terminate(nil) }
    }
    let result = controller.perform(command, from: source)
    // The controller says on screen why a key or a menu item did nothing. For those who switched that off there is
    // the Mac's own way of saying "that does nothing here".
    // Not during a hold: a call would hear it.
    if !result.ok, source == .shortcut || source == .menu, controller.settings.messageLevel == .off, controller.mayShowUnasked {
      NSSound.beep()
    }
    return result
  }

  private func startServer() {
    let endpoint = ControlEndpoint(feed: feed) { [weak self] command in
      self?.handle(command, from: .script) ?? .failure("Arbor is quitting")
    }
    let server = ControlServer { line in endpoint.respond(to: line) }
    do {
      // The socket takes commands: never in a folder that somebody else owns or can write to.
      try ArborPaths.ensureHome()
      try server.start()
      self.server = server
    } catch {
      Log.error("control socket unavailable: \(error)")
    }
  }

  /// `arbor://dock/left`, `arbor://show-all`, `arbor://view/2`. Anything can open a URL, so the
  /// controller decides which commands they may run (Controller+URL.swift).
  @objc private func handleURLEvent(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
    guard let text = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue else { return }
    switch controller.admit(url: text) {
    case .success(let command): handle(command, from: .url)
    case .failure: NSSound.beep()
    }
  }

  private func installSignalHandlers() {
    for signalNumber in [SIGTERM, SIGINT, SIGHUP] {
      signal(signalNumber, SIG_IGN)
      let source = DispatchSource.makeSignalSource(signal: signalNumber, queue: .main)
      source.setEventHandler {
        MainActor.assumeIsolated { NSApp.terminate(nil) }
      }
      source.resume()
      signalSources.append(source)
    }
  }

  // MARK: Menu helpers

  /// The items of the menu that only the app can carry out.
  func carryOut(_ action: MenuModel.AppAction) {
    switch action {
    case .openSettingsFile: openSettingsFile()
    case .showLog: openLog()
    case .showAbout: showAbout()
    case .quit: NSApp.terminate(nil)
    }
  }

  var isBundled: Bool { Bundle.main.bundleURL.pathExtension == "app" }

  var launchesAtLogin: Bool { controller.loginItem?.status == .enabled }

  func toggleLaunchAtLogin() {
    if handle(.launchAtLogin(!launchesAtLogin)).ok { return }
    if controller.loginItem?.status == .requiresApproval {
      // Only the user can switch it back on, so take them to the switch.
      SMAppService.openSystemSettingsLoginItems()
    } else {
      NSSound.beep()
    }
  }

  func openSettingsFile() {
    SettingsFile.create(controller.settings)
    NSWorkspace.shared.open(ArborPaths.settingsFile)
  }

  func openLog() {
    NSWorkspace.shared.open(ArborPaths.logFile)
  }

  func showAbout() {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize), .foregroundColor: NSColor.labelColor,
      .paragraphStyle: paragraph,
    ]
    let credits = NSMutableAttributedString(
      string: "Dock windows side by side,\nthen zoom between them.\n\nFree and open source\n", attributes: attributes)
    let repository = "https://github.com/evbarleyg/arbor"
    if let url = URL(string: repository) {
      credits.append(
        NSAttributedString(string: repository, attributes: attributes.merging([.link: url]) { _, link in link }))
    }
    let build = controller.buildInfo
    NSApp.activate(ignoringOtherApps: true)
    NSApp.orderFrontStandardAboutPanel(options: [
      .applicationName: "Arbor",
      .applicationIcon: ArborArtwork.appIcon(side: 128),
      // The panel writes "Version 0.9.0 (build 214, 47a2ba9)", which is `BuildInfo.text` with a word before it.
      .applicationVersion: build.version,
      .version: [build.build.map { "build \($0)" }, build.commit].compactMap { $0 }.joined(separator: ", "),
      .credits: credits,
    ])
  }

  // MARK: The welcome window

  /// - Parameter page: the page to open it on, or turn it to. Without the permission it is the first whatever is asked
  ///   for. Nil when Arbor only wants it seen: an open window comes forward as it is.
  func showWelcomeWindow(_ page: OnboardingFlow.Page? = nil) {
    if onboarding == nil {
      onboarding = OnboardingWindow(
        controller: controller, onButton: { [weak self] row in self?.openSystemSettings(for: row) },
        onLogin: { [weak self] in self?.toggleLaunchAtLogin() })
    }
    onboarding?.show(page)
    controller.noteWelcomed()
  }

  /// For whoever finds the permission missing at a moment when the window would be too much (F63: a shortcut that fails).
  func openAccessibilitySettings() { openSystemSettings(for: .accessibility) }

  /// A row's button: lets macOS put Arbor in the list the row is about, then opens that pane of System Settings.
  private func openSystemSettings(for row: OnboardingModel.Row.ID) {
    let pane: String
    switch row {
    case .accessibility:
      // The literal is kAXTrustedCheckOptionPrompt; the global is not concurrency-safe in Swift 6.
      AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
      pane = "com.apple.preference.security?Privacy_Accessibility"
    case .screenRecording:
      CGRequestScreenCaptureAccess()
      pane = "com.apple.preference.security?Privacy_ScreenCapture"
    case .desktopAndDock:
      pane = "com.apple.Desktop-Settings.extension"
    case .inputSources:
      pane = "com.apple.Keyboard-Settings.extension"
    case .competingApps, .voiceOver, .ownShortcuts:
      return  // these rows have no button
    }
    if let url = URL(string: "x-apple.systempreferences:" + pane) { NSWorkspace.shared.open(url) }
  }

  /// What only macOS knows, read afresh: for `doctor` and, once a second, the welcome window.
  private func systemFacts() -> SystemFacts {
    SystemFacts(
      accessibility: AXIsProcessTrusted(), screenRecording: CGPreflightScreenCaptureAccess(),
      switches: MacFacts.switches, separateSpaces: NSScreen.screensHaveSeparateSpaces,
      voiceOver: NSWorkspace.shared.isVoiceOverEnabled, inputSources: MacFacts.inputSources,
      competingApps: MacFacts.competingApps, opensAtLogin: isBundled ? launchesAtLogin : nil,
      inputDisabled: environment.noHotkeys,
      eventTaps: pointerInput?.installedTaps ?? [])
  }
}
