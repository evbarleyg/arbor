import ArborCore
import CoreGraphics

/// Per-app rules (docs/features/F11-app-rules.md): `settings.rules` decides
/// what happens to a window that appears while Arbor is running. Windows
/// found at launch or restored from state go through `reconcile()` instead,
/// so starting Arbor never rearranges what is already on screen; of the rules,
/// only `ignore` applies to windows Arbor did not see open.
///
/// The list that is checked is `settings.newWindowRules`: the user's rules and, after them, the one that
/// `"newWindows": "dock"` stands for (Controller+AutoDock.swift). Indexes count in that list.
extension Controller {
  /// Adopts a window that just appeared and applies the first rule matching
  /// its app and title. With no matching rule it floats where its app put it.
  func adoptNewWindow(_ id: WindowID) {
    guard let snapshot = windows[id] else { return }
    guard !isTakingInAFoundWindow else { return adopt(id, rescue: true) }
    holdNotesNewWindow(id)
    let rules = settings.newWindowRules
    let match = firstMatchingRule(for: snapshot, among: rules.count)
    watchTitle(of: id, above: match ?? rules.count, openingFrame: snapshot.frame)
    apply(ruleAt: match, to: id)
  }

  /// The index of the first of the top `count` rules that matches a window. Rules that choose their windows by
  /// size go by `openingSize`, the size it opened with, if Arbor has moved it since.
  func firstMatchingRule(for window: WindowSnapshot, openingSize: CGSize? = nil, among count: Int) -> Int? {
    // Whoever summons an app that has no window yet wants its window over the view for a moment (F53), not in the
    // arrangement for good. A rule that names the app is still obeyed: a docked window has a place.
    let isAwaited = awaitedSummon.map { Self.isWindow(window, of: $0.app) } ?? false
    return settings.newWindowRules.prefix(count).firstIndex {
      !(isAwaited && $0.isCautious)
        && $0.matches(
          bundleID: window.bundleID, title: window.title, openingSize: openingSize ?? window.frame.size,
          isResizable: window.isResizable, minimum: settings.autoDockMinimumSize)
    }
  }

  /// Does what a rule says with a new window, whatever an earlier rule did with it. Without a
  /// rule the window floats.
  func apply(ruleAt index: Int?, to id: WindowID) {
    let rule = index.map { settings.newWindowRules[$0] }
    let dockedOn = workspaces.first { $0.value.isDocked(id) }?.key
    // (A window in a workspace is brought into view by `releaseUnmanagedWindows`. One that cannot be ignored yet
    // floats meanwhile.)
    if let index, rule?.action == .ignore, workspaceID(containing: id) != nil || canBeLeftAlone(id, by: index) {
      // From now on every `filter.manages` check fails for this window, so
      // nothing docks, floats, parks or moves it.
      filter.ignoredWindowIDs.insert(id)
      releaseUnmanagedWindows()
      if let dockedOn {
        returnToOpeningFrame(id)
        relayout(dockedOn, reason: .structure)
      }
      logRule(index, "ignoring \(id)")
      return
    }
    filter.ignoredWindowIDs.remove(id)
    if workspaceID(containing: id) == nil {
      // Not every window that appears is new: one on a Space that was not showing when Arbor started
      // may have been left out of view by a run that did not quit cleanly.
      adopt(id, rescue: true)
      // Where the rescue put it is where a late `float` rule sends it back to.
      if let frame = windows[id]?.frame { titleWatches[id]?.openingFrame = frame }
      appPlacedFrames[id] = workspaceID(containing: id).flatMap { workspaces[$0]?.floating[id] }
    }
    guard let index, let rule, let display = workspaceID(containing: id), !holdPutsOff(rule, for: id) else {
      receiveAsGuestOfTheView(id)
      return
    }
    // A window is a guest only while no rule says otherwise, and a late title can bring a rule.
    workspaces[display]!.endVisit(of: id)
    switch rule.action {
    case .float, .pin, .ignore:  // `ignore` returned above
      if let dockedOn {
        workspaces[dockedOn]!.undock(
          id, floatingAt: floatingFrame(for: id, on: dockedOn), shareSpace: settings.shareRemovedSpace)
        if let frame = returnToOpeningFrame(id) { workspaces[dockedOn]!.floating[id] = frame }
      }
      // Before the layout, which moves a floating window onto the Desktop and leaves a pinned one where it is.
      if rule.action == .pin {
        workspaces[display]?.pin(id)
        logRule(index, "keeping \(id) in view")
        holdLetsIn(id)
      } else {
        // A rule that matched before the window had its real title may have pinned it.
        workspaces[display]?.unpin(id)
        logRule(index, "\(id) floats")
      }
      if let dockedOn { relayout(dockedOn, reason: .structure) } else { notify(.layout(display)) }
    case .dock(let edge):
      dockNewWindow(id, at: .cameraEdge(edge), on: display)
      logRule(index, "docked \(id) at the \(edge.rawValue) edge of the view")
    case .dockBeside(let app, let edge):
      if let neighbour = recentlyFocusedDockedWindow(of: app, on: display, except: id),
        let leaf = workspaces[display]?.tree.leaf(containing: neighbour)
      {
        dockNewWindow(id, at: .beside(leaf, edge), on: display)
        logRule(index, "docked \(id) \(edge.rawValue) of \(neighbour)")
      } else {
        dockNewWindow(id, at: .cameraEdge(edge), on: display)
        let outcome = "docked \(id) at the \(edge.rawValue) edge of the view"
        logRule(index, "no docked \(app) window on this display; \(outcome)")
      }
    case .dockAuto:
      // A better rule than the one that docked it, and it says no more than "dock it somewhere".
      logRule(
        index,
        dockedOn == nil ? summingUpForTheLine(on: display) { dockAutomatically(id, on: display) } : "\(id) is docked already")
      // Left floating over a view without the Desktop, it stays with that view like a window no rule claimed (F57).
      if workspaces[display]?.isFloating(id) == true { receiveAsGuestOfTheView(id) }
    }
  }

  // MARK: Windows Arbor did not see open

  /// Leaves a window alone from now on if the first rule matching it is `ignore`, and says whether it
  /// did. For windows Arbor comes across rather than sees open: at launch, when their app is
  /// included again, or when the window system never announced them. So a window a rule ignores stays
  /// ignored across a restart, with nothing saved.
  ///
  /// `lastRun` is the workspace the last run had it in, if it had.
  func ignoreIfARuleSaysSo(_ id: WindowID, arrangedBy lastRun: Workspace? = nil) -> Bool {
    guard let window = windows[id], filter.manages(window),
      let index = firstMatchingRule(for: window, among: settings.newWindowRules.count),
      settings.newWindowRules[index].action == .ignore, canBeLeftAlone(id, by: index, arrangedBy: lastRun)
    else { return false }
    filter.ignoredWindowIDs.insert(id)
    logRule(index, "ignoring \(id), which was already open")
    return true
  }

  /// To ignore a window is never to touch it again, not even when quitting. So one that Arbor put out of
  /// view is brought back first: the rule can be younger than the arrangement, and the last run may not have
  /// quit cleanly. False while that cannot be done (no display, an app that does not answer, full screen): the
  /// window is not to be ignored yet, and Arbor comes across it again. A window that is out of view by its
  /// app's or its user's doing is none of Arbor's business, and stays there.
  private func canBeLeftAlone(_ id: WindowID, by index: Int, arrangedBy lastRun: Workspace? = nil) -> Bool {
    let lastRun = lastRun ?? foundInTheDark[id]
    if displays.isEmpty, !parked.contains(id), let lastRun {
      // Whether it is in view cannot be told. `decideAboutWindowsFoundInTheDark` asks again.
      foundInTheDark[id] = lastRun
      return false
    }
    foundInTheDark[id] = nil
    guard parked.contains(id) || isInAParkingCorner(id) || lastRun != nil && showsOnlyASliver(id) else { return true }
    guard fetch(id, arrangedBy: lastRun) else {
      // Still Arbor's to fetch, whoever comes across it next.
      parked.insert(id)
      return false
    }
    logRule(index, "brought \(id) into view before ignoring it")
    return true
  }

  /// Whether a window is exactly where Arbor would put it out of view, the displays being what they are (as in
  /// `parkAgain`). Then Arbor did, whatever else is known: after a crash the window can have another number (its
  /// app started again), be on a Space that was not showing at launch, or show more than a sliver on a neighbouring display.
  private func isInAParkingCorner(_ id: WindowID) -> Bool {
    guard let frame = windows[id]?.frame else { return false }
    return displays.contains { display in
      let corner = parkingOrigin(for: frame.size, on: display)
      return abs(frame.minX - corner.x) <= 1
        && (abs(frame.minY - corner.y) <= 1 || abs(frame.minY - whereItStops(corner).y) <= 1)
    }
  }

  /// Brings a window into view to stay: where it was before Arbor arranged it, if some arrangement remembers
  /// that, or else the middle of its display. Says whether it is in view now.
  private func fetch(_ id: WindowID, arrangedBy lastRun: Workspace?) -> Bool {
    // At launch the saved arrangements may mean another window by this number (`reconcile` has yet to look).
    let isKnown = lastRun != nil || isRunning
    // macOS does not let a window in full screen be moved, and sends it back to the corner when that ends.
    guard let window = windows[id], !window.isFullScreen,
      let displayID = (isKnown ? workspaceID(containing: id) : nil) ?? displayID(at: window.frame.center),
      let display = display(displayID)
    else { return false }
    let arrangements =
      [lastRun, workspaces[displayID]].compactMap { $0 } + dormant.keys.sorted().compactMap { dormant[$0]?.workspace }
    let was = isKnown ? arrangements.lazy.compactMap { $0.undockedFrame(of: id) ?? $0.floating[id] }.first : nil
    let (visible, size) = (display.visibleFrame, window.frame.size)
    let middle = CGRect(
      x: visible.midX - size.width / 2, y: visible.midY - size.height / 2, width: size.width, height: size.height)
    putBack(id, at: was.map { asItWas($0, on: display) } ?? middle.fitted(into: visible), on: display)
    return !showsOnlyASliver(id) && !isInAParkingCorner(id)
  }

  /// Called by `start()` before the saved arrangement is matched against the open windows, so that
  /// an ignored window also leaves the saved arrangement, if it was in it.
  func ignoreWindowsFoundAtLaunch(saved: PersistedState?) {
    foundInTheDark.removeAll()
    let arrangements = saved.map { Array($0.workspaces.values) + $0.dormant.values.map(\.workspace) } ?? []
    for id in windows.keys.sorted() {
      // Window numbers restart after a reboot: the number alone does not make it the same window.
      let isTheSame = hints[id].map { $0.bundleID == windows[id]?.bundleID } ?? false
      _ = ignoreIfARuleSaysSo(id, arrangedBy: isTheSame ? arrangements.first { $0.contains(id) } : nil)
    }
  }

  /// Called by `start()`. An app can be excluded by hand in settings.json while Arbor is not running. If the last run
  /// did not quit cleanly, its windows are still where that run had put them, and this one will never look at
  /// them: so what Arbor put out of view is brought back now. (`exclude`, and an edit while Arbor runs, let go of windows in view.)
  func fetchWindowsOfExcludedAppsLeftOutOfView(saved: PersistedState?) {
    let arrangements = saved.map { Array($0.workspaces.values) + $0.dormant.values.map(\.workspace) } ?? []
    var otherwise = filter
    otherwise.excludedBundleIDs = []
    // Only for being excluded: windows that are none of Arbor's business for another reason stay so.
    for (id, window) in windows.sorted(by: { $0.key < $1.key }) where !filter.manages(window) && otherwise.manages(window) {
      let isTheSame = hints[id].map { $0.bundleID == window.bundleID } ?? false
      let lastRun = isTheSame ? arrangements.first { $0.contains(id) } : nil
      guard isInAParkingCorner(id) || lastRun != nil && showsOnlyASliver(id), fetch(id, arrangedBy: lastRun) else { continue }
      Log.info("brought \(id) into view: the last run left it out of view, and its app is excluded now")
    }
  }

  /// Called when displays change, before any arrangement comes back to one.
  func decideAboutWindowsFoundInTheDark() {
    guard !displays.isEmpty else { return }
    for id in foundInTheDark.keys.sorted() { _ = ignoreIfARuleSaysSo(id) }
    foundInTheDark.removeAll()
  }

  // MARK: Late titles

  /// What is kept about a new window while its title can still bring a better rule into play.
  struct TitleWatch {
    /// Only the rules above this index can take over: it is the index of the rule applied so
    /// far, or the number of rules if none was.
    var limit: Int
    /// Where the window's app opened it, to go back to if a rule docked it and a better one
    /// floats or ignores it.
    var openingFrame: CGRect
  }

  /// Browsers and editors open a window first and give it its real title a moment later. So for
  /// `ruleTitleWait` seconds a rule for the window's app that ranks above `limit` can still take
  /// over when the title changes. (Such a rule has a `title`, or it would have matched already.)
  private func watchTitle(of id: WindowID, above limit: Int, openingFrame: CGRect) {
    let wait = min(settings.ruleTitleWait, 60)
    guard wait > 0, let app = windows[id]?.bundleID,
      settings.newWindowRules.prefix(limit).contains(where: { $0.covers(bundleID: app) })
    else { return stopWatchingTitle(of: id) }
    let isNew =
      titleWatches.updateValue(TitleWatch(limit: limit, openingFrame: openingFrame), forKey: id) == nil
    // The time runs from when the window opened, not from its latest title.
    if isNew {
      scheduler.schedule("rule-title-\(id.rawValue)", after: wait) { [weak self] in
        self?.titleWatches[id] = nil
      }
    }
  }

  /// Called from `windowChanged` when a window's title changed. Returns whether a rule took over, in
  /// which case the window is no longer where the report of the change says it is.
  func recheckRules(for id: WindowID) -> Bool {
    // Not while the mouse is arranging something, and not for a window that takes no space now.
    guard isRunning, drag == nil, edgeResize == nil, let watch = titleWatches[id], let snapshot = windows[id],
      snapshot.isPresent,
      let match = firstMatchingRule(for: snapshot, openingSize: watch.openingFrame.size, among: watch.limit)
    else { return false }
    apply(ruleAt: match, to: id)
    watchTitle(of: id, above: match, openingFrame: watch.openingFrame)
    if isManaged(id) { hints[id] = WindowHint(bundleID: snapshot.bundleID, title: snapshot.title) }
    // A window docked as it opens is revealed when its app focuses it. This one has the focus already.
    if system.focusedWindow() == id { windowFocused(id) }
    scheduleSave()
    return true
  }

  /// Puts a window that a rule docked back where its app opened it. Returns the frame it took.
  @discardableResult
  private func returnToOpeningFrame(_ id: WindowID) -> CGRect? {
    guard let frame = titleWatches[id]?.openingFrame, let actual = system.setFrame(frame, of: id) else {
      return nil
    }
    windows[id]?.frame = actual
    settled[id] = actual
    parked.remove(id)
    return actual
  }

  /// Ends the wait for one window: it closed, or the user took it in hand (a drag, an edge resize, a
  /// command aimed at it), and what the user arranged is not for a rule to undo.
  func stopWatchingTitle(of id: WindowID) {
    guard titleWatches.removeValue(forKey: id) != nil else { return }
    scheduler.cancel("rule-title-\(id.rawValue)")
  }

  /// Ends every wait: the rules changed, so the watches count rules of a list no longer in use;
  /// the user rearranged everything; or Arbor is stopping.
  func stopWatchingTitles() {
    for id in Array(titleWatches.keys) { stopWatchingTitle(of: id) }
  }

  /// Docks a window that was just adopted. Docking widens the camera just
  /// enough to show it (`Workspace.dock`). It is not focused here; its app
  /// usually focuses it, and if it is too small to show and became a tile,
  /// `windowFocused` zooms in on it as it does for any window. `desktopWeight` is `AutoDock.Placement`'s.
  func dockNewWindow(_ id: WindowID, at target: DropTarget, on display: DisplayID, desktopWeight: Double? = nil) {
    guard var workspace = workspaces[display] else { return }
    // Undoing it leaves the window floating. Nobody asked for it just now, so redo stays.
    recordingUndo("dock \(id) as it opened", title: "Dock", keepingRedo: true) {
      AutoDock.Placement(target: target, desktopWeight: desktopWeight)
        .apply(to: &workspace, docking: id, shareSpace: settings.shareRemovedSpace)
      workspaces[display] = workspace
      relayout(display, reason: .structure)
    }
  }

  /// The docked window of the app `bundleID` on `display` that was focused
  /// most recently. Docked windows not focused since Arbor started (restored
  /// from state, say) count as the least recent, in tree order.
  func recentlyFocusedDockedWindow(of bundleID: String, on display: DisplayID, except new: WindowID)
    -> WindowID?
  {
    guard let tree = workspaces[display]?.tree else { return nil }
    let docked = tree.allWindows.filter {
      $0 != new && windows[$0]?.bundleID?.lowercased() == bundleID.lowercased()
    }
    return focusHistory.first { docked.contains($0) } ?? docked.first
  }

  /// Called from `bringIntoViewIfFocused` once a window that was reported is seen to have the keyboard.
  func recordFocus(_ id: WindowID) {
    guard isRunning, isManaged(id) else { return }
    focusHistory.removeAll { $0 == id }
    focusHistory.insert(id, at: 0)
    autoDockTrail = nil
  }

  /// Called from `windowDestroyed`.
  func forgetRuleState(of id: WindowID) {
    focusHistory.removeAll { $0 == id }
    filter.ignoredWindowIDs.remove(id)
    foundInTheDark[id] = nil
    stopWatchingTitle(of: id)
  }

  /// Logs what a rule did. The rule's title pattern is left out because it is
  /// part of a window title, and titles are never logged.
  private func logRule(_ index: Int, _ outcome: String) {
    let rule = settings.newWindowRules[index]
    let name = index < settings.rules.count ? "rule \(index + 1)" : "newWindows"
    Log.info("\(name) (\(rule.app): \(rule.action.text)): \(outcome)")
  }

  // MARK: The `rules` query

  /// The rules in order, the entries of settings.json that were skipped and
  /// why, and which rule matches the focused window.
  func rulesReport() -> CommandResult {
    let rules = settings.rules
    var lines: [String] = []
    if rules.isEmpty {
      let outcome = settings.docksNewWindows ? "" : ": new windows float"
      lines.append("No rules\(outcome). Add one with `rule add <bundle id> <action>`, or in settings.json.")
    } else {
      lines.append("Rules for new windows, checked in order (the first match wins):")
      for (index, rule) in rules.enumerated() { lines.append("  \(index + 1). \(rule)") }
    }
    if !settings.skippedRules.isEmpty {
      lines.append("Skipped entries of \"rules\" in settings.json (fix them there):")
      lines += settings.skippedRules.map { "  \($0)" }
    }
    lines += newWindowsLines()
    lines += focusedWindowRuleLines()
    lines.append(
      "Rules apply when a window opens. Of windows that were already open, Arbor only ignores those a rule says to."
    )
    return CommandResult(ok: true, message: "\(rules.count) rule(s)", text: lines.joined(separator: "\n"))
  }

  private func focusedWindowRuleLines() -> [String] {
    guard isRunning else { return ["No focused window: \(statusText)."] }
    guard let id = system.focusedWindow(), let window = windows[id] else { return ["No focused window."] }
    let subject = "Focused window \(id) (\(window.bundleID ?? "no bundle id"))"
    var lines: [String]
    // By the size it has now. The size it opened with is not kept.
    if let index = firstMatchingRule(for: window, among: settings.newWindowRules.count) {
      let rule = settings.newWindowRules[index]
      lines =
        index < settings.rules.count
        ? ["\(subject) matches rule \(index + 1): \(rule.action.text)."]
        : ["\(subject) matches no rule of its own; a new window like it docks (`newWindows`)."]
    } else {
      lines = ["\(subject) matches no rule."]
    }
    if filter.ignoredWindowIDs.contains(id) {
      lines.append("Arbor is leaving it alone: an ignore rule matched it.")
    } else if let bundle = window.bundleID, filter.excludedBundleIDs.contains(bundle) {
      lines.append("Arbor does not arrange its app, so rules do not apply; `include \(bundle)` arranges it again.")
    }
    return lines
  }
}
