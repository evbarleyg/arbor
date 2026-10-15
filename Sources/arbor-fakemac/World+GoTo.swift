import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics

/// The palette of Go to… (UI/FinderPanel.swift) on the fake Mac: one of the panels of Arbor's that take the keyboard. While
/// it is open, keys that are no shortcut of Arbor's go to it, a click on a row chooses the row, and a press anywhere else
/// closes it, as the panel's monitors do. That another window taking the keyboard closes it is the controller's own doing.
extension World {
  /// The palette's window level: floating + 2.
  static let paletteLevel = 5

  var palette: FinderSession? { arbor?.overlays.fake.finder }

  /// Takes the key if the palette is open. ⌘Tab and its like close it and go on to do what they do.
  func paletteTakes(_ chord: KeyChord) -> Bool {
    guard let overlays = arbor?.overlays.fake, let palette = overlays.finder else { return false }
    system.keyDown()
    system.keyUp()
    switch (chord.modifiers, chord.key) {
    case ([.command], .tab), ([.control], .left), ([.control], .right), ([.control], .up):
      // macOS's own: another app comes forward, the Space changes, Mission Control opens. The panel watches for all three.
      overlays.dismissFinder()
      return false
    case ([], .returnKey): overlays.chooseInFinder()
    case ([], .escape): overlays.dismissFinder()
    case ([], .down), ([], .tab): overlays.moveFinderSelection(by: 1)
    case ([], .up), ([.shift], .tab): overlays.moveFinderSelection(by: -1)
    // An empty field reports no change.
    case ([], .delete): if !palette.query.isEmpty { overlays.typeInFinder(String(palette.query.dropLast())) }
    case ([], .space): overlays.typeInFinder(palette.query + " ")
    case ([.command], let key):
      if let digit = Int(key.name), digit >= 1 { overlays.chooseInFinder(row: digit) }
    case ([], let key) where key.name.count == 1:
      overlays.typeInFinder(palette.query + key.name)
    default: break
    }
    followKeyboard()
    return true
  }

  /// Takes the press if it lands on the palette; any other press closes the palette and lands where it lands.
  func paletteTakesPress(at point: CGPoint) -> Bool {
    guard let overlays = arbor?.overlays.fake, let palette = overlays.finder else { return false }
    let layout = palette.layout
    guard layout.panel.contains(point) else {
      overlays.dismissFinder()
      return false
    }
    // The real one chooses when the button comes up; nothing here tells the two apart.
    let inList = CGPoint(x: point.x - layout.panel.minX - layout.list.minX, y: point.y - layout.panel.minY - layout.list.minY)
    if let row = layout.row(at: inList) { overlays.chooseInFinder(row: row + 1) }
    followKeyboard()
    return true
  }
}
