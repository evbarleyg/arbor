import ArborCore
import ArborKit

/// "A person's ⌘M is never undone" (collab/QUESTIONS.md). The stand-in plays what a Mac does to a minimized window that is given the keyboard or raised: it
/// comes out of the Dock (`FakeWindowSystem.focus`, `raise`). Whoever does it, on whichever road, this net sees what came of it.
extension ChaosRunner {
  func undoneViolations(after action: ChaosAction) -> [InvariantViolation] {
    guard case .minimize(let window, true) = action, let fake = system.windows[window] else { return [] }
    // Counted where it could have gone wrong: Arbor was looking.
    if isRunning { Self.questionsAsked["undone", default: 0] += 1 }
    guard !fake.snapshot.isMinimized else { return [] }
    return [.init("minimize-undone", "its user minimized \(window), and it is back out of the Dock: somebody gave it the keyboard, or raised it, as it landed")]
  }
}
