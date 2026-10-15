import AppKit
import ArborCore
import QuartzCore

/// What a stand-in is drawn from.
struct Costume {
  /// A still picture of the window, if Arbor has one.
  var picture: CGImage?
  /// The app's colour and icon, for the cover. Nil if the cover will not be seen.
  var colour: CGColor?
  var icon: CGImage?
}

/// One display's stage: a panel that covers the whole display while something moves on it.
///
/// It draws a picture of the desktop and, on top, one stand-in per window. The real windows go
/// straight to their final frames underneath, where nobody sees them jump; Core Animation moves the
/// stand-ins in the render server, so the motion stays smooth while the main thread waits on apps.
///
/// A stage that stayed up would hide the user's windows from them. So every way of ending leads to
/// `drop()`, which cannot fail, and two independent things end a motion: a timer and Core
/// Animation's completion block. `StageDirector` adds clicks, sleep, and Space and display changes.
@MainActor
final class Stage {
  /// How long lifting the stage takes. A short fade hides small differences between the stand-ins
  /// and the real windows.
  static let liftDuration: TimeInterval = 0.08
  /// Shown behind the windows when there is no picture of the desktop. Never clear: the real windows
  /// jumping about underneath would show.
  static let fallbackBackdrop = NSColor(calibratedWhite: 0.12, alpha: 1).cgColor

  /// Called whenever the stage has come down.
  var onDown: (() -> Void)?
  /// Writes down what the stage shows, while a trace is recorded.
  var sampler: StageSampler?
  private(set) var isUp = false

  private let panel = StagePanel()
  /// Holds everything that is drawn. Fading it out lifts the stage.
  private let canvas = CALayer()
  private let backdrop = CALayer()
  /// What darkens the wallpaper behind docked windows (F15), between the picture of the desktop, which is taken without
  /// it, and the windows. The stage covers the panel that draws it at rest.
  private let surface = BackdropLayer()
  private var surfaceShown: BackdropModel?
  /// How long the motion that is playing takes.
  private var duration: TimeInterval = 0
  private var standIns: [WindowID: StandIn] = [:]
  /// The display's frame, in global coordinates.
  private var frame = CGRect.zero
  /// Counts motions, so that the completion block and the timers of an earlier one do nothing.
  private var generation = 0
  private var timer: Timer?

  init() {
    // A view that is given its layer before `wantsLayer` is set hosts it: AppKit leaves the sublayers alone.
    let view = NSView(frame: .zero)
    let root = CALayer()
    view.layer = root
    view.wantsLayer = true
    panel.contentView = view
    root.addSublayer(canvas)
    backdrop.backgroundColor = Self.fallbackBackdrop
    backdrop.contentsGravity = .resizeAspectFill
    backdrop.masksToBounds = true
    backdrop.zPosition = -1
    canvas.addSublayer(backdrop)
    surface.layer.zPosition = -0.5
    canvas.addSublayer(surface.layer)
  }

  /// Covers the display and starts the motion. When this returns the window server has been told
  /// to show the stage, so the caller can move the real windows. If the stage is up already,
  /// stand-ins carry on from where they are now. `atRest` is the surface behind docked windows as the display shows it.
  func play(
    _ transition: Transition, costumes: [WindowID: Costume], backdrop desktop: CGImage?, surface atRest: BackdropModel?
  ) {
    generation += 1
    let generation = self.generation
    timer?.invalidate()
    frame = transition.frame
    duration = transition.duration
    // Core Animation raises an exception for a frame that is not finite.
    let items = transition.items.filter { $0.from.isFinite && $0.to.isFinite }
    let cast = Set(items.map(\.window))

    // First everything where it is now, without animation, and up with the stage.
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    panel.setFrame(ScreenGeometry.appKit(fromGlobal: frame), display: false)
    canvas.removeAllAnimations()
    canvas.opacity = 1
    canvas.frame = CGRect(origin: .zero, size: frame.size)
    backdrop.frame = canvas.bounds
    backdrop.contents = desktop
    if !isUp {
      surface.show(atRest, in: frame, fade: 0)
      surfaceShown = atRest
    }
    for (index, item) in items.enumerated() {
      let standIn: StandIn
      if let onStage = standIns[item.window] {
        standIn = onStage
        standIn.freeze()
        if let costume = costumes[item.window] { standIn.wear(costume) }
      } else {
        standIn = StandIn()
        // Dressed first: whether it can show as itself depends on having a picture.
        if let costume = costumes[item.window] { standIn.wear(costume) }
        standIn.place(local(item.from))
        standIn.show(item.fromLook, opacity: item.fromOpacity)
        canvas.addSublayer(standIn.layer)
        standIns[item.window] = standIn
      }
      standIn.layer.zPosition = CGFloat(index)
    }
    for (window, standIn) in standIns where !cast.contains(window) { standIn.freeze() }
    CATransaction.commit()
    panel.orderFrontRegardless()
    surface.match(scale: panel.backingScaleFactor)
    CATransaction.flush()
    let wasUp = isUp
    isUp = true

    // Then on their way.
    let curve = Transition.curve
    let timing = CAMediaTimingFunction(
      controlPoints: Float(curve.x1), Float(curve.y1), Float(curve.x2), Float(curve.y2))
    CATransaction.begin()
    // Said out loud, in case the caller is inside a transaction that switched them off.
    CATransaction.setDisableActions(false)
    CATransaction.setAnimationDuration(transition.duration)
    CATransaction.setAnimationTimingFunction(timing)
    CATransaction.setCompletionBlock { [weak self] in
      MainActor.assumeIsolated { self?.lift(generation) }
    }
    for item in items {
      guard let standIn = standIns[item.window] else { continue }
      standIn.glide(to: local(item.to), duration: transition.duration, timing: timing)
      standIn.show(item.toLook, opacity: item.toOpacity)
    }
    // Windows that are no longer part of it (closed since) fade away where they are.
    for (window, standIn) in standIns where !cast.contains(window) { standIn.layer.opacity = 0 }
    CATransaction.commit()
    CATransaction.flush()

    // The timer usually comes first: the completion block was seen to arrive 0.15 s after the end
    // of the motion, which is 0.15 s of looking at pictures that have stopped moving.
    let timer = Timer(timeInterval: transition.duration, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated { self?.lift(generation) }
    }
    // Common modes, so that an open menu does not keep the stage up.
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
    sampler?.began(transition, retargeted: wasUp, layers: standIns.mapValues(\.layer))
    Log.debug("stage \(wasUp ? "retargeted" : "up") on \(transition.display): \(items.count) stand-ins, \(transition.duration) s")
  }

  /// The scene the motion ends in has arrived: the surface fades into its new shape while the windows travel, and is
  /// what the stage reveals when it lifts.
  func show(surface model: BackdropModel?) {
    guard isUp, model != surfaceShown else { return }
    surfaceShown = model
    surface.show(model, in: frame, fade: duration)
  }

  /// Swaps in a picture that has only just been taken.
  func show(_ picture: CGImage, of window: WindowID) {
    guard isUp, let standIn = standIns[window] else { return }
    CATransaction.begin()
    CATransaction.setAnimationDuration(0.1)
    standIn.wear(picture)
    CATransaction.commit()
  }

  /// The motion is over: fades the stage out and takes it down.
  private func lift(_ expected: Int) {
    guard isUp, expected == generation else { return }
    sampler?.lifting()
    generation += 1
    let generation = self.generation
    timer?.invalidate()
    CATransaction.begin()
    CATransaction.setAnimationDuration(Self.liftDuration)
    canvas.opacity = 0
    CATransaction.commit()
    let timer = Timer(timeInterval: Self.liftDuration, repeats: false) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, generation == self.generation else { return }
        self.drop()
      }
    }
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  /// Takes the stage down at once and lets go of the pictures.
  func drop() {
    generation += 1
    timer?.invalidate()
    timer = nil
    guard isUp else { return }
    sampler?.comingDown()
    isUp = false
    panel.orderOut(nil)
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    for standIn in standIns.values { standIn.layer.removeFromSuperlayer() }
    standIns.removeAll()
    backdrop.contents = nil
    surface.show(nil, in: frame, fade: 0)
    surfaceShown = nil
    canvas.removeAllAnimations()
    canvas.opacity = 1
    CATransaction.commit()
    Log.debug("stage down")
    onDown?()
  }

  private func local(_ rect: CGRect) -> CGRect { ScreenGeometry.local(fromGlobal: rect, in: frame) }
}

/// Above normal and floating windows and Arbor's own tiles, seams and previews; below the Dock and the
/// menu bar. Clicks go through it to the real windows.
private final class StagePanel: OverlayPanel {
  override init() {
    super.init()
    level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 1)
    ignoresMouseEvents = true
    // Not `.fullScreenAuxiliary`: a full-screen app is none of Arbor's business.
    collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
  }
}

/// The layers that stand for one window: its picture over its cover, and a shadow.
@MainActor
private final class StandIn {
  /// About what macOS gives its windows.
  static var cornerRadius: CGFloat {
    if #available(macOS 26.0, *) { return 16 }
    return 10
  }

  /// Moves and fades as a whole.
  let layer = CALayer()
  private let cover = CALayer()
  private let icon = CALayer()
  private let picture = CALayer()
  /// The look last asked for, which a picture that arrives late has to respect.
  private var look = Plane.Look.picture

  init() {
    layer.shadowColor = NSColor.black.cgColor
    layer.shadowOpacity = 0.3
    layer.shadowRadius = 14
    layer.shadowOffset = CGSize(width: 0, height: -6)
    cover.cornerRadius = Self.cornerRadius
    cover.borderWidth = 1
    cover.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
    icon.contentsGravity = .resizeAspect
    // Stand-ins scale by stretching, as TrellisWM's do.
    picture.contentsGravity = .resize
    picture.cornerRadius = Self.cornerRadius
    picture.masksToBounds = true
    cover.addSublayer(icon)
    layer.addSublayer(cover)
    layer.addSublayer(picture)
  }

  func wear(_ costume: Costume) {
    if let colour = costume.colour { cover.backgroundColor = colour }
    if let image = costume.icon { icon.contents = image }
    if let image = costume.picture { picture.contents = image }
  }

  /// A picture that arrived after the motion began. If there was none before, it takes the cover's
  /// place. Nothing else is touched: setting a property again would cut short a fade under way.
  func wear(_ image: CGImage) {
    picture.contents = image
    guard look == .picture, picture.opacity != 1 else { return }
    picture.opacity = 1
    cover.opacity = 0
  }

  /// `frame` is in the canvas's coordinates.
  func place(_ frame: CGRect) {
    let bounds = CGRect(origin: .zero, size: frame.size)
    layer.frame = frame
    // A plain rectangle: under this much blur nobody sees the corners, and a rounded one may not be
    // smaller than its corners.
    layer.shadowPath = CGPath(rect: bounds, transform: nil)
    cover.frame = bounds
    picture.frame = bounds
    let side = min(bounds.width, bounds.height) * 0.45
    icon.frame = CGRect(x: bounds.midX - side / 2, y: bounds.midY - side / 2, width: side, height: side)
  }

  /// `place` inside an animated transaction. Everything follows by itself except the shadow's path:
  /// paths are not animated implicitly.
  func glide(to frame: CGRect, duration: TimeInterval, timing: CAMediaTimingFunction) {
    let shadow = CABasicAnimation(keyPath: "shadowPath")
    shadow.fromValue = layer.shadowPath
    place(frame)
    shadow.toValue = layer.shadowPath
    shadow.duration = duration
    shadow.timingFunction = timing
    layer.add(shadow, forKey: "shadowPath")
  }

  /// Without a picture to show, a window looks like its cover.
  func show(_ look: Plane.Look, opacity: Double) {
    self.look = look
    let asItself = look == .picture && picture.contents != nil
    picture.opacity = asItself ? 1 : 0
    cover.opacity = asItself ? 0 : 1
    layer.opacity = Float(opacity)
  }

  /// Stops where it is on screen right now, so that the next motion starts from there.
  func freeze() {
    let frame = layer.presentation()?.frame ?? layer.frame
    let opacities = [layer, cover, picture].map { $0.presentation()?.opacity ?? $0.opacity }
    for each in [layer, cover, icon, picture] { each.removeAllAnimations() }
    if frame.isFinite { place(frame) }
    layer.opacity = opacities[0]
    cover.opacity = opacities[1]
    picture.opacity = opacities[2]
  }
}
