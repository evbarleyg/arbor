import ArborCore
import CoreGraphics

/// The `layout` command (docs/features/F54-layouts-as-text.md, docs/LAYOUTS.md): arranging a display as a
/// line of text says, and printing its arrangement as such a line. Reading, matching and building
/// are pure and live in ArborCore (`LayoutNotation`, `WindowSlot`); here they meet the windows.
extension Controller {
  /// An arrangement that is waiting for the windows of apps `layout --open` opened.
  struct PendingLayout {
    var spec: LayoutNotation.Spec
    /// The windows of each slot so far.
    var windows: [[WindowID]]
    /// The tree as `layout` left it. Once the display's tree differs, the user has moved on.
    var tree: LayoutTree
  }

  /// How long a window may take to appear. Big apps on a cold start take half a minute.
  static let pendingLayoutPatience = 60.0
  /// More than anyone wants to start at once; a line can hold a thousand names.
  static let mostAppsToOpen = 12

  // MARK: Naming displays

  /// Displays in the order people count them: the main one, then from left to right and top to bottom.
  var numberedDisplays: [DisplaySnapshot] {
    displays.sorted { a, b in
      if a.isMain != b.isMain { return a.isMain }
      return (a.frame.minX, a.frame.minY, a.id.rawValue) < (b.frame.minX, b.frame.minY, b.id.rawValue)
    }
  }

  /// 1 for the main display, and so on; what `@2` counts.
  func number(of display: DisplayID) -> Int? {
    numberedDisplays.firstIndex { $0.id == display }.map { $0 + 1 }
  }

  enum DisplayChoice {
    case display(DisplayID)
    case failure(CommandResult)
  }

  /// The display `name` means: a number as `number(of:)` counts, or an id from `state`. Nil is the display
  /// commands act on (`commandDisplayID()`).
  func chooseDisplay(_ name: String?) -> DisplayChoice {
    guard let name else {
      guard let id = commandDisplayID(), workspaces[id] != nil else { return .failure(.failure("no display")) }
      return .display(id)
    }
    let ordered = numberedDisplays
    let found = Int(name).flatMap { $0 >= 1 && $0 <= ordered.count ? ordered[$0 - 1] : nil }
      ?? ordered.first { $0.id.rawValue.lowercased() == name.lowercased() }
    guard let found, workspaces[found.id] != nil else {
      return .failure(.failure("no display \(name); there \(ordered.count == 1 ? "is" : "are") \(Self.count(ordered.count, "display")), counted from @1"))
    }
    return .display(found.id)
  }

  // MARK: Naming windows

  /// The windows Arbor arranges, best first: those that take up room before those that are minimised,
  /// hidden or on another macOS Space, and within each the most recently focused first. Windows
  /// not focused since Arbor started come last, oldest first.
  func windowCandidates() -> [WindowCandidate] {
    var seen = Set<WindowID>()
    let order = ([system.focusedWindow()].compactMap { $0 } + focusHistory + managedWindowIDs)
      .filter { seen.insert($0).inserted && isManaged($0) }
      .compactMap { windows[$0] }
    return (order.filter(\.isPresent) + order.filter { !$0.isPresent }).map(Self.candidate)
  }

  private static func candidate(_ window: WindowSnapshot) -> WindowCandidate {
    WindowCandidate(id: window.id, bundleID: window.bundleID, appName: window.appName, title: window.title)
  }

  // MARK: Arranging

  func applyLayout(_ spec: LayoutNotation.Spec, display name: String?, open: Bool) -> CommandResult {
    let display: DisplayID
    switch chooseDisplay(name) {
    case .failure(let result): return result
    case .display(let id): display = id
    }
    // Laying out now would pull the window out of the user's hand.
    if system.isMouseButtonDown(), drag != nil || edgeResize != nil {
      return .failure("cannot arrange while a window is being dragged")
    }

    let candidates = windowCandidates()
    let resolution = spec.resolve(candidates, current: workspaces[display]?.tree)
    let placed = resolution.allWindows
    // An app Arbor was told not to arrange is not missing, and opening it would not help.
    let excluded = resolution.missing.filter { owner in
      guard case .app(let name) = owner else { return false }
      return windows.values.contains { !filter.manages($0) && AppName.rank(name, bundleID: $0.bundleID, appName: $0.appName) != nil }
    }
    var opening: [String] = []
    if open {
      for case .app(let name) in resolution.missing where !excluded.contains(.app(name)) {
        if opening.count < Self.mostAppsToOpen, system.launchApp(name) { opening.append(name) }
      }
    }
    // Most likely a slip of the keyboard. Floating everything would be a poor answer to it.
    guard !placed.isEmpty || spec.slots.isEmpty || !opening.isEmpty else {
      return .failure(Self.sentence(about: resolution, excluded: excluded, opening: []).joined(separator: "; ") + "; nothing changed")
    }

    forgetPendingLayout(on: display)
    // Places kept for windows that are not there yet (Controller+PendingSlots.swift) belong to the arrangement that is being replaced.
    forgetPendingSlots(on: display)
    // As for `arrange`: what the user arranged is not for a rule to undo when a window's title arrives late.
    stopWatchingTitles()
    let isPlaced = Set(placed)
    for other in workspaces.keys.sorted() where other != display {
      let taken = workspaces[other]!.allWindows.filter(isPlaced.contains)
      guard !taken.isEmpty else { continue }
      // They arrive floating, at the frames they have of their own, which docking them below remembers (F48).
      for window in taken { transfer(window, from: other, to: display) }
      relayout(other, reason: .structure)
    }
    guard let workspace = workspaces[display] else { return .failure("no display") }
    let floated = workspace.tree.allWindows.filter { !isPlaced.contains($0) }
    var updated = workspace
    for window in floated { updated.floating[window] = floatingFrame(for: window, on: display) }
    // Those the line places go on floating until `reset`, which remembers where, so that they can go back there.
    let holdsWindows = updated.floating.keys.contains {
      !isPlaced.contains($0) && windows[$0]?.isPresent == true && !updated.isPinned($0)
    }
    let tree = tree(for: spec, filling: resolution.windows, recent: candidates.map(\.id), roomOnDesktop: holdsWindows, on: display)
    // Saved views and history go on pointing at the spaces that still hold the same windows.
    updated.reset(tree: tree, carrying: workspace.tree.counterparts(in: tree))
    workspaces[display] = updated
    // Node ids start again in the new tree, and would be mistaken for slots somebody squeezed in the old one.
    forgetSqueezes(on: display)
    layOutAnew(display, undocked: floated)
    notifyOfReset(display)
    scheduleSave()

    if !opening.isEmpty || (open && !resolution.short.isEmpty) {
      pendingLayouts[display] = PendingLayout(spec: spec, windows: resolution.windows, tree: tree)
      scheduler.schedule(Self.pendingLayoutKey(display), after: Self.pendingLayoutPatience) { [weak self] in
        self?.pendingLayouts[display] = nil
      }
    }

    var message = "arranged \(Self.count(placed.count, "window"))"
    if !floated.isEmpty { message += ", floated \(floated.count)" }
    var notes = Self.sentence(about: resolution, excluded: excluded, opening: opening)
    let away = Self.unique(placed.compactMap { windows[$0] }.filter { !$0.isPresent }.map(\.appName))
    if !away.isEmpty {
      notes.append("\(Self.list(away, joinedBy: "and")) \(away.count == 1 ? "is" : "are") minimised or hidden, and will be in place when back")
    }
    // Until tab groups have strips (F04), nothing on screen says that they are there.
    let behind = tree.preorder().reduce(0) { count, leaf in
      guard case .stack(let windows, _) = tree[leaf]?.kind else { return count }
      return count + max(windows.filter { self.windows[$0]?.isPresent == true }.count - 1, 0)
    }
    if behind > 0 {
      notes.append("\(Self.count(behind, "window")) \(behind == 1 ? "is" : "are") behind \(behind == 1 ? "a tab" : "tabs"): ⌘Tab or ⌘` brings one forward")
    }
    let unseen = updated.floating.keys.filter { parked.contains($0) && windows[$0]?.isPresent == true }.count
    if unseen > 0 {
      notes.append("\(Self.count(unseen, "window")) on the Desktop \(unseen == 1 ? "is" : "are") out of view: the Desktop is too small to use")
    }
    return .success(([message] + notes).joined(separator: "; "))
  }

  /// The tree of `spec`. The Desktop that is added when the line does not mention it is as narrow as `arrange` makes it,
  /// which on a laptop is too narrow to use beside three columns: it would be a tile, with the windows that float on it
  /// nowhere to go. With `roomOnDesktop` it is made just wide enough to use, unless that costs a docked window its place.
  private func tree(
    for spec: LayoutNotation.Spec, filling windows: [[WindowID]], recent: [WindowID], roomOnDesktop: Bool, on displayID: DisplayID
  ) -> LayoutTree {
    let usual = spec.tree(filling: windows, recent: recent, desktopSize: settings.arrangeDesktopWeight)
    guard roomOnDesktop, !spec.mentionsDesktop, let display = display(displayID) else { return usual }
    let present = presentWindowIDs()
    let minimums = minimumSizes
    let here = options(for: displayID)
    func trial(_ tree: LayoutTree) -> Layout {
      LayoutEngine.layout(
        tree, camera: tree.root, in: display.visibleFrame, options: here.layoutOptions, isPresent: { present.contains($0) },
        minimumSize: { minimums[$0] })
    }
    let before = trial(usual)
    guard before.desktopFrame == nil else { return usual }
    // Beside n spaces of average size 1, a Desktop of size s gets s / (n + s) of the room.
    let beside = Double(max(usual.children(of: usual.root).count - 1, 1))
    let room = Double(display.visibleFrame.width) - here.gap * (beside + 2)
    let needed = here.minimumUsableWidth + 2
    guard room > needed else { return usual }
    let wider = spec.tree(filling: windows, recent: recent, desktopSize: beside * needed / (room - needed))
    let after = trial(wider)
    return after.desktopFrame != nil && after.tiles.count < before.tiles.count ? wider : usual
  }

  /// Lays out the arrangement a line has made. A change of the arrangement, which never takes a floating window out of view
  /// (`placeFloatingWindows`) and leaves alone those their user put over docked windows on purpose. But here the docked
  /// space is all new, so none of them lies there on purpose. The layout is told so, and it alone moves them: a line is one
  /// action, and for one action a window is given one frame. `undocked` have just left their slots and still have the
  /// slots' shape (F48).
  private func layOutAnew(_ displayID: DisplayID, undocked: [WindowID]) {
    func inView() -> [(window: WindowID, frame: CGRect)] {
      undocked.sorted().filter { !parked.contains($0) && windows[$0]?.isPresent == true }.compactMap { window in
        workspaces[displayID]?.floating[window].map { (window, $0) }
      }
    }
    // The Desktop is too small to use. What is in view stays in view, over the docked windows, at its own size.
    let toPutBack = layoutToCome(on: displayID)?.desktopFrame == nil ? inView() : []
    placedOnPurpose = Set(toPutBack.map(\.window))
    displayArrangedAnew = displayID
    defer { (placedOnPurpose, displayArrangedAnew) = ([], nil) }
    relayout(displayID, reason: .structure, puttingBack: toPutBack)
    // A window refused its slot, and the room it took has cost the Desktop that was to come. Nothing has moved these yet.
    guard toPutBack.isEmpty, layouts[displayID]?.desktopFrame == nil, let display = display(displayID) else { return }
    for (window, frame) in inView() { putBack(window, at: frame, on: display) }
  }

  /// What was asked for and not found: "no window of Mail or Notes", "only 1 window of Safari", "opening Slack".
  private static func sentence(
    about resolution: LayoutNotation.Resolution, excluded: [WindowSlot.Owner], opening: [String]
  ) -> [String] {
    var notes: [String] = []
    var (apps, unarranged, numbers): ([String], [String], [String]) = ([], [], [])
    for owner in resolution.missing {
      switch owner {
      case .app(let name) where excluded.contains(owner): unarranged.append(name)
      case .app(let name): if !opening.contains(name) { apps.append(name) }
      case .window(let id): numbers.append(String(id.rawValue))
      }
    }
    if !apps.isEmpty { notes.append("no window of " + list(apps, joinedBy: "or")) }
    if !unarranged.isEmpty { notes.append("Arbor does not arrange " + list(unarranged, joinedBy: "or")) }
    if !numbers.isEmpty { notes.append("no window " + list(numbers, joinedBy: "or")) }
    for shortfall in resolution.short.prefix(3) {
      notes.append("only \(count(shortfall.found, "window")) of \(shortfall.app)")
    }
    if !opening.isEmpty { notes.append("opening " + list(opening, joinedBy: "and")) }
    return notes
  }

  /// "Mail", "Mail or Notes", "Mail, Notes or Slack", "Mail, Notes, Slack, Xcode or 3 more".
  static func list(_ items: [String], joinedBy word: String) -> String {
    var items = items
    if items.count > 5 { items = items.prefix(4) + ["\(items.count - 4) more"] }
    guard let last = items.popLast() else { return "" }
    return items.isEmpty ? last : items.joined(separator: ", ") + " \(word) " + last
  }

  private static func unique(_ items: [String]) -> [String] {
    var seen = Set<String>()
    return items.filter { seen.insert($0).inserted }
  }

  /// The same spaces, windows and sizes under the same ids. Which tab a group shows is not arrangement.
  private static func sameArrangement(_ a: LayoutTree, _ b: LayoutTree) -> Bool {
    guard a.root == b.root, a.nodes.count == b.nodes.count else { return false }
    return a.nodes.allSatisfy { id, node in
      guard let other = b.nodes[id], node.parent == other.parent, node.weight == other.weight else { return false }
      if case .stack(let mine, _) = node.kind, case .stack(let theirs, _) = other.kind { return mine == theirs }
      return node.kind == other.kind
    }
  }

  // MARK: Windows that arrive later

  private static func pendingLayoutKey(_ display: DisplayID) -> String { "layout-open \(display.rawValue)" }

  func forgetPendingLayout(on display: DisplayID) {
    guard pendingLayouts.removeValue(forKey: display) != nil else { return }
    scheduler.cancel(Self.pendingLayoutKey(display))
  }

  /// Called from `shutdown`, so also by `pause`.
  func forgetPendingLayouts() {
    for display in pendingLayouts.keys.sorted() { forgetPendingLayout(on: display) }
  }

  /// Called from `windowDestroyed`. A window that joined and closed again (a splash screen) leaves its
  /// slot free for the next one.
  func releasePendingSlot(of id: WindowID) {
    for display in pendingLayouts.keys.sorted() {
      guard var pending = pendingLayouts[display], let index = pending.windows.firstIndex(where: { $0.contains(id) })
      else { continue }
      pending.windows[index].removeAll { $0 == id }
      pending.tree.remove(id, shareSpace: settings.shareRemovedSpace)
      pendingLayouts[display] = pending
    }
  }

  /// Called from `windowAppeared` with a window nobody has adopted yet. If an arrangement is waiting
  /// for a window of its app, the window takes its slot, ahead of any rule, and this returns true.
  ///
  /// The tree is built again from the text with the window in it. Node ids depend only on the text
  /// (`Spec.tree`), so the view stays where it is: if the user has zoomed in on something else
  /// meanwhile, the newcomer takes its place out of view.
  func joinPendingLayout(_ id: WindowID) -> Bool {
    guard !pendingLayouts.isEmpty, let snapshot = windows[id] else { return false }
    let rule = AppRule.firstMatch(in: settings.rules, bundleID: snapshot.bundleID, title: snapshot.title)
    guard rule?.action != .ignore else { return false }
    let candidate = Self.candidate(snapshot)
    for display in pendingLayouts.keys.sorted() {
      guard var pending = pendingLayouts[display], let current = workspaces[display]?.tree,
        Self.sameArrangement(current, pending.tree)
      else {
        forgetPendingLayout(on: display)
        continue
      }
      let slots = pending.spec.slots
      let free = slots.indices.filter { $0 < pending.windows.count && pending.windows[$0].isEmpty && slots[$0].accepts(candidate) }
      guard let index = free.first(where: { slots[$0].title != nil && slots[$0].matchesTitle(candidate.title) }) ?? free.first
      else { continue }

      adopt(id, rescue: false)
      // It floats for a moment, where its app put it, which docking it below remembers (F48).
      if let home = workspaceID(containing: id), home != display { transfer(id, from: home, to: display) }
      pending.windows[index] = [id]
      // As in `applyLayout`, or the Desktop would change its width now.
      let holdsWindows = workspaces[display]!.floating.keys.contains {
        $0 != id && windows[$0]?.isPresent == true && !workspaces[display]!.isPinned($0)
      }
      var tree = tree(for: pending.spec, filling: pending.windows, recent: [], roomOnDesktop: holdsWindows, on: display)
      for leaf in current.preorder() {
        if let shown = current.activeWindow(of: leaf) { tree.activate(shown) }
      }
      pending.tree = tree
      workspaces[display]!.grow(into: tree)
      relayout(display, reason: .structure)
      Log.info("\(id) took its place in the arrangement that was waiting for it")

      if zip(slots, pending.windows).contains(where: { $0.1.isEmpty && !$0.0.takesAll }) {
        pendingLayouts[display] = pending
      } else {
        forgetPendingLayout(on: display)
      }
      return true
    }
    return false
  }

  // MARK: Printing

  func printLayout(display name: String?, naming: LayoutNotation.Naming) -> CommandResult {
    let display: DisplayID
    switch chooseDisplay(name) {
    case .failure(let result): return result
    case .display(let id): display = id
    }
    guard let tree = workspaces[display]?.tree else { return .failure("no display") }
    let candidates = windowCandidates()
    let docked = Self.count(tree.allWindows.count, "docked window")
    // What is printed can be read: that is what it is for. A line has a greatest length, in bytes, and titles are the first to go, a
    // little at a time, so that a line that nearly fits still tells an app's windows apart; then names, since numbers are shortest.
    var ways: [(naming: LayoutNotation.Naming, title: Int)] = [(.apps, 0), (.ids, 0)]
    if naming == .titles { ways = [60, 40, 24, 12, 6].map { (.titles, $0) } + ways }
    if naming == .ids { ways = [(.ids, 0)] }
    for way in ways {
      let text = LayoutNotation.Spec(tree) { slot(for: $0, naming: way.naming, titleLength: way.title, among: candidates) }.text
      guard (try? LayoutNotation.parse(text)) != nil else { continue }
      return CommandResult(ok: true, message: "display \(number(of: display) ?? 1): \(docked)", text: text)
    }
    return .failure("\(docked) in spaces this deep are more than a line can hold (\(LayoutNotation.maximumLength) bytes, \(LayoutNotation.maximumDepth) brackets deep)")
  }

  /// How to write a window so that the line finds it again: by its app's name, or by the bundle id
  /// when that name would also mean another app, or by its number when nothing else can be written.
  private func slot(
    for id: WindowID, naming: LayoutNotation.Naming, titleLength: Int, among candidates: [WindowCandidate]
  ) -> WindowSlot {
    guard let window = windows[id] else {
      // A place kept for a window that is not there yet, under a number that means nothing. Its app is remembered.
      if let bundle = hints[id]?.bundleID, LayoutNotation.canBeWritten(bundle) { return .app(bundle) }
      return .window(id)
    }
    guard naming != .ids else { return .window(id) }
    func isOnlyThisApp(_ name: String) -> Bool {
      LayoutNotation.canBeWritten(name)
        && AppName.windows(of: name, in: candidates + [Self.candidate(window)]).allSatisfy { $0.bundleID == window.bundleID }
    }
    guard let name = ([window.appName] + [window.bundleID].compactMap { $0 }).first(where: isOnlyThisApp) else {
      return .window(id)
    }
    guard naming == .titles else { return .app(name) }
    // The beginning is enough to tell windows apart, and keeps the line readable.
    let title = String(window.title.prefix(titleLength))
    return .app(name, title: LayoutNotation.canBeWritten(title) ? title : nil)
  }
}
