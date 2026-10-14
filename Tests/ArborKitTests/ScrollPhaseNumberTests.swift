import ArborCore
import Testing

#if os(macOS)
  import CoreGraphics

  /// `ScrollClaim` reads the phases of scroll events as plain numbers, so that it builds and is tested
  /// everywhere. This checks the numbers against CoreGraphics' own.
  @Suite struct ScrollPhaseNumberTests {
    @Test func phaseNumbersMatchCoreGraphics() {
      #expect(ScrollClaim.Phase(scrollPhase: Int64(CGScrollPhase.began.rawValue)) == .began)
      #expect(ScrollClaim.Phase(scrollPhase: Int64(CGScrollPhase.changed.rawValue)) == .changed)
      #expect(ScrollClaim.Phase(scrollPhase: Int64(CGScrollPhase.ended.rawValue)) == .ended)
      #expect(ScrollClaim.Phase(scrollPhase: Int64(CGScrollPhase.cancelled.rawValue)) == .cancelled)
      #expect(ScrollClaim.Phase(scrollPhase: Int64(CGScrollPhase.mayBegin.rawValue)) == .mayBegin)
      #expect(ScrollClaim.Momentum(momentumPhase: Int64(CGMomentumScrollPhase.none.rawValue)) == .none)
      #expect(ScrollClaim.Momentum(momentumPhase: Int64(CGMomentumScrollPhase.begin.rawValue)) == .began)
      #expect(ScrollClaim.Momentum(momentumPhase: Int64(CGMomentumScrollPhase.end.rawValue)) == .ended)
    }
  }
#else
  @Suite struct ScrollPhaseNumberTests {
    @Test(.disabled("CoreGraphics' scroll phases exist only on macOS")) func phaseNumbersMatchCoreGraphics() {}
  }
#endif
