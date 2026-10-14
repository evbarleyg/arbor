import ApplicationServices
import ArborCore
import CoreGraphics
import Foundation

// F27, "Go to…": `find`, `reveal`, and the one panel of Arbor's that takes the keyboard. All three test windows are
// docked when this starts, and are again when it ends. The windows are called "Arbor Test 1" to "3".

extension Runner {
  /// The palette's window level: floating + 2 (UI/FinderPanel.swift).
  private static let paletteLevel = 5

  /// Whether Arbor has a window of its own on screen at this window level.
  private func arborShowsAWindow(atLevel level: Int) -> Bool {
    guard let pid = arborPID(),
      let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
    else { return false }
    return list.contains { info in
      (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == pid
        && (info[kCGWindowLayer as String] as? NSNumber)?.intValue == level
    }
  }

  private var paletteIsUp: Bool { arborShowsAWindow(atLevel: Self.paletteLevel) }

  /// The process that owns what has the keyboard, as Accessibility sees it from outside. No key is pressed here: this
  /// runner posts no input, so that it can run on a Mac somebody is using.
  private func keyboardOwner() -> pid_t? {
    var value: CFTypeRef?
    guard
      AXUIElementCopyAttributeValue(AXUIElementCreateSystemWide(), kAXFocusedUIElementAttribute as CFString, &value)
        == .success,
      let value, CFGetTypeID(value) == AXUIElementGetTypeID()
    else { return nil }
    var pid: pid_t = 0
    guard AXUIElementGetPid(value as! AXUIElement, &pid) == .success else { return nil }
    return pid
  }

  func goTo(_ w1: WindowID, _ w2: WindowID, _ w3: WindowID) throws {
    func focused() -> WindowID? { (try? state())?.focused }

    try step("find a window by its title", "find test 2") { _ in
      check("\(w2) is in view", comesIntoView(w2), whereabouts(w2))
      check("\(w2) has the keyboard", poll(3) { focused() == w2 }, "\(focused().map(\.description) ?? "nobody") has it")
    }
    try step("open Go to…", "find") { _ in
      check("the palette is on screen", poll(3) { self.paletteIsUp })
      observe("AppKit says it has the keyboard", poll(2) { self.arborLog().contains("the palette is up, with the keyboard") })
      let (owner, arbor) = (keyboardOwner(), arborPID())
      observe(
        "Accessibility says so too: what has the keyboard is Arbor's", owner != nil && owner == arbor,
        "pid \(owner.map(String.init) ?? "nobody"); Arbor is \(arbor.map(String.init) ?? "?"), the test app \(helperPID)")
      check("\(w2) still counts as focused: Arbor did not become the active app", focused() == w2)
    }
    try step("close Go to…", "find") { _ in
      check("the palette has gone", poll(3) { !self.paletteIsUp })
    }

    try step("open Go to… once more", "find") { _ in
      check("the palette is on screen", poll(3) { self.paletteIsUp })
    }
    step("another window takes the keyboard", by: "the app makes \(w1) key") {
      tell("key \(w1.rawValue)")
      observe("the palette closes when the keyboard goes elsewhere", poll(3) { !self.paletteIsUp })
    }
    if paletteIsUp { _ = try? send("find") }
    check("no palette is left behind", poll(3) { !self.paletteIsUp })

    step("send the third window to the Dock", by: "the app minimizes \(w3)") {
      tell("minimize \(w3.rawValue)")
      check("Arbor sees it", eventually { $0.window(w3)?.minimized == true })
    }
    try step("frame the first window again", "zoom \(w1.rawValue)") { _ in
      check("\(w2) is out of view", leavesView(w2), whereabouts(w2))
    }
    try step("bring the minimised window back", "reveal \(w3.rawValue)") { _ in
      check("\(w3) is no longer minimised", eventually { $0.window(w3)?.minimized == false })
      check("\(w3) has its slot, and is not a tile", eventually { $0.displays[0].windowFrames[w3] != nil })
      check("the windows match Arbor's layout once it is back", poll(5) { (try? self.state()).map(self.settled) ?? false }, mismatch())
      check("\(w3) is in view", comesIntoView(w3), whereabouts(w3))
      check("\(w3) has the keyboard", poll(3) { focused() == w3 }, "\(focused().map(\.description) ?? "nobody") has it")
    }

    step("hide the app", by: "the app hides itself, as ⌘H does") {
      tell("hide")
      check("Arbor sees it", eventually { $0.window(w2)?.hidden == true })
    }
    try step("bring a window of the hidden app back", "reveal \(w2.rawValue)") { _ in
      observe("the app shows again", eventually { $0.window(w2)?.hidden == false })
      observe("\(w2) is in view", comesIntoView(w2), whereabouts(w2))
      observe("the windows match Arbor's layout", poll(5) { (try? self.state()).map(self.settled) ?? false }, mismatch())
    }
    // Whatever came of it, the steps that follow need the windows.
    tell("unhide")
    check("the app is not left hidden", eventually { $0.window(w2)?.hidden == false })
  }
}
