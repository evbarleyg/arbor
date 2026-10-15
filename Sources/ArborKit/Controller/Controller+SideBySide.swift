import ArborCore
import CoreGraphics

/// A few windows into one group, in one step: `side-by-side 103 101 104`, which Go to… runs for the windows that are ticked
/// (`collab/QUESTIONS.md`, Q29, 9; board 0.12).
///
/// - The windows named leave wherever they are, docked or floating, on this display or another, in the Dock or hidden with their
///   app, and are docked side by side in the order named, as a group of their own at the right end of the arrangement.
/// - The view goes onto that group, so the group fills the display.
/// - **What else is docked stays docked**, in its order; the places that were left close.
/// - **Nobody who was just asked for is a tile.** They are equally wide; whoever is known not to go that narrow gets what it needs
///   and the others share the rest (F61). If they do not fit together it is refused, and everything is as it was.
/// - **Whoever is in the Dock or hidden comes back, and nobody moves twice for it.** macOS reports a window back a moment after it was
///   asked. Until then its place in the group is kept open (`awaitedBack`), so the others go straight to where they end up,
///   and it is put into its place when it lands.
/// - All of them come to the front, and the first has the keyboard.
/// - It is one command, so one `undo` takes all of it back, the keyboard too (`UndoStep.keyboard`).
extension Controller {
  /// A group of which somebody is still on the way back.
  struct AwaitedGroup {
    var windows: [WindowID]
    /// Those of them that were in the Dock or hidden.
    var absent: [WindowID]
    var display: DisplayID
  }

  /// On the display Go to… is open on, if it is Go to… that asks; else on the one commands act on.
  func sideBySide(_ ids: [WindowID]) -> CommandResult {
    guard (2...4).contains(ids.count), Set(ids).count == ids.count else {
      return .failure("side by side takes two to four windows, each once")
    }
    guard drag == nil else { return .failure("a window is being dragged; drop it first") }
    guard let display = sideBySideDisplay ?? commandDisplayID(), workspaces[display] != nil else {
      return .failure("no display")
    }
    for id in ids {
      if let why = whyNotSideBySide(id) { return .failure(why) }
    }
    // Everything a trial writes, so that a refusal leaves nothing behind.
    let before = (
      workspaces: workspaces, rooms: treesBeforeRoomWasMade, fitted: fittedToADisplay, awaited: awaitedBack,
      frames: ids.reduce(into: [WindowID: CGRect]()) { $0[$1] = windows[$1]?.frame },
      settled: ids.reduce(into: [WindowID: CGRect]()) { $0[$1] = settled[$1] },
      parked: parked.intersection(ids)
    )
    /// What Arbor knows, and then the windows that were named: no layout gives a floating window its frame back, which is its
    /// person's; and one that floated out of view is out of view again, or where it stands now would pass for its own place.
    func asItWas() {
      (workspaces, treesBeforeRoomWasMade, fittedToADisplay, awaitedBack) = (before.workspaces, before.rooms, before.fitted, before.awaited)
      parked = parked.subtracting(ids).union(before.parked)
      justAnswered.removeAll()
      for (id, frame) in before.frames.sorted(by: { $0.key < $1.key }) where windows[id]?.frame != frame {
        guard let actual = system.setFrame(frame, of: id) else { continue }
        windows[id]?.frame = actual
        // As it was noted, or not noted: a place its person chose is not one Arbor chose.
        settled[id] = before.settled[id]
      }
    }
    let notes = endOfRoleNotes(ids)

    let homes = Set(ids.compactMap(workspaceID(containing:))).subtracting([display])
    for id in ids {
      if let home = workspaceID(containing: id), home != display { transfer(id, from: home, to: display) }
    }
    let outcome = workspaces[display]!.dockSideBySide(ids, shareSpace: settings.shareRemovedSpace)
    if let why = outcome.refusal(of: ids[0]) {
      asItWas()
      return .failure(why)
    }

    func short(in layout: Layout?) -> [WindowID] {
      guard let layout else { return [] }
      return ids.filter { layout.windowFrames[$0] == nil }
    }
    // From here on whoever is in the Dock or hidden counts as back.
    let absent = ids.filter { windows[$0]?.isPresent == false }
    awaitedBack.formUnion(absent)
    // What macOS says beforehand: a size that cannot change.
    noteFixedSizes(of: ids)
    // Judged as it will be laid out: with room made for who needs it, if the others can spare it.
    let arranged = workspaces[display]
    guard let known = roomyLayout(of: display, for: .camera), short(in: known).isEmpty else {
      let words = doNotFit(ids)
      asItWas()
      return .failure(words)
    }
    // How small an app lets its window get is known only once it has been asked. Each is asked where it stands, before anybody
    // goes anywhere (Controller+AskFirst.swift): if they turn out not to fit, whoever was asked has its size back and that is all.
    let asked = askingFirst(known, on: display) { self.roomyLayout(of: display, for: .camera, startingFrom: arranged) }
    guard short(in: asked).isEmpty else {
      let words = doNotFit(ids)
      asItWas()
      return .failure(words)
    }
    (workspaces[display], treesBeforeRoomWasMade[display]) = (arranged, before.rooms[display])

    // As `moveCamera` does.
    peekYields(on: display)
    expectFocusToMove()
    keyboardHandOver.reveal = nil
    unframedIntoATile = nil
    // This display first: the answers just given hold for the layout that follows them.
    relayout(display, reason: .camera)
    for home in homes.sorted() { relayout(home, reason: .structure) }
    // One that could not be asked where it stood has refused in its slot: all or nothing, so all of it is taken back.
    guard short(in: layouts[display]).isEmpty else {
      let words = doNotFit(ids)
      asItWas()
      relayout(display, reason: .camera)
      for home in homes.sorted() { relayout(home, reason: .structure) }
      return .failure(words)
    }
    for id in ids { stopWatchingTitle(of: id) }  // the user has taken them in hand
    // Now that the others are where they end up. macOS reports that these happened a moment later.
    awaitedGroup = absent.isEmpty ? nil : AwaitedGroup(windows: ids, absent: absent, display: display)
    if !absent.isEmpty {
      scheduler.schedule(Self.awaitedBackKey, after: Self.timeToComeBack) { [weak self] in self?.stopAwaitingAnybody(layingOut: true) }
    }
    for id in absent {
      guard let snapshot = windows[id] else { continue }
      if snapshot.isHidden { system.unhideApp(pid: snapshot.pid) }
      if snapshot.isMinimized { system.setMinimized(id, false) }
    }
    // Asked for by name (Controller+Hold.swift), said after they were asked back, whose own reports would unsay it.
    holdNotesRequest(for: ids[0])
    bringToTheFront(ids)
    notify(.camera(display))
    scheduleSave()
    return .success((["docked \(Self.list(ids.map(\.description))) side by side"] + notes).joined(separator: "; "))
  }

  /// From the last to the first, so that the first ends in front, with the keyboard.
  private func bringToTheFront(_ ids: [WindowID]) {
    for id in ids.reversed() where windows[id]?.isPresent == true { system.raise(id) }
    if windows[ids[0]]?.isPresent == true || awaitedBack.contains(ids[0]) { askForTheKeyboard(for: ids[0]) }
  }

  /// Why `id` cannot be one of them, in words for the line under Go to…'s rows as well. Nil: it can.
  func whyNotSideBySide(_ id: WindowID) -> String? {
    guard isManaged(id) else { return whyNotManaged(id) }
    guard let window = windows[id], workspaceID(containing: id) != nil else { return "\(id) is not on any display" }
    if window.isFullScreen { return "\(id) is full screen" }
    if !window.isOnActiveSpace { return "\(id) is on another macOS Space" }
    return nil
  }

  /// "Safari, Xcode and Mail do not fit side by side on this display".
  private func doNotFit(_ ids: [WindowID]) -> String {
    "\(Self.list(ids.map { windows[$0]?.appName ?? $0.description })) do not fit side by side on this display"
  }

  // MARK: On the way back

  static let awaitedBackKey = "awaited-back"
  static let awaitedLandedKey = "awaited-landed"
  /// Longer than the flight out of the Dock takes, and than an app takes to show again.
  static let timeToComeBack = 2.0

  /// Called with every report about a window, before anything is laid out for it.
  func noteWhetherAnAwaitedWindowIsBack(_ window: WindowSnapshot) {
    guard window.isPresent, awaitedBack.remove(window.id) != nil, awaitedBack.isEmpty else { return }
    scheduler.cancel(Self.awaitedBackKey)
    // When the report has been dealt with and the window has its place; and once more when it has landed, for only then is
    // what it answers believed (Controller+OnTheWayBack.swift).
    scheduler.schedule(Self.awaitedLandedKey, after: 0) { [weak self] in self?.theAwaitedAreBack(landed: false) }
  }

  /// The one that flew in last took the keyboard with it, and lies in front; one whose app only shows again lies where it lay.
  private func theAwaitedAreBack(landed: Bool) {
    guard isRunning, let group = awaitedGroup else { return }
    // The person has gone on to something else meanwhile: it is theirs.
    guard workspaces[group.display].map({ $0.tree.windows(under: $0.camera) == group.windows }) == true,
      keyboardFocus().map(group.windows.contains) != false
    else { return awaitedGroup = nil }
    // It never said how small it goes, being in the Dock. All or nothing holds for it too.
    let tiles = Set(layouts[group.display]?.tiles.flatMap(\.windows) ?? [])
    if !tiles.isDisjoint(with: group.windows) {
      awaitedGroup = nil
      let words = doNotFit(group.windows)
      guard nextStepLabel(.undo, on: group.display) == Command.sideBySide(group.windows).text, undo().ok else { return }
      showHeadsUp(HeadsUpModel(kind: .problem, text: words), on: group.display)
      return
    }
    if !landed {
      // Only who came: the others are in front since the command.
      for id in group.absent.reversed() where windows[id]?.isPresent == true { system.raise(id) }
      if keyboardFocus() != group.windows[0] { askForTheKeyboard(for: group.windows[0]) }
      scheduler.schedule(Self.awaitedLandedKey, after: Self.timeToLand + 0.1) { [weak self] in self?.theAwaitedAreBack(landed: true) }
    } else {
      awaitedGroup = nil
      // macOS says that a window is back and that it has the keyboard in no particular order.
      if let has = keyboardFocus(), has != group.windows[0], group.absent.contains(has) { askForTheKeyboard(for: group.windows[0]) }
    }
  }

  /// For the nets: the windows of a group of which somebody has only just come back, who may be raised a moment after the command.
  public var windowsOfTheAwaitedGroup: Set<WindowID> { Set(awaitedGroup?.absent ?? []) }
  /// And all of that group, who go back where they were if the one that comes back does not fit.
  public var everybodyOfTheAwaitedGroup: Set<WindowID> { Set(awaitedGroup?.windows ?? []) }

  /// Whoever has not come back by now is not coming: its place closes, as that of any window in the Dock.
  func stopAwaitingAnybody(layingOut: Bool = false) {
    scheduler.cancel(Self.awaitedBackKey)
    scheduler.cancel(Self.awaitedLandedKey)
    let group = awaitedGroup
    awaitedGroup = nil
    guard !awaitedBack.isEmpty else { return }
    let homes = Set(awaitedBack.compactMap(workspaceID(containing:)))
    awaitedBack.removeAll()
    guard layingOut else { return }
    for home in homes.sorted() { relayout(home, reason: .structure) }
    // The keyboard was meant for one that is not there.
    if let group { ensureFocusIsVisible(on: group.display) }
  }
}
