// A stand-in for SwiftUI: localised string keys, text, fonts, images, labels. See SwiftUI.swift.
//
// Wherever the SDK takes a title it has two overloads, one for a `LocalizedStringKey` and a disfavoured one for any `StringProtocol`: a
// literal becomes a key, a `String` variable is shown as it is. The stand-ins keep both, with `@_disfavoredOverload` where the SDK has it.
import AppKit

// MARK: LocalizedStringKey

/// What `"\(x)"` may hold in a key without a formatter, besides strings: the numbers. With a `Bool`, an optional or a type of Arbor's own in it, a
/// literal cannot be a key; the compiler then takes the overload for plain strings where there is one, here as on the Mac.
public protocol _FormatSpecifiable: Equatable {
  associatedtype _Arg: CVarArg
  var _arg: _Arg { get }
  var _specifier: String { get }
}
extension Int: _FormatSpecifiable {
  public var _arg: Int64 { 0 }
  public var _specifier: String { "" }
}
extension Int8: _FormatSpecifiable {
  public var _arg: Int32 { 0 }
  public var _specifier: String { "" }
}
extension Int16: _FormatSpecifiable {
  public var _arg: Int32 { 0 }
  public var _specifier: String { "" }
}
extension Int32: _FormatSpecifiable {
  public var _arg: Int32 { 0 }
  public var _specifier: String { "" }
}
extension Int64: _FormatSpecifiable {
  public var _arg: Int64 { 0 }
  public var _specifier: String { "" }
}
extension UInt: _FormatSpecifiable {
  public var _arg: UInt64 { 0 }
  public var _specifier: String { "" }
}
extension UInt8: _FormatSpecifiable {
  public var _arg: UInt32 { 0 }
  public var _specifier: String { "" }
}
extension UInt16: _FormatSpecifiable {
  public var _arg: UInt32 { 0 }
  public var _specifier: String { "" }
}
extension UInt32: _FormatSpecifiable {
  public var _arg: UInt32 { 0 }
  public var _specifier: String { "" }
}
extension UInt64: _FormatSpecifiable {
  public var _arg: UInt64 { 0 }
  public var _specifier: String { "" }
}
extension Float: _FormatSpecifiable {
  public var _arg: Float { 0 }
  public var _specifier: String { "" }
}
extension Double: _FormatSpecifiable {
  public var _arg: Double { 0 }
  public var _specifier: String { "" }
}
extension CGFloat: _FormatSpecifiable {
  public var _arg: CGFloat { 0 }
  public var _specifier: String { "" }
}

public struct LocalizedStringKey: Equatable, ExpressibleByStringInterpolation {
  public init(_ value: String) {}
  public init(stringLiteral value: String) {}
  public init(stringInterpolation: StringInterpolation) {}
  public struct StringInterpolation: StringInterpolationProtocol {
    public init(literalCapacity: Int, interpolationCount: Int) {}
    public mutating func appendLiteral(_ literal: String) {}
    public mutating func appendInterpolation(_ string: String) {}
    public mutating func appendInterpolation<Subject: ReferenceConvertible>(_ subject: Subject, formatter: Formatter? = nil) {}
    public mutating func appendInterpolation<Subject: NSObject>(_ subject: Subject, formatter: Formatter? = nil) {}
    public mutating func appendInterpolation<F: FormatStyle>(_ input: F.FormatInput, format: F)
    where F.FormatInput: Equatable, F.FormatOutput == String {}
    public mutating func appendInterpolation<T: _FormatSpecifiable>(_ value: T) {}
    public mutating func appendInterpolation<T: _FormatSpecifiable>(_ value: T, specifier: String) {}
    public mutating func appendInterpolation(_ text: Text) {}
    public mutating func appendInterpolation(_ attributedString: AttributedString) {}
    public mutating func appendInterpolation(_ image: Image) {}
    public mutating func appendInterpolation(_ date: Date, style: Text.DateStyle) {}
    public mutating func appendInterpolation(_ dates: ClosedRange<Date>) {}
    public mutating func appendInterpolation(_ interval: DateInterval) {}
    public mutating func appendInterpolation(
      timerInterval: ClosedRange<Date>, pauseTime: Date? = nil, countsDown: Bool = true, showsHours: Bool = true) {}
  }
}

// MARK: Text

public struct Text: Equatable, Sendable {
  public enum TruncationMode: Hashable, Sendable { case head, tail, middle }
  public enum Case: Hashable, Sendable { case uppercase, lowercase }
  public struct DateStyle: Equatable, Codable, Sendable {
    public static let time = DateStyle()
    public static let date = DateStyle()
    public static let relative = DateStyle()
    public static let offset = DateStyle()
    public static let timer = DateStyle()
  }
  public struct LineStyle: Hashable, Sendable {
    public struct Pattern: Sendable {
      public static let solid = Pattern()
      public static let dot = Pattern()
      public static let dash = Pattern()
      public static let dashDot = Pattern()
      public static let dashDotDot = Pattern()
    }
    public init(pattern: Pattern = .solid, color: Color? = nil) {}
    public static let single = LineStyle()
  }
  public struct Scale: Hashable, Sendable {
    public static let `default` = Scale()
    public static let secondary = Scale()
  }

  public init(_ key: LocalizedStringKey, tableName: String? = nil, bundle: Bundle? = nil, comment: StaticString? = nil) {}
  public init(verbatim content: String) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ content: S) {}
  public init(_ attributedContent: AttributedString) {}
  public init(_ image: Image) {}
  public init(_ date: Date, style: DateStyle) {}
  public init(_ dates: ClosedRange<Date>) {}
  public init(_ interval: DateInterval) {}
  public init(timerInterval: ClosedRange<Date>, pauseTime: Date? = nil, countsDown: Bool = true, showsHours: Bool = true) {}
  public init<Subject: ReferenceConvertible>(_ subject: Subject, formatter: Formatter) {}
  public init<Subject: NSObject>(_ subject: Subject, formatter: Formatter) {}
  public init<F: FormatStyle>(_ input: F.FormatInput, format: F) where F.FormatInput: Equatable, F.FormatOutput == String {}

  public static func + (lhs: Text, rhs: Text) -> Text { lhs }

  public func font(_ font: Font?) -> Text { self }
  public func fontWeight(_ weight: Font.Weight?) -> Text { self }
  public func fontWidth(_ width: Font.Width?) -> Text { self }
  public func fontDesign(_ design: Font.Design?) -> Text { self }
  public func foregroundColor(_ color: Color?) -> Text { self }
  public func foregroundStyle<S: ShapeStyle>(_ style: S) -> Text { self }
  public func bold() -> Text { self }
  public func bold(_ isActive: Bool) -> Text { self }
  public func italic() -> Text { self }
  public func italic(_ isActive: Bool) -> Text { self }
  public func monospaced(_ isActive: Bool = true) -> Text { self }
  public func monospacedDigit() -> Text { self }
  public func strikethrough(_ isActive: Bool = true, color: Color? = nil) -> Text { self }
  public func strikethrough(_ isActive: Bool = true, pattern: LineStyle.Pattern, color: Color? = nil) -> Text { self }
  public func underline(_ isActive: Bool = true, color: Color? = nil) -> Text { self }
  public func underline(_ isActive: Bool = true, pattern: LineStyle.Pattern, color: Color? = nil) -> Text { self }
  public func kerning(_ kerning: CGFloat) -> Text { self }
  public func tracking(_ tracking: CGFloat) -> Text { self }
  public func baselineOffset(_ baselineOffset: CGFloat) -> Text { self }
  public func textScale(_ scale: Scale, isEnabled: Bool = true) -> Text { self }
  public func accessibilityLabel(_ label: Text) -> Text { self }
  public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> Text { self }
  @_disfavoredOverload public func accessibilityLabel<S: StringProtocol>(_ label: S) -> Text { self }
  public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> Text { self }
  public func accessibilityTextContentType(_ value: AccessibilityTextContentType) -> Text { self }
  public func speechAlwaysIncludesPunctuation(_ value: Bool = true) -> Text { self }
  public func speechSpellsOutCharacters(_ value: Bool = true) -> Text { self }
  public func speechAdjustedPitch(_ value: Double) -> Text { self }
  public func speechAnnouncementsQueued(_ value: Bool = true) -> Text { self }
}
extension Text: View, _PrimitiveView {}

// MARK: Font

public struct Font: Hashable, Sendable {
  public struct Weight: Hashable, Sendable {
    public static let ultraLight = Weight()
    public static let thin = Weight()
    public static let light = Weight()
    public static let regular = Weight()
    public static let medium = Weight()
    public static let semibold = Weight()
    public static let bold = Weight()
    public static let heavy = Weight()
    public static let black = Weight()
  }
  public struct Width: Hashable, Sendable {
    public var value: CGFloat
    public init(_ value: CGFloat) { self.value = value }
    public static let compressed = Width(-0.2)
    public static let condensed = Width(-0.1)
    public static let standard = Width(0)
    public static let expanded = Width(0.2)
  }
  public enum Leading: Hashable, Sendable { case standard, tight, loose }
  public enum TextStyle: CaseIterable, Hashable, Sendable {
    case largeTitle, title, title2, title3, headline, subheadline, body, callout, footnote, caption, caption2
  }
  public enum Design: Hashable, Sendable { case `default`, serif, rounded, monospaced }

  public static let largeTitle = Font()
  public static let title = Font()
  public static let title2 = Font()
  public static let title3 = Font()
  public static let headline = Font()
  public static let subheadline = Font()
  public static let body = Font()
  public static let callout = Font()
  public static let footnote = Font()
  public static let caption = Font()
  public static let caption2 = Font()

  init() {}
  public static func system(_ style: TextStyle, design: Design? = nil, weight: Weight? = nil) -> Font { Font() }
  @_disfavoredOverload public static func system(_ style: TextStyle, design: Design = .default) -> Font { Font() }
  public static func system(size: CGFloat, weight: Weight? = nil, design: Design? = nil) -> Font { Font() }
  @_disfavoredOverload public static func system(size: CGFloat, weight: Weight = .regular, design: Design = .default) -> Font { Font() }
  public static func custom(_ name: String, size: CGFloat) -> Font { Font() }
  public static func custom(_ name: String, size: CGFloat, relativeTo textStyle: TextStyle) -> Font { Font() }
  public static func custom(_ name: String, fixedSize: CGFloat) -> Font { Font() }

  public func italic() -> Font { self }
  public func smallCaps() -> Font { self }
  public func lowercaseSmallCaps() -> Font { self }
  public func uppercaseSmallCaps() -> Font { self }
  public func monospacedDigit() -> Font { self }
  public func monospaced() -> Font { self }
  public func weight(_ weight: Weight) -> Font { self }
  public func width(_ width: Width) -> Font { self }
  public func bold() -> Font { self }
  public func leading(_ leading: Leading) -> Font { self }
}

// MARK: Image

public struct Image: Equatable, Sendable {
  public enum Scale: Hashable, Sendable { case small, medium, large }
  public enum TemplateRenderingMode: Hashable, Sendable { case template, original }
  public enum ResizingMode: Hashable, Sendable { case tile, stretch }
  public enum Interpolation: Hashable, Sendable { case none, low, medium, high }
  public enum Orientation: UInt8, CaseIterable, Hashable, Sendable {
    case up, upMirrored, down, downMirrored, left, leftMirrored, right, rightMirrored
  }
  public struct DynamicRange: Hashable, Sendable {
    public static let standard = DynamicRange()
    public static let constrainedHigh = DynamicRange()
    public static let high = DynamicRange()
  }

  public init(_ name: String, bundle: Bundle? = nil) {}
  public init(_ name: String, bundle: Bundle? = nil, label: Text) {}
  public init(decorative name: String, bundle: Bundle? = nil) {}
  public init(_ name: String, variableValue: Double?, bundle: Bundle? = nil) {}
  public init(_ name: String, variableValue: Double?, bundle: Bundle? = nil, label: Text) {}
  public init(decorative name: String, variableValue: Double?, bundle: Bundle? = nil) {}
  public init(systemName: String) {}
  public init(systemName: String, variableValue: Double?) {}
  public init(nsImage: NSImage) {}
  public init(_ cgImage: CGImage, scale: CGFloat, orientation: Orientation = .up, label: Text) {}
  public init(decorative cgImage: CGImage, scale: CGFloat, orientation: Orientation = .up) {}

  public func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: ResizingMode = .stretch) -> Image { self }
  public func renderingMode(_ renderingMode: TemplateRenderingMode?) -> Image { self }
  public func interpolation(_ interpolation: Interpolation) -> Image { self }
  public func antialiased(_ isAntialiased: Bool) -> Image { self }
  public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> Image { self }
  public func allowedDynamicRange(_ range: DynamicRange?) -> Image { self }
}
extension Image: View, _PrimitiveView {}

public enum AsyncImagePhase: Sendable {
  case empty
  case success(Image)
  case failure(any Error)
  public var image: Image? { nil }
  public var error: (any Error)? { nil }
}
public struct AsyncImage<Content: View>: _PrimitiveView {
  public init(url: URL?, scale: CGFloat = 1) where Content == Image {}
  public init<I: View, P: View>(
    url: URL?, scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P
  ) where Content == _ConditionalContent<I, P> {}
  public init(
    url: URL?, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {}
}

public struct SymbolRenderingMode: Sendable {
  public static let monochrome = SymbolRenderingMode()
  public static let multicolor = SymbolRenderingMode()
  public static let hierarchical = SymbolRenderingMode()
  public static let palette = SymbolRenderingMode()
}
public struct SymbolVariants: Hashable, Sendable {
  public static let none = SymbolVariants()
  public static let circle = SymbolVariants()
  public static let square = SymbolVariants()
  public static let rectangle = SymbolVariants()
  public static let fill = SymbolVariants()
  public static let slash = SymbolVariants()
  public var circle: SymbolVariants { self }
  public var square: SymbolVariants { self }
  public var rectangle: SymbolVariants { self }
  public var fill: SymbolVariants { self }
  public var slash: SymbolVariants { self }
  public func contains(_ other: SymbolVariants) -> Bool { false }
}

// MARK: Label

public struct Label<Title: View, Icon: View>: _PrimitiveView {
  public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) {}
}
extension Label where Title == Text, Icon == Image {
  public init(_ titleKey: LocalizedStringKey, image name: String) {}
  public init(_ titleKey: LocalizedStringKey, systemImage name: String) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, image name: String) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage name: String) {}
}
extension Label where Title == LabelStyleConfiguration.Title, Icon == LabelStyleConfiguration.Icon {
  public init(_ configuration: LabelStyleConfiguration) {}
}
