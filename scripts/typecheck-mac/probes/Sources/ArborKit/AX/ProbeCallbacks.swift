// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// What is passed for a C callback must capture nothing. Nothing else is wrong in this file: a file that does not type-check gets no further.
import ApplicationServices
import CoreGraphics

private func probePlainCallback(_ observer: AXObserver, _ element: AXUIElement, _ name: CFString, _ context: UnsafeMutableRawPointer?) {}
private func probePlainTap(_ proxy: CGEventTapProxy, _ type: CGEventType, _ event: CGEvent, _ context: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? { nil }

@MainActor
final class ProbeCallbacks {
  func observe(_ pid: pid_t) {
    var observer: AXObserver?
    let local = 1
    _ = AXObserverCreate(pid, probePlainCallback, &observer)
    _ = AXObserverCreate(pid, { _, _, _, _ in }, &observer)
    _ = AXObserverCreate(pid, { _, _, _, _ in _ = local }, &observer)  // wrong
    _ = AXObserverCreate(pid, { [weak self] _, _, _, _ in _ = self }, &observer)  // wrong
    func nested(_ observer: AXObserver, _ element: AXUIElement, _ name: CFString, _ context: UnsafeMutableRawPointer?) { _ = local }
    _ = AXObserverCreate(pid, nested, &observer)  // wrong
    _ = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: 0, callback: probePlainTap, userInfo: nil)
    _ = CGEvent.tapCreate(
      tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: 0,
      callback: { _, _, event, _ in local > 0 ? Unmanaged.passUnretained(event) : nil }, userInfo: nil)  // wrong
  }
}
