import ArborCore
import Foundation

/// **A word that is added changes no old walk.** A walk draws its commands and the settings it changes from lists, so one more entry used to send
/// every seed another way: whoever added a command met, in their own pull request, faults of the trunk that had nothing to do with it.
///
/// So the lists are frozen, version by version, and a seed says which version it draws from: 0 to 999,999 the first, 1,000,000 to 1,999,999 the first
/// two, and so on. Seeds beyond the last frozen version draw from everything there is, also from what no version lists yet: **those are
/// the seeds for hunting, and they do move**. The tests walk frozen seeds only.
///
/// Adding a command or a setting needs nothing here. A new kind of act, or a new weight, in `next` or `ordinaryNext` gets its weight only where
/// `drawsFromEverything` is true, and 0 elsewhere: an entry of weight 0 changes no draw. The keeper of the lab freezes a new version now and then: a new row below with the words that no row
/// has, a few seeds of its range added to the tests that walk, and whatever those find mended or listed.
extension ChaosGenerator {
  public static let seedsInAVersion: UInt64 = 1_000_000

  /// The command kinds each version added, by the names of the cases, in the order they are drawn from.
  public static let frozenCommandKinds: [[String]] = [
    [
      "status", "state", "ascii", "help", "showAll", "stepOut", "stepIn", "neighbor", "back", "forward", "zoom", "zoomNode",
      "desktop", "saveView", "goToView", "dock", "dockBeside", "float", "toggleFloat", "arrange", "floatAll", "resize",
      "exclude", "include", "relayout", "reloadSettings", "quit", "bindings", "rules", "frameRect", "home", "pause", "resume",
      "togglePause", "floatAllHere", "arrangeAll", "passThrough", "pin", "unpin", "togglePin", "stats", "version",
      "checkForUpdates", "launchAtLogin", "settings", "trace", "summon", "layout", "printLayout", "name", "unname",
      "goToSpace", "spaces", "askName", "doctor", "checkSetup", "welcome", "menuBar", "menu", "toggleAutoDock", "focus",
      "swap", "swapWindows", "equalize", "rotate", "mirror", "grow", "shrink", "moveToDisplay", "focusDisplay", "hold",
      "holdStill", "release", "toggleHold", "undo", "redo", "watch", "find", "reveal", "displays", "showShortcuts", "minimap",
    ]
  ]

  /// The settings each version added, by key.
  public static let frozenSettings: [[String]] = [
    [
      "hotkeysEnabled", "peek", "stepInToward", "shortcutsFollowLayout", "automaticUpdateChecks", "bindings", "messages",
      "gap", "minimumUsableWidth", "minimumUsableHeight", "arrangeDesktopWeight", "rules", "ruleTitleWait",
      "newWindowsWhileFramed", "tileRetryMinutes", "summonStays", "makeRoom", "soleFloatTakesDesktop", "resizeStep",
      "displays", "newWindows", "autoDockMinimumWidth", "autoDockMinimumHeight", "shareRemovedSpace", "shrinkOutOfView",
      "screenEdgeBand", "windowEdgeFraction", "dropDwell", "previewDrags", "reflowWhileDragging", "keepPushed", "tabsEnabled",
      "pointerGestures", "gesturesEnabled", "pinchThreshold", "frameRectangleModifier", "frameRectangleOnDesktop",
      "continuousZoom", "guardDesktopClicks", "scrollZoom", "scrollZoomThreshold", "scrollOnDesktopZooms",
      "holdStillWhileCameraIsOn", "holdStillWhileMicrophoneIsOn", "holdStillFor", "focusRing", "focusRingWidth",
      "focusRingColour", "focusRingRadius", "animationDuration", "minimapDuration", "dimBehindArranged", "blurBehindArranged",
      "tileStyle", "appColours", "appColourAmount", "gapHandles", "windowPictures", "tintBehindArranged", "desktopEdge",
      "tileFade", "menuBarControls", "historyButtons", "menuBarFill", "excludedBundleIDs", "passThroughApps", "pauseForApps",
      "allowAllURLCommands",
    ]
  ]

  /// The words of `all` that a walk with `seed` draws from: those of its version and the ones before, in the order of the rows; beyond the last version
  /// all of those, and then whatever no row lists, in the order of `all`.
  public static func vocabulary<Word>(for seed: UInt64, of all: [Word], frozen: [[String]], name: (Word) -> String) -> [Word] {
    let byName = Dictionary(all.map { (name($0), $0) }, uniquingKeysWith: { first, _ in first })
    let version = seed / seedsInAVersion
    let listed = frozen.prefix(Int(min(version, UInt64(frozen.count))) + 1).joined().compactMap { byName[$0] }
    guard version >= UInt64(frozen.count) else { return listed }
    let known = Set(frozen.joined())
    return listed + all.filter { !known.contains(name($0)) }
  }
}
