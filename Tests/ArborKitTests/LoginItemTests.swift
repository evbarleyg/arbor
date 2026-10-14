import ArborCore
import ArborKit
import ArborTesting
import Foundation
import Testing

/// `launch-at-login`, through the real controller and a fake list of login items.
@Suite @MainActor struct LoginItemTests {
  @Test func launchAtLoginSwitchesOnAndOffAndReports() {
    let h = Harness()
    #expect(h.run("launch-at-login").message == "off")
    #expect(h.loginItem.changes.isEmpty)  // asking changes nothing

    let on = h.run("launch-at-login on")
    #expect(on.ok)
    #expect(on.message == "Arbor opens at login")
    #expect(h.loginItem.status == .enabled)
    #expect(h.run("launch-at-login").message == "on")

    let off = h.run("launch-at-login off")
    #expect(off.ok)
    #expect(off.message == "Arbor does not open at login")
    #expect(h.loginItem.status == .disabled)
    #expect(h.loginItem.changes == [true, false])
  }

  @Test func launchAtLoginNeedsNoAccessibilityPermission() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    #expect(h.run("launch-at-login on").ok)
    #expect(h.loginItem.status == .enabled)
  }

  @Test func askingForWhatIsAlreadySoAsksMacOSForNothing() {
    let h = Harness()
    #expect(h.run("launch-at-login off").ok)
    h.loginItem.status = .enabled
    #expect(h.run("launch-at-login on").ok)
    #expect(h.loginItem.changes.isEmpty)
  }

  @Test func aRefusalIsReportedWithWhatIsTrueNow() {
    let h = Harness()
    h.loginItem.refuses = true
    let on = h.run("launch-at-login on")
    #expect(!on.ok)
    #expect(on.message == "Arbor does not open at login (macOS refused: operation not permitted)")
    h.loginItem.status = .enabled
    let off = h.run("launch-at-login off")
    #expect(!off.ok)
    #expect(off.message == "Arbor opens at login (macOS refused: operation not permitted)")
  }

  @Test func anItemTheUserSwitchedOffInSystemSettingsIsExplained() {
    let h = Harness()
    h.loginItem.refuses = true
    h.loginItem.statusAfterRefusal = .requiresApproval  // what macOS does when the user has said no before
    let on = h.run("launch-at-login on")
    #expect(!on.ok)
    #expect(on.message.contains("System Settings → General → Login Items & Extensions"))
    // Asked, it is off, for a script, and says why, for a person.
    let asked = h.run("launch-at-login")
    #expect(asked.ok)
    #expect(asked.message.hasPrefix("off: "))
    #expect(asked.message.contains("System Settings → General → Login Items & Extensions"))
    // Asking again does not pester macOS, asking how things are is not a failure, and `off` removes the entry.
    #expect(!h.run("launch-at-login on").ok)
    #expect(h.loginItem.changes == [true])
    #expect(h.run("launch-at-login").ok)
    h.loginItem.refuses = false
    #expect(h.run("launch-at-login off").ok)
    #expect(h.loginItem.status == .disabled)
  }

  @Test func aCopyThatCannotOpenAtLoginSaysWhy() {
    let h = Harness()
    h.loginItem.status = .unavailable("Arbor is not running from an app bundle")
    for command in ["launch-at-login", "launch-at-login on", "launch-at-login off"] {
      let result = h.run(command)
      #expect(!result.ok)
      #expect(result.message == "Arbor is not running from an app bundle")
    }
    #expect(h.loginItem.changes.isEmpty)
    h.controller.loginItem = nil
    #expect(h.run("launch-at-login on").message == "this build cannot open at login")
  }

  @Test func launchAtLoginParsesAndRoundTrips() throws {
    #expect(try Command.parse("launch-at-login") == .launchAtLogin(nil))
    #expect(try Command.parse("launch-at-login ON") == .launchAtLogin(true))
    #expect(try Command.parse("launch-at-login off") == .launchAtLogin(false))
    for command in [Command.launchAtLogin(nil), .launchAtLogin(true), .launchAtLogin(false)] {
      #expect(try Command.parse(command.text) == command)
    }
    #expect(Command.launchAtLogin(nil).isQuery)
    #expect(!Command.launchAtLogin(true).isQuery)
    #expect(throws: Command.ParseError.self) { try Command.parse("launch-at-login maybe") }
    #expect(throws: Command.ParseError.self) { try Command.parse("launch-at-login on off") }
  }

  /// Any web page can open a URL, and this one would make Arbor start with the Mac, or stop it from doing so.
  @Test func launchAtLoginIsRefusedFromURLs() throws {
    for url in ["arbor://launch-at-login", "arbor://launch-at-login/on", "arbor://launch-at-login/off"] {
      #expect(try !Command.parse(url: url).isAllowedFromURL, "\(url)")
    }
  }
}
