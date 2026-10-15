import ArborCore

extension Settings {
  /// What the first build wrote into `settings.json` at its first launch: every key of its day with the default of its day, in the order
  /// of the alphabet, without the mark (`Settings.defaultsOfOldFiles`). Only a file that looks whole is taken for an early build's
  /// (`Settings.upgradedFile`), so a test about such a file writes all of it. Its keys and values, not its bytes (that build wrote an
  /// empty list over three lines): those are kept in `SettingsFileFormatTests.wholeFile`.
  /// - Parameters:
  ///   - changes: what somebody changed in it by hand: the JSON that stands behind a key instead.
  ///   - more: members added at its end, each as it is written: `"mine" : "a note"`.
  public static func fileOfTheFirstBuild(_ changes: [String: String] = [:], and more: [String] = []) -> String {
    let table = try! JSONText(defaultsOfOldFiles)
    let keys = (table.keys(at: []) ?? []).sorted()
    precondition(changes.keys.allSatisfy(keys.contains), "no such key in a file of the first build: \(changes.keys.sorted())")
    let members = keys.map { "\"\($0)\" : \(changes[$0] ?? table.elements(at: [$0])![0])" } + more
    return "{\n" + members.map { "  " + $0 }.joined(separator: ",\n") + "\n}\n"
  }
}
