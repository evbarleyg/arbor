import CoreGraphics

/// The small queries (F50, part 2): `windows`, `where`, `views`, `displays`, `version`. Each answer is a list of rows. A row is
/// one line of text, its fields separated by tabs (made for `cut -f`; `arborctl` lines the columns up when a person is
/// looking), and one JSON object (made for `jq`). docs/SCRIPTING.md documents every field: scripts depend on them, so
/// fields are added at the end and never renamed, reordered or removed.
///
/// The words are those of the events (`watch`), so that a script learns them once: `docked` is true or false; `state` says where a
/// window is; `label` is a space in words, `name` only a name a person gave; `display` is a display's number, as commands
/// take it (`@2`), and `displayID` its UUID; what *is* a window or a display has an `id`, what refers to one says `window` or `display`.
public enum Query {
  /// A window Arbor arranges.
  public struct Window: Codable, Equatable, Sendable {
    public typealias State = ArborEvent.Window.State

    public var id: WindowID
    /// In the arrangement, or floating on the Desktop.
    public var docked: Bool
    public var state: State
    /// The number of the display whose arrangement holds it, as `@2` counts, and its UUID.
    public var display: Int
    public var displayID: DisplayID
    public var bundleID: String?
    public var app: String
    /// Only when asked for (`--titles`).
    public var title: String?
    public var focused: Bool
    @JSONRect public var frame: CGRect
    /// The space it is docked in; `zoom-node` takes it.
    public var node: NodeID?
    /// Kept in view wherever the view goes (`pin`). Only a floating window can be.
    public var pinned: Bool
    /// Brought over the view by `summon`, until the keyboard goes elsewhere. It floats as well.
    public var summoned: Bool

    public init(
      id: WindowID, docked: Bool, state: State, display: Int, displayID: DisplayID, bundleID: String?, app: String,
      title: String?, focused: Bool, frame: CGRect, node: NodeID?, pinned: Bool = false, summoned: Bool = false
    ) {
      self.id = id
      self.docked = docked
      self.state = state
      self.display = display
      self.displayID = displayID
      self.bundleID = bundleID
      self.app = app
      self.title = title
      self.focused = focused
      self.frame = frame
      self.node = node
      self.pinned = pinned
      self.summoned = summoned
    }

    public var fields: [String] {
      [String(id.rawValue), docked ? "docked" : pinned ? "pinned" : summoned ? "summoned" : "floating", state.rawValue, String(display), bundleID ?? "-", app]
        + (title.map { [$0] } ?? [])
    }
  }

  /// What a display's view shows: an answer to "where am I?".
  public struct Place: Codable, Equatable, Sendable {
    public typealias Kind = ArborEvent.View.Kind

    public var display: Int
    public var displayID: DisplayID
    /// In Arbor's words: "everything", "the Desktop", "Safari and Mail".
    public var label: String
    /// The space that fills the view; `zoom-node` takes it.
    public var node: NodeID
    public var kind: Kind
    /// How often `out` can be run from here, and from the deepest space.
    public var depth: Int
    public var deepest: Int
    /// Windows of this display that are out of view.
    public var outOfView: Int
    /// The docked windows in view, in reading order, and their apps.
    public var windows: [WindowID]
    public var apps: [String]
    public var canGoBack: Bool
    public var canGoForward: Bool
    /// What a person called the space (`name`), if anything.
    public var name: String?

    public init(
      display: Int, displayID: DisplayID, label: String, node: NodeID, kind: Kind, depth: Int, deepest: Int, outOfView: Int,
      windows: [WindowID], apps: [String], canGoBack: Bool, canGoForward: Bool, name: String? = nil
    ) {
      self.display = display
      self.displayID = displayID
      self.label = label
      self.node = node
      self.kind = kind
      self.depth = depth
      self.deepest = deepest
      self.outOfView = outOfView
      self.windows = windows
      self.apps = apps
      self.canGoBack = canGoBack
      self.canGoForward = canGoForward
      self.name = name
    }

    /// As text a space goes by its name if it has one, as in replies.
    public var fields: [String] {
      [String(display), name ?? label, "\(node)", "depth \(depth) of \(deepest)", "\(outOfView) out of view"]
    }
  }

  public struct SavedView: Codable, Equatable, Sendable {
    public var display: Int
    public var displayID: DisplayID
    /// 1 to 9; `view` takes it.
    public var view: Int
    public var label: String
    public var node: NodeID
    /// The view is showing it now.
    public var current: Bool
    /// What a person called the space, if anything.
    public var name: String?

    public init(display: Int, displayID: DisplayID, view: Int, label: String, node: NodeID, current: Bool, name: String? = nil) {
      self.display = display
      self.displayID = displayID
      self.view = view
      self.label = label
      self.node = node
      self.current = current
      self.name = name
    }

    public var fields: [String] { [String(display), String(view), name ?? label, "\(node)"] + (current ? ["current"] : []) }
  }

  public struct Display: Codable, Equatable, Sendable {
    /// What `@2` counts: 1 is the main display, then from left to right and top to bottom.
    public var display: Int
    /// Its UUID, which stays the same when the display is unplugged and comes back. Twice: this is a display, so it has an `id`,
    /// and the events call a display's UUID `displayID` wherever it stands, which is what `windows` and `where` are joined on.
    public var id: DisplayID
    public var displayID: DisplayID
    /// Global points, origin at the top left of the main display, y down.
    @JSONRect public var frame: CGRect
    /// Without the menu bar and the Dock.
    @JSONRect public var visibleFrame: CGRect
    public var main: Bool
    public var pointer: Bool
    public var focus: Bool
    /// What macOS calls it, as in the `displays` event. Left out if it has no name.
    public var name: String?
    public var builtIn = false
    /// The options in effect on this display (F25): the general settings, or what an entry of `displays` in settings.json gave it.
    public var gap = 0.0
    public var minimumUsableWidth = 0.0
    public var minimumUsableHeight = 0.0
    public var screenEdgeBand = 0.0
    /// For each of those four that an entry gave: the entry's `match`. Those with the general value are left out.
    public var from: [String: String] = [:]

    public init(display: Int, id: DisplayID, frame: CGRect, visibleFrame: CGRect, main: Bool, pointer: Bool, focus: Bool) {
      self.display = display
      self.id = id
      self.displayID = id
      self.frame = frame
      self.visibleFrame = visibleFrame
      self.main = main
      self.pointer = pointer
      self.focus = focus
    }

    public var fields: [String] {
      let marks = [main ? "main" : nil, pointer ? "pointer" : nil, focus ? "focus" : nil].compactMap { $0 }
      let values = ["gap": gap, "minimumUsableWidth": minimumUsableWidth, "minimumUsableHeight": minimumUsableHeight, "screenEdgeBand": screenEdgeBand]
      // `gap 6 (builtin)`: only what the display has of its own.
      let own = ["gap", "minimumUsableWidth", "minimumUsableHeight", "screenEdgeBand"].compactMap { key in
        from[key].map { "\(key) \(Query.plain(values[key] ?? 0)) (\($0))" }
      }
      return [
        String(display), id.rawValue, Query.text(of: frame), marks.isEmpty ? "-" : marks.joined(separator: ","),
        name.flatMap { $0.isEmpty ? nil : $0 } ?? "-", own.isEmpty ? "-" : own.joined(separator: ", "),
      ]
    }
  }

  /// `BuildInfo` as JSON, with what a script needs to know before it reads anything else.
  public struct Version: Codable, Equatable, Sendable {
    /// `0.9.0`, or `dev` for a build that is not in a bundle.
    public var version: String
    public var build: String?
    public var commit: String?
    /// Of `state`'s JSON.
    public var schema: Int

    public init(_ info: BuildInfo, schema: Int = StateSnapshot.currentSchema) {
      self.version = info.version
      self.build = info.build
      self.commit = info.commit
      self.schema = schema
    }
  }

  /// `0,25,1440,875`: x, y, width, height in whole points.
  static func text(of rect: CGRect) -> String {
    [rect.origin.x, rect.origin.y, rect.size.width, rect.size.height].map { value -> String in
      let rounded = Double(value).rounded()
      return Int(exactly: rounded).map(String.init) ?? "0"
    }.joined(separator: ",")
  }

  /// 12 for 12.0, 12.5 for 12.5.
  static func plain(_ value: Double) -> String {
    value == value.rounded() && abs(value) < 1e9 ? String(Int(value)) : String(value)
  }

  /// Rows as text. A tab or line break inside a field (an app can call itself anything) would shift the fields after it.
  public static func table(_ rows: [[String]]) -> String {
    rows.map { row in
      row.map { field in String(field.map { $0 == "\t" || $0.isNewline ? " " : $0 }) }.joined(separator: "\t")
    }.joined(separator: "\n")
  }
}
