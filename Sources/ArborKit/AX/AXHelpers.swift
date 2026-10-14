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
    let error = AXUIElementCopyAttributeValue(self, name as CFString, &value)
    return (error, error == .success ? value : nil)
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

  func elements(_ name: String) -> [AXUIElement] { elementsIfAnswered(name) ?? [] }

  /// The elements of an array attribute, or nil if the app gave no answer: it timed out, is quitting, or
  /// Arbor has lost its permission. Only an app that says it has no value has an empty list; reading
  /// every failure as "no windows" would take all of an app's windows out of the layout.
  func elementsIfAnswered(_ name: String) -> [AXUIElement]? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(self, name as CFString, &value)
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

  var frame: CGRect? {
    guard let position, let size else { return nil }
    return CGRect(origin: position, size: size)
  }

  @discardableResult
  func setPosition(_ point: CGPoint) -> AXError {
    var point = point
    guard let value = AXValueCreate(.cgPoint, &point) else { return .failure }
    return AXUIElementSetAttributeValue(self, kAXPositionAttribute as CFString, value)
  }

  @discardableResult
  func setSize(_ size: CGSize) -> AXError {
    var size = size
    guard let value = AXValueCreate(.cgSize, &size) else { return .failure }
    return AXUIElementSetAttributeValue(self, kAXSizeAttribute as CFString, value)
  }

  @discardableResult
  func setBool(_ name: String, _ flag: Bool) -> AXError {
    AXUIElementSetAttributeValue(self, name as CFString, flag ? kCFBooleanTrue : kCFBooleanFalse)
  }

  var windowID: WindowID? {
    var identifier = CGWindowID(0)
    guard _AXUIElementGetWindow(self, &identifier) == .success, identifier != 0 else { return nil }
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
