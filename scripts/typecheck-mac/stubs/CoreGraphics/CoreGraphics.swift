// A stand-in for CoreGraphics (scripts/typecheck-mac/README.md). Never shipped. Signatures as in the macOS 14 SDK. The window list, the event source's
// figures and the displays' identity ask the model of a Mac (stubs/FakeMacOS), for `make mac-on-linux`; the rest does nothing.
// The geometry types (CGRect and company) are Foundation's.
import FakeMacOS
@_exported import MacFoundation

public typealias boolean_t = UInt32

// MARK: Windows and displays

public typealias CGWindowID = UInt32
public typealias CGDirectDisplayID = UInt32
public typealias CGWindowLevel = Int32
public let kCGNullWindowID: CGWindowID = 0
public let kCGNullDirectDisplay: CGDirectDisplayID = 0
public struct CGWindowListOption: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let optionAll = CGWindowListOption([])
  public static let optionOnScreenOnly = CGWindowListOption(rawValue: 1)
  public static let optionOnScreenAboveWindow = CGWindowListOption(rawValue: 2)
  public static let optionOnScreenBelowWindow = CGWindowListOption(rawValue: 4)
  public static let optionIncludingWindow = CGWindowListOption(rawValue: 8)
  public static let excludeDesktopElements = CGWindowListOption(rawValue: 16)
}
public struct CGWindowImageOption: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let boundsIgnoreFraming = CGWindowImageOption(rawValue: 1)
  public static let shouldBeOpaque = CGWindowImageOption(rawValue: 2)
  public static let onlyShadows = CGWindowImageOption(rawValue: 4)
  public static let bestResolution = CGWindowImageOption(rawValue: 8)
  public static let nominalResolution = CGWindowImageOption(rawValue: 16)
}
public func CGWindowListCopyWindowInfo(_ option: CGWindowListOption, _ relativeToWindow: CGWindowID) -> CFArray? {
  let list = FakeMac.current.windowList(
    onScreenOnly: option.contains(.optionOnScreenOnly), withoutDesktop: option.contains(.excludeDesktopElements),
    only: option.contains(.optionIncludingWindow) ? relativeToWindow : nil)
  guard let list else { return nil }
  return list.map { window -> NSDictionary in
    let info = NSMutableDictionary()
    info[kCGWindowNumber] = NSNumber(value: window.number)
    info[kCGWindowOwnerPID] = NSNumber(value: window.pid)
    info[kCGWindowOwnerName] = window.ownerName as NSString
    info[kCGWindowLayer] = NSNumber(value: window.layer)
    info[kCGWindowAlpha] = NSNumber(value: window.alpha)
    info[kCGWindowBounds] = window.bounds.dictionaryRepresentation
    // The key is there only for a window that shows.
    if window.isOnScreen { info[kCGWindowIsOnscreen] = NSNumber(value: true) }
    return info
  } as NSArray
}
public func CGWindowListCreateDescriptionFromArray(_ windowArray: CFArray?) -> CFArray? { nil }
@available(*, unavailable, message: "the macOS 15 SDK took it away: use ScreenCaptureKit")
public func CGWindowListCreateImage(
  _ screenBounds: CGRect, _ listOption: CGWindowListOption, _ windowID: CGWindowID, _ imageOption: CGWindowImageOption
) -> CGImage? { nil }
@available(*, unavailable, message: "the macOS 15 SDK took it away: use ScreenCaptureKit")
public func CGDisplayCreateImage(_ displayID: CGDirectDisplayID) -> CGImage? { nil }
public nonisolated(unsafe) let kCGWindowNumber: CFString = "kCGWindowNumber"
public nonisolated(unsafe) let kCGWindowStoreType: CFString = "kCGWindowStoreType"
public nonisolated(unsafe) let kCGWindowLayer: CFString = "kCGWindowLayer"
public nonisolated(unsafe) let kCGWindowBounds: CFString = "kCGWindowBounds"
public nonisolated(unsafe) let kCGWindowSharingState: CFString = "kCGWindowSharingState"
public nonisolated(unsafe) let kCGWindowAlpha: CFString = "kCGWindowAlpha"
public nonisolated(unsafe) let kCGWindowOwnerPID: CFString = "kCGWindowOwnerPID"
public nonisolated(unsafe) let kCGWindowMemoryUsage: CFString = "kCGWindowMemoryUsage"
public nonisolated(unsafe) let kCGWindowOwnerName: CFString = "kCGWindowOwnerName"
public nonisolated(unsafe) let kCGWindowName: CFString = "kCGWindowName"
public nonisolated(unsafe) let kCGWindowIsOnscreen: CFString = "kCGWindowIsOnscreen"
public enum CGWindowLevelKey: Int32, Sendable {
  case baseWindow = 0, minimumWindow, desktopWindow, backstopMenu, normalWindow, floatingWindow, tornOffMenuWindow, dockWindow, mainMenuWindow,
    statusWindow, modalPanelWindow, popUpMenuWindow, draggingWindow, screenSaverWindow, maximumWindow, overlayWindow, helpWindow, utilityWindow,
    desktopIconWindow, cursorWindow, assistiveTechHighWindow, numberOfWindowLevelKeys
}
public func CGWindowLevelForKey(_ key: CGWindowLevelKey) -> CGWindowLevel { 0 }
public func CGShieldingWindowLevel() -> CGWindowLevel { 0 }
public func CGPreflightScreenCaptureAccess() -> Bool { false }
@discardableResult public func CGRequestScreenCaptureAccess() -> Bool { false }
public func CGPreflightListenEventAccess() -> Bool { false }
@discardableResult public func CGRequestListenEventAccess() -> Bool { false }
public func CGPreflightPostEventAccess() -> Bool { false }
@discardableResult public func CGRequestPostEventAccess() -> Bool { false }

public enum CGError: Int32, Sendable {
  case success = 0, failure = 1000, illegalArgument = 1001, invalidConnection = 1002, invalidContext = 1003, cannotComplete = 1004,
    notImplemented = 1006, rangeCheck = 1007, typeCheck = 1008, invalidOperation = 1010, noneAvailable = 1011
}
@discardableResult public func CGGetActiveDisplayList(
  _ maxDisplays: UInt32, _ activeDisplays: UnsafeMutablePointer<CGDirectDisplayID>?, _ displayCount: UnsafeMutablePointer<UInt32>?
) -> CGError { .success }
@discardableResult public func CGGetOnlineDisplayList(
  _ maxDisplays: UInt32, _ onlineDisplays: UnsafeMutablePointer<CGDirectDisplayID>?, _ displayCount: UnsafeMutablePointer<UInt32>?
) -> CGError { .success }
@discardableResult public func CGGetDisplaysWithPoint(
  _ point: CGPoint, _ maxDisplays: UInt32, _ displays: UnsafeMutablePointer<CGDirectDisplayID>?,
  _ matchingDisplayCount: UnsafeMutablePointer<UInt32>?
) -> CGError { .success }
@discardableResult public func CGGetDisplaysWithRect(
  _ rect: CGRect, _ maxDisplays: UInt32, _ displays: UnsafeMutablePointer<CGDirectDisplayID>?,
  _ matchingDisplayCount: UnsafeMutablePointer<UInt32>?
) -> CGError { .success }
public func CGMainDisplayID() -> CGDirectDisplayID { 0 }
public func CGSessionCopyCurrentDictionary() -> CFDictionary? { nil }
public func CGDisplayBounds(_ display: CGDirectDisplayID) -> CGRect { .zero }
public func CGDisplayPixelsWide(_ display: CGDirectDisplayID) -> Int { 0 }
public func CGDisplayPixelsHigh(_ display: CGDirectDisplayID) -> Int { 0 }
public func CGDisplayScreenSize(_ display: CGDirectDisplayID) -> CGSize { .zero }
public func CGDisplayRotation(_ display: CGDirectDisplayID) -> Double { 0 }
public func CGDisplayIsActive(_ display: CGDirectDisplayID) -> boolean_t { 0 }
public func CGDisplayIsAsleep(_ display: CGDirectDisplayID) -> boolean_t { 0 }
public func CGDisplayIsOnline(_ display: CGDirectDisplayID) -> boolean_t { 0 }
public func CGDisplayIsMain(_ display: CGDirectDisplayID) -> boolean_t { 0 }
public func CGDisplayIsBuiltin(_ display: CGDirectDisplayID) -> boolean_t { FakeMac.current.screens.contains { $0.id == display && $0.isBuiltIn } ? 1 : 0 }
public func CGDisplayIsInMirrorSet(_ display: CGDirectDisplayID) -> boolean_t { 0 }
public func CGDisplayMirrorsDisplay(_ display: CGDirectDisplayID) -> CGDirectDisplayID { 0 }
public func CGDisplayVendorNumber(_ display: CGDirectDisplayID) -> UInt32 { 0 }
public func CGDisplayModelNumber(_ display: CGDirectDisplayID) -> UInt32 { 0 }
public func CGDisplaySerialNumber(_ display: CGDirectDisplayID) -> UInt32 { 0 }
public func CGDisplayUnitNumber(_ display: CGDirectDisplayID) -> UInt32 { 0 }
// ColorSync's, which ApplicationServices brings; here for convenience.
public func CGDisplayCreateUUIDFromDisplayID(_ display: CGDirectDisplayID) -> Unmanaged<CFUUID>? {
  guard FakeMac.current.screens.contains(where: { $0.id == display }) else { return nil }
  return Unmanaged.passRetained(CFUUID(_text: "00000000-0000-0000-0000-" + String(format: "%012d", Int(display))))
}
public func CGDisplayGetDisplayIDFromUUID(_ uuid: CFUUID) -> CGDirectDisplayID { 0 }
public final class CGDisplayMode {
  public var width: Int { 0 }
  public var height: Int { 0 }
  public var pixelWidth: Int { 0 }
  public var pixelHeight: Int { 0 }
  public var refreshRate: Double { 0 }
  public var ioDisplayModeID: Int32 { 0 }
  public func isUsableForDesktopGUI() -> Bool { false }
}
public func CGDisplayCopyDisplayMode(_ display: CGDirectDisplayID) -> CGDisplayMode? { nil }
public nonisolated(unsafe) let kCGDisplayShowDuplicateLowResolutionModes: CFString = "kCGDisplayResolution"
public func CGDisplayCopyAllDisplayModes(_ display: CGDirectDisplayID, _ options: CFDictionary?) -> CFArray? { nil }
public typealias CGDisplayConfigRef = OpaquePointer
public struct CGConfigureOption: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let forAppOnly = CGConfigureOption([])
  public static let forSession = CGConfigureOption(rawValue: 1)
  public static let permanently = CGConfigureOption(rawValue: 2)
}
public func CGBeginDisplayConfiguration(_ config: UnsafeMutablePointer<CGDisplayConfigRef?>?) -> CGError { .failure }
public func CGConfigureDisplayWithDisplayMode(
  _ config: CGDisplayConfigRef?, _ display: CGDirectDisplayID, _ mode: CGDisplayMode?, _ options: CFDictionary?) -> CGError { .failure }
public func CGCompleteDisplayConfiguration(_ config: CGDisplayConfigRef?, _ option: CGConfigureOption) -> CGError { .failure }
public func CGCancelDisplayConfiguration(_ config: CGDisplayConfigRef?) -> CGError { .failure }
public struct CGDisplayChangeSummaryFlags: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let beginConfigurationFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 0)
  public static let movedFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 1)
  public static let setMainFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 2)
  public static let setModeFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 3)
  public static let addFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 4)
  public static let removeFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 5)
  public static let enabledFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 8)
  public static let disabledFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 9)
  public static let mirrorFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 10)
  public static let unMirrorFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 11)
  public static let desktopShapeChangedFlag = CGDisplayChangeSummaryFlags(rawValue: 1 << 12)
}
/// `@convention(c)` on the Mac: it must not capture anything. See the README.
public typealias CGDisplayReconfigurationCallBack = (CGDirectDisplayID, CGDisplayChangeSummaryFlags, UnsafeMutableRawPointer?) -> Void
@discardableResult public func CGDisplayRegisterReconfigurationCallback(
  _ callback: CGDisplayReconfigurationCallBack?, _ userInfo: UnsafeMutableRawPointer?
) -> CGError { .success }
@discardableResult public func CGDisplayRemoveReconfigurationCallback(
  _ callback: CGDisplayReconfigurationCallBack?, _ userInfo: UnsafeMutableRawPointer?
) -> CGError { .success }
@discardableResult public func CGWarpMouseCursorPosition(_ newCursorPosition: CGPoint) -> CGError { .success }
@discardableResult public func CGAssociateMouseAndMouseCursorPosition(_ connected: boolean_t) -> CGError { .success }
@discardableResult public func CGDisplayMoveCursorToPoint(_ display: CGDirectDisplayID, _ point: CGPoint) -> CGError { .success }
@discardableResult public func CGDisplayHideCursor(_ display: CGDirectDisplayID) -> CGError { .success }
@discardableResult public func CGDisplayShowCursor(_ display: CGDirectDisplayID) -> CGError { .success }

// MARK: Events

public typealias CGKeyCode = UInt16
public typealias CGCharCode = UInt16
public typealias CGEventMask = UInt64
public typealias CGEventTimestamp = UInt64
public typealias CGEventTapProxy = OpaquePointer
public enum CGEventType: UInt32, Sendable {
  case null = 0, leftMouseDown = 1, leftMouseUp = 2, rightMouseDown = 3, rightMouseUp = 4, mouseMoved = 5, leftMouseDragged = 6,
    rightMouseDragged = 7, keyDown = 10, keyUp = 11, flagsChanged = 12, scrollWheel = 22, tabletPointer = 23, tabletProximity = 24,
    otherMouseDown = 25, otherMouseUp = 26, otherMouseDragged = 27, tapDisabledByTimeout = 0xFFFF_FFFE, tapDisabledByUserInput = 0xFFFF_FFFF
}
public enum CGMouseButton: UInt32, Sendable { case left = 0, right = 1, center = 2 }
public enum CGScrollEventUnit: UInt32, Sendable { case pixel = 0, line = 1 }
public enum CGEventSourceStateID: Int32, Sendable { case privateState = -1, combinedSessionState = 0, hidSystemState = 1 }
public enum CGEventTapLocation: UInt32, Sendable { case cghidEventTap = 0, cgSessionEventTap = 1, cgAnnotatedSessionEventTap = 2 }
public enum CGEventTapPlacement: UInt32, Sendable { case headInsertEventTap = 0, tailAppendEventTap = 1 }
public enum CGEventTapOptions: UInt32, Sendable { case defaultTap = 0, listenOnly = 1 }
/// A C struct, so it has the initializer that sets everything to zero.
public struct CGEventTapInformation {
  public var eventTapID: UInt32 = 0
  public var tapPoint: CGEventTapLocation = .cghidEventTap
  public var options: CGEventTapOptions = .defaultTap
  public var eventsOfInterest: CGEventMask = 0
  public var tappingProcess: pid_t = 0
  public var processBeingTapped: pid_t = 0
  public var enabled: Bool = false
  public var minUsecLatency: Float = 0
  public var avgUsecLatency: Float = 0
  public var maxUsecLatency: Float = 0
  public init() {}
}
@discardableResult public func CGGetEventTapList(
  _ maxNumberOfTaps: UInt32, _ tapList: UnsafeMutablePointer<CGEventTapInformation>?, _ eventTapCount: UnsafeMutablePointer<UInt32>?
) -> CGError { .failure }
public enum CGScrollPhase: UInt32, Sendable { case began = 1, changed = 2, ended = 4, cancelled = 8, mayBegin = 128 }
public enum CGMomentumScrollPhase: UInt32, Sendable { case none = 0, begin = 1, `continue` = 2, end = 3 }
public enum CGEventField: UInt32, Sendable {
  case mouseEventNumber = 0, mouseEventClickState = 1, mouseEventPressure = 2, mouseEventButtonNumber = 3, mouseEventDeltaX = 4,
    mouseEventDeltaY = 5, mouseEventInstantMouser = 6, mouseEventSubtype = 7, keyboardEventAutorepeat = 8, keyboardEventKeycode = 9,
    keyboardEventKeyboardType = 10, scrollWheelEventDeltaAxis1 = 11, scrollWheelEventDeltaAxis2 = 12, scrollWheelEventDeltaAxis3 = 13,
    scrollWheelEventFixedPtDeltaAxis1 = 93, scrollWheelEventFixedPtDeltaAxis2 = 94, scrollWheelEventFixedPtDeltaAxis3 = 95,
    scrollWheelEventPointDeltaAxis1 = 96, scrollWheelEventPointDeltaAxis2 = 97, scrollWheelEventPointDeltaAxis3 = 98,
    scrollWheelEventScrollPhase = 99, scrollWheelEventScrollCount = 100, scrollWheelEventMomentumPhase = 123,
    scrollWheelEventInstantMouser = 14, eventTargetProcessSerialNumber = 39, eventTargetUnixProcessID = 40, eventSourceUnixProcessID = 41,
    eventSourceUserData = 42, eventSourceUserID = 43, eventSourceGroupID = 44, eventSourceStateID = 45, scrollWheelEventIsContinuous = 88,
    mouseEventWindowUnderMousePointer = 91, mouseEventWindowUnderMousePointerThatCanHandleThisEvent = 92, eventUnacceleratedPointerMovementX = 170,
    eventUnacceleratedPointerMovementY = 171
}
public struct CGEventFlags: OptionSet, Sendable {
  public let rawValue: UInt64
  public init(rawValue: UInt64) { self.rawValue = rawValue }
  public static let maskAlphaShift = CGEventFlags(rawValue: 0x0001_0000)
  public static let maskShift = CGEventFlags(rawValue: 0x0002_0000)
  public static let maskControl = CGEventFlags(rawValue: 0x0004_0000)
  public static let maskAlternate = CGEventFlags(rawValue: 0x0008_0000)
  public static let maskCommand = CGEventFlags(rawValue: 0x0010_0000)
  public static let maskNumericPad = CGEventFlags(rawValue: 0x0020_0000)
  public static let maskHelp = CGEventFlags(rawValue: 0x0040_0000)
  public static let maskSecondaryFn = CGEventFlags(rawValue: 0x0080_0000)
  public static let maskNonCoalesced = CGEventFlags(rawValue: 0x0000_0100)
}
public struct CGEventFilterMask: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let permitLocalMouseEvents = CGEventFilterMask(rawValue: 1)
  public static let permitLocalKeyboardEvents = CGEventFilterMask(rawValue: 2)
  public static let permitSystemDefinedEvents = CGEventFilterMask(rawValue: 4)
}
public enum CGEventSuppressionState: UInt32, Sendable { case eventSuppressionStateSuppressionInterval = 0, eventSuppressionStateRemoteMouseDrag = 1 }
/// `@convention(c)` on the Mac: it must not capture anything. See the README.
public typealias CGEventTapCallBack = (CGEventTapProxy, CGEventType, CGEvent, UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>?
public final class CGEventSource {
  public init?(stateID: CGEventSourceStateID) {}
  public class func buttonState(_ stateID: CGEventSourceStateID, button: CGMouseButton) -> Bool { false }
  public class func keyState(_ stateID: CGEventSourceStateID, key: CGKeyCode) -> Bool { FakeMac.current.mouse.keysDown.contains(key) }
  public class func flagsState(_ stateID: CGEventSourceStateID) -> CGEventFlags { [] }
  public class func secondsSinceLastEventType(_ stateID: CGEventSourceStateID, eventType: CGEventType) -> CFTimeInterval {
    FakeMac.current.secondsSinceLastEvent(eventType.rawValue)
  }
  public class func counterForEventType(_ stateID: CGEventSourceStateID, eventType: CGEventType) -> UInt32 { FakeMac.current.eventCount(eventType.rawValue) }
  public var localEventsSuppressionInterval: CFTimeInterval = 0
  public var userData: Int64 = 0
  public var pixelsPerLine: Double = 0
  public var sourceStateID: CGEventSourceStateID { .privateState }
  public func setLocalEventsFilterDuringSuppressionState(_ filter: CGEventFilterMask, state: CGEventSuppressionState) {}
}
public final class CGEvent {
  public init?(source: CGEventSource?) {}
  public init?(mouseEventSource source: CGEventSource?, mouseType: CGEventType, mouseCursorPosition: CGPoint, mouseButton: CGMouseButton) {}
  public init?(keyboardEventSource source: CGEventSource?, virtualKey: CGKeyCode, keyDown: Bool) {}
  public init?(
    scrollWheelEvent2Source source: CGEventSource?, units: CGScrollEventUnit, wheelCount: UInt32, wheel1: Int32, wheel2: Int32, wheel3: Int32) {}
  public func copy() -> CGEvent? { nil }
  public var type: CGEventType = .null
  public var flags: CGEventFlags = []
  public var location: CGPoint = .zero
  public var unflippedLocation: CGPoint { .zero }
  public var timestamp: CGEventTimestamp = 0
  public func getIntegerValueField(_ field: CGEventField) -> Int64 { 0 }
  public func setIntegerValueField(_ field: CGEventField, value: Int64) {}
  public func getDoubleValueField(_ field: CGEventField) -> Double { 0 }
  public func setDoubleValueField(_ field: CGEventField, value: Double) {}
  public func setSource(_ source: CGEventSource?) {}
  public func post(tap: CGEventTapLocation) {}
  public func postToPid(_ pid: pid_t) {}
  public func tapPostEvent(_ proxy: CGEventTapProxy?) {}
  public func keyboardGetUnicodeString(
    maxStringLength: Int, actualStringLength: UnsafeMutablePointer<Int>?, unicodeString: UnsafeMutablePointer<UniChar>?) {}
  public func keyboardSetUnicodeString(stringLength: Int, unicodeString: UnsafePointer<UniChar>?) {}
  public class func tapCreate(
    tap: CGEventTapLocation, place: CGEventTapPlacement, options: CGEventTapOptions, eventsOfInterest: CGEventMask,
    callback: CGEventTapCallBack, userInfo: UnsafeMutableRawPointer?
  ) -> CFMachPort? { nil }
  public class func tapCreateForPid(
    pid: pid_t, place: CGEventTapPlacement, options: CGEventTapOptions, eventsOfInterest: CGEventMask, callback: CGEventTapCallBack,
    userInfo: UnsafeMutableRawPointer?
  ) -> CFMachPort? { nil }
  public class func tapEnable(tap: CFMachPort, enable: Bool) {}
  public class func tapIsEnabled(tap: CFMachPort) -> Bool { false }
}

// MARK: Geometry that Linux's Foundation leaves out

extension CGRect {
  public func equalTo(_ rect2: CGRect) -> Bool { self == rect2 }
  public init?(dictionaryRepresentation dict: CFDictionary) {
    func number(_ key: String) -> Double? { (dict[key] as? NSNumber)?.doubleValue }
    guard let x = number("X"), let y = number("Y"), let width = number("Width"), let height = number("Height") else { return nil }
    self.init(x: x, y: y, width: width, height: height)
  }
  public var dictionaryRepresentation: CFDictionary {
    ["X": NSNumber(value: Double(minX)), "Y": NSNumber(value: Double(minY)), "Width": NSNumber(value: Double(width)), "Height": NSNumber(value: Double(height))]
  }
  public func applying(_ t: CGAffineTransform) -> CGRect { self }
}
extension CGPoint {
  public func equalTo(_ point2: CGPoint) -> Bool { self == point2 }
  public init?(dictionaryRepresentation dict: CFDictionary) { return nil }
  public var dictionaryRepresentation: CFDictionary { [:] }
  public func applying(_ t: CGAffineTransform) -> CGPoint { self }
}
extension CGSize {
  public init?(dictionaryRepresentation dict: CFDictionary) { return nil }
  public var dictionaryRepresentation: CFDictionary { [:] }
  public func applying(_ t: CGAffineTransform) -> CGSize { self }
}
// Not Hashable: on the Mac that comes with macOS 15.
public struct CGVector: Equatable, Sendable, Codable {
  public var dx: CGFloat
  public var dy: CGFloat
  public static var zero: CGVector { CGVector(dx: 0, dy: 0) }
  public init() { dx = 0; dy = 0 }
  public init(dx: CGFloat, dy: CGFloat) { self.dx = dx; self.dy = dy }
  public init(dx: Double, dy: Double) { self.dx = CGFloat(dx); self.dy = CGFloat(dy) }
  public init(dx: Int, dy: Int) { self.dx = CGFloat(dx); self.dy = CGFloat(dy) }
}
public struct CGAffineTransform: Equatable, Sendable, Codable {
  public var a: CGFloat = 1, b: CGFloat = 0, c: CGFloat = 0, d: CGFloat = 1, tx: CGFloat = 0, ty: CGFloat = 0
  public static var identity: CGAffineTransform { CGAffineTransform() }
  public init() {}
  public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {}
  public init(translationX tx: CGFloat, y ty: CGFloat) {}
  public init(scaleX sx: CGFloat, y sy: CGFloat) {}
  public init(rotationAngle angle: CGFloat) {}
  public var isIdentity: Bool { true }
  public func translatedBy(x tx: CGFloat, y ty: CGFloat) -> CGAffineTransform { self }
  public func scaledBy(x sx: CGFloat, y sy: CGFloat) -> CGAffineTransform { self }
  public func rotated(by angle: CGFloat) -> CGAffineTransform { self }
  public func inverted() -> CGAffineTransform { self }
  public func concatenating(_ t2: CGAffineTransform) -> CGAffineTransform { self }
}

// MARK: Drawing. None of these classes is Sendable here. Newer SDKs say some are; code that does without compiles against both.

public enum CGLineCap: Int32, Sendable { case butt = 0, round = 1, square = 2 }
public enum CGLineJoin: Int32, Sendable { case miter = 0, round = 1, bevel = 2 }
public enum CGPathFillRule: Int, Sendable { case evenOdd = 0, winding = 1 }
public enum CGPathDrawingMode: Int32, Sendable { case fill = 0, eoFill = 1, stroke = 2, fillStroke = 3, eoFillStroke = 4 }
public enum CGInterpolationQuality: Int32, Sendable { case `default` = 0, none = 1, low = 2, medium = 4, high = 3 }
public enum CGColorRenderingIntent: Int32, Sendable { case defaultIntent = 0, absoluteColorimetric, relativeColorimetric, perceptual, saturation }
public enum CGBlendMode: Int32, Sendable {
  case normal = 0, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion, hue,
    saturation, color, luminosity, clear, copy, sourceIn, sourceOut, sourceAtop, destinationOver, destinationIn, destinationOut,
    destinationAtop, xor, plusDarker, plusLighter
}
public enum CGImageAlphaInfo: UInt32, Sendable {
  case none = 0, premultipliedLast, premultipliedFirst, last, first, noneSkipLast, noneSkipFirst, alphaOnly
}
public struct CGBitmapInfo: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let alphaInfoMask = CGBitmapInfo(rawValue: 0x1F)
  public static let floatComponents = CGBitmapInfo(rawValue: 1 << 8)
  public static let byteOrderMask = CGBitmapInfo(rawValue: 0x7000)
  public static let byteOrder16Little = CGBitmapInfo(rawValue: 1 << 12)
  public static let byteOrder32Little = CGBitmapInfo(rawValue: 2 << 12)
  public static let byteOrder16Big = CGBitmapInfo(rawValue: 3 << 12)
  public static let byteOrder32Big = CGBitmapInfo(rawValue: 4 << 12)
}
public struct CGGradientDrawingOptions: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let drawsBeforeStartLocation = CGGradientDrawingOptions(rawValue: 1)
  public static let drawsAfterEndLocation = CGGradientDrawingOptions(rawValue: 2)
}
public final class CGColorSpace {
  public init?(name: CFString) {}
  public nonisolated(unsafe) static let sRGB: CFString = "kCGColorSpaceSRGB"
  public nonisolated(unsafe) static let displayP3: CFString = "kCGColorSpaceDisplayP3"
  public nonisolated(unsafe) static let linearSRGB: CFString = "kCGColorSpaceLinearSRGB"
  public nonisolated(unsafe) static let extendedSRGB: CFString = "kCGColorSpaceExtendedSRGB"
  public nonisolated(unsafe) static let genericGrayGamma2_2: CFString = "kCGColorSpaceGenericGrayGamma2_2"
  public nonisolated(unsafe) static let genericRGBLinear: CFString = "kCGColorSpaceGenericRGBLinear"
  public var name: CFString? { nil }
  public var numberOfComponents: Int { 3 }
}
public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace { CGColorSpace(name: CGColorSpace.sRGB)! }
public func CGColorSpaceCreateDeviceGray() -> CGColorSpace { CGColorSpace(name: CGColorSpace.sRGB)! }
public final class CGColor {
  public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
  public init(gray: CGFloat, alpha: CGFloat) {}
  public init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
  public init(genericGrayGamma2_2Gray gray: CGFloat, alpha: CGFloat) {}
  public init?(colorSpace space: CGColorSpace, components: UnsafePointer<CGFloat>) {}
  public class var white: CGColor { CGColor(gray: 1, alpha: 1) }
  public class var black: CGColor { CGColor(gray: 0, alpha: 1) }
  public class var clear: CGColor { CGColor(gray: 0, alpha: 0) }
  public func copy() -> CGColor? { nil }
  public func copy(alpha: CGFloat) -> CGColor? { nil }
  public func converted(to space: CGColorSpace, intent: CGColorRenderingIntent, options: CFDictionary?) -> CGColor? { nil }
  public var alpha: CGFloat { 1 }
  public var components: [CGFloat]? { nil }
  public var numberOfComponents: Int { 4 }
  public var colorSpace: CGColorSpace? { nil }
}
extension CGColor: Equatable {
  public static func == (lhs: CGColor, rhs: CGColor) -> Bool { lhs === rhs }
}
public final class CGGradient {
  public init?(colorsSpace space: CGColorSpace?, colors: CFArray, locations: UnsafePointer<CGFloat>?) {}
  public init?(colorSpace space: CGColorSpace, colorComponents: UnsafePointer<CGFloat>, locations: UnsafePointer<CGFloat>?, count: Int) {}
}
public enum CGPathElementType: Int32, Sendable {
  case moveToPoint = 0, addLineToPoint, addQuadCurveToPoint, addCurveToPoint, closeSubpath
}
public struct CGPathElement {
  public var type: CGPathElementType
  public var points: UnsafeMutablePointer<CGPoint>
}
public class CGPath {
  init() {}
  public convenience init(rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) { self.init() }
  public convenience init(ellipseIn rect: CGRect, transform: UnsafePointer<CGAffineTransform>?) { self.init() }
  public convenience init(
    roundedRect rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat, transform: UnsafePointer<CGAffineTransform>?
  ) { self.init() }
  public func copy() -> CGPath? { nil }
  public func copy(using transform: UnsafePointer<CGAffineTransform>?) -> CGPath? { nil }
  public func mutableCopy() -> CGMutablePath? { nil }
  public func mutableCopy(using transform: UnsafePointer<CGAffineTransform>?) -> CGMutablePath? { nil }
  public func copy(
    strokingWithWidth lineWidth: CGFloat, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: CGFloat, transform: CGAffineTransform = .identity
  ) -> CGPath { self }
  public func copy(dashingWithPhase phase: CGFloat, lengths: [CGFloat], transform: CGAffineTransform = .identity) -> CGPath { self }
  public func contains(_ point: CGPoint, using rule: CGPathFillRule = .winding, transform: CGAffineTransform = .identity) -> Bool { false }
  public func applyWithBlock(_ block: (UnsafePointer<CGPathElement>) -> Void) {}
  public func union(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath { self }
  public func intersection(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath { self }
  public func subtracting(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath { self }
  public func symmetricDifference(_ other: CGPath, using rule: CGPathFillRule = .winding) -> CGPath { self }
  public func normalized(using rule: CGPathFillRule = .winding) -> CGPath { self }
  public var isEmpty: Bool { true }
  public var currentPoint: CGPoint { .zero }
  public var boundingBox: CGRect { .zero }
  public var boundingBoxOfPath: CGRect { .zero }
}
public final class CGMutablePath: CGPath {
  public override init() {}
  public func move(to point: CGPoint, transform: CGAffineTransform = .identity) {}
  public func addLine(to point: CGPoint, transform: CGAffineTransform = .identity) {}
  public func addLines(between points: [CGPoint], transform: CGAffineTransform = .identity) {}
  public func addRect(_ rect: CGRect, transform: CGAffineTransform = .identity) {}
  public func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) {}
  public func addRoundedRect(in rect: CGRect, cornerWidth: CGFloat, cornerHeight: CGFloat, transform: CGAffineTransform = .identity) {}
  public func addEllipse(in rect: CGRect, transform: CGAffineTransform = .identity) {}
  public func addArc(
    center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool, transform: CGAffineTransform = .identity) {}
  public func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat, transform: CGAffineTransform = .identity) {}
  public func addRelativeArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, delta: CGFloat, transform: CGAffineTransform = .identity) {}
  public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint, transform: CGAffineTransform = .identity) {}
  public func addQuadCurve(to end: CGPoint, control: CGPoint, transform: CGAffineTransform = .identity) {}
  public func addPath(_ path: CGPath, transform: CGAffineTransform = .identity) {}
  public func closeSubpath() {}
}
public final class CGDataProvider {
  public init?(data: CFData) {}
  public var data: CFData? { nil }
}
public final class CGImage {
  public init?(
    width: Int, height: Int, bitsPerComponent: Int, bitsPerPixel: Int, bytesPerRow: Int, space: CGColorSpace, bitmapInfo: CGBitmapInfo,
    provider: CGDataProvider, decode: UnsafePointer<CGFloat>?, shouldInterpolate: Bool, intent: CGColorRenderingIntent) {}
  public var width: Int { 0 }
  public var height: Int { 0 }
  public var bitsPerComponent: Int { 8 }
  public var bitsPerPixel: Int { 32 }
  public var bytesPerRow: Int { 0 }
  public var colorSpace: CGColorSpace? { nil }
  public var alphaInfo: CGImageAlphaInfo { .none }
  public var bitmapInfo: CGBitmapInfo { [] }
  public var dataProvider: CGDataProvider? { nil }
  public func copy() -> CGImage? { nil }
  public func copy(colorSpace space: CGColorSpace) -> CGImage? { nil }
  public func cropping(to rect: CGRect) -> CGImage? { nil }
  public func masking(_ mask: CGImage) -> CGImage? { nil }
}
public final class CGContext {
  public init?(
    data: UnsafeMutableRawPointer?, width: Int, height: Int, bitsPerComponent: Int, bytesPerRow: Int, space: CGColorSpace, bitmapInfo: UInt32) {}
  public var data: UnsafeMutableRawPointer? { nil }
  public var width: Int { 0 }
  public var height: Int { 0 }
  public var bytesPerRow: Int { 0 }
  public var ctm: CGAffineTransform { .identity }
  public var boundingBoxOfClipPath: CGRect { .zero }
  public var interpolationQuality: CGInterpolationQuality = .default
  public var path: CGPath? { nil }
  public func makeImage() -> CGImage? { nil }
  public func saveGState() {}
  public func restoreGState() {}
  public func translateBy(x tx: CGFloat, y ty: CGFloat) {}
  public func scaleBy(x sx: CGFloat, y sy: CGFloat) {}
  public func rotate(by angle: CGFloat) {}
  public func concatenate(_ transform: CGAffineTransform) {}
  public func setFillColor(_ color: CGColor) {}
  public func setStrokeColor(_ color: CGColor) {}
  public func setFillColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
  public func setStrokeColor(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
  public func setFillColor(gray: CGFloat, alpha: CGFloat) {}
  public func setStrokeColor(gray: CGFloat, alpha: CGFloat) {}
  public func setAlpha(_ alpha: CGFloat) {}
  public func setBlendMode(_ mode: CGBlendMode) {}
  public func setLineWidth(_ width: CGFloat) {}
  public func setLineCap(_ cap: CGLineCap) {}
  public func setLineJoin(_ join: CGLineJoin) {}
  public func setMiterLimit(_ limit: CGFloat) {}
  public func setLineDash(phase: CGFloat, lengths: [CGFloat]) {}
  public func setShouldAntialias(_ shouldAntialias: Bool) {}
  public func setAllowsAntialiasing(_ allowsAntialiasing: Bool) {}
  public func setShadow(offset: CGSize, blur: CGFloat, color: CGColor?) {}
  public func setShadow(offset: CGSize, blur: CGFloat) {}
  public func beginPath() {}
  public func closePath() {}
  public func move(to point: CGPoint) {}
  public func addLine(to point: CGPoint) {}
  public func addLines(between points: [CGPoint]) {}
  public func addRect(_ rect: CGRect) {}
  public func addRects(_ rects: [CGRect]) {}
  public func addEllipse(in rect: CGRect) {}
  public func addArc(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {}
  public func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {}
  public func addQuadCurve(to end: CGPoint, control: CGPoint) {}
  public func addPath(_ path: CGPath) {}
  public func fillPath(using rule: CGPathFillRule = .winding) {}
  public func strokePath() {}
  public func drawPath(using mode: CGPathDrawingMode) {}
  public func replacePathWithStrokedPath() {}
  public func fill(_ rect: CGRect) {}
  public func fill(_ rects: [CGRect]) {}
  public func stroke(_ rect: CGRect) {}
  public func stroke(_ rect: CGRect, width: CGFloat) {}
  public func clear(_ rect: CGRect) {}
  public func fillEllipse(in rect: CGRect) {}
  public func strokeEllipse(in rect: CGRect) {}
  public func strokeLineSegments(between points: [CGPoint]) {}
  public func clip(using rule: CGPathFillRule = .winding) {}
  public func clip(to rect: CGRect) {}
  public func clip(to rects: [CGRect]) {}
  public func clip(to rect: CGRect, mask: CGImage) {}
  public func resetClip() {}
  public func draw(_ image: CGImage, in rect: CGRect, byTiling: Bool = false) {}
  public func drawLinearGradient(_ gradient: CGGradient, start: CGPoint, end: CGPoint, options: CGGradientDrawingOptions) {}
  public func drawRadialGradient(
    _ gradient: CGGradient, startCenter: CGPoint, startRadius: CGFloat, endCenter: CGPoint, endRadius: CGFloat,
    options: CGGradientDrawingOptions) {}
  public func beginTransparencyLayer(auxiliaryInfo: CFDictionary?) {}
  public func beginTransparencyLayer(in rect: CGRect, auxiliaryInfo: CFDictionary?) {}
  public func endTransparencyLayer() {}
  public func flush() {}
  public func synchronize() {}
}
