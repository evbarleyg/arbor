import Foundation

/// A request for the keyboard that waits for an app that does not answer, and whether it is still to be made when the app wakes.
///
/// A move of the view moves a window and then gives it the keyboard. If its app hangs at that moment the request is kept, or the keyboard
/// would stay in a window that has just gone out of view. But a hang lasts seconds, and the person does not sit still: whoever
/// switches apps or clicks says where the keyboard goes, and ends the wait. Two ways past that were left. A switch of apps that is
/// never reported: the request went on to activate the app, and took the keyboard from another. And a key typed ahead into the hung app
/// itself (⌘` for its next window), which the app serves as it wakes: the request took the keyboard back from where its person had just
/// sent it. So at the wake it is made only if things are as they were when the wait began. And soon enough: with another app in front its
/// person can go on typing there, which nothing tells of, and a minute later the keyboard would be taken from under their hands.
public struct WaitingFocus: Equatable, Sendable {
  public let window: WindowID
  /// The window's app.
  public let app: Int32
  /// Whom macOS named as the app in front when the wait began, and how many apps Arbor had heard come forward by then. Two channels,
  /// of which either can be behind the other (`AppThatCameForward`), or miss a switch.
  public let front: Int32?
  public let activations: Int
  /// The window Arbor had last heard has the keyboard. Nil if nothing was heard since its app came forward.
  public let heard: WindowID?
  /// When the wait began, on a clock that never goes backwards.
  public let began: TimeInterval

  /// How long a request for a window of an app in the background keeps, in seconds. Long enough for whoever is still looking at the window
  /// they asked for; a hang is not known for one before a second has passed.
  public static let keeps: TimeInterval = 3

  public init(window: WindowID, app: Int32, front: Int32?, activations: Int, heard: WindowID?, began: TimeInterval) {
    self.window = window
    self.app = app
    self.front = front
    self.activations = activations
    self.heard = heard
    self.began = began
  }

  public enum Verdict: Equatable, Sendable {
    /// Nothing speaks against it.
    case make
    /// The person is somewhere else by now.
    case drop
    /// The app is the one in front: it may have been asked for another of its windows meanwhile. Ask it which has the keyboard.
    case ask
  }

  /// What macOS says of the apps now. If either channel tells of a switch, there has been one.
  public func verdict(front now: Int32?, activations count: Int, at time: TimeInterval) -> Verdict {
    guard now == front, count == activations else { return .drop }
    // Whoever has a hung app in front can type nowhere else without a switch or a click.
    if now == app { return .ask }
    return time - began <= Self.keeps ? .make : .drop
  }

  /// The app says of itself, as it wakes, that this window of its has got the keyboard. Nobody has to know which had it before: unless that is
  /// old news, of the window Arbor last heard of, somebody asked the app for it while it hung.
  public func verdict(reported now: WindowID) -> Verdict {
    now == window || now == heard ? .make : .drop
  }

  /// What the app in front says has the keyboard now; nil if none of the windows Arbor knows.
  public func verdict(focused now: WindowID?) -> Verdict {
    // What it had is not known, so nothing can be seen to have changed. Nor has it if nobody has the keyboard.
    guard let heard, let now else { return .make }
    return now == heard || now == window ? .make : .drop
  }
}
