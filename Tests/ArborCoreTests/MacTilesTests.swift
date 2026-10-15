import ArborCore
import CoreGraphics
import Testing

/// Which frames are macOS's own tiles (`MacTiling.isTile`).
@Suite struct MacTilesTests {
  let visible = CGRect(x: 0, y: 31, width: 1024, height: 677)

  @Test func whatAMacWasSeenToDo() {
    #expect(MacTiling.isTile(CGRect(x: 0, y: 31, width: 513, height: 677), of: visible), "Move & Resize ▸ Left")
    #expect(MacTiling.isTile(CGRect(x: 0, y: 31, width: 513, height: 679), of: CGRect(x: 0, y: 31, width: 1024, height: 679)), "Terminal")
    #expect(!MacTiling.isTile(CGRect(x: 0, y: 31, width: 1024, height: 677), of: visible), "Fill, and Zoom")
    #expect(!MacTiling.isTile(CGRect(x: 79, y: 56, width: 603, height: 505), of: visible), "the way back from a zoom")
  }

  @Test func halvesQuartersAndThirds() {
    let (w, h) = (visible.width, visible.height)
    for x in [0, w / 2] {
      #expect(MacTiling.isTile(CGRect(x: x, y: 31, width: w / 2, height: h), of: visible), "a half at \(x)")
      for y in [31, 31 + h / 2] { #expect(MacTiling.isTile(CGRect(x: x, y: y, width: w / 2, height: h / 2), of: visible), "a quarter at \(x),\(y)") }
    }
    for y in [31, 31 + h / 2] { #expect(MacTiling.isTile(CGRect(x: 0, y: y, width: w, height: h / 2), of: visible), "a half at y \(y)") }
    for third in 0..<3 { #expect(MacTiling.isTile(CGRect(x: CGFloat(third) * w / 3, y: 31, width: w / 3, height: h), of: visible), "third \(third)") }
    #expect(!MacTiling.isTile(CGRect(x: 0, y: 31, width: w / 3, height: h / 3), of: visible), "macOS has no ninth")
    #expect(!MacTiling.isTile(CGRect(x: 0, y: 31, width: w / 3, height: h / 2), of: visible), "nor a sixth")
  }

  @Test func withMacOSsMargins() {
    let half = CGRect(x: 0, y: 31, width: 512, height: 677)
    #expect(MacTiling.isTile(half.insetBy(dx: 8, dy: 8), of: visible))
    #expect(MacTiling.isTile(CGRect(x: 8, y: 39, width: 500, height: 661), of: visible), "half a margin between two tiles")
    #expect(!MacTiling.isTile(half.insetBy(dx: 20, dy: 20), of: visible), "that is no margin")
  }

  @Test func whatAnAppMakesOfItsOwnWindowIsNoTile() {
    #expect(!MacTiling.isTile(CGRect(x: 12, y: 43, width: 360, height: 653), of: visible), "a terminal whose font grew")
    #expect(!MacTiling.isTile(CGRect(x: 212, y: 131, width: 600, height: 400), of: visible), "centred")
    #expect(!MacTiling.isTile(CGRect(x: 0, y: 31, width: 513, height: 400), of: visible), "half as wide, and no tile's height")
    #expect(!MacTiling.isTile(CGRect(x: 100, y: 31, width: 512, height: 677), of: visible), "a half's size in no half's place")
    #expect(!MacTiling.isTile(.zero, of: visible))
    #expect(!MacTiling.isTile(CGRect(x: 0, y: 0, width: 10, height: 10), of: .zero))
  }

  /// A slot of Arbor's, a third wide less its gap of twelve points, cannot be told from a third with margins. So whoever asks this has asked
  /// first whether the window is in its slot.
  @Test func aSlotOfArborsCanLookLikeATileWithMargins() {
    #expect(MacTiling.isTile(CGRect(x: 12, y: 43, width: 325, height: 653), of: visible))
  }

  @Test func asLargeAsTheScreen() {
    #expect(MacTiling.fillsTheScreen(visible, of: visible))
    #expect(MacTiling.fillsTheScreen(visible.insetBy(dx: 8, dy: 8), of: visible), "with macOS's margins")
    #expect(!MacTiling.fillsTheScreen(visible.insetBy(dx: 20, dy: 20), of: visible))
    #expect(!MacTiling.fillsTheScreen(CGRect(x: 0, y: 31, width: 513, height: 677), of: visible))
    #expect(!MacTiling.fillsTheScreen(visible, of: .zero))
  }

  @Test func onADisplayThatIsNotTheMainOne() {
    let side = CGRect(x: -1280, y: 200, width: 1280, height: 775)
    #expect(MacTiling.isTile(CGRect(x: -640, y: 200, width: 640, height: 775), of: side))
    #expect(!MacTiling.isTile(CGRect(x: 0, y: 31, width: 512, height: 677), of: side))
  }
}
