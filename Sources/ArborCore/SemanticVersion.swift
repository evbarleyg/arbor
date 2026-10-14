/// A version number ordered the way semver.org orders them. Arbor compares the version it runs with
/// the tag of the newest release, so reading is lenient about what people put in tags (`v0.9.0`,
/// `0.9`, `1.0.0-rc.1`, `1.0.0+mac`) and anything else is nil rather than a guess.
public struct SemanticVersion: Equatable, Hashable, Sendable {
  public var major: Int
  public var minor: Int
  public var patch: Int
  /// The identifiers after `-`, e.g. `["rc", "1"]`. Empty for a finished release.
  public var prerelease: [String]

  public init(major: Int, minor: Int, patch: Int, prerelease: [String] = []) {
    self.major = major
    self.minor = minor
    self.patch = patch
    self.prerelease = prerelease
  }

  /// Reads `[v]major[.minor[.patch]][-prerelease][+build]`. Build metadata is checked and dropped: it
  /// takes no part in ordering.
  public init?(_ text: String) {
    var rest = Substring(text)
    while rest.first?.isWhitespace == true { rest.removeFirst() }
    while rest.last?.isWhitespace == true { rest.removeLast() }
    if rest.first == "v" || rest.first == "V" { rest.removeFirst() }

    /// Dot-separated identifiers of ASCII letters, digits and hyphens, none of them empty.
    func identifiers(_ text: Substring) -> [String]? {
      let parts = text.split(separator: ".", omittingEmptySubsequences: false)
      let valid = parts.allSatisfy { part in
        !part.isEmpty && part.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
      }
      return valid ? parts.map(String.init) : nil
    }

    if let plus = rest.firstIndex(of: "+") {
      guard identifiers(rest[rest.index(after: plus)...]) != nil else { return nil }
      rest = rest[..<plus]
    }
    var prerelease: [String] = []
    if let dash = rest.firstIndex(of: "-") {
      guard let parts = identifiers(rest[rest.index(after: dash)...]) else { return nil }
      // "01" and "1" would be different texts that neither precedes the other, so, as semver.org
      // does, refuse the first.
      guard parts.allSatisfy({ !(Self.isNumeric($0) && $0.count > 1 && $0.first == "0") }) else { return nil }
      prerelease = parts
      rest = rest[..<dash]
    }

    let numbers = rest.split(separator: ".", omittingEmptySubsequences: false)
    guard (1...3).contains(numbers.count) else { return nil }
    var values = [0, 0, 0]
    for (index, number) in numbers.enumerated() {
      // `Int` alone would take "+1", and returns nil for a number too large to hold.
      guard Self.isNumeric(number), let value = Int(number) else { return nil }
      values[index] = value
    }
    self.init(major: values[0], minor: values[1], patch: values[2], prerelease: prerelease)
  }

  private static func isNumeric(_ text: some StringProtocol) -> Bool {
    !text.isEmpty && text.allSatisfy { ("0"..."9").contains($0) }
  }
}

extension SemanticVersion: Comparable {
  public static func < (a: SemanticVersion, b: SemanticVersion) -> Bool {
    let (left, right) = ((a.major, a.minor, a.patch), (b.major, b.minor, b.patch))
    if left != right { return left < right }
    // A pre-release comes before the release it leads to.
    if a.prerelease.isEmpty || b.prerelease.isEmpty { return !a.prerelease.isEmpty && b.prerelease.isEmpty }
    for (x, y) in zip(a.prerelease, b.prerelease) where x != y {
      switch (isNumeric(x), isNumeric(y)) {
      // Without leading zeros the longer number is the larger, whatever its size.
      case (true, true): return x.count != y.count ? x.count < y.count : x < y
      case (true, false): return true
      case (false, true): return false
      case (false, false): return x.utf8.lexicographicallyPrecedes(y.utf8)
      }
    }
    return a.prerelease.count < b.prerelease.count
  }
}

extension SemanticVersion: CustomStringConvertible {
  public var description: String {
    "\(major).\(minor).\(patch)" + (prerelease.isEmpty ? "" : "-" + prerelease.joined(separator: "."))
  }
}
