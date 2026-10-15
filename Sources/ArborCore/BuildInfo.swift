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
  /// How the bundle was signed, as `scripts/sign.sh` stamped it just before it signed. Nil where nobody said: a binary outside
  /// a bundle, or a bundle from before the stamp. A bundle that something else signs again keeps the old word; nothing that
  /// reaches a person does that.
  public var signature: Signature?

  /// macOS ties the Accessibility permission to the signature, so its kind decides what the next build costs.
  public enum Signature: String, Sendable {
    /// With no certificate. macOS knows such an app by the hash of this very build, so the next build is a stranger.
    case adHoc = "adhoc"
    /// With the certificate `scripts/make-signing-identity.sh` makes, which only this Mac has.
    case local
    /// With any other certificate, which is taken to be one Apple issued.
    case issued

    /// Whether macOS takes the next build for the same app, and lets it keep what this one was granted.
    public var outlivesTheBuild: Bool { self != .adHoc }
  }

  public static let development = BuildInfo(version: "dev")

  public init(version: String, build: String? = nil, commit: String? = nil, signature: Signature? = nil) {
    self.version = version
    self.build = build
    self.commit = commit
    self.signature = signature
  }

  /// Reads the keys `bundle.sh` and `sign.sh` stamp from an Info.plist, e.g. `Bundle.main.infoDictionary`.
  public init(infoDictionary: [String: Any]?) {
    func text(_ key: String) -> String? {
      guard let value = infoDictionary?[key] as? String, !value.isEmpty else { return nil }
      return value
    }
    guard let version = text("CFBundleShortVersionString") else {
      self = .development
      return
    }
    self.init(
      version: version, build: text("CFBundleVersion"), commit: text("ArborCommit"),
      signature: text("ArborSignature").flatMap(Signature.init(rawValue:)))
  }

  /// `0.9.0 (build 214, 47a2ba9)`, `0.9.0`, `dev`.
  public var text: String {
    let details = [build.map { "build \($0)" }, commit].compactMap { $0 }
    return details.isEmpty ? version : "\(version) (\(details.joined(separator: ", ")))"
  }
}
