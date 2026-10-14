import ArborCore
import Carbon.HIToolbox
import Foundation

/// Reads macOS's own keyboard shortcuts as the list `SystemShortcuts` decides with. No decisions here.
@MainActor
enum SystemShortcutReader {
  /// Nil if macOS does not say.
  static func read() -> SystemShortcuts? {
    var list: Unmanaged<CFArray>?
    guard CopySymbolicHotKeys(&list) == noErr, let entries = list?.takeRetainedValue() as? [[String: Any]] else {
      return nil
    }
    let shortcuts = entries.compactMap { entry -> SystemShortcuts.Shortcut? in
      guard let code = (entry[kHISymbolicHotKeyCode] as? Int).flatMap(UInt32.init(exactly:)),
        let modifiers = (entry[kHISymbolicHotKeyModifiers] as? Int).flatMap(UInt32.init(exactly:)),
        let isEnabled = entry[kHISymbolicHotKeyEnabled] as? Bool
      else { return nil }
      return SystemShortcuts.Shortcut(keyCode: code, carbonModifiers: modifiers, isEnabled: isEnabled)
    }
    return SystemShortcuts(shortcuts: shortcuts, inputSources: inputSources)
  }

  /// How many keyboard layouts and input methods the Input menu switches between.
  private static var inputSources: Int? {
    let wanted: [String: Any] = [
      kTISPropertyInputSourceCategory as String: kTISCategoryKeyboardInputSource as String,
      kTISPropertyInputSourceIsSelectCapable as String: true,
    ]
    return (TISCreateInputSourceList(wanted as CFDictionary, false)?.takeRetainedValue() as? [TISInputSource])?.count
  }
}
