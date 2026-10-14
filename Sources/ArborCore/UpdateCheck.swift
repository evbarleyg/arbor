import Foundation

/// What asking for the newest release came back with.
public enum ReleaseLookup: Equatable, Sendable {
  /// The tag of the newest published release, e.g. `v0.9.1`.
  case latest(tag: String)
  /// There is no published release to compare with. GitHub answers 404 both when a repository has
  /// none and when it is private, so this is a normal answer and not a failure.
  case nothingPublished
  /// No usable answer: offline, rate-limited, or not what GitHub normally sends.
  case failed(String)

  /// Reads GitHub's answer to `GET /repos/<owner>/<repository>/releases/latest`.
  public init(status: Int, body: Data) {
    struct Release: Decodable {
      var tag_name: String
    }
    switch status {
    case 200:
      if let release = try? JSONDecoder().decode(Release.self, from: body) {
        self = .latest(tag: release.tag_name)
      } else {
        self = .failed("GitHub's answer could not be read")
      }
    case 404:
      self = .nothingPublished
    default:
      self = .failed("GitHub answered with status \(status)")
    }
  }
}

/// What to tell the user after a lookup.
public enum UpdateDecision: Equatable, Sendable {
  /// A newer release exists; `page` describes it and holds the download.
  case available(latest: SemanticVersion, page: String)
  case upToDate(latest: SemanticVersion)
  /// Nothing can be said, and why. Never shown as an error: not knowing is harmless.
  case noInformation(String)

  /// The release page to offer, when there is something to offer.
  public var page: String? {
    if case .available(_, let page) = self { return page }
    return nil
  }

  /// One line for command replies, `version` and the log.
  public var summary: String {
    switch self {
    case .available(let latest, let page): return "Arbor \(latest) is available: \(page)"
    case .upToDate(let latest): return "up to date (the latest release is \(latest))"
    case .noInformation(let reason): return "no update information (\(reason))"
    }
  }

  /// What the window shown after a check says.
  public func message(current: BuildInfo) -> (headline: String, detail: String) {
    switch self {
    case .available(let latest, _):
      return (
        "Arbor \(latest) is available",
        "You have \(current.version). Arbor does not download or install anything by itself: "
          + "the release page has the download and the list of changes."
      )
    case .upToDate(let latest):
      return ("Arbor is up to date", "You have \(current.version); the latest release is \(latest).")
    case .noInformation(let reason):
      return ("No update information", "You have \(current.version). Nothing to compare it with: \(reason).")
    }
  }
}

/// Deciding whether a newer Arbor exists. Pure; `ReleaseFeed` in ArborKit does the asking.
public enum UpdateCheck {
  public static let repository = "evbarleyg/arbor"
  public static let latestReleaseAPI = "https://api.github.com/repos/\(repository)/releases/latest"

  /// The page of the release tagged `tag`. Call it only with a tag `SemanticVersion` could read,
  /// which leaves nothing in it that could lead the URL elsewhere.
  static func releasePage(tag: String) -> String {
    "https://github.com/\(repository)/releases/tag/\(tag)"
  }

  /// Compares the running version (`BuildInfo.version`) with what the lookup found.
  public static func decide(current: String, lookup: ReleaseLookup) -> UpdateDecision {
    switch lookup {
    case .nothingPublished:
      return .noInformation("GitHub lists no published release")
    case .failed(let reason):
      return .noInformation(reason)
    case .latest(let rawTag):
      let tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
      // The second condition is for white space that the line above and `SemanticVersion` see differently.
      guard let latest = SemanticVersion(tag), tag.allSatisfy({ $0.isASCII && !$0.isWhitespace }) else {
        return .noInformation("the latest release's tag is not a version number")
      }
      guard let running = SemanticVersion(current) else {
        return .noInformation("this is a development build; the latest release is \(latest)")
      }
      return running < latest ? .available(latest: latest, page: releasePage(tag: tag)) : .upToDate(latest: latest)
    }
  }
}
