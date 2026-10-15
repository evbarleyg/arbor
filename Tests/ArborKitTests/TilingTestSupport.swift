import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// A 1280×800 display to the right of the standard one.
let sideDisplay = DisplaySnapshot(
  id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1280, height: 800),
  visibleFrame: CGRect(x: 1440, y: 0, width: 1280, height: 800), isMain: false)

/// Opens one window per name in the middle of the standard display, starts Arbor and runs `commands`, in
/// which `$0`, `$1`… stand for the windows.
@MainActor
func tilingScenario(
  _ apps: [String], _ commands: [String] = [], displays: [DisplaySnapshot] = [FakeWindowSystem.standardDisplay],
  settings: Settings = Harness.settingsWhenNoneAreGiven, sourceLocation: SourceLocation = #_sourceLocation
) -> (Harness, [WindowID]) {
  let h = Harness(displays: displays, settings: settings)
  let windows = apps.map { h.system.open(app: $0, frame: CGRect(x: 520, y: 300, width: 400, height: 300)) }
  h.start()
  for command in commands { runOK(h, command, windows, sourceLocation: sourceLocation) }
  return (h, windows)
}

/// Settings under which a window that cannot be as small as its slot is a tile at once. By default Arbor first tries to make
/// room for it (F61), and it is a tile only where its neighbours cannot spare the room; these tests are about the tile.
var noRoomMade: Settings {
  var settings = Settings()
  settings.makeRoom = false
  return settings
}

/// Runs a command that is expected to succeed.
@MainActor @discardableResult
func runOK(
  _ h: Harness, _ command: String, _ windows: [WindowID] = [], sourceLocation: SourceLocation = #_sourceLocation
) -> CommandResult {
  var text = command
  for (index, window) in windows.enumerated().reversed() {
    text = text.replacingOccurrences(of: "$\(index)", with: String(window.rawValue))
  }
  let result = h.run(text)
  #expect(result.ok, "\(text): \(result.message)", sourceLocation: sourceLocation)
  return result
}

/// Every tree is sound, every docked window is where its display's layout says, and the window with
/// focus is not one that Arbor has tucked away.
@MainActor
func expectSound(_ h: Harness, sourceLocation: SourceLocation = #_sourceLocation) {
  for (display, workspace) in h.controller.workspaces {
    let problems = workspace.tree.invariantViolations()
    #expect(problems.isEmpty, "\(display): \(problems)", sourceLocation: sourceLocation)
    #expect(workspace.tree.contains(workspace.camera), "\(display): the camera is on a node that is gone", sourceLocation: sourceLocation)
    expectWindowsMatchLayout(h, on: display, sourceLocation: sourceLocation)
  }
  if let focused = h.system.focused {
    #expect(!h.controller.parked.contains(focused), "\(focused) has focus but is out of view", sourceLocation: sourceLocation)
  }
}
