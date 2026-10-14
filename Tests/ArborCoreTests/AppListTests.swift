import ArborCore
import Foundation
import Testing

/// The lists of apps that keep their own ⌃⌥ or pause Arbor, and the command that edits the first
/// (docs/features/F41-pass-through-apps.md).
@Suite struct AppListTests {
  @Test func oldSettingsFilesLoadWithEmptyLists() throws {
    let settings = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8))
    #expect(settings.passThroughApps.isEmpty)
    #expect(settings.pauseForApps.isEmpty)
    #expect(!settings.passesThrough("org.gnu.Emacs"))
    #expect(!settings.pausesFor("org.gnu.Emacs"))
  }

  @Test func theListsRoundTrip() throws {
    var settings = Settings()
    settings.passThroughApps = ["org.gnu.Emacs", "com.vmware.fusion"]
    settings.pauseForApps = ["com.valvesoftware.steam"]
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
  }

  @Test func anAppIsFoundWhateverTheCaseItWasTypedIn() {
    var settings = Settings()
    settings.passThroughApps = ["org.gnu.emacs"]
    settings.pauseForApps = ["COM.EXAMPLE.GAME"]
    #expect(settings.passesThrough("org.gnu.Emacs"))
    #expect(settings.pausesFor("com.example.game"))
    #expect(!settings.passesThrough("org.gnu.Emacs.helper"), "the whole id, not its beginning")
    #expect(!settings.passesThrough("com.example.game"), "each list is its own")
    #expect(!settings.passesThrough(nil), "a program without a bundle id is on no list")
  }

  @Test func theCommandParsesAndRoundTrips() throws {
    #expect(try Command.parse("pass-through") == .passThrough(bundleID: nil))
    #expect(try Command.parse("pass-through org.gnu.Emacs") == .passThrough(bundleID: "org.gnu.Emacs"))
    #expect(try Command.parse("passthrough org.gnu.Emacs") == .passThrough(bundleID: "org.gnu.Emacs"))
    #expect(try Command.parse("pass-through on") == .passThrough(bundleID: nil, on: true))
    #expect(try Command.parse("pass-through Off") == .passThrough(bundleID: nil, on: false))
    #expect(try Command.parse("pass-through org.gnu.Emacs on") == .passThrough(bundleID: "org.gnu.Emacs", on: true))
    #expect(try Command.parse("pass-through org.gnu.Emacs off") == .passThrough(bundleID: "org.gnu.Emacs", on: false))
    for command in [
      Command.passThrough(bundleID: nil), .passThrough(bundleID: "org.gnu.Emacs"), .passThrough(bundleID: nil, on: true),
      .passThrough(bundleID: "org.gnu.Emacs", on: false),
    ] {
      #expect(try Command.parse(command.text) == command)
    }
    #expect(Command.helpText.contains("pass-through [bundle-id] [on|off]"))
  }

  @Test(arguments: ["pass-through a b", "pass-through a b on", "pass-through on off", "pass-through com.example.*", "pass-through x\"y", "pass-through \"x", "pass-through \"a b\"", "pass-through é"])
  func theCommandRefusesWhatIsNotOneBundleID(text: String) {
    #expect(throws: Command.ParseError.self) { try Command.parse(text) }
  }

  /// Quotes around a word hold it together and come off (F50), so none of them gets into settings.json either.
  @Test func quotesAroundTheBundleIDComeOff() throws {
    #expect(try Command.parse("pass-through \"org.gnu.Emacs\" on") == .passThrough(bundleID: "org.gnu.Emacs", on: true))
  }

  /// It changes settings, and could be used to switch the shortcuts off in every app one by one.
  @Test func aURLCannotRunIt() {
    #expect(!Command.passThrough(bundleID: nil).isAllowedFromURL)
    #expect(!Command.passThrough(bundleID: "com.apple.Safari").isAllowedFromURL)
  }

  @Test func onlyThePanicKeyAndTheToggleItselfWorkInAPassThroughApp() {
    #expect(Command.togglePause.worksInPassThroughApps)
    #expect(Command.passThrough(bundleID: nil).worksInPassThroughApps)
    for command in [Command.showAll, .home, .zoom(nil), .floatAll, .resume, .pause(minutes: nil), .quit] {
      #expect(!command.worksInPassThroughApps, "\(command.text)")
    }
  }

  @Test func appsKnownToUseControlOptionThemselves() {
    for id in [
      "org.gnu.Emacs", "com.vmware.fusion", "com.parallels.desktop.console", "com.utmapp.UTM",
      "com.microsoft.rdc.macos", "org.virtualbox.app.VirtualBoxVM", "com.jetbrains.intellij",
      "com.jetbrains.pycharm.ce", "com.apple.ScreenSharing",
    ] {
      #expect(ControlOptionApps.contains(id), "\(id)")
    }
    for id in ["com.apple.Safari", "com.jetbrains", "org.gnu", "", nil] as [String?] {
      #expect(!ControlOptionApps.contains(id), "\(id ?? "nil")")
    }
  }
}
