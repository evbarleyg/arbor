import ArborCore

/// The words Arbor's replies use for spaces (docs/GLOSSARY.md). A reply is read by a person at a
/// terminal, and later on screen, who has never seen a node id; the id follows in brackets because
/// `zoom-node` takes it and the log needs it. App names only: window titles are never logged, and
/// every reply is.
extension Controller {
  /// "everything", "the Desktop", "Safari", "Safari and Mail", "Safari, Mail and the Desktop", "5 windows". Windows of one
  /// app are counted where the first of them stands: "2 Safari windows and Mail".
  /// A space that has a name is called by it (F20): "Writing (n5)". With `byName` false it is not, which is for
  /// whatever goes to the log without passing through `perform`: names are the user's own words, and are not logged.
  func name(of node: NodeID, on display: DisplayID, byName: Bool = true) -> String {
    guard let tree = workspaces[display]?.tree, tree.contains(node) else { return "\(node)" }
    if byName, let name = spaceName(of: node, on: display) { return "\(name) (\(node))" }
    if node == tree.root { return "everything" }
    if node == tree.desktop { return "the Desktop" }
    // Only what can be seen there is named: a minimized window, a hidden app, a window on another of
    // macOS's Spaces and a place kept for a window that does not exist (yet) are not there.
    var apps: [(name: String, windows: Int)] = []
    var desktopComesAfter: Int?
    for leaf in tree.preorder(from: node) {
      if leaf == tree.desktop {
        desktopComesAfter = apps.count
      } else if let window = tree.activeWindow(of: leaf), let snapshot = windows[window], snapshot.isPresent {
        if let index = apps.firstIndex(where: { $0.name == snapshot.appName }) {
          apps[index].windows += 1
        } else {
          apps.append((snapshot.appName, 1))
        }
      }
    }
    let shown = apps.reduce(0) { $0 + $1.windows }
    var parts = apps.map { $0.windows == 1 ? $0.name : "\($0.windows) \($0.name) windows" }
    if let desktopComesAfter { parts.insert("the Desktop", at: desktopComesAfter) }
    let words: String
    switch shown + (desktopComesAfter == nil ? 0 : 1) {
    case 0: return "\(node)"
    case 1...3: words = parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
    default: words = parts.count == 1 ? parts[0] : Self.count(shown, "window")
    }
    return "\(words) (\(node))"
  }

  /// "1 window", "3 windows".
  static func count(_ number: Int, _ noun: String) -> String {
    number == 1 ? "1 \(noun)" : "\(number) \(noun)s"
  }
}
