import ArborCore

/// `fix-setup`: the one step (docs/features/F42-setup-check.md). As a Mac comes, macOS tiles a window that is dragged to a screen
/// edge or with ⌥ held, and fills the screen with one dragged to the menu bar: the same drags Arbor is used with. `doctor` and the
/// welcome window find that out before anything is arranged; this switches it off for whoever asks, instead of sending them to look
/// for three switches in System Settings.
///
/// Only when asked, never by itself. Only what is in the way. All of it or none of it. And how each switch was stored before is
/// written down first (`MacSwitchboard.keep`), so that `fix-setup undo` puts the Mac back exactly as it was, at any later time.
extension Controller {
  private static let place = "System Settings → Desktop & Dock"
  private static let unreadable =
    "what Arbor wrote down about macOS’s settings cannot be read (\(MacSwitchLedger.fileName)), so nothing was changed; see \(place)"

  /// The settings of macOS in Arbor's way as they stand. Nil if they cannot be read. The one rule for what `doctor` calls a
  /// problem, what the welcome window lists and what `fix-setup` touches.
  func macSwitchesInTheWay(_ facts: SystemFacts?) -> [MacSwitch]? { facts?.switches?.filter(\.isInArborsWay) }

  /// The switches Arbor switched off and has not put back.
  public var macSwitchesChangedByArbor: [MacSwitch] { macSwitchboard?.records()?.map(\.item) ?? [] }

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

  private func switchOff(on board: any MacSwitchboard) -> CommandResult {
    // What cannot be read is not "in order".
    guard let inTheWay = macSwitchesInTheWay(systemFacts?()) else {
      return .failure("how macOS’s settings stand cannot be read here; see \(Self.place)")
    }
    let mine = inTheWay.filter(\.canBeSwitchedOffForYou)
    let theirs = inTheWay.contains(.stageManager) ? "Stage Manager is yours to switch off: \(Self.place)" : nil
    guard !mine.isEmpty else {
      return theirs.map { .failure($0) } ?? .success("no setting of macOS is in Arbor’s way")
    }
    guard let known = board.records() else { return .failure(Self.unreadable) }
    // Written down before anything is changed. What an earlier round wrote down stays: that is how the Mac was before Arbor.
    let asTheyAre = mine.map { MacSwitchRecord($0, stored: board.stored($0)) }
    let new = asTheyAre.filter { record in !known.contains { $0.item == record.item } }
    // No way back, no step: a full disk must not leave somebody with settings they cannot account for.
    guard board.keep(known + new) else {
      return .failure("could not write down how the settings are, so nothing was changed; try \(Self.place)")
    }
    for item in mine { board.store(false, for: item) }
    guard mine.allSatisfy({ board.stored($0) == false }) else {
      // All or nothing: half a step would be harder to account for than none. What was written is taken back before it is forgotten,
      // because a value that somebody's profile only hides comes into force the day the profile goes.
      for record in asTheyAre { board.store(record.stored, for: record.item) }
      _ = board.keep(known)
      return .failure("macOS did not keep the change (is this Mac managed by somebody else?), so nothing was changed; try \(Self.place)")
    }
    let one = mine.count == 1
    return .success(
      "switched off \(mine.count) setting\(one ? "" : "s") of macOS under Desktop & Dock; `fix-setup undo` puts "
        + "\(one ? "it back as it was" : "them back as they were")" + (theirs.map { ". \($0)" } ?? ""))
  }

  /// Without a controller: `Arbor --fix-setup undo` is how `make uninstall` leaves the Mac as Arbor found it, running or not.
  static func putBack(on board: any MacSwitchboard) -> CommandResult {
    guard let records = board.records() else { return .failure(unreadable) }
    guard !records.isEmpty else { return .failure("Arbor has changed no setting of macOS") }
    for record in records { board.store(record.stored, for: record.item) }
    // What did not go back is still owed, and stays written down.
    let owed = records.filter { board.stored($0.item) != $0.stored }
    _ = board.keep(owed)
    guard owed.isEmpty else {
      return .failure(
        "macOS did not take \(owed.count) of \(records.count) settings back (is this Mac managed by somebody else?); "
          + "they stay written down, and \(place) has the switches")
    }
    let one = records.count == 1
    return .success(
      "put \(records.count) setting\(one ? "" : "s") of macOS under Desktop & Dock back as \(one ? "it was" : "they were")")
  }
}
