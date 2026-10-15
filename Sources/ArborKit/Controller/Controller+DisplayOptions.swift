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

  /// 12 for 12.0, 12.5 for 12.5.
  private static func plain(_ value: Double) -> String {
    value == value.rounded() && abs(value) < 1e9 ? String(Int(value)) : String(value)
  }
}
