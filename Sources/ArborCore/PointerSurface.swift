import CoreGraphics

/// Whether an app's window is under the pointer, judged from the window server's list.
///
/// Some gestures are Arbor's only where no app would want them: a pinch without ⌥, for one, belongs
/// to Arbor on the Desktop, in a gap between windows and on a tile. Taking an event from an app is
/// the worse mistake, so whatever is not clearly bare counts as an app's.
public enum PointerSurface {
  /// One window on screen, as the window server lists it.
  public struct Window: Equatable, Sendable {
    public var frame: CGRect
    /// The window's level: 0 for ordinary windows, 3 for floating palettes, 20 for the Dock, 24 for
    /// the menu bar, 25 for its items, 101 for open menus. The wallpaper and the icons on it are below 0.
    public var layer: Int
    public var alpha: Double
    /// One of Arbor's own panels: a tile, a seam handle, the band. Not an ordinary window of its own.
    public var isOwn: Bool
    /// The process the window belongs to; 0 if that does not matter.
    public var pid: Int32

    public init(frame: CGRect, layer: Int, alpha: Double = 1, isOwn: Bool = false, pid: Int32 = 0) {
      self.frame = frame
      self.layer = layer
      self.alpha = alpha
      self.isOwn = isOwn
      self.pid = pid
    }
  }

  public enum Surface: Equatable, Sendable {
    /// Somebody may want a click here: there is a window, a menu or a widget under the pointer, or something
    /// elsewhere on screen that a click beside it would close, or something this rule does not know.
    case taken
    /// The Desktop. `owner` is the process that draws the icons, which knows whether one is under the pointer. Nil
    /// if nobody draws any (people hide them): then it is the wallpaper, and there is nobody to ask and no need to.
    case bare(owner: Int32?)
  }

  /// Floating palettes, and Arbor's own panels (the band, the drop preview, the peek's outline), all but one.
  static let floatingLevel = 3
  /// The stage of a motion (F02, `StagePanel`), the highest of Arbor's own panels. It covers the display, so it is looked
  /// through under the pointer like any such window.
  static let stageLevel = floatingLevel + 1
  static let dockLevel = 20
  static let menuBarLevels = 24...25
  /// About 30 points without a notch, 37 beside one.
  static let tallestMenuBar: CGFloat = 50
  /// `kCGDesktopIconWindowLevel`: where Finder keeps the icons, in a window as large as the display.
  static let desktopIconLevel = -2_147_483_603

  /// What a press at `point` would meet, for whoever means to hold it back on the Desktop (F60, F05). Stricter than
  /// `appWindowIsUnder`, which only decides who gets a pinch.
  ///
  /// - Parameters:
  ///   - windows: the windows on screen, the Desktop's elements included, in any order.
  ///   - displays: the frames of all displays.
  ///   - mayVanish: the press may be kept from everybody for good, as a plain click is by the guard. Then nothing
  ///     anywhere on screen may be waiting for it: a click that vanishes looks like a broken Mac. A press
  ///     with ⇧ is given back or becomes a rectangle, and must not stop working wherever something unknown is up.
  public static func under(_ point: CGPoint, windows: [Window], displays: [CGRect], mayVanish: Bool) -> Surface {
    guard let display = displays.first(where: { $0.contains(point) }),
      !appWindowIsUnder(point, windows: windows, display: display),
      !mayVanish || whatMayBeWaiting(windows, displays: displays) == nil,
      // Not Arbor's own: the backdrop (F15) lies just above the icons, and the mouse goes straight through it.
      case let below = windows.filter({ $0.alpha > 0 && $0.layer < 0 && !$0.isOwn && $0.frame.contains(point) }),
      // What belongs to the Desktop itself (the wallpaper, the window with the icons) is as large as the display. Anything
      // smaller is somebody's: a widget, wherever macOS keeps those. Behind the icons Finder would call it wallpaper.
      below.allSatisfy({ $0.frame.contains(display) }),
      // Whatever lies in front of the icons (a tool that draws on the wallpaper) would answer for them.
      // Without anything below the windows the list is not what it should be.
      let front = below.max(by: { $0.layer < $1.layer }), front.layer <= desktopIconLevel
    else { return .taken }
    return .bare(owner: front.layer == desktopIconLevel ? front.pid : nil)
  }

  /// The first window on screen, above the windows and palettes, that a Mac at rest does not have there. Nil if
  /// there is none.
  ///
  /// An open menu, Spotlight, Control Centre, a Dock stack: people click the wallpaper to be rid of them, so they wait
  /// for a click that is nowhere near them. Mission Control and the crosshair of a screenshot cover the display
  /// while the list goes on giving the windows' real places. Their levels have not been measured, and there
  /// will be others, so this knows what is harmless and takes everything else to be waiting. Measured on
  /// macOS 26.6: the Dock keeps one window as large as each display at level 20, the menu bar is at 24 and its items at 25.
  public static func whatMayBeWaiting(_ windows: [Window], displays: [CGRect]) -> Window? {
    var uncovered = displays
    for window in windows where window.alpha > 0 && window.layer > floatingLevel {
      // Up for as long as the view moves. Given back, a click during a motion would sweep the windows aside.
      if window.isOwn, window.layer == stageLevel { continue }
      if menuBarLevels.contains(window.layer), window.frame.height <= tallestMenuBar { continue }
      if window.layer == dockLevel, let index = uncovered.firstIndex(where: { window.frame.contains($0) }) {
        uncovered.remove(at: index)
        continue
      }
      return window
    }
    return nil
  }

  /// Whether, by what the app that draws the Desktop says, it has a use for a click under the pointer: an item is
  /// there rather than the wallpaper, or a name is being edited, which a click beside it ends. Nil if the app
  /// did not say, or not all of it.
  ///
  /// - Parameters:
  ///   - roles: the Accessibility role of the element under the pointer, then its parent's, and so on for a
  ///     few levels. Finder says AXGroup, AXScrollArea, AXApplication of the wallpaper, and AXImage before those
  ///     of an icon. Empty if any of them could not be had: half an answer is none.
  ///   - focused: the role of the element that has the keyboard in that app, "" if none has, nil if the app
  ///     did not say.
  public static func isDesktopItem(roles: [String], focused: String?) -> Bool? {
    guard !roles.isEmpty else { return nil }
    if roles.contains(where: desktopItems.contains) { return true }
    return focused.map(textFields.contains)
  }

  static let textFields: Set<String> = ["AXTextField", "AXTextArea"]

  /// Icons are images; a name being edited is a text field; widgets are made of buttons.
  static let desktopItems: Set<String> = [
    "AXImage", "AXTextField", "AXTextArea", "AXButton", "AXCell", "AXRow", "AXMenuItem", "AXLink",
  ]

  /// - Parameters:
  ///   - windows: the windows on screen, front to back.
  ///   - display: the frame of the display under the pointer, if known.
  public static func appWindowIsUnder(_ point: CGPoint, windows: [Window], display: CGRect?) -> Bool {
    for window in windows where window.alpha > 0 && window.layer >= 0 && window.frame.contains(point) {
      // Arbor's own panels are looked through. Nothing is under a tile or a seam handle, which stand
      // where windows are not; the focus ring's panel lies over the whole of the window it surrounds; the
      // band and the drop preview float above the windows. Its menu, higher up, is a menu like any other.
      if window.isOwn, window.layer <= floatingLevel { continue }
      // Something above the ordinary windows that covers the whole display cannot be what the
      // pointer is aimed at, or nothing else would be visible: the Dock keeps such a window at level
      // 20, and screen dimmers do the same. Anything smaller is: a menu, the menu bar, a palette.
      if window.layer > 0, let display, window.frame.contains(display) { continue }
      return true
    }
    return false
  }
}
