import ArborCore
import ArborTesting
import Foundation
import Testing

@testable import ArborKit

/// What a reply becomes before it is logged. `SettingsFileTests.noPartOfATitleReachesTheLog` reads the log itself, where a
/// command that fails is written only with debug logging on.
@Suite @MainActor struct SettingsLogTests {
  @Test func aReplyThatQuotesTheFileIsLoggedWithoutTheQuotation() throws {
    let h = Harness()
    #expect(h.controller.forTheLog("gap is 12") == "gap is 12")
    let text = #"{"rules": [{"app": "com.a", "title": "Salaries "Payroll" 2026", "action": "float"}]}"#
    h.controller.loadSettings = { try Settings.read(Data(text.utf8)) }
    guard case .invalid(let reason, _) = h.controller.takeInSettingsFile() else {
      Issue.record("the file was read")
      return
    }
    #expect(reason.contains("Payroll"), "the reply goes to whoever wrote the file")
    let reply = h.run("set gap 20").message
    #expect(reply.contains(reason))
    let logged = h.controller.forTheLog(reply)
    #expect(!logged.contains("Payroll") && logged.contains("line 1, column 49"))
    // The rest of the reply is as it was, and a reply that quotes nothing is left alone.
    #expect(logged.hasPrefix(String(reply.prefix { $0 != ":" })))
    #expect(h.controller.forTheLog("gap is 12") == "gap is 12")
  }
}
