import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// `doctor`, `permissions` and what the welcome window says, with made-up facts about the Mac.
@Suite @MainActor struct DoctorTests {
  /// A Mac where everything is as Arbor likes it.
  static let healthy = SystemFacts(
    accessibility: true, screenRecording: true, switches: [], separateSpaces: true, voiceOver: false, inputSources: 1,
    eventTaps: ["pinch", "scroll", "rectangle"])

  /// A started harness that reports `facts` and has every shortcut registered.
  func makeHarness(_ facts: SystemFacts = healthy, settings: Settings = Harness.settingsWhenNoneAreGiven) -> Harness {
    let h = Harness(settings: settings)
    h.controller.systemFacts = { facts }
    h.controller.registeredBindings = KeyBindings.effective(settings: settings).bindings
    h.controller.buildInfo = BuildInfo(version: "0.1.0", build: "1")
    h.start()
    return h
  }

  func check(_ h: Harness, _ title: String) -> DoctorReport.Check? { h.controller.doctorReport().check(title) }

  @Test func aHealthyMacHasNoProblems() {
    let result = makeHarness(settings: Settings()).run("doctor")
    #expect(result.ok)
    #expect(result.message == "no problems")
    #expect(
      result.text == """
        – Menu bar item: unknown here
        – Version: 0.1.0 (build 1)
        ✔ Accessibility: granted
        ✔ Desktop & Dock settings: none in the way
        ✔ Displays have separate Spaces: yes
        ✔ Other window managers: none running
        ✔ VoiceOver: off
        ✔ Input sources: 1
        ✔ Gestures: pinch, scroll, rectangle
        ✔ Shortcuts: 9 registered
            macOS does not tell Arbor when another program has registered the same key: then both get it, or the other alone
        ✔ Keyboard layout: US
        ✔ settings.json: no problems
        ✔ Displays: 1 (1440×900 main)
        """)
  }

  /// The signature decides whether the next build keeps the permission. `scripts/sign.sh` stamps its kind into the bundle.
  @Test func theSignatureIsNamedWithWhatItCosts() throws {
    let h = makeHarness()
    #expect(check(h, "Signature") == nil, "nobody stamped it: a binary outside a bundle")

    h.controller.buildInfo.signature = .adHoc
    let adHoc = try #require(check(h, "Signature"))
    #expect(adHoc.mark == .note, "this build works as well as any")
    #expect(adHoc.detail.hasPrefix("ad hoc, so to macOS every build is a new app: after each `make install` or update it asks "))
    #expect(adHoc.detail.contains("permission again") && adHoc.detail.contains("scripts/make-signing-identity.sh"))
    #expect(h.run("doctor").ok)
    #expect(h.run("doctor").text?.contains("\n– Signature: ad hoc, so") == true)

    h.controller.buildInfo.signature = .local
    #expect(check(h, "Signature")?.mark == .ok)
    #expect(check(h, "Signature")?.detail.hasPrefix("this Mac’s own certificate") == true)
    h.controller.buildInfo.signature = .issued
    #expect(check(h, "Signature")?.mark == .ok)

    // Check Setup is told the same.
    h.controller.buildInfo.signature = .adHoc
    #expect(h.controller.onboardingModel(Self.healthy).row(.accessibility)?.detail.hasPrefix("macOS will ask for this permission again") == true)
    h.controller.buildInfo.signature = .local
    #expect(h.controller.onboardingModel(Self.healthy).row(.accessibility)?.detail == "")
  }

  /// As a hosted Mac had it: a download, which is signed ad hoc, on its first day, the permission there, nothing docked yet. By the window's
  /// own road, not by a model made for the test: the one above asked in a harness that was not on its first launch, and was green.
  @Test func whoeverOpensCheckSetupOnTheFirstDayIsToldHowLongThePermissionLasts() {
    let sentence = "macOS will ask for this permission again after each update of Arbor"
    let h = Harness()
    h.controller.buildInfo.signature = .adHoc
    h.launchForTheFirstTime(permitted: true)
    #expect(h.welcome.isOpen && h.welcome.model.isNewcomer && h.welcome.model.page == .permissions)
    #expect(h.welcome.text?.contains("✔ Accessibility") == true)
    #expect(h.welcome.text?.contains(sentence) == false, "the welcome stays bare")
    #expect(h.run("check-setup").ok)
    #expect(h.welcome.model.isNewcomer && h.welcome.model.page == .setup)
    #expect(h.welcome.text?.contains(sentence) == true)
    // Signed with a certificate there is nothing to tell.
    h.controller.buildInfo.signature = .local
    #expect(h.run("check-setup").ok)
    #expect(h.welcome.text?.contains(sentence) == false)
  }

  /// Whoever runs `doctor` has a problem, and should not have to look for it among what is in order.
  @Test func theWorstComesFirst() {
    var facts = Self.healthy
    facts.screenRecording = false
    facts.competingApps = ["Rectangle"]
    facts.voiceOver = true
    let lines = (makeHarness(facts).run("doctor").text ?? "").split(separator: "\n").map(String.init)
    #expect(lines.prefix(2).map { String($0.prefix(24)) } == ["✘ Other window managers:", "✘ VoiceOver: on, and ⌃⌥ "])
    #expect(lines.map { $0.prefix(1) }.filter { "✘–✔".contains($0) }.map(String.init).joined().hasPrefix("✘✘––✔"))
    // Within a kind, the order the checks are made in; a check's notes stay under it.
    facts = Self.healthy
    facts.switches = [.optionKey]
    let withNotes = (makeHarness(facts).run("doctor").text ?? "").split(separator: "\n").map(String.init)
    #expect(withNotes[0].hasPrefix("✘ Desktop & Dock settings"))
    #expect(withNotes[1] == "    " + MacSwitch.optionKey.advice)
  }

  /// Most people never run `doctor`: what it would call a problem is in the log from the start.
  @Test func problemsGoIntoTheLogAtLaunchAndNothingElseDoes() {
    #expect(makeHarness().controller.setupProblemLines.isEmpty, "a healthy Mac")
    var facts = Self.healthy
    facts.screenRecording = false  // a note
    facts.switches = [.stageManager]
    facts.competingApps = ["yabai"]
    let lines = makeHarness(facts).controller.setupProblemLines
    #expect(lines.count == 2)
    #expect(lines[0].hasPrefix("setup: Desktop & Dock settings: ") && lines[0].hasSuffix(" | " + MacSwitch.stageManager.advice))
    #expect(lines[1].hasPrefix("setup: Other window managers: yabai running"))
  }

  /// Signs a keyboard cannot type alone stay where a US keyboard has them (F44): said, because the README's table does not.
  @Test func theKeyboardLayoutIsNamedWithTheShortcutsItMoves() {
    let h = makeHarness(settings: Settings())
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(
      check(h, "Keyboard layout")
        == .init(mark: .ok, title: "Keyboard layout", detail: "German; it does not type [ alone, so `back` is ⌃⌥Ü"))
    let whole = makeHarness(settings: .withEveryKey)
    whole.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(
      check(whole, "Keyboard layout")
        == .init(
          mark: .ok, title: "Keyboard layout",
          detail: "German; it does not type [, ], / and = alone, so `back` is ⌃⌥Ü, `forward` is ⌃⌥+, `show-shortcuts` is ⌃⌥⇧ß, `grow` is ⌃⌥⌘´"))
    // With shortcuts that do not follow it, it is the US layout that counts.
    var settings = Settings()
    settings.shortcutsFollowLayout = false
    let fixed = makeHarness(settings: settings)
    fixed.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    #expect(check(fixed, "Keyboard layout")?.detail == "US")
    // Without shortcuts there is nothing to say.
    settings.hotkeysEnabled = false
    #expect(check(makeHarness(settings: settings), "Keyboard layout") == nil)
  }

  /// Arbor only ever suggests it (F41): someone who frames a virtual machine still wants ⌃⌥Space to get out of it.
  @Test func appsThatUseTheSameModifiersAreNoted() {
    let h = makeHarness()
    #expect(check(h, "Apps with their own ⌃⌥") == nil)
    h.system.open(app: "Emacs", bundleID: "org.gnu.Emacs")
    #expect(check(h, "Apps with their own ⌃⌥")?.mark == .note)
    #expect(check(h, "Apps with their own ⌃⌥")?.detail.hasPrefix("Emacs uses ⌃⌥ too") == true)
    #expect(check(h, "Apps with their own ⌃⌥")?.detail.contains("Shortcuts Off in “App”") == true)
    #expect(h.run("doctor").ok, "advice, not a problem")
    // The welcome window shows the same finding.
    let row = h.controller.onboardingModel(Self.healthy).row(.ownShortcuts)
    #expect(row?.title == "Emacs uses ⌃⌥ too" && row?.state == .note && row?.button == nil)
    h.system.open(app: "UTM", bundleID: "com.utmapp.UTM")
    #expect(h.controller.onboardingModel(Self.healthy).row(.ownShortcuts)?.title == "Emacs and UTM use ⌃⌥ too")
    #expect(check(h, "Apps with their own ⌃⌥")?.detail.hasPrefix("Emacs and UTM use ⌃⌥ too") == true)
    // Dealt with, it is not mentioned again.
    h.run("pass-through org.gnu.Emacs on")
    h.run("pass-through com.utmapp.UTM on")
    #expect(check(h, "Apps with their own ⌃⌥") == nil)
    #expect(h.controller.onboardingModel(Self.healthy).row(.ownShortcuts) == nil)
  }

  @Test func missingAccessibilityIsAProblemAndDoctorStillAnswers() {
    var facts = Self.healthy
    facts.accessibility = false
    facts.eventTaps = []
    let h = Harness()
    h.controller.accessibilityGranted = false
    h.controller.systemFacts = { facts }
    let result = h.run("doctor")
    #expect(!result.ok, "so that `arborctl doctor` exits with 1")
    #expect(result.message == "1 problem(s)")
    #expect(check(h, "Accessibility")?.mark == .problem)
    #expect(check(h, "Accessibility")?.detail.contains("Privacy & Security") == true)
    // What cannot be there yet is not a second and third problem.
    #expect(check(h, "Gestures")?.mark == .note)
    #expect(check(h, "Shortcuts")?.mark == .note)
    #expect(check(h, "Displays")?.detail == "1 (1440×900 main)", "read from macOS, since Arbor has not started")
  }

  /// What `arborctl` goes by. On a Mac as it comes `arborctl doctor > file` left the file empty: one ✘ made the whole report a complaint.
  @Test func aReportWithAProblemInItIsStillTheAnswer() {
    var facts = Self.healthy
    facts.accessibility = false
    let h = Harness()
    h.controller.accessibilityGranted = false
    h.controller.systemFacts = { facts }
    func printed(_ result: CommandResult) -> CLIInvocation.Printed {
      CLIInvocation.printed(ok: result.ok, message: result.message, text: result.text)
    }
    let found = printed(h.run("doctor"))
    #expect(found.answer?.hasPrefix("✘ Accessibility: ") == true && found.answer?.contains("\n✔ ") == true, "all of it, on standard output")
    #expect(found.complaint == nil && found.exitCode == .refused, "the exit code alone says 1")
    let healthy = printed(makeHarness().run("doctor"))
    #expect(healthy.answer?.contains("✘") == false && healthy.complaint == nil && healthy.exitCode == .ok)
    // A refusal has nothing to report, and stays a complaint.
    let refusal = printed(h.run("dock 999 left"))
    #expect(refusal.answer == nil && refusal.complaint?.isEmpty == false && refusal.exitCode == .refused)
  }

  @Test func screenRecordingIsOptional() {
    var facts = Self.healthy
    facts.screenRecording = false
    var h = makeHarness(facts)
    #expect(check(h, "Screen Recording") == nil, "not spoken of while Arbor has no use for it")
    #expect(h.controller.onboardingModel(facts).row(.screenRecording) == nil)
    var withPictures = Settings()
    withPictures.windowPictures = true
    h = makeHarness(facts, settings: withPictures)
    #expect(h.controller.onboardingModel(facts).row(.screenRecording)?.state == .optional)
    #expect(check(h, "Screen Recording")?.mark == .note)
    #expect(check(h, "Screen Recording")?.detail.contains("optional") == true)
    #expect(h.run("doctor").ok)
  }

  @Test func desktopAndDockSettingsCompeteWithArbor() {
    var facts = Self.healthy
    facts.switches = [.menuBar, .optionKey]
    let h = makeHarness(facts)
    #expect(check(h, "Desktop & Dock settings")?.mark == .problem)
    #expect(check(h, "Desktop & Dock settings")?.detail.contains("System Settings → Desktop & Dock") == true)
    #expect(check(h, "Desktop & Dock settings")?.notes == [MacSwitch.menuBar.advice, MacSwitch.optionKey.advice])
    #expect(!h.run("doctor").ok)

    // What cannot be read is unknown, never a problem.
    facts.switches = nil
    #expect(
      check(makeHarness(facts), "Desktop & Dock settings")
        == .init(mark: .note, title: "Desktop & Dock settings", detail: "unknown here"))
  }

  /// A sweep is only a picture, and the next click brings the windows back (Q24): that switch is something to know, not to put right. The
  /// more so while Arbor keeps clicks on the Desktop from macOS itself (F60).
  @Test func theWallpaperClickIsOnlyNoted() {
    var facts = Self.healthy
    facts.switches = [.clickWallpaper]
    var guarded = Settings.withGestures
    guarded.guardDesktopClicks = true
    let alone = check(makeHarness(facts, settings: guarded), "Desktop & Dock settings")
    #expect(alone?.mark == .ok && alone?.detail == "none in the way")
    #expect(alone?.notes.count == 1 && alone?.notes.first?.contains("guardDesktopClicks") == true)
    #expect(alone?.notes.first?.contains("Only in Stage Manager") == true, "which is surer still")
    #expect(makeHarness(facts, settings: guarded).run("doctor").ok)

    // The others are as much in the way as ever.
    facts.switches = [.clickWallpaper, .optionKey]
    let both = check(makeHarness(facts, settings: guarded), "Desktop & Dock settings")
    #expect(both?.mark == .problem)
    #expect(both?.notes.first == MacSwitch.optionKey.advice && both?.notes.count == 2)

    // Nor is a newcomer sent to look for it.
    facts.switches = [.clickWallpaper]
    #expect(makeHarness(facts, settings: guarded).controller.onboardingModel(facts).row(.desktopAndDock)?.isSatisfied == true)

    // Without the guard, which is how Arbor ships: the same, in other words.
    let unguarded = makeHarness(facts)
    #expect(!unguarded.controller.settings.guardDesktopClicks)
    let plain = check(unguarded, "Desktop & Dock settings")
    #expect(plain?.mark == .ok && plain?.detail == "none in the way")
    #expect(
      plain?.notes == [
        "“Click wallpaper to reveal desktop” is on: a click on the wallpaper sweeps the windows aside, and the next one brings them back "
          + "where they were. “Only in Stage Manager” switches that off"
      ])
    #expect(unguarded.run("doctor").ok)
    #expect(unguarded.controller.onboardingModel(facts).row(.desktopAndDock)?.isSatisfied == true)
    #expect(unguarded.controller.pageToWelcomeOn() == nil || unguarded.controller.onboardingModel(facts).pageToOpenOn == .firstSteps)

    // The guard works through an event tap. With `pointerGestures` off there is none, and nobody may be told that Arbor guards.
    guarded.pointerGestures = false
    #expect(check(makeHarness(facts, settings: guarded), "Desktop & Dock settings")?.notes == plain?.notes)
  }

  @Test func aPauseIsSaidAndIsNotAProblem() {
    let h = makeHarness()
    #expect(check(h, "Arbor") == nil)
    h.run("pause")
    // The app hands back every shortcut but the ones that end the pause, and both taps.
    h.controller.registeredBindings = KeyBindings.whilePaused(KeyBindings.all)
    #expect(check(h, "Arbor")?.detail.hasPrefix("paused") == true)
    #expect(check(h, "Gestures")?.detail == "off while Arbor is paused")
    #expect(check(h, "Shortcuts")?.mark == .ok)
    #expect(check(h, "Shortcuts")?.detail.hasSuffix("registered while Arbor is paused") == true)
    #expect(h.run("doctor").ok)
  }

  /// Whoever asks because the keys do nothing must not be shown a tick. `doctor` is run from a terminal, a likely app to have them off in.
  @Test func shortcutsOffInTheAppInFrontAreSaidAndNotTicked() {
    let h = makeHarness()
    h.system.activate(bundleID: "com.example.terminal", name: "Terminal")
    #expect(check(h, "Shortcuts")?.mark == .ok)
    h.run("pass-through com.example.terminal on")
    h.controller.registeredBindings = h.controller.activeBindings
    #expect(check(h, "Shortcuts")?.mark == .note)
    #expect(check(h, "Shortcuts")?.detail.hasPrefix("all but \(h.controller.activeBindings.count) off in Terminal, the app in front") == true)
    #expect(h.run("doctor").ok, "nothing is wrong: it was asked for")
    // What macOS refused is still the worse news.
    h.controller.refusedBindings = Array(h.controller.activeBindings.prefix(1))
    #expect(check(h, "Shortcuts")?.mark == .problem)
    h.controller.refusedBindings = []
    h.system.activate(bundleID: "com.example.safari", name: "Safari")
    h.controller.registeredBindings = h.controller.activeBindings
    #expect(check(h, "Shortcuts")?.mark == .ok)
  }

  @Test func otherWindowManagersAreAProblem() {
    var facts = Self.healthy
    facts.competingApps = ["Rectangle", "Magnet"]
    let h = makeHarness(facts)
    #expect(check(h, "Other window managers")?.mark == .problem)
    #expect(check(h, "Other window managers")?.detail.hasPrefix("Rectangle and Magnet running") == true)
    #expect(check(h, "Other window managers")?.detail.hasSuffix("Quit them or switch their shortcuts off") == true)
    facts.competingApps = ["yabai"]
    #expect(check(makeHarness(facts), "Other window managers")?.detail.hasPrefix("yabai running") == true)
    #expect(check(makeHarness(facts), "Other window managers")?.detail.hasSuffix("Quit it or switch its shortcuts off") == true)
  }

  @Test func voiceOverCollidesWithTheShortcutsWhileTheyAreOn() {
    var facts = Self.healthy
    facts.voiceOver = true
    #expect(check(makeHarness(facts), "VoiceOver")?.mark == .problem)
    #expect(check(makeHarness(facts), "VoiceOver")?.detail.contains("Caps Lock") == true)
    var settings = Settings()
    settings.hotkeysEnabled = false
    #expect(check(makeHarness(facts, settings: settings), "VoiceOver")?.mark == .note)
  }

  @Test func severalInputSourcesAreNotedWhileSomethingIsOnTheirShortcut() {
    var facts = Self.healthy
    facts.inputSources = 2
    let h = makeHarness(facts, settings: Settings())
    #expect(check(h, "Input sources")?.mark == .note)
    #expect(check(h, "Input sources")?.detail.hasPrefix("2, so macOS may keep ⌃⌥Space (`show-all`)") == true)
    #expect(check(h, "Input sources")?.detail.contains("shows everything too") == false, "among the nine no other key does")
    #expect(h.run("doctor").ok, "nobody has seen who wins, and macOS's shortcut can be off")
    let whole = check(makeHarness(facts, settings: .withEveryKey), "Input sources")
    #expect(whole?.detail.hasPrefix("2, so macOS may keep ⌃⌥Space (`show-all`)") == true)
    #expect(whole?.detail.hasSuffix("; ⌃⌥0 shows everything too") == true, "the way round it")

    var settings = Settings()
    settings.bindings = ["ctrl+opt+space": nil]
    #expect(check(makeHarness(facts, settings: settings), "Input sources") == .init(mark: .ok, title: "Input sources", detail: "2"))
    facts.inputSources = nil
    #expect(check(makeHarness(facts), "Input sources")?.detail == "unknown here")
  }

  @Test func sharedSpacesAreOnlyNoted() {
    var facts = Self.healthy
    facts.separateSpaces = false
    #expect(check(makeHarness(facts), "Displays have separate Spaces")?.mark == .note)
    // A bare "no" leaves the reader to guess what it has to do with Arbor.
    #expect(check(makeHarness(facts), "Displays have separate Spaces")?.detail.contains("on the main display only") == true)
    facts.separateSpaces = nil
    #expect(check(makeHarness(facts), "Displays have separate Spaces")?.detail == "unknown here")
  }

  @Test func anEventTapTheSettingsAskForMustBeInstalled() {
    var facts = Self.healthy
    facts.eventTaps = ["scroll", "rectangle"]
    let h = makeHarness(facts, settings: .withGestures)
    #expect(check(h, "Gestures")?.mark == .problem)
    #expect(check(h, "Gestures")?.detail == "pinch does nothing: its event tap is not installed (installed: scroll, rectangle)")
    facts.eventTaps = []
    #expect(
      check(makeHarness(facts, settings: .withGestures), "Gestures")?.detail
        == "pinch, scroll and rectangle do nothing: their event taps are not installed (installed: none)")
    facts.eventTaps = ["rectangle"]

    // Switched off in the settings, it is not missed.
    var settings = Settings.withGestures
    settings.gesturesEnabled = false
    #expect(check(makeHarness(facts, settings: settings), "Gestures") == .init(mark: .ok, title: "Gestures", detail: "rectangle"))
    // ⇧-drag on the Desktop and the guard against the wallpaper click listen through the same tap as the rectangle.
    let missed = "rectangle does nothing: its event tap is not installed (installed: none)"
    settings.frameRectangleModifier = "none"
    facts.eventTaps = []
    #expect(check(makeHarness(facts, settings: settings), "Gestures")?.detail == missed)
    settings.frameRectangleOnDesktop = false
    settings.guardDesktopClicks = true
    #expect(check(makeHarness(facts, settings: settings), "Gestures")?.detail == missed)
    settings.guardDesktopClicks = false
    #expect(check(makeHarness(facts, settings: settings), "Gestures")?.mark == .note)

    // A tap doctor has not heard of is listed, not complained about.
    facts.eventTaps = ["pinch", "scroll", "rectangle", "double-click"]
    #expect(
      check(makeHarness(facts, settings: .withGestures), "Gestures")
        == .init(mark: .ok, title: "Gestures", detail: "pinch, scroll, rectangle, double-click"))
  }

  @Test func theTapForScrollingIsATapOfItsOwn() {
    // ⌃⌥ + scroll (F55) listens through another tap than the pinch.
    var facts = Self.healthy
    facts.eventTaps = ["pinch", "rectangle"]
    #expect(
      check(makeHarness(facts, settings: .withGestures), "Gestures")
        == .init(
          mark: .problem, title: "Gestures",
          detail: "scroll does nothing: its event tap is not installed (installed: pinch, rectangle)"))
    // Nothing that scrolls is asked for: it is not missed.
    var settings = Settings.withGestures
    settings.scrollZoom = false
    #expect(check(makeHarness(facts, settings: settings), "Gestures") == .init(mark: .ok, title: "Gestures", detail: "pinch, rectangle"))
    // The view that follows the fingers slides with two of them (F16).
    settings.continuousZoom = true
    #expect(check(makeHarness(facts, settings: settings), "Gestures")?.mark == .problem)
    // `gesturesEnabled` is the switch for all of them.
    settings.gesturesEnabled = false
    facts.eventTaps = ["rectangle"]
    #expect(check(makeHarness(facts, settings: settings), "Gestures")?.mark == .ok)
  }

  @Test func shortcutsMacOSRefusedAreNamed() {
    let h = makeHarness(settings: Settings())
    h.controller.registeredBindings = KeyBindings.core.filter { ![.showAll, .undo].contains($0.command) }
    h.controller.refusedBindings = KeyBindings.core.filter { [.showAll, .undo].contains($0.command) }
    #expect(check(h, "Shortcuts")?.mark == .problem)
    #expect(
      check(h, "Shortcuts")?.detail
        == "\(KeyBindings.core.count - 2) registered; macOS refused ⌃⌥Space ⌃⌥Z, which Arbor so does not hear")
  }

  /// Arbor itself asks for fewer shortcuts, or for other keys, than the settings describe: during a pause, in an app
  /// that keeps its own ⌃⌥ (F41), on another keyboard layout (F44). None of that is a refusal. What it does ask for and does
  /// not hold is another matter (`KeysHeldTests`): this test used to give a running Arbor that held nothing a tick.
  @Test func shortcutsArborDidNotAskForWereNotRefused() {
    let h = makeHarness()
    h.run("pause")
    let paused = h.controller.activeBindings
    #expect(paused.count < KeyBindings.core.count)
    h.controller.registeredBindings = paused
    #expect(check(h, "Shortcuts")?.mark == .ok)
    #expect(check(h, "Shortcuts")?.detail == "\(paused.count) registered while Arbor is paused")
    h.run("resume")
    h.controller.keyboardLayoutChanged(SampleKeyLayouts.german)
    h.controller.registeredBindings = h.controller.activeBindings
    #expect(h.controller.activeBindings != KeyBindings.core, "other keys")
    #expect(check(h, "Shortcuts")?.mark == .ok)
    #expect(h.run("doctor").ok)
  }

  @Test func inputSwitchedOffOnPurposeIsNotAProblem() {
    var settings = Settings()
    settings.hotkeysEnabled = false
    let off = makeHarness(settings: settings)
    off.controller.registeredBindings = []
    #expect(check(off, "Shortcuts") == .init(mark: .note, title: "Shortcuts", detail: "off (hotkeysEnabled is false)"))

    var facts = Self.healthy
    facts.inputDisabled = true
    facts.eventTaps = []
    let h = makeHarness(facts)
    h.controller.registeredBindings = []
    #expect(check(h, "Shortcuts")?.detail == "off (ARBOR_NO_HOTKEYS)")
    #expect(check(h, "Gestures")?.detail == "off (ARBOR_NO_HOTKEYS)")
    #expect(h.run("doctor").ok)
  }

  @Test func aSettingsFileThatCannotBeReadIsAProblemThatSaysWhere() {
    let h = makeHarness()
    struct Broken: Error, CustomStringConvertible { let description = "line 3, column 3: expected `,` or `}`" }
    h.controller.loadSettings = { throw Broken() }
    h.run("reload-settings")
    #expect(check(h, "settings.json")?.mark == .problem)
    #expect(check(h, "settings.json")?.detail.hasPrefix("cannot be read (") == true)
    #expect(check(h, "settings.json")?.detail.contains(h.controller.settingsFileProblem ?? "?") == true)
  }

  @Test func whatArborCouldNotUseInTheSettingsFileIsListed() throws {
    let json = #"""
      {"rules": [{"app": "com.apple.Notes"}, {"app": "com.apple.mail", "action": "dock left"}],
       "bindings": {"hyper+x": "show-all", "ctrl+opt+j": 7},
       "frameRectangleModifier": "banana", "displays": [{"match": "main", "gap": "wide"}]}
      """#
    let settings = try JSONDecoder().decode(Settings.self, from: Data(json.utf8))
    let h = makeHarness(settings: settings)
    let found = try #require(check(h, "settings.json"))
    #expect(found.mark == .problem)
    #expect(found.detail == "5 entries skipped")
    #expect(found.notes.count == 5)
    #expect(found.notes.contains { $0.hasPrefix("displays: entry 1 (main)") })
    // What an entry matches can be a display's name, and that can be a person's: told to whoever asks, never logged.
    #expect(h.controller.setupProblemLines.contains { $0.hasPrefix("setup: settings.json: 5 entries skipped") })
    #expect(!h.controller.setupProblemLines.contains { $0.contains("displays:") || $0.contains("(main)") })
    #expect(found.notes.contains { $0.hasPrefix("rules: entry 1 (com.apple.Notes)") })
    #expect(found.notes.contains { $0.hasPrefix("bindings: hyper+x") })
    #expect(found.notes.contains { $0.hasPrefix("bindings: ctrl+opt+j") })
    #expect(found.notes == settings.valueProblems + found.notes.dropFirst(settings.valueProblems.count), "as `settings` says it")
    #expect(found.notes.contains { $0.hasPrefix("frameRectangleModifier: ") && $0.contains("banana") })
    // The notes are indented under their check.
    let lines = try #require(h.run("doctor").text).components(separatedBy: "\n")
    let index = try #require(lines.firstIndex { $0.hasPrefix("✘ settings.json") })
    #expect(lines[(index + 1)...(index + 5)].allSatisfy { $0.hasPrefix("    ") })
    // The unreadable modifier falls back to the default, so its tap is still expected.
    #expect(check(h, "Gestures")?.mark == .ok)
  }

  @Test func everyDisplayIsListed() {
    let side = DisplaySnapshot(
      id: DisplayID("side"), frame: CGRect(x: 1440, y: 0, width: 1920, height: 1080),
      visibleFrame: CGRect(x: 1440, y: 25, width: 1920, height: 1055), isMain: false)
    let h = Harness(displays: [FakeWindowSystem.standardDisplay, side])
    h.start()
    #expect(check(h, "Displays")?.detail == "2 (1440×900 main, 1920×1080)")
    h.system.setDisplays([])
    #expect(check(h, "Displays")?.mark == .problem)
  }

  @Test func withoutFactsNothingIsClaimed() {
    let h = Harness(settings: Settings())
    h.start()
    let report = h.controller.doctorReport()
    #expect(report.problems == 0)
    for title in [
      "Desktop & Dock settings", "Displays have separate Spaces", "Other window managers", "VoiceOver",
      "Input sources", "Gestures",
    ] {
      #expect(report.check(title) == .init(mark: .note, title: title, detail: "unknown here"))
    }
    #expect(report.check("Accessibility")?.mark == .ok, "the controller knows that much itself")
    #expect(report.check("Shortcuts")?.detail == "\(KeyBindings.core.count) in the settings, not registered yet")
  }

  // MARK: The welcome window

  @Test func theWelcomeWindowOpensEvenBeforeArborMayStart() {
    let h = Harness()
    h.controller.accessibilityGranted = false
    var opened: [OnboardingFlow.Page?] = []
    h.controller.openWelcomeWindow = { page, _ in opened.append(page) }
    #expect(h.run("check-setup").ok)
    #expect(opened == [.setup])
    h.controller.accessibilityGranted = true
    h.start()
    #expect(h.run("welcome").ok)
    #expect(opened == [.setup, .firstSteps])
  }

  @Test func theCommandsSaySoWhereThereIsNoWindow() {
    for command in ["check-setup", "welcome"] {
      let result = Harness().run(command)
      #expect(!result.ok)
      #expect(result.message.contains("doctor"))
    }
  }

  @Test func theWindowCanHaveAShortcutButQueriesCannot() {
    var settings = Settings()
    settings.bindings = ["ctrl+opt+y": "check-setup", "ctrl+opt+j": "doctor", "ctrl+opt+k": "menu-bar"]
    let (bindings, problems) = KeyBindings.effective(settings: settings)
    #expect(bindings.contains { $0.command == .checkSetup })
    #expect(problems.count == 2)
  }

  @Test func theWelcomeWindowShowsTheFactsAndTheShortcutsInEffect() {
    var facts = Self.healthy
    facts.accessibility = false
    facts.switches = [.menuBar]
    let h = Harness(settings: Settings())
    let model = h.controller.onboardingModel(facts)
    #expect(model.rows.map(\.isSatisfied) == [false, false])
    // Nothing is registered before Arbor starts, so the window shows what the settings promise.
    #expect(model.steps.map(\.lead) == ["Click a window and press ⌃⌥←", "Click another and press ⌃⌥→", "Then press ⌃⌥↩", "Press ⌃⌥↩ again"])

    var settings = Settings()
    settings.bindings = ["ctrl+opt+return": nil, "ctrl+opt+z": "zoom"]
    h.controller.apply(settings: settings)
    #expect(h.controller.onboardingModel(facts).step(.frame)?.lead == "Then press ⌃⌥Z")

    // With ARBOR_NO_HOTKEYS nothing will ever be registered.
    facts.inputDisabled = true
    #expect(h.controller.onboardingModel(facts).step(.frame)?.lead == "Then choose Frame Focused Window in Arbor’s menu")
  }
}

/// One showing of the welcome window against the real controller.
@Suite @MainActor struct OnboardingSessionTests {
  /// Facts a test can change, as the user does in System Settings.
  final class Mac {
    var facts = SystemFacts(accessibility: false, screenRecording: false, switches: [.clickWallpaper, .menuBar, .optionKey])
  }

  func ticks(_ model: OnboardingModel) -> [Bool] { model.steps.map(\.isDone) }

  @Test func aNewcomerIsTakenFromThePermissionToTheFourMoves() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let b = h.system.open(app: "Mail")
    let mac = Mac()
    h.controller.accessibilityGranted = false
    h.controller.systemFacts = { mac.facts }
    var shown: [OnboardingModel] = []
    let session = OnboardingSession(controller: h.controller) { shown.append($0) }
    session.begin()
    #expect(session.model.page == .permissions && !session.model.isReady)

    session.refresh()
    #expect(shown.isEmpty, "nothing has changed, so nothing is drawn again")

    // The welcome does not speak of Desktop & Dock (Q29, 11), so nothing there is anything to it.
    mac.facts.switches = [.optionKey]
    session.refresh()
    #expect(shown.isEmpty && session.model.rows.map(\.id) == [.accessibility])

    // The permission arrives; the app starts the controller.
    mac.facts.accessibility = true
    h.controller.accessibilityGranted = true
    h.start()
    session.refresh()
    #expect(session.model.page == .firstSteps)
    #expect(ticks(session.model) == [false, false, false, false])

    // Each move is ticked off as it happens, with no look at the clock.
    h.system.tiling = .off  // the screen's edges are Arbor's only with macOS's tiling off
    h.system.drag(a, through: [CGPoint(x: 600, y: 210), CGPoint(x: 300, y: 300), CGPoint(x: 2, y: 400)])
    #expect(ticks(session.model) == [true, false, false, false])
    h.run("dock \(b.rawValue) right")
    #expect(ticks(session.model) == [true, true, false, false])
    h.system.userFocus(a)
    h.run("zoom")
    #expect(ticks(session.model) == [true, true, true, false])
    h.run("show-all")
    #expect(ticks(session.model) == [true, true, true, true])
    #expect(session.model.title == "That is all there is to it")
    #expect(shown.last == session.model)
  }

  /// Whoever comes back from granting the permission has looked at nothing else on the page: so the window waits at what is in the way of
  /// the moves (F46, "Setup: only the problems. Skipped when there are none"), and nothing has been arranged by then. macOS's own tiling is
  /// not in their way: they are keys (Q29, 11).
  @Test func withThePermissionThereTheWindowWaitsAtWhatIsStillInTheWay() throws {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    let before = h.frame(a)
    let mac = Mac()
    mac.facts.switches = MacSwitch.inTheWay(macOS: 26) { _ in nil }
    mac.facts.competingApps = ["Rectangle"]
    h.controller.accessibilityGranted = false
    h.controller.systemFacts = { mac.facts }
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin()
    #expect(session.model.title == "Arbor keeps your windows arranged")

    mac.facts.accessibility = true
    h.controller.accessibilityGranted = true
    h.start()
    session.refresh()
    #expect(session.model.page == .permissions)
    #expect(session.model.row(.accessibility)?.isSatisfied == true)
    #expect(session.model.row(.competingApps)?.state == .recommended && session.model.row(.desktopAndDock) == nil)
    #expect(session.model.isPrimaryEnabled, "it is advice: nobody is held up")
    #expect(h.frame(a) == before && h.system.frameLog.isEmpty && h.workspace.isFloating(a), "nothing has moved")

    // Put right while the window waits: it stays, so that what was done can be read. Continue goes on.
    mac.facts.competingApps = []
    session.refresh()
    #expect(session.model.page == .permissions && !session.model.needsAttention)
    session.go(to: .firstSteps)
    #expect(session.model.page == .firstSteps)
  }

  /// On a Mac as it comes nothing is in the way of the moves, so the window goes on to them by itself.
  @Test func onAMacAsItComesTheWindowGoesOnWhenThePermissionArrives() {
    let h = Harness()
    let mac = Mac()
    mac.facts.switches = MacSwitch.inTheWay(macOS: 26) { _ in nil }
    h.controller.accessibilityGranted = false
    h.controller.systemFacts = { mac.facts }
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin()
    mac.facts.accessibility = true
    h.controller.accessibilityGranted = true
    h.start()
    session.refresh()
    #expect(session.model.page == .firstSteps)
  }

  /// An open Check Setup… follows Desktop & Dock one switch at a time, whoever flips them.
  @Test func checkSetupFollowsTheSwitchesAsTheyAreFlipped() {
    let h = Harness()
    let mac = Mac()
    mac.facts.accessibility = true
    h.controller.systemFacts = { mac.facts }
    h.start()
    var shown: [OnboardingModel] = []
    let session = OnboardingSession(controller: h.controller) { shown.append($0) }
    session.begin(on: .setup)
    shown = []
    session.refresh()
    #expect(shown.isEmpty, "nothing has changed, so nothing is drawn again")

    mac.facts.switches = [.optionKey]
    session.refresh()
    #expect(shown.count == 1)
    #expect(shown.last?.row(.desktopAndDock)?.afterword == "Changes 1 setting in Desktop & Dock, nothing else: \(MacSwitch.optionKey.named).")

    // The last one.
    mac.facts.switches = []
    session.refresh()
    #expect(shown.count == 2)
    #expect(shown.last?.row(.desktopAndDock)?.isSatisfied == true)
    #expect(session.model.page == .setup && session.model.title == "Arbor is ready")
  }

  @Test func aPausedArborSaysSoInsteadOfPromisingMovesThatDoNothing() {
    let h = Harness(settings: Settings())
    h.start()
    h.controller.registeredBindings = KeyBindings.all
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin()
    session.go(to: .firstSteps)
    h.run("pause")
    h.controller.registeredBindings = KeyBindings.whilePaused(KeyBindings.all)
    session.refresh()
    #expect(session.model.summary.contains("Resume"))
    #expect(session.model.step(.frame)?.lead == "Then press ⌃⌥↩", "the shortcut that will be there again")
    session.go(to: .permissions)
    #expect(session.model.title == "Arbor is paused")
    session.go(to: .setup)
    #expect(session.model.title == "Arbor is paused")
    h.run("resume")
    // As the app does when it hears of it. Left at the pause's one key, the window would rightly say that the others are not Arbor's.
    h.controller.registeredBindings = KeyBindings.core
    session.refresh()
    #expect(session.model.title == "Arbor is ready")
  }

  @Test func welcomeOpensOnTheMovesAndCheckSetupOnHowThingsStand() {
    let h = Harness()
    h.start()
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin(on: .firstSteps)
    #expect(session.model.page == .firstSteps)
    session.end()
    session.begin(on: .setup)
    #expect(session.model.page == .setup)
    session.end()

    // Without the permission there is nothing to try, whatever was asked for.
    h.controller.accessibilityGranted = false
    session.begin(on: .firstSteps)
    #expect(session.model.page == .permissions)
  }

  @Test func theWayBackNamesTheShortcutInEffect() {
    let model = Harness().controller.onboardingModel(DoctorTests.healthy)
    #expect(model.wayBack == "⌃⌥⎋ pauses Arbor: every window is as it was. Quit does the same.")
  }

  @Test func theButtonsTurnThePages() {
    let h = Harness()
    h.start()
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin(on: .permissions)
    #expect(session.model.page == .permissions)
    #expect(session.model.isPrimaryEnabled)
    session.go(to: .firstSteps)
    #expect(session.model.page == .firstSteps)
    session.refresh()
    #expect(session.model.page == .firstSteps)
    session.go(to: .permissions)
    #expect(session.model.page == .permissions)
  }

  @Test func everyShowingStartsOver() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin()
    session.go(to: .firstSteps)
    h.run("dock \(a.rawValue) left")
    h.run("zoom \(a.rawValue)")
    h.run("show-all")
    #expect(ticks(session.model) == [true, false, true, true])
    session.end()

    session.begin()
    #expect(session.model.page == .setup, "no page was asked for, by somebody who has used Arbor: how things stand")
    session.go(to: .firstSteps)
    #expect(ticks(session.model) == [true, false, false, false], "a window is docked already; the other moves are to be made again")
  }

  @Test func aClosedWindowIsLeftAlone() {
    let h = Harness()
    let a = h.system.open(app: "Safari")
    h.start()
    var shown = 0
    let session = OnboardingSession(controller: h.controller) { _ in shown += 1 }
    h.run("dock \(a.rawValue) left")
    session.refresh()
    session.go(to: .firstSteps)
    #expect(shown == 0, "never opened")

    session.begin()
    session.go(to: .firstSteps)
    let before = shown
    session.end()
    h.run("zoom \(a.rawValue)")
    session.refresh()
    #expect(shown == before)
  }

  @Test func losingThePermissionGoesBackToTheFirstPage() {
    let h = Harness()
    let mac = Mac()
    mac.facts.accessibility = true
    h.controller.systemFacts = { mac.facts }
    h.start()
    let session = OnboardingSession(controller: h.controller) { _ in }
    session.begin()
    session.go(to: .firstSteps)
    mac.facts.accessibility = false
    session.refresh()
    #expect(session.model.page == .permissions)
    #expect(!session.model.isPrimaryEnabled)
  }
}
