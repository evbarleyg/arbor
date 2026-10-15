import ArborCore
import CoreGraphics

/// Showing changes as motion (docs/features/F02-animated-transitions.md).
///
/// Real windows cannot be animated through the Accessibility API. They go straight to their final
/// frames, exactly as they do without animation, while the presenter covers the display with a
/// stage on which stand-ins travel from where the windows were to where they went. The controller
/// only describes that journey (`Transition`, planned by `TransitionPlanner`). Nothing it decides
/// depends on the stage, so frames, parking and focus are the same with any `animationDuration`.
extension Controller {
  /// Whether a relayout may be shown as motion. Every `relayout` call that must not be says so.
  enum Motion {
    /// A camera move or a deliberate change to the arrangement: a command, a drop, a window
    /// closing, minimizing or joining the tree. This is the default.
    case animated
    /// Applied at once: whatever follows the mouse live (seam drags), what macOS already shows in
    /// its own way (Space switches, display changes), settings, and starting up. Putting
    /// windows back (`RelayoutReason.enforce`) is always instant.
    case instant
  }

  /// A transition the presenter was given before the real windows moved.
  struct StagedTransition {
    var before: Keyframe
    var stack: [StackedWindow]
    var sent: Transition
  }

  /// Called by `relayout` before it moves anything: plans the way from what the display shows now
  /// to `layout` and hands it to the presenter, which has to cover the real windows first.
  /// Returns nil if the change is applied at once.
  func stageTransition(
    on displayID: DisplayID, to layout: Layout, reason: RelayoutReason, motion: Motion,
    puttingBack: [(window: WindowID, frame: CGRect)] = []
  ) -> StagedTransition? {
    guard reason != .enforce else { return nil }
    guard motion == .animated, settings.motionDuration > 0,
      // The user is holding a window. Its stand-in would stay behind while the window goes on.
      drag == nil, edgeResize == nil,
      let display = display(displayID), var before = keyframes[displayID],
      // The display changed shape since: the two layouts are not views of one plane.
      before.layout.frame == layout.frame
    else {
      // A stage still up from an earlier change would lift on something it did not lead to.
      overlays.finishAnimations()
      return nil
    }
    before.visible = framesInView(on: display)
    guard
      var transition = transition(
        on: display, from: before,
        visible: expectedFrames(on: display, layout: layout, reason: reason, puttingBack: puttingBack),
        layout: layout),
      transition.hasMotion
    else { return nil }
    // Asked for only now: most relayouts move nothing, and the window server takes a moment to answer.
    let stack = system.stackedWindows()
    // macOS is showing its desktop. The windows take their new frames unseen and come back to them; a stage would
    // put stand-ins on a desktop that somebody wanted bare, and lift on nothing.
    guard !isSweptAside(stack) else {
      overlays.finishAnimations()
      return nil
    }
    fit(&transition, to: stack)
    overlays.animate(transition)
    return StagedTransition(before: before, stack: stack, sent: transition)
  }

  /// Whether macOS has swept the windows aside to show its desktop, going by what the window server has just `listed`.
  private func isSweptAside(_ listed: [StackedWindow]) -> Bool {
    SweptAside.isSwept(
      believed: windows.filter(\.value.isPresent).mapValues(\.frame), listed: listed, displays: displays.map(\.frame))
  }

  /// Stacks the stand-ins like the real windows. `Transition.leaveOpen` joins in with the change that teaches
  /// the stage to draw holes: a hole it does not draw is a window that vanishes for as long as the motion lasts.
  ///
  /// Windows that stay in view (pinned, summoned) go in front whatever the stacking says. The stack is read before anything moves, and one of
  /// them that nothing covered yet may lie behind the window that is about to reach under it; Arbor raises the real one as soon as the move
  /// is over (`raisePinnedWindows`), and for the time of the motion its stand-in must not be buried either.
  private func fit(_ transition: inout Transition, to stack: [StackedWindow]) {
    let order = stack.map(\.id)
    transition.stack(frontToBack: order.filter(staysInView) + order.filter { !staysInView($0) })
  }

  /// A click during a motion ends it (T42): the user wants their windows now. The click itself goes
  /// through the stage to whatever is really under the pointer.
  public func pointerPressed() {
    guard isRunning else { return }
    overlays.finishAnimations()
    lookAfterPinnedWindowsAfterAPress()
  }

  /// Called by `relayout` once everything is in place: remembers what the display shows now, for
  /// the next transition to start from, and corrects the transition under way if it leads
  /// somewhere else. Apps have the last word on their windows' frames: one that refuses its slot
  /// becomes a tile, and a terminal rounds its size to whole characters.
  func settleTransition(_ staged: StagedTransition?, on displayID: DisplayID, layout: Layout) {
    guard let workspace = workspaces[displayID] else { return }
    keyframes[displayID] = Keyframe(
      tree: workspace.tree, layout: layout, present: presentWindowIDs(), visible: [:])
    guard let staged, let display = display(displayID),
      var actual = transition(on: display, from: staged.before, visible: framesInView(on: display), layout: layout)
    else { return }
    fit(&actual, to: staged.stack)
    if !actual.endsLike(staged.sent) { overlays.animate(actual) }
  }

  private func transition(
    on display: DisplaySnapshot, from before: Keyframe, visible: [WindowID: CGRect], layout: Layout
  ) -> Transition? {
    guard let workspace = workspaces[display.id] else { return nil }
    let after = Keyframe(tree: workspace.tree, layout: layout, present: presentWindowIDs(), visible: visible)
    var transition = TransitionPlanner.plan(
      display: display.id, frame: display.frame, from: before, to: after, options: options(for: display.id).layoutOptions,
      duration: settings.motionDuration)
    for index in transition.items.indices {
      guard let window = windows[transition.items[index].window] else { continue }
      transition.items[index].pid = window.pid
      transition.items[index].bundleID = window.bundleID
    }
    return transition
  }

  /// Where every window that shows as itself on `display` is right now, whether Arbor arranges
  /// it or not: the stage hides them all, so they all have to be drawn.
  func framesInView(on display: DisplaySnapshot) -> [WindowID: CGRect] {
    var frames: [WindowID: CGRect] = [:]
    for (id, window) in windows
    where window.isPresent && !parked.contains(id) && window.frame.overlaps(display.frame) {
      frames[id] = window.frame
    }
    return frames
  }

  /// What `framesInView` will say once `layout` has been applied, if every app does as it is told.
  private func expectedFrames(
    on display: DisplaySnapshot, layout: Layout, reason: RelayoutReason,
    puttingBack: [(window: WindowID, frame: CGRect)]
  ) -> [WindowID: CGRect] {
    var frames = framesInView(on: display)
    for (window, slot) in layout.windowFrames {
      guard let current = windows[window] else { continue }
      if isInPlace(current, at: slot) {
        frames[window] = current.frame
      } else if let misfit = misfits[window], misfit.slot == slot {
        // It has been asked to fill this slot before, and this is as close as its app let it come.
        frames[window] = misfit.frame
      } else if enforcement.givenUp.contains(window) {
        // Its app keeps moving it, and Arbor has stopped putting it back.
        continue
      } else {
        frames[window] = slot
      }
    }
    for window in layout.hiddenWindows { frames[window] = nil }
    for (window, move) in floatingMoves(on: display.id, layout: layout, reason: reason) {
      switch move {
      case .place(let frame, _):
        if let current = windows[window] { frames[window] = isInPlace(current, at: frame) ? current.frame : frame }
      case .park:
        frames[window] = nil
      case .fill(let desktop):
        frames[window] = frameWhenFilling(desktop, with: window, on: display)
      }
    }
    for (window, frame) in puttingBack {
      // As `putBack` and `framesInView` have it.
      guard let current = windows[window], current.isPresent, !current.isFullScreen else { continue }
      frames[window] = frame.overlaps(display.frame) ? frame : nil
    }
    return frames
  }
}
