import ArborCore
import Foundation

#if canImport(FoundationNetworking)
  import FoundationNetworking  // URLSession, off macOS
#endif

/// Where Arbor hears about new releases: the only part of Arbor that uses the network.
/// `GitHubReleaseFeed` asks GitHub; `FakeReleaseFeed` answers from memory in tests.
@MainActor
public protocol ReleaseFeed: AnyObject {
  /// Looks up the newest published release and calls `completion` once, on the main actor.
  func latestRelease(_ completion: @escaping @MainActor @Sendable (ReleaseLookup) -> Void)
}

/// One unauthenticated GET to GitHub's releases API. It sends nothing about the user or the Mac
/// beyond Arbor's own version in the User-Agent, keeps no cookies or cache, and only reads a tag name.
@MainActor
public final class GitHubReleaseFeed: ReleaseFeed {
  private let address: String
  private let userAgent: String
  private let session = URLSession(configuration: .ephemeral)

  /// `address` is replaced only by tests of the real app (`ARBOR_RELEASES_URL`).
  public init(address: String = UpdateCheck.latestReleaseAPI, version: String) {
    self.address = address
    userAgent = "Arbor/\(version)"
  }

  public func latestRelease(_ completion: @escaping @MainActor @Sendable (ReleaseLookup) -> Void) {
    guard let url = URL(string: address) else {
      completion(.failed("the releases address is not a URL"))
      return
    }
    var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 15)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
    let task = session.dataTask(with: request) { data, response, error in
      let lookup: ReleaseLookup
      if let response = response as? HTTPURLResponse {
        lookup = ReleaseLookup(status: response.statusCode, body: data ?? Data())
      } else {
        lookup = .failed("GitHub could not be reached: \(error?.localizedDescription ?? "no answer")")
      }
      Task { @MainActor in completion(lookup) }
    }
    task.resume()
  }
}
