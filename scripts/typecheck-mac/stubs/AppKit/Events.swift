// A stand-in for AppKit: events and responders. See Application.swift.
import FakeMacOS

open class NSEvent: NSObject {
  public enum EventType: UInt, Sendable {
    case leftMouseDown = 1, leftMouseUp = 2, rightMouseDown = 3, rightMouseUp = 4, mouseMoved = 5, leftMouseDragged = 6, rightMouseDragged = 7,
      mouseEntered = 8, mouseExited = 9, keyDown = 10, keyUp = 11, flagsChanged = 12, appKitDefined = 13, systemDefined = 14,
      applicationDefined = 15, periodic = 16, cursorUpdate = 17, scrollWheel = 22, tabletPoint = 23, tabletProximity = 24, otherMouseDown = 25,
      otherMouseUp = 26, otherMouseDragged = 27, gesture = 29, magnify = 30, swipe = 31, rotate = 18, beginGesture = 19, endGesture = 20,
      smartMagnify = 32, quickLook = 33, pressure = 34, directTouch = 37, changeMode = 38
  }
  public struct EventTypeMask: OptionSet, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public init(type: EventType) { rawValue = 1 << UInt64(type.rawValue) }
    public static let leftMouseDown = EventTypeMask(type: .leftMouseDown)
    public static let leftMouseUp = EventTypeMask(type: .leftMouseUp)
    public static let rightMouseDown = EventTypeMask(type: .rightMouseDown)
    public static let rightMouseUp = EventTypeMask(type: .rightMouseUp)
    public static let mouseMoved = EventTypeMask(type: .mouseMoved)
    public static let leftMouseDragged = EventTypeMask(type: .leftMouseDragged)
    public static let rightMouseDragged = EventTypeMask(type: .rightMouseDragged)
    public static let mouseEntered = EventTypeMask(type: .mouseEntered)
    public static let mouseExited = EventTypeMask(type: .mouseExited)
    public static let keyDown = EventTypeMask(type: .keyDown)
    public static let keyUp = EventTypeMask(type: .keyUp)
    public static let flagsChanged = EventTypeMask(type: .flagsChanged)
    public static let appKitDefined = EventTypeMask(type: .appKitDefined)
    public static let systemDefined = EventTypeMask(type: .systemDefined)
    public static let applicationDefined = EventTypeMask(type: .applicationDefined)
    public static let periodic = EventTypeMask(type: .periodic)
    public static let cursorUpdate = EventTypeMask(type: .cursorUpdate)
    public static let scrollWheel = EventTypeMask(type: .scrollWheel)
    public static let otherMouseDown = EventTypeMask(type: .otherMouseDown)
    public static let otherMouseUp = EventTypeMask(type: .otherMouseUp)
    public static let otherMouseDragged = EventTypeMask(type: .otherMouseDragged)
    public static let gesture = EventTypeMask(type: .gesture)
    public static let magnify = EventTypeMask(type: .magnify)
    public static let swipe = EventTypeMask(type: .swipe)
    public static let rotate = EventTypeMask(type: .rotate)
    public static let beginGesture = EventTypeMask(type: .beginGesture)
    public static let endGesture = EventTypeMask(type: .endGesture)
    public static let smartMagnify = EventTypeMask(type: .smartMagnify)
    public static let pressure = EventTypeMask(type: .pressure)
    public static let directTouch = EventTypeMask(type: .directTouch)
    public static let any = EventTypeMask(rawValue: UInt64.max)
  }
  public struct ModifierFlags: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let capsLock = ModifierFlags(rawValue: 1 << 16)
    public static let shift = ModifierFlags(rawValue: 1 << 17)
    public static let control = ModifierFlags(rawValue: 1 << 18)
    public static let option = ModifierFlags(rawValue: 1 << 19)
    public static let command = ModifierFlags(rawValue: 1 << 20)
    public static let numericPad = ModifierFlags(rawValue: 1 << 21)
    public static let help = ModifierFlags(rawValue: 1 << 22)
    public static let function = ModifierFlags(rawValue: 1 << 23)
    public static let deviceIndependentFlagsMask = ModifierFlags(rawValue: 0xFFFF_0000)
  }
  public struct Phase: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let began = Phase(rawValue: 1)
    public static let stationary = Phase(rawValue: 2)
    public static let changed = Phase(rawValue: 4)
    public static let ended = Phase(rawValue: 8)
    public static let cancelled = Phase(rawValue: 16)
    public static let mayBegin = Phase(rawValue: 32)
  }
  public enum EventSubtype: Int16, Sendable {
    case windowExposed = 0, applicationActivated = 1, applicationDeactivated = 2, windowMoved = 4, screenChanged = 8
    public static var powerOff: EventSubtype { .applicationActivated }
    public static var mouseEvent: EventSubtype { .windowExposed }
    public static var tabletPoint: EventSubtype { .applicationActivated }
    public static var tabletProximity: EventSubtype { .applicationDeactivated }
    public static var touch: EventSubtype { .windowExposed }
  }
  public struct SwipeTrackingOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let lockDirection = SwipeTrackingOptions(rawValue: 1)
    public static let clampGestureAmount = SwipeTrackingOptions(rawValue: 2)
  }
  public enum SpecialKey {}
  public convenience init?(cgEvent: CGEvent) { self.init() }
  var _type = EventType.leftMouseDown
  var _flags: ModifierFlags = []
  /// Where the pointer was when it happened, in CoreGraphics' coordinates, which are the model's.
  var _location: CGPoint?
  open var cgEvent: CGEvent? {
    guard let _location, let event = CGEvent(source: nil) else { return nil }
    event.location = _location
    return event
  }
  open var type: EventType { _type }
  open var subtype: EventSubtype { .windowExposed }
  open var modifierFlags: ModifierFlags { _flags }
  open var timestamp: TimeInterval { 0 }
  // Main-actor only, like the window itself.
  @MainActor open var window: NSWindow? { nil }
  open var windowNumber: Int { 0 }
  open var clickCount: Int { 1 }
  open var buttonNumber: Int { 0 }
  open var eventNumber: Int { 0 }
  open var pressure: Float { 0 }
  open var stage: Int { 0 }
  open var locationInWindow: NSPoint { .zero }
  open var deltaX: CGFloat { 0 }
  open var deltaY: CGFloat { 0 }
  open var deltaZ: CGFloat { 0 }
  open var hasPreciseScrollingDeltas: Bool { false }
  open var scrollingDeltaX: CGFloat { 0 }
  open var scrollingDeltaY: CGFloat { 0 }
  open var momentumPhase: Phase { [] }
  open var isDirectionInvertedFromDevice: Bool { false }
  open var characters: String? { nil }
  open var charactersIgnoringModifiers: String? { nil }
  open func characters(byApplyingModifiers modifiers: ModifierFlags) -> String? { nil }
  open var isARepeat: Bool { false }
  open var keyCode: UInt16 { 0 }
  open var trackingNumber: Int { 0 }
  open var trackingArea: NSTrackingArea? { nil }
  open var data1: Int { 0 }
  open var data2: Int { 0 }
  open var magnification: CGFloat { 0 }
  open var rotation: Float { 0 }
  open var phase: Phase { [] }
  @MainActor open func touches(matching phase: NSTouch.Phase, in view: NSView?) -> Set<NSTouch> { [] }
  @MainActor open func allTouches() -> Set<NSTouch> { [] }
  open class var mouseLocation: NSPoint {
    let mac = FakeMac.current
    return NSPoint(x: mac.mouse.location.x, y: (mac.screens.first?.frame.height ?? 0) - mac.mouse.location.y)
  }
  open class var modifierFlags: ModifierFlags { ModifierFlags(rawValue: FakeMac.current.mouse.flags) }
  open class var pressedMouseButtons: Int { FakeMac.current.mouse.isDownByAppKit ? 1 : 0 }
  open class var doubleClickInterval: TimeInterval { 0.5 }
  open class var keyRepeatDelay: TimeInterval { 0.5 }
  open class var keyRepeatInterval: TimeInterval { 0.1 }
  open class var isSwipeTrackingFromScrollEventsEnabled: Bool { false }
  open class var isMouseCoalescingEnabled: Bool {
    get { true }
    set {}
  }
  private final class _Monitor {
    let number: Int
    init(number: Int) { self.number = number }
  }
  private class func _event(_ type: FakeMac.MouseEvent, _ flags: UInt, _ location: CGPoint) -> NSEvent {
    let event = NSEvent()
    event._location = location
    event._type = EventType(rawValue: type.rawValue) ?? .leftMouseDown
    event._flags = ModifierFlags(rawValue: flags)
    return event
  }
  open class func addGlobalMonitorForEvents(matching mask: EventTypeMask, handler block: @escaping (NSEvent) -> Void) -> Any? {
    _Monitor(number: FakeMac.current.addMonitor(global: true, mask: mask.rawValue) { type, flags, location in block(_event(type, flags, location)) })
  }
  open class func addLocalMonitorForEvents(matching mask: EventTypeMask, handler block: @escaping (NSEvent) -> NSEvent?) -> Any? {
    _Monitor(number: FakeMac.current.addMonitor(global: false, mask: mask.rawValue) { type, flags, location in _ = block(_event(type, flags, location)) })
  }
  open class func removeMonitor(_ eventMonitor: Any) {
    if let monitor = eventMonitor as? _Monitor { FakeMac.current.removeMonitor(monitor.number) }
  }
  open class func mouseEvent(
    with type: EventType, location: NSPoint, modifierFlags flags: ModifierFlags, timestamp time: TimeInterval, windowNumber wNum: Int,
    context unusedPassNil: NSGraphicsContext?, eventNumber eNum: Int, clickCount cNum: Int, pressure: Float
  ) -> NSEvent? { nil }
  open class func keyEvent(
    with type: EventType, location: NSPoint, modifierFlags flags: ModifierFlags, timestamp time: TimeInterval, windowNumber wNum: Int,
    context unusedPassNil: NSGraphicsContext?, characters keys: String, charactersIgnoringModifiers ukeys: String, isARepeat flag: Bool,
    keyCode code: UInt16
  ) -> NSEvent? { nil }
  open class func otherEvent(
    with type: EventType, location: NSPoint, modifierFlags flags: ModifierFlags, timestamp time: TimeInterval, windowNumber wNum: Int,
    context unusedPassNil: NSGraphicsContext?, subtype: Int16, data1 d1: Int, data2 d2: Int
  ) -> NSEvent? { nil }
}

open class NSTouch: NSObject {
  public struct Phase: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let began = Phase(rawValue: 1)
    public static let moved = Phase(rawValue: 2)
    public static let stationary = Phase(rawValue: 4)
    public static let ended = Phase(rawValue: 8)
    public static let cancelled = Phase(rawValue: 16)
    public static let touching = Phase(rawValue: 7)
    public static let any = Phase(rawValue: UInt.max)
  }
  public struct TouchTypeMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let direct = TouchTypeMask(rawValue: 1)
    public static let indirect = TouchTypeMask(rawValue: 2)
  }
  open var identity: any NSCopying & NSObjectProtocol { NSString() }
  open var phase: Phase { [] }
  open var normalizedPosition: NSPoint { .zero }
  open var isResting: Bool { false }
  open var deviceSize: NSSize { .zero }
}

@MainActor open class NSResponder: NSObject {
  public override init() {}
  public init?(coder: NSCoder) {}
  open var nextResponder: NSResponder?
  open var acceptsFirstResponder: Bool { false }
  open func becomeFirstResponder() -> Bool { true }
  open func resignFirstResponder() -> Bool { true }
  open var menu: NSMenu?
  open var undoManager: UndoManager? { nil }
  open func mouseDown(with event: NSEvent) {}
  open func rightMouseDown(with event: NSEvent) {}
  open func otherMouseDown(with event: NSEvent) {}
  open func mouseUp(with event: NSEvent) {}
  open func rightMouseUp(with event: NSEvent) {}
  open func otherMouseUp(with event: NSEvent) {}
  open func mouseMoved(with event: NSEvent) {}
  open func mouseDragged(with event: NSEvent) {}
  open func rightMouseDragged(with event: NSEvent) {}
  open func otherMouseDragged(with event: NSEvent) {}
  open func scrollWheel(with event: NSEvent) {}
  open func mouseEntered(with event: NSEvent) {}
  open func mouseExited(with event: NSEvent) {}
  open func cursorUpdate(with event: NSEvent) {}
  open func keyDown(with event: NSEvent) {}
  open func keyUp(with event: NSEvent) {}
  open func flagsChanged(with event: NSEvent) {}
  open func magnify(with event: NSEvent) {}
  open func rotate(with event: NSEvent) {}
  open func swipe(with event: NSEvent) {}
  open func beginGesture(with event: NSEvent) {}
  open func endGesture(with event: NSEvent) {}
  open func smartMagnify(with event: NSEvent) {}
  open func pressureChange(with event: NSEvent) {}
  open func touchesBegan(with event: NSEvent) {}
  open func touchesMoved(with event: NSEvent) {}
  open func touchesEnded(with event: NSEvent) {}
  open func touchesCancelled(with event: NSEvent) {}
  open func performKeyEquivalent(with event: NSEvent) -> Bool { false }
  open func interpretKeyEvents(_ eventArray: [NSEvent]) {}
  open func doCommand(by selector: Selector) {}
  open func tryToPerform(_ action: Selector, with object: Any?) -> Bool { false }
  open func noResponder(for eventSelector: Selector) {}
  open func cancelOperation(_ sender: Any?) {}
  open func insertText(_ insertString: Any) {}
  open func insertNewline(_ sender: Any?) {}
  open func insertTab(_ sender: Any?) {}
  open func insertBacktab(_ sender: Any?) {}
  open func deleteBackward(_ sender: Any?) {}
  open func moveUp(_ sender: Any?) {}
  open func moveDown(_ sender: Any?) {}
  open func moveLeft(_ sender: Any?) {}
  open func moveRight(_ sender: Any?) {}
  open func selectAll(_ sender: Any?) {}
  open func complete(_ sender: Any?) {}
  // The rest of what a key binding can send (NSStandardKeyBindingResponding).
  open func insertLineBreak(_ sender: Any?) {}
  open func insertParagraphSeparator(_ sender: Any?) {}
  open func insertNewlineIgnoringFieldEditor(_ sender: Any?) {}
  open func insertTabIgnoringFieldEditor(_ sender: Any?) {}
  open func insertContainerBreak(_ sender: Any?) {}
  open func insertSingleQuoteIgnoringSubstitution(_ sender: Any?) {}
  open func insertDoubleQuoteIgnoringSubstitution(_ sender: Any?) {}
  open func moveForward(_ sender: Any?) {}
  open func moveBackward(_ sender: Any?) {}
  open func moveWordForward(_ sender: Any?) {}
  open func moveWordBackward(_ sender: Any?) {}
  open func moveToBeginningOfLine(_ sender: Any?) {}
  open func moveToEndOfLine(_ sender: Any?) {}
  open func moveToBeginningOfParagraph(_ sender: Any?) {}
  open func moveToEndOfParagraph(_ sender: Any?) {}
  open func moveToEndOfDocument(_ sender: Any?) {}
  open func moveToBeginningOfDocument(_ sender: Any?) {}
  open func pageDown(_ sender: Any?) {}
  open func pageUp(_ sender: Any?) {}
  open func centerSelectionInVisibleArea(_ sender: Any?) {}
  open func moveBackwardAndModifySelection(_ sender: Any?) {}
  open func moveForwardAndModifySelection(_ sender: Any?) {}
  open func moveWordForwardAndModifySelection(_ sender: Any?) {}
  open func moveWordBackwardAndModifySelection(_ sender: Any?) {}
  open func moveUpAndModifySelection(_ sender: Any?) {}
  open func moveDownAndModifySelection(_ sender: Any?) {}
  open func moveToBeginningOfLineAndModifySelection(_ sender: Any?) {}
  open func moveToEndOfLineAndModifySelection(_ sender: Any?) {}
  open func moveToBeginningOfParagraphAndModifySelection(_ sender: Any?) {}
  open func moveToEndOfParagraphAndModifySelection(_ sender: Any?) {}
  open func moveToEndOfDocumentAndModifySelection(_ sender: Any?) {}
  open func moveToBeginningOfDocumentAndModifySelection(_ sender: Any?) {}
  open func pageDownAndModifySelection(_ sender: Any?) {}
  open func pageUpAndModifySelection(_ sender: Any?) {}
  open func moveParagraphForwardAndModifySelection(_ sender: Any?) {}
  open func moveParagraphBackwardAndModifySelection(_ sender: Any?) {}
  open func moveWordRight(_ sender: Any?) {}
  open func moveWordLeft(_ sender: Any?) {}
  open func moveRightAndModifySelection(_ sender: Any?) {}
  open func moveLeftAndModifySelection(_ sender: Any?) {}
  open func moveWordRightAndModifySelection(_ sender: Any?) {}
  open func moveWordLeftAndModifySelection(_ sender: Any?) {}
  open func moveToLeftEndOfLine(_ sender: Any?) {}
  open func moveToRightEndOfLine(_ sender: Any?) {}
  open func moveToLeftEndOfLineAndModifySelection(_ sender: Any?) {}
  open func moveToRightEndOfLineAndModifySelection(_ sender: Any?) {}
  open func scrollPageUp(_ sender: Any?) {}
  open func scrollPageDown(_ sender: Any?) {}
  open func scrollLineUp(_ sender: Any?) {}
  open func scrollLineDown(_ sender: Any?) {}
  open func scrollToBeginningOfDocument(_ sender: Any?) {}
  open func scrollToEndOfDocument(_ sender: Any?) {}
  open func transpose(_ sender: Any?) {}
  open func transposeWords(_ sender: Any?) {}
  open func selectParagraph(_ sender: Any?) {}
  open func selectLine(_ sender: Any?) {}
  open func selectWord(_ sender: Any?) {}
  open func indent(_ sender: Any?) {}
  open func changeCaseOfLetter(_ sender: Any?) {}
  open func uppercaseWord(_ sender: Any?) {}
  open func lowercaseWord(_ sender: Any?) {}
  open func capitalizeWord(_ sender: Any?) {}
  open func deleteForward(_ sender: Any?) {}
  open func deleteBackwardByDecomposingPreviousCharacter(_ sender: Any?) {}
  open func deleteWordForward(_ sender: Any?) {}
  open func deleteWordBackward(_ sender: Any?) {}
  open func deleteToBeginningOfLine(_ sender: Any?) {}
  open func deleteToEndOfLine(_ sender: Any?) {}
  open func deleteToBeginningOfParagraph(_ sender: Any?) {}
  open func deleteToEndOfParagraph(_ sender: Any?) {}
  open func yank(_ sender: Any?) {}
  open func setMark(_ sender: Any?) {}
  open func deleteToMark(_ sender: Any?) {}
  open func selectToMark(_ sender: Any?) {}
  open func swapWithMark(_ sender: Any?) {}
  open func makeBaseWritingDirectionNatural(_ sender: Any?) {}
  open func makeBaseWritingDirectionLeftToRight(_ sender: Any?) {}
  open func makeBaseWritingDirectionRightToLeft(_ sender: Any?) {}
  open func makeTextWritingDirectionNatural(_ sender: Any?) {}
  open func makeTextWritingDirectionLeftToRight(_ sender: Any?) {}
  open func makeTextWritingDirectionRightToLeft(_ sender: Any?) {}
  open func quickLookPreviewItems(_ sender: Any?) {}
  open func showContextMenuForSelection(_ sender: Any?) {}
  @discardableResult open func presentError(_ error: any Error) -> Bool { false }
  open func supplementalTarget(forAction action: Selector, sender: Any?) -> Any? { nil }
}

open class NSTrackingArea: NSObject {
  public struct Options: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let mouseEnteredAndExited = Options(rawValue: 0x01)
    public static let mouseMoved = Options(rawValue: 0x02)
    public static let cursorUpdate = Options(rawValue: 0x04)
    public static let activeWhenFirstResponder = Options(rawValue: 0x10)
    public static let activeInKeyWindow = Options(rawValue: 0x20)
    public static let activeInActiveApp = Options(rawValue: 0x40)
    public static let activeAlways = Options(rawValue: 0x80)
    public static let assumeInside = Options(rawValue: 0x100)
    public static let inVisibleRect = Options(rawValue: 0x200)
    public static let enabledDuringMouseDrag = Options(rawValue: 0x400)
  }
  public init(rect: NSRect, options: Options = [], owner: Any?, userInfo: [AnyHashable: Any]? = nil) {}
  open var rect: NSRect { .zero }
  open var options: Options { [] }
  open var owner: Any? { nil }
  open var userInfo: [AnyHashable: Any]? { nil }
}

@MainActor open class NSGestureRecognizer: NSObject {
  public enum State: Int, Sendable {
    case possible = 0, began = 1, changed = 2, ended = 3, cancelled = 4, failed = 5
    public static var recognized: State { .ended }
  }
  public init(target: Any?, action: Selector?) {}
  public init?(coder: NSCoder) {}
  open weak var target: AnyObject?
  open var action: Selector?
  open var state: State = .possible
  open var isEnabled = true
  open var view: NSView? { nil }
  open var delaysPrimaryMouseButtonEvents = false
  open func location(in view: NSView?) -> NSPoint { .zero }
}
@MainActor open class NSClickGestureRecognizer: NSGestureRecognizer {
  open var buttonMask = 1
  open var numberOfClicksRequired = 1
}
@MainActor open class NSPanGestureRecognizer: NSGestureRecognizer {
  open var buttonMask = 1
  open func translation(in view: NSView?) -> NSPoint { .zero }
  open func setTranslation(_ translation: NSPoint, in view: NSView?) {}
  open func velocity(in view: NSView?) -> NSPoint { .zero }
}
@MainActor open class NSMagnificationGestureRecognizer: NSGestureRecognizer {
  open var magnification: CGFloat = 0
}
@MainActor open class NSPressGestureRecognizer: NSGestureRecognizer {
  open var buttonMask = 1
  open var minimumPressDuration: TimeInterval = 0.5
  open var allowableMovement: CGFloat = 10
}

// MARK: Keys without a character of their own, and the characters of the others. Untyped enums in the headers, so `Int` here as there.

public let NSUpArrowFunctionKey = 0xF700
public let NSDownArrowFunctionKey = 0xF701
public let NSLeftArrowFunctionKey = 0xF702
public let NSRightArrowFunctionKey = 0xF703
public let NSF1FunctionKey = 0xF704
public let NSF2FunctionKey = 0xF705
public let NSF3FunctionKey = 0xF706
public let NSF4FunctionKey = 0xF707
public let NSF5FunctionKey = 0xF708
public let NSF6FunctionKey = 0xF709
public let NSF7FunctionKey = 0xF70A
public let NSF8FunctionKey = 0xF70B
public let NSF9FunctionKey = 0xF70C
public let NSF10FunctionKey = 0xF70D
public let NSF11FunctionKey = 0xF70E
public let NSF12FunctionKey = 0xF70F
public let NSF13FunctionKey = 0xF710
public let NSF14FunctionKey = 0xF711
public let NSF15FunctionKey = 0xF712
public let NSF16FunctionKey = 0xF713
public let NSF17FunctionKey = 0xF714
public let NSF18FunctionKey = 0xF715
public let NSF19FunctionKey = 0xF716
public let NSF20FunctionKey = 0xF717
public let NSF21FunctionKey = 0xF718
public let NSF22FunctionKey = 0xF719
public let NSF23FunctionKey = 0xF71A
public let NSF24FunctionKey = 0xF71B
public let NSF25FunctionKey = 0xF71C
public let NSF26FunctionKey = 0xF71D
public let NSF27FunctionKey = 0xF71E
public let NSF28FunctionKey = 0xF71F
public let NSF29FunctionKey = 0xF720
public let NSF30FunctionKey = 0xF721
public let NSF31FunctionKey = 0xF722
public let NSF32FunctionKey = 0xF723
public let NSF33FunctionKey = 0xF724
public let NSF34FunctionKey = 0xF725
public let NSF35FunctionKey = 0xF726
public let NSInsertFunctionKey = 0xF727
public let NSDeleteFunctionKey = 0xF728
public let NSHomeFunctionKey = 0xF729
public let NSBeginFunctionKey = 0xF72A
public let NSEndFunctionKey = 0xF72B
public let NSPageUpFunctionKey = 0xF72C
public let NSPageDownFunctionKey = 0xF72D
public let NSPrintScreenFunctionKey = 0xF72E
public let NSScrollLockFunctionKey = 0xF72F
public let NSPauseFunctionKey = 0xF730
public let NSSysReqFunctionKey = 0xF731
public let NSBreakFunctionKey = 0xF732
public let NSResetFunctionKey = 0xF733
public let NSStopFunctionKey = 0xF734
public let NSMenuFunctionKey = 0xF735
public let NSUserFunctionKey = 0xF736
public let NSSystemFunctionKey = 0xF737
public let NSPrintFunctionKey = 0xF738
public let NSClearLineFunctionKey = 0xF739
public let NSClearDisplayFunctionKey = 0xF73A
public let NSInsertLineFunctionKey = 0xF73B
public let NSDeleteLineFunctionKey = 0xF73C
public let NSInsertCharFunctionKey = 0xF73D
public let NSDeleteCharFunctionKey = 0xF73E
public let NSPrevFunctionKey = 0xF73F
public let NSNextFunctionKey = 0xF740
public let NSSelectFunctionKey = 0xF741
public let NSExecuteFunctionKey = 0xF742
public let NSUndoFunctionKey = 0xF743
public let NSRedoFunctionKey = 0xF744
public let NSFindFunctionKey = 0xF745
public let NSHelpFunctionKey = 0xF746
public let NSModeSwitchFunctionKey = 0xF747
public let NSEnterCharacter = 0x0003
public let NSBackspaceCharacter = 0x0008
public let NSTabCharacter = 0x0009
public let NSNewlineCharacter = 0x000A
public let NSFormFeedCharacter = 0x000C
public let NSCarriageReturnCharacter = 0x000D
public let NSBackTabCharacter = 0x0019
public let NSDeleteCharacter = 0x007F
public let NSLineSeparatorCharacter = 0x2028
public let NSParagraphSeparatorCharacter = 0x2029
