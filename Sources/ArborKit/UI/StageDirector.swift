import AppKit
import ArborCore

/// Plays transitions: one `Stage` per display, dressed from `WindowPictures` and `AppAppearance`.
///
/// It also sees to it that no stage outstays its welcome. Whatever makes the picture on a stage
/// wrong, or shows that the user wants their windows now, takes every stage down at once: a mouse
/// button going down anywhere, sleep and wake, a Space switch, a change of displays.
@MainActor
final class StageDirector {
  let pictures = WindowPictures()

  private var stages: [DisplayID: Stage] = [:]
  /// The windows each display's last transition left showing as themselves, largest first. Their
  /// pictures are taken again once things have settled.
  private var showing: [DisplayID: [WindowID]] = [:]
  private var icons: [String: CGImage] = [:]
  private var mouseMonitors: [Any] = []
  private var observers: [NSObjectProtocol] = []
  /// When the last transition began, in seconds since the Mac started, as events are stamped.
  private var lastBegan: TimeInterval = 0
  private var focused: WindowID?

  init() {
    pictures.onPicture = { [weak self] window, picture in
      guard let self else { return }
      for stage in self.stages.values { stage.show(picture, of: window) }
    }
    let workspace = NSWorkspace.shared.notificationCenter
    for name in [
      NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification, NSWorkspace.screensDidSleepNotification,
      NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.sessionDidResignActiveNotification,
    ] {
      observers.append(
        workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
          MainActor.assumeIsolated { self?.finish() }
        })
    }
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          self?.finish()
          // A display that went away takes its stage with it.
          self?.stages.removeAll()
        }
      })
  }

  // MARK: Playing

  func play(_ transition: Transition, surface: BackdropModel?) {
    guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
      Log.debug("no stage: Reduce motion is on")
      return
    }
    guard transition.duration > 0, transition.frame.isFinite, transition.frame.width >= 1,
      transition.frame.height >= 1
    else {
      finish()
      return
    }
    let display = transition.display
    let stage = stages[display] ?? makeStage(for: display)
    var costumes: [WindowID: Costume] = [:]
    for item in transition.items { costumes[item.window] = costume(for: item) }
    lastBegan = ProcessInfo.processInfo.systemUptime
    stage.play(transition, costumes: costumes, backdrop: pictures.desktop(of: display), surface: surface)
    watchTheMouse()

    let staying = transition.items.filter {
      $0.toLook == .picture && $0.toOpacity > 0 && $0.to.overlaps(transition.frame)
    }
    showing[display] = staying.sorted { $0.to.area > $1.to.area }.map(\.window)
    // A moment from now, which is after the caller has moved the real windows (it keeps the main
    // thread busy until then): the new pictures show the windows at the size the stage will reveal.
    pictures.refresh(showing[display] ?? [], after: 0.01)
  }

  /// A display's scene changed. During a motion that is the scene the motion ends in.
  func surfaceChanged(_ surface: BackdropModel?, on display: DisplayID) {
    stages[display]?.show(surface: surface)
  }

  /// Takes every stage down at once.
  func finish() {
    for stage in stages.values { stage.drop() }
  }

  /// Arbor is stopping: nothing of anyone's windows is kept.
  func stop() {
    finish()
    showing.removeAll()
    pictures.removeAll()
  }

  private func makeStage(for display: DisplayID) -> Stage {
    let stage = Stage()
    stage.onDown = { [weak self] in self?.stageCameDown(on: display) }
    stages[display] = stage
    return stage
  }

  private func stageCameDown(on display: DisplayID) {
    if !stages.values.contains(where: \.isUp) { stopWatchingTheMouse() }
    // Apps go on redrawing for a moment after a resize.
    pictures.refresh(showing[display] ?? [], after: 0.3)
  }

  // MARK: Keeping pictures fresh

  /// Windows may have appeared or changed size. The first time is at launch, which is what has
  /// pictures ready for the first motion.
  func windowsWereLaidOut() {
    pictures.refresh(after: 0.6)
  }

  /// The window the user leaves will mostly stay as it is now; the one they turn to is the one they
  /// are most likely to move next.
  func windowFocused(_ window: WindowID) {
    pictures.refresh([focused, window].compactMap { $0 }, after: 0.4)
    focused = window
  }

  // MARK: Costumes

  private func costume(for item: Transition.Item) -> Costume {
    let picture = pictures.picture(of: item.window)
    // Working out an app's colour and icon takes a few milliseconds the first time. A motion must not
    // wait for a cover that stays hidden behind the picture.
    guard picture == nil || item.fromLook == .cover || item.toLook == .cover else {
      return Costume(picture: picture)
    }
    return Costume(
      picture: picture,
      // The colour is the icon's average, transparent margin included. A cover hides what is behind it.
      colour: AppAppearance.colour(pid: item.pid, bundleID: item.bundleID).withAlphaComponent(1).cgColor,
      icon: icon(for: item))
  }

  private func icon(for item: Transition.Item) -> CGImage? {
    let key = item.bundleID ?? "pid-\(item.pid)"
    if let cached = icons[key] { return cached }
    var proposed = NSRect(x: 0, y: 0, width: 256, height: 256)
    guard let image = AppAppearance.icon(pid: item.pid)?.cgImage(forProposedRect: &proposed, context: nil, hints: nil)
    else { return nil }
    icons[key] = image
    return image
  }

  // MARK: A click during an animation ends it

  private func watchTheMouse() {
    guard mouseMonitors.isEmpty else { return }
    let buttons: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
    // Global monitors see other apps' events, local ones Arbor's own (a click on a tile, the menu).
    let global = NSEvent.addGlobalMonitorForEvents(matching: buttons) { [weak self] event in
      let time = event.timestamp
      MainActor.assumeIsolated { self?.mouseWentDown(at: time) }
    }
    let local = NSEvent.addLocalMonitorForEvents(matching: buttons) { [weak self] event in
      let time = event.timestamp
      MainActor.assumeIsolated { self?.mouseWentDown(at: time) }
      return event
    }
    mouseMonitors = [global, local].compactMap { $0 }
  }

  private func stopWatchingTheMouse() {
    for monitor in mouseMonitors { NSEvent.removeMonitor(monitor) }
    mouseMonitors.removeAll()
  }

  private func mouseWentDown(at time: TimeInterval) {
    // The click that started the motion (on a tile, say) can arrive after the motion has begun.
    guard time > lastBegan else { return }
    finish()
  }
}
