#if os(macOS)
  import AppKit
  import ArborCore
  import ArborTesting
  import CoreGraphics
  import Foundation
  import SwiftUI
  import Testing

  @testable import ArborKit

  /// Where the pictures go: `.build/pictures/F10` of the checkout, for people to look at.
  private func pictureFolder() throws -> URL {
    var root = URL(fileURLWithPath: #filePath)
    for _ in 0..<3 { root.deleteLastPathComponent() }
    let folder = root.appendingPathComponent(".build/pictures/F10")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    return folder
  }

  /// A bitmap to draw into and to read back. Nothing here touches the screen or reads from it, so the pictures it saves
  /// hold only what Arbor drew.
  @MainActor
  private final class Canvas {
    let size: CGSize
    let scale: CGFloat
    let bitmap: CGContext

    init(size: CGSize, scale: CGFloat) throws {
      self.size = size
      self.scale = scale
      let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
      bitmap = try #require(
        CGContext(
          data: nil, width: Int(size.width * scale), height: Int(size.height * scale), bitsPerComponent: 8,
          bytesPerRow: 0, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
    }

    /// Runs `body` with the bitmap as the current context, in points, y growing upward as in an `NSImage`.
    func draw(_ body: () -> Void) {
      bitmap.saveGState()
      bitmap.scaleBy(x: scale, y: scale)
      NSGraphicsContext.saveGraphicsState()
      NSGraphicsContext.current = NSGraphicsContext(cgContext: bitmap, flipped: false)
      body()
      NSGraphicsContext.restoreGraphicsState()
      bitmap.restoreGState()
    }

    /// How opaque the picture is at a point, counted from the bottom-left corner in points. 0 outside it.
    func alpha(_ x: CGFloat, _ y: CGFloat) -> Double {
      // The first row in memory is the top one.
      let column = Int(x * scale), row = bitmap.height - 1 - Int(y * scale)
      guard x >= 0, y >= 0, column < bitmap.width, row >= 0, row < bitmap.height,
        let bytes = bitmap.data?.assumingMemoryBound(to: UInt8.self)
      else { return 0 }
      return Double(bytes[row * bitmap.bytesPerRow + column * 4 + 3]) / 255
    }

    /// The most opaque pixel in `rect`, and how many are more opaque than `floor`.
    func ink(in rect: CGRect, above floor: Double = 0.5) -> (most: Double, count: Int) {
      var most = 0.0
      var count = 0
      let step = 1 / scale
      for y in stride(from: rect.minY + step / 2, to: rect.maxY, by: step) {
        for x in stride(from: rect.minX + step / 2, to: rect.maxX, by: step) {
          let value = alpha(x, y)
          most = max(most, value)
          if value > floor { count += 1 }
        }
      }
      return (most, count)
    }

    func save(_ name: String) throws {
      let image = try #require(bitmap.makeImage())
      let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
      try data.write(to: try pictureFolder().appendingPathComponent(name + ".png"))
    }
  }

  /// What `MenuBarModel`, `MenuBarLayout` and `OnboardingModel` decide is tested without a screen on every platform. This checks
  /// that AppKit and SwiftUI draw it as decided, and leaves pictures of every state for people to look at. No window
  /// is shown, nothing is captured, no input is sent.
  @Suite @MainActor struct MenuBarDrawingTests {
    /// [Safari | Desktop | Notes] with Mail floating, started, showing everything.
    func makeHarness(settings: ArborCore.Settings = ArborCore.Settings()) -> (Harness, WindowID, WindowID) {
      let h = Harness(settings: settings)
      let a = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
      let b = h.system.open(app: "Notes", frame: CGRect(x: 300, y: 200, width: 600, height: 400))
      h.system.open(app: "Mail", frame: CGRect(x: 500, y: 300, width: 400, height: 300))
      h.start()
      h.run("dock \(a.rawValue) left")
      h.run("dock \(b.rawValue) right")
      return (h, a, b)
    }

    /// The item's image for a model, as `StatusMenu.show` chooses it.
    func image(for model: MenuBarModel) -> NSImage {
      model.buttons.isEmpty
        ? ArborArtwork.menuBarIcon(model.icon.glyph) : ArborArtwork.menuBarControls(MenuBarLayout(model), fill: model.fill)
    }

    /// The template image alone, which is what the checks read.
    private func bitmap(of image: NSImage, scale: CGFloat = 2) throws -> Canvas {
      let canvas = try Canvas(size: image.size, scale: scale)
      canvas.draw { image.draw(in: NSRect(origin: .zero, size: image.size)) }
      return canvas
    }

    /// As a menu bar would show it: macOS turns a template image black on a light bar and white on a dark one. `dimmed` stands
    /// in for `appearsDisabled`, which only a real status bar button can show.
    func savePicture(_ image: NSImage, as name: String, dimmed: Bool = false) throws {
      for (suffix, bar, ink) in [("light", NSColor(white: 0.93, alpha: 1), NSColor.black), ("dark", NSColor(white: 0.16, alpha: 1), NSColor.white)] {
        for scale: CGFloat in [1, 2] {
          let whole = NSRect(origin: .zero, size: image.size)
          let layer = try Canvas(size: image.size, scale: scale)
          layer.draw {
            image.draw(in: whole)
            ink.set()
            whole.fill(using: .sourceAtop)
          }
          let tinted = try #require(layer.bitmap.makeImage())
          let size = CGSize(width: image.size.width + 16, height: 24)
          let picture = try Canvas(size: size, scale: scale)
          picture.draw {
            bar.setFill()
            NSRect(origin: .zero, size: size).fill()
            picture.bitmap.setAlpha(dimmed ? 0.35 : 1)
            picture.bitmap.draw(
              tinted, in: CGRect(x: 8, y: (24 - image.size.height) / 2, width: image.size.width, height: image.size.height))
          }
          try picture.save("item-\(name)-\(suffix)-\(Int(scale))x")
        }
      }
    }

    // MARK: The menu bar item

    @Test func everySymbolTheItemUsesExistsOnThisMac() {
      let (h, a, _) = makeHarness()
      h.run("zoom \(a.rawValue)")
      h.run("save-view 1")
      var glyphs = h.controller.menuBarModel().buttons.map(\.glyph)
      glyphs += [MenuBarModel.Icon.needsPermission.glyph, MenuBarModel.Icon.paused.glyph]
      for glyph in glyphs {
        if case .symbol(let name) = glyph {
          #expect(NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil, "\(name)")
        }
      }
    }

    @Test func everyButtonIsDrawnInItsOwnCell() throws {
      let (h, a, _) = makeHarness()
      h.run("zoom \(a.rawValue)")
      h.run("save-view 1")
      h.run("show-all")
      let model = h.controller.menuBarModel()
      let layout = MenuBarLayout(model)
      let drawn = image(for: model)
      #expect(drawn.size == layout.size)
      #expect(drawn.isTemplate, "so that macOS turns it white on a dark menu bar")
      let canvas = try bitmap(of: drawn)
      for (button, cell) in zip(layout.buttons, layout.cells) {
        let ink = canvas.ink(in: cell.insetBy(dx: 3, dy: 4), above: button.isEnabled ? 0.8 : 0.2)
        #expect(ink.count > 4, "\(button.id) shows something")
        if !button.isEnabled { #expect(ink.most < 0.5, "\(button.id) is faint") }
      }
      try savePicture(drawn, as: "one-view-everything")
    }

    @Test func theButtonForWhereTheViewIsHasABackgroundAndNoOtherHas() throws {
      let (h, a, _) = makeHarness()
      h.run("zoom \(a.rawValue)")
      h.run("save-view 1")
      let model = h.controller.menuBarModel()
      let layout = MenuBarLayout(model)
      let canvas = try bitmap(of: image(for: model))
      for (button, cell) in zip(layout.buttons, layout.cells) {
        // Inside the rounded rectangle, which begins 2 points up, and below every glyph, none of which is 16 points tall.
        let under = canvas.alpha(cell.midX + 0.25, cell.minY + 2.75)
        if button.isCurrent {
          #expect(abs(under - model.fill) < 0.05, "\(button.id): \(under)")
        } else {
          #expect(under == 0, "\(button.id): \(under)")
        }
      }
      #expect(model.buttons.filter(\.isCurrent).map(\.id) == [.view(1)])
      try savePicture(image(for: model), as: "framed-is-view-1")
    }

    /// Every state the item has, for the eye.
    @Test func picturesOfEveryState() throws {
      // Day one: nothing docked.
      let fresh = Harness()
      fresh.system.open(app: "Safari")
      fresh.start()
      try savePicture(image(for: fresh.controller.menuBarModel()), as: "nothing-docked")

      let (h, a, b) = makeHarness()
      try savePicture(image(for: h.controller.menuBarModel()), as: "docked-no-views")
      h.run("zoom \(a.rawValue)")
      h.run("save-view 1")
      h.run("zoom \(b.rawValue)")
      h.run("save-view 3")
      h.run("desktop")
      try savePicture(image(for: h.controller.menuBarModel()), as: "two-views-desktop")
      for slot in [2, 4, 5, 6, 7, 8, 9] { h.run("save-view \(slot)") }
      let nine = image(for: h.controller.menuBarModel())
      try savePicture(nine, as: "nine-views")
      #expect(nine.size.width < 330, "what a notch has to leave room for: \(nine.size.width)")

      var settings = ArborCore.Settings()
      settings.historyButtons = false
      settings.menuBarFill = 0.12
      h.controller.apply(settings: settings)
      try savePicture(image(for: h.controller.menuBarModel()), as: "no-history-faint-fill")

      h.run("pause")
      let paused = h.controller.menuBarModel()
      #expect(paused.icon.isDimmed)
      try savePicture(image(for: paused), as: "paused", dimmed: true)

      let waiting = Harness()
      waiting.controller.accessibilityGranted = false
      let warning = image(for: waiting.controller.menuBarModel())
      let sign = try bitmap(of: warning).ink(in: NSRect(origin: .zero, size: warning.size))
      #expect(sign.count > 10, "the warning sign is drawn")
      try savePicture(warning, as: "needs-permission")
    }

    // MARK: The icon

    @Test func theAppIconIsARoundedSquareWithTheMarkAtEverySize() throws {
      for side: CGFloat in [16, 32, 64, 128, 256, 512] {
        let icon = ArborArtwork.appIcon(side: side)
        let canvas = try Canvas(size: CGSize(width: side, height: side), scale: 1)
        canvas.draw { icon.draw(in: NSRect(x: 0, y: 0, width: side, height: side)) }
        #expect(canvas.alpha(0.5, 0.5) == 0, "\(side): the corners are clear")
        #expect(canvas.alpha(side / 2, side / 2) > 0.95, "\(side): the middle is not")
        try canvas.save("icon-\(Int(side))")
      }
    }

    // MARK: The welcome window

    /// Lays a page out as `OnboardingWindow` does, in a window that is never shown, and draws it into a bitmap.
    func page(_ model: OnboardingModel, rowsHeight: CGFloat? = nil, isDark: Bool, as name: String) throws -> CGSize {
      let view = OnboardingView(
        model: model, icon: ArborArtwork.appIcon(side: 128), rowsHeight: rowsHeight,
        onButton: { _ in }, onAction: { _ in }, onLogin: {}, onPrimary: {}, onBack: {})
      // A window needs an application object, which a test runner has not made. Nothing is activated or shown.
      _ = NSApplication.shared
      let host = NSHostingView(rootView: view)
      let size = host.fittingSize
      let window = NSWindow(
        contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
      window.isReleasedWhenClosed = false
      window.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
      window.backgroundColor = .windowBackgroundColor
      window.contentView = host
      host.layoutSubtreeIfNeeded()
      let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
      host.cacheDisplay(in: host.bounds, to: bitmap)
      let data = try #require(bitmap.representation(using: .png, properties: [:]))
      try data.write(to: try pictureFolder().appendingPathComponent("welcome-\(name)-\(isDark ? "dark" : "light").png"))
      window.contentView = nil
      return size
    }

    @Test func picturesOfEveryPageAndTheRoomEachTakes() throws {
      func model(
        _ facts: SystemFacts, flow: OnboardingFlow? = nil, apps: [String] = [], changed: [MacSwitch] = [], isNewcomer: Bool = false,
        isPaused: Bool = false
      ) -> OnboardingModel {
        OnboardingModel(
          facts, flow: flow, appsWithOwnShortcuts: apps, canFixSetup: true, switchesChangedByArbor: changed,
          // As the controller would have it.
          menuBarIcon: !facts.accessibility ? .needsPermission : isPaused ? .paused : MenuBarModel.Icon(), isNewcomer: isNewcomer,
          isPaused: isPaused
        ) { command in
          KeyBindings.label(for: command)
        }
      }
      let tiling: [MacSwitch] = [.screenEdges, .menuBar, .optionKey]
      let fresh = SystemFacts(accessibility: false, screenRecording: false, switches: tiling, inputSources: 1)
      let granted = SystemFacts(accessibility: true, screenRecording: false, switches: tiling, inputSources: 1)
      let tuned = SystemFacts(
        accessibility: true, screenRecording: true, switches: [], inputSources: 1, opensAtLogin: false)
      let everything = SystemFacts(
        accessibility: false, screenRecording: false, switches: MacSwitch.allCases, voiceOver: true, inputSources: 2,
        competingApps: ["Magnet", "Rectangle"])

      var moves = OnboardingFlow(isReady: true)
      moves.go(to: .firstSteps)
      var done = moves
      var workspace = Workspace()
      let window = WindowID(1)
      workspace.dock(window, at: .cameraEdge(.left))
      done.steps.observe([DisplayID("main"): workspace])
      let half = done
      workspace.dock(WindowID(2), at: .cameraEdge(.right))
      done.steps.observe([DisplayID("main"): workspace])
      workspace.moveCamera(to: try #require(workspace.tree.leaf(containing: window)))
      done.steps.observe([DisplayID("main"): workspace])
      workspace.moveCamera(to: workspace.tree.root)
      done.steps.observe([DisplayID("main"): workspace])
      #expect(done.steps.isComplete)

      let pages: [(String, OnboardingModel, CGFloat?)] = [
        ("1-first-launch", model(fresh, flow: OnboardingFlow(isReady: false), isNewcomer: true), nil),
        ("2-permission-granted", model(granted, flow: OnboardingFlow(isReady: true), isNewcomer: true), nil),
        ("3-all-in-order", model(tuned), nil),
        ("4-everything-wrong", model(everything, apps: ["Emacs"]), nil),
        ("5-everything-wrong-scrolling", model(everything, apps: ["Emacs"]), 300),
        ("6-four-moves", model(tuned, flow: moves), nil),
        ("7-one-move-made", model(tuned, flow: half), nil),
        ("8-all-moves-made", model(tuned, flow: done), nil),
        ("9-paused", model(tuned, flow: moves, isPaused: true), nil),
        ("10-switched-off-by-arbor", model(tuned, changed: tiling), nil),
        // What every Mac shows as it comes, to whoever asks.
        ("11-check-setup-on-a-mac-as-it-comes", model(granted), nil),
        ("12-check-setup-without-the-permission", model(fresh), nil),
      ]
      var sizes = ""
      var heights: [String: CGFloat] = [:]
      for (name, model, rowsHeight) in pages {
        for isDark in [false, true] {
          let size = try page(model, rowsHeight: rowsHeight, isDark: isDark, as: name)
          #expect(size.width == OnboardingModel.width(of: model.page), "\(name)")
          heights[name] = size.height
          if !isDark { sizes += "\(name): \(Int(size.width)) x \(Int(size.height))\n" }
        }
      }
      try sizes.write(to: try pictureFolder().appendingPathComponent("welcome-sizes.txt"), atomically: true, encoding: .utf8)

      // 644 points are what a 1024 x 768 display leaves between the menu bar and the Dock, less the title bar.
      // The first page's rows scroll when they must; the second page has nothing that could.
      for (name, model, _) in pages where model.page == .firstSteps {
        #expect((heights[name] ?? 0) < 644, "\(name) fits the smallest display: \(heights[name] ?? 0)")
      }
      // Rows in order lose their text, so the better things stand, the smaller the window.
      #expect((heights["3-all-in-order"] ?? 0) < (heights["11-check-setup-on-a-mac-as-it-comes"] ?? 0))
      // During the moves the window lies over the windows they are made on: what can wait, waits.
      #expect((heights["6-four-moves"] ?? 0) < (heights["8-all-moves-made"] ?? 0))
      #expect((heights["5-everything-wrong-scrolling"] ?? 0) < (heights["4-everything-wrong"] ?? 0), "the rows scroll")
    }
  }
#endif
