#if os(macOS)
  import CoreGraphics
  import Foundation
  import Testing
  import os

  @testable import ArborKit

  /// The thread event taps run on (board item B3): callbacks there must never
  /// wait on the main actor, so the thread is its own, with its own run loop.
  @Suite struct EventTapThreadTests {
    @Test func blocksRunOnTheTapThreadAndReturnTheirResult() {
      let thread = EventTapThread.shared
      #expect(!thread.isCurrent)
      #expect(thread.sync { Thread.current.name } == EventTapThread.name)
      #expect(thread.sync { thread.isCurrent })
      #expect(thread.sync { 6 * 7 } == 42)
      #expect(!Thread.isMainThread || thread.sync { !Thread.isMainThread })
    }

    @Test func aNestedSyncRunsInPlaceInsteadOfDeadlocking() {
      let thread = EventTapThread.shared
      let name = thread.sync { thread.sync { Thread.current.name } }
      #expect(name == EventTapThread.name)
    }

    @Test func syncLetsGoOfTheClosureBeforeTheCallerGoesOn() {
      // It used to trap now and then, "closure argument was escaped in withoutActuallyEscaping block", in
      // debug and release builds alike: whenever the caller was quicker to go on than the run loop was to
      // release its block. The app calls `sync` each time a tap is installed, removed or paused.
      let thread = EventTapThread.shared
      var sum = 0
      for number in 1...100_000 {
        let captured = [number]  // so that the closure has a context to be let go of
        sum &+= thread.sync { captured[0] }
      }
      #expect(sum == 5_000_050_000)
    }

    @Test func asyncBlocksRunOnTheTapThreadAfterTheCurrentOne() {
      let thread = EventTapThread.shared
      let done = DispatchSemaphore(value: 0)
      let order = OSAllocatedUnfairLock(initialState: [String]())
      thread.sync {
        thread.async {
          order.withLock { $0.append("later, on \(Thread.current.name ?? "?")") }
          done.signal()
        }
        order.withLock { $0.append("now") }
      }
      #expect(done.wait(timeout: .now() + 2) == .success)
      #expect(order.withLock { $0 } == ["now", "later, on \(EventTapThread.name)"])
    }

    @Test func theThreadServesPointerEventsAtInteractivePriority() {
      #expect(EventTapThread.shared.sync { Thread.current.qualityOfService } == .userInteractive)
    }

    @Test func aTapThatIsNeverStartedIsNotInstalled() {
      let tap = EventTap(name: "test", mask: 1 << CGEventType.leftMouseUp.rawValue) { _, _ in false }
      #expect(!tap.isInstalled)
      tap.stop()  // harmless when nothing was installed
      #expect(!tap.isInstalled)
    }

    @Test func aTapThatIsNotInstalledCannotBeResumed() {
      // `RectangleFramer` lets a press through when this says there is nothing to follow it with.
      let tap = EventTap(name: "test", mask: 1 << CGEventType.leftMouseUp.rawValue) { _, _ in false }
      #expect(!tap.resume())
      tap.pause()
      EventTapThread.shared.sync { tap.reviveIfSwitchedOff() }  // where the clock does it
      #expect(!tap.isInstalled)
    }
  }
#endif
