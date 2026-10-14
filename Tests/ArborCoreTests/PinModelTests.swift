import ArborCore
import CoreGraphics
import Foundation
import Testing

/// The parts of pinning (docs/features/F49-pin.md) that live in the core.
@Suite struct PinModelTests {
  let a = WindowID(1)
  let b = WindowID(2)
  let frame = CGRect(x: 10, y: 20, width: 300, height: 200)

  func workspace() -> Workspace {
    var workspace = Workspace()
    workspace.floating[a] = frame
    workspace.floating[b] = frame
    return workspace
  }

  @Test func onlyAFloatingWindowCanBePinned() {
    var workspace = workspace()
    let pinned = workspace.pin(a)
    #expect(pinned)
    #expect(workspace.isPinned(a) && !workspace.isPinned(b))
    #expect(workspace.pinnedWindows == [a])
    let unknown = workspace.pin(WindowID(9))
    workspace.dock(b, at: .cameraEdge(.left))
    let docked = workspace.pin(b)
    #expect(!unknown && !docked)
    #expect(workspace.pinnedWindows == [a])
  }

  @Test func howeverAWindowStopsFloatingItsPinGoes() {
    for stop in ["dock", "forget", "remove"] {
      var workspace = workspace()
      workspace.pin(a)
      workspace.pin(b)
      switch stop {
      case "dock": workspace.dock(a, at: .cameraEdge(.right))
      case "forget": workspace.forget(a)
      default: workspace.floating[a] = nil
      }
      #expect(workspace.pinned == [b], "\(stop)")
      // Floating again is not pinned again.
      workspace.undock(a, floatingAt: frame)
      #expect(!workspace.isPinned(a), "\(stop)")
    }
  }

  @Test func movingAPinnedWindowKeepsItsPin() {
    var workspace = workspace()
    workspace.pin(a)
    workspace.floating[a] = frame.offsetBy(dx: 50, dy: 50)
    #expect(workspace.isPinned(a))
  }

  @Test func pinningAndUnpinningLeavesTheWorkspaceAsItWas() {
    let before = workspace()
    var workspace = before
    workspace.unpin(a)
    #expect(workspace == before)
    workspace.pin(a)
    #expect(workspace != before)
    workspace.pin(a)
    workspace.unpin(a)
    #expect(workspace == before)
    #expect(workspace.pinned == nil)
  }

  @Test func resettingTheTreeKeepsThePins() {
    var workspace = workspace()
    workspace.pin(a)
    workspace.reset(tree: LayoutTree())
    #expect(workspace.isPinned(a))
  }

  @Test func pinsAreSavedAndAPinOnAWindowThatDoesNotFloatIsNotBelieved() throws {
    var workspace = workspace()
    workspace.pin(a)
    let data = try JSONEncoder().encode(workspace)
    #expect(try JSONDecoder().decode(Workspace.self, from: data) == workspace)

    // A file edited by hand: 9 is nowhere in the workspace.
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["pinned"] = [1, 9]
    let edited = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(edited.pinnedWindows == [a])
    #expect(!edited.isPinned(WindowID(9)))
  }

  @Test func theCommandsHaveATextForm() throws {
    #expect(try Command.parse("pin") == .pin(nil))
    #expect(try Command.parse("pin 412") == .pin(WindowID(412)))
    #expect(try Command.parse("unpin w412") == .unpin(WindowID(412)))
    #expect(try Command.parse("toggle-pin") == .togglePin(nil))
    for command in [Command.pin(nil), .pin(a), .unpin(nil), .unpin(a), .togglePin(nil), .togglePin(a)] {
      #expect(try Command.parse(command.text) == command)
      #expect(command.isAllowedFromURL, "an arrangement that is easily put back")
      #expect(!command.isQuery && !command.endsPause)
    }
    // Since F50 a window can be named by its app wherever a command takes one. It is kept as a name, never guessed at here.
    let named = try Command.parse("pin Zoom")
    if case .naming(_, let names) = named { #expect(names == [.app("Zoom")]) } else { Issue.record("pin Zoom became \(named)") }
    #expect(named.filling([a]) == .pin(a))
    #expect(throws: Command.ParseError.self) { try Command.parse("pin left") }
    for verb in ["pin", "unpin", "toggle-pin"] {
      #expect(throws: Command.ParseError.self, "a second window is not ignored in silence") { try Command.parse("\(verb) 103 104") }
    }
    #expect(Command.helpText.contains("pin [window] | unpin | toggle-pin"))
    #expect(Command.helpText.contains("actions: float, ignore, pin,"), "`rule add` takes it, so `help` names it")
  }

  @Test func theRuleActionHasATextForm() throws {
    #expect(try RuleAction(text: "pin") == .pin)
    #expect(try RuleAction(text: "PIN") == .pin)
    #expect(RuleAction.pin.text == "pin")
    #expect(throws: RuleAction.ParseError.self) { try RuleAction(text: "pin left") }
    let rule = AppRule(app: "us.zoom.xos", title: "Meeting", action: .pin)
    #expect(try JSONDecoder().decode(AppRule.self, from: JSONEncoder().encode(rule)) == rule)
    #expect(rule.description == #"us.zoom.xos, title contains "Meeting" → pin"#)
  }
}
