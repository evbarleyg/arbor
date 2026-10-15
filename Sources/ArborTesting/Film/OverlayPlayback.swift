import ArborCore
import ArborKit
import CoreGraphics

/// Arbor's overlays without a screen, in time: what `AppKitOverlays` and its panels (ArborKit/UI, macOS only) show at any
/// moment, fades and glides included. `FakeOverlays` records what the controller last asked for; this hears the same calls,
/// notes when each came, and answers "what is on screen now?" the way the panels would.
///
/// The durations are the panels' own, repeated here because that code does not build without AppKit.
/// `StageTimingTests` holds the two against each other on a Mac. "Reduce motion" is taken to be off.
@MainActor
public final class OverlayPlayback {
  /// `AppKitOverlays.previewMotion`.
  public nonisolated static let previewMotion = 0.12
  /// `PassingPanel.fadeIn` and `fadeOut`: the heads-up line and the panel of shortcuts. `MinimapPanel` has the same numbers of its own.
  public nonisolated static let passingFadeIn = 0.1
  public nonisolated static let passingFadeOut = 0.25
  /// `BackdropLayer.fade`.
  public nonisolated static let backdropFade = 0.15

  /// Something that is shown as it is, more or less opaque.
  public struct Shown<Model: Equatable>: Equatable {
    public var model: Model
    public var opacity: Double
  }

  /// A panel that fades in, shows a model and fades out, still showing it.
  private struct Passing<Model: Equatable> {
    var model: Model?
    var opacity = Ramp(0)

    mutating func show(_ new: Model?, at now: Double, outAtOnce: Bool = false) {
      if let new {
        model = new
        opacity = opacity.turned(to: 1, at: now, over: OverlayPlayback.passingFadeIn)
      } else if opacity.to != 0 {
        opacity = outAtOnce ? Ramp(0) : opacity.turned(to: 0, at: now, over: OverlayPlayback.passingFadeOut)
      }
    }

    func shown(at now: Double) -> Shown<Model>? {
      let value = opacity.value(at: now)
      return value > 0 ? model.map { Shown(model: $0, opacity: value) } : nil
    }
  }

  private struct Tile {
    var model: TileModel
    var opacity: Ramp
  }

  private let clock: () -> Double
  private var stages: [DisplayID: StagePlayback] = [:]
  private var preview: (frame: RectRamp, opacity: Ramp)?
  private var tiles: [DisplayID: [NodeID: Tile]] = [:]
  /// The tiles each display was last asked to show.
  private var tilesAsked: [DisplayID: [TileModel]] = [:]
  private var backdrops: [DisplayID: (before: BackdropModel?, now: BackdropModel?, fade: Ramp, changed: Double)] = [:]
  private var headsUp = Passing<HeadsUpModel>()
  private var cheatSheet = Passing<CheatSheetModel>()
  private var minimaps: [DisplayID: Passing<MinimapModel>] = [:]
  /// The pulse last drawn, on whichever display, and when the flash it set off began (`FocusRings`).
  private var lastPulse = 0
  private var flashBegan: Double?
  /// Of which windows there would be a picture to move in place of the cover. None, as long as `windowPictures` is off.
  public var hasPicture: (WindowID) -> Bool = { _ in false }

  /// Listens to `overlays` from now on. `clock` tells the time, in seconds: `ManualScheduler.now`.
  public init(_ overlays: FakeOverlays, clock: @escaping () -> Double) {
    self.clock = clock
    overlays.onCall = { [weak self] in self?.hear($0) }
  }

  private func hear(_ call: FakeOverlays.Call) {
    let now = clock()
    switch call {
    case .dropPreview(let frame): showPreview(frame, at: now)
    case .update(let display, let scene): update(display, scene, at: now)
    case .animate(let transition): animate(transition, at: now)
    case .finishAnimations: for display in stages.keys { stages[display]?.drop() }
    case .headsUp(let model, _): headsUp.show(model, at: now)
    // `CheatSheetPanel.hide`: at once, because while it faded it would still have the keyboard.
    case .cheatSheet(let model, _): cheatSheet.show(model, at: now, outAtOnce: true)
    case .minimap(let model, let display): minimaps[display, default: Passing()].show(model, at: now)
    case .removeAll:
      // Every panel is closed, not faded.
      stages.removeAll()
      preview = nil
      tiles.removeAll()
      tilesAsked.removeAll()
      backdrops.removeAll()
      headsUp = Passing()
      cheatSheet = Passing()
      minimaps.removeAll()
      (lastPulse, flashBegan) = (0, nil)
    }
  }

  // MARK: What the panels do

  /// `AppKitOverlays.showDropPreview`: it fades in where it appears, glides from one target to the next and fades out.
  private func showPreview(_ frame: CGRect?, at now: Double) {
    guard let frame else {
      if let shown = preview, shown.opacity.to != 0 {
        preview?.opacity = shown.opacity.turned(to: 0, at: now, over: Self.previewMotion)
      }
      return
    }
    let onScreen = preview.map { $0.opacity.value(at: now) > 0 || !$0.opacity.isOver(at: now) } ?? false
    let wasWanted = preview.map { $0.opacity.to != 0 } ?? false
    let place =
      onScreen && wasWanted
      ? RectRamp(
        from: preview!.frame.value(at: now), to: frame, start: now, duration: Self.previewMotion, curve: .systemDefault)
      : RectRamp(frame)
    let opacity = (onScreen ? preview!.opacity : Ramp(0)).turned(to: 1, at: now, over: Self.previewMotion)
    preview = (place, opacity)
  }

  private func update(_ display: DisplayID, _ scene: OverlayScene, at now: Double) {
    // `showTilesAndSeams`: most layouts leave the tiles as they are, and then nothing is touched. `TilePanel.show` and `leave`: a tile that
    // was not there fades in, one that was leaving comes back from however faint it is, one that only changed is there at once.
    if scene.tiles != tilesAsked[display] ?? [] {
      tilesAsked[display] = scene.tiles
      var shown = (tiles[display] ?? [:]).filter { $0.value.opacity.to != 0 || !$0.value.opacity.isOver(at: now) }
      let wanted = Set(scene.tiles.map(\.node))
      for (node, tile) in shown where !wanted.contains(node) && tile.opacity.to != 0 {
        shown[node]?.opacity = tile.opacity.turned(to: 0, at: now, over: scene.tileFade)
      }
      for model in scene.tiles {
        if let old = shown[model.node], old.opacity.to != 0 {
          shown[model.node] = Tile(model: model, opacity: old.model == model ? old.opacity : Ramp(1))
        } else {
          shown[model.node] = Tile(
            model: model, opacity: (shown[model.node]?.opacity ?? Ramp(0)).turned(to: 1, at: now, over: scene.tileFade))
        }
      }
      tiles[display] = shown
    }

    // `BackdropPanel.show`, `hide` and `fade`: one shape cross-fades into the next, unless the last change was a moment ago (a drag).
    let old = backdrops[display]
    if scene.backdrop != old?.now {
      let fades = now - (old?.changed ?? -.infinity) > Self.backdropFade
      backdrops[display] = (
        old?.now, scene.backdrop, fades ? Ramp(from: 0, to: 1, start: now, duration: Self.backdropFade, curve: .linear) : Ramp(1), now
      )
    }
    stages[display]?.show(surface: scene.backdrop, at: now)

    // `FocusRings.update`.
    if let ring = scene.focusRing {
      if ring.pulse != lastPulse { flashBegan = now }
      lastPulse = ring.pulse
    }
  }

  /// `StageDirector.play`.
  private func animate(_ transition: Transition, at now: Double) {
    guard transition.duration > 0, transition.frame.isFinite, transition.frame.width >= 1, transition.frame.height >= 1
    else {
      for display in stages.keys { stages[display]?.drop() }
      return
    }
    stages[transition.display, default: StagePlayback()].play(
      transition, at: now, surface: backdrops[transition.display]?.now, hasPicture: hasPicture)
  }

  // MARK: What is on screen now

  public func stage(on display: DisplayID) -> StagePlayback.Picture? { stages[display]?.picture(at: clock()) }

  public var dropPreview: Shown<CGRect>? {
    guard let preview else { return nil }
    let opacity = preview.opacity.value(at: clock())
    return opacity > 0 ? Shown(model: preview.frame.value(at: clock()), opacity: opacity) : nil
  }

  /// In the order of their nodes' numbers, those on their way out included.
  public func tiles(on display: DisplayID) -> [Shown<TileModel>] {
    (tiles[display] ?? [:]).sorted { $0.key < $1.key }.compactMap { _, tile in
      let opacity = tile.opacity.value(at: clock())
      return opacity > 0 ? Shown(model: tile.model, opacity: opacity) : nil
    }
  }

  /// The surface behind docked windows: one shape, or two while one fades into the other.
  public func backdrops(on display: DisplayID) -> [Shown<BackdropModel>] {
    guard let (before, now, fade, _) = backdrops[display] else { return [] }
    let share = fade.value(at: clock())
    var shown: [Shown<BackdropModel>] = []
    if let before, share < 1 { shown.append(Shown(model: before, opacity: 1 - share)) }
    if let now, share > 0 { shown.append(Shown(model: now, opacity: share)) }
    return shown
  }

  /// How strong the focus ring's flash is: 1 when the ring has just been moved by Arbor, 0 a quarter of a second later.
  public var flash: Double {
    guard let flashBegan else { return 0 }
    return Ramp(from: 1, to: 0, start: flashBegan, duration: FocusRingModel.pulseDuration, curve: .easeIn).value(at: clock())
  }

  public var headsUpLine: Shown<HeadsUpModel>? { headsUp.shown(at: clock()) }
  public var shortcutsPanel: Shown<CheatSheetModel>? { cheatSheet.shown(at: clock()) }
  public func minimap(on display: DisplayID) -> Shown<MinimapModel>? { minimaps[display]?.shown(at: clock()) }
}
