import Foundation

/// Every setting, described once: where it is shown, what it is called, what it does, which values
/// it takes, and how to read and write it in a `Settings` value. The `set`, `get`, `settings` and
/// `reset` commands, the checks on a hand-edited settings.json, docs/SETTINGS.md and the settings
/// window are all views of this list, so none of them needs to know about any particular setting.
///
/// **Adding a setting** takes its property in `Settings` (see there) and ONE entry here, at the end
/// of its section's list:
///
///     .toggle("previewDrags", \.previewDrags, "Drop preview", "Show where a dragged window would land."),
///     .number("dropDwell", \.dropDwell, min: 0, max: 2, step: 0.05, unit: "s", "Hold over a target",
///       "How long the pointer must rest on a window before it can be dropped there.", advanced: true),
///     .choice("tileClick", \.tileClick, ["single": "One click", "double": "Double-click"], "Open tiles with",
///       "How a tile is opened."),
///
/// `advanced: true` keeps it behind "Advanced" in the window, `hidden: true` out of the window altogether. What the
/// window shows takes its words from docs/GLOSSARY.md (a test knows the commonest wrong ones); if in doubt about
/// words, section or level, write `hidden: true` and it can be placed later without anybody having seen it.
/// Then run the tests: `everySettingsKeyHasASchemaEntry` fails for a key without an entry, and
/// `theSettingsDocumentIsUpToDate` rewrites docs/SETTINGS.md (commit it).
public enum SettingsSchema {
  private static let general = section(
    .general,
    [
      .toggle(
        "hotkeysEnabled", \.hotkeysEnabled, "Use keyboard shortcuts",
        "Global keyboard shortcuts: ⌃⌥ moves the view and ⌃⌥⌘ moves windows, unless you change them.",
        whenOff: "Settings… in Arbor's menu is the way back"),
      .toggle(
        "peek", \.peek, "Hold Show Everything to peek",
        "While the Show Everything shortcut is held everything shows, and letting go frames the outlined space. "
          + "Off, holding it does the same as a tap."),
      .choice(
        "stepInToward", \.stepInToward,
        ["auto": "Whichever was used last", "pointer": "The pointer", "focus": "The focused window"],
        "Shortcuts follow",
        "Which display a shortcut acts on, and which space Step In steps toward. Gestures always follow the pointer.",
        advanced: true),
      .toggle(
        "shortcutsFollowLayout", \.shortcutsFollowLayout, "Shortcuts follow the keyboard layout",
        "A letter, digit or sign in a shortcut means the key that types it on the keyboard layout in use, as in ⌘ "
          + "shortcuts. Off, it means that key's place on a US keyboard.", advanced: true),
      .toggle(
        "automaticUpdateChecks", \.automaticUpdateChecks, "Check for updates",
        "Ask GitHub for a newer release a minute after starting and once a week. No window opens: the menu then offers "
          + "the update, and nothing is ever downloaded. Off, Arbor uses the network only when asked to."),
      .list(
        "bindings", \.bindings, shape: "an object that maps shortcuts to commands",
        editedWith: "`bind <shortcut> <command>` and `unbind <shortcut>`", counts: "shortcut", "Your shortcuts",
        "Changes to the shortcuts: a shortcut and the command it runs, or null to remove a default one."),
      .choice(
        "messages", \.messages, ["helpful": "When it helps", "all": "After every command", "off": "Never"],
        "Messages on screen",
        "A line on screen after a shortcut, a gesture or a menu item: what went wrong, what changed out of view, and a "
          + "few hints for newcomers."),
    ])

  private static let windows = section(
    .windows,
    [
      .number(
        "gap", \.gap, min: 0, max: 100, step: 1, unit: "pt", "Gap",
        "Space between docked windows, and between them and the screen edges."),
      .number(
        "minimumUsableWidth", \.minimumUsableWidth, min: 0, max: 1000, step: 10, unit: "pt",
        "Smallest usable width",
        "A space narrower than this shows a tile with the app's colour and icon instead of its window."),
      .number(
        "minimumUsableHeight", \.minimumUsableHeight, min: 0, max: 1000, step: 10, unit: "pt",
        "Smallest usable height", "A space shorter than this shows a tile instead of its window."),
      .number(
        "arrangeDesktopWeight", \.arrangeDesktopWeight, min: 0.1, max: 3, step: 0.1, unit: "",
        "Desktop width in Arrange",
        "How wide Arrange Windows leaves the Desktop, relative to the windows beside it.", advanced: true),
      .list(
        "rules", \.rules, shape: "a list of rules",
        editedWith: "`rule add`, `rule change`, `rule remove` and `rule move`", counts: "rule", "Rules",
        "What happens to new windows of particular apps. Rules are checked in order and the first match wins."),
      .number(
        "ruleTitleWait", \.ruleTitleWait, min: 0, max: 60, step: 0.5, unit: "s", "Wait for a window's title",
        "How long a new window's title is checked against rules that have a title: browsers and editors set "
          + "the real title a moment after the window opens. 0 checks only the first title.", hidden: true),
      .choice(
        "newWindowsWhileFramed", \.newWindowsWhileFramed,
        ["guest": "Stay with that view", "float": "Belong to the Desktop"], "New windows while framed",
        "A window that opens over a view that does not show the Desktop (a framed window, a group) can go out of view and "
          + "come back with that view, or belong to the Desktop like any floating window."),
      .number(
        "tileRetryMinutes", \.tileRetryMinutes, min: 0, max: 1440, step: 5, unit: "min", "Ask tiles again after",
        "A window that is a tile because it once refused the size of its space is asked again, out of view, after this "
          + "long. 0 never asks; `relayout` always does.", hidden: true),
      .toggle(
        "summonStays", \.summonStays, "Summoned windows stay",
        "A summoned window stays over the view when another window gets the keyboard, until it is summoned away. Off, "
          + "turning to another window sends it out of view.", advanced: true),
      .toggle(
        "makeRoom", \.makeRoom, "Make room before making a tile",
        "Before a window becomes a tile because its app will not shrink that far, move the gaps around it and take "
          + "the room from the Desktop and from neighbours that can spare it.", advanced: true),
      .toggle(
        "soleFloatTakesDesktop", \.soleFloatTakesDesktop, "Lone window fills the Desktop",
        "Beside docked windows, the only floating window takes the whole Desktop and follows it. It has its own size "
          + "back as soon as a second window floats. Moved or resized by hand, it stays as you leave it.",
        advanced: true),
      .number(
        "resizeStep", \.resizeStep, min: 1, max: 1000, step: 10, unit: "pt", "Grow and Shrink by",
        "How much bigger or smaller Grow and Shrink (⌃⌥⌘= and ⌃⌥⌘-) make the focused window at a time.", advanced: true),
      .list(
        "displays", \.displays, shape: "a list of entries: `match` and the settings that differ there",
        editedWith: "a text editor; `displays` shows what is in effect on each display", "Options per display",
        "Other values of the gap, the smallest usable size and the screen edge band for particular displays. "
          + "The first entry that matches a display and sets a value gives it.", advanced: true),
      .choice(
        "newWindows", \.newWindows, ["float": "Float where they open", "dock": "Dock beside the focused window"],
        "New windows",
        "What a new window does when no rule matches it. dock: it takes half the place of the docked window you were "
          + "working in, if there is room; small windows and windows of a fixed size float. The menu's Dock New "
          + "Windows and `toggle-auto-dock` switch it."),
      .number(
        "autoDockMinimumWidth", \.autoDockMinimumWidth, min: 0, max: 3000, step: 10, unit: "pt",
        "Narrowest window docked",
        "A window that opens narrower than this is never docked by `dock auto` or by a rule for `*`.", advanced: true),
      .number(
        "autoDockMinimumHeight", \.autoDockMinimumHeight, min: 0, max: 3000, step: 10, unit: "pt",
        "Shortest window docked",
        "A window that opens shorter than this is never docked by `dock auto` or by a rule for `*`.", advanced: true),
      .toggle(
        "shareRemovedSpace", \.shareRemovedSpace, "Share a leaving window's space",
        "The space of a window that leaves is shared by its whole group. Off, it goes to the neighbour before it and "
          + "nothing else moves.", advanced: true),
      .toggle(
        "shrinkOutOfView", \.shrinkOutOfView, "Shrink windows out of view",
        "Windows that go out of view are also shrunk, to 320 by 200 points at most, until they come back.",
        advanced: true),
    ])

  private static let dragging = section(
    .dragging,
    [
      .number(
        "screenEdgeBand", \.screenEdgeBand, min: 0, max: 100, step: 1, unit: "pt", "Screen edge band",
        "How close to a screen edge the pointer must come for a dragged window to dock there.", advanced: true),
      .number(
        "windowEdgeFraction", \.windowEdgeFraction, min: 0, max: 0.5, step: 0.05, unit: "", "Window edge band",
        "The band along a window's edges, as a fraction of its size, where a dropped window docks beside it.",
        advanced: true),
      .number(
        "dropDwell", \.dropDwell, min: 0, max: 2, step: 0.05, unit: "s", "Hold over a target",
        "How long a dragged window must be held over a window or tile before it can be dropped there. "
          + "Screen edges never wait.", advanced: true),
      .toggle(
        "previewDrags", \.previewDrags, "Drop preview",
        "Show where a dragged window will land. Without it nothing has to be held either.", advanced: true),
      .toggle(
        "reflowWhileDragging", \.reflowWhileDragging, "Make room while dragging",
        "While you drag, the other windows close up and make room, showing what letting go would do.", hidden: true),
      .toggle(
        "keepPushed", \.keepPushed, "Pushed windows stay aside",
        "With reflowWhileDragging: floating windows pushed aside stay there until the drag ends.", hidden: true),
    ])

  private static let tabs = section(
    .tabs,
    [
      .toggle(
        "tabsEnabled", \.tabsEnabled, "Tab groups",
        "Dropping a window on the middle of another makes the two a tab group.", hidden: true)
    ])

  private static let gestures = section(
    .gestures,
    [
      .toggle(
        "gesturesEnabled", \.gesturesEnabled, "Pinch to zoom",
        "A trackpad pinch with ⌥ held, or over the Desktop, zooms the view in and out."),
      .number(
        "pinchThreshold", \.pinchThreshold, min: GestureInterpreter.minimumThreshold, max: 2, step: 0.05,
        unit: "", "Pinch travel for one step",
        "How far a pinch must travel for one step; smaller is more sensitive.", advanced: true),
      .text(
        "frameRectangleModifier", \.frameRectangleModifier, example: "shift+cmd",
        expects: "modifier keys joined by +, such as shift+cmd, or none",
        canonical: { RectangleGesture.Modifiers(text: $0)?.text }, "Frame a rectangle with",
        "Hold these keys and drag a rectangle to frame what it covers; none turns this off."),
      .toggle(
        "frameRectangleOnDesktop", \.frameRectangleOnDesktop, "⇧-drag on the Desktop frames",
        "A ⇧-drag that starts on the Desktop, in a gap or on a tile also frames a rectangle."),
      .toggle(
        "continuousZoom", \.continuousZoom, "Continuous zoom",
        "Not finished: the view will follow the fingers during a pinch, and pan with ⌥ and two fingers. "
          + "For now a pinch steps as before.", hidden: true),
      .toggle(
        "guardDesktopClicks", \.guardDesktopClicks, "Guard clicks on the Desktop",
        "An experiment, not yet seen at work on a Mac. While something is docked, a plain click on the bare Desktop is "
          + "kept from macOS, which would sweep every window aside (“Click wallpaper to reveal desktop”). Drags, icons and "
          + "widgets are left alone.", advanced: true),
      .toggle(
        "scrollZoom", \.scrollZoom, "Zoom with ⌃⌥ and scroll",
        "Scrolling with ⌃⌥ held zooms: up steps in toward the pointer, down steps out. Off with Pinch to zoom too."),
      .number(
        "scrollZoomThreshold", \.scrollZoomThreshold, min: ScrollZoom.minimumThreshold, max: 400, step: 4,
        unit: "pt", "Scroll travel for one step",
        "How far a Magic Mouse or trackpad must scroll for one step; smaller is more sensitive. A wheel steps once "
          + "per notch.", advanced: true),
      .toggle(
        "scrollOnDesktopZooms", \.scrollOnDesktopZooms, "Scroll on the Desktop zooms",
        "Scrolling on the Desktop, in a gap or on a tile zooms without the keys. Every scroll on the Mac then passes "
          + "through Arbor.", advanced: true),
    ])

  private static let appearance = section(
    .appearance,
    [
      .toggle(
        "focusRing", \.focusRing, "Focus ring", "Draw a line around the focused window, if Arbor arranges it."),
      .number(
        "focusRingWidth", \.focusRingWidth, min: 1, max: 12, step: 0.5, unit: "pt", "Focus ring width",
        "How thick the line around the focused window is.", advanced: true),
      .text(
        "focusRingColour", \.focusRingColour, example: "#FF8000", expects: "accent, #RRGGBB or #RRGGBBAA",
        canonical: { text in
          guard FocusRingColour(text: text) != nil else { return nil }
          let word = text.trimmingCharacters(in: .whitespaces)
          return word.lowercased() == "accent" ? "accent" : word.uppercased()
        }, "Focus ring colour",
        "The colour of the line: accent is the accent colour chosen in System Settings.", advanced: true),
      .number(
        "focusRingRadius", \.focusRingRadius, min: 0, max: 60, step: 1, unit: "pt", "Focus ring corners",
        "The radius of the window corners the line follows; 0 picks that of the macOS Arbor runs on.",
        hidden: true),
      .number(
        "animationDuration", \.animationDuration, min: 0, max: 2, step: 0.05, unit: "s", "Motion",
        "How long a zoom, a dock or a close takes to play; 0 applies everything at once. “Reduce motion” in System "
          + "Settings turns the motion off as well."),
      .number(
        "minimapDuration", \.minimapDuration, min: 0, max: 10, step: 0.1, unit: "s", "Show minimap after each move",
        "For how long the minimap shows by itself after the view has moved. 0 is off; its shortcut shows it either way."),
      .number(
        "dimBehindArranged", \.dimBehindArranged, min: 0, max: 1, step: 0.05, unit: "", "Darken behind docked windows",
        "How much darker the wallpaper is behind docked windows, so that they read as one surface: 0 leaves it as it "
          + "is, 1 is black."),
      .number(
        "blurBehindArranged", \.blurBehindArranged, min: 0, max: 1, step: 0.1, unit: "", "Blur behind docked windows",
        "How much the wallpaper is blurred behind docked windows: 0 leaves it sharp, 1 is all the blur macOS has.",
        advanced: true),
      .choice(
        "tileStyle", \.tileStyle, ["icon": "The icon", "name": "The icon and the name", "plain": "Only the colour"],
        "Tiles show", "What the tile of a window too small to use shows on its colour."),
      .toggle(
        "appColours", \.appColours, "Tiles in their app's colour",
        "A tile takes on the colour of its app's icon. Off, every tile is the same grey.", advanced: true),
      .number(
        "appColourAmount", \.appColourAmount, min: 0, max: 1, step: 0.05, unit: "", "How much of the app's colour",
        "How much of its app's colour goes into a tile: 0 is grey, 1 is the colour itself.", advanced: true),
      .choice(
        "gapHandles", \.gapHandles,
        ["shown": "Drag them, with a handle", "hidden": "Drag them, nothing drawn", "off": "Only gaps"],
        "Gaps between windows",
        "shown: dragging a gap resizes the windows on both sides, and a handle shows in it under the pointer. hidden: the "
          + "same without the handle. off: gaps cannot be dragged; window edges and `resize` still resize."),
      .toggle(
        "windowPictures", \.windowPictures, "Pictures of moving windows",
        "Not ready: it has crashed Arbor and has not been tried since it was mended. While they move, windows are still "
          + "pictures of themselves instead of their app's colour and icon. Needs Screen & System Audio Recording "
          + "permission; nothing is recorded or stored.", hidden: true),
      .number(
        "tintBehindArranged", \.tintBehindArranged, min: 0, max: 1, step: 0.05, unit: "", "Tint behind docked windows",
        "How much of your accent colour is laid over the wallpaper behind docked windows.", advanced: true),
      .number(
        "desktopEdge", \.desktopEdge, min: 0, max: 1, step: 0.05, unit: "", "Line around the Desktop",
        "How strong the hairline around the Desktop is where it lies between docked windows; 0 draws none.",
        advanced: true),
      .number(
        "tileFade", \.tileFade, min: 0, max: 1, step: 0.05, unit: "s", "Tiles fade for",
        "How long a tile takes to fade in and out; 0 shows and hides it at once.", hidden: true),
    ])

  private static let calls = section(
    .calls,
    [
      .toggle(
        "holdStillWhileCameraIsOn", \.holdStillWhileCameraIsOn, "While a camera is on",
        "Hold still by itself during a call: the view moves only when you ask. Arbor reads from macOS that some app has a camera "
          + "running, and opens none itself. Off until that has been seen at work: choose Hold Still from the menu.", advanced: true),
      .toggle(
        "holdStillWhileMicrophoneIsOn", \.holdStillWhileMicrophoneIsOn, "While a microphone is on",
        "The same for calls without a camera. Off, because it is not yet known what else keeps a microphone running on a "
          + "Mac.", advanced: true),
      .list(
        "holdStillFor", \.holdStillFor, shape: "a list of bundle ids, each with part of a title after it if you like",
        editedWith: "a text editor", "While one of these is open",
        "Arbor also holds still while a window like one of these is open, for example \"us.zoom.xos Zoom Meeting\" (written from "
          + "memory: check the title on your Mac).", advanced: true),
    ])

  private static let menuBar = section(
    .menuBar,
    [
      .toggle(
        "menuBarControls", \.menuBarControls, "Buttons in the menu bar",
        "Buttons for back, forward, the Desktop, everything and each saved view; right-click them for the menu. Off, a "
          + "single icon opens the menu."),
      .toggle(
        "historyButtons", \.historyButtons, "Back and forward buttons", "Whether the buttons include back and forward.", advanced: true),
      .number(
        "menuBarFill", \.menuBarFill, min: 0, max: 1, step: 0.05, unit: "", "Fill of the current button",
        "How opaque the background of the button for where you are is, from 0 to 1.", hidden: true),
    ])

  private static let apps = section(
    .apps,
    [
      .apps(
        "excludedBundleIDs", \.excludedBundleIDs, alsoEditedWith: "`exclude [bundle id]` and `include <bundle id>`",
        added: "no longer arranging %@", removed: "arranging %@ again", "Don't arrange", "Arbor leaves the windows of these apps alone: it never docks, moves or sends them out of view."),
      .apps(
        "passThroughApps", \.passThroughApps, alsoEditedWith: "`pass-through [bundle id] [on|off]`",
        added: "shortcuts and gestures are off in %@", removed: "shortcuts and gestures work in %@ again", "Shortcuts off in",
        "Apps that keep ⌃⌥ for themselves: while one of them is in front Arbor gives up its shortcuts and gestures, and "
          + "goes on arranging windows."),
      .apps(
        "pauseForApps", \.pauseForApps, added: "Arbor pauses while %@ is in front",
        removed: "Arbor no longer pauses for %@", "Pause for",
        "Arbor pauses for as long as one of these apps is in front.", advanced: true),
    ])

  private static let scripting = section(
    .scripting,
    [
      .toggle(
        "allowAllURLCommands", \.allowAllURLCommands, "Every command from URLs",
        "Let arbor:// URLs run every command, not only those that move the view and arrange windows; "
          + "any web page or document can open such a URL.")
    ])

  /// Every setting, section by section in the order of `SettingsSection.allCases`.
  public static let entries: [SettingEntry] = [
    general, windows, dragging, tabs, gestures, calls, appearance, menuBar, apps, scripting,
  ].flatMap { $0 }

  private static func section(_ section: SettingsSection, _ entries: [SettingEntry]) -> [SettingEntry] {
    entries.map { entry in
      var entry = entry
      entry.section = section
      return entry
    }
  }

  public static func entries(in section: SettingsSection) -> [SettingEntry] {
    entries.filter { $0.section == section }
  }

  // MARK: Finding a setting by name

  private static let entriesByLowercasedKey: [String: SettingEntry] = Dictionary(
    entries.map { ($0.key.lowercased(), $0) }, uniquingKeysWith: { first, _ in first })

  /// The setting called `name`, ignoring case. Anything else is an error, even the beginning of a key
  /// that only one key has: a script must not change meaning when a later version adds a key.
  /// The error names the keys the user most likely meant.
  public static func entry(named name: String) throws -> SettingEntry {
    if let entry = entriesByLowercasedKey[name.lowercased()] { return entry }
    let shown = SettingError.quoted(name)
    let likely = suggestions(for: name).map { "`\($0)`" }
    guard let last = likely.last else {
      throw SettingError("unknown setting \(shown); `settings` lists them all")
    }
    let others = likely.dropLast().joined(separator: ", ")
    throw SettingError(
      "unknown setting \(shown); did you mean \(others.isEmpty ? last : "\(others) or \(last)")?")
  }

  /// The values a number may take, for code that reads the same quantity from somewhere else than its own key
  /// (an entry of `displays`, say) and should hold it to the same bounds. Nil if `key` is no number.
  public static func range(of key: String) -> ClosedRange<Double>? {
    guard case .number(let range, _, _)? = entriesByLowercasedKey[key.lowercased()]?.kind else { return nil }
    return range
  }

  /// A list by its key or by its label, however that is spelt: `excludedBundleIDs`, `dont-arrange`, `Don't arrange`.
  public static func list(named name: String) -> SettingEntry? {
    func letters(_ text: String) -> String { text.lowercased().filter { $0.isLetter || $0.isNumber } }
    let wanted = letters(name)
    return entries.first { entry in
      guard case .list = entry.kind, !wanted.isEmpty else { return false }
      return letters(entry.key) == wanted || letters(entry.label) == wanted
    }
  }

  /// Up to three keys that `name` may be a misspelling or a part of, or whose label has the word (people
  /// remember "shortcuts", not `hotkeysEnabled`), the likeliest first.
  public static func suggestions(for name: String) -> [String] {
    let typed = name.lowercased()
    // Longer than any key could be misspelt into, and comparing costs time in proportion to the length.
    guard !typed.isEmpty, typed.count <= 64 else { return [] }
    var ranked: [(key: String, distance: Int)] = []
    for entry in entries {
      let key = entry.key.lowercased()
      let distance = editDistance(typed, key)
      if typed.count >= 3, key.firstRange(of: typed) != nil {
        ranked.append((entry.key, 0))
      } else if distance <= max(1, max(typed.count, key.count) / 3) {
        ranked.append((entry.key, distance))
      } else if typed.count >= 3, entry.label.lowercased().firstRange(of: typed) != nil {
        ranked.append((entry.key, 1))
      }
    }
    // The sort is not stable, so ties are settled by the key to keep the message the same every time.
    return ranked.sorted { ($0.distance, $0.key) < ($1.distance, $1.key) }.prefix(3).map(\.key)
  }

  /// How many single-character edits turn `a` into `b`: insertions, deletions, replacements, and swaps
  /// of two neighbours, the commonest typing mistake (`gpa` for `gap` is one edit, not two).
  static func editDistance(_ a: String, _ b: String) -> Int {
    let a = Array(a)
    let b = Array(b)
    guard !a.isEmpty, !b.isEmpty else { return max(a.count, b.count) }
    var beforeLast: [Int] = []
    var last = Array(0...b.count)
    for i in 1...a.count {
      var row = [i] + Array(repeating: 0, count: b.count)
      for j in 1...b.count {
        row[j] = min(last[j] + 1, row[j - 1] + 1, last[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
        if i > 1, j > 1, a[i - 1] == b[j - 2], a[i - 2] == b[j - 1] {
          row[j] = min(row[j], beforeLast[j - 2] + 1)
        }
      }
      beforeLast = last
      last = row
    }
    return last[b.count]
  }

  // MARK: Hand-edited files

  /// Brings every value into what its entry allows: a number outside its range moves to the nearest
  /// end of it, and anything else that `set` would refuse goes back to the default. Returns one line
  /// per setting changed. `Settings.init(from:)` runs this on everything it decodes, so nothing
  /// written in settings.json reaches the layout, a timer or a conversion to `Int` unchecked.
  public static func sanitize(_ settings: inout Settings) -> [String] {
    entries.compactMap { $0.sanitize(&settings) }
  }

  /// Why a value of the wrong JSON type for `key` was skipped, in the form `sanitize` reports.
  static func wrongTypeProblem(key: String) -> String {
    guard let entry = entriesByLowercasedKey[key.lowercased()] else {
      return "\(key): not the kind of value it takes; using the default"
    }
    return "\(key): not \(entry.jsonShape); using the default, \(entry.defaultValue.summary)"
  }

  // MARK: Reports

  /// What `settings` prints: every setting with its value, what it accepts, its default and what it
  /// does, by section, with a star beside the ones that differ from their defaults.
  public static func report(_ settings: Settings) -> String {
    var lines = [
      "Change a setting with `set <key> <value>`, put it back with `reset <key>`. * marks the ones you changed."
    ]
    for section in SettingsSection.allCases {
      let entries = entries(in: section)
      guard !entries.isEmpty else { continue }
      lines += ["", section.title]
      for entry in entries {
        let mark = entry.isDefault(in: settings) ? " " : "*"
        let value = entry.value(in: settings).summary
        lines.append(
          "\(mark) \(entry.key) = \(value)  (\(entry.accepts); default \(entry.defaultValue.summary))")
        lines.append("      \(entry.help)\(entry.choiceNote)\(entry.commandHint)")
      }
    }
    if !settings.valueProblems.isEmpty {
      lines += ["", "Values in settings.json that Arbor could not use as written:"]
      lines += settings.valueProblems.map { "  \($0)" }
    }
    return lines.joined(separator: "\n")
  }

  /// `settings --json`: the same as a list of objects, for scripts. Every object has `key`, `section`,
  /// `level`, `label`, `help`, `kind`, `value`, `default` and `changed`; a number also `min`, `max`, `step` and
  /// `unit`, a choice `choices`, checked text `example`.
  public static func json(_ settings: Settings) -> String {
    func plain(_ value: SettingValue) -> Any {
      switch value {
      case .bool(let flag): return flag
      case .number(let number): return number
      case .text(let text): return text
      case .list(let json, _):
        return (try? JSONSerialization.jsonObject(with: Data(json.utf8), options: .fragmentsAllowed)) ?? NSNull()
      }
    }
    let objects = entries.map { entry -> [String: Any] in
      var object: [String: Any] = [
        "key": entry.key, "section": entry.section.title, "level": entry.level.rawValue, "label": entry.label,
        "help": entry.help, "value": plain(entry.value(in: settings)), "default": plain(entry.defaultValue),
        "changed": !entry.isDefault(in: settings),
      ]
      switch entry.kind {
      case .toggle:
        object["kind"] = "switch"
      case .number(let range, let step, let unit):
        object["kind"] = "number"
        object["min"] = range.lowerBound
        object["max"] = range.upperBound
        object["step"] = step
        object["unit"] = unit
      case .choice(let choices):
        object["kind"] = "choice"
        object["choices"] = choices.map { ["value": $0.value, "label": $0.label] }
      case .text(let example):
        object["kind"] = "text"
        object["example"] = example
      case .list:
        object["kind"] = "list"
      }
      return object
    }
    let options: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try? JSONSerialization.data(withJSONObject: objects, options: options)
    return data.map { String(decoding: $0, as: UTF8.self) } ?? "[]"
  }

  /// docs/SETTINGS.md (`settings --markdown`). `theSettingsDocumentIsUpToDate` keeps the file equal to this.
  public static func markdown() -> String {
    var lines = [
      "# Settings",
      "",
      "<!-- Generated from Sources/ArborCore/SettingsSchema.swift (`arborctl settings --markdown`). Do not edit:",
      "     change the schema and run the tests, which rewrite this file. -->",
      "",
      "Arbor keeps its settings in `~/Library/Application Support/Arbor/settings.json` (menu → Open Settings",
      "File). There are four ways to change one, and each takes effect at once and shows in the others:",
      "",
      "- **The settings window**: Settings… in the menu, or ⌃⌥,. It has the sections below, the settings marked",
      "  *Advanced* behind a disclosure, a search field, and panes for your shortcuts and rules. A few settings are not",
      "  in it, for the few who look for them; they are marked too.",
      "- **A command**: `arborctl set gap 16`. `arborctl get gap` prints one value, `arborctl settings` lists them",
      "  all and marks the ones you changed, `arborctl reset gap` goes back to the default, `arborctl reset all`",
      "  resets everything except your shortcuts, rules and lists of apps, and `arborctl reset everything` resets",
      "  those too. Keys ignore case, and `on`/`off`, `yes`/`no` and `1`/`0` also mean true and false. A value",
      "  outside what the table allows is refused, with the reason, and changes nothing. A command changes only its",
      "  own setting in the file; the rest stays as you wrote it, keys Arbor does not know included.",
      "- **The file**: Arbor watches it and applies an edit as soon as it is saved. Missing keys take their",
      "  defaults. A number outside its range is moved to the nearest end of it, and any other value Arbor cannot",
      "  use goes back to its default; `arborctl settings` and the log say which, and the file keeps what you wrote",
      "  until you `set` or `reset` that key. While the file is not valid JSON Arbor keeps the settings it has and",
      "  refuses commands that change settings; `arborctl reload-settings` says where the typo is. `arborctl reset",
      "  everything` is the way out: it writes a new file and keeps the old one as `settings.unreadable.json`.",
      "- **A keyboard shortcut**: `arborctl bind ctrl+opt+x set gap 0`, or `set focusRing toggle` for a switch.",
    ]
    for section in SettingsSection.allCases {
      let entries = entries(in: section)
      guard !entries.isEmpty else { continue }
      lines += [
        "", "## \(section.title)", "", "| Key | Default | Values | What it does |", "|---|---|---|---|",
      ]
      for entry in entries {
        let cells = [
          "`\(entry.key)`", "`\(entry.defaultValue.text)`", entry.accepts,
          "**\(entry.label).** \(entry.help)\(entry.choiceNote)\(entry.commandHint)\(entry.levelNote)",
        ]
        lines.append(
          "| " + cells.map { $0.replacingOccurrences(of: "|", with: "\\|") }.joined(separator: " | ") + " |")
      }
    }
    lines += [
      "",
      "Shortcuts and rules are described in the [README](../README.md#keyboard).",
    ]
    return lines.joined(separator: "\n") + "\n"
  }
}

/// Where a setting is shown: the parts of the settings window, of `settings` and of
/// docs/SETTINGS.md, in order. A section without settings is left out.
public enum SettingsSection: String, CaseIterable, Sendable, Codable {
  case general = "General"
  case windows = "Windows"
  case dragging = "Dragging"
  case tabs = "Tabs"
  case gestures = "Gestures"
  /// When Arbor holds still because others may be watching.
  case calls = "Calls"
  case appearance = "Appearance"
  case menuBar = "Menu Bar"
  /// The lists of apps.
  case apps = "Apps"
  /// What other programs may ask of Arbor. (There is no section for "the rest": a rarely needed setting stays in the
  /// section it belongs to, marked `advanced`.)
  case scripting = "Scripting"

  public var title: String { rawValue }
}

/// The value of one setting, whatever its type.
public enum SettingValue: Equatable, Sendable {
  case bool(Bool)
  case number(Double)
  case text(String)
  /// A list or table (`bindings`, `rules`, `excludedBundleIDs`): its JSON, and how many entries it has.
  case list(json: String, count: Int)

  /// What `get` prints and `set` takes: `true`, `12`, `0.3`, `shift+cmd`. Lists are JSON.
  public var text: String {
    switch self {
    case .bool(let flag): flag ? "true" : "false"
    case .number(let number): Self.format(number)
    case .text(let text): text
    case .list(let json, _): json
    }
  }

  /// `text`, except that a list is summed up by its length so it fits on a line.
  public var summary: String {
    guard case .list(_, let count) = self else { return text }
    return count == 0 ? "none" : count == 1 ? "1 entry" : "\(count) entries"
  }

  /// `12` rather than `12.0`, for any number at all: converting to an integer is only defined, and
  /// only exact, well inside the bound.
  static func format(_ number: Double) -> String {
    number == number.rounded() && abs(number) < 1e15 ? String(Int64(number)) : String(number)
  }
}

/// Why a setting could not be found or a value was refused, in words for the user.
public struct SettingError: Error, Equatable, CustomStringConvertible {
  public let description: String
  init(_ description: String) { self.description = description }

  /// `text` in backquotes, cut short: it may come from a URL or a file and ends up in messages and the log.
  static func quoted(_ text: String) -> String {
    "`\(text.count > 40 ? String(text.prefix(40)) + "…" : text)`"
  }
}

/// One setting. See `SettingsSchema`.
public struct SettingEntry: Sendable {
  public enum Kind: Equatable, Sendable {
    /// On or off.
    case toggle
    /// A number from `range`. `step` is what a slider or stepper moves by (values between steps are
    /// fine), `unit` what it is measured in ("pt", "s", or nothing for a ratio).
    case number(range: ClosedRange<Double>, step: Double, unit: String)
    /// One of a few values, in the order to offer them.
    case choice([Choice])
    /// Text that is checked when it is set. `example` is a valid value other than the default.
    case text(example: String)
    /// A list or table with commands and an editor of its own; `set` refuses it and names `editedWith`.
    case list(editedWith: String)
  }

  /// How far a setting is put forward. Whatever its level it works in `set`, `get`, `reset` and the file,
  /// and `settings` and docs/SETTINGS.md list it.
  public enum Level: String, Sendable, CaseIterable {
    /// In the settings window, in its section.
    case normal
    /// Rarely needed: the window shows it only on request.
    case advanced
    /// Not in the window at all: for the few who look for it, or not ready to be offered.
    case hidden

    init(advanced: Bool, hidden: Bool) { self = hidden ? .hidden : advanced ? .advanced : .normal }
  }

  public struct Choice: Equatable, Sendable {
    /// What settings.json holds.
    public let value: String
    /// What the settings window shows.
    public let label: String
  }

  /// The key in settings.json, which is also its name in `set` and `get`.
  public let key: String
  public fileprivate(set) var section: SettingsSection = .scripting
  /// A few words for the settings window.
  public let label: String
  /// One sentence on what it does.
  public let help: String
  public let kind: Kind
  public let level: Level
  /// Not among the settings a newcomer meets.
  public var isAdvanced: Bool { level != .normal }

  /// For a list of apps: how to read and write it as such. Nil for every other setting.
  private let appList: (WritableKeyPath<Settings, [String]> & Sendable)?
  /// For a list of apps: what to say when an app has gone on it and come off it, with %@ for the app's name.
  private var sentences: (added: String, removed: String)?
  /// For a list: what it is a list of, in the singular, to say "your 7 shortcuts".
  private var counts: String?
  /// Whether replies can say in people's words how many entries a list has.
  public var isCountedInWords: Bool { counts != nil || isAppList }
  /// For a switch: what someone who has just switched it off should hear.
  public private(set) var whenOff: String?

  private let read: @Sendable (Settings) -> SettingValue
  /// Stores a value that `validated` has passed.
  private let write: @Sendable (inout Settings, SettingValue) -> Void
  private let restoreDefault: @Sendable (inout Settings) -> Void
  /// For `.text`: the canonical spelling of valid text, nil for anything else.
  private let canonicalText: @Sendable (String) -> String?
  /// For `.text`: what valid text looks like, to complete "needs …".
  private let expects: String
  /// What the value is in JSON, to complete "not …".
  fileprivate let jsonShape: String

  // MARK: Reading

  public func value(in settings: Settings) -> SettingValue { read(settings) }

  public var defaultValue: SettingValue { read(Settings()) }

  /// Whether this is a list of apps, which `set <key> add` and `remove` change and the window shows with a menu of running
  /// apps.
  public var isAppList: Bool { appList != nil }

  /// The bundle ids on a list of apps, in the file's order. Empty for any other setting.
  public func apps(in settings: Settings) -> [String] { appList.map { settings[keyPath: $0] } ?? [] }

  /// What to say when `app` has gone on this list of apps, or come off it.
  public func sentence(about app: String, added: Bool) -> String {
    guard let sentences else { return added ? "\(app) is on \(key) now" : "\(app) is off \(key)" }
    return (added ? sentences.added : sentences.removed).replacingOccurrences(of: "%@", with: app)
  }

  /// How much is on a list, in people's words: "7 shortcuts", "1 rule", "2 apps under “Don't arrange”".
  public func tally(in settings: Settings) -> String {
    guard case .list(_, let count) = value(in: settings) else { return value(in: settings).summary }
    func some(_ noun: String) -> String { "\(count) \(noun)\(count == 1 ? "" : "s")" }
    if isAppList { return "\(some("app")) under “\(label)”" }
    return counts.map(some) ?? "\(count == 1 ? "1 entry" : "\(count) entries") of \(key)"
  }

  /// Replaces a list of apps. Does nothing to any other setting.
  public func setApps(_ apps: [String], in settings: inout Settings) {
    guard let appList else { return }
    settings[keyPath: appList] = apps
    forgetProblem(in: &settings)
  }

  public func isDefault(in settings: Settings) -> Bool { read(settings) == defaultValue }

  /// The values it takes, in a few words: `true or false`, `0 to 100 pt`, `single or double`.
  public var accepts: String {
    switch kind {
    case .toggle:
      return "true or false"
    case .number(let range, _, let unit):
      let span = "\(SettingValue.format(range.lowerBound)) to \(SettingValue.format(range.upperBound))"
      return unit.isEmpty ? span : "\(span) \(unit)"
    case .choice(let choices):
      return choices.map(\.value).joined(separator: " or ")
    case .text:
      return expects
    case .list:
      return jsonShape
    }
  }

  /// For docs/SETTINGS.md: where the settings window has it, unless it is simply there.
  fileprivate var levelNote: String {
    switch level {
    case .normal: ""
    case .advanced: " *Advanced.*"
    case .hidden: " *Not in the settings window.*"
    }
  }

  /// For a choice, what each value means, to follow `help` where values are typed. The window's menu
  /// shows the same words instead of the values, so `help` itself need not name them.
  fileprivate var choiceNote: String {
    guard case .choice(let choices) = kind else { return "" }
    return " " + choices.map { "`\($0.value)`: \($0.label)." }.joined(separator: " ")
  }

  /// For a list, a sentence on the commands that change it, to follow `help` where commands are at home.
  fileprivate var commandHint: String {
    guard case .list(let editedWith) = kind else { return "" }
    return " Change it with \(editedWith)."
  }

  /// Whether a search for `words` finds this setting: each must occur in its label, help or key,
  /// ignoring case.
  public func matches(search words: String) -> Bool {
    let text = "\(label) \(help) \(key)".lowercased()
    return words.lowercased().split(whereSeparator: \.isWhitespace).allSatisfy { text.firstRange(of: $0) != nil }
  }

  // MARK: Writing

  /// Reads a value from the text of a `set` command. Throws `SettingError` for text that is not a
  /// value of this kind, and for a value `validated` refuses.
  public func parse(_ text: String) throws -> SettingValue {
    switch kind {
    case .toggle:
      switch text.lowercased() {
      case "true", "on", "yes", "1": return .bool(true)
      case "false", "off", "no", "0": return .bool(false)
      default:
        throw SettingError(
          "`\(key)` is true or false (or on/off, yes/no, 1/0), got \(SettingError.quoted(text))")
      }
    case .number:
      guard let number = Double(text) else {
        throw SettingError("`\(key)` needs a number from \(accepts), got \(SettingError.quoted(text))")
      }
      return try validated(.number(number))
    case .choice, .text:
      return try validated(.text(text))
    case .list(let editedWith):
      throw SettingError("`\(key)` is \(jsonShape), which `set` cannot write; change it with \(editedWith)")
    }
  }

  /// `value` in its canonical form, if this setting can take it. Throws `SettingError` with the
  /// reason otherwise.
  public func validated(_ value: SettingValue) throws -> SettingValue {
    switch (kind, value) {
    case (.toggle, .bool):
      return value
    case (.number(let range, _, _), .number(let number)):
      // Not a number and the infinities compare oddly, crash conversions to Int and cannot be saved as JSON.
      guard number.isFinite else {
        throw SettingError("`\(key)` needs a finite number from \(accepts), got \(SettingValue.format(number))")
      }
      guard range.contains(number) else {
        throw SettingError("`\(key)` must be from \(accepts), got \(SettingValue.format(number))")
      }
      return value
    case (.choice(let choices), .text(let text)):
      guard let choice = choices.first(where: { $0.value.lowercased() == text.lowercased() }) else {
        throw SettingError("`\(key)` must be \(accepts), got \(SettingError.quoted(text))")
      }
      return .text(choice.value)
    case (.text, .text(let text)):
      guard let canonical = canonicalText(text) else {
        throw SettingError("`\(key)` needs \(expects), got \(SettingError.quoted(text))")
      }
      return .text(canonical)
    default:
      throw SettingError("`\(key)` takes \(accepts), got \(SettingError.quoted(value.text))")
    }
  }

  /// Stores `value` in `settings`, or throws `SettingError` and leaves them alone.
  public func set(_ value: SettingValue, in settings: inout Settings) throws {
    write(&settings, try validated(value))
    forgetProblem(in: &settings)
  }

  public func reset(in settings: inout Settings) {
    restoreDefault(&settings)
    forgetProblem(in: &settings)
  }

  /// Whether settings.json holds a value for this key that Arbor could not use as written.
  public func hasProblem(in settings: Settings) -> Bool {
    settings.valueProblems.contains { $0.hasPrefix("\(key): ") }
  }

  /// What was wrong with this key in settings.json is history once the key has been given a value.
  private func forgetProblem(in settings: inout Settings) {
    settings.valueProblems.removeAll { $0.hasPrefix("\(key): ") }
  }

  /// This setting's part of `SettingsSchema.sanitize`: nil if the value could stay.
  public func sanitize(_ settings: inout Settings) -> String? {
    if case .list = kind { return nil }  // read entry by entry when decoded, with reports of their own
    let value = read(settings)
    if let valid = try? validated(value) {
      // Text stays as the user spelt it, since what uses it parses it. A choice is compared letter for
      // letter, so `"Double"` becomes the `double` the code looks for.
      if case .choice = kind, valid != value { write(&settings, valid) }
      return nil
    }
    if case .number(let range, _, _) = kind, case .number(let number) = value, number.isFinite {
      let nearest = SettingValue.number(min(max(number, range.lowerBound), range.upperBound))
      write(&settings, nearest)
      return "\(key): \(value.text) is outside \(accepts); using \(nearest.text)"
    }
    restoreDefault(&settings)
    return
      "\(key): \(SettingError.quoted(value.text)) is not \(accepts); using the default, \(defaultValue.text)"
  }

  // MARK: Making entries

  public static func toggle(
    _ key: String, _ path: WritableKeyPath<Settings, Bool> & Sendable, _ label: String, _ help: String,
    whenOff: String? = nil, advanced: Bool = false, hidden: Bool = false
  ) -> SettingEntry {
    var entry = SettingEntry(
      key: key, label: label, help: help, kind: .toggle, level: Level(advanced: advanced, hidden: hidden),
      appList: nil,
      read: { .bool($0[keyPath: path]) },
      write: { settings, value in
        if case .bool(let flag) = value { settings[keyPath: path] = flag }
      },
      restoreDefault: { $0[keyPath: path] = Settings()[keyPath: path] },
      canonicalText: { _ in nil }, expects: "", jsonShape: "true or false")
    entry.whenOff = whenOff
    return entry
  }

  public static func number(
    _ key: String, _ path: WritableKeyPath<Settings, Double> & Sendable, min lowest: Double,
    max highest: Double, step: Double, unit: String, _ label: String, _ help: String, advanced: Bool = false, hidden: Bool = false
  ) -> SettingEntry {
    SettingEntry(
      key: key, label: label, help: help,
      // Written the wrong way round, the bounds would crash `...`; a test checks they are in order.
      kind: .number(range: Swift.min(lowest, highest)...Swift.max(lowest, highest), step: step, unit: unit),
      level: Level(advanced: advanced, hidden: hidden),
      appList: nil,
      read: { .number($0[keyPath: path]) },
      write: { settings, value in
        if case .number(let number) = value { settings[keyPath: path] = number }
      },
      restoreDefault: { $0[keyPath: path] = Settings()[keyPath: path] },
      canonicalText: { _ in nil }, expects: "", jsonShape: "a number")
  }

  /// `choices` maps each value to its label in the settings window, in the order to offer them.
  public static func choice(
    _ key: String, _ path: WritableKeyPath<Settings, String> & Sendable,
    _ choices: KeyValuePairs<String, String>,
    _ label: String, _ help: String, advanced: Bool = false, hidden: Bool = false
  ) -> SettingEntry {
    SettingEntry(
      key: key, label: label, help: help, kind: .choice(choices.map { Choice(value: $0.key, label: $0.value) }),
      level: Level(advanced: advanced, hidden: hidden),
      appList: nil,
      read: { .text($0[keyPath: path]) },
      write: { settings, value in
        if case .text(let text) = value { settings[keyPath: path] = text }
      },
      restoreDefault: { $0[keyPath: path] = Settings()[keyPath: path] },
      canonicalText: { _ in nil }, expects: "", jsonShape: "text")
  }

  /// - Parameters:
  ///   - example: a valid value other than the default, shown as a hint.
  ///   - expects: what valid text looks like, completing "needs …".
  ///   - canonical: the canonical spelling of valid text, nil for text that is not valid.
  public static func text(
    _ key: String, _ path: WritableKeyPath<Settings, String> & Sendable, example: String, expects: String,
    canonical: @escaping @Sendable (String) -> String?, _ label: String, _ help: String, advanced: Bool = false, hidden: Bool = false
  ) -> SettingEntry {
    SettingEntry(
      key: key, label: label, help: help, kind: .text(example: example), level: Level(advanced: advanced, hidden: hidden),
      appList: nil,
      read: { .text($0[keyPath: path]) },
      write: { settings, value in
        if case .text(let text) = value { settings[keyPath: path] = text }
      },
      restoreDefault: { $0[keyPath: path] = Settings()[keyPath: path] },
      canonicalText: canonical, expects: expects, jsonShape: "text")
  }

  /// A list of apps, by bundle id. `set <key> add <app>` and `set <key> remove <app>` change it and the window has a
  /// control for it, so it needs no commands or editor of its own; `alsoEditedWith` names the commands it has anyway.
  /// `added` and `removed` are the replies, in people's words, with %@ for the app's name.
  public static func apps(
    _ key: String, _ path: WritableKeyPath<Settings, [String]> & Sendable, alsoEditedWith others: String? = nil,
    added: String, removed: String, _ label: String, _ help: String, advanced: Bool = false, hidden: Bool = false
  ) -> SettingEntry {
    var entry = list(
      key, path, shape: "a list of bundle ids",
      editedWith: "`set \(key) add <app>` and `set \(key) remove <app>`" + (others.map { ", or \($0)" } ?? ""), label,
      help, advanced: advanced, hidden: hidden, appList: path)
    entry.sentences = (added, removed)
    return entry
  }

  /// - Parameters:
  ///   - shape: what it is in JSON, completing "is …" and "not …".
  ///   - editedWith: the commands that change it.
  ///   - counts: what it is a list of, in the singular ("shortcut"), for replies that say how many there are.
  public static func list<Value: Collection & Encodable & Sendable>(
    _ key: String, _ path: WritableKeyPath<Settings, Value> & Sendable, shape: String, editedWith: String,
    counts: String? = nil, _ label: String, _ help: String, advanced: Bool = false, hidden: Bool = false
  ) -> SettingEntry {
    var entry = list(
      key, path, shape: shape, editedWith: editedWith, label, help, advanced: advanced, hidden: hidden, appList: nil)
    entry.counts = counts
    return entry
  }

  private static func list<Value: Collection & Encodable & Sendable>(
    _ key: String, _ path: WritableKeyPath<Settings, Value> & Sendable, shape: String, editedWith: String,
    _ label: String, _ help: String, advanced: Bool, hidden: Bool,
    appList: (WritableKeyPath<Settings, [String]> & Sendable)?
  ) -> SettingEntry {
    SettingEntry(
      key: key, label: label, help: help, kind: .list(editedWith: editedWith), level: Level(advanced: advanced, hidden: hidden),
      appList: appList,
      read: { settings in
        let value = settings[keyPath: path]
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let json = (try? encoder.encode(value)).map { String(decoding: $0, as: UTF8.self) }
        return .list(json: json ?? "null", count: value.count)
      },
      write: { _, _ in },
      restoreDefault: { $0[keyPath: path] = Settings()[keyPath: path] },
      canonicalText: { _ in nil }, expects: "", jsonShape: shape)
  }
}
