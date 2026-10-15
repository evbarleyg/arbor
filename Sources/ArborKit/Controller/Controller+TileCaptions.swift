import ArborCore
import CoreGraphics

/// Tiles say which window they are (collab/QUESTIONS.md, Q15): a window's tile is captioned with its title, so that two
/// windows of one app can be told apart without a click.
///
/// **A title is drawn and nothing else.** It goes from the window's snapshot into the `TileModel` and from there to the
/// screen. Scenes are not recorded (`RecordingOverlays`), `state` and `watch` take their tiles from the layout, which knows
/// numbers only, and nothing here logs. `TileCaptionTests` and scripts/privacy-smoke.sh send a word through all of it and
/// look for it everywhere.
extension Controller {
  struct TileCaptions {
    /// No title is shown although nothing is held: a hold has ended by itself, perhaps with the screen still shared.
    var wait = false
    /// Nor now: Arbor is starting, and does not know yet whether a call is on.
    var isStarting = false
    /// The titles each display's tiles were last sent with.
    var sent: [DisplayID: [NodeID: String]] = [:]
    /// Titles have changed and the tiles will be drawn again in a moment.
    var isOwed = false
  }

  /// How long a new title waits to be drawn, for others to come along: a terminal has a new one at every command, and some
  /// apps count in theirs.
  static let tileCaptionPause = 0.25

  /// The title to call `tile` by. Nil for anything but a window's tile, for one that has a name, which comes first, for a
  /// window without a title, and wherever a title is somebody's business: while the view is held, at either strength.
  func title(for tile: Tile, on display: DisplayID) -> String? {
    guard tile.kind == .window, !isHeld, !tileCaptions.wait, !tileCaptions.isStarting, spaceName(of: tile.node, on: display) == nil,
      // Of a tab group, the tab in front: that is the window a click shows.
      let window = frontWindow(of: tile, on: display), let title = windows[window]?.title,
      title.contains(where: { !$0.isWhitespace })
    else { return nil }
    return title
  }

  private func frontWindow(of tile: Tile, on display: DisplayID) -> WindowID? {
    if case .stack(let tabs, let active)? = workspaces[display]?.tree[tile.node]?.kind, tabs.indices.contains(active),
      tile.windows.contains(tabs[active])
    {
      return tabs[active]
    }
    return tile.windows.first
  }

  private func titles(of layout: Layout, on display: DisplayID) -> [NodeID: String] {
    var titles: [NodeID: String] = [:]
    for tile in layout.tiles { titles[tile.node] = title(for: tile, on: display) }
    return titles
  }

  /// Called while a scene is put together.
  func noteTitlesSent(with layout: Layout, on display: DisplayID) {
    tileCaptions.sent[display] = titles(of: layout, on: display)
  }

  /// What `display` shows: during a drag with live reflow a trial, not the arrangement at rest.
  private func layoutShown(on display: DisplayID) -> Layout? { drag?.reflow.trials[display] ?? layouts[display] }

  /// A window has another title. If that is what a tile is called, the tile is drawn again in a moment; no window moves.
  func tileFollowsItsTitle(_ window: WindowID) {
    guard isRunning, !tileCaptions.isOwed, let display = workspaceID(containing: window),
      let layout = layoutShown(on: display), titles(of: layout, on: display) != tileCaptions.sent[display] ?? [:]
    else { return }
    tileCaptions.isOwed = true
    scheduler.schedule("tile-captions", after: Self.tileCaptionPause) { [weak self] in self?.drawTileCaptions() }
  }

  /// Sends every display whose tiles are called something else by now its scene again, at once.
  func drawTileCaptions() {
    scheduler.cancel("tile-captions")
    tileCaptions.isOwed = false
    guard isRunning else { return }
    // A title is no layout: the line round the focused window stays as it is. Worked out anew it would ask the app in
    // front a question, and go away if a mouse button happened to be down.
    let wasWorkedOut = focusRing.isWorkedOut
    focusRing.isWorkedOut = true
    defer { focusRing.isWorkedOut = wasWorkedOut }
    for display in layouts.keys.sorted() {
      guard let layout = layoutShown(on: display), titles(of: layout, on: display) != tileCaptions.sent[display] ?? [:]
      else { continue }
      overlays.update(display: display, scene: overlayScene(for: layout, on: display))
    }
  }

  /// A hold has begun: the titles go, now. They stay away when it ends, because the end can come by itself, when the
  /// time is up or the call is over, with the screen still shared.
  func tileCaptionsAreHeld() {
    tileCaptions.wait = true
    drawTileCaptions()
  }

  /// Arbor has started, and holds still if a call is on.
  func tileCaptionsKnowWhetherACallIsOn() {
    tileCaptions.isStarting = false
    drawTileCaptions()
  }

  /// Somebody has let go of the hold, or moves the view after it: like what the hold kept out of view
  /// (`holdLetsInWhatWaited`), the titles come back with that.
  func tileCaptionsMayShowAgain() {
    guard tileCaptions.wait, !isHeld else { return }
    tileCaptions.wait = false
    drawTileCaptions()
  }
}
