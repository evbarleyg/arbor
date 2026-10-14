import ArborCore
import CoreGraphics
import Foundation
import Testing

private let a = WindowID(1)
private let b = WindowID(2)
private let c = WindowID(3)
private let small = CGRect(x: 300, y: 200, width: 400, height: 300)
private let other = CGRect(x: 500, y: 90, width: 640, height: 420)

/// What a workspace remembers about docked windows (docs/features/F48-floating-restores-size.md).
@Suite struct UndockedFrameTests {
  @Test func dockingRemembersWhereTheWindowFloated() {
    var workspace = Workspace()
    workspace.floating[a] = small
    #expect(workspace.undockedFrame(of: a) == nil, "a floating window has nothing to go back to")
    workspace.dock(a, at: .cameraEdge(.left))
    #expect(workspace.undockedFrame(of: a) == small)
  }

  @Test func movingADockedWindowKeepsWhatIsRemembered() {
    var workspace = Workspace()
    workspace.floating[a] = small
    workspace.floating[b] = other
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.dock(a, at: .cameraEdge(.right))
    workspace.dock(a, at: .beside(workspace.tree.leaf(containing: b)!, .top))
    workspace.dock(a, at: .stack(workspace.tree.leaf(containing: b)!))
    #expect(workspace.undockedFrame(of: a) == small)
    #expect(workspace.undockedFrame(of: b) == other)
  }

  @Test func floatingAndForgettingDropWhatIsRemembered() {
    var workspace = Workspace()
    workspace.floating[a] = small
    workspace.floating[b] = other
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    workspace.undock(a, floatingAt: other)
    #expect(workspace.undockedFrames == [b: other])
    workspace.forget(b)
    #expect(workspace.undockedFrames == nil, "nil, not empty, so that it equals a workspace that never docked anything")
  }

  @Test func dockingAgainRemembersTheNewerFrame() {
    var workspace = Workspace()
    workspace.floating[a] = small
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.undock(a, floatingAt: other)
    workspace.dock(a, at: .cameraEdge(.right))
    #expect(workspace.undockedFrame(of: a) == other)
  }

  @Test func aWindowThatNeverFloatedHasNothingRemembered() {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    #expect(workspace.undockedFrame(of: a) == nil)
    #expect(workspace.undockedFrames == nil)
  }

  @Test func replacingTheTreeRemembersTheWindowsItDocks() {
    var workspace = Workspace()
    workspace.floating[a] = small
    workspace.floating[b] = other
    workspace.floating[c] = other
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.reset(tree: .grid(of: [a, b], desktopWeight: 0.5))
    #expect(workspace.undockedFrames == [a: small, b: other], "what was docked before keeps its frame")
    #expect(workspace.floating == [c: other], "a docked window does not float as well")
    workspace.reset(tree: LayoutTree())
    #expect(workspace.undockedFrames == nil)
  }

  @Test func aWindowUnderANewNumberKeepsWhatIsRemembered() {
    var workspace = Workspace()
    workspace.floating[a] = small
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.replaceWindow(a, with: b)
    #expect(workspace.isDocked(b))
    #expect(workspace.undockedFrames == [b: small])
  }

  @Test func tryingADropOutChangesNothing() {
    var workspace = Workspace()
    workspace.floating[a] = small
    let before = workspace
    _ = workspace.previewFrame(
      for: a, at: .cameraEdge(.left), in: CGRect(x: 0, y: 0, width: 1000, height: 800), options: LayoutOptions(),
      isPresent: { _ in true })
    #expect(workspace == before)
  }

  // MARK: Files

  @Test func rememberedFramesRoundTrip() throws {
    var workspace = Workspace()
    workspace.floating[a] = small
    workspace.floating[b] = other
    workspace.dock(a, at: .cameraEdge(.left))
    let decoded = try JSONDecoder().decode(Workspace.self, from: JSONEncoder().encode(workspace))
    #expect(decoded == workspace)
    #expect(decoded.undockedFrame(of: a) == small)
  }

  /// A workspace as Arbor saved it before it remembered anything.
  @Test func aWorkspaceSavedBeforeThisExistedLoads() throws {
    var workspace = Workspace()
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.floating[b] = other
    var object = try #require(
      JSONSerialization.jsonObject(with: JSONEncoder().encode(workspace)) as? [String: Any])
    #expect(object["undockedFrames"] == nil, "nothing remembered leaves no key behind")
    object["undockedFrames"] = nil
    let decoded = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(decoded == workspace)
  }

  /// Hand-edited or damaged: the numbers are JSON, so they are finite, but can be anything else.
  @Test(arguments: [
    CGRect(x: 0, y: 0, width: 0, height: 300), CGRect(x: 0, y: 0, width: 400, height: 0.5),
    CGRect(origin: .zero, size: CGSize(width: -400, height: 300)),
    CGRect(x: CGFloat.infinity, y: 0, width: 400, height: 300),
    CGRect(x: 0, y: 0, width: CGFloat.nan, height: 300),
  ])
  func aFrameNoWindowCouldTakeIsIgnored(_ frame: CGRect) {
    var workspace = Workspace()
    workspace.floating[a] = frame
    workspace.dock(a, at: .cameraEdge(.left))
    #expect(workspace.undockedFrame(of: a) == nil)
  }

  @Test func whatIsRememberedAboutAWindowThatIsNotDockedIsIgnoredAndReplaced() throws {
    // Only a damaged file says this.
    var docked = Workspace()
    docked.floating[a] = small
    docked.dock(a, at: .cameraEdge(.left))
    var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(Workspace())) as? [String: Any])
    let saved = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(docked)) as? [String: Any])
    object["undockedFrames"] = saved["undockedFrames"]
    var workspace = try JSONDecoder().decode(Workspace.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(workspace.undockedFrame(of: a) == nil)
    workspace.floating[a] = other
    workspace.dock(a, at: .cameraEdge(.left))
    #expect(workspace.undockedFrame(of: a) == other)
  }

  @Test func readingAWorkspaceDropsWhatIsRememberedForNothing() throws {
    /// Saved and read back, with what the decoder noted.
    func reread(_ workspace: Workspace) throws -> (workspace: Workspace, notes: [String]) {
      let decoder = JSONDecoder()
      let notes = DecodingNotes()
      decoder.userInfo[DecodingNotes.key] = notes
      return (try decoder.decode(Workspace.self, from: JSONEncoder().encode(workspace)), notes.notes)
    }
    var workspace = Workspace()
    workspace.floating[a] = small
    workspace.floating[b] = CGRect(x: 0, y: 0, width: 0, height: 300)
    workspace.dock(a, at: .cameraEdge(.left))
    workspace.dock(b, at: .cameraEdge(.right))
    #expect(try reread(Workspace()).notes.isEmpty)
    let (fixed, notes) = try reread(workspace)
    #expect(fixed.undockedFrames == [a: small])
    #expect(notes == ["frames were remembered for windows that are not docked, or were impossible"])
    #expect(try reread(fixed).notes.isEmpty)
  }
}
