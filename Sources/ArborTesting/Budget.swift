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
  /// Moves of a window that had already been moved in the same measurement.
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

  public init(
    moves: Int = 0, idleMoves: Int = 0, repeatMoves: Int = 0, movesAlone: Int = 0, unclaimedMoves: Int = 0,
    focuses: Int = 0, idleFocuses: Int = 0,
    focusReads: Int = 0, overlayUpdates: Int = 0, idleOverlayUpdates: Int = 0, saves: Int = 0
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
  }

  /// Work for other apps that changed nothing or was done twice.
  public var waste: Int { idleMoves + repeatMoves + unclaimedMoves + idleFocuses }

  public var description: String {
    "moves \(moves) (idle \(idleMoves), repeat \(repeatMoves), alone \(movesAlone), unclaimed \(unclaimedMoves)), focus \(focuses) (idle \(idleFocuses)), "
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

    var budget = Budget()
    var seen = Set<WindowID>()
    for move in system.moveLog[moves...] {
      budget.moves += 1
      if move.before == move.after { budget.idleMoves += 1 }
      if !seen.insert(move.window).inserted { budget.repeatMoves += 1 }
      if !move.together { budget.movesAlone += 1 }
    }
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
