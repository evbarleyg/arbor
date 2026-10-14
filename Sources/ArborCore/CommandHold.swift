/// How firmly the view is held (docs/features/F58-hold-the-view.md).
public enum HoldLevel: String, Codable, Sendable, Equatable {
  /// `hold still`: Arbor moves the view only when the user asks for it.
  case still
  /// `hold`: nothing moves the view until `release`.
  case view
}

extension Command {
  /// Whether the command may run while the view is held (`hold`; `hold still` refuses nothing).
  ///
  /// The promise is that what an audience sees stays as it is, so the list says what is known to keep
  /// it: queries, the ways out, and rearranging the windows that are in view (the controller checks
  /// that they are). Everything else is refused, **including every command added later until it is
  /// listed here**: a key that does nothing and says why costs a moment, a view that jumps in front of an
  /// audience cannot be taken back. Settings wait too: `exclude` brings an app's windows back into
  /// view, and a reloaded file can resize everything.
  ///
  /// The ways out that bring every window into view (pausing, floating everything) are for the menu and the
  /// terminal. From a shortcut the controller answers them differently (`Controller.holdAnswers`).
  public var isAllowedWhileHeld: Bool {
    if isQuery { return true }
    switch self {
    case .hold, .holdStill, .release, .toggleHold: return true
    case .pause, .resume, .togglePause, .floatAll, .floatAllHere, .quit: return true
    case .dock, .dockBeside, .float, .toggleFloat, .resize, .relayout: return true
    // The keyboard's ways of doing the same, and of going from one window in view to another (F22). Where `focus` would
    // have to move the view, and where `swap` would cross to another display, the controller refuses.
    case .focus, .focusDisplay, .swap, .swapWindows, .grow, .shrink, .equalize, .rotate, .mirror: return true
    // Remembers where the view is without moving it.
    case .saveView: return true
    // So does a name, given or taken off. The field to type one into would open in front of the audience; closing it may.
    case .name, .unname, .askName(cancel: true): return true
    // Nothing of it shows.
    case .launchAtLogin: return true
    // Nor of this, and a hold that misbehaves on somebody's Mac is found out by recording it.
    case .trace: return true
    default: return false
    }
  }

  /// For the log, of a command that a held view refused. A settings command logs itself when it runs, without what it may hold of a
  /// window's title (`rule add … title …`); refused, it never gets there, so only its verb is written.
  public var textWhenRefused: String {
    if case .settings = self { return verb }
    return textWithoutNames
  }

  /// The ways out of a hold that show an audience every window. Chosen from the menu or typed they are meant; on a key they
  /// can be a slip (`Controller.holdAnswers`).
  public var bringsEverythingIntoView: Bool {
    switch self {
    case .pause, .togglePause, .floatAll, .floatAllHere: true
    default: false
    }
  }

  /// The windows the command names or, with nil, means by "the focused window". While the view is
  /// held they must all be in view: docking or floating one that is not would bring it in.
  public var arrangedWindows: [WindowID?] {
    switch self {
    case .dock(let window, _), .float(let window), .toggleFloat(let window), .resize(let window, _, _): [window]
    case .dockBeside(let window, let target, _): [window, target]
    case .focus(.window(let window)): [window]
    case .swap(let window, _): [window]
    case .swapWindows(let first, let second): [first, second]
    case .grow, .shrink, .rotate, .mirror: [nil]
    default: []
    }
  }

  /// Whether the first of `arrangedWindows` leaves its place in the arrangement for another, or for none.
  public var takesAWindowOutOfItsPlace: Bool {
    switch self {
    case .dock, .dockBeside, .float, .toggleFloat: true
    default: false
    }
  }
}

/// Signs of a call or a recording that macOS lets any app read, without permission, because nothing is captured:
/// whether some app has a camera or a microphone running. They say "call", not "the screen is shared", which
/// nothing says; but a call is when nothing may jump.
public struct CallSignals: Equatable, Sendable {
  public var cameraIsOn: Bool
  public var microphoneIsOn: Bool

  public init(cameraIsOn: Bool = false, microphoneIsOn: Bool = false) {
    self.cameraIsOn = cameraIsOn
    self.microphoneIsOn = microphoneIsOn
  }
}

/// An entry of the `holdStillFor` setting: a bundle id, optionally followed by text that the window's
/// title must contain: `us.zoom.xos Zoom Meeting`. Bundle ids have no spaces, so the first one divides them.
public struct HoldPattern: Equatable, Sendable {
  public var app: String
  public var title: String?

  public init(_ text: String) {
    let trimmed = text.drop(while: \.isWhitespace)
    app = String(trimmed.prefix { !$0.isWhitespace })
    let rest = trimmed.dropFirst(app.count).drop(while: \.isWhitespace)
    title = rest.isEmpty ? nil : String(rest)
  }

  /// As a rule matches (AppRule.swift): the app exactly, the title anywhere and whatever its case.
  public func matches(bundleID: String?, title windowTitle: String) -> Bool {
    !app.isEmpty && AppRule(app: app, title: title, action: .float).matches(bundleID: bundleID, title: windowTitle)
  }
}
