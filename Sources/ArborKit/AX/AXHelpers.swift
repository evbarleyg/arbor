import AppKit
import ApplicationServices
import ArborCore

/// Private but stable for over a decade, and used by every macOS window
/// manager: the window-server number (CGWindowID) behind an AX window.
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ identifier: UnsafeMutablePointer<CGWindowID>) -> AXError

extension AXUIElement {
  /// An attribute's value together with what the call returned, for callers that must tell an app that
  /// does not answer (`.cannotComplete`) from one that has nothing to say.
  func read(_ name: String) -> (error: AXError, value: CFTypeRef?) {
    var value: CFTypeRef?
    let error = AXCalls.timed("read \(name)", self) { AXUIElementCopyAttributeValue(self, name as CFString, &value) }
    return (error, error == .success ? value : nil)
  }

  /// Several attributes in one round trip, in the order asked, with nil for those the element does not have.
  /// `values` is nil when the app did not answer or the element is gone, and `error` says which.
  func attributes(_ names: [String]) -> (values: [CFTypeRef?]?, error: AXError) {
    var array: CFArray?
    let error = AXCalls.timed("read \(names.count) attributes", self) {
      AXUIElementCopyMultipleAttributeValues(self, names as CFArray, AXCopyMultipleAttributeOptions(rawValue: 0), &array)
    }
    guard error == .success, let array, let list = (array as CFTypeRef) as? [AnyObject], list.count == names.count
    else {
      if error == .cannotComplete || error == .invalidUIElement { return (nil, error) }
      // Not every toolkit's bridge to Accessibility need know this call. Taking that for "has no such attributes" would
      // leave all of the app's windows unarranged, so it is asked one question at a time, as everybody used to be.
      CallStats.shared.record("window system", "attributes read one by one", seconds: 0)
      return (names.map { copyAttribute($0) }, .success)
    }
    let values = list.map { item -> CFTypeRef? in
      // An attribute that could not be read comes back as the error, wrapped, or as a null.
      if CFGetTypeID(item) == AXValueGetTypeID(), AXValueGetType(item as! AXValue) == .axError { return nil }
      if CFGetTypeID(item) == CFNullGetTypeID() { return nil }
      return item
    }
    return (values, error)
  }

  /// Position and size in one round trip. `unanswered` means the app took the whole timeout.
  func readFrame() -> (frame: CGRect?, unanswered: Bool) {
    var values: [CFTypeRef?]?
    let unanswered = AXCalls.wentUnanswered {
      let answer = attributes([kAXPositionAttribute, kAXSizeAttribute])
      values = answer.values
      return answer.error
    }
    if unanswered { return (nil, true) }
    guard let values, let origin = Self.point(values[0]), let size = Self.size(values[1]) else { return (nil, false) }
    return (CGRect(origin: origin, size: size), false)
  }

  static func point(_ value: CFTypeRef?) -> CGPoint? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var point = CGPoint.zero
    return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
  }

  static func size(_ value: CFTypeRef?) -> CGSize? {
    guard let value, CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
    var size = CGSize.zero
    return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
  }

  static func bool(_ value: CFTypeRef?) -> Bool? {
    guard let value, CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
    return CFBooleanGetValue((value as! CFBoolean))
  }

  func copyAttribute(_ name: String) -> CFTypeRef? { read(name).value }

  /// Whether the thing this element stood for is gone, while its app is still there to say so.
  var isInvalid: Bool { read(kAXRoleAttribute).error == .invalidUIElement }

  func string(_ name: String) -> String? { copyAttribute(name) as? String }

  func bool(_ name: String) -> Bool? {
    guard let value = copyAttribute(name), CFGetTypeID(value) == CFBooleanGetTypeID() else { return nil }
    return CFBooleanGetValue((value as! CFBoolean))
  }

  /// Whether the attribute can be set, or nil if the app does not say.
  func isSettable(_ name: String) -> Bool? {
    var settable: DarwinBoolean = false
    guard AXUIElementIsAttributeSettable(self, name as CFString, &settable) == .success else { return nil }
    return settable.boolValue
  }

  func element(_ name: String) -> AXUIElement? {
    guard let value = copyAttribute(name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return (value as! AXUIElement)
  }

  /// The element an attribute names, `.some(nil)` if the app says there is none, or nil if it gave no answer.
  func elementIfAnswered(_ name: String) -> AXUIElement?? {
    var value: CFTypeRef?
    let result = AXCalls.timed("read \(name)", self) { AXUIElementCopyAttributeValue(self, name as CFString, &value) }
    if result == .noValue { return .some(nil) }
    guard result == .success, let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
    return .some((value as! AXUIElement))
  }

  func elements(_ name: String) -> [AXUIElement] { elementsIfAnswered(name) ?? [] }

  /// The elements of an array attribute, or nil if the app gave no answer: it timed out, is quitting, or
  /// Arbor has lost its permission. Only an app that says it has no value has an empty list; reading
  /// every failure as "no windows" would take all of an app's windows out of the layout.
  func elementsIfAnswered(_ name: String) -> [AXUIElement]? {
    var value: CFTypeRef?
    let result = AXCalls.timed("read \(name)", self) { AXUIElementCopyAttributeValue(self, name as CFString, &value) }
    if result == .noValue { return [] }
    guard result == .success else { return nil }
    guard let value, CFGetTypeID(value) == CFArrayGetTypeID() else { return [] }
    return (value as? [AnyObject] ?? []).compactMap { item in
      CFGetTypeID(item) == AXUIElementGetTypeID() ? (item as! AXUIElement) : nil
    }
  }

  var position: CGPoint? {
    guard let value = copyAttribute(kAXPositionAttribute), CFGetTypeID(value) == AXValueGetTypeID() else {
      return nil
    }
    var point = CGPoint.zero
    return AXValueGetValue(value as! AXValue, .cgPoint, &point) ? point : nil
  }

  var size: CGSize? {
    guard let value = copyAttribute(kAXSizeAttribute), CFGetTypeID(value) == AXValueGetTypeID() else {
      return nil
    }
    var size = CGSize.zero
    return AXValueGetValue(value as! AXValue, .cgSize, &size) ? size : nil
  }

  var frame: CGRect? { readFrame().frame }

  @discardableResult
  func setPosition(_ point: CGPoint) -> AXError {
    var point = point
    guard let value = AXValueCreate(.cgPoint, &point) else { return .failure }
    return AXCalls.timed("set AXPosition", self) {
      AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, value)
    }
  }

  @discardableResult
  func setSize(_ size: CGSize) -> AXError {
    var size = size
    guard let value = AXValueCreate(.cgSize, &size) else { return .failure }
    return AXCalls.timed("set AXSize", self) {
      AXUIElementSetAttributeValue(self, kAXSizeAttribute as CFString, value)
    }
  }

  @discardableResult
  func setBool(_ name: String, _ flag: Bool) -> AXError {
    AXCalls.timed("set \(name)", self) {
      AXUIElementSetAttributeValue(self, name as CFString, flag ? kCFBooleanTrue : kCFBooleanFalse)
    }
  }

  var windowID: WindowID? {
    var identifier = CGWindowID(0)
    let result = AXCalls.timed("window number", self) { _AXUIElementGetWindow(self, &identifier) }
    guard result == .success, identifier != 0 else { return nil }
    return WindowID(identifier)
  }

  var pid: pid_t? {
    var pid: pid_t = 0
    return AXUIElementGetPid(self, &pid) == .success ? pid : nil
  }
}

/// Carries a non-Sendable value across a hop that stays on the main actor, or hands it over for good to
/// a task that is the only one to use it.
struct MainActorBox<Value>: @unchecked Sendable {
  let value: Value
}
