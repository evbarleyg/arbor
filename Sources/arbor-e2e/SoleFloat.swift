import ArborCore
import CoreGraphics
import Foundation

// F18 (docs/features/F18-sole-floating-window.md): with `soleFloatTakesDesktop` on, and `floatingWindowsMakeWay`, without which Arbor
// sizes no floating window, the only floating window takes the Desktop, and it has its own frame back when the settings go off.

extension Runner {
  /// `window` floats alone on the Desktop, beside docked windows.
  func soleFloatingWindow(_ window: WindowID) throws {
    let own = actualFrames()[window] ?? .zero
    // The file is put back byte for byte afterwards: later steps compare it with what the run began with.
    let before = try Data(contentsOf: settingsFile)
    let edited = settingsText().replacingOccurrences(of: #""gap":"#, with: #""soleFloatTakesDesktop": true, "floatingWindowsMakeWay": true, "gap":"#)
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
    try step("without the setting it has its own frame back", "reload-settings") { _ in
      // Exactly, whatever is docked there: as Arbor ships, a floating window's frame is its person's.
      let isBack = poll(3) { self.actualFrames()[window]?.approximatelyEquals(own, tolerance: 3) == true }
      check("\(window) is back at \(describe(own))", isBack, whereabouts(window))
    }
  }
}
