import ArborCore
import ArborKit
import ArborTesting
import CoreGraphics
import Foundation
import Testing

/// `state` is what people paste into a report, and a title can hold anything they are reading or writing: it lists none
/// unless it is asked to (`state --titles`), as `watch` and `layout` do.
@MainActor @Suite struct StateTitlesTests {
  func makeHarness() -> (Harness, docked: WindowID, floating: WindowID) {
    let h = Harness()
    let docked = h.system.open(app: "Safari", title: "quokkadoo: my bank")
    let floating = h.system.open(app: "Notes", title: "quokkadoo: a letter")
    h.start()
    h.run("dock \(docked.rawValue) left")
    return (h, docked, floating)
  }

  /// The reply as it goes over the socket.
  func line(_ result: CommandResult) throws -> String { String(decoding: try JSONEncoder().encode(result), as: UTF8.self) }

  @Test func stateListsNoTitle() throws {
    let (h, docked, floating) = makeHarness()
    let reply = h.run("state")
    #expect(reply.state?.window(docked) != nil && reply.state?.window(floating) != nil)
    #expect(try !line(reply).contains("quokkadoo"))
    #expect(try !line(reply).contains("\"title\""), "no key without a value either")
  }

  @Test func askedForTitlesItListsThem() throws {
    let (h, docked, floating) = makeHarness()
    let reply = h.run("state --titles")
    #expect(reply.state?.window(docked)?.title == "quokkadoo: my bank")
    #expect(reply.state?.window(floating)?.title == "quokkadoo: a letter")
  }

  @Test func titlesAreAllThatIsLeftOut() throws {
    let (h, _, _) = makeHarness()
    let plain = try #require(h.run("state").state)
    let asked = try #require(h.run("state --titles").state)
    #expect(plain != asked)
    #expect(plain == asked.withoutTitles)
  }

  @Test func heldPausedOrStoppedItIsTheSame() throws {
    let (h, _, _) = makeHarness()
    for command in ["hold", "release", "pause", "resume"] {
      h.run(command)
      #expect(try !line(h.run("state")).contains("quokkadoo"), "after \(command)")
    }
  }

  @Test func whoeverReadsAReplyFromBeforeStillCan() throws {
    let (h, docked, _) = makeHarness()
    for command in ["state", "state --titles"] {
      let reply = h.run(command)
      let decoded = try JSONDecoder().decode(CommandResult.self, from: JSONEncoder().encode(reply))
      #expect(decoded.state == reply.state)
      #expect(decoded.state?.window(docked)?.app == "Safari")
    }
  }

  @Test func theCommandHasATextForm() throws {
    #expect(try Command.parse("state") == .state(titles: false))
    #expect(try Command.parse("state --titles") == .state(titles: true))
    #expect(Command.state(titles: true).text == "state --titles")
    #expect(Command.state(titles: false).text == "state")
    #expect(Command.state(titles: true).isQuery)
    #expect(throws: (any Error).self) { try Command.parse("state --names") }
    #expect(throws: (any Error).self) { try Command.parse("state 101") }
  }
}
