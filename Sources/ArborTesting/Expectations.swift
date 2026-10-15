import ArborCore
import ArborKit
import CoreGraphics

/// The `expect` lines of the documenter's scenarios (`collab/scenarios/*.sim`;
/// the forms are listed in `collab/README.md`, "Scenarios"), checked against a
/// harness. arbor-sim prints `EXPECTATION FAILED` for one that does not hold
/// and exits with code 1 at the end, which is what makes `make scenarios` fail
/// when a user journey breaks.
@MainActor
public enum ScenarioExpectation {
  public static let forms =
    "docked <id>, floating <id>, visible <id>, hidden <id>, tile <id>, fills <id>, "
    + "left-of <a> <b>, above <a> <b>, camera root|desktop|<id>, count docked <n>, ok, fail, "
    + "ring <id>|none, outline <id>|desktop|none, shortcut <keys> on|off, shortcut <keys> shows <label>, "
    + "shortcut <keys> key <code>, app-got <keys>|nothing, pinned <id>, in-front <id>, size <id> <w>x<h>, summoned <id>, space <name>, no-space <name>, "
    + "field open|closed, held view|still|no, focused <id>, said <words>, silent, "
    + "minimap none|everything|desktop|<id>, still [<id>], moved-once, jolt <id>, at <id> <x> <y> [<w>x<h>], "
    + "replied <words>, preview none|showing"

  /// Checks the words after `expect`. `lastCommandOK` is whether the previous
  /// command succeeded, for `ok` and `fail`. Returns nil when the expectation
  /// holds, otherwise a sentence saying why it does not.
  /// `lastReply` is what the previous line printed, for `replied`.
  public static func check(_ words: [String], harness h: Harness, lastCommandOK: Bool, lastReply: String? = nil) -> String? {
    let controller = h.controller
    func window(_ index: Int) -> WindowID? {
      words.indices.contains(index) ? WindowID(word: words[index]) : nil
    }
    func frame(_ id: WindowID) -> CGRect? { h.system.frame(of: id) }
    func place(_ id: WindowID) -> String {
      frame(id).map { "\(id) at \(describe($0))" } ?? "\(id) (no such window)"
    }

    switch (words.first?.lowercased(), words.count) {
    case ("docked", 2):
      guard let id = window(1) else { return usage(words) }
      guard controller.windows[id] != nil else { return "there is no window \(id)" }
      return isDocked(id, controller) ? nil : "\(id) is not docked"

    case ("floating", 2):
      guard let id = window(1) else { return usage(words) }
      guard let display = controller.workspaceID(containing: id) else { return "\(id) is not on any display" }
      return controller.workspaces[display]?.isFloating(id) == true ? nil : "\(id) is docked"

    case ("visible", 2):
      guard let id = window(1) else { return usage(words) }
      return whyNotVisible(id, controller, h.system)

    case ("hidden", 2):
      guard let id = window(1) else { return usage(words) }
      guard let snapshot = controller.windows[id] else { return "there is no window \(id)" }
      guard whyNotVisible(id, controller, h.system) != nil else { return "\(place(id)) is visible" }
      // Arbor thinking it is out of view is not enough: no more than a sliver may show on any display.
      let showing = h.system.displayList.map { snapshot.frame.fractionInside($0.frame) }.reduce(0, +)
      return snapshot.isPresent && showing > 0.02 ? "\(place(id)) should be out of view but shows on a display" : nil

    case ("tile", 2):
      guard let id = window(1) else { return usage(words) }
      guard let display = controller.workspaceID(containing: id), let layout = controller.layouts[display] else {
        return "\(id) is not on any display"
      }
      return layout.tiles.contains { $0.windows.contains(id) } ? nil : "\(id) is not inside a tile"

    case ("fills", 2):
      guard let id = window(1) else { return usage(words) }
      guard let displayID = controller.workspaceID(containing: id), let display = controller.display(displayID),
        let frame = frame(id)
      else { return "\(id) is not on any display" }
      let gap = CGFloat(controller.options(for: displayID).gap)
      let expected = display.visibleFrame.insetBy(dx: gap, dy: gap)
      return frame.approximatelyEquals(expected, tolerance: 1)
        ? nil : "\(id) is at \(describe(frame)), not \(describe(expected))"

    case ("left-of", 3):
      guard let a = window(1), let b = window(2) else { return usage(words) }
      guard let fa = frame(a), let fb = frame(b) else { return "\(place(a)), \(place(b))" }
      return fa.maxX <= fb.minX + 0.5 ? nil : "\(place(a)) is not left of \(place(b))"

    case ("above", 3):
      guard let a = window(1), let b = window(2) else { return usage(words) }
      guard let fa = frame(a), let fb = frame(b) else { return "\(place(a)), \(place(b))" }
      return fa.maxY <= fb.minY + 0.5 ? nil : "\(place(a)) is not above \(place(b))"

    case ("camera", 2):
      let displayID: DisplayID
      let node: NodeID
      switch words[1].lowercased() {
      case "root":
        displayID = h.display
        node = h.workspace.tree.root
      case "desktop":
        displayID = h.display
        node = h.workspace.tree.desktop
      default:
        guard let id = window(1) else { return usage(words) }
        guard let display = controller.workspaceID(containing: id),
          let leaf = controller.workspaces[display]?.tree.leaf(containing: id)
        else { return "\(id) is not docked, so the camera cannot be on it" }
        displayID = display
        node = leaf
      }
      guard let camera = controller.workspaces[displayID]?.camera else { return "no workspace for \(displayID)" }
      return camera == node ? nil : "the camera is on \(camera), not \(node) (\(words[1]))"

    case ("count", 3) where words[1].lowercased() == "docked":
      guard let expected = Int(words[2]) else { return usage(words) }
      // Windows that exist. A saved slot that waits for its window (Controller+PendingSlots.swift) is not one.
      let count = controller.workspaces.values.flatMap(\.tree.allWindows).filter { controller.windows[$0] != nil }.count
      return count == expected ? nil : "\(count) window(s) are docked, not \(expected)"

    case ("shortcut", 4):
      guard let chord = try? KeyChord(text: words[1]) else { return usage(words) }
      guard let binding = controller.effectiveBindings.bindings.first(where: { $0.chord == chord }) else {
        return "\(chord.text) is not a shortcut in effect"
      }
      switch words[2].lowercased() {
      case "shows":
        return binding.label == words[3] ? nil : "\(chord.text) shows as \(binding.label), not \(words[3])"
      case "key":
        guard let code = UInt32(words[3]) else { return usage(words) }
        return binding.keyCode == code ? nil : "\(chord.text) is key \(binding.keyCode), not \(code)"
      default:
        return usage(words)
      }

    case ("shortcut", 3):
      guard let chord = try? KeyChord(text: words[1]), ["on", "off"].contains(words[2].lowercased()) else {
        return usage(words)
      }
      let held = controller.activeBindings.contains { $0.chord == chord }
      if held == (words[2].lowercased() == "on") { return nil }
      return held ? "Arbor holds \(chord.text)" : "Arbor does not hold \(chord.text): the app in front gets it"

    case ("app-got", 2):
      // The shortcuts pressed so far (`key`, `keydown`) that nobody held, so that they went to the app in front.
      let got = h.system.keysTheAppInFrontGot.map(\.text)
      if words[1].lowercased() == "nothing" {
        return got.isEmpty ? nil : "the app in front got \(got.joined(separator: ", "))"
      }
      guard let chord = try? KeyChord(text: words[1]) else { return usage(words) }
      if got.last == chord.text { return nil }
      return got.isEmpty ? "the app in front got nothing" : "the last key the app in front got is \(got[got.count - 1])"

    case ("pinned", 2):
      guard let id = window(1) else { return usage(words) }
      guard controller.windows[id] != nil else { return "there is no window \(id)" }
      return controller.isPinned(id) ? nil : "\(id) is not pinned"

    case ("summoned", 2):
      guard let id = window(1) else { return usage(words) }
      guard controller.windows[id] != nil else { return "there is no window \(id)" }
      if case .summoned = controller.role(of: id) { return nil }
      return "\(id) is not summoned"

    case ("in-front", 2):
      guard let id = window(1) else { return usage(words) }
      guard let own = frame(id) else { return "there is no window \(id)" }
      let above = h.system.windowsFrontToBack().prefix { $0 != id }
      return above.first { frame($0)?.overlaps(own) == true }.map { "\($0) covers \(id)" }

    case ("ok", 1):
      return lastCommandOK ? nil : "the previous command failed"

    case ("fail", 1):
      return lastCommandOK ? "the previous command succeeded" : nil

    case ("ring", 2):
      let rings = h.overlays.scenes.sorted { $0.key < $1.key }.compactMap(\.value.focusRing)
      if words[1].lowercased() == "none" {
        return rings.first.map { "the focus ring is around \($0.window)" }
      }
      guard let id = window(1) else { return usage(words) }
      guard let ring = rings.first else { return "there is no focus ring" }
      guard rings.count == 1 else { return "there are \(rings.count) focus rings" }
      guard ring.window == id else { return "the focus ring is around \(ring.window), not \(id)" }
      return ring.frame == frame(id) ? nil : "the focus ring is at \(describe(ring.frame)), not around \(place(id))"

    case ("outline", 2):
      let outlines = h.overlays.scenes.sorted { $0.key < $1.key }.compactMap(\.value.peekOutline)
      let word = words[1].lowercased()
      if word == "none" { return outlines.first.map { "there is an outline at \(describe($0))" } }
      guard let outline = outlines.first else { return "nothing is outlined" }
      guard outlines.count == 1 else { return "there are \(outlines.count) outlines" }
      if word == "desktop" {
        let desktops = controller.layouts.values.compactMap(\.desktopFrame)
        return desktops.contains(outline) ? nil : "the outline is at \(describe(outline)), not around the Desktop"
      }
      guard let id = window(1) else { return usage(words) }
      return outline == frame(id) ? nil : "the outline is at \(describe(outline)), not around \(place(id))"

    case ("held", 2):
      let expected = HoldLevel(rawValue: words[1].lowercased())
      guard expected != nil || words[1].lowercased() == "no" else { return usage(words) }
      return controller.holdLevel == expected ? nil : "held: \(controller.holdLevel?.rawValue ?? "no"), not \(words[1])"

    case ("focused", 2):
      guard let id = window(1) else { return usage(words) }
      return h.system.focused == id ? nil : "\(h.system.focused.map { "\($0)" } ?? "no window") has the keyboard, not \(id)"

    case ("size", 3):
      let numbers = words[2].lowercased().split(separator: "x", omittingEmptySubsequences: false).map { Double($0) }
      guard let id = window(1), numbers.count == 2, let width = numbers[0], let height = numbers[1] else {
        return usage(words)
      }
      guard let frame = frame(id) else { return "there is no window \(id)" }
      return abs(frame.width - width) <= 1 && abs(frame.height - height) <= 1
        ? nil : "\(place(id)) is not \(words[2]) in size"

    case ("still", 1...2) where h.stepMark == nil, ("moved-once", 1) where h.stepMark == nil,
      ("jolt", 2) where h.stepMark == nil:
      // A replay answers Arbor's requests from the trace, so the stand-in's log of moves says nothing there.
      return "`\(words[0])` looks at the line before, which only arbor-sim's scripts have: not for the `.expect` file of a trace"

    case ("still", 1):
      // What Arbor did during the line before: a window it asked to be where it was already has not moved.
      let moved = h.movesInStep.keys.sorted()
      return moved.isEmpty ? nil : "Arbor moved \(moved.map { "\($0)" }.joined(separator: ", "))"

    case ("still", 2):
      guard let id = window(1) else { return usage(words) }
      guard frame(id) != nil else { return "there is no window \(id)" }
      return h.movesInStep[id] == nil ? nil : "Arbor moved \(place(id))"

    case ("moved-once", 1):
      let moves = h.movesInStep
      guard !moves.isEmpty else { return "Arbor moved nothing" }
      let twice = moves.filter { $0.value > 1 }.sorted { $0.key < $1.key }
      return twice.isEmpty ? nil : twice.map { "Arbor moved \($0.key) \($0.value) times" }.joined(separator: ", ")

    case ("jolt", 2):
      guard let id = window(1) else { return usage(words) }
      // Also one that an app's refusal excuses: it is the same fault on a desk where some app happens to refuse a size.
      return h.jolts.contains { $0.window == id }
        ? nil : "\(id) was not moved twice: if the known fault has been mended, this line can go, and its row on the board"

    case ("at", 4):
      guard let id = window(1), let x = Double(words[2]), let y = Double(words[3]) else { return usage(words) }
      guard let frame = frame(id) else { return "there is no window \(id)" }
      return abs(frame.minX - x) <= 1 && abs(frame.minY - y) <= 1 ? nil : "\(place(id)) is not at \(words[2]),\(words[3])"

    case ("replied", 2...):
      let wanted = words.dropFirst().joined(separator: " ")
      guard let lastReply else { return "`replied` looks at the line before, which only arbor-sim's scripts have" }
      return lastReply.lowercased().contains(wanted.lowercased()) ? nil : "the reply does not say “\(wanted)”"

    case ("preview", 2):
      switch words[1].lowercased() {
      case "none": return h.overlays.preview.map { "a drop preview is showing at \(describe($0))" }
      case "showing": return h.overlays.preview == nil ? "no drop preview is showing" : nil
      default: return usage(words)
      }

    case ("at", 5):
      // To the point: this is for windows that nobody is meant to have moved.
      let numbers = words[4].lowercased().split(separator: "x", omittingEmptySubsequences: false).map { Double($0) }
      guard let id = window(1), let x = Double(words[2]), let y = Double(words[3]), numbers.count == 2,
        let width = numbers[0], let height = numbers[1]
      else { return usage(words) }
      guard let frame = frame(id) else { return "there is no window \(id)" }
      return frame == CGRect(x: x, y: y, width: width, height: height)
        ? nil : "\(place(id)) is not at \(words[2]),\(words[3]) \(words[4])"

    case ("said", 2...):
      // The heads-up line on screen now, on any display. It stays until its time is up (`flush`).
      let wanted = words.dropFirst().joined(separator: " ").lowercased()
      let lines = h.overlays.headsUp.values.map(\.line)
      guard !lines.isEmpty else { return "nothing is being said on screen" }
      return lines.contains { $0.lowercased().contains(wanted) }
        ? nil : "the line on screen is “\(lines.sorted().joined(separator: "”, “"))”"

    case ("silent", 1):
      let lines = h.overlays.headsUp.values.map(\.line)
      return lines.isEmpty ? nil : "the line on screen is “\(lines.sorted().joined(separator: "”, “"))”"

    case ("space", 2...):
      // The view of some display is on the space of that name.
      let name = words.dropFirst().joined(separator: " ")
      let holders = controller.workspaces.sorted { $0.key < $1.key }.filter { $0.value.node(named: name) != nil }
      guard !holders.isEmpty else { return "no space is named \(name)" }
      if holders.contains(where: { $0.value.camera == $0.value.node(named: name) }) { return nil }
      return "\(name) is \(holders[0].value.node(named: name)!), and the camera is on \(holders[0].value.camera)"

    case ("no-space", 2...):
      let name = words.dropFirst().joined(separator: " ")
      let holder = controller.workspaces.sorted { $0.key < $1.key }.compactMap { $0.value.node(named: name) }.first
      return holder.map { "\(name) is the name of \($0)" }

    case ("field", 2):
      switch words[1].lowercased() {
      case "open": return h.overlays.namePrompt == nil ? "the name field is not showing" : nil
      case "closed": return h.overlays.namePrompt == nil ? nil : "the name field is showing"
      default: return usage(words)
      }

    case ("minimap", 2):
      // What the minimap marks as filling the view, on the main display.
      let model = h.overlays.minimaps[h.display]
      let word = words[1].lowercased()
      if word == "none" { return model.map { "the minimap shows: \($0.line)" } }
      guard let model else { return "no minimap is showing" }
      let marked: CGRect?
      switch word {
      case "everything":
        marked = ([model.desktop].compactMap { $0 } + model.items.map(\.frame)).reduce(CGRect.null) { $0.union($1) }
      case "desktop":
        marked = model.desktop
      default:
        guard let id = window(1) else { return usage(words) }
        marked = model.items.first { $0.window == id }?.frame
      }
      guard let marked else { return "\(words[1]) is not on the minimap: \(model.line)" }
      return model.highlight == marked ? nil : "the minimap does not mark \(words[1]): \(model.line)"

    default:
      let verbs = [
        "docked", "floating", "visible", "hidden", "tile", "fills", "left-of", "above", "camera", "count", "ok", "fail", "ring", "minimap", "outline", "shortcut", "app-got", "pinned", "in-front", "size",
        "summoned", "space", "no-space", "field", "said", "silent",
        "held", "focused", "still", "moved-once", "jolt", "at", "replied", "preview",
      ]
      if let verb = words.first?.lowercased(), verbs.contains(verb) { return usage(words) }
      return "unknown expectation `\(words.joined(separator: " "))`; the forms are: \(forms)"
    }
  }

  private static func usage(_ words: [String]) -> String {
    "cannot read `\(words.joined(separator: " "))`; the forms are: \(forms)"
  }

  private static func isDocked(_ id: WindowID, _ controller: Controller) -> Bool {
    controller.workspaces.values.contains { $0.isDocked(id) }
  }

  /// Why a window is not showing: minimized, hidden, on another Space,
  /// parked out of view, docked but left out of the layout (inside a tile,
  /// an inactive tab, outside the camera's view), or mostly off screen.
  private static func whyNotVisible(
    _ id: WindowID, _ controller: Controller, _ system: FakeWindowSystem
  ) -> String? {
    if controller.isPaused {
      // The controller is not looking, so where the window really is is all there is to say.
      guard let frame = system.frame(of: id) else { return "there is no window \(id)" }
      return system.isVisible(id) ? nil : "\(id) is mostly off screen at \(describe(frame))"
    }
    guard let snapshot = controller.windows[id] else { return "there is no window \(id)" }
    if snapshot.isMinimized { return "\(id) is minimized" }
    if snapshot.isHidden { return "\(id)'s app is hidden" }
    if !snapshot.isOnActiveSpace { return "\(id) is on another Space" }
    if snapshot.isFullScreen { return "\(id) is in full screen" }
    if controller.parked.contains(id) { return "\(id) is parked at \(describe(snapshot.frame))" }
    if let display = controller.workspaceID(containing: id), controller.workspaces[display]?.isDocked(id) == true,
      controller.layouts[display]?.windowFrames[id] == nil
    {
      return "\(id) is docked but not shown (inside a tile, an inactive tab, or outside the view)"
    }
    if !system.isVisible(id) { return "\(id) is mostly off screen at \(describe(snapshot.frame))" }
    return nil
  }

  private static func describe(_ rect: CGRect) -> String {
    "(\(Int(rect.minX)),\(Int(rect.minY)) \(Int(rect.width))×\(Int(rect.height)))"
  }
}
