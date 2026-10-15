import AppKit
import ArborCore

/// Shows the answer of an update check somebody asked for and, when there is a newer release, offers to open its page. It says
/// `UpdateDecision.message`; the decisions are made in the core, and the controller never calls for it unasked.
///
/// macOS's own alert: where macOS has its own thing Arbor uses it, and it looks like the macOS it runs on without anybody's
/// work. (The window Arbor laid out itself was twenty points too short for its buttons on macOS 26: seen on a hosted Mac.)
///
/// **The alert is shown, not run.** An alert's modal loop would keep Arbor from hearing about other apps' windows for as long as
/// it stayed open. So its window is put on screen like any other, and its buttons report here instead of ending a loop that nobody runs.
@MainActor
final class UpdateWindow: NSObject {
  private var alert: NSAlert?
  private var page: URL?

  /// The alert for `decision`, with the button that ↩ presses first. Apart from `show` so that a test can look at it without a screen.
  static func alert(for decision: UpdateDecision, current: BuildInfo) -> NSAlert {
    let message = decision.message(current: current)
    let alert = NSAlert()
    alert.alertStyle = .informational
    alert.messageText = message.headline
    alert.informativeText = message.detail
    if decision.page == nil {
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
    page = decision.page.flatMap { URL(string: $0) }
    for (place, button) in alert.buttons.enumerated() {
      button.target = self
      button.action = place == 0 && page != nil ? #selector(openPage) : #selector(close)
    }
    alert.layout()
    self.alert = alert
    let window = alert.window
    // Arbor has no Dock icon to find the window by, so it must not end up under other apps' windows.
    window.level = .floating
    window.center()
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
    // Asked for from a terminal, Arbor may not be let to the front; the window comes all the same.
    window.orderFrontRegardless()
  }

  @objc func close() {
    alert?.window.orderOut(nil)
    alert = nil
    page = nil
  }

  @objc private func openPage() {
    if let page { NSWorkspace.shared.open(page) }
    close()
  }
}
