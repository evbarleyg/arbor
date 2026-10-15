import AppKit
import ArborCore
import CoreGraphics
import Foundation

/// A panel that comes, says something and goes: a translucent rounded background that fades in and out, above
/// everything else Arbor draws. The heads-up line and the panel of shortcuts are both one.
class PassingPanel: OverlayPanel {
  static let fadeIn: TimeInterval = 0.1
  static let fadeOut: TimeInterval = 0.25

  let background = PanelGround()
  /// Whether the panel is meant to be seen. It stays on screen a little longer, while it fades out.
  private(set) var isWanted = false
  /// How often it has begun to fade out, so that the end of an earlier fade does not cut a later one short.
  private var departures = 0

  override init() {
    super.init()
    // The stage that covers a display while windows move is one above `.floating`.
    level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + 2)
    hasShadow = true
    // Not `.fullScreenAuxiliary`: another app's full-screen Space is none of Arbor's business. `.transient`, because a
    // `.stationary` panel stays on screen in Mission Control.
    collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
    contentView = background
  }

  private var animates: Bool { !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

  /// Fades in, or carries on showing. With "Reduce motion" on it only appears.
  func appear() {
    isWanted = true
    if !isVisible {
      alphaValue = animates ? 0 : 1
      orderFrontRegardless()
    }
    // Through the animator even when there is nothing to fade, so that it replaces a fade-out under way.
    NSAnimationContext.runAnimationGroup { context in
      context.duration = animates ? Self.fadeIn : 0
      animator().alphaValue = 1
    }
  }

  /// Fades out, or with `atOnce` is simply gone.
  func disappear(atOnce: Bool = false) {
    guard isWanted else { return }
    isWanted = false
    departures += 1
    let departure = departures
    guard animates, !atOnce else {
      orderOut(nil)
      return
    }
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = Self.fadeOut
        animator().alphaValue = 0
      },
      completionHandler: { [weak self] in
        MainActor.assumeIsolated {
          // Unless it was asked for again while it faded.
          guard let self, !self.isWanted, self.departures == departure else { return }
          self.orderOut(nil)
        }
      })
  }
}

/// Draws the heads-up line (`HeadsUpModel`): one or two lines of text that no click can hit.
final class HeadsUpPanel: PassingPanel {
  private static let padding = NSSize(width: 18, height: 10)
  private let line = MeasuredTextView()
  /// What it was last asked to show.
  private(set) var shown: HeadsUpModel?

  override init() {
    super.init()
    // One higher than the panel of shortcuts, which a line may have something to say about.
    level = NSWindow.Level(rawValue: level.rawValue + 1)
    ignoresMouseEvents = true
    background.addSubview(line)
  }

  /// What `show` puts where. Worked out without a window, so that tests can draw it off screen.
  struct Placement {
    /// The panel, in global coordinates.
    var frame: CGRect
    var text: NSAttributedString
    /// The text inside the panel.
    var textFrame: NSRect
  }

  static func placement(of model: HeadsUpModel) -> Placement {
    let text = Self.text(of: model)
    let limit = NSSize(width: model.maximumWidth - 2 * Self.padding.width, height: 400)
    let measured = text.boundingRect(with: limit, options: [.usesLineFragmentOrigin, .usesFontLeading]).size
    let size = NSSize(width: measured.width.rounded(.up), height: measured.height.rounded(.up))
    let frame = CGRect(
      x: (model.anchor.x - size.width / 2 - Self.padding.width).rounded(),
      y: (model.anchor.y - size.height - 2 * Self.padding.height).rounded(),
      width: size.width + 2 * Self.padding.width, height: size.height + 2 * Self.padding.height)
    return Placement(
      frame: frame, text: text, textFrame: NSRect(origin: NSPoint(x: Self.padding.width, y: Self.padding.height), size: size))
  }

  func show(_ model: HeadsUpModel) {
    shown = model
    let placement = Self.placement(of: model)
    setFrame(ScreenGeometry.appKit(fromGlobal: placement.frame), display: false)
    background.radius = PanelLook.Corner.line(height: placement.frame.height)
    line.frame = placement.textFrame
    line.text = placement.text
    invalidateShadow()
    appear()
  }

  /// What happened, and after a dot what to press next: lighter in weight, not in colour. The keys are what the
  /// person came for, the line is gone in seconds, and the colour of secondary text stood out from the panel by 3 to 1
  /// on a Mac. Where the line wraps the dot goes with the hint: spaces that do not break tie it there.
  private static func text(of model: HeadsUpModel) -> NSAttributedString {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    paragraph.lineBreakMode = .byWordWrapping
    let text = NSMutableAttributedString(
      string: model.text,
      attributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: PanelInk.main,
        .paragraphStyle: paragraph,
      ])
    if let hint = model.hint {
      for (part, colour) in [("  ·\u{A0}\u{A0}", PanelInk.second), (hint, PanelInk.main)] {
        text.append(
          NSAttributedString(
            string: part,
            attributes: [
              .font: NSFont.systemFont(ofSize: 15, weight: .regular), .foregroundColor: colour, .paragraphStyle: paragraph,
            ]))
      }
    }
    return text
  }
}

/// Draws text exactly where it was measured to fit, which a text field's cell, with margins of its own, does not.
final class MeasuredTextView: NSView {
  var text = NSAttributedString() {
    didSet { needsDisplay = true }
  }

  override var isFlipped: Bool { true }

  override func draw(_ dirtyRect: NSRect) {
    text.draw(with: bounds, options: [.usesLineFragmentOrigin, .usesFontLeading])
  }
}
