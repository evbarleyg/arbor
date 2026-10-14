import ArborCore
import CoreGraphics
import Foundation

/// Recording traces (docs/TRACES.md, docs/features/F28-traces.md). The recording itself happens in decorators
/// around the platform seams (`Trace/`). The controller's part is the `trace` command, the header, which holds what
/// only it knows, and recording commands.
extension Controller {
  /// The recorder shared by the decorators. The app and the test harness always install them.
  public var traceRecorder: TraceRecorder? { (system as? RecordingWindowSystem)?.recorder }

  /// Does `body`, which performs `command`, as one reaction in the trace. All that a command sets off belongs inside.
  func traced(_ command: Command, from source: CommandSource?, _ body: () -> CommandResult) -> CommandResult {
    guard let recorder = traceRecorder, recorder.isRecording else { return body() }
    // Not part of what is being recorded, and a replay must not start traces of its own.
    if case .trace = command { return body() }
    var result = CommandResult.failure("")
    let (text, typed) = textForTrace(command, recorder)
    recorder.stimulus(.command(text, from: source)) {
      result = body()
      // Only the message: a result's state and text hold window titles.
      let message = typed.map { result.message.replacingOccurrences(of: "“\($0)”", with: "“…”") } ?? result.message
      recorder.record(.done(text, ok: result.ok, message: message))
    }
    return result
  }

  /// `command.text` as a trace may hold it, and what a reply may quote of it and a trace may not.
  ///
  /// What `find` looks for was typed by a person to find a title, and may be any part of one, so searching the text for whole
  /// titles is not enough. It is replaced by what stands for the destination it finds: a window's title token, which in
  /// a replay *is* the window's title, so that the replayed command finds the same window; for a window without a title, a
  /// saved view or a named space, its name in the list. If that would not come out the same, or nothing is found, by `…`,
  /// which finds nothing.
  private func textForTrace(_ command: Command, _ recorder: TraceRecorder) -> (text: String, typed: String?) {
    guard case .find(let query?) = command else { return (command.text, nil) }
    let typed = FinderCandidate.line(query, limit: 80)
    let rows = finderRows()
    guard let best = FinderQuery(query).rank(rows.map(\.candidate)).first else {
      return (command.textForLog, typed)
    }
    // The rows as the replay will have them.
    let replayed = rows.map { row -> FinderCandidate in
      guard case .window(let id) = row.destination, let window = windows[id] else { return row.candidate }
      return FinderCandidate(name: row.name, detail: recorder.window(window).title)
    }
    // A space's name in full outranks everything, and goes into the trace as its token, which is its name in a replay.
    let byName = rows[best.index].place == .namedSpace || replayed[best.index].detail.isEmpty
    let standIn = byName ? replayed[best.index].name : replayed[best.index].detail
    guard FinderQuery(standIn).rank(replayed).first?.index == best.index else { return (command.textForLog, typed) }
    return (Command.find(standIn).text, typed)
  }

  /// Does `body`, which is what Arbor makes of a shortcut's key going down or coming up, as one reaction in the trace. Most
  /// shortcuts are the commands they run, which follow as nested lines; a peek is more than that (Controller+Peek.swift).
  func traced(_ binding: KeyBinding, _ phase: KeyPhase, _ body: () -> Void) {
    guard let recorder = traceRecorder, recorder.isRecording else { return body() }
    recorder.event("shortcut", [binding.chord.text, textForTrace(binding.command, recorder).text, phase.rawValue], body)
  }

  /// Does `body` as one reaction in the trace, under the name of the method the app called.
  func traced(_ name: String, _ arguments: @autoclosure () -> [any Encodable] = [], _ body: () -> Void) {
    guard let recorder = traceRecorder else { return body() }
    recorder.event(name, arguments(), body)
  }

  func trace(_ action: TraceCommand) -> CommandResult {
    guard let recorder = traceRecorder else { return .failure("traces cannot be recorded here") }
    switch action {
    case .status:
      return .success(recorder.statusText)

    case .off:
      guard recorder.isRecording else { return .failure(recorder.statusText) }
      recorder.end(reason: "trace off")
      return .success("trace saved: \(recorder.lastOutcome ?? "")")

    case .note(let text):
      guard recorder.isRecording else { return .failure(recorder.statusText) }
      recorder.record(.note(text))
      return .success("noted")

    case .on(let name):
      guard isRunning else { return .failure(statusText) }
      guard !recorder.isRecording else { return .failure("already \(recorder.statusText); run `trace off` first") }
      let name = name ?? "trace"
      let formatter = ISO8601DateFormatter()
      let date = formatter.string(from: now())  // 2026-10-14T09:30:05Z
      let stamp = date.replacingOccurrences(of: "T", with: "-").filter { $0 != ":" && $0 != "Z" }
      recorder.words = self
      do {
        try recorder.begin(name: name, fileName: "\(stamp)-\(name).jsonl") { titles in
          traceHeader(name: name, date: date, recorder: recorder, titles: &titles)
        }
      } catch {
        return .failure("could not start the trace: \(error)")
      }
      return .success(recorder.statusText)
    }
  }

  /// The world and what Arbor knows of it, read from the system inside the decorator so that reading it
  /// leaves no lines in the trace.
  private func traceHeader(
    name: String, date: String, recorder: TraceRecorder, titles: inout TitleTokens
  ) -> TraceHeader {
    let inner = (system as? RecordingWindowSystem)?.inner ?? system
    titles.displayIDs = Set((inner.displays().map(\.id) + workspaces.keys + dormant.keys).map { $0.rawValue.lowercased() })
    // Settings first: a title's token depends on the patterns of the rules.
    let settings = titles.sanitised(settings)
    var header = TraceHeader(
      name: name, arbor: recorder.arborVersion, os: recorder.osVersion, recorded: date,
      displays: inner.displays().map { TraceDisplay($0, name: titles.displayToken(for: $0.name)) },
      windows: inner.allWindows().map { TraceWindow($0, title: titles.token(for: $0.title)) },
      settings: settings, workspaces: workspaces, focused: inner.focusedWindow(),
      cursor: inner.cursorLocation(), mouseDown: inner.isMouseButtonDown(), thinning: recorder.limits.thinning)
    header.dormant = dormant.mapValues(\.workspace)
    header.parked = parked.sorted()
    header.minimumSizes = minimumSizes
    header.appPlaced = appPlacedFrames
    header.focusHistory = focusHistory
    header.onlyPIDs = filter.onlyPIDs?.sorted()
    header.ignored = filter.ignoredWindowIDs.sorted()
    hideWords(in: &header, &titles)
    return header
  }

  /// For replays: what stands for the names of displays, where it has changed (`TraceReplayer.adoptDisplayNames`).
  public func restoreDisplayNames(_ names: [DisplayID: String]) {
    for index in displays.indices { if let name = names[displays[index].id] { displays[index].name = name } }
  }

  /// Puts back what a trace's header says Arbor had learned and `state.json` does not hold. For replays: call it
  /// before `start()`, on a controller whose store holds the header's workspaces.
  public func restore(from header: TraceHeader) {
    filter.onlyPIDs = header.onlyPIDs.map { Set($0) }
    filter.ignoredWindowIDs = Set(header.ignored)
    minimumSizes = header.minimumSizes
    appPlacedFrames = header.appPlaced
    focusHistory = header.focusHistory
  }
}
