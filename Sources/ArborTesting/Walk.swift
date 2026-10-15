import ArborCore
import Foundation

// Walks for a hosted Mac (docs/VIABLE.md, ring 3; docs/TESTING.md, "Walks for a hosted Mac").
//
// On Linux the chaos lab plays random walks against stand-ins. On a hosted Mac scripts/mac-shell/lib-walk.sh plays a journey against real apps, one word
// for each thing a person does. These files write seeded walks in those words and play the same file against the stand-ins, so that one seed is one journey
// in both places, judged by the same rules: where the two differ, either a stand-in lies or a Mac shows a fault that Linux cannot.
//
//   Walk.swift         the words, their text form, and a walk as a file
//   RealApps.swift     the cast
//   WalkPlayer*.swift  plays a word on a `ChaosRunner`: whether it applies, what the person does, what it may move
//   WalkSamples.swift  writes down what the screen showed, in the grammar of scripts/mac-shell/sampler.swift, for scripts/mac-shell/jolts.py to judge
//   WalkWriter.swift   which word comes next
//
// The contract is lib-walk.sh's header. `WalkTests` reads it: a word that is added there and not here turns a test red.

/// One line of a walk: one thing a person does, in lib-walk.sh's words. Apps go by the names of the cast and never by a title.
public enum WalkWord: Equatable, Sendable, CustomStringConvertible {
  public enum Arrow: String, CaseIterable, Sendable { case left, right, up, down }
  public enum Part: String, CaseIterable, Sendable { case left, right, top, bottom }
  /// The edges of a display at which macOS tiles.
  public enum ScreenEdge: String, CaseIterable, Sendable { case left, right, top }
  public enum View: String, CaseIterable, Sendable { case frame, out, `in`, left, right, back, forward, all, home, desktop }
  public enum Size: String, CaseIterable, Sendable { case grow, shrink, balance }
  public enum DisplayChange: String, CaseIterable, Sendable { case plug, unplug, left, right, smaller, larger }

  case switchDock(String), switchClick(String), switchTo(String), switchCmdTab(Int), switchBacktick, switchMenu(String)
  case tileClick(Int), focusKey(Arrow), summon(String)
  case openNew, closeNew, minimize, restore(String?), hide, unhide(String?), quitApp(String), reopen(String)
  case dockKey(Arrow), floatKey, arrangeKey, undo, redo, rotate, mirror, pin
  case dragOnto(String, String, Part), dragOut(String), dragBy(String, Int, Int, click: Bool), dragEdge(String, ScreenEdge)
  case view(View), peek, saveView(Int), viewN(Int)
  case resizeGap(String, Int), resizeKey(Size), resizeEdge(String, Part, Int)
  case fullScreen(Bool), wallpaperClick, titleDoubleClick(String)
  case pause, resume, floatAll, floatAllHere, holdView, releaseView
  case display(DisplayChange), sendAcross, moveToDisplay
  case quitAndStart, idleAct
  case chapter(String)

  public var description: String { text }

  /// The function of lib-walk.sh's that plays it.
  public var name: String { String(text.prefix { $0 != " " }) }

  public var text: String {
    switch self {
    case .switchDock(let app): "switch_dock \(app)"
    case .switchClick(let app): "switch_click \(app)"
    case .switchTo(let app): "switch_to \(app)"
    case .switchCmdTab(let times): "switch_cmdtab \(times)"
    case .switchBacktick: "switch_backtick"
    case .switchMenu(let app): "switch_menu \(app)"
    case .tileClick(let index): "tile_click \(index)"
    case .focusKey(let arrow): "focus_key \(arrow.rawValue)"
    case .summon(let app): "summon \(app)"
    case .openNew: "open_new"
    case .closeNew: "close_new"
    case .minimize: "minimize"
    case .restore(let app): app.map { "restore \($0)" } ?? "restore"
    case .hide: "hide"
    case .unhide(let app): app.map { "unhide \($0)" } ?? "unhide"
    case .quitApp(let app): "quit_app \(app)"
    case .reopen(let app): "reopen \(app)"
    case .dockKey(let arrow): "dock_key \(arrow.rawValue)"
    case .floatKey: "float_key"
    case .arrangeKey: "arrange_key"
    case .undo: "undo"
    case .redo: "redo"
    case .rotate: "rotate"
    case .mirror: "mirror"
    case .pin: "pin"
    case .dragOnto(let app, let other, let part): "drag_onto \(app) \(other) \(part.rawValue)"
    case .dragOut(let app): "drag_out \(app)"
    case .dragBy(let app, let across, let down, let click): "drag_by \(app) \(across) \(down)" + (click ? " click" : "")
    case .dragEdge(let app, let edge): "drag_edge \(app) \(edge.rawValue)"
    case .view(let move): "view \(move.rawValue)"
    case .peek: "peek"
    case .saveView(let number): "save_view \(number)"
    case .viewN(let number): "view_n \(number)"
    case .resizeGap(let app, let points): "resize_gap \(app) \(points)"
    case .resizeKey(let size): "resize_key \(size.rawValue)"
    case .resizeEdge(let app, let part, let points): "resize_edge \(app) \(part.rawValue) \(points)"
    case .fullScreen(let on): "full_screen \(on ? "on" : "off")"
    case .wallpaperClick: "wallpaper_click"
    case .titleDoubleClick(let app): "title_double_click \(app)"
    case .pause: "pause"
    case .resume: "resume"
    case .floatAll: "float_all"
    case .floatAllHere: "float_all_here"
    case .holdView: "hold_view"
    case .releaseView: "release_view"
    case .display(let change): "display \(change.rawValue)"
    case .sendAcross: "send_across"
    case .moveToDisplay: "move_to_display"
    case .quitAndStart: "quit_and_start"
    case .idleAct: "idle_act"
    case .chapter(let title): "chapter \"\(title)\""
    }
  }

  /// Reads a line as `text` writes it. Nil for anything else: a walk is run by bash as it stands, so what is not a word of the contract's with
  /// arguments of the contract's has no business in one.
  public init?(text line: String) {
    let words = line.split(separator: " ").map(String.init)
    guard let verb = words.first else { return nil }
    let count = words.count
    func app(_ index: Int) -> String? { index < count && RealApp.named(words[index]) != nil ? words[index] : nil }
    func number(_ index: Int, _ range: ClosedRange<Int> = -4000...4000) -> Int? {
      index < count ? Int(words[index]).flatMap { range.contains($0) ? $0 : nil } : nil
    }
    func one<T: RawRepresentable>(_ index: Int) -> T? where T.RawValue == String { index < count ? T(rawValue: words[index]) : nil }
    let word: WalkWord? =
      switch (verb, count) {
      case ("switch_dock", 2): app(1).map { .switchDock($0) }
      case ("switch_click", 2): app(1).map { .switchClick($0) }
      case ("switch_to", 2): app(1).map { .switchTo($0) }
      case ("switch_cmdtab", 1): .switchCmdTab(1)
      case ("switch_cmdtab", 2): number(1, 1...9).map { .switchCmdTab($0) }
      case ("switch_backtick", 1): .switchBacktick
      case ("switch_menu", 2): app(1).map { .switchMenu($0) }
      case ("tile_click", 1): .tileClick(1)
      case ("tile_click", 2): number(1, 1...99).map { .tileClick($0) }
      case ("focus_key", 2): one(1).map { .focusKey($0) }
      case ("summon", 2): app(1).map { .summon($0) }
      case ("open_new", 1): .openNew
      case ("close_new", 1): .closeNew
      case ("minimize", 1): .minimize
      case ("restore", 1): .restore(nil)
      case ("restore", 2): app(1).map { .restore($0) }
      case ("hide", 1): .hide
      case ("unhide", 1): .unhide(nil)
      case ("unhide", 2): app(1).map { .unhide($0) }
      case ("quit_app", 2): app(1).map { .quitApp($0) }
      case ("reopen", 2): app(1).map { .reopen($0) }
      case ("dock_key", 2): one(1).map { .dockKey($0) }
      case ("float_key", 1): .floatKey
      case ("arrange_key", 1): .arrangeKey
      case ("undo", 1): .undo
      case ("redo", 1): .redo
      case ("rotate", 1): .rotate
      case ("mirror", 1): .mirror
      case ("pin", 1): .pin
      case ("drag_onto", 4):
        if let dragged = app(1), let other = app(2), let part: Part = one(3) { .dragOnto(dragged, other, part) } else { nil }
      case ("drag_out", 2): app(1).map { .dragOut($0) }
      case ("drag_by", 4), ("drag_by", 5):
        if let dragged = app(1), let across = number(2), let down = number(3), count == 4 || words[4] == "click" {
          .dragBy(dragged, across, down, click: count == 5)
        } else {
          nil
        }
      case ("drag_edge", 3): if let dragged = app(1), let edge: ScreenEdge = one(2) { .dragEdge(dragged, edge) } else { nil }
      case ("view", 2): one(1).map { .view($0) }
      case ("peek", 1): .peek
      case ("save_view", 2): number(1, 1...9).map { .saveView($0) }
      case ("view_n", 2): number(1, 1...9).map { .viewN($0) }
      case ("resize_gap", 3): if let beside = app(1), let points = number(2) { .resizeGap(beside, points) } else { nil }
      case ("resize_key", 2): one(1).map { .resizeKey($0) }
      case ("resize_edge", 4):
        if let resized = app(1), let part: Part = one(2), let points = number(3) { .resizeEdge(resized, part, points) } else { nil }
      case ("full_screen", 2) where words[1] == "on" || words[1] == "off": .fullScreen(words[1] == "on")
      case ("wallpaper_click", 1): .wallpaperClick
      case ("title_double_click", 2): app(1).map { .titleDoubleClick($0) }
      case ("pause", 1): .pause
      case ("resume", 1): .resume
      case ("float_all", 1): .floatAll
      case ("float_all_here", 1): .floatAllHere
      case ("hold_view", 1): .holdView
      case ("release_view", 1): .releaseView
      case ("display", 2): one(1).map { .display($0) }
      case ("send_across", 1): .sendAcross
      case ("move_to_display", 1): .moveToDisplay
      case ("quit_and_start", 1): .quitAndStart
      case ("idle_act", 1): .idleAct
      case ("chapter", 2...):
        // Letters, digits and spaces between the quotes: nothing that a shell would read as more than a title.
        { () -> WalkWord? in
          let rest = line.dropFirst("chapter ".count).trimmingCharacters(in: .whitespaces)
          guard rest.count >= 2, rest.first == "\"", rest.last == "\"" else { return nil }
          let title = String(rest.dropFirst().dropLast())
          return title.allSatisfy({ $0.isLetter || $0.isNumber || $0 == " " }) ? .chapter(title) : nil
        }()
      default: nil
      }
    guard let word else { return nil }
    self = word
  }

  /// One of each, with arguments that do not matter: for whoever has to go through all the words there are.
  public static let oneOfEach: [WalkWord] = [
    .switchDock("safari"), .switchClick("safari"), .switchTo("safari"), .switchCmdTab(1), .switchBacktick, .switchMenu("safari"), .tileClick(1),
    .focusKey(.left), .summon("safari"), .openNew, .closeNew, .minimize, .restore(nil), .hide, .unhide(nil), .quitApp("safari"), .reopen("safari"),
    .dockKey(.left), .floatKey, .arrangeKey, .undo, .redo, .rotate, .mirror, .pin, .dragOnto("safari", "notes", .left), .dragOut("safari"),
    .dragBy("safari", 10, 10, click: false), .dragEdge("safari", .left), .view(.frame), .peek, .saveView(1), .viewN(1), .resizeGap("safari", 40),
    .resizeKey(.grow), .resizeEdge("safari", .left, 30), .fullScreen(true), .wallpaperClick, .titleDoubleClick("safari"), .pause, .resume, .floatAll,
    .floatAllHere, .holdView, .releaseView, .display(.plug), .sendAcross, .moveToDisplay, .quitAndStart, .idleAct, .chapter("Noon"),
  ]
}

/// What kind of thing a person did, by the names of docs/VIABLE.md ("The mixture").
public enum WalkKind: String, CaseIterable, Sendable {
  case `switch`, openClose = "open-close", dockKey = "dock-key", drag, dragWhereMacOSTiles = "drag-where-macos-tiles", view, resize
  case macOSOwn = "macos-own", wayOut = "way-out", quitAndStart = "quit-and-start", displayChange = "display-change", idle, tileClick = "tile-click"
  /// No act, and no kind of the page's mixture: a round of input, by which the gate measures who holds input back (lib-walk.sh, `input_round`).
  case instrument

  /// The kinds of act there are.
  public static let ofActs = allCases.filter { $0 != .instrument }
}

/// Where a walk is taken: `walk_begin`'s arguments.
public struct WalkSetting: Equatable, Sendable {
  public enum Display: String, CaseIterable, Sendable { case laptop, desk, two }
  public enum Tiling: String, CaseIterable, Sendable { case defaults, off }

  public var cast = "stock"
  public var display = Display.laptop
  public var tiling = Tiling.defaults
  /// Any word without a space. Taken from the commit's own hash, so that nobody can pick one that passes.
  public var seed: String
  /// The commit the seed was taken from, or nothing.
  public var commit = ""

  public init(cast: String = "stock", display: Display = .laptop, tiling: Tiling = .defaults, seed: String, commit: String = "") {
    (self.cast, self.display, self.tiling, self.seed, self.commit) = (cast, display, tiling, seed, commit)
  }

  /// What is safe between two spaces of a line that bash runs.
  public static func isAPlainWord(_ word: String) -> Bool {
    !word.isEmpty && word.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_") }
  }
}

/// A walk as a file: plain text that bash can run as it stands, and nothing else.
public struct Walk: Equatable, Sendable {
  public var setting: WalkSetting
  public var words: [WalkWord]
  /// Comments above the first line that does anything, and below the last, without their `# `.
  public var head: [String] = []
  public var foot: [String] = []

  public init(setting: WalkSetting, words: [WalkWord], head: [String] = [], foot: [String] = []) {
    (self.setting, self.words, self.head, self.foot) = (setting, words, head, foot)
  }

  /// A walk lies beside lib-walk.sh, in scripts/mac-shell.
  static let source = "source \"$(dirname \"${BASH_SOURCE[0]}\")/lib-walk.sh\""
  /// Or in a folder of its own there.
  static let sourceFromAFolder = "source \"$(dirname \"${BASH_SOURCE[0]}\")/../lib-walk.sh\""

  public var text: String {
    var begin = ["walk_begin", setting.cast, setting.display.rawValue, setting.tiling.rawValue, setting.seed]
    if !setting.commit.isEmpty { begin.append(setting.commit) }
    let lines =
      ["#!/bin/bash"] + head.map { "# \($0)" } + [Self.source, begin.joined(separator: " ")] + words.map(\.text) + ["walk_end"]
      + foot.map { "# \($0)" }
    return lines.joined(separator: "\n") + "\n"
  }

  public struct Unreadable: Error, Equatable, CustomStringConvertible {
    public var line: Int
    public var reason: String
    public var description: String { "line \(line): \(reason)" }
  }

  /// Reads a walk, and refuses whatever is not one: the shebang, comments, the one `source`, `walk_begin`, words, `walk_end`. Several words on a line
  /// with `;` between them are taken too, as lib-walk.sh's own example has them.
  public init(text: String) throws {
    var setting: WalkSetting?
    var (words, head, foot): ([WalkWord], [String], [String]) = ([], [], [])
    var (sourced, ended) = (false, false)
    for (index, raw) in text.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
      let line = raw.trimmingCharacters(in: .whitespaces)
      func refuse(_ reason: String) -> Unreadable { Unreadable(line: index + 1, reason: reason) }
      if line.isEmpty || (index == 0 && line == "#!/bin/bash") { continue }
      if line.hasPrefix("#") {
        let comment = String(line.dropFirst().drop { $0 == " " })
        if ended { foot.append(comment) } else if setting == nil { head.append(comment) }
        continue
      }
      guard !ended else { throw refuse("after walk_end there are only comments") }
      if line == Self.source || line == Self.sourceFromAFolder || line == "source \"$(dirname \"$0\")/lib-walk.sh\"" {
        sourced = true
        continue
      }
      guard sourced else { throw refuse("before anything else lib-walk.sh is sourced") }
      for piece in line.split(separator: ";").map({ $0.trimmingCharacters(in: .whitespaces) }) where !piece.isEmpty {
        let parts = piece.split(separator: " ").map(String.init)
        if parts[0] == "walk_begin" {
          guard setting == nil else { throw refuse("a walk begins once") }
          guard (4...6).contains(parts.count), parts.dropFirst().allSatisfy(WalkSetting.isAPlainWord), let display = WalkSetting.Display(rawValue: parts[2]),
            let tiling = WalkSetting.Tiling(rawValue: parts[3])
          else { throw refuse("walk_begin <cast> laptop|desk|two defaults|off [seed [commit]]") }
          setting = WalkSetting(
            cast: parts[1], display: display, tiling: tiling, seed: parts.count > 4 ? parts[4] : "", commit: parts.count > 5 ? parts[5] : "")
        } else if piece == "walk_end" {
          guard setting != nil else { throw refuse("a walk that never began cannot end") }
          ended = true
        } else {
          guard setting != nil else { throw refuse("the first word of a walk is walk_begin") }
          guard !ended else { throw refuse("after walk_end there are only comments") }
          guard let word = WalkWord(text: piece) else { throw refuse("`\(piece)` is no word of lib-walk.sh's, or its arguments are not") }
          words.append(word)
        }
      }
    }
    guard let setting, ended else { throw Unreadable(line: 0, reason: "a walk has a walk_begin and a walk_end") }
    self.init(setting: setting, words: words, head: head, foot: foot)
  }
}
