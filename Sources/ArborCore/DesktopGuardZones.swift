import CoreGraphics

/// Where a press might land on bare Desktop inside Arbor's view (F60, F05), as far as Arbor itself can
/// tell. The controller publishes it after every change and the mouse-down tap asks it first, because
/// the answer is nearly always no and costs next to nothing: most clicks on a Mac are on windows.
/// A yes only means that the window server's list is worth reading (`PointerSurface`).
public struct DesktopGuardZones: Equatable, Sendable {
  /// A display with something docked.
  public struct Display: Equatable, Sendable {
    /// The part of the display Arbor lays out: without the menu bar and the Dock.
    public var view: CGRect
    /// Where the windows Arbor knows to be in view really are, docked or not. Not their slots: a window
    /// that cannot grow to its slot has wallpaper around it.
    public var windows: [CGRect]
    /// Where Arbor's own tiles and gap handles stand, and a minimap that takes clicks.
    public var panels: [CGRect]

    public init(view: CGRect, windows: [CGRect], panels: [CGRect]) {
      self.view = view
      self.windows = windows
      self.panels = panels
    }
  }

  public var displays: [Display]

  public init(displays: [Display] = []) {
    self.displays = displays
  }

  /// Nothing is guarded anywhere.
  public var isEmpty: Bool { displays.isEmpty }

  /// - Parameter throughPanels: whether a tile or a gap handle counts as bare. A plain press on one is
  ///   meant for it; a rectangle may start there.
  public func mayBeBare(_ point: CGPoint, throughPanels: Bool = false) -> Bool {
    displays.contains { display in
      display.view.contains(point) && !display.windows.contains { $0.contains(point) }
        && (throughPanels || !display.panels.contains { $0.contains(point) })
    }
  }
}
