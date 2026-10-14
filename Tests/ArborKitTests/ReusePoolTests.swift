import ArborKit
import Testing

@Suite struct ReusePoolTests {
  /// Stands in for a panel.
  final class Thing {}

  struct Key: Hashable {
    var display: Int
    var node: Int
  }

  final class Factory {
    var made = 0
    func make() -> Thing {
      made += 1
      return Thing()
    }
  }

  func keys(_ nodes: [Int], display: Int = 1) -> [Key] { nodes.map { Key(display: display, node: $0) } }

  @Test func goingAwayAndComingBackMakesNothingNew() {
    var pool = ReusePool<Key, Thing>(sparesKept: 32)
    let factory = Factory()
    _ = pool.use(keys([1, 2, 3, 4]), replacing: { $0.display == 1 }, make: factory.make)
    #expect(factory.made == 4)
    let first = Set(pool.inUse.values.map(ObjectIdentifier.init))

    // The camera frames one window: no seams.
    let away = pool.use([], replacing: { $0.display == 1 }, make: factory.make)
    #expect(away.retired.count == 4 && away.discarded.isEmpty && pool.inUse.isEmpty && pool.spares.count == 4)

    // And steps back out.
    let back = pool.use(keys([1, 2, 3, 4]), replacing: { $0.display == 1 }, make: factory.make)
    #expect(factory.made == 4, "nothing new")
    #expect(back.retired.isEmpty && back.discarded.isEmpty && pool.spares.isEmpty)
    #expect(Set(pool.inUse.values.map(ObjectIdentifier.init)) == first)
  }

  @Test func whatStaysKeepsItsItemAndWhatGoesHandsItsOver() {
    var pool = ReusePool<Key, Thing>(sparesKept: 32)
    let factory = Factory()
    _ = pool.use(keys([1, 2]), replacing: { _ in true }, make: factory.make)
    let one = pool.inUse[Key(display: 1, node: 1)]!
    let two = pool.inUse[Key(display: 1, node: 2)]!
    let change = pool.use(keys([1, 3]), replacing: { _ in true }, make: factory.make)
    #expect(pool.inUse[Key(display: 1, node: 1)] === one)
    #expect(pool.inUse[Key(display: 1, node: 3)] === two, "straight from one key to the other, without leaving the screen")
    #expect(change.retired.isEmpty && change.discarded.isEmpty && factory.made == 2)
  }

  @Test func oneDisplaysUpdateLeavesTheOthersAlone() {
    var pool = ReusePool<Key, Thing>(sparesKept: 32)
    let factory = Factory()
    _ = pool.use(keys([1, 2], display: 1), replacing: { $0.display == 1 }, make: factory.make)
    _ = pool.use(keys([1], display: 2), replacing: { $0.display == 2 }, make: factory.make)
    let other = pool.inUse[Key(display: 2, node: 1)]!
    _ = pool.use([], replacing: { $0.display == 1 }, make: factory.make)
    #expect(pool.inUse.count == 1 && pool.inUse[Key(display: 2, node: 1)] === other)
    // What one display gave up the other can take.
    _ = pool.use(keys([1, 2, 3], display: 2), replacing: { $0.display == 2 }, make: factory.make)
    #expect(factory.made == 3 && pool.spares.isEmpty)
  }

  @Test func noMoreSparesAreKeptThanTheLimit() {
    var pool = ReusePool<Key, Thing>(sparesKept: 2)
    let factory = Factory()
    _ = pool.use(keys([1, 2, 3, 4, 5]), replacing: { _ in true }, make: factory.make)
    let change = pool.use([], replacing: { _ in true }, make: factory.make)
    #expect(change.retired.count == 2 && change.discarded.count == 3 && pool.spares.count == 2)
    let kept = Set(pool.spares.map(ObjectIdentifier.init))
    #expect(kept == Set(change.retired.map(ObjectIdentifier.init)))
    #expect(kept.isDisjoint(with: change.discarded.map(ObjectIdentifier.init)))
  }

  @Test func nothingIsEverInTwoPlaces() {
    var pool = ReusePool<Key, Thing>(sparesKept: 3)
    let factory = Factory()
    // Kept alive, or a new thing could get the address, and so the identity, of a dead one.
    var graveyard: [Thing] = []
    // A fixed walk through views of different sizes on two displays.
    for step in 0..<200 {
      let display = step % 2 + 1
      let nodes = (0..<(step * 7 % 6)).map { ($0 * 5 + step) % 9 }
      let change = pool.use(keys(Array(Set(nodes)), display: display), replacing: { $0.display == display }, make: factory.make)
      graveyard += change.discarded
      let disposed = Set(graveyard.map(ObjectIdentifier.init))
      let used = pool.inUse.values.map(ObjectIdentifier.init)
      let spare = pool.spares.map(ObjectIdentifier.init)
      // Added up first: Swift 6.2 gives up on type-checking the sums inside #expect.
      let held = used + spare
      #expect(Set(held).count == held.count)
      #expect(disposed.isDisjoint(with: held))
      #expect(pool.spares.count <= 3)
    }
  }

  @Test func emptyingReturnsEverything() {
    var pool = ReusePool<Key, Thing>(sparesKept: 8)
    let factory = Factory()
    _ = pool.use(keys([1, 2, 3]), replacing: { _ in true }, make: factory.make)
    _ = pool.use(keys([1]), replacing: { _ in true }, make: factory.make)
    #expect(pool.removeAll().count == 3)
    #expect(pool.inUse.isEmpty && pool.spares.isEmpty)
  }
}
