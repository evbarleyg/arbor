/// Which build of Arbor this is. Nothing is generated when Arbor compiles: `scripts/bundle.sh` stamps
/// the bundle's Info.plist from the `VERSION` file and Git, and the app and `arborctl` read it back
/// when they start. A binary outside a bundle (`make run`, the tests, arbor-sim) is a development build.
public struct BuildInfo: Equatable, Sendable {
  /// `0.9.0`, or `dev`.
  public var version: String
  /// The number of commits the build was made from.
  public var build: String?
  /// The short hash of the commit, with `-dirty` when the sources had uncommitted changes.
  public var commit: String?

  public static let development = BuildInfo(version: "dev")

  public init(version: String, build: String? = nil, commit: String? = nil) {
    self.version = version
    self.build = build
    self.commit = commit
  }

  /// Reads the keys `bundle.sh` stamps from an Info.plist, e.g. `Bundle.main.infoDictionary`.
  public init(infoDictionary: [String: Any]?) {
    func text(_ key: String) -> String? {
      guard let value = infoDictionary?[key] as? String, !value.isEmpty else { return nil }
      return value
    }
    guard let version = text("CFBundleShortVersionString") else {
      self = .development
      return
    }
    self.init(version: version, build: text("CFBundleVersion"), commit: text("ArborCommit"))
  }

  /// `0.9.0 (build 214, 47a2ba9)`, `0.9.0`, `dev`.
  public var text: String {
    let details = [build.map { "build \($0)" }, commit].compactMap { $0 }
    return details.isEmpty ? version : "\(version) (\(details.joined(separator: ", ")))"
  }
}
