import ArborCore
import CoreGraphics
import Foundation
import Testing

private func read(_ json: String) throws -> Settings { try JSONDecoder().decode(Settings.self, from: Data(json.utf8)) }

@Suite struct SettingsDecodingTests {
  @Test func nullMeansTheDefault() throws {
    let settings = try read(#"{"gap": null, "tabsEnabled": null, "bindings": null, "rules": null}"#)
    #expect(settings == Settings())
  }

  @Test func aFileThatIsNotAnObjectFails() {
    for json in ["[]", "12", #""gap""#, "", "{", #"{"gap": 12"#, #"{"gap": }"#] {
      #expect(throws: (any Error).self, "\(json)") { try read(json) }
    }
  }

  /// Values of the right type that make no sense are not the decoder's business, but nothing built
  /// from them may be dangerous.
  @Test func senselessNumbersAreHarmless() throws {
    let settings = try read(
      #"{"gap": -40, "minimumUsableWidth": -1, "minimumUsableHeight": 1e300, "arrangeDesktopWeight": -2, "windowEdgeFraction": 7, "screenEdgeBand": -3, "pinchThreshold": 0}"#)
    let tree = LayoutTree.grid(of: [WindowID(1), WindowID(2), WindowID(3)], desktopWeight: settings.arrangeDesktopWeight)
    #expect(tree.invariantViolations() == [])
    let display = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let layout = LayoutEngine.layout(tree, camera: tree.root, in: display, options: settings.layoutOptions, isPresent: { _ in true })
    for frame in layout.nodeFrames.values { #expect(display.contains(frame)) }
    #expect(GestureInterpreter(threshold: settings.pinchThreshold).effectiveThreshold > 0)
  }
}
