import ArborCore
import Foundation
import Testing

// F05: the text form of `frame-rect`.

@Suite struct FrameRectCommandTests {
  @Test func frameRectParsesAndRoundTrips() throws {
    #expect(try Command.parse("frame-rect 10 20 300 400") == .frameRect(x: 10, y: 20, width: 300, height: 400))
    #expect(try Command.parse("frame-rect/10/20/300/400") == .frameRect(x: 10, y: 20, width: 300, height: 400))
    for command: Command in [
      .frameRect(x: 10, y: 20, width: 300, height: 400),
      .frameRect(x: -1440, y: 12.5, width: 640.25, height: -480),
    ] {
      #expect(try Command.parse(command.text) == command)
      #expect(try JSONDecoder().decode(Command.self, from: JSONEncoder().encode(command)) == command)
    }
    #expect(Command.frameRect(x: 10, y: 20, width: 300, height: 400).text == "frame-rect 10 20 300 400")
    #expect(!Command.frameRect(x: 0, y: 0, width: 1, height: 1).isQuery)
  }

  @Test func frameRectRejectsBadInput() {
    for text in [
      "frame-rect", "frame-rect 1 2 3", "frame-rect 1 2 3 4 5", "frame-rect a 2 3 4", "frame-rect nan 2 3 4",
      "frame-rect 1 2 inf 4", "frame-rect 1e300 2 3 4",
    ] {
      #expect(throws: Command.ParseError.self, "\(text)") { try Command.parse(text) }
    }
  }

  @Test func frameRectIsInTheHelp() {
    #expect(Command.helpText.contains("frame-rect <x> <y> <w> <h>"))
  }
}
