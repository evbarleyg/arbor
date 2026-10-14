import ArborCore
import Foundation
import Testing

/// What Arbor itself writes: two spaces, a space on both sides of the colon.
private let pretty = """
  {
    "gap" : 12,
    "apps" : [
      "one",
      "two"
    ],
    "keys" : {
      "a" : "dock left",
      "b" : null
    },
    "on" : true
  }

  """

@Suite struct JSONTextReadingTests {
  @Test func readsValuesExactlyAsWritten() throws {
    let document = try JSONText(#"{"a": 1.50, "b": {"c": [1,  2], "d": "x\ty"}, "e": null}"#)
    #expect(document.value(at: ["a"]) == "1.50")
    #expect(document.value(at: ["b", "c"]) == "[1,  2]")
    #expect(document.value(at: ["b", "d"]) == #""x\ty""#)
    #expect(document.value(at: ["e"]) == "null")
    #expect(document.value(at: []) == document.text)
    #expect(document.value(at: ["missing"]) == nil)
    #expect(document.value(at: ["a", "deeper"]) == nil)
  }

  @Test func listsKeysAndElementsInTheOrderWritten() throws {
    let document = try JSONText(#"{"z": 1, "a": [3, "x", {"k": 1}, []], "m": {}}"#)
    #expect(document.keys(at: []) == ["z", "a", "m"])
    #expect(document.keys(at: ["m"]) == [])
    #expect(document.keys(at: ["a"]) == nil)
    #expect(document.elements(at: ["a"]) == ["3", #""x""#, #"{"k": 1}"#, "[]"])
    #expect(document.elements(at: ["z"]) == nil)
    #expect(document.keys(at: ["nothing"]) == nil && document.elements(at: ["nothing"]) == nil)
  }

  @Test func keysAreComparedWithTheirEscapesResolved() throws {
    let document = try JSONText(#"{"g\u0061p": 1, "a\"b\\c\/d": 2, "\ud83d\udc4d": 3, "tab\there": 4}"#)
    #expect(document.keys(at: []) == ["gap", #"a"b\c/d"#, "👍", "tab\there"])
    #expect(document.value(at: ["gap"]) == "1")
    #expect(document.value(at: ["👍"]) == "3")
  }

  @Test func anyValueCanBeTheRoot() throws {
    for text in ["1", "-0.5e+3", #""text""#, "true", "false", "null", "[]", " [1] ", "{}"] {
      #expect(try JSONText(text).text == text)
    }
  }

  @Test func quotesText() {
    #expect(JSONText.quote("plain") == #""plain""#)
    #expect(JSONText.quote(#"a"b\c"#) == #""a\"b\\c""#)
    #expect(JSONText.quote("line\nbreak\ttab\r") == #""line\nbreak\ttab\r""#)
    #expect(JSONText.quote("\u{1}\u{1f}") == #""\u0001\u001f""#)
    #expect(JSONText.quote("ctrl+opt+/ ⌘ 👍") == #""ctrl+opt+/ ⌘ 👍""#)
  }
}

@Suite struct JSONTextSettingTests {
  /// `text` after `change`, checked to differ from `text` only as `expected` says.
  func changed(_ text: String, _ change: (JSONText) throws -> JSONText) throws -> String {
    try change(try JSONText(text)).text
  }

  @Test func replacingAValueLeavesEveryOtherByteAlone() throws {
    #expect(
      try changed(pretty) { try $0.setting(["gap"], to: "20.5") }
        == pretty.replacingOccurrences(of: #""gap" : 12,"#, with: #""gap" : 20.5,"#))
    #expect(
      try changed(pretty) { try $0.setting(["on"], to: "false") }
        == pretty.replacingOccurrences(of: "true", with: "false"))
    #expect(
      try changed(pretty) { try $0.setting(["keys", "b"], to: #""zoom""#) }
        == pretty.replacingOccurrences(of: "null", with: #""zoom""#))
  }

  @Test func settingTheSameValueChangesNothing() throws {
    #expect(try changed(pretty) { try $0.setting(["gap"], to: "12") } == pretty)
    let odd = "{ \"a\":1.0 ,\t\"b\" :[ ] }\n\n"
    #expect(try changed(odd) { try $0.setting(["a"], to: "1.0") } == odd)
  }

  @Test func aListKeepsTheLayoutOfTheOneItReplaces() throws {
    let spread = try changed(pretty) { try $0.setting(["apps"], to: #"["one","two","three"]"#) }
    #expect(
      spread
        == pretty.replacingOccurrences(of: "    \"two\"\n", with: "    \"two\",\n    \"three\"\n"))

    let oneLine = "{\n  \"apps\": [\"one\", \"two\"],\n  \"gap\": 1\n}"
    #expect(
      try changed(oneLine) { try $0.setting(["apps"], to: #"["one","two","three"]"#) }
        == "{\n  \"apps\": [\"one\", \"two\", \"three\"],\n  \"gap\": 1\n}")
  }

  @Test func anEmptyListIsFilledTheWayItsFileIsLaidOut() throws {
    #expect(
      try changed("{\n  \"apps\": [],\n  \"gap\": 1\n}") { try $0.setting(["apps"], to: #"["one"]"#) }
        == "{\n  \"apps\": [\n    \"one\"\n  ],\n  \"gap\": 1\n}")
    #expect(
      try changed(#"{"apps": [], "gap": 1}"#) { try $0.setting(["apps"], to: #"["one"]"#) }
        == #"{"apps": ["one"], "gap": 1}"#)
    // What JSONEncoder writes for an empty list.
    #expect(
      try changed("{\n  \"apps\" : [\n\n  ]\n}") { try $0.setting(["apps"], to: #"["one"]"#) }
        == "{\n  \"apps\" : [\n    \"one\"\n  ]\n}")
    #expect(try changed(pretty) { try $0.setting(["apps"], to: "[]") }.contains("\"apps\" : [],\n"))
  }

  @Test func aNewKeyGoesAtTheEndInTheStyleOfTheFile() throws {
    #expect(
      try changed(pretty) { try $0.setting(["new"], to: "1") }
        == pretty.replacingOccurrences(of: "\"on\" : true\n", with: "\"on\" : true,\n  \"new\" : 1\n"))
    #expect(
      try changed("{\n    \"a\": 1\n}\n") { try $0.setting(["b"], to: #"{"c":[1,{"d":2}]}"#) }
        == "{\n    \"a\": 1,\n    \"b\": {\n        \"c\": [\n            1,\n            {\n                \"d\": 2\n            }\n        ]\n    }\n}\n"
    )
    #expect(
      try changed("{\n\t\"a\":1\n}") { try $0.setting(["b"], to: "[2]") }
        == "{\n\t\"a\":1,\n\t\"b\":[\n\t\t2\n\t]\n}")
    #expect(
      try changed(#"{"a": 1}"#) { try $0.setting(["b"], to: #"{"c":[1,2]}"#) }
        == #"{"a": 1, "b": {"c": [1, 2]}}"#)
    #expect(
      try changed("{\r\n  \"a\": 1\r\n}\r\n") { try $0.setting(["b"], to: "[2]") }
        == "{\r\n  \"a\": 1,\r\n  \"b\": [\r\n    2\r\n  ]\r\n}\r\n")
    // No indentation at all is a style too.
    #expect(try changed("{\n\"a\": 1\n}") { try $0.setting(["b"], to: "2") } == "{\n\"a\": 1,\n\"b\": 2\n}")
  }

  @Test func anEmptyObjectIsFilledLikeAFileOfArbors() throws {
    for empty in ["{}", "{ }", "{\n}", "{\n\n}"] {
      #expect(try changed(empty) { try $0.setting(["a"], to: "1") } == "{\n  \"a\" : 1\n}", "\(empty)")
    }
    #expect(
      try changed(" {} \n") { try $0.setting(["a"], to: "[1]") } == " {\n   \"a\" : [\n     1\n   ]\n } \n")
  }

  @Test func keysInsideObjectsFollowThatObject() throws {
    #expect(
      try changed(pretty) { try $0.setting(["keys", "c"], to: #""zoom""#) }
        == pretty.replacingOccurrences(of: "\"b\" : null\n", with: "\"b\" : null,\n    \"c\" : \"zoom\"\n"))
    let mixed = "{\n  \"keys\": {\"a\":\"x\"},\n  \"empty\": {}\n}"
    #expect(
      try changed(mixed) { try $0.setting(["keys", "b"], to: "null") }
        == "{\n  \"keys\": {\"a\":\"x\", \"b\":null},\n  \"empty\": {}\n}")
    #expect(
      try changed(mixed) { try $0.setting(["empty", "b"], to: "1") }
        == "{\n  \"keys\": {\"a\":\"x\"},\n  \"empty\": {\n    \"b\": 1\n  }\n}")
  }

  @Test func missingObjectsOnTheWayAreAdded() throws {
    #expect(
      try changed("{\n  \"a\": 1\n}") { try $0.setting(["b", "c", "d"], to: "2") }
        == "{\n  \"a\": 1,\n  \"b\": {\n    \"c\": {\n      \"d\": 2\n    }\n  }\n}")
    #expect(try changed(#"{"a": 1}"#) { try $0.setting(["b", "c"], to: "2") } == #"{"a": 1, "b": {"c": 2}}"#)
  }

  @Test func aKeyCannotBeSetInsideSomethingThatIsNotAnObject() throws {
    let document = try JSONText(#"{"a": 1, "b": [1]}"#)
    #expect(throws: JSONText.EditError(description: "`a` is not an object, so `c` cannot be set in it")) {
      try document.setting(["a", "c"], to: "2")
    }
    #expect(throws: JSONText.EditError.self) { try document.setting(["b", "c", "d"], to: "2") }
    #expect(throws: JSONText.EditError(description: "the file is not an object, so `a` cannot be set in it"))
    {
      try JSONText("[1]").setting(["a"], to: "2")
    }
    #expect(throws: JSONText.SyntaxError.self) { try document.setting(["a"], to: "not json") }
  }

  @Test func newKeysAreEscapedAndFoundAgain() throws {
    let key = "a\"b\\c\n👍"
    let document = try JSONText("{}").setting([key], to: "1")
    #expect(document.text == "{\n  \"a\\\"b\\\\c\\n👍\" : 1\n}")
    #expect(document.keys(at: []) == [key])
    #expect(try document.setting([key], to: "2").keys(at: []) == [key])
  }

  @Test func aKeyWrittenWithEscapesIsReplacedNotAddedAgain() throws {
    #expect(try changed(#"{"g\u0061p": 1}"#) { try $0.setting(["gap"], to: "2") } == #"{"g\u0061p": 2}"#)
  }

  /// `JSONDecoder` reads the first, so that is the one to change. The other may hold entries of its own.
  @Test func ofAKeyWrittenTwiceTheFirstIsSet() throws {
    let text = #"{"a": 1, "b": [1, 2], "a": "long text"}"#
    #expect(
      try changed(text) { try $0.setting(["a"], to: "22") } == #"{"a": 22, "b": [1, 2], "a": "long text"}"#)
    #expect(try JSONText(text).value(at: ["a"]) == "1")
    struct Both: Decodable { var a: Int }
    #expect(try JSONDecoder().decode(Both.self, from: Data(text.utf8)).a == 1)
  }

  @Test func theRootCannotBeReplaced() throws {
    #expect(throws: JSONText.EditError.self) { try JSONText("[1]").setting([], to: "{}") }
  }

  @Test func whatSurroundsTheRootStays() throws {
    let marked = "\u{FEFF}\n\n  {\"a\": 1}\n\t\n"
    #expect(try changed(marked) { try $0.setting(["a"], to: "2") } == "\u{FEFF}\n\n  {\"a\": 2}\n\t\n")
  }
}

@Suite struct JSONTextArrayTests {
  @Test func elementsAreLaidOutOrKeptAsTheyAre() throws {
    let text = "{\n  \"rules\": [\n    { \"app\": \"a\",   \"action\": \"float\" },\n    5\n  ]\n}"
    let document = try JSONText(text)
    let kept = try #require(document.elements(at: ["rules"]))
    let result = try document.settingArray(
      ["rules"], to: [.verbatim(kept[0]), .value(#"{"app":"b","action":"ignore"}"#), .verbatim(kept[1])])
    #expect(
      result.text
        == "{\n  \"rules\": [\n    { \"app\": \"a\",   \"action\": \"float\" },\n    { \"app\": \"b\", \"action\": \"ignore\" },\n    5\n  ]\n}"
    )
  }

  /// On one line if they are, with their space inside the brackets; spread out if any of them is, or
  /// if there is none to go by.
  @Test(arguments: [
    ("[\n    {\"a\": 1}\n  ]", "[\n    {\"a\": 1},\n    {\"b\": [2, 3]}\n  ]"),
    ("[\n    { \"a\": 1 }\n  ]", "[\n    { \"a\": 1 },\n    { \"b\": [ 2, 3 ] }\n  ]"),
    (
      "[\n    {\"a\": 1},\n    {\n      \"a\": 2\n    }\n  ]",
      "[\n    {\"a\": 1},\n    {\n      \"a\": 2\n    },\n    {\n      \"b\": [\n        2,\n        3\n      ]\n    }\n  ]"
    ),
    ("[\n    5\n  ]", "[\n    5,\n    {\n      \"b\": [\n        2,\n        3\n      ]\n    }\n  ]"),
    ("[{}]", "[{}, {\"b\": [2, 3]}]"),
  ]) func aNewElementIsWrittenLikeTheOnesThatStay(list: String, expected: String) throws {
    let document = try JSONText("{\n  \"list\": \(list)\n}")
    let kept = try #require(document.elements(at: ["list"])).map { JSONText.Element.verbatim($0) }
    #expect(
      try document.settingArray(["list"], to: kept + [.value(#"{"b":[2,3]}"#)]).text
        == "{\n  \"list\": \(expected)\n}")
  }

  @Test func aOneLineListStaysOnItsLineUnlessAnElementCannot() throws {
    let document = try JSONText("{\n  \"list\": [1, 2]\n}")
    #expect(
      try document.settingArray(["list"], to: [.verbatim("1"), .value("[3]")]).text
        == "{\n  \"list\": [1, [3]]\n}")
    #expect(
      try document.settingArray(["list"], to: [.verbatim("1"), .verbatim("{\n      \"a\": 1\n    }")]).text
        == "{\n  \"list\": [\n    1,\n    {\n      \"a\": 1\n    }\n  ]\n}")
    #expect(try document.settingArray(["list"], to: []).text == "{\n  \"list\": []\n}")
  }

  @Test func aMissingListIsAdded() throws {
    #expect(
      try JSONText("{\n  \"a\": 1\n}").settingArray(["list"], to: [.value("1"), .value("2")]).text
        == "{\n  \"a\": 1,\n  \"list\": [\n    1,\n    2\n  ]\n}")
  }

  @Test func elementsMustBeJSON() throws {
    let document = try JSONText(#"{"list": []}"#)
    #expect(throws: JSONText.SyntaxError.self) {
      try document.settingArray(["list"], to: [.verbatim("1, 2")])
    }
    #expect(throws: JSONText.SyntaxError.self) { try document.settingArray(["list"], to: [.value("")]) }
  }
}

@Suite struct JSONTextRemovingTests {
  func removed(_ text: String, _ path: [String]) throws -> String { try JSONText(text).removing(path).text }

  @Test func removesAKeyWithItsLine() throws {
    #expect(try removed(pretty, ["gap"]) == pretty.replacingOccurrences(of: "  \"gap\" : 12,\n", with: ""))
    #expect(try removed(pretty, ["on"]) == pretty.replacingOccurrences(of: ",\n  \"on\" : true", with: ""))
    #expect(
      try removed(pretty, ["apps"])
        == pretty.replacingOccurrences(of: "  \"apps\" : [\n    \"one\",\n    \"two\"\n  ],\n", with: ""))
    #expect(
      try removed(pretty, ["keys", "a"])
        == pretty.replacingOccurrences(of: "    \"a\" : \"dock left\",\n", with: ""))
    #expect(
      try removed(pretty, ["keys", "b"]) == pretty.replacingOccurrences(of: ",\n    \"b\" : null", with: ""))
  }

  @Test func removesFromOneLineObjects() throws {
    let text = #"{"a": 1, "b": 2, "c": 3}"#
    #expect(try removed(text, ["a"]) == #"{"b": 2, "c": 3}"#)
    #expect(try removed(text, ["b"]) == #"{"a": 1, "c": 3}"#)
    #expect(try removed(text, ["c"]) == #"{"a": 1, "b": 2}"#)
  }

  @Test func removingTheOnlyKeyLeavesAnEmptyObject() throws {
    #expect(try removed("{\n  \"a\": 1\n}\n", ["a"]) == "{}\n")
    #expect(
      try removed("{\n  \"k\": {\n    \"a\": 1\n  },\n  \"z\": 1\n}", ["k", "a"])
        == "{\n  \"k\": {},\n  \"z\": 1\n}")
  }

  @Test func removingWhatIsNotThereChangesNothing() throws {
    #expect(try removed(pretty, ["missing"]) == pretty)
    #expect(try removed(pretty, ["gap", "deeper"]) == pretty)
    #expect(try removed(pretty, ["missing", "deeper"]) == pretty)
    #expect(throws: JSONText.EditError.self) { try JSONText(pretty).removing([]) }
  }

  @Test func aKeyWrittenTwiceIsRemovedTwice() throws {
    #expect(try removed(#"{"a": 1, "b": 2, "a": 3}"#, ["a"]) == #"{"b": 2}"#)
    #expect(try removed(#"{"a": 1, "a": 3}"#, ["a"]) == "{}")
  }
}

@Suite struct JSONTextSyntaxTests {
  /// The typos people make in a settings file, and where Arbor says they are.
  @Test(arguments: [
    ("", 1, 1, "the file is empty"),
    ("  \n ", 2, 2, "the file is empty"),
    ("{\n  \"gap\": 12,,\n}", 2, 13, "expected a key in quotes, found `,`"),
    ("{\n  \"a\": [1, 2,,]\n}", 2, 14, "expected a value, found `,`"),
    ("{,}", 1, 2, "expected a key in quotes, found `,`"),
    ("[,]", 1, 2, "expected a value, found `,`"),
    ("{\n  \"a\": 1\n  \"b\": 2\n}", 3, 3, "expected `,` or `}` after the value of `a`, found `\"`"),
    ("{\n  gap: 12\n}", 2, 3, "expected a key in quotes, found `gap`"),
    ("{\n  'gap': 12\n}", 2, 3, "expected a key in quotes, found `'` (JSON uses double quotes)"),
    ("{\n  // the gap\n  \"gap\": 12\n}", 2, 3, "expected a key in quotes, found `/` (JSON has no comments)"),
    ("{\"gap\" 12}", 1, 8, "expected `:` after the key `gap`, found `12`"),
    ("{\"on\": True}", 1, 8, "expected a value, found `True`"),
    ("{\"on\": tru}", 1, 8, "expected a value, found `tru`"),
    ("{\"a\": }", 1, 7, "expected a value, found `}`"),
    ("{\"a\": 1", 1, 8, "expected `,` or `}` after the value of `a`, found the end of the file"),
    ("{\"a\":", 1, 6, "expected a value, but the file ends here"),
    ("{", 1, 2, "expected a key in quotes, but the file ends here"),
    ("[1, 2", 1, 6, "expected `,` or `]` in the list, found the end of the file"),
    ("[1 2]", 1, 4, "expected `,` or `]` in the list, found `2`"),
    ("{\"a\": 1} x", 1, 10, "unexpected `x` after the end of the JSON"),
    ("{\"a\": 1}{}", 1, 9, "unexpected `{` after the end of the JSON"),
    ("{\"a\": \"text}", 1, 7, "the text starting here has no closing quote"),
    ("{\"a\": \"text,\n\"b\": 1}", 1, 7, "the text starting here has no closing quote on its line"),
    ("{\"a\": \"tab\there\"}", 1, 11, "a control character inside quotes; write it as an escape such as \\t"),
    ("{\"a\": \"C:\\path\"}", 1, 10, "unknown escape; write a backslash itself as \\\\"),
    ("{\"a\": \"\\u12\"}", 1, 8, "a \\u escape needs four hexadecimal digits"),
    ("{\"a\": \"\\ud83d\"}", 1, 8, "this \\u escape is half of a pair whose other half is missing"),
    ("{\"a\": \"\\ud83d\\u0041\"}", 1, 8, "this \\u escape is half of a pair whose other half is missing"),
    ("{\"a\": 012}", 1, 7, "a number cannot start with 0"),
    ("{\"a\": 1.}", 1, 7, "a number needs digits after its point"),
    ("{\"a\": .5}", 1, 7, "expected a value, found `.`"),
    ("{\"a\": 1e}", 1, 7, "a number needs digits after its exponent"),
    ("{\"a\": -}", 1, 7, "expected digits after `-`"),
    ("{\"a\": +1}", 1, 7, "expected a value, found `+`"),
    ("{\"a\": NaN}", 1, 7, "expected a value, found `NaN`"),
    ("{\n  \"é👍\": 1,\n  \"é👍é\" 2\n}", 3, 9, "expected `:` after the key `é👍é`, found `2`"),
  ]) func saysWhereATypoIs(text: String, line: Int, column: Int, problem: String) {
    #expect(throws: JSONText.SyntaxError(line: line, column: column, problem: problem)) {
      try JSONText(text, strict: true)
    }
  }

  @Test func describesItself() {
    #expect("\(JSONText.SyntaxError(line: 3, column: 1, problem: "oops"))" == "line 3, column 1: oops")
  }

  /// The limit is low because tests, unlike the app, parse on threads with little stack.
  @Test(arguments: [false, true]) func deepNestingIsRefusedNotACrash(strict: Bool) throws {
    func nested(_ depth: Int) -> String {
      String(repeating: "[", count: depth) + String(repeating: "]", count: depth)
    }
    #expect(try JSONText(nested(64), strict: strict).text.count == 128)
    #expect(throws: JSONText.SyntaxError.self) { try JSONText(nested(65), strict: strict) }
    #expect(throws: JSONText.SyntaxError.self) {
      try JSONText(String(repeating: "[", count: 100_000), strict: strict)
    }
    #expect(throws: JSONText.SyntaxError.self) {
      try JSONText(String(repeating: "{\"a\":", count: 100_000), strict: strict)
    }
  }

  /// With `strict`, what `JSONText` accepts is JSON, so Foundation accepts it too.
  @Test func strictlyAcceptsNothingThatFoundationRefuses() {
    let valid = [
      "{}", "[]", #"{"a":1}"#, "[1,2,3]", #"["\u00e9\ud83d\udc4d\n\"\\\/"]"#,
      "[-0, 0.5, 1e5, 1E-5, -1.5e+10, 123456789012]",
      "[true,false,null]", " \t\r\n[ \t\r\n] \t\r\n", #"{"a":{"b":{"c":[{"d":[]}]}}}"#, #"{"":""}"#,
      #"{"a":1,"a":2}"#,
    ]
    let invalid = [
      "", "{", "}", "[", "]", "{,}", #"{"a"}"#, #"{"a":}"#, "[1 2]", "[01]", "[1.]", "[.1]", "[+1]",
      "[1e]", "[-]", "[tru]", "[nul]", "[True]", "['a']", #"["a]"#, #"["\x"]"#, #"["\u12"]"#, "[1]]", "[1] 2",
      "{1:2}",
      "[\"a\nb\"]", "// c\n[]", "[1,,2]", "[,1]", "nope",
    ]
    func foundationAccepts(_ text: String) -> Bool {
      (try? JSONSerialization.jsonObject(with: Data(text.utf8), options: [.fragmentsAllowed])) != nil
    }
    for text in valid {
      #expect((try? JSONText(text, strict: true)) != nil, "\(text)")
      #expect((try? JSONText(text)) != nil, "\(text)")
      #expect(foundationAccepts(text), "\(text)")
    }
    for text in invalid {
      #expect((try? JSONText(text, strict: true)) == nil, "\(text)")
    }
  }

  /// A broken structure cannot be edited, strict or not.
  @Test(arguments: [
    "", "{", "}", "[", "]", "{,}", #"{"a"}"#, #"{"a":}"#, "[1 2]", #"["a]"#, "[1]]", "[1] 2", "{1:2}",
    "[1,,2]", "[,1]",
    "[,]", "{,}", #"{"a":1,,}"#, #"{"a" 1}"#, #"{"a":1 "b":2}"#, #"{"a":"x\"}"#, "{\"a\":1}}", "// c\n[]",
  ]) func aBrokenStructureIsAlwaysRefused(text: String) {
    #expect(throws: JSONText.SyntaxError.self) { try JSONText(text) }
  }
}

/// `JSONDecoder` allows a comma after the last entry, and never looks at values nobody decodes. A file
/// it can read has to be a file Arbor can change.
@Suite struct JSONTextLenientTests {
  /// What the rest of this suite rests on, checked on every platform the tests run on.
  @Test func jsonDecoderAllowsACommaAfterTheLastEntry() throws {
    #expect(try JSONDecoder().decode([Int].self, from: Data("[1, 2,]".utf8)) == [1, 2])
    #expect(try JSONDecoder().decode([String: [Int]].self, from: Data(#"{"a": [1,],}"#.utf8)) == ["a": [1]])
    for text in ["[1, 2,]", #"{"a": [1,],}"#] {
      #expect(try JSONText(text, strict: true).text == text)
    }
  }

  @Test func aCommaAfterTheLastEntryIsKept() throws {
    let text = "{\n  \"a\": 1,\n  \"list\": [\n    1,\n    2,\n  ],\n  \"keys\": {\"x\": 1,},\n}\n"
    let document = try JSONText(text)
    #expect(document.keys(at: []) == ["a", "list", "keys"])
    #expect(document.elements(at: ["list"]) == ["1", "2"])
    #expect(
      try document.setting(["a"], to: "2").text == text.replacingOccurrences(of: "\"a\": 1", with: "\"a\": 2")
    )
    #expect(
      try document.setting(["b"], to: "3").text
        == text.replacingOccurrences(of: "{\"x\": 1,},\n", with: "{\"x\": 1,},\n  \"b\": 3,\n"))
    #expect(
      try document.setting(["keys", "y"], to: "2").text
        == text.replacingOccurrences(of: "{\"x\": 1,}", with: "{\"x\": 1, \"y\": 2,}"))
    #expect(
      try document.removing(["keys"]).text
        == text.replacingOccurrences(of: ",\n  \"keys\": {\"x\": 1,}", with: ""))
    #expect(
      try document.removing(["keys", "x"]).text == text.replacingOccurrences(of: "{\"x\": 1,}", with: "{}"))
    #expect(try document.removing(["a"]).text == text.replacingOccurrences(of: "  \"a\": 1,\n", with: ""))
  }

  @Test func whatItIsNotAskedToChangeItDoesNotJudge() throws {
    let text =
      #"{"path": "C:\path", "number": 01, "word": tru, "tab": "a\#tb", "u": "\u12", "half": "\ud83d", "gap": 1}"#
    #expect(throws: JSONText.SyntaxError.self) { try JSONText(text, strict: true) }
    let document = try JSONText(text)
    #expect(document.value(at: ["path"]) == #""C:\path""# && document.value(at: ["number"]) == "01")
    #expect(
      try document.setting(["gap"], to: "2").text
        == text.replacingOccurrences(of: #""gap": 1"#, with: #""gap": 2"#))
    #expect(
      try document.removing(["word"]).text == text.replacingOccurrences(of: #""word": tru, "#, with: ""))
  }

  @Test func aKeyWithABadEscapeIsKnownAsWritten() throws {
    let document = try JSONText(#"{"a\qb": 1, "ok": 2}"#)
    #expect(document.keys(at: []) == [#"a\qb"#, "ok"])
    #expect(try document.setting(["ok"], to: "3").text == #"{"a\qb": 1, "ok": 3}"#)
  }

  @Test func anEscapedQuoteDoesNotEndAString() throws {
    let document = try JSONText(#"{"a": "x\"y, {", "b\\": "\\", "c": 1}"#)
    #expect(document.keys(at: []) == ["a", "b\\", "c"])
    #expect(document.value(at: ["a"]) == #""x\"y, {""#)
  }
}

/// Random documents in random layouts, changed at random: the result always means what it should,
/// and what was not touched is still there byte for byte.
@Suite struct JSONTextRandomTests {
  struct Writer {
    var random: SeededRandom
    let newline: String
    let unit: String
    let colon: String

    init(seed: UInt64) {
      random = SeededRandom(seed: seed)
      newline = ["\n", "\r\n"][Int.random(in: 0..<2, using: &random)]
      unit = ["  ", "    ", "\t", " ", ""][Int.random(in: 0..<5, using: &random)]
      colon = [": ", " : ", ":", " :\t"][Int.random(in: 0..<4, using: &random)]
    }

    mutating func pick<T>(_ options: [T]) -> T { options[Int.random(in: 0..<options.count, using: &random)] }

    mutating func key() -> String {
      pick([
        "gap", "rules", "a", "b", "c", "key with spaces", "é👍", "quo\"te", "back\\slash", "", "ctrl+opt+/",
        "x1", "x2", "x3",
      ])
    }

    mutating func scalar() -> String {
      pick([
        "1", "-2.50", "1e3", "0", "true", "false", "null", #""""#, #""text""#,
        #""é👍 \n \u00e9 \" \\ {[,:]}""#, "12345678901234567890",
      ])
    }

    /// A value in a layout of its own: on one line, or one child to a line.
    mutating func value(depth: Int, indent: String) -> String {
      let kind = depth >= 3 ? 0 : Int.random(in: 0..<4, using: &random)
      guard kind >= 2 else { return scalar() }
      let count = Int.random(in: 0..<4, using: &random)
      let inline = Bool.random(using: &random)
      let inner = indent + unit
      var used = Set<String>()
      var parts: [String] = []
      for _ in 0..<count {
        let child = value(depth: depth + 1, indent: inline ? indent : inner)
        if kind == 2 {
          parts.append(child)
        } else {
          let name = key()
          if used.insert(name).inserted { parts.append(JSONText.quote(name) + colon + child) }
        }
      }
      let (open, close) = kind == 2 ? ("[", "]") : ("{", "}")
      if parts.isEmpty { return open + pick(["", " ", newline + indent]) + close }
      let last = pick(["", "", ","])
      if inline { return open + parts.joined(separator: pick([",", ", "])) + last + close }
      return open + newline + parts.map { inner + $0 }.joined(separator: "," + newline) + last + newline
        + indent + close
    }

    mutating func document() -> String {
      var used = Set<String>()
      var parts: [String] = []
      let inline = Int.random(in: 0..<4, using: &random) == 0
      for _ in 0..<Int.random(in: 0..<7, using: &random) {
        let name = key()
        if used.insert(name).inserted {
          parts.append(JSONText.quote(name) + colon + value(depth: 1, indent: inline ? "" : unit))
        }
      }
      let end = pick(["", newline, newline + newline])
      if parts.isEmpty { return "{}" + end }
      let last = pick(["", "", ","])
      if inline { return "{" + parts.joined(separator: ", ") + last + "}" + end }
      return "{" + newline + parts.map { unit + $0 }.joined(separator: "," + newline) + last + newline + "}"
        + end
    }
  }

  /// What `JSONDecoder` makes of a text, commas after last entries included.
  indirect enum Value: Decodable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([Value])
    case object([String: Value])

    init(from decoder: any Decoder) throws {
      let container = try decoder.singleValueContainer()
      if container.decodeNil() {
        self = .null
      } else if let value = try? container.decode(Bool.self) {
        self = .bool(value)
      } else if let value = try? container.decode(Double.self) {
        self = .number(value)
      } else if let value = try? container.decode(String.self) {
        self = .string(value)
      } else if let value = try? container.decode([Value].self) {
        self = .array(value)
      } else {
        self = .object(try container.decode([String: Value].self))
      }
    }
  }

  func meaning(_ text: String) throws -> Value { try JSONDecoder().decode(Value.self, from: Data(text.utf8)) }

  @Test(arguments: [UInt64](1...60)) func randomChangesMeanWhatTheyShouldAndTouchNothingElse(seed: UInt64)
    throws
  {
    var writer = Writer(seed: seed)
    var document = try JSONText(writer.document())
    for _ in 0..<25 {
      let before = document
      guard case .object(var expected) = try meaning(before.text) else { return }
      let key = writer.key()
      if Int.random(in: 0..<3, using: &writer.random) == 0 {
        document = try document.removing([key])
        expected[key] = nil
      } else {
        let value = writer.value(depth: 1, indent: "")
        document = try document.setting([key], to: value)
        expected[key] = try meaning(value)
      }
      #expect(try meaning(document.text) == .object(expected), "\(before.text)\n→ \(key) →\n\(document.text)")
      for other in before.keys(at: []) ?? [] where other != key {
        #expect(document.value(at: [other]) == before.value(at: [other]), "\(other) in\n\(document.text)")
      }
      #expect(
        (document.keys(at: []) ?? []).filter { $0 != key } == (before.keys(at: []) ?? []).filter { $0 != key }
      )
    }
  }
}
