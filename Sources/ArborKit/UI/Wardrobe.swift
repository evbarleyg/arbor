import AppKit
import ArborCore

/// What a window's cover is drawn from, for each app: its colour and its icon.
///
/// macOS draws an app's icon at a size the first time anybody asks for it at that size, and keeps it. On a Mac that has
/// not drawn them yet that takes long: 4.7 s for eight apps on a hosted Mac, 27 ms for the same eight a minute later. A
/// motion that asked while it was being set up kept the real windows, and whoever had pressed the key, waiting all that time.
/// It is nobody's main thread's business. So covers are made on a thread of their own, ahead of time (`order`, from
/// `StageDirector.rehearse`), and **a motion never waits for one**: it takes what is here, and a window whose app has no
/// cover yet sets off as a plain grey card and is dressed on its way, as soon as the cover arrives.
@MainActor
final class Wardrobe {
  struct Cover {
    /// The colour the app's icon is recognised by. What becomes of it on a card is the tiles' business (`Transition.Cover`).
    var colour: RGBA?
    var icon: CGImage?
  }

  /// For a window whose app's cover is not here yet, or has no icon.
  static let plain = Cover(colour: nil, icon: nil)

  /// Called with every cover as it arrives, for a motion that began without it.
  var onCover: ((Rehearsal.App, Cover) -> Void)?

  private var covers: [String: Cover] = [:]
  private var ordered: Set<String> = []
  /// One after the other: they all wait for the same service of macOS's.
  private static let workshop = DispatchQueue(label: "dev.arbor.wardrobe", qos: .userInitiated)

  /// The cover if it is here. If not it is ordered, and `onCover` brings it.
  func cover(of app: Rehearsal.App) -> Cover? {
    if let cover = covers[AppAppearance.key(pid: app.pid, bundleID: app.bundleID)] { return cover }
    order(app)
    return nil
  }

  /// Has the app's cover made, unless it is here or on its way. Returns at once.
  ///
  /// A process without a bundle identifier goes by its number, and numbers get new owners: `again` makes its cover anew.
  func order(_ app: Rehearsal.App, again: Bool = false) {
    let key = AppAppearance.key(pid: app.pid, bundleID: app.bundleID)
    guard again || covers[key] == nil, ordered.insert(key).inserted else { return }
    Self.workshop.async {
      let began = ProcessInfo.processInfo.systemUptime
      let made = Self.make(pid: app.pid)
      let took = Int(((ProcessInfo.processInfo.systemUptime - began) * 1000).rounded())
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          self.ordered.remove(key)
          // Its process has gone, or it has no icon. Whoever asks again orders again.
          guard let made else { return Log.debug("no costume for \(app.bundleID ?? "pid \(app.pid)") after \(took) ms") }
          let cover = Cover(colour: made.colour, icon: made.icon)
          self.covers[key] = cover
          // Tiles and the minimap are tinted with it, and ask while they wait to be drawn.
          if let colour = made.colour { AppAppearance.remember(colour, pid: app.pid, bundleID: app.bundleID) }
          Log.debug("got ready the costume of \(app.bundleID ?? "pid \(app.pid)") in \(took) ms")
          self.onCover?(app, cover)
        }
      }
    }
  }

  /// Made on the workshop's thread and handed over whole: nobody there keeps hold of it.
  private struct Made: @unchecked Sendable {
    var icon: CGImage?
    var colour: RGBA?
  }

  nonisolated private static func make(pid: Int32) -> Made? {
    guard let icon = NSRunningApplication(processIdentifier: pid)?.icon else { return nil }
    var proposed = NSRect(x: 0, y: 0, width: 256, height: 256)
    return Made(icon: icon.cgImage(forProposedRect: &proposed, context: nil, hints: nil), colour: AppAppearance.colour(of: icon))
  }
}
