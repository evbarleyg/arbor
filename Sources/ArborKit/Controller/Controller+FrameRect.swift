import ArborCore
import CoreGraphics

extension Controller {
  /// A rectangle narrower or shorter than this does nothing, so a short
  /// modifier-drag never moves the camera by accident.
  static let minimumFrameRectSide: CGFloat = 40

  /// Moves the camera to the node that best fits `rect` (global coordinates)
  /// in the current layout of the display containing its centre: around one
  /// window it frames that window, around a group the group. Around all that
  /// is in view it changes nothing, and says so. `RectangleFramer` sends this on release.
  func frameRect(_ rect: CGRect) -> CommandResult {
    let rect = rect.standardized
    let side = Self.minimumFrameRectSide
    guard rect.width >= side, rect.height >= side else {
      return .failure("the rectangle is smaller than \(Int(side)) × \(Int(side)) points")
    }
    guard let display = displayID(at: rect.center), let layout = layouts[display] else {
      return .failure("no display")
    }
    guard let node = Navigation.bestFit(for: rect, in: layout, tree: workspaces[display]?.tree) else {
      return .failure("nothing in view under the rectangle")
    }
    // What counts is what the view shows: a split whose other children are minimized looks like the one that is left.
    if let view = treeView(display), view.passThrough(node) == view.passThrough(layout.camera) {
      return .failure("that is already the view")
    }
    moveCamera(on: display, to: node)
    return .success("framed \(name(of: node, on: display))")
  }

  /// During a peek ⌃⌥ is down, and ⌃⌥ is also what draws a rectangle. So a press on the peek's outline is held as the beginning
  /// of one, and if the pointer slips by more than the drag threshold before the button is up, it arrives here as a rectangle
  /// too small to be one. Refused like any other, it would end the peek with the view on everything, as every command does.
  /// It is the click it was meant as: the view lands where the outline is.
  func landPeek(insteadOf command: Command) -> CommandResult? {
    // Only once something is outlined is there anything to have clicked on.
    guard case .frameRect(let x, let y, let width, let height) = command, isPeeking, let display = peeking?.display else {
      return nil
    }
    let rect = CGRect(x: x, y: y, width: width, height: height).standardized
    guard min(rect.width, rect.height) < Self.minimumFrameRectSide, displayID(at: rect.center) == display else { return nil }
    peekOutlineClicked(display: display)
    return .success("taken for a click on the outline")
  }
}
