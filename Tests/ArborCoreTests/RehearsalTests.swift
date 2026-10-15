import ArborCore
import CoreGraphics
import Testing

@Suite struct RehearsalTests {
  /// What is got ready is found again by what the motion asks for.
  @Test func anItemsAppIsWhatItsCostumeIsLookedUpBy() {
    let item = Transition.Item(window: WindowID(7), from: .zero, to: .zero, pid: 42, bundleID: "com.example.notes")
    #expect(item.app == Rehearsal.App(pid: 42, bundleID: "com.example.notes"))
    #expect(Transition.Item(window: WindowID(7), from: .zero, to: .zero).app == Rehearsal.App(pid: 0, bundleID: nil))
  }

  @Test func twoProcessesOfOneAppAreTwo() {
    let apps: Set = [Rehearsal.App(pid: 1, bundleID: "a"), Rehearsal.App(pid: 2, bundleID: "a"), Rehearsal.App(pid: 1, bundleID: "a")]
    #expect(apps.count == 2)
  }
}
