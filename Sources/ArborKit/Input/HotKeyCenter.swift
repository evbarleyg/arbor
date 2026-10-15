import ArborCore
import Carbon.HIToolbox

/// Registers global shortcuts with Carbon's RegisterEventHotKey, which needs
/// no extra permission and swallows the key press so the frontmost app never
/// sees it. It reports each shortcut's key going down and coming up, and decides nothing:
/// which keys to ask macOS for and which to give back is `HotKeyTable`'s business.
///
/// What macOS's yes is worth, as seen on macOS 26: it says yes whoever else holds the key. Another program that
/// registered the same key hears it as well, and one that registered it exclusively hears it alone. Nothing tells Arbor.
/// And it compares the flag of the fn key exactly, so most keys are registered twice (`HotKeyTable`).
@MainActor
public final class HotKeyCenter {
  fileprivate static weak var current: HotKeyCenter?

  private var handlerRef: EventHandlerRef?
  private var table = HotKeyTable<EventHotKeyRef>()
  /// What the log was last told about listening, so that trying again does not fill it.
  private var deafnessSaid: OSStatus = noErr
  private let onKey: (KeyBinding, KeyPhase) -> Void

  public init(onKey: @escaping (KeyBinding, KeyPhase) -> Void) {
    self.onKey = onKey
    HotKeyCenter.current = self
    _ = listen()
  }

  /// Without a handler a registered shortcut would be taken from every app and heard by nobody. Tried again whenever
  /// shortcuts are asked for.
  private func listen() -> Bool {
    guard handlerRef == nil else { return true }
    let specs = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]
    let status = InstallEventHandler(
      GetEventDispatcherTarget(), hotKeyEventHandler, 2, specs, nil, &handlerRef)
    if status != noErr { handlerRef = nil }
    if status != noErr, status != deafnessSaid {
      Log.error("no shortcut will work: could not listen for hot keys (error \(status))")
    }
    deafnessSaid = status
    return status == noErr
  }

  /// Holds these and, besides, only what `setTemporary` added. Says how it went, or nil if Arbor cannot listen for shortcuts
  /// and so holds none.
  public func register(_ bindings: [KeyBinding]) -> HotKeyOutcome? {
    guard listen() else { return nil }
    return table.hold(bindings, ask: Self.ask, giveBack: Self.giveBack)
  }

  /// Registers these on top of the others, in place of the ones the last call added. The others stay as
  /// they are: unregistering a shortcut whose key is down would lose its release.
  public func setTemporary(_ bindings: [KeyBinding]) {
    guard listen() else { return }
    let outcome = table.setTemporary(bindings, ask: Self.ask, giveBack: Self.giveBack)
    let refusals = (outcome.refused + outcome.stuck).map(\.text) + outcome.withoutTwin.map { "fn " + $0.text }
    if !refusals.isEmpty { Log.error("shortcuts for the time being: macOS said no to \(refusals.joined(separator: ", "))") }
  }

  public func unregisterAll() {
    let stuck = table.giveAllBack(Self.giveBack).stuck.map(\.text)
    if !stuck.isEmpty { Log.error("macOS would not take shortcuts back: \(stuck.joined(separator: ", "))") }
  }

  private static func ask(
    _ binding: KeyBinding, _ identifier: UInt32, _ withFn: Bool
  ) -> (EventHotKeyRef?, HotKeyOutcome.Status) {
    var ref: EventHotKeyRef?
    let hotKeyID = EventHotKeyID(signature: OSType(0x4152_424F), id: identifier)  // 'ARBO'
    // Carbon's kEventKeyModifierFnMask. Which keys are asked for a second time with it: `KeyChord.hasFnTwin`.
    let flags = binding.modifiers.carbonFlags | (withFn ? 1 << 17 : 0)
    let status = RegisterEventHotKey(binding.keyCode, flags, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
    return (ref, status)
  }

  private static func giveBack(_ ref: EventHotKeyRef) -> HotKeyOutcome.Status { UnregisterEventHotKey(ref) }

  fileprivate func fire(_ identifier: UInt32, _ phase: KeyPhase) {
    guard let binding = table.heard(identifier, phase) else { return }
    onKey(binding, phase)
  }
}

extension KeyChord.Modifiers {
  /// Carbon's modifier flags for RegisterEventHotKey.
  fileprivate var carbonFlags: UInt32 {
    var flags: UInt32 = 0
    if contains(.command) { flags |= UInt32(cmdKey) }
    if contains(.shift) { flags |= UInt32(shiftKey) }
    if contains(.option) { flags |= UInt32(optionKey) }
    if contains(.control) { flags |= UInt32(controlKey) }
    return flags
  }
}

/// Carbon delivers hot key events on the main thread.
private func hotKeyEventHandler(
  _ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
  guard let event else { return OSStatus(eventNotHandledErr) }
  var hotKeyID = EventHotKeyID()
  let status = GetEventParameter(
    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
    MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
  guard status == noErr else { return status }
  let identifier = hotKeyID.id
  let phase: KeyPhase = GetEventKind(event) == UInt32(kEventHotKeyReleased) ? .released : .pressed
  MainActor.assumeIsolated { HotKeyCenter.current?.fire(identifier, phase) }
  return noErr
}
