import ArborCore

/// The words Arbor's replies use for spaces (docs/GLOSSARY.md). A reply is read by a person at a
/// terminal, and later on screen, who has never seen a node id; the id follows in brackets because
/// `zoom-node` takes it and the log needs it. App names only: window titles are never logged, and
/// every reply is.
extension Controller {
  /// "everything", "the Desktop", "Safari", "Safari and Mail", "Safari, Mail and the Desktop", "5 windows".
  /// A space that has a name is called by it (F20): "Writing (n5)". With `byName` false it is not, which is for
  /// whatever goes to the log without passing through `perform`: names are the user's own words, and are not logged.
  func name(of node: NodeID, on display: DisplayID, byName: Bool = true) -> String {
    guard let tree = workspaces[display]?.tree, tree.contains(node) else { return "\(node)" }
    if byName, let name = spaceName(of: node, on: display) { return "\(name) (\(node))" }
    if node == tree.root { return "everything" }
    if node == tree.desktop { return "the Desktop" }
    // Only what can be seen there is named: a minimized window, a hidden app, a window on another of
    // macOS's Spaces and a place kept for a window that does not exist (yet) take no room.
    var parts: [String] = []
    var shown = 0
    for leaf in tree.preorder(from: node) {
      if leaf == tree.desktop {
        parts.append("the Desktop")
      } else if let window = tree.activeWindow(of: leaf), let snapshot = windows[window], snapshot.isPresent {
        parts.append(snapshot.appName)
        shown += 1
      }
    }
    let words: String
    switch parts.count {
    case 0: return "\(node)"
    case 1: words = parts[0]
    case 2, 3: words = parts.dropLast().joined(separator: ", ") + " and " + parts[parts.count - 1]
    default: words = Self.count(shown, "window")
    }
    return "\(words) (\(node))"
  }

  /// "1 window", "3 windows".
  static func count(_ number: Int, _ noun: String) -> String {
    number == 1 ? "1 \(noun)" : "\(number) \(noun)s"
  }
}
