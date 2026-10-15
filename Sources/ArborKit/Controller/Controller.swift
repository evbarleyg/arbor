import ArborCore
import CoreGraphics
import Foundation

/// Decides which windows Arbor arranges.
public struct WindowFilter: Sendable, Equatable {
  public var excludedBundleIDs: Set<String>
  /// When set, only windows owned by these processes are arranged. The
  /// end-to-end runner uses this so tests never touch the user's windows.
  public var onlyPIDs: Set<Int32>?
  public var ownPID: Int32
  /// Windows an `ignore` rule matched. Arbor leaves them alone (Controller+Rules.swift).
  public internal(set) var ignoredWindowIDs: Set<WindowID> = []

  public init(excludedBundleIDs: Set<String> = [], onlyPIDs: Set<Int32>? = nil, ownPID: Int32 = getpid()) {
    self.excludedBundleIDs = excludedBundleIDs
    self.onlyPIDs = onlyPIDs
    self.ownPID = ownPID
  }

  public func manages(_ window: WindowSnapshot) -> Bool {
    if window.pid == ownPID { return false }
    if let onlyPIDs, !onlyPIDs.contains(window.pid) { return false }
    if let bundle = window.bundleID, excludedBundleIDs.contains(bundle) { return false }
    if ignoredWindowIDs.contains(window.id) { return false }
    return true
  }
}

/// The window manager's brain. It owns one `Workspace` per display, turns
/// commands and window events into tree changes, lays the trees out with
/// `LayoutEngine`, and applies the result through the `WindowSystem`.
///
/// Everything here is deterministic given the platform fakes, which is what
/// lets the scenario tests in ArborKitTests and arbor-sim run without
/// Accessibility permission. The code is split by concern:
/// - Controller.swift: state, lifecycle, persistence, snapshots
/// - Controller+Layout.swift: relayout, parking, floating windows, camera moves
/// - Controller+Commands.swift: `execute(_:)` and one method per command
/// - Controller+Events.swift: window-system and overlay callbacks
/// - Controller+Drag.swift: drag and drop
/// - Controller+Reflow.swift: the other windows making room while one is dragged
/// - Controller+Observers.swift: telling the menu bar and other observers what changed
/// - Controller+EventSummary.swift, EventFeed.swift: the events of `arborctl watch`
/// - Controller+EdgeResize.swift: resizing docked windows by their own edges
/// - Controller+Displays.swift: displays going away and coming back
/// - Controller+DisplayOptions.swift: settings that differ from display to display
/// - Controller+Spaces.swift: windows on other Spaces
/// - Controller+Pause.swift: letting go of the windows for a while
/// - Controller+LearnedSizes.swift: asking windows that refused their slot again, out of view
/// - Controller+Focus.swift: keeping the window that has the keyboard in view
/// - Controller+Guests.swift: new windows that open while one window is framed
/// - Controller+FocusRing.swift: the line around the window that has the keyboard
/// - Controller+Hardening.swift: apps that fight back or hang; lost releases; the Dock; native tabs
/// - Controller+PendingSlots.swift: saved slots waiting for apps to restore their windows
/// - Controller+MenuBar.swift: what the menu bar item shows
/// - Controller+Menu.swift: what is in its menu
/// - Controller+Doctor.swift: `doctor`
/// - Controller+Onboarding.swift: what the welcome window says
/// - Controller+PassThrough.swift: letting go of the keys, or pausing, while certain apps are frontmost
/// - Controller+KeyboardLayout.swift: which keys the shortcuts' letters mean
/// - Controller+Permission.swift: Accessibility permission taken away while running
/// - Controller+SystemShortcuts.swift: shortcuts that macOS uses as well
/// - Controller+Pin.swift: floating windows that stay in view wherever the camera goes
/// - Controller+Hold.swift: moving nothing uninvited during calls and on shared screens
/// - Controller+UndockedFrames.swift: giving windows that leave the arrangement their own size back
/// - Controller+Switches.swift: what the behaviour switches need (parking small, windows left parked)
/// - Controller+Transitions.swift: showing changes as motion
/// - Controller+Updates.swift: the version, and asking whether a newer release exists
/// - Controller+LoginItem.swift: opening Arbor at login
/// - Controller+Settings.swift: `set`, `get` and the other settings commands; reloading settings.json
/// - Controller+Finder.swift: "Go to…", the picker for windows, named spaces and saved views
/// - Controller+Trace.swift: recording traces
/// - Controller+Summon.swift: an app's window over any view for a moment
/// - Controller+LayoutNotation.swift: arrangements written as a line of text
/// - Controller+NamedSpaces.swift: names for spaces, and going to them
/// - Controller+SoleFloat.swift: a window that floats alone takes the whole Desktop
/// - Controller+KeyboardFocus.swift, Controller+Tiling.swift: the keyboard tiling tools
/// - Controller+AutoDock.swift: new windows that dock without being asked
/// - Controller+HeadsUp.swift: saying on screen what happened
/// - Controller+CheatSheet.swift: the shortcuts on screen
/// - Controller+Minimap.swift: the whole arrangement in small, after the view has moved
/// - Controller+Undo.swift: undo and redo for changes to the arrangement
@MainActor
public final class Controller {
  public let system: any WindowSystem
  public let overlays: any OverlayPresenter
  public let store: any StateStore
  public let scheduler: any Scheduler
  public internal(set) var settings: Settings
  public var filter: WindowFilter

  /// False until the app has Accessibility permission. Commands other than
  /// queries fail with an explanation until `start()` runs.
  public var accessibilityGranted = true
  /// Called when a command changes settings, to save what changed between `old` and `new`; see
  /// `change(settings:)`. If it throws, the command fails with what was thrown and nothing changes.
  public var saveSettings: ((_ old: Settings, _ new: Settings) throws -> Void)?
  /// Called to read the settings file again: by `reload-settings`, when the file changes, and before a
  /// command changes settings. Throws `SettingsFile.Missing` if there is no file, and anything else
  /// if the file cannot be read; the settings in use then stay (Controller+Settings.swift).
  public var loadSettings: (() throws -> Settings)?
  /// Called by `reset everything` to write a whole new file in place of one that cannot be read. Returns the name of
  /// the copy it kept of the old one, or nil if there was nothing to copy.
  public var replaceSettingsFile: ((Settings) throws -> String?)?
  /// What it returned the last time, for the reply.
  var copyOfReplacedSettingsFile: String?
  /// Called before a `reset` empties a list or everything, to keep a copy of the file as it is. Returns the copy's name,
  /// or nil if there is no file to copy. If it throws, nothing is reset.
  public var keepCopyOfSettingsFile: (() throws -> String?)?
  /// Why settings.json could not be read the last time Arbor looked, nil if it could. While it
  /// cannot be read, commands that change settings are refused.
  public internal(set) var settingsFileProblem: String? {
    // Whatever shows settings shows this too.
    didSet { if settingsFileProblem != oldValue { notify(.settings) } }
  }
  /// The same without what it quotes from the file (`Settings.FileError.forTheLog`).
  var settingsFileProblemForTheLog: String?
  /// Opens the settings window (`settings-window`), at a pane if one is named. Nil where there is none: tests,
  /// arbor-sim.
  public var onShowSettingsWindow: ((SettingsPane?) -> Void)?
  /// Closes it (`settings-window close`).
  public var onCloseSettingsWindow: (() -> Void)?
  /// True while the settings window records a shortcut. Arbor holds none meanwhile (`activeBindings`), or pressing one
  /// of its own would run it instead of reaching the window.
  public var isRecordingShortcut = false {
    didSet { if isRecordingShortcut != oldValue { notify(.input) } }
  }
  /// Called at the end of every `apply(settings:)` (reload-settings, exclude, include), so the app
  /// can register the shortcuts the new settings describe.
  public var onSettingsApplied: ((Settings) -> Void)?

  public internal(set) var workspaces: [DisplayID: Workspace] = [:]
  /// Workspaces of displays that went away, restored when they come back
  /// (Controller+Displays.swift).
  public internal(set) var dormant: [DisplayID: DormantWorkspace] = [:]
  /// The current time. Tests replace it to age dormant workspaces.
  public var now: () -> Date = { Date() }
  public internal(set) var displays: [DisplaySnapshot] = [] {
    didSet { if let main = displays.first(where: \.isMain) ?? displays.first { lastMainDisplay = main } }
  }
  /// The main display, or what it was when the last display went (asleep, unplugged with the lid closed).
  var lastMainDisplay: DisplaySnapshot?
  /// Windows macOS moved while it had other displays than Arbor was told of (Controller+Displays.swift).
  var movedBehindArborsBack: Set<WindowID> = []
  public internal(set) var windows: [WindowID: WindowSnapshot] = [:] {
    didSet { desktopGuardZonesMayHaveChanged() }
  }
  /// The most recent layout of each display.
  public internal(set) var layouts: [DisplayID: Layout] = [:]
  /// Windows Arbor has moved out of view (to a screen corner).
  public internal(set) var parked: Set<WindowID> = [] {
    didSet { desktopGuardZonesMayHaveChanged() }
  }
  public internal(set) var isRunning = false

  /// Sizes apps refused to shrink below, learned when a frame does not stick.
  var minimumSizes: [WindowID: CGSize] = [:]
  /// How often each window has been seen smaller than its learned size (Controller+Layout.swift).
  var disprovedMinimums: [WindowID: Int] = [:]
  /// When each window last stood by its learned size (Controller+LearnedSizes.swift).
  var confirmedSizes: [WindowID: ConfirmedSize] = [:]
  /// The frame each new window floated at when its app opened it. While that is still the frame remembered for
  /// it, the user has not placed it (Controller+Layout.swift).
  var appPlacedFrames: [WindowID: CGRect] = [:]
  /// When each floating window's app last said where it is and that passed for the person's own move
  /// (Controller+Displays.swift, "A display that moved").
  var spokeOfItsPlace: [WindowID: Date] = [:]
  /// Windows reported back (their app shown again) since the layout that will show them was put off (Controller+Spaces.swift).
  var returningWindows: Set<WindowID> = []
  /// Displays whose layout was put off until all the reports of a Space switch or a hidden app are in.
  var postponedRelayouts: Set<DisplayID> = []
  /// Those of them that wait for the Space a window has left for full screen to go out of sight.
  var waitingForASpaceToLeave: Set<DisplayID> = []
  /// What is remembered for a moment about the keyboard changing hands (Controller+Focus.swift).
  var keyboardHandOver = KeyboardHandOver()
  /// How often each parked window was sent back to its corner since it was parked (Controller+Layout.swift).
  var parkedAgain: [WindowID: Int] = [:]
  /// Windows Arbor has let go of (their app was excluded, a rule ignores them) that are still out of view, because their
  /// app did not answer when they were to be brought back, and where each belongs. Paid when the app has something
  /// to report, and at the latest when Arbor stops.
  var owedTheWayBack: [WindowID: CGRect] = [:]
  /// The window the framing shortcut last un-framed, if that made it a tile, and the window that got the focus
  /// instead (`zoom`). Forgotten at the next move of the view, and after a few seconds.
  var unframedIntoATile: (window: WindowID, heir: WindowID, time: Date)?
  static let unframedIsRemembered: TimeInterval = 5
  /// The frame each window took the last time Arbor placed it.
  var settled: [WindowID: CGRect] = [:]
  var hints: [WindowID: WindowHint] = [:]
  /// The window the user is dragging by its title bar (Controller+Drag.swift).
  var drag: DragSession?
  /// A docked window the user is resizing by its edges (Controller+EdgeResize.swift).
  var edgeResize: EdgeResize?

  /// Who to tell when something they might show has changed (Controller+Observers.swift).
  var observers: [@MainActor (Change) -> Void] = []
  /// See Controller+DesktopGuard.swift.
  var announcedGuardZones = DesktopGuardZones()
  var guardZonesCheckIsQueued = false

  /// Managed windows, most recently focused first. `dock beside` rules use it
  /// to pick which of an app's windows to dock beside (Controller+Rules.swift).
  var focusHistory: [WindowID] = []
  /// New windows whose title is still being checked against the rules (Controller+Rules.swift).
  var titleWatches: [WindowID: TitleWatch] = [:]
  /// Windows an `ignore` rule matches that the last run arranged (in the workspace given), found while there was no
  /// display, so that nothing says whether they are in view (Controller+Rules.swift).
  var foundInTheDark: [WindowID: Workspace] = [:]
  /// Whether commands follow the pointer or the keyboard (Controller+Lead.swift).
  var following = Following()
  /// The peek in progress, if any (Controller+Peek.swift).
  var peeking: PeekSession?
  /// Called when the shortcuts a peek needs on top of the registered ones change; empty takes them away.
  public var onTemporaryShortcuts: (([KeyBinding]) -> Void)?
  /// The window a command gave focus to, until macOS says so too (Controller+KeyboardFocus.swift).
  var focusRequest: FocusRequest?
  /// The window `dock auto` placed last (Controller+AutoDock.swift).
  var autoDockTrail: AutoDockTrail?
  /// True while `windowFound` runs: the window at hand was open all along.
  var isTakingInAFoundWindow = false

  /// Windows that did not take the size of their slot: the slot they were asked to fill and the
  /// frame they ended at. While both still hold there is no point in asking again.
  var misfits: [WindowID: (slot: CGRect, frame: CGRect)] = [:]
  /// How small and how large each window has been seen, so that only what is not known is asked (Controller+AskFirst.swift).
  var seenSizes: [WindowID: SeenSizes] = [:]
  /// The windows asked for a size during the layout under way that have yet to go to their place: what each was offered.
  var justAnswered: [WindowID: CGSize] = [:]
  /// The windows whose size Accessibility said cannot be changed, once that has been written down.
  var fixedSizesNoted: Set<WindowID> = []
  /// Making room before making tiles (Controller+MakeRoom.swift): true while the layout follows the person's own hand on a
  /// gap, and the slots they squeezed into tiles that way, which stay as they left them.
  var gapsInHand = false
  var squeezedByHand: [DisplayID: Set<NodeID>] = [:]

  /// True between `pause` and `resume` (Controller+Pause.swift). `isRunning` is false meanwhile.
  public internal(set) var isPaused = false
  /// What `resume` starts from, in place of the saved file.
  var resumeState: PersistedState?
  /// When the pause ends by itself, for the saved file. The scheduler does the ending.
  var pauseEnd: Date?
  /// The watchdog started this process after the last one ended without quitting. The app sets it before the
  /// first `start()`, which then takes up a pause that was on (Controller+Pause.swift).
  public var restartedAfterAccident = false
  /// True while `resume` runs `start()`: what is missing now was closed under the user's eyes.
  var isResuming = false
  /// Counts a streamed pinch into steps (Controller+Gesture.swift).
  var gestureSteps = GestureInterpreter()
  /// The shortcuts the app has registered with macOS: the ones menus, tooltips and `doctor` go by.
  /// Nil until the app has said, and in tests; then the ones the settings describe stand in.
  public var registeredBindings: [KeyBinding]?
  /// The shortcuts macOS would not let the app register, the last time it asked (another app holds them).
  public var refusedBindings: [KeyBinding] = []
  /// Reads what only macOS knows, for `doctor` and the welcome window (Controller+Doctor.swift).
  public var systemFacts: (() -> SystemFacts)?
  /// The name of an installed app, from its bundle id, for an app that has no window open to ask (Controller+Menu.swift).
  public var nameOfApp: ((String) -> String?)?
  /// Whether the welcome window and `doctor` speak of Screen Recording. Pictures of moving windows are all Arbor wants that
  /// permission for, so nobody is invited to grant it while they are switched off, as they are until they have been seen to work.
  public var offersScreenRecording: Bool { settings.windowPictures }
  /// What is known about the room the menu bar has for Arbor's item (Controller+MenuBar.swift).
  public internal(set) var menuBarRoom = MenuBarRoom()
  /// The welcome window has been seen, now or at an earlier launch (Controller+Onboarding.swift).
  var hasWelcomed = false
  /// Opens the welcome window on a page, for `check-setup` and `welcome`.
  public var openWelcomeWindow: ((OnboardingFlow.Page) -> Void)?
  /// How many more times to look whether a pinned window is covered (Controller+Pin.swift).
  var pinChecksLeft = 0
  /// Whether and how the view is held (Controller+Hold.swift).
  var hold = Hold()
  /// The shortcut that released a held view, until it comes up. It outlives the hold.
  var keyThatReleasedTheHold: KeyChord?
  /// What the app last heard about cameras and microphones. Kept through a pause.
  var callSignals = CallSignals()
  /// Where the pause left each window it moved, to tell at the resume which of them nobody has touched since.
  var pausedFrames: [WindowID: CGRect] = [:]
  /// The window that had the keyboard before `summon` took it (Controller+Summon.swift).
  var keyboardBeforeSummon: WindowID?
  /// Where `summon` came from when it went to a docked window, until the next press (Controller+Summon.swift).
  var visitToDockedWindow: VisitToDockedWindow?
  /// The app `summon` has asked to open a window, and the display to summon it on.
  var awaitedSummon: (app: String, display: DisplayID)?
  /// Arrangements waiting for the windows of apps that `layout --open` opened (Controller+LayoutNotation.swift).
  var pendingLayouts: [DisplayID: PendingLayout] = [:]
  /// The changes `undo` and `redo` step through (Controller+Undo.swift). Not saved between launches.
  public internal(set) var undoHistory = UndoHistory()
  /// How many `beginUndoStep` calls are waiting for their `endUndoStep`.
  var undoScopeDepth = 0
  /// The window being dragged, and where the floating windows were when the drag began.
  var dragOrigin: (window: WindowID, frames: [DisplayID: [WindowID: CGRect]])?
  /// Floating windows that the layout in progress takes out of view: an undo has put back an arrangement in which they were.
  var leavingView: Set<WindowID> = []
  /// Each display's tree as it was when Arbor first moved its gaps to make room (F61) during the change being recorded.
  var treesBeforeRoomWasMade: [DisplayID: LayoutTree] = [:]
  /// What the menu called the step the last `undo` or `redo` took; nil if it took none.
  var titleOfTheStepJustTaken: String?
  /// The palette of "Go to…"; nil while it is closed (Controller+Finder.swift).
  var finder: OpenFinder?

  /// Where the line around the focused window is (Controller+FocusRing.swift).
  var focusRing = FocusRingState()
  /// The space the field for typing a name is open for, and the window that had the keyboard when it opened
  /// (Controller+NamedSpaces.swift).
  var namePrompt: (display: DisplayID, node: NodeID, keyboard: WindowID?)?
  /// What the heads-up line and the panel of shortcuts show, and what has been taught (Controller+HeadsUp.swift).
  var headsUp = HeadsUpState()
  /// Which displays show a minimap, and where their views were (Controller+Minimap.swift).
  var minimap = MinimapState()

  /// Counts how often each docked window was put back, to stop fighting an app that keeps moving its
  /// own windows (Controller+Hardening.swift).
  var enforcement = EnforcementLimiter()
  /// Windows that could not be moved because their app did not answer. They are placed when it does.
  var unplaced: Set<WindowID> = []
  /// Of those, the ones whose app has answered since. The layout that follows owes them the move they missed, whatever
  /// else that layout is for (Controller+Hardening.swift).
  var owedMoves: Set<WindowID> = []
  /// Windows that were out of view when a pause began and could not be brought back, because their app did not answer, and where
  /// each was to go; and how often it has been tried since (Controller+Hardening.swift).
  var couldNotComeBack: [WindowID: CGRect] = [:]
  var triesForWhatCouldNotComeBack = 0
  /// Stand-ins for saved docked windows that may still be restored (Controller+PendingSlots.swift).
  var pendingSlots: Set<WindowID> = []
  /// Those of them whose wait is over and whose going would move a window: they go with the next layout.
  var overdueSlots: Set<WindowID> = []
  /// Windows that took a waiting slot on the strength of their app alone, until the wait is over.
  var provisionalSlots: [WindowID: ProvisionalSlot] = [:]
  // Controller+Economy.swift
  /// Where commands and layouts are counted and timed (the `stats` command).
  public var stats = CallStats.shared
  /// What Arbor last wrote to the state file, so that nothing is written when nothing changed. Not what it read:
  /// loading repairs, and what was repaired should be written.
  var lastSaved: PersistedState?
  /// What was wrong with it when this run read it (Controller+Notices.swift).
  var stateNews: StateNews?
  /// Floating windows that the layout in progress must leave exactly where they are: the one that was just
  /// dropped, the ones `float-all` has just put back (Controller+UndockedFrames.swift), or the ones that lay over a view that
  /// is taken back (Controller+Focus.swift).
  var placedOnPurpose: Set<WindowID> = []
  /// The opposite: the display whose docked space is all new in the layout in progress, so that no floating window
  /// lies over it on purpose and all of them make way (`layout`, Controller+LayoutNotation.swift).
  var displayArrangedAnew: DisplayID?
  /// What each display showed when it was last laid out, for the next transition to start from
  /// (Controller+Transitions.swift).
  var keyframes: [DisplayID: Keyframe] = [:]
  /// Which build this is. The app reads it from its Info.plist when it starts (BuildInfo.swift).
  public var buildInfo = BuildInfo.development
  /// Who to ask about new releases. Without one, `check-for-updates` says it cannot
  /// (Controller+Updates.swift).
  public var releaseFeed: (any ReleaseFeed)?
  /// Called with the answer of an update check that the user asked for, to show it.
  public var onUpdateDecision: ((UpdateDecision) -> Void)?
  public internal(set) var updates = UpdateState()
  /// Arbor's entry in macOS's login items (Controller+LoginItem.swift).
  public var loginItem: (any LoginItem)?
  /// Windows that float alone and have been taken in hand (Controller+SoleFloat.swift).
  var soleFloats = SoleFloats()

  /// The app in front, as last reported (Controller+PassThrough.swift). Nil until the first report.
  public internal(set) var frontmostApp: FrontmostApp?
  /// True while the pause is one Arbor began by itself because of `pauseForApps`, and will end by itself.
  public internal(set) var isPausedForApp = false
  /// What `followFrontmostApp` last told observers.
  var wasPassingThrough = false
  /// The shortcuts kept in an app that keeps its own ⌃⌥ because they send away what is summoned, as last told.
  var summonKeysLastTold: [KeyChord] = []
  /// Whether the frontmost app is one Arbor pauses for and has had its pause (or found one in progress).
  var frontmostAppPaused = false

  /// Reads macOS's own keyboard shortcuts. Set by the app; without it nobody knows (Controller+SystemShortcuts.swift).
  public var systemShortcuts: (() -> SystemShortcuts?)?
  var loggedSystemShortcutClashes: [String] = []
  var bindingsHeldAgainstMacOS: [KeyBinding]?

  /// The keyboard layout macOS has selected, as last reported (Controller+KeyboardLayout.swift).
  public internal(set) var keyboardLayout: KeyLayout = .us

  /// Asks macOS whether Arbor may still use Accessibility: thoroughly, or only by the flag, which is cheap and may
  /// lag. Set by the app; without it nobody asks (Controller+Permission.swift).
  public var accessibilityProbe: ((_ thoroughly: Bool) -> Bool)?
  /// When macOS last said yes to the thorough question. Nil after a no.
  var lastThoroughYes: Date?
  /// Whether it ever has, in this process. Until then its no counts only together with the flag's.
  var thoroughWayHasSaidYes = false
  var saidThatTheThoroughWayFails = false
  /// Puts the request for the permission in front of the user. Set by the app; called once when the permission
  /// goes while windows are out of view.
  public var askForAccessibility: (() -> Void)?
  /// Set between losing the permission while running and getting it back.
  public internal(set) var permissionLoss: PermissionLoss?
  var permissionWatch = PermissionWatch()
  /// When a failed shortcut last opened the Accessibility pane.
  var lastVisitToSettings: Date?
  /// True from the first `start()` with a probe.
  var isWatchingPermission = false
  /// True during `shutdown(movingWindows: false)`: `placeVisibly` and `putBack`, through which it moves windows, do nothing.
  var isStoppingWithoutMoving = false

  /// When each window that has only just come back can be taken at its word (Controller+OnTheWayBack.swift).
  var landsAt: [WindowID: Date] = [:]
  /// For each window in macOS's full screen, the windows that took up room when it went there (Controller+OnTheWayBack.swift).
  var sharedItsSpace: [WindowID: Set<WindowID>] = [:]
  /// Windows on their way out of full screen: the frame each is to land at, what it last made of that, and how often Arbor has
  /// looked whether it has it.
  var metAhead: [WindowID: (target: CGRect, answer: CGRect?, looks: Int)] = [:]

  /// Windows a pause could not bring into view (Controller+LeftInFullScreen.swift).
  var leftInFullScreen = LeftInFullScreen()

  /// Floating windows whose remembered frame their user's own hand gave them, with the frame their display had then
  /// (`noteWhereItsUserLeftIt`).
  var chosenOnShape: [WindowID: (frame: CGRect, display: CGRect)] = [:]

  /// The window ⌃⌥F floated last, and where it was docked (Controller+FloatAndBack.swift).
  var floatedOut: FloatedOut?

  /// Windows parked smaller than they are in view (Controller+Switches.swift).
  var shrunk: [WindowID: ShrunkWindow] = [:]

  /// What the presenter has got ready for the next motion (Controller+Rehearsal.swift).
  var rehearsed = Rehearsed()

  /// Windows on a display too small for their own size, which they take along when they leave it (Controller+UndockedFrames.swift).
  var fittedToADisplay: [WindowID: FittedWindow] = [:]

  public init(
    system: any WindowSystem, overlays: any OverlayPresenter, store: any StateStore,
    scheduler: any Scheduler, settings: Settings = Settings(), filter: WindowFilter = WindowFilter()
  ) {
    self.system = system
    self.overlays = overlays
    self.store = store
    self.scheduler = scheduler
    self.settings = settings
    var filter = filter
    filter.excludedBundleIDs.formUnion(settings.excludedBundleIDs)
    self.filter = filter
    system.events = self
    overlays.actions = self
    startFocusRing()
    startMinimap()
  }

  // MARK: Lifecycle

  /// Starts observing windows, restores the saved arrangement, and lays out
  /// every display. A launch ends showing everything; a start that goes on from a moment ago ends in the view of then.
  public func start() {
    let afterAccident = restartedAfterAccident
    guard !isRunning, !comesBackPaused() else { return }
    // Not always the first start of the process: Arbor also starts after a pause, and after losing and
    // regaining Accessibility permission. Nobody told it what happened meanwhile, so what it knew about
    // windows, displays and frames is forgotten here, whoever stopped it.
    windows.removeAll()
    workspaces.removeAll()
    dormant.removeAll()
    layouts.removeAll()
    parked.removeAll()
    settled.removeAll()
    misfits.removeAll()
    owedMoves.removeAll()
    forgetWhatCouldNotComeBack()
    pendingSlots.removeAll()
    overdueSlots.removeAll()
    provisionalSlots.removeAll()
    drag = nil
    soleFloats.dragged = nil
    edgeResize = nil
    system.start()
    let shapes = Dictionary(displays.map { ($0.id, $0.frame) }, uniquingKeysWith: { first, _ in first })
    displays = system.displays()
    var saved = resumeState
    if saved == nil {
      // Somebody starts Arbor, or logs in. Quitting put every window in view, and the view of last time would send most of
      // them out of it again, unasked. Where nobody quit (a pause, the permission, the watchdog) `resumeState` has the view.
      saved = store.load()?.showingEverything()
      noteHowLoadingWent()
    }
    resumeState = nil
    hints = saved?.hints ?? [:]
    // Or just now, before this start: a launch without the permission begins with the welcome window.
    // Or in an earlier run whose file could not be used: whoever had a state file has been here before.
    hasWelcomed = hasWelcomed || saved?.welcomed == true || (stateNews != nil && stateNews?.problem != .repaired)
    headsUp.hintsShown = saved?.hintsShown ?? [:]
    for display in displays {
      var workspace = saved?.workspaces[display.id] ?? Workspace()
      // The displays may be arranged otherwise than when that was written (Controller+Displays.swift, "A display that moved").
      if let old = saved?.origins?[display.id] {
        workspace.shift(by: CGPoint(x: display.frame.minX - old.x, y: display.frame.minY - old.y))
      }
      workspaces[display.id] = workspace
    }
    // A start after a pause has the history of before it, and the displays may have changed meanwhile.
    // The file has the corners only; what the displays were like when Arbor stopped is still in memory.
    endUndoHistoryIfDisplaysMoved(since: saved?.origins ?? [:], sizes: shapes.mapValues(\.size))
    for window in system.allWindows() { windows[window.id] = window }
    if let saved, saved.origins == nil {
      for display in displays where saved.workspaces[display.id] != nil { healFramesOfUnknownOrigin(on: display) }
    }
    ignoreWindowsFoundAtLaunch(saved: saved)
    fetchWindowsOfExcludedAppsLeftOutOfView(saved: saved)
    // What was learned about windows that still exist stays.
    minimumSizes = minimumSizes.filter { windows[$0.key] != nil }
    disprovedMinimums = disprovedMinimums.filter { windows[$0.key] != nil }
    seenSizes = seenSizes.filter { windows[$0.key] != nil }
    fixedSizesNoted = fixedSizesNoted.filter { windows[$0] != nil }
    owedTheWayBack = owedTheWayBack.filter { windows[$0.key] != nil }
    appPlacedFrames = appPlacedFrames.filter { windows[$0.key] != nil }
    spokeOfItsPlace = spokeOfItsPlace.filter { windows[$0.key] != nil }
    landsAt = landsAt.filter { windows[$0.key] != nil }
    chosenOnShape = chosenOnShape.filter { windows[$0.key] != nil }
    fittedToADisplay = fittedToADisplay.filter { windows[$0.key] != nil }
    keepOnlyWhatIsStillOwedAfterAStart()
    parkedAgain.removeAll()
    unplaced.removeAll()
    owedMoves.removeAll()
    enforcement = EnforcementLimiter()
    focusHistory.removeAll { windows[$0] == nil }
    let savedHints = hints
    reconcile()
    noteWindowsLeftParked()
    resumeDormantWorkspaces(from: saved, hints: savedHints)
    // A run that did not quit cleanly leaves its parked windows out of view.
    treatStrandedWindowsAsParked()
    if afterAccident { showEverythingWhereTheViewWouldTakeAWindowOutOfView() }
    isRunning = true
    Log.info("started: \(displays.count) display(s), \(managedWindowIDs.count) managed window(s)")
    letTheViewFollowTheKeyboardBeforeTheFirstLayout()
    relayoutAll(reason: .camera, motion: .instant)
    placedOnPurpose.removeAll()
    refreshHoldCaller()
    notify(.lifecycle)
    scheduleSave()
    startWaitingForPendingSlots()
    watchAccessibility()
    fillOnceWindowsHaveTurnedUp()
    followFrontmostApp()
    scheduleUpdateChecks()
    // Nobody told Arbor where the keyboard went while it was not running, and the view that has just come back may not
    // include that window: it was swept out of view with the keyboard in it, and ⌘Tab does not fetch it, because its
    // app is in front already and nothing is reported. A launch ends with the focused window in view, as `resume` does.
    if isRunning, !isResuming, let focused = system.focusedWindow() { windowFocused(focused) }
  }

  /// After an accident the windows the view leaves out are still in their corners, and keeping the view moves nothing. But the
  /// file can be half a second behind: the view had just widened when Arbor died, say, or ⌃⌥0 had fetched what `summon` had sent
  /// away. The watchdog's start takes no window out of view either, so a display where it would shows everything instead.
  private func showEverythingWhereTheViewWouldTakeAWindowOutOfView() {
    for id in workspaces.keys.sorted() {
      guard let layout = layout(of: id) else { continue }
      let floating = floatingMoves(on: id, layout: layout, reason: .camera).filter { if case .park = $0.move { true } else { false } }
      guard !layout.hiddenWindows.union(floating.map(\.window)).isSubset(of: parked) else { continue }
      workspaces[id]?.showEverything()
    }
  }

  /// Puts every window somewhere visible, saves, and stops. Called on quit so
  /// no window is left parked off-screen. A pause stops the same way (Controller+Pause.swift). Without `movingWindows`
  /// nothing is moved: for when nothing can be (Controller+Permission.swift).
  public func shutdown(movingWindows: Bool = true) {
    guard isRunning else {
      letGoAfterPause()
      return
    }
    isStoppingWithoutMoving = !movingWindows
    defer { isStoppingWithoutMoving = false }
    cancelDrag()
    if movingWindows { lookAtTheDisplaysBeforeLettingGo() }
    scheduler.cancel("save")
    overlays.finishAnimations()
    stopWatchingTitles()
    cancelFocusLooks()
    for id in postponedRelayouts { scheduler.cancel("space-\(id.rawValue)") }
    postponedRelayouts.removeAll()
    waitingForASpaceToLeave.removeAll()
    returningWindows.removeAll()
    keyboardHandOver = KeyboardHandOver()
    scheduler.cancel("pending-slots")
    forgetHold()
    scheduler.cancel(Self.afterLaunchKey)
    soleFloats.isWaitingAfterLaunch = false
    endSummonsWithoutMoving()
    forgetPendingLayouts()
    let present = presentWindowIDs()
    for id in workspaces.keys.sorted() {
      guard let workspace = workspaces[id], let display = display(id) else { continue }
      var withoutTiles = options(for: id).layoutOptions
      withoutTiles.minimumUsableSize = .zero
      let layout = LayoutEngine.layout(
        workspace.tree, camera: workspace.tree.root, in: display.visibleFrame, options: withoutTiles,
        isPresent: { present.contains($0) })
      // Each goes back to where it floated before it was docked (Controller+UndockedFrames.swift), or
      // stays in its slot if that is not known.
      for (window, frame) in layout.windowFrames.sorted(by: { $0.key < $1.key }) {
        letGo(of: window, on: display, otherwiseAt: frame)
      }
      // Inactive tabs go where their stack is.
      for window in layout.hiddenWindows.sorted() {
        if let leaf = workspace.tree.leaf(containing: window), let frame = layout.nodeFrames[leaf] {
          letGo(of: window, on: display, otherwiseAt: frame)
        }
      }
      // Windows that take no space just now (minimized, a hidden app, another macOS Space) will show again
      // when Arbor is gone, and should not do so in the shape of a slot, let alone in the corner. If it is not
      // known where one floated and it is parked, it goes where it would sit if everything were present.
      let everything = LayoutEngine.layout(
        workspace.tree, camera: workspace.tree.root, in: display.visibleFrame, options: withoutTiles,
        isPresent: { _ in true })
      for window in workspace.tree.allWindows where !present.contains(window) {
        let slot = workspace.tree.leaf(containing: window).flatMap { everything.nodeFrames[$0] }
        letGo(of: window, on: display, otherwiseAt: parked.contains(window) ? slot : nil)
      }
      for (window, preferred) in workspace.floating.sorted(by: { $0.key < $1.key })
      where parked.contains(window) || wasPushedAside(window, from: preferred) {
        putBack(window, at: asItWas(preferred, on: display), on: display)
      }
    }
    // Whatever the bookkeeping says, nothing Arbor arranges is left out of view: a window can be in the
    // corner without being in `parked`, for one when it was minimized there and its display changed.
    for id in managedWindowIDs {
      guard var frame = windows[id]?.frame, isMostlyOffScreen(id),
        let home = workspaceID(containing: id) ?? displayID(at: frame.center), let display = display(home)
      else { continue }
      frame.size = sizeInView(of: id) ?? frame.size
      placeVisibly(id, at: frame, on: display)
    }
    // With no display at all the windows are in no workspace. They go where the main display was, which is where
    // one is most likely to be again.
    noteWindowsLeftInFullScreen()
    for window in parked.sorted() { bringBackWithNoDisplay(window) }
    payTheWayBack()
    parked.removeAll()
    keyframes.removeAll()
    namePrompt = nil
    closeFinder()
    overlays.removeAll()
    saveNow()
    // Saved with their hints; the next start finds them again.
    pendingSlots.removeAll()
    overdueSlots.removeAll()
    provisionalSlots.removeAll()
    store.flush()
    isRunning = false
    forgetRehearsal()
    system.stop()
    scheduleUpdateChecks()
    notify(.lifecycle)
    Log.info(movingWindows ? "stopped; all windows returned to view" : "stopped; no window was moved")
  }

  /// Does nothing while there is a display.
  func bringBackWithNoDisplay(_ window: WindowID) {
    guard displays.isEmpty, let last = lastMainDisplay else { return }
    guard let frame = frameRememberedWithADisplayThatWent(of: window) ?? windows[window]?.frame else { return }
    placeVisibly(window, at: frame, on: last)
  }

  /// Moves a window to `frame`, then, if the app kept it larger than that
  /// and it now hangs off the display, slides it fully onto the display.
  func placeVisibly(_ window: WindowID, at frame: CGRect, on display: DisplaySnapshot) {
    guard !isStoppingWithoutMoving else { return }
    let visible = display.visibleFrame
    guard let actual = system.setFrame(frame.fitted(into: visible), of: window) else {
      noteThatItCouldNotComeBack(window, to: frame.fitted(into: visible))
      return
    }
    windows[window]?.frame = actual
    if actual.fractionInside(visible) < 0.99, let moved = system.setFrame(actual.fitted(into: visible), of: window) {
      windows[window]?.frame = moved
    }
  }

  // MARK: Settings

  public func apply(settings newSettings: Settings) {
    defer {
      followFrontmostApp()
      onSettingsApplied?(newSettings)
      notify(.settings)
    }
    traceRecorder?.settingsWillApply(newSettings)
    // With pictures of windows the presenter needs other things for a motion than without.
    if newSettings.windowPictures != settings.windowPictures { forgetRehearsal() }
    settings = newSettings
    filter.excludedBundleIDs = Set(newSettings.excludedBundleIDs)
    stopWatchingTitles()
    if !newSettings.previewDrags { overlays.showDropPreview(nil) }
    scheduleUpdateChecks()
    guard isRunning else { return }
    releaseUnmanagedWindows()
    adoptNewlyManagedWindows()
    // The displays may have changed while Arbor was not arranging a window it has just taken on.
    treatStrandedWindowsAsParked()
    relayoutAll(reason: .structure, motion: .instant)
    refreshHoldCaller()
    scheduleSave()
  }

  // MARK: Lookup helpers

  public func display(_ id: DisplayID) -> DisplaySnapshot? { displays.first { $0.id == id } }

  var mainDisplayID: DisplayID? { (displays.first(where: \.isMain) ?? displays.first)?.id }

  /// The display containing `point`, or the nearest one.
  func displayID(at point: CGPoint) -> DisplayID? {
    if let hit = displays.first(where: { $0.frame.contains(point) }) { return hit.id }
    return displays.min { $0.frame.distance(to: point) < $1.frame.distance(to: point) }?.id
  }

  /// The display whose workspace docks or floats `window`.
  public func workspaceID(containing window: WindowID) -> DisplayID? {
    workspaces.first { $0.value.contains(window) }?.key
  }

  /// The display under the pointer. `commandDisplayID()` picks the one camera commands act on.
  var pointerDisplayID: DisplayID? { displayID(at: system.cursorLocation()) ?? mainDisplayID }

  func isManaged(_ id: WindowID) -> Bool { windows[id].map(filter.manages) ?? false }

  var managedWindowIDs: [WindowID] {
    windows.values.filter(filter.manages).map(\.id).sorted()
  }

  func presentWindowIDs() -> Set<WindowID> {
    Set(windows.values.filter(\.isPresent).map(\.id))
  }

  func treeView(_ display: DisplayID) -> TreeView? {
    guard let workspace = workspaces[display] else { return nil }
    let present = presentWindowIDs()
    return TreeView(tree: workspace.tree, isPresent: { present.contains($0) })
  }

  // MARK: Persistence

  func scheduleSave() {
    scheduler.schedule("save", after: 0.5) { [weak self] in self?.saveNow() }
  }

  public func saveNow() {
    let state = persistedState()
    guard state != lastSaved else { return }
    lastSaved = state
    store.save(state)
  }

  func persistedState() -> PersistedState {
    let known = Set(
      workspaces.values.flatMap(\.allWindows) + dormant.values.flatMap(\.workspace.allWindows))
    var state = PersistedState(
      workspaces: workspaces, hints: hints.filter { known.contains($0.key) }, dormant: dormant, welcomed: hasWelcomed)
    state.hintsShown = headsUp.hintsShown
    state = state.written(with: displays)
    if isPaused { state.pause = PersistedState.Pause(until: pauseEnd, forApp: isPausedForApp) }
    return state
  }

  /// Matches saved trees against the windows that exist now: windows that
  /// survived keep their place, windows from restarted apps are matched by
  /// app and title, the rest are dropped, and new windows float.
  func reconcile() {
    let managed = Set(managedWindowIDs)
    let existing = system.existingWindowIDs()
    var claimed = Set<WindowID>()
    var pinsFoundAgain: [WindowID] = []
    // Window numbers restart after a reboot, so a saved number can belong to
    // an unrelated window now. Trust it only if the app matches.
    func isStale(_ window: WindowID) -> Bool {
      guard let hint = hints[window], let snapshot = windows[window] else { return false }
      return hint.bundleID != snapshot.bundleID
    }
    // Windows that are still where some display's saved arrangement has them stay there. They
    // must not stand in for a window with the same app and title that has closed since.
    let inPlace = Set(workspaces.values.flatMap(\.allWindows).filter { managed.contains($0) && !isStale($0) })
    for id in workspaces.keys.sorted() {
      var workspace = workspaces[id]!
      for window in workspace.tree.allWindows
      where !managed.contains(window) || claimed.contains(window) || isStale(window) {
        // Only a damaged file lists a window twice. The first place keeps it, and its hint.
        guard !claimed.contains(window) else {
          workspace.forget(window, shareSpace: settings.shareRemovedSpace)
          continue
        }
        let hint = hints.removeValue(forKey: window)
        if let hint,
          let replacement = rematch(hint, managed: managed, claimed: claimed.union(inPlace), workspace: workspace)
        {
          workspace.replaceWindow(window, with: replacement)
          undoHistory.renumber(window, as: replacement)
          hints[replacement] = hint
          claimed.insert(replacement)
        } else if let hint, windows[window] == nil || windows[window]?.bundleID != hint.bundleID {
          // Not for a window that is there, the same app's as before, and no longer arranged (its app
          // was excluded, an `ignore` rule matches it): there is nothing to wait for.
          keepSlotPending(of: window, hint: hint, existing: existing, in: &workspace)
        } else {
          workspace.forget(window, shareSpace: settings.shareRemovedSpace)
        }
      }
      claimed.formUnion(workspace.tree.allWindows)
      for window in workspace.floating.keys.sorted()
      where !managed.contains(window) || claimed.contains(window) || isStale(window) {
        // Floating windows have no place to keep, but a pin is worth finding again.
        if workspace.isPinned(window), !claimed.contains(window), let hint = hints[window],
          let replacement = rematch(hint, managed: managed, claimed: claimed.union(inPlace), workspace: workspace)
        {
          claimed.insert(replacement)
          pinsFoundAgain.append(replacement)
        }
        workspace.floating[window] = nil
      }
      claimed.formUnion(workspace.floating.keys)
      // A floating window of which no display shows more than a sliver was left parked by a run that did not
      // quit cleanly. Counting it as parked sends it back to its frame when the Desktop is in view. One that
      // merely hangs off an edge is in view: the first layout parks it properly if the Desktop is not.
      for window in workspace.floating.keys where showsOnlyASliver(window) { parked.insert(window) }
      workspaces[id] = workspace
    }
    for window in managed.subtracting(claimed).sorted() {
      adopt(window, rescue: true)
      receiveWhatOpenedUnseen(window)
    }
    for window in pinsFoundAgain {
      adopt(window, rescue: true)
      pinWhereItFloats(window)
    }
  }

  private func rematch(
    _ hint: WindowHint, managed: Set<WindowID>, claimed: Set<WindowID>, workspace: Workspace
  ) -> WindowID? {
    windows.values
      .filter {
        managed.contains($0.id) && !claimed.contains($0.id) && !workspace.contains($0.id)
          && $0.bundleID == hint.bundleID && $0.title == hint.title
      }
      .map(\.id).sorted().first
  }

  /// No display shows more of it than the line, a point or two wide, that a window out of view leaves on screen.
  /// In points and not as a share of the window: of a large one pushed aside on purpose, a strip to pull it back by
  /// is a small share.
  func showsOnlyASliver(_ window: WindowID) -> Bool {
    guard let frame = windows[window]?.frame else { return false }
    return showsOnlyASliver(frame)
  }

  func showsOnlyASliver(_ frame: CGRect) -> Bool {
    displays.allSatisfy {
      let showing = frame.intersection($0.frame)
      return showing.isNull || showing.width <= 2 || showing.height <= 2
    }
  }

  func isMostlyOffScreen(_ window: WindowID) -> Bool {
    guard let frame = windows[window]?.frame else { return false }
    return displays.allSatisfy { frame.fractionInside($0.frame) < 0.5 }
  }

  /// Starts managing `window` as a floating window on the display it is on.
  /// With `rescue`, a window found mostly off-screen (left parked by a run
  /// that did not quit cleanly) is brought back to the middle of its display.
  func adopt(_ window: WindowID, rescue: Bool) {
    guard !ignoreIfARuleSaysSo(window) else { return }
    guard let snapshot = windows[window], let displayID = displayID(at: snapshot.frame.center),
      let display = display(displayID)
    else { return }
    var frame = snapshot.frame
    // Not out of the user's hand: a window being dragged is where the pointer is.
    if rescue, isMostlyOffScreen(window), snapshot.isPresent, window != drag?.window {
      if isOutOfView(frame) { frame.size = Self.unshrunk(frame.size) }
      let visible = display.visibleFrame
      let centred = CGRect(
        x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2, width: frame.width,
        height: frame.height
      ).fitted(into: visible)
      if holdLeavesOutOfView(window) {
        // It floats like any other window that is out of view, and comes to the middle with the Desktop.
        workspaces[displayID]?.floating[window] = centred
        hints[window] = WindowHint(bundleID: snapshot.bundleID, title: snapshot.title)
        return park(window, on: display)
      }
      if let actual = system.setFrame(centred, of: window) {
        windows[window]?.frame = actual
        frame = actual
      }
      Log.info("rescued off-screen window \(window)")
    }
    workspaces[displayID]?.floating[window] = frame
    hints[window] = WindowHint(bundleID: snapshot.bundleID, title: snapshot.title)
    notify(.windows)
  }

  /// Stops managing windows the filter no longer accepts, returning them to view.
  func releaseUnmanagedWindows() {
    for id in workspaces.keys.sorted() {
      guard var workspace = workspaces[id], let display = display(id) else { continue }
      for window in workspace.allWindows where !isManaged(window) && !pendingSlots.contains(window) {
        let wasParked = parked.contains(window)
        let frame =
          frameAsItWas(of: window, on: id)
          ?? workspace.floating[window].flatMap {
            wasParked || wasPushedAside(window, from: $0) ? asItWas($0, on: display) : nil
          }
        if wasParked { noteIfInFullScreen(window, belongsAt: frame, on: display) }
        workspace.forget(window, shareSpace: settings.shareRemovedSpace)
        parked.remove(window)
        var place = frame
        if let frame {
          putBack(window, at: frame, on: display)
        } else if wasParked, var frame = windows[window]?.frame {
          frame.size = sizeInView(of: window) ?? frame.size
          let visible = display.visibleFrame
          let centred = CGRect(
            x: visible.midX - frame.width / 2, y: visible.midY - frame.height / 2,
            width: frame.width, height: frame.height
          ).fitted(into: visible)
          if let actual = system.setFrame(centred, of: window) { windows[window]?.frame = actual }
          place = centred
        }
        // Its app did not answer, and from now on no layout and no quit would look at it.
        if wasParked, let place, showsOnlyASliver(window) { owedTheWayBack[window] = place }
      }
      workspaces[id] = workspace
    }
    // Out of view when the last display went, so in no workspace to be released from. When a display comes
    // back the arrangement remembered for it drops what is not managed, and nothing would move these again.
    for window in parked.sorted() where !isManaged(window) && workspaceID(containing: window) == nil {
      bringBackWithNoDisplay(window)
      parked.remove(window)
    }
    parked = parked.filter(isManaged)
  }

  /// Tries again for `only`, or for all that are owed it.
  func payTheWayBack(to only: WindowID? = nil) {
    for (window, place) in owedTheWayBack.sorted(by: { $0.key < $1.key }) where only == nil || only == window {
      guard let actual = system.setFrame(place, of: window) else { continue }
      windows[window]?.frame = actual
      owedTheWayBack[window] = nil
    }
  }

  func adoptNewlyManagedWindows() {
    for window in managedWindowIDs where workspaceID(containing: window) == nil {
      owedTheWayBack[window] = nil
      adopt(window, rescue: true)
      receiveAsGuestOfTheView(window)
    }
  }

  // MARK: Snapshots

  public func snapshot() -> StateSnapshot {
    let displayStates = displays.compactMap { display -> StateSnapshot.Display? in
      guard let workspace = workspaces[display.id] else { return nil }
      let layout = layouts[display.id]
      var state = StateSnapshot.Display(
        id: display.id, frame: display.frame, visibleFrame: display.visibleFrame,
        camera: workspace.camera, tree: workspace.tree, windowFrames: layout?.windowFrames ?? [:],
        tiles: layout?.tiles ?? [], desktopFrame: layout?.desktopFrame,
        floating: workspace.floating.keys.sorted(), canGoBack: workspace.canGoBack,
        canGoForward: workspace.canGoForward, savedViews: workspace.savedViews)
      state.names = workspace.names
      state.named = workspace.names.values.sorted()
      state.undo = nextStepLabel(.undo, on: display.id)
      state.redo = nextStepLabel(.redo, on: display.id)
      return state
    }
    // One pass over the workspaces instead of a search of every tree for every window.
    var homes: [WindowID: (display: DisplayID, docked: Bool)] = [:]
    for (display, workspace) in workspaces.sorted(by: { $0.key < $1.key }) {
      for window in workspace.floating.keys where homes[window] == nil { homes[window] = (display, false) }
      for window in workspace.tree.allWindows { homes[window] = (display, true) }
    }
    let windowStates = windows.values.sorted { $0.id < $1.id }.map { window in
      StateSnapshot.Window(
        id: window.id, pid: window.pid, app: window.appName, bundleID: window.bundleID,
        title: window.title, frame: window.frame, minimized: window.isMinimized,
        hidden: window.isHidden, managed: filter.manages(window),
        docked: homes[window.id]?.docked ?? false,
        parked: parked.contains(window.id), display: homes[window.id]?.display,
        fullScreen: window.isFullScreen,
        guestOf: homes[window.id].flatMap { workspaces[$0.display]?.guests?[window.id] })
    }
    var snapshot = StateSnapshot(
      accessibility: accessibilityGranted, running: isRunning,
      focused: isRunning ? system.focusedWindow() : nil, displays: displayStates,
      windows: windowStates)
    snapshot.paused = isPaused
    snapshot.waiting = waitingSlots
    for index in snapshot.windows.indices {
      let role = role(of: snapshot.windows[index].id)
      snapshot.windows[index].pinned = role == .pinned
      snapshot.windows[index].stashed = role == .stashed
      if case .summoned = role { snapshot.windows[index].summoned = true }
    }
    snapshot.held = holdLevel
    return snapshot
  }

  /// Every display drawn as text.
  public func asciiDrawing(columns: Int = 72, rows: Int = 22) -> String {
    displays.compactMap { display -> String? in
      guard let layout = layouts[display.id], let workspace = workspaces[display.id] else {
        return nil
      }
      var floating: [WindowID: CGRect] = [:]
      for window in workspace.floating.keys where !parked.contains(window) {
        if let snapshot = windows[window], snapshot.isPresent { floating[window] = snapshot.frame }
      }
      let drawing = AsciiRenderer.render(
        layout, tree: workspace.tree, floating: floating, columns: columns, rows: rows, names: workspace.names,
        label: { [windows] id in "\(id) \(Self.word(for: workspace.role(of: id)))\(windows[id]?.appName ?? "")" })
      return "display \(display.id)\n" + drawing
    }.joined(separator: "\n\n")
  }

  var statusText: String {
    guard accessibilityGranted else { return permissionSentence }
    guard !isPausedForApp else {
      return "paused for \(frontmostAppName): windows, shortcuts and gestures are left alone until another app is in front"
        + noticesInStatus
    }
    guard !isPaused else {
      return "paused: windows, shortcuts and gestures are left alone until `resume`" + noticesInStatus
    }
    guard isRunning else { return "starting" }
    let docked = workspaces.values.flatMap(\.tree.allWindows).filter { !pendingSlots.contains($0) }.count
    let floating = workspaces.values.map(\.floating.count).reduce(0, +)
    let pinned = workspaces.values.map(\.pinnedWindows.count).reduce(0, +)
    let kept = pinned > 0 ? " (\(pinned) kept in view)" : ""
    return "running: \(Self.count(displays.count, "display")), \(docked) docked and \(floating) floating\(kept), "
      + "\(parked.count) out of view" + holdStatus + noticesInStatus
      + (isPassingThrough ? "; shortcuts and gestures are off in \(frontmostAppName)" : "")
  }
}
