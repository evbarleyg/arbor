import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// `pointerGestures`, the one switch for whatever needs an event tap (collab/QUESTIONS.md, Q26). A tap holds every event of its kind, for
/// the whole Mac, until Arbor's callback returns. Off, none goes in, whatever the gestures' own settings say.
///
/// The taps themselves are macOS-only code. Asked here are the three questions they put before they go in (`GestureTap.update`,
/// `RectangleFramer.update`), of the settings they put them to (`Controller.inputSettings`), and `doctor`, which puts the same three.
/// On a Mac, `scripts/mac-shell/input-taps.sh` counts the taps macOS lists for Arbor.
@Suite @MainActor struct PointerGesturesTests {
  /// Everything that could ask for a tap, asking for it.
  static var everything: Settings {
    var settings = Settings.withGestures
    settings.guardDesktopClicks = true
    settings.continuousZoom = true
    settings.scrollOnDesktopZooms = true
    return settings
  }

  /// Out of what the first launch of a build from before the switch wrote down, which was every default of its day: the four gestures switched
  /// on, and the guard, which shipped on until 2026-10-14.
  static let fileOfAnEarlierBuild = #"""
    {"gap": 12, "gesturesEnabled": true, "scrollZoom": true, "frameRectangleModifier": "ctrl+opt", "frameRectangleOnDesktop": true,
     "guardDesktopClicks": true}
    """#

  /// Started, with a window docked: ⇧-drag and the guard take no interest in a display before that.
  func makeHarness(_ settings: Settings) -> Harness {
    let h = Harness(settings: settings)
    let safari = h.system.open(app: "Safari")
    h.start()
    h.run("dock \(safari.rawValue) left")
    return h
  }

  /// The taps Arbor asks for, under the names `doctor` has for them.
  func taps(_ h: Harness) -> [String] {
    let input = h.controller.inputSettings
    var presses = RectangleGesture()
    presses.follow(input)
    return (input.gesturesEnabled ? ["pinch"] : []) + (GestureRouter.listensToScrolls(input) ? ["scroll"] : [])
      + (presses.isEnabled ? ["rectangle"] : [])
  }

  func taps(_ change: (inout Settings) -> Void) -> [String] {
    var settings = Settings()
    change(&settings)
    return taps(makeHarness(settings))
  }

  @Test func offArborAsksForNoEventTapWhateverTheOtherSettingsSay() {
    #expect(taps { $0 = Self.everything } == ["pinch", "scroll", "rectangle"])
    #expect(
      taps {
        $0 = Self.everything
        $0.pointerGestures = false
      } == [])
  }

  /// The app installs and removes its taps when it hears `onSettingsApplied`, and hands them the zones when observers hear of a change.
  @Test func itIsObeyedAtOnceBothWaysAndWhoeverHoldsTheTapsHearsOfIt() {
    let h = makeHarness(Self.everything)
    var heard: [[String]] = []
    h.controller.onSettingsApplied = { [unowned h] _ in heard.append(self.taps(h)) }
    var published = h.controller.desktopGuardZones()
    h.controller.observe { if $0.mayChangeDesktopGuardZones { published = h.controller.desktopGuardZones() } }
    #expect(!published.isEmpty)

    var settings = Self.everything
    settings.pointerGestures = false
    h.controller.apply(settings: settings)
    #expect(heard == [[]], "told once, and by then the answer is none")
    #expect(published.isEmpty, "the tap's copy of the zones")
    #expect(h.controller.settings == settings && h.controller.inputSettings != settings, "the person's own settings are untouched")

    settings.pointerGestures = true
    h.controller.apply(settings: settings)
    #expect(heard == [[], ["pinch", "scroll", "rectangle"]])
    #expect(!published.isEmpty && published == h.controller.desktopGuardZones())
    #expect(h.controller.inputSettings == settings, "each gesture is as it was")
  }

  @Test func onWhoeverAsksForAGestureGetsItsTapAndNoOther() {
    func only(_ change: (inout Settings) -> Void) -> [String] {
      taps {
        ($0.pointerGestures, $0.gesturesEnabled, $0.scrollZoom) = (true, false, false)
        ($0.frameRectangleModifier, $0.frameRectangleOnDesktop) = ("none", false)
        change(&$0)
      }
    }
    #expect(only { _ in } == [], "the switch asks for none by itself")
    #expect(only { $0.gesturesEnabled = true } == ["pinch"])
    #expect(only { $0.scrollZoom = true } == [], "`gesturesEnabled` is the switch for the scroll as well")
    #expect(only { ($0.gesturesEnabled, $0.scrollZoom) = (true, true) } == ["pinch", "scroll"])
    #expect(only { $0.frameRectangleModifier = "ctrl+opt" } == ["rectangle"])
    #expect(only { $0.frameRectangleOnDesktop = true } == ["rectangle"])
    #expect(only { $0.guardDesktopClicks = true } == ["rectangle"])
  }

  @Test func offDoctorMissesNoTapAndSaysThatThereIsNone() {
    var settings = Self.everything
    settings.pointerGestures = false
    let h = makeHarness(settings)
    h.controller.systemFacts = {
      SystemFacts(
        accessibility: true, screenRecording: true, switches: [], separateSpaces: true, voiceOver: false, inputSources: 1,
        eventTaps: [])
    }
    #expect(
      h.controller.doctorReport().check("Gestures") == .init(mark: .note, title: "Gestures", detail: "none, as the settings ask"))
  }

  @Test func offNobodyIsToldWhereTheWallpaperShows() {
    // The zones are worked out after every layout for a tap to read. Without the tap there is nobody to read them.
    #expect(!makeHarness(Self.everything).controller.desktopGuardZones().isEmpty)
    var settings = Self.everything
    settings.pointerGestures = false
    #expect(makeHarness(settings).controller.desktopGuardZones().isEmpty)
  }

  @Test func offThePanelOfShortcutsListsOnlyWhatStillWorks() {
    func pointerRows(_ settings: Settings) -> [String] {
      let h = makeHarness(settings)
      h.run("show-shortcuts")
      return h.overlays.cheatSheets.values.first?.sections.last?.rows.map(\.keys) ?? []
    }
    var settings = Settings.withGestures
    #expect(pointerRows(settings).suffix(3) == ["⌥ + pinch", "⌃⌥ + drag", "⇧ + drag on the Desktop"])
    settings.pointerGestures = false
    #expect(pointerRows(settings) == ["Drag to a screen edge", "Drag to a window’s edge", "Drag a gap", "Click a tile"])
  }

  @Test func aFileWrittenByAnEarlierBuildCannotHoldItAndSoFollowsTheDefault() throws {
    let old = try JSONDecoder().decode(Settings.self, from: Data(Self.fileOfAnEarlierBuild.utf8))
    #expect(old.gesturesEnabled && old.scrollZoom && old.frameRectangleModifier == "ctrl+opt" && old.frameRectangleOnDesktop)
    #expect(old.pointerGestures == Settings().pointerGestures)
  }

  @Test func itIsReadAndWrittenLikeAnyOtherSetting() throws {
    var changed = Settings()
    changed.pointerGestures.toggle()
    #expect(try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(changed)) == changed)
    let entry = try SettingsSchema.entry(named: "pointerGestures")
    #expect(entry.label == "Trackpad and mouse gestures")
    #expect(SettingsSchema.entries(in: .gestures).first?.key == "pointerGestures", "the switch above the others")
  }
}
