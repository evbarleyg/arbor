import Foundation

/// Where Arbor keeps its files. Everything lives in one folder so a test run
/// can point `ARBOR_HOME` at a temporary directory and touch nothing else.
///
/// - `ARBOR_HOME`: the folder (default `~/Library/Application Support/Arbor` for the app and arborctl, and a
///   folder in the temporary directory for every other program: see `home(environment:program:)`)
/// - `ARBOR_SOCKET`: the control socket path (default `$ARBOR_HOME/arbor.sock`)
public enum ArborPaths {
  public static var home: URL {
    // The file this process runs, whatever link it was started through (`arborctl` is installed as one).
    let program = (Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])).resolvingSymlinksInPath()
    return home(environment: ProcessInfo.processInfo.environment, program: program.lastPathComponent)
  }

  /// Only the app and its client find the person's folder by themselves. Everything else that links this code (the
  /// test runner under whatever name, arbor-sim, arbor-e2e) is a guest on the Mac it runs on, and it logs: one
  /// `swift test` writes more than `arbor.log` and its predecessor hold together, which on a Mac where Arbor is in use
  /// would replace the log of the person's own Arbor. A guest that is given no `ARBOR_HOME` gets a folder of the guests' own.
  public static func home(environment: [String: String], program: String) -> URL {
    if let override = environment["ARBOR_HOME"], !override.isEmpty {
      return URL(fileURLWithPath: NSString(string: override).expandingTildeInPath, isDirectory: true)
    }
    guard ["Arbor", "arborctl"].contains(program) else {
      // The user's number: on Linux the temporary directory is everybody's.
      return FileManager.default.temporaryDirectory.appendingPathComponent("arbor-guests-\(getuid())", isDirectory: true)
    }
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return support.appendingPathComponent("Arbor", isDirectory: true)
  }

  /// `text` with `~` for a home folder: this account's, wherever it is, and anybody's under `/Users`. For whatever people pass on: the
  /// log, and what `arborctl` says when it cannot reach Arbor, are what gets pasted into a public issue, and an account's name is a
  /// person's name as often as not. Not for what a program goes by: a reply that says where a trace is recorded is read by scripts.
  public static func withoutHomeFolder(_ text: String, homes: [String] = homeFolders) -> String {
    guard text.contains("/") else { return text }
    /// What a name in a path ends at.
    func ends(_ character: Character?) -> Bool { character.map { $0 == "/" || $0.isWhitespace || "\"'`:,;)]".contains($0) } ?? true }
    var result = ""
    var rest = Substring(text)
    while let slash = rest.firstIndex(of: "/") {
      result += rest[..<slash]
      rest = rest[slash...]
      // Only where a path begins, also after `file://`: `/Users` in the middle of one is a folder like any other.
      let begins = result.hasSuffix("://") || (result.last.map { !($0.isLetter || $0.isNumber || "._-~/".contains($0)) } ?? true)
      if begins, let home = homes.first(where: { rest.hasPrefix($0) && ends(rest.dropFirst($0.count).first) }) {
        result += "~"
        rest = rest.dropFirst(home.count)
      } else if begins, rest.hasPrefix("/Users/"), case let name = rest.dropFirst(7).prefix(while: { !ends($0) }), !name.isEmpty, name != "Shared" {
        result += "~"
        rest = rest.dropFirst(7 + name.count)
      } else {
        result.append(rest.removeFirst())
      }
    }
    return result + rest
  }

  /// What this account's home folder goes by: as the system has it, and as `HOME` says, which need not be the same. The longest first.
  /// Read once: `environment` copies every variable each time it is asked.
  public static let homeFolders: [String] = Set([NSHomeDirectory(), ProcessInfo.processInfo.environment["HOME"] ?? ""])
    .map { $0.count > 1 && $0.hasSuffix("/") ? String($0.dropLast()) : $0 }.filter { $0.count > 1 && $0.hasPrefix("/") }.sorted { $0.count > $1.count }

  public static var socketPath: String {
    if let override = ProcessInfo.processInfo.environment["ARBOR_SOCKET"], !override.isEmpty {
      return NSString(string: override).expandingTildeInPath
    }
    return home.appendingPathComponent("arbor.sock").path
  }

  public static var settingsFile: URL { home.appendingPathComponent("settings.json") }
  public static var stateFile: URL { home.appendingPathComponent("state.json") }
  public static var logFile: URL { home.appendingPathComponent("arbor.log") }
  /// Where `trace on` writes traces (docs/TRACES.md).
  public static var tracesDirectory: URL { home.appendingPathComponent("traces", isDirectory: true) }
  public static var lockFile: URL { home.appendingPathComponent("arbor.lock") }

  public struct Problem: Error, CustomStringConvertible {
    public let description: String
  }

  /// Creates the home folder (owner-only permissions) if needed.
  public static func ensureHome() throws {
    try secure(folder: home)
  }

  /// Creates `folder` for its owner only, or makes sure that is what an existing one is. The folder
  /// holds window titles (state.json) and the socket that commands Arbor. `ARBOR_HOME` may point into
  /// a shared place such as /tmp, where somebody else could have made the folder first and could then
  /// swap the files in it.
  public static func secure(folder: URL) throws {
    try FileManager.default.createDirectory(
      at: folder, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    var info = stat()
    guard stat(folder.path, &info) == 0 else {
      throw Problem(description: "cannot examine \(withoutHomeFolder(folder.path)): \(String(cString: strerror(errno)))")
    }
    guard info.st_uid == geteuid() else {
      throw Problem(description: "\(withoutHomeFolder(folder.path)) belongs to another user (uid \(info.st_uid)); Arbor keeps no files there")
    }
    if info.st_mode & 0o077 != 0, chmod(folder.path, 0o700) != 0 {
      throw Problem(description: "\(withoutHomeFolder(folder.path)) is open to other users and cannot be closed to them")
    }
  }
}
