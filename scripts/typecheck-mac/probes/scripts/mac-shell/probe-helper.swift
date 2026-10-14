// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// A helper tool of the Mac shell: a program of one file, in language mode 5, with its code at the top level.
import AppKit
import ApplicationServices
import CoreGraphics

let source = CGEventSource(stateID: .hidSystemState)
if let event = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: true) { event.post(tap: .cghidEventTap) }
_ = CGEvent(keyboardEventSource: source, virtualKeyCode: 49, keyDown: true)  // wrong
let mode = CGDisplayCopyDisplayMode(CGMainDisplayID())
print(mode?.pixelWidth ?? 0)
print(mode.pixelWidth)  // wrong
_ = CGEventSource.flagsState(.hidSystemState)
_ = CGEventSource.flagState(.hidSystemState)  // wrong

var value: CFTypeRef?
if AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedApplicationAttribute as CFString, &value) == .success,
  let value, CFGetTypeID(value) == AXUIElementGetTypeID()
{
  var pid: pid_t = 0
  AXUIElementGetPid(value as! AXUIElement, &pid)
}
_ = value as? AXUIElement  // wrong

// What comes from Objective-C may be called for its effect alone.
FileManager.default.createFile(atPath: "/dev/null", contents: nil)

// In mode 5 the SDK lets code at the top level touch what belongs to the main actor.
let application = NSApplication.shared
application.setActivationPolicy(.accessory)
application.run()
