#if os(macOS)
  import AppKit
  import ArborCore
  import ArborTesting
  import CoreGraphics
  import Foundation
  import Testing

  @testable import ArborKit

  /// What stands behind the panel in a picture: a wall, a window's worth of colour over the left third of it, and, since
  /// an `NSVisualEffectView` draws nothing off screen, a plain rounded plate about as light as its material.
  private final class PictureStage: NSView {
    var isDark = false
    var plate = NSRect.zero

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
      NSColor(deviceWhite: isDark ? 0.08 : 0.82, alpha: 1).setFill()
      bounds.fill()
      NSColor(deviceRed: 0.85, green: 0.2, blue: 0.18, alpha: 1).setFill()
      NSRect(x: 0, y: 0, width: bounds.width / 3, height: bounds.height).fill()
      NSColor(deviceWhite: isDark ? 0.16 : 0.95, alpha: 0.92).setFill()
      let radius = PanelLook.Corner.line(height: plate.height)
      NSBezierPath(roundedRect: plate, xRadius: radius, yRadius: radius).fill()
    }
  }

  /// A panel's real views, drawn by AppKit into a bitmap in memory. No window is made, nothing is put on the screen and
  /// nothing is read from it, so the picture holds only what Arbor drew.
  @MainActor
  private struct Picture {
    static let margin: CGFloat = 20
    let bitmap: NSBitmapImageRep
    let scale: CGFloat

    /// `content` is placed inside a panel of that size as it is in the real one.
    init(panel: NSSize, content: NSView, at frame: NSRect, isDark: Bool, scale: CGFloat) throws {
      let size = NSSize(width: panel.width + 2 * Self.margin, height: panel.height + 2 * Self.margin)
      let stage = PictureStage(frame: NSRect(origin: .zero, size: size))
      stage.isDark = isDark
      stage.plate = NSRect(x: Self.margin, y: Self.margin, width: panel.width, height: panel.height)
      stage.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
      content.frame = frame.offsetBy(dx: Self.margin, dy: Self.margin)
      stage.addSubview(content)
      bitmap = try #require(
        NSBitmapImageRep(
          bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
          bytesPerRow: 0, bitsPerPixel: 0))
      // More pixels than points: AppKit then draws at that scale.
      bitmap.size = size
      self.scale = scale
      stage.cacheDisplay(in: stage.bounds, to: bitmap)
    }

    /// How light the picture is at a point of the panel, from 0 to 1. Points count from the panel's top-left corner.
    func lightness(_ x: CGFloat, _ y: CGFloat) -> Double {
      let column = Int((x + Self.margin) * scale), row = Int((y + Self.margin) * scale)
      guard column >= 0, row >= 0, column < bitmap.pixelsWide, row < bitmap.pixelsHigh,
        let colour = bitmap.colorAt(x: column, y: row)?.usingColorSpace(.deviceRGB)
      else { return -1 }
      return Double(colour.redComponent + colour.greenComponent + colour.blueComponent) / 3
    }

    /// How many of the points of `rect`, one in each direction every `step`, are ink: far lighter than the plate in a
    /// dark picture, far darker in a light one.
    func ink(in rect: NSRect, isDark: Bool, step: CGFloat = 1) -> Int {
      var found = 0
      for y in stride(from: rect.minY + 0.5, to: rect.maxY, by: step) {
        for x in stride(from: rect.minX + 0.5, to: rect.maxX, by: step) {
          let light = lightness(x, y)
          if isDark ? light > 0.45 : light >= 0 && light < 0.6 { found += 1 }
        }
      }
      return found
    }

    /// Into `.build/pictures/F43` of the checkout, for people to look at.
    func save(_ name: String) throws {
      var root = URL(fileURLWithPath: #filePath)
      for _ in 0..<3 { root.deleteLastPathComponent() }
      let folder = root.appendingPathComponent(".build/pictures/F43")
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let data = try #require(bitmap.representation(using: .png, properties: [:]))
      try data.write(to: folder.appendingPathComponent(name + ".png"))
    }
  }

  /// The heads-up line and the panel of shortcuts as AppKit draws them (docs/features/F43-say-what-happened.md, criterion 6),
  /// off screen. What they say is tested on every platform; this checks that it is drawn inside its panel, in a colour that
  /// can be read, and leaves pictures to look at. Each picture is saved before it is checked.
  @Suite @MainActor struct HeadsUpPictureTests {
    private let looks: [(name: String, isDark: Bool)] = [("light", false), ("dark", true)]

    /// Real models, from the real controller.
    private func harness(_ change: (inout Settings) -> Void = { _ in }) -> Harness {
      var settings = Settings()
      change(&settings)
      let h = Harness(settings: settings)
      let first = h.system.open(app: "Safari")
      h.system.open(app: "Mail")
      h.system.open(app: "Notes")
      h.start()
      h.system.userFocus(first)
      return h
    }

    private func lines() throws -> [(name: String, model: HeadsUpModel)] {
      let h = harness()
      var lines: [(name: String, model: HeadsUpModel)] = []
      for (name, command) in [
        ("1-nothing-there", "back"), ("2-problem", "out"), ("3-names-keys", "view 9"), ("4-docked", "dock left"), ("5-out-of-view", "zoom"),
        ("6-change", "save-view 2"),
      ] {
        h.run(command, from: .shortcut)
        lines.append((name, try #require(h.overlays.messages.last?.model, "\(command) says something")))
      }
      var narrow = lines[4].model
      narrow.maximumWidth = 320
      lines.append(("7-wrapped", narrow))
      return lines
    }

    @Test func theLineIsDrawnInsideItsPanelAndCanBeRead() throws {
      for (name, model) in try lines() {
        let placement = HeadsUpPanel.placement(of: model)
        #expect(placement.frame.width <= model.maximumWidth + 1, "\(name)")
        #expect(abs(placement.frame.midX - model.anchor.x) <= 1, "\(name) is centred on its anchor")
        #expect(abs(placement.frame.maxY - model.anchor.y) <= 1, "\(name) stands on its anchor")
        for look in looks {
          for scale: CGFloat in [1, 2] {
            let view = MeasuredTextView()
            view.text = placement.text
            let picture = try Picture(
              panel: placement.frame.size, content: view, at: placement.textFrame, isDark: look.isDark, scale: scale)
            try picture.save("line-\(name)-\(look.name)-\(Int(scale))x")

            let what = "\(name), \(look.name), \(Int(scale))x"
            #expect(picture.ink(in: placement.textFrame, isDark: look.isDark) > 40, "letters that stand out: \(what)")
            // Between the text's frame and the panel's edge there is nothing: no letter is cut off or hangs out. Looked for
            // above and below the text over its whole width, and beside it over its height: the corners are round, and
            // what shows there is what the panel floats over.
            let panel = NSRect(origin: .zero, size: placement.frame.size)
            let text = placement.textFrame
            let tall = NSRect(x: text.minX, y: 4, width: text.width, height: panel.height - 8)
            let wide = NSRect(x: 6, y: text.minY, width: panel.width - 12, height: text.height)
            for whole in [tall, wide] {
              let all = picture.ink(in: whole, isDark: look.isDark)
              #expect(all == picture.ink(in: text.intersection(whole), isDark: look.isDark), "nothing in the padding: \(what)")
            }
          }
        }
      }
    }

    /// "⌃⌥Space shows everything" is the half of the line that helps. Measured on a hosted Mac it stood out from the
    /// panel by 3.1 to 1 in the light look and 3.6 to 1 in the dark one, the sentence before it by 7.5 and 12.5. 4.5 is
    /// what text of this size needs.
    @Test func theKeysToPressStandOutAsTextMust() throws {
      let model = try #require(try lines().first { $0.name == "5-out-of-view" }?.model)
      let hint = try #require(model.hint)
      let placement = HeadsUpPanel.placement(of: model)
      // The hint is the end of the one line.
      let start = placement.text.attributedSubstring(
        from: NSRange(location: 0, length: placement.text.length - (hint as NSString).length))
      var area = placement.textFrame
      area.origin.x += start.size().width
      area.size.width -= start.size().width
      func linear(_ light: Double) -> Double { light <= 0.03928 ? light / 12.92 : pow((light + 0.055) / 1.055, 2.4) }
      for look in looks {
        let view = MeasuredTextView()
        view.text = placement.text
        let picture = try Picture(
          panel: placement.frame.size, content: view, at: placement.textFrame, isDark: look.isDark, scale: 2)
        // The plate right above the hint, in the padding.
        let plate = picture.lightness(area.midX, 3)
        var ink = plate
        for y in stride(from: area.minY + 0.25, to: area.maxY, by: 0.5) {
          for x in stride(from: area.minX + 0.25, to: area.maxX, by: 0.5) {
            let light = picture.lightness(x, y)
            if light >= 0 { ink = look.isDark ? max(ink, light) : min(ink, light) }
          }
        }
        let ratio = (max(linear(ink), linear(plate)) + 0.05) / (min(linear(ink), linear(plate)) + 0.05)
        #expect(ratio >= 4.5, "\(look.name): \(ratio) to 1")
      }
    }

    @Test func aLongLineWrapsInsteadOfGrowingWider() throws {
      let all = try lines()
      let wide = HeadsUpPanel.placement(of: all[4].model), narrow = HeadsUpPanel.placement(of: all[6].model)
      #expect(narrow.frame.width <= 320)
      // The text's heights, not the panels': the padding is the same around one line and two, so two lines make a panel
      // less than one and a half times as high, which is what this asked for until it first ran on a Mac.
      #expect(narrow.textFrame.height >= 2 * wide.textFrame.height - 2, "\(narrow.textFrame.height) to \(wide.textFrame.height)")
      #expect(narrow.frame.height - narrow.textFrame.height == wide.frame.height - wide.textFrame.height)
      #expect(abs(narrow.frame.maxY - wide.frame.maxY) <= 1, "it grows upward")
    }

    private func sheets() throws -> [(name: String, model: CheatSheetModel)] {
      var sheets: [(name: String, model: CheatSheetModel)] = []
      func sheet(_ name: String, _ h: Harness) throws {
        h.run("show-shortcuts")
        sheets.append((name, try #require(h.overlays.cheatSheets[h.display], "\(name)")))
      }
      try sheet("1-defaults", harness())
      try sheet(
        "2-own-shortcuts",
        harness { $0.bindings = ["ctrl+opt+e": "show-all", "ctrl+opt+space": nil, "ctrl+opt+5": "arrange all", "ctrl+opt+cmd+h": "dock left"] })
      let german = harness()
      german.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
      try sheet("3-german-keyboard", german)
      let emacs = harness { $0.passThroughApps = ["org.gnu.Emacs"] }
      emacs.controller.applicationActivated(FrontmostApp(bundleID: "org.gnu.Emacs", name: "Emacs"))
      try sheet("4-in-a-listed-app", emacs)
      var small = sheets[1].model
      small.area = CGRect(x: 0, y: 25, width: 800, height: 475)
      sheets.append(("5-on-a-small-display", small))
      return sheets
    }

    @Test func thePanelOfShortcutsFitsItsDisplayAndNothingInItOverlaps() throws {
      for (name, model) in try sheets() {
        let layout = CheatSheetPanel.layout(of: model)
        #expect(layout.size.width <= model.area.width && layout.size.height <= model.area.height, "\(name) fits")
        for look in looks {
          for scale: CGFloat in [1, 2] {
            let view = CheatSheetView()
            view.placed = layout
            let picture = try Picture(
              panel: layout.size, content: view, at: NSRect(origin: .zero, size: layout.size), isDark: look.isDark, scale: scale)
            try picture.save("shortcuts-\(name)-\(look.name)-\(Int(scale))x")
            if scale == 1 {
              let inside = NSRect(origin: .zero, size: layout.size).insetBy(dx: 12, dy: 12)
              #expect(picture.ink(in: inside, isDark: look.isDark, step: 2) > 300, "\(name), \(look.name): letters that stand out")
            }
          }
        }

        let boxes = layout.texts.map { NSRect(origin: $0.origin, size: $0.text.size()) }
        let inside = NSRect(origin: .zero, size: layout.size).insetBy(dx: 10, dy: 10)
        for (index, box) in boxes.enumerated() {
          #expect(inside.contains(box), "\(name): “\(layout.texts[index].text.string)” is inside the panel")
          for (other, second) in boxes.enumerated() where other > index {
            // A hair's breadth is let through: line heights are a little taller than the rows' letters.
            #expect(
              !box.insetBy(dx: 0, dy: 3).intersects(second.insetBy(dx: 0, dy: 3)),
              "\(name): “\(layout.texts[index].text.string)” and “\(layout.texts[other].text.string)” overlap")
          }
        }
        #expect(boxes.count == 2 * model.sections.flatMap(\.rows).count + model.sections.count + 2, "\(name): every row, heading, title and footer")
      }
    }
  }
#endif
