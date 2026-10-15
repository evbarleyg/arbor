import ArborCore
import Foundation
import Testing

@Suite struct UpdateCheckTests {
  func decide(_ current: String, _ tag: String) -> UpdateDecision {
    UpdateCheck.decide(current: current, lookup: .latest(tag: tag))
  }

  @Test func aNewerReleaseIsOfferedWithItsPage() throws {
    let latest = try #require(SemanticVersion("0.9.1"))
    let page = "https://github.com/evbarleyg/arbor/releases/tag/v0.9.1"
    #expect(decide("0.9.0", "v0.9.1") == .available(latest: latest, page: page))
    #expect(decide("0.9.0", "v0.9.1").page == page)
    #expect(decide("0.9.0", " v0.9.1\n").page == page)
    for space in ["\u{85}", "\u{A0}", "\u{2003}", "\u{200B}", "\u{2028}", "\u{3000}", "\t", "\r\n"] {
      // Whatever counts as white space around a tag, none of it reaches the address.
      let offered = decide("0.9.0", space + "v0.9.1" + space).page
      #expect(offered == page || offered == nil, "U+\(String(space.unicodeScalars.first!.value, radix: 16))")
    }
    #expect(decide("0.9.0", "0.10.0").page == "https://github.com/evbarleyg/arbor/releases/tag/0.10.0")
    #expect(decide("0.9.9", "v0.10.0").page != nil)  // not compared as text
    #expect(decide("0.9.0-rc.1", "v0.9.0").page != nil)  // a release candidate is offered its release
  }

  @Test func theSameOrAnOlderReleaseMeansUpToDate() throws {
    let nine = try #require(SemanticVersion("0.9.0"))
    #expect(decide("0.9.0", "v0.9.0") == .upToDate(latest: nine))
    #expect(decide("0.10.0", "v0.9.0") == .upToDate(latest: nine))
    #expect(decide("1.0.0", "v1.0.0-rc.2").page == nil)
    #expect(decide("0.9.0", "v0.9.0+rebuilt").page == nil)
  }

  @Test func aPrivateRepositoryOrOneWithoutReleasesIsNoInformation() {
    let body = Data(#"{"message": "Not Found", "status": "404"}"#.utf8)
    let lookup = ReleaseLookup(status: 404, body: body)
    #expect(lookup == .nothingPublished)
    #expect(UpdateCheck.decide(current: "0.9.0", lookup: lookup) == .noInformation("GitHub lists no published release"))
  }

  @Test func gitHubsAnswerIsRead() {
    let body = Data(
      #"""
      {"url": "https://api.github.com/repos/evbarleyg/arbor/releases/1", "id": 1, "tag_name": "v0.9.1",
       "html_url": "https://example.com/elsewhere", "name": "Arbor 0.9.1", "draft": false, "prerelease": false,
       "assets": [{"name": "Arbor-0.9.1.dmg", "size": 1234}], "body": "Notes"}
      """#.utf8)
    #expect(ReleaseLookup(status: 200, body: body) == .latest(tag: "v0.9.1"))
  }

  @Test func answersArborCannotUseAreFailuresNotCrashes() {
    for body in ["", "not json", "[]", "{}", #"{"tag_name": 5}"#, #"{"tag_name": null}"#] {
      #expect(ReleaseLookup(status: 200, body: Data(body.utf8)) == .failed("GitHub's answer could not be read"), "\(body)")
    }
    #expect(ReleaseLookup(status: 403, body: Data()) == .failed("GitHub answered with status 403"))
    #expect(ReleaseLookup(status: 500, body: Data("oops".utf8)) == .failed("GitHub answered with status 500"))
    #expect(
      UpdateCheck.decide(current: "0.9.0", lookup: .failed("GitHub answered with status 403"))
        == .noInformation("GitHub answered with status 403"))
  }

  @Test(arguments: [
    "latest", "", "v1.0.0/../../../evil", "v1.0.0?tab=x", "v1.0.0#x", "v1.0.0 and more", "<script>", "v1.0.0%2f..", "v9.9.9@evil.example",
    "v1.0.0\u{0}", "v1.\u{200B}0.0", "v1.\u{202E}0.0",
  ])
  func tagsThatAreNotVersionsNeverBecomeLinks(tag: String) {
    #expect(decide("0.9.0", tag) == .noInformation("the latest release's tag is not a version number"), "\(tag)")
  }

  @Test func aDevelopmentBuildIsToldTheLatestReleaseButOfferedNothing() {
    #expect(
      decide(BuildInfo.development.version, "v0.9.1")
        == .noInformation("this is a development build; the latest release is 0.9.1"))
  }

  @Test func theWordsSayWhatYouHaveAndWhatThereIs() {
    let current = BuildInfo(version: "0.9.0", build: "214", commit: "47a2ba9")
    let available = decide("0.9.0", "v0.9.1")
    #expect(available.summary == "Arbor 0.9.1 is available: https://github.com/evbarleyg/arbor/releases/tag/v0.9.1")
    #expect(available.message(current: current).headline == "Arbor 0.9.1 is available")
    #expect(available.message(current: current).detail.hasPrefix("You have 0.9.0. Arbor does not download or install"))
    let same = decide("0.9.0", "v0.9.0")
    #expect(same.summary == "up to date (the latest release is 0.9.0)")
    #expect(same.message(current: current).headline == "Arbor is up to date")
    let nothing = UpdateCheck.decide(current: "0.9.0", lookup: .nothingPublished)
    #expect(nothing.summary == "no update information (GitHub lists no published release)")
    #expect(nothing.message(current: current).headline == "No update information")
    #expect(nothing.message(current: current).detail.contains("GitHub lists no published release"))
  }
}

@Suite struct BuildInfoTests {
  @Test func theStampedKeysAreRead() {
    let info = BuildInfo(infoDictionary: [
      "CFBundleShortVersionString": "0.9.0", "CFBundleVersion": "214", "ArborCommit": "47a2ba9", "CFBundleName": "Arbor",
    ])
    #expect(info == BuildInfo(version: "0.9.0", build: "214", commit: "47a2ba9"))
    #expect(info.text == "0.9.0 (build 214, 47a2ba9)")
  }

  @Test func withoutAStampItIsADevelopmentBuild() {
    #expect(BuildInfo(infoDictionary: nil) == .development)
    #expect(BuildInfo(infoDictionary: [:]) == .development)
    #expect(BuildInfo(infoDictionary: ["CFBundleShortVersionString": ""]) == .development)
    #expect(BuildInfo(infoDictionary: ["CFBundleShortVersionString": 9, "CFBundleVersion": "214"]) == .development)
    #expect(BuildInfo.development.text == "dev")
  }

  @Test func missingDetailsAreLeftOut() {
    #expect(BuildInfo(infoDictionary: ["CFBundleShortVersionString": "0.9.0"]).text == "0.9.0")
    #expect(BuildInfo(infoDictionary: ["CFBundleShortVersionString": "0.9.0", "CFBundleVersion": "3"]).text == "0.9.0 (build 3)")
    #expect(BuildInfo(version: "0.9.0", commit: "47a2ba9-dirty").text == "0.9.0 (47a2ba9-dirty)")
  }

  /// `scripts/sign.sh` stamps one of three words. Another word is from a build Arbor does not know, and says nothing.
  @Test func theKindOfSignatureIsRead() {
    func signature(_ word: Any?) -> BuildInfo.Signature? {
      var keys: [String: Any] = ["CFBundleShortVersionString": "0.9.0"]
      keys["ArborSignature"] = word
      return BuildInfo(infoDictionary: keys).signature
    }
    #expect(signature("adhoc") == .adHoc)
    #expect(signature("local") == .local)
    #expect(signature("issued") == .issued)
    for word: Any? in [nil, "", "Adhoc", "something new", 1] { #expect(signature(word) == nil) }
    #expect(BuildInfo(infoDictionary: ["ArborSignature": "adhoc"]) == .development, "a stamp without a version is no bundle of ours")
    #expect(BuildInfo.development.signature == nil)
    // Only the ad-hoc one makes a stranger of the next build.
    #expect(!BuildInfo.Signature.adHoc.outlivesTheBuild)
    #expect(BuildInfo.Signature.local.outlivesTheBuild && BuildInfo.Signature.issued.outlivesTheBuild)
    // The version's text is compared and shown in many places, and stays what it was.
    #expect(BuildInfo(version: "0.9.0", build: "3", signature: .adHoc).text == "0.9.0 (build 3)")
  }

  /// `scripts/bundle.sh` stamps this file's content into the app, which later compares it with release tags.
  @Test func theVersionFileHoldsAVersion() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
    let text = try String(contentsOf: root.appendingPathComponent("VERSION"), encoding: .utf8)
    let version = try #require(SemanticVersion(text), "VERSION holds \(text)")
    #expect(version.description == text.trimmingCharacters(in: .whitespacesAndNewlines))
  }
}

@Suite struct UpdateCommandAndSettingTests {
  @Test func versionAndCheckForUpdatesParseAndRoundTrip() throws {
    #expect(try Command.parse("version") == .version)
    #expect(try Command.parse("--version") == .version)
    #expect(try Command.parse("check-for-updates") == .checkForUpdates)
    for command in [Command.version, .checkForUpdates] {
      #expect(try Command.parse(command.text) == command)
      #expect(Command.helpText.contains("\n  \(command.text) "))
    }
    #expect(Command.version.isQuery)
    #expect(!Command.checkForUpdates.isQuery)  // so it can have a shortcut
    #expect(throws: Command.ParseError.self) { try Command.parse("version 2") }
    #expect(throws: Command.ParseError.self) { try Command.parse("check-for-updates now") }
  }

  /// A URL has nowhere to send a version to, and a web page has no business making Arbor use the network.
  @Test func versionAndCheckForUpdatesAreRefusedFromURLs() throws {
    #expect(try !Command.parse(url: "arbor://version").isAllowedFromURL)
    #expect(try !Command.parse(url: "arbor://check-for-updates").isAllowedFromURL)
  }

  @Test func updateChecksAreOffUnlessTheSettingsFileTurnsThemOn() throws {
    #expect(!Settings().automaticUpdateChecks)
    let old = try JSONDecoder().decode(Settings.self, from: Data(#"{"gap": 8}"#.utf8))
    #expect(!old.automaticUpdateChecks)
    let on = try JSONDecoder().decode(Settings.self, from: Data(#"{"automaticUpdateChecks": true}"#.utf8))
    #expect(on.automaticUpdateChecks)
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(on)) == on)
  }
}
