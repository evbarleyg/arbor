import ArborCore
import ArborKit

/// macOS's side of Arbor's shortcuts: what `RegisterEventHotKey` and `UnregisterEventHotKey` do to the window server's table.
/// It notes which keys are in the table after every single step, so a test can see a key that was out of it for a moment.
public final class FakeHotKeyServer {
  /// What is registered, by the reference macOS handed out for it.
  public private(set) var keys: [UInt32: HotKey] = [:]
  /// The keys in the table after each step since this was last emptied.
  public var steps: [Set<HotKey>] = []
  /// Keys it says no to. A real Mac has not been seen to refuse any; it is there so that the day it does is thought through.
  public var refuses: Set<HotKey> = []
  /// Keys it will not take back.
  public var keeps: Set<HotKey> = []
  public private(set) var asked = 0
  /// Every number it was ever given.
  public private(set) var numbers: [UInt32] = []

  public init() {}

  public var held: Set<HotKey> { Set(keys.values) }

  public func ask(_ binding: KeyBinding, _ number: UInt32) -> (UInt32?, HotKeyOutcome.Status) {
    asked += 1
    numbers.append(number)
    let key = HotKey(binding)
    if refuses.contains(key) { return (nil, -9879) }
    // An app gets each key once (`eventHotKeyExistsErr`).
    if held.contains(key) { return (nil, -9878) }
    keys[number] = key
    steps.append(held)
    return (number, 0)
  }

  public func giveBack(_ reference: UInt32) -> HotKeyOutcome.Status {
    guard let key = keys[reference] else { return -9879 }
    if keeps.contains(key) { return -1 }
    keys[reference] = nil
    steps.append(held)
    return 0
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

  /// What a press of this key would run, or nil if it goes to the app in front: by macOS's table, then by Arbor's.
  public func binding(at key: HotKey) -> KeyBinding? {
    server.keys.first { $0.value == key }.flatMap { table.binding(for: $0.key) }
  }

  /// Keys that macOS takes from every app and of which Arbor knows nothing: swallowed, and dead.
  public var leaked: [HotKey] { server.keys.filter { table.binding(for: $0.key) == nil }.map(\.value) }
}
