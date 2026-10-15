import ArborCore
import ArborIPC
import CoreGraphics
import Dispatch
import Foundation

/// Identifies a window across app restarts, when its window number changes.
public struct WindowHint: Codable, Equatable, Sendable {
  public var bundleID: String?
  public var title: String

  public init(bundleID: String?, title: String) {
    self.bundleID = bundleID
    self.title = title
  }
}

/// The workspace of a display that is not connected, kept so its arrangement
/// comes back when the display does.
public struct DormantWorkspace: Codable, Equatable, Sendable {
  public var workspace: Workspace
  /// When the display went away (or, for a display missing at launch, when
  /// Arbor noticed). Arbor discards dormant workspaces 30 days after this. It also says which of two displays went first, so
  /// it is a thousandth of a second later than that where it would otherwise tie (`dateToRemember`).
  public var since: Date
  /// The display's top-left corner when it went away, in the coordinates the workspace's frames are in. It may come
  /// back somewhere else, and the frames go with it. Nil if that is not known (older files, a display missing at launch).
  public var origin: CGPoint?

  public init(workspace: Workspace, since: Date, origin: CGPoint? = nil) {
    self.workspace = workspace
    self.since = since
    self.origin = origin
  }

  /// Whether a corner read from a file can be believed. macOS's coordinates are far smaller.
  static func isPlaceForADisplay(_ corner: CGPoint) -> Bool { abs(corner.x) <= 1_000_000 && abs(corner.y) <= 1_000_000 }
}

/// What Arbor saves between launches.
public struct PersistedState: Codable, Equatable, Sendable {
  /// Raise this when a change to the format would make an older Arbor misread the file; adding
  /// optional keys does not.
  public static let currentVersion = 1
  public var version: Int = PersistedState.currentVersion
  public var workspaces: [DisplayID: Workspace]
  public var hints: [WindowID: WindowHint]
  /// Workspaces of disconnected displays, keyed by display. Files written
  /// before this existed do not have it.
  public var dormant: [DisplayID: DormantWorkspace]
  /// The welcome window has been seen, so it does not open by itself again (F46). Files written before this existed
  /// do not have it: their owners have not seen it either.
  public var welcomed: Bool
  /// The pause that was on when this was written, if one was. Only an Arbor that the watchdog started
  /// follows it (`Controller.restartedAfterAccident`): a person who starts Arbor wants it running.
  public var pause: Pause?

  public struct Pause: Codable, Equatable, Sendable {
    /// When it ends by itself. Nil: with `resume`, or with the app it is for.
    public var until: Date?
    /// Arbor began it by itself for an app in `pauseForApps`, and ends it when that app is left.
    public var forApp: Bool

    public init(until: Date?, forApp: Bool = false) {
      self.until = until
      self.forApp = forApp
    }
  }
  /// How often each teaching moment (`HeadsUpHint`) has been shown, by its name. Older files do not have it.
  public var hintsShown: [String: Int] = [:]
  /// Each connected display's top-left corner when this was written: the coordinates the frames in `workspaces` are
  /// in. The next launch may find the displays arranged otherwise (the lid shut, say), and the frames go with their
  /// display. Older files do not have it, and nothing is moved on their account.
  public var origins: [DisplayID: CGPoint]?
  /// Where Arbor left each window when it let go of them all, a quit or a pause, if it has not taken one since. A window found elsewhere
  /// at the next start was moved by somebody else (Controller+FoundAtAStart.swift). Not in a file written while Arbor runs, nor in
  /// older ones: after those, nobody can tell. Without the windows that were in full screen, whose frame then is the display's.
  public var leftAt: [WindowID: CGRect]?
  /// The leaves, by display, that were kept open for windows that were not there yet when this was written, in the
  /// minutes after a login (Controller+KeptRoom.swift). Nearly always absent, and older files do not have it.
  public var roomKept: [DisplayID: [NodeID]]?
  /// The docked windows that are where macOS put them at their person's asking, and are let be there (Controller+AppsDoubleClick.swift).
  /// Followed only by a start that nobody asked for: after a pause, a doubt about the permission, a crash. A person who starts Arbor gets
  /// what was docked docked. Nearly always absent, and older files do not have it.
  public var zoomedByMacOS: [WindowID: ZoomedWindow]?

  public struct ZoomedWindow: Codable, Equatable, Sendable {
    /// Where it is.
    public var frame: CGRect
    /// Where it was before, which is where macOS's own way back leads, and the slot it had then.
    public var began: CGRect?
    public var slot: CGRect?
    /// What a pause made of it, if it was still as large as its slot, which is no size of its own: the resume undoes that. Older files do not have it.
    public var asThePauseLeftIt: CGRect?

    public init(frame: CGRect, began: CGRect?, slot: CGRect?) {
      self.frame = frame
      self.began = began
      self.slot = slot
    }
  }

  public init(
    workspaces: [DisplayID: Workspace], hints: [WindowID: WindowHint],
    dormant: [DisplayID: DormantWorkspace] = [:], welcomed: Bool = false
  ) {
    self.workspaces = workspaces
    self.hints = hints
    self.dormant = dormant
    self.welcomed = welcomed
  }

  /// The same, saying that its frames are in the coordinates of `displays`.
  public func written(with displays: [DisplaySnapshot]) -> PersistedState {
    var state = self
    let corners = displays.filter { workspaces[$0.id] != nil }.map { ($0.id, $0.frame.origin) }
    state.origins = corners.isEmpty ? nil : Dictionary(corners) { first, _ in first }
    return state
  }

  /// What a launch starts from (`Workspace.showEverything`), on the displays that are not connected too: they may be by now,
  /// or come back while this run lasts.
  public func showingEverything() -> PersistedState { changingEveryWorkspace { $0.showEverything() } }

  /// What is written: no look outlasts Arbor (`Workspace.stayAfterALook`).
  public func withEveryLookOver() -> PersistedState { changingEveryWorkspace { $0.stayAfterALook() } }

  private func changingEveryWorkspace(_ change: (inout Workspace) -> Void) -> PersistedState {
    var state = self
    for id in state.workspaces.keys { change(&state.workspaces[id]!) }
    for id in state.dormant.keys { change(&state.dormant[id]!.workspace) }
    return state
  }

  private enum CodingKeys: String, CodingKey {
    case version, workspaces, hints, dormant, welcomed, pause
    case hintsShown
    case origins
    case leftAt
    case roomKept
    case zoomedByMacOS
  }

  public init(from decoder: any Decoder) throws {
    let c = try decoder.container(keyedBy: CodingKeys.self)
    version = try c.decode(Int.self, forKey: .version)
    // Entry by entry: a display or a hint that cannot be read costs only itself. What was skipped or
    // repaired is noted in the decoder's `DecodingNotes`.
    workspaces = try c.decode(LossyDictionary<DisplayID, Workspace>.self, forKey: .workspaces).entries
    hints = try c.decode(LossyDictionary<WindowID, WindowHint>.self, forKey: .hints).entries
    dormant =
      try c.decodeIfPresent(LossyDictionary<DisplayID, DormantWorkspace>.self, forKey: .dormant)?.entries ?? [:]
    // A value that cannot be read costs a second look at the welcome window, not the arrangement.
    welcomed = (try? c.decodeIfPresent(Bool.self, forKey: .welcomed)) ?? false
    // Not worth losing the arrangement over.
    do {
      pause = try c.decodeIfPresent(Pause.self, forKey: .pause)
    } catch {
      pause = nil
      (decoder.userInfo[DecodingNotes.key] as? DecodingNotes)?.add("`pause` could not be read")
    }
    // Not worth losing an arrangement over: counts that cannot be read start again.
    do {
      hintsShown = try c.decodeIfPresent([String: Int].self, forKey: .hintsShown) ?? [:]
    } catch {
      hintsShown = [:]
      (decoder.userInfo[DecodingNotes.key] as? DecodingNotes)?.add("`hintsShown` could not be read", isLoss: false)
    }
    // Nor over this. A corner that is no place for a display would send every frame to no place for a window.
    let corners = (try? c.decodeIfPresent(LossyDictionary<DisplayID, CGPoint>.self, forKey: .origins))?.entries
    origins = corners?.filter { DormantWorkspace.isPlaceForADisplay($0.value) }
    // Unreadable is as good as absent: then what is remembered is trusted, as it always was. All or nothing, and nothing a person made.
    do {
      leftAt = try c.decodeIfPresent([WindowID: CGRect].self, forKey: .leftAt)
    } catch {
      leftAt = nil
      (decoder.userInfo[DecodingNotes.key] as? DecodingNotes)?.add("`leftAt` could not be read", isLoss: false)
    }
    // Nor over this: those windows move once more than they had to.
    roomKept = (try? c.decodeIfPresent(LossyDictionary<DisplayID, [NodeID]>.self, forKey: .roomKept))?.entries
    // Nor over this: that window is docked like the rest.
    zoomedByMacOS = (try? c.decodeIfPresent(LossyDictionary<WindowID, ZoomedWindow>.self, forKey: .zoomedByMacOS))?.entries
    for id in dormant.keys where dormant[id]!.origin.map(DormantWorkspace.isPlaceForADisplay) == false {
      dormant[id]!.origin = nil
    }
  }
}

extension PersistedState {
  /// What the bytes of a state file turned out to be.
  public enum ReadResult: Equatable, Sendable {
    case loaded(PersistedState)
    /// Written by a newer Arbor. This version would misread it, or drop what it does not know when
    /// it next saved.
    case newer(version: Int)
    case unreadable(reason: String)
  }

  /// A file can be valid JSON of the right shape and still describe a tree whose links form a loop,
  /// which would hang or crash Arbor at every launch. Trees and workspaces see to that themselves as
  /// they are decoded (`LayoutTree+Decoding.swift`): what loads is safe to use. What they had to
  /// repair, and the displays and hints that had to be left out, are listed in `notes`, for the log.
  public static func read(_ data: Data, notes: DecodingNotes = DecodingNotes()) -> ReadResult {
    struct Header: Decodable { var version: Int }
    let decoder = JSONDecoder()
    decoder.userInfo[DecodingNotes.key] = notes
    // The version first: the rest of a newer file need not decode at all.
    if let header = try? decoder.decode(Header.self, from: data), header.version > currentVersion {
      return .newer(version: header.version)
    }
    do {
      let state = try decoder.decode(PersistedState.self, from: data)
      // What was repaired is not written back either, and has been noted with its reason.
      if notes.notes.isEmpty { for key in keysLeftOut(of: data, by: state) { notes.add(key) } }
      return .loaded(state)
    } catch {
      return .unreadable(reason: "\(error)")
    }
  }

  /// The fields of the file that would not be in it after the next save, one line each. A later Arbor may add keys
  /// without raising the format (`currentVersion`); this one reads past them, and half a second after starting
  /// it would save without them. Noted like a repair, so that the file is kept as it was.
  private static func keysLeftOut(of data: Data, by state: PersistedState) -> [String] {
    // Their keys are displays, windows, spaces, apps and names, not fields. An entry that is dropped (a guest whose
    // window has gone elsewhere) is the decoders' business, and most are not worth a word.
    let tables: Set = [
      "workspaces", "dormant", "hints", "nodes", "floating", "guests", "undockedFrames", "summonFrames", "names",
      "savedViews", "hintsShown", "leftAt", "roomKept",
    ]
    guard let file = try? JSONSerialization.jsonObject(with: data),
      let written = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
    else { return [] }
    var found: [String] = []
    func compare(_ file: Any, _ written: Any?, _ path: [String]) {
      guard let file = file as? [String: Any] else { return }
      let written = written as? [String: Any]
      for key in file.keys.sorted() {
        let value = file[key]!
        // Nothing is as good as absent: Arbor itself leaves out what is empty.
        if value is NSNull || (value as? [Any])?.isEmpty == true || (value as? [String: Any])?.isEmpty == true {
          continue
        }
        if let other = written?[key] {
          compare(value, other, path + [key])
        } else if !tables.contains(path.last ?? "") {
          found.append("\((path + [key]).joined(separator: ".")) is not read by this version, and will not be saved again")
        }
      }
    }
    compare(file, written, [])
    return found
  }
}

/// What was wrong with the saved state at the last `load()`, for `status` and the menu. The details are in the log.
public enum StateLoadProblem: Equatable, Sendable {
  /// Not loaded; set aside.
  case unreadable
  /// Written by a newer Arbor. Not loaded; set aside.
  case newer
  /// Loaded, with repairs (`repairs`): from a view on a space that is gone to a display's whole arrangement left out.
  /// A copy of the file as it was is kept.
  case repaired
  /// There is no file, but one that was set aside: by a rescue (`ARBOR_RESCUE`), which quits at once, or by a run that
  /// ended before its first save. This launch is the first that can say so.
  case setAsideEarlier
}

@MainActor
public protocol StateStore: AnyObject {
  func load() -> PersistedState?
  /// About the last `load()`. Nil if there was nothing wrong, or no file.
  var loadProblem: StateLoadProblem? { get }
  /// Saves `state`, now or shortly. Saves take effect in the order they were made.
  func save(_ state: PersistedState)
  /// Returns once everything saved so far is on disk. Called before Arbor quits.
  func flush()
  /// What the last `load` had to repair or leave out, one line each. Empty if nothing was wrong.
  var repairs: [String] { get }
  /// The name of the file that holds what was there before the last `load`, if anything was wrong with it.
  var keptCopy: String? { get }
}

extension StateStore {
  public func flush() {}
  public var repairs: [String] { [] }
  public var keptCopy: String? { nil }
}

/// Saves state as JSON in Arbor's home folder. Encoding a big desk takes milliseconds and the disk can take
/// longer, and a save follows every change, so both happen on a queue of their own, in order.
@MainActor
public final class FileStateStore: StateStore {
  private let url: URL
  private let queue = DispatchQueue(label: "dev.arbor.state", qos: .utility)
  public private(set) var loadProblem: StateLoadProblem?
  public private(set) var repairs: [String] = []
  public private(set) var keptCopy: String?

  public init(url: URL = ArborPaths.stateFile) {
    self.url = url
  }

  public func load() -> PersistedState? {
    flush()
    loadProblem = nil
    repairs = []
    keptCopy = nil
    guard FileManager.default.fileExists(atPath: url.path) else {
      if FileManager.default.fileExists(atPath: aside.path) {
        loadProblem = .setAsideEarlier
        keptCopy = aside.lastPathComponent
      }
      return nil
    }
    let result: PersistedState.ReadResult
    let notes = DecodingNotes()
    var data = Data()
    do {
      data = try Data(contentsOf: url)
      result = PersistedState.read(data, notes: notes)
    } catch {
      result = .unreadable(reason: "\(error)")
    }
    switch result {
    case .loaded(let state):
      // What a person could tell is an error, and worth a word to them. What was merely tidied (`DecodingNotes`)
      // Arbor could have written itself, and earlier versions did: history that ends where the view is, after
      // zoom, close and quit. To greet somebody with "was damaged" for that would be a false alarm.
      for note in notes.losses { Log.error("state.json: \(note)") }
      for note in notes.tidied { Log.info("state.json: tidied: \(note)") }
      repairs = notes.losses
      if !repairs.isEmpty { loadProblem = .repaired }
      // The copy is made either way. In a damaged file what is tidied can be all that was left of something real:
      // where `floating` is gone without a word (null, or under another name beside a tidying), so are the pins and guests.
      if !notes.notes.isEmpty { keepACopy(of: data, quietly: repairs.isEmpty) }
      return state
    case .newer(let version):
      loadProblem = .newer
      Log.error("state.json is from a newer Arbor (format \(version); this one reads \(PersistedState.currentVersion))")
    case .unreadable(let reason):
      loadProblem = .unreadable
      Log.error("could not read saved state: \(reason)")
    }
    setAside()
    return nil
  }

  /// Moves the file out of the way, as state.unreadable.json, so that Arbor starts fresh. Arbor saves
  /// soon after starting, and the file may be all that a newer version, or whoever looks into the
  /// damage, has to go on; so it is never simply overwritten.
  /// Removes the file. For a rescue, whose own save on quitting holds nothing worth keeping and would hide from the next
  /// launch that the arrangement was set aside.
  public func discard() {
    flush()
    try? FileManager.default.removeItem(at: url)
  }

  private var aside: URL { url.deletingPathExtension().appendingPathExtension("unreadable.json") }

  public func setAside() {
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    try? FileManager.default.removeItem(at: aside)
    do {
      try FileManager.default.moveItem(at: url, to: aside)
      keptCopy = aside.lastPathComponent
      Log.error("starting fresh; the old state is now \(aside.lastPathComponent)")
    } catch {
      Log.error("starting fresh; could not set the old state aside: \(error)")
    }
  }

  /// How many files `keepACopy` leaves at most.
  static let mostCopies = 3

  /// A file that was read with repairs is in use, so it stays, and will be saved over in a moment. What could not
  /// be read (a display's whole arrangement, for one) would be gone with that, so the bytes as they were go beside
  /// it: state.before-repair.json, then .2 and .3. The first is never written over, because later ones may be
  /// Arbor's own saves of what it had repaired; the last place holds the latest.
  private func keepACopy(of data: Data, quietly: Bool) {
    let base = url.deletingPathExtension()
    let names = (1...Self.mostCopies).map { $0 == 1 ? "before-repair.json" : "before-repair.\($0).json" }
    let places = names.map { base.appendingPathExtension($0) }
    let place = places.first { !FileManager.default.fileExists(atPath: $0.path) } ?? places.last!
    do {
      try data.write(to: place, options: .atomic)
      // Window titles are in here too.
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: place.path)
      keptCopy = place.lastPathComponent
      let news = "state.json as it was before these repairs is now \(place.lastPathComponent)"
      if quietly { Log.info(news) } else { Log.error(news) }
    } catch {
      Log.error("could not keep state.json as it was before these repairs: \(error)")
    }
  }

  public func save(_ state: PersistedState) {
    queue.async { [self] in write(state) }
  }

  public func flush() {
    queue.sync {}
  }

  /// Runs on `queue`.
  private nonisolated func write(_ state: PersistedState) {
    do {
      let encoder = JSONEncoder()
      encoder.outputFormatting = [.sortedKeys]
      let data = try encoder.encode(state)
      try ArborPaths.ensureHome()
      try data.write(to: url, options: .atomic)
      // Window titles are in here. The app's umask already gives this; tools and tests have their own.
      try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    } catch {
      Log.error("could not save state: \(error)")
    }
  }
}

/// Loads and saves `settings.json`, which holds only what differs from the defaults (SettingsFileFormat.swift). The
/// first launch writes one, so there is a file to edit. People do edit it, so Arbor writes a whole file only
/// where there is none, changes an existing one key by key (`update`), and
/// never writes to one it cannot read, unless it is asked to replace it (`replace`).
public enum SettingsFile {
  /// Thrown by `read` where there is no file, or nothing but white space in it.
  public struct Missing: Error, Equatable, CustomStringConvertible {
    public init() {}
    public var description: String { "there is no such file" }
  }

  /// What Arbor starts with: the file's settings, or the defaults if there is no file (one is
  /// written) or it cannot be read (it is left alone).
  public static func load(from url: URL = ArborPaths.settingsFile) -> Settings {
    upgrade(at: url)
    do {
      let settings = try read(from: url)
      logProblems(in: settings)
      return settings
    } catch is Missing {
      create(Settings(), at: url)
      return Settings()
    } catch {
      Log.error("settings.json cannot be read, using the defaults: \(forTheLog(error))")
      return Settings()
    }
  }

  /// Once, at a launch: a file from the days when the first launch wrote every default down is stripped of what nobody chose, and
  /// marked (`Settings.upgradedFile`). It is somebody's file, so a copy stays beside it as settings.before-format-2.json. A file that
  /// cannot be read, copied or written is left as it is, and looked at again at the next launch. A file of a few keys, which somebody wrote
  /// by hand, only gets the mark.
  static func upgrade(at url: URL) {
    do {
      guard let data = try contents(of: url), String(data: data, encoding: .utf8) != nil,
        let upgraded = try Settings.upgradedFile(String(decoding: data, as: UTF8.self))
      else { return }
      // Asked before the copy is made, or a file that may not be written would get a new copy at every launch.
      guard FileManager.default.isWritableFile(atPath: destination(of: url).path) else {
        throw Settings.FileError("the file is read-only")
      }
      // What was read, not what lies there by now. And the first copy stays: it is the one with the whole old file. (Somebody who later puts
      // a file without the mark in its place has that one upgraded too.)
      // No copy where nothing is taken out: nothing is lost, and the name would be taken when a whole old file comes after all.
      let copy = url.deletingPathExtension().appendingPathExtension("before-format-\(Settings.format).json")
      if !upgraded.stripped.isEmpty, !FileManager.default.fileExists(atPath: copy.path) {
        do {
          try data.write(to: copy, options: .atomic)
        } catch {
          throw Settings.FileError("no copy could be kept as \(copy.lastPathComponent) (\(error.localizedDescription))")
        }
      }
      try write(upgraded.text, to: url)
      // The names of settings, never their values.
      Log.info(
        upgraded.stripped.isEmpty
          ? "settings.json has the mark now; nothing was taken out of it"
          : "settings.json now holds only what differs from the defaults; taken out, to follow the defaults from now on: "
            + upgraded.stripped.joined(separator: ", "))
    } catch {
      Log.error("settings.json stays as it is, without the mark: \(forTheLog(error))")
    }
  }

  /// Reads the file without falling back on anything, for a reload: when it throws, the caller
  /// keeps the settings it has. Throws `Missing`, or a `Settings.FileError` that says what is wrong
  /// with the file as a whole. Single values Arbor cannot use are set right and listed in the
  /// result (`valueProblems`, `skippedRules`).
  public static func read(from url: URL = ArborPaths.settingsFile) throws -> Settings {
    guard let data = try contents(of: url) else { throw Missing() }
    return try Settings.read(data)
  }

  /// An error as it may be logged: without what it quotes from the file (`Settings.FileError`).
  static func forTheLog(_ error: any Error) -> String { (error as? Settings.FileError)?.forTheLog ?? "\(error)" }

  /// One log line for everything in settings.json that Arbor could not use as written: where, not what (`problemsForTheLog`).
  static func logProblems(in settings: Settings) {
    for problem in settings.problemsForTheLog { Log.error("settings.json: \(problem)") }
  }

  /// Writes a whole file where there is none, or only a blank one. Leaves any other file alone.
  public static func create(_ settings: Settings, at url: URL = ArborPaths.settingsFile) {
    do {
      if try contents(of: url) == nil { try write(try settings.fileText, to: url) }
    } catch {
      Log.error("could not write settings: \(error)")
    }
  }

  /// Writes what changed between `old` and `new` into the file and leaves the rest of it as it is
  /// (see `Settings.rewrite` for what `old` should be), but for the mark, which somebody's own file gets with it
  /// (`Settings.rewriteAndMark`). Throws a `Settings.FileError`, without touching the file, if Arbor cannot read it.
  public static func update(from old: Settings, to new: Settings, at url: URL = ArborPaths.settingsFile) throws {
    guard let data = try contents(of: url) else { return try write(try new.fileText, to: url) }
    // Checked, then decoded without a check: that way a byte order mark stays in the text.
    guard String(data: data, encoding: .utf8) != nil else {
      throw Settings.FileError("the file is not UTF-8 text, so Arbor cannot change it")
    }
    let text = String(decoding: data, as: UTF8.self)
    let rewritten = try Settings.rewriteAndMark(text, from: old, to: new)
    if rewritten != text { try write(rewritten, to: url) }
  }

  /// Writes a whole new file whatever is there: the way out, on request (`reset everything`), when the
  /// file cannot be read or cannot be changed. Somebody wrote that file, so a copy stays beside
  /// settings.json as settings.unreadable.json, in place of an earlier one. Returns the copy's name, or nil if there was
  /// nothing to copy.
  @discardableResult
  public static func replace(with settings: Settings, at url: URL = ArborPaths.settingsFile) throws -> String? {
    let text = try settings.fileText
    let files = FileManager.default
    let aside = url.deletingPathExtension().appendingPathExtension("unreadable.json")
    // Under another name until the new file is written: if that fails, the earlier copy is still the only one.
    let pending = aside.appendingPathExtension("new")
    try? files.removeItem(at: pending)
    let old = destination(of: url)
    if files.fileExists(atPath: old.path) {
      do {
        try files.copyItem(at: old, to: pending)
      } catch {
        throw Settings.FileError("the old file could not be kept as \(aside.lastPathComponent), so it stays")
      }
    }
    do {
      try write(text, to: url)
    } catch {
      try? files.removeItem(at: pending)
      throw error
    }
    guard files.fileExists(atPath: pending.path) else { return nil }
    try? files.removeItem(at: aside)
    try? files.moveItem(at: pending, to: aside)
    return aside.lastPathComponent
  }

  /// Keeps a copy of the file as it is beside settings.json, as settings.before-reset.json, in place of an earlier one:
  /// what `reset` is about to empty took somebody a while to make. Returns the copy's name, or nil if there is no file.
  public static func keepCopy(of url: URL = ArborPaths.settingsFile) throws -> String? {
    let files = FileManager.default
    let old = destination(of: url)
    guard files.fileExists(atPath: old.path) else { return nil }
    let copy = url.deletingPathExtension().appendingPathExtension("before-reset.json")
    // Under another name first: if copying fails, the earlier copy is still there.
    let pending = copy.appendingPathExtension("new")
    try? files.removeItem(at: pending)
    do {
      try files.copyItem(at: old, to: pending)
      try? files.removeItem(at: copy)
      try files.moveItem(at: pending, to: copy)
    } catch {
      try? files.removeItem(at: pending)
      throw Settings.FileError("no copy could be kept as \(copy.lastPathComponent) (\(error.localizedDescription))")
    }
    return copy.lastPathComponent
  }

  /// The file at `url`, or the one it is a link to, whether or not that exists.
  private static func destination(of url: URL) -> URL {
    let resolved = url.resolvingSymlinksInPath()
    // A link to nothing is left as it is by that call.
    guard let path = try? FileManager.default.destinationOfSymbolicLink(atPath: resolved.path) else {
      return resolved
    }
    return URL(fileURLWithPath: path, relativeTo: resolved.deletingLastPathComponent()).standardizedFileURL
  }

  /// What is in the file, or nil if there is no file or nothing but white space in it.
  private static func contents(of url: URL) throws -> Data? {
    guard FileManager.default.fileExists(atPath: url.path) else {
      if (try? FileManager.default.destinationOfSymbolicLink(atPath: url.path)) != nil {
        throw Settings.FileError("it is a link to a file that does not exist")
      }
      return nil
    }
    do {
      let data = try Data(contentsOf: url)
      return data.allSatisfy { [0x20, 0x09, 0x0A, 0x0D].contains($0) } ? nil : data
    } catch {
      throw Settings.FileError("the file cannot be opened (\(error.localizedDescription))")
    }
  }

  private static func write(_ text: String, to url: URL) throws {
    // An atomic write puts a new file at the path, whatever was there. So where that is a link
    // (dotfile managers keep the real file elsewhere), write to the file it points at; respect a
    // file marked read-only; and give the new file the old one's permissions.
    let target = destination(of: url)
    let permissions = try? FileManager.default.attributesOfItem(atPath: target.path)[.posixPermissions]
    guard permissions == nil || FileManager.default.isWritableFile(atPath: target.path) else {
      throw Settings.FileError("the file is read-only")
    }
    do {
      try FileManager.default.createDirectory(
        at: target.deletingLastPathComponent(), withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700])
      try Data(text.utf8).write(to: target, options: .atomic)
    } catch {
      throw Settings.FileError("the file cannot be written (\(error.localizedDescription))")
    }
    if let permissions {
      try? FileManager.default.setAttributes([.posixPermissions: permissions], ofItemAtPath: target.path)
    }
  }
}
