// selftest.py: lines that end in "wrong" must be reported, the others must not. Never shipped, never run.
// A test for the Mac alone, which Linux's compiler skips and a Mac's meets an hour later.
#if os(macOS)
  import AppKit
  import Testing

  @testable import ArborKit

  @Suite @MainActor struct ProbeMacOnlyTests {
    @Test func drawsOffScreen() throws {
      let picture = try #require(
        NSBitmapImageRep(
          bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 4, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
          colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: picture)
      NSColor.red.setFill()
      NSRect(x: 0, y: 0, width: 4, height: 4).fill()
      NSGraphicsContext.restoreGraphicsState()
      #expect(picture.colorAt(x: 1, y: 1)?.redComponent == 1)
      #expect(picture.retagging(with: .sRGB) != nil)
      #expect(picture.colorAt(x: 1, y: 1)?.redComponnent == 1)  // wrong
      let view = NSView(frame: .zero)
      #expect(!view.isHidden)
      #expect(view.isHiden)  // wrong
      _ = NSView(frme: .zero)  // wrong
    }

    // Geometry can be hashed only from macOS 15, and Arbor runs on 14 (prepare.py's check).
    @Test func geometryIsNotHashable() {
      let frames: [CGRect] = [.zero]
      #expect(frames.count == 1)
      let distinct = Set<CGRect>(frames)  // wrong
      let names: [CGPoint: String] = [:]  // wrong
      #expect(distinct.count == names.count + 1)
      // Where the type is not spelt out only the compiler knows (stubs/MacFoundation/HashedGeometry.swift). This is the form that cost a build.
      let unspelt = Set(frames.map { $0.insetBy(dx: 1, dy: 1) })  // wrong
      #expect(Set(frames) == unspelt)  // wrong
      let byOrigin = Dictionary(uniqueKeysWithValues: frames.map { ($0.origin, $0) })  // wrong
      let bySize = Dictionary(grouping: frames) { $0.size }  // wrong
      #expect(byOrigin.count == bySize.count)
      var hasher = Hasher()
      hasher.combine(frames[0])  // wrong
      hasher.combine(frames.count)
      #expect(Set(frames.map(\.width)).count == 1)
      #expect(Dictionary(grouping: frames) { $0.width }.count == 1)
    }
  }
#endif
