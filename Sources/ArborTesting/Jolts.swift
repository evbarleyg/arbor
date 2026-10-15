import ArborCore
import ArborKit
import CoreGraphics

/// "A window moves once, to where it ends up" (docs/GUIDE.md, "What Arbor promises"), read off the fake's `moveLog`.
///
/// A jolt is Arbor changing its own mind where a person can see it: it asked a window for a frame, the window's app
/// did exactly as it was asked, nobody else touched the window, and before the command or event was over Arbor asked
/// the same window for another frame. Not a jolt: asking again because the app answered with another size than it was asked for
/// (nobody can know an app's limits before asking), two moves of which a person sees one, because the
/// place in between is out of view like the place before or after it, and a question: a window of which Arbor does not know how small
/// it goes is asked to shrink where it stands and goes to its place afterwards, which is one road (Roads.swift). Nor a window sized where
/// its size fits and then moved into a frame that hangs over the edge of the screen, into which macOS lets nobody grow (`isSizedWhereItFits`).
public struct Jolt: Equatable, Sendable, CustomStringConvertible {
  public var window: WindowID
  public var from: CGRect
  public var via: CGRect
  public var to: CGRect
  /// Before the second move some app, this window's or another's, had answered with another frame than it was asked for.
  /// What Arbor learns from that can change where everything goes.
  public var whileLearning = false

  public init(window: WindowID, from: CGRect, via: CGRect, to: CGRect, whileLearning: Bool = false) {
    (self.window, self.from, self.via, self.to, self.whileLearning) = (window, from, via, to, whileLearning)
  }

  public var description: String { "\(window) went from \(from.brief) by way of \(via.brief) to \(to.brief)" }
}

extension FakeWindowSystem {
  /// The jolts among the moves Arbor has made since the move log was `mark` long.
  public func jolts(since mark: Int) -> [Jolt] {
    var last: [WindowID: Move] = [:]
    var found: [Jolt] = []
    var learning = false
    func asAsked(_ move: Move) -> CGRect {
      whereMacOSPuts(move.requested, titleBar: windows[move.window]?.titleBar ?? Self.usualTitleBar)
    }
    for move in moveLog[min(mark, moveLog.count)...] {
      defer { if move.after != asAsked(move) { learning = true } }
      guard move.before != move.after else { continue }
      // What nobody can see belongs to the move before it: a window asked for a size in its corner is still in its corner, and
      // one that is fetched from there has been out of view and back all the same.
      if !shows(move.before), !shows(move.after), var earlier = last[move.window], earlier.after == move.before {
        (earlier.requested, earlier.after) = (move.requested, move.after)
        last[move.window] = earlier
        continue
      }
      defer { last[move.window] = move }
      guard let first = last[move.window],
        // The app did as it was asked, so there was nothing to learn from its answer.
        first.after == asAsked(first),
        // Nobody else has had the window since.
        first.after == move.before,
        // Not a question: a size where it stood, and from there straight on.
        first.after.origin != first.before.origin || Self.detour([first.before, first.after, move.after]) != nil,
        !isSizedWhereItFits(first, then: move)
      else { continue }
      let (before, between, after) = (shows(first.before), shows(first.after), shows(move.after))
      if between || (before && after) {
        found.append(Jolt(window: move.window, from: first.before, via: first.after, to: move.after, whileLearning: learning))
      }
    }
    return found
  }

  /// Whether some display shows more of `frame` than the sliver, a point or two wide, that is left of a window out of view.
  private func shows(_ frame: CGRect) -> Bool {
    displayList.contains {
      let showing = frame.intersection($0.frame)
      return !showing.isNull && showing.width > 2 && showing.height > 2
    }
  }
}
