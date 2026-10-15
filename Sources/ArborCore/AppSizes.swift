import CoreGraphics
import Foundation

/// How small apps go, by bundle id (docs/features/F68-how-small-apps-go.md).
///
/// Only asking tells how small a window goes, and the answer shows: a window that refuses its slot has been moved once
/// already when Arbor finds out, and it and its neighbours move again. What a window of an app answered is therefore kept for
/// the next window of that app, in this run and the next, so that a layout can be worked out on paper first.
///
/// It is used to foresee, never as the truth: a window's own answer replaces it, and it goes the ways a record about one
/// window goes (F45). Where it errs it had better err low. Too low costs what not knowing costs: the window refuses, and is
/// believed. Too high would give a window room it does not need, or make a tile of a window that was never asked.
///
/// A bundle id, two numbers, the version of macOS and a date. No titles, no paths, nothing about what is in a window.
public struct AppSizes: Equatable, Sendable {
  public struct Entry: Codable, Equatable, Sendable {
    /// What a window of the app would not go below. 0: not known, as in a record about one window.
    public var width: Double
    public var height: Double
    /// The major version of macOS it was seen on. Apple's apps change with it.
    public var macOS: Int
    /// When a window of the app last stood by it.
    public var seen: Date

    public init(width: Double, height: Double, macOS: Int, seen: Date) {
      self.width = width
      self.height = height
      self.macOS = macOS
      self.seen = seen
    }

    public var size: CGSize { CGSize(width: width, height: height) }

    /// Whether a value read from a file can be believed. No display is 10,000 points wide, and a window that is said not to
    /// go below that would be a tile wherever it is docked. Nor does it say anything that a window goes no smaller than a few points.
    var isSound: Bool {
      func sound(_ side: Double) -> Bool { side.isFinite && (side == 0 || side >= AppSizes.leastSide) && side <= AppSizes.largestSide }
      return sound(width) && sound(height) && (width > 0 || height > 0) && seen.timeIntervalSinceReferenceDate.isFinite
    }
  }

  public private(set) var apps: [String: Entry] = [:]

  /// Nobody has stood by it for this long: it is forgotten, and the next window of the app is asked. With the size known no
  /// window is asked for less, so that this is also how often the truth is looked at again. As long as the arrangement
  /// of a display that is away is kept.
  public static let lifetime: TimeInterval = 30 * 24 * 3600
  /// The file does not grow for ever. Nobody runs this many apps in a month.
  public static let capacity = 200
  static let largestSide = 10_000.0
  /// Smaller than this either way is no window to go by: some apps open theirs a point wide and give them a size afterwards.
  static let leastSide = 20.0
  /// Closer than this is the same size, as everywhere a frame is compared with what was asked for.
  static let tolerance = 2.0

  public init() {}

  public var isEmpty: Bool { apps.isEmpty }

  public func entry(for app: String) -> Entry? { apps[app] }

  /// What there is to go by at `now` on this macOS. Arbor runs for weeks: what is too old is so without a start in between.
  public func entry(for app: String, at now: Date, macOS: Int) -> Entry? {
    apps[app].flatMap { Self.holds($0, at: now, macOS: macOS) ? $0 : nil }
  }

  // Either way, so that a date from a clock that ran ahead does not live for ever.
  private static func holds(_ entry: Entry, at now: Date, macOS: Int) -> Bool {
    entry.macOS == macOS && abs(now.timeIntervalSince(entry.seen)) < lifetime
  }

  /// A window of `app` was asked for less and took `size`, 0 in a direction in which it did as it was asked. What was just
  /// seen replaces what was known, larger or smaller. Returns whether anything changed.
  ///
  /// There is one date for two numbers, and it is the older one's: it is renewed only when all that is known has been stood by. What
  /// nobody stands by must not live on because the other direction is asked about every day.
  @discardableResult
  public mutating func stoodBy(_ size: CGSize, app: String, macOS: Int, at date: Date) -> Bool {
    // Half of an answer that no window could have given is not believed either.
    guard Self.isName(app), size.width.isFinite, size.height.isFinite, size.width >= 0, size.height >= 0 else { return false }
    // An answer that is older than what is kept (a window answered while it floated, and is docked weeks later) is no news.
    if let kept = apps[app], kept.macOS == macOS, date < kept.seen { return false }
    // What is too old to go by does not come back to life with the other direction's answer.
    var entry = self.entry(for: app, at: date, macOS: macOS) ?? Entry(width: 0, height: 0, macOS: macOS, seen: date)
    if (entry.width == 0 || size.width > 0) && (entry.height == 0 || size.height > 0) { entry.seen = date }
    if size.width > 0 { entry.width = Double(size.width) }
    if size.height > 0 { entry.height = Double(size.height) }
    guard entry.isSound, entry != apps[app] else { return false }
    apps[app] = entry
    trim()
    return true
  }

  /// A window of `app` has been seen at `size`. Where that is smaller than what is on record, the record was wrong, or is about another
  /// kind of window: that direction is unknown again. Not what was seen: nobody stood by that, and a size that is merely not too
  /// small would be disproved again at the next smaller slot, with a window going out of view and back each time.
  @discardableResult
  public mutating func wasSeen(at size: CGSize, app: String) -> Bool {
    // A window with next to no size is coming or going, not one that goes down to nothing.
    guard var entry = apps[app], Double(size.width) >= Self.leastSide, Double(size.height) >= Self.leastSide else { return false }
    if Double(size.width) < entry.width - Self.tolerance { entry.width = 0 }
    if Double(size.height) < entry.height - Self.tolerance { entry.height = 0 }
    guard entry != apps[app] else { return false }
    apps[app] = entry.width > 0 || entry.height > 0 ? entry : nil
    return true
  }

  /// The name of the line in which a trace is told what was known of an app whose first window came while it was recorded.
  public static let traceLine = "howSmallItGoes"

  /// For a replay: what such a line says. What the header says of the app, which is older, stays. Returns whether it was taken.
  @discardableResult
  public mutating func take(_ entry: Entry, for app: String) -> Bool {
    guard Self.isName(app), entry.isSound, apps[app] == nil else { return false }
    apps[app] = entry
    return true
  }

  @discardableResult
  public mutating func drop(_ names: some Sequence<String>) -> Bool {
    let before = apps.count
    for name in names { apps[name] = nil }
    return apps.count != before
  }

  /// Drops what is too old to go by, and what was seen on another macOS.
  @discardableResult
  public mutating func expire(at now: Date, macOS: Int) -> Bool {
    // Asked at every layout, and nearly always there is nothing to drop.
    guard apps.values.contains(where: { !Self.holds($0, at: now, macOS: macOS) }) else { return false }
    apps = apps.filter { Self.holds($0.value, at: now, macOS: macOS) }
    return true
  }

  /// The same, every date `seconds` later, as if seen on `macOS`. For a replay, which has a clock and a system of its own: how old
  /// each entry was when the trace began is what counts.
  public func moved(by seconds: TimeInterval, macOS: Int) -> AppSizes {
    var moved = self
    moved.apps = apps.mapValues { Entry(width: $0.width, height: $0.height, macOS: macOS, seen: $0.seen.addingTimeInterval(seconds)) }
    return moved
  }

  /// The oldest go first, and of two as old as each other the same one every time.
  private mutating func trim() {
    guard apps.count > Self.capacity else { return }
    let kept = apps.sorted { ($0.value.seen, $0.key) > ($1.value.seen, $1.key) }.prefix(Self.capacity)
    apps = Dictionary(uniqueKeysWithValues: kept.map { ($0.key, $0.value) })
  }

  private static func isName(_ app: String) -> Bool { !app.isEmpty && app.utf8.count <= 255 }
}

extension AppSizes: Codable {
  /// Entry by entry. One that cannot be read or believed is left out, which costs a question to a window of that app and nothing
  /// a person has made: no reason to call a file damaged.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.container(keyedBy: StringKey.self)
    var skipped = 0
    for key in container.allKeys {
      if Self.isName(key.stringValue), let entry = try? container.decode(Entry.self, forKey: key), entry.isSound {
        apps[key.stringValue] = entry
      } else {
        skipped += 1
      }
    }
    trim()
    if skipped > 0 {
      (decoder.userInfo[DecodingNotes.key] as? DecodingNotes)?.add(
        [], tidied: ["left out \(skipped) that cannot be read or believed"], at: decoder.codingPath)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: StringKey.self)
    for (app, entry) in apps { try container.encode(entry, forKey: StringKey(app)) }
  }
}
