import ArborCore
import ArborKit
import CoreGraphics

/// "Keep in View makes room" (docs/features/F49-pin.md; collab/QUESTIONS.md, Q25). Worked out afresh from where the window system has the windows
/// kept in view, in the order they were pinned: what is left of the display is what the layout fills, and nothing the layout
/// places, in any view, lies under or over a window that has its strip.
extension ChaosRunner {
  func pinnedRoomViolations(_ problems: inout [InvariantViolation]) {
    // In the hand, the others wait until it is let go.
    // Nor is anybody moved in front of an audience for what its own app does to it.
    guard !system.mouseDown, controller.draggedWindow == nil, !controller.isHeld else { return }
    for (id, workspace) in controller.workspaces.sorted(by: { $0.key < $1.key }) where workspace.pinned != nil && !isDueForLayout(id) {
      guard let layout = controller.layouts[id], let display = controller.display(id) else { continue }
      // One in macOS's full screen keeps its room, at a frame that the window system no longer has.
      guard !workspace.pinnedWindows.contains(where: { system.windows[$0]?.snapshot.isFullScreen == true }) else { continue }
      let present = workspace.pinnedWindows.compactMap { system.windows[$0] }
        .filter { $0.snapshot.isPresent && controller.filter.manages($0.snapshot) }
      // One that is owed a move, or whose app does as it likes, is not where the layout had to take it to be.
      guard
        present.allSatisfy({
          cooperates($0) && !controller.parked.contains($0.snapshot.id) && !controller.windowsOwedAMove.contains($0.snapshot.id)
        })
      else { continue }
      Self.questionsAsked["pinned-room", default: 0] += present.count
      let kept = PinnedRoom.reserve(in: display.visibleFrame, for: present.map { (window: $0.snapshot.id, frame: $0.snapshot.frame) })
      if layout.frame != kept.room {
        problems.append(.init("pinned-room", "\(id) is laid out in \(layout.frame.brief); the windows kept in view leave \(kept.room.brief)"))
      }
      for fake in present where !kept.without.contains(fake.snapshot.id) {
        let (pin, own) = (fake.snapshot.id, fake.snapshot.frame)
        for (window, slot) in layout.windowFrames.sorted(by: { $0.key < $1.key }) where slot.overlaps(own) {
          problems.append(.init("pinned-room", "the slot of \(window), \(slot.brief), lies under \(pin), which is kept in view at \(own.brief)"))
        }
        for tile in layout.tiles where tile.frame.overlaps(own) {
          problems.append(.init("pinned-room", "the tile \(tile.node), \(tile.frame.brief), lies under \(pin), which is kept in view at \(own.brief)"))
        }
      }
    }
  }
}
