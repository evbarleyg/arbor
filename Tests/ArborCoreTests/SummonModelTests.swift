import ArborCore
import CoreGraphics
import Foundation
import Testing

/// The parts of summoning (docs/features/F53-summon.md) that live in the core.
@Suite struct SummonModelTests {
  let a = WindowID(1)
  let b = WindowID(2)
  let frame = CGRect(x: 10, y: 20, width: 300, height: 200)
  let other = CGRect(x: 400, y: 300, width: 500, height: 250)

  func workspace() -> Workspace {
    var workspace = Workspace()
    workspace.floating[a] = frame
    workspace.floating[b] = frame
    return workspace
  }

  @Test func oneWindowIsSummonedAtATimeAndTheOneBeforeIsStashed() {
    var workspace = workspace()
    let none = workspace.summon(a, app: "A", at: other)
    #expect(none == nil)
    #expect(workspace.isSummoned(a) && workspace.staysInView(a) && workspace.floating[a] == other)
    let replaced = workspace.summon(b, app: "B", at: other)
    #expect(replaced == a)
    #expect(workspace.isSummoned(b) && workspace.isStashed(a) && !workspace.staysInView(a))
    // Summoning the summoned window again replaces nothing.
    let same = workspace.summon(b, app: "B", at: frame)
    #expect(same == nil)
    #expect(workspace.stashedWindows == [a])
  }

  @Test func whereTheSummonedWindowIsIsWhereItWillBeNextTime() {
    var workspace = workspace()
    workspace.summon(a, app: "A", at: other)
    #expect(workspace.summonFrames == ["A": other])
    workspace.floating[a] = frame
    #expect(workspace.summonFrames == ["A": frame])
    // Not once it has been sent away, and not for other windows.
    workspace.dismissSummon()
    workspace.floating[a] = other
    workspace.floating[b] = other
    #expect(workspace.summonFrames == ["A": frame])
  }

  @Test func dismissingStashesAndReturnsTheWindow() {
    var workspace = workspace()
    let nothing = workspace.dismissSummon()
    #expect(nothing == nil)
    workspace.summon(a, app: "A", at: other)
    let dismissed = workspace.dismissSummon()
    #expect(dismissed == a)
    #expect(workspace.summoned == nil && workspace.stashed == [a])
  }

  @Test func howeverAWindowStopsFloatingItIsNeitherSummonedNorStashed() {
    for stop in ["dock", "forget", "remove"] {
      var workspace = workspace()
      workspace.summon(a, app: "A", at: other)
      workspace.summon(b, app: "B", at: other)
      for window in [a, b] {
        switch stop {
        case "dock": workspace.dock(window, at: .cameraEdge(.right))
        case "forget": workspace.forget(window)
        default: workspace.floating[window] = nil
        }
      }
      #expect(workspace.summoned == nil && workspace.stashed == nil, "\(stop)")
      #expect(workspace.summonFrames == ["A": other, "B": other], "\(stop): the places are still remembered")
    }
  }

  @Test func aWindowHasOneRoleAtATime() {
    var workspace = workspace()
    workspace.pin(a)
    workspace.summon(a, app: "A", at: other)
    #expect(workspace.role(of: a) == .summoned(app: "A") && workspace.pinned == nil)
    workspace.pin(a)
    #expect(workspace.role(of: a) == .pinned && workspace.summoned == nil)
    workspace.summon(a, app: "A", at: other)
    workspace.dismissSummon()
    #expect(workspace.role(of: a) == .stashed)
    workspace.pin(a)
    #expect(workspace.role(of: a) == .pinned && workspace.stashed == nil)
    #expect(workspace.role(of: b) == nil)
  }

  @Test func rolesCanBeHandedFromOneWorkspaceToAnother() {
    var workspace = workspace()
    for role in [FloatingRole.pinned, .stashed, .summoned(app: "A"), nil] {
      workspace.setRole(role, of: a)
      #expect(workspace.role(of: a) == role)
    }
    // There is a summoned window already: the newcomer waits its turn.
    workspace.setRole(.summoned(app: "A"), of: a)
    workspace.setRole(.summoned(app: "B"), of: b)
    #expect(workspace.role(of: a) == .summoned(app: "A") && workspace.role(of: b) == .stashed)
    // Only for windows that float here.
    workspace.setRole(.pinned, of: WindowID(9))
    #expect(workspace.role(of: WindowID(9)) == nil)
  }

  @Test func forgettingSummonsLeavesOrdinaryFloatingWindows() {
    var workspace = workspace()
    workspace.summon(a, app: "A", at: other)
    workspace.summon(b, app: "B", at: other)
    let released = workspace.forgetSummons()
    #expect(released == [a, b])
    #expect(workspace.role(of: a) == nil && workspace.role(of: b) == nil)
    #expect(workspace.isFloating(a) && workspace.isFloating(b))
    let nothing = workspace.forgetSummons()
    #expect(nothing.isEmpty)
  }

  @Test func withNothingSummonedEverTheWorkspaceIsAsItWas() {
    let before = workspace()
    var workspace = before
    workspace.dismissSummon()
    workspace.forgetSummon(of: a)
    workspace.forgetSummons()
    workspace.setRole(nil, of: a)
    #expect(workspace == before)
  }

  @Test func whatAFileSaysOfWindowsThatDoNotFloatIsNotBelieved() throws {
    var workspace = workspace()
    workspace.summon(a, app: "A", at: other)
    let data = try JSONEncoder().encode(workspace)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["summoned"] = ["window": 9, "app": "X"]
    object["stashed"] = [2, 9]
    let edited = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(!edited.isSummoned(WindowID(9)) && !edited.staysInView(WindowID(9)) && !edited.isStashed(WindowID(9)))
    #expect(edited.stashedWindows == [b])
  }

  @Test func theCommandHasATextForm() throws {
    #expect(try Command.parse("summon Terminal") == .summon(app: "Terminal"))
    #expect(try Command.parse("summon com.apple.Terminal") == .summon(app: "com.apple.Terminal"), "case is kept")
    #expect(try Command.parse("summon Visual Studio Code") == .summon(app: "Visual Studio Code"))
    #expect(try Command.parse("summon  1Password   7") == .summon(app: "1Password 7"))
    #expect(try Command.parse("summon Überblick") == .summon(app: "Überblick"))
    for app in ["Terminal", "Visual Studio Code", "com.apple.Terminal"] {
      #expect(try Command.parse(Command.summon(app: app).text) == .summon(app: app))
    }
    for bad in ["summon", "summon .hidden", "summon a\u{7}b", "summon $(rm)", "summon a;b", "summon " + String(repeating: "x", count: 256)] {
      #expect(throws: Command.ParseError.self, "\(bad.prefix(20))") { try Command.parse(bad) }
    }
    // A slash is no part of a name, so no path can be spelled. (It separates words only in the form URLs have.)
    #expect(throws: Command.ParseError.self) { try Command.parse("summon a/b") }
    #expect(try Command.parse("/summon/a/b") == .summon(app: "a b"))
    #expect(throws: Command.ParseError.self) { try Command.parse("summon ../../bin/sh") }
  }

  @Test func itIsNotAcceptedFromURLs() {
    #expect(!Command.summon(app: "Terminal").isAllowedFromURL)
    #expect(!Command.summon(app: "Terminal").isQuery)
    #expect(Command.helpText.contains("summon <app>"))
  }

  @Test func theSettingDefaultsToOffAndOldFilesLoad() throws {
    #expect(!Settings().summonStays)
    #expect(try !JSONDecoder().decode(Settings.self, from: Data("{}".utf8)).summonStays)
    #expect(try JSONDecoder().decode(Settings.self, from: Data(#"{"summonStays": true}"#.utf8)).summonStays)
  }
}
