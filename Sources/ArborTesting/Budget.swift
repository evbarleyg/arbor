import ArborCore
import ArborKit
import CoreGraphics

/// What something cost the window system and the overlays. On a Mac every one of these is a round trip
/// (or several) to another process while the main thread waits, so the counts are what a command's
/// latency is made of. `BudgetTests` pins them and `arbor-sim bench` prints them.
public struct Budget: Equatable, Sendable, CustomStringConvertible {
  /// Windows moved or resized (`setFrame`).
  public var moves = 0
  /// Moves that left the window exactly where it was.
  public var idleMoves = 0
  /// Moves of a window that had already been moved in the same measurement. What follows a question is not one.
  public var repeatMoves = 0
  /// Moves that were not announced with `moveTogether`: each waits for its app on its own.
  public var movesAlone = 0
  /// Moves that were announced and made, and that `setFrame` then never asked for.
  public var unclaimedMoves = 0
  public var focuses = 0
  /// Focusing the window that already had the focus.
  public var idleFocuses = 0
  /// Times Arbor asked which window has the focus.
  public var focusReads = 0
  public var overlayUpdates = 0
  /// Overlay updates with the scene that was already showing.
  public var idleOverlayUpdates = 0
  public var saves = 0
  /// Moves, counted among `moves`, that asked a window for a size where it stood before it went anywhere: nobody knew
  /// whether it would take it (Controller+AskFirst.swift). Each size is asked once, so what is done a second time has none.
  public var questions = 0

  public init(
    moves: Int = 0, idleMoves: Int = 0, repeatMoves: Int = 0, movesAlone: Int = 0, unclaimedMoves: Int = 0,
    focuses: Int = 0, idleFocuses: Int = 0,
    focusReads: Int = 0, overlayUpdates: Int = 0, idleOverlayUpdates: Int = 0, saves: Int = 0, questions: Int = 0
  ) {
    self.moves = moves
    self.idleMoves = idleMoves
    self.repeatMoves = repeatMoves
    self.movesAlone = movesAlone
    self.unclaimedMoves = unclaimedMoves
    self.focuses = focuses
    self.idleFocuses = idleFocuses
    self.focusReads = focusReads
    self.overlayUpdates = overlayUpdates
    self.idleOverlayUpdates = idleOverlayUpdates
    self.saves = saves
    self.questions = questions
  }

  /// Work for other apps that changed nothing or was done twice.
  public var waste: Int { idleMoves + repeatMoves + unclaimedMoves + idleFocuses }

  public var description: String {
    "moves \(moves) (questions \(questions), idle \(idleMoves), repeat \(repeatMoves), alone \(movesAlone), unclaimed \(unclaimedMoves)), focus \(focuses) (idle \(idleFocuses)), "
      + "focus reads \(focusReads), overlays \(overlayUpdates) (idle \(idleOverlayUpdates)), saves \(saves)"
  }
}

extension Harness {
  /// Runs `body`, then the work it scheduled (saves, enforcement, the layout after a Space switch),
  /// and returns what all of it asked of the window system and the overlays.
  public func measure(_ body: () -> Void) -> Budget {
    let moves = system.moveLog.count
    let focuses = system.focusLog.count
    let reads = system.focusedWindowReads
    let updates = overlays.updateLog.count
    let saves = store.saveCount
    body()
    // Scheduled work can schedule more; a put-back waiting for the mouse button would do so forever.
    for _ in 0..<4 where !scheduler.pendingKeys.isEmpty { scheduler.runPending() }

    var budget = Budget.tally(system.moveLog[moves...])
    budget.unclaimedMoves = system.answersAhead.count
    for focus in system.focusLog[focuses...] {
      budget.focuses += 1
      if focus.wasFocused { budget.idleFocuses += 1 }
    }
    budget.focusReads = system.focusedWindowReads - reads
    for update in overlays.updateLog[updates...] {
      budget.overlayUpdates += 1
      if !update.changed { budget.idleOverlayUpdates += 1 }
    }
    budget.saves = store.saveCount - saves
    return budget
  }
}

extension Budget {
  /// What has been done to a window so far: it has only been asked for sizes where it stands (which, and the frames it went
  /// through), or it has been moved.
  private enum Done {
    case asked(sizes: [CGSize], road: [CGRect])
    case moved
  }

  /// What a stretch of `FakeWindowSystem.moveLog` cost: the counts of moves, and nothing else.
  public static func tally(_ log: some Sequence<FakeWindowSystem.Move>) -> Budget {
    var budget = Budget()
    var done: [WindowID: Done] = [:]
    for move in log {
      budget.moves += 1
      if !move.together { budget.movesAlone += 1 }
      var (sizes, road): ([CGSize], [CGRect]) = ([], [move.before])
      if case .asked(let earlier, let way)? = done[move.window] { (sizes, road) = (earlier, way) }
      road.append(move.after)
      // A question leaves the window where it stands, comes before any move, is put once, and takes back nothing that an
      // earlier one achieved. "No" is an answer, so it may change nothing.
      if case .moved? = done[move.window] {
        budget.repeatMoves += 1
      } else if move.after.origin == move.before.origin, move.requested.size != move.before.size,
        !sizes.contains(move.requested.size), FakeWindowSystem.detour(road) == nil
      {
        done[move.window] = .asked(sizes: sizes + [move.requested.size], road: road)
        continue
      }
      // Questions count as such once the window goes somewhere. A resize that was all there was to do is a move like any other.
      budget.questions += sizes.count
      if move.before == move.after { budget.idleMoves += 1 }
      done[move.window] = .moved
    }
    return budget
  }
}
