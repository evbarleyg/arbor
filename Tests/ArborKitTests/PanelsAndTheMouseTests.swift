import Foundation
import Testing

#if os(macOS)
  import AppKit

  @testable import ArborKit
#endif

/// Drags must never block input (collab/QUESTIONS.md, Q17): the drop preview is a panel that ignores the mouse, and no layer that can
/// cover a display may take a press or a release. A panel that took the release of a drag would leave the window in the hand
/// for ever, and one left on screen would make the Mac look dead.
///
/// Whether a panel takes the mouse, and how high it lies, are two lines in its source, which no test on Linux can run. So the
/// sources are read, and held against the one table of Arbor's panels, in docs/ARCHITECTURE.md ("Arbor's panels and the mouse").
@Suite struct PanelsAndTheMouseTests {
  private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()

  struct Row: Equatable {
    var level: String
    /// "no", "yes" or "when asked".
    var mouse: String
  }

  /// Classes others are made from, which are never on screen themselves.
  static let bases: Set<String> = ["OverlayPanel", "PassingPanel"]
  /// What is no class of its own: made by `AppKitOverlays.makePreviewPanel()`.
  static let preview = "the drop preview"

  /// Ordinary windows with a title bar, which a person opens and closes. They take the mouse as any window does. Every line that sets the
  /// level of one, word for word; the section's second table says why.
  static let ordinaryWindows: [String: [String]] = [
    "Sources/ArborKit/UI/Onboarding.swift": ["window.level = model.page == .firstSteps ? .floating : .normal"],
    "Sources/ArborKit/UI/SettingsWindow.swift": ["window?.level = .floating", "window?.level = .normal"],
    "Sources/ArborKit/UI/UpdateWindow.swift": ["window.level = .floating"],
  ]
  /// Where a window is made that is no class of Arbor's own. (The update window is an alert of macOS's.)
  static let bareWindows: Set<String> = ["Sources/ArborKit/UI/SettingsWindow.swift"]

  // MARK: The table

  private static func table() throws -> [String: Row] {
    var rows: [String: Row] = [:]
    let text = try String(contentsOf: root.appendingPathComponent("docs/ARCHITECTURE.md"), encoding: .utf8)
    let start = try #require(text.range(of: "### Arbor's panels and the mouse"))
    for line in text[start.upperBound...].components(separatedBy: "\n") {
      if line.hasPrefix("## ") { break }
      let cells = line.split(separator: "|", omittingEmptySubsequences: false).map { $0.trimmingCharacters(in: .whitespaces) }
      guard cells.count == 6, cells[1] != "Panel", !cells[1].hasPrefix("---") else { continue }
      #expect(!cells[4].isEmpty, "\(cells[1]) has no reason")
      rows[cells[1].trimmingCharacters(in: CharacterSet(charactersIn: "`"))] = Row(level: cells[2], mouse: cells[3])
    }
    return rows
  }

  // MARK: The sources

  /// A line of Arbor's sources, and in whose braces it stands: a class declared at the top level, or `preview`.
  struct Line {
    var path: String
    var number: Int
    var text: String
    var owner: String?
    var place: String { "\(path):\(number)" }
  }

  struct Sources {
    var lines: [Line] = []
    /// What every class declared at the top level is made from.
    var parents: [String: String] = [:]

    /// Made from `NSPanel` or `NSWindow`, directly or not.
    func isWindow(_ name: String) -> Bool {
      var name = name
      while let parent = parents[name] {
        if parent == "NSPanel" || parent == "NSWindow" { return true }
        name = parent
      }
      return false
    }

    func body(of owner: String) -> [String] { lines.filter { $0.owner == owner }.map(\.text) }
  }

  /// Everything the app is made of, not only the folders where the panels are today. Read once: it is a hundred and fifty files.
  private static let sources = Result { try readSources() }

  private static func readSources() throws -> Sources {
    var sources = Sources()
    var paths: [String] = []
    for folder in ["Sources/ArborKit", "Sources/Arbor"] {
      let files = try #require(FileManager.default.enumerator(atPath: root.appendingPathComponent(folder).path))
      paths += files.compactMap { $0 as? String }.filter { $0.hasSuffix(".swift") }.map { "\(folder)/\($0)" }
    }
    for path in paths.sorted() {
      var owner: String?
      var outer: String?
      let text = try String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
      for (index, line) in text.components(separatedBy: "\n").enumerated() {
        // Declarations in the first column, which is where all of them are (the net below sees to that): the body ends at the next `}` there.
        if line.contains("class "),
          let match = line.firstMatch(of: /^(?:@\w+ )*(?:private |fileprivate |public |open )?(?:final )?class (\w+)\s*:\s*(\w+)/)
        {
          owner = String(match.1)
          sources.parents[String(match.1)] = String(match.2)
        } else if line.hasPrefix("}") {
          owner = nil
        } else if line == "  func makePreviewPanel() -> OverlayPanel {" {
          (outer, owner) = (owner, preview)
        } else if owner == preview, line == "  }" {
          owner = outer
        }
        sources.lines.append(Line(path: path, number: index + 1, text: line, owner: owner))
      }
    }
    return sources
  }

  private static func isComment(_ line: String) -> Bool { line.trimmingCharacters(in: .whitespaces).hasPrefix("//") }

  /// What a line gives `ignoresMouseEvents`, if it does.
  private static func mouseAnswer(in line: String) -> String? {
    guard line.contains("ignoresMouseEvents"), !isComment(line) else { return nil }
    return line.firstMatch(of: /ignoresMouseEvents = (.+)/).map { String($0.1).trimmingCharacters(in: .whitespaces) }
  }

  /// What a line gives a window's `level`, if it does. `let level = holdLevel` is another word.
  private static func levelAnswer(in line: String) -> String? {
    guard line.contains("level = "), !isComment(line), !line.contains("let level = "), !line.contains("var level = ") else { return nil }
    return line.firstMatch(of: /(?:^|[\s.])level = (.+)/).map { String($0.1).trimmingCharacters(in: .whitespaces) }
  }

  /// "no" if it never says anything but that it ignores the mouse, "when asked" if something decides, otherwise "yes".
  private static func mouse(_ answers: [String]) -> String {
    if answers.isEmpty { return "does not say" }
    if answers.allSatisfy({ $0 == "true" }) { return "no" }
    return answers.contains { $0 != "true" && $0 != "false" } ? "when asked" : "yes"
  }

  /// A level in the table's words. `above`: its parent's, for one that counts from there or sets none.
  private static func level(_ text: String?, above parent: String?) -> String? {
    guard let text else { return parent }
    func plus(_ base: String, _ more: Int) -> String {
      let parts = base.components(separatedBy: " + ")
      let sum = (parts.count == 2 ? Int(parts[1]) ?? 0 : 0) + more
      return sum == 0 ? parts[0] : "\(parts[0]) + \(sum)"
    }
    switch text {
    case ".normal": return "normal"
    case ".floating": return "floating"
    case ".modalPanel": return "modal panel"
    default: break
    }
    if let more = text.firstMatch(of: /^NSWindow\.Level\(rawValue: NSWindow\.Level\.floating\.rawValue \+ (\d+)\)$/) {
      return plus("floating", Int(more.1) ?? 0)
    }
    if let more = text.firstMatch(of: /^NSWindow\.Level\(rawValue: level\.rawValue \+ (\d+)\)$/), let parent {
      return plus(parent, Int(more.1) ?? 0)
    }
    if let more = text.firstMatch(of: /^NSWindow\.Level\(rawValue: Int\(CGWindowLevelForKey\(\.desktopIconWindow\)\) \+ (\d+)\)$/) {
      return plus("desktop icons", Int(more.1) ?? 0)
    }
    return "? " + text
  }

  /// What the sources say, in the table's words.
  private static let written = Result { () throws -> [String: Row] in
    let sources = try Self.sources.get()
    func inherited(_ name: String) -> String? {
      guard sources.parents[name] != nil || name == preview else { return nil }
      // The one it sets: the net below allows no second.
      return level(sources.body(of: name).compactMap(levelAnswer).first, above: sources.parents[name].flatMap(inherited))
    }
    var rows: [String: Row] = [:]
    // The welcome window is an ordinary window that happens to be a panel.
    for name in sources.parents.keys + [preview] where (sources.isWindow(name) || name == preview) && !bases.contains(name) && name != "WelcomeWindow" {
      rows[name] = Row(level: inherited(name) ?? "none", mouse: mouse(sources.body(of: name).compactMap(mouseAnswer)))
    }
    return rows
  }

  // MARK: The checks

  @Test func everyPanelIsInTheTableAsItIsWritten() throws {
    let (table, written) = (try Self.table(), try Self.written.get())
    #expect(written.count >= 13, "the sources were read: \(written.keys.sorted())")
    for (name, row) in written.sorted(by: { $0.key < $1.key }) {
      let listed = table[name]
      #expect(
        listed != nil,
        "\(name) is not in the table of Arbor's panels (docs/ARCHITECTURE.md). What is only looked at, or can cover a display, ignores the mouse")
      if let listed { #expect(listed == row, "\(name): the table says \(listed), the source \(row)") }
    }
    for name in table.keys { #expect(written[name] != nil, "\(name) is in the table and nowhere else") }
  }

  /// Whatever the table comes to say: these can lie under the pointer of a drag, or cover a display.
  @Test(arguments: [preview, "StagePanel", "BackdropPanel", "RubberBandPanel", "FocusRingPanel", "HeadsUpPanel"])
  func whatIsOnlyLookedAtIgnoresTheMouse(name: String) throws {
    #expect(try Self.written.get()[name]?.mouse == "no")
    #expect(try Self.table()[name]?.mouse == "no")
  }

  /// The reading above sees what stands in a panel's own braces. So that is where all of it has to stand: nobody changes a panel's mind from
  /// outside or later (an extension, another class, `showDropPreview` on the panel it has just made), and no window comes about that the
  /// reading cannot see (nested, or a bare `NSWindow`).
  @Test func nothingIsSaidOfAPanelOutsideItsOwnBraces() throws {
    let sources = try Self.sources.get()
    var strays: [String] = []
    var levels: [String: Int] = [:]
    var ordinary = Self.ordinaryWindows
    for line in sources.lines where !Self.isComment(line.text) {
      let isAPanels = line.owner.map { $0 == Self.preview || sources.isWindow($0) } ?? false
      if line.text.contains("ignoresMouseEvents") {
        if !isAPanels {
          strays.append("\(line.place) speaks of the mouse outside the braces of the panel it speaks of")
        } else if line.owner != Self.preview, line.text.contains(".ignoresMouseEvents") {
          strays.append("\(line.place) speaks of another panel's mouse")
        }
      }
      if Self.levelAnswer(in: line.text) != nil {
        let words = line.text.trimmingCharacters(in: .whitespaces)
        if isAPanels, let owner = line.owner {
          levels[owner, default: 0] += 1
        } else if let index = ordinary[line.path]?.firstIndex(of: words) {
          ordinary[line.path]?.remove(at: index)
        } else {
          strays.append("\(line.place) sets a window's level outside the braces of a panel")
        }
      }
      if line.text.contains("Panel(") || line.text.contains("NSWindow("),
        line.text.firstMatch(of: /\b(?:NSPanel|NSWindow|OverlayPanel|PassingPanel)\(/) != nil,
        line.owner != Self.preview, !Self.bareWindows.contains(line.path)
      {
        strays.append("\(line.place) makes a window that is no class of its own")
      }
      if line.text.contains("class "), let match = line.text.firstMatch(of: /\bclass (\w+)\s*:\s*(\w+)/), sources.parents[String(match.1)] == nil,
        ["NSPanel", "NSWindow"].contains(String(match.2)) || sources.isWindow(String(match.2))
      {
        strays.append("\(line.place) declares a window where this test cannot read it: put it in the first column")
      }
    }
    for (owner, count) in levels where count > 1 { strays.append("\(owner) sets its level \(count) times; the table has room for one") }
    for (path, lines) in ordinary { for line in lines { strays.append("\(path) no longer says `\(line)`: see `ordinaryWindows`") } }
    #expect(strays.isEmpty, "\(strays.sorted().joined(separator: "\n"))\nSee \"Arbor's panels and the mouse\" in docs/ARCHITECTURE.md")
  }

  #if os(macOS)
    /// The same asked of the panels themselves, as AppKit has them. None is shown: the window server hears of a panel when it is
    /// first put on screen.
    @MainActor @Test func thePanelsThemselvesSayTheSame() {
      let panels: [(String, NSPanel)] = [
        (Self.preview, AppKitOverlays().makePreviewPanel()), ("BackdropPanel", BackdropPanel()), ("FocusRingPanel", FocusRingPanel()),
        ("HeadsUpPanel", HeadsUpPanel()), ("RubberBandPanel", RubberBandPanel()),
      ]
      for (name, panel) in panels {
        #expect(panel.ignoresMouseEvents, "\(name)")
        #expect(!panel.canBecomeKey && !panel.canBecomeMain, "\(name) must not take the keyboard either")
        #expect(panel.styleMask.contains(.nonactivatingPanel), "\(name)")
        #expect(!panel.isVisible, "\(name)")
      }
    }
  #endif
}
