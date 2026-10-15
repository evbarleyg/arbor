import CoreGraphics

/// Draws a layout as text, for tests, `arborctl ascii` and arbor-sim.
///
/// Docked windows are boxes drawn with `+-|`, tiles with `#`, the Desktop
/// with `.`, floating windows with `~`, and with `:` a docked window that is let be, where it stands: its slot or
/// its tile shows the place that is kept for it. A docked window that is larger than its place is drawn in its place, as the tree has
/// it, and the side it hangs over is drawn with `>`, `<`, `v` or `^`.
/// Each box is labelled in its top-left corner. Under the drawing: the node in view with its name, the
/// windows out of view, those that are let be, those that hang over their places and by how much, and on a line of their own the names of the
/// display's spaces.
public enum AsciiRenderer {
  public static func render(
    _ layout: Layout, tree: LayoutTree, floating: [WindowID: CGRect] = [:], letBe: [WindowID: CGRect] = [:],
    columns: Int = 72, rows: Int = 22, names: [String: NodeID] = [:], label: (WindowID) -> String = { $0.description }
  ) -> String {
    let frame = layout.frame
    guard frame.width > 0, frame.height > 0, columns > 2, rows > 2 else { return "" }
    var grid = Array(repeating: Array(repeating: Character(" "), count: columns), count: rows)

    /// Clamps before converting, because `Int(_:)` traps on a value that is too large or not a number.
    func index(_ fraction: CGFloat, of count: Int) -> Int {
      let position = (fraction * CGFloat(count)).rounded(.down)
      return position.isNaN ? 0 : Int(min(max(position, 0), CGFloat(count - 1)))
    }

    func cell(_ x: CGFloat, _ y: CGFloat) -> (Int, Int) {
      (index((x - frame.minX) / frame.width, of: columns), index((y - frame.minY) / frame.height, of: rows))
    }

    func box(
      _ rect: CGRect, corner: Character, horizontal: Character, vertical: Character, text: String, reachingTo reach: CGRect? = nil
    ) {
      let (x0, y0) = cell(rect.minX, rect.minY)
      var (x1, y1) = cell(rect.maxX - 0.01, rect.maxY - 0.01)
      x1 = max(x1, x0 + 1)
      y1 = max(y1, y0 + 1)
      x1 = min(x1, columns - 1)
      y1 = min(y1, rows - 1)
      for x in x0...x1 {
        grid[y0][x] = horizontal
        grid[y1][x] = horizontal
      }
      for y in y0...y1 {
        grid[y][x0] = vertical
        grid[y][x1] = vertical
      }
      for (x, y) in [(x0, y0), (x1, y0), (x0, y1), (x1, y1)] { grid[y][x] = corner }
      if let reach {
        if reach.maxX > rect.maxX { for y in y0...y1 { grid[y][x1] = ">" } }
        if reach.minX < rect.minX { for y in y0...y1 { grid[y][x0] = "<" } }
        if reach.maxY > rect.maxY { for x in x0...x1 { grid[y1][x] = "v" } }
        if reach.minY < rect.minY { for x in x0...x1 { grid[y0][x] = "^" } }
      }
      let room = max(x1 - x0 - 1, 0)
      let textRow = y1 - y0 >= 2 ? y0 + 1 : y0
      for (offset, character) in text.prefix(room).enumerated() {
        grid[textRow][x0 + 1 + offset] = character
      }
    }

    if let desktop = layout.desktopFrame {
      box(desktop, corner: ".", horizontal: ".", vertical: ".", text: "desktop")
    }
    for (window, rect) in layout.windowFrames.sorted(by: { $0.key < $1.key }) {
      let place = layout.tightPlaces[window]
      box(place ?? rect, corner: "+", horizontal: "-", vertical: "|", text: label(window), reachingTo: place == nil ? nil : rect)
    }
    for tile in layout.tiles {
      let text: String
      switch tile.kind {
      case .window: text = tile.windows.first.map(label) ?? "tile"
      case .group: text = "\(tile.windows.count) windows"
      case .desktop: text = "desktop"
      }
      let name = names.first { $0.value == tile.node }?.key
      box(tile.frame, corner: "#", horizontal: "#", vertical: "#", text: name ?? text)
    }

    // Floating windows are drawn on top, with `~` edges.
    for (window, rect) in floating.sorted(by: { $0.key < $1.key }) where rect.overlaps(frame) {
      box(rect.intersection(frame), corner: "~", horizontal: "~", vertical: "~", text: label(window))
    }

    // Where the layout has them they are not. Last: it is what a reader does not expect, and must not be painted over.
    for (window, rect) in letBe.sorted(by: { $0.key < $1.key }) where rect.overlaps(frame) {
      box(rect.intersection(frame), corner: ":", horizontal: ":", vertical: ":", text: label(window))
    }

    var lines = grid.map { String($0) }
    let hidden = layout.hiddenWindows.subtracting(letBe.keys).sorted().map(label)
    let inView = names.first { $0.value == layout.camera }.map { " \($0.key)" } ?? ""
    func points(_ value: CGFloat) -> String { value == value.rounded() ? "\(Int(value))" : "\(Double(value))" }
    let over = layout.overhangs.sorted { $0.key < $1.key }.map { window, by in
      label(window) + " by " + [by.width, by.height].filter { $0 > 0 }.map(points).joined(separator: " and ")
    }
    lines.append(
      "camera \(layout.camera)" + inView + (hidden.isEmpty ? "" : "  hidden: \(hidden.joined(separator: " "))")
        + (letBe.isEmpty ? "" : "  let be: \(letBe.keys.sorted().map(label).joined(separator: " "))")
        + (over.isEmpty ? "" : "  over its place: \(over.joined(separator: ", "))"))
    if !names.isEmpty {
      lines.append("spaces: " + SpaceName.sorted(names.keys).map { "\($0) \(names[$0]!)" }.joined(separator: ", "))
    }
    return lines.joined(separator: "\n")
  }
}
