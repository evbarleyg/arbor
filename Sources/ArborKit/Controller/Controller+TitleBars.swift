import ArborCore
import CoreGraphics

/// How low a window can be sent. macOS keeps a window's title bar above the Dock and the display's bottom edge, and title bars are not one
/// height: on one macOS 26 a plain one measured 28 or 32 points, by how its app was built, and one with a toolbar 52 (Finder, Calculator,
/// System Settings). So a window out of view reaches higher than the corner it was sent to, each by its own measure, which
/// Arbor learns from the answer when it sends a window there.
extension Controller {
  /// What is reckoned with for a window that has not been sent below the bottom yet. The answer puts it right.
  static let guessedTitleBar: CGFloat = 32
  /// No title bar is taken to be higher than this: twice the highest seen.
  static let highestTitleBar: CGFloat = 104

  /// The display that stops a window on its way down to `origin`: the one its corner is on, or the nearest. With one display that is
  /// what was measured, with several it is a guess that the fake window system shares.
  func stopper(of origin: CGPoint) -> DisplaySnapshot? {
    displays.first { $0.frame.contains(origin) }
      ?? displays.min { $0.frame.distance(to: origin) < $1.frame.distance(to: origin) }
  }

  /// Where a window with a title bar this high, asked to go to `origin`, ends up.
  func whereItStops(_ origin: CGPoint, titleBar: CGFloat) -> CGPoint {
    guard let stopper = stopper(of: origin) else { return origin }
    return CGPoint(x: origin.x, y: min(origin.y, stopper.visibleFrame.maxY - titleBar))
  }

  /// The title bar of a window that is at `origin` because macOS stopped it there on its way to `place`. Nil if that cannot be why it
  /// is there: it is not straight above the place, or further above the bottom than macOS stops any window.
  func titleBar(ofAWindowAt origin: CGPoint, sentTo place: CGPoint) -> CGFloat? {
    guard origin.y < place.y, abs(origin.x - place.x) <= 1, let bottom = stopper(of: place)?.visibleFrame.maxY else { return nil }
    let titleBar = bottom - origin.y
    return titleBar > 0 && titleBar <= Self.highestTitleBar ? titleBar : nil
  }

  /// Takes note of how far above the bottom macOS stopped a window that was `asked` to go below it. Says whether that is news. An
  /// answer from anywhere else says nothing: the app refused, or something else moved the window.
  @discardableResult
  func learnTitleBar(of window: WindowID, asked: CGRect, took: CGRect) -> Bool {
    guard let titleBar = titleBar(ofAWindowAt: took.origin, sentTo: asked.origin), titleBars[window] != titleBar else { return false }
    titleBars[window] = titleBar
    return true
  }

  /// Whether `window`, at `origin`, is where it ends up when it is sent to `place`: there, or where macOS stops it.
  func isAsFarAsItGoes(_ window: WindowID, at origin: CGPoint, sentTo place: CGPoint) -> Bool {
    guard abs(origin.x - place.x) <= 1 else { return false }
    if abs(origin.y - place.y) <= 1 { return true }
    return titleBars[window].map { abs(origin.y - whereItStops(place, titleBar: $0).y) <= 1 } ?? false
  }

  /// How many square points of `frame` the displays show. They do not overlap, so what they show adds up.
  func whatShows(of frame: CGRect) -> CGFloat {
    displays.map { frame.intersection($0.frame).area }.reduce(0, +)
  }
}
