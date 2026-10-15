import ArborCore
import ArborTesting

/// What the user's hands do besides moving windows: words for stories about where a command came
/// from and what was touched last (docs/features/F56-keys-follow-the-keyboard.md). Nil for any other word.
@MainActor
func simulateHands(_ words: [String], harness: Harness) -> (String, Bool)? {
  func report(_ result: CommandResult) -> (String, Bool) { ((result.ok ? "" : "error: ") + result.message, result.ok) }
  let rest = words.dropFirst().joined(separator: " ")

  switch words[0] {
  case "press":
    guard words.count > 1 else { return ("usage: press <command>", false) }
    return report(harness.press(rest))
  case "from":
    let sources = CommandSource.allCases.map(\.rawValue).joined(separator: "|")
    guard words.count > 2, let source = CommandSource(rawValue: words[1]) else {
      return ("usage: from <\(sources)> <command>", false)
    }
    return report(harness.run(words.dropFirst(2).joined(separator: " "), from: source))
  case "keydown", "keyup", "key":
    guard words.count == 2, (try? KeyChord(text: words[1])) != nil else {
      return ("usage: \(words[0]) <shortcut>, e.g. \(words[0]) ctrl+opt+space", false)
    }
    if words[0] == "keyup" {
      harness.keyUp(words[1])
      return ("let go of \(words[1])", true)
    }
    let handedOver = harness.system.keysTheAppInFrontGot.count
    let result = words[0] == "key" ? harness.key(words[1]) : harness.keyDown(words[1])
    if harness.system.keysTheAppInFrontGot.count > handedOver {
      return ("pressed \(words[1]): Arbor does not hold it, so the app in front gets it", true)
    }
    return result.map(report) ?? ("pressed \(words[1])", true)
  case "mouse":
    guard words.count == 2, ["down", "up"].contains(words[1]) else { return ("usage: mouse down|up", false) }
    harness.system.mouseDown = words[1] == "down"
    return ("the mouse button is \(words[1])", true)
  case "type":
    harness.system.type()
    return ("typed into \(harness.system.focused.map { String($0.rawValue) } ?? "nothing")", true)
  case "wait":
    guard words.count == 2, let seconds = Double(words[1]), (0...86_400).contains(seconds) else {
      return ("usage: wait <seconds>", false)
    }
    harness.scheduler.advance(by: seconds)
    return ("\(words[1]) s later", true)
  default:
    return nil
  }
}
