import CoreGraphics

/// The apps that walks are taken with: what each is called, how small it goes, about how large it opens. One table for the walks a person could
/// take against the stand-ins (ChaosGenerator+Ordinary.swift) and for those that are written for a hosted Mac (Walk.swift), so that a size
/// which a Mac corrects is corrected for both. The smallest sizes are what the apps answered on hosted Macs, macOS 26, when Arbor asked for less (the traces of the
/// runs have every question and answer), unless it says otherwise.
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
  /// And that one is as large as the one in front, as Safari's was seen to be.
  public var isABrowser: Bool { ["safari", "chrome", "firefox", "edge"].contains(word) }
  /// The harness opened a document in it, which can be opened again once the app has quit.
  public var hasADocument = false
  /// It opens with a second window, here.
  public var secondWindow: CGRect?
  /// Its windows have a yellow button.
  public var canBeMinimized = true
  /// Its size comes in steps, to the nearest of which it rounds whatever it is asked for, with so much besides.
  public var cells: Cells?

  public struct Cells: Equatable, Sendable {
    public var step: CGSize
    public var margin: CGSize
    public init(step: CGSize, margin: CGSize) { (self.step, self.margin) = (step, margin) }
  }

  /// The first eight, in this order, are the cast of the ordinary walks: a seed draws an app by its place.
  public static let all: [RealApp] = [
    RealApp(
      word: "safari", name: "Safari", bundleID: "com.apple.Safari", minimum: CGSize(width: 574, height: 220), opens: CGSize(width: 1200, height: 800),
      onAHostedMac: CGRect(x: 138, y: 31, width: 1324, height: 790), opensNewWindows: true, hasADocument: true),
    RealApp(
      word: "notes", name: "Notes", bundleID: "com.apple.Notes", minimum: CGSize(width: 709, height: 320), opens: CGSize(width: 900, height: 600),
      onAHostedMac: CGRect(x: 0, y: 31, width: 800, height: 791)),
    RealApp(
      word: "mail", name: "Mail", bundleID: "com.apple.mail", minimum: CGSize(width: 871, height: 236), opens: CGSize(width: 1100, height: 700),
      onAHostedMac: CGRect(x: 240, y: 72, width: 1120, height: 630)),
    RealApp(
      // Characters of 7 by 15 points, and 2 by 4 besides: 24 answers out of 24. How small it goes nobody has asked: 240 wide was taken.
      word: "terminal", name: "Terminal", bundleID: "com.apple.Terminal", minimum: CGSize(width: 177, height: 64), opens: CGSize(width: 877, height: 499),
      onAHostedMac: CGRect(x: 97, y: 238, width: 877, height: 499), opensNewWindows: true,
      cells: Cells(step: CGSize(width: 7, height: 15), margin: CGSize(width: 2, height: 4))),
    RealApp(
      word: "xcode", name: "Xcode", bundleID: "com.apple.dt.Xcode", minimum: CGSize(width: 1188, height: 685), opens: CGSize(width: 1300, height: 800)),
    RealApp(
      word: "finder", name: "Finder", bundleID: "com.apple.finder", minimum: CGSize(width: 501, height: 252), opens: CGSize(width: 920, height: 436),
      onAHostedMac: CGRect(x: 340, y: 120, width: 920, height: 436), opensNewWindows: true, hasADocument: true),
    RealApp(
      word: "music", name: "Music", bundleID: "com.apple.Music", minimum: CGSize(width: 980, height: 600), opens: CGSize(width: 980, height: 600),
      onAHostedMac: CGRect(x: 310, y: 84, width: 980, height: 600)),
    // As wide as it is, whatever anybody asks.
    RealApp(
      word: "settings", name: "Settings", bundleID: "com.apple.systempreferences", minimum: CGSize(width: 723, height: 470),
      opens: CGSize(width: 723, height: 650), maximum: CGSize(width: 723, height: 2000), onAHostedMac: CGRect(x: 437, y: 85, width: 723, height: 625)),
    // TextEdit took whatever it was asked for, 244 wide and 161 high among it, and Preview was not asked for less than 248 high. The smallest size somebody asked for is no
    // limit, and a stand-in that refuses what the app takes sends Arbor another way: so these are below what Arbor asks of any window (`minimumUsableWidth`, `…Height`).
    RealApp(
      word: "textedit", name: "TextEdit", bundleID: "com.apple.TextEdit", minimum: CGSize(width: 100, height: 100), opens: CGSize(width: 673, height: 439),
      onAHostedMac: CGRect(x: 165, y: 65, width: 673, height: 439), opensNewWindows: true, hasADocument: true),
    RealApp(
      word: "calendar", name: "Calendar", bundleID: "com.apple.iCal", minimum: CGSize(width: 680, height: 503), opens: CGSize(width: 909, height: 600),
      onAHostedMac: CGRect(x: 386, y: 118, width: 909, height: 600)),
    RealApp(
      word: "preview", name: "Preview", bundleID: "com.apple.Preview", minimum: CGSize(width: 708, height: 100), opens: CGSize(width: 708, height: 424),
      onAHostedMac: CGRect(x: 4, y: 35, width: 708, height: 424), hasADocument: true),
    // Toolkits that are not Apple's. No Mac has been asked about these three yet: sizes and places are guesses, which the first run corrects (`WalkScene(samples:)`).
    RealApp(
      word: "chrome", name: "Chrome", bundleID: "com.google.Chrome", minimum: CGSize(width: 500, height: 375), opens: CGSize(width: 1200, height: 780),
      onAHostedMac: CGRect(x: 100, y: 31, width: 1200, height: 780), opensNewWindows: true, hasADocument: true),
    RealApp(
      word: "firefox", name: "Firefox", bundleID: "org.mozilla.firefox", minimum: CGSize(width: 500, height: 120), opens: CGSize(width: 1200, height: 780),
      onAHostedMac: CGRect(x: 160, y: 31, width: 1200, height: 780), opensNewWindows: true, hasADocument: true),
    RealApp(
      word: "edge", name: "Edge", bundleID: "com.microsoft.edgemac", minimum: CGSize(width: 500, height: 375), opens: CGSize(width: 1200, height: 780),
      onAHostedMac: CGRect(x: 220, y: 31, width: 1200, height: 780), opensNewWindows: true, hasADocument: true),
    // Manners, as a hosted Mac was found to have them. One size only.
    RealApp(
      word: "calculator", name: "Calculator", bundleID: "com.apple.calculator", minimum: CGSize(width: 230, height: 408), opens: CGSize(width: 230, height: 408),
      maximum: CGSize(width: 230, height: 408), onAHostedMac: CGRect(x: 350, y: 411, width: 230, height: 408)),
    // No narrower than well over half a laptop's screen.
    RealApp(
      word: "books", name: "Books", bundleID: "com.apple.iBooksX", minimum: CGSize(width: 1001, height: 530), opens: CGSize(width: 1024, height: 768),
      onAHostedMac: CGRect(x: 288, y: 37, width: 1024, height: 768)),
    // Two notes, which cannot be minimized.
    RealApp(
      word: "stickies", name: "Stickies", bundleID: "com.apple.Stickies", minimum: CGSize(width: 54, height: 40), opens: CGSize(width: 352, height: 260),
      onAHostedMac: CGRect(x: 69, y: 153, width: 352, height: 260), opensNewWindows: true, secondWindow: CGRect(x: 48, y: 131, width: 355, height: 268),
      canBeMinimized: false),
    RealApp(
      word: "reminders", name: "Reminders", bundleID: "com.apple.reminders", minimum: CGSize(width: 768, height: 692), opens: CGSize(width: 768, height: 692),
      onAHostedMac: CGRect(x: 192, y: 173, width: 768, height: 692)),
    // It puts up no window at all.
    RealApp(word: "quicktime", name: "QuickTime", bundleID: "com.apple.QuickTimePlayerX", minimum: .zero, opens: .zero),
  ]

  /// The apps of the walks a person could take against the stand-ins.
  public static let ordinary = Array(all.prefix(8))

  /// docs/VIABLE.md's cast `stock`, in the order in which lib-walk.sh opens it.
  public static let stock = ["finder", "safari", "textedit", "terminal", "notes", "calendar", "settings", "preview", "mail"].map { named($0)! }

  /// The casts of docs/VIABLE.md, section 4: lib-walk.sh's `members_of`.
  public static func cast(_ name: String) -> [RealApp]? {
    switch name {
    case "stock": stock
    case "browsers": ["safari", "chrome", "firefox", "edge", "finder", "textedit", "terminal"].map { named($0)! }
    case "awkward": ["finder", "terminal", "textedit", "safari", "calculator", "books", "music", "stickies", "reminders"].map { named($0)! }
    default: nil
    }
  }

  public static func named(_ word: String) -> RealApp? { all.first { $0.word == word } }
}
