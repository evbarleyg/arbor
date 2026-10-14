/// Things that are dear to make and cheap to keep. Making one of Arbor's panels and showing it for the first time
/// takes about three milliseconds, and a step back out to a dozen windows needs a dozen seam handles: most of what
/// that command cost. So what goes out of use is kept, up to a limit, and handed out again.
///
/// The pool only decides who gets what. Showing, hiding and disposing are the caller's, which is why it can be tested
/// without a screen.
public struct ReusePool<Key: Hashable, Item> {
  /// What each key has now.
  public private(set) var inUse: [Key: Item] = [:]
  /// Out of use, waiting to be handed out again.
  public private(set) var spares: [Item] = []
  public let sparesKept: Int

  public struct Change {
    /// Went out of use and are kept: take them off the screen.
    public var retired: [Item] = []
    /// Went out of use and are one too many: dispose of them.
    public var discarded: [Item] = []
  }

  public init(sparesKept: Int) {
    self.sparesKept = max(sparesKept, 0)
  }

  /// Gives every key in `keys` an item: the one it has, else one that just went out of use (which is still on
  /// screen, and only has to move), else a spare, else a new one. Of the keys in use so far, those for which
  /// `isReplaced` holds (one display's, say) and that are not among `keys` give up theirs.
  public mutating func use(_ keys: [Key], replacing isReplaced: (Key) -> Bool, make: () -> Item) -> Change {
    let wanted = Set(keys)
    var freed: [Item] = []
    for key in inUse.keys.filter({ isReplaced($0) && !wanted.contains($0) }) {
      if let item = inUse.removeValue(forKey: key) { freed.append(item) }
    }
    for key in keys where inUse[key] == nil {
      inUse[key] = freed.popLast() ?? spares.popLast() ?? make()
    }
    var change = Change()
    for item in freed {
      if spares.count < sparesKept {
        spares.append(item)
        change.retired.append(item)
      } else {
        change.discarded.append(item)
      }
    }
    return change
  }

  /// Empties the pool and returns everything that was in it, in use or spare.
  public mutating func removeAll() -> [Item] {
    let all = Array(inUse.values) + spares
    inUse.removeAll()
    spares.removeAll()
    return all
  }
}
