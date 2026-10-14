import ArborCore
import CoreGraphics
import Foundation

/// Peek: hold to look, let go to land (docs/features/F51-peek.md).
///
/// `Peek` (ArborCore) decides; this file tells it what happens and does what it answers. While the keys are down
/// a timer looks at the pointer, the mouse button and the keys thirty times a second, so the only thing
/// the app has to add is the key's press and release.
///
/// History: the move to everything is not recorded when the key goes down. Whatever ends the peek first puts the camera, Back
/// and Forward back as they were, without laying anything out, and then makes one ordinary move. So history gets one
/// entry from the view that was left to the landing, or none.
extension Controller {
  struct PeekSession {
    var peek: Peek
    var display: DisplayID
    /// The shortcut that is being held.
    var chord: KeyChord
    /// What `onTemporaryShortcuts` was last told.
    var temporary: [KeyBinding] = []
    var tookKeys = false
    var shownOutline: NodeID?
    /// What Back and Forward held when the key went down.
    var back: [NodeID]
    var forward: [NodeID]
  }

  static let peekInterval = 1.0 / 30

  /// The shortcuts a peek has asked for on top of the registered ones.
  public var temporaryShortcuts: [KeyBinding] { peeking?.temporary ?? [] }
  /// Whether a shortcut is being held to look.
  public var isPeeking: Bool { peeking?.peek.phase == .holding }

  /// A registered shortcut's key went down or came up. Every shortcut comes through here. Runs its command with
  /// `run` (by default `perform(_:from:)`) and returns the reply, unless a peek takes the key, or it came up.
  @discardableResult
  public func shortcut(
    _ binding: KeyBinding, _ phase: KeyPhase, run: ((Command) -> CommandResult)? = nil
  ) -> CommandResult? {
    var result: CommandResult?
    traced(binding, phase) {
      // "Any key puts the panel of shortcuts away", also one that a peek takes and that runs no command.
      if phase == .pressed, binding.command != .showShortcuts { hideCheatSheet() }
      if holdIgnores(binding, phase) || peekTakes(binding, phase) || minimapTakes(binding, phase) || phase == .released { return }
      result = run?(binding.command) ?? perform(binding.command, from: .shortcut)
      minimapKeyWentDown(binding)
    }
    return result
  }

  private func peekTakes(_ binding: KeyBinding, _ phase: KeyPhase) -> Bool {
    guard let session = peeking else {
      return phase == .pressed && binding.command == .showAll && beginPeek(holding: binding.chord)
    }
    if binding.chord == session.chord {
      // Pressed again while it is down is auto-repeat.
      if phase == .released {
        Log.debug("peek: the key came up")
        updatePeek { $0.released(at: peekTime) }
      }
      return true
    }
    guard phase == .pressed, session.peek.takesKeys, binding.chord.modifiers == session.chord.modifiers else {
      return false
    }
    switch binding.chord.key {
    case .left: movePeekOutline(.left)
    case .right: movePeekOutline(.right)
    case .up: movePeekOutline(.top)
    case .down: movePeekOutline(.bottom)
    case .escape: updatePeek { $0.escape() }
    default: return false
    }
    return true
  }

  // MARK: Beginning

  /// Shows everything, as the command does, and waits to see whether the key stays down. False leaves the
  /// key to the plain command: peeking is off, Arbor is not running, the mouse is busy with a window, or the view
  /// is held, and the command says so.
  private func beginPeek(holding chord: KeyChord) -> Bool {
    // As before a command: a peek must not pretend either (Controller+Permission.swift).
    askAboutAccessibility(beyondDoubt: true, inPassing: true)
    guard settings.peek, isRunning, holdLevel != .view, drag == nil, edgeResize == nil,
      let (display, workspace) = deciding(true, { from(.shortcut) { cameraDisplay() } })
    else { return false }
    watchLifecycleForPeek()
    // As `perform` would before `show-all`, whose place this takes.
    closeFinder()
    moveCamera(on: display, to: workspace.tree.root, record: false)
    Log.info("show-all: showing everything")
    // The clock starts once everything shows. Laying out many windows takes a while, and a release that
    // waited in the queue meanwhile is a tap however late it is heard.
    peeking = PeekSession(
      peek: Peek(
        origin: workspace.camera, root: workspace.tree.root, at: peekTime, pointer: system.cursorLocation(),
        buttonDown: system.isMouseButtonDown()),
      display: display, chord: chord, back: workspace.back, forward: workspace.forward)
    scheduler.schedule("peek", after: Self.peekInterval) { [weak self] in self?.peekTick() }
    return true
  }

  private var peekTime: Double { now().timeIntervalSinceReferenceDate }

  // MARK: While the keys are down

  private func peekTick() {
    guard let session = peeking else { return }
    guard isRunning, let workspace = workspaces[session.display], let layout = layouts[session.display] else {
      return abandonPeek()
    }
    if drag != nil || edgeResize != nil { return interruptPeek() }
    let pointer = system.cursorLocation()
    let stillHeld = system.isHolding(session.chord)
    if !stillHeld { Log.debug("peek: the keys were found up") }
    updatePeek {
      $0.tick(
        at: peekTime, pointer: pointer, under: peekSpace(at: pointer, in: layout, of: workspace),
        buttonDown: system.isMouseButtonDown(), stillHeld: stillHeld)
    }
    if session.peek.phase == .pressed, isPeeking { Log.debug("peek: held") }
  }

  /// The space the pointer is over. A window kept in view (F49) lies over the arrangement, so pointing at it points
  /// at nothing underneath: the outline stays where it was, as over a gap.
  private func peekSpace(at pointer: CGPoint, in layout: Layout, of workspace: Workspace) -> NodeID? {
    let covered = workspace.pinnedWindows.contains { windows[$0]?.isPresent == true && windows[$0]?.frame.contains(pointer) == true }
    return covered ? nil : layout.leafOrTile(at: pointer, in: workspace.tree)
  }

  private func movePeekOutline(_ edge: Edge) {
    guard let session = peeking, let workspace = workspaces[session.display], let layout = layouts[session.display]
    else { return }
    let space = Peek.step(
      from: session.peek.outline, toward: edge, focused: system.focusedWindow(), in: layout, tree: workspace.tree)
    updatePeek {
      $0.arrow(to: space, pointer: system.cursorLocation())
      return nil
    }
  }

  /// `OverlayActions`: the outline's panel took a click.
  public func peekOutlineClicked(display: DisplayID) {
    guard peeking?.display == display else { return }
    updatePeek { $0.clicked() }
  }

  /// Another command, a drag or a pause gets in the way: the view stays on everything.
  func interruptPeek() {
    updatePeek { $0.interrupted() }
  }

  /// Something else is about to move the camera on `display`: a clicked tile, a window that took the keyboard.
  /// That is the landing. Called by `moveCamera` before it moves.
  func peekYields(on display: DisplayID) {
    // Any move of the camera makes the last landing history.
    if following.peekLanding?.display == display { following.peekLanding = nil }
    guard let session = peeking, session.display == display,
      session.peek.phase == .pressed || session.peek.phase == .holding
    else { return }
    returnFromPeek(session)
    updatePeek {
      $0.yielded()
      return nil
    }
  }

  /// Tells the peek that something happened, does what it answers, and keeps the outline, the temporary
  /// shortcuts and the timer in step with it.
  private func updatePeek(_ event: (inout Peek) -> Peek.Ending?) {
    guard var session = peeking else { return }
    if let tree = workspaces[session.display]?.tree { session.peek.spacesChanged(root: tree.root, exists: tree.contains) }
    let ending = event(&session.peek)
    peeking = session
    // The outline goes before the windows move.
    showPeek()
    if let ending { endPeek(ending, of: session) }
    if session.peek.phase == .over {
      peeking = nil
      scheduler.cancel("peek")
    } else {
      scheduler.schedule("peek", after: Self.peekInterval) { [weak self] in self?.peekTick() }
    }
  }

  // MARK: Ending

  /// The books as they were when the key went down, without laying anything out. One ordinary move follows, or none.
  private func returnFromPeek(_ session: PeekSession) {
    workspaces[session.display]?.returnFromALook(to: session.peek.origin, back: session.back, forward: session.forward)
  }

  private func endPeek(_ ending: Peek.Ending, of session: PeekSession) {
    let display = session.display
    guard workspaces[display] != nil else { return }
    returnFromPeek(session)
    switch ending {
    case .stay:
      // Everything is showing already, so only the record changes.
      workspaces[display]!.moveCamera(to: session.peek.root)
      notify(.camera(display))
      scheduleSave()
    case .goBack:
      // The workspace is there already; `relayout` and the rest of a camera move are still due.
      moveCamera(on: display, to: session.peek.origin, record: false)
      Log.info("peek: back to \(name(of: session.peek.origin, on: display, byName: false))")
    case .land(let space):
      moveCamera(on: display, to: space)
      following.peekLanding = (display, space, session.peek.origin)
      focusAfterLanding(on: space, display: display)
      Log.info("peek: framed \(name(of: space, on: display, byName: false))")
    }
  }

  /// Whether the view on `display` is where a peek put it, with nothing in history since: ⌃⌥[ leads to where the
  /// peek began, and ⌃⌥↩ to everything, which is what the person was looking at when they chose.
  func landedByPeek(on space: NodeID, display: DisplayID) -> Bool {
    guard let landing = following.peekLanding, landing.display == display, landing.space == space,
      let workspace = workspaces[display]
    else { return false }
    return workspace.camera == space && workspace.back.last == landing.origin
  }

  /// Framing a space with the keyboard somewhere else (another display, a window that is still in view beside it)
  /// would leave the typing behind. Who gets it is the rule of every view that arrives, the window used last: a group
  /// is landed on as a tile, and where the pointer lies in a tile says nothing about the windows inside.
  private func focusAfterLanding(on space: NodeID, display: DisplayID) {
    guard let layout = layouts[display], let tree = workspaces[display]?.tree else { return }
    let inView = tree.windows(under: space).filter { layout.windowFrames[$0] != nil }
    if let focused = system.focusedWindow(), inView.contains(focused) { return }
    giveTheKeyboardToTheView(on: display)
  }

  /// Arbor stopped looking (a pause, quitting) or the display is gone: there is nothing left to move.
  private func abandonPeek() {
    guard peeking != nil else { return }
    let hadTemporary = !temporaryShortcuts.isEmpty
    peeking = nil
    scheduler.cancel("peek")
    if hadTemporary { onTemporaryShortcuts?([]) }
  }

  /// Pausing and quitting stop the controller without asking anyone.
  private func watchLifecycleForPeek() {
    guard !following.watchesLifecycleForPeek else { return }
    following.watchesLifecycleForPeek = true
    observe { [weak self] change in
      guard change == .lifecycle, let self, !self.isRunning else { return }
      self.abandonPeek()
    }
  }

  // MARK: What shows

  /// The outline for `overlayScene(for:on:)`.
  func peekOutline(for layout: Layout, on display: DisplayID) -> CGRect? {
    guard var session = peeking, session.display == display, let tree = workspaces[display]?.tree else { return nil }
    // A layout after a window closed comes before the next tick.
    session.peek.spacesChanged(root: tree.root, exists: tree.contains)
    peeking = session
    return session.peek.shownOutline.flatMap { Peek.frame(of: $0, in: layout, tree: tree) }
  }

  /// Draws or removes the outline, and asks for or gives back the temporary shortcuts, if either changed.
  private func showPeek() {
    guard var session = peeking else { return }
    let outline = session.peek.shownOutline
    let (keysChanged, outlineChanged) = (session.peek.takesKeys != session.tookKeys, outline != session.shownOutline)
    var wanted = session.temporary
    if keysChanged {
      wanted =
        session.peek.takesKeys
        ? KeyBindings.whilePeeking(session.chord, besides: KeyBindings.effective(settings: settings).bindings) : []
    }
    let asks = wanted != session.temporary
    session.tookKeys = session.peek.takesKeys
    session.temporary = wanted
    session.shownOutline = outline
    peeking = session
    if asks { onTemporaryShortcuts?(wanted) }
    if outlineChanged, isRunning, let layout = layouts[session.display] {
      overlays.update(display: session.display, scene: overlayScene(for: layout, on: session.display))
    }
  }
}
