import ArborCore

/// `fix-setup`: the one step (docs/features/F42-setup-check.md). As a Mac comes, macOS tiles a window that is dragged to a screen
/// edge or with ⌥ held, and fills the screen with one dragged to the menu bar: the same drags Arbor is used with. `doctor` and the
/// welcome window find that out before anything is arranged; this switches it off for whoever asks, instead of sending them to look
/// for three switches in System Settings.
///
/// Only when asked, never by itself. Only what is in the way. All of it or none of it. And how each switch was stored before is
/// written down first (`MacSwitchboard.keep`), so that the Mac can be put back exactly as it was.
///
/// **Only while Arbor arranges windows.** Leave things as you found them: whenever Arbor stops (a quit, a pause, the permission gone) it
/// gives the switches back, and takes them again when it starts. So back to normal is one thing, Quit. What is written down stays
/// meanwhile, marked `isGivenBack`: it is somebody's choice, made once. `fix-setup undo` ends it. A switch that no longer stands as Arbor
/// left it is its owner's, and is forgotten.
///
/// Wherever Arbor ends, nothing is off that is not written down as owed: taking is written down before the switches are touched, giving
/// back after.
extension Controller {
  private static let place = "System Settings → Desktop & Dock"
  private static let unreadable =
    "what Arbor wrote down about macOS’s settings cannot be read (\(MacSwitchLedger.fileName)), so nothing was changed; see \(place)"

  /// The settings of macOS that can be in Arbor's way, as they stand. Nil if they cannot be read. What `fix-setup` touches, and what
  /// `doctor` and Check Setup… weigh, both by `MacSwitch.weight`.
  func macSwitchesInTheWay(_ facts: SystemFacts?) -> [MacSwitch]? {
    let lent = macSwitchesLent
    return facts?.switches?.filter { $0.isInArborsWay && !lent.contains($0) }
  }

  /// The switches Arbor keeps off while it runs, because somebody asked it to.
  public var macSwitchesChangedByArbor: [MacSwitch] { macSwitchboard?.records()?.map(\.item) ?? [] }

  /// Those of them that macOS has back because Arbor is not arranging windows: on by Arbor's own doing, and in nobody's way. In a
  /// running Arbor none is: one that could not be taken again is as much in the way as any.
  public var macSwitchesLent: [MacSwitch] {
    isRunning && !isTurning ? [] : macSwitchboard?.records()?.filter(\.isGivenBack).map(\.item) ?? []
  }

  /// Those that are on though somebody asked Arbor to keep them off and Arbor arranges windows: it could not take them again at its
  /// start (a full disk, a Mac managed by somebody else). One that a person has switched on again by hand is theirs, and is not among them.
  var macSwitchesAskedForInVain: [MacSwitch] {
    isRunning && !isTurning ? macSwitchboard?.records()?.filter(\.isGivenBack).map(\.item) ?? [] : []
  }

  /// When a window dragged to a screen edge docks. Never, too, for whoever has no band of Arbor's along the edges of any display.
  var edgeDrags: DragDocks {
    displays.isEmpty || displays.contains { options(for: $0.id).dropOptions.offersScreenEdges } ? dragDocks : .never
  }

  /// Needs no Accessibility permission, so it works before `start()`: the welcome window offers it from the first moment.
  func fixSetup(undo: Bool) -> CommandResult {
    guard let board = macSwitchboard else {
      return .failure("this Arbor cannot change settings of macOS; see \(Self.place)")
    }
    let result = undo ? Self.putBack(on: board) : switchOff(on: board)
    // Names of settings, never of apps or windows.
    Log.info("\(Command.fixSetup(undo: undo).text): \(result.message)")
    return result
  }

  private var whyNotNow: String { isPaused ? "is paused" : "may not arrange windows" }

  private func switchOff(on board: any MacSwitchboard) -> CommandResult {
    // What cannot be read is not "in order".
    guard let inTheWay = macSwitchesInTheWay(systemFacts?()) else {
      return .failure("how macOS’s settings stand cannot be read here; see \(Self.place)")
    }
    let mine = inTheWay.filter(\.canBeSwitchedOffForYou)
    let theirs = inTheWay.contains(.stageManager) ? "Stage Manager is yours to switch off: \(Self.place)" : nil
    guard !mine.isEmpty else {
      if let theirs { return .failure(theirs) }
      // The choice has been made, and is acted on by itself.
      return macSwitchesLent.isEmpty
        ? .success("no setting of macOS is in Arbor’s way")
        : .failure("macOS has its settings back while Arbor \(whyNotNow); Arbor switches them off again when it starts")
    }
    guard let known = board.records() else { return .failure(Self.unreadable) }
    // Written down before anything is changed, as a choice that has yet to be acted on. What an earlier round wrote down about a switch
    // stays: that is how the Mac was before Arbor. What it wrote down about other switches is not touched.
    let chosen = mine.map { item in
      MacSwitchRecord(item, stored: known.first { $0.item == item }.map(\.stored) ?? board.stored(item), isGivenBack: true)
    }
    // No way back, no step: a full disk must not leave somebody with settings they cannot account for.
    guard board.keep(known.filter { !mine.contains($0.item) } + chosen) else {
      return .failure("could not write down how the settings are, so nothing was changed; try \(Self.place)")
    }
    let (one, also) = (mine.count == 1, theirs.map { ". \($0)" } ?? "")
    guard isRunning else {
      macSwitchesDidChange?()
      return .success(
        "noted: Arbor keeps \(mine.count) setting\(one ? "" : "s") of macOS under Desktop & Dock off while it runs. It \(whyNotNow) now, so "
          + "nothing has changed yet; `fix-setup undo` takes that back" + also)
    }
    guard Self.take(on: board, asked: mine) == [] else {
      // All or nothing: half a step would be harder to account for than none. Of this round only: what an earlier one took stays taken.
      for record in chosen where board.stored(record.item) == false { board.store(record.stored, for: record.item) }
      _ = board.keep(known)
      macSwitchesDidChange?()
      return .failure("macOS did not keep the change (is this Mac managed by somebody else?), so nothing was changed; try \(Self.place)")
    }
    macSwitchesDidChange?()
    return .success(
      "switched off \(mine.count) setting\(one ? "" : "s") of macOS under Desktop & Dock for as long as Arbor runs; `fix-setup undo` puts "
        + "\(one ? "it back as it was" : "them back as they were") for good" + also)
  }

  /// Without a controller: `Arbor --fix-setup undo` is how `make uninstall` leaves the Mac as Arbor found it, running or not.
  static func putBack(on board: any MacSwitchboard) -> CommandResult {
    guard let records = board.records() else { return .failure(unreadable) }
    guard !records.isEmpty else { return .failure("Arbor has changed no setting of macOS") }
    guard let (back, owed) = give(on: board, forgetting: true) else { return .failure(unreadable) }
    guard owed == 0 else {
      return .failure(
        "macOS did not take \(owed) of \(back + owed) settings back (is this Mac managed by somebody else?); "
          + "they stay written down, and \(place) has the switches")
    }
    return .success(
      back == 0
        ? "macOS has its settings under Desktop & Dock as they were already; from now on Arbor leaves them alone"
        : "put \(back) setting\(back == 1 ? "" : "s") of macOS under Desktop & Dock back as \(back == 1 ? "it was" : "they were")")
  }

  // MARK: Only while Arbor arranges windows

  /// Called wherever Arbor ends up not arranging windows: `shutdown`, a start that comes back paused, a launch without the permission.
  public func giveMacSwitchesBack() {
    guard let board = macSwitchboard, let (back, owed) = Self.give(on: board, forgetting: false), back + owed > 0 else { return }
    Log.info("gave \(back) of \(back + owed) settings of macOS back until Arbor starts again")
    macSwitchesDidChange?()
  }

  /// Called at the end of `start`, once it is known that Arbor stays running: behind an app it pauses for it takes nothing, even for a moment.
  func takeMacSwitchesAgain() {
    guard isRunning, let board = macSwitchboard, let refused = Self.take(on: board) else { return }
    if !refused.isEmpty { Log.info("macOS did not let Arbor switch \(refused.count) of its settings off again") }
    macSwitchesDidChange?()
  }

  /// Puts back what is off and still stands as Arbor set it. What somebody has flipped since is theirs: left alone, and forgotten.
  /// - Parameter forgetting: the choice goes too. Otherwise it stays on record, marked.
  /// - Returns: how many went back, and how many macOS did not take, which stay written down as owed. Nil: the record cannot be read.
  private static func give(on board: any MacSwitchboard, forgetting: Bool) -> (back: Int, owed: Int)? {
    guard let records = board.records() else { return nil }
    let mine = records.filter { !$0.isGivenBack && board.stored($0.item) == false }
    for record in mine { board.store(record.stored, for: record.item) }
    let owed = mine.filter { board.stored($0.item) != $0.stored }
    let kept = forgetting ? [] : records.filter(\.isGivenBack) + mine.filter { !owed.contains($0) }.map(\.givenBack)
    let now = records.compactMap { record in (owed + kept).first { $0.item == record.item } }
    if now != records { _ = board.keep(now) }
    return (mine.count - owed.count, owed.count)
  }

  /// Switches off what is on record as given back and still stands as it was given. What somebody has flipped since is theirs, and so is
  /// what is on record as off and is not (Arbor ended without quitting, and they are off still, or somebody has been there).
  /// - Parameter asked: somebody has just asked for these, however they stand.
  /// - Returns: what macOS did not let go of, which stays marked. Nil: nothing is on record, or it cannot be read or written, and nothing was touched.
  private static func take(on board: any MacSwitchboard, asked: [MacSwitch] = []) -> [MacSwitch]? {
    guard let records = board.records(), !records.isEmpty else { return nil }
    let standing = records.filter { asked.contains($0.item) || board.stored($0.item) == ($0.isGivenBack ? $0.stored : false) }
    let again = standing.filter(\.isGivenBack)
    let taken = standing.map(\.taken)
    guard taken == records || board.keep(taken) else { return nil }
    for record in again { board.store(false, for: record.item) }
    let refused = again.filter { board.stored($0.item) != false }
    if !refused.isEmpty {
      // What was written is taken back: a value that somebody's profile only hides comes into force the day the profile goes.
      for record in refused { board.store(record.stored, for: record.item) }
      _ = board.keep(standing.map { refused.contains($0) ? $0 : $0.taken })
    }
    return refused.map(\.item)
  }
}

extension MacSwitchRecord {
  fileprivate var taken: MacSwitchRecord { MacSwitchRecord(item, stored: stored) }
  fileprivate var givenBack: MacSwitchRecord { MacSwitchRecord(item, stored: stored, isGivenBack: true) }
}
