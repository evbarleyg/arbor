import ArborCore
import ArborKit
import ArborTesting
import Foundation
import Testing

/// The census: Arbor's keys held against the menu bars of the apps on a hosted Mac (collab/evidence/menu-keys; docs/KEYBOARD.md has the table;
/// collab/IDEAS.md, I16 and I25 d). So that a default that an app also uses is found here, before a person meets it.
@Suite @MainActor struct MenuKeyCensusTests {
  typealias Press = MenuShortcut.Press

  static let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("collab/evidence/menu-keys")
  /// GitHub's Macs have a US keyboard selected, so that is where the characters in the files are typed.
  static let layout = SampleKeyLayouts.us

  struct Malformed: Error { let file: String, line: String }

  /// One for each file: a line is modifiers, the character's scalars in hex or `-`, the virtual key or `-`. A line that is anything else fails
  /// the test that reads it: left out in silence it would be a shortcut nobody holds anything against.
  static func readings() throws -> [MenuBarReading] {
    try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil).filter { $0.pathExtension == "tsv" }
      .sorted { $0.path < $1.path }
      .map { file in
        let name = file.deletingPathExtension().lastPathComponent
        let shortcuts = try String(contentsOf: file, encoding: .utf8).split(separator: "\n").map { line -> MenuShortcut in
          let fields = line.split(separator: "\t").map(String.init)
          let scalars = fields.count == 3 ? fields[1].split(separator: ",").map { UInt32($0, radix: 16).flatMap(Unicode.Scalar.init) } : []
          guard fields.count == 3, let modifiers = Int(fields[0]), fields[1] == "-" || !scalars.contains(where: { $0 == nil }),
            fields[2] == "-" || Int(fields[2]) != nil
          else { throw Malformed(file: name, line: String(line)) }
          return MenuShortcut(
            modifiers: modifiers, character: fields[1] == "-" ? nil : String(String.UnicodeScalarView(scalars.compactMap { $0 })),
            virtualKey: Int(fields[2]))
        }
        return MenuBarReading(app: name, shortcuts: shortcuts)
      }
  }

  /// Every shortcut Arbor has without a person making it. The map that ships is about to shrink to nine keys, with the rest to be switched on by a
  /// setting: until there is one this is refused, and the map that ships is the whole.
  static var map: [KeyBinding] {
    let h = Harness()
    h.run("set shortcuts all")
    return h.controller.effectiveBindings.bindings
  }

  struct Clash: Hashable, CustomStringConvertible {
    let chord: String, app: String
    var description: String { "\(chord) \(app)" }
  }

  static func clashes(of bindings: [KeyBinding], with readings: [MenuBarReading]) -> Set<Clash> {
    Set(
      readings.flatMap { reading in
        let presses = reading.presses(on: layout)
        return bindings.filter { presses.contains(Press(keyCode: $0.keyCode, modifiers: $0.modifiers)) }
          .map { Clash(chord: $0.chord.text, app: reading.app) }
      })
  }

  /// As many as docs/KEYBOARD.md says. Every other test here would pass on an empty folder.
  @Test func theCensusIsThere() throws {
    let readings = try Self.readings()
    #expect(readings.count == 82)
    // An app goes on building its menu bar after it has one, and a file from a reading that came too early would be held against next to nothing. One
    // chat app's really is that short at the window it shows without an account: six shortcuts in each of two runs.
    #expect(readings.filter { $0.shortcuts.count < 20 }.map(\.app) == ["com.hnc.Discord"])
  }

  /// A row that comes out as no press is held against nothing.
  @Test func everyRowIsAPress() throws {
    for reading in try Self.readings() {
      let lost = reading.shortcuts.filter { $0.press(on: Self.layout) == nil }
      #expect(lost.isEmpty, "\(reading.app): \(lost)")
    }
  }

  /// The core of the map: ⌃⌥ and one key. None of them is in any menu bar that was read.
  @Test func noKeyOnControlOptionAndOneKeyIsInAnyMenuBar() throws {
    let core = Self.map.filter { $0.modifiers == [.control, .option] }
    #expect(!core.isEmpty)
    #expect(Self.clashes(of: core, with: try Self.readings()) == [])
  }

  /// docs/KEYBOARD.md's table.
  static let table: Set<Clash> = [
    Clash(chord: "ctrl+opt+cmd+left", app: "com.apple.dt.Xcode"), Clash(chord: "ctrl+opt+cmd+right", app: "com.apple.dt.Xcode"),
  ]

  /// Whoever adds a default that an app has too hears of it here, and either chooses another key or writes the clash into docs/KEYBOARD.md and the
  /// table above. Held both ways: a row of the table that is no longer found, while Arbor still has the key, fails as well.
  @Test func theWholeMapClashesWhereTheTableSaysSoAndNowhereElse() throws {
    let map = Self.map
    #expect(!map.isEmpty)
    #expect(Self.clashes(of: map, with: try Self.readings()) == Self.table.filter { row in map.contains { $0.chord.text == row.chord } })
  }

  /// That the comparison finds anything at all, on real rows and whatever becomes of Arbor's map: these keys are in that app's menu bar.
  @Test func aKeyThatARealAppHasIsFound() throws {
    let asked = [
      KeyBinding([.control, .option, .command], .left, .showAll), KeyBinding([.control, .option], .semicolon, .showAll),
      KeyBinding([.control, .option, .shift], .semicolon, .showAll), KeyBinding([.control, .option], .tab, .showAll),
    ]
    #expect(
      Self.clashes(of: asked, with: try Self.readings()) == [
        Clash(chord: "ctrl+opt+cmd+left", app: "com.apple.dt.Xcode"), Clash(chord: "ctrl+opt+;", app: "com.apple.dt.Xcode"),
        Clash(chord: "ctrl+opt+shift+;", app: "com.apple.dt.Xcode"), Clash(chord: "ctrl+opt+tab", app: "com.sublimetext.4"),
      ])
    // Every key of Arbor's holds ⌃ and ⌥ both, so the rows above would not notice the two exchanged. Force Quit, in the Apple menu, is ⌥⌘⎋.
    #expect(Self.clashes(of: [KeyBinding([.option, .command], .escape, .showAll)], with: try Self.readings()).count == 82)
    #expect(Self.clashes(of: [KeyBinding([.control, .command], .escape, .showAll)], with: try Self.readings()) == [])
  }

  /// What the census is for, tried on the fault it was built after: ⌃⌥A ran `arrange` in the first build, and an app had the same keys. The app here is
  /// made up: no app that was read has them in a menu, at the window it shows without an account.
  @Test func theKeyOfTheFirstBuildIsFoundInAnAppThatHasIt() throws {
    let old = [KeyBinding([.control, .option], .a, .arrange)]
    let chat = MenuBarReading(
      app: "com.example.chat", shortcuts: [MenuShortcut(modifiers: 0, character: "Q"), MenuShortcut(modifiers: 14, character: "A")])
    #expect(Self.clashes(of: old, with: [chat]) == [Clash(chord: "ctrl+opt+a", app: "com.example.chat")])
    #expect(Self.clashes(of: old, with: try Self.readings()) == [], "docs/KEYBOARD.md says that none of the apps read has it in a menu")
  }

  /// On Apple's keyboards fn makes another key of ←, →, ↑, ↓ and ↩, and fn sits beside ⌃: a finger resting on it turns ⌃⌥← into ⌃⌥Home, which Arbor does not
  /// hold and will not (the product owner: no five more keys taken on a guess). So what becomes of each of Arbor's keys on those five is looked
  /// for here instead, written either way: by the other key's code, or, as macOS writes its own Move & Resize, with the Globe key among the
  /// modifiers and the arrow's own code.
  @Test func whatAFingerOnFnMakesOfArborsKeysIsWhereTheTableSaysSoAndNowhereElse() throws {
    let made: [UInt32: UInt32] = [123: 115, 124: 119, 126: 116, 125: 121, 36: 76]  // Home, End, Page Up, Page Down, Enter
    let map = Self.map.filter { made[$0.keyCode] != nil }
    #expect(!map.isEmpty)
    var found: [String: Int] = [:]
    for reading in try Self.readings() {
      let (plain, withFn) = (reading.presses(on: Self.layout), reading.presses(on: Self.layout, withFn: true))
      for binding in map
      where plain.contains(Press(keyCode: made[binding.keyCode]!, modifiers: binding.modifiers))
        || withFn.contains(Press(keyCode: binding.keyCode, modifiers: binding.modifiers))
      { found[binding.chord.text, default: 0] += 1 }
    }
    // macOS's own Window → Move & Resize → … & Quarters, in every menu bar but one.
    let table = ["ctrl+opt+shift+left": 81, "ctrl+opt+shift+right": 81, "ctrl+opt+shift+up": 81, "ctrl+opt+shift+down": 81]
    #expect(found == table.filter { row in map.contains { $0.chord.text == row.key } })
  }

  /// Both sides mean the same by a key: each of Arbor's own, written as a menu would hold it, is that very press.
  @Test func everyKeyOfArborsWrittenAsAMenuItemIsItself() {
    for binding in Self.map {
      #expect(
        MenuShortcut(showing: binding.chord).press(on: Self.layout) == Press(keyCode: binding.keyCode, modifiers: binding.modifiers),
        "\(binding.chord.text)")
    }
  }
}
