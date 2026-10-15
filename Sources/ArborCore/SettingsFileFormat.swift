import Foundation

/// What `settings.json` holds: **only what differs from the defaults** (collab/QUESTIONS.md, Q27).
///
/// Until 2026-10-15 the first launch wrote every default into the file, "so there is something to edit". A written default cannot be
/// told from a choice, so a default that changed later reached only a Mac on which Arbor had never run. Now a value that is the
/// default is not in the file: not after a first launch, not after `reset`, not after `set` to that very value.
///
/// Files of the old kind are put right once (`upgradedFile`), and files of the new kind say what they are: `"format": 2`.
/// A file without the mark that holds a few keys is neither: somebody wrote it by hand, and all of it is their choice.
extension Settings {
  /// The key that marks a file which holds only what differs. It is no setting: Arbor reads nothing else from it.
  public static let formatKey = "format"
  public static let format = 2

  /// The text of a new `settings.json`: the mark, and what differs from the defaults, in the order of the alphabet.
  public var fileText: String {
    get throws {
      let (mine, defaults) = (try Self.canonical(self), try Self.canonical(Settings()))
      return try Self.describingEditErrors {
        var document = try JSONText("{\n  \"\(Self.formatKey)\": \(Self.format)\n}\n")
        for key in mine.keys(at: []) ?? [] where mine.value(at: [key]) != defaults.value(at: [key]) {
          document = try document.setting([key], to: mine.value(at: [key])!)
        }
        return document.text
      }
    }
  }

  /// A file of the old kind, put right.
  public struct UpgradedFile: Equatable, Sendable {
    /// What to write.
    public var text: String
    /// The keys that were taken out, in the order of the alphabet. They follow the defaults from now on.
    public var stripped: [String]
  }

  /// `text`, the contents of a `settings.json` without the mark, stripped of every value that equals the default **as it was when such
  /// files were written**, and marked. Nil if it has the mark already. Everything else stays byte for byte: what somebody changed, keys
  /// Arbor does not know, the order, the spacing.
  ///
  /// **Only a file that looks whole is taken for one of those** (`leastKeysOfAWholeFile`: it holds sixteen or more of the keys such files held). They were
  /// written by Arbor, every default in them, unasked; and sixteen is no longer a few. A file of a few keys is somebody's own:
  /// `{"focusRing": true}` says what it means, though true is what an early build wrote down too. Nothing is taken out of it. It
  /// only gets the mark, so that it is read the same at a launch as at a reload, today and after the next default has changed.
  ///
  /// Whoever had chosen a value that happened to be the default loses nothing that day, and follows the default from then on. **But for
  /// a default that has changed since such files were written:** there the value goes and today's default comes, at once. That is
  /// the point for whoever never chose it, and the price for whoever did (`defaultsOfOldFiles` says which keys those are).
  ///
  /// Throws, and so changes nothing, if Arbor cannot read `text`: it is somebody's to mend first, and is looked at again at the next launch.
  public static func upgradedFile(_ text: String) throws -> UpgradedFile? {
    try upgradedFile(text, wholeFrom: leastKeysOfAWholeFile)
  }

  /// The same with the rule as a number, for the tests of how a file is stripped, which show it on files of a few lines.
  static func upgradedFile(_ text: String, wholeFrom least: Int) throws -> UpgradedFile? {
    try describingEditErrors { () throws -> UpgradedFile? in
      var document = try JSONText(text)
      // Asked first: of a file that has the mark nothing more is asked, not even whether it can be read.
      guard let keys = document.keys(at: []), !keys.contains(formatKey) else { return nil }
      let before = try read(text)
      let unusable = Set(before.valueProblems.map { String($0.prefix { $0 != ":" }) })
      let table = try JSONText(defaultsOfOldFiles)
      // Marked first, while the file still has members to show how it is written: on one line or many, with which space at the colon.
      document = try document.setting([formatKey], to: "\(format)")
      var stripped: [String] = []
      let isWhole = Set(keys).intersection(table.keys(at: []) ?? []).count >= least
      // A value Arbor could not use was never written by Arbor. It stays for whoever wrote it to put right.
      for key in Set(keys).subtracting(unusable).sorted() where isWhole {
        guard let written = document.value(at: [key]), let old = table.elements(at: [key]),
          old.contains(where: { isSame($0, written) })
        else { continue }
        document = try document.removing([key])
        stripped.append(key)
      }
      // Never hand back text in which anything that stayed means something else than it did.
      let (was, now) = (try canonical(before), try canonical(try read(document.text)))
      for key in was.keys(at: []) ?? [] where !stripped.contains(key) && was.value(at: [key]) != now.value(at: [key]) {
        throw FileError("`\(key)` would not have come through")
      }
      return UpgradedFile(text: document.text, stripped: stripped)
    }
  }

  /// `rewrite`, for a command that changes settings; and somebody's own file, put there without the mark while Arbor runs, gets the mark with
  /// the first command that writes into it, going by the file as they left it. Otherwise command after command could fill it
  /// until it looks whole, and the next launch would take out of it what those very commands were asked for.
  /// A whole file of an early build stays without the mark: it is the next launch's.
  public static func rewriteAndMark(_ text: String, from old: Settings, to new: Settings) throws -> String {
    let rewritten = try rewrite(text, from: old, to: new)
    // Marked first, as at a launch: while the file still has the members that show how it is written.
    guard rewritten != text, let marked = try? upgradedFile(text), marked.stripped.isEmpty,
      let both = try? rewrite(marked.text, from: old, to: new)
    else { return rewritten }
    return both
  }

  /// How many of the keys of `defaultsOfOldFiles` a file without the mark has to hold to pass for one that Arbor wrote. Far fewer than the 68
  /// of the table, on purpose: a file holds the keys of the build that first launched on that Mac, and an older build had fewer. Too high, and
  /// such a file counts as somebody's own and no changed default ever reaches that Mac, in silence. Too low, and somebody who wrote that
  /// many by hand loses those that equal an old default, once, with the copy of the file lying beside it (QUESTIONS, Q27).
  public static let leastKeysOfAWholeFile = 16

  /// Whether two pieces of JSON say the same: numbers by their value (an older macOS wrote 0.46 with seventeen digits), the rest by its
  /// text with the white space outside strings taken out (an empty list was written over three lines).
  static func isSame(_ a: String, _ b: String) -> Bool {
    if let a = Double(a), let b = Double(b) { return a == b }
    return compact(a) == compact(b)
  }

  private static func compact(_ json: String) -> [UInt8] {
    var (result, inString, escaped) = ([UInt8](), false, false)
    for byte in json.utf8 {
      if inString {
        result.append(byte)
        if escaped { escaped = false } else if byte == 0x5C { escaped = true } else if byte == 0x22 { inString = false }
      } else if ![0x20, 0x09, 0x0A, 0x0D].contains(byte) {
        result.append(byte)
        inString = byte == 0x22
      }
    }
    return result
  }

  /// **FROZEN. Never change a value here, and never add a key that came after the mark.** Each key with the defaults it has had in builds that
  /// wrote whole files: what such a file holds without anybody having chosen it. It is history, not the defaults of today: when a
  /// default changes, this stays, and that is what lets the change reach an old file.
  ///
  /// Two keys have had two defaults: the rectangle's keys were ⇧⌘ until 2026-10-14, and the guard of the wallpaper click shipped on until then.
  /// Whoever chose ⇧⌘, or the guard, on purpose cannot be told from a file of those days and loses the choice: the notes say so.
  ///
  /// Left out on purpose: `pointerGestures` true, the default for the twelve minutes between the commit that brought the key and the one that
  /// switched it off. No build of those minutes was handed to anybody, and in every other file true is somebody's choice.
  public static let defaultsOfOldFiles = #"""
    {
      "allowAllURLCommands": [false], "animationDuration": [0.46], "appColourAmount": [0.25], "appColours": [true],
      "arrangeDesktopWeight": [0.5], "autoDockMinimumHeight": [300], "autoDockMinimumWidth": [400], "automaticUpdateChecks": [false],
      "bindings": [{}], "blurBehindArranged": [0], "continuousZoom": [false], "desktopEdge": [0.05], "dimBehindArranged": [0.25],
      "displays": [[]], "dropDwell": [0.15], "excludedBundleIDs": [[]], "focusRing": [true], "focusRingColour": ["accent"],
      "focusRingRadius": [0], "focusRingWidth": [3], "frameRectangleModifier": ["ctrl+opt", "shift+cmd"], "frameRectangleOnDesktop": [true],
      "gap": [12], "gapHandles": ["shown"], "gesturesEnabled": [true], "guardDesktopClicks": [false, true], "historyButtons": [true],
      "holdStillFor": [[]], "holdStillWhileCameraIsOn": [false], "holdStillWhileMicrophoneIsOn": [false], "hotkeysEnabled": [true],
      "keepPushed": [true], "makeRoom": [true], "menuBarControls": [true], "menuBarFill": [0.25], "messages": ["helpful"],
      "minimapDuration": [0], "minimumUsableHeight": [160], "minimumUsableWidth": [240], "newWindows": ["float"],
      "newWindowsWhileFramed": ["guest"], "passThroughApps": [[]], "pauseForApps": [[]], "peek": [true], "pinchThreshold": [0.25],
      "pointerGestures": [false], "previewDrags": [true], "reflowWhileDragging": [false], "resizeStep": [40], "ruleTitleWait": [2],
      "rules": [[]], "screenEdgeBand": [12], "scrollOnDesktopZooms": [false], "scrollZoom": [true], "scrollZoomThreshold": [40],
      "shareRemovedSpace": [true], "shortcutsFollowLayout": [true], "shrinkOutOfView": [false], "soleFloatTakesDesktop": [false],
      "stepInToward": ["auto"], "summonStays": [false], "tabsEnabled": [false], "tileFade": [0.2], "tileRetryMinutes": [10],
      "tileStyle": ["icon"], "tintBehindArranged": [0], "windowEdgeFraction": [0.3], "windowPictures": [false]
    }
    """#
}
