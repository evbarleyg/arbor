import ArborCore
import CoreGraphics

/// Finding the windows a command names (ArborCore/WindowRef.swift).
extension Controller {
  /// The plain command that `command` stands for now, or why there is none: the first name that means nothing ends it. Asking changes nothing.
  func plain(_ command: Command, naming names: [WindowRef]) -> Result<Command, Command.ParseError> {
    guard isRunning else { return .failure(Command.ParseError(refusing: statusText)) }
    var found: [WindowID] = []
    let candidates = windowCandidates()
    for name in names {
      switch window(for: name, among: candidates) {
      case .success(let id): found.append(id)
      case .failure(let refusal): return .failure(refusal)
      }
    }
    guard let plain = command.filling(found) else { return .failure(Command.ParseError(refusing: "cannot read `\(command.text)`")) }
    return .success(plain)
  }

  private func window(for name: WindowRef, among candidates: [WindowCandidate]) -> Result<WindowID, Command.ParseError> {
    switch name {
    case .app(let app):
      guard let window = AppName.windows(of: app, in: candidates).first else {
        return .failure(Command.ParseError(refusing: "no window of \(app); `windows` lists them"))
      }
      return .success(window.id)
    case .focused:
      // As for a command that names nobody (`target(nil)`): for a moment after `focus Mail` macOS still reports the window before.
      guard let id = keyboardFocus() else { return .failure(Command.ParseError(refusing: "no focused window")) }
      return .success(id)
    case .pointer:
      guard let id = windowUnderPointer(among: candidates) else {
        return .failure(Command.ParseError(refusing: "no window under the pointer"))
      }
      return .success(id)
    }
  }

  /// The bundle id a word means where a command keeps a list of apps (`exclude`, `include`, `pass-through`). Those lists hold bundle ids, so a
  /// name put on one as it stands would match nothing, and the reply would say that it had worked. `listed` is the list concerned.
  ///
  /// A bundle id Arbor has met or that is listed, in any case; failing that an app's name, as `zoom Terminal` finds it (`AppName`), among
  /// every app with a window, arranged or not, then among the list; failing that anything with a dot in it, which may be the bundle
  /// id of an app that is not open now.
  func bundleID(named word: String, listed: [String]) -> Result<String, Command.ParseError> {
    var met = windows.values.sorted { $0.id < $1.id }.compactMap { window in
      window.bundleID.map { WindowCandidate(id: window.id, bundleID: $0, appName: window.appName) }
    }
    if let app = frontmostApp, let bundle = app.bundleID { met.append(WindowCandidate(id: WindowID(0), bundleID: bundle, appName: app.name)) }
    func distinct(_ ids: [String]) -> [String] {
      var seen = Set<String>()
      return ids.filter { seen.insert($0.lowercased()).inserted }
    }
    if let exact = (listed + met.compactMap(\.bundleID)).first(where: { $0.lowercased() == word.lowercased() }) { return .success(exact) }
    var meant = distinct(AppName.windows(of: word, in: met).compactMap(\.bundleID))
    if meant.isEmpty { meant = distinct(listed.filter { AppName.rank(word, bundleID: $0, appName: "") != nil }) }
    switch meant.count {
    case 1: return .success(meant[0])
    case 2...: return .failure(Command.ParseError(refusing: "\(word) could be \(meant.prefix(4).joined(separator: " or ")); say which"))
    default:
      guard word.contains(".") else {
        return .failure(
          Command.ParseError(refusing: "no app called \(word) has a window open; open one, or name it by its bundle id, like com.apple.Terminal"))
      }
      return .success(word)
    }
  }

  /// The window Arbor arranges that the pointer is over. Where several overlap, floating windows are above docked
  /// ones, and among floating ones the most recently focused is on top.
  func windowUnderPointer(among candidates: [WindowCandidate]) -> WindowID? {
    let point = system.cursorLocation()
    let under = candidates.map(\.id).filter { id in
      guard let window = windows[id], window.isPresent, !parked.contains(id) else { return false }
      return window.frame.contains(point)
    }
    return under.first { id in workspaces.values.contains { $0.isFloating(id) } } ?? under.first
  }
}
