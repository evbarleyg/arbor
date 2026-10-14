/// Naming windows by their app, and handing windows out to the places that ask for them.
///
/// An arrangement that is written down (a line of text, a preset) cannot hold window numbers: they
/// change every time an app restarts. It holds **slots** instead, each naming an app and perhaps part
/// of a title, and the slots are matched against the windows that exist when it is applied. This
/// file is the only place that decides what a name means and which window a slot gets.

/// What matching needs to know about a window.
public struct WindowCandidate: Equatable, Sendable {
  public var id: WindowID
  public var bundleID: String?
  public var appName: String
  public var title: String

  public init(id: WindowID, bundleID: String?, appName: String, title: String = "") {
    self.id = id
    self.bundleID = bundleID
    self.appName = appName
    self.title = title
  }
}

/// What people call an app.
public enum AppName {
  /// How well `name` names the app of a window; smaller is better, nil is not at all. Case never counts.
  ///
  /// 0. The bundle id or the app's whole name: `com.apple.Safari`, `Safari`, `Visual Studio Code`.
  /// 1. The last part of the bundle id: `Chrome` for com.google.Chrome, `VSCode` for com.microsoft.VSCode.
  /// 2. Whole words of the app's name, next to each other: `Chrome` for Google Chrome, `Studio Code`.
  public static func rank(_ name: String, bundleID: String?, appName: String) -> Int? {
    let name = name.lowercased()
    guard !name.isEmpty else { return nil }
    let bundle = bundleID?.lowercased()
    let app = appName.lowercased()
    if bundle == name || app == name { return 0 }
    if let last = bundle?.split(separator: ".").last, last == name { return 1 }
    let wanted = words(name)
    let present = words(app)
    guard !wanted.isEmpty, wanted.count <= present.count else { return nil }
    for start in 0...(present.count - wanted.count) where present[start..<(start + wanted.count)].elementsEqual(wanted) {
      return 2
    }
    return nil
  }

  /// The windows `name` means, in the order they were given.
  ///
  /// Only the best kind of match counts: with Code and Visual Studio Code both open, `Code` is the first
  /// alone. That is judged over every window given, so what a name means does not change while
  /// windows are being handed out.
  public static func windows(of name: String, in candidates: [WindowCandidate]) -> [WindowCandidate] {
    var best = Int.max
    var ranked: [(window: WindowCandidate, rank: Int)] = []
    for candidate in candidates {
      guard let rank = rank(name, bundleID: candidate.bundleID, appName: candidate.appName) else { continue }
      ranked.append((candidate, rank))
      best = min(best, rank)
    }
    return ranked.filter { $0.rank == best }.map(\.window)
  }

  private static func words(_ text: String) -> [Substring] {
    text.split(whereSeparator: { !$0.isLetter && !$0.isNumber })
  }
}

/// A place for a window (or, with `takesAll`, for several) in an arrangement that is written down.
public struct WindowSlot: Equatable, Sendable {
  public enum Owner: Equatable, Sendable {
    /// An app's name or bundle id (`AppName.rank` says what counts).
    case app(String)
    /// One particular window, for as long as it lives.
    case window(WindowID)
  }

  public var owner: Owner
  /// Text to look for in the titles of the app's windows, ignoring case. It is a preference: the slot
  /// gets first pick of the windows that have it, and takes another window of the app when none has,
  /// because titles change (a browser's with every page) and a place left empty helps nobody.
  public var title: String?
  /// Takes every window of the app that is left when all other slots have theirs. With a `title`,
  /// only those that have it.
  public var takesAll: Bool

  public init(_ owner: Owner, title: String? = nil, takesAll: Bool = false) {
    self.owner = owner
    self.title = title?.isEmpty == true ? nil : title
    self.takesAll = takesAll
  }

  public static func app(_ name: String, title: String? = nil, takesAll: Bool = false) -> WindowSlot {
    WindowSlot(.app(name), title: title, takesAll: takesAll)
  }

  public static func window(_ id: WindowID) -> WindowSlot { WindowSlot(.window(id)) }

  /// Hands `candidates` out to `slots`: the windows of each slot, in the order of `slots`. A slot
  /// that found nothing gets an empty list. No window is handed out twice.
  ///
  /// `candidates` come best first (the controller gives them in most-recently-focused order), and
  /// each slot takes the best that is left. Who chooses first:
  /// 1. slots that name a window;
  /// 2. slots with a title, among the windows that have it: first every slot whose text is a window's whole title, then those
  ///    whose text a title begins with, then those whose text is somewhere in one. The whole of one title can be part of
  ///    another's ("Inbox", "Inbox (2)", "Re: Inbox"), and a vague slot written early is not to take what a later one names exactly;
  /// 3. every other slot for one window, and those of step 2 that found nothing;
  /// 4. slots that take all that remain.
  /// Within a step, slots choose in the order they are written.
  ///
  /// `current` lists, for each slot, the windows that are in its place now, if the arrangement is already there. Among the
  /// windows a slot could take it prefers those, in their order, so that applying an arrangement twice changes nothing,
  /// whichever of an app's windows was used in between.
  public static func assign(
    _ slots: [WindowSlot], from candidates: [WindowCandidate], preferring current: [[WindowID]] = []
  ) -> [[WindowID]] {
    var result = [[WindowID]](repeating: [], count: slots.count)
    var taken = Set<WindowID>()
    // A window listed twice is still one window.
    var seen = Set<WindowID>()
    let candidates = candidates.filter { seen.insert($0.id).inserted }
    // What each name means, worked out once per name over all the windows.
    var meanings: [String: [WindowCandidate]] = [:]
    func windows(of index: Int, titled: Bool) -> [WindowCandidate] {
      let slot = slots[index]
      guard case .app(let name) = slot.owner else { return [] }
      let key = name.lowercased()
      let all = meanings[key] ?? AppName.windows(of: name, in: candidates)
      meanings[key] = all
      let free = all.filter { !taken.contains($0.id) && (!titled || slot.matchesTitle($0.title)) }
      guard index < current.count, !current[index].isEmpty else { return free }
      var listed = Set<WindowID>()
      let inPlace = current[index].filter { listed.insert($0).inserted }.compactMap { id in free.first { $0.id == id } }
      return inPlace + free.filter { window in !inPlace.contains { $0.id == window.id } }
    }

    for (index, slot) in slots.enumerated() {
      guard case .window(let id) = slot.owner, seen.contains(id), taken.insert(id).inserted else { continue }
      result[index] = [id]
    }
    for closeness in TitleMatch.allCases {
      for (index, slot) in slots.enumerated() where slot.title != nil && !slot.takesAll && result[index].isEmpty {
        guard let window = windows(of: index, titled: true).first(where: { slot.match(of: $0.title) == closeness }) else { continue }
        taken.insert(window.id)
        result[index] = [window.id]
      }
    }
    // Before anyone chooses freely: a window that is in its place is not for another slot to take.
    for (index, slot) in slots.enumerated() where !slot.takesAll && result[index].isEmpty && index < current.count {
      guard let window = windows(of: index, titled: false).first, current[index].contains(window.id) else { continue }
      taken.insert(window.id)
      result[index] = [window.id]
    }
    for (index, slot) in slots.enumerated() where !slot.takesAll && result[index].isEmpty {
      guard let window = windows(of: index, titled: false).first else { continue }
      taken.insert(window.id)
      result[index] = [window.id]
    }
    for (index, slot) in slots.enumerated() where slot.takesAll {
      let rest = windows(of: index, titled: true).map(\.id)
      taken.formUnion(rest)
      result[index] = rest
    }
    return result
  }

  /// How a slot's text is found in a window's title, the closest first.
  public enum TitleMatch: Int, CaseIterable, Sendable {
    case whole, beginning, somewhere
  }

  /// How closely a window with this title is what the slot's text says; nil if not at all, or if the slot has none. Case never counts.
  public func match(of windowTitle: String) -> TitleMatch? {
    guard let title, !title.isEmpty else { return nil }
    let (text, whole) = (title.lowercased(), windowTitle.lowercased())
    // As in `AppRule.matches`: `firstRange(of:)` compares whole characters on every platform.
    guard let range = whole.firstRange(of: text) else { return nil }
    if range.lowerBound != whole.startIndex { return .somewhere }
    return range.upperBound == whole.endIndex ? .whole : .beginning
  }

  /// Whether a window with this title is one the slot prefers. True without a `title`.
  public func matchesTitle(_ windowTitle: String) -> Bool {
    guard let title, !title.isEmpty else { return true }
    return match(of: windowTitle) != nil
  }

  /// Whether a window that has just appeared could fill this slot.
  public func accepts(_ window: WindowCandidate) -> Bool {
    switch owner {
    case .window(let id): id == window.id
    case .app(let name): AppName.rank(name, bundleID: window.bundleID, appName: window.appName) != nil
    }
  }
}
