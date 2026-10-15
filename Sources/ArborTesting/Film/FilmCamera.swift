import ArborCore
import ArborKit
import CoreGraphics
import Foundation

/// Writes down what a display shows at one moment, as one JSON object: every window, everything Arbor draws, the pointer and
/// the keys. `docs/FILM.md` describes the format. Whoever reads it needs no knowledge of Arbor to paint the picture, or to
/// judge it: shapes come as paths, colours as CSS colours, and what fades or glides is where and as faint as it is at that moment.
///
/// All rectangles are `[x, y, width, height]` in global points, origin top-left, y down, unless the format says otherwise.
@MainActor
public final class FilmCamera {
  public let harness: Harness
  public let playback: OverlayPlayback
  public let hands: FilmHands
  /// The colour Arbor would take from each app's icon (`IconColour`), by the app's name. An app without one is grey, as on a Mac.
  public var appColours: [String: RGBA] = [:]
  /// macOS's accent colour: its blue, unless the film says otherwise.
  public var accent = RGBA(red: 0, green: 0.478, blue: 1)
  /// The film's own notes, which Arbor knows nothing of: a caption, the number of a shot, a badge in the Dock. They are handed on
  /// with every frame until they change.
  public var marks: [String: String] = [:]
  /// The radius macOS 26 gives a window's corners (`ContinuousCorners.windowRadius`).
  public static let windowRadius: CGFloat = 17

  public init(_ harness: Harness) {
    self.harness = harness
    playback = OverlayPlayback(harness.overlays, clock: { [scheduler = harness.scheduler] in scheduler.now })
    hands = FilmHands(harness)
    // With the setting on, and macOS taken to allow it, every window has a picture of itself to travel as.
    playback.hasPicture = { [controller = harness.controller] _ in controller.settings.windowPictures }
  }

  // MARK: Small parts

  /// Hundredths of a point are finer than any pixel, and whole numbers are shorter without a fraction.
  static func number(_ value: Double) -> Any {
    guard value.isFinite else { return 0 }
    let rounded = (value * 100).rounded() / 100
    return rounded == rounded.rounded() && abs(rounded) < 1e9 ? Int(rounded) as Any : rounded as Any
  }

  static func number(_ value: CGFloat) -> Any { number(Double(value)) }
  static func rect(_ rect: CGRect) -> [Any] { [number(rect.minX), number(rect.minY), number(rect.width), number(rect.height)] }
  static func point(_ point: CGPoint) -> [Any] { [number(point.x), number(point.y)] }

  static func colour(_ colour: RGBA) -> String {
    func byte(_ value: Double) -> Int { Int((value * 255).rounded()) }
    return "rgba(\(byte(colour.red)),\(byte(colour.green)),\(byte(colour.blue)),\((colour.alpha * 1000).rounded() / 1000))"
  }

  /// An outline in the words of an SVG path, which `Path2D` reads too.
  static func path(_ elements: [PathElement]) -> String {
    func text(_ point: CGPoint) -> String { "\(number(point.x)) \(number(point.y))" }
    return elements.map { element in
      switch element {
      case .move(let point): "M\(text(point))"
      case .line(let point): "L\(text(point))"
      case .curve(let point, let control1, let control2): "C\(text(control1)) \(text(control2)) \(text(point))"
      case .close: "Z"
      }
    }.joined()
  }

  private func appColour(pid: Int32) -> RGBA? {
    harness.system.windows.values.first { $0.snapshot.pid == pid }.flatMap { appColours[$0.snapshot.appName] }
  }

  private func appName(pid: Int32) -> String? {
    harness.system.windows.values.first { $0.snapshot.pid == pid }?.snapshot.appName
  }

  /// `AppAppearance.colour`: the icon's colour as a plain fill, darkened a little; grey without one.
  private func plainColour(pid: Int32) -> RGBA {
    appColour(pid: pid)?.mixed(with: .black, amount: 0.25) ?? RGBA(red: 0.557, green: 0.557, blue: 0.576)
  }

  // MARK: The header

  /// The first line of a film: what holds for all of it.
  public func header(fps: Int) -> [String: Any] {
    let display = harness.system.displayList[0]
    return [
      "film": 1, "fps": fps,
      "display": ["frame": Self.rect(display.frame), "visible": Self.rect(display.visibleFrame)],
      "accent": Self.colour(accent), "windowRadius": Self.number(Self.windowRadius),
      "apps": appColours.mapValues { Self.colour($0) },
    ]
  }

  // MARK: A frame

  public func frame(number: Int, fps: Int) -> [String: Any] {
    let system = harness.system
    let display = system.displayList[0]
    let scene = harness.overlays.scenes[display.id]
    var frame: [String: Any] = [
      "n": number, "t": Self.number(Double(number) / Double(fps)),
      "pointer": ["at": Self.point(hands.pointer), "down": hands.isButtonDown],
      "windows": windows(),
    ]
    if !marks.isEmpty { frame["marks"] = marks }
    if let keys = keys() { frame["keys"] = keys }

    let backdrops = playback.backdrops(on: display.id).map { backdrop($0.model, opacity: $0.opacity) }
    if !backdrops.isEmpty { frame["backdrop"] = backdrops }
    let tiles = playback.tiles(on: display.id).map { tile($0.model, opacity: $0.opacity) }
    if !tiles.isEmpty { frame["tiles"] = tiles }
    if let handle = gapHandle(showing: scene?.showsSeamHandles ?? false) { frame["gapHandle"] = handle }
    if let ring = scene?.focusRing { frame["ring"] = self.ring(ring) }
    if let outline = scene?.peekOutline { frame["peek"] = Self.rect(outline) }
    if let preview = playback.dropPreview {
      frame["preview"] = ["frame": Self.rect(preview.model), "opacity": Self.number(preview.opacity)]
    }
    if let stage = playback.stage(on: display.id) { frame["stage"] = self.stage(stage) }
    if let prompt = scene?.namePrompt {
      frame["nameField"] = ["frame": Self.rect(prompt.frame), "title": prompt.title, "text": prompt.initial]
    }
    if let line = playback.headsUpLine { frame["headsUp"] = headsUp(line.model, opacity: line.opacity) }
    if let map = playback.minimap(on: display.id) { frame["minimap"] = minimap(map.model, opacity: map.opacity) }
    if let sheet = playback.shortcutsPanel { frame["shortcuts"] = shortcuts(sheet.model, opacity: sheet.opacity) }
    if let finder = harness.overlays.finder { frame["goTo"] = goTo(finder) }
    if hands.arborIsInTheMenuBar { frame["menuBar"] = menuBar() }
    if let menu = hands.menu { frame["menu"] = self.menu(menu) }
    return frame
  }

  /// One line of JSON, keys in order, so that the same film is the same text.
  public static func line(_ object: [String: Any]) -> String {
    let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes])
    return data.map { String(decoding: $0, as: UTF8.self) } ?? "{}"
  }

  /// Back to front. Windows that are out of view are where Arbor put them, past a corner of the display.
  private func windows() -> [[String: Any]] {
    let system = harness.system
    return system.windowsFrontToBack().reversed().compactMap { id in
      guard let window = system.windows[id]?.snapshot, window.isPresent else { return nil }
      var entry: [String: Any] = [
        "id": Int(id.rawValue), "app": window.appName, "title": window.title, "frame": Self.rect(window.frame),
      ]
      if system.focused == id { entry["focused"] = true }
      return entry
    }
  }

  private func keys() -> [String: Any]? {
    func names(_ modifiers: KeyChord.Modifiers) -> [String] {
      let all: [(KeyChord.Modifiers, String)] = [(.control, "ctrl"), (.option, "opt"), (.shift, "shift"), (.command, "cmd")]
      return all.filter { modifiers.contains($0.0) }.map(\.1)
    }
    if let chord = hands.chords.last {
      return ["modifiers": names(chord.modifiers), "key": chord.key.name, "label": chord.label]
    }
    if let key = hands.typingKey { return ["modifiers": [String](), "key": key, "label": key] }
    // Held by themselves: there is no key, and the label is their signs.
    guard !hands.modifiers.isEmpty else { return nil }
    return ["modifiers": names(hands.modifiers), "label": String(KeyChord(hands.modifiers, .space).label.dropLast(5))]
  }

  private func backdrop(_ model: BackdropModel, opacity: Double) -> [String: Any] {
    var entry: [String: Any] = [
      "path": Self.path(model.outline(slotRadius: Self.windowRadius)), "fill": Self.colour(model.fill(accent: accent)),
      "blur": Self.number(model.blur), "opacity": Self.number(opacity),
    ]
    // One pixel wide on a Mac; half a point is that on a Retina display.
    if let outline = model.desktopOutline(width: 0.5, radius: Self.windowRadius) {
      entry["desktopEdge"] = [
        "path": Self.path(outline), "width": 0.5, "stroke": Self.colour(RGBA.white.withAlpha(model.desktopEdge)),
      ]
    }
    return entry
  }

  /// `TileArt`'s answers, moved from the tile's own coordinates to global ones by `frame`'s origin.
  private func tile(_ model: TileModel, opacity: Double) -> [String: Any] {
    let art = TileArt(model, isDark: false, scale: 2, cornerRadius: Self.windowRadius) { self.appColour(pid: $0.pid) }
    func plate(_ plate: TileArt.Plate) -> [String: Any] {
      [
        "frame": Self.rect(plate.frame), "path": Self.path(plate.outline), "top": Self.colour(plate.top),
        "bottom": Self.colour(plate.bottom), "borderPath": Self.path(plate.borderOutline),
        "border": Self.colour(plate.border), "borderWidth": Self.number(plate.borderWidth),
      ]
    }
    func label(_ label: TileArt.Label) -> [String: Any] {
      [
        "text": label.text, "frame": Self.rect(label.frame), "size": Self.number(label.size), "strong": label.isStrong,
        "align": label.alignment == .centre ? "center" : "left", "colour": Self.colour(label.colour),
      ]
    }
    var entry: [String: Any] = [
      "node": model.node.rawValue, "kind": model.kind.rawValue, "frame": Self.rect(model.frame),
      "opacity": Self.number(opacity), "plate": plate(art.plate), "shadow": art.castsShadow,
      "cells": art.cells.map(plate),
      "icons": art.icons.map { ["app": appName(pid: $0.pid) ?? "", "frame": Self.rect($0.frame)] as [String: Any] },
    ]
    if let glyph = art.glyph {
      entry["glyph"] = ["symbol": glyph.symbol, "frame": Self.rect(glyph.frame), "colour": Self.colour(glyph.colour)]
    }
    if let caption = art.caption { entry["caption"] = label(caption) }
    if let badge = art.badge {
      entry["badge"] = ["path": Self.path(badge.outline), "fill": Self.colour(badge.fill), "label": label(badge.label)]
    }
    return entry
  }

  /// `SeamView.draw`: nothing at rest, a pill under the pointer, the pill in the accent colour while it is dragged.
  private func gapHandle(showing: Bool) -> [String: Any]? {
    let dragged = hands.draggedSeam
    guard showing, let seam = dragged ?? hands.seam(at: hands.pointer), seam.frame.width >= 2, seam.frame.height >= 2,
      let pill = SeamHandle.pill(in: seam.frame, axis: seam.axis)
    else { return nil }
    return [
      "path": Self.path(RoundedPath.capsule(pill)), "axis": seam.axis.rawValue, "dragged": dragged != nil,
      "fill": Self.colour(dragged != nil ? accent : RGBA.white.withAlpha(0.9)),
    ]
  }

  private func ring(_ model: FocusRingModel) -> [String: Any] {
    func band(_ band: FocusRingModel.Band) -> [String: Any] {
      [
        "frame": Self.rect(band.frame), "radius": Self.number(band.cornerRadius), "thickness": Self.number(band.thickness),
        "innerRadius": Self.number(band.innerRadius),
      ]
    }
    let colour: RGBA
    switch model.colour {
    case .accent: colour = accent
    case .rgba(let red, let green, let blue, let alpha): colour = RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }
    return [
      "window": Int(model.window.rawValue), "colour": Self.colour(colour),
      "line": band(model.band(automaticRadius: Self.windowRadius)),
      "flash": band(model.band(reaching: model.flashReach, automaticRadius: Self.windowRadius)),
      "flashOpacity": Self.number(playback.flash),
    ]
  }

  private func stage(_ stage: StagePlayback.Picture) -> [String: Any] {
    [
      "frame": Self.rect(stage.frame), "opacity": Self.number(stage.opacity),
      "surfaces": stage.surfaces.map { backdrop($0.model, opacity: $0.opacity) },
      "standIns": stage.standIns.map { standIn -> [String: Any] in
        [
          "id": Int(standIn.window.rawValue), "app": appName(pid: standIn.pid) ?? "", "frame": Self.rect(standIn.frame),
          "opacity": Self.number(standIn.opacity), "cover": Self.number(standIn.cover),
          "picture": Self.number(standIn.picture), "colour": Self.colour(plainColour(pid: standIn.pid)),
        ]
      },
    ]
  }

  private func headsUp(_ model: HeadsUpModel, opacity: Double) -> [String: Any] {
    var entry: [String: Any] = [
      "kind": model.kind.rawValue, "text": model.text, "anchor": Self.point(model.anchor),
      "maximumWidth": Self.number(model.maximumWidth), "opacity": Self.number(opacity),
    ]
    if let hint = model.hint { entry["hint"] = hint }
    return entry
  }

  /// Everything but `frame` is in the panel's own coordinates.
  private func minimap(_ model: MinimapModel, opacity: Double) -> [String: Any] {
    var entry: [String: Any] = [
      "frame": Self.rect(model.frame), "opacity": Self.number(opacity), "highlight": Self.rect(model.highlight),
      "desktopInView": model.desktopIsInView,
      "items": model.items.map { item -> [String: Any] in
        [
          "id": Int(item.window.rawValue), "frame": Self.rect(item.frame), "inView": item.isInView,
          "colour": Self.colour(plainColour(pid: item.pid)),
        ]
      },
    ]
    if let desktop = model.desktop { entry["desktop"] = Self.rect(desktop) }
    if let hover = model.hover { entry["hover"] = Self.rect(hover) }
    if let caption = model.caption {
      entry["caption"] = caption
      entry["captionFrame"] = Self.rect(model.captionFrame)
    }
    return entry
  }

  private func shortcuts(_ model: CheatSheetModel, opacity: Double) -> [String: Any] {
    [
      "title": model.title, "footer": model.footer, "area": Self.rect(model.area), "opacity": Self.number(opacity),
      "columns": model.columns.map { column in
        column.map { section -> [String: Any] in
          ["title": section.title, "rows": section.rows.map { ["keys": $0.keys, "title": $0.title] }]
        }
      },
    ]
  }

  /// `field`, `list` and the rows are measured from the palette's top-left corner.
  private func goTo(_ session: FinderSession) -> [String: Any] {
    let layout = session.layout
    func ranges(_ ranges: [Range<Int>]) -> [[Int]] { ranges.map { [$0.lowerBound, $0.upperBound] } }
    var entry: [String: Any] = [
      "panel": Self.rect(layout.panel), "field": Self.rect(layout.field), "list": Self.rect(layout.list),
      "text": session.query, "placeholder": FinderSession.placeholder,
      "rows": session.items.enumerated().map { place, item -> [String: Any] in
        var row: [String: Any] = [
          "frame": Self.rect(layout.rowFrame(place).offsetBy(dx: layout.list.minX, dy: layout.list.minY)),
          "name": item.row.name, "detail": item.row.detail, "note": item.row.note, "selected": item.isSelected,
          "nameRanges": ranges(item.match.nameRanges), "detailRanges": ranges(item.match.detailRanges),
        ]
        if let pid = item.row.pid { row["app"] = appName(pid: pid) ?? "" }
        if let badge = item.row.badge { row["badge"] = badge }
        return row
      },
    ]
    if let message = session.message {
      entry["message"] = message
      entry["messageFrame"] = Self.rect(layout.messageFrame.offsetBy(dx: layout.list.minX, dy: layout.list.minY))
    }
    return entry
  }

  /// Arbor's item in the menu bar. The cells and the mark's rectangles are global.
  private func menuBar() -> [String: Any] {
    let model = harness.controller.menuBarModel()
    let frame = hands.statusItemFrame
    func mark(_ size: CGSize, around centre: CGPoint) -> [[Any]] {
      let box = CGRect(x: centre.x - size.width / 2, y: centre.y - size.height / 2, width: size.width, height: size.height)
      return ArborGlyph.cells(in: box, gap: 1).map(Self.rect)
    }
    func glyph(_ glyph: MenuBarModel.Button.Glyph, size: CGSize, around centre: CGPoint) -> [String: Any] {
      switch glyph {
      case .arbor: ["mark": mark(size, around: centre)]
      case .digit(let digit): ["digit": digit]
      case .symbol(let name): ["symbol": name]
      }
    }
    var entry: [String: Any] = ["frame": Self.rect(frame), "open": hands.menu != nil]
    guard let layout = hands.statusItemLayout else {
      entry["icon"] = glyph(model.icon.glyph, size: ArborGlyph.iconSize, around: frame.center)
      entry["dimmed"] = model.icon.isDimmed
      return entry
    }
    let origin = CGPoint(x: frame.minX + (frame.width - layout.size.width) / 2, y: frame.minY)
    entry["fill"] = Self.number(model.fill)
    entry["buttons"] = zip(layout.buttons, layout.cells).map { button, cell -> [String: Any] in
      let cell = cell.offsetBy(dx: origin.x, dy: origin.y)
      return [
        "name": button.id.description, "cell": Self.rect(cell), "chip": Self.rect(MenuBarLayout.chip(in: cell)),
        "enabled": button.isEnabled, "current": button.isCurrent,
        "glyph": glyph(button.glyph, size: ArborGlyph.buttonSize, around: cell.center),
      ]
    }
    return entry
  }

  private func menu(_ menu: FilmMenu) -> [String: Any] {
    [
      "frame": Self.rect(menu.frame),
      "rows": menu.rows.enumerated().map { index, row -> [String: Any] in
        var entry: [String: Any] = ["kind": row.kind.rawValue, "frame": Self.rect(row.frame)]
        guard row.kind != .separator else { return entry }
        entry["title"] = row.title
        entry["enabled"] = row.isEnabled
        if let shortcut = row.shortcut { entry["shortcut"] = shortcut }
        if row.isTicked { entry["ticked"] = true }
        if row.opensSubmenu { entry["submenu"] = true }
        if row.isNews { entry["news"] = true }
        if menu.highlighted == index { entry["highlighted"] = true }
        return entry
      },
    ]
  }
}
