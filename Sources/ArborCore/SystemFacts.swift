/// What only macOS can tell: permissions, system settings, who else is running, and what the app
/// managed to install. Nothing above the platform seams can read any of it, so the app fills one
/// in whenever it is asked (`Controller.systemFacts`), and `doctor` and the welcome window are
/// built from it. Tests make them up.
public struct SystemFacts: Equatable, Sendable {
  public var accessibility: Bool
  public var screenRecording: Bool
  /// The settings under Desktop & Dock that are on and that Arbor has something to say about. Nil if they cannot be read.
  public var switches: [MacSwitch]?
  /// "Displays have separate Spaces" in System Settings. Nil if it cannot be read.
  public var separateSpaces: Bool?
  public var voiceOver: Bool
  /// How many keyboard input sources the Input menu switches between. Nil if it cannot be read.
  public var inputSources: Int?
  /// The names of running apps that get in Arbor's way (`CompetingApp`).
  public var competingApps: [String]
  /// Whether Arbor opens at login. Nil where it cannot (it runs outside its bundle).
  public var opensAtLogin: Bool?
  /// `ARBOR_NO_HOTKEYS` is set: no shortcuts and no event taps, on purpose.
  public var inputDisabled: Bool
  /// The names of the event taps installed now, e.g. `pinch`.
  public var eventTaps: [String]

  public init(
    accessibility: Bool, screenRecording: Bool, switches: [MacSwitch]?, separateSpaces: Bool? = nil,
    voiceOver: Bool = false, inputSources: Int? = nil, competingApps: [String] = [], opensAtLogin: Bool? = nil,
    inputDisabled: Bool = false, eventTaps: [String] = []
  ) {
    self.accessibility = accessibility
    self.screenRecording = screenRecording
    self.switches = switches
    self.separateSpaces = separateSpaces
    self.voiceOver = voiceOver
    self.inputSources = inputSources
    self.competingApps = competingApps
    self.opensAtLogin = opensAtLogin
    self.inputDisabled = inputDisabled
    self.eventTaps = eventTaps
  }
}

/// The settings under System Settings → Desktop & Dock that make macOS react to the same clicks and drags
/// as Arbor, or move windows itself (docs/features/F42-setup-check.md).
public enum MacSwitch: String, CaseIterable, Sendable {
  /// A click on the wallpaper sweeps every window aside. Seen on macOS 26.6: the window server moves them and
  /// Accessibility reports nothing, so Arbor goes on believing them in their places.
  case clickWallpaper
  case screenEdges, menuBar, optionKey
  case stageManager

  /// Its key in the `com.apple.WindowManager` defaults.
  public var defaultsKey: String {
    switch self {
    case .clickWallpaper: "EnableStandardClickToShowDesktop"
    case .screenEdges: "EnableTilingByEdgeDrag"
    case .menuBar: "EnableTopTilingByEdgeDrag"
    case .optionKey: "EnableTilingOptionAccelerator"
    case .stageManager: "GloballyEnabled"
    }
  }

  /// What a missing key means: macOS writes one only when the user changes the setting.
  var isOnByDefault: Bool { self != .stageManager }

  /// Whether, switched on, it is in Arbor's way at all. The click on the wallpaper is not (collab/QUESTIONS.md, Q24): a sweep is only a
  /// picture, Accessibility keeps every true frame, and the next click brings the windows back. It is something to know.
  public var isInArborsWay: Bool { self != .clickWallpaper }

  /// Whether Arbor offers to switch it off for a person (`fix-setup`). As little as possible: macOS's tiling, which is on as a Mac comes and
  /// which hardly anybody chose. Stage Manager is off as a Mac comes: whoever has it on wanted it, and switching it off rearranges their windows.
  public var canBeSwitchedOffForYou: Bool { isInArborsWay && isOnByDefault }

  /// The first macOS that has it.
  var since: Int {
    switch self {
    case .stageManager: 13
    case .clickWallpaper: 14
    case .screenEdges, .menuBar, .optionKey: 15
    }
  }

  /// Its label in System Settings.
  public var label: String {
    switch self {
    case .clickWallpaper: "Click wallpaper to reveal desktop"
    case .screenEdges: "Drag windows to left or right edge of screen to tile"
    case .menuBar: "Drag windows to menu bar to fill screen"
    case .optionKey: "Hold ⌥ key while dragging windows to tile"
    case .stageManager: "Stage Manager"
    }
  }

  /// The label and what to do about it, as one line of a list.
  public var advice: String {
    switch self {
    case .clickWallpaper: "“\(label)”: choose “Only in Stage Manager”. Otherwise a click on the Desktop sends every window away"
    case .screenEdges, .menuBar, .optionKey: "“\(label)”: switch it off"
    case .stageManager: "“\(label)”: switch it off. It moves windows itself, so use one or the other"
    }
  }

  /// The ones in Arbor's way on this Mac.
  /// - Parameters:
  ///   - macOS: the major version, e.g. 15.
  ///   - read: the value stored under a defaults key, nil if there is none.
  public static func inTheWay(macOS: Int, read: (String) -> Bool?) -> [MacSwitch] {
    allCases.filter { macOS >= $0.since && (read($0.defaultsKey) ?? $0.isOnByDefault) }
  }
}

/// Apps that cannot share a Mac with Arbor quietly: they use the same ⌃⌥ shortcuts (both react, or
/// one silently wins), or they arrange windows themselves (docs/KEYBOARD.md, "Conflicts").
public enum CompetingApp {
  private static let names: [String: String] = [
    "com.knollsoft.rectangle": "Rectangle",
    "com.knollsoft.hookshot": "Rectangle Pro",
    "com.crowdcafe.windowmagnet": "Magnet",
    "com.amethyst.amethyst": "Amethyst",
    "bobko.aerospace": "AeroSpace",
    "com.manytricks.moom": "Moom",
    "com.hegenberg.bettersnaptool": "BetterSnapTool",
    "com.mrkai77.loop": "Loop",
    "co.highlyopinionated.swish": "Swish",
  ]

  /// The name to show for a running app if it is one of them, otherwise nil.
  /// - Parameter executable: the name of the file that runs, for what is no app and so has no bundle id.
  public static func name(bundleID: String?, appName: String?, executable: String? = nil) -> String? {
    if let bundleID, let known = names[bundleID.lowercased()] { return known }
    if executable == "yabai" || appName == "yabai" { return "yabai" }
    // Its bundle id is not published, so go by its name.
    if appName == "TrellisWM" || bundleID?.lowercased().firstRange(of: "trelliswm") != nil { return "TrellisWM" }
    return nil
  }
}

/// A fact that is dear to read and seldom changes, kept for as long as something cheap to read stays what it was.
///
/// The welcome window reads the facts about the Mac once a second for as long as it is open, which can be all day. Asking macOS
/// about every running app each time kept Arbor at over 1 % of a core with nothing happening; how many there are says nearly
/// as well whether anybody has come or gone. No notice has to arrive for this to notice, so none can be lost.
public struct KeptFact<Key: Equatable, Value> {
  private var kept: (key: Key, value: Value)?

  public init() {}

  /// What `read` answered when `key` last changed, or answers now.
  public mutating func value(for key: Key, read: () -> Value) -> Value {
    if let kept, kept.key == key { return kept.value }
    let value = read()
    kept = (key, value)
    return value
  }

  /// The next question is passed on, whatever the key.
  public mutating func forget() { kept = nil }
}
