// Named spaces (docs/features/F20-named-spaces.md): the names of one display's spaces.
//
// `names` maps each name, as typed, to its node. Two rules hold at all times: no two names are alike
// (capitals aside), and no node has two names. A group that has a name is kept for it
// (LayoutTree+Keeps.swift): it neither dissolves into the group around it nor gives way to its last window.

extension Workspace {
  // MARK: Reading

  public func name(of node: NodeID) -> String? { names.first { $0.value == node }?.key }

  /// The space of exactly that name, capitals aside.
  public func node(named name: String) -> NodeID? {
    SpaceName.exact(name, among: names.keys).flatMap { names[$0] }
  }

  /// The same spaces under other names, for whoever may show the arrangement but not what a person called it (traces). The marks
  /// that keep a named group hang on the nodes, so nothing else has to follow. `transform` must keep different names different.
  public func renamingSpaces(_ transform: (String) -> String) -> Workspace {
    var copy = self
    copy.names = Dictionary(names.map { (transform($0.key), $0.value) }, uniquingKeysWith: { first, _ in first })
    return copy
  }

  // MARK: Naming

  /// What `setName` did, for whoever tells the user.
  public struct Naming: Equatable, Sendable {
    /// The name as it is kept.
    public var name: String
    public var node: NodeID
    /// The name the space had until now, if it differs at all (also only in capitals).
    public var replaced: String?
    /// The space that had the name until now.
    public var takenFrom: NodeID?
    /// Whether anything changed.
    public var changed: Bool
  }

  /// Names `node`. A name it already has is replaced, and a space that has this name loses it.
  /// Throws a `SpaceName.Problem` if `text` cannot be a name. A node that does not exist stands
  /// for the root, as everywhere.
  @discardableResult
  public mutating func setName(_ text: String, of node: NodeID) throws -> Naming {
    let name = try SpaceName.tidied(text)
    let node = tree.contains(node) ? node : tree.root
    let before = names
    let old = self.name(of: node)
    let holder = self.node(named: name)
    if let old { names[old] = nil }
    if let taken = SpaceName.exact(name, among: names.keys) { names[taken] = nil }
    names[name] = node
    keepWhatIsNamed()
    return Naming(
      name: name, node: node, replaced: old == name ? nil : old, takenFrom: holder == node ? nil : holder,
      changed: names != before)
  }

  /// Takes the name off `node` and returns it.
  @discardableResult
  public mutating func removeName(of node: NodeID) -> String? {
    guard let name = name(of: node) else { return nil }
    names[name] = nil
    keepWhatIsNamed()
    return name
  }

  /// Keeps exactly the groups that have a name. One that has lost its name dissolves if the tree would not
  /// have left it standing, and the view and everything else that pointed at it follow. Giving a name
  /// lets go of nothing, and then this changes no more than a mark in the tree.
  mutating func keepWhatIsNamed() {
    let named = Set(names.values)
    guard Set(tree.kept(for: .name)).isSubset(of: named) else {
      changeStructure { $0.keep(exactly: named, for: .name) }
      return
    }
    tree.keep(exactly: named, for: .name)
  }

  // MARK: Following the tree

  /// Drops the names whose spaces went with their last window: the nearest thing left is the group around them,
  /// which was never called that. The others stay where they are: a named group is kept firmly, so it is never
  /// merged or replaced, and a leaf has nothing to collapse into. So no two names can come to the same node here.
  mutating func follow(_ remap: Remap) {
    guard !names.isEmpty else { return }
    names = names.compactMapValues { remap.survivor(of: $0, in: tree) }
  }

  /// A window was docked at an edge of the view, which was on `space` and is now on `group`: the two of them
  /// together (`Workspace.dock`). If the space had a name, the group has it from now on: someone who is in
  /// "Code" and docks a terminal below is still in "Code".
  mutating func moveName(from space: NodeID, to group: NodeID) {
    guard let name = name(of: space), self.name(of: group) == nil else { return }
    names[name] = group
    tree.keep(group, for: .name)
    apply(tree.stopKeeping(space, for: .name))
  }

  /// Removes and returns the names of the spaces that hold `window` and nothing else: its own place,
  /// and any group that is down to it. Call before the window is taken out to be docked elsewhere;
  /// `give` hands them on to the place where it lands.
  mutating func takeNames(ofSpacesHoldingOnly window: WindowID) -> [String] {
    guard !names.isEmpty, let leaf = tree.leaf(containing: window) else { return [] }
    let lineage = [leaf] + tree.ancestors(of: leaf)
    let emptied = lineage.prefix { holdsOnly(window, in: $0) }
    let taken = SpaceName.sorted(names.filter { emptied.contains($0.value) }.keys)
    for name in taken { names[name] = nil }
    return taken
  }

  /// Whether `window` is all there is in `node`: its own place, or a kept group that is down to it.
  public func holdsOnly(_ window: WindowID, in node: NodeID) -> Bool {
    tree.windows(under: node) == [window] && !tree.subtree(node, contains: tree.desktop)
  }

  /// The window those names went with has landed in `node`. A space keeps the name it has, so this
  /// does nothing if the window joined a named tab group, and only the first of several names stays.
  mutating func give(_ taken: [String], to node: NodeID) {
    guard let name = taken.first, self.name(of: node) == nil, SpaceName.exact(name, among: names.keys) == nil else {
      return
    }
    names[name] = node
  }

  // MARK: Reading a file

  /// A value that costs only itself if it cannot be read. (`LossyDictionary` does the same for a whole object, but
  /// notes the keys it skips, and these keys are names.)
  struct Lenient<Value: Decodable>: Decodable {
    var value: Value?
    init(from decoder: any Decoder) { value = try? Value(from: decoder) }
  }

  /// What can be believed of the `names` in a `state.json`. The texts themselves are not put in the notes, which are
  /// logged: names are not, and one that is refused may be refused for what it would do to a log.
  static func readable(
    _ saved: [String: Lenient<NodeID>], in tree: LayoutTree, notes: inout [String]
  ) -> [String: NodeID] {
    var result: [String: NodeID] = [:]
    var keys = Set<String>()
    var nodes = Set<NodeID>()
    for name in SpaceName.sorted(saved.keys) {
      guard let node = saved[name]?.value else {
        notes.append("a name had no space's number")
        continue
      }
      if !SpaceName.isTidy(name) {
        notes.append("the name of \(node) is not a possible name")
      } else if !tree.contains(node) {
        notes.append("a name was of \(node), which does not exist")
      } else if !keys.insert(SpaceName.key(name)).inserted {
        notes.append("the name of \(node) is also that of another space")
      } else if !nodes.insert(node).inserted {
        notes.append("\(node) had two names")
      } else {
        result[name] = node
      }
    }
    return result
  }
}
