import ArborCore
import Testing

@Suite struct SemanticVersionTests {
  func version(_ text: String, sourceLocation: SourceLocation = #_sourceLocation) throws -> SemanticVersion {
    try #require(SemanticVersion(text), "\(text)", sourceLocation: sourceLocation)
  }

  @Test func versionsAreReadTheWayPeopleTagThem() throws {
    #expect(try version("0.9.0") == SemanticVersion(major: 0, minor: 9, patch: 0))
    #expect(try version("v0.9.0") == SemanticVersion(major: 0, minor: 9, patch: 0))
    #expect(try version(" V1.2\n") == SemanticVersion(major: 1, minor: 2, patch: 0))
    #expect(try version("3") == SemanticVersion(major: 3, minor: 0, patch: 0))
    #expect(try version("1.02.3") == SemanticVersion(major: 1, minor: 2, patch: 3))
    #expect(try version("1.0.0-rc.1") == SemanticVersion(major: 1, minor: 0, patch: 0, prerelease: ["rc", "1"]))
    #expect(try version("1.0.0-x-y.0") == SemanticVersion(major: 1, minor: 0, patch: 0, prerelease: ["x-y", "0"]))
    #expect(try version("1.0.0-beta+exp.sha-5114f85").prerelease == ["beta"])
  }

  @Test(arguments: [
    "", " ", "dev", "v", "latest", "1.2.3.4", "1..2", ".1", "1.", "1.-2", "+1.0.0", "-1.0.0", "1.+2.0", "1.0.0-",
    "1.0.0-a..b", "1.0.0-.a", "1.0.0-01", "1.0.0+", "1.0.0+a/b", "1.0.0-a/b", "1.0.0-é", "٣.1.0", "1.0 .0", "1,0,0",
    "1.0.0?x=1", "vv1.0.0", "99999999999999999999.0.0", "0x10.0.0",
  ])
  func whatIsNotAVersionIsRefused(text: String) {
    #expect(SemanticVersion(text) == nil, "\(text)")
  }

  @Test func orderFollowsSemverOrg() throws {
    // The chain in section 11 of the specification, carried on through the three numbers.
    let ascending = try [
      "0.9.0", "0.9.1", "0.10.0", "1.0.0-alpha", "1.0.0-alpha.1", "1.0.0-alpha.beta", "1.0.0-beta", "1.0.0-beta.2",
      "1.0.0-beta.11", "1.0.0-rc.1", "1.0.0", "1.0.1", "1.1.0", "1.9.9", "1.10.0", "2.0.0", "10.0.0",
    ].map { try version($0) }
    for (i, a) in ascending.enumerated() {
      for (j, b) in ascending.enumerated() {
        #expect((a < b) == (i < j), "\(a) < \(b)")
        #expect((a == b) == (i == j), "\(a) == \(b)")
      }
    }
    #expect(ascending.shuffled().sorted() == ascending)
  }

  @Test func prereleaseIdentifiersCompareAsTheSpecificationSays() throws {
    #expect(try version("1.0.0-2") < version("1.0.0-11"))  // numbers as numbers
    #expect(try version("1.0.0-999") < version("1.0.0-a"))  // numbers before words
    #expect(try version("1.0.0-RC") < version("1.0.0-rc"))  // words in ASCII order
    #expect(try version("1.0.0-rc") < version("1.0.0-rc.0"))  // more identifiers come later
    // Too large for an Int, and still compared as numbers.
    #expect(try version("1.0.0-99999999999999999999999") < version("1.0.0-100000000000000000000000"))
    #expect(try version("1.0.0-100000000000000000000001") > version("1.0.0-100000000000000000000000"))
  }

  @Test func spellingAndBuildMetadataDoNotMakeADifference() throws {
    #expect(try version("v1.2.0+mac.1") == version("1.2"))
    #expect(try !(version("1.2.0+a") < version("1.2.0+b")))
    #expect(try !(version("1.2.0+b") < version("1.2.0+a")))
  }

  @Test(arguments: ["0.9.0", "1.0.0-rc.1", "12.34.56-alpha-1.x"])
  func theDescriptionReadsBack(text: String) throws {
    #expect(try version(text).description == text)
  }
}
