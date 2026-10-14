import ApplicationServices
import CoreGraphics
import Foundation

// How a run ends that gives no verdict, and what it says then.
//
// All of these used to be exit code 2, and whatever was thrown was called "setup failed". A loop on a person's Mac reported "not run (exit 2)"
// eleven times in a row, everybody took it for "somebody is at the Mac", and it was "Arbor did not find the three test windows". So: a
// code each, one line that says which, and under it what the Mac says of itself. scripts/e2e.sh puts that block first in a report.

enum Ending: Int32 {
  /// No Accessibility permission for the terminal, or a binary is not built. Somebody has to do something first.
  case notReady = 2
  /// Somebody touched the keyboard or the pointer, before the start or in the middle (Manners.swift).
  case somebodyIsHere = 3
  /// Set-up failed while the screen was locked, the display asleep, or another user's session on the console.
  case nobodyCouldSeeIt = 4
  /// The test windows or Arbor did not come up as they must, on a Mac that looks ready.
  case setupFailed = 5
  /// The run was under way and Arbor, or a test window, stopped answering.
  case lostInMidRun = 6
  case outOfTime = 7
}

/// One line, which begins the same way whatever the reason, and then `facts`, indented. A blank line ends the block.
func announce(code: Int32, _ why: String, facts: [String] = []) {
  print("\narbor-e2e: no verdict (exit \(code)): \(why)")
  for fact in facts { print("  \(fact)") }
  print("")
}

func announce(_ ending: Ending, _ why: String, facts: [String] = []) {
  announce(code: ending.rawValue, why, facts: facts)
}

/// What macOS says of the session this runs in. Yes, no and numbers: nothing of the person whose Mac it is.
struct MacState {
  var hasSession: Bool
  var isOnConsole: Bool
  var isLocked: Bool
  var displayIsAsleep: Bool
  var screenSaverIsUp: Bool

  /// Whether a process of that very name runs.
  private static func runs(_ name: String) -> Bool {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    process.arguments = ["-x", name]
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return false }
    process.waitUntilExit()
    return process.terminationStatus == 0
  }

  static var now: MacState {
    let session = CGSessionCopyCurrentDictionary() as? [String: Any]
    func flag(_ key: String) -> Bool { (session?[key] as? NSNumber)?.boolValue ?? false }
    return MacState(
      hasSession: session != nil, isOnConsole: flag("kCGSSessionOnConsoleKey"), isLocked: flag("CGSSessionScreenIsLocked"),
      displayIsAsleep: CGDisplayIsAsleep(CGMainDisplayID()) != 0, screenSaverIsUp: runs("ScreenSaverEngine"))
  }

  /// Why nobody could see a window now, or nil.
  var whyNothingShows: String? {
    if !hasSession { return "this process has no session with the window server" }
    if !isOnConsole { return "another user's session is on the console" }
    if isLocked { return "the screen is locked" }
    if displayIsAsleep { return "the display is asleep" }
    if screenSaverIsUp { return "the screen saver is up" }
    return nil
  }

  var inWords: String {
    func word(_ value: Bool) -> String { value ? "yes" : "no" }
    let idle = secondsSinceInput().map { "\(Int($0)) s" } ?? "unknown"
    return "screen locked: \(word(isLocked)); display asleep: \(word(displayIsAsleep)); screen saver: \(word(screenSaverIsUp)); "
      + "on the console: \(word(isOnConsole)); "
      + "last input: \(idle) ago"
  }
}

extension Runner {
  /// When the display was last turned off and on, from macOS's own log, in UTC: the person's time zone is nobody's business.
  static func displayLog() -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sh")
    process.arguments = ["-c", "/usr/bin/pmset -g log | /usr/bin/grep 'Display is turned' | /usr/bin/tail -n 3"]
    let output = Pipe()
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    guard (try? process.run()) != nil else { return "unknown" }
    let text = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    process.waitUntilExit()
    let theirs = DateFormatter()
    theirs.locale = Locale(identifier: "en_US_POSIX")
    theirs.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
    let ours = DateFormatter()
    ours.locale = Locale(identifier: "en_US_POSIX")
    ours.timeZone = TimeZone(identifier: "UTC")
    ours.dateFormat = "HH:mm:ss"
    // `2026-01-02 03:04:05 +0100 Notification        	Display is turned off`
    let turns = text.split(separator: "\n").compactMap { line -> String? in
      guard let date = theirs.date(from: String(line.prefix(25))) else { return nil }
      return "\(line.contains("turned off") ? "off" : "on") at \(ours.string(from: date)) UTC"
    }
    return turns.isEmpty ? "unknown" : turns.joined(separator: ", ")
  }

  /// For a set-up that failed: what the window server and Accessibility say of the test windows when this runner asks them itself,
  /// with the permission Arbor has (both are the terminal's children).
  func whatTheMacSays() -> [String] {
    var facts = [MacState.now.inWords, "Accessibility for what this terminal starts: \(AXIsProcessTrusted() ? "granted" : "NOT granted")"]
    guard helperPID != 0 else { return facts }

    let list = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    let ours = list.filter { ($0[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == helperPID }
    let onScreen = ours.filter { ($0[kCGWindowIsOnscreen as String] as? NSNumber)?.boolValue ?? false }
    facts.append(
      "the window server lists \(ours.count) window(s) of the test app, \(onScreen.count) of them on screen "
        + "(off screen: another Space is in front, or they are hidden)")

    let app = AXUIElementCreateApplication(helperPID)
    AXUIElementSetMessagingTimeout(app, 2)
    var value: CFTypeRef?
    let error = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value)
    let windows = value as? [AXUIElement] ?? []
    facts.append(
      "Accessibility, asked for the test app's windows: error \(error.rawValue), \(windows.count) window(s) "
        + "(0 is success, -25204 cannot complete, -25211 the API is disabled)")
    // What Arbor goes by when it takes a window up or leaves it: only an AXWindow that is an AXStandardWindow is one to arrange.
    func text(_ element: AXUIElement, _ attribute: String) -> String {
      var value: CFTypeRef?
      let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
      guard error == .success else { return "error \(error.rawValue)" }
      return (value as? String) ?? (value as? NSNumber).map { $0.boolValue ? "yes" : "no" } ?? "?"
    }
    for window in windows.prefix(3) {
      facts.append(
        "  a window: role \(text(window, kAXRoleAttribute)), subrole \(text(window, kAXSubroleAttribute)), "
          + "minimized \(text(window, kAXMinimizedAttribute))")
    }
    // And what it needs before it reads that list at all.
    var observer: AXObserver?
    let created = AXObserverCreate(helperPID, { _, _, _, _ in }, &observer)
    let added = observer.map { AXObserverAddNotification($0, app, kAXWindowCreatedNotification as CFString, nil).rawValue }
    facts.append("an observer of the test app: created with error \(created.rawValue), told of new windows with error \(added.map(String.init) ?? "-")")
    facts.append("the display went: \(Self.displayLog())")

    facts.append("the test app is \(helper?.isRunning == true ? "running" : "NOT running"); Arbor is \(arborPID() == nil ? "NOT running" : "running")")
    return facts
  }
}
