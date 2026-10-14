// The part of Carbon's HIToolbox that speaks of Core Foundation types, which the stand-in in C cannot (scripts/typecheck-mac/README.md).
// prepare.py imports this module, and ApplicationServices, which Carbon brings too, into every file that imports Carbon.
import MacFoundation

public final class TISInputSource: NSObject {}
public func TISCopyCurrentKeyboardInputSource() -> Unmanaged<TISInputSource>! { nil }
public func TISCopyCurrentKeyboardLayoutInputSource() -> Unmanaged<TISInputSource>! { nil }
public func TISCopyCurrentASCIICapableKeyboardInputSource() -> Unmanaged<TISInputSource>! { nil }
public func TISCopyCurrentASCIICapableKeyboardLayoutInputSource() -> Unmanaged<TISInputSource>! { nil }
public func TISCopyInputSourceForLanguage(_ language: CFString!) -> Unmanaged<TISInputSource>! { nil }
public func TISCreateInputSourceList(_ properties: CFDictionary!, _ includeAllInstalled: Bool) -> Unmanaged<CFArray>! { nil }
@discardableResult public func TISSelectInputSource(_ inputSource: TISInputSource!) -> OSStatus { 0 }
@discardableResult public func TISDeselectInputSource(_ inputSource: TISInputSource!) -> OSStatus { 0 }
@discardableResult public func TISEnableInputSource(_ inputSource: TISInputSource!) -> OSStatus { 0 }
@discardableResult public func TISDisableInputSource(_ inputSource: TISInputSource!) -> OSStatus { 0 }
public func TISGetInputSourceProperty(_ inputSource: TISInputSource!, _ propertyKey: CFString!) -> UnsafeMutableRawPointer! { nil }
public nonisolated(unsafe) let kTISPropertyUnicodeKeyLayoutData: CFString! = "TISPropertyUnicodeKeyLayoutData"
public nonisolated(unsafe) let kTISPropertyInputSourceID: CFString! = "TISPropertyInputSourceID"
public nonisolated(unsafe) let kTISPropertyInputSourceCategory: CFString! = "TISPropertyInputSourceCategory"
public nonisolated(unsafe) let kTISPropertyInputSourceType: CFString! = "TISPropertyInputSourceType"
public nonisolated(unsafe) let kTISPropertyLocalizedName: CFString! = "TISPropertyLocalizedName"
public nonisolated(unsafe) let kTISPropertyInputSourceIsASCIICapable: CFString! = "TISPropertyInputSourceIsASCIICapable"
public nonisolated(unsafe) let kTISPropertyInputSourceIsEnableCapable: CFString! = "TISPropertyInputSourceIsEnableCapable"
public nonisolated(unsafe) let kTISPropertyInputSourceIsSelectCapable: CFString! = "TISPropertyInputSourceIsSelectCapable"
public nonisolated(unsafe) let kTISPropertyInputSourceIsEnabled: CFString! = "TISPropertyInputSourceIsEnabled"
public nonisolated(unsafe) let kTISPropertyInputSourceIsSelected: CFString! = "TISPropertyInputSourceIsSelected"
public nonisolated(unsafe) let kTISPropertyInputSourceLanguages: CFString! = "TISPropertyInputSourceLanguages"
public nonisolated(unsafe) let kTISPropertyBundleID: CFString! = "TISPropertyBundleID"
public nonisolated(unsafe) let kTISPropertyInputModeID: CFString! = "TISPropertyInputModeID"
public nonisolated(unsafe) let kTISCategoryKeyboardInputSource: CFString! = "TISCategoryKeyboardInputSource"
public nonisolated(unsafe) let kTISCategoryPaletteInputSource: CFString! = "TISCategoryPaletteInputSource"
public nonisolated(unsafe) let kTISCategoryInkInputSource: CFString! = "TISCategoryInkInputSource"
public nonisolated(unsafe) let kTISTypeKeyboardLayout: CFString! = "TISTypeKeyboardLayout"
public nonisolated(unsafe) let kTISTypeKeyboardInputMethodWithoutModes: CFString! = "TISTypeKeyboardInputMethodWithoutModes"
public nonisolated(unsafe) let kTISTypeKeyboardInputMethodModeEnabled: CFString! = "TISTypeKeyboardInputMethodModeEnabled"
public nonisolated(unsafe) let kTISTypeKeyboardInputMode: CFString! = "TISTypeKeyboardInputMode"
public nonisolated(unsafe) let kTISNotifySelectedKeyboardInputSourceChanged: CFString! = "TISNotifySelectedKeyboardInputSourceChanged"
public nonisolated(unsafe) let kTISNotifyEnabledKeyboardInputSourcesChanged: CFString! = "TISNotifyEnabledKeyboardInputSourcesChanged"
