import AppKit
import ArborCore

/// Shows the answer of an update check somebody asked for and, when there is a newer release, offers to open its page.
/// It says `UpdateDecision.message`; the decisions are made in the core, and the controller never calls for it unasked.
///
/// macOS's own alert: where macOS has its own thing Arbor uses it, and it looks like the macOS it runs on without
/// anybody's work. (The window Arbor laid out itself was twenty points too short for its buttons on macOS 26: seen on
/// a hosted Mac.)
///
/// **The alert is shown, not run.** An alert's modal loop would keep Arbor from hearing about other apps' windows for
/// as long as it stayed open. So its window is put on screen like any other, and its buttons report here instead of
/// ending a loop that nobody runs.
@MainActor
final class UpdateWindow: NSObject {
  private var alert: NSAlert?
  private var page: URL?

  /// The page to offer, if there is one and it is an address.
  static func page(of decision: UpdateDecision) -> URL? { decision.page.flatMap { URL(string: $0) } }

  /// The alert for `decision`, with the button that ↩ presses first. Apart from `show` so that a test can look at it
  /// without a screen.
  static func alert(for decision: UpdateDecision, current: BuildInfo) -> NSAlert {
    let message = decision.message(current: current)
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = message.headline
    alert.informativeText = message.detail
    if page(of: decision) == nil {
      alert.addButton(withTitle: "OK")
    } else {
      alert.addButton(withTitle: "Open Release Page")
      alert.addButton(withTitle: "Later").keyEquivalent = "\u{1b}"
    }
    return alert
  }

  /// Replaces whatever answer is showing.
  func show(_ decision: UpdateDecision, current: BuildInfo) {
    close()
    let alert = Self.alert(for: decision, current: current)
    page = Self.page(of: decision)
    for (place, button) in alert.buttons.enumerated() {
      button.target = self
      button.action = place == 0 && page != nil ? #selector(openPage) : #selector(close)
    }
    alert.layout()
    self.alert = alert
    let window = alert.window
    // Arbor is hardly ever the active app, and a panel that hides when its app is not would never show, or go at the
    // first click elsewhere.
    window.hidesOnDeactivate = false
    // Arbor has no Dock icon to find the window by, so it must not end up under other apps' windows.
    window.level = .floating
    window.center()
    // The app in front gets the keyboard back when the alert goes. The answer comes when the network pleases, perhaps in
    // mid-word: Arbor asks to come forward and does not insist.
    KeyboardLoan.shared.borrow(insisting: false)
    window.makeKeyAndOrderFront(nil)
    // Asked for from a terminal, Arbor may not be let to the front; the window comes all the same.
    window.orderFrontRegardless()
  }

  @objc func close() {
    // Taken off the screen, not closed: no notification tells of it.
    if alert != nil { KeyboardLoan.shared.aWindowWasTakenAway() }
    alert?.window.orderOut(nil)
    alert = nil
    page = nil
  }

  @objc private func openPage() {
    if let page {
      // The browser comes forward, a moment later than the window closes.
      KeyboardLoan.shared.forgive()
      NSWorkspace.shared.open(page)
    }
    close()
  }
}
