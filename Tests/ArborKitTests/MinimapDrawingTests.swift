#if os(macOS)
  import AppKit
  import ArborCore
  import CoreGraphics
  import Foundation
  import Testing

  @testable import ArborKit

  /// A colour in sRGB, as it goes into a picture and comes out of it.
  private struct Paint {
    var red: Double
    var green: Double
    var blue: Double
    var alpha = 1.0

    var colour: NSColor { NSColor(srgbRed: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha)) }

    /// This paint laid over `other`, which is opaque, as thinly as `amount` says.
    func over(_ other: Paint, amount: Double) -> Paint {
      Paint(
        red: red * amount + other.red * (1 - amount), green: green * amount + other.green * (1 - amount),
        blue: blue * amount + other.blue * (1 - amount))
    }

    func isNear(_ other: Paint, within tolerance: Double = 0.04) -> Bool {
      abs(red - other.red) <= tolerance && abs(green - other.green) <= tolerance && abs(blue - other.blue) <= tolerance
        && abs(alpha - other.alpha) <= tolerance
    }
  }

  /// A bitmap to draw into as the minimap's view would be drawn, and to read back (after F15's `TileDrawingTests`). Nothing here
  /// touches the screen or reads from it, so the pictures it saves hold only what Arbor drew.
  @MainActor
  private final class Canvas {
    let size: CGSize
    let scale: CGFloat
    let bitmap: CGContext

    init(size: CGSize, scale: CGFloat = 2) throws {
      self.size = size
      self.scale = scale
      let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
      bitmap = try #require(
        CGContext(
          data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8,
          bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    }

    /// Runs `body` with the bitmap as the current context, in points, y growing downward from the top-left corner.
    func draw(isDark: Bool = false, _ body: () -> Void) {
      bitmap.saveGState()
      bitmap.scaleBy(x: scale, y: scale)
      bitmap.translateBy(x: 0, y: size.height)
      bitmap.scaleBy(x: 1, y: -1)
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: true)
      NSAppearance(named: isDark ? .darkAqua : .aqua)?.performAsCurrentDrawingAppearance { body() }
      NSGraphicsContext.restoreGraphicsState()
      bitmap.restoreGState()
    }

    /// The colour at a point, counted from the top-left corner in points. Clear outside the picture.
    func pixel(_ x: CGFloat, _ y: CGFloat) -> Paint {
      let column = Int(x * scale)
      let row = Int(y * scale)
      guard x >= 0, y >= 0, column < bitmap.width, row < bitmap.height,
        let bytes = bitmap.data?.assumingMemoryBound(to: UInt8.self)
      else { return Paint(red: 0, green: 0, blue: 0, alpha: 0) }
      // The first row in memory is the top one. Red, green, blue, alpha, the colours multiplied by alpha.
      let at = row * bitmap.bytesPerRow + column * 4
      let alpha = Double(bytes[at + 3])
      guard alpha > 0 else { return Paint(red: 0, green: 0, blue: 0, alpha: 0) }
      return Paint(
        red: Double(bytes[at]) / alpha, green: Double(bytes[at + 1]) / alpha, blue: Double(bytes[at + 2]) / alpha,
        alpha: alpha / 255)
    }

    func pixel(_ point: CGPoint) -> Paint { pixel(point.x, point.y) }

    /// How many of the pixels in `rect` satisfy `test`.
    func count(in rect: CGRect, where test: (Paint) -> Bool) -> Int {
      var found = 0
      let step = 1 / scale
      for y in stride(from: rect.minY + step / 2, to: rect.maxY, by: step) {
        for x in stride(from: rect.minX + step / 2, to: rect.maxX, by: step) where test(pixel(x, y)) { found += 1 }
      }
      return found
    }

    /// Into `.build/pictures/F26` of the checkout, for people to look at.
    func save(_ name: String) throws {
      var root = URL(fileURLWithPath: #filePath)
      for _ in 0..<3 { root.deleteLastPathComponent() }
      let folder = root.appendingPathComponent(".build/pictures/F26")
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let image = try #require(bitmap.makeImage())
      let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try data.write(to: folder.appendingPathComponent(name + ".png"))
    }
  }

  private let accent = Paint(red: 0.0, green: 0.48, blue: 1.0)
  /// One per app, by process id, far enough apart to tell which is which.
  private let apps = [
    Paint(red: 0.85, green: 0.25, blue: 0.20), Paint(red: 0.20, green: 0.60, blue: 0.30),
    Paint(red: 0.55, green: 0.30, blue: 0.75), Paint(red: 0.90, green: 0.60, blue: 0.10),
    Paint(red: 0.15, green: 0.55, blue: 0.70), Paint(red: 0.45, green: 0.45, blue: 0.50),
  ]
  private func paint(of item: MinimapModel.Item) -> Paint { apps[Int(item.pid) % apps.count] }
  /// What stands in for the blur behind the panel, which draws nothing off screen.
  private func backing(isDark: Bool) -> Paint {
    isDark ? Paint(red: 0.16, green: 0.16, blue: 0.17) : Paint(red: 0.93, green: 0.93, blue: 0.94)
  }
  private func ink(isDark: Bool) -> Paint {
    isDark ? Paint(red: 1, green: 1, blue: 1) : Paint(red: 0, green: 0, blue: 0)
  }

  /// What the minimap holds and where is tested without a screen on every platform (`MinimapTests`, `MinimapScenarioTests`). This checks that
  /// AppKit draws it as decided, the right way up and in the right colours, and leaves pictures to be looked at.
  @Suite @MainActor struct MinimapDrawingTests {
    func window(_ number: Int) -> WindowID { WindowID(UInt32(number)) }

    func model(
      _ tree: LayoutTree, camera: NodeID? = nil, caption: String? = nil, takesClicks: Bool = false,
      area: CGSize = CGSize(width: 1440, height: 875)
    ) throws -> MinimapModel {
      let map = try #require(Minimap.make(tree, camera: camera ?? tree.root, area: area, isPresent: { _ in true }))
      return MinimapModel(
        map, on: DisplayID("main"), in: CGRect(origin: .zero, size: area), caption: caption, takesClicks: takesClicks,
        app: { (pid: Int32($0.rawValue), bundleID: nil) })
    }

    /// [1 / 3 | Desktop | 2]
    func threeWindows() -> LayoutTree {
      var tree = LayoutTree()
      let left = tree.dock(window(1), beside: tree.desktop, edge: .left)
      tree.dock(window(2), beside: tree.desktop, edge: .right)
      tree.dock(window(3), beside: left, edge: .bottom)
      return tree
    }

    /// The panel as it would look, on a plain backing with the panel's corners.
    private func picture(_ model: MinimapModel, isDark: Bool = false, scale: CGFloat = 2) throws -> Canvas {
      let canvas = try Canvas(size: model.frame.size, scale: scale)
      canvas.draw(isDark: isDark) {
        backing(isDark: isDark).colour.setFill()
        let radius = PanelLook.Corner.panel
        NSBezierPath(roundedRect: CGRect(origin: .zero, size: model.frame.size), xRadius: radius, yRadius: radius).fill()
        MinimapDrawing.draw(model, accent: accent.colour, ink: ink(isDark: isDark).colour) { paint(of: $0).colour }
      }
      return canvas
    }

    // MARK: Checked

    @Test func everyWindowIsWhereTheModelPutsItInItsAppsColour() throws {
      let tree = threeWindows()
      for isDark in [false, true] {
        let model = try model(tree, camera: tree.leaf(containing: window(3)))
        let canvas = try picture(model, isDark: isDark)
        #expect(model.items.count == 3)
        for item in model.items {
          let expected =
            item.isInView
            ? accent.over(paint(of: item), amount: Double(MinimapDrawing.highlightFillAlpha))
            : paint(of: item).over(backing(isDark: isDark), amount: Double(MinimapDrawing.outOfViewAlpha))
          #expect(canvas.pixel(item.frame.center).isNear(expected), "\(item.window), dark: \(isDark)")
        }
        // Three colours in three places: upside down or mirrored, at least one would be another's.
        #expect(model.items[0].frame.maxY < model.items[1].frame.minY, "1 is above 3")
      }
    }

    @Test func theSpaceInViewIsFramedInTheAccentColourAroundItNotOnIt() throws {
      let tree = threeWindows()
      let model = try model(tree, camera: tree.leaf(containing: window(2)))
      let canvas = try picture(model)
      let view = model.highlight
      for point in [
        CGPoint(x: view.midX, y: view.minY - 2), CGPoint(x: view.midX, y: view.maxY + 2),
        CGPoint(x: view.minX - 2, y: view.midY), CGPoint(x: view.maxX + 2, y: view.midY),
      ] {
        #expect(canvas.pixel(point).isNear(accent), "\(point)")
      }
      #expect(!canvas.pixel(view.midX, view.minY + 3).isNear(accent), "the window's own colour shows inside")
      #expect(canvas.pixel(view.midX, view.minY - 5).isNear(backing(isDark: false)), "and nothing beyond the line")
    }

    /// Whatever its app's colour: one of the ground's own brightness was not there at all.
    @Test func aWindowOutOfViewHasALineRoundItAndEveryWindowAFullOneWithIncreaseContrast() throws {
      // One window framed: over the other two no tint of the view's lies.
      let tree = threeWindows()
      let model = try model(tree, camera: tree.leaf(containing: window(2)))
      let paper = backing(isDark: false)
      for strong in [false, true] {
        let canvas = try Canvas(size: model.frame.size, scale: 2)
        canvas.draw(isDark: false) {
          paper.colour.setFill()
          CGRect(origin: .zero, size: model.frame.size).fill()
          // Every window in the paper's own colour.
          MinimapDrawing.draw(model, accent: accent.colour, ink: ink(isDark: false).colour, increasesContrast: strong) { _ in
            paper.colour
          }
        }
        #expect(model.items.contains { $0.isInView } && model.items.contains { !$0.isInView })
        for item in model.items {
          let edge = canvas.pixel(item.frame.minX + 0.5, item.frame.midY)
          if !item.isInView || strong { #expect(!edge.isNear(paper, within: 0.2), "\(item.window), strong: \(strong)") }
          if !item.isInView, strong { #expect(edge.isNear(ink(isDark: false), within: 0.1), "\(item.window)") }
        }
      }
    }

    @Test func theDesktopIsAnOutline() throws {
      let tree = threeWindows()
      let model = try model(tree, camera: tree.leaf(containing: window(2)))
      let canvas = try picture(model)
      let desktop = try #require(model.desktop)
      let paper = backing(isDark: false)
      #expect(canvas.pixel(desktop.center).isNear(paper), "empty inside")
      #expect(!canvas.pixel(desktop.minX + 0.5, desktop.midY).isNear(paper), "a line at its edge")
      #expect(!canvas.pixel(desktop.midX, desktop.maxY - 0.5).isNear(paper))
    }

    @Test func theSpaceUnderThePointerIsOutlinedInInk() throws {
      let tree = threeWindows()
      let plain = try model(tree, camera: tree.leaf(containing: window(2)), takesClicks: true)
      let model = plain.pointing(at: plain.items[0].frame.center)
      let hover = try #require(model.hover)
      let spot = CGPoint(x: hover.midX, y: hover.minY - 0.5)
      let outlined = try picture(model).pixel(spot)
      let bare = try picture(plain).pixel(spot)
      #expect(outlined.isNear(ink(isDark: false), within: 0.15))
      #expect(!bare.isNear(ink(isDark: false), within: 0.15))
    }

    @Test func aLongCaptionStaysInItsLine() throws {
      let name = "The quarterly report, its appendices and everything else that has to be read before Friday"
      let model = try model(threeWindows(), caption: name)
      let canvas = try picture(model)
      try canvas.save("checked-long-caption")
      let paper = backing(isDark: false)
      let line = model.captionFrame
      // Beside the line, as far out as the panel's round corner leaves paper at that height.
      let corner = PanelLook.Corner.panel
      let depth = max(corner - min(model.frame.height - line.maxY + 4, line.minY + 6), 0)
      let cut = (corner - (corner * corner - depth * depth).squareRoot()).rounded(.up) + 1
      let left = CGRect(x: cut, y: line.minY + 6, width: line.minX - 1 - cut, height: line.height - 10)
      let right = CGRect(
        x: line.maxX + 1, y: line.minY + 6, width: model.frame.width - line.maxX - 1 - cut, height: line.height - 10)
      #expect(left.width >= 2 && right.width >= 2, "there is paper to look at: \(left), \(right)")
      let letters = canvas.count(in: line, where: { !$0.isNear(paper) })
      let spiltLeft = canvas.count(in: left, where: { !$0.isNear(paper) })
      let spiltRight = canvas.count(in: right, where: { !$0.isNear(paper) })
      #expect(letters > 100, "there are letters")
      #expect(spiltLeft == 0, "none to the left of the map")
      #expect(spiltRight == 0, "none to the right")
    }

    @Test func withoutACaptionNothingIsWritten() throws {
      let tree = threeWindows()
      let model = try model(tree, camera: tree.desktop)
      let canvas = try picture(model)
      let paper = backing(isDark: false)
      let margin = CGRect(x: 14, y: 1, width: model.frame.width - 28, height: 5)
      let marks = canvas.count(in: margin, where: { !$0.isNear(paper) })
      #expect(marks == 0)
    }

    // MARK: To be looked at

    /// `.build/pictures/F26/<arrangement>-<look>@<scale>.png`. Is everything legible at this size? Can what is in view be told from
    /// what is not? Does the frame sit well around small windows and around everything?
    @Test func picturesOfManyArrangements() throws {
      var one = LayoutTree()
      one.dock(window(1), beside: one.desktop, edge: .left)

      let twelve = LayoutTree.grid(of: (1...12).map(window))

      // Groups within groups: a column of two beside a row of three, over a wide window.
      var nested = LayoutTree()
      let first = nested.dock(window(1), beside: nested.desktop, edge: .left)
      nested.dock(window(2), beside: first, edge: .bottom)
      let third = nested.dock(window(3), beside: nested.desktop, edge: .right)
      let fourth = nested.dock(window(4), beside: third, edge: .right)
      nested.dock(window(5), beside: fourth, edge: .bottom)
      nested.dock(window(6), beside: third, edge: .bottom)

      var tabs = threeWindows()
      if let leaf = tabs.leaf(containing: window(2)) {
        tabs.addToStack(window(4), leaf: leaf)
        tabs.addToStack(window(5), leaf: leaf)
      }

      let three = threeWindows()
      let asked = try model(three, camera: three.leaf(containing: window(1)), caption: "View 3", takesClicks: true)
      let models: [(String, MinimapModel)] = [
        ("one-window", try model(one, camera: one.leaf(containing: window(1)))),
        ("everything", try model(three)),
        ("the-desktop", try model(three, camera: three.desktop)),
        ("a-group", try model(three, camera: three.leaf(containing: window(1)).flatMap { three.parent(of: $0) })),
        ("twelve", try model(twelve, camera: twelve.leaf(containing: window(7)))),
        ("nested-groups", try model(nested, camera: nested.leaf(containing: window(5)))),
        ("tab-group", try model(tabs, camera: tabs.leaf(containing: window(5)))),
        ("saved-view", try model(three, camera: three.leaf(containing: window(3)), caption: "View 3")),
        ("long-name", try model(three, caption: "Everything that has to be read before Friday, and then some")),
        ("asked-for-pointer-over-a-window", asked.pointing(at: asked.items[2].frame.center)),
        ("tall-display", try model(nested, camera: nested.leaf(containing: window(2)), area: CGSize(width: 1080, height: 1920))),
        ("wide-display", try model(nested, camera: nested.leaf(containing: window(2)), area: CGSize(width: 5120, height: 1440))),
      ]
      for (name, model) in models {
        for isDark in [false, true] {
          for scale in [CGFloat(1), 2] {
            let canvas = try picture(model, isDark: isDark, scale: scale)
            try canvas.save("\(name)-\(isDark ? "dark" : "light")@\(Int(scale))")
            #expect(canvas.pixel(1, 1).alpha == 0, "\(name): the corners are cut off")
          }
        }
      }
    }
  }
#endif
