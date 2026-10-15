import AppKit
import ArborCore
import CoreGraphics

/// Draws Arbor's own on-screen elements with borderless, non-activating panels.
@MainActor
public final class AppKitOverlays: OverlayPresenter {
  public weak var actions: (any OverlayActions)?

  private var previewPanel: OverlayPanel?
  /// Whether the preview is meant to be seen. The panel itself stays on screen while it fades out.
  private var previewIsShown = false
  /// Panels are kept when they go out of use and handed out again (`ReusePool` says why).
  private var tilePanels = ReusePool<TileKey, TilePanel>(sparesKept: 32)
  private var seamPanels = ReusePool<SeamKey, SeamPanel>(sparesKept: 32)
  /// The tiles and seams each display shows, whether the seams show their handles, and how many Space switches there had
  /// been when they were shown.
  private var shown: [DisplayID: (tiles: [TileModel], seams: [Seam], handles: Bool, spaceSwitches: Int)] = [:]
  /// A panel belongs to the Space it was shown on. After a switch everything is shown again, as it always was.
  private var spaceSwitches = 0
  private var spaceObserver: NSObjectProtocol?
  private let peekOutlines = PeekOutlines()
  private let focusRings = FocusRings()
  let backdrops = Backdrops()
  /// Plays transitions (AppKitOverlays+Motion.swift).
  let director = StageDirector()
  private let nameField = NameField()
  /// The palette of "Go to…", kept once made (FinderPanel.swift).
  var finderPanel: FinderPanel?
  /// The heads-up line and the panel of shortcuts (AppKitOverlays+HeadsUp.swift).
  var headsUpPanel: HeadsUpPanel?
  var cheatSheetPanel: CheatSheetPanel?

  private struct TileKey: Hashable {
    let display: DisplayID
    let node: NodeID
  }
  private let minimaps = Minimaps()

  private struct SeamKey: Hashable {
    let display: DisplayID
    let split: NodeID
    let leading: NodeID
    let trailing: NodeID
  }

  public init() {
    spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
    ) { [weak self] _ in
      MainActor.assumeIsolated { self?.spaceSwitches += 1 }
    }
  }

  /// The preview fades in where it appears, glides from one target to the next and fades out, each
  /// in `previewMotion` seconds. With "Reduce motion" on it only appears, jumps and disappears.
  public func showDropPreview(_ frame: CGRect?) {
    let animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    let wasShown = previewIsShown
    previewIsShown = frame != nil

    guard let frame else {
      guard wasShown, let panel = previewPanel else { return }
      guard animates else {
        panel.orderOut(nil)
        return
      }
      NSAnimationContext.runAnimationGroup(
        { context in
          context.duration = Self.previewMotion
          panel.animator().alphaValue = 0
        },
        completionHandler: { [weak self] in
          MainActor.assumeIsolated {
            // Unless it was asked for again while it faded.
            guard let self, !self.previewIsShown else { return }
            self.previewPanel?.orderOut(nil)
          }
        })
      return
    }

    let panel = previewPanel ?? makePreviewPanel()
    previewPanel = panel
    let target = ScreenGeometry.appKit(fromGlobal: frame)
    guard animates else {
      panel.alphaValue = 1
      panel.setFrame(target, display: true)
      panel.orderFrontRegardless()
      return
    }
    if !panel.isVisible {
      panel.alphaValue = 0
      panel.setFrame(target, display: true)
      panel.orderFrontRegardless()
    }
    // Through the animator even when it should not glide (it is fading out somewhere else), so
    // that this move replaces one still under way instead of being overtaken by it.
    NSAnimationContext.runAnimationGroup { context in
      context.duration = wasShown ? Self.previewMotion : 0
      panel.animator().setFrame(target, display: true)
    }
    NSAnimationContext.runAnimationGroup { context in
      context.duration = Self.previewMotion
      panel.animator().alphaValue = 1
    }
  }

  static let previewMotion = 0.12

  public func update(display: DisplayID, scene: OverlayScene) {
    showTilesAndSeams(of: scene, on: display)
    peekOutlines.update(display: display, frame: scene.peekOutline) { [weak self] in
      self?.actions?.peekOutlineClicked(display: display)
    }
    focusRings.update(display: display, model: scene.focusRing)
    nameField.update(display: display, model: scene.namePrompt, actions: actions)
    backdrops.update(display: display, model: scene.backdrop)
    director.surfaceChanged(scene.backdrop, on: display)
  }

  private func showTilesAndSeams(of scene: OverlayScene, on display: DisplayID) {
    // Most layouts leave them as they are, and every panel touched is a call to the window server.
    let again = shown[display]?.spaceSwitches != spaceSwitches
    if !again, let shown = shown[display], shown.tiles == scene.tiles, shown.seams == scene.seams,
      shown.handles == scene.showsSeamHandles
    {
      return
    }
    shown[display] = (scene.tiles, scene.seams, scene.showsSeamHandles, spaceSwitches)

    let tileKeys = scene.tiles.map { TileKey(display: display, node: $0.node) }
    let tileChange = tilePanels.use(tileKeys, replacing: { $0.display == display }, make: { TilePanel() })
    tileChange.retired.forEach { $0.leave(fade: scene.tileFade) }
    tileChange.discarded.forEach { $0.close() }
    for (key, model) in zip(tileKeys, scene.tiles) {
      guard let panel = tilePanels.inUse[key] else { continue }
      panel.onActivate = { [weak self] in self?.actions?.tileActivated(display: display, node: model.node) }
      panel.show(model, fade: scene.tileFade, again: again)
    }

    let seams = scene.seams.filter { $0.frame.width >= 2 && $0.frame.height >= 2 }
    let seamKeys = seams.map { SeamKey(display: display, split: $0.split, leading: $0.leading, trailing: $0.trailing) }
    let seamChange = seamPanels.use(seamKeys, replacing: { $0.display == display }, make: { SeamPanel() })
    seamChange.retired.forEach { $0.orderOut(nil) }
    seamChange.discarded.forEach { $0.close() }
    for (key, seam) in zip(seamKeys, seams) {
      guard let panel = seamPanels.inUse[key] else { continue }
      panel.onDrag = { [weak self] seam, delta in self?.actions?.seamDragged(display: display, seam: seam, by: delta) }
      panel.show(seam, showsHandle: scene.showsSeamHandles, again: again)
    }
  }

  public func removeAll() {
    previewPanel?.close()
    previewPanel = nil
    previewIsShown = false
    tilePanels.removeAll().forEach { $0.close() }
    seamPanels.removeAll().forEach { $0.close() }
    shown.removeAll()
    peekOutlines.removeAll()
    focusRings.removeAll()
    backdrops.removeAll()
    director.stop()
    nameField.removeAll()
    finderPanel?.dismiss()
    finderPanel?.close()
    finderPanel = nil
    removeHeadsUp()
    minimaps.removeAll()
  }

  public func showMinimap(_ model: MinimapModel?, on display: DisplayID) {
    minimaps.onClick = { [weak self] display, point in self?.actions?.minimapClicked(display: display, at: point) }
    minimaps.show(model, on: display)
  }

  private func makePreviewPanel() -> OverlayPanel {
    let panel = OverlayPanel()
    panel.level = .floating
    panel.ignoresMouseEvents = true
    panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
    let view = PreviewView()
    panel.contentView = view
    return panel
  }
}

/// A borderless panel that never takes focus.
class OverlayPanel: NSPanel {
  init() {
    super.init(
      contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    isOpaque = false
    backgroundColor = .clear
    hasShadow = false
    hidesOnDeactivate = false
    isReleasedWhenClosed = false
    animationBehavior = .none
    // Transient: hidden in Mission Control. A stationary tile stayed where it was, over the windows' miniatures.
    collectionBehavior = [.ignoresCycle, .transient]
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }

  /// AppKit keeps windows from reaching under the menu bar, borderless panels at the normal level too: the focus
  /// ring's, whose margin does reach there around a window at the top of the screen, was pushed down and off its
  /// window. An overlay goes where its model says.
  override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

  /// Puts the panel on screen behind every other window of its level, or sends it back there. For panels that stand where
  /// no docked window is: tiles and gap handles. Whatever else lies there (a floating or pinned window, a window
  /// Arbor does not arrange) was put there by somebody and stays in front, in view and within reach of the mouse. In front
  /// of it a tile would hide it, and a gap handle, which cannot even be seen, would take a strip of its clicks.
  func orderInBehind() {
    order(.below, relativeTo: 0)
  }
}

private final class PreviewView: NSView {
  /// The shape of the tile or window that would land here, in the accent colour.
  override func draw(_ dirtyRect: NSRect) {
    AccentInk.mark(bounds, radius: ContinuousCorners.windowRadius, fill: 0.18, width: 2)
  }
}

// MARK: Tiles

/// A node too small to show its windows: the app colour, icon and name.
/// Clicking zooms onto it.
final class TilePanel: OverlayPanel {
  var onActivate: (() -> Void)?
  private let tileView = TileView()
  /// Fading out, on its way off the screen.
  private var isLeaving = false
  /// Counts the times it has left, so that the end of an earlier fade is not taken for the end of this one.
  private var departures = 0

  override init() {
    super.init()
    level = .normal
    // Arbor is never the active app, and help tags are for the active app's windows unless a window says otherwise.
    allowsToolTipsWhenApplicationIsInactive = true
    contentView = tileView
    tileView.onClick = { [weak self] in self?.onActivate?() }
  }

  /// A tile that was not on screen fades in over `fade` seconds. With `again`, it is shown also when it shows this very
  /// model already.
  func show(_ model: TileModel, fade: TimeInterval, again: Bool) {
    // Moving, redrawing and reordering a panel are calls to the window server; most tiles outlast most layouts.
    if !again, isVisible, !isLeaving, tileView.model == model { return }
    // The same tile in the same place, of the same kind: what has changed is drawn inside it. A terminal gives its window
    // a new title at every command, and that is nothing the window server need hear of.
    if !again, isVisible, !isLeaving, let old = tileView.model, old.node == model.node, old.frame == model.frame,
      old.kind == model.kind
    {
      tileView.model = model
      // Taken away first: a tag that is up shows the words it came up with, and they may be a title that has to go.
      if old.helpTag != model.helpTag { tileView.toolTip = nil }
      tileView.toolTip = model.helpTag
      tileView.needsDisplay = true
      return
    }
    // A panel handed over from another tile is a new tile to the eye, wherever it was a moment ago.
    let isSameTile = isVisible && tileView.model?.node == model.node
    let isNew = !isSameTile || isLeaving
    isLeaving = false
    ignoresMouseEvents = false
    tileView.model = model
    tileView.toolTip = model.helpTag
    tileView.needsDisplay = true
    setFrame(ScreenGeometry.appKit(fromGlobal: model.frame), display: true)
    // The window server shapes the shadow after what was last drawn.
    hasShadow = TileDrawing.art(for: model, in: tileView).castsShadow
    invalidateShadow()
    guard isNew, fade > 0 else {
      setAlphaAtOnce(1)
      orderInBehind()
      return
    }
    // One that was on its way out comes back from however faint it is by now.
    if !isSameTile { setAlphaAtOnce(0) }
    orderInBehind()
    NSAnimationContext.runAnimationGroup { context in
      context.duration = fade
      animator().alphaValue = 1
    }
  }

  /// Fades out over `fade` seconds and leaves the screen. What takes the tile's place is under it already, so from now
  /// on clicks are meant for that. The panel may be handed out again (`show`) before it has faded.
  func leave(fade: TimeInterval) {
    onActivate = nil
    departures += 1
    guard fade > 0, isVisible else {
      isLeaving = false
      setAlphaAtOnce(1)
      orderOut(nil)
      return
    }
    isLeaving = true
    ignoresMouseEvents = true
    let departure = departures
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = fade
        animator().alphaValue = 0
      },
      completionHandler: { [weak self] in
        MainActor.assumeIsolated {
          // Unless it was asked for again while it faded, even if it has left once more since.
          guard let self, self.isLeaving, self.departures == departure else { return }
          self.isLeaving = false
          self.orderOut(nil)
        }
      })
  }

  /// Through the animator: a plain assignment would be overwritten by the next step of a fade still under way.
  private func setAlphaAtOnce(_ alpha: CGFloat) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0
      animator().alphaValue = alpha
    }
  }
}

private final class TileView: NSView {
  var model: TileModel?
  var onClick: (() -> Void)?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
  override func mouseUp(with event: NSEvent) { onClick?() }

  /// `TileArt` counts y downward.
  override var isFlipped: Bool { true }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    needsDisplay = true
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let model else { return }
    TileDrawing.draw(TileDrawing.art(for: model, in: self))
  }
}

// MARK: Seams

/// A handle in the gap between two docked windows. Dragging it resizes both.
final class SeamPanel: OverlayPanel {
  var onDrag: ((Seam, CGFloat) -> Void)?
  private let seamView = SeamView()

  override init() {
    super.init()
    level = .normal
    // The handle draws nothing at rest, and the window server lets clicks fall through a window's transparent
    // parts unless the window has said that it wants them.
    ignoresMouseEvents = false
    contentView = seamView
    seamView.onDrag = { [weak self] delta in
      guard let self, let seam = self.seamView.seam else { return }
      self.onDrag?(seam, delta)
    }
  }

  /// With `again`, also when it shows this very seam already.
  func show(_ seam: Seam, showsHandle: Bool, again: Bool) {
    seamView.showsHandle = showsHandle
    if !again, isVisible, seamView.seam == seam { return }
    // It may have been put away, or handed over from another gap, in the middle of a drag.
    if let old = seamView.seam,
      !isVisible || old.split != seam.split || old.leading != seam.leading || old.trailing != seam.trailing
    {
      seamView.forgetDrag()
    }
    seamView.seam = seam
    setFrame(ScreenGeometry.appKit(fromGlobal: seam.frame), display: false)
    orderInBehind()
  }
}

private final class SeamView: NSView {
  var seam: Seam? {
    didSet { cursor = seam?.axis == .vertical ? .resizeUpDown : .resizeLeftRight }
  }
  var onDrag: ((CGFloat) -> Void)?
  /// Whether a pill shows in the middle of the seam while the pointer is over it or dragging it.
  var showsHandle = true {
    didSet { if showsHandle != oldValue { needsDisplay = true } }
  }
  private var cursor: NSCursor = .resizeLeftRight
  private var lastLocation: NSPoint? {
    didSet { if (lastLocation == nil) != (oldValue == nil) { needsDisplay = true } }
  }
  private var isHovered = false {
    didSet { if isHovered != oldValue { needsDisplay = true } }
  }
  private var trackingArea: NSTrackingArea?

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

  override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea { removeTrackingArea(trackingArea) }
    let area = NSTrackingArea(
      rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
    addTrackingArea(area)
    trackingArea = area
  }

  override func mouseEntered(with event: NSEvent) {
    isHovered = true
    cursor.set()
  }

  override func mouseExited(with event: NSEvent) {
    isHovered = false
    if lastLocation == nil { NSCursor.arrow.set() }
  }

  override func mouseDown(with event: NSEvent) {
    lastLocation = NSEvent.mouseLocation
    cursor.set()
  }

  override func mouseDragged(with event: NSEvent) {
    guard let last = lastLocation, let seam else { return }
    let now = NSEvent.mouseLocation
    // AppKit y grows upward; Arbor's grows downward.
    let delta = seam.axis == .horizontal ? now.x - last.x : last.y - now.y
    lastLocation = now
    if delta != 0 { onDrag?(delta) }
  }

  override func mouseUp(with event: NSEvent) {
    lastLocation = nil
  }

  /// Nothing at rest; a pill under the pointer; the pill in the accent colour while it is dragged. The gap
  /// shows the wallpaper, which has nothing to do with light or dark mode, so like the labels of icons on
  /// the Desktop the pill is white with a soft shadow: that shows on any picture.
  override func draw(_ dirtyRect: NSRect) {
    let isDragged = lastLocation != nil
    guard showsHandle, isHovered || isDragged, let seam, let pill = SeamHandle.pill(in: bounds, axis: seam.axis)
    else { return }
    TileDrawing.softShadow(RGBA.black.withAlpha(0.45)).set()
    (isDragged ? NSColor.controlAccentColor : NSColor.white.withAlphaComponent(0.9)).setFill()
    NSBezierPath.make(RoundedPath.capsule(pill)).fill()
  }

  /// The panel was put away or handed over: nothing tells it that the pointer is no longer over it.
  func forgetDrag() {
    lastLocation = nil
    isHovered = false
  }
}

// MARK: App appearance

@MainActor
enum AppAppearance {
  private static var colours: [String: RGBA] = [:]

  static func icon(pid: Int32) -> NSImage? {
    NSRunningApplication(processIdentifier: pid)?.icon
  }

  /// The colour of the app's icon as a plain fill, darkened a little so white captions stay readable.
  static func colour(pid: Int32, bundleID: String?) -> NSColor {
    rgba(pid: pid, bundleID: bundleID).map(fill) ?? .systemGray
  }

  static func fill(_ colour: RGBA) -> NSColor { colour.mixed(with: .black, amount: 0.25).nsColor }

  /// A colour that was worked out elsewhere (`Wardrobe`), so that nobody here has to wait for the icon.
  static func remember(_ colour: RGBA, pid: Int32, bundleID: String?) { colours[key(pid: pid, bundleID: bundleID)] = colour }

  /// What an app's colour and cover are kept under.
  static func key(pid: Int32, bundleID: String?) -> String { bundleID ?? "pid-\(pid)" }

  /// The colour the app's icon is recognised by (`IconColour`), which tints its tiles. Nil without an icon.
  static func rgba(pid: Int32, bundleID: String?) -> RGBA? {
    let key = key(pid: pid, bundleID: bundleID)
    if let cached = colours[key] { return cached }
    guard let icon = icon(pid: pid), let colour = colour(of: icon) else { return nil }
    colours[key] = colour
    return colour
  }

  /// On any thread, like `samples`: they touch nothing but the icon and a bitmap of their own.
  nonisolated static func colour(of icon: NSImage) -> RGBA? { IconColour.dominant(of: samples(of: icon)) }

  /// The icon's pixels at a size where its large shapes are left and its details are not, in sRGB like every `RGBA`.
  nonisolated private static func samples(of icon: NSImage) -> [RGBA] {
    let side = 24
    guard let space = CGColorSpace(name: CGColorSpace.sRGB),
      let bitmap = CGContext(
        data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4, space: space,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return [] }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
    NSGraphicsContext.current?.imageInterpolation = .high
    icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
    NSGraphicsContext.restoreGraphicsState()

    // Straight from the bytes (red, green, blue, alpha; colours multiplied by alpha): asking an image for 576
    // colour objects takes milliseconds, and this runs while a tile waits to be drawn.
    guard let bytes = bitmap.data?.assumingMemoryBound(to: UInt8.self) else { return [] }
    var samples: [RGBA] = []
    for pixel in 0..<(side * side) where bytes[pixel * 4 + 3] > 0 {
      let alpha = Double(bytes[pixel * 4 + 3])
      samples.append(
        RGBA(
          red: Double(bytes[pixel * 4]) / alpha, green: Double(bytes[pixel * 4 + 1]) / alpha,
          blue: Double(bytes[pixel * 4 + 2]) / alpha, alpha: alpha / 255))
    }
    return samples
  }
}
