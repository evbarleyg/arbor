import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation

// arbor-sim first-launch [--permitted | --been-here] [lines…]
//
// The first five minutes, to play and to read: a Mac as it comes (macOS's own tiling and the wallpaper click are on), an Arbor that has
// never run on it and has no Accessibility permission (with --permitted it has), and three windows open already (101 Safari, 102 Mail,
// 103 Notes). With --been-here it is no first launch: somebody who has used Arbor starts a build that macOS takes for a new app, so the state file
// says "welcomed" and the permission is missing. The welcome window is the real `OnboardingSession` on the real controller (`FakeWelcomeWindow`); it is printed
// whenever it opens or shows something else, buttons in square brackets. Then the lines run as in any script.
//
// Words that only make sense here:
//   grant                        flip the switch under Privacy & Security → Accessibility: Arbor notices and starts
//   click <button's title>       click a button of the welcome window, e.g. click Let Arbor Have the Screen Edges
//   close-welcome                its close button
//   mac-switch <name> on|off|unset
//                                flip a switch in System Settings → Desktop & Dock: screenEdges, menuBar, optionKey, clickWallpaper,
//                                stageManager. `unset` is how a Mac comes
//   mac-switches                 what is stored for each, and what Arbor has written down
//   welcome-window               print the window as it is
// A second passes after every line, so the window has looked at the Mac again.

@MainActor
final class FirstLaunch {
  let harness: Harness
  private var printed: String?

  /// Takes `first-launch` and its option off the front of `lines`. Nil if the first word is another.
  init?(taking lines: inout [String]) {
    guard lines.first == "first-launch" else { return nil }
    lines.removeFirst()
    var (permitted, beenHere) = (false, false)
    if lines.first == "--permitted" {
      permitted = true
      lines.removeFirst()
    } else if lines.first == "--been-here" {
      beenHere = true
      lines.removeFirst()
    }
    harness = Harness(saved: beenHere ? PersistedState(workspaces: [:], hints: [:], welcomed: true) : nil)
    for (index, app) in ["Safari", "Mail", "Notes"].enumerated() {
      let offset = CGFloat(index) * 120
      harness.system.open(
        app: app, pid: pid(ofApp: app), frame: CGRect(x: 200 + offset, y: 120 + offset / 2, width: 760 - offset, height: 560 - offset / 2))
    }
    if beenHere { harness.launchWithItsWindow(permitted: false) } else { harness.launchForTheFirstTime(permitted: permitted) }
    printWindow()
  }

  /// Prints the window if it says something else than when it was last printed.
  func printWindow(always: Bool = false) {
    let text = harness.welcome.text
    guard always || text != printed else { return }
    printed = text
    guard let text else { return print("the welcome window is closed\n") }
    let width = 100
    print("+-- Arbor " + String(repeating: "-", count: width - 10))
    for line in text.split(separator: "\n", omittingEmptySubsequences: false) { print("| \(line)") }
    print("+" + String(repeating: "-", count: width - 1) + "\n")
  }

  /// After every line of the script.
  func aSecondPasses() {
    let forward = harness.welcome.timesComeForward
    harness.welcome.tick()
    if harness.welcome.timesComeForward > forward { print("the welcome window comes forward") }
    printWindow()
  }

  /// Runs a line that only makes sense here. Nil if it is not one.
  func simulate(_ words: [String]) -> (String, Bool)? {
    let mac = harness.mac
    switch words[0] {
    case "grant" where !harness.controller.isRunning && !harness.controller.isPaused:
      let forward = harness.welcome.timesComeForward
      harness.permissionArrives()
      return ("Accessibility permission granted" + (harness.welcome.timesComeForward > forward ? "; the welcome window comes forward" : ""), true)
    case "click":
      let title = words.dropFirst().joined(separator: " ")
      guard harness.welcome.click(title) else {
        let buttons = harness.welcome.buttons.map { "[\($0)]" }.joined(separator: " ")
        return ("there is no button “\(title)” to click" + (buttons.isEmpty ? ": the window is closed" : "; there are \(buttons)"), false)
      }
      if let pane = harness.welcome.panesOpened.last, title.hasPrefix("Open Settings") { return ("System Settings opens, at \(pane.rawValue)", true) }
      return ("clicked", true)
    case "close-welcome":
      harness.welcome.close()
      return ("closed", true)
    case "welcome-window":
      printWindow(always: true)
      return ("", true)
    case "mac-switch":
      guard words.count == 3, let item = MacSwitch(rawValue: words[1]), ["on", "off", "unset"].contains(words[2]) else {
        return ("usage: mac-switch <\(MacSwitch.allCases.map(\.rawValue).joined(separator: "|"))> on|off|unset", false)
      }
      mac.values[item] = words[2] == "unset" ? nil : words[2] == "on"
      return ("“\(item.label)” is \(words[2])", true)
    case "quit" where words.count == 1:
      // As the app does: `quit` is answered, then the app ends, which shuts the controller down.
      let reply = harness.run("quit")
      harness.controller.shutdown()
      return (reply.message, reply.ok)
    case "relaunch":
      // The window and the words above are wired to this process.
      return ("first-launch plays one launch, the first; `quit` ends it", false)
    case "mac-switches":
      let stored = MacSwitch.allCases.map { "\($0.defaultsKey): \(mac.values[$0].map(String.init) ?? "not set")" }
      let written = mac.before.map {
        "\($0.item.defaultsKey) was \($0.stored.map(String.init) ?? "not set")" + ($0.isGivenBack ? " (given back for now)" : "")
      }
      return ((stored + [written.isEmpty ? "Arbor has written nothing down" : "written down: " + written.joined(separator: ", ")]).joined(separator: "\n"), true)
    default:
      return nil
    }
  }
}
