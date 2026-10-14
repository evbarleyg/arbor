import ArborCore
import ArborIPC
import Foundation

// arborctl: send commands to a running Arbor and print the replies.
//
//   arborctl dock left
//   arborctl state                      # full JSON
//   arborctl ascii                      # the layout drawn as text
//   arborctl zoom 412 --json            # raw JSON reply
//   arborctl zoom 412 , dock 413 right  # several commands; stops at the first that fails
//   arborctl --timeout 1 status         # give up after a second
//   arborctl - < morning.arbor          # one command per line; # starts a comment
//   arborctl watch view                 # one line of JSON per event, until Arbor quits
//   arborctl completions zsh            # a completion script
//   arborctl --version                  # this arborctl's own version; `arborctl version` asks the running app
//
// What the arguments mean is worked out by `CLIInvocation` (ArborCore), where tests reach it, and `arborctl --help`
// prints it. Answers go to standard output, and whatever went wrong to standard error, so that `$(arborctl …)` holds
// an answer or nothing. The exit codes are `CLIInvocation.ExitCode`. See docs/SCRIPTING.md.

func complain(_ message: String) {
  // Not `write(_:)`, which raises an exception when nobody reads standard error any more.
  try? FileHandle.standardError.write(contentsOf: Data("arborctl: \(message)\n".utf8))
}

func leave(_ code: CLIInvocation.ExitCode) -> Never { exit(code.rawValue) }

/// Sends one command and prints what comes back. `place` goes before a complaint: the line of a batch.
func run(_ line: String, as invocation: CLIInvocation, place: String = "") -> CLIInvocation.ExitCode {
  do {
    let reply = try ControlClient.send(line, timeout: invocation.timeout)
    guard let object = try JSONSerialization.jsonObject(with: Data(reply.utf8)) as? [String: Any] else {
      if !invocation.quiet { print(reply) }
      return .ok
    }
    let outcome = CLIInvocation.outcome(ok: object["ok"] as? Bool ?? false)
    if invocation.quiet {
      // The exit code says it all.
    } else if invocation.rawJSON || CLIInvocation.verb(of: line) == "state" {
      // The whole reply, refusals too: whoever asked for JSON reads `ok` and `message` from it.
      print(reply)
    } else if let answer = object["text"] as? String ?? object["message"] as? String {
      if outcome.toStandardError { complain(place + answer) } else { print(answer) }
    }
    return outcome.exitCode
  } catch let failure as ControlClient.Failure {
    if !invocation.quiet { complain(place + failure.description) }
    return failure.timedOut ? .timedOut : .unreachable
  } catch {
    if !invocation.quiet { complain(place + "\(error)") }
    return .unreachable
  }
}

/// How several commands end, from a comma-separated line or from standard input.
struct Tally {
  var keepGoing: Bool
  /// The first thing that went wrong is what the whole reports.
  var worst = CLIInvocation.ExitCode.ok

  /// Returns false when it is time to stop.
  mutating func carryOn(after code: CLIInvocation.ExitCode) -> Bool {
    guard code != .ok else { return true }
    if worst == .ok { worst = code }
    // With nobody there, the commands that follow would only say so again.
    return keepGoing && code != .unreachable
  }
}

let invocation: CLIInvocation
do {
  invocation = try CLIInvocation.parse(Array(CommandLine.arguments.dropFirst()))
} catch {
  complain("\(error)")
  leave(.usage)
}

switch invocation.action {
case .help:
  // Answered here, because people read the help before they have Arbor running.
  print(CLIInvocation.usage + "\n\n" + Command.helpText)
  leave(.ok)

case .version:
  // arborctl is Arbor.app/Contents/Helpers/arborctl, usually reached through a symlink on the PATH, so
  // the Info.plist that scripts/bundle.sh stamped is two folders up. Elsewhere it is a development build.
  let contents = Bundle.main.executableURL?.resolvingSymlinksInPath().deletingLastPathComponent().deletingLastPathComponent()
  let info = contents.flatMap { try? Data(contentsOf: $0.appendingPathComponent("Info.plist")) }
    .flatMap { try? PropertyListSerialization.propertyList(from: $0, format: nil) as? [String: Any] }
  let own = BuildInfo(infoDictionary: info).text
  print("arborctl \(own)")
  // After an update the Arbor that is running may still be the old one.
  if let reply = try? ControlClient.send("version", timeout: 1),
    let object = try? JSONSerialization.jsonObject(with: Data(reply.utf8)) as? [String: Any],
    object["ok"] as? Bool == true, let running = object["message"] as? String, running != "Arbor \(own)"
  {
    print("The Arbor that is running is another build, \(running): quit it and open Arbor again")
  }
  leave(.ok)

case .completions(let shell):
  print(ShellCompletions.script(for: shell))
  leave(.ok)

case .commands(let commands) where CLIInvocation.verb(of: commands[0].joined(separator: " ")) == "watch":
  let end = ControlClient.watch(
    commands[0].joined(separator: " "), timeout: invocation.timeout, output: STDOUT_FILENO,
    print: { event in
      print(event)
      // Into a pipe, output is held back until a buffer fills; a status bar needs each line now.
      fflush(nil)
    },
    complain: complain)
  exit(end.exitCode)

case .commands(let commands):
  var tally = Tally(keepGoing: invocation.keepGoing)
  for words in commands {
    guard tally.carryOn(after: run(words.joined(separator: " "), as: invocation)) else { break }
  }
  leave(tally.worst)

case .batch:
  // Line by line, as they arrive: the other end may be a program that waits for each answer.
  var tally = Tally(keepGoing: invocation.keepGoing)
  var number = 0
  reading: while let text = readLine() {
    number += 1
    // Usually one. `readLine` ends a line at fewer characters than count as line breaks (not at a lone carriage return).
    for (_, command) in CLIInvocation.batch(text) {
      let code: CLIInvocation.ExitCode
      if CLIInvocation.verb(of: command) == "watch" {
        // It ends when Arbor does, and its answer is a stream, not a reply.
        complain("line \(number): watch cannot be part of a batch")
        code = .usage
      } else {
        code = run(command, as: invocation, place: "line \(number): ")
      }
      fflush(nil)
      guard tally.carryOn(after: code) else { break reading }
    }
  }
  leave(tally.worst)
}
