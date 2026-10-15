// A stand-in for ApplicationServices (the Accessibility API), to type-check macOS-only code on Linux
// (scripts/typecheck-mac/README.md). Never shipped. The calls Arbor's Accessibility layer makes ask the model of a Mac (stubs/FakeMacOS), for
// `make mac-on-linux` (scripts/mac-on-linux/README.md); the others fail, as they always did.
@_exported import CoreGraphics
import FakeMacOS

public final class AXUIElement: NSObject, _CFTypeWithID {
  public static var _typeID: CFTypeID { AXUIElementGetTypeID() }
  var _stands = FakeMac.Element.nothing
  /// A timeout belongs to one element object: another object for the same window does not have it.
  var _timeout: TimeInterval?
  convenience init(_ stands: FakeMac.Element) {
    self.init()
    _stands = stands
  }
  // Two objects for the same thing are equal, as to CFEqual.
  public override func isEqual(_ object: Any?) -> Bool { (object as? AXUIElement)?._stands == _stands }
  public override var hash: Int { _stands.hashValue }
}
public final class AXObserver: NSObject {
  var _observer: FakeMac.Observer?
  let _source = CFRunLoopSource()
  deinit { if let _observer { FakeMac.current.retire(_observer) } }
}
public final class AXValue: NSObject, _CFTypeWithID {
  public static var _typeID: CFTypeID { AXValueGetTypeID() }
  enum Held { case point(CGPoint), size(CGSize), rect(CGRect), nothing }
  var _held = Held.nothing
  convenience init(_ held: Held) {
    self.init()
    _held = held
  }
}
extension AXError {
  init(_ answer: FakeMac.Answer) { self = AXError(rawValue: answer.rawValue) ?? .failure }
}
public enum AXError: Int32, Sendable {
  case success = 0
  case failure = -25200, illegalArgument = -25201, invalidUIElement = -25202, invalidUIElementObserver = -25203
  case cannotComplete = -25204, attributeUnsupported = -25205, actionUnsupported = -25206, notificationUnsupported = -25207
  case notImplemented = -25208, notificationAlreadyRegistered = -25209, notificationNotRegistered = -25210
  case apiDisabled = -25211, noValue = -25212, parameterizedAttributeUnsupported = -25213, notEnoughPrecision = -25214
}
public enum AXValueType: UInt32, Sendable { case cgPoint = 1, cgSize = 2, cgRect = 3, cfRange = 4, axError = 5, illegal = 0 }
public typealias AXObserverCallback = (AXObserver, AXUIElement, CFString, UnsafeMutableRawPointer?) -> Void

public func AXIsProcessTrusted() -> Bool { FakeMac.current.isTrusted }
@discardableResult public func AXIsProcessTrustedWithOptions(_ options: CFDictionary?) -> Bool { FakeMac.current.isTrusted }
@available(*, unavailable, message: "a global variable, which Swift 6 does not let anyone read: write the literal \"AXTrustedCheckOptionPrompt\"")
public var kAXTrustedCheckOptionPrompt: Unmanaged<CFString> { fatalError() }
public func AXUIElementGetTypeID() -> CFTypeID { 10 }
public func AXValueGetTypeID() -> CFTypeID { 11 }
public func AXUIElementCreateApplication(_ pid: pid_t) -> AXUIElement { AXUIElement(.app(pid)) }
public func AXUIElementCreateSystemWide() -> AXUIElement { AXUIElement(.systemWide) }
public func AXUIElementCopyAttributeValue(_ element: AXUIElement, _ attribute: CFString, _ value: UnsafeMutablePointer<CFTypeRef?>) -> AXError {
  let (answer, found) = FakeMac.current.read(attribute as String, of: element._stands, timeout: element._timeout)
  switch found {
  case .string(let text): value.pointee = text as NSString
  case .bool(let flag): value.pointee = flag ? kCFBooleanTrue : kCFBooleanFalse
  case .point(let point): value.pointee = AXValue(.point(point))
  case .size(let size): value.pointee = AXValue(.size(size))
  case .element(let other): value.pointee = AXUIElement(other)
  case .elements(let others): value.pointee = others.map { AXUIElement($0) } as NSArray
  case nil: break
  }
  return AXError(answer)
}
public func AXUIElementSetAttributeValue(_ element: AXUIElement, _ attribute: CFString, _ value: CFTypeRef) -> AXError {
  let given: FakeMac.Value
  switch value {
  case let flag as CFBoolean: given = .bool(CFBooleanGetValue(flag))
  case let text as NSString: given = .string(text as String)
  case let held as AXValue:
    switch held._held {
    case .point(let point): given = .point(point)
    case .size(let size): given = .size(size)
    case .rect, .nothing: return .illegalArgument
    }
  default: return .illegalArgument
  }
  return AXError(FakeMac.current.write(given, to: attribute as String, of: element._stands, timeout: element._timeout))
}
@discardableResult public func AXUIElementPerformAction(_ element: AXUIElement, _ action: CFString) -> AXError {
  AXError(FakeMac.current.perform(action as String, on: element._stands, timeout: element._timeout))
}
@discardableResult public func AXUIElementSetMessagingTimeout(_ element: AXUIElement, _ timeoutInSeconds: Float) -> AXError {
  if element._stands == .systemWide { FakeMac.current.setProcessTimeout(TimeInterval(timeoutInSeconds)) }
  element._timeout = TimeInterval(timeoutInSeconds)
  return .success
}
/// Answered from the element itself: it works for an app that hangs and for a window that is gone.
@discardableResult public func AXUIElementGetPid(_ element: AXUIElement, _ pid: UnsafeMutablePointer<pid_t>) -> AXError {
  guard let owner = element._stands.pid else { return .illegalArgument }
  pid.pointee = owner
  return .success
}
/// The private call Arbor declares for itself (Sources/ArborKit/AX/AXHelpers.swift). Nothing here can be called by this name; it is for the linker.
@_silgen_name("_AXUIElementGetWindow")
public func _standInForAXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError {
  let (answer, number) = FakeMac.current.windowNumber(of: element._stands, timeout: element._timeout)
  if answer == .success { identifier.pointee = number }
  return AXError(answer)
}
public struct AXCopyMultipleAttributeOptions: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let stopOnError = AXCopyMultipleAttributeOptions(rawValue: 1)
}
public func AXUIElementCopyMultipleAttributeValues(
  _ element: AXUIElement, _ attributes: CFArray, _ options: AXCopyMultipleAttributeOptions, _ values: UnsafeMutablePointer<CFArray?>
) -> AXError { .failure }
public func AXUIElementCopyAttributeNames(_ element: AXUIElement, _ names: UnsafeMutablePointer<CFArray?>) -> AXError { .failure }
public func AXUIElementCopyAttributeValues(
  _ element: AXUIElement, _ attribute: CFString, _ index: CFIndex, _ maxValues: CFIndex, _ values: UnsafeMutablePointer<CFArray?>
) -> AXError { .failure }
public func AXUIElementGetAttributeValueCount(_ element: AXUIElement, _ attribute: CFString, _ count: UnsafeMutablePointer<CFIndex>) -> AXError {
  .failure
}
public func AXUIElementIsAttributeSettable(_ element: AXUIElement, _ attribute: CFString, _ settable: UnsafeMutablePointer<DarwinBoolean>) -> AXError {
  let (answer, flag) = FakeMac.current.isSettable(attribute as String, of: element._stands, timeout: element._timeout)
  if answer == .success { settable.pointee = DarwinBoolean(flag) }
  return AXError(answer)
}
public func AXUIElementCopyParameterizedAttributeValue(
  _ element: AXUIElement, _ parameterizedAttribute: CFString, _ parameter: CFTypeRef, _ result: UnsafeMutablePointer<CFTypeRef?>
) -> AXError { .failure }
public func AXUIElementCopyActionNames(_ element: AXUIElement, _ names: UnsafeMutablePointer<CFArray?>) -> AXError { .failure }
public func AXUIElementCopyElementAtPosition(
  _ application: AXUIElement, _ x: Float, _ y: Float, _ element: UnsafeMutablePointer<AXUIElement?>
) -> AXError { .failure }
public func AXValueGetType(_ value: AXValue) -> AXValueType {
  switch value._held {
  case .point: .cgPoint
  case .size: .cgSize
  case .rect: .cgRect
  case .nothing: .illegal
  }
}
public func AXValueCreate(_ theType: AXValueType, _ valuePtr: UnsafeRawPointer) -> AXValue? {
  switch theType {
  case .cgPoint: AXValue(.point(valuePtr.load(as: CGPoint.self)))
  case .cgSize: AXValue(.size(valuePtr.load(as: CGSize.self)))
  case .cgRect: AXValue(.rect(valuePtr.load(as: CGRect.self)))
  case .cfRange, .axError, .illegal: nil
  }
}
@discardableResult public func AXValueGetValue(_ value: AXValue, _ theType: AXValueType, _ valuePtr: UnsafeMutableRawPointer) -> Bool {
  switch (value._held, theType) {
  case (.point(let point), .cgPoint): valuePtr.storeBytes(of: point, as: CGPoint.self)
  case (.size(let size), .cgSize): valuePtr.storeBytes(of: size, as: CGSize.self)
  case (.rect(let rect), .cgRect): valuePtr.storeBytes(of: rect, as: CGRect.self)
  default: return false
  }
  return true
}
public func AXObserverCreate(_ application: pid_t, _ callback: @escaping AXObserverCallback, _ outObserver: UnsafeMutablePointer<AXObserver?>) -> AXError {
  let made = AXObserver()
  let (answer, observer) = FakeMac.current.makeObserver(for: application) { [weak made] element, name, refcon in
    if let made { callback(made, AXUIElement(element), name as NSString, refcon) }
  }
  guard let observer else { return AXError(answer) }
  made._observer = observer
  made._source._onRunLoop = { [weak observer] isOn in observer?.isOnRunLoop = isOn }
  outObserver.pointee = made
  return .success
}
@discardableResult public func AXObserverAddNotification(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString, _ refcon: UnsafeMutableRawPointer?) -> AXError {
  guard let model = observer._observer else { return .invalidUIElementObserver }
  return AXError(FakeMac.current.register(model, for: notification as String, on: element._stands, refcon: refcon, timeout: element._timeout))
}
@discardableResult public func AXObserverRemoveNotification(_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString) -> AXError {
  guard let model = observer._observer else { return .invalidUIElementObserver }
  return AXError(FakeMac.current.unregister(model, from: notification as String, on: element._stands))
}
public func AXObserverGetRunLoopSource(_ observer: AXObserver) -> CFRunLoopSource { observer._source }

public let kAXRoleAttribute = "AXRole"
public let kAXSubroleAttribute = "AXSubrole"
public let kAXTitleAttribute = "AXTitle"
public let kAXPositionAttribute = "AXPosition"
public let kAXSizeAttribute = "AXSize"
public let kAXMinimizedAttribute = "AXMinimized"
public let kAXHiddenAttribute = "AXHidden"
public let kAXMainAttribute = "AXMain"
public let kAXFrontmostAttribute = "AXFrontmost"
public let kAXWindowsAttribute = "AXWindows"
public let kAXFocusedWindowAttribute = "AXFocusedWindow"
public let kAXMainWindowAttribute = "AXMainWindow"
public let kAXChildrenAttribute = "AXChildren"
public let kAXWindowRole = "AXWindow"
public let kAXStandardWindowSubrole = "AXStandardWindow"
public let kAXRaiseAction = "AXRaise"
public let kAXWindowCreatedNotification = "AXWindowCreated"
public let kAXFocusedWindowChangedNotification = "AXFocusedWindowChanged"
public let kAXMainWindowChangedNotification = "AXMainWindowChanged"
public let kAXFocusedUIElementChangedNotification = "AXFocusedUIElementChanged"
public let kAXApplicationActivatedNotification = "AXApplicationActivated"
public let kAXApplicationDeactivatedNotification = "AXApplicationDeactivated"
public let kAXApplicationHiddenNotification = "AXApplicationHidden"
public let kAXApplicationShownNotification = "AXApplicationShown"
public let kAXUIElementDestroyedNotification = "AXUIElementDestroyed"
public let kAXMovedNotification = "AXMoved"
public let kAXResizedNotification = "AXResized"
public let kAXWindowMiniaturizedNotification = "AXWindowMiniaturized"
public let kAXWindowDeminiaturizedNotification = "AXWindowDeminiaturized"
public let kAXTitleChangedNotification = "AXTitleChanged"
public let kAXCloseButtonAttribute = "AXCloseButton"
public let kAXMinimizeButtonAttribute = "AXMinimizeButton"
public let kAXZoomButtonAttribute = "AXZoomButton"
public let kAXFullScreenButtonAttribute = "AXFullScreenButton"
public let kAXDialogSubrole = "AXDialog"
public let kAXSystemDialogSubrole = "AXSystemDialog"
public let kAXTabGroupRole = "AXTabGroup"
public let kAXFocusedApplicationAttribute = "AXFocusedApplication"
public let kAXFocusedUIElementAttribute = "AXFocusedUIElement"
public let kAXParentAttribute = "AXParent"
public let kAXTopLevelUIElementAttribute = "AXTopLevelUIElement"
public let kAXWindowAttribute = "AXWindow"
public let kAXEnabledAttribute = "AXEnabled"
public let kAXFocusedAttribute = "AXFocused"
public let kAXIdentifierAttribute = "AXIdentifier"
public let kAXDescriptionAttribute = "AXDescription"
public let kAXRoleDescriptionAttribute = "AXRoleDescription"
public let kAXHelpAttribute = "AXHelp"
public let kAXValueAttribute = "AXValue"
public let kAXSelectedAttribute = "AXSelected"
public let kAXModalAttribute = "AXModal"
public let kAXDefaultButtonAttribute = "AXDefaultButton"
public let kAXCancelButtonAttribute = "AXCancelButton"
public let kAXToolbarButtonAttribute = "AXToolbarButton"
public let kAXGrowAreaAttribute = "AXGrowArea"
public let kAXProxyAttribute = "AXProxy"
public let kAXDocumentAttribute = "AXDocument"
public let kAXURLAttribute = "AXURL"
public let kAXTabsAttribute = "AXTabs"
public let kAXMenuBarAttribute = "AXMenuBar"
public let kAXMenuItemMarkCharAttribute = "AXMenuItemMarkChar"
public let kAXExtrasMenuBarAttribute = "AXExtrasMenuBar"
public let kAXTitleUIElementAttribute = "AXTitleUIElement"
public let kAXApplicationRole = "AXApplication"
public let kAXSheetRole = "AXSheet"
public let kAXDrawerRole = "AXDrawer"
public let kAXButtonRole = "AXButton"
public let kAXRadioButtonRole = "AXRadioButton"
public let kAXGroupRole = "AXGroup"
public let kAXToolbarRole = "AXToolbar"
public let kAXPopoverRole = "AXPopover"
public let kAXUnknownRole = "AXUnknown"
public let kAXSystemWideRole = "AXSystemWide"
public let kAXGrowAreaRole = "AXGrowArea"
public let kAXImageRole = "AXImage"
public let kAXCheckBoxRole = "AXCheckBox"
public let kAXPopUpButtonRole = "AXPopUpButton"
public let kAXMenuButtonRole = "AXMenuButton"
public let kAXTableRole = "AXTable"
public let kAXColumnRole = "AXColumn"
public let kAXRowRole = "AXRow"
public let kAXOutlineRole = "AXOutline"
public let kAXBrowserRole = "AXBrowser"
public let kAXScrollAreaRole = "AXScrollArea"
public let kAXScrollBarRole = "AXScrollBar"
public let kAXRadioGroupRole = "AXRadioGroup"
public let kAXListRole = "AXList"
public let kAXValueIndicatorRole = "AXValueIndicator"
public let kAXComboBoxRole = "AXComboBox"
public let kAXSliderRole = "AXSlider"
public let kAXIncrementorRole = "AXIncrementor"
public let kAXBusyIndicatorRole = "AXBusyIndicator"
public let kAXProgressIndicatorRole = "AXProgressIndicator"
public let kAXRelevanceIndicatorRole = "AXRelevanceIndicator"
public let kAXDisclosureTriangleRole = "AXDisclosureTriangle"
public let kAXTextFieldRole = "AXTextField"
public let kAXTextAreaRole = "AXTextArea"
public let kAXStaticTextRole = "AXStaticText"
public let kAXMenuBarRole = "AXMenuBar"
public let kAXMenuBarItemRole = "AXMenuBarItem"
public let kAXMenuRole = "AXMenu"
public let kAXMenuItemRole = "AXMenuItem"
public let kAXSplitGroupRole = "AXSplitGroup"
public let kAXSplitterRole = "AXSplitter"
public let kAXColorWellRole = "AXColorWell"
public let kAXTimeFieldRole = "AXTimeField"
public let kAXDateFieldRole = "AXDateField"
public let kAXHelpTagRole = "AXHelpTag"
public let kAXMatteRole = "AXMatte"
public let kAXDockItemRole = "AXDockItem"
public let kAXRulerRole = "AXRuler"
public let kAXRulerMarkerRole = "AXRulerMarker"
public let kAXGridRole = "AXGrid"
public let kAXLevelIndicatorRole = "AXLevelIndicator"
public let kAXCellRole = "AXCell"
public let kAXLayoutAreaRole = "AXLayoutArea"
public let kAXLayoutItemRole = "AXLayoutItem"
public let kAXHandleRole = "AXHandle"
public let kAXFloatingWindowSubrole = "AXFloatingWindow"
public let kAXSystemFloatingWindowSubrole = "AXSystemFloatingWindow"
public let kAXUnknownSubrole = "AXUnknown"
public let kAXPressAction = "AXPress"
public let kAXCancelAction = "AXCancel"
public let kAXConfirmAction = "AXConfirm"
public let kAXShowMenuAction = "AXShowMenu"
public let kAXCreatedNotification = "AXCreated"
public let kAXSheetCreatedNotification = "AXSheetCreated"
public let kAXDrawerCreatedNotification = "AXDrawerCreated"
public let kAXWindowMovedNotification = "AXWindowMoved"
public let kAXWindowResizedNotification = "AXWindowResized"
public let kAXValueChangedNotification = "AXValueChanged"
public let kAXMenuOpenedNotification = "AXMenuOpened"
public let kAXMenuClosedNotification = "AXMenuClosed"
public let kAXSelectedChildrenChangedNotification = "AXSelectedChildrenChanged"
public let kAXLayoutChangedNotification = "AXLayoutChanged"
public let kAXAnnouncementRequestedNotification = "AXAnnouncementRequested"
