#if os(macOS)
  import AppKit
  import ArborCore
  import CoreGraphics
  import Foundation
  import Testing

  @testable import ArborKit

  /// The palette of Go to… as AppKit draws it, off screen: no window is shown, nothing is read from the screen, no
  /// input is posted, and every name and title in the pictures is invented. The blur behind the palette is the window
  /// server's and does not show; a plain colour stands in for it.
  @MainActor
  private struct PalettePicture {
    /// What was drawn, on nothing. Pixels count from the top-left corner.
    let rep: NSBitmapImageRep
    let size: CGSize
    var scale: CGFloat { CGFloat(rep.pixelsWide) / size.width }

    /// Draws everything in the palette but the blur: the view that holds the field, the rows and the outline.
    init(of panel: FinderPanel, isDark: Bool) throws {
      panel.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
      let view = try #require(panel.contentView?.subviews.first { String(describing: type(of: $0)).contains("FinderView") })
      size = view.bounds.size
      rep = try #require(view.bitmapImageRepForCachingDisplay(in: view.bounds))
      view.cacheDisplay(in: view.bounds, to: rep)
    }

    /// How opaque the picture is at a point, counted in points from the top-left corner.
    func alpha(_ x: CGFloat, _ y: CGFloat) -> CGFloat {
      rep.colorAt(x: Int(x * scale), y: Int(y * scale))?.alphaComponent ?? 0
    }

    /// The box around everything drawn inside `rect`, in points; nil if nothing was. The faintest text (a placeholder, a
    /// note) is a quarter opaque.
    func ink(in rect: CGRect) -> CGRect? {
      var box: CGRect?
      let step = 1 / scale
      for y in stride(from: rect.minY + step / 2, to: rect.maxY, by: step) {
        for x in stride(from: rect.minX + step / 2, to: rect.maxX, by: step) where alpha(x, y) > 0.08 {
          let pixel = CGRect(x: x - step / 2, y: y - step / 2, width: step, height: step)
          box = box?.union(pixel) ?? pixel
        }
      }
      return box
    }

    /// Into `.build/pictures/F27` of the checkout, over `background` cut to the palette's corners, for people to look at.
    func save(_ name: String, over background: CGColor) throws {
      let drawn = try #require(rep.cgImage)
      let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
      let context = try #require(
        CGContext(
          data: nil, width: drawn.width, height: drawn.height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
      let whole = CGRect(x: 0, y: 0, width: drawn.width, height: drawn.height)
      let radius = 16 * scale
      context.addPath(CGPath(roundedRect: whole, cornerWidth: radius, cornerHeight: radius, transform: nil))
      context.clip()
      context.setFillColor(background)
      context.fill(whole)
      context.draw(drawn, in: whole)
      let image = try #require(context.makeImage())
      let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      var root = URL(fileURLWithPath: #filePath)
      for _ in 0..<3 { root.deleteLastPathComponent() }
      let folder = root.appendingPathComponent(".build/pictures/F27")
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try data.write(to: folder.appendingPathComponent(name + ".png"))
    }
  }

  @Suite @MainActor struct FinderDrawingTests {
    let screen = CGRect(x: 0, y: 25, width: 1440, height: 875)
    /// About what `.popover` looks like over a quiet window.
    func backdrop(isDark: Bool) -> CGColor {
      isDark ? CGColor(srgbRed: 0.16, green: 0.16, blue: 0.17, alpha: 1) : CGColor(srgbRed: 0.95, green: 0.95, blue: 0.96, alpha: 1)
    }

    /// A day's windows. The test runner's own process lends its icon to every other row.
    func model(notice: String? = nil) -> FinderModel {
      let main = DisplayID("main")
      let own = ProcessInfo.processInfo.processIdentifier
      func window(_ id: UInt32, _ app: String, _ title: String, _ place: FinderPlace, on display: String? = nil) -> FinderModel.Row {
        FinderModel.Row(
          destination: .window(WindowID(id)), name: app, detail: title, place: place, display: main, displayName: display,
          pid: id.isMultiple(of: 2) ? own : Int32.max)
      }
      return FinderModel(
        display: main, screen: screen,
        rows: [
          window(102, "Mail", "Inbox — 3 unread", .outOfView),
          window(103, "Safari", "Inbox zero, a method that works for people who get too much mail and read all of it anyway", .minimized),
          window(104, "Terminal", "zsh", .floatingOutOfView),
          window(105, "Notes", "Shopping", .tab),
          window(106, "Xcode", "Arbor — FinderPanel.swift", .inView, on: "Studio Display"),
          window(107, "Zoom", "Weekly", .keptInView),
          window(108, "Übersicht", "Größe jetzt", .otherSpace),
          window(101, "Safari", "Arbor docs", .inView),
          FinderModel.Row(
            destination: .view(main, slot: 2), name: "View 2", detail: "Mail, Slack", place: .savedView, display: main),
          FinderModel.Row(
            destination: .space(main, NodeID(4)), name: "Writing", detail: "Notes, Safari", place: .namedSpace, display: main),
        ],
        notice: notice)
    }

    func row(_ place: Int, of layout: FinderLayout) -> CGRect {
      layout.rowFrame(place).offsetBy(dx: layout.list.minX, dy: layout.list.minY)
    }

    @Test(arguments: [false, true]) func theListAsItOpens(isDark: Bool) throws {
      let panel = FinderPanel()
      defer { panel.close() }
      panel.load(model())
      let picture = try PalettePicture(of: panel, isDark: isDark)
      try picture.save("01-open-\(isDark ? "dark" : "light")", over: backdrop(isDark: isDark))

      let layout = FinderSession(model: model()).layout
      #expect(picture.size == layout.panel.size)
      #expect(layout.rows == 9, "nine of the ten rows show")
      // The first row is selected: filled from edge to edge. The second is not.
      let (first, second) = (row(0, of: layout), row(1, of: layout))
      #expect(picture.alpha(first.minX + 4, first.midY) > 0.9)
      #expect(picture.alpha(first.maxX - 4, first.midY) > 0.9)
      #expect(picture.alpha(second.minX + 4, second.midY) < 0.1)
      // The placeholder sits in the middle of its band.
      let placeholder = try #require(picture.ink(in: CGRect(x: 16, y: 4, width: layout.panel.width - 32, height: 48)))
      #expect(abs(placeholder.midY - FinderLayout.fieldBand / 2) <= 4, "the field's text is at \(placeholder)")
      // Text sits in the middle of its row, starts after the icon, and the note ends 12 points from the row's end.
      let text = try #require(picture.ink(in: CGRect(x: second.minX + 44, y: second.minY, width: second.width - 44, height: second.height)))
      #expect(abs(text.midY - second.midY) <= 3, "the second row's text is at \(text) in \(second)")
      #expect(abs(text.maxX - (second.maxX - 12)) <= 3, "the note ends at \(text.maxX)")
      // The outline runs down the sides.
      #expect(picture.alpha(0.5, layout.panel.height / 2) > 0.03)
    }

    @Test(arguments: [false, true]) func matchedLettersAndAShorterList(isDark: Bool) throws {
      let panel = FinderPanel()
      defer { panel.close() }
      panel.load(model())
      panel.type("inb")
      let picture = try PalettePicture(of: panel, isDark: isDark)
      try picture.save("02-typed-\(isDark ? "dark" : "light")", over: backdrop(isDark: isDark))

      var session = FinderSession(model: model())
      session.type("inb")
      #expect(picture.size == session.layout.panel.size, "the palette is as tall as its list")
      #expect(session.layout.rows < 9)
      let typed = try #require(picture.ink(in: CGRect(x: 16, y: 4, width: 200, height: 48)))
      #expect(abs(typed.midY - FinderLayout.fieldBand / 2) <= 5, "what is typed is at \(typed)")
    }

    @Test(arguments: [false, true]) func theLineUnderTheRows(isDark: Bool) throws {
      let panel = FinderPanel()
      defer { panel.close() }
      panel.load(model())
      panel.type("zzz")
      let nothing = try PalettePicture(of: panel, isDark: isDark)
      try nothing.save("03-nothing-matches-\(isDark ? "dark" : "light")", over: backdrop(isDark: isDark))
      var session = FinderSession(model: model())
      session.type("zzz")
      let message = session.layout.messageFrame.offsetBy(dx: session.layout.list.minX, dy: session.layout.list.minY)
      let words = try #require(nothing.ink(in: message))
      #expect(abs(words.midY - message.midY) <= 3, "“Nothing matches” is at \(words) in \(message)")

      panel.type("")
      panel.load(model(notice: "That window has closed"))
      try PalettePicture(of: panel, isDark: isDark).save("04-notice-\(isDark ? "dark" : "light")", over: backdrop(isDark: isDark))
    }
  }
#endif
