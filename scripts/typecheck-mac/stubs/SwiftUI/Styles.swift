// A stand-in for SwiftUI: shape styles, colours, gradients, materials. See SwiftUI.swift.
import AppKit

// MARK: ShapeStyle

public protocol ShapeStyle: Sendable {
  associatedtype Resolved: ShapeStyle = Never
  func resolve(in environment: EnvironmentValues) -> Resolved
}
extension Never: ShapeStyle {
  public typealias Resolved = Never
}
extension ShapeStyle where Resolved == Never {
  public func resolve(in environment: EnvironmentValues) -> Never { fatalError() }
}
extension ShapeStyle {
  public func opacity(_ opacity: Double) -> some ShapeStyle { self }
  public func blendMode(_ mode: BlendMode) -> some ShapeStyle { self }
  public func shadow(_ style: ShadowStyle) -> some ShapeStyle { self }
  public func `in`(_ rect: CGRect) -> some ShapeStyle { self }
  public var secondary: some ShapeStyle { self }
  public var tertiary: some ShapeStyle { self }
  public var quaternary: some ShapeStyle { self }
  public var quinary: some ShapeStyle { self }
}
public struct AnyShapeStyle: ShapeStyle {
  public init<S: ShapeStyle>(_ style: S) {}
}
public struct ShadowStyle: Equatable, Sendable {
  public static func drop(
    color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0
  ) -> ShadowStyle { ShadowStyle() }
  public static func inner(
    color: Color = Color(.sRGBLinear, white: 0, opacity: 0.55), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0
  ) -> ShadowStyle { ShadowStyle() }
}
public enum BlendMode: Hashable, Sendable {
  case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion, hue, saturation,
    color, luminosity, sourceAtop, destinationOver, destinationOut, plusDarker, plusLighter
}

public struct ForegroundStyle: ShapeStyle {
  public init() {}
}
public struct BackgroundStyle: ShapeStyle {
  public init() {}
}
public struct HierarchicalShapeStyle: ShapeStyle {
  public static let primary = HierarchicalShapeStyle()
  public static let secondary = HierarchicalShapeStyle()
  public static let tertiary = HierarchicalShapeStyle()
  public static let quaternary = HierarchicalShapeStyle()
  public static let quinary = HierarchicalShapeStyle()
}
public struct TintShapeStyle: ShapeStyle {
  public init() {}
}
public struct SelectionShapeStyle: ShapeStyle {
  public init() {}
}
public struct SeparatorShapeStyle: ShapeStyle {
  public init() {}
}
public struct PlaceholderTextShapeStyle: ShapeStyle {
  public init() {}
}
public struct LinkShapeStyle: ShapeStyle {
  public init() {}
}
public struct FillShapeStyle: ShapeStyle {
  public init() {}
}
public struct WindowBackgroundShapeStyle: ShapeStyle {
  public init() {}
}
extension ShapeStyle where Self == ForegroundStyle {
  public static var foreground: ForegroundStyle { ForegroundStyle() }
}
extension ShapeStyle where Self == BackgroundStyle {
  public static var background: BackgroundStyle { BackgroundStyle() }
}
extension ShapeStyle where Self == HierarchicalShapeStyle {
  public static var primary: HierarchicalShapeStyle { .primary }
  public static var secondary: HierarchicalShapeStyle { .secondary }
  public static var tertiary: HierarchicalShapeStyle { .tertiary }
  public static var quaternary: HierarchicalShapeStyle { .quaternary }
  public static var quinary: HierarchicalShapeStyle { .quinary }
}
extension ShapeStyle where Self == TintShapeStyle {
  public static var tint: TintShapeStyle { TintShapeStyle() }
}
extension ShapeStyle where Self == SelectionShapeStyle {
  public static var selection: SelectionShapeStyle { SelectionShapeStyle() }
}
extension ShapeStyle where Self == SeparatorShapeStyle {
  public static var separator: SeparatorShapeStyle { SeparatorShapeStyle() }
}
extension ShapeStyle where Self == PlaceholderTextShapeStyle {
  public static var placeholder: PlaceholderTextShapeStyle { PlaceholderTextShapeStyle() }
}
extension ShapeStyle where Self == LinkShapeStyle {
  public static var link: LinkShapeStyle { LinkShapeStyle() }
}
extension ShapeStyle where Self == FillShapeStyle {
  public static var fill: FillShapeStyle { FillShapeStyle() }
}
extension ShapeStyle where Self == WindowBackgroundShapeStyle {
  public static var windowBackground: WindowBackgroundShapeStyle { WindowBackgroundShapeStyle() }
}

// MARK: Color

public struct Color: Hashable, CustomStringConvertible, Sendable {
  public enum RGBColorSpace: Hashable, Sendable { case sRGB, sRGBLinear, displayP3 }
  public struct Resolved: Hashable, ShapeStyle, Animatable, CustomStringConvertible, Codable {
    public var linearRed: Float
    public var linearGreen: Float
    public var linearBlue: Float
    public var opacity: Float
    public var red: Float {
      get { linearRed }
      set {}
    }
    public var green: Float {
      get { linearGreen }
      set {}
    }
    public var blue: Float {
      get { linearBlue }
      set {}
    }
    public init(colorSpace: RGBColorSpace = .sRGB, red: Float, green: Float, blue: Float, opacity: Float = 1) {
      linearRed = red
      linearGreen = green
      linearBlue = blue
      self.opacity = opacity
    }
    public var cgColor: CGColor { fatalError() }
    public var description: String { "" }
    public var animatableData: AnimatablePair<Float, AnimatablePair<Float, AnimatablePair<Float, Float>>> {
      get { fatalError() }
      set {}
    }
  }
  public init(_ name: String, bundle: Bundle? = nil) {}
  public init(_ colorSpace: RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) {}
  public init(_ colorSpace: RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) {}
  public init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) {}
  public init(_ resolved: Resolved) {}
  public init(nsColor: NSColor) {}
  @available(*, deprecated, message: "Use Color(nsColor:) when converting a NSColor.")
  public init(_ color: NSColor) {}
  public init(cgColor: CGColor) {}
  @available(*, deprecated, renamed: "init(cgColor:)")
  public init(_ cgColor: CGColor) {}
  public init<T: Hashable & ShapeStyle>(_ color: T) where T.Resolved == Resolved {}
  public var description: String { "" }
  public var cgColor: CGColor? { nil }
  public var gradient: AnyGradient { AnyGradient(Gradient(colors: [self])) }
  public func opacity(_ opacity: Double) -> Color { self }
  public func resolve(in environment: EnvironmentValues) -> Resolved { Resolved(red: 0, green: 0, blue: 0) }

  public static let red = Color(white: 0)
  public static let orange = Color(white: 0)
  public static let yellow = Color(white: 0)
  public static let green = Color(white: 0)
  public static let mint = Color(white: 0)
  public static let teal = Color(white: 0)
  public static let cyan = Color(white: 0)
  public static let blue = Color(white: 0)
  public static let indigo = Color(white: 0)
  public static let purple = Color(white: 0)
  public static let pink = Color(white: 0)
  public static let brown = Color(white: 0)
  public static let white = Color(white: 1)
  public static let gray = Color(white: 0)
  public static let black = Color(white: 0)
  public static let clear = Color(white: 0)
  public static let primary = Color(white: 0)
  public static let secondary = Color(white: 0)
  public static var accentColor: Color { Color(white: 0) }
}
extension Color: ShapeStyle {}
extension Color: View, _PrimitiveView {}
extension ShapeStyle where Self == Color {
  public static var red: Color { .red }
  public static var orange: Color { .orange }
  public static var yellow: Color { .yellow }
  public static var green: Color { .green }
  public static var mint: Color { .mint }
  public static var teal: Color { .teal }
  public static var cyan: Color { .cyan }
  public static var blue: Color { .blue }
  public static var indigo: Color { .indigo }
  public static var purple: Color { .purple }
  public static var pink: Color { .pink }
  public static var brown: Color { .brown }
  public static var white: Color { .white }
  public static var gray: Color { .gray }
  public static var black: Color { .black }
  public static var clear: Color { .clear }
}
extension NSColor {
  public convenience init(_ color: Color) { self.init() }
}

// MARK: Gradients

public struct Gradient: Equatable, Hashable, ShapeStyle {
  public struct Stop: Equatable, Hashable, Sendable {
    public var color: Color
    public var location: CGFloat
    public init(color: Color, location: CGFloat) {
      self.color = color
      self.location = location
    }
  }
  public var stops: [Stop]
  public init(stops: [Stop]) { self.stops = stops }
  public init(colors: [Color]) { stops = [] }
}
public struct AnyGradient: Hashable, ShapeStyle {
  public init(_ gradient: Gradient) {}
}
public struct LinearGradient: ShapeStyle {
  public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) {}
  public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {}
  public init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) {}
}
public struct RadialGradient: ShapeStyle {
  public init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
  public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
  public init(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
}
public struct EllipticalGradient: ShapeStyle {
  public init(gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {}
  public init(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {}
  public init(stops: [Gradient.Stop], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {}
}
public struct AngularGradient: ShapeStyle {
  public init(gradient: Gradient, center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {}
  public init(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) {}
  public init(stops: [Gradient.Stop], center: UnitPoint, startAngle: Angle, endAngle: Angle) {}
  public init(gradient: Gradient, center: UnitPoint, angle: Angle = .zero) {}
  public init(colors: [Color], center: UnitPoint, angle: Angle = .zero) {}
  public init(stops: [Gradient.Stop], center: UnitPoint, angle: Angle = .zero) {}
}
extension LinearGradient: View, _PrimitiveView {}
extension RadialGradient: View, _PrimitiveView {}
extension EllipticalGradient: View, _PrimitiveView {}
extension AngularGradient: View, _PrimitiveView {}
extension ShapeStyle where Self == LinearGradient {
  public static func linearGradient(_ gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
    LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint)
  }
  public static func linearGradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
    LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint)
  }
  public static func linearGradient(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient {
    LinearGradient(stops: stops, startPoint: startPoint, endPoint: endPoint)
  }
}
extension ShapeStyle where Self == RadialGradient {
  public static func radialGradient(_ gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient {
    RadialGradient(gradient: gradient, center: center, startRadius: startRadius, endRadius: endRadius)
  }
  public static func radialGradient(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient {
    RadialGradient(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius)
  }
  public static func radialGradient(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient {
    RadialGradient(stops: stops, center: center, startRadius: startRadius, endRadius: endRadius)
  }
}
extension ShapeStyle where Self == EllipticalGradient {
  public static func ellipticalGradient(
    _ gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5
  ) -> EllipticalGradient { EllipticalGradient(gradient: gradient) }
  public static func ellipticalGradient(
    colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5
  ) -> EllipticalGradient { EllipticalGradient(colors: colors) }
  public static func ellipticalGradient(
    stops: [Gradient.Stop], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5
  ) -> EllipticalGradient { EllipticalGradient(stops: stops) }
}
extension ShapeStyle where Self == AngularGradient {
  public static func angularGradient(_ gradient: Gradient, center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient {
    AngularGradient(gradient: gradient, center: center, startAngle: startAngle, endAngle: endAngle)
  }
  public static func angularGradient(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient {
    AngularGradient(colors: colors, center: center, startAngle: startAngle, endAngle: endAngle)
  }
  public static func angularGradient(stops: [Gradient.Stop], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient {
    AngularGradient(stops: stops, center: center, startAngle: startAngle, endAngle: endAngle)
  }
  public static func conicGradient(_ gradient: Gradient, center: UnitPoint, angle: Angle = .zero) -> AngularGradient {
    AngularGradient(gradient: gradient, center: center, angle: angle)
  }
  public static func conicGradient(colors: [Color], center: UnitPoint, angle: Angle = .zero) -> AngularGradient {
    AngularGradient(colors: colors, center: center, angle: angle)
  }
  public static func conicGradient(stops: [Gradient.Stop], center: UnitPoint, angle: Angle = .zero) -> AngularGradient {
    AngularGradient(stops: stops, center: center, angle: angle)
  }
}
extension ShapeStyle where Self == AnyShapeStyle {
  public static func linearGradient(_ gradient: AnyGradient, startPoint: UnitPoint, endPoint: UnitPoint) -> some ShapeStyle { gradient }
  public static func radialGradient(
    _ gradient: AnyGradient, center: UnitPoint = .center, startRadius: CGFloat = 0, endRadius: CGFloat
  ) -> some ShapeStyle { gradient }
  public static func ellipticalGradient(
    _ gradient: AnyGradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5
  ) -> some ShapeStyle { gradient }
  public static func angularGradient(_ gradient: AnyGradient, center: UnitPoint = .center, startAngle: Angle, endAngle: Angle) -> some ShapeStyle {
    gradient
  }
  public static func conicGradient(_ gradient: AnyGradient, center: UnitPoint = .center, angle: Angle = .zero) -> some ShapeStyle { gradient }
}

// MARK: Materials and images

public struct Material: ShapeStyle {
  public static let ultraThin = Material()
  public static let thin = Material()
  public static let regular = Material()
  public static let thick = Material()
  public static let ultraThick = Material()
  public static let bar = Material()
}
extension ShapeStyle where Self == Material {
  public static var ultraThinMaterial: Material { .ultraThin }
  public static var thinMaterial: Material { .thin }
  public static var regularMaterial: Material { .regular }
  public static var thickMaterial: Material { .thick }
  public static var ultraThickMaterial: Material { .ultraThick }
  public static var bar: Material { .bar }
}
public struct ImagePaint: ShapeStyle {
  public var image: Image
  public var sourceRect: CGRect
  public var scale: CGFloat
  public init(image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) {
    self.image = image
    self.sourceRect = sourceRect
    self.scale = scale
  }
}
extension ShapeStyle where Self == ImagePaint {
  public static func image(_ image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) -> ImagePaint {
    ImagePaint(image: image, sourceRect: sourceRect, scale: scale)
  }
}
