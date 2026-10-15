import ArborCore
import Testing

@Suite struct CommandDisplaysTests {
  @Test(arguments: [
    "status", "state", "help", "get gap", "bindings", "shortcuts", "quit", "pause", "resume", "toggle-pause", "check-setup", "welcome", "check-for-updates",
    "settings-window", "settings-window shortcuts", "settings-window close", "ask-name cancel", "launch-at-login on", "trace status", "trace on x",
  ])
  func leavesWindowsAndViewsAlone(_ text: String) throws {
    #expect(try Command.parse(text).leavesWindowsAndViewsAlone)
  }

  /// Whatever is not listed is refused: a command added later is, until somebody has thought about it.
  @Test(arguments: [
    "show-all", "home", "desktop", "out", "in", "back", "forward", "zoom", "view 1", "dock left", "float", "toggle-float", "float-all", "float-all here", "arrange",
    "undo", "redo", "focus left", "swap left", "equalize", "rotate", "mirror", "grow", "shrink", "move-to-display next", "pin", "unpin", "summon Notes", "reveal",
    "find Notes", "find", "minimap", "ask-name", "name Work", "unname", "relayout", "reload-settings", "hold", "hold still", "release", "toggle-hold", "set gap 12",
    "set messages off", "toggle-auto-dock", "exclude", "pass-through", "save-view 1", "show-shortcuts",
  ])
  func doesNot(_ text: String) throws {
    #expect(try !Command.parse(text).leavesWindowsAndViewsAlone)
  }
}
