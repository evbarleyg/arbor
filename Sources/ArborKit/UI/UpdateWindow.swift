import AppKit
import ArborCore

/// The small window that shows the answer of an update check somebody asked for and, when there is a
/// newer release, offers to open its page. It draws `UpdateDecision.message`; the decisions are made
/// in the core, and the controller never calls for it unasked.
///
/// An ordinary window rather than an alert: an alert's modal loop would keep Arbor from hearing about
/// other apps' windows for as long as it stayed open.
@MainActor
final class UpdateWindow: NSObject, NSWindowDelegate {
  private var window: NSWindow?
  private var page: URL?

  /// Replaces whatever answer is showing.
  func show(_ decision: UpdateDecision, current: BuildInfo) {
    close()
    let message = decision.message(current: current)
    page = decision.page.flatMap { URL(string: $0) }

    let headline = NSTextField(labelWithString: message.headline)
    headline.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
    let detail = NSTextField(wrappingLabelWithString: message.detail)
    detail.isSelectable = false
    // Both: the first wraps the text when its height is worked out, the second holds the window to it.
    detail.preferredMaxLayoutWidth = 320
    detail.widthAnchor.constraint(equalToConstant: 320).isActive = true

    let buttons = NSStackView()
    buttons.orientation = .horizontal
    let dismiss = NSButton(title: page == nil ? "OK" : "Later", target: self, action: #selector(close))
    buttons.addView(dismiss, in: .trailing)
    if page != nil {
      let open = NSButton(title: "Open Release Page", target: self, action: #selector(openPage))
      open.keyEquivalent = "\r"
      dismiss.keyEquivalent = "\u{1b}"
      buttons.addView(open, in: .trailing)
    } else {
      dismiss.keyEquivalent = "\r"
    }

    let text = NSStackView(views: [headline, detail, buttons])
    text.orientation = .vertical
    text.alignment = .leading
    text.spacing = 8
    text.setCustomSpacing(16, after: detail)
    buttons.widthAnchor.constraint(equalTo: detail.widthAnchor).isActive = true

    let icon = NSImageView()
    icon.image = NSApp.applicationIconImage
    icon.widthAnchor.constraint(equalToConstant: 48).isActive = true
    icon.heightAnchor.constraint(equalToConstant: 48).isActive = true

    let content = NSStackView(views: [icon, text])
    content.orientation = .horizontal
    content.alignment = .top
    content.spacing = 16
    content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 424, height: 140), styleMask: [.titled, .closable], backing: .buffered,
      defer: false)
    window.title = "Arbor"
    window.contentView = content
    window.setContentSize(content.fittingSize)
    window.isReleasedWhenClosed = false
    window.delegate = self
    // Arbor has no Dock icon to find the window by, so it must not end up under other apps' windows.
    window.level = .floating
    window.center()
    self.window = window
    NSApp.activate()
    window.makeKeyAndOrderFront(nil)
    // Asked for from a terminal, Arbor may not be let to the front; the window comes all the same.
    window.orderFrontRegardless()
  }

  @objc func close() {
    window?.close()
  }

  @objc private func openPage() {
    if let page { NSWorkspace.shared.open(page) }
    close()
  }

  func windowWillClose(_ notification: Notification) {
    window = nil
    page = nil
  }
}
