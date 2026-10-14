// A stand-in for AppKit: views, layout, animation. See Application.swift.

@MainActor public protocol NSAnimatablePropertyContainer {
  func animator() -> Self
  var animations: [NSAnimatablePropertyKey: Any] { get set }
}
extension NSAnimatablePropertyContainer {
  public func animator() -> Self { self }
  public var animations: [NSAnimatablePropertyKey: Any] {
    get { [:] }
    set {}
  }
}
public typealias NSAnimatablePropertyKey = String
@MainActor public protocol NSAppearanceCustomization: NSObjectProtocol {
  var appearance: NSAppearance? { get set }
  var effectiveAppearance: NSAppearance { get }
}

@MainActor public protocol NSViewToolTipOwner: NSObjectProtocol {
  func view(_ view: NSView, stringForToolTip tag: NSView.ToolTipTag, point: NSPoint, userData data: UnsafeMutableRawPointer?) -> String
}

/// The completion handler is `@Sendable` here, the stricter reading: hop to the main actor inside it.
@MainActor open class NSAnimationContext: NSObject {
  open class func runAnimationGroup(_ changes: (NSAnimationContext) -> Void, completionHandler: (@Sendable () -> Void)? = nil) {}
  open class func runAnimationGroup(_ changes: (NSAnimationContext) -> Void) async {}
  open class func beginGrouping() {}
  open class func endGrouping() {}
  open class var current: NSAnimationContext { NSAnimationContext() }
  open var duration: TimeInterval = 0.25
  open var timingFunction: CAMediaTimingFunction?
  open var completionHandler: (@Sendable () -> Void)?
  open var allowsImplicitAnimation = false
}

@MainActor open class NSView: NSResponder, NSAnimatablePropertyContainer, NSAppearanceCustomization, NSUserInterfaceItemIdentification {
  public struct AutoresizingMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let none = AutoresizingMask([])
    public static let minXMargin = AutoresizingMask(rawValue: 1)
    public static let width = AutoresizingMask(rawValue: 2)
    public static let maxXMargin = AutoresizingMask(rawValue: 4)
    public static let minYMargin = AutoresizingMask(rawValue: 8)
    public static let height = AutoresizingMask(rawValue: 16)
    public static let maxYMargin = AutoresizingMask(rawValue: 32)
  }
  public enum LayerContentsRedrawPolicy: Int, Sendable { case never = 0, onSetNeedsDisplay, duringViewResize, beforeViewResize, crossfade }
  public enum LayerContentsPlacement: Int, Sendable {
    case scaleAxesIndependently = 0, scaleProportionallyToFit, scaleProportionallyToFill, center, top, topRight, right, bottomRight, bottom,
      bottomLeft, left, topLeft
  }
  public typealias TrackingRectTag = Int
  public typealias ToolTipTag = Int

  public init(frame frameRect: NSRect) { super.init() }
  public required override init?(coder: NSCoder) { super.init(coder: coder) }
  public convenience override init() { self.init(frame: .zero) }

  open var window: NSWindow? { nil }
  open var superview: NSView? { nil }
  open var subviews: [NSView] = []
  open var identifier: NSUserInterfaceItemIdentifier?
  open var tag: Int { -1 }
  open var frame = NSRect.zero
  open var bounds = NSRect.zero
  open var frameRotation: CGFloat = 0
  open var visibleRect: NSRect { .zero }
  open var isHidden = false
  open var isHiddenOrHasHiddenAncestor: Bool { false }
  open var alphaValue: CGFloat = 1
  open var isFlipped: Bool { false }
  open var isOpaque: Bool { false }
  open var wantsLayer = false
  open var layer: CALayer?
  open var wantsUpdateLayer: Bool { false }
  open var layerContentsRedrawPolicy: LayerContentsRedrawPolicy = .never
  open var layerContentsPlacement: LayerContentsPlacement = .scaleAxesIndependently
  open var canDrawSubviewsIntoLayer = false
  open var layerUsesCoreImageFilters = false
  open var clipsToBounds = false
  open var shadow: NSShadow?
  open var needsDisplay = false
  open var needsLayout = false
  open var needsUpdateConstraints = false
  open var autoresizingMask: AutoresizingMask = []
  open var autoresizesSubviews = true
  open var translatesAutoresizingMaskIntoConstraints = true
  open var postsFrameChangedNotifications = false
  open var postsBoundsChangedNotifications = false
  open var toolTip: String?
  open var focusRingType: NSFocusRingType = .default
  open var appearance: NSAppearance?
  open var effectiveAppearance: NSAppearance { NSAppearance() }
  open var userInterfaceLayoutDirection: NSUserInterfaceLayoutDirection = .leftToRight
  open var trackingAreas: [NSTrackingArea] { [] }
  open var gestureRecognizers: [NSGestureRecognizer] = []
  open var allowedTouchTypes: NSTouch.TouchTypeMask = []
  open var wantsRestingTouches = false
  open var mouseDownCanMoveWindow: Bool { false }
  open var canBecomeKeyView: Bool { false }
  open var needsPanelToBecomeKey: Bool { false }
  open var nextKeyView: NSView?
  open var inLiveResize: Bool { false }
  open var enclosingScrollView: NSScrollView? { nil }
  open var enclosingMenuItem: NSMenuItem? { nil }
  open var allowsVibrancy: Bool { false }
  open var intrinsicContentSize: NSSize { .zero }
  open var fittingSize: NSSize { .zero }
  open var firstBaselineOffsetFromTop: CGFloat { 0 }
  open var lastBaselineOffsetFromBottom: CGFloat { 0 }
  open var alignmentRectInsets: NSEdgeInsets { NSEdgeInsets() }
  open var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
  open var safeAreaRect: NSRect { .zero }
  open var constraints: [NSLayoutConstraint] { [] }
  open var layoutGuides: [NSLayoutGuide] { [] }
  open var safeAreaLayoutGuide: NSLayoutGuide { NSLayoutGuide() }
  open var layoutMarginsGuide: NSLayoutGuide { NSLayoutGuide() }
  open var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var leftAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var rightAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
  open var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
  open var widthAnchor: NSLayoutDimension { NSLayoutDimension() }
  open var heightAnchor: NSLayoutDimension { NSLayoutDimension() }
  open var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
  open var firstBaselineAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
  open var lastBaselineAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
  open class var requiresConstraintBasedLayout: Bool { false }
  open class var defaultMenu: NSMenu? { nil }
  open class var isCompatibleWithResponsiveScrolling: Bool { false }
  public static let noIntrinsicMetric: CGFloat = -1

  open func addSubview(_ view: NSView) {}
  open func addSubview(_ view: NSView, positioned place: NSWindow.OrderingMode, relativeTo otherView: NSView?) {}
  open func replaceSubview(_ oldView: NSView, with newView: NSView) {}
  open func removeFromSuperview() {}
  open func removeFromSuperviewWithoutNeedingDisplay() {}
  open func isDescendant(of view: NSView) -> Bool { false }
  open func ancestorShared(with view: NSView) -> NSView? { nil }
  open func viewWithTag(_ tag: Int) -> NSView? { nil }
  open func sortSubviews(
    _ compare: (NSView, NSView, UnsafeMutableRawPointer?) -> ComparisonResult, context: UnsafeMutableRawPointer?) {}
  open func viewWillMove(toWindow newWindow: NSWindow?) {}
  open func viewDidMoveToWindow() {}
  open func viewWillMove(toSuperview newSuperview: NSView?) {}
  open func viewDidMoveToSuperview() {}
  open func didAddSubview(_ subview: NSView) {}
  open func willRemoveSubview(_ subview: NSView) {}
  open func viewDidHide() {}
  open func viewDidUnhide() {}
  open func viewDidChangeBackingProperties() {}
  open func viewDidChangeEffectiveAppearance() {}
  open func viewWillStartLiveResize() {}
  open func viewDidEndLiveResize() {}
  open func viewWillDraw() {}
  open func setFrameOrigin(_ newOrigin: NSPoint) {}
  open func setFrameSize(_ newSize: NSSize) {}
  open func setBoundsOrigin(_ newOrigin: NSPoint) {}
  open func setBoundsSize(_ newSize: NSSize) {}
  open func translateOrigin(to translation: NSPoint) {}
  open func scaleUnitSquare(to newUnitSize: NSSize) {}
  open func resizeSubviews(withOldSize oldSize: NSSize) {}
  open func resize(withOldSuperviewSize oldSize: NSSize) {}
  open func convert(_ point: NSPoint, from view: NSView?) -> NSPoint { point }
  open func convert(_ point: NSPoint, to view: NSView?) -> NSPoint { point }
  open func convert(_ size: NSSize, from view: NSView?) -> NSSize { size }
  open func convert(_ size: NSSize, to view: NSView?) -> NSSize { size }
  open func convert(_ rect: NSRect, from view: NSView?) -> NSRect { rect }
  open func convert(_ rect: NSRect, to view: NSView?) -> NSRect { rect }
  open func convertToBacking(_ point: NSPoint) -> NSPoint { point }
  open func convertFromBacking(_ point: NSPoint) -> NSPoint { point }
  open func convertToBacking(_ size: NSSize) -> NSSize { size }
  open func convertFromBacking(_ size: NSSize) -> NSSize { size }
  open func convertToBacking(_ rect: NSRect) -> NSRect { rect }
  open func convertFromBacking(_ rect: NSRect) -> NSRect { rect }
  open func convertToLayer(_ point: NSPoint) -> NSPoint { point }
  open func convertFromLayer(_ point: NSPoint) -> NSPoint { point }
  open func convertToLayer(_ rect: NSRect) -> NSRect { rect }
  open func convertFromLayer(_ rect: NSRect) -> NSRect { rect }
  open func backingAlignedRect(_ rect: NSRect, options: AlignmentOptions) -> NSRect { rect }
  open func centerScanRect(_ rect: NSRect) -> NSRect { rect }
  open func setNeedsDisplay(_ invalidRect: NSRect) {}
  open func display() {}
  open func displayIfNeeded() {}
  open func display(_ rect: NSRect) {}
  open func draw(_ dirtyRect: NSRect) {}
  open func needsToDraw(_ rect: NSRect) -> Bool { true }
  open func updateLayer() {}
  open func makeBackingLayer() -> CALayer { CALayer() }
  open func layout() {}
  open func layoutSubtreeIfNeeded() {}
  open func updateConstraints() {}
  open func updateConstraintsForSubtreeIfNeeded() {}
  open func invalidateIntrinsicContentSize() {}
  open func addConstraint(_ constraint: NSLayoutConstraint) {}
  open func addConstraints(_ constraints: [NSLayoutConstraint]) {}
  open func removeConstraint(_ constraint: NSLayoutConstraint) {}
  open func removeConstraints(_ constraints: [NSLayoutConstraint]) {}
  open func addLayoutGuide(_ guide: NSLayoutGuide) {}
  open func removeLayoutGuide(_ guide: NSLayoutGuide) {}
  open func contentHuggingPriority(for orientation: NSLayoutConstraint.Orientation) -> NSLayoutConstraint.Priority { .defaultLow }
  open func setContentHuggingPriority(_ priority: NSLayoutConstraint.Priority, for orientation: NSLayoutConstraint.Orientation) {}
  open func contentCompressionResistancePriority(for orientation: NSLayoutConstraint.Orientation) -> NSLayoutConstraint.Priority { .defaultHigh }
  open func setContentCompressionResistancePriority(_ priority: NSLayoutConstraint.Priority, for orientation: NSLayoutConstraint.Orientation) {}
  open func hitTest(_ point: NSPoint) -> NSView? { nil }
  open func isMousePoint(_ point: NSPoint, in rect: NSRect) -> Bool { false }
  open func acceptsFirstMouse(for event: NSEvent?) -> Bool { false }
  open func shouldDelayWindowOrdering(for event: NSEvent) -> Bool { false }
  open func menu(for event: NSEvent) -> NSMenu? { nil }
  open func addTrackingArea(_ trackingArea: NSTrackingArea) {}
  /// The owner answers to `NSViewToolTipOwner`'s method, or its description is the text.
  @discardableResult open func addToolTip(_ rect: NSRect, owner: Any, userData data: UnsafeMutableRawPointer?) -> ToolTipTag { 0 }
  open func removeToolTip(_ tag: ToolTipTag) {}
  open func removeAllToolTips() {}
  open func removeTrackingArea(_ trackingArea: NSTrackingArea) {}
  open func updateTrackingAreas() {}
  open func addCursorRect(_ rect: NSRect, cursor object: NSCursor) {}
  open func removeCursorRect(_ rect: NSRect, cursor object: NSCursor) {}
  open func discardCursorRects() {}
  open func resetCursorRects() {}
  open func addGestureRecognizer(_ gestureRecognizer: NSGestureRecognizer) {}
  open func removeGestureRecognizer(_ gestureRecognizer: NSGestureRecognizer) {}
  open func scroll(_ point: NSPoint) {}
  @discardableResult open func scrollToVisible(_ rect: NSRect) -> Bool { false }
  @discardableResult open func autoscroll(with event: NSEvent) -> Bool { false }
  open func bitmapImageRepForCachingDisplay(in rect: NSRect) -> NSBitmapImageRep? { nil }
  open func cacheDisplay(in rect: NSRect, to bitmapImageRep: NSBitmapImageRep) {}
  open func dataWithPDF(inside rect: NSRect) -> Data { Data() }
  open func registerForDraggedTypes(_ newTypes: [NSPasteboard.PasteboardType]) {}
  open func unregisterDraggedTypes() {}
  open func noteFocusRingMaskChanged() {}
  open func drawFocusRingMask() {}
  open var focusRingMaskBounds: NSRect { .zero }
  open func displayLink(target: Any, selector: Selector) -> CADisplayLink { CADisplayLink() }
  open func prepareForReuse() {}

  open func isAccessibilityElement() -> Bool { false }
  open func setAccessibilityElement(_ accessibilityElement: Bool) {}
  open func accessibilityLabel() -> String? { nil }
  open func setAccessibilityLabel(_ accessibilityLabel: String?) {}
  open func accessibilityRole() -> NSAccessibility.Role? { nil }
  open func setAccessibilityRole(_ accessibilityRole: NSAccessibility.Role?) {}
  open func setAccessibilitySubrole(_ accessibilitySubrole: NSAccessibility.Subrole?) {}
  open func setAccessibilityRoleDescription(_ accessibilityRoleDescription: String?) {}
  open func accessibilityValue() -> Any? { nil }
  open func setAccessibilityValue(_ accessibilityValue: Any?) {}
  open func setAccessibilityHelp(_ accessibilityHelp: String?) {}
  open func setAccessibilityTitle(_ accessibilityTitle: String?) {}
  open func setAccessibilityIdentifier(_ accessibilityIdentifier: String?) {}
  open func setAccessibilityHidden(_ accessibilityHidden: Bool) {}
  open func setAccessibilityChildren(_ accessibilityChildren: [Any]?) {}
  open func accessibilityPerformPress() -> Bool { false }

  public nonisolated static let frameDidChangeNotification = NSNotification.Name("NSViewFrameDidChangeNotification")
  public nonisolated static let boundsDidChangeNotification = NSNotification.Name("NSViewBoundsDidChangeNotification")
}
public enum NSFocusRingType: UInt, Sendable { case `default` = 0, none = 1, exterior = 2 }

// MARK: Auto Layout

@MainActor open class NSLayoutAnchor<AnchorType: AnyObject>: NSObject {
  open func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(greaterThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(lessThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(equalTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(greaterThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(lessThanOrEqualTo anchor: NSLayoutAnchor<AnchorType>, constant c: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
}
@MainActor open class NSLayoutXAxisAnchor: NSLayoutAnchor<NSLayoutXAxisAnchor> {
  open func anchorWithOffset(to otherAnchor: NSLayoutXAxisAnchor) -> NSLayoutDimension { NSLayoutDimension() }
}
@MainActor open class NSLayoutYAxisAnchor: NSLayoutAnchor<NSLayoutYAxisAnchor> {
  open func anchorWithOffset(to otherAnchor: NSLayoutYAxisAnchor) -> NSLayoutDimension { NSLayoutDimension() }
}
@MainActor open class NSLayoutDimension: NSLayoutAnchor<NSLayoutDimension> {
  open func constraint(equalToConstant c: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(greaterThanOrEqualToConstant c: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(lessThanOrEqualToConstant c: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(equalTo anchor: NSLayoutDimension, multiplier m: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(greaterThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(lessThanOrEqualTo anchor: NSLayoutDimension, multiplier m: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
  open func constraint(equalTo anchor: NSLayoutDimension, multiplier m: CGFloat, constant c: CGFloat) -> NSLayoutConstraint { NSLayoutConstraint() }
}
@MainActor open class NSLayoutGuide: NSObject {
  open var frame: NSRect { .zero }
  open weak var owningView: NSView?
  open var identifier = NSUserInterfaceItemIdentifier("")
  open var leadingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var trailingAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var leftAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var rightAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var topAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
  open var bottomAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
  open var widthAnchor: NSLayoutDimension { NSLayoutDimension() }
  open var heightAnchor: NSLayoutDimension { NSLayoutDimension() }
  open var centerXAnchor: NSLayoutXAxisAnchor { NSLayoutXAxisAnchor() }
  open var centerYAnchor: NSLayoutYAxisAnchor { NSLayoutYAxisAnchor() }
}
@MainActor open class NSLayoutConstraint: NSObject {
  public struct Priority: RawRepresentable, Hashable, Sendable {
    public let rawValue: Float
    public init(rawValue: Float) { self.rawValue = rawValue }
    public init(_ rawValue: Float) { self.rawValue = rawValue }
    public static let required = Priority(1000)
    public static let defaultHigh = Priority(750)
    public static let dragThatCanResizeWindow = Priority(510)
    public static let windowSizeStayPut = Priority(500)
    public static let dragThatCannotResizeWindow = Priority(490)
    public static let defaultLow = Priority(250)
    public static let fittingSizeCompression = Priority(50)
  }
  public enum Orientation: Int, Sendable { case horizontal = 0, vertical = 1 }
  public enum Relation: Int, Sendable { case lessThanOrEqual = -1, equal = 0, greaterThanOrEqual = 1 }
  public enum Attribute: Int, Sendable {
    case left = 1, right, top, bottom, leading, trailing, width, height, centerX, centerY, lastBaseline, firstBaseline, notAnAttribute = 0
  }
  public struct FormatOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let alignAllLeading = FormatOptions(rawValue: 1 << 5)
    public static let alignAllCenterY = FormatOptions(rawValue: 1 << 10)
  }
  public convenience init(
    item view1: Any, attribute attr1: Attribute, relatedBy relation: Relation, toItem view2: Any?, attribute attr2: Attribute,
    multiplier: CGFloat, constant c: CGFloat
  ) { self.init() }
  open class func activate(_ constraints: [NSLayoutConstraint]) {}
  open class func deactivate(_ constraints: [NSLayoutConstraint]) {}
  open class func constraints(
    withVisualFormat format: String, options opts: FormatOptions = [], metrics: [String: NSNumber]?, views: [String: Any]
  ) -> [NSLayoutConstraint] { [] }
  open var priority: Priority = .required
  open var constant: CGFloat = 0
  open var multiplier: CGFloat { 1 }
  open var isActive = false
  open var identifier: String?
  open var shouldBeArchived = false
}
