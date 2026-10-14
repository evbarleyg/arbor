// A stand-in for SwiftUI: paths and shapes. See SwiftUI.swift.

public enum RoundedCornerStyle: Hashable, Sendable { case circular, continuous }
public struct FillStyle: Equatable, Sendable {
  public var isEOFilled: Bool
  public var isAntialiased: Bool
  public init(eoFill: Bool = false, antialiased: Bool = true) {
    isEOFilled = eoFill
    isAntialiased = antialiased
  }
}
public struct StrokeStyle: Equatable, Animatable, Sendable {
  public var lineWidth: CGFloat
  public var lineCap: CGLineCap
  public var lineJoin: CGLineJoin
  public var miterLimit: CGFloat
  public var dash: [CGFloat]
  public var dashPhase: CGFloat
  public init(
    lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: CGFloat = 10, dash: [CGFloat] = [CGFloat](),
    dashPhase: CGFloat = 0
  ) {
    self.lineWidth = lineWidth
    self.lineCap = lineCap
    self.lineJoin = lineJoin
    self.miterLimit = miterLimit
    self.dash = dash
    self.dashPhase = dashPhase
  }
  public var animatableData: AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>> {
    get { fatalError() }
    set {}
  }
}
public struct RectangleCornerRadii: Equatable, Animatable, Sendable {
  public var topLeading: CGFloat
  public var bottomLeading: CGFloat
  public var bottomTrailing: CGFloat
  public var topTrailing: CGFloat
  public init(topLeading: CGFloat = 0, bottomLeading: CGFloat = 0, bottomTrailing: CGFloat = 0, topTrailing: CGFloat = 0) {
    self.topLeading = topLeading
    self.bottomLeading = bottomLeading
    self.bottomTrailing = bottomTrailing
    self.topTrailing = topTrailing
  }
  public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
    get { fatalError() }
    set {}
  }
}

// MARK: Path

public struct Path: Equatable, LosslessStringConvertible, Sendable {
  public enum Element: Equatable, Sendable {
    case move(to: CGPoint)
    case line(to: CGPoint)
    case quadCurve(to: CGPoint, control: CGPoint)
    case curve(to: CGPoint, control1: CGPoint, control2: CGPoint)
    case closeSubpath
  }
  public init() {}
  public init(_ path: CGPath) {}
  public init(_ path: CGMutablePath) {}
  public init(_ rect: CGRect) {}
  public init(roundedRect rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous) {}
  public init(roundedRect rect: CGRect, cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) {}
  public init(roundedRect rect: CGRect, cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) {}
  public init(ellipseIn rect: CGRect) {}
  public init(_ callback: (inout Path) -> Void) {}
  public init?(_ string: String) {}
  public var description: String { "" }
  public var cgPath: CGPath { CGMutablePath() }
  public var isEmpty: Bool { true }
  public var boundingRect: CGRect { .zero }
  public var currentPoint: CGPoint? { nil }
  public func contains(_ p: CGPoint, eoFill: Bool = false) -> Bool { false }
  public func forEach(_ body: (Element) -> Void) {}
  public func strokedPath(_ style: StrokeStyle) -> Path { self }
  public func trimmedPath(from: CGFloat, to: CGFloat) -> Path { self }
  public func applying(_ transform: CGAffineTransform) -> Path { self }
  public func offsetBy(dx: CGFloat, dy: CGFloat) -> Path { self }
  public func normalized(eoFill: Bool = true) -> Path { self }
  public func intersection(_ other: Path, eoFill: Bool = false) -> Path { self }
  public func union(_ other: Path, eoFill: Bool = false) -> Path { self }
  public func subtracting(_ other: Path, eoFill: Bool = false) -> Path { self }
  public func symmetricDifference(_ other: Path, eoFill: Bool = false) -> Path { self }
  public func lineIntersection(_ other: Path, eoFill: Bool = false) -> Path { self }
  public func lineSubtraction(_ other: Path, eoFill: Bool = false) -> Path { self }

  public mutating func move(to end: CGPoint) {}
  public mutating func addLine(to end: CGPoint) {}
  public mutating func addQuadCurve(to end: CGPoint, control: CGPoint) {}
  public mutating func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {}
  public mutating func closeSubpath() {}
  public mutating func addRect(_ rect: CGRect, transform: CGAffineTransform = .identity) {}
  public mutating func addRoundedRect(
    in rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous, transform: CGAffineTransform = .identity) {}
  public mutating func addRoundedRect(
    in rect: CGRect, cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous, transform: CGAffineTransform = .identity) {}
  public mutating func addEllipse(in rect: CGRect, transform: CGAffineTransform = .identity) {}
  public mutating func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) {}
  public mutating func addLines(_ lines: [CGPoint]) {}
  public mutating func addRelativeArc(
    center: CGPoint, radius: CGFloat, startAngle: Angle, delta: Angle, transform: CGAffineTransform = .identity) {}
  public mutating func addArc(
    center: CGPoint, radius: CGFloat, startAngle: Angle, endAngle: Angle, clockwise: Bool, transform: CGAffineTransform = .identity) {}
  public mutating func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat, transform: CGAffineTransform = .identity) {}
  public mutating func addPath(_ path: Path, transform: CGAffineTransform = .identity) {}
}
extension Path: Shape {
  public nonisolated func path(in rect: CGRect) -> Path { self }
  public typealias AnimatableData = EmptyAnimatableData
}

// MARK: Shape

public enum ShapeRole: Hashable, Sendable { case fill, stroke, separator }

/// A view, and yet not on the main actor: a shape's path may be asked for on any thread.
nonisolated public protocol Shape: Sendable, Animatable, View {
  nonisolated func path(in rect: CGRect) -> Path
  nonisolated static var role: ShapeRole { get }
  nonisolated var layoutDirectionBehavior: LayoutDirectionBehavior { get }
  nonisolated func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize
}
extension Shape {
  public static var role: ShapeRole { .fill }
  public var layoutDirectionBehavior: LayoutDirectionBehavior { .fixed }
  public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { .zero }
  public var body: _ShapeView<Self, ForegroundStyle> { fatalError() }
}
public protocol InsettableShape: Shape {
  associatedtype InsetShape: InsettableShape
  nonisolated func inset(by amount: CGFloat) -> InsetShape
}

public protocol ShapeView<Content>: View {
  associatedtype Content: Shape
  var shape: Content { get }
}
public struct _ShapeView<Content: Shape, Style: ShapeStyle>: _PrimitiveView, ShapeView {
  public var shape: Content
  public var style: Style
  public var fillStyle: FillStyle
  public nonisolated init(shape: Content, style: Style, fillStyle: FillStyle = FillStyle()) {
    self.shape = shape
    self.style = style
    self.fillStyle = fillStyle
  }
}
public struct FillShapeView<Content: Shape, Style: ShapeStyle, Background: View>: _PrimitiveView, ShapeView {
  public var shape: Content
  public var style: Style
  public var fillStyle: FillStyle
  public var background: Background
  public init(shape: Content, style: Style, fillStyle: FillStyle, background: Background) {
    self.shape = shape
    self.style = style
    self.fillStyle = fillStyle
    self.background = background
  }
}
public struct StrokeShapeView<Content: Shape, Style: ShapeStyle, Background: View>: _PrimitiveView, ShapeView {
  public var shape: Content
  public var style: Style
  public var strokeStyle: StrokeStyle
  public var isAntialiased: Bool
  public var background: Background
  public init(shape: Content, style: Style, strokeStyle: StrokeStyle, isAntialiased: Bool, background: Background) {
    self.shape = shape
    self.style = style
    self.strokeStyle = strokeStyle
    self.isAntialiased = isAntialiased
    self.background = background
  }
}
public struct StrokeBorderShapeView<Content: InsettableShape, Style: ShapeStyle, Background: View>: _PrimitiveView, ShapeView {
  public var shape: Content
  public var style: Style
  public var strokeStyle: StrokeStyle
  public var isAntialiased: Bool
  public var background: Background
  public init(shape: Content, style: Style, strokeStyle: StrokeStyle, isAntialiased: Bool, background: Background) {
    self.shape = shape
    self.style = style
    self.strokeStyle = strokeStyle
    self.isAntialiased = isAntialiased
    self.background = background
  }
}

extension Shape {
  public func fill<S: ShapeStyle>(_ content: S = .foreground, style: FillStyle = FillStyle()) -> _ShapeView<Self, S> { fatalError() }
  public func stroke<S: ShapeStyle>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> StrokeShapeView<Self, S, EmptyView> {
    fatalError()
  }
  public func stroke<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeShapeView<Self, S, EmptyView> {
    fatalError()
  }
  public func stroke(style: StrokeStyle) -> some Shape { self }
  public func stroke(lineWidth: CGFloat = 1) -> some Shape { self }
  public func trim(from startFraction: CGFloat = 0, to endFraction: CGFloat = 1) -> some Shape { self }
  public func offset(_ offset: CGSize) -> OffsetShape<Self> { OffsetShape(shape: self, offset: offset) }
  public func offset(_ offset: CGPoint) -> OffsetShape<Self> { OffsetShape(shape: self, offset: .zero) }
  public func offset(x: CGFloat = 0, y: CGFloat = 0) -> OffsetShape<Self> { OffsetShape(shape: self, offset: .zero) }
  public func scale(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> ScaledShape<Self> {
    ScaledShape(shape: self, scale: .zero, anchor: anchor)
  }
  public func scale(_ scale: CGFloat, anchor: UnitPoint = .center) -> ScaledShape<Self> { ScaledShape(shape: self, scale: .zero, anchor: anchor) }
  public func rotation(_ angle: Angle, anchor: UnitPoint = .center) -> RotatedShape<Self> {
    RotatedShape(shape: self, angle: angle, anchor: anchor)
  }
  public func transform(_ transform: CGAffineTransform) -> TransformedShape<Self> { TransformedShape(shape: self, transform: transform) }
  public func size(_ size: CGSize) -> some Shape { self }
  public func size(width: CGFloat, height: CGFloat) -> some Shape { self }
  public func intersection<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
  public func union<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
  public func subtracting<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
  public func symmetricDifference<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
  public func lineIntersection<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
  public func lineSubtraction<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
}
extension InsettableShape {
  public func strokeBorder<S: ShapeStyle>(
    _ content: S = .foreground, style: StrokeStyle, antialiased: Bool = true
  ) -> StrokeBorderShapeView<Self, S, EmptyView> { fatalError() }
  public func strokeBorder<S: ShapeStyle>(
    _ content: S = .foreground, lineWidth: CGFloat = 1, antialiased: Bool = true
  ) -> StrokeBorderShapeView<Self, S, EmptyView> { fatalError() }
}
nonisolated extension ShapeView {
  public func fill<S: ShapeStyle>(_ content: S = .foreground, style: FillStyle = FillStyle()) -> FillShapeView<Content, S, Self> { fatalError() }
  public func stroke<S: ShapeStyle>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> StrokeShapeView<Content, S, Self> {
    fatalError()
  }
  public func stroke<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeShapeView<Content, S, Self> {
    fatalError()
  }
}
nonisolated extension ShapeView where Content: InsettableShape {
  public func strokeBorder<S: ShapeStyle>(
    _ content: S = .foreground, style: StrokeStyle, antialiased: Bool = true
  ) -> StrokeBorderShapeView<Content, S, Self> { fatalError() }
  public func strokeBorder<S: ShapeStyle>(
    _ content: S = .foreground, lineWidth: CGFloat = 1, antialiased: Bool = true
  ) -> StrokeBorderShapeView<Content, S, Self> { fatalError() }
}

// MARK: The shapes

public struct Rectangle: InsettableShape {
  public init() {}
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public nonisolated func inset(by amount: CGFloat) -> some InsettableShape { self }
}
public struct RoundedRectangle: InsettableShape {
  public var cornerSize: CGSize
  public var style: RoundedCornerStyle
  public init(cornerSize: CGSize, style: RoundedCornerStyle = .continuous) {
    self.cornerSize = cornerSize
    self.style = style
  }
  public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) {
    cornerSize = CGSize(width: cornerRadius, height: cornerRadius)
    self.style = style
  }
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public nonisolated func inset(by amount: CGFloat) -> some InsettableShape { self }
  public var animatableData: CGSize.AnimatableData {
    get { cornerSize.animatableData }
    set {}
  }
}
public struct UnevenRoundedRectangle: InsettableShape {
  public var cornerRadii: RectangleCornerRadii
  public var style: RoundedCornerStyle
  public init(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) {
    self.cornerRadii = cornerRadii
    self.style = style
  }
  public init(
    topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0,
    style: RoundedCornerStyle = .continuous
  ) {
    cornerRadii = RectangleCornerRadii()
    self.style = style
  }
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public nonisolated func inset(by amount: CGFloat) -> some InsettableShape { self }
  public var animatableData: RectangleCornerRadii.AnimatableData {
    get { cornerRadii.animatableData }
    set {}
  }
}
public struct Circle: InsettableShape {
  public init() {}
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public nonisolated func inset(by amount: CGFloat) -> some InsettableShape { self }
}
public struct Ellipse: InsettableShape {
  public init() {}
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public nonisolated func inset(by amount: CGFloat) -> some InsettableShape { self }
}
public struct Capsule: InsettableShape {
  public var style: RoundedCornerStyle
  public init(style: RoundedCornerStyle = .continuous) { self.style = style }
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public nonisolated func inset(by amount: CGFloat) -> some InsettableShape { self }
}
public struct ContainerRelativeShape: InsettableShape {
  public init() {}
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public nonisolated func inset(by amount: CGFloat) -> some InsettableShape { self }
}
public struct AnyShape: Shape {
  public init<S: Shape>(_ shape: S) {}
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
}
public struct OffsetShape<Content: Shape>: Shape {
  public var shape: Content
  public var offset: CGSize
  public init(shape: Content, offset: CGSize) {
    self.shape = shape
    self.offset = offset
  }
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public var animatableData: AnimatablePair<Content.AnimatableData, CGSize.AnimatableData> {
    get { fatalError() }
    set {}
  }
}
extension OffsetShape: InsettableShape where Content: InsettableShape {
  public nonisolated func inset(by amount: CGFloat) -> OffsetShape<Content.InsetShape> { fatalError() }
}
public struct ScaledShape<Content: Shape>: Shape {
  public var shape: Content
  public var scale: CGSize
  public var anchor: UnitPoint
  public init(shape: Content, scale: CGSize, anchor: UnitPoint = .center) {
    self.shape = shape
    self.scale = scale
    self.anchor = anchor
  }
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public var animatableData: AnimatablePair<Content.AnimatableData, AnimatablePair<CGSize.AnimatableData, UnitPoint.AnimatableData>> {
    get { fatalError() }
    set {}
  }
}
public struct RotatedShape<Content: Shape>: Shape {
  public var shape: Content
  public var angle: Angle
  public var anchor: UnitPoint
  public init(shape: Content, angle: Angle, anchor: UnitPoint = .center) {
    self.shape = shape
    self.angle = angle
    self.anchor = anchor
  }
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public var animatableData: AnimatablePair<Content.AnimatableData, AnimatablePair<Angle.AnimatableData, UnitPoint.AnimatableData>> {
    get { fatalError() }
    set {}
  }
}
extension RotatedShape: InsettableShape where Content: InsettableShape {
  public nonisolated func inset(by amount: CGFloat) -> RotatedShape<Content.InsetShape> { fatalError() }
}
public struct TransformedShape<Content: Shape>: Shape {
  public var shape: Content
  public var transform: CGAffineTransform
  public init(shape: Content, transform: CGAffineTransform) {
    self.shape = shape
    self.transform = transform
  }
  public nonisolated func path(in rect: CGRect) -> Path { Path() }
  public var animatableData: Content.AnimatableData {
    get { shape.animatableData }
    set {}
  }
}

extension Shape where Self == Rectangle {
  public static var rect: Rectangle { Rectangle() }
}
extension Shape where Self == RoundedRectangle {
  public static func rect(cornerSize: CGSize, style: RoundedCornerStyle = .continuous) -> RoundedRectangle {
    RoundedRectangle(cornerSize: cornerSize, style: style)
  }
  public static func rect(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) -> RoundedRectangle {
    RoundedRectangle(cornerRadius: cornerRadius, style: style)
  }
}
extension Shape where Self == UnevenRoundedRectangle {
  public static func rect(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) -> UnevenRoundedRectangle {
    UnevenRoundedRectangle(cornerRadii: cornerRadii, style: style)
  }
  public static func rect(
    topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0,
    style: RoundedCornerStyle = .continuous
  ) -> UnevenRoundedRectangle { UnevenRoundedRectangle(style: style) }
}
extension Shape where Self == Circle {
  public static var circle: Circle { Circle() }
}
extension Shape where Self == Ellipse {
  public static var ellipse: Ellipse { Ellipse() }
}
extension Shape where Self == Capsule {
  public static var capsule: Capsule { Capsule() }
  public static func capsule(style: RoundedCornerStyle) -> Capsule { Capsule(style: style) }
}
extension Shape where Self == ContainerRelativeShape {
  public static var containerRelative: ContainerRelativeShape { ContainerRelativeShape() }
}
