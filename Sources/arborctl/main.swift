import ArborCore
import ArborIPC
import Foundation

// arborctl: send commands to a running Arbor and print the replies.
//
//   arborctl dock left
//   arborctl zoom Safari , dock Mail right    # several commands; stops at the first that fails
//   arborctl - < morning.arbor                # one command per line; # starts a comment
//   arborctl --timeout 1 status               # give up after a second
//   arborctl windows --json | jq '.[0].app'   # a query's answer as JSON
//   arborctl where | cut -f2                  # or as text, one line per item, fields separated by tabs
//   arborctl watch view                       # one line of JSON per event, until Arbor quits
//   arborctl help dock
//
// Everything it decides is in ArborCore/Arborctl.swift, where tests reach it; docs/SCRIPTING.md is the manual. Here is only what
// needs a process: the socket, standard input and output, and the bundle it was started from.

func complain(_ message: String) {
  // Not `write(_:)`, which raises an exception when nobody reads standard error any more.
  try? FileHandle.standardError.write(contentsOf: Data("arborctl: \(message)\n".utf8))
}

let unchecked = !["", "0"].contains(ProcessInfo.processInfo.environment["ARBOR_UNCHECKED"] ?? "")
// arborctl lives two folders below Arbor.app/Contents and is usually reached through a symlink on the PATH, so the Info.plist that
// says which build this is, is two folders up. Elsewhere it is a development build.
let contents = Bundle.main.executableURL?.resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent()
let info = contents.flatMap { try? Data(contentsOf: $0.appendingPathComponent("Info.plist")) }
  .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }

exit(
  Arborctl.run(
    Array(CommandLine.arguments.dropFirst()), unchecked: unchecked, terminal: isatty(STDOUT_FILENO) == 1,
    own: BuildInfo(infoDictionary: info),
    readLine: { readLine() },
    watch: { request, timeout in
      ControlClient.watch(
        request, timeout: timeout, output: STDOUT_FILENO,
        print: { event in
          print(event)
          // Into a pipe, output is held back until a buffer fills; a status bar needs each line now.
          fflush(nil)
        },
        complain: complain
      ).exitCode
    },
    send: { line, timeout in
      do {
        return try ControlClient.send(line, timeout: timeout)
      } catch let failure as ControlClient.Failure where failure.timedOut {
        // Arbor is there but did not answer in time, as opposed to not being there.
        throw Arborctl.TimedOut(description: failure.description)
      }
    },
    emit: { output in
      if let out = output.out {
        print(out)
        // Whoever feeds a batch may be waiting for each answer.
        fflush(nil)
      }
      if let err = output.err { complain(err) }
    }))
