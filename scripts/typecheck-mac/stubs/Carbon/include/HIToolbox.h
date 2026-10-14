// A stand-in for Carbon's HIToolbox: hot keys, virtual key codes, keyboard layouts (scripts/typecheck-mac/README.md).
// In C, so that `import Carbon.HIToolbox` works and Swift imports it as it imports Apple's.
#ifndef HITOOLBOX_H
#define HITOOLBOX_H
#include "CMacTypes.h"
#define _Nullable_result
#pragma clang assume_nonnull begin

typedef struct OpaqueEventRef *EventRef;
typedef struct OpaqueEventHandlerRef *EventHandlerRef;
typedef struct OpaqueEventHandlerCallRef *EventHandlerCallRef;
typedef struct OpaqueEventTargetRef *EventTargetRef;
typedef struct OpaqueEventHotKeyRef *EventHotKeyRef;
typedef OSType EventParamName;
typedef OSType EventParamType;
typedef struct EventTypeSpec { OSType eventClass; UInt32 eventKind; } EventTypeSpec;
typedef struct EventHotKeyID { OSType signature; UInt32 id; } EventHotKeyID;
typedef OSStatus (*EventHandlerProcPtr)(EventHandlerCallRef _Nullable inHandlerCallRef, EventRef _Nullable inEvent, void *_Nullable inUserData);
typedef EventHandlerProcPtr EventHandlerUPP;

#pragma clang assume_nonnull end
// Carbon's headers say nothing about null, so everything arrives implicitly unwrapped.
EventTargetRef GetEventDispatcherTarget(void);
EventTargetRef GetApplicationEventTarget(void);
OSStatus InstallEventHandler(EventTargetRef inTarget, EventHandlerUPP inHandler, ItemCount inNumTypes, const EventTypeSpec *inList,
                             void *inUserData, EventHandlerRef *outRef);
OSStatus RemoveEventHandler(EventHandlerRef inHandlerRef);
OSStatus CallNextEventHandler(EventHandlerCallRef inCallRef, EventRef inEvent);
OSStatus RegisterEventHotKey(UInt32 inHotKeyCode, UInt32 inHotKeyModifiers, EventHotKeyID inHotKeyID, EventTargetRef inTarget,
                             OptionBits inOptions, EventHotKeyRef *outRef);
OSStatus UnregisterEventHotKey(EventHotKeyRef inHotKey);
OSStatus GetEventParameter(EventRef inEvent, EventParamName inName, EventParamType inType, EventParamType *outActualType,
                           ByteCount inBufferSize, ByteCount *outActualSize, void *outData);
OSType GetEventClass(EventRef inEvent);
UInt32 GetEventKind(EventRef inEvent);
UInt32 GetCurrentKeyModifiers(void);
UInt32 GetCurrentEventKeyModifiers(void);
UInt8 LMGetKbdType(void);

enum { kEventClassKeyboard = 0x6B657962, kEventClassMouse = 0x6D6F7573, kEventClassApplication = 0x6170706C };
enum { kEventRawKeyDown = 1, kEventRawKeyRepeat = 2, kEventRawKeyUp = 3, kEventRawKeyModifiersChanged = 4, kEventHotKeyPressed = 5,
       kEventHotKeyReleased = 6 };
enum { kEventParamDirectObject = 0x2D2D2D2D, kEventParamKeyCode = 0x6B636F64, kEventParamKeyModifiers = 0x6B6D6F64 };
enum { typeEventHotKeyID = 0x686B6964, typeUInt32 = 0x6D61676E };
enum { eventNotHandledErr = -9874, eventAlreadyPostedErr = -9860, eventHotKeyExistsErr = -9878, eventHotKeyInvalidErr = -9879 };
enum { kEventHotKeyNoOptions = 0, kEventHotKeyExclusive = 1 };
enum { activeFlagBit = 0, btnStateBit = 7, cmdKeyBit = 8, shiftKeyBit = 9, alphaLockBit = 10, optionKeyBit = 11, controlKeyBit = 12 };
enum { activeFlag = 1 << 0, btnState = 1 << 7, cmdKey = 1 << 8, shiftKey = 1 << 9, alphaLock = 1 << 10, optionKey = 1 << 11,
       controlKey = 1 << 12, rightShiftKey = 1 << 13, rightOptionKey = 1 << 14, rightControlKey = 1 << 15 };

enum {
  kVK_ANSI_A = 0x00, kVK_ANSI_S = 0x01, kVK_ANSI_D = 0x02, kVK_ANSI_F = 0x03, kVK_ANSI_H = 0x04, kVK_ANSI_G = 0x05, kVK_ANSI_Z = 0x06,
  kVK_ANSI_X = 0x07, kVK_ANSI_C = 0x08, kVK_ANSI_V = 0x09, kVK_ANSI_B = 0x0B, kVK_ANSI_Q = 0x0C, kVK_ANSI_W = 0x0D, kVK_ANSI_E = 0x0E,
  kVK_ANSI_R = 0x0F, kVK_ANSI_Y = 0x10, kVK_ANSI_T = 0x11, kVK_ANSI_1 = 0x12, kVK_ANSI_2 = 0x13, kVK_ANSI_3 = 0x14, kVK_ANSI_4 = 0x15,
  kVK_ANSI_6 = 0x16, kVK_ANSI_5 = 0x17, kVK_ANSI_Equal = 0x18, kVK_ANSI_9 = 0x19, kVK_ANSI_7 = 0x1A, kVK_ANSI_Minus = 0x1B,
  kVK_ANSI_8 = 0x1C, kVK_ANSI_0 = 0x1D, kVK_ANSI_RightBracket = 0x1E, kVK_ANSI_O = 0x1F, kVK_ANSI_U = 0x20, kVK_ANSI_LeftBracket = 0x21,
  kVK_ANSI_I = 0x22, kVK_ANSI_P = 0x23, kVK_ANSI_L = 0x25, kVK_ANSI_J = 0x26, kVK_ANSI_Quote = 0x27, kVK_ANSI_K = 0x28,
  kVK_ANSI_Semicolon = 0x29, kVK_ANSI_Backslash = 0x2A, kVK_ANSI_Comma = 0x2B, kVK_ANSI_Slash = 0x2C, kVK_ANSI_N = 0x2D, kVK_ANSI_M = 0x2E,
  kVK_ANSI_Period = 0x2F, kVK_ANSI_Grave = 0x32, kVK_ANSI_KeypadDecimal = 0x41, kVK_ANSI_KeypadMultiply = 0x43, kVK_ANSI_KeypadPlus = 0x45,
  kVK_ANSI_KeypadClear = 0x47, kVK_ANSI_KeypadDivide = 0x4B, kVK_ANSI_KeypadEnter = 0x4C, kVK_ANSI_KeypadMinus = 0x4E,
  kVK_ANSI_KeypadEquals = 0x51, kVK_ANSI_Keypad0 = 0x52, kVK_ANSI_Keypad1 = 0x53, kVK_ANSI_Keypad2 = 0x54, kVK_ANSI_Keypad3 = 0x55,
  kVK_ANSI_Keypad4 = 0x56, kVK_ANSI_Keypad5 = 0x57, kVK_ANSI_Keypad6 = 0x58, kVK_ANSI_Keypad7 = 0x59, kVK_ANSI_Keypad8 = 0x5B,
  kVK_ANSI_Keypad9 = 0x5C
};
enum {
  kVK_Return = 0x24, kVK_Tab = 0x30, kVK_Space = 0x31, kVK_Delete = 0x33, kVK_Escape = 0x35, kVK_Command = 0x37, kVK_Shift = 0x38,
  kVK_CapsLock = 0x39, kVK_Option = 0x3A, kVK_Control = 0x3B, kVK_RightCommand = 0x36, kVK_RightShift = 0x3C, kVK_RightOption = 0x3D,
  kVK_RightControl = 0x3E, kVK_Function = 0x3F, kVK_F17 = 0x40, kVK_VolumeUp = 0x48, kVK_VolumeDown = 0x49, kVK_Mute = 0x4A, kVK_F18 = 0x4F,
  kVK_F19 = 0x50, kVK_F20 = 0x5A, kVK_F5 = 0x60, kVK_F6 = 0x61, kVK_F7 = 0x62, kVK_F3 = 0x63, kVK_F8 = 0x64, kVK_F9 = 0x65, kVK_F11 = 0x67,
  kVK_F13 = 0x69, kVK_F16 = 0x6A, kVK_F14 = 0x6B, kVK_F10 = 0x6D, kVK_F12 = 0x6F, kVK_F15 = 0x71, kVK_Help = 0x72, kVK_Home = 0x73,
  kVK_PageUp = 0x74, kVK_ForwardDelete = 0x75, kVK_End = 0x77, kVK_F4 = 0x76, kVK_F2 = 0x78, kVK_PageDown = 0x79, kVK_F1 = 0x7A,
  kVK_LeftArrow = 0x7B, kVK_RightArrow = 0x7C, kVK_DownArrow = 0x7D, kVK_UpArrow = 0x7E
};
enum { kVK_ISO_Section = 0x0A };
enum { kVK_JIS_Yen = 0x5D, kVK_JIS_Underscore = 0x5E, kVK_JIS_KeypadComma = 0x5F, kVK_JIS_Eisu = 0x66, kVK_JIS_Kana = 0x68 };

// Unicode Utilities (CoreServices, which Carbon brings).
typedef struct UCKeyboardLayout { UInt16 keyLayoutHeaderFormat; } UCKeyboardLayout;
enum { kUCKeyActionDown = 0, kUCKeyActionUp = 1, kUCKeyActionAutoKey = 2, kUCKeyActionDisplay = 3 };
enum { kUCKeyTranslateNoDeadKeysBit = 0 };
enum { kUCKeyTranslateNoDeadKeysMask = 1 };
OSStatus UCKeyTranslate(const UCKeyboardLayout *keyLayoutPtr, UInt16 virtualKeyCode, UInt16 keyAction, UInt32 modifierKeyState,
                        UInt32 keyboardType, OptionBits keyTranslateOptions, UInt32 *deadKeyState, UniCharCount maxStringLength,
                        UniCharCount *actualStringLength, UniChar unicodeString[]);
#endif
