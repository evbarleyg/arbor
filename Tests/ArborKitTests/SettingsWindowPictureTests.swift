#if os(macOS)
  import AppKit
  import ArborCore
  import ArborTesting
  import CoreGraphics
  import Foundation
  import SwiftUI
  import Testing

  @testable import ArborKit

  /// The settings window's real views, drawn off screen into bitmaps and saved as PNGs in `.build/pictures/F12` for people
  /// to look at. What the window shows is tested without it (`SettingsPanelModelTests`); how it looks nobody can test, but
  /// somebody can look.
  ///
  /// Nothing here is shown on the screen or read from it: the views sit in a window that is never ordered in, and are asked to
  /// draw themselves into memory. And nothing of the Mac's owner is in the pictures: the model stands on a controller
  /// with fake windows, on settings made here (never the Mac's settings.json), and is told which apps "run".
  @MainActor
  private final class Studio {
    let h: Harness
    let model: SettingsPanelModel
    private let store: SettingsPanelStore
    private var broken: String?

    init(settings: ArborCore.Settings = ArborCore.Settings()) {
      // Windows and controls expect there to be an application object. It is not run, and shows nothing.
      _ = NSApplication.shared
      let h = Harness(settings: settings)
      self.h = h
      let safari = h.system.open(app: "Safari", frame: CGRect(x: 100, y: 100, width: 600, height: 400))
      h.start()
      h.run("dock \(safari.rawValue) left")
      model = SettingsPanelModel(
        controller: h.controller,
        runningApps: {
          [
            .init(bundleID: "com.example.safari", name: "Safari"), .init(bundleID: "com.example.mail", name: "Mail"),
            .init(bundleID: "com.example.terminal", name: "Terminal"),
          ]
        },
        run: { h.controller.perform($0) })
      store = SettingsPanelStore(model: model, openFile: {})
    }

    /// As if settings.json had just been saved with a typo in it.
    func breakTheFile(_ reason: String) {
      h.controller.loadSettings = { throw ArborCore.Settings.FileError(reason) }
      h.controller.takeInSettingsFile()
    }

    /// Draws the window's content as it is now. Returns the bitmap, having saved it as `<name>.png`.
    @discardableResult
    func picture(
      _ name: String, dark: Bool = false, scale: CGFloat = 2, size: CGSize = CGSize(width: 780, height: 540)
    ) throws -> NSBitmapImageRep {
      let host = NSHostingView(rootView: SettingsRootView(store: store))
      // Never ordered in, so it is on no screen. Views lay themselves out and take their appearance from a window.
      let window = NSWindow(
        contentRect: CGRect(origin: .zero, size: size), styleMask: [.titled], backing: .buffered, defer: true)
      window.isReleasedWhenClosed = false
      window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
      window.contentView = host
      window.setContentSize(size)
      // SwiftUI fills in lists and forms over a few turns of the run loop.
      for _ in 0..<3 {
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
      }
      let bitmap = try #require(
        NSBitmapImageRep(
          bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
          bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
          bytesPerRow: 0, bitsPerPixel: 0))
      // The size in points: what is drawn is scaled up to the pixels there are.
      bitmap.size = size
      // The window's own background, which `cacheDisplay` leaves out.
      if let context = NSGraphicsContext(bitmapImageRep: bitmap) {
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        window.appearance?.performAsCurrentDrawingAppearance {
          NSColor.windowBackgroundColor.setFill()
          CGRect(origin: .zero, size: size).fill()
        }
        NSGraphicsContext.restoreGraphicsState()
      }
      host.cacheDisplay(in: host.bounds, to: bitmap)
      window.contentView = nil

      var root = URL(fileURLWithPath: #filePath)
      for _ in 0..<3 { root.deleteLastPathComponent() }
      let folder = root.appendingPathComponent(".build/pictures/F12")
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      let data = try #require(bitmap.representation(using: .png, properties: [:]))
      try data.write(to: folder.appendingPathComponent(name + ".png"))
      return bitmap
    }
  }

  /// How light a picture is on average, 0 to 1, and how many different shades a coarse sample of it has: a picture of
  /// nothing has one.
  private func look(_ bitmap: NSBitmapImageRep) -> (lightness: Double, shades: Int) {
    var sum = 0.0
    var count = 0.0
    var shades: Set<Int> = []
    for y in stride(from: 0, to: bitmap.pixelsHigh, by: 7) {
      for x in stride(from: 0, to: bitmap.pixelsWide, by: 7) {
        guard let colour = bitmap.colorAt(x: x, y: y) else { continue }
        let light = Double(colour.redComponent + colour.greenComponent + colour.blueComponent) / 3
        sum += light
        count += 1
        shades.insert(Int(light * 32))
      }
    }
    return (count > 0 ? sum / count : 0, shades.count)
  }

  @Suite @MainActor struct SettingsWindowPictureTests {
    /// Something of everything, so that no pane is pictured empty.
    static var lived: ArborCore.Settings {
      var settings = ArborCore.Settings()
      settings.gap = 20
      settings.bindings = ["ctrl+opt+shift+f9": "set gap 0", "cmd+shift+d": "desktop", "ctrl+opt+d": nil]
      settings.rules = [
        AppRule(app: "com.example.mail", title: "Inbox", action: .dock(.left)),
        AppRule(app: "com.example.terminal", action: .dockBeside(bundleID: "com.example.mail", .bottom)),
        AppRule(app: "com.example.player", action: .float), AppRule(app: "com.example.palette", action: .ignore),
      ]
      settings.excludedBundleIDs = ["com.example.music", "com.example.safari"]
      settings.passThroughApps = ["org.example.editor"]
      settings.pauseForApps = ["com.example.game"]
      return settings
    }

    @Test func everyPaneInLightAndDark() throws {
      let studio = Studio(settings: Self.lived)
      for pane in studio.model.panes {
        studio.model.go(to: pane)
        let light = look(try studio.picture("light-\(pane.word)"))
        let dark = look(try studio.picture("dark-\(pane.word)", dark: true))
        #expect(light.shades > 3 && dark.shades > 3, "\(pane.word): something is drawn")
        #expect(light.lightness > dark.lightness + 0.2, "\(pane.word): dark is dark")
      }
    }

    @Test func everySectionWithAdvancedOpen() throws {
      let studio = Studio(settings: Self.lived)
      for section in SettingsSection.allCases where !studio.model.advancedRows(in: section).isEmpty {
        studio.model.go(to: .section(section))
        studio.model.setAdvanced(true, in: section)
        // Tall enough for everything, to see all of it at once.
        let size = CGSize(width: 780, height: 1100)
        try studio.picture("light-\(SettingsPane.section(section).word)-advanced", size: size)
        try studio.picture("dark-\(SettingsPane.section(section).word)-advanced", dark: true, size: size)
      }
    }

    @Test func theLongListsFromTopToBottom() throws {
      let studio = Studio(settings: Self.lived)
      studio.model.go(to: .shortcuts)
      try studio.picture("light-shortcuts-whole", size: CGSize(width: 780, height: 2600))
      try studio.picture("dark-shortcuts-whole", dark: true, size: CGSize(width: 780, height: 2600))
      studio.model.go(to: .rules)
      try studio.picture("light-rules-whole", size: CGSize(width: 780, height: 1000))
    }

    @Test func atTheSmallestSizeAndOnAPlainDisplay() throws {
      let studio = Studio(settings: Self.lived)
      studio.model.go(to: .section(.windows))
      try studio.picture("light-windows-smallest", size: CGSize(width: 720, height: 440))
      try studio.picture("light-windows-1x", scale: 1)
      try studio.picture("dark-windows-1x", dark: true, scale: 1)
    }

    @Test func aSearchARefusalAndTheBanners() throws {
      let studio = Studio(settings: Self.lived)
      studio.model.search = "ring"
      try studio.picture("light-search")
      try studio.picture("dark-search", dark: true)
      studio.model.search = "desktop"
      try studio.picture("light-search-with-shortcuts", size: CGSize(width: 780, height: 800))
      studio.model.search = "nothing like it"
      try studio.picture("light-search-nothing")
      studio.model.go(to: .section(.windows))
      studio.model.set("gap", to: "500")
      #expect(studio.model.rows(in: .windows).first?.error != nil)
      try studio.picture("light-refusal")
      try studio.picture("dark-refusal", dark: true)

      studio.model.go(to: .section(.general))
      studio.breakTheFile("line 3, column 3: expected `,` or `}` after the value of `gap`, found `\"`")
      studio.model.set("hotkeysEnabled", to: false)
      try studio.picture("light-file-broken")
      try studio.picture("dark-file-broken", dark: true)
      studio.model.replaceFileWithDefaults()
      try studio.picture("light-file-broken-question")

      let text = #"{"gap": 500, "focusRingColour": "mauve", "pinchThreshold": "far"}"#
      let unusable = Studio(settings: try JSONDecoder().decode(ArborCore.Settings.self, from: Data(text.utf8)))
      #expect(!unusable.model.valueProblems.isEmpty)
      try unusable.picture("light-values-unusable")
      try unusable.picture("dark-values-unusable", dark: true)
    }

    @Test func recordingAClashAndACaution() throws {
      let studio = Studio(settings: Self.lived)
      studio.model.go(to: .shortcuts)
      let row = try #require(studio.model.shortcutRows.first)
      studio.model.startRecording(row)
      try studio.picture("light-recording")
      try studio.picture("dark-recording", dark: true)
      // ⌃⌥↑, which steps out.
      #expect(studio.model.keyPressed(code: KeyChord.Key.up.code, modifiers: [.control, .option]))
      #expect(studio.model.clash != nil)
      try studio.picture("light-clash")
      try studio.picture("dark-clash", dark: true)
      studio.model.cancelRecording()
      studio.model.startRecording(row)
      #expect(studio.model.keyPressed(code: KeyChord.Key.w.code, modifiers: [.command]))
      #expect(studio.model.shortcutRows.first?.caution != nil)
      try studio.picture("light-caution")
      studio.model.restoreAllShortcuts()
      #expect(studio.model.question != nil)
      try studio.picture("light-shortcuts-whole-with-a-question", size: CGSize(width: 780, height: 2600))
      studio.model.answer(yes: false)
      studio.model.startRecording(commandText: "no such command")
      try studio.picture("light-shortcuts-whole-with-a-refusal", size: CGSize(width: 780, height: 2600))
    }

    @Test func aFreshArbor() throws {
      let studio = Studio()
      for pane: SettingsPane in [.section(.general), .shortcuts, .rules, .section(.apps)] {
        studio.model.go(to: pane)
        try studio.picture("fresh-\(pane.word)")
      }
    }
  }
#endif
