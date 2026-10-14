import CoreGraphics
import SwiftUI

/// Rounded rectangles with the corner curve macOS gives its windows, which starts to bend about one and a half
/// radii before the corner instead of one. SwiftUI is the only public way to that curve as a path. It
/// has this file to itself because it has an `Edge`, an `Axis`, a `Layout` and a `Settings` of its own.
@MainActor
enum ContinuousCorners {
  /// The corner radius macOS gives a window with a plain title bar. Everything of Arbor's that lies around a window
  /// or stands in for one follows it: the focus ring, tiles, the drop preview, the backdrop. On macOS 26 the
  /// continuous curve of radius 17 fits a screenshot of a window's corner to a fifth of a point; 16 leaves half a
  /// point of wallpaper between window and ring. The older systems' 10 is not measured.
  static var windowRadius: CGFloat {
    if #available(macOS 26, *) { return 17 }
    return 10
  }

  static func path(_ rect: CGRect, radius: CGFloat) -> CGPath {
    RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect).cgPath
  }
}
