import CoreGraphics
import Foundation
import Testing

@testable import ArborCore

/// Arbor does less by itself (collab/IDEAS.md, I20 d and e, I23): as it ships there is no line round the focused window, one icon in
/// the menu bar, no stage with stand-ins while windows move, and nothing behind docked windows but the wallpaper. Each stays an option. What the controller then does is
/// `NothingDrawnUnaskedScenarioTests`' business; here it is the defaults, whom they reach (collab/QUESTIONS.md, Q27) and where they are offered.
@Suite struct NothingDrawnUnaskedTests {
  static let keys = ["animationDuration", "desktopEdge", "dimBehindArranged", "focusRing", "menuBarControls"]

  /// `wholeFile`, the file the first launch of the build of 2026-10-15 wrote, with other values in some lines.
  func wholeFile(with changes: [String: String]) -> String {
    var text = SettingsFileFormatTests.wholeFile
    for (key, value) in changes {
      let line = text.split(separator: "\n").first { $0.contains("\"\(key)\" :") }!
      text = text.replacingOccurrences(of: line, with: "  \"\(key)\" : \(value),")
    }
    return text
  }

  /// What a launch makes of a file of the old kind.
  func afterALaunch(_ text: String) throws -> (settings: Settings, file: JSONText) {
    let upgraded = try #require(try Settings.upgradedFile(text))
    return (try Settings.read(upgraded.text), try JSONText(upgraded.text))
  }

  // MARK: As it ships

  @Test func noRingOneIconNoMotion() {
    let settings = Settings()
    #expect(!settings.focusRing)
    #expect(!settings.menuBarControls)
    #expect(settings.animationDuration == 0)
    #expect(settings.motionDuration == 0)
  }

  @Test func theWallpaperIsLeftAsItIs() {
    let settings = Settings()
    #expect(settings.dimBehindArranged == 0 && settings.desktopEdge == 0)
    #expect(settings.appearanceOptions.dim == 0 && settings.appearanceOptions.desktopEdge == 0)
    // With the two that shipped at nought all along, that is all there is to a backdrop.
    #expect(settings.blurBehindArranged == 0 && settings.tintBehindArranged == 0)
  }

  @Test func anAmountThatIsNoNumberIsNoneEither() {
    var settings = Settings()
    (settings.dimBehindArranged, settings.desktopEdge) = (.nan, .infinity)
    #expect(settings.appearanceOptions.dim == 0 && settings.appearanceOptions.desktopEdge == 0)
  }

  @Test func aDurationThatIsNoNumberIsNoMotionEither() {
    var settings = Settings()
    settings.animationDuration = .nan
    #expect(settings.motionDuration == 0)
  }

  // MARK: Whom the new defaults reach

  @Test func aFileOfTheFirstBuildThatNeverTouchedThemGetsTheNewDefaults() throws {
    let (settings, file) = try afterALaunch(SettingsFileFormatTests.wholeFile)
    #expect(settings == Settings())
    #expect(!settings.focusRing && !settings.menuBarControls && settings.animationDuration == 0)
    #expect(settings.dimBehindArranged == 0 && settings.desktopEdge == 0)
    #expect(file.keys(at: []) == [Settings.formatKey])
  }

  @Test func aFileOfTheFirstBuildThatSetThemKeepsItsOwn() throws {
    // A slower motion is somebody's choice, and so is a motion of nought, the ring off and the buttons off: that these are now what
    // Arbor ships with takes nothing out of the file.
    let slower = try afterALaunch(wholeFile(with: ["animationDuration": "0.2"]))
    #expect(slower.settings.animationDuration == 0.2)
    #expect(slower.file.keys(at: []) == ["animationDuration", Settings.formatKey])

    let darker = try afterALaunch(wholeFile(with: ["dimBehindArranged": "0.4", "desktopEdge": "0.2"]))
    #expect(darker.settings.dimBehindArranged == 0.4 && darker.settings.desktopEdge == 0.2)
    #expect(darker.file.keys(at: []) == ["desktopEdge", "dimBehindArranged", Settings.formatKey])

    let less = try afterALaunch(
      wholeFile(with: ["animationDuration": "0", "desktopEdge": "0", "dimBehindArranged": "0", "focusRing": "false", "menuBarControls": "false"]))
    #expect(less.settings == Settings())
    #expect(less.file.keys(at: []) == Self.keys + [Settings.formatKey])
  }

  @Test func whatGoesWithThemStaysChosenToo() throws {
    // The ring is off, and the width somebody gave it waits for the day it is switched on.
    let (settings, _) = try afterALaunch(wholeFile(with: ["focusRingWidth": "5", "historyButtons": "false"]))
    #expect(!settings.focusRing && settings.focusRingWidth == 5)
    #expect(!settings.menuBarControls && !settings.historyButtons)
  }

  @Test func aFileOfTheNewKindThatSwitchesThemOnKeepsThemOn() throws {
    let text =
      #"{"format": 2, "animationDuration": 0.46, "desktopEdge": 0.05, "dimBehindArranged": 0.25, "focusRing": true, "menuBarControls": true}"#
    #expect(try Settings.upgradedFile(text) == nil, "nothing is taken out of a file that has the mark")
    let settings = try Settings.read(text)
    #expect(settings.focusRing && settings.menuBarControls && settings.animationDuration == 0.46)
    #expect(settings.dimBehindArranged == 0.25 && settings.desktopEdge == 0.05)
    #expect(try JSONText(try settings.fileText).keys(at: []) == [Settings.formatKey] + Self.keys, "they differ now, so they are written")
  }

  @Test func theTableOfOldFilesStillHoldsWhatSuchFilesHeld() throws {
    // It is history. Were it to follow today's defaults, no old file would ever be rid of the ring.
    let table = try JSONText(Settings.defaultsOfOldFiles)
    #expect(table.elements(at: ["focusRing"]) == ["true"])
    #expect(table.elements(at: ["menuBarControls"]) == ["true"])
    #expect(table.elements(at: ["animationDuration"]) == ["0.46"])
    #expect(table.elements(at: ["dimBehindArranged"]) == ["0.25"])
    #expect(table.elements(at: ["desktopEdge"]) == ["0.05"])
  }

  // MARK: One icon, one width

  /// Sizes a symbol may have: small, as wide as the image, wider, taller, both, and far too large.
  static let signs = [
    CGSize(width: 10, height: 10), CGSize(width: 15.5, height: 13.5), CGSize(width: 18, height: 14), CGSize(width: 19.5, height: 13),
    CGSize(width: 12, height: 17), CGSize(width: 22, height: 22), CGSize(width: 400, height: 3),
  ]

  @Test(arguments: signs) func aSignIsDrawnInsideTheImageOfTheMark(size: CGSize) {
    let place = ArborGlyph.place(ofSign: size)
    #expect(CGRect(origin: .zero, size: ArborGlyph.iconSize).contains(place), "\(place)")
  }

  @Test(arguments: signs) func aSignKeepsItsProportionsAndIsNeverMadeLarger(size: CGSize) {
    let place = ArborGlyph.place(ofSign: size)
    #expect(place.width <= size.width && place.height <= size.height)
    #expect(abs(place.width * size.height - place.height * size.width) < 0.001)
  }

  @Test func aSignThatFitsKeepsItsSizeAndSitsInTheMiddleOnWholePoints() {
    #expect(ArborGlyph.place(ofSign: CGSize(width: 10, height: 10)) == CGRect(x: 4, y: 2, width: 10, height: 10))
    #expect(ArborGlyph.place(ofSign: CGSize(width: 15.5, height: 13.5)) == CGRect(x: 1, y: 0, width: 15.5, height: 13.5))
    #expect(ArborGlyph.place(ofSign: ArborGlyph.iconSize) == CGRect(origin: .zero, size: ArborGlyph.iconSize))
  }

  @Test func aSignOfNoSizeIsNoCrash() {
    #expect(ArborGlyph.place(ofSign: .zero).size == .zero)
  }

  // MARK: Each stays an option

  @Test(arguments: keys) func eachIsOfferedInTheSettingsWindow(key: String) throws {
    // The hairline round the Desktop among the advanced ones, where it has always been. The others without asking for more.
    #expect(try SettingsSchema.entry(named: key).level == (key == "desktopEdge" ? .advanced : .normal))
  }

  @Test func theHelpSaysWhichNumberBringsTheMotionBack() throws {
    // A switch says what "on" is. A number that ships as nought does not.
    #expect(try SettingsSchema.entry(named: "animationDuration").help.contains("\(Settings.usualMotionDuration)"))
    #expect(Settings.usualMotionDuration == 0.46)
  }
}
