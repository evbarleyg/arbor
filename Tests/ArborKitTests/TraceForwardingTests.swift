import Foundation
import Testing

/// The recording decorators stand between the controller and the real window system, overlays and scheduler. A requirement added to
/// one of those protocols must be forwarded by its decorator. The compiler insists on that only while the requirement has no
/// default implementation; with one, everything compiles, the decorator answers with the default, and the real
/// implementation is never called again. So these tests read the sources: every `func` in a protocol must be
/// declared by everything that wraps it.
@Suite struct TraceForwardingTests {
  private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent()

  private func source(_ path: String) throws -> String {
    try String(contentsOf: Self.root.appendingPathComponent(path), encoding: .utf8)
  }

  /// The names of the functions a protocol requires: those between its opening brace and the matching one.
  private func requirements(of name: String, in text: String) throws -> [String] {
    let start = try #require(text.range(of: "protocol \(name):"), "protocol \(name) has moved")
    var depth = 0
    var body = ""
    for character in text[start.upperBound...] {
      if character == "{" { depth += 1 }
      if character == "}" {
        depth -= 1
        if depth == 0 { break }
      }
      if depth > 0 { body.append(character) }
    }
    return body.matches(of: /func\s+([A-Za-z0-9_]+)\s*\(/).map { String($0.1) }
  }

  @Test(arguments: [
    // arbor-fakemac watches the same two protocols for the rehearsals of Mac shell scripts: with a default it would quietly rehearse a no-op.
    (
      "WindowSystem", "Platform/WindowSystem.swift",
      ["Sources/ArborKit/Trace/RecordingWindowSystem.swift", "Sources/ArborTesting/TraceReplayer.swift", "Sources/arbor-fakemac/Arbor.swift"]
    ),
    ("WindowSystemEvents", "Platform/WindowSystem.swift", ["Sources/ArborKit/Trace/RecordingWindowSystem.swift"]),
    ("OverlayPresenter", "Platform/OverlayPresenter.swift", ["Sources/ArborKit/Trace/RecordingOverlays.swift", "Sources/arbor-fakemac/Arbor.swift"]),
    ("OverlayActions", "Platform/OverlayPresenter.swift", ["Sources/ArborKit/Trace/RecordingOverlays.swift"]),
    ("Scheduler", "Platform/Scheduler.swift", ["Sources/ArborKit/Trace/RecordingScheduler.swift"]),
  ])
  func everyRequirementIsForwardedByWhateverWrapsTheProtocol(name: String, file: String, wrappers: [String]) throws {
    let required = try requirements(of: name, in: try source("Sources/ArborKit/" + file))
    #expect(!required.isEmpty)
    for wrapper in wrappers {
      let text = try source(wrapper)
      for function in required {
        #expect(
          text.contains("func \(function)("),
          """
          \(wrapper) does not forward `\(function)`, which \(name) requires. If it has a default implementation everything compiles, but \
          the real implementation is never reached. Forward it, and see docs/TRACES.md, "When a protocol in Platform/ gains a requirement".
          """)
      }
    }
  }

  /// What stands between a brace at or after `start` and the one that closes it.
  private func block(in text: String, from start: String.Index) -> String {
    var depth = 0
    var body = ""
    for character in text[start...] {
      if character == "{" { depth += 1 }
      if character == "}" {
        depth -= 1
        if depth == 0 { break }
      }
      if depth > 0 { body.append(character) }
    }
    return body
  }

  /// The product runs inside the decorators, so declaring a member is not enough: a body that does not pass it on is a feature that is
  /// dead in the product while every test on the bare fakes stays green.
  @Test(arguments: [
    ("WindowSystem", "Platform/WindowSystem.swift", "Sources/ArborKit/Trace/RecordingWindowSystem.swift", "inner."),
    ("WindowSystemEvents", "Platform/WindowSystem.swift", "Sources/ArborKit/Trace/RecordingWindowSystem.swift", "events?."),
    ("OverlayPresenter", "Platform/OverlayPresenter.swift", "Sources/ArborKit/Trace/RecordingOverlays.swift", "inner."),
    ("OverlayActions", "Platform/OverlayPresenter.swift", "Sources/ArborKit/Trace/RecordingOverlays.swift", "actions?."),
    ("Scheduler", "Platform/Scheduler.swift", "Sources/ArborKit/Trace/RecordingScheduler.swift", "inner."),
  ])
  func everyDecoratorPassesOnWhatItDeclares(name: String, file: String, decorator: String, wrapped: String) throws {
    let text = try source(decorator)
    for function in try requirements(of: name, in: try source("Sources/ArborKit/" + file)) {
      let start = try #require(text.range(of: "func \(function)("), "\(decorator) does not declare `\(function)`")
      #expect(
        block(in: text, from: start.lowerBound).contains("\(wrapped)\(function)("),
        "`\(function)` in \(decorator) never calls `\(wrapped)\(function)(…)`: the real implementation is not reached, in the product either")
    }
  }

  /// Properties can be required, and given defaults, like functions.
  @Test(arguments: [
    ("WindowSystem", "Platform/WindowSystem.swift", ["Sources/ArborKit/Trace/RecordingWindowSystem.swift", "Sources/ArborTesting/TraceReplayer.swift", "Sources/arbor-fakemac/Arbor.swift"]),
    ("WindowSystemEvents", "Platform/WindowSystem.swift", ["Sources/ArborKit/Trace/RecordingWindowSystem.swift"]),
    ("OverlayPresenter", "Platform/OverlayPresenter.swift", ["Sources/ArborKit/Trace/RecordingOverlays.swift", "Sources/arbor-fakemac/Arbor.swift"]),
    ("OverlayActions", "Platform/OverlayPresenter.swift", ["Sources/ArborKit/Trace/RecordingOverlays.swift"]),
    ("Scheduler", "Platform/Scheduler.swift", ["Sources/ArborKit/Trace/RecordingScheduler.swift"]),
  ])
  func everyRequiredPropertyIsDeclaredByWhateverWrapsTheProtocol(name: String, file: String, wrappers: [String]) throws {
    let text = try source("Sources/ArborKit/" + file)
    let start = try #require(text.range(of: "protocol \(name):"), "protocol \(name) has moved")
    let properties = block(in: text, from: start.upperBound).matches(of: /var\s+([A-Za-z0-9_]+)\s*:/).map { String($0.1) }
    for wrapper in wrappers {
      let text = try source(wrapper)
      for property in properties {
        #expect(text.contains("var \(property):"), "\(wrapper) does not declare `\(property)`, which \(name) requires")
      }
    }
  }

  private func swiftFiles() throws -> [String] {
    let sources = Self.root.appendingPathComponent("Sources")
    let found = FileManager.default.enumerator(atPath: sources.path)?.compactMap { $0 as? String } ?? []
    return found.filter { $0.hasSuffix(".swift") }.sorted().map { "Sources/" + $0 }
  }

  private static let wrapped = ["WindowSystem", "WindowSystemEvents", "OverlayPresenter", "OverlayActions", "Scheduler"]

  /// A member that is written only in an extension of a protocol is not a requirement: called through the protocol, it is the extension's
  /// own body that runs, whatever an implementation declares under the same name. With or without decorators.
  @Test func noMemberOfAWrappedProtocolLivesOnlyInAnExtension() throws {
    var required: [String: Set<String>] = [:]
    for (name, file) in [
      ("WindowSystem", "WindowSystem"), ("WindowSystemEvents", "WindowSystem"), ("OverlayPresenter", "OverlayPresenter"),
      ("OverlayActions", "OverlayPresenter"), ("Scheduler", "Scheduler"),
    ] {
      required[name] = Set(try requirements(of: name, in: try source("Sources/ArborKit/Platform/\(file).swift")))
    }
    var extensions = 0
    for file in try swiftFiles() {
      let text = try source(file)
      for name in Self.wrapped {
        var rest = text[...]
        while let found = rest.range(of: "\nextension \(name) {") {
          extensions += 1
          for match in block(in: text, from: found.lowerBound).matches(of: /\n  (?:public )?func\s+([A-Za-z0-9_]+)\s*[(<]/) {
            #expect(
              required[name]!.contains(String(match.1)),
              "`\(match.1)` in an extension of \(name) (\(file)) is not among the protocol's requirements, so no implementation of it is ever called through the protocol")
          }
          rest = rest[found.upperBound...]
        }
      }
    }
    #expect(extensions >= 2, "the reader no longer finds the extensions with the defaults")
  }

  /// arbor-fakemac's two wrappers were written without anybody thinking of these tests. Whatever conforms to a wrapped protocol is either the
  /// real thing or a fake, which answers for itself, or it wraps another, and then it belongs in the rows above.
  @Test func everyTypeThatConformsToAWrappedProtocolIsKnownHere() throws {
    let answerForThemselves: Set = ["AXWindowSystem", "FakeWindowSystem", "AppKitOverlays", "FakeOverlays", "MainQueueScheduler", "ManualScheduler"]
    let wrapAnother: Set = [
      "RecordingWindowSystem", "ReplayWindowSystem", "WatchedSystem", "RecordingOverlays", "WatchedOverlays", "RecordingScheduler",
    ]
    var found: Set<String> = []
    for file in try swiftFiles() {
      for match in try source(file).matches(of: /(?:class|struct|actor)\s+([A-Za-z0-9_]+)\s*:\s*([^{\n]+)\{/) {
        let conformances = match.2.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard conformances.contains(where: { ["WindowSystem", "OverlayPresenter", "Scheduler"].contains($0) }) else { continue }
        found.insert(String(match.1))
        #expect(
          answerForThemselves.contains(String(match.1)) || wrapAnother.contains(String(match.1)),
          """
          `\(match.1)` (\(file)) conforms to a protocol the product reaches through wrappers. If it wraps another implementation, add its file to the rows of \
          everyRequirementIsForwardedByWhateverWrapsTheProtocol, or a requirement with a default will silently stop there. Then list it here.
          """)
      }
    }
    #expect(found == answerForThemselves.union(wrapAnother), "listed here and gone from the sources: \(answerForThemselves.union(wrapAnother).subtracting(found))")
  }

  /// A trace holds whole snapshots. A field added to one must travel too, or replays quietly lose it.
  @Test(arguments: [("WindowSnapshot", "snapshot"), ("DisplaySnapshot", "display")])
  func everyFieldOfASnapshotIsCarriedByATrace(type: String, variable: String) throws {
    let text = try source("Sources/ArborKit/Platform/WindowSystem.swift")
    let start = try #require(text.range(of: "public struct \(type):"), "\(type) has moved")
    let end = try #require(text[start.upperBound...].range(of: "public init("))
    // Stored properties: declared before the initialiser, without a body.
    let fields = text[start.upperBound..<end.lowerBound].matches(of: /public var ([A-Za-z0-9_]+): [^{\n]+\n/).map { String($0.1) }
    #expect(fields.count >= 4)
    let conversions = try source("Sources/ArborKit/Trace/TraceRecorder.swift")
    // (A display's name is carried as a stand-in, never as it is: TraceWordsTests.)
    for field in fields {
      #expect(
        conversions.contains("\(variable).\(field)"),
        "\(type).\(field) is not written into traces: add it to the trace's type in ArborCore/Trace.swift and to both conversions in TraceRecorder.swift")
    }
  }

  /// What reaches the controller through the protocols is recorded by the decorators. What the app calls on the controller itself is
  /// not, unless the method sees to it. F51's `shortcut` and F56's `perform(_:from:)` came in beside `perform(_:)`, and traces
  /// missed them until a scenario happened to use them.
  @Test func everyWayIntoTheControllerIsRecordedOrChangesNothing() throws {
    /// Recorded where they are declared: look for `traced` or `traceRecorder` in them.
    /// `takeInSettingsFile` does nothing but `apply`.
    let recordedByThemselves: Set = [
      "perform", "shortcut", "apply", "settingsFileMayHaveChanged", "takeInSettingsFile", "callSignalsChanged",
    ]
    /// They ask, or belong to starting and ending, which a trace's header and its `start` and `stop` lines stand for.
    let changeNothing: Set = [
      // They read a text.
      "asItMayBeLogged", "partsOfTitles",
      // TraceWordsTests.workingOutTheWordsLeavesNoMarkOnWhichHandLeads holds it to that.
      "wordsForTrace",
      // Only replays call it.
      "restoreDisplayNames",
      "admit", "asciiDrawing", "display", "manages", "observe", "restore", "saveNow", "snapshot", "workspaceID", "start", "shutdown",
      "isPinned", "isFilled", "desktopGuardZones", "role", "displayForCommands", "options",
      "freshLayout", "eventSummary", "nextStepLabel", "nextStepTitle",
      // F20. `askingForTheNamesDoesNotChangeWhatTheNextShortcutFollows` holds them to it.
      "spaceName", "namedSpaces", "namedSpacesMenu",
      // Remembers only what it has written to the log, so as not to write it again.
      "logSystemShortcutClashes",
      // Logout has begun: a pause, which stops the window system and so ends the trace with its `stop` line.
      "sessionIsEnding",
      // Which keys mean which shortcut. A trace holds the shortcut.
      "keyboardLayoutChanged",
      // ADD NEW ONES BELOW, EACH FEATURE ON A LINE OF ITS OWN: two branches that each add a line merge by themselves.
      // It asks macOS for the Accessibility permission and writes the answer into the trace as a read, which a replay is given. It is called from
      // scheduled work, commands and events, which are recorded. The other only keeps count of visits to System Settings.
      "askAboutAccessibility", "shouldOpenAccessibilitySettings", "sendToAccessibilitySettings",
      // F10, F42, F46. What the menu bar item, the menu, `doctor` and the welcome window show: they ask, and write to the log.
      "menuBarModel", "menuModel", "describe", "doctorReport", "check", "logSetupProblems", "logSkippedBindings", "onboardingModel", "pageToWelcomeOn",
      // The same files' `MenuBarWatcher` and `OnboardingSession`, and `noteWelcomed`: they change only what Arbor knows about its own
      // face (how wide an item the menu bar has room for, which page is open, that the window has been seen). No window, view or
      // layout depends on it. Their scheduled work (`menu-bar`, `menu-bar-room`, a `save`) has no effect a replay would miss.
      "update", "tryAgain", "begin", "end", "refresh", "go", "noteWelcomed", "welcome",
      // F42. `OnboardingSession` is told how the command of a row's button ended, to say so in the window. The command itself went through `perform`.
      "actionEnded",
      // F42. macOS's own switches go back as they were. No window, view or layout depends on it; a drag asks `macTiling()`, which is recorded.
      "giveMacSwitchesBack",
      "invariantViolations", "expectedTilesAndSeams",
      // F26. Where the minimap is, for whatever shares the bottom of the display with it.
      "minimapFrame",
      // F15. What the overlays should be showing, for the chaos lab: it asks, as `expectedTilesAndSeams` does.
      "expectedScene",
      // What even Show Everything leaves out of view, for the chaos lab: it asks, as `freshLayout` does.
      "layoutOfEverything",
      // What the presenter is told ahead of a motion is said again. No window, view or layout depends on it, and its scheduled work (`rehearsal`)
      // only tells the presenter.
      "rehearseAfresh",
      // Which shortcuts the app is to hold, and what macOS said. The first asks (`activeBindings`, which follows no hand) and remembers what it
      // handed out and logged; the second sets what menus, `doctor`, the welcome window and the log go by. No window, view or layout depends on either.
      "shortcutsToRegister", "shortcutsWereRegistered",
    ]
    /// Everything they do, they do by calling `perform`. A gesture that moves the view by itself (F16) will have to be recorded.
    let endAsCommands: Set = ["gesture"]
    let platform = try source("Sources/ArborKit/Platform/WindowSystem.swift")
    let overlays = try source("Sources/ArborKit/Platform/OverlayPresenter.swift")
    let known = recordedByThemselves.union(changeNothing).union(endAsCommands)
      .union(try requirements(of: "WindowSystemEvents", in: platform)).union(try requirements(of: "OverlayActions", in: overlays))

    let folder = Self.root.appendingPathComponent("Sources/ArborKit/Controller")
    let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasPrefix("Controller") }.sorted()
    #expect(files.count > 10)
    var found: Set<String> = []
    for file in files {
      // Two spaces: a member of `Controller` or of an extension of it, not of a type nested in it.
      for match in try source("Sources/ArborKit/Controller/" + file).matches(of: /\n  public func ([A-Za-z0-9_]+)\s*[(<]/) {
        let name = String(match.1)
        found.insert(name)
        #expect(
          known.contains(name),
          """
          `Controller.\(name)` in \(file) is a new way into the controller. If it can change anything, a trace has to hold it or replays \
          will not do what the recording did: see docs/TRACES.md, "When the controller gains a way in". Then add it to the right list here.
          """)
      }
    }
    #expect(found.isSuperset(of: recordedByThemselves), "the reader of the controller's sources no longer finds what is there")
    for name in recordedByThemselves.union(changeNothing).union(endAsCommands) {
      #expect(found.contains(name), "`\(name)` is gone from the controller: take it off the list")
    }
  }

  /// The test above takes a report or an overlay's action for recorded because the decorators record them. That holds for what comes through the
  /// decorators. `ArborApp` handed `applicationActivated` and `pointerPressed` to the controller itself, so no trace of a real Mac held an app
  /// coming forward, which is the only sign of ⌘Tab.
  @Test func nobodyHandsTheControllerAReportPastTheRecorder() throws {
    let names = Set(try requirements(of: "WindowSystemEvents", in: source("Sources/ArborKit/Platform/WindowSystem.swift")))
      .union(try requirements(of: "OverlayActions", in: source("Sources/ArborKit/Platform/OverlayPresenter.swift")))
      // Records itself.
      .subtracting(["perform"])
    #expect(names.contains("applicationActivated") && names.contains("tileActivated"))
    var read = 0
    // The controller may call itself, and tests and the labs say what they mean to.
    for file in try swiftFiles() where !file.hasPrefix("Sources/ArborKit/Controller/") && !file.hasPrefix("Sources/ArborTesting/") {
      read += 1
      for match in try source(file).matches(of: /controller\??\.([A-Za-z0-9_]+)\(/) where names.contains(String(match.1)) {
        Issue.record("\(file) calls `controller.\(match.1)`, which no trace will hold: `controller.reports.\(match.1)` goes through the recorder")
      }
    }
    #expect(read > 50)
  }

  @Test func theReaderOfProtocolsFindsWhatIsThere() throws {
    let text = try source("Sources/ArborKit/Platform/WindowSystem.swift")
    let calls = try requirements(of: "WindowSystem", in: text)
    #expect(calls.contains("setFrame") && calls.contains("isMouseButtonDown") && !calls.contains("windowAppeared"))
    let events = try requirements(of: "WindowSystemEvents", in: text)
    #expect(events.contains("windowAppeared") && events.contains("resizeEnded") && !events.contains("setFrame"))
  }
}
