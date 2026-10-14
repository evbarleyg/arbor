import AppKit
import ArborCore

/// The talking part of `OverlayPresenter`: see `HeadsUpPanel` and `CheatSheetPanel`. There is one of each, which
/// goes to whichever display it is wanted on; the models say where that is.
extension AppKitOverlays {
  public func showHeadsUp(_ model: HeadsUpModel?, on display: DisplayID) {
    guard let model else {
      headsUpPanel?.disappear()
      return
    }
    let panel = headsUpPanel ?? HeadsUpPanel()
    headsUpPanel = panel
    // The same words at another place are the line making room for the minimap, not news.
    let onlyMoved = panel.isWanted && panel.shown?.line == model.line && panel.shown?.anchor != model.anchor
    panel.show(model)
    guard !onlyMoved else { return }
    // The panel never has the keyboard, so VoiceOver would not come across it.
    NSAccessibility.post(
      element: NSApp as Any, notification: .announcementRequested,
      userInfo: [.announcement: model.spoken, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
  }

  public func showCheatSheet(_ model: CheatSheetModel?, on display: DisplayID) {
    guard let model else {
      cheatSheetPanel?.hide()
      return
    }
    let panel = cheatSheetPanel ?? CheatSheetPanel()
    cheatSheetPanel = panel
    panel.onDismiss = { [weak self] in self?.actions?.cheatSheetDismissed() }
    panel.show(model)
  }

  func removeHeadsUp() {
    headsUpPanel?.close()
    headsUpPanel = nil
    cheatSheetPanel?.hide()
    cheatSheetPanel?.close()
    cheatSheetPanel = nil
  }
}
