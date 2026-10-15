import ArborCore
import CoreGraphics
import Foundation

/// Arbor knows how small apps go (docs/features/F68-how-small-apps-go.md).
///
/// A window that Arbor has never seen at its smallest is a stranger: its slot is worked out as if it took any size, it
/// refuses, and it and its neighbours move a second time. What docked windows of its app answered before is therefore kept (`AppSizes`,
/// in `state.json`), and the frames of docked windows are worked out with it (`plannedSizes`): layouts, room before tiles, the preview
/// of a drop, where automatic docking tries.
///
/// **It is foresight, never the truth.** `minimumSizes` holds what windows answered themselves, and nothing else, and everything else goes
/// by that alone: floating windows, a gap in the person's hand, how far `shrink` goes, whatever chooses a view or an arrangement, traces.
/// Nothing is copied: what is foreseen of a window is looked up when it is wanted (`unaskedForesight`), so that it ends when the store's entry
/// does. And no plan stands on foresight unasked:
/// - A window whose slot is just what is foreseen is asked for a step less, where it stands, when the strangers have answered and before
///   anybody is moved (`askingThoseWhoseRoomIsForeseen`). If the foresight is right it stops at the size that was planned and goes to its place from there,
///   and now it has answered. If not, the store is put right, and the plan is made anew. A question moves nobody.
/// - Whoever would be a tile because of it is asked in its corner, where nobody sees, and so is whoever the view leaves while somebody is
///   a tile (`askOutOfView`).
/// So what is too high in the store is put right the first time a window is given room for it or refused a place for it.
extension Controller {
  /// What of `minimumSizes` has been entered into `appSizes`: the record, and when the window last stood by it.
  struct EnteredSize {
    var size: CGSize
    var at: Date
  }

  /// The directions in which a window has been asked about what is foreseen of its app, or has been offered less.
  struct AskedAbout: Equatable {
    var width = false
    var height = false
  }

  // MARK: Foreseeing

  /// Called by `start()` once `windows` holds what is there.
  func recallHowSmallAppsGo(saved: PersistedState?) {
    // A file that could not be read says nothing. After a pause what was known is still in memory.
    if let kept = saved?.appSizes { appSizes = kept }
    appSizes.expire(at: now(), macOS: macOSVersion)
    askedAbout = askedAbout.filter { windows[$0.key] != nil }
    enteredSizes = enteredSizes.filter { windows[$0.key] != nil }
  }

  /// What is foreseen of `window` and nothing has borne out or disproved yet; 0 in a direction in which there is nothing of the kind.
  func unaskedForesight(about window: WindowID) -> CGSize {
    // What cannot be asked about is not gone by: nobody gives room for a window whose app does not answer.
    guard !appSizes.isEmpty, !unplaced.contains(window), let snapshot = windows[window], let app = snapshot.bundleID,
      let known = appSizes.entry(for: app, at: now(), macOS: macOSVersion), filter.manages(snapshot)
    else { return .zero }
    let own = minimumSizes[window] ?? .zero
    let asked = askedAbout[window] ?? AskedAbout()
    // Its own answer counts. And a window that is smaller than that already is another kind of window, or the store is wrong.
    return CGSize(
      width: own.width > 0 || asked.width || snapshot.frame.width < known.width - 2 ? 0 : known.width,
      height: own.height > 0 || asked.height || snapshot.frame.height < known.height - 2 ? 0 : known.height)
  }

  /// What the frames of docked windows are worked out with: what each window answered, and where it has not been asked, what is foreseen.
  /// Under the person's own hand nothing is foreseen: the window follows the hand, and says itself where it stops. Nor where a command only
  /// judges whether it may go ahead (`byAnswersAlone`).
  var plannedSizes: [WindowID: CGSize] {
    guard !appSizes.isEmpty, !gapsInHand, !judgesByAnswersAlone else { return minimumSizes }
    var sizes = minimumSizes
    for window in windows.keys {
      let foreseen = unaskedForesight(about: window)
      guard foreseen != .zero else { continue }
      let own = sizes[window] ?? .zero
      sizes[window] = CGSize(width: max(own.width, foreseen.width), height: max(own.height, foreseen.height))
    }
    return sizes
  }

  /// For a command that works a layout out only to judge whether it may go ahead. A refusal comes before any layout, so that nobody would ever be
  /// asked: it must not rest on foresight.
  func byAnswersAlone<Result>(_ body: () -> Result) -> Result {
    let outer = judgesByAnswersAlone
    judgesByAnswersAlone = true
    defer { judgesByAnswersAlone = outer }
    return body()
  }

  // MARK: Asking

  /// How much less than is foreseen a window is asked for. More than the largest step in which windows come (Controller+SizeSteps.swift), so
  /// that a window that stays has refused; little enough that one that gives way is not seen to collapse.
  static let stepBelowForesight: CGFloat = 40

  /// Called by `relayout` with a plan, before anything is moved for it and when the strangers in it have answered (`askingFirst`): whoever
  /// shrinks for a plan that a stranger then overturns may have to grow again. Asks the windows whose slots are just what is foreseen of them,
  /// where they stand. Returns nil if the plan holds, as nearly always, or else the plan there is now. `before` is the workspace as the layout
  /// found it; room in it that an earlier layout made for what turns out wrong is given back.
  func askingThoseWhoseRoomIsForeseen(
    _ layout: Layout, on displayID: DisplayID, reason: RelayoutReason, startingFrom before: inout Workspace?
  ) -> Layout? {
    // Nothing is foreseen under the hand. During a drag no room is made, and nothing may change under the pointer.
    guard !appSizes.isEmpty, !gapsInHand, drag == nil, edgeResize == nil else { return nil }
    // In sight, so only inside an act a person asked for: a command, a drop, a move of the view, which a start is too (as in
    // `aLayoutSomebodyAskedForEndsLettingBe`). What a timer, a putting-back or another window's coming and going lays out goes by the paper,
    // and whoever has its room on that is asked at the next thing its person asks for.
    guard reason == .camera || following.decides || !placedOnPurpose.isEmpty else { return nil }
    var holds = true
    for (window, slot) in layout.windowFrames.sorted(by: { $0.key < $1.key }) where !enforcement.givenUp.contains(window) {
      let foreseen = unaskedForesight(about: window)
      // Just that: a window that stops a point short of a slot that happens to be a little larger would have to be set again.
      let width = foreseen.width > 0 && slot.width <= foreseen.width + 0.5
      let height = foreseen.height > 0 && slot.height <= foreseen.height + 0.5
      // Only just back, it may not be ready to take a frame, and its answer would mean nothing (Controller+OnTheWayBack.swift). The next act asks.
      guard width || height, var question = windows[window]?.frame, !postponesJudgement(of: window, on: displayID) else { continue }
      // Where it stands, and only about what is foreseen. Nobody is moved for a plan that the next answer may overturn, and where in its
      // slot a window belongs is `place`'s to say, which knows more (Controller+AskFirst.swift). It is asked for less than it has and for
      // nothing more, so no edge of the screen is in the way of the answer.
      // In its corner, if that is where it is.
      if whereItStops(question.origin, titleBar: titleBars[window] ?? Self.guessedTitleBar) != question.origin {
        // The one that is moved by the question: its person has left it lower than macOS lets anybody put a window, so it would not stay
        // where it stands. To the corner of its slot, at the size it has.
        question.origin = slot.origin
      }
      var believed = question.size
      if width { (question.size.width, believed.width) = (slot.width - Self.stepBelowForesight, slot.width) }
      if height { (question.size.height, believed.height) = (slot.height - Self.stepBelowForesight, slot.height) }
      guard var actual = system.setFrame(question, of: window) else {
        // Its app does not answer. Until it does nothing is foreseen of it.
        unplaced.insert(window)
        holds = false
        continue
      }
      actual = askForLess(window, slot: question, took: actual)
      windows[window]?.frame = actual
      settled[window] = actual
      if !itStoodBy(believed, window, asked: question.size, took: actual.size) {
        holds = false
        // The size it has now is what it made of this question, not of the slot it may have been offered a moment ago (`request`).
        justAnswered[window] = nil
        if let leaf = before?.tree.leaf(containing: window) { before?.tree.giveBackWhatWasBorrowed(for: leaf) }
      }
    }
    return holds ? nil : roomyLayout(of: displayID, for: reason, startingFrom: before)
  }

  /// `window` was foreseen to go no smaller than `foreseen` in the directions in which it was `asked` for less, and `took` this. From now on it
  /// has answered for itself, and where it went smaller its app is no longer known not to. Returns whether it stopped where it was foreseen to.
  private func itStoodBy(_ foreseen: CGSize, _ window: WindowID, asked: CGSize, took actual: CGSize) -> Bool {
    var own = minimumSizes[window] ?? .zero
    // A point or two short of it, it still fits the plan. Any more than was foreseen, and the plan has no room for it.
    var stood = true
    if asked.width < foreseen.width {
      askedAbout[window, default: AskedAbout()].width = true
      // What it stopped at, if it stopped.
      own.width = actual.width > asked.width + 2 ? actual.width : 0
      if actual.width > foreseen.width + 0.5 || actual.width < foreseen.width - 2 { stood = false }
    }
    if asked.height < foreseen.height {
      askedAbout[window, default: AskedAbout()].height = true
      own.height = actual.height > asked.height + 2 ? actual.height : 0
      if actual.height > foreseen.height + 0.5 || actual.height < foreseen.height - 2 { stood = false }
    }
    minimumSizes[window] = own == .zero ? nil : own
    // Now: in its corner it has the size it had again in a moment, and nobody would see that it went smaller.
    if !stood, let app = windows[window]?.bundleID, appSizes.wasSeen(at: actual, app: app) { scheduleSave() }
    Log.debug("\(window) was asked for a step less than is foreseen of its app, and \(stood ? "stood by it" : "did not stop there")")
    return stood
  }

  /// Called by `relayout` once `layout` has been applied, so that whatever is not in view is in its corner. Asks there, where nobody sees:
  /// - the windows that are tiles in `layout`, of which something is foreseen. Whatever `tileRetryMinutes` says, and in a hold: nobody is asked
  ///   *again* here, and without the foresight a tile would have been offered its share in sight;
  /// - the windows the view has just left, if somebody was a tile in it: one of them may have been believed to have nothing to spare. That is what
  ///   clicking a tile does. Where nobody pays nobody is asked: a question is a round trip to an app, and squeezes its window.
  /// Each gets the size it had back, there and then. Returns true if the display should be laid out again.
  func askOutOfView(_ layout: Layout, on displayID: DisplayID) -> Bool {
    guard !appSizes.isEmpty, drag == nil, edgeResize == nil, let display = display(displayID) else { return false }
    var changed = false
    let tiles = Set(layout.tiles.flatMap(\.windows))
    let somebodyPaid = layouts[displayID]?.tiles.contains { $0.kind == .window } == true
    // In its corner: a tile can be in view all the same, the window with the keyboard that a start lets be (Controller+LetBe.swift). Let be means
    // that no frame is set, so of that one the paper is believed, as of a lender, until its person asks for something and it is parked.
    for window in (somebodyPaid ? layout.hiddenWindows.union(tiles) : tiles).sorted() where parked.contains(window) {
      var foreseen = unaskedForesight(about: window)
      // A step less than next to nothing is no size to ask for.
      if foreseen.width < 2 * Self.stepBelowForesight { foreseen.width = 0 }
      if foreseen.height < 2 * Self.stepBelowForesight { foreseen.height = 0 }
      guard foreseen != .zero, landsAt[window].map({ $0 <= now() }) != false, let current = windows[window]?.frame else { continue }
      // The corner to the left of a display depends on the window's width: it stays where it is parked at the size it has.
      let corner = parkingOrigin(for: current.size, of: window, on: display)
      let size = CGSize(
        width: foreseen.width > 0 ? foreseen.width - Self.stepBelowForesight : current.width,
        height: foreseen.height > 0 ? foreseen.height - Self.stepBelowForesight : current.height)
      guard var actual = system.setFrame(CGRect(origin: corner, size: size), of: window) else { continue }
      actual = askForLess(window, slot: CGRect(origin: corner, size: size), took: actual)
      let believed = CGSize(
        width: foreseen.width > 0 ? foreseen.width : size.width, height: foreseen.height > 0 ? foreseen.height : size.height)
      if !itStoodBy(believed, window, asked: size, took: actual.size) { changed = true }
      // As it was: whatever goes by the size of a window out of view finds it, and the way back is a move and no more.
      if actual.size != current.size { actual = system.setFrame(CGRect(origin: corner, size: current.size), of: window) ?? actual }
      windows[window]?.frame = actual
      settled[window] = actual
    }
    return changed
  }

  // MARK: Remembering

  /// Called at the end of every layout of a display. Several places write records about windows, and more will; whoever did, what has changed
  /// since the last look is what a window has just answered, and goes for its app from now on.
  ///
  /// Only docked windows count, both ways: it is docked windows that are planned with it, and what floats beside an app's main window
  /// is often another kind of window.
  func noteHowSmallAppsGo(after layout: Layout, on displayID: DisplayID) {
    // Nearly always, on a Mac on which nothing has refused yet.
    guard !minimumSizes.isEmpty || !appSizes.isEmpty || !enteredSizes.isEmpty else { return }
    let now = self.now()
    let docked = workspaces[displayID]?.tree.allWindows.sorted() ?? []
    var changed = appSizes.expire(at: now, macOS: macOSVersion)
    for window in docked {
      // Not what Accessibility calls a window of one size: that is a kind of window, not how small its app goes (Controller+AskFirst.swift).
      guard let record = minimumSizes[window], !fixedSizesNoted.contains(window) else { continue }
      // A record that is new or has changed held a moment ago (as in `askTilesAgain`).
      if confirmedSizes[window]?.size != record { confirmedSizes[window] = ConfirmedSize(size: record, at: now) }
      let at = confirmedSizes[window]!.at
      guard enteredSizes[window]?.size != record || enteredSizes[window]?.at != at else { continue }
      enteredSizes[window] = EnteredSize(size: record, at: at)
      guard let snapshot = windows[window], filter.manages(snapshot), let app = snapshot.bundleID else { continue }
      if appSizes.stoodBy(record, app: app, macOS: macOSVersion, at: at) {
        changed = true
        Log.debug("\(window) stood by \(Int(record.width))×\(Int(record.height)): kept for \(app)")
      }
    }
    if !enteredSizes.isEmpty { enteredSizes = enteredSizes.filter { minimumSizes[$0.key] != nil } }
    if !appSizes.isEmpty {
      for window in docked {
        guard let snapshot = windows[window], filter.manages(snapshot), let app = snapshot.bundleID else { continue }
        if appSizes.wasSeen(at: snapshot.frame.size, app: app) {
          changed = true
          Log.debug("\(window) is smaller than \(app) was known to go: no longer known")
        }
      }
    }
    if changed { scheduleSave() }
    // Whoever has been offered less than is foreseen has been asked, whatever it made of it. Under the hand that happens: what it refused is on
    // record, and a point or two over is no refusal. And to a window whose answer does not count yet (only just back, in the hand) while another
    // window of its app teaches in the same layout: so after the store has learned, and on every display. Otherwise what is shown would
    // not be what a layout made now would say, and the next one would make a tile of it.
    if !appSizes.isEmpty {
      for shown in [layout] + layouts.filter({ $0.key != displayID }).values {
        for (window, slot) in shown.windowFrames {
          let foreseen = unaskedForesight(about: window)
          if slot.width < foreseen.width { askedAbout[window, default: AskedAbout()].width = true }
          if slot.height < foreseen.height { askedAbout[window, default: AskedAbout()].height = true }
        }
      }
    }
  }

  /// Called by `lowerDisprovedMinimum`, which has just brought the record about `window` down to the size it was seen at. Nobody stood by
  /// that size, so it is not entered as an answer; what is known of the app is disproved like the record.
  func noteThatItWasSeenSmaller(_ window: WindowSnapshot) {
    guard let record = minimumSizes[window.id] else { return }
    let now = self.now()
    confirmedSizes[window.id] = ConfirmedSize(size: record, at: now)
    enteredSizes[window.id] = EnteredSize(size: record, at: now)
    if filter.manages(window), let app = window.bundleID, appSizes.wasSeen(at: window.frame.size, app: app) { scheduleSave() }
  }

  /// With `forgetLearnedMinimums`: people run `relayout` because something looks wrong, and every window is then offered its
  /// slot in sight. What an app that is not running answered looks wrong to nobody.
  func forgetHowSmallAppsGo() {
    askedAbout.removeAll()
    enteredSizes.removeAll()
    if appSizes.drop(Set(windows.values.compactMap(\.bundleID))) { scheduleSave() }
  }

  /// A trace's header tells of the apps that have a window when the recording begins. Of an app whose first window comes later the trace is told
  /// then, in a line of its own: nothing but a window of the app changes what is known of it. The line names the window, whose own line says
  /// which app it is of, and holds numbers only: whatever is text in a trace is searched for titles and for the names of spaces, and may come out
  /// otherwise than it went in. Nothing where nothing is known, so of an app that has no window in the trace it still holds no word.
  func tellTheTrace(whatIsKnownOf window: WindowSnapshot) {
    guard toldInTheTrace != nil else { return }
    guard let recorder = traceRecorder, recorder.isRecording else {
      toldInTheTrace = nil
      return
    }
    guard let app = window.bundleID, toldInTheTrace!.insert(app).inserted, let known = appSizes.entry(for: app) else { return }
    _ = recorder.read(AppSizes.traceLine, [window.id]) { known }
  }

  /// What a trace's header says of it: only about `apps`, which are in the trace anyway.
  func appSizesForATrace(of apps: [String]) -> AppSizes? {
    var told = appSizes
    told.drop(Set(appSizes.apps.keys).subtracting(apps))
    return told.isEmpty ? nil : told
  }

  /// With the record itself: a tab that comes to the front of its group stands for the one that was there.
  func foresightPasses(from old: WindowID, to window: WindowID) {
    askedAbout[window] = askedAbout.removeValue(forKey: old)
    enteredSizes[window] = enteredSizes.removeValue(forKey: old)
    confirmedSizes[window] = confirmedSizes.removeValue(forKey: old)
  }

  func forgetForesight(of window: WindowID) {
    askedAbout[window] = nil
    enteredSizes[window] = nil
  }
}
