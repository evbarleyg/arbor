import ArborCore
import ArborIPC
import CoreGraphics
import Foundation

// The last session: windows that open while Arbor runs, with "Dock New Windows" on (F23). What no headless test
// reaches: the order in which macOS reports a new window and its focus, whether Accessibility says that a window
// cannot be resized, what frame a window has at the moment it is reported, and the app's own wiring of the switch.

extension Runner {
  /// Has the test app open a window (ArborTestWindows/Commands.swift, `open`) and returns it.
  func openWindow(_ frame: CGRect, _ options: String = "") throws -> WindowID {
    tell("open \(Int(frame.minX)) \(Int(frame.minY)) \(Int(frame.width)) \(Int(frame.height)) \(options)")
    struct Reply: Decodable { let window: UInt32 }
    let line = helperOutput.map { readLine(from: $0.fileHandleForReading) } ?? ""
    guard let reply = try? JSONDecoder().decode(Reply.self, from: Data(line.utf8)) else {
      throw Setup(description: "ArborTestWindows did not report its new window (got: \(line))")
    }
    testWindows.append(WindowID(reply.window))
    return WindowID(reply.window)
  }

  func closeWindow(_ window: WindowID) {
    tell("close \(window.rawValue)")
    _ = eventually { $0.window(window) == nil }
    testWindows.removeAll { $0 == window }
  }

  /// Whether `window` floats and is still where its app opened it.
  private func floats(_ window: WindowID, at frame: CGRect) -> Bool {
    eventually { $0.displays[0].floating.contains(window) }
      && poll(2) { self.actualFrames()[window]?.approximatelyEquals(frame, tolerance: 3) == true }
  }

  func newWindows(_ w1: WindowID, _ w3: WindowID) throws {
    try Data(Self.handEditedSettings.utf8).write(to: settingsFile)
    try step("start once more", by: "Arbor, same home folder, settings.json without the typo") {
      try startArbor(managing: 2)
    }
    try step("start from a normal Mac", "float-all") { _ in }
    try step("dock one window", "dock \(w1.rawValue) left") { state in
      check("\(w1) is docked", state.displays[0].windowFrames[w1] != nil)
      check("it has the keyboard", eventually { $0.focused == w1 })
    }
    let visible = try state().displays[0].visibleFrame
    let place = CGRect(x: visible.minX + 60, y: visible.minY + 60, width: 440, height: 340)

    var floating = w1
    try step("a new window, as things are by default", by: "the app opens a window") {
      floating = try openWindow(place)
      check("it floats where its app put it", floats(floating, at: place), whereabouts(floating))
      closeWindow(floating)
    }
    try step("switch automatic docking on", "toggle-auto-dock") { _ in
      check("settings.json says so", settingsText().contains("\"newWindows\": \"dock\""), settingsText())
      check(
        "and kept what Arbor does not know or could not read",
        settingsText().contains("kept by arbor-e2e") && settingsText().contains("dock sideways"), settingsText())
    }
    try step("give the docked window the keyboard", "zoom \(w1.rawValue)") { _ in
      check("it has the keyboard", eventually { $0.focused == w1 })
    }
    var whole = CGRect.zero
    try step("show everything again", "show-all") { state in
      whole = state.displays[0].windowFrames[w1] ?? .zero
    }

    var docked = w1
    try step("a new window docks beside the focused one", by: "the app opens a window") {
      docked = try openWindow(place)
      check("it is docked", eventually { $0.displays[0].windowFrames[docked] != nil }, whereabouts(docked))
      let state = try state()
      let (old, new) = (state.displays[0].windowFrames[w1] ?? .zero, state.displays[0].windowFrames[docked] ?? .zero)
      check("the two share the slot the focused window had", old.union(new).approximatelyEquals(whole, tolerance: 2), "\(describe(old)) and \(describe(new))")
      check("the new one comes after it", new.minX > old.maxX || new.minY > old.maxY, "\(describe(old)) and \(describe(new))")
      check("nothing became a tile", state.displays[0].tiles.isEmpty)
      check("the view stayed", state.displays[0].camera == state.displays[0].tree.root)
      check("windows match Arbor's layout", poll(3) { (try? self.state()).map(self.settled) ?? false }, mismatch())
      observe("it has the keyboard", eventually { $0.focused == docked })
    }
    let shared = try state().displays[0].windowFrames

    try step("a small window floats", by: "the app opens a window of 300 x 200") {
      let frame = CGRect(x: place.minX, y: place.minY, width: 300, height: 200)
      let small = try openWindow(frame)
      check("it floats where its app put it", floats(small, at: frame), whereabouts(small))
      check("nobody made room", try state().displays[0].windowFrames == shared)
      closeWindow(small)
    }
    try step("a window of a fixed size floats", by: "the app opens a window that cannot be resized") {
      let fixed = try openWindow(place, "fixed")
      check("it floats where its app put it", floats(fixed, at: place), whereabouts(fixed))
      check("nobody made room", try state().displays[0].windowFrames == shared)
      closeWindow(fixed)
    }
    try step("a window that fits nowhere floats", by: "the app opens a window that insists on nearly all of the display") {
      // More than anyone can give, the Desktop included: room is made before a window is turned away (F61).
      let size = CGSize(width: visible.width - 200, height: visible.height - 100)
      let frame = CGRect(origin: CGPoint(x: visible.minX + 10, y: visible.minY + 10), size: size)
      let large = try openWindow(frame, "min \(Int(size.width)) \(Int(size.height))")
      check("it is back where its app put it", floats(large, at: frame), whereabouts(large))
      check("every window is back in its slot", layoutReturns(to: shared), mismatch())
      check("nothing became a tile", try state().displays[0].tiles.isEmpty)
      closeWindow(large)
    }
    try step("a native tab takes no slot of its own", by: "the app opens a tab in \(docked)") {
      let tab = try openTab(in: docked)
      testWindows.append(tab)
      observe("the tab takes over the slot", eventually { $0.displays[0].windowFrames[tab] == shared[docked] }, mismatch())
      observe("and nothing else docked", try state().displays[0].tree.allWindows.count == 2)
      closeWindow(tab)
      observe("the first tab has the slot back", layoutReturns(to: shared), mismatch())
    }
    step("closing the window gives its room back", by: "the app closes \(docked)") {
      closeWindow(docked)
      check("the first window has its slot back", layoutReturns(to: [w1: whole]), mismatch())
    }
    try step("switch automatic docking off", "toggle-auto-dock") { _ in
      check("settings.json says so", settingsText().contains("\"newWindows\": \"float\""), settingsText())
    }
    try step("a new window floats again", by: "the app opens a window") {
      let last = try openWindow(place)
      check("it floats where its app put it", floats(last, at: place), whereabouts(last))
      closeWindow(last)
    }
    step("quit for the last time", by: "quit") {
      quitArbor()
      for window in [w1, w3] {
        check("\(window) is on screen after quitting", comesIntoView(window), whereabouts(window))
      }
    }
  }
}
