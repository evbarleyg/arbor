import CoreGraphics

/// The room that windows kept in view reserve on their display (F49; collab/QUESTIONS.md Q25).
///
/// macOS lets nobody lift another app's window over the window that has the keyboard: the Accessibility raise brings it in front
/// of everything else and stops there. So a call kept in view lay wholly behind the editor that filled the screen. Keep in View
/// therefore makes room instead of fighting for the front: like the Dock, a window kept in view takes a strip off its display,
/// and every view, a window that fills the screen, a group, everything, is laid out in what is left.
///
/// A strip runs from the window's inner edge to the display's edge, over the whole height or width. Of the four there are, it
/// is the one that costs the least. Where even that costs too much (a window in the middle, or a very large one) none
/// is reserved, and Arbor says so rather than squeeze everything else.
///
/// It is a function of where the windows are and of the order they were pinned in, never of the road that led there.
public struct PinnedRoom: Equatable, Sendable {
  public struct Strip: Equatable, Sendable {
    public var window: WindowID
    /// The edge of the display that it lies along.
    public var edge: Edge
    public var frame: CGRect

    public init(window: WindowID, edge: Edge, frame: CGRect) {
      self.window = window
      self.edge = edge
      self.frame = frame
    }
  }

  /// What is left of the display for views.
  public var room: CGRect
  /// In the order reserved. A window that lies within an earlier one's strip has room there, and none of its own.
  public var strips: [Strip] = []
  /// The windows for which there was no room: docked windows may lie under them, or over them.
  public var without: [WindowID] = []

  /// All the strips of a display together take no more than this share of it.
  public static let largestShare: CGFloat = 0.4

  public init(room: CGRect, strips: [Strip] = [], without: [WindowID] = []) {
    self.room = room
    self.strips = strips
    self.without = without
  }

  /// - Parameters:
  ///   - view: the display's visible frame.
  ///   - kept: the windows kept in view on it that take up room, in the order they were pinned. What hangs over the display's
  ///     edge needs no room, and a window of which nothing shows here needs none at all.
  public static func reserve(in view: CGRect, for kept: [(window: WindowID, frame: CGRect)]) -> PinnedRoom {
    var result = PinnedRoom(room: view)
    for (window, frame) in kept {
      let showing = frame.intersection(result.room)
      guard showing.area > 0 else { continue }
      // Whole points, outwards from the window: a slot never begins half a point under it.
      let cheapest = Edge.allCases
        .map { Strip(window: window, edge: $0, frame: strip(along: $0, of: result.room, upTo: showing)) }
        .min { $0.frame.area < $1.frame.area }!
      let left = result.room.without(cheapest)
      guard view.area - left.area <= largestShare * view.area else {
        result.without.append(window)
        continue
      }
      result.strips.append(cheapest)
      result.room = left
    }
    return result
  }

  private static func strip(along edge: Edge, of room: CGRect, upTo window: CGRect) -> CGRect {
    switch edge {
    case .left: CGRect(x: room.minX, y: room.minY, width: window.maxX.rounded(.up) - room.minX, height: room.height)
    case .right: CGRect(x: window.minX.rounded(.down), y: room.minY, width: room.maxX - window.minX.rounded(.down), height: room.height)
    case .top: CGRect(x: room.minX, y: room.minY, width: room.width, height: window.maxY.rounded(.up) - room.minY)
    case .bottom: CGRect(x: room.minX, y: window.minY.rounded(.down), width: room.width, height: room.maxY - window.minY.rounded(.down))
    }
  }
}

extension CGRect {
  fileprivate func without(_ strip: PinnedRoom.Strip) -> CGRect {
    switch strip.edge {
    case .left: CGRect(x: strip.frame.maxX, y: minY, width: maxX - strip.frame.maxX, height: height)
    case .right: CGRect(x: minX, y: minY, width: strip.frame.minX - minX, height: height)
    case .top: CGRect(x: minX, y: strip.frame.maxY, width: width, height: maxY - strip.frame.maxY)
    case .bottom: CGRect(x: minX, y: minY, width: width, height: strip.frame.minY - minY)
    }
  }
}
