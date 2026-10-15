import ArborCore
import CoreGraphics
import Foundation
import Testing

/// The JSON scripts read (F50, part 3): rectangles are objects, `state` says which schema it is, and any JSON can be carried.
@Suite struct JSONShapeTests {
  struct Sample: Codable, Equatable {
    @JSONRect var frame: CGRect
    @JSONRect var maybe: CGRect?
    @JSONRect var byWindow: [WindowID: CGRect]
    var other = 1
  }

  func json(_ value: some Encodable) throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return String(decoding: try encoder.encode(value), as: UTF8.self)
  }

  @Test func rectanglesAreObjects() throws {
    let sample = Sample(
      frame: CGRect(x: 0, y: 25, width: 720, height: 875), maybe: CGRect(x: -1.5, y: 2, width: 3, height: 4.25),
      byWindow: [WindowID(412): CGRect(x: 1, y: 2, width: 3, height: 4)])
    #expect(
      try json(sample)
        == #"{"byWindow":{"412":{"height":4,"width":3,"x":1,"y":2}},"frame":{"height":875,"width":720,"x":0,"y":25},"maybe":{"height":4.25,"width":3,"x":-1.5,"y":2},"other":1}"#)
    #expect(try JSONDecoder().decode(Sample.self, from: Data(try json(sample).utf8)) == sample)
  }

  @Test func aRectangleThatIsNotThereHasNoKey() throws {
    let sample = Sample(frame: .zero, maybe: nil, byWindow: [:])
    #expect(try json(sample) == #"{"byWindow":{},"frame":{"height":0,"width":0,"x":0,"y":0},"other":1}"#)
    #expect(try JSONDecoder().decode(Sample.self, from: Data(try json(sample).utf8)) == sample)
    let withNull = #"{"byWindow":{},"frame":{"height":0,"width":0,"x":0,"y":0},"maybe":null,"other":1}"#
    #expect(try JSONDecoder().decode(Sample.self, from: Data(withNull.utf8)) == sample)
  }

  @Test func theOldFormIsStillRead() throws {
    let old = #"{"byWindow":{"7":[[1,2],[3,4]]},"frame":[[0,25],[720,875]],"maybe":[[5,6],[7,8]],"other":1}"#
    #expect(
      try JSONDecoder().decode(Sample.self, from: Data(old.utf8))
        == Sample(
          frame: CGRect(x: 0, y: 25, width: 720, height: 875), maybe: CGRect(x: 5, y: 6, width: 7, height: 8),
          byWindow: [WindowID(7): CGRect(x: 1, y: 2, width: 3, height: 4)]))
  }

  @Test(arguments: [
    #"{"byWindow":{},"frame":{"x":0,"y":0,"width":1}}"#, #"{"byWindow":{},"frame":{"x":"0","y":0,"width":1,"height":1}}"#, #"{"byWindow":{},"frame":3}"#,
    #"{"byWindow":{},"frame":[1,2,3,4]}"#, #"{"byWindow":{},"frame":null}"#, #"{"byWindow":{}}"#, #"{"byWindow":[],"frame":{"x":0,"y":0,"width":1,"height":1}}"#,
  ]) func whatIsNoRectangleIsRefused(text: String) {
    #expect(throws: (any Error).self) { try JSONDecoder().decode(Sample.self, from: Data(text.utf8)) }
  }

  @Test func aNegativeSizeIsWrittenAsItIsStored() throws {
    let sample = Sample(frame: CGRect(x: 10, y: 10, width: -4, height: -6), maybe: nil, byWindow: [:])
    #expect(try json(sample).contains(#""frame":{"height":-6,"width":-4,"x":10,"y":10}"#))
  }

  @Test func stateSaysItsSchemaAndWritesRectanglesAsObjects() throws {
    var tree = LayoutTree()
    let five = tree.dock(WindowID(5), beside: tree.desktop, edge: .left)
    tree.dock(WindowID(6), beside: five, edge: .bottom)
    let frame = CGRect(x: 0, y: 25, width: 720, height: 875)
    // Everything is too small to use, so the column is a tile with a miniature of its two windows.
    let layout = LayoutEngine.layout(
      tree, camera: tree.root, in: frame, options: LayoutOptions(gap: 10, minimumUsableSize: CGSize(width: 500, height: 100)),
      isPresent: { _ in true })
    #expect(layout.tiles.contains { !$0.miniature.isEmpty })
    let display = StateSnapshot.Display(
      id: DisplayID("main"), frame: frame, visibleFrame: frame, camera: tree.root, tree: tree, windowFrames: [WindowID(5): frame],
      tiles: layout.tiles, desktopFrame: frame, floating: [], canGoBack: false, canGoForward: false, savedViews: [:])
    let state = StateSnapshot(accessibility: true, running: true, focused: nil, displays: [display], windows: [])
    let text = try json(state)
    #expect(StateSnapshot.currentSchema == 2)
    #expect(text.contains(#""schema":2"#))
    let object = #"{"height":875,"width":720,"x":0,"y":25}"#
    for key in ["frame", "visibleFrame", "desktopFrame"] { #expect(text.contains("\"\(key)\":\(object)"), "\(key)") }
    #expect(text.contains("\"windowFrames\":{\"5\":\(object)}"))
    #expect(text.contains("\"miniature\":{\"5\":{\"height\":"))
    #expect(!text.contains("[["), "a rectangle is still written Foundation's way")
    #expect(try JSONDecoder().decode(StateSnapshot.self, from: Data(text.utf8)) == state)
  }

  // MARK: JSONValue

  @Test func anyJSONSurvives() throws {
    let text = #"{"a":[1,-2.5,true,false,null,"x",{"b":[]},{}],"c":"é\n","d":9007199254740993,"e":1e300}"#
    let value = try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    #expect(value["a"]?[0] == .int(1))
    #expect(value["a"]?[1] == .number(-2.5))
    #expect(value["a"]?[2] == .bool(true))
    #expect(value["a"]?[4] == .null)
    #expect(value["a"]?[5] == .string("x"))
    #expect(value["a"]?[6]?["b"] == .array([]))
    #expect(value["a"]?[7] == .object([:]))
    #expect(value["a"]?[8] == nil && value["a"]?[-1] == nil && value["zz"] == nil && value["a"]?["b"] == nil)
    #expect(value["d"] == .int(9_007_199_254_740_993))
    #expect(try JSONDecoder().decode(JSONValue.self, from: Data(value.text.utf8)) == value)
  }

  @Test func itIsWrittenOnOneLineWithSortedKeysAndPlainSlashes() {
    #expect(JSONValue.object(["b": .int(1), "a": .string("x/y"), "c": .array([.null, .bool(false)])]).text == #"{"a":"x/y","b":1,"c":[null,false]}"#)
  }

  @Test func anythingEncodableBecomesJSON() {
    #expect(JSONValue(encoding: [WindowID(4)]) == .array([.int(4)]))
    #expect(JSONValue(encoding: ["a": 1.5]) == .object(["a": .number(1.5)]))
    #expect(JSONValue(encoding: Double.nan) == nil)
  }

  @Test func aReplyCarriesItBesideTheText() throws {
    let result = CommandResult(ok: true, message: "1 window", text: "412\tdocked", json: .array([.object(["id": .int(412)])]))
    #expect(try json(result) == #"{"json":[{"id":412}],"message":"1 window","ok":true,"text":"412\tdocked"}"#)
    #expect(try JSONDecoder().decode(CommandResult.self, from: Data(try json(result).utf8)) == result)
    // Replies without it look as they always did.
    #expect(try json(CommandResult.success("done")) == #"{"message":"done","ok":true}"#)
  }
}
