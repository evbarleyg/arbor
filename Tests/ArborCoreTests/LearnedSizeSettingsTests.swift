import ArborCore
import Foundation
import Testing

/// The setting of docs/features/F45-learned-sizes-expire.md.
@Suite struct LearnedSizeSettingsTests {
  @Test func tenMinutesUnlessTheFileSaysOtherwise() throws {
    #expect(Settings().tileRetryMinutes == 10)
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 8}"#.utf8))
    #expect(old.tileRetryMinutes == 10, "a file written before the key existed")
    let chosen = try JSONDecoder().decode(Settings.self, from: Data(#"{"tileRetryMinutes": 0.5}"#.utf8))
    #expect(chosen.tileRetryMinutes == 0.5)
  }

  @Test func itSurvivesSavingAndLoading() throws {
    var settings = Settings()
    settings.tileRetryMinutes = 45
    let decoded = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(settings))
    #expect(decoded == settings)
  }
}
