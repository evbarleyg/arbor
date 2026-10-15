import ArborCore
import ArborKit
import ArborTesting
import Foundation
import Testing

/// Runs the worked examples of docs/SCRIPTING.md: the scripts as they stand on the page, under bash, with an `arborctl` on
/// their PATH that is the real `Arborctl.run` talking to a real controller over fake windows.
@Suite @MainActor struct ScriptingExampleTests {
  /// The fenced block that follows `<!-- example: name -->`.
  static func example(_ name: String) throws -> String {
    let markdown = try String(contentsOf: DocTranscript.root.appendingPathComponent("docs/SCRIPTING.md"), encoding: .utf8)
    let lines = markdown.components(separatedBy: "\n")
    let marker = try #require(lines.firstIndex(of: "<!-- example: \(name) -->"))
    #expect(lines[marker + 1] == "```bash")
    let end = try #require(lines[(marker + 2)...].firstIndex(of: "```"))
    return lines[(marker + 2)..<end].joined(separator: "\n") + "\n"
  }

  struct Run {
    var output: String
    var code: Int32
    /// The arguments of every call, in order.
    var arborctl: [[String]]
    var sketchybar: [String]
  }

  /// Runs `script`. With no harness, Arbor is not running.
  ///
  /// The stand-in `arborctl` leaves its arguments in a file and waits for the answer in another; this side, which owns the
  /// controller, looks for requests while the script runs.
  func run(_ script: String, _ arguments: [String] = [], environment: [String: String] = [:], against harness: Harness?) throws -> Run {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("arbor-example-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    func install(_ name: String, _ text: String) throws {
      let path = folder.appendingPathComponent(name).path
      try text.write(toFile: path, atomically: true, encoding: .utf8)
      try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path)
    }
    try install("example.sh", script)
    try install(
      "arborctl",
      """
      #!/bin/sh
      dir=$(dirname "$0")
      for argument in "$@"; do printf '%s\\n' "$argument"; done > "$dir/request.$$.tmp"
      mv "$dir/request.$$.tmp" "$dir/request.$$"
      while [ ! -f "$dir/reply.$$.code" ]; do sleep 0.01; done
      cat "$dir/reply.$$.out"
      cat "$dir/reply.$$.err" >&2
      exit "$(cat "$dir/reply.$$.code")"
      """)
    try install("sketchybar", "#!/bin/sh\necho \"$*\" >> \"$(dirname \"$0\")/sketchybar.log\"\n")

    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = [folder.appendingPathComponent("example.sh").path] + arguments
    process.environment = ["PATH": "\(folder.path):/usr/bin:/bin", "HOME": folder.path].merging(environment) { $1 }
    let output = Pipe()
    process.standardOutput = output
    process.standardError = output
    try process.run()

    struct NotRunning: Error, CustomStringConvertible { let description = "Arbor is not running" }
    var calls: [[String]] = []
    let deadline = Date().addingTimeInterval(20)
    while process.isRunning, Date() < deadline {
      for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] where name.hasPrefix("request.") && !name.hasSuffix(".tmp") {
        let id = name.dropFirst("request.".count)
        let request = try String(contentsOf: folder.appendingPathComponent(name), encoding: .utf8)
        try FileManager.default.removeItem(at: folder.appendingPathComponent(name))
        let words = request.split(separator: "\n", omittingEmptySubsequences: false).dropLast().map(String.init)
        calls.append(words)
        var (out, err) = ("", "")
        let code = Arborctl.run(
          words,
          send: { line, _ in
            guard let harness else { throw NotRunning() }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return String(decoding: try encoder.encode(harness.run(line)), as: UTF8.self)
          },
          emit: { answer in
            if let text = answer.out { out += text + "\n" }
            if let text = answer.err { err += "arborctl: \(text)\n" }
          })
        try out.write(to: folder.appendingPathComponent("reply.\(id).out"), atomically: true, encoding: .utf8)
        try err.write(to: folder.appendingPathComponent("reply.\(id).err"), atomically: true, encoding: .utf8)
        try String(code).write(to: folder.appendingPathComponent("reply.\(id).code"), atomically: true, encoding: .utf8)
      }
      Thread.sleep(forTimeInterval: 0.005)
    }
    if process.isRunning {
      process.terminate()
      Issue.record("the script did not end")
    }
    process.waitUntilExit()
    let printed = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    let log = (try? String(contentsOf: folder.appendingPathComponent("sketchybar.log"), encoding: .utf8)) ?? ""
    return Run(
      output: printed.trimmingCharacters(in: .newlines), code: process.terminationStatus, arborctl: calls,
      sketchybar: log.split(separator: "\n").map(String.init))
  }

  func harness() -> Harness {
    let h = Harness()
    for app in ["Safari", "Mail", "Notes", "Visual Studio Code"] { h.system.open(app: app) }
    h.start()
    h.run("layout Safari | (Mail / Notes) | 'Visual Studio Code'")
    return h
  }

  // MARK: Raycast

  @Test func theRaycastScriptFramesTheAppItIsGiven() throws {
    let h = harness()
    let run = try run(Self.example("raycast"), ["Mail"], against: h)
    #expect(run.code == 0)
    #expect(run.output == "Framed Mail")
    #expect(run.arborctl == [["zoom", "Mail"]])
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: WindowID(102)))
  }

  @Test func aNameWithSpacesArrivesAsOneName() throws {
    let h = harness()
    let run = try run(Self.example("raycast"), ["Visual Studio Code"], against: h)
    #expect(run.code == 0 && run.output == "Framed Visual Studio Code")
    #expect(h.workspace.camera == h.workspace.tree.leaf(containing: WindowID(104)))
  }

  @Test func itShowsArborsReasonWhenThereIsNoSuchWindow() throws {
    let run = try run(Self.example("raycast"), ["Slack"], against: harness())
    #expect(run.code == 1)
    #expect(run.output == "no window of Slack; `windows` lists them")
  }

  @Test func itSaysSoWhenArborIsNotRunning() throws {
    let run = try run(Self.example("raycast"), ["Mail"], against: nil)
    #expect(run.code == 1)
    #expect(run.output == "Arbor is not running")
  }

  // MARK: SketchyBar

  @Test func theSketchyBarPluginShowsWhatTheViewHolds() throws {
    let h = harness()
    var run = try run(Self.example("sketchybar"), environment: ["NAME": "arbor"], against: h)
    #expect(run.code == 0 && run.output.isEmpty)
    #expect(run.arborctl == [["where"]])
    #expect(run.sketchybar == ["--set arbor drawing=on label=everything"])

    h.run("zoom Mail")
    h.run("out")
    run = try self.run(Self.example("sketchybar"), environment: ["NAME": "arbor"], against: h)
    #expect(run.sketchybar == ["--set arbor drawing=on label=Mail and Notes  +2"])
  }

  @Test func itHidesTheItemWhenArborIsPausedOrNotRunning() throws {
    let h = harness()
    h.run("pause")
    #expect(try run(Self.example("sketchybar"), environment: ["NAME": "arbor"], against: h).sketchybar == ["--set arbor drawing=off"])
    #expect(try run(Self.example("sketchybar"), environment: ["NAME": "arbor"], against: nil).sketchybar == ["--set arbor drawing=off"])
  }
}
