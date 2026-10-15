import ArborCore
import ArborKit

/// "Arbor raises nothing else" (collab/QUESTIONS.md, Q20 and Q25). Which window lies in front of which is macOS's business. What is acted on or
/// switched to comes to the front with the keyboard, which is no raise; a raise without the keyboard is for a window kept in
/// view or summoned, and for nobody else, running, paused or on the way out.
///
/// `switched-to-behind` sees the harm where there is some: the raised window happens to overlap the one just switched to. This net sees the
/// raise itself, at the step in which it is made, whatever lies where.
extension ChaosRunner {
  func raiseViolations(after action: ChaosAction) -> [InvariantViolation] {
    // It looks at every step, which says little. Counted is how often a walk comes to where Arbor used to raise: a floating window that
    // nothing keeps in view comes back into view. (A pause and a quit empty the list of what is out of view: nothing came back.)
    if wasRunningBefore, isRunning {
      let floating = controller.workspaces.values
      Self.questionsAsked["raised", default: 0] +=
        parkedBefore.subtracting(controller.parked).filter { back in floating.contains { $0.isFloating(back) && !$0.staysInView(back) } }.count
    }
    let raised = system.raiseLog.dropFirst(raiseLogMark)
    // A way back is several things in one step: Arbor is resumed or started, and before a pause all comes to rest, with its looks at a
    // pin falling due.
    var wasRunningMeanwhile = isRunning
    if case .wayBack = action { wasRunningMeanwhile = true }
    // Kept in view when the step began or when it ended: a pin that is set, and one taken off with a look still due. An Arbor that has
    // paused or quit raises nothing at all, a window kept in view included.
    func isKeptInView(_ window: WindowID) -> Bool {
      wasRunningMeanwhile
        && (controller.workspaces.values.contains { $0.staysInView(window) } || workspacesBefore.values.contains { $0.staysInView(window) })
    }
    // The trial `outOfViewIsBehind`: what is in view comes in front of what is left behind, and that is a raise (Controller+Behind.swift). Never
    // of a window that is out of view itself.
    func comesInFrontOfWhatIsBehind(_ window: WindowID) -> Bool {
      wasRunningMeanwhile && controller.settings.outOfViewIsBehind && !controller.parked.contains(window)
    }
    return Set(raised).sorted().filter { !isKeptInView($0) && !comesInFrontOfWhatIsBehind($0) }.map {
      .init("raised-unasked", "Arbor raised \($0), which is neither kept in view nor summoned")
    }
  }
}
