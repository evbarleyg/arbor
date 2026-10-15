import AppKit
import ArborCore
import ImageIO
// Its classes are not marked Sendable. They never leave the main actor here.
@preconcurrency import ScreenCaptureKit

/// Still pictures of the windows on screen, and of the desktop behind them, for the stage to draw.
///
/// A motion has to start the moment it is asked for, and taking a picture takes a while, so pictures
/// are taken ahead of time and kept: when Arbor starts, when the focus moves on, and after every
/// motion. The stage starts with what is here, asks for new pictures, and swaps them in as they
/// come. A window without a picture is drawn as its cover.
///
/// Pictures need Screen Recording permission. Arbor works without it and never asks for it from here
/// (onboarding may, see `isAllowed`). They are stills, not recordings. They are kept in memory only, let
/// go of when their window leaves the screen and when Arbor stops, and nothing is written to disk.
@MainActor
final class WindowPictures {
  /// Whether macOS lets Arbor take pictures of other apps' windows. Asking this never prompts.
  static var isAllowed: Bool { !isSwitchedOff && CGPreflightScreenCaptureAccess() }

  /// The `windowPictures` setting. While it is off no picture is taken, whatever macOS allows, and none is kept.
  var isWanted = false {
    didSet {
      guard isWanted != oldValue else { return }
      if isWanted { refresh(after: 0.6) } else { removeAll() }
    }
  }

  /// Whether stand-ins are pictures of their windows, now or as soon as a sweep has been round.
  var areTaken: Bool { isWanted && Self.isAllowed }

  /// `ARBOR_NO_PICTURES`, for looking at Arbor as it is without the permission on a Mac that has it.
  private static let isSwitchedOff = ArborEnvironment.current.noPictures

  /// A picture holds at most this many pixels, which bounds the memory a window costs (12 MB). Small
  /// windows are as sharp as the display; a window that fills a Retina display is a little softer.
  private static let mostPixels: CGFloat = 3_000_000
  private static let mostPerSweep = 40
  /// Windows narrower or lower than this are not worth a picture.
  private static let smallestSide: CGFloat = 40
  /// What shows through a window's rounded corners. It has to outlive every configuration it is given
  /// to: `SCStreamConfiguration.backgroundColor` does not retain its value, and a colour made on the
  /// spot is gone by the time ScreenCaptureKit copies the configuration, which crashes.
  private static let noBackground = NSColor.clear.cgColor

  /// Called with every new picture of a window.
  var onPicture: ((WindowID, CGImage) -> Void)?

  private var pictures: [WindowID: CGImage] = [:]
  /// What is behind the windows on each display: wallpaper, icons, widgets.
  private var desktops: [DisplayID: CGImage] = [:]
  /// Wallpaper files that were read, for when there is no picture of the desktop.
  private var wallpapers: [String: CGImage] = [:]
  /// Windows to take a new picture of in the next sweep, most important first.
  private var wanted: [WindowID] = []
  private var timer: Timer?
  private var isSweeping = false
  private var sweepAgain = false
  /// Counts `removeAll()`, so that a sweep under way does not fill the store again.
  private var epoch = 0

  func picture(of window: WindowID) -> CGImage? { pictures[window] }

  /// A picture of the desktop as it is, or else the wallpaper's file, or else nothing.
  func desktop(of display: DisplayID) -> CGImage? { desktops[display] ?? wallpaper(of: display) }

  /// Takes new pictures `delay` seconds from now: of `windows`, most important first, then of every
  /// window on screen that has none, then of the desktop.
  ///
  /// Whoever names windows is waiting for them, so a later request never puts that off. A request
  /// that names none is housekeeping: asking again starts its wait anew, so a burst of them
  /// (a seam being dragged) costs one sweep when it is over.
  func refresh(_ windows: [WindowID] = [], after delay: TimeInterval) {
    let someoneIsWaiting = !wanted.isEmpty
    for window in windows where !wanted.contains(window) { wanted.append(window) }
    let due = Date(timeIntervalSinceNow: max(delay, 0))
    if someoneIsWaiting, let timer, timer.isValid, timer.fireDate <= due { return }
    timer?.invalidate()
    let timer = Timer(fire: due, interval: 0, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated { self?.sweep() }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  func removeAll() {
    epoch += 1
    timer?.invalidate()
    timer = nil
    wanted.removeAll()
    pictures.removeAll()
    desktops.removeAll()
    wallpapers.removeAll()
  }

  // MARK: Taking pictures

  private func sweep() {
    timer?.invalidate()
    timer = nil
    guard isWanted, Self.isAllowed else {
      wanted.removeAll()
      // The wallpaper's file is all there is to show. Read it before the first motion needs it.
      for screen in NSScreen.screens { _ = wallpaper(of: ScreenGeometry.displayID(for: screen)) }
      return
    }
    guard !isSweeping else {
      sweepAgain = true
      return
    }
    isSweeping = true
    let first = wanted
    wanted.removeAll()
    let epoch = self.epoch
    Task { @MainActor in
      await self.takePictures(first: first, epoch: epoch)
      self.isSweeping = false
      if self.sweepAgain {
        self.sweepAgain = false
        self.sweep()
      }
    }
  }

  private func takePictures(first: [WindowID], epoch: Int) async {
    let started = ProcessInfo.processInfo.systemUptime
    let content: SCShareableContent
    do {
      content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
    } catch {
      Log.debug("pictures: no list of windows: \(error)")
      return
    }
    guard epoch == self.epoch else { return }

    // Normal and floating windows of other apps. Windows Arbor moved out of view count as on screen.
    let own = getpid()
    var listed: [WindowID: SCWindow] = [:]
    for window in content.windows
    where (0...NSWindow.Level.floating.rawValue).contains(window.windowLayer)
      && window.owningApplication?.processID != own
      && window.frame.width >= Self.smallestSide && window.frame.height >= Self.smallestSide
    {
      listed[WindowID(window.windowID)] = window
    }
    pictures = pictures.filter { listed[$0.key] != nil }

    // The first picture of a desktop comes before the windows: it is the largest thing on the stage.
    // Without Arbor's own backdrop, which lies there too: its shape changes with the arrangement, and the stage draws it.
    let behind = content.windows.filter { $0.windowLayer < 0 && $0.owningApplication?.processID != own }
    let displays = content.displays.map { (id: ScreenGeometry.displayID(for: $0.displayID), display: $0) }
    desktops = desktops.filter { entry in displays.contains { $0.id == entry.key } }
    let known = Set(desktops.keys)
    for (id, display) in displays where !known.contains(id) {
      guard let image = await desktop(on: display, id: id, behind: behind) else { continue }
      guard epoch == self.epoch else { return }
      desktops[id] = image
    }

    let scale = min(NSScreen.screens.map(\.backingScaleFactor).max() ?? 1, 2)
    let missing = listed.keys.filter { pictures[$0] == nil && !first.contains($0) }.sorted()
    var taken = 0
    for id in (first + missing).prefix(Self.mostPerSweep) {
      guard let window = listed[id], let image = await picture(of: window, scale: scale) else { continue }
      guard epoch == self.epoch else { return }
      pictures[id] = image
      taken += 1
      onPicture?(id, image)
    }

    for (id, display) in displays where known.contains(id) {
      guard let image = await desktop(on: display, id: id, behind: behind) else { continue }
      guard epoch == self.epoch else { return }
      desktops[id] = image
    }
    let milliseconds = Int((ProcessInfo.processInfo.systemUptime - started) * 1000)
    Log.debug(
      "pictures: took \(taken) of \(listed.count) windows (\(first.count) asked for) and \(displays.count) desktop(s) "
        + "from \(behind.count) windows behind, in \(milliseconds) ms")
  }

  private func picture(of window: SCWindow, scale: CGFloat) async -> CGImage? {
    let size = window.frame.size
    let factor = min(scale, (Self.mostPixels / (size.width * size.height)).squareRoot())
    let configuration = SCStreamConfiguration()
    configuration.width = max(Int(size.width * factor), 1)
    configuration.height = max(Int(size.height * factor), 1)
    configuration.scalesToFit = true
    configuration.showsCursor = false
    // The picture is stretched over the window's frame, so it must hold the window and nothing else.
    configuration.ignoreShadowsSingleWindow = true
    configuration.backgroundColor = Self.noBackground
    return try? await SCScreenshotManager.captureImage(
      contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration)
  }

  /// Everything below the level of normal windows on one display.
  private func desktop(on display: SCDisplay, id: DisplayID, behind: [SCWindow]) async -> CGImage? {
    // With nothing to draw the picture would be black, which is worse than the wallpaper's file.
    guard !behind.isEmpty else { return nil }
    let scale = ScreenGeometry.screen(for: id)?.backingScaleFactor ?? 1
    let configuration = SCStreamConfiguration()
    configuration.width = max(Int(CGFloat(display.width) * scale), 1)
    configuration.height = max(Int(CGFloat(display.height) * scale), 1)
    configuration.showsCursor = false
    return try? await SCScreenshotManager.captureImage(
      contentFilter: SCContentFilter(display: display, including: behind), configuration: configuration)
  }

  // MARK: The wallpaper's file

  /// The file macOS says is the display's wallpaper, scaled down to the display. It can differ from
  /// what is on screen (a wallpaper that changes with the time of day, a video, a folder of
  /// pictures), and it has no icons or widgets, so a picture of the desktop is preferred.
  private func wallpaper(of display: DisplayID) -> CGImage? {
    guard let screen = ScreenGeometry.screen(for: display),
      let url = NSWorkspace.shared.desktopImageURL(for: screen)
    else { return nil }
    let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    let key = "\(url.path) \(dark ? "dark" : "light")"
    if let cached = wallpapers[key] { return cached }
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let count = CGImageSourceGetCount(source)
    guard count > 0 else { return nil }
    // Apple's light-and-dark wallpapers are one file holding the light picture, then the dark one.
    let index = count == 2 && dark ? 1 : 0
    let options: [CFString: Any] = [
      kCGImageSourceCreateThumbnailFromImageAlways: true,
      kCGImageSourceCreateThumbnailWithTransform: true,
      kCGImageSourceThumbnailMaxPixelSize: Int(max(screen.frame.width, screen.frame.height) * screen.backingScaleFactor),
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, index, options as CFDictionary) else { return nil }
    if wallpapers.count >= 4 { wallpapers.removeAll() }
    wallpapers[key] = image
    return image
  }
}
