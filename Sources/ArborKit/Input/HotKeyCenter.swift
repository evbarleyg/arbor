import ArborCore
import Carbon.HIToolbox

/// Registers global shortcuts with Carbon's RegisterEventHotKey, which needs
/// no extra permission and swallows the key press so the frontmost app never
/// sees it. It reports each shortcut's key going down and coming up, and decides nothing.
@MainActor
public final class HotKeyCenter {
  fileprivate static weak var current: HotKeyCenter?

  private var handlerRef: EventHandlerRef?
  private var registered: [UInt32: (ref: EventHotKeyRef, binding: KeyBinding)] = [:]
  /// The shortcuts `setTemporary` added.
  private var temporary: [UInt32] = []
  /// Never used twice, so that the release of a shortcut that has been unregistered meanwhile is nobody's, and a
  /// press still on its way when the shortcuts are registered anew (another app came to the front) finds
  /// nothing rather than whichever command took over its number.
  private var lastIdentifier: UInt32 = 0
  private let onKey: (KeyBinding, KeyPhase) -> Void

  public init(onKey: @escaping (KeyBinding, KeyPhase) -> Void) {
    self.onKey = onKey
    HotKeyCenter.current = self
    let specs = [
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
    ]
    let status = InstallEventHandler(
      GetEventDispatcherTarget(), hotKeyEventHandler, 2, specs, nil, &handlerRef)
    if status != noErr { Log.error("no shortcut will work: could not listen for hot keys (error \(status))") }
  }

  /// Registers the bindings and returns any that macOS refused.
  @discardableResult
  public func register(_ bindings: [KeyBinding]) -> [KeyBinding] {
    unregisterAll()
    let failed = bindings.filter { add($0) == nil }
    if !failed.isEmpty {
      Log.info("shortcuts already in use by another app: \(failed.map(\.label).joined(separator: " "))")
    }
    return failed
  }

  /// Registers these on top of the others, in place of the ones the last call added. The others stay as
  /// they are: unregistering a shortcut whose key is down would lose its release.
  public func setTemporary(_ bindings: [KeyBinding]) {
    for identifier in temporary { remove(identifier) }
    temporary = bindings.compactMap { add($0) }
  }

  public func unregisterAll() {
    for entry in registered.values { UnregisterEventHotKey(entry.ref) }
    registered.removeAll()
    temporary.removeAll()
  }

  private func add(_ binding: KeyBinding) -> UInt32? {
    lastIdentifier &+= 1
    var ref: EventHotKeyRef?
    let hotKeyID = EventHotKeyID(signature: OSType(0x4152_424F), id: lastIdentifier)  // 'ARBO'
    let status = RegisterEventHotKey(
      binding.keyCode, binding.modifiers.carbonFlags, hotKeyID, GetEventDispatcherTarget(), 0, &ref)
    guard status == noErr, let ref else { return nil }
    registered[lastIdentifier] = (ref, binding)
    return lastIdentifier
  }

  private func remove(_ identifier: UInt32) {
    guard let entry = registered.removeValue(forKey: identifier) else { return }
    UnregisterEventHotKey(entry.ref)
  }

  fileprivate func fire(_ identifier: UInt32, _ phase: KeyPhase) {
    guard let binding = registered[identifier]?.binding else { return }
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
