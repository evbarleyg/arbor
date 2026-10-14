import ArborCore
import CoreGraphics

/// Appearance options (docs/features/F15-appearance-options.md): how the settings reach what Arbor draws.
/// None of this moves a window; frames are the same whatever the options say.
extension Controller {
  /// Fills in the parts of a scene that depend on the appearance settings.
  func applyAppearance(to scene: inout OverlayScene, for layout: Layout, on displayID: DisplayID) {
    let options = settings.appearanceOptions
    for index in scene.tiles.indices {
      scene.tiles[index].usesAppColour = options.usesAppColours
      scene.tiles[index].colourAmount = options.appColourAmount
      scene.tiles[index].style = options.tileStyle
    }
    // Without seams in the scene there is nothing to drag.
    if options.gapHandles == .off { scene.seams = [] }
    scene.showsSeamHandles = options.gapHandles == .shown
    scene.tileFade = options.tileFade
    scene.backdrop = backdrop(for: layout, on: displayID, options: options)
  }

  /// The surface behind what is docked and in view, or nil if there is nothing to draw.
  func backdrop(for layout: Layout, on displayID: DisplayID, options: AppearanceOptions) -> BackdropModel? {
    let edge = layout.desktopFrame == nil ? 0 : options.desktopEdge
    guard options.dim > 0 || options.blur > 0 || options.tint > 0 || edge > 0, let tree = workspaces[displayID]?.tree
    else { return nil }
    let growth = BackdropShape.growth(forGap: self.options(for: displayID).layoutOptions.gap)
    let rects = BackdropShape.surface(
      slots: BackdropShape.slots(of: layout, in: tree), growth: growth, within: layout.frame,
      avoiding: layout.desktopFrame)
    guard !rects.isEmpty else { return nil }
    return BackdropModel(
      frame: layout.frame, rects: rects, growth: growth, dim: options.dim, blur: options.blur, tint: options.tint,
      desktop: edge > 0 ? layout.desktopFrame : nil, desktopEdge: edge)
  }
}
