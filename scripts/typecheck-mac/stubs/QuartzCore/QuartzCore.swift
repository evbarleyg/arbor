// A stand-in for QuartzCore (Core Animation) (scripts/typecheck-mac/README.md). Never shipped, never run. Signatures as in the macOS 14 SDK.
// Core Animation's classes belong to no actor and are not Sendable.
@_exported import CoreGraphics

public func CACurrentMediaTime() -> CFTimeInterval { 0 }

public struct CATransform3D: Sendable {
  public var m11: CGFloat = 1, m12: CGFloat = 0, m13: CGFloat = 0, m14: CGFloat = 0
  public var m21: CGFloat = 0, m22: CGFloat = 1, m23: CGFloat = 0, m24: CGFloat = 0
  public var m31: CGFloat = 0, m32: CGFloat = 0, m33: CGFloat = 1, m34: CGFloat = 0
  public var m41: CGFloat = 0, m42: CGFloat = 0, m43: CGFloat = 0, m44: CGFloat = 1
  public init() {}
}
public let CATransform3DIdentity = CATransform3D()
public func CATransform3DMakeTranslation(_ tx: CGFloat, _ ty: CGFloat, _ tz: CGFloat) -> CATransform3D { CATransform3D() }
public func CATransform3DMakeScale(_ sx: CGFloat, _ sy: CGFloat, _ sz: CGFloat) -> CATransform3D { CATransform3D() }
public func CATransform3DMakeRotation(_ angle: CGFloat, _ x: CGFloat, _ y: CGFloat, _ z: CGFloat) -> CATransform3D { CATransform3D() }
public func CATransform3DTranslate(_ t: CATransform3D, _ tx: CGFloat, _ ty: CGFloat, _ tz: CGFloat) -> CATransform3D { t }
public func CATransform3DScale(_ t: CATransform3D, _ sx: CGFloat, _ sy: CGFloat, _ sz: CGFloat) -> CATransform3D { t }
public func CATransform3DConcat(_ a: CATransform3D, _ b: CATransform3D) -> CATransform3D { a }
public func CATransform3DMakeAffineTransform(_ m: CGAffineTransform) -> CATransform3D { CATransform3D() }
public func CATransform3DIsIdentity(_ t: CATransform3D) -> Bool { true }

public struct CAMediaTimingFunctionName: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let linear = CAMediaTimingFunctionName(rawValue: "linear")
  public static let easeIn = CAMediaTimingFunctionName(rawValue: "easeIn")
  public static let easeOut = CAMediaTimingFunctionName(rawValue: "easeOut")
  public static let easeInEaseOut = CAMediaTimingFunctionName(rawValue: "easeInEaseOut")
  public static let `default` = CAMediaTimingFunctionName(rawValue: "default")
}
open class CAMediaTimingFunction: NSObject {
  public convenience init(name: CAMediaTimingFunctionName) { self.init() }
  public convenience init(controlPoints c1x: Float, _ c1y: Float, _ c2x: Float, _ c2y: Float) { self.init() }
  open func getControlPoint(at idx: Int, values ptr: UnsafeMutablePointer<Float>) {}
}
public struct CAMediaTimingFillMode: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let forwards = CAMediaTimingFillMode(rawValue: "forwards")
  public static let backwards = CAMediaTimingFillMode(rawValue: "backwards")
  public static let both = CAMediaTimingFillMode(rawValue: "both")
  public static let removed = CAMediaTimingFillMode(rawValue: "removed")
}
public protocol CAMediaTiming {
  var beginTime: CFTimeInterval { get set }
  var duration: CFTimeInterval { get set }
  var speed: Float { get set }
  var timeOffset: CFTimeInterval { get set }
  var repeatCount: Float { get set }
  var repeatDuration: CFTimeInterval { get set }
  var autoreverses: Bool { get set }
  var fillMode: CAMediaTimingFillMode { get set }
}
public protocol CAAction {
  func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable: Any]?)
}
extension NSNull: CAAction {
  public func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable: Any]?) {}
}
public protocol CAAnimationDelegate: NSObjectProtocol {
  func animationDidStart(_ anim: CAAnimation)
  func animationDidStop(_ anim: CAAnimation, finished flag: Bool)
}
extension CAAnimationDelegate {
  public func animationDidStart(_ anim: CAAnimation) {}
  public func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {}
}
open class CAAnimation: NSObject, CAMediaTiming, CAAction {
  open var beginTime: CFTimeInterval = 0
  open var duration: CFTimeInterval = 0
  open var speed: Float = 1
  open var timeOffset: CFTimeInterval = 0
  open var repeatCount: Float = 0
  open var repeatDuration: CFTimeInterval = 0
  open var autoreverses = false
  open var fillMode: CAMediaTimingFillMode = .removed
  open var timingFunction: CAMediaTimingFunction?
  open var delegate: (any CAAnimationDelegate)?
  open var isRemovedOnCompletion = true
  open var preferredFrameRateRange = CAFrameRateRange()
  open func run(forKey event: String, object anObject: Any, arguments dict: [AnyHashable: Any]?) {}
  open func setValue(_ value: Any?, forKey key: String) {}
  open func value(forKey key: String) -> Any? { nil }
}
public struct CAFrameRateRange: Sendable, Equatable {
  public var minimum: Float = 0
  public var maximum: Float = 0
  public var preferred: Float = 0
  public static let `default` = CAFrameRateRange()
  public init() {}
  public init(minimum: Float, maximum: Float, preferred: Float? = nil) {}
}
open class CAPropertyAnimation: CAAnimation {
  public convenience init(keyPath path: String?) { self.init() }
  open var keyPath: String?
  open var isAdditive = false
  open var isCumulative = false
}
open class CABasicAnimation: CAPropertyAnimation {
  open var fromValue: Any?
  open var toValue: Any?
  open var byValue: Any?
}
open class CASpringAnimation: CABasicAnimation {
  open var mass: CGFloat = 1
  open var stiffness: CGFloat = 100
  open var damping: CGFloat = 10
  open var initialVelocity: CGFloat = 0
  open var settlingDuration: CFTimeInterval { 0 }
  public convenience init(perceptualDuration: CFTimeInterval, bounce: CGFloat) { self.init() }
}
public struct CAAnimationCalculationMode: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let linear = CAAnimationCalculationMode(rawValue: "linear")
  public static let discrete = CAAnimationCalculationMode(rawValue: "discrete")
  public static let paced = CAAnimationCalculationMode(rawValue: "paced")
  public static let cubic = CAAnimationCalculationMode(rawValue: "cubic")
}
open class CAKeyframeAnimation: CAPropertyAnimation {
  open var values: [Any]?
  open var path: CGPath?
  open var keyTimes: [NSNumber]?
  open var timingFunctions: [CAMediaTimingFunction]?
  open var calculationMode: CAAnimationCalculationMode = .linear
}
open class CAAnimationGroup: CAAnimation {
  open var animations: [CAAnimation]?
}
public struct CATransitionType: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let fade = CATransitionType(rawValue: "fade")
  public static let moveIn = CATransitionType(rawValue: "moveIn")
  public static let push = CATransitionType(rawValue: "push")
  public static let reveal = CATransitionType(rawValue: "reveal")
}
open class CATransition: CAAnimation {
  open var type: CATransitionType = .fade
}

open class CATransaction: NSObject {
  open class func begin() {}
  open class func commit() {}
  open class func flush() {}
  open class func lock() {}
  open class func unlock() {}
  open class func animationDuration() -> CFTimeInterval { 0 }
  open class func setAnimationDuration(_ dur: CFTimeInterval) {}
  open class func animationTimingFunction() -> CAMediaTimingFunction? { nil }
  open class func setAnimationTimingFunction(_ function: CAMediaTimingFunction?) {}
  open class func disableActions() -> Bool { false }
  open class func setDisableActions(_ flag: Bool) {}
  open class func completionBlock() -> (() -> Void)? { nil }
  open class func setCompletionBlock(_ block: (() -> Void)?) {}
}

public struct CALayerContentsGravity: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let center = CALayerContentsGravity(rawValue: "center")
  public static let top = CALayerContentsGravity(rawValue: "top")
  public static let bottom = CALayerContentsGravity(rawValue: "bottom")
  public static let left = CALayerContentsGravity(rawValue: "left")
  public static let right = CALayerContentsGravity(rawValue: "right")
  public static let topLeft = CALayerContentsGravity(rawValue: "topLeft")
  public static let topRight = CALayerContentsGravity(rawValue: "topRight")
  public static let bottomLeft = CALayerContentsGravity(rawValue: "bottomLeft")
  public static let bottomRight = CALayerContentsGravity(rawValue: "bottomRight")
  public static let resize = CALayerContentsGravity(rawValue: "resize")
  public static let resizeAspect = CALayerContentsGravity(rawValue: "resizeAspect")
  public static let resizeAspectFill = CALayerContentsGravity(rawValue: "resizeAspectFill")
}
public struct CALayerContentsFilter: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let linear = CALayerContentsFilter(rawValue: "linear")
  public static let nearest = CALayerContentsFilter(rawValue: "nearest")
  public static let trilinear = CALayerContentsFilter(rawValue: "trilinear")
}
public struct CALayerCornerCurve: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let circular = CALayerCornerCurve(rawValue: "circular")
  public static let continuous = CALayerCornerCurve(rawValue: "continuous")
}
public struct CACornerMask: OptionSet, Sendable {
  public let rawValue: UInt
  public init(rawValue: UInt) { self.rawValue = rawValue }
  public static let layerMinXMinYCorner = CACornerMask(rawValue: 1)
  public static let layerMaxXMinYCorner = CACornerMask(rawValue: 2)
  public static let layerMinXMaxYCorner = CACornerMask(rawValue: 4)
  public static let layerMaxXMaxYCorner = CACornerMask(rawValue: 8)
}
public struct CAAutoresizingMask: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let layerMinXMargin = CAAutoresizingMask(rawValue: 1)
  public static let layerWidthSizable = CAAutoresizingMask(rawValue: 2)
  public static let layerMaxXMargin = CAAutoresizingMask(rawValue: 4)
  public static let layerMinYMargin = CAAutoresizingMask(rawValue: 8)
  public static let layerHeightSizable = CAAutoresizingMask(rawValue: 16)
  public static let layerMaxYMargin = CAAutoresizingMask(rawValue: 32)
}
public protocol CALayerDelegate: NSObjectProtocol {
  func display(_ layer: CALayer)
  func draw(_ layer: CALayer, in ctx: CGContext)
  func layerWillDraw(_ layer: CALayer)
  func layoutSublayers(of layer: CALayer)
  func action(for layer: CALayer, forKey event: String) -> (any CAAction)?
}
extension CALayerDelegate {
  public func display(_ layer: CALayer) {}
  public func draw(_ layer: CALayer, in ctx: CGContext) {}
  public func layerWillDraw(_ layer: CALayer) {}
  public func layoutSublayers(of layer: CALayer) {}
  public func action(for layer: CALayer, forKey event: String) -> (any CAAction)? { nil }
}
open class CALayer: NSObject, CAMediaTiming {
  public override init() {}
  public init(layer: Any) {}
  public required init?(coder: NSCoder) {}
  open func presentation() -> Self? { nil }
  open func model() -> Self { self }
  open var bounds = CGRect.zero
  open var position = CGPoint.zero
  open var zPosition: CGFloat = 0
  open var anchorPoint = CGPoint.zero
  open var anchorPointZ: CGFloat = 0
  open var transform = CATransform3D()
  open func affineTransform() -> CGAffineTransform { .identity }
  open func setAffineTransform(_ m: CGAffineTransform) {}
  open var frame = CGRect.zero
  open var isHidden = false
  open var isDoubleSided = true
  open var isGeometryFlipped = false
  open var superlayer: CALayer? { nil }
  open func removeFromSuperlayer() {}
  open var sublayers: [CALayer]?
  open func addSublayer(_ layer: CALayer) {}
  open func insertSublayer(_ layer: CALayer, at idx: UInt32) {}
  open func insertSublayer(_ layer: CALayer, below sibling: CALayer?) {}
  open func insertSublayer(_ layer: CALayer, above sibling: CALayer?) {}
  open func replaceSublayer(_ oldLayer: CALayer, with newLayer: CALayer) {}
  open var sublayerTransform = CATransform3D()
  open var mask: CALayer?
  open var masksToBounds = false
  open func convert(_ p: CGPoint, from l: CALayer?) -> CGPoint { p }
  open func convert(_ p: CGPoint, to l: CALayer?) -> CGPoint { p }
  open func convert(_ r: CGRect, from l: CALayer?) -> CGRect { r }
  open func convert(_ r: CGRect, to l: CALayer?) -> CGRect { r }
  open func hitTest(_ p: CGPoint) -> CALayer? { nil }
  open func contains(_ p: CGPoint) -> Bool { false }
  open var contents: Any?
  open var contentsRect = CGRect.zero
  open var contentsGravity: CALayerContentsGravity = .resize
  open var contentsScale: CGFloat = 1
  open var contentsCenter = CGRect.zero
  open var minificationFilter: CALayerContentsFilter = .linear
  open var magnificationFilter: CALayerContentsFilter = .linear
  open var isOpaque = false
  open func display() {}
  open func setNeedsDisplay() {}
  open func setNeedsDisplay(_ r: CGRect) {}
  open func needsDisplay() -> Bool { false }
  open func displayIfNeeded() {}
  open var needsDisplayOnBoundsChange = false
  open var drawsAsynchronously = false
  open func draw(in ctx: CGContext) {}
  open func render(in ctx: CGContext) {}
  open var allowsEdgeAntialiasing = false
  open var backgroundColor: CGColor?
  open var cornerRadius: CGFloat = 0
  open var maskedCorners: CACornerMask = []
  open var cornerCurve: CALayerCornerCurve = .circular
  open class func cornerCurveExpansionFactor(_ curve: CALayerCornerCurve) -> CGFloat { 1 }
  open var borderWidth: CGFloat = 0
  open var borderColor: CGColor?
  open var opacity: Float = 1
  open var allowsGroupOpacity = true
  open var compositingFilter: Any?
  open var filters: [Any]?
  open var backgroundFilters: [Any]?
  open var shouldRasterize = false
  open var rasterizationScale: CGFloat = 1
  open var shadowColor: CGColor?
  open var shadowOpacity: Float = 0
  open var shadowOffset = CGSize.zero
  open var shadowRadius: CGFloat = 3
  open var shadowPath: CGPath?
  open var autoresizingMask: CAAutoresizingMask = []
  open func preferredFrameSize() -> CGSize { .zero }
  open func setNeedsLayout() {}
  open func needsLayout() -> Bool { false }
  open func layoutIfNeeded() {}
  open func layoutSublayers() {}
  open class func defaultAction(forKey event: String) -> (any CAAction)? { nil }
  open func action(forKey event: String) -> (any CAAction)? { nil }
  open var actions: [String: any CAAction]?
  open func add(_ anim: CAAnimation, forKey key: String?) {}
  open func removeAllAnimations() {}
  open func removeAnimation(forKey key: String) {}
  open func animationKeys() -> [String]? { nil }
  open func animation(forKey key: String) -> CAAnimation? { nil }
  open var name: String?
  open weak var delegate: (any CALayerDelegate)?
  open var style: [AnyHashable: Any]?
  open func setValue(_ value: Any?, forKey key: String) {}
  open func setValue(_ value: Any?, forKeyPath keyPath: String) {}
  open func value(forKey key: String) -> Any? { nil }
  open func value(forKeyPath keyPath: String) -> Any? { nil }
  open var beginTime: CFTimeInterval = 0
  open var duration: CFTimeInterval = 0
  open var speed: Float = 1
  open var timeOffset: CFTimeInterval = 0
  open var repeatCount: Float = 0
  open var repeatDuration: CFTimeInterval = 0
  open var autoreverses = false
  open var fillMode: CAMediaTimingFillMode = .removed
}
public struct CAShapeLayerFillRule: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let nonZero = CAShapeLayerFillRule(rawValue: "non-zero")
  public static let evenOdd = CAShapeLayerFillRule(rawValue: "even-odd")
}
public struct CAShapeLayerLineCap: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let butt = CAShapeLayerLineCap(rawValue: "butt")
  public static let round = CAShapeLayerLineCap(rawValue: "round")
  public static let square = CAShapeLayerLineCap(rawValue: "square")
}
public struct CAShapeLayerLineJoin: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let miter = CAShapeLayerLineJoin(rawValue: "miter")
  public static let round = CAShapeLayerLineJoin(rawValue: "round")
  public static let bevel = CAShapeLayerLineJoin(rawValue: "bevel")
}
open class CAShapeLayer: CALayer {
  open var path: CGPath?
  open var fillColor: CGColor?
  open var fillRule: CAShapeLayerFillRule = .nonZero
  open var strokeColor: CGColor?
  open var strokeStart: CGFloat = 0
  open var strokeEnd: CGFloat = 1
  open var lineWidth: CGFloat = 1
  open var miterLimit: CGFloat = 10
  open var lineCap: CAShapeLayerLineCap = .butt
  open var lineJoin: CAShapeLayerLineJoin = .miter
  open var lineDashPhase: CGFloat = 0
  open var lineDashPattern: [NSNumber]?
}
public struct CAGradientLayerType: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let axial = CAGradientLayerType(rawValue: "axial")
  public static let radial = CAGradientLayerType(rawValue: "radial")
  public static let conic = CAGradientLayerType(rawValue: "conic")
}
open class CAGradientLayer: CALayer {
  open var colors: [Any]?
  open var locations: [NSNumber]?
  open var startPoint = CGPoint.zero
  open var endPoint = CGPoint.zero
  open var type: CAGradientLayerType = .axial
}
public struct CATextLayerTruncationMode: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let none = CATextLayerTruncationMode(rawValue: "none")
  public static let start = CATextLayerTruncationMode(rawValue: "start")
  public static let end = CATextLayerTruncationMode(rawValue: "end")
  public static let middle = CATextLayerTruncationMode(rawValue: "middle")
}
public struct CATextLayerAlignmentMode: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let natural = CATextLayerAlignmentMode(rawValue: "natural")
  public static let left = CATextLayerAlignmentMode(rawValue: "left")
  public static let right = CATextLayerAlignmentMode(rawValue: "right")
  public static let center = CATextLayerAlignmentMode(rawValue: "center")
  public static let justified = CATextLayerAlignmentMode(rawValue: "justified")
}
open class CATextLayer: CALayer {
  open var string: Any?
  open var font: CFTypeRef?
  open var fontSize: CGFloat = 36
  open var foregroundColor: CGColor?
  open var isWrapped = false
  open var truncationMode: CATextLayerTruncationMode = .none
  open var alignmentMode: CATextLayerAlignmentMode = .natural
  open var allowsFontSubpixelQuantization = false
}
open class CATransformLayer: CALayer {}
open class CAReplicatorLayer: CALayer {
  open var instanceCount = 1
  open var instanceDelay: CFTimeInterval = 0
  open var instanceTransform = CATransform3D()
}
open class CADisplayLink: NSObject {
  open func add(to runloop: RunLoop, forMode mode: RunLoop.Mode) {}
  open func remove(from runloop: RunLoop, forMode mode: RunLoop.Mode) {}
  open func invalidate() {}
  open var timestamp: CFTimeInterval { 0 }
  open var duration: CFTimeInterval { 0 }
  open var targetTimestamp: CFTimeInterval { 0 }
  open var isPaused = false
  open var preferredFrameRateRange = CAFrameRateRange()
}
