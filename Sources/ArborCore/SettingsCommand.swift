/// The commands that read and change settings (`Command.settings`). Like every command they have a
/// text form, so each option can be scripted (`arborctl set gap 16`), bound to a key
/// (`bind ctrl+opt+x set gap 0`) and tested; the settings window changes nothing any other way.
///
/// Keys, values, shortcuts and rules are checked when the text is parsed, against `SettingsSchema`,
/// `KeyChord` and `RuleAction`, and stored in their canonical spelling. A typo is therefore reported
/// wherever the text is read, including in the `bindings` of settings.json. The one thing left to the controller: whether a
/// single character names a key (`ctrl+opt+ö`), which depends on the keyboard layout in use.
public enum SettingsCommand: Equatable, Sendable, Codable {
  /// `set gap 16`: changes one setting, at once, and saves it. `set focusRing toggle` flips a switch, for a
  /// shortcut that turns something on and off.
  case set(key: String, value: String)
  /// `get gap`, a query: one setting's value.
  case get(key: String)
  /// `settings`, a query: every setting with its value, default and meaning. `settings --json` is the same
  /// for scripts, and `settings --markdown` prints docs/SETTINGS.md.
  case list(ListFormat)
  /// `reset gap`: back to the default.
  case reset(key: String)
  /// `reset all` puts every setting back except the user's lists (shortcuts, rules, lists of apps);
  /// `reset everything` empties those too.
  case resetAll(everything: Bool)
  /// `bind ctrl+opt+h dock left`: makes a shortcut run a command, in place of whatever it ran.
  case bind(chord: String, command: String)
  /// `unbind ctrl+opt+d`: the shortcut does nothing any more, even if it has a default.
  case unbind(chord: String)
  /// `rule add com.apple.mail dock left title Inbox`: adds a rule after the others.
  case addRule(AppRule)
  /// `rule change 2 com.apple.mail float`: replaces a rule, numbered from 1 as `rules` lists them.
  case changeRule(Int, AppRule)
  /// `rule remove 2`
  case removeRule(Int)
  /// `rule move 3 1`: takes a rule out and puts it back at that place in the list.
  case moveRule(Int, to: Int)
  /// `set pauseForApps add us.zoom.xos`: puts an app on one of the lists of apps. The list can go by its label too:
  /// `set pause for add Zoom`.
  case addApp(key: String, app: String)
  /// `set pauseForApps remove us.zoom.xos`: takes it off.
  case removeApp(key: String, app: String)
  /// `settings-window`: opens the settings window, or brings it to the front. `settings-window shortcuts`
  /// turns it to that pane.
  case showWindow(SettingsPane? = nil)
  /// `settings-window close`: closes it, as ⌘W does.
  case closeWindow

  public enum ListFormat: String, Equatable, Sendable, Codable, CaseIterable {
    case text, json, markdown
  }

  public var isQuery: Bool {
    switch self {
    case .get, .list: true
    default: false
    }
  }

  /// Whether it can change settings.json.
  public var saves: Bool {
    switch self {
    case .get, .list, .showWindow, .closeWindow: false
    default: true
    }
  }

  /// The value of `set` that flips a switch.
  public static let toggle = "toggle"

  // MARK: Text form

  /// The first words of the commands parsed here.
  static let verbs: Set<String> = [
    "set", "get", "settings", "reset", "bind", "unbind", "rule", "settings-window",
  ]

  /// Parses the words after `verb`, one of `verbs` in lower case. `args` are as the user wrote
  /// them: bundle ids, titles and values keep their case.
  static func parse(verb: String, args: [String]) throws -> SettingsCommand {
    typealias ParseError = Command.ParseError
    func entry(_ name: String) throws -> SettingEntry {
      do {
        return try SettingsSchema.entry(named: name)
      } catch {
        throw ParseError("\(error)")
      }
    }
    func chord(_ written: String) throws -> String {
      do {
        let chord = try KeyChord(text: written)
        return chord.text
      } catch {
        // It may name a key by what it types (`ctrl+opt+ö`). Whether it does depends on the keyboard layout in use, which
        // only the controller knows: it goes on tidied, and is judged there.
        if let tidied = withAKeyNamedByACharacter(written) { return tidied }
        throw ParseError(notAShortcut(written, error))
      }
    }

    switch verb {
    case "set":
      guard args.count >= 2 else { throw ParseError("usage: set <key> <value> (`settings` lists the keys)") }
      // `set <list> add <app>`: the last word but one says so, and what stands before it names the list.
      if args.count >= 3, let adds = ["add": true, "remove": false][args[args.count - 2].lowercased()] {
        let name = args.dropLast(2).joined(separator: " ")
        if let list = try SettingsSchema.list(named: name) ?? (args.count == 3 ? entry(name) : nil) {
          guard list.isAppList else {
            let lists = SettingsSchema.entries.filter(\.isAppList).map(\.key).joined(separator: ", ")
            throw ParseError("`\(list.key)` is not a list of apps; those are \(lists)")
          }
          let app = try Command.bundleID(args[args.count - 1])
          return adds ? .addApp(key: list.key, app: app) : .removeApp(key: list.key, app: app)
        }
      }
      let entry = try entry(args[0])
      if entry.kind == .toggle, args.count == 2, args[1].lowercased() == Self.toggle {
        return .set(key: entry.key, value: Self.toggle)
      }
      do {
        // The rest of the line is the value, so one with spaces needs no quoting: `shift + cmd`.
        return .set(key: entry.key, value: try entry.parse(args.dropFirst().joined(separator: " ")).text)
      } catch {
        throw ParseError("\(error)")
      }
    case "get":
      guard args.count == 1 else { throw ParseError("usage: get <key> (`settings` lists the keys)") }
      return .get(key: try entry(args[0]).key)
    case "settings":
      switch args.map({ $0.lowercased() }) {
      case []: return .list(.text)
      case ["--json"], ["json"]: return .list(.json)
      case ["--markdown"], ["markdown"]: return .list(.markdown)
      default: throw ParseError("usage: settings [--json | --markdown]")
      }
    case "reset":
      guard args.count == 1 else { throw ParseError("usage: reset <key> | reset all | reset everything") }
      switch args[0].lowercased() {
      case "all": return .resetAll(everything: false)
      case "everything": return .resetAll(everything: true)
      default: return .reset(key: try entry(args[0]).key)
      }
    case "bind":
      guard args.count >= 2 else {
        throw ParseError("usage: bind <shortcut> <command>, e.g. bind ctrl+opt+h dock left")
      }
      // Nobody needs a shortcut that changes shortcuts, and `bind` inside `bind` inside `bind`, for as
      // long as a line can be, would be parsed that deep and overflow the stack.
      guard args[1].lowercased() != "bind" else { throw ParseError("a shortcut cannot run `bind`") }
      return .bind(chord: try chord(args[0]), command: try Command.parse(words: Array(args.dropFirst())).text)
    case "unbind":
      guard args.count == 1 else { throw ParseError("usage: unbind <shortcut>, e.g. unbind ctrl+opt+d") }
      return .unbind(chord: try chord(args[0]))
    case "rule":
      return try parseRule(args)
    case "settings-window":
      guard !args.isEmpty else { return .showWindow() }
      if args.count == 1, args[0].lowercased() == "close" { return .closeWindow }
      let name = args.joined(separator: " ")
      guard let pane = SettingsPane(named: name) else {
        let panes = SettingsPane.all.map(\.word).joined(separator: ", ")
        throw ParseError("the settings window has no pane \(SettingError.quoted(name)); it has \(panes)")
      }
      return .showWindow(pane)
    default:
      throw ParseError("unknown command `\(verb)`; try `help`")
    }
  }

  public static func notAShortcut(_ written: String, _ error: any Error) -> String {
    "\(SettingError.quoted(written)) is not a shortcut: \(error)"
  }

  /// `Opt + Ctrl + Ö` as `ctrl+opt+ö`, if the text is modifiers and one single character besides. Nil otherwise.
  static func withAKeyNamedByACharacter(_ written: String) -> String? {
    guard let (modifiers, character) = KeyChord.modifiersAndOneCharacter(in: written) else { return nil }
    if character == "+" {
      // `ctrl+opt+` is a shortcut somebody has not finished typing. The key for + is `ctrl+opt++`, or `⌃⌥+` as a menu shows it.
      let compact = written.filter { !$0.isWhitespace }.dropLast()
      guard let last = compact.last, last == "+" || KeyChord.modifierNames[String(last)] != nil else { return nil }
    }
    return KeyChord.text(modifiers, typing: character)
  }

  private static let ruleUsage =
    "usage: rule add <bundle id> <action> [title <text>] | rule change <n> <bundle id> <action> [title <text>]"
    + " | rule remove <n> | rule move <n> <place>"

  private static func parseRule(_ args: [String]) throws -> SettingsCommand {
    func number(_ index: Int) throws -> Int {
      guard args.indices.contains(index), let number = Int(args[index]), number >= 1 else {
        throw Command.ParseError("expected a rule number from `rules`; \(ruleUsage)")
      }
      return number
    }
    switch args.first?.lowercased() {
    case nil:
      throw Command.ParseError(ruleUsage)
    case "add":
      return .addRule(try rule(args.dropFirst()))
    case "change":
      return .changeRule(try number(1), try rule(args.dropFirst(2)))
    case "remove":
      guard args.count == 2 else { throw Command.ParseError(ruleUsage) }
      return .removeRule(try number(1))
    case "move":
      guard args.count == 3 else { throw Command.ParseError(ruleUsage) }
      return .moveRule(try number(1), to: try number(2))
    default:
      // `rule com.apple.Terminal dock right` is short for `rule add …`.
      return .addRule(try rule(args[...]))
    }
  }

  /// `<bundle id> <action> [title <text>]`. The action comes first because its length follows
  /// from its own words, which leaves the rest of the line for a title with spaces in it.
  private static func rule(_ words: ArraySlice<String>) throws -> AppRule {
    guard let first = words.first, words.count >= 2 else { throw Command.ParseError(ruleUsage) }
    // A `*` at the end stands for the rest of the bundle id, and alone for any app (F23).
    let app = first == "*" ? first : first.hasSuffix("*") ? try Command.bundleID(String(first.dropLast())) + "*" : try Command.bundleID(first)
    let rest = words.dropFirst()
    let length: Int
    switch (rest.first?.lowercased(), rest.dropFirst().first?.lowercased()) {
    case ("dock", "beside"): length = 4
    case ("dock", _): length = 2
    default: length = 1
    }
    let action: RuleAction
    do {
      action = try RuleAction(text: rest.prefix(length).joined(separator: " "))
    } catch {
      throw Command.ParseError("\(error)")
    }
    if case .dockBeside(let neighbour, _) = action { _ = try Command.bundleID(neighbour) }
    let tail = rest.dropFirst(length)
    guard let keyword = tail.first else { return AppRule(app: app, action: action) }
    // A word list (a URL's, say) can have white space inside its words. One space between words is
    // what the text form can say, so that is what is kept.
    let title = tail.dropFirst().flatMap { $0.split(whereSeparator: \.isWhitespace) }.joined(separator: " ")
    guard keyword.lowercased() == "title", !title.isEmpty else {
      throw Command.ParseError(
        "expected `title <text>` after the action, got \(SettingError.quoted(keyword)); \(ruleUsage)")
    }
    return AppRule(app: app, title: title, action: action)
  }

  /// The canonical text form; `Command.parse` round-trips it.
  public var text: String {
    func words(_ rule: AppRule) -> String {
      "\(rule.app) \(rule.action.text)" + (rule.title.map { " title \($0)" } ?? "")
    }
    switch self {
    case .set(let key, let value): return "set \(key) \(value)"
    case .get(let key): return "get \(key)"
    case .list(let format): return format == .text ? "settings" : "settings --\(format.rawValue)"
    case .reset(let key): return "reset \(key)"
    case .resetAll(let everything): return everything ? "reset everything" : "reset all"
    case .bind(let chord, let command): return "bind \(chord) \(command)"
    case .unbind(let chord): return "unbind \(chord)"
    case .addRule(let rule): return "rule add \(words(rule))"
    case .changeRule(let number, let rule): return "rule change \(number) \(words(rule))"
    case .removeRule(let number): return "rule remove \(number)"
    case .moveRule(let number, let place): return "rule move \(number) \(place)"
    case .addApp(let key, let app): return "set \(key) add \(app)"
    case .removeApp(let key, let app): return "set \(key) remove \(app)"
    case .closeWindow: return "settings-window close"
    case .showWindow(let pane): return "settings-window" + (pane.map { " \($0.word)" } ?? "")
    }
  }
}

extension Settings {
  /// Drops everything `bindings` says about `chord`, however the user spelt it (`opt+ctrl+Space`),
  /// including an entry that could not be read. What `bind` and `unbind` do first.
  /// On `layout`, where a key can also be named by what it types: `ü` and `us:[` are one shortcut on a German keyboard.
  public mutating func removeBindings(for chord: KeyChord, layout: KeyLayout = .us) {
    for text in bindings.keys where (try? KeyChord(text: text, layout: layout)) == chord {
      bindings.removeValue(forKey: text)
    }
    unreadableBindings.removeAll { (try? KeyChord(text: $0, layout: layout)) == chord }
  }

  /// Drops everything `bindings` says about the key that `chord` means on `layout`, under whichever of its names: `z` and
  /// `us:y`, `ü` and `[` and `us:[` are one key on a German keyboard. Entries that free the key (null) go as well.
  public mutating func removeBindings(onTheKeyOf chord: KeyChord, layout: KeyLayout) {
    func isOnTheKey(_ text: String) -> Bool {
      guard let other = try? KeyChord(text: text, layout: layout) else { return false }
      return other.modifiers == chord.modifiers && other.code(in: layout) == chord.code(in: layout)
    }
    for text in bindings.keys where isOnTheKey(text) { bindings.removeValue(forKey: text) }
    unreadableBindings.removeAll(where: isOnTheKey)
  }
}
