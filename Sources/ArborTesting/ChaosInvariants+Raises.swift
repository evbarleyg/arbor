import ArborCore
import ArborKit

/// "Arbor raises nothing else" (collab/QUESTIONS.md, Q20 and Q25). Which window lies in front of which is macOS's business. What is acted on or
/// switched to comes to the front with the keyboard, which is no raise; a raise without the keyboard is for a window as it is pinned
/// or summoned, once, and for nobody else and at no other time, running, paused or on the way out.
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
    // Kept in view when the step ended and not when it began: that is the pin being set. There are no retries, so what covers it later is
    // no reason. An Arbor that has paused or quit raises nothing at all.
    func isBeingPinned(_ window: WindowID) -> Bool {
      isRunning && controller.workspaces.values.contains { $0.staysInView(window) }
        && !workspacesBefore.values.contains { $0.staysInView(window) }
    }
    var problems: [InvariantViolation] = Set(raised).sorted().filter { !isBeingPinned($0) }.map {
      .init("raised-unasked", "Arbor raised \($0), which is not being pinned or summoned in this step")
    }
    for window in Set(raised).sorted() where isBeingPinned(window) && raised.filter({ $0 == window }).count > 1 {
      problems.append(.init("raised-unasked", "Arbor raised \(window) \(raised.filter { $0 == window }.count) times as it was pinned: once is the rule"))
    }
    return problems
  }
}
