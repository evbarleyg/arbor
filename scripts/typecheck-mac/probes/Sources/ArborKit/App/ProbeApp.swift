// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// The application, the workspace, login items.
import AppKit
import ServiceManagement

@MainActor final class ProbeDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.setActivationPolicy(.accessory)
    NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp"))
    _ = SMAppService.mainApp.status == .enabled
    NSApp.setActivationPolicy(.background)  // wrong
    NSWorkspace.shared.open("/tmp")  // wrong
    _ = SMAppService.mainApp.status == .on  // wrong
    NSApp.terminate()  // wrong
  }
}
