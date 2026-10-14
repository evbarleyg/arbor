// CarbonEvents.h: macOS's own keyboard shortcuts. The three keys are CFSTR macros, which Swift imports as String.
import MacFoundation

public func CopySymbolicHotKeys(_ outHotKeyArray: UnsafeMutablePointer<Unmanaged<CFArray>?>!) -> OSStatus { 0 }
public let kHISymbolicHotKeyCode = "kHISymbolicHotKeyCode"
public let kHISymbolicHotKeyModifiers = "kHISymbolicHotKeyModifiers"
public let kHISymbolicHotKeyEnabled = "kHISymbolicHotKeyEnabled"
