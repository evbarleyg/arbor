import ArborCore
import Foundation
import Testing

@Suite struct WindowPicturesSettingTests {
  @Test func picturesOfWindowsAreOffUntilSomebodySaysOtherwise() throws {
    #expect(!Settings().windowPictures)
    #expect(!(try JSONDecoder().decode(Settings.self, from: Data("{}".utf8))).windowPictures, "also for a file from before")
    #expect(try JSONDecoder().decode(Settings.self, from: Data(#"{"windowPictures": true}"#.utf8)).windowPictures)
    #expect(try SettingsSchema.entry(named: "windowPictures").isAdvanced, "not among the settings a newcomer meets")
  }
}

@Suite struct MotionSettingsTests {
  func decode(_ json: String) throws -> Settings {
    try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
  }

  @Test func noMotionUntilSomebodyAsksForIt() {
    // It shipped as one motion of 460 milliseconds until 2026-10-15 (collab/QUESTIONS.md, Q29).
    #expect(Settings().animationDuration == 0)
    #expect(Settings().motionDuration == 0)
  }

  @Test func anOldSettingsFileWithoutADurationStillLoads() throws {
    let settings = try decode(#"{"gap": 20, "tabsEnabled": false}"#)
    #expect(settings.gap == 20)
    #expect(settings.animationDuration == 0)
  }

  @Test func theDurationIsReadAndWritten() throws {
    #expect(try decode(#"{"animationDuration": 0.2}"#).motionDuration == 0.2)
    #expect(try decode(#"{"animationDuration": 0}"#).motionDuration == 0, "0 turns the motion off")
    var settings = Settings()
    settings.animationDuration = 0.3
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings)) == settings)
  }

  @Test func theDurationIsKeptSane() {
    var settings = Settings()
    for (written, used) in [(-1, 0), (0, 0), (0.001, 0.001), (2, 2), (2.5, 2), (1e9, 2)] {
      settings.animationDuration = written
      #expect(settings.motionDuration == used, "\(written)")
    }
    for nonsense in [Double.nan, .infinity, -.infinity] {
      settings.animationDuration = nonsense
      #expect(settings.motionDuration == 0, "\(nonsense) counts as the default, which is none")
    }
  }
}
