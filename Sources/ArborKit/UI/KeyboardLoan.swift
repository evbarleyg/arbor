import AppKit

/// Arbor is an accessory app: nothing brings it to the front unless one of its ordinary windows asks (the settings, the
/// answer of an update check, About). And an accessory app that closes its last window stays the active app, so that no
/// window has the keyboard until something is clicked, and Arbor's own shortcuts find no focused window.
///
/// So the keyboard is borrowed. Whoever brings Arbor forward does it here, and when the last of those windows closes, the
/// app that was in front before gets the keyboard back. Panels that take the keyboard without making Arbor active (the
/// welcome window, Go to…, the name field) have nothing to give back.
@MainActor
final class KeyboardLoan {
  static let shared = KeyboardLoan()

  /// The app that was in front when Arbor last came forward.
  private var lender: NSRunningApplication?
  private var closeObserver: (any NSObjectProtocol)?

  /// Makes Arbor the active app and remembers which one was. `insisting`: whatever the person is doing, because they have
  /// just asked for the window. An answer that comes when the network pleases only asks, and macOS decides.
  func borrow(insisting: Bool = true) {
    // Not Arbor itself: a second window opened from the first borrows from the same app.
    if let front = NSWorkspace.shared.frontmostApplication,
      front.processIdentifier != NSRunningApplication.current.processIdentifier
    {
      lender = front
    }
    watchWindowsClose()
    if insisting { NSApp.activate(ignoringOtherApps: true) } else { NSApp.activate() }
  }

  /// Nobody is owed the keyboard: the person has sent for another app (the browser, for the release page), which must not find
  /// the lender pushed in front of it.
  func forgive() {
    lender = nil
  }

  /// For a window that goes without being closed, so that `willCloseNotification` says nothing (the alert of an update check).
  func aWindowWasTakenAway() {
    DispatchQueue.main.async { [weak self] in self?.giveBackUnlessAWindowIsOpen() }
  }

  /// All of them, because AppKit makes the About panel and Arbor is not its delegate.
  private func watchWindowsClose() {
    guard closeObserver == nil else { return }
    closeObserver = NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: nil, queue: .main
    ) { [weak self] note in
      // A plain value, so that nothing that is not Sendable crosses into the main actor's closure.
      let closing = (note.object as? NSWindow).map { ObjectIdentifier($0) }
      MainActor.assumeIsolated { self?.windowWillClose(closing) }
    }
  }

  private static func bringsArborForward(_ window: NSWindow) -> Bool {
    window.styleMask.contains(.titled) && !window.styleMask.contains(.nonactivatingPanel)
  }

  private func windowWillClose(_ closing: ObjectIdentifier?) {
    // Tiles and other panels close all the time.
    guard NSApp.windows.contains(where: { ObjectIdentifier($0) == closing && Self.bringsArborForward($0) }) else { return }
    // Decided a turn later, when the window has gone. Whoever closes a window to put another in its place (a second answer
    // of an update check while the first is still open) would otherwise give the keyboard away and ask for it back in one
    // breath, while Arbor still counts as active and the asking does nothing.
    DispatchQueue.main.async { [weak self] in self?.giveBackUnlessAWindowIsOpen() }
  }

  private func giveBackUnlessAWindowIsOpen() {
    // Another one is open here: the keyboard goes to that. One left on another Space counts as visible and takes no keyboard.
    guard !NSApp.windows.contains(where: { $0.isVisible && $0.isOnActiveSpace && Self.bringsArborForward($0) }) else { return }
    // If the person has gone to another app meanwhile, the keyboard is where they want it.
    guard NSRunningApplication.current.isActive, let lender, !lender.isTerminated else { return }
    // Since macOS 14 an app comes forward for certain only if the one in front makes way for it.
    NSApp.yieldActivation(to: lender)
    _ = lender.activate(options: [])
    self.lender = nil
  }
}
