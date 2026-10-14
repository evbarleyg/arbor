import ArborCore
import CoreGraphics

/// Wraps any `WindowSystem` and forwards everything both ways, writing each call with its answer and each
/// event to the recorder while a trace is being recorded. Neither the system inside nor the
/// controller outside knows it is there.
///
/// **A new requirement of `WindowSystem` or `WindowSystemEvents` must be forwarded here**, with a `TraceLine` for
/// it, and answered in `TraceReplayer`. One with a default implementation would otherwise stop reaching
/// the real system without any error.
@MainActor
public final class RecordingWindowSystem: WindowSystem {
  public let inner: any WindowSystem
  public let recorder: TraceRecorder
  public weak var events: (any WindowSystemEvents)?

  /// The window being dragged or resized with the mouse, as it was last reported. Its moves come at a high
  /// frequency and may be thinned. Kept up to date only while recording.
  private var gesture: WindowSnapshot?

  public init(wrapping inner: any WindowSystem, recorder: TraceRecorder) {
    self.inner = inner
    self.recorder = recorder
    inner.events = self
  }

  public func start() {
    inner.start()
    if recorder.isRecording { recorder.record(.start) }
  }

  public func stop() {
    inner.stop()
    guard recorder.isRecording else { return }
    recorder.record(.stop)
    // Arbor is quitting, or has lost its permission: nothing more will come.
    recorder.end(reason: "Arbor stopped")
  }

  public func allWindows() -> [WindowSnapshot] {
    let windows = inner.allWindows()
    if recorder.isRecording { recorder.record(.allWindows(windows.map(recorder.window))) }
    return windows
  }

  public func displays() -> [DisplaySnapshot] {
    let displays = inner.displays()
    if recorder.isRecording { recorder.record(.displays(displays.map(recorder.display))) }
    return displays
  }

  public func setFrame(_ frame: CGRect, of window: WindowID) -> CGRect? {
    guard recorder.isRecording else { return inner.setFrame(frame, of: window) }
    let before = recorder.clock()
    let actual = inner.setFrame(frame, of: window)
    // Accessibility calls wait for the app. A slow one holds up everything Arbor does.
    let took = ((recorder.clock() - before) * 10_000).rounded() / 10_000
    recorder.record(.setFrame(window, frame, result: actual, took: took >= 0.001 ? took : nil))
    return actual
  }

  public func focus(_ window: WindowID) {
    if recorder.isRecording { recorder.record(.focus(window)) }
    inner.focus(window)
  }

  public func focusedWindow() -> WindowID? {
    let window = inner.focusedWindow()
    if recorder.isRecording { recorder.record(.focusedWindow(window)) }
    return window
  }

  public func cursorLocation() -> CGPoint {
    let point = inner.cursorLocation()
    if recorder.isRecording { recorder.record(.cursorLocation(point)) }
    return point
  }

  public func isMouseButtonDown() -> Bool {
    let down = inner.isMouseButtonDown()
    if recorder.isRecording { recorder.record(.isMouseButtonDown(down)) }
    return down
  }

  public func existingWindowIDs() -> Set<WindowID> {
    guard recorder.isRecording else { return inner.existingWindowIDs() }
    // In order, so that the same answer is the same line.
    return Set(recorder.read("existingWindowIDs") { inner.existingWindowIDs().sorted() })
  }

  /// How long the hands have been still and how many keys were pressed; never which.
  public func inputActivity() -> InputActivity {
    guard recorder.isRecording else { return inner.inputActivity() }
    return recorder.read("inputActivity") { TraceInputActivity(inner.inputActivity()) }.activity
  }

  public func isHolding(_ chord: KeyChord) -> Bool {
    recorder.read("isHolding", [chord.description]) { inner.isHolding(chord) }
  }

  /// How long ago; never what was clicked or which key. JSON has no infinity, the answer where nobody has touched anything.
  public func secondsSinceClickOrModifierKey() -> Double {
    guard recorder.isRecording else { return inner.secondsSinceClickOrModifierKey() }
    return recorder.read("secondsSinceClickOrModifierKey") {
      Optional(inner.secondsSinceClickOrModifierKey()).flatMap { $0.isFinite ? $0 : nil }
    } ?? .infinity
  }

  public func leaveStrayDialogs(_ leave: Bool, exceptOfApp inUse: String?) {
    recorder.call("leaveStrayDialogs", [leave, inUse]) { inner.leaveStrayDialogs(leave, exceptOfApp: inUse) }
  }
  public func bringInStrayDialogs(ofApp bundleID: String?) {
    recorder.call("bringInStrayDialogs", [bundleID]) { inner.bringInStrayDialogs(ofApp: bundleID) }
  }
  public func strayDialogsWaiting() -> Int { recorder.read("strayDialogsWaiting") { inner.strayDialogsWaiting() } }
  public func macTitleBarAction() -> MacTitleBarAction { recorder.read("macTitleBarAction") { inner.macTitleBarAction() } }

  public func raise(_ window: WindowID) { recorder.call("raise", [window]) { inner.raise(window) } }
  public func windowsFrontToBack() -> [WindowID] { recorder.read("windowsFrontToBack") { inner.windowsFrontToBack() } }
  public func stackedWindows() -> [StackedWindow] { recorder.read("stackedWindows") { inner.stackedWindows() } }
  public func modifierKeysDown() -> KeyChord.Modifiers { recorder.read("modifierKeysDown") { inner.modifierKeysDown() } }
  public func macTiling() -> MacTiling { recorder.read("macTiling") { inner.macTiling() } }
  public func openApplication(_ app: String) -> Bool {
    recorder.call("openApplication", [app], returning: { inner.openApplication(app) })
  }
  public func launchApp(_ name: String) -> Bool {
    recorder.call("launchApp", [name], returning: { inner.launchApp(name) })
  }

  public func setMinimized(_ window: WindowID, _ minimized: Bool) {
    recorder.call("setMinimized", [window, minimized]) { inner.setMinimized(window, minimized) }
  }

  public func unhideApp(pid: Int32) { recorder.call("unhideApp", [pid]) { inner.unhideApp(pid: pid) } }

  /// A hint: it changes what the `setFrame` calls that follow cost, never what they return, so it is no line a replay has
  /// to find again. But the waiting moves here, and a trace should say where the time went.
  public func moveTogether(_ frames: [(window: WindowID, frame: CGRect)]) {
    guard recorder.isRecording, !frames.isEmpty else { return inner.moveTogether(frames) }
    let before = recorder.clock()
    inner.moveTogether(frames)
    let took = ((recorder.clock() - before) * 10_000).rounded() / 10_000
    recorder.record(.note("moveTogether, \(frames.count) windows, took \(took) s"))
  }

  /// In a trace it is a `setFrame` like any other: what was asked of the window, and what came of it.
  public func setFrameOnce(_ frame: CGRect, of window: WindowID, pid: Int32) -> CGRect? {
    let actual = inner.setFrameOnce(frame, of: window, pid: pid)
    if recorder.isRecording { recorder.record(.setFrame(window, frame, result: actual, took: nil)) }
    return actual
  }
}

extension RecordingWindowSystem: WindowSystemEvents {
  public func windowAppeared(_ window: WindowSnapshot) {
    guard recorder.isRecording else {
      events?.windowAppeared(window)
      return
    }
    recorder.stimulus(.appeared(recorder.window(window))) { events?.windowAppeared(window) }
  }

  public func windowDestroyed(_ id: WindowID) {
    guard recorder.isRecording else {
      events?.windowDestroyed(id)
      return
    }
    if gesture?.id == id { gesture = nil }
    recorder.stimulus(.destroyed(id)) { events?.windowDestroyed(id) }
  }

  public func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {
    guard recorder.isRecording else {
      events?.windowChanged(window, userInitiated: userInitiated)
      return
    }
    // Only a change of nothing but the frame, during a gesture, is one of many.
    var thinKey: String?
    if var previous = gesture, previous.id == window.id {
      previous.frame = window.frame
      if previous == window, userInitiated { thinKey = "changed" }
      gesture = window
    }
    recorder.stimulus(.changed(recorder.window(window), user: userInitiated), thinKey: thinKey) {
      events?.windowChanged(window, userInitiated: userInitiated)
    }
  }

  public func windowFocused(_ id: WindowID) {
    guard recorder.isRecording else {
      events?.windowFocused(id)
      return
    }
    recorder.stimulus(.focused(id)) { events?.windowFocused(id) }
  }

  public func dragBegan(_ id: WindowID, at point: CGPoint) {
    guard recorder.isRecording else {
      events?.dragBegan(id, at: point)
      return
    }
    beginGesture(id)
    recorder.stimulus(.dragBegan(id, at: point)) { events?.dragBegan(id, at: point) }
  }

  public func dragMoved(_ id: WindowID, to point: CGPoint) {
    guard recorder.isRecording else {
      events?.dragMoved(id, to: point)
      return
    }
    recorder.stimulus(.dragMoved(id, to: point), thinKey: "dragMoved") { events?.dragMoved(id, to: point) }
  }

  public func dragEnded(_ id: WindowID, at point: CGPoint) {
    guard recorder.isRecording else {
      events?.dragEnded(id, at: point)
      return
    }
    gesture = nil
    recorder.stimulus(.dragEnded(id, at: point)) { events?.dragEnded(id, at: point) }
  }

  public func displaysChanged() {
    guard recorder.isRecording else {
      events?.displaysChanged()
      return
    }
    // The event says only that something changed. The list makes the line readable by itself.
    recorder.stimulus(.displaysChanged(inner.displays().map(recorder.display))) { events?.displaysChanged() }
  }

  public func resizeBegan(_ id: WindowID) {
    guard recorder.isRecording else {
      events?.resizeBegan(id)
      return
    }
    beginGesture(id)
    recorder.stimulus(.resizeBegan(id)) { events?.resizeBegan(id) }
  }

  public func resizeEnded(_ id: WindowID) {
    guard recorder.isRecording else {
      events?.resizeEnded(id)
      return
    }
    gesture = nil
    recorder.stimulus(.resizeEnded(id)) { events?.resizeEnded(id) }
  }

  public func keyboardFocusMoved() {
    guard recorder.isRecording else {
      events?.keyboardFocusMoved()
      return
    }
    recorder.stimulus(.keyboardFocusMoved) { events?.keyboardFocusMoved() }
  }

  public func dragCancelled(_ id: WindowID) {
    if recorder.isRecording { gesture = nil }
    recorder.event("dragCancelled", [id]) { events?.dragCancelled(id) }
  }

  /// With no arguments: nobody knows which.
  public func pointerPressed() { recorder.event("pointerPressed") { events?.pointerPressed() } }

  public func applicationActivated(_ app: FrontmostApp?) {
    recorder.event("applicationActivated", app.map { [$0.bundleID, $0.name] } ?? []) { events?.applicationActivated(app) }
  }

  public func accessibilityWasRefused() { recorder.event("accessibilityWasRefused") { events?.accessibilityWasRefused() } }

  public func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {
    recorder.event("windowReplaced", [old, recorder.window(window)]) { events?.windowReplaced(old, by: window) }
  }

  public func windowFound(_ window: WindowSnapshot) {
    recorder.event("windowFound", [recorder.window(window)]) { events?.windowFound(window) }
  }

  public func doubleClickReached(_ window: WindowID) {
    recorder.event("doubleClickReached", [window]) { events?.doubleClickReached(window) }
  }

  /// Not a line of its own: all it does is run a command, which is recorded as any command is. That is also what a trace
  /// from the app holds, where the event tap runs the command and only tests and arbor-sim report this.
  @discardableResult
  public func doubleClicked(at point: CGPoint) -> Bool { events?.doubleClicked(at: point) ?? false }

  private func beginGesture(_ id: WindowID) {
    gesture = inner.allWindows().first { $0.id == id }
  }
}
