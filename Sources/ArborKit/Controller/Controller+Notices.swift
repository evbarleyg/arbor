import ArborCore

/// What Arbor has to tell that nobody asked about and that no command ends: one line each, for the end of
/// `status` and for the state lines at the top of the menu (docs/MENU.md, state 8). Each makes sense read alone.
extension Controller {
  public var notices: [String] {
    [keptPlacesNotice, stateNotice].compactMap { $0 }
  }

  /// How reading the saved state went, taken down when it was read: the store answers for its last `load()` only.
  struct StateNews {
    var problem: StateLoadProblem
    /// The file that has what was there, if it could be kept.
    var copy: String?
    var repairs: Int
  }

  /// Right after `store.load()`.
  func noteHowLoadingWent() {
    stateNews = store.loadProblem.map { StateNews(problem: $0, copy: store.keptCopy, repairs: store.repairs.count) }
  }

  /// About the start of this run, until Arbor next starts: someone whose arrangement is gone or different looks for
  /// the reason when they notice, which can be hours later. Until now only the log knew.
  private var stateNotice: String? {
    guard let news = stateNews else { return nil }
    // Nothing is said to be kept that is not.
    let aside = news.copy.map { " and was set aside (\($0))" } ?? "; it could not be set aside, and the next save replaces it"
    switch news.problem {
    case .unreadable: return "The saved arrangement could not be read" + aside
    case .newer: return "The saved arrangement is from a newer Arbor" + aside
    case .setAsideEarlier:
      return "The saved arrangement was set aside earlier\(news.copy.map { " (\($0))" } ?? ""), and Arbor started afresh"
    case .repaired:
      // Not "damaged": a repair can be a view on a space that is gone, which nobody would miss.
      let asItWas = news.copy.map { "\($0) has it as it was" } ?? "no copy of it as it was could be kept"
      return "The saved arrangement needed \(Self.count(news.repairs, "repair")) when it was read "
        + "(arbor.log says which; \(asItWas))"
    }
  }

  /// The notices at the end of a line of `status`.
  var noticesInStatus: String { notices.map { "; " + Self.midSentence($0) }.joined() }

  /// A notice as part of a longer line.
  static func midSentence(_ notice: String) -> String {
    notice.prefix(1).lowercased() + notice.dropFirst()
  }
}
