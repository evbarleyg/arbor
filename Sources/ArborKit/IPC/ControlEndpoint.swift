import ArborCore
import Foundation

/// What Arbor answers on the control socket: between the lines `ControlServer` carries and the commands
/// and events the controller deals in.
@MainActor
public final class ControlEndpoint {
  private let feed: EventFeed
  private let perform: (Command) -> CommandResult

  /// - Parameter perform: runs a command. The app's own, because `quit` ends the app, not only the controller.
  public init(feed: EventFeed, perform: @escaping (Command) -> CommandResult) {
    self.feed = feed
    self.perform = perform
  }

  /// Answers one request line.
  public func respond(to line: String) -> ControlServer.Response {
    let command: Command
    do {
      command = try Command.parse(line)
    } catch {
      return .reply(Self.line(for: .failure("\(error)")))
    }
    guard case .watch(let options) = command else { return .reply(Self.line(for: perform(command))) }
    guard feed.hasRoom else {
      let full = feed.subscriberCount >= EventFeed.maximumSubscribers
      return .reply(
        Self.line(
          for: .failure(
            full ? "\(EventFeed.maximumSubscribers) clients are watching already; that is the limit" : "Arbor is quitting")))
    }
    return .stream { [feed] send in
      let subscription = feed.subscribe(options, sink: send)
      return { if let subscription { feed.unsubscribe(subscription) } }
    }
  }

  /// A command's result as the line of JSON that answers it.
  public static func line(for result: CommandResult) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(result) else { return #"{"ok":false,"message":"encoding failed"}"# }
    return String(decoding: data, as: UTF8.self)
  }
}
