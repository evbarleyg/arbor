import ArborCore
import CoreGraphics
import Foundation

// F18 (docs/features/F18-sole-floating-window.md): with `soleFloatTakesDesktop` on, the only floating window takes
// the Desktop, and it has its own frame back when the setting goes off.

extension Runner {
  /// `window` floats alone on the Desktop, beside docked windows.
  func soleFloatingWindow(_ window: WindowID) throws {
    let own = actualFrames()[window] ?? .zero
    // The file is put back byte for byte afterwards: later steps compare it with what the run began with.
    let before = try Data(contentsOf: settingsFile)
    let edited = settingsText().replacingOccurrences(of: #""gap":"#, with: #""soleFloatTakesDesktop": true, "gap":"#)
    try Data(edited.utf8).write(to: settingsFile)
    try step("a window that floats alone takes the Desktop", "reload-settings") { state in
      let desktop = state.displays[0].desktopFrame ?? .zero
      let fills = poll(3) { self.actualFrames()[window]?.approximatelyEquals(desktop, tolerance: 3) == true }
      check("\(window) fills the Desktop, \(describe(desktop))", fills, whereabouts(window))
      check("\(window) is still floating", state.displays[0].floating.contains(window))
    }
    // Long enough for macOS to report the move late, which must not be taken for the user's.
    Thread.sleep(forTimeInterval: 1.5)
    try before.write(to: settingsFile)
    try step("without the setting it has its own frame back", "reload-settings") { state in
      // As far as the Desktop has room for it. On a display 1024 points wide the Desktop is narrower than the window, which lay over
      // the docked windows where `float` had put it. Now Arbor has placed it, and what Arbor places on the Desktop stays on it.
      let expected = own.fitted(into: roomForFloatingWindows(on: state.displays[0]))
      let isBack = poll(3) { self.actualFrames()[window]?.approximatelyEquals(expected, tolerance: 3) == true }
      check("\(window) is back at \(describe(expected))", isBack, whereabouts(window))
    }
  }

  /// Where floating windows may be: the Desktop, out to the edge of the screen on the sides where nothing is docked beside it
  /// (the controller's `floatingRegion`).
  func roomForFloatingWindows(on display: StateSnapshot.Display) -> CGRect {
    guard let desktop = display.desktopFrame else { return display.visibleFrame }
    let (visible, content) = (display.visibleFrame, display.visibleFrame.insetBy(dx: gap, dy: gap))
    let minX = desktop.minX <= content.minX + 1 ? visible.minX : desktop.minX
    let minY = desktop.minY <= content.minY + 1 ? visible.minY : desktop.minY
    let maxX = desktop.maxX >= content.maxX - 1 ? visible.maxX : desktop.maxX
    let maxY = desktop.maxY >= content.maxY - 1 ? visible.maxY : desktop.maxY
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }
}
