import ArborCore
import ArborKit

/// macOS's side of Arbor's shortcuts: what `RegisterEventHotKey` and `UnregisterEventHotKey` do to the window server's table, and which
/// registrations a press fires. It notes which keys are in the table after every single step, so a test can see a key
/// that was out of it for a moment.
///
/// As a hosted Mac answered (macOS 26, posted events): it says yes to a key with fn and without, both at once too. For an ordinary key
/// the two are two: a plain press fires the one, a press with fn's flag the other. For a key that carries the flag by nature (arrows, function
/// keys) they are one: either fires with the flag and neither without, and **held both ways a press fires both**: down, down, up, up.
/// What it does not play: fn going down or up in the middle of a press, and auto-repeat.
public final class FakeHotKeyServer {
  public struct Registration: Equatable {
    public let key: HotKey
    public let withFn: Bool
    /// Whether a real key of this kind sends fn's flag whatever the fingers do.
    public let carriesFn: Bool
  }

  /// What is registered, by the reference macOS handed out for it.
  public private(set) var registrations: [UInt32: Registration] = [:]
  /// The keys in the table after each step since this was last emptied: those registered plainly, and those registered with fn.
  public var steps: [Set<HotKey>] = []
  public var twinSteps: [Set<HotKey>] = []
  /// Keys it says no to. A real Mac has not been seen to refuse any; it is there so that the day it does is thought through.
  public var refuses: Set<HotKey> = []
  /// Keys it says no to with fn.
  public var refusesTwins: Set<HotKey> = []
  /// Keys it will not take back, with fn or without.
  public var keeps: Set<HotKey> = []
  /// Keys whose registration with fn it will not take back.
  public var keepsTwins: Set<HotKey> = []
  /// A macOS that does not know Carbon's bit for fn. Nobody has met one; macOS 14 and 15 have not been asked. The Mac that was asked ignored the
  /// bits it does not know, took such a registration for a plain one, refused neither of two that it took for one, and fired both.
  public var ignoresTheFnBit = false
  public private(set) var asked = 0
  /// Every number it was ever given.
  public private(set) var numbers: [UInt32] = []

  public init() {}

  /// The plain registrations, by reference.
  public var keys: [UInt32: HotKey] { registrations.filter { !$0.value.withFn }.mapValues(\.key) }
  public var held: Set<HotKey> { Set(keys.values) }
  /// The keys registered with fn.
  public var twins: Set<HotKey> { Set(registrations.values.filter(\.withFn).map(\.key)) }

  private func note() {
    steps.append(held)
    twinSteps.append(twins)
  }

  public func ask(_ binding: KeyBinding, _ number: UInt32, _ withFn: Bool) -> (UInt32?, HotKeyOutcome.Status) {
    asked += 1
    numbers.append(number)
    let key = HotKey(binding)
    if (withFn ? refusesTwins : refuses).contains(key) { return (nil, -9879) }
    // An app gets each key once (`eventHotKeyExistsErr`), once more with fn.
    if (withFn ? twins : held).contains(key) { return (nil, -9878) }
    registrations[number] = Registration(key: key, withFn: withFn, carriesFn: Self.carriesFn(binding.keyCode))
    note()
    return (number, 0)
  }

  public func giveBack(_ reference: UInt32) -> HotKeyOutcome.Status {
    guard let registration = registrations[reference] else { return -9879 }
    if keeps.contains(registration.key) || (registration.withFn && keepsTwins.contains(registration.key)) { return -1 }
    registrations[reference] = nil
    note()
    return 0
  }

  /// The numbers that fire when this key goes down, with fn held or not. None: the app in front gets the key.
  public func fires(_ key: HotKey, fn: Bool) -> [UInt32] {
    registrations.filter {
      $0.value.key == key && ($0.value.carriesFn || (ignoresTheFnBit ? !fn : $0.value.withFn == fn))
    }.keys.sorted()
  }

  /// By the key's code, as macOS goes, and by a list of its own, not Arbor's. Asked of a Mac: ← → F5 Home End Page Up Page Down forward
  /// delete. The others are their kin: ↑ ↓, F1 to F20, Help.
  public static func carriesFn(_ keyCode: UInt32) -> Bool {
    (96...101).contains(keyCode) || (113...126).contains(keyCode) || [103, 105, 106, 107, 109, 111, 64, 79, 80, 90].contains(keyCode)
  }
}

/// The part of `ArborApp` that holds shortcuts, with the real `HotKeyTable` and a `FakeHotKeyServer` for macOS: it
/// listens to the controller as the app does, and does what the app does when it hears something.
@MainActor
public final class FakeHotKeys {
  public let server = FakeHotKeyServer()
  public private(set) var table = HotKeyTable<UInt32>()
  /// `HotKeyCenter` could not install its handler.
  public var isDeaf = false
  /// What went into the log.
  public var lines: [String] = []
  /// How often macOS was talked to about the shortcuts that are held for good.
  public private(set) var registrations = 0
  /// `ArborApp.holdsKeys`: true from launch until Arbor quits, whether or not it can act on a press.
  public var holdsKeys = true
  private unowned let controller: Controller

  /// Wires itself in as `ArborApp.init` does. Call before `start()`. `register()` is what the app does at launch, before it knows of
  /// the permission, and again once the controller has started.
  public init(_ controller: Controller) {
    self.controller = controller
    controller.onSettingsApplied = { [weak self] _ in self?.register() }
    controller.onTemporaryShortcuts = { [weak self] in self?.setTemporary($0) }
    controller.observe { [weak self] change in
      guard change == .lifecycle || change == .input || change == .hold, let self else { return }
      self.register()
    }
  }

  /// `ArborApp.registerHotKeys`.
  public func register() {
    guard holdsKeys else { return }
    guard let bindings = controller.shortcutsToRegister() else { return }
    guard !controller.shortcutsAreDisabled else { return lines += controller.shortcutsWereRegistered(HotKeyOutcome(), microseconds: 0) }
    registrations += 1
    let outcome = isDeaf ? nil : table.hold(bindings, ask: server.ask, giveBack: server.giveBack)
    lines += controller.shortcutsWereRegistered(outcome, microseconds: 900)
  }

  /// `HotKeyCenter.setTemporary`.
  public func setTemporary(_ bindings: [KeyBinding]) {
    guard !isDeaf else { return }
    _ = table.setTemporary(bindings, ask: server.ask, giveBack: server.giveBack)
  }

  /// What the controller is told when this key goes down and comes up, with fn held or not: by macOS's table, then by Arbor's. Nothing: the
  /// app in front gets the key. More than one: the command runs more than once.
  public func runs(_ key: HotKey, fn: Bool = false) -> [KeyBinding] {
    let numbers = server.fires(key, fn: fn)
    let told = numbers.compactMap { table.heard($0, .pressed) }
    for number in numbers { _ = table.heard(number, .released) }
    return told
  }

  /// What a plain press of this key would run, or nil if it goes to the app in front.
  public func binding(at key: HotKey) -> KeyBinding? { runs(key).first }

  /// Keys that macOS takes from every app and of which Arbor knows nothing: swallowed, and dead.
  public var leaked: [HotKey] { server.registrations.filter { table.binding(for: $0.key) == nil }.map(\.value.key) }
}
