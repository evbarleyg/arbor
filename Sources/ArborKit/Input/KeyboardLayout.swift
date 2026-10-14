import ArborCore
import Carbon.HIToolbox
import Foundation

/// Reads keyboard layouts from macOS as the tables `KeyLayout` decides with. No decisions here.
@MainActor
enum KeyboardLayoutReader {
  /// The layout ⌘-shortcuts go by: the one selected or, while a layout or input method without Latin letters
  /// is (Russian, Greek, Japanese kana), the Latin one macOS pairs with it.
  static func current() -> KeyLayout? {
    guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue() else { return nil }
    return layout(of: source)
  }

  /// An installed layout by its id, e.g. `com.apple.keylayout.German`, selected or not. For tests.
  static func installed(id: String) -> KeyLayout? {
    let filter = [kTISPropertyInputSourceID as String: id] as CFDictionary
    guard let list = TISCreateInputSourceList(filter, true)?.takeRetainedValue() as? [TISInputSource],
      let source = list.first
    else { return nil }
    return layout(of: source)
  }

  static func layout(of source: TISInputSource) -> KeyLayout? {
    guard let pointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else { return nil }
    let data = Unmanaged<CFData>.fromOpaque(pointer).takeUnretainedValue() as Data
    let name = TISGetInputSourceProperty(source, kTISPropertyLocalizedName).map {
      Unmanaged<CFString>.fromOpaque($0).takeUnretainedValue() as String
    }
    return KeyLayout(
      name: name ?? "unnamed", plain: table(data, modifiers: 0), shifted: table(data, modifiers: shiftKey))
  }

  /// What every key types with these modifiers (Carbon's `shiftKey`…) held. A dead key counts as the accent it
  /// would add: that is what is printed on it.
  private static func table(_ data: Data, modifiers: Int) -> [UInt32: String] {
    var result: [UInt32: String] = [:]
    let keyboardType = UInt32(LMGetKbdType())
    data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
      guard let layout = bytes.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return }
      for code in UInt16(0)..<128 {
        var deadKeys: UInt32 = 0
        var length = 0
        var characters = [UniChar](repeating: 0, count: 4)
        let status = UCKeyTranslate(
          layout, code, UInt16(kUCKeyActionDisplay), UInt32((modifiers >> 8) & 0xFF), keyboardType,
          OptionBits(kUCKeyTranslateNoDeadKeysMask), &deadKeys, characters.count, &length, &characters)
        if status == noErr, length > 0 { result[UInt32(code)] = String(utf16CodeUnits: characters, count: length) }
      }
    }
    return result
  }
}

/// Reports the keyboard layout: once when started, then whenever another input source is selected.
///
/// `ARBOR_KEYBOARD_LAYOUT=com.apple.keylayout.German` makes Arbor go by that installed layout whatever is
/// selected, so that a test can press real keys "on a German keyboard" without changing somebody's Mac.
@MainActor
final class KeyboardLayoutWatcher: NSObject {
  private let onChange: @MainActor (KeyLayout) -> Void
  private var isObserving = false
  private let pretendedID = ProcessInfo.processInfo.environment["ARBOR_KEYBOARD_LAYOUT"]

  init(onChange: @escaping @MainActor (KeyLayout) -> Void) {
    self.onChange = onChange
    super.init()
  }

  func start() {
    guard !isObserving else { return }
    isObserving = true
    // Delivered at once: AppKit holds distributed notifications back from an app that is not active, which
    // Arbor never is.
    DistributedNotificationCenter.default().addObserver(
      self, selector: #selector(inputSourceChanged),
      name: Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String), object: nil,
      suspensionBehavior: .deliverImmediately)
    report()
  }

  func stop() {
    guard isObserving else { return }
    isObserving = false
    DistributedNotificationCenter.default().removeObserver(self)
  }

  /// Distributed notifications arrive on the main thread.
  @objc private func inputSourceChanged() { report() }

  private func report() {
    if let pretendedID, !pretendedID.isEmpty {
      if let layout = KeyboardLayoutReader.installed(id: pretendedID) { return onChange(layout) }
      Log.error("ARBOR_KEYBOARD_LAYOUT: macOS has no keyboard layout \(pretendedID); using the one selected")
    }
    // Without a table (nobody has seen that happen) a US keyboard is as good a guess as before F44.
    onChange(KeyboardLayoutReader.current() ?? .us)
  }
}
