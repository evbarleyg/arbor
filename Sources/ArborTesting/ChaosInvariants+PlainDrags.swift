import ArborCore
import ArborKit

/// "A dragged window floats" (collab/QUESTIONS.md, Q29). Putting a window somewhere else is what people do with a title bar, most of the
/// time, and it is macOS's own act: while nothing is held that asks Arbor to dock (`dragDocks`), Arbor shows nothing, and when the
/// window is let go nothing but that window has moved.
///
/// `moved-unasked` would let much of this through: it speaks only where the display is laid out as it was, and a drop that docks lays
/// it out anew. This net goes by what the hand held.
extension ChaosRunner {
  /// Whether a window dragged at this moment is offered anywhere to dock: how Arbor is set, and what is held.
  var aDragIsOfferedPlaces: Bool { DragDocks(setting: controller.settings.dragDocks).docks(holding: system.modifierKeysDown()) }

  /// Before the action: the window that Arbor knows to be dragged, if it is dragged plainly.
  func notePlainDrag() {
    plainlyInHandBefore = system.dragging.flatMap { controller.draggedWindow == $0 && !aDragIsOfferedPlaces ? $0 : nil }
  }

  func plainDragViolations(after action: ChaosAction) -> [InvariantViolation] {
    guard wasRunningBefore, isRunning else { return [] }
    var problems: [InvariantViolation] = []
    if let inHand = system.dragging, controller.draggedWindow == inHand, !aDragIsOfferedPlaces, let preview = harness.overlays.preview {
      problems.append(.init("previewed-unasked", "\(inHand) is dragged with nothing held that docks, and Arbor shows a preview at \(preview.brief)"))
    }
    guard action == .release, let dropped = plainlyInHandBefore, system.dragging == nil, system.windows[dropped] != nil else { return problems }
    Self.questionsAsked["plain-drop", default: 0] += 1
    let wasDocked = workspacesBefore.values.contains { $0.isDocked(dropped) }
    let isDocked = controller.workspaces.values.contains { $0.isDocked(dropped) }
    // What is beside what, not how wide: a layout may settle what was owed to the gaps, and whom that moves is asked below.
    let shapes = { (all: [DisplayID: Workspace]) in all.mapValues { Self.shape(of: $0.tree, waiting: []) } }
    let sameTrees = shapes(workspacesBefore) == shapes(controller.workspaces)
    // Docked before and after, in the same place: it had only slipped.
    if isDocked, !(wasDocked && sameTrees) {
      problems.append(.init("plain-drag-docked", "\(dropped) was let go with nothing held that docks, and is docked"))
    }
    // A docked window comes out, and its neighbours take the room. A floating one changes nothing but its own place.
    guard !wasDocked, !isDocked else { return problems }
    // Carried to another display it leaves one Desktop and comes to another: a fault of its own, older than this net (`knownFailures`).
    let home = { (all: [DisplayID: Workspace]) in all.first { $0.value.isFloating(dropped) }?.key }
    let stayed = home(workspacesBefore) == home(controller.workspaces)
    if !sameTrees, stayed {
      problems.append(.init("plain-drag-rearranged", "\(dropped), which floats, was let go with nothing held that docks, and the arrangement is another"))
    }
    // What a trial of live reflow pushed aside goes back, and the only floating window may be given the Desktop: both are switched on
    // by whoever wants them. What was owed a move before has it coming whatever happens.
    guard !wasTryingOutADrop, !controller.settings.soleFloatTakesDesktop else { return problems }
    let owed = owedAMoveBefore.union(owedAPlaceBefore).union(owedTheWayBackBefore)
    let others = Set(system.moveLog.dropFirst(seven.moveLogMark).filter { $0.before != $0.after && $0.window != dropped }.map(\.window))
    let rule = stayed ? "plain-drag-moved-another" : "plain-drag-across-displays-moved-another"
    for other in others.subtracting(owed).sorted() {
      problems.append(.init(rule, "\(dropped), which floats, was let go with nothing held that docks, and Arbor moved \(other)"))
    }
    return problems
  }
}
