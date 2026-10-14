import ArborCore
import ArborKit
import ArborTesting
import Foundation

/// `arbor-sim --serve <socket path>`: the simulator behind a real control socket, until `quit`.
///
///     arbor-sim --serve /tmp/sim.sock &
///     export ARBOR_SOCKET=/tmp/sim.sock
///     arborctl open Safari; arborctl dock 101 left; arborctl watch view
///
/// `arborctl` then talks to the real server, endpoint, event feed and controller, with pretend windows:
/// a place to try a script, or `arborctl` itself (scripts/watch-smoke.sh), without a Mac and without
/// touching anyone's windows. Besides Arbor's commands it takes the simulator's own (`open`, `close`, `focus`…).
@MainActor
final class SimulatorServer {
  private let harness: Harness
  private let feed: EventFeed
  private var server: ControlServer?
  private var printLayout = false

  init() {
    let harness = Harness()
    harness.start()
    self.harness = harness
    feed = EventFeed(controller: harness.controller)
  }

  func run(at path: String) -> Never {
    let endpoint = ControlEndpoint(feed: feed) { [self] command in
      afterReplying(quit: command == .quit)
      return harness.controller.perform(command)
    }
    let server = ControlServer(path: path) { [self] line in
      let words = line.split(separator: " ").map(String.init)
      // Arbor's commands get Arbor's replies. What Arbor cannot read may be one of the simulator's.
      if words.isEmpty || (try? Command.parse(line)) != nil { return endpoint.respond(to: line) }
      let (message, ok) = simulate(words, harness: harness, printLayout: &printLayout)
      afterReplying()
      return .reply(ControlEndpoint.line(for: CommandResult(ok: ok, message: message)))
    }
    self.server = server
    do {
      try server.start()
    } catch {
      print("arbor-sim: \(error)")
      exit(2)
    }
    // Not `dispatchMain()`: on macOS that gives the main thread up, other threads serve the main queue from then on,
    // and `MainActor.assumeIsolated` traps on them. The run loop serves the queue on the main thread, as the app's does.
    while true { RunLoop.main.run(until: .distantFuture) }
  }

  /// The simulator's clock stands still. This is its main loop coming round after a request: work
  /// scheduled without delay (the events) runs, timers wait for `flush`.
  private func afterReplying(quit: Bool = false) {
    DispatchQueue.main.async { [self] in
      MainActor.assumeIsolated {
        // macOS reports the focus changes Arbor asked for back to it.
        harness.system.deliverEchoes()
        harness.scheduler.advance(by: 0)
        guard quit else { return }
        // What the app does on its way out.
        harness.controller.shutdown()
        feed.stop()
        server?.stop()
        exit(0)
      }
    }
  }
}
