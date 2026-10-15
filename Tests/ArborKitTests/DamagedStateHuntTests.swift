import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// `state.json` as a rich session leaves it, with any value anywhere in it damaged. Whatever it holds, Arbor reads it or
/// sets it aside, starts, and is in working order. The damage knows nothing of the fields, so it covers those to come.
@MainActor @Suite struct DamagedStateHuntTests {
  private struct Random: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &* 0xD134_2543_DE82_EF95 }
    mutating func next() -> UInt64 {
      state &+= 0x9E37_79B9_7F4A_7C15
      var z = state
      z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
      z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
      return z ^ (z >> 31)
    }
  }

  /// A session with a bit of everything in it.
  private static let script = [
    "open Delta at 300,300", "open Echo at 1700,200", "open Alpha at 1900,300",
    "layout Alpha | (Beta / Gamma) | Desktop", "zoom 102", "save-view 1", "out", "name Pair", "save-view 2", "show-all",
    "name All", "pin 104", "pointer 2000,400", "dock 105 left", "dock 106 beside 105 bottom", "zoom 105",
    "dock 106 right", "save-view 3", "name Side", "back", "forward", "displays main", "pointer 400,400", "summon Echo",
    "summon Alpha", "zoom 101", "open Foxtrot at 200,200", "dock 103 right",
    "layout --open Alpha | Zulu | (Beta / Gamma) | Desktop", "zoom 102", "out", "name Pair", "save-view 4", "zoom 102",
    "open Golf at 260,260", "summon Echo", "hold",
  ]

  /// Every place in a JSON value, as a path of keys and indices.
  private static func paths(in value: Any, at path: [Any] = []) -> [[Any]] {
    var result = [path]
    if let object = value as? [String: Any] {
      for key in object.keys.sorted() { result += paths(in: object[key]!, at: path + [key]) }
    } else if let array = value as? [Any] {
      for (index, element) in array.enumerated() { result += paths(in: element, at: path + [index]) }
    }
    return result
  }

  private static func value(at path: ArraySlice<Any>, in value: Any) -> Any? {
    guard let step = path.first else { return value }
    if let key = step as? String {
      return (value as? [String: Any])?[key].flatMap { Self.value(at: path.dropFirst(), in: $0) }
    }
    if let index = step as? Int, let array = value as? [Any], array.indices.contains(index) {
      return Self.value(at: path.dropFirst(), in: array[index])
    }
    return nil
  }

  /// `value` with what is at `path` replaced, or removed if `new` is nil.
  private static func replacing(_ path: ArraySlice<Any>, in value: Any, with new: Any?) -> Any {
    guard let step = path.first else { return new ?? NSNull() }
    if let key = step as? String, var object = value as? [String: Any] {
      if path.count == 1, new == nil { object[key] = nil } else if let old = object[key] {
        object[key] = replacing(path.dropFirst(), in: old, with: new)
      }
      return object
    }
    if let index = step as? Int, var array = value as? [Any], array.indices.contains(index) {
      if path.count == 1, new == nil { array.remove(at: index) } else {
        array[index] = replacing(path.dropFirst(), in: array[index], with: new)
      }
      return array
    }
    return value
  }

  @Test(arguments: Array<UInt64>(1...100)) func whateverIsDamagedArborStartsAndWorks(seed: UInt64) throws {
    var random = Random(seed: seed)
    let session = HalfInTheTreeTests.Session(tabs: seed % 2 == 0)
    for step in Self.script { session.apply(step) }
    session.h.controller.saveNow()
    let saved = try #require(session.h.store.saved)
    var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(saved))
    var done: [String] = []
    for _ in 0..<Int.random(in: 1...3, using: &random) {
      let all = Self.paths(in: json).filter { !$0.isEmpty }
      let path = all.randomElement(using: &random)!
      let junk: [Any?] = [
        nil, NSNull(), 0, -1, 1, 7, 4711, 1e300, -1e300, 0.5, Int.max, Int.min, "", "x", "n1", "101", true, [Any](),
        [String: Any](), [0], ["a": 1], Self.value(at: all.randomElement(using: &random)![...], in: json),
      ]
      let new = junk.randomElement(using: &random)!
      json = Self.replacing(path[...], in: json, with: new)
      let place = path.map { "\($0)" }.joined(separator: ".")
      done.append("\(place) = \(new.map { String(describing: $0).prefix(40) } ?? "(removed)")")
    }
    let data = try JSONSerialization.data(withJSONObject: json)
    guard case .loaded(let state) = PersistedState.read(data) else { return }

    let h = Harness(displays: [FakeWindowSystem.standardDisplay], saved: state)
    for window in session.h.system.allWindows() {
      h.system.open(
        app: window.appName, bundleID: window.bundleID, title: window.title, pid: window.pid, frame: window.frame)
    }
    h.start()
    var problems = HalfInTheTreeTests.problems(in: h)
    let commands = [
      "state", "back", "view 1", "view 2", "go Pair", "go All", "spaces", "out", "dock 101 left", "layout", "arrange",
      "float-all",
    ]
    for command in commands where problems.isEmpty {
      h.run(command)
      problems = HalfInTheTreeTests.problems(in: h).map { "after `\(command)`: \($0)" }
    }
    #expect(problems.isEmpty, "seed \(seed): \(done.joined(separator: " ; "))")
  }
}
