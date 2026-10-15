import ArborCore
import CoreGraphics

/// Settings that differ from display to display (docs/features/F25-per-display-options.md).
extension Controller {
  /// The settings in effect on a display: the general ones, with what the entries of `displays` in
  /// settings.json give that display in their place.
  ///
  /// Everything that lays out, previews or resolves a drop on a display reads its options from here and
  /// never from `settings` directly, or that display's gap would be right in one place and wrong in another.
  public func options(for displayID: DisplayID) -> Settings {
    guard !settings.displays.isEmpty, let display = display(displayID) else { return settings }
    return settings.applying(to: display.traits)
  }

  /// For the reply to `set gap 50`, after which nothing moves on a display that has a gap of its own:
  /// "; Built-in Display keeps 6 (`displays` in settings.json)". Empty if no display has its own value for `key`.
  func ownValuesNote(for key: String) -> String {
    let own = numberedDisplays.enumerated().compactMap { index, display -> String? in
      guard let given = DisplayOptions.given(by: settings.displays, to: display.traits).first(where: { $0.key == key })
      else { return nil }
      return "\(called(display, number: index + 1)) keeps \(Self.plain(given.value))"
    }
    return own.isEmpty ? "" : "; " + own.joined(separator: ", ") + " (`displays` in settings.json)"
  }

  /// As Go to… calls it (two of the same make are told apart), also when it is the only one.
  private func called(_ display: DisplaySnapshot, number: Int) -> String {
    displayLabel(display.id) ?? display.name.flatMap { $0.isEmpty ? nil : $0 } ?? "display \(number)"
  }

  // MARK: The `displays` query

  /// Every display with its name, size and id, the options in effect on it and the entry each comes from, and the
  /// entries of settings.json that were skipped and why.
  func displaysReport() -> CommandResult {
    var lines: [String] = []
    if displays.isEmpty {
      lines.append("No displays yet: \(statusText).")
    }
    for (index, display) in numberedDisplays.enumerated() {
      var traits = ["\(Self.whole(display.frame.width))×\(Self.whole(display.frame.height))"]
      if display.isMain { traits.append("main") }
      if display.isBuiltIn { traits.append("built-in") }
      lines.append("\(index + 1). \(display.name.flatMap { $0.isEmpty ? nil : $0 } ?? "Display"), \(traits.joined(separator: ", "))")
      lines.append("   id \(display.id)")
      let given = DisplayOptions.given(by: settings.displays, to: display.traits)
      let inEffect = options(for: display.id)
      for (key, value) in [
        ("gap", inEffect.gap), ("minimumUsableWidth", inEffect.minimumUsableWidth),
        ("minimumUsableHeight", inEffect.minimumUsableHeight), ("screenEdgeBand", inEffect.screenEdgeBand),
      ] {
        let entry = given.first { $0.key == key }.map { ", from the entry \"\($0.match)\"" } ?? ""
        lines.append("   \(key) \(Self.plain(value))\(entry)")
      }
    }
    if settings.displays.isEmpty {
      lines.append("Every display uses the general settings. Add a \"displays\" list to settings.json to change that.")
    }
    if !settings.skippedDisplays.isEmpty {
      lines.append("Skipped entries of \"displays\" in settings.json:")
      lines += settings.skippedDisplays.map { "  \($0)" }
    }
    if !settings.displayKeysNotRead.isEmpty {
      lines.append("Keys that are not read (the entries count without them):")
      lines += settings.displayKeysNotRead.map { "  \($0)" }
    }
    // Before Arbor has looked there is no telling what an entry matches.
    let idle = displays.isEmpty ? [] : DisplayOptions.idle(among: settings.displays, on: displays.map(\.traits))
    if !idle.isEmpty {
      let numbers = settings.displayNumbers
      lines.append("Entries that change nothing at the moment:")
      lines += idle.map { "  entry \(numbers[$0.index]) (\(settings.displays[$0.index].match)): \($0.why)" }
    }
    return CommandResult(ok: true, message: "\(displays.count) display(s)", text: lines.joined(separator: "\n"))
  }

  /// A display's side in whole points. Frames come from the system; a nonsensical one must not crash a query.
  private static func whole(_ value: CGFloat) -> String {
    value.isFinite && abs(value) < 1e9 ? String(Int(value.rounded())) : "?"
  }

  /// 12 for 12.0, 12.5 for 12.5.
  private static func plain(_ value: Double) -> String {
    value == value.rounded() && abs(value) < 1e9 ? String(Int(value)) : String(value)
  }
}
