import ArborCore
import CoreGraphics
import Testing

@Suite struct WorkspaceShiftTests {
  /// Every frame a workspace holds is global. One added later belongs in `shift(by:)` and in here.
  @Test func everyRememberedFrameGoesWithTheDisplay() {
    var workspace = Workspace()
    let (docked, floats, summoned) = (WindowID(1), WindowID(2), WindowID(3))
    let frame = CGRect(x: 2000, y: 500, width: 600, height: 400)
    workspace.floating[docked] = frame
    workspace.dock(docked, at: .cameraEdge(.left))
    workspace.floating[floats] = frame
    workspace.floating[summoned] = frame
    workspace.summon(summoned, app: "com.example.terminal", at: frame)
    #expect(workspace.undockedFrames?[docked] == frame)
    let before = workspace

    workspace.shift(by: .zero)
    #expect(workspace == before)
    workspace.shift(by: CGPoint(x: -1440, y: 323))
    let there = frame.offsetBy(dx: -1440, dy: 323)
    #expect(workspace.floating == [floats: there, summoned: there])
    #expect(workspace.undockedFrames == [docked: there])
    #expect(workspace.summonFrames == ["com.example.terminal": there])
    #expect(workspace.tree == before.tree && workspace.summoned == before.summoned)
    workspace.shift(by: CGPoint(x: 1440, y: -323))
    #expect(workspace == before)
  }
}
