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
  private let wardrobe = Wardrobe()
  /// The stand-ins of each display's last motion that set off without their cover, by app.
  private var undressed: [DisplayID: [Rehearsal.App: [WindowID]]] = [:]
  /// How covers look in the motion each display last played.
  private var looks: [DisplayID: Transition.Cover] = [:]
  private var mouseMonitors: [Any] = []
  private var observers: [NSObjectProtocol] = []
  /// When the last transition began, in seconds since the Mac started, as events are stamped.
  private var lastBegan: TimeInterval = 0
  private var focused: WindowID?
  /// Reduce Motion may have been switched on or off. While it is on nothing is got ready.
  var onDisplayOptionsChanged: (() -> Void)?
  /// `ARBOR_NO_REHEARSAL`, for measuring what a first motion costs that nothing was got ready for.
  private static let rehearsalIsSwitchedOff = ArborEnvironment.current.noRehearsal

  init() {
    pictures.onPicture = { [weak self] window, picture in
      guard let self else { return }
      for stage in self.stages.values { stage.show(picture, of: window) }
    }
    wardrobe.onCover = { [weak self] app, cover in
      guard let self else { return }
      for (display, cast) in self.undressed {
        let costume = Costume(palette: self.palette(of: cover, on: display), icon: cover.icon)
        for window in cast[app] ?? [] { self.stages[display]?.show(costume, of: window) }
        self.undressed[display]?[app] = nil
      }
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
      workspace.addObserver(forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil, queue: .main) {
        [weak self] _ in
        MainActor.assumeIsolated { self?.onDisplayOptionsChanged?() }
      })
    observers.append(
      NotificationCenter.default.addObserver(
        forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated {
          guard let self else { return }
          self.finish()
          // A display that went away takes its stage with it. The others keep theirs: macOS says this at every minimize, and
          // the next motion would wait for a new panel each time. A stage takes its display's frame whenever it plays.
          self.stages = self.stages.filter { ScreenGeometry.screen(for: $0.key) != nil }
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
    // The real windows wait until the stage is up, and whoever pressed the key waits with them. Where that time went
    // is in the log, because no one can tell afterwards.
    var marks = [uptime]
    let stage = stages[display] ?? makeStage(for: display)
    let wasUp = stage.isUp
    marks.append(uptime)
    var costumes: [WindowID: Costume] = [:]
    looks[display] = transition.cover
    undressed[display] = [:]
    for item in transition.items { costumes[item.window] = costume(for: item, on: display) }
    let plainCards = undressed[display]?.values.reduce(0) { $0 + $1.count } ?? 0
    marks.append(uptime)
    let desktop = pictures.desktop(of: display)
    marks.append(uptime)
    lastBegan = ProcessInfo.processInfo.systemUptime
    stage.play(transition, costumes: costumes, backdrop: desktop, surface: surface)
    marks.append(uptime)
    // Not for a correction: the windows have moved by then.
    if !wasUp {
      let took = zip(marks.dropFirst(), marks).map { ms($0 - $1) }
      let story = "the stage kept the windows waiting \(ms(marks[4] - marks[0])) ms: its panel \(took[0]), "
        + "\(costumes.count) costumes \(took[1]) (\(plainCards) not ready), the desktop \(took[2]), going up \(took[3])"
      // A tenth of a second is felt. That is worth a line in anybody's log.
      if marks[4] - marks[0] >= 0.1 { Log.info(story) } else { Log.debug(story) }
    }
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

  // MARK: Getting ready

  /// Makes now, when nobody waits, what the next motion would otherwise make while somebody does: a display's stage and
  /// the picture behind it. An app's colour and icon are ordered (`Wardrobe`). All of it is kept, and what is there already is
  /// skipped. The controller hands out one display or one app at a time (Controller+Rehearsal.swift).
  func rehearse(_ rehearsal: Rehearsal) {
    guard !Self.rehearsalIsSwitchedOff, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
    for display in rehearsal.displays {
      guard let screen = ScreenGeometry.screen(for: display) else { continue }
      var marks = [uptime]
      // Kept once read, and let go of when Arbor stops and when pictures are switched off. With pictures a sweep brings the
      // desktop as it is, and the wallpaper's file would be read for nothing.
      let desktop = pictures.areTaken ? nil : pictures.desktop(of: display)
      marks.append(uptime)
      if stages[display] == nil {
        makeStage(for: display).rehearse(in: ScreenGeometry.global(fromAppKit: screen.frame), backdrop: desktop)
      }
      marks.append(uptime)
      Log.debug("got ready the stage of \(display) in \(ms(marks[2] - marks[0])) ms, the desktop \(ms(marks[1] - marks[0])) of them")
    }
    // Also where stand-ins are pictures of their windows: a tile, a window back from the Dock and one that has only just opened are covers.
    for app in rehearsal.apps { wardrobe.order(app, again: app.bundleID == nil) }
  }

  private func ms(_ seconds: TimeInterval) -> Int { Int((seconds * 1000).rounded()) }

  private var uptime: TimeInterval { ProcessInfo.processInfo.systemUptime }

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

  private func costume(for item: Transition.Item, on display: DisplayID) -> Costume {
    let picture = pictures.picture(of: item.window)
    // A cover that stays hidden behind the picture is not even looked for.
    guard picture == nil || item.fromLook == .cover || item.toLook == .cover else {
      return Costume(picture: picture)
    }
    // Never waited for: see `Wardrobe`.
    let cover = wardrobe.cover(of: item.app)
    if cover == nil { undressed[display, default: [:]][item.app, default: []].append(item.window) }
    return Costume(picture: picture, palette: palette(of: cover ?? Wardrobe.plain, on: display), icon: cover?.icon)
  }

  /// A tile's, by the look of the motion that is playing on `display`.
  private func palette(of cover: Wardrobe.Cover, on display: DisplayID) -> TilePalette {
    (looks[display] ?? Transition.Cover()).palette(
      appColour: cover.colour, isDark: NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua)
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
