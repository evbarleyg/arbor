import ArborCore
import ArborKit
import ArborTesting
import Foundation
import Testing

/// What the controller lets `arbor://` URLs do.
@Suite @MainActor struct URLCommandTests {
  @Test func cameraAndArrangementURLsAreAdmitted() throws {
    let h = Harness()
    h.start()
    #expect(try h.controller.admit(url: "arbor://dock/left").get() == .dock(nil, .left))
    #expect(try h.controller.admit(url: "arbor://show-all").get() == .showAll)
  }

  @Test(arguments: [
    "arbor://quit", "arbor://exclude", "arbor://exclude/com.apple.Safari", "arbor://include/com.apple.Safari",
    "arbor://float-all", "arbor://reload-settings", "arbor://state",
  ]) func otherURLsAreRefusedAndSayHowToAllowThem(url: String) {
    let h = Harness()
    h.start()
    guard case .failure(let error) = h.controller.admit(url: url) else {
      Issue.record("\(url) was admitted")
      return
    }
    #expect(error.description.contains("allowAllURLCommands"))
  }

  @Test func theSettingAdmitsEverythingThatParses() throws {
    var settings = Settings()
    settings.allowAllURLCommands = true
    let h = Harness(settings: settings)
    h.start()
    #expect(try h.controller.admit(url: "arbor://quit").get() == .quit)
    #expect(try h.controller.admit(url: "arbor://float-all").get() == .floatAll)
    guard case .failure = h.controller.admit(url: "arbor://exclude/a%0Ab") else {
      Issue.record("a URL that does not parse was admitted")
      return
    }
  }

  @Test func theSettingIsOffByDefaultAndInOldFiles() throws {
    #expect(!Settings().allowAllURLCommands)
    #expect(try !JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 20}"#.utf8)).allowAllURLCommands)
    #expect(try JSONDecoder().decode(Settings.self, from: Data(#"{"allowAllURLCommands": true}"#.utf8)).allowAllURLCommands)
  }
}
