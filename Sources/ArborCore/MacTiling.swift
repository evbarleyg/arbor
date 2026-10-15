import CoreGraphics

/// macOS's own tiling of a window that is being dragged (macOS 15 and later; System Settings → Desktop & Dock → Windows), as
/// far as Arbor has to know it to keep out of its way: which of the three switches are on, and where the pointer has to be
/// for macOS to take the window when it is let go.
///
/// All three are on as a Mac comes, and macOS asks nobody. Where both react to one drag, two previews show, and the window
/// moves three times when it is let go: into Arbor's slot, from there to macOS's tile over a third of a second, and half a
/// second later back into the slot. So where macOS acts, Arbor stands aside: no preview, no docking, and no frame set.
///
/// The places were measured on macOS 26.6 with every switch as it comes, on a display of 1024×768 whose menu bar leaves
/// the visible frame beginning at y 31, by holding a window with the pointer at one point after another and looking for
/// macOS's preview among the window server's windows:
///
/// - left and right: at x 0 and at x 1023; not at 1, 2, 1021 or 1022. A half from y 60 to y 740, a quarter at y 0, 31 and 767;
/// - the top: from y 0 to y 30; not at 31, 32 or 42. At the bottom edge, nothing. Only for a pointer that has rested there: let go
///   0.1 s after it arrived the window was left alone, after 0.2 s it filled the screen. At the sides macOS waits for nothing;
/// - with ⌥ held: wherever the pointer is, and whatever else is held (⇧, ⌘, ⌃⌘, ⌃⇧). ⇧ alone changes nothing. With ⌥ and nothing else, let go
///   with posted keys, the preview was all: the window stayed where it was. Arbor stands aside either way;
/// - a window that cannot change its size is taken all the same, and moved into the tile as it is (not with ⌥);
/// - with the pointer beyond the display, where a hand's cannot go but a display that was unplugged leaves it: nothing.
public struct MacTiling: Equatable, Sendable, Codable {
  /// "Drag windows to left or right edge of screen to tile".
  public var screenEdges: Bool
  /// "Drag windows to menu bar to fill screen".
  public var menuBar: Bool
  /// "Hold ⌥ key while dragging windows to tile".
  public var optionKey: Bool

  public init(screenEdges: Bool, menuBar: Bool, optionKey: Bool) {
    self.screenEdges = screenEdges
    self.menuBar = menuBar
    self.optionKey = optionKey
  }

  /// From the settings that are in Arbor's way as they stand (`MacSwitch.inTheWay`).
  public init(_ switches: [MacSwitch]) {
    self.init(
      screenEdges: switches.contains(.screenEdges), menuBar: switches.contains(.menuBar),
      optionKey: switches.contains(.optionKey))
  }

  /// A macOS that has no such thing, or where all of it is switched off.
  public static let off = MacTiling(screenEdges: false, menuBar: false, optionKey: false)
  /// As a Mac comes.
  public static let on = MacTiling(screenEdges: true, menuBar: true, optionKey: true)

  /// The screen edges that are macOS's as the switches stand. It acts only at their last point, but a hand pushes a window against an edge,
  /// so Arbor leaves it the whole of its own band along them (`DropOptions.silentEdges`). The bottom edge is nobody's but Arbor's.
  public var edges: Set<Edge> {
    var edges: Set<Edge> = screenEdges ? [.left, .right] : []
    if menuBar { edges.insert(.top) }
    return edges
  }

  /// How long the pointer has to rest in the menu bar before macOS fills the screen, in seconds: somewhere between 0.1 and 0.2. Arbor does
  /// not go by it. Taking a window back that macOS then takes after all is the fight again, and leaving one alone that macOS
  /// leaves alone too costs nothing: it floats where it was let go.
  public static let menuBarRest = 0.15

  /// Why a window is macOS's.
  public enum Claim: Equatable, Sendable {
    /// The pointer is at the left or the right edge of the display: a half, or in the corners a quarter.
    case side
    /// It is in the menu bar: the whole screen.
    case menuBar
    /// ⌥ is held: the half the pointer is in.
    case optionKey
  }

  /// Why macOS gives a window a place of its own choosing when it is let go with the pointer at `point`, or nil if it does not.
  /// - Parameters:
  ///   - frame: the whole of the display under the pointer.
  ///   - visibleFrame: that display without the menu bar and the Dock.
  ///   - optionHeld: whether ⌥ is down.
  public func claim(onWindowLetGoAt point: CGPoint, on frame: CGRect, visibleFrame: CGRect, optionHeld: Bool) -> Claim? {
    guard frame.contains(point) else { return nil }
    // In this order: in the corner of the menu bar macOS showed a quarter.
    if screenEdges, point.x < frame.minX + 1 || point.x >= frame.maxX - 1 { return .side }
    // With the menu bar hidden, which was not tried, the pointer stops in the display's first row.
    if menuBar, point.y < max(visibleFrame.minY, frame.minY + 1) { return .menuBar }
    if optionKey, optionHeld { return .optionKey }
    return nil
  }
}

extension MacTiling {
  /// How far a tile's edges lie inside the part of the screen it stands for, at the most: macOS's own margins ("Tiled windows have margins")
  /// and an app that rounds its size.
  public static let tileMargin: CGFloat = 12

  /// Whether `frame` is one of the places macOS's own tiling puts a window on a display whose visible frame is `visible`: a half, a quarter or
  /// a third of it, with or without macOS's margins. Not the whole of it, which is filling, and not the middle, which is centring.
  ///
  /// Measured on macOS 26 on a visible frame of 0,31 1024×677: Window ▸ Move & Resize ▸ Left ends at 0,31 513×677.
  public static func isTile(_ frame: CGRect, of visible: CGRect) -> Bool {
    guard visible.width > 0, visible.height > 0 else { return false }
    let across = Span.all.filter { $0.isFilled(from: frame.minX, to: frame.maxX, within: visible.minX, length: visible.width) }
    let down = Span.all.filter { $0.isFilled(from: frame.minY, to: frame.maxY, within: visible.minY, length: visible.height) }
    return across.contains { x in
      down.contains { y in
        if x.isWhole && y.isWhole { return false }
        // Thirds are columns or rows: macOS has no ninth, and no sixth.
        if x.isThird { return y.isWhole }
        if y.isThird { return x.isWhole }
        return true
      }
    }
  }

  /// Whether `frame` is as large as the screen: the whole of `visible`, with or without macOS's margins. By its edges, like a tile.
  public static func fillsTheScreen(_ frame: CGRect, of visible: CGRect) -> Bool {
    guard visible.width > 0, visible.height > 0 else { return false }
    return Span.all[0].isFilled(from: frame.minX, to: frame.maxX, within: visible.minX, length: visible.width)
      && Span.all[0].isFilled(from: frame.minY, to: frame.maxY, within: visible.minY, length: visible.height)
  }

  /// The part of a display's width, or of its height, that a tile can have.
  private struct Span {
    var from: CGFloat
    var to: CGFloat
    var isWhole: Bool { to - from == 1 }
    var isThird: Bool { to - from < 0.4 }

    static let all: [Span] = [
      Span(from: 0, to: 1), Span(from: 0, to: 0.5), Span(from: 0.5, to: 1),
      Span(from: 0, to: 1.0 / 3), Span(from: 1.0 / 3, to: 2.0 / 3), Span(from: 2.0 / 3, to: 1),
    ]

    /// Inside it by no more than the margin, and over it by no more than a rounding.
    func isFilled(from start: CGFloat, to end: CGFloat, within origin: CGFloat, length: CGFloat) -> Bool {
      let first = origin + from * length
      let last = origin + to * length
      return start >= first - 2 && start <= first + MacTiling.tileMargin && end <= last + 2 && end >= last - MacTiling.tileMargin
    }
  }
}
