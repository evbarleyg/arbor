import ArborCore
import ArborKit
import CoreGraphics

/// A number on its way from one value to another.
struct Ramp: Equatable {
  var from: Double
  var to: Double
  var start: Double
  var duration: Double
  var curve = TimingCurve.systemDefault

  /// A number that stays as it is.
  init(_ value: Double) { (from, to, start, duration) = (value, value, 0, 0) }

  init(from: Double, to: Double, start: Double, duration: Double, curve: TimingCurve = .systemDefault) {
    (self.from, self.to, self.start, self.duration, self.curve) = (from, to, start, duration, curve)
  }

  func share(at now: Double) -> Double { duration > 0 ? curve.progress(at: (now - start) / duration) : 1 }
  func value(at now: Double) -> Double { from + (to - from) * share(at: now) }
  func isOver(at now: Double) -> Bool { now >= start + duration }

  /// Carries on from where it is now, as an animation does that replaces one under way.
  func turned(to target: Double, at now: Double, over duration: Double, curve: TimingCurve = .systemDefault) -> Ramp {
    Ramp(from: value(at: now), to: target, start: now, duration: duration, curve: curve)
  }
}

/// A rectangle on its way from one place to another. Each edge goes its own straight way, as a layer's frame does.
struct RectRamp: Equatable {
  var from: CGRect
  var to: CGRect
  var time: Ramp

  init(_ rect: CGRect) { (from, to, time) = (rect, rect, Ramp(1)) }

  init(from: CGRect, to: CGRect, start: Double, duration: Double, curve: TimingCurve) {
    (self.from, self.to) = (from, to)
    time = Ramp(from: 0, to: 1, start: start, duration: duration, curve: curve)
  }

  func value(at now: Double) -> CGRect {
    let share = CGFloat(time.value(at: now))
    func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * share }
    return CGRect(
      x: mix(from.minX, to.minX), y: mix(from.minY, to.minY), width: mix(from.width, to.width),
      height: mix(from.height, to.height))
  }
}

/// One display's stage without a screen: what `Stage` (ArborKit/UI, macOS only) has Core Animation show, worked out for any
/// moment. It is given the same transitions in the same order and keeps to the same rules:
///
/// - a window new to the stage starts at its item's `from`; one that is on it already carries on from where it is now;
/// - everything travels for the transition's `duration` on `Transition.curve`;
/// - a window that is no longer part of it fades away where it is;
/// - without a picture of itself a window shows its cover, the app's colour and icon, whatever look is asked for;
/// - when the time is up the whole stage fades for `liftDuration` and is gone.
///
/// `StageTimingTests` holds the numbers here against the real stage's on a Mac.
public struct StagePlayback: Equatable {
  /// `Stage.liftDuration`.
  public static let liftDuration = 0.08

  /// One window's stand-in at one moment.
  public struct StandIn: Equatable {
    public var window: WindowID
    /// Global coordinates.
    public var frame: CGRect
    public var opacity: Double
    /// How much of it is the cover and how much the picture. They cross-fade where the look changes.
    public var cover: Double
    public var picture: Double
    public var pid: Int32
    public var bundleID: String?
  }

  /// The surface behind docked windows, which fades from the shape the motion began with into the one it ends with.
  public struct Surface: Equatable {
    public var model: BackdropModel
    public var opacity: Double
  }

  /// What the stage shows at one moment.
  public struct Picture: Equatable {
    /// The display's frame, which the stage covers with a picture of the desktop.
    public var frame: CGRect
    /// Of all of it: below 1 while the stage lifts and the real windows show through.
    public var opacity: Double
    public var surfaces: [Surface]
    /// Back to front.
    public var standIns: [StandIn]
  }

  private struct Actor: Equatable {
    var frame: RectRamp
    var opacity: Ramp
    var cover: Ramp
    var picture: Ramp
    var depth: Int
    var pid: Int32
    var bundleID: String?
  }

  private var actors: [WindowID: Actor] = [:]
  private var frame = CGRect.zero
  private var duration = 0.0
  /// When the motion that is playing is over and the stage begins to lift. Nil while the stage is down.
  private var ends: Double?
  private var surfaceBefore: BackdropModel?
  private var surfaceNow: BackdropModel?
  private var surfaceFade = Ramp(1)

  public init() {}

  public func isUp(at now: Double) -> Bool { ends.map { now < $0 + Self.liftDuration } ?? false }

  /// `Stage.play`. `atRest` is the surface as the display shows it; `hasPicture` says of which windows there is a picture
  /// (none, unless `windowPictures` is on and macOS allows it).
  public mutating func play(
    _ transition: Transition, at now: Double, surface atRest: BackdropModel?,
    hasPicture: (WindowID) -> Bool = { _ in false }
  ) {
    if !isUp(at: now) {
      drop()
      (surfaceBefore, surfaceNow, surfaceFade) = (nil, atRest, Ramp(1))
    }
    frame = transition.frame
    duration = transition.duration
    ends = now + transition.duration
    let items = transition.items.filter { $0.from.isFinite && $0.to.isFinite }
    let cast = Set(items.map(\.window))

    func looks(_ look: Plane.Look, _ window: WindowID) -> (cover: Double, picture: Double) {
      look == .picture && hasPicture(window) ? (0, 1) : (1, 0)
    }
    for (index, item) in items.enumerated() {
      let (first, last) = (looks(item.fromLook, item.window), looks(item.toLook, item.window))
      let onStage = actors[item.window]
      func ramp(_ old: Ramp?, _ from: Double, _ to: Double) -> Ramp {
        Ramp(from: old?.value(at: now) ?? from, to: to, start: now, duration: duration, curve: .motion)
      }
      actors[item.window] = Actor(
        frame: RectRamp(
          from: onStage?.frame.value(at: now) ?? item.from, to: item.to, start: now, duration: duration, curve: .motion),
        opacity: ramp(onStage?.opacity, item.fromOpacity, item.toOpacity),
        cover: ramp(onStage?.cover, first.cover, last.cover), picture: ramp(onStage?.picture, first.picture, last.picture),
        depth: index, pid: item.pid, bundleID: item.bundleID)
    }
    for (window, actor) in actors where !cast.contains(window) {
      actors[window]?.frame = RectRamp(actor.frame.value(at: now))
      actors[window]?.cover = Ramp(actor.cover.value(at: now))
      actors[window]?.picture = Ramp(actor.picture.value(at: now))
      actors[window]?.opacity = actor.opacity.turned(to: 0, at: now, over: duration, curve: .motion)
    }
  }

  /// `Stage.show(surface:)`: the scene the motion ends in has arrived.
  public mutating func show(surface model: BackdropModel?, at now: Double) {
    guard isUp(at: now), model != surfaceNow else { return }
    (surfaceBefore, surfaceNow) = (surfaceNow, model)
    // A `CATransition` that is given no timing function runs evenly.
    surfaceFade = Ramp(from: 0, to: 1, start: now, duration: duration, curve: .linear)
  }

  /// `Stage.drop`: down at once.
  public mutating func drop() {
    actors.removeAll()
    ends = nil
    (surfaceBefore, surfaceNow, surfaceFade) = (nil, nil, Ramp(1))
  }

  /// Nil while the stage is down.
  public func picture(at now: Double) -> Picture? {
    guard let ends, isUp(at: now) else { return nil }
    let lift = Ramp(from: 1, to: 0, start: ends, duration: Self.liftDuration)
    let share = surfaceFade.value(at: now)
    var surfaces: [Surface] = []
    if let surfaceBefore, share < 1 { surfaces.append(Surface(model: surfaceBefore, opacity: 1 - share)) }
    if let surfaceNow, share > 0 { surfaces.append(Surface(model: surfaceNow, opacity: share)) }
    let standIns = actors.sorted { ($0.value.depth, $0.key) < ($1.value.depth, $1.key) }.map { window, actor in
      StandIn(
        window: window, frame: actor.frame.value(at: now), opacity: actor.opacity.value(at: now),
        cover: actor.cover.value(at: now), picture: actor.picture.value(at: now), pid: actor.pid,
        bundleID: actor.bundleID)
    }
    return Picture(frame: frame, opacity: now < ends ? 1 : lift.value(at: now), surfaces: surfaces, standIns: standIns)
  }
}
