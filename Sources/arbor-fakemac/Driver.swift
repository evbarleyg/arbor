import Foundation

/// What one line of the world printed, and the exit code of the stand-in that wrote it.
struct Reply {
  var out = ""
  var err = ""
  var code: Int32 = 0

  static func printing(_ text: String) -> Reply { Reply(out: text + "\n") }
}

/// Ends a line early with a message on stderr. 64 is the real pointer tool's exit code for a bad command line.
struct Refusal: Error {
  var message: String
  var code: Int32 = 64
}

/// One line of the world file, with the `note` lines that follow it.
struct Entry {
  var fields: [String]
  /// What the line read from outside the world when it first ran, in the order it read it.
  var notes: [Note] = []

  struct Note {
    var name: String
    /// Nil: there was no such file.
    var data: Data?
  }

  /// Tabs separate fields and a newline ends the line, so inside a field they are written as \t and \n.
  static func encode(_ fields: [String]) -> String {
    fields.map { field in
      field.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\t", with: "\\t")
        .replacingOccurrences(of: "\n", with: "\\n")
    }.joined(separator: "\t")
  }

  static func decode(_ line: String) -> [String] {
    line.split(separator: "\t", omittingEmptySubsequences: false).map { field in
      guard field.contains("\\") else { return String(field) }
      var result = ""
      var escaped = false
      for character in field {
        if escaped {
          result.append(character == "t" ? "\t" : character == "n" ? "\n" : character)
          escaped = false
        } else if character == "\\" {
          escaped = true
        } else {
          result.append(character)
        }
      }
      return result
    }
  }

  static func encode(_ note: Note) -> String {
    encode(["note", note.name, note.data.map { "=" + $0.base64EncodedString() } ?? "-"])
  }

  /// Reads a world file. A last line without its newline is still being written by someone else: a
  /// stand-in that only asks does not take the lock.
  static func parse(_ text: String) -> [Entry] {
    var entries: [Entry] = []
    var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    lines.removeLast()
    for line in lines where !line.isEmpty {
      let fields = decode(String(line))
      if fields[0] == "note", fields.count == 3, !entries.isEmpty {
        let data = fields[2].hasPrefix("=") ? Data(base64Encoded: String(fields[2].dropFirst())) : nil
        entries[entries.count - 1].notes.append(Note(name: fields[1], data: data))
      } else {
        entries.append(Entry(fields: fields))
      }
    }
    return entries
  }
}

/// Turns one invocation of a stand-in into a line of the session's world, replays the world, prints what the
/// last line printed and leaves on disk what the real Arbor would have left.
@MainActor
enum Driver {
  static let usage = """
    usage: arbor-fakemac pointer|arborctl|open|lsappinfo <arguments…> | sleep <seconds>
           arbor-fakemac app-start <pid> <bundle id> <name> <arguments…>
           arbor-fakemac app-request <pid> <line> | app-exit <pid>
           arbor-fakemac arbor-start <pid> <bundled: 0 or 1> [watchdog=<pid>]
           arbor-fakemac arbor-term <pid> | arbor-watchdog <pid>
           arbor-fakemac replay <world file>
    The session is the one ARBOR_HOME belongs to. See scripts/mac-shell/rehearse.sh.
    """

  /// The launch options the real Arbor reads from its environment; `arbor-start` records them in its line.
  static let launchVariables = [
    "ARBOR_ONLY_PIDS", "ARBOR_NO_HOTKEYS", "ARBOR_NO_STATUS_ITEM", "ARBOR_NO_PROMPT", "ARBOR_DEBUG",
    "ARBOR_NO_WATCHDOG", "ARBOR_RESCUE", "ARBOR_RESTARTS",
  ]

  static func run(_ arguments: [String]) -> Int32 {
    guard let role = arguments.first else { return complain(usage) }
    if role == "replay" {
      guard arguments.count == 2 else { return complain(usage) }
      return trace(arguments[1])
    }
    guard
      [
        "pointer", "arborctl", "open", "lsappinfo", "sleep", "app-start", "app-request", "app-exit",
        "arbor-start", "arbor-term", "arbor-watchdog",
      ].contains(role)
    else { return complain("arbor-fakemac: unknown role \(role)\n\(usage)") }

    let environment = ProcessInfo.processInfo.environment
    var fields = arguments
    // Without a session (lib.sh has not been sourced) there is an empty Mac, and nothing done to it lasts.
    let session = environment["ARBOR_HOME"].flatMap {
      $0.isEmpty ? nil : Session(home: $0, environment: environment)
    }
    if role == "arbor-start" {
      guard let session else { return complain("Arbor (rehearsal): ARBOR_HOME is not set") }
      fields += ["home=\(session.home)", "socket=\(session.socket)"]
      fields += launchVariables.compactMap { name in environment[name].map { "\(name)=\($0)" } }
    }
    if role == "arbor-watchdog", let restarts = environment["ARBOR_RESTARTS"] {
      fields.append("ARBOR_RESTARTS=\(restarts)")
    }

    // A world begins with its display, so that every replay has the one the session began with.
    let wanted =
      environment["ARBOR_REHEARSAL_DISPLAY"].flatMap { $0.isEmpty ? nil : $0 } ?? World.defaultDisplay
    guard World.display(wanted) != nil else {
      return complain(
        "arbor-fakemac: ARBOR_REHEARSAL_DISPLAY is \"\(wanted)\", not like \"\(World.defaultDisplay)\": "
          + "width x height, the height of the menu bar, the height of the Dock")
    }
    let beginning = Entry(fields: ["display", wanted])

    session?.noticeKilledArbor()
    guard let session, FileManager.default.fileExists(atPath: session.folder) else {
      silenceLog()
      return finish(replay([beginning, Entry(fields: fields)], lastAsks: true, session: nil).reply)
    }
    var entries = Entry.parse(session.worldText())
    if entries.isEmpty { entries = [beginning] }
    // What is said to an Arbor that is not there changes nothing, and the answer needs no history.
    if ["arborctl", "open", "arbor-term"].contains(role), !session.arborRuns {
      silenceLog()
      return finish(replay([entries[0], Entry(fields: fields)], lastAsks: true, session: session).reply)
    }
    if World.onlyAsks(fields) {
      silenceLog()
      // It looks at the disk too, and writes nothing down: a script that saves settings.json and then only
      // looks sees the edit applied, and the next line that changes something takes note of it.
      let asked = entries + [Entry(fields: fields)]
      return finish(replay(asked, lastAsks: true, live: true, session: session).reply)
    }

    session.lock()
    defer { session.unlock() }
    // Again, now that nobody else can add to it.
    entries = Entry.parse(session.worldText())
    let lines = entries.isEmpty ? [Entry.encode(beginning.fields)] : []
    if entries.isEmpty { entries = [beginning] }
    session.redirectLog()
    let (world, reply) = replay(
      entries + [Entry(fields: fields)], lastAsks: false, live: true, session: session)
    // The line and its notes in one piece: those who only ask do not take the lock, and must not find one
    // without the other.
    session.append(
      (lines + [Entry.encode(fields)] + world.newNotes.map { Entry.encode($0) }).joined(separator: "\n"))
    session.publish(world)
    return finish(reply)
  }

  /// The world that `entries` begin: their first line says what display it has.
  private static func newWorld(_ entries: [Entry], socket: String) -> World {
    let first = entries.first?.fields ?? []
    let display = first.count == 2 && first[0] == "display" ? World.display(first[1]) : nil
    return World(socket: socket, display: display ?? World.display(World.defaultDisplay)!)
  }

  /// Replays `entries`. With `live` the last one is happening now: it reads what it needs from the disk.
  private static func replay(
    _ entries: [Entry], lastAsks: Bool, live: Bool = false, session: Session?
  ) -> (world: World, reply: Reply) {
    let world = newWorld(entries, socket: session?.socket ?? "")
    var reply = Reply()
    for (index, entry) in entries.enumerated() where entry.fields[0] != "display" {
      let last = index == entries.count - 1
      world.begin(entry)
      if last, live, let session { world.noticeChanges(in: session.home, settingsIn: session.rehearsal) }
      reply = world.perform(entry.fields)
      if !(last && lastAsks) { world.letTimePass() }
    }
    return (world, reply)
  }

  private static func trace(_ path: String) -> Int32 {
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
      return complain("arbor-fakemac: cannot read \(path)")
    }
    silenceLog()
    let entries = Entry.parse(text)
    let world = newWorld(entries, socket: "")
    for entry in entries {
      print("> " + entry.fields.joined(separator: " "))
      if entry.fields[0] == "display" { continue }
      world.begin(entry)
      let reply = world.perform(entry.fields)
      world.letTimePass()
      print(reply.out + reply.err, terminator: "")
      if reply.code != 0 { print("(exit code \(reply.code))") }
    }
    print(world.perform(["arborctl", "ascii"]).out, terminator: "")
    print(world.perform(["pointer", "windows"]).out, terminator: "")
    return 0
  }

  /// `Log` writes to arbor.log in ARBOR_HOME and gives up quietly where it cannot make that folder.
  private static func silenceLog() { setenv("ARBOR_HOME", "/dev/null/no-log", 1) }

  private static func finish(_ reply: Reply) -> Int32 {
    FileHandle.standardOutput.write(Data(reply.out.utf8))
    FileHandle.standardError.write(Data(reply.err.utf8))
    return reply.code
  }

  private static func complain(_ message: String) -> Int32 { finish(Reply(err: message + "\n", code: 64)) }
}

/// The files of one session: lib.sh makes a folder per session and ARBOR_HOME inside it.
@MainActor
struct Session {
  let home: String
  let socket: String
  let folder: String
  /// Where rehearse.sh wants a copy of every world, because lib.sh deletes the session's folder at the end.
  let copies: String?
  /// rehearse.sh's own folder, where the `defaults` stand-in keeps the Mac's settings.
  let rehearsal: String?

  init(home: String, environment: [String: String]) {
    self.home = home
    socket = environment["ARBOR_SOCKET"].flatMap { $0.isEmpty ? nil : $0 } ?? home + "/arbor.sock"
    folder = (home as NSString).deletingLastPathComponent
    copies = environment["ARBOR_REHEARSAL_WORLDS"]
    rehearsal = environment["ARBOR_REHEARSAL_DIR"]
  }

  private var world: String { folder + "/world" }
  private var lockFolder: String { folder + "/world.lock" }
  /// Holds the process id of the Arbor stand-in while the world's Arbor runs. The stand-in waits for it to go.
  private var marker: String { folder + "/arbor.pid" }
  private var logFolder: String { folder + "/replay" }

  var arborRuns: Bool { FileManager.default.fileExists(atPath: marker) }

  func worldText() -> String { (try? String(contentsOfFile: world, encoding: .utf8)) ?? "" }

  /// Making a folder either succeeds or fails as a whole, on every file system.
  func lock() {
    var waited = 0
    while mkdir(lockFolder, 0o700) != 0 {
      // The session's folder is gone: a stand-in that outlived its session has nothing left to tell, and nobody to tell it to.
      if errno == ENOENT { exit(0) }
      usleep(2000)
      waited += 1
      // Ten seconds: whoever held it was killed. A replay takes milliseconds.
      if waited > 5000 {
        rmdir(lockFolder)
        waited = 0
      }
    }
  }

  func unlock() { rmdir(lockFolder) }

  func append(_ line: String) {
    for path in [world] + (copies.map { ["\($0)/\((folder as NSString).lastPathComponent).world"] } ?? []) {
      if !FileManager.default.fileExists(atPath: path) {
        _ = FileManager.default.createFile(atPath: path, contents: nil)
      }
      guard let handle = FileHandle(forWritingAtPath: path) else { continue }
      handle.seekToEndOfFile()
      handle.write(Data((line + "\n").utf8))
      try? handle.close()
    }
  }

  /// SIGKILL cannot be caught, so the Arbor stand-in cannot say that it died. Whoever comes next notices.
  func noticeKilledArbor() {
    func deadArbor() -> Int32? {
      guard let text = try? String(contentsOfFile: marker, encoding: .utf8),
        let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines))
      else { return nil }
      if kill(pid, 0) != 0 { return errno == ESRCH ? pid : nil }
      // Where nobody collects the dead (a container whose first process does not), an orphan that was killed
      // stays for ever as a zombie, which still takes signals. Linux says so after the name in brackets.
      let status = (try? String(contentsOfFile: "/proc/\(pid)/stat", encoding: .utf8)) ?? ""
      return status.split(separator: ")").last?.split(separator: " ").first == "Z" ? pid : nil
    }
    guard deadArbor() != nil else { return }
    lock()
    defer { unlock() }
    guard let pid = deadArbor() else { return }
    append(Entry.encode(["arbor-killed", String(pid)]))
    try? FileManager.default.removeItem(atPath: marker)
  }

  /// A replay writes the whole log again. It does so aside, so that a script reading arbor.log meanwhile never
  /// finds half of it. `Log` decides once per process whether to write debug lines, and this process stands in
  /// for every launch in turn, so it writes them all and `publish` drops those of launches without ARBOR_DEBUG.
  func redirectLog() {
    try? FileManager.default.removeItem(atPath: logFolder + "/arbor.log")
    setenv("ARBOR_HOME", logFolder, 1)
    setenv("ARBOR_DEBUG", "1", 1)
  }

  /// Leaves on disk what the real Arbor would have left by now: the log, and whatever the last line made it
  /// save. Nothing else: a script may well have deleted or edited state.json since Arbor wrote it.
  func publish(_ world: World) {
    let written = logFolder + "/arbor.log"
    if world.launchesWithDebug.contains(false), let text = try? String(contentsOfFile: written, encoding: .utf8)
    {
      var launch = -1
      let kept = text.split(separator: "\n").filter { line in
        if line.contains(" INFO  Arbor starting, pid ") { launch += 1 }
        let isDebug = line.split(separator: " ", maxSplits: 2).dropFirst().first == "DEBUG"
        return !isDebug || !world.launchesWithDebug.indices.contains(launch) || world.launchesWithDebug[launch]
      }
      try? Data((kept.joined(separator: "\n") + "\n").utf8).write(to: URL(fileURLWithPath: written))
    }
    if FileManager.default.fileExists(atPath: written) { rename(written, home + "/arbor.log") }
    for name in World.filesWritten {
      let path = home + "/" + name
      let data = world.file(name)
      guard data != (try? Data(contentsOf: URL(fileURLWithPath: path))) else { continue }
      guard let data else {
        try? FileManager.default.removeItem(atPath: path)
        continue
      }
      // Everything Arbor creates is for its owner only (`ProcessGuards.prepareProcess`), state.json always; a
      // settings.json that was there keeps the permissions it had (`SettingsFile.write`).
      let before =
        name == "state.json" ? nil : try? FileManager.default.attributesOfItem(atPath: path)[.posixPermissions]
      try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
      try? FileManager.default.setAttributes([.posixPermissions: before ?? 0o600], ofItemAtPath: path)
    }
    if let pid = world.arbor?.pid {
      try? Data("\(pid)\n".utf8).write(to: URL(fileURLWithPath: marker), options: .atomic)
    } else {
      try? FileManager.default.removeItem(atPath: marker)
    }
  }
}
