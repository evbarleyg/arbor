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
/// Docked windows are another matter: a start brings back what was docked, one move each (Q16).
extension Controller {
  /// Whether `window` is where this start found it, and that is a place somebody may have chosen. Never true outside a start.
  func countsAsLeftWhereItWasFound(_ window: WindowID) -> Bool {
    guard let found = foundAtThisStart[window] else { return false }
    // This start has had a reason to fetch it (`adopt`), so where it is now is nobody's choice.
    return windows[window]?.frame == found
      // Nor is a corner, where a run that did not quit left it, or one that could not bring it back.
      && !isOutOfView(found)
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
  func takeFloatingWindowsAsFound(leftAt: [WindowID: CGRect], ownSizes: [WindowID: CGSize]) {
    for id in workspaces.keys.sorted() {
      for (window, remembered) in workspaces[id]!.floating.sorted(by: { $0.key < $1.key })
      where countsAsLeftWhereItWasFound(window) {
        guard let found = foundAtThisStart[window] else { continue }
        let touched = leftAt[window].map { !found.approximatelyEquals($0, tolerance: 1) } ?? false
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

  /// What one start found, and where Arbor had left the windows before it, is nothing a later start may go by.
  func foundAtAStartViolations(_ problems: inout [InvariantViolation]) {
    if !foundAtThisStart.isEmpty {
      problems.append(.init("found-at-a-start", "what the start found is still noted for \(foundAtThisStart.keys.sorted())"))
    }
    if leftAt != nil { problems.append(.init("found-at-a-start", "Arbor runs, and still says where it left the windows")) }
  }
}
