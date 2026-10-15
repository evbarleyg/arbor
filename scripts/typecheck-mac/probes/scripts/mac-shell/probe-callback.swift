// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// What is passed for a C callback must capture nothing. In a script a top-level `let` is a global, and what a top-level `guard let` binds is a local of the script: a Mac refuses
// a closure, or a function, that uses it ("a C function pointer cannot be formed from a local function that captures context"). Nothing else is wrong in this file:
// the check for it comes after all others.
import AppKit

let global = 1
guard let bound = Optional(2) else { exit(1) }
var observer: AXObserver?

func plain(_ observer: AXObserver, _ element: AXUIElement, _ name: CFString, _ context: UnsafeMutableRawPointer?) { _ = global }
func usesWhatTheGuardBound(_ observer: AXObserver, _ element: AXUIElement, _ name: CFString, _ context: UnsafeMutableRawPointer?) { _ = bound }
let kept: AXObserverCallback = { _, _, _, _ in _ = global }

_ = AXObserverCreate(1, plain, &observer)
_ = AXObserverCreate(1, kept, &observer)
_ = AXObserverCreate(1, { _, _, _, _ in _ = global }, &observer)
_ = AXObserverCreate(1, usesWhatTheGuardBound, &observer)  // wrong
_ = AXObserverCreate(1, { _, _, _, _ in _ = bound }, &observer)  // wrong

_ = CGEvent.tapCreate(
  tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: 0,
  callback: { _, _, event, _ in Unmanaged.passUnretained(event) }, userInfo: nil)
_ = CGEvent.tapCreate(
  tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: 0,
  callback: { _, _, event, _ in bound > 0 ? Unmanaged.passUnretained(event) : nil }, userInfo: nil)  // wrong

_ = CGDisplayRegisterReconfigurationCallback({ _, _, _ in _ = global }, nil)
_ = CGDisplayRegisterReconfigurationCallback({ _, _, _ in _ = bound }, nil)  // wrong
CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { _, _, _, _, _ in _ = global }, "probe" as CFString, nil, .deliverImmediately)
CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), nil, { _, _, _, _, _ in _ = bound }, "probe" as CFString, nil, .deliverImmediately)  // wrong
