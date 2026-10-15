import ArborCore
import ArborIPC
import CoreGraphics
import Foundation

/// Writes a trace while one is being recorded. The decorators around the platform seams
/// (`RecordingWindowSystem`, `RecordingOverlays`, `RecordingScheduler`) and the controller share one
/// recorder and hand it lines; it stamps them with the time, replaces titles, thins high-frequency lines,
/// and stops by itself at a size or an age.
///
/// The decorators are always installed. While nothing is recorded each of their methods costs one
/// test of `isRecording`.
@MainActor
public final class TraceRecorder {
  public struct Limits: Equatable, Sendable {
    /// Recording stops by itself when the file reaches this size…
    public var bytes = 20 * 1024 * 1024
    /// …or this age, in seconds. `.infinity`: never (arbor-sim, where `wait 3600` takes no time).
    public var seconds: Double = 600
    /// High-frequency lines of one kind closer together than this are thinned (see `thin`).
    public var thinning: Double = 0.05

    public init() {}
  }

  public var limits = Limits()
  /// Seconds that only go forward. Tests use the manual scheduler's clock.
  public var clock: @MainActor () -> Double = { ProcessInfo.processInfo.systemUptime }
  /// Opens the sink for a trace with this file name.
  public var openSink: @MainActor (String) throws -> any TraceSink = TraceRecorder.openFile

  /// A file of that name in `<Arbor home>/traces`.
  public static func openFile(_ name: String) throws -> any TraceSink {
    try FileTraceSink(url: ArborPaths.tracesDirectory.appendingPathComponent(name))
  }
  /// What the header says recorded the trace.
  public var arborVersion: String = {
    let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    // Whoever launches a build that is not a release can say which commit it is.
    return ProcessInfo.processInfo.environment["ARBOR_BUILD"].map { "\(version) (\($0))" } ?? version
  }()
  public var osVersion: String = {
    #if os(macOS)
      "macOS " + ProcessInfo.processInfo.operatingSystemVersionString
    #else
      ProcessInfo.processInfo.operatingSystemVersionString
    #endif
  }()

  public private(set) var isRecording = false
  /// How many traces have been begun. Whoever writes something that has a beginning and an end can tell whether the trace that is
  /// being recorded is still the one that has the beginning.
  public private(set) var tracesBegun = 0
  /// The sink of the trace being recorded, or of the last one.
  public private(set) var sink: (any TraceSink)?
  /// How the last trace ended, for `trace status`.
  public private(set) var lastOutcome: String?
  /// Who knows what the words in a command stand for. Without one, commands are only searched for titles and names already seen.
  public weak var words: (any TraceWordsSource)?
  /// The commands that are running: their text, what the trace shows for it, whether a replay can give the same reply, and the words
  /// of the text that the trace does not show.
  private var shownCommands: [String: (text: String, sameReply: Bool, hidden: Set<String>)] = [:]

  private let writer = TraceWriter()
  private var name = ""
  private var startedAt: Double = 0
  private var bytes = 0
  private var lines = 0
  private var thinned = 0
  private var titles = TitleTokens()
  /// The names of the apps seen in this trace. A window whose title is its app's name gives nothing away.
  private var appNames: Set<String> = []
  /// How many stimuli Arbor is reacting to right now.
  private var depth = 0
  /// High-frequency lines waiting to see what comes next, oldest first.
  private var held: [(key: String, entry: TraceEntry, asked: [TraceEntry])] = []
  /// The key of the held line Arbor is reacting to at the moment, if it has done nothing but ask so far.
  private var reactingToHeld: String?
  /// The last answer to each question recorded by name.
  private var lastAnswers: [String: TraceJSON?] = [:]
  private var lastKept: [String: Double] = [:]

  public init() {}

  // MARK: Starting and stopping

  /// Starts a trace. `header` is given the function that turns titles into tokens and settings into
  /// settings without title patterns; it must use them for everything it puts in the header.
  public func begin(name: String, fileName: String, header: (inout TitleTokens) -> TraceHeader) throws {
    if isRecording { end(reason: "another trace was started") }
    let sink = try openSink(fileName)
    self.sink = sink
    self.name = name
    startedAt = clock()
    bytes = 0
    lines = 0
    thinned = 0
    titles = TitleTokens()
    shownCommands = [:]
    depth = 0
    held = []
    reactingToHeld = nil
    lastAnswers = [:]
    lastKept = [:]
    isRecording = true
    tracesBegun += 1
    do {
      let header = header(&titles)
      appNames = Set(header.windows.map(\.app))
      try write(writer.text(of: header))
    } catch {
      fail(error)
      throw error
    }
    Log.info("trace \(name): recording to \(sink.location)")
  }

  /// Writes the last line and closes the file.
  public func end(reason: String) {
    guard isRecording else { return }
    flush()
    emit(TraceEntry(t: elapsed, line: .end(reason: reason, lines: lines, thinned: thinned)))
    guard isRecording else { return }  // The write failed, and that ended the trace.
    close(outcome: "\(lines) lines, \(reason)")
  }

  private func close(outcome: String) {
    isRecording = false
    held = []
    sink?.close()
    lastOutcome = "\(sink?.location ?? name): \(outcome)"
    Log.info("trace \(name) ended: \(outcome)")
  }

  private func fail(_ error: any Error) {
    Log.error("trace \(name): could not write, so recording stops: \(error)")
    close(outcome: "stopped after \(lines) lines because it could not be written")
  }

  public var statusText: String {
    if isRecording {
      return "recording \(sink?.location ?? name): \(lines) lines, \(bytes / 1024) KB, \(Int(elapsed)) s "
        + "(stops by itself at \(limits.bytes / (1024 * 1024)) MB"
        + (limits.seconds.isFinite ? " or \(Int(limits.seconds / 60)) minutes)" : ")")
    }
    return lastOutcome.map { "not recording; last trace \($0)" } ?? "not recording"
  }

  private var elapsed: Double { max(clock() - startedAt, 0) }

  // MARK: Lines

  /// Records something Arbor did, or a remark.
  public func record(_ line: TraceLine) {
    guard isRecording else { return }
    let entry = TraceEntry(t: elapsed, line: scrubbed(line))
    if goesWithTheHeldLine(entry) { return }
    reactingToHeld = nil
    flush()
    emit(entry)
  }

  /// A question that gets the answer it got last time is not yet a reaction: F09 asks for the modifier keys at every step of a
  /// drag. It shares the fate of the line it was asked about. A new answer is news, and is kept with its line.
  private func goesWithTheHeldLine(_ entry: TraceEntry) -> Bool {
    guard case .other(.read, let name, let arguments, let result) = entry.line else { return false }
    let question = name + arguments.map { " \($0)" }.joined()
    let isNews = lastAnswers.updateValue(result, forKey: question) != .some(result)
    guard !isNews, let key = reactingToHeld, let index = held.firstIndex(where: { $0.key == key }) else { return false }
    held[index].asked.append(entry)
    return true
  }

  /// Free text is searched for the titles this trace has seen, whoever put them there.
  private func scrubbed(_ line: TraceLine) -> TraceLine {
    /// A trace never holds more than the log may.
    func asLogged(_ text: String) -> String { words?.asItMayBeLogged(text) ?? text }
    // Whole titles and whole names before the parts of them, or the parts would be cut out of the whole ones and the rest be left.
    func clean(_ text: String) -> String { titles.withMarks(titles.withNameTokens(titles.scrubbed(asLogged(text), keeping: appNames))) }
    /// The text of a command that is about to run.
    func shown(_ text: String, from source: CommandSource?) -> String {
      // Nobody to ask what the words stand for. Then too, what cannot be read as a command is not written down.
      guard let words else { return (try? Command.parse(text)) == nil ? TitleTokens.unreadable(text) : clean(text) }
      // Working it out takes questions to the window system, which are not Arbor's reaction to anything.
      isRecording = false
      let answer = words.wordsForTrace(inCommand: text, from: source)
      let parts = words.partsOfTitles(inCommand: text)
      isRecording = true
      for name in answer.names.sorted() { _ = titles.nameToken(for: name) }
      // The longest first, so that no part is cut out of another.
      let marked = parts.sorted { $0.count > $1.count }.reduce(answer.text) { titles.withMark(forPart: $1, inCommand: $0) }
      let shown = clean(marked)
      // An app's name goes when a slot is written as a window's number. It is in the trace anyway.
      let apps = appNames.reduce(into: Set<String>()) { $0.formUnion(TitleTokens.words(in: $1)) }
      shownCommands[text] = (shown, answer.sameReply, TitleTokens.words(in: text).subtracting(TitleTokens.words(in: shown)).subtracting(apps))
      return shown
    }
    switch line {
    case .command(let text, let source): return .command(shown(text, from: source), from: source)
    // As when it began: what its words stood for may be gone by now.
    case .done(let text, let ok, let message):
      let shown = shownCommands.removeValue(forKey: text) ?? (clean(text), true, [])
      // The one place where a reply becomes a line. What has a stand-in gets it. Then the backstop: a word that the trace does not show
      // in the command is not shown in its reply either, whoever thought of hiding it there and whichever reply quotes it.
      let standIns = clean(message)
      let reply = TitleTokens.without(shown.hidden, in: standIns)
      let sameReply = shown.sameReply && asLogged(message) == message && reply == standIns
      return .done(shown.text, ok: ok, message: (sameReply ? "" : TraceLine.aboutMark) + reply)
    case .other(.event, "shortcut", let arguments, let result) where arguments.count == 3:
      guard case .string(let text) = arguments[1] else { return line }
      return .other(.event, "shortcut", arguments: [arguments[0], .string(shown(text, from: .shortcut)), arguments[2]], result: result)
    case .note(let text): return .note(clean(text))
    case .raw(let text): return .raw(clean(text))
    case .other(let kind, let name, let arguments, let result):
      return .other(kind, name, arguments: arguments.map { $0.mapStrings(clean) }, result: result?.mapStrings(clean))
    default: return line
    }
  }

  /// Records something Arbor reacts to, then lets it react (`body`), so that what it does follows in the
  /// file. A stimulus that arrives during another's `body` is marked as nested. With a `thinKey` the
  /// line may be thinned.
  public func stimulus(_ line: TraceLine, thinKey: String? = nil, _ body: () -> Void) {
    guard isRecording else { return body() }
    let entry = TraceEntry(t: elapsed, line: scrubbed(line), nested: depth > 0)
    depth += 1
    if let thinKey {
      thin(entry, key: thinKey)
    } else {
      flush()
      emit(entry)
    }
    reactingToHeld = thinKey
    body()
    reactingToHeld = nil
    // A trace that started during `body` begins at depth 0.
    depth = max(depth - 1, 0)
    stopAtLimits()
  }

  /// Records what macOS sent, as it arrived. With a `thinKey` the line may be thinned.
  public func raw(_ text: String, thinKey: String? = nil) {
    guard isRecording else { return }
    guard let thinKey else { return record(.raw(text)) }
    thin(TraceEntry(t: elapsed, line: .raw(text)), key: thinKey)
  }

  /// Records a line of a stage's log of its frames, as a `raw` line. It takes the line and not its text, so that no words can be sent
  /// this way: a `StageLog.Line` holds numbers, and its text them and a few fixed words. So it is not searched for titles and
  /// names as free text is, which would damage it (a space can be named `1`) and take time, sixty times a second, on the very thread whose
  /// stalls the log is there to show. Never thinned.
  public func stage(_ line: StageLog.Line) {
    guard isRecording else { return }
    reactingToHeld = nil
    flush()
    emit(TraceEntry(t: elapsed, line: .raw(line.text)))
  }

  /// The controller is about to apply these settings.
  func settingsWillApply(_ settings: Settings) {
    guard isRecording else { return }
    flush()
    emit(TraceEntry(t: elapsed, line: .settings(titles.sanitisedBindings(titles.sanitised(settings))), nested: depth > 0))
  }

  /// A window as the trace writes it, with a token for its title.
  public func window(_ snapshot: WindowSnapshot) -> TraceWindow {
    appNames.insert(snapshot.appName)
    return TraceWindow(snapshot, title: titles.token(for: snapshot.title))
  }

  /// A display as the trace writes it, with a stand-in for its name.
  public func display(_ snapshot: DisplaySnapshot) -> TraceDisplay {
    TraceDisplay(snapshot, name: titles.displayToken(for: snapshot.name))
  }

  /// Thinning. A drag reports the pointer and the window's frame some sixty times a second each, and
  /// Arbor reacts to few of them. The line is held back until the next line shows what it was worth:
  /// - anything else being recorded (Arbor reacted, or something else happened) writes it first, so the
  ///   last line of a run and every line Arbor reacted to are always kept;
  /// - another line with the same key replaces it, unless the last one kept is `limits.thinning` old.
  private func thin(_ entry: TraceEntry, key: String) {
    if let index = held.firstIndex(where: { $0.key == key }) {
      if held[index].entry.t - (lastKept[key] ?? -.infinity) >= limits.thinning {
        // With whatever was held before it, so that the file stays in order.
        flush(through: index)
      } else {
        held.remove(at: index)
        thinned += 1
      }
    }
    held.append((key, entry, []))
  }

  private func flush(through index: Int? = nil) {
    guard !held.isEmpty else { return }
    let count = index.map { $0 + 1 } ?? held.count
    let due = held.prefix(count)
    held.removeFirst(count)
    for (key, entry, asked) in due {
      lastKept[key] = entry.t
      emit(entry)
      asked.forEach(emit)
    }
  }

  private func emit(_ entry: TraceEntry) {
    guard isRecording else { return }
    do {
      try write(writer.text(of: entry))
    } catch {
      fail(error)
      return
    }
    if case .end = entry.line { return }
    stopAtLimits()
  }

  /// Never in the middle of a reaction: a replay would find Arbor doing more than the trace holds. One reaction is a few lines.
  private func stopAtLimits() {
    guard isRecording, depth == 0 else { return }
    if bytes >= limits.bytes {
      end(reason: "stopped by itself at \(limits.bytes / (1024 * 1024)) MB")
    } else if elapsed >= limits.seconds {
      end(reason: "stopped by itself after \(Int(limits.seconds / 60)) minutes")
    }
  }

  private func write(_ text: String) throws {
    try sink?.write(text)
    bytes += text.utf8.count + 1
    lines += 1
  }
}

/// What only the controller can say about the words in a command (Controller+TraceWords.swift).
@MainActor
public protocol TraceWordsSource: AnyObject {
  /// `text`, the text of a command that is about to run for `source`, with what was typed replaced by what it stands for at this
  /// moment; every name of a space that there is or that the command may hold; and whether the stand-ins will get the same reply
  /// in a replay. Must change nothing.
  func wordsForTrace(inCommand text: String, from source: CommandSource?) -> (text: String, names: Set<String>, sameReply: Bool)
  /// A reply, or whatever else Arbor says, without what it quotes from a file that cannot be read. Must change nothing.
  func asItMayBeLogged(_ text: String) -> String
  /// The parts of titles that the command `text` brings for rules to go by (`rule add … title Payslip`). Each gets a mark, which is
  /// written wherever the part stands: in the command, in its reply, and at the end of the token of every title that contains it. So the
  /// rule matches in a replay what it matched. Must change nothing.
  func partsOfTitles(inCommand text: String) -> [String]
}

// MARK: Requirements without a line of their own

/// For the decorators: one line forwards and records a requirement that `TraceLine` has no case for. The name is the method's. Arguments
/// and results are written as the JSON their `Encodable` gives; a `WindowSnapshot` goes as `recorder.window(snapshot)`, which
/// replaces its title. While nothing is recorded these cost one branch: the arguments are not even put together.
///
///     public func raise(_ window: WindowID) { recorder.call("raise", [window]) { inner.raise(window) } }
///     public func inputActivity() -> InputActivity { recorder.read("inputActivity") { inner.inputActivity() } }
///     public func dragCancelled(_ id: WindowID) { recorder.event("dragCancelled", [id]) { events?.dragCancelled(id) } }
///
/// `TraceReplayer` has the counterparts (`answer(read:)`, `answer(call:)`, `deliverOther`). docs/TRACES.md has the checklist.
extension TraceRecorder {
  /// A question Arbor asks, with the answer.
  public func read<T: Encodable>(
    _ name: String, _ arguments: @autoclosure () -> [any Encodable] = [], _ body: () -> T
  ) -> T {
    guard isRecording else { return body() }
    let value = body()
    record(.other(.read, name, arguments: json(arguments()), result: TraceJSON(encoding: value)))
    return value
  }

  /// Something Arbor asks for that changes what a person can see. Written before the call is made, so that whatever the system
  /// reports from inside it follows.
  public func call(_ name: String, _ arguments: @autoclosure () -> [any Encodable] = [], _ body: () -> Void) {
    guard isRecording else { return body() }
    record(.other(.call, name, arguments: json(arguments())))
    body()
  }

  /// The same with an answer, written when the call returns.
  public func call<T: Encodable>(
    _ name: String, _ arguments: @autoclosure () -> [any Encodable] = [], returning body: () -> T
  ) -> T {
    guard isRecording else { return body() }
    let value = body()
    record(.other(.call, name, arguments: json(arguments()), result: TraceJSON(encoding: value)))
    return value
  }

  /// Something the window system reports.
  public func event(_ name: String, _ arguments: @autoclosure () -> [any Encodable] = [], _ body: () -> Void) {
    guard isRecording else { return body() }
    stimulus(.other(.event, name, arguments: json(arguments())), body)
  }

  /// Something the user does with an overlay.
  public func action(_ name: String, _ arguments: @autoclosure () -> [any Encodable] = [], _ body: () -> Void) {
    guard isRecording else { return body() }
    stimulus(.other(.action, name, arguments: json(arguments())), body)
  }

  private func json(_ values: [any Encodable]) -> [TraceJSON] { values.map { TraceJSON(encoding: $0) } }
}

extension TraceJSON {
  /// What `value` is as JSON. A value that cannot be written becomes null rather than ending the trace.
  public init(encoding value: any Encodable) {
    guard let data = try? JSONEncoder().encode(value), let json = try? JSONDecoder().decode(TraceJSON.self, from: data) else {
      self = .null
      return
    }
    self = json
  }

  /// The value this JSON stands for, or nil if it is not one of that type.
  public func decoded<T: Decodable>(as type: T.Type = T.self) -> T? {
    guard let data = try? JSONEncoder().encode(self) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}

// MARK: Conversions

/// `FinderDestination` as a trace holds it: `{"window":101}`, `{"display":"main","view":3}`, `{"display":"main","space":4}`,
/// `{"command":"dock left"}`.
public struct TraceFinderDestination: Codable, Equatable, Sendable {
  public var window: WindowID?
  public var display: DisplayID?
  public var view: Int?
  public var space: NodeID?
  public var command: String?

  public init(_ destination: FinderDestination) {
    switch destination {
    case .window(let id): window = id
    case .view(let id, let slot): (display, view) = (id, slot)
    case .space(let id, let node): (display, space) = (id, node)
    case .command(let text): command = text
    }
  }

  public var destination: FinderDestination? {
    if let window { return .window(window) }
    if let command { return .command(command) }
    guard let display else { return nil }
    if let view { return .view(display, slot: view) }
    return space.map { .space(display, $0) }
  }
}

/// `InputActivity` as a trace holds it. JSON has no infinity, so a hand that has not been used at all is left out.
public struct TraceInputActivity: Codable, Equatable, Sendable {
  public var pointerIdle: Double?
  public var keyboardIdle: Double?
  public var keyPresses: UInt32

  public init(_ activity: InputActivity) {
    pointerIdle = activity.pointerIdle.isFinite ? activity.pointerIdle : nil
    keyboardIdle = activity.keyboardIdle.isFinite ? activity.keyboardIdle : nil
    keyPresses = activity.keyPresses
  }

  public var activity: InputActivity {
    InputActivity(pointerIdle: pointerIdle ?? .infinity, keyboardIdle: keyboardIdle ?? .infinity, keyPresses: keyPresses)
  }
}

extension TraceWindow {
  /// `title` is the token that stands for the snapshot's title.
  public init(_ snapshot: WindowSnapshot, title: String) {
    self.init(
      id: snapshot.id, pid: snapshot.pid, bundle: snapshot.bundleID, app: snapshot.appName, title: title,
      frame: snapshot.frame, minimized: snapshot.isMinimized, hidden: snapshot.isHidden,
      offSpace: !snapshot.isOnActiveSpace, fullScreen: snapshot.isFullScreen, fixedSize: !snapshot.isResizable)
  }
}

extension WindowSnapshot {
  public init(_ window: TraceWindow) {
    self.init(
      id: window.id, pid: window.pid, bundleID: window.bundle, appName: window.app, title: window.title,
      frame: window.frame, isMinimized: window.minimized, isHidden: window.hidden,
      isOnActiveSpace: !window.offSpace, isFullScreen: window.fullScreen, isResizable: !window.fixedSize)
  }
}

extension TraceDisplay {
  /// `name` is what stands for the display's name (`TitleTokens.displayToken`), which can be a person's ("Robin's iPad").
  public init(_ display: DisplaySnapshot, name: String = "") {
    self.init(
      id: display.id, frame: display.frame, visible: display.visibleFrame, main: display.isMain, name: name,
      builtIn: display.isBuiltIn)
  }
}

extension DisplaySnapshot {
  public init(_ display: TraceDisplay) {
    self.init(
      id: display.id, frame: display.frame, visibleFrame: display.visible, isMain: display.main,
      name: display.name.isEmpty ? nil : display.name, isBuiltIn: display.builtIn)
  }
}
