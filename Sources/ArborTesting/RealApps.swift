import CoreGraphics

/// The apps that walks are taken with: what each is called, how small it goes, about how large it opens. One table for the walks a person could
/// take against the stand-ins (ChaosGenerator+Ordinary.swift) and for those that are written for a hosted Mac (Walk.swift), so that a size
/// which a Mac corrects is corrected for both.
public struct RealApp: Equatable, Sendable {
  /// What scripts/mac-shell/lib-walk.sh calls it.
  public var word: String
  /// What macOS calls it, without spaces: a script's words are told apart by them.
  public var name: String
  public var bundleID: String
  /// What it refuses to go below.
  public var minimum: CGSize
  /// About how large it opens.
  public var opens: CGSize
  public var maximum: CGSize?
  /// Where its first window stood when a walk began on a hosted Mac whose display was set to 1600×900. An app remembers its frame from the script
  /// before, so this is one morning of many: `WalkScene(samples:)` takes the frames a run really began with.
  public var onAHostedMac: CGRect?
  /// ⌘N opens another window.
  public var opensNewWindows = false
  /// The harness opened a document in it, which can be opened again once the app has quit.
  public var hasADocument = false

  /// The first eight, in this order, are the cast of the ordinary walks: a seed draws an app by its place.
  public static let all: [RealApp] = [
    RealApp(
      word: "safari", name: "Safari", bundleID: "com.apple.Safari", minimum: CGSize(width: 574, height: 240), opens: CGSize(width: 1200, height: 800),
      onAHostedMac: CGRect(x: 138, y: 31, width: 1324, height: 790), opensNewWindows: true, hasADocument: true),
    RealApp(
      word: "notes", name: "Notes", bundleID: "com.apple.Notes", minimum: CGSize(width: 709, height: 320), opens: CGSize(width: 900, height: 600),
      onAHostedMac: CGRect(x: 0, y: 31, width: 800, height: 791)),
    RealApp(
      // 871 wide and no less, on macOS 26. It was seen 297 high: how much lower it goes nobody has asked.
      word: "mail", name: "Mail", bundleID: "com.apple.mail", minimum: CGSize(width: 871, height: 297), opens: CGSize(width: 1100, height: 700),
      onAHostedMac: CGRect(x: 240, y: 72, width: 1120, height: 630)),
    RealApp(
      word: "terminal", name: "Terminal", bundleID: "com.apple.Terminal", minimum: CGSize(width: 177, height: 60), opens: CGSize(width: 877, height: 499),
      onAHostedMac: CGRect(x: 97, y: 238, width: 877, height: 499), opensNewWindows: true),
    RealApp(
      word: "xcode", name: "Xcode", bundleID: "com.apple.dt.Xcode", minimum: CGSize(width: 1188, height: 685), opens: CGSize(width: 1300, height: 800)),
    RealApp(
      word: "finder", name: "Finder", bundleID: "com.apple.finder", minimum: CGSize(width: 501, height: 252), opens: CGSize(width: 920, height: 436),
      onAHostedMac: CGRect(x: 340, y: 120, width: 920, height: 436), opensNewWindows: true, hasADocument: true),
    RealApp(word: "music", name: "Music", bundleID: "com.apple.Music", minimum: CGSize(width: 680, height: 480), opens: CGSize(width: 980, height: 600)),
    // As wide as it is, whatever anybody asks.
    RealApp(
      word: "settings", name: "Settings", bundleID: "com.apple.systempreferences", minimum: CGSize(width: 723, height: 470),
      opens: CGSize(width: 723, height: 650), maximum: CGSize(width: 723, height: 2000), onAHostedMac: CGRect(x: 437, y: 85, width: 723, height: 625)),
    // Calendar was seen to stop at 503 high. The other smallest sizes of these three are guesses until a Mac has been asked (`apptool limits`).
    RealApp(
      word: "textedit", name: "TextEdit", bundleID: "com.apple.TextEdit", minimum: CGSize(width: 300, height: 200), opens: CGSize(width: 673, height: 439),
      onAHostedMac: CGRect(x: 165, y: 65, width: 673, height: 439), opensNewWindows: true, hasADocument: true),
    RealApp(
      word: "calendar", name: "Calendar", bundleID: "com.apple.iCal", minimum: CGSize(width: 650, height: 503), opens: CGSize(width: 909, height: 600),
      onAHostedMac: CGRect(x: 386, y: 118, width: 909, height: 600)),
    RealApp(
      word: "preview", name: "Preview", bundleID: "com.apple.Preview", minimum: CGSize(width: 702, height: 297), opens: CGSize(width: 708, height: 424),
      onAHostedMac: CGRect(x: 4, y: 35, width: 708, height: 424), hasADocument: true),
  ]

  /// The apps of the walks a person could take against the stand-ins.
  public static let ordinary = Array(all.prefix(8))

  /// docs/VIABLE.md's cast `stock`, in the order in which lib-walk.sh opens it.
  public static let stock = ["finder", "safari", "textedit", "terminal", "notes", "calendar", "settings", "preview", "mail"].map { named($0)! }

  public static func named(_ word: String) -> RealApp? { all.first { $0.word == word } }
}
