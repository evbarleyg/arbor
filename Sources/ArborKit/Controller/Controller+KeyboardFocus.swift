import ArborCore
import CoreGraphics
import Foundation

/// Moving keyboard focus from the keyboard: `focus <direction>`, `focus next|previous`, `focus <window>`
/// and `focus-display` (docs/features/F22-keyboard-tiling-tools.md). `DirectionalSearch` in ArborCore
/// decides which rectangle lies in a direction; this file gathers what is in view and acts on the answer.
/// (Controller+Focus.swift is the other way round: following the focus changes macOS reports.)
extension Controller {
  /// What `focus` can land on: a window in view, or a tile, which it enters.
  enum FocusItem: Hashable, Sendable {
    case window(WindowID)
    case tile(NodeID)
  }

  typealias FocusCandidate = DirectionalSearch.Candidate<FocusItem>

  func focus(_ target: FocusTarget) -> CommandResult {
    switch target {
    case .direction(let direction): return focus(toward: direction)
    case .next: return cycleFocus(forward: true)
    case .previous: return cycleFocus(forward: false)
    case .window(let window): return focus(window: window)
    }
  }

  // MARK: What is in view

  /// Where a window Arbor arranges shows on `display`: its slot if it is docked, its own frame if it
  /// floats. Nil when it is out of view (parked, inside a tile, an inactive tab, minimized, hidden).
  /// Slots rather than window frames, so that an app that rounds its size, or a tab strip, does not
  /// make one neighbour look nearer than another.
  func frameInView(of window: WindowID, on display: DisplayID) -> CGRect? {
    guard let workspace = workspaces[display], let snapshot = windows[window], snapshot.isPresent,
      isManaged(window)
    else { return nil }
    if isLetBe(window) { return snapshot.frame }
    if let leaf = workspace.tree.leaf(containing: window) {
      guard let layout = layouts[display], let shown = layout.windowFrames[window] else { return nil }
      return layout.nodeFrames[leaf] ?? shown
    }
    guard workspace.isFloating(window), !parked.contains(window) else { return nil }
    return snapshot.frame
  }

  /// A request for focus that macOS has not confirmed yet.
  struct FocusRequest {
    var window: WindowID
    var time: Date
    /// The requests this one replaced before macOS had confirmed them. Word of those is still to come.
    var earlier: Set<WindowID> = []
    /// Whom macOS named when the request was made: the answer it goes on giving until it has got there.
    var from: WindowID?
    /// Activating another app takes a few hundredths of a second. After this long, what macOS says counts.
    static let patience: TimeInterval = 0.5
  }

  /// The window commands take as the focused one: what macOS reports, except that for a moment after a
  /// command gave a window focus it is that window. macOS needs that moment to make it true, and the next
  /// key can arrive sooner; it would start from the old window, and one press would seem lost.
  func keyboardFocus() -> WindowID? {
    let reported = system.focusedWindow()
    guard let request = focusRequest else { return reported }
    // On its way macOS names whom it named before, or one of those asked for earlier. Anybody else is somebody's own doing, of which
    // there may never be a report (⌘Tab to an app whose focused window is the same as ever): whoever came last is right.
    let onItsWay = reported == request.from || reported.map(request.earlier.contains) == true
    if reported == request.window || !onItsWay || windows[request.window] == nil
      || now().timeIntervalSince(request.time) > FocusRequest.patience
    {
      focusRequest = nil
      return reported
    }
    return request.window
  }

  /// Called for every focus change that is reported. One that goes neither to the window asked for nor to one asked for
  /// just before it is somebody else's doing (a click, ⌘Tab, another command), and whoever came last is right.
  func endFocusRequest(unlessFor reported: WindowID) {
    guard let request = focusRequest else { return }
    guard reported != request.window else { return confirmFocusRequest(at: system.focusedWindow()) }
    guard !request.earlier.contains(reported) else { return }
    focusRequest = nil
  }

  /// macOS has got there, so the request is over and what macOS says counts again. Not only at the next command: the keyboard
  /// can go on meanwhile without a report (a click in another app), and that command would act on the window asked for.
  func confirmFocusRequest(at focused: WindowID?) {
    if let request = focusRequest, request.window == focused { focusRequest = nil }
  }

  /// The focused window, its display and where it shows, if Arbor arranges it and it is in view.
  func focusedWindowInView() -> (window: WindowID, display: DisplayID, frame: CGRect)? {
    guard let window = keyboardFocus(), let display = workspaceID(containing: window),
      let frame = frameInView(of: window, on: display)
    else { return nil }
    return (window, display, frame)
  }

  /// The display of commands that start from the focused window (`focus`, `rotate`, `mirror`): that window's, or the one
  /// under the pointer when Arbor does not arrange it. Commands about the view ask `commandDisplayID()`.
  var keyboardDisplayID: DisplayID? { focusedPlace?.display ?? pointerDisplayID }

  /// How long ago any of `windows` had focus, as `DirectionalSearch` counts it.
  func focusRecency(of windows: [WindowID]) -> Int {
    windows.compactMap { focusHistory.firstIndex(of: $0) }.min() ?? .max
  }

  /// Whether entering the Desktop of `display` would bring a floating window into view. As a tile it is still part of the view
  /// and what floats on it is in view already, so this is for whatever is kept away all the same.
  func hasFloatingWindowsOutOfView(on display: DisplayID) -> Bool {
    workspaces[display]?.floating.keys.contains {
      windows[$0]?.isPresent == true && isManaged($0) && parked.contains($0)
    } ?? false
  }

  /// Everything focus can go to on `display`: the docked windows in view in tree order, the tiles, then
  /// the floating windows in view in the order they were opened. With `arriving`, what came into view with a move of the
  /// view: not the pinned windows, which were there before, and where keys typed by surprise do harm (a call). Nor the floating
  /// windows that merely lie there whatever the view shows (`floatsBesideTheView`). Of those, one that something covers is never a stop: it
  /// cannot be seen, a direction would fetch it from behind the framed window, and the neighbor beyond would be out of the key's reach.
  func focusCandidates(on display: DisplayID, arriving: Bool = false) -> [FocusCandidate] {
    guard let layout = layouts[display], let workspace = workspaces[display] else { return [] }
    var candidates: [FocusCandidate] = []
    lazy var frontToBack = system.windowsFrontToBack()
    func add(_ window: WindowID) {
      // One that hangs over its neighbour lies where its place is: left of that neighbour, however far it reaches.
      guard let frame = layout.tightPlaces[window] ?? frameInView(of: window, on: display), !(arriving && workspace.isPinned(window)),
        !(floatsBesideTheView(window, on: display) && (arriving || isCovered(window, by: frontToBack, apartFrom: [])))
      else { return }
      candidates.append(FocusCandidate(id: .window(window), frame: frame, recency: focusRecency(of: [window])))
    }
    for window in workspace.tree.windows(under: layout.camera) { add(window) }
    for tile in layout.tiles {
      // There is nothing to focus on an empty Desktop, nor on one whose windows are stops themselves.
      if tile.kind == .desktop, !hasFloatingWindowsOutOfView(on: display) { continue }
      // Its window is a stop itself (Controller+LetBe.swift).
      if tile.windows.contains(where: isLetBe) { continue }
      let inside = tile.kind == .desktop ? Array(workspace.floating.keys) : tile.windows
      candidates.append(FocusCandidate(id: .tile(tile.node), frame: tile.frame, recency: focusRecency(of: inside)))
    }
    for window in workspace.floating.keys.sorted() { add(window) }
    return candidates
  }

  /// The windows in view on `display`, in the order `focus next` visits them.
  func windowsInView(on display: DisplayID) -> [WindowID] {
    focusCandidates(on: display).compactMap { candidate in
      if case .window(let window) = candidate.id { return window }
      return nil
    }
  }

  // MARK: Giving focus

  /// Gives `window` keyboard focus and brings it into view if it is not.
  func giveFocus(to window: WindowID) {
    // A command asked for this window, so it comes into view now, not when macOS has moved the keyboard.
    // That can hand focus to another window on the way (`ensureFocusIsVisible`), so the request comes after.
    let replaced = focusRequest
    onTheWay(to: window) { bringIntoView(window) }
    // `swap` and `move-to-display` ask for the window that has it as a rule: asking macOS again is several round trips.
    guard system.focusedWindow() != window else {
      focusRequest = nil
      return
    }
    system.focus(window)
    // macOS reports the change a moment later. Hearing of it now puts it in the history and tells the
    // observers before the command returns; hearing it again from macOS does no harm.
    keyboardIs(in: window, saysMacOS: false)
    noteFocusRequest(for: window, replacing: replaced)
  }

  /// Asks macOS to give `window` the keyboard, and remembers having asked until macOS has got there. Across apps a Mac moves the
  /// keyboard only after the call has returned: whoever asks it in the same breath who has the keyboard is told the old window.
  /// `keyboardFocus()` knows better. (Nothing comes into view for it, and nobody is told: that is `giveFocus`.)
  ///
  /// For a window its person has named or pointed at. One that Arbor picks by itself goes through `sendTheKeyboard(to:)`.
  func askForTheKeyboard(for window: WindowID) {
    let replaced = focusRequest
    system.focus(window)
    noteFocusRequest(for: window, replacing: replaced)
  }

  /// `askForTheKeyboard` for a window that Arbor has picked by itself: the keyboard has to go somewhere, or back. A person's ⌘M is never undone,
  /// so the window is asked first, then and there, where it is. It may have landed in the Dock: its app names its next window, which is
  /// why Arbor is looking for somebody to give the keyboard to, a moment before it reports the minimizing, and the request would
  /// fetch the window back out. Returns false if it was not made, for that reason or because the window's app does not say: what cannot
  /// be found out is no leave to act, and there may be another to pick. (Whoever names a window gets it, out of the Dock too: what
  /// they ask for last counts. And of an app found hanging the question would be the call that times out, after which the layer sends that
  /// app nothing: unasked, the first call of the request at least waits with the app and is carried out when it wakes.)
  func sendTheKeyboard(to window: WindowID) -> Bool {
    let whereabouts = window == namedWindow ? .here : system.whereabouts(of: window)
    guard whereabouts == .here else {
      Log.info("\(window) \(whereabouts == .unknown ? "does not say where it is" : "is in the Dock or gone"): the keyboard is not sent to it")
      return false
    }
    askForTheKeyboard(for: window)
    return true
  }

  /// Runs `move`, which moves the view on the way to `window`, named by its person. A view that moves takes the keyboard along and picks that very
  /// window as a rule. It is asked nothing then, as at the request that follows.
  func onTheWay(to window: WindowID, _ move: () -> Void) {
    let outer = namedWindow
    namedWindow = window
    defer { namedWindow = outer }
    move()
  }

  private func noteFocusRequest(for window: WindowID, replacing replaced: FocusRequest?) {
    let named = system.focusedWindow()
    guard named != window else {
      focusRequest = nil
      return
    }
    let earlier = replaced.map { $0.earlier.union([$0.window]) } ?? []
    focusRequest = FocusRequest(window: window, time: now(), earlier: earlier.subtracting([window]), from: named)
  }

  // MARK: focus <direction>

  /// Focuses the nearest window in view in `direction` from the focused one. When none lies that way it
  /// does what `neighbor` does, on the display the keyboard is on, and focuses what it finds there; past
  /// the last space it goes on to the next display.
  func focus(toward direction: Edge) -> CommandResult {
    let origin = focusedWindowInView()
    guard let displayID = origin?.display ?? keyboardDisplayID, let here = display(displayID) else {
      return .failure("no display")
    }

    // A held view does not move (F58), so a tile is no stop, and neither is what lies beyond the view.
    let isHeld = holdLevel == .view
    func stops(on display: DisplayID) -> [FocusCandidate] {
      focusCandidates(on: display).filter { candidate in
        if isHeld, case .tile = candidate.id { return false }
        return true
      }
    }

    // 1. The nearest window or tile in view.
    let inView = stops(on: displayID)
    if let origin {
      let others = inView.filter { $0.id != .window(origin.window) }
      if let found = DirectionalSearch.nearest(from: origin.frame, toward: direction, among: others) {
        return arrive(at: found.id, on: displayID, toward: direction, from: origin.frame)
      }
    } else if let found = startingPoint(among: inView) {
      // A tile is entered as if from the left of the screen.
      return arrive(at: found.id, on: displayID, toward: .right, from: here.visibleFrame)
    }
    // 1b. A floating window that lies over a docked one: the one beneath has its turn before the view moves.
    if let origin, workspaces[displayID]?.isFloating(origin.window) == true,
      let beneath = inView.first(where: { candidate in
        guard case .window(let window) = candidate.id, workspaces[displayID]?.isDocked(window) == true else { return false }
        return candidate.frame.contains(origin.frame.center)
      })
    {
      return arrive(at: beneath.id, on: displayID, toward: direction, from: origin.frame)
    }
    // Leaving the view, what lies ahead is measured from the focused window, or from the whole view.
    let from = origin?.frame ?? here.visibleFrame

    // 2. At the edge of the view: the neighbouring space.
    if !isHeld, let view = treeView(displayID), let camera = workspaces[displayID]?.camera,
      let space = Navigation.neighbor(of: camera, toward: direction, in: view)
    {
      return arrive(at: .tile(space), on: displayID, toward: direction, from: from)
    }

    // 3. At the edge of the display: the next display that way with something to focus.
    var others = displays.filter { $0.id != displayID }
    while let next = DirectionalSearch.nearest(
      from: here.frame, toward: direction,
      among: others.map { DirectionalSearch.Candidate(id: $0.id, frame: $0.frame) }),
      let there = display(next.id)
    {
      let start = DirectionalSearch.approaching(there.visibleFrame, from: from, toward: direction)
      if let found = DirectionalSearch.nearest(from: start, toward: direction, among: stops(on: there.id)) {
        return arrive(at: found.id, on: there.id, toward: direction, from: from)
      }
      others.removeAll { $0.id == there.id }
    }
    if isHeld { return .failure("no window in view \(direction.sidePhrase), and \(heldMessage)") }
    return .failure("no window or space \(direction.sidePhrase)")
  }

  /// Where focus goes when there is no focused window to start from (none, one Arbor does not arrange, or
  /// one out of view): what is under the pointer, or else nearest the top left.
  private func startingPoint(among candidates: [FocusCandidate]) -> FocusCandidate? {
    let cursor = system.cursorLocation()
    // Floating windows come last in the list and more often than not lie in front of docked ones, hence `reversed`.
    return candidates.reversed().filter { $0.frame.contains(cursor) }.min { $0.recency < $1.recency }
      ?? candidates.min { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
  }

  /// Focuses what a search found: a window, or whatever is nearest in a tile or space, which the camera
  /// moves onto.
  private func arrive(
    at item: FocusItem, on display: DisplayID, toward direction: Edge, from origin: CGRect
  ) -> CommandResult {
    let window: WindowID
    switch item {
    case .window(let found):
      window = found
    case .tile(let node):
      guard let found = enter(node, on: display, toward: direction, from: origin) else {
        // An empty Desktop. The camera is there now, as `neighbor` would have left it.
        ensureFocusIsVisible(on: display)
        return .success("moved to \(name(of: node, on: display)); no window to focus there")
      }
      window = found
    }
    giveFocus(to: window)
    return .success("focused \(window)")
  }

  /// Moves the camera onto `node` and returns the window there that is nearest the edge one came
  /// through. If that is a tile again, goes on into it.
  private func enter(_ node: NodeID, on display: DisplayID, toward direction: Edge, from origin: CGRect) -> WindowID? {
    var node = node
    // A tile is always inside the camera's node, so every round goes down the tree and this ends
    // by itself; the bound is a second lock on the door.
    for _ in 0..<64 {
      moveCamera(on: display, to: node, refocus: false)
      guard let view = self.display(display)?.visibleFrame else { return nil }
      let start = DirectionalSearch.approaching(view, from: origin, toward: direction)
      // What arrived with the view; a pinned window only if nothing did, rather than leave the keyboard out of view.
      guard
        let found = DirectionalSearch.nearest(
          from: start, toward: direction, among: focusCandidates(on: display, arriving: true))
          ?? DirectionalSearch.nearest(from: start, toward: direction, among: focusCandidates(on: display))
      else { return nil }
      switch found.id {
      case .window(let window): return window
      case .tile(let inner):
        guard inner != node else { return nil }
        node = inner
      }
    }
    return nil
  }

  // MARK: focus next | previous

  func cycleFocus(forward: Bool) -> CommandResult {
    let focused = focusedWindowInView()
    guard let display = focused?.display ?? keyboardDisplayID else { return .failure("no display") }
    let order = windowsInView(on: display)
    guard let first = order.first, let last = order.last else { return .failure("no windows in view") }
    var next = forward ? first : last
    if let current = focused?.window, let index = order.firstIndex(of: current) {
      guard order.count > 1 else { return .failure("\(current) is the only window in view") }
      next = order[(index + (forward ? 1 : order.count - 1)) % order.count]
    }
    giveFocus(to: next)
    return .success("focused \(next)")
  }

  // MARK: focus <window>

  func focus(window: WindowID) -> CommandResult {
    if case .failure(let result) = target(window) { return result }
    guard windows[window]?.isPresent == true else {
      return .failure("\(window) is minimized, hidden (⌘H) or on another of the macOS Spaces")
    }
    giveFocus(to: window)
    return .success("focused \(window)")
  }

  // MARK: focus-display

  /// Displays in the order `focus-display` and `move-to-display` count them: left to right, then top to bottom.
  var orderedDisplays: [DisplaySnapshot] {
    displays.sorted {
      ($0.frame.minX, $0.frame.minY, $0.id.rawValue) < ($1.frame.minX, $1.frame.minY, $1.id.rawValue)
    }
  }

  /// The display `target` means, counting from `current`, and its number; or why there is none.
  func resolve(_ target: DisplayTarget, from current: DisplayID?) -> (display: DisplaySnapshot, number: Int)? {
    let ordered = orderedDisplays
    let place = ordered.firstIndex { $0.id == current }
    guard let index = target.index(from: place, count: ordered.count) else { return nil }
    return (ordered[index], index + 1)
  }

  func noSuchDisplay(_ target: DisplayTarget) -> CommandResult {
    .failure("no display \(target.text); \(displays.count) connected")
  }

  /// Focuses the window of another display that had focus last among those in view there. From then on shortcuts act
  /// there, because they follow the keyboard (F56). The pointer stays where the hand left it.
  /// `next` and `previous` pass over a display with nothing in view, as `focus <direction>` does.
  func focusDisplay(_ target: DisplayTarget) -> CommandResult {
    let current = keyboardDisplayID
    guard let first = resolve(target, from: current) else { return noSuchDisplay(target) }
    let steps = target == .next || target == .previous
    if first.display.id == current, steps { return .failure("there is only one display") }
    var (display, number) = first
    while true {
      let inView = windowsInView(on: display.id)
      let topLeft = inView.min { a, b in
        let (fa, fb) = (frameInView(of: a, on: display.id) ?? .zero, frameInView(of: b, on: display.id) ?? .zero)
        return (fa.minY, fa.minX) < (fb.minY, fb.minX)
      }
      if let window = focusHistory.first(where: { inView.contains($0) }) ?? topLeft {
        giveFocus(to: window)
        return .success("focused \(window) on display \(number)")
      }
      // Round to where the keyboard is, or to the first one tried when it is on no display.
      guard steps, let further = resolve(target, from: display.id), further.display.id != current,
        further.display.id != first.display.id
      else { break }
      (display, number) = further
    }
    return .failure(
      steps && displays.count > 2 ? "no window is in view on another display" : "no window is in view on display \(first.number)")
  }
}
