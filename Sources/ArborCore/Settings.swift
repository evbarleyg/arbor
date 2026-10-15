import CoreGraphics

/// User settings, stored as `settings.json` in Arbor's home folder. Every key
/// is optional when decoding, so a hand-edited file with missing or extra
/// keys still loads; missing keys take their defaults. A value of the wrong
/// type or outside what `SettingsSchema` allows costs only its own key.
///
/// Every key also needs an entry in `SettingsSchema`, which gives it its range, its help text, the
/// `set` and `get` commands and its place in the settings window.
public struct Settings: Codable, Equatable, Sendable {
  /// Space between docked windows, and between them and the screen edges.
  public var gap: Double = 12
  /// Nodes smaller than this become tiles showing the app colour and icon.
  public var minimumUsableWidth: Double = 240
  public var minimumUsableHeight: Double = 160
  /// How close to a screen edge a dragged window's pointer must be to dock there. 0: none ever does.
  public var screenEdgeBand: Double = 12
  /// The band along a window's edges (fraction of its size) that docks beside it. 0: none ever does.
  public var windowEdgeFraction: Double = 0.3
  /// Dropping a window on the middle of another stacks them as tabs. There is
  /// no tab strip yet (see docs/features/F04-tab-groups.md), so this is off.
  public var tabsEnabled: Bool = false
  /// Bundle IDs Arbor never arranges.
  public var excludedBundleIDs: [String] = []
  /// Global keyboard shortcuts (⌃⌥ by default; see KeyBindings.swift).
  public var hotkeysEnabled: Bool = true
  /// Width of the Desktop column created by `arrange`, relative to a window column.
  public var arrangeDesktopWeight: Double = 0.5
  /// Changes to the keyboard shortcuts, chord to command text: `"ctrl+opt+h": "dock left"`. A null
  /// command removes that chord's default. See `KeyBindings.effective(settings:)`.
  public var bindings: [String: String?] = [:]
  /// Chords in `bindings` whose value was neither command text nor null. They are reported and
  /// skipped rather than making the whole file invalid, and are not written back.
  public internal(set) var unreadableBindings: [String] = []
  /// What happens to new windows of particular apps, checked in order; the
  /// first match wins. See AppRule.swift.
  public var rules: [AppRule] = []
  /// Why entries of `rules` in settings.json were skipped, e.g.
  /// "entry 3 (com.apple.Notes): `action` is missing". Filled in when
  /// decoding and never saved; Arbor logs them and the `rules` command shows them.
  public internal(set) var skippedRules: [String] = []
  /// Values in settings.json that could not be used as written, and what Arbor uses instead, e.g.
  /// "gap: -500 is outside 0 to 100 pt; using 0". Filled in when decoding and never saved;
  /// Arbor logs them and the `settings` command shows them.
  public internal(set) var valueProblems: [String] = []
  /// Trackpad pinch with ⌥ held, or over the Desktop, steps the camera in and out.
  public var gesturesEnabled: Bool = true
  /// Pinch travel for one step, in the trackpad's magnification units (the
  /// sum of the magnify events' deltas); smaller is more sensitive.
  public var pinchThreshold: Double = 0.25
  /// The modifiers to hold while dragging a rectangle to frame, e.g.
  /// `ctrl+opt`, `shift+cmd`, `⌃⌥`; `none` turns rectangle framing off. ⌃⌥ is Arbor's, with the pointer too
  /// (docs/KEYBOARD.md); ⇧⌘, the default until 2026-10-14, is what design tools select with.
  public var frameRectangleModifier: String = "ctrl+opt"
  /// Accept every command from `arbor://` URLs. Off, URLs can only move the camera and arrange
  /// windows (`Command.isAllowedFromURL`), because any web page or document can open a URL.
  public var allowAllURLCommands: Bool = false
  /// Draws a line around the window that has the keyboard, if Arbor arranges it (FocusRing.swift).
  public var focusRing: Bool = true
  /// The line's thickness in points, 1 to 12.
  public var focusRingWidth: Double = 3
  /// `accent` (the accent colour of System Settings), `#RRGGBB` or `#RRGGBBAA`.
  public var focusRingColour: String = "accent"
  /// The radius of the window corners the line follows. 0 picks the radius of the macOS Arbor runs
  /// on: 17 on macOS 26, 10 before.
  public var focusRingRadius: Double = 0
  /// Seconds a new window's title is checked against rules that have a `title`. Browsers and
  /// editors set the real title a moment after the window opens. 0 checks only the first title;
  /// more than 60 counts as 60.
  public var ruleTitleWait: Double = 2
  /// While a window like one of these is open Arbor holds still, as after `hold still`: the view
  /// moves only when asked. Each entry is a bundle id, optionally followed by text the title must
  /// contain (`HoldPattern`). macOS does not tell apps whether the screen is being shared or
  /// recorded, so a call's window is the nearest thing to a sign of it. Empty, which turns this off: out of the box Arbor
  /// holds only when asked. For example "us.zoom.xos Zoom Meeting", written from memory: nobody has read that title off a Mac yet.
  /// An entry without title text matches any window of the app, minimized ones too, all day: good for few apps.
  public var holdStillFor: [String] = []
  /// Hold still while any app has a camera running, whichever app and in whichever window the call is. Off: a camera that is on
  /// is not a screen that is shared, and a sensor that has not been seen at work on a Mac must not start by itself, in every
  /// call, a state that turns the person's own launcher away.
  public var holdStillWhileCameraIsOn: Bool = false
  /// The same for a microphone. Only devices that are microphones and nothing else count: a headset that is
  /// one device for both directions is "running" while it plays music. Off until two things have been seen on a Mac
  /// (docs/TESTING.md): that "Hey Siri" and dictation do not count as a call, and that muting does not end one.
  public var holdStillWhileMicrophoneIsOn: Bool = false
  /// The menu bar item shows buttons for back, forward, the Desktop, everything and each saved view;
  /// right-click it for the menu. False shows a single icon that opens the menu.
  public var menuBarControls: Bool = true
  /// Whether those buttons include back and forward.
  public var historyButtons: Bool = true
  /// How opaque the background of the button for where you are is, from 0 to 1.
  public var menuBarFill: Double = 0.25
  /// How long camera moves and layout changes take to play, in seconds; 0 applies them at once.
  /// macOS's "Reduce motion" turns the motion off as well. See `motionDuration`.
  public var animationDuration: Double = 0.46
  /// A summoned window stays over the view when the keyboard goes to another window, until it is
  /// summoned away. Off, turning to another window sends it out of view.
  public var summonStays: Bool = false

  /// What happens to a new window that opens over a view that does not show the Desktop, when no rule says
  /// otherwise: `"guest"`, it floats and goes out of view and comes back with that view; `"float"`, it belongs to
  /// the Desktop like any floating window. See docs/features/F57-new-windows-while-framed.md.
  public var newWindowsWhileFramed: String = "guest"
  /// ⇧-drag that starts where no app's window is under the pointer (the Desktop, a gap between
  /// windows, a tile) also draws a rectangle to frame.
  public var frameRectangleOnDesktop: Bool = true
  /// The view follows the fingers during a pinch, and pans with ⌥ and two fingers, instead of
  /// stepping a level at a time (F16).
  public var continuousZoom: Bool = false
  /// A window that is a tile because it once refused the size of its slot is asked again, out of view, when the
  /// display is next laid out and this many minutes have passed. 0 never asks; `relayout` always does.
  public var tileRetryMinutes: Double = 10
  /// What a shortcut (or `arborctl`, or a URL) follows when it has to choose a display, and a space for
  /// `in` to step toward: `auto` (the focused window, or the pointer if it has moved since the last key
  /// press or focus change), `pointer` or `focus`. Gestures always follow the pointer. See InputLead.swift.
  public var stepInToward: String = "auto"
  /// Holding the Show Everything shortcut peeks: everything shows while the keys are down, and letting go
  /// frames the outlined space. Off, the shortcut does the same held as tapped. See Peek.swift.
  public var peek: Bool = true
  /// Apps (bundle ids) that keep their own ⌃⌥: while one of them is frontmost Arbor gives up its shortcuts
  /// and pointer gestures, and goes on arranging windows. See AppLists.swift and `pass-through`.
  public var passThroughApps: [String] = []
  /// Apps (bundle ids) Arbor pauses for, as by `pause`, for as long as one of them is frontmost.
  public var pauseForApps: [String] = []
  /// A letter, digit or sign in a shortcut means the key that types it on the keyboard layout in use, as in
  /// ⌘-shortcuts. Off, it means the key's position on a US keyboard, whatever the layout (KeyLayout.swift).
  public var shortcutsFollowLayout: Bool = true
  /// While something is docked on a display, a plain click on bare Desktop there is kept from macOS,
  /// which would sweep every window aside ("Click wallpaper to reveal desktop"). Drags, icons
  /// and widgets are left alone (F60). Off until it has been seen at work on a Mac.
  public var guardDesktopClicks: Bool = false
  /// Ask GitHub for a newer release a minute after starting and once a week from then on. Off by
  /// default: Arbor uses the network only when asked to. `check-for-updates` works either way.
  public var automaticUpdateChecks: Bool = false
  /// How long, in seconds, a dragged window's pointer must rest on a window or tile before it can
  /// be dropped there (0 to 2; 0 is at once). Screen edges never wait, and nothing waits without `previewDrags`.
  public var dropDwell: Double = 0.15
  /// While a window is dragged, the other windows move to show the arrangement that letting go
  /// would produce: they close up when it leaves its slot and make room where it would land.
  public var reflowWhileDragging: Bool = false
  /// With `reflowWhileDragging`: floating windows pushed off docked space stay where they were
  /// pushed until the drag ends, instead of moving back and forth as the target changes.
  public var keepPushed: Bool = true
  /// Show where a dragged window would land.
  public var previewDrags: Bool = true
  /// Before a window becomes a tile because its slot is smaller than the window will go, move the gaps around
  /// it and take the missing points from the Desktop and from neighbours that can spare them (F61).
  public var makeRoom = true
  /// A window that floats alone on a display where something is docked takes the whole Desktop, and gets its
  /// own frame back as soon as it has company (docs/features/F18-sole-floating-window.md).
  public var soleFloatTakesDesktop: Bool = false
  /// Options for particular displays, checked in order; the first match wins, key by key. See DisplayOptions.swift.
  public var displays: [DisplayOptions] = []
  /// Why entries of `displays` in settings.json were skipped, e.g. "entry 2 (>=wide): …". Filled in when
  /// decoding and never saved; Arbor logs them and the `displays` command shows them.
  public internal(set) var skippedDisplays: [String] = []
  /// Their places in the file, counted from 1, for the log. Empty if `displays` is not a list at all.
  public internal(set) var skippedDisplayNumbers: [Int] = []
  /// How much Arbor says in a line on screen after a shortcut, a gesture or a menu item: `helpful` (what went
  /// wrong, what changed unseen, and a few hints for newcomers), `all` (every reply) or `off`. See HeadsUp.swift.
  public var messages: String = "helpful"
  /// How much the wallpaper is darkened behind docked windows, from 0 (not at all) to 1 (black), so
  /// that the docked area reads as one surface. This and the five keys below are read through
  /// `appearanceOptions` (Appearance.swift).
  public var dimBehindArranged: Double = 0.25
  /// Blur of the wallpaper in the same area, from 0 (none) to 1 (all the blur macOS has to give).
  public var blurBehindArranged: Double = 0
  /// Tiles take on their app's colour; false gives every tile the same grey.
  public var appColours: Bool = true
  /// How much of the app's colour goes into a tile, from 0 to 1.
  public var appColourAmount: Double = 0.25
  /// The gaps between docked windows: `shown` (drag one to resize both sides; a handle appears in it under the
  /// pointer), `hidden` (the same without the handle) or `off` (gaps cannot be dragged).
  public var gapHandles: String = "shown"
  /// What a tile shows: `icon` (the app's icon), `name` (the icon and the app's name) or `plain` (only the colour).
  public var tileStyle: String = "icon"
  /// Windows keep their contents while they move: their stand-ins are still pictures of them, if macOS lets Arbor take
  /// any (Screen Recording permission). Off, they travel as their app's colour and icon whatever macOS allows, and no
  /// picture is ever taken. Off until the pictures have been seen to work on a Mac: they once crashed
  /// Arbor, and the fix has not run since.
  public var windowPictures = false
  /// How many points `grow` and `shrink` add or take when the command gives no amount.
  public var resizeStep: Double = 40
  /// How much of the accent colour is laid over the wallpaper behind docked windows, from 0 (none) to 1. This and
  /// the two keys below are read through `appearanceOptions` too (docs/features/F36-appearance-leftovers.md).
  public var tintBehindArranged: Double = 0
  /// How strong the hairline around the Desktop is where it lies between docked windows, from 0 (none) to 1.
  public var desktopEdge: Double = 0.05
  /// Seconds a tile takes to fade in and out, from 0 (at once) to 1.
  public var tileFade: Double = 0.2
  /// Scrolling with ⌃⌥ held zooms: up steps in toward the pointer, down steps out (F55). Off with `gesturesEnabled`.
  public var scrollZoom: Bool = true
  /// Points of travel for one step on a Magic Mouse or trackpad. A wheel steps once per notch.
  public var scrollZoomThreshold: Double = 40
  /// Scrolling where no app's window is under the pointer zooms without the keys, as a pinch there does. Every scroll on
  /// the Mac then passes through Arbor, and each notch of a wheel reads the window list.
  public var scrollOnDesktopZooms: Bool = false
  /// What happens to a new window that no entry of `rules` matches: `"float"`, it stays where its app put it, or
  /// `"dock"`, it docks beside the focused window. `"dock"` is short for a last rule
  /// `{"app": "*", "action": "dock auto"}` (AutoDock.swift). Anything else means `"float"`.
  public var newWindows: String = "float"
  /// A window that opens smaller than this is never docked by `dock auto` or by a rule for `*`: inspectors,
  /// palettes and small dialogs are not worth a place in the arrangement.
  public var autoDockMinimumWidth: Double = 400
  public var autoDockMinimumHeight: Double = 300
  /// How long the minimap shows after the view has moved, in seconds, at most 10. 0, the default, turns that off;
  /// `minimap` shows it either way (Minimap.swift).
  public var minimapDuration: Double = 0
  /// The space of a window that leaves (closed, floated, dragged out, minimized, hidden, on another
  /// Space) is shared by its whole group. Off: it goes to the neighbour before it (after it, for the
  /// first in the group) and nothing else moves.
  public var shareRemovedSpace: Bool = true
  /// Windows moved out of view are also shrunk (to 320 × 200 at most) until they come back.
  public var shrinkOutOfView: Bool = false
  /// A trial (collab/QUESTIONS.md, Q29, point 8): a window that is not in the framed space stays where it is, behind what is, and is
  /// not sent to the display's corner. Only what its person sent away still goes there (Controller+Behind.swift).
  public var outOfViewIsBehind: Bool = false
  /// The one switch for whatever needs an event tap: the pinch, ⌃⌥ + scroll, the ⌃⌥ rectangle, ⇧-drag on the Desktop, the guard of
  /// the wallpaper click. Off, Arbor installs no event tap, whatever their own settings say (`Controller.inputSettings`). A key of
  /// its own because a settings.json written by an earlier build holds theirs as they were then, and cannot hold this one
  /// (collab/QUESTIONS.md, Q26).
  /// Off as Arbor ships: no tap goes in at launch until all its checks of the taps on a Mac are green.
  public var pointerGestures: Bool = false

  public init() {}

  /// These settings as they are in effect on `display`: what the entries of `displays` give it
  /// (`DisplayOptions.given`) replaces the general values. Everything that depends on the display
  /// (`layoutOptions`, `dropOptions`) is then read from the result as usual.
  public func applying(to display: DisplayTraits) -> Settings {
    guard !displays.isEmpty else { return self }
    var settings = self
    for given in DisplayOptions.given(by: displays, to: display) {
      guard let key = DisplayOptions.keys.first(where: { $0.name == given.key }) else { continue }
      settings[keyPath: key.setting] = given.value
    }
    return settings
  }

  public var layoutOptions: LayoutOptions {
    LayoutOptions(
      gap: CGFloat(gap),
      minimumUsableSize: CGSize(width: minimumUsableWidth, height: minimumUsableHeight),
      shareRemovedSpace: shareRemovedSpace)
  }

  /// `animationDuration` kept between 0 and 2 seconds. A value that is not a number counts as the default.
  public var motionDuration: Double {
    guard animationDuration.isFinite else { return Settings().animationDuration }
    return min(max(animationDuration, 0), 2)
  }

  public var dropOptions: DropOptions {
    DropOptions(
      screenEdgeBand: CGFloat(screenEdgeBand), windowEdgeFraction: CGFloat(windowEdgeFraction),
      tabsEnabled: tabsEnabled,
      // Without the preview nothing would show when the hold is over, so there is none. Not a number would
      // crash the timer that waits this long.
      dwell: !previewDrags ? 0 : dropDwell.isFinite ? min(max(dropDwell, 0), 2) : DropOptions().dwell)
  }

  private enum CodingKeys: String, CodingKey {
    case gap, minimumUsableWidth, minimumUsableHeight, screenEdgeBand, windowEdgeFraction
    case tabsEnabled, excludedBundleIDs, hotkeysEnabled, arrangeDesktopWeight
    case bindings
    case rules
    case gesturesEnabled, pinchThreshold, frameRectangleModifier
    case allowAllURLCommands
    case focusRing, focusRingWidth, focusRingColour, focusRingRadius
    case ruleTitleWait
    case newWindowsWhileFramed
    case frameRectangleOnDesktop
    case continuousZoom
    case menuBarControls, historyButtons, menuBarFill
    case tileRetryMinutes
    case stepInToward
    case peek
    case passThroughApps, pauseForApps
    case shortcutsFollowLayout
    case holdStillFor, holdStillWhileCameraIsOn, holdStillWhileMicrophoneIsOn
    case guardDesktopClicks
    case animationDuration
    case automaticUpdateChecks
    case summonStays
    case dropDwell, reflowWhileDragging, keepPushed, previewDrags
    case makeRoom
    case soleFloatTakesDesktop
    case displays
    case messages
    case dimBehindArranged, blurBehindArranged, appColours, appColourAmount, gapHandles, tileStyle
    case windowPictures
    case resizeStep
    case tintBehindArranged, desktopEdge, tileFade
    case scrollZoom, scrollZoomThreshold, scrollOnDesktopZooms
    case newWindows, autoDockMinimumWidth, autoDockMinimumHeight
    case minimapDuration
    case shareRemovedSpace, shrinkOutOfView, outOfViewIsBehind
    case pointerGestures
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    var problems: [String] = []
    // Deferred so that it stays after the last `read`, where features add theirs: once every key
    // is in, the schema brings the values into their ranges.
    defer {
      problems += SettingsSchema.sanitize(&self)
      valueProblems = problems
    }
    /// A missing key keeps the default its property is declared with, and so does one whose value has
    /// the wrong type (`"gap": "12"`): a slip in one line must not cost the user the rest of the
    /// file. One line per key.
    func read<T: Decodable>(_ key: CodingKeys, into value: inout T) throws {
      do {
        if let decoded = try c.decodeIfPresent(T.self, forKey: key) { value = decoded }
      } catch {
        // Any error: for `1e999` Foundation throws one of its own, which becomes a `DecodingError` only
        // on its way out of `decode`.
        problems.append(SettingsSchema.wrongTypeProblem(key: key.stringValue))
      }
    }
    try read(.gap, into: &gap)
    try read(.minimumUsableWidth, into: &minimumUsableWidth)
    try read(.minimumUsableHeight, into: &minimumUsableHeight)
    try read(.screenEdgeBand, into: &screenEdgeBand)
    try read(.windowEdgeFraction, into: &windowEdgeFraction)
    try read(.tabsEnabled, into: &tabsEnabled)
    try read(.excludedBundleIDs, into: &excludedBundleIDs)
    try read(.hotkeysEnabled, into: &hotkeysEnabled)
    try read(.arrangeDesktopWeight, into: &arrangeDesktopWeight)
    var bindingsObject = BindingsObject()
    try read(.bindings, into: &bindingsObject)
    bindings = bindingsObject.entries
    unreadableBindings = bindingsObject.unreadable
    // Read rule by rule: one bad rule is skipped instead of failing the file.
    let ruleList = try c.decodeIfPresent(RuleList.self, forKey: .rules) ?? RuleList()
    rules = ruleList.rules
    skippedRules = ruleList.skipped
    try read(.gesturesEnabled, into: &gesturesEnabled)
    try read(.pinchThreshold, into: &pinchThreshold)
    try read(.frameRectangleModifier, into: &frameRectangleModifier)
    try read(.allowAllURLCommands, into: &allowAllURLCommands)
    try read(.focusRing, into: &focusRing)
    try read(.focusRingWidth, into: &focusRingWidth)
    try read(.focusRingColour, into: &focusRingColour)
    try read(.focusRingRadius, into: &focusRingRadius)
    try read(.ruleTitleWait, into: &ruleTitleWait)
    try read(.newWindowsWhileFramed, into: &newWindowsWhileFramed)
    try read(.frameRectangleOnDesktop, into: &frameRectangleOnDesktop)
    try read(.continuousZoom, into: &continuousZoom)
    try read(.menuBarControls, into: &menuBarControls)
    try read(.historyButtons, into: &historyButtons)
    try read(.menuBarFill, into: &menuBarFill)
    try read(.tileRetryMinutes, into: &tileRetryMinutes)
    try read(.stepInToward, into: &stepInToward)
    try read(.peek, into: &peek)
    try read(.passThroughApps, into: &passThroughApps)
    try read(.pauseForApps, into: &pauseForApps)
    try read(.shortcutsFollowLayout, into: &shortcutsFollowLayout)
    try read(.holdStillFor, into: &holdStillFor)
    try read(.holdStillWhileCameraIsOn, into: &holdStillWhileCameraIsOn)
    try read(.holdStillWhileMicrophoneIsOn, into: &holdStillWhileMicrophoneIsOn)
    try read(.guardDesktopClicks, into: &guardDesktopClicks)
    try read(.animationDuration, into: &animationDuration)
    try read(.automaticUpdateChecks, into: &automaticUpdateChecks)
    try read(.summonStays, into: &summonStays)
    try read(.dropDwell, into: &dropDwell)
    try read(.reflowWhileDragging, into: &reflowWhileDragging)
    try read(.keepPushed, into: &keepPushed)
    try read(.previewDrags, into: &previewDrags)
    try read(.makeRoom, into: &makeRoom)
    try read(.soleFloatTakesDesktop, into: &soleFloatTakesDesktop)
    try read(.resizeStep, into: &resizeStep)
    // Read entry by entry, like the rules.
    let displayList = try c.decodeIfPresent(DisplayOptionsList.self, forKey: .displays) ?? DisplayOptionsList()
    displays = displayList.entries
    skippedDisplays = displayList.skipped
    skippedDisplayNumbers = displayList.skippedNumbers
    try read(.messages, into: &messages)
    try read(.dimBehindArranged, into: &dimBehindArranged)
    try read(.blurBehindArranged, into: &blurBehindArranged)
    try read(.appColours, into: &appColours)
    try read(.appColourAmount, into: &appColourAmount)
    // It was a switch for a short while: true is `shown`, false is `off`.
    if let flag = try? c.decodeIfPresent(Bool.self, forKey: .gapHandles) {
      gapHandles = flag ? "shown" : "off"
    } else {
      try read(.gapHandles, into: &gapHandles)
    }
    try read(.tileStyle, into: &tileStyle)
    try read(.windowPictures, into: &windowPictures)
    try read(.tintBehindArranged, into: &tintBehindArranged)
    try read(.desktopEdge, into: &desktopEdge)
    try read(.tileFade, into: &tileFade)
    try read(.scrollZoom, into: &scrollZoom)
    try read(.scrollZoomThreshold, into: &scrollZoomThreshold)
    try read(.scrollOnDesktopZooms, into: &scrollOnDesktopZooms)
    try read(.newWindows, into: &newWindows)
    try read(.autoDockMinimumWidth, into: &autoDockMinimumWidth)
    try read(.autoDockMinimumHeight, into: &autoDockMinimumHeight)
    try read(.minimapDuration, into: &minimapDuration)
    try read(.shareRemovedSpace, into: &shareRemovedSpace)
    try read(.shrinkOutOfView, into: &shrinkOutOfView)
    try read(.outOfViewIsBehind, into: &outOfViewIsBehind)
    try read(.pointerGestures, into: &pointerGestures)
  }
}
