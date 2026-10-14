import ApplicationServices
import ArborCore
import CoreGraphics
import Foundation

/// Asks whoever draws the Desktop under the pointer (Finder, a widget) what is there, for
/// `PointerSurface.isDesktopItem`, which decides.
///
/// An app may take its time over the answer, so the question is never asked from a tap's callback, where all input
/// would wait with it. `RectangleFramer` is holding the press back anyway: it asks from here, on a queue of
/// its own, while the button is down, and needs the answer only when the button comes up.
enum DesktopProbe {
  /// How long the app may take over one question.
  private static let timeout: Float = 0.25
  /// How long it may take over all of them. There are up to eleven, and an app that answers each just in time would keep
  /// a drag with ⇧ waiting for nearly three seconds.
  private static let patience = 0.5
  /// How many levels of the Accessibility tree to look at, from the element under the pointer up.
  private static let depth = 4

  private static let queue = DispatchQueue(label: "dev.arbor.desktop-probe", qos: .userInteractive)

  /// - Parameters:
  ///   - mayVanish: the press may be kept from everybody, so it also matters whether a name is being edited.
  ///   - isWanted: asked right before the app is, so that questions about presses that are over do not queue up
  ///     behind an app that is stuck.
  ///   - answer: called on the probe's queue, unless the answer is no longer wanted. If the app did not say, the
  ///     answer is that there is an item: nothing is taken that is not known to be the wallpaper's.
  static func ask(
    pid: pid_t, at point: CGPoint, mayVanish: Bool, isWanted: @escaping @Sendable () -> Bool,
    answer: @escaping @Sendable (_ isItem: Bool) -> Void
  ) {
    queue.async {
      guard isWanted() else { return }
      let deadline = DispatchTime.now() + patience
      let app = AXUIElementCreateApplication(pid)
      AXUIElementSetMessagingTimeout(app, timeout)
      let roles = roles(app, at: point, before: deadline)
      var isItem = PointerSurface.isDesktopItem(roles: roles, focused: "")
      // The second question only if the first leaves it open, and only for a click that would be lost.
      if mayVanish, isItem == false {
        isItem = PointerSurface.isDesktopItem(roles: roles, focused: DispatchTime.now() < deadline ? focusedRole(app) : nil)
        // A search field of a window of Finder's that keeps the keyboard in the background would do this all day.
        if isItem != false {
          let why = isItem == true ? "a text field of its has the keyboard" : "it did not say what has the keyboard"
          TapLog.debug("a click on the wallpaper is left alone: pid \(pid) draws the icons, and \(why)")
        }
      }
      answer(isItem ?? true)
    }
  }

  /// The role of the element that has the keyboard in `app`; "" if none has; nil if the app did not say.
  private static func focusedRole(_ app: AXUIElement) -> String? {
    var value: CFTypeRef?
    switch AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &value) {
    case .noValue, .attributeUnsupported:
      return ""
    case .success:
      guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return "" }
      let element = value as! AXUIElement
      AXUIElementSetMessagingTimeout(element, timeout)
      return element.string(kAXRoleAttribute)
    default:
      return nil
    }
  }

  /// The role of the Accessibility element at `point`, then its parent's, and so on up to the app. Empty if the app
  /// failed to give any of them. A timeout belongs to one element object, so each gets its own, and Arbor's other
  /// calls keep theirs.
  private static func roles(_ app: AXUIElement, at point: CGPoint, before deadline: DispatchTime) -> [String] {
    var found: AXUIElement?
    guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &found) == .success,
      var element = found
    else { return [] }
    var roles: [String] = []
    while roles.count < depth {
      guard DispatchTime.now() < deadline else { return [] }
      AXUIElementSetMessagingTimeout(element, timeout)
      guard let role = element.string(kAXRoleAttribute) else { return [] }
      roles.append(role)
      if role == kAXApplicationRole { break }
      // Everything but the app has a parent.
      guard let parent = element.element(kAXParentAttribute) else { return [] }
      element = parent
    }
    return roles
  }
}
