import ArborCore
import CoreGraphics
import Foundation

/// **What a start finds counts as left there**: a frame a person gives a window while Arbor is paused, or not running, is its own from
/// then on (collab/QUESTIONS.md: Q16, Q20, Q21, and the product owner's note of 2026-10-15 on F48 and rule 5).
///
/// What Arbor remembers of a floating window is one frame for each display it has floated on: the ones connected, and the ones that were
/// away when Arbor stopped and may be back (`restoreDormantWorkspace`). All of them are older than whatever happened while Arbor was not
/// looking: its person moved or resized the window, took it to another display, or macOS did when the displays changed. Followed, the
/// frame of a display that is back made the window jump at the start; the one of a display that had stayed made it jump later, when the
/// Desktop next came back into view, and held a window kept in view to a size it no longer had. So there are two rules.
///
/// **A display that is back fetches no floating window that is in view**, whoever ended the last run. It floats on the display it is on.
///
/// **A floating window that somebody has touched since Arbor let go of it has the frame it is found at for its own.** Where a window is
/// found does not say who put it there. It may be as Arbor had it, squeezed onto a narrow Desktop say: after an accident, without the
/// permission, or because its app did not answer, or did not obey, when Arbor let go. Taken for the person's doing, that would be the
/// window's own size for good (rule 5). So a quit and a pause write down where they left each window (`leftAt`), and nothing else does.
/// Found there, nobody has touched it, and what is remembered stands. Found elsewhere, somebody has. Nothing written: nobody can tell,
/// and what is remembered stands.
///
/// **So has a docked one**, for the frame it goes back to when Arbor next lets go of it or it floats again
/// (Controller+UndockedFrames.swift). It is docked again all the same: a start brings back what was docked, one move each (Q16).
extension Controller {
  /// Whether `window` is where this start found it, and that is a place somebody may have chosen. Never true outside a start.
  func countsAsLeftWhereItWasFound(_ window: WindowID) -> Bool {
    guard let found = foundAtThisStart[window] else { return false }
    // This start has had a reason to fetch it (`adopt`), so where it is now is nobody's choice.
    return windows[window]?.frame == found
      // Nor is a corner, where a run that did not quit left it, or one that could not bring it back. Beside another display it is no
      // sliver: that one shows the window's whole title bar.
      && !isOutOfView(found) && !isInAParkingCorner(window)
      // The whole display is not its frame. macOS gives it its own again when it leaves full screen.
      && windows[window]?.isFullScreen != true
  }

  /// A display that is back fetches no floating window that is in view. `reconcile()` has it already, floating where it is. Called
  /// before the arrangement of `id` comes back.
  func forgetWhatFloatsInView(inTheArrangementRememberedFor id: DisplayID) {
    for window in (dormant[id]?.workspace.floating ?? [:]).keys.sorted() where countsAsLeftWhereItWasFound(window) {
      dormant[id]!.workspace.floating[window] = nil
    }
  }

  /// The size each window had for its own when Arbor stopped: as remembered on the display it floated or was docked on then, or, if that had
  /// gone, with the display that went last. (What an earlier display remembers of it is older.) A number is trusted as in `reconcile()`, an
  /// arrangement as in `resumeDormantWorkspaces`.
  func ownSizesWhenArborStopped(_ saved: PersistedState?, hints: [WindowID: WindowHint]) -> [WindowID: CGSize] {
    guard let saved else { return [:] }
    let now = now()
    let oldestFirst = saved.dormant.filter { abs(now.timeIntervalSince($0.value.since)) <= Self.dormantLifetime }
      .sorted { ($0.value.since, $0.key) < ($1.value.since, $1.key) }.map(\.value.workspace)
    var sizes: [WindowID: CGSize] = [:]
    for workspace in oldestFirst + saved.workspaces.sorted(by: { $0.key < $1.key }).map(\.value) {
      for window in workspace.allWindows where hints[window]?.bundleID == windows[window]?.bundleID {
        // Nothing, if it was docked and nobody knows where it floated before: what is older says nothing of it either.
        sizes[window] = (workspace.floating[window] ?? workspace.undockedFrame(of: window))?.size
      }
    }
    return sizes
  }

  /// Once the arrangements are back, of the connected displays and of those that returned, and before anything is laid out.
  /// Moves nothing: it corrects what is remembered of the floating windows. `leftAt`: where Arbor left each when it let go, if it did.
  /// `couldHaveStayed`: the windows that floated then on a display that is still there.
  func takeFloatingWindowsAsFound(leftAt: [WindowID: CGRect], ownSizes: [WindowID: CGSize], couldHaveStayed: Set<WindowID> = []) {
    for id in workspaces.keys.sorted() {
      for (window, remembered) in workspaces[id]!.floating.sorted(by: { $0.key < $1.key })
      where countsAsLeftWhereItWasFound(window) {
        guard let found = foundAtThisStart[window] else { continue }
        let touched = leftAt[window].map { !found.approximatelyEquals($0, tolerance: 1) } ?? false
        // A hand Arbor did not see counts as a hand: no display that is away fetches the window when it comes back. Only where it could
        // have stayed: if the display it was on when Arbor let go has gone, macOS had to move it, and where it is found says nothing.
        if touched, couldHaveStayed.contains(window) { aHandHasPlaced(window) }
        let home = displayID(at: found.center) ?? id
        // Taken in afresh, because the display it floated on is not there: then where it is found is all that is remembered here.
        let isNewHere = remembered == found && ownSizes[window].map { $0 != found.size } == true
        guard let visible = display(home)?.visibleFrame, workspaces[home] != nil,
          home != id || isNewHere || (touched && found != remembered)
        else { continue }
        // A move is not a resize: in the size Arbor left it in, it keeps its own to go back to. Where nobody can tell who gave it its size
        // (squeezed, or in the shape of a slot that the file, half a second behind, knows nothing of), the one remembered stands.
        let own =
          leftAt[window].map { frameToRemember(of: window, movedFrom: $0, to: found, ownSize: ownSizes[window]) }
          ?? CGRect(origin: found.origin, size: ownSizes[window] ?? remembered.size).fitted(into: visible)
        let role = workspaces[id]!.role(of: window)
        if home != id { workspaces[id]!.floating[window] = nil }
        workspaces[home]?.floating[window] = own
        if home != id {
          workspaces[home]?.setRole(role, of: window)
          // The view that comes back on that display knows nothing of it. It is not swept away for having been brought there. (What is kept in
          // view stays anyway, and what `summon` sent away goes: neither is anybody's guest.)
          if role == nil { receiveWhatOpenedUnseen(window) }
        }
        // Left there by somebody, it may go on hanging over an edge of its display.
        if touched { noteWhereItsUserLeftIt(window) }
        Log.info("window \(window) is taken as it was found")
      }
    }
  }

  /// After `takeFloatingWindowsAsFound`, and like it: moves nothing, and corrects what is remembered of the docked windows.
  /// `then`: the arrangements as they were when Arbor let go.
  func takeDockedWindowsAsFound(leftAt: [WindowID: CGRect], then: [DisplayID: Workspace]) {
    for id in workspaces.keys.sorted() {
      var frames: [WindowID: CGRect] = [:]
      // Docked then under the number it has now: numbers start again after a reboot, and where another window of that number was left says nothing.
      for window in workspaces[id]!.tree.allWindows.sorted() where then[id]?.isDocked(window) == true && countsAsLeftWhereItWasFound(window) {
        guard let found = foundAtThisStart[window], let left = leftAt[window], !found.approximatelyEquals(left, tolerance: 1)
        else { continue }
        // A move is not a resize. Arbor leaves a window in another size than its own where its app did not answer, or did not obey: in the
        // shape of its slot, say. Pushed aside like that, it keeps its own to go back to, from where it is now.
        let own = workspaces[id]!.undockedFrame(of: window)?.size
        let isMovedOnly = abs(found.width - left.width) <= 1 && abs(found.height - left.height) <= 1
        frames[window] = isMovedOnly ? frame(ofSize: own ?? found.size, from: found) : found
        Log.info("docked window \(window) is taken as it was found")
      }
      workspaces[id]!.rememberUndockedFrames(ofArrivals: frames)
      frames.keys.forEach(forgetFitUnlessItStillHolds)
    }
  }

  /// Whether the displays are the ones Arbor let go on. macOS fits windows onto what there is when a display goes or changes its resolution, and puts
  /// them back on one that returns as they were there, in the shape of their slots: with other displays, nobody can tell whose doing a frame
  /// is. The file says which there were. `shapes`: what they were like, if it was this process that let go.
  func areTheDisplaysArborLeft(_ saved: PersistedState?, shapes: [DisplayID: CGRect]) -> Bool {
    let now = Dictionary(displays.map { ($0.id, $0.frame) }) { first, _ in first }
    return Set((saved?.workspaces ?? [:]).keys) == Set(now.keys) && (shapes.isEmpty || shapes == now)
  }

  /// What one start found, and where Arbor had left the windows before it, is nothing a later start may go by.
  func foundAtAStartViolations(_ problems: inout [InvariantViolation]) {
    if !foundAtThisStart.isEmpty {
      problems.append(.init("found-at-a-start", "what the start found is still noted for \(foundAtThisStart.keys.sorted())"))
    }
    if leftAt != nil { problems.append(.init("found-at-a-start", "Arbor runs, and still says where it left the windows")) }
  }
}
