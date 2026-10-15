// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// The Accessibility API, Core Foundation types, and what is for the Mac only.
import ApplicationServices
import FakeMacOS  // wrong
import Foundation

func probeAccessibility(_ element: AXUIElement, _ something: AnyObject) {
  var value: CFTypeRef?
  _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
  if let value, CFGetTypeID(value) == AXUIElementGetTypeID() { _ = value as! AXUIElement }
  _ = AXUIElementCopyAttributeValue(element, kAXRoleAttribute, &value)  // wrong
  _ = AXUIElementCopyAttributeValue(element, kAXRoleAtribute as CFString, &value)  // wrong
  // What the stand-ins have for their own ends is public here, and no Mac has it (prepare.py's check).
  _ = AXUIElement._typeID  // wrong
  _ = AXValue._typeID  // wrong
  _ = something is any _CFTypeWithID  // wrong
  _ = CFUUID(_text: "0")  // wrong
  CFRunLoopSource()._onRunLoop = nil  // wrong
  var number = CGWindowID(0)
  _ = _standInForAXUIElementGetWindow(element, &number)  // wrong
  _ = FakeMac.current.now  // wrong
  // Core Foundation types cannot be tested for (prepare.py's check).
  _ = something is AXUIElement  // wrong
  _ = something as? AXValue  // wrong
  _ = kAXTrustedCheckOptionPrompt  // wrong

  // The compiler runs on Linux, but what counts is what a Mac compiles.
  #if os(macOS)
    _ = element.probeMacOnly  // wrong
  #else
    _ = element.probeLinuxOnly
  #endif
  #if canImport(Glibc)
    _ = element.probeLinuxOnly
  #endif
}
