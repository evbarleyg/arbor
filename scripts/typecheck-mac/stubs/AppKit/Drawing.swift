// A stand-in for AppKit: colours, fonts, images, paths, text, cursors, appearance. See Application.swift.

public struct NSColorSpaceName: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(_ rawValue: String) { self.rawValue = rawValue }
  public static let calibratedWhite = NSColorSpaceName("NSCalibratedWhiteColorSpace")
  public static let calibratedRGB = NSColorSpaceName("NSCalibratedRGBColorSpace")
  public static let deviceWhite = NSColorSpaceName("NSDeviceWhiteColorSpace")
  public static let deviceRGB = NSColorSpaceName("NSDeviceRGBColorSpace")
  public static let deviceCMYK = NSColorSpaceName("NSDeviceCMYKColorSpace")
  public static let named = NSColorSpaceName("NSNamedColorSpace")
  public static let pattern = NSColorSpaceName("NSPatternColorSpace")
  public static let custom = NSColorSpaceName("NSCustomColorSpace")
}
open class NSColorSpace: NSObject, @unchecked Sendable {
  public convenience init?(cgColorSpace: CGColorSpace) { self.init() }
  open var cgColorSpace: CGColorSpace? { nil }
  open var localizedName: String? { nil }
  open var numberOfColorComponents: Int { 3 }
  open class var sRGB: NSColorSpace { NSColorSpace() }
  open class var extendedSRGB: NSColorSpace { NSColorSpace() }
  open class var displayP3: NSColorSpace { NSColorSpace() }
  open class var deviceRGB: NSColorSpace { NSColorSpace() }
  open class var deviceGray: NSColorSpace { NSColorSpace() }
  open class var genericRGB: NSColorSpace { NSColorSpace() }
  open class var genericGray: NSColorSpace { NSColorSpace() }
  open class var genericGamma22Gray: NSColorSpace { NSColorSpace() }
}

open class NSColor: NSObject, @unchecked Sendable {
  public enum SystemEffect: Int, Sendable { case none = 0, pressed, deepPressed, disabled, rollover }
  public enum ColorType: Int, Sendable { case componentBased = 0, pattern, catalog }
  public typealias Name = String
  public convenience init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(srgbRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(calibratedRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(deviceRed red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(displayP3Red red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(white: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(calibratedWhite white: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(deviceWhite white: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(genericGamma22White white: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(calibratedHue hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(deviceHue hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) { self.init() }
  public convenience init(colorSpace space: NSColorSpace, components: UnsafePointer<CGFloat>, count numberOfComponents: Int) { self.init() }
  public convenience init?(cgColor: CGColor) { self.init() }
  public convenience init?(named name: Name) { self.init() }
  public convenience init(patternImage image: NSImage) { self.init() }
  public convenience init(name colorName: Name?, dynamicProvider: @escaping @Sendable (NSAppearance) -> NSColor) { self.init() }
  open var cgColor: CGColor { .black }
  open var type: ColorType { .componentBased }
  open var colorSpace: NSColorSpace { .sRGB }
  open var redComponent: CGFloat { 0 }
  open var greenComponent: CGFloat { 0 }
  open var blueComponent: CGFloat { 0 }
  open var alphaComponent: CGFloat { 1 }
  open var whiteComponent: CGFloat { 0 }
  open var hueComponent: CGFloat { 0 }
  open var saturationComponent: CGFloat { 0 }
  open var brightnessComponent: CGFloat { 0 }
  open var numberOfComponents: Int { 4 }
  open func getRed(
    _ red: UnsafeMutablePointer<CGFloat>?, green: UnsafeMutablePointer<CGFloat>?, blue: UnsafeMutablePointer<CGFloat>?,
    alpha: UnsafeMutablePointer<CGFloat>?) {}
  open func getHue(
    _ hue: UnsafeMutablePointer<CGFloat>?, saturation: UnsafeMutablePointer<CGFloat>?, brightness: UnsafeMutablePointer<CGFloat>?,
    alpha: UnsafeMutablePointer<CGFloat>?) {}
  open func getWhite(_ white: UnsafeMutablePointer<CGFloat>?, alpha: UnsafeMutablePointer<CGFloat>?) {}
  open func getComponents(_ components: UnsafeMutablePointer<CGFloat>) {}
  open func usingColorSpace(_ space: NSColorSpace) -> NSColor? { nil }
  open func usingType(_ type: ColorType) -> NSColor? { nil }
  open func withAlphaComponent(_ alpha: CGFloat) -> NSColor { self }
  open func blended(withFraction fraction: CGFloat, of color: NSColor) -> NSColor? { nil }
  open func highlight(withLevel val: CGFloat) -> NSColor? { nil }
  open func shadow(withLevel val: CGFloat) -> NSColor? { nil }
  open func withSystemEffect(_ systemEffect: SystemEffect) -> NSColor { self }
  open func set() {}
  open func setFill() {}
  open func setStroke() {}
  open class var black: NSColor { NSColor() }
  open class var darkGray: NSColor { NSColor() }
  open class var lightGray: NSColor { NSColor() }
  open class var white: NSColor { NSColor() }
  open class var gray: NSColor { NSColor() }
  open class var red: NSColor { NSColor() }
  open class var green: NSColor { NSColor() }
  open class var blue: NSColor { NSColor() }
  open class var cyan: NSColor { NSColor() }
  open class var yellow: NSColor { NSColor() }
  open class var magenta: NSColor { NSColor() }
  open class var orange: NSColor { NSColor() }
  open class var purple: NSColor { NSColor() }
  open class var brown: NSColor { NSColor() }
  open class var clear: NSColor { NSColor() }
  open class var labelColor: NSColor { NSColor() }
  open class var secondaryLabelColor: NSColor { NSColor() }
  open class var tertiaryLabelColor: NSColor { NSColor() }
  open class var quaternaryLabelColor: NSColor { NSColor() }
  open class var linkColor: NSColor { NSColor() }
  open class var placeholderTextColor: NSColor { NSColor() }
  open class var windowFrameTextColor: NSColor { NSColor() }
  open class var selectedMenuItemTextColor: NSColor { NSColor() }
  open class var alternateSelectedControlTextColor: NSColor { NSColor() }
  open class var headerTextColor: NSColor { NSColor() }
  open class var separatorColor: NSColor { NSColor() }
  open class var gridColor: NSColor { NSColor() }
  open class var windowBackgroundColor: NSColor { NSColor() }
  open class var underPageBackgroundColor: NSColor { NSColor() }
  open class var controlBackgroundColor: NSColor { NSColor() }
  open class var selectedContentBackgroundColor: NSColor { NSColor() }
  open class var unemphasizedSelectedContentBackgroundColor: NSColor { NSColor() }
  open class var alternatingContentBackgroundColors: [NSColor] { [] }
  open class var findHighlightColor: NSColor { NSColor() }
  open class var textColor: NSColor { NSColor() }
  open class var textBackgroundColor: NSColor { NSColor() }
  open class var selectedTextColor: NSColor { NSColor() }
  open class var selectedTextBackgroundColor: NSColor { NSColor() }
  open class var unemphasizedSelectedTextBackgroundColor: NSColor { NSColor() }
  open class var unemphasizedSelectedTextColor: NSColor { NSColor() }
  open class var controlColor: NSColor { NSColor() }
  open class var controlTextColor: NSColor { NSColor() }
  open class var selectedControlColor: NSColor { NSColor() }
  open class var selectedControlTextColor: NSColor { NSColor() }
  open class var disabledControlTextColor: NSColor { NSColor() }
  open class var keyboardFocusIndicatorColor: NSColor { NSColor() }
  open class var scrubberTexturedBackground: NSColor { NSColor() }
  open class var controlAccentColor: NSColor { NSColor() }
  open class var highlightColor: NSColor { NSColor() }
  open class var shadowColor: NSColor { NSColor() }
  open class var systemRed: NSColor { NSColor() }
  open class var systemGreen: NSColor { NSColor() }
  open class var systemBlue: NSColor { NSColor() }
  open class var systemOrange: NSColor { NSColor() }
  open class var systemYellow: NSColor { NSColor() }
  open class var systemBrown: NSColor { NSColor() }
  open class var systemPink: NSColor { NSColor() }
  open class var systemPurple: NSColor { NSColor() }
  open class var systemGray: NSColor { NSColor() }
  open class var systemTeal: NSColor { NSColor() }
  open class var systemIndigo: NSColor { NSColor() }
  open class var systemMint: NSColor { NSColor() }
  open class var systemCyan: NSColor { NSColor() }
  open class var currentControlTint: NSControlTint { .defaultControlTint }
  public static let systemColorsDidChangeNotification = NSNotification.Name("NSSystemColorsDidChangeNotification")
}
public enum NSControlTint: UInt, Sendable { case defaultControlTint = 0, blueControlTint = 1, graphiteControlTint = 6, clearControlTint = 7 }

open class NSFontDescriptor: NSObject, @unchecked Sendable {
  public struct SymbolicTraits: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let italic = SymbolicTraits(rawValue: 1)
    public static let bold = SymbolicTraits(rawValue: 2)
    public static let monoSpace = SymbolicTraits(rawValue: 1 << 10)
  }
  public struct SystemDesign: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let `default` = SystemDesign(rawValue: "default")
    public static let serif = SystemDesign(rawValue: "serif")
    public static let monospaced = SystemDesign(rawValue: "monospaced")
    public static let rounded = SystemDesign(rawValue: "rounded")
  }
  open var symbolicTraits: SymbolicTraits { [] }
  open func withSymbolicTraits(_ symbolicTraits: SymbolicTraits) -> NSFontDescriptor { self }
  open func withDesign(_ design: SystemDesign) -> NSFontDescriptor? { nil }
  open func withSize(_ newPointSize: CGFloat) -> NSFontDescriptor { self }
}
open class NSFont: NSObject, @unchecked Sendable {
  public struct Weight: RawRepresentable, Hashable, Sendable {
    public let rawValue: CGFloat
    public init(rawValue: CGFloat) { self.rawValue = rawValue }
    public init(_ rawValue: CGFloat) { self.rawValue = rawValue }
    public static let ultraLight = Weight(-0.8)
    public static let thin = Weight(-0.6)
    public static let light = Weight(-0.4)
    public static let regular = Weight(0)
    public static let medium = Weight(0.23)
    public static let semibold = Weight(0.3)
    public static let bold = Weight(0.4)
    public static let heavy = Weight(0.56)
    public static let black = Weight(0.62)
  }
  public struct TextStyle: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let largeTitle = TextStyle(rawValue: "largeTitle")
    public static let title1 = TextStyle(rawValue: "title1")
    public static let title2 = TextStyle(rawValue: "title2")
    public static let title3 = TextStyle(rawValue: "title3")
    public static let headline = TextStyle(rawValue: "headline")
    public static let subheadline = TextStyle(rawValue: "subheadline")
    public static let body = TextStyle(rawValue: "body")
    public static let callout = TextStyle(rawValue: "callout")
    public static let footnote = TextStyle(rawValue: "footnote")
    public static let caption1 = TextStyle(rawValue: "caption1")
    public static let caption2 = TextStyle(rawValue: "caption2")
  }
  public struct TextStyleOptionKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
  }
  public convenience init?(name fontName: String, size fontSize: CGFloat) { self.init() }
  public convenience init?(descriptor fontDescriptor: NSFontDescriptor, size fontSize: CGFloat) { self.init() }
  open class func systemFont(ofSize fontSize: CGFloat) -> NSFont { NSFont() }
  open class func boldSystemFont(ofSize fontSize: CGFloat) -> NSFont { NSFont() }
  open class func systemFont(ofSize fontSize: CGFloat, weight: Weight) -> NSFont { NSFont() }
  open class func monospacedSystemFont(ofSize fontSize: CGFloat, weight: Weight) -> NSFont { NSFont() }
  open class func monospacedDigitSystemFont(ofSize fontSize: CGFloat, weight: Weight) -> NSFont { NSFont() }
  open class func labelFont(ofSize fontSize: CGFloat) -> NSFont { NSFont() }
  open class func menuFont(ofSize fontSize: CGFloat) -> NSFont { NSFont() }
  open class func menuBarFont(ofSize fontSize: CGFloat) -> NSFont { NSFont() }
  open class func messageFont(ofSize fontSize: CGFloat) -> NSFont { NSFont() }
  open class func titleBarFont(ofSize fontSize: CGFloat) -> NSFont { NSFont() }
  open class func toolTipsFont(ofSize fontSize: CGFloat) -> NSFont { NSFont() }
  open class func controlContentFont(ofSize fontSize: CGFloat) -> NSFont { NSFont() }
  open class func userFont(ofSize fontSize: CGFloat) -> NSFont? { nil }
  open class func userFixedPitchFont(ofSize fontSize: CGFloat) -> NSFont? { nil }
  open class func preferredFont(forTextStyle style: TextStyle, options: [TextStyleOptionKey: Any] = [:]) -> NSFont { NSFont() }
  open class func systemFontSize(for controlSize: NSControl.ControlSize) -> CGFloat { 13 }
  open class var systemFontSize: CGFloat { 13 }
  open class var smallSystemFontSize: CGFloat { 11 }
  open class var labelFontSize: CGFloat { 10 }
  open var fontName: String { "" }
  open var familyName: String? { nil }
  open var displayName: String? { nil }
  open var pointSize: CGFloat { 13 }
  open var fontDescriptor: NSFontDescriptor { NSFontDescriptor() }
  open var ascender: CGFloat { 0 }
  open var descender: CGFloat { 0 }
  open var leading: CGFloat { 0 }
  open var capHeight: CGFloat { 0 }
  open var xHeight: CGFloat { 0 }
  open var boundingRectForFont: NSRect { .zero }
  open var isFixedPitch: Bool { false }
  open func withSize(_ fontSize: CGFloat) -> NSFont { self }
}

open class NSImageRep: NSObject {
  open var size = NSSize.zero
  open var pixelsWide = 0
  open var pixelsHigh = 0
  open var hasAlpha = true
  open var isOpaque = false
  open var bitsPerSample = 8
  @discardableResult open func draw() -> Bool { false }
  @discardableResult open func draw(in rect: NSRect) -> Bool { false }
  open func cgImage(forProposedRect proposedDestRect: UnsafeMutablePointer<NSRect>?, context: NSGraphicsContext?, hints: [NSImageRep.HintKey: Any]?)
    -> CGImage?
  { nil }
  public struct HintKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let interpolation = HintKey(rawValue: "NSImageHintInterpolation")
    public static let ctm = HintKey(rawValue: "NSImageHintCTM")
  }
}
open class NSBitmapImageRep: NSImageRep {
  public enum FileType: UInt, Sendable { case tiff = 0, bmp, gif, jpeg, png, jpeg2000 }
  public struct PropertyKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let compressionFactor = PropertyKey(rawValue: "NSImageCompressionFactor")
  }
  public struct Format: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let alphaFirst = Format(rawValue: 1)
    public static let alphaNonpremultiplied = Format(rawValue: 2)
    public static let floatingPointSamples = Format(rawValue: 4)
  }
  public init?(
    bitmapDataPlanes planes: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?, pixelsWide width: Int, pixelsHigh height: Int,
    bitsPerSample bps: Int, samplesPerPixel spp: Int, hasAlpha alpha: Bool, isPlanar: Bool, colorSpaceName: NSColorSpaceName,
    bytesPerRow rBytes: Int, bitsPerPixel pBits: Int) {}
  public init?(
    bitmapDataPlanes planes: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>?, pixelsWide width: Int, pixelsHigh height: Int,
    bitsPerSample bps: Int, samplesPerPixel spp: Int, hasAlpha alpha: Bool, isPlanar: Bool, colorSpaceName: NSColorSpaceName,
    bitmapFormat: Format, bytesPerRow rBytes: Int, bitsPerPixel pBits: Int) {}
  public init(cgImage: CGImage) {}
  public init?(data: Data) {}
  open var cgImage: CGImage? { nil }
  open var bitmapData: UnsafeMutablePointer<UInt8>? { nil }
  open var bytesPerRow: Int { 0 }
  open var bitsPerPixel: Int { 32 }
  open var samplesPerPixel: Int { 4 }
  open var colorSpace: NSColorSpace { .sRGB }
  open func colorAt(x: Int, y: Int) -> NSColor? { nil }
  open func setColor(_ color: NSColor, atX x: Int, y: Int) {}
  open func retagging(with newSpace: NSColorSpace) -> NSBitmapImageRep? { nil }
  open func converting(to targetSpace: NSColorSpace, renderingIntent: NSColorRenderingIntent) -> NSBitmapImageRep? { nil }
  open func representation(using storageType: FileType, properties: [PropertyKey: Any]) -> Data? { nil }
  open var tiffRepresentation: Data? { nil }
}
public enum NSColorRenderingIntent: Int, Sendable { case `default` = 0, absoluteColorimetric, relativeColorimetric, perceptual, saturation }
public enum NSImageInterpolation: UInt, Sendable { case `default` = 0, none = 1, low = 2, medium = 4, high = 3 }
public enum NSCompositingOperation: UInt, Sendable {
  case clear = 0, copy, sourceOver, sourceIn, sourceOut, sourceAtop, destinationOver, destinationIn, destinationOut, destinationAtop, xor,
    plusDarker, highlight, plusLighter, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference,
    exclusion, hue, saturation, color, luminosity
}
open class NSImage: NSObject, @unchecked Sendable {
  public typealias Name = String
  public enum CacheMode: UInt, Sendable { case `default` = 0, always, bySize, never }
  open class SymbolConfiguration: NSObject, @unchecked Sendable {
    public convenience init(pointSize: CGFloat, weight: NSFont.Weight) { self.init() }
    public convenience init(pointSize: CGFloat, weight: NSFont.Weight, scale: SymbolScale) { self.init() }
    public convenience init(textStyle style: NSFont.TextStyle) { self.init() }
    public convenience init(textStyle style: NSFont.TextStyle, scale: SymbolScale) { self.init() }
    public convenience init(scale: SymbolScale) { self.init() }
    public convenience init(hierarchicalColor: NSColor) { self.init() }
    public convenience init(paletteColors: [NSColor]) { self.init() }
    open class func preferringMulticolor() -> Self { fatalError() }
    open class func preferringMonochrome() -> Self { fatalError() }
    open class func preferringHierarchical() -> Self { fatalError() }
    open func applying(_ configuration: SymbolConfiguration) -> Self { self }
  }
  public enum SymbolScale: Int, Sendable { case small = 1, medium = 2, large = 3 }
  public override init() {}
  public init(size: NSSize) {}
  public convenience init?(named name: Name) { self.init() }
  public convenience init?(systemSymbolName name: String, accessibilityDescription description: String?) { self.init() }
  public convenience init?(systemSymbolName name: String, variableValue value: Double, accessibilityDescription description: String?) { self.init() }
  public convenience init?(contentsOf url: URL) { self.init() }
  public convenience init?(contentsOfFile fileName: String) { self.init() }
  public convenience init?(data: Data) { self.init() }
  public convenience init(cgImage: CGImage, size: NSSize) { self.init() }
  public convenience init(size: NSSize, flipped drawingHandlerShouldBeCalledWithFlippedContext: Bool, drawingHandler: @escaping (NSRect) -> Bool) {
    self.init()
  }
  open var size = NSSize.zero
  open var isTemplate = false
  open var isValid: Bool { true }
  open var representations: [NSImageRep] { [] }
  open var accessibilityDescription: String?
  open var cacheMode: CacheMode = .default
  open var resizingMode: ResizingMode = .stretch
  open var capInsets = NSEdgeInsets()
  open var tiffRepresentation: Data? { nil }
  open var symbolConfiguration: SymbolConfiguration { SymbolConfiguration() }
  public enum ResizingMode: Int, Sendable { case stretch = 1, tile = 0 }
  open func name() -> Name? { nil }
  @discardableResult open func setName(_ string: Name?) -> Bool { true }
  open func addRepresentation(_ imageRep: NSImageRep) {}
  open func removeRepresentation(_ imageRep: NSImageRep) {}
  open func bestRepresentation(for rect: NSRect, context referenceContext: NSGraphicsContext?, hints: [NSImageRep.HintKey: Any]?) -> NSImageRep? { nil }
  open func withSymbolConfiguration(_ configuration: SymbolConfiguration) -> NSImage? { nil }
  open func cgImage(
    forProposedRect proposedDestRect: UnsafeMutablePointer<NSRect>?, context referenceContext: NSGraphicsContext?,
    hints: [NSImageRep.HintKey: Any]?
  ) -> CGImage? { nil }
  open func draw(in rect: NSRect) {}
  open func draw(at point: NSPoint, from fromRect: NSRect, operation op: NSCompositingOperation, fraction delta: CGFloat) {}
  open func draw(in rect: NSRect, from fromRect: NSRect, operation op: NSCompositingOperation, fraction delta: CGFloat) {}
  open func draw(
    in dstSpacePortionRect: NSRect, from srcSpacePortionRect: NSRect, operation op: NSCompositingOperation, fraction requestedAlpha: CGFloat,
    respectFlipped respectContextIsFlipped: Bool, hints: [NSImageRep.HintKey: Any]?) {}
  open func lockFocus() {}
  open func lockFocusFlipped(_ flipped: Bool) {}
  open func unlockFocus() {}
  open func recache() {}
  open func layerContents(forContentsScale layerContentsScale: CGFloat) -> Any { self }
  open func recommendedLayerContentsScale(_ preferredContentsScale: CGFloat) -> CGFloat { 1 }
  public static let applicationIconName: Name = "NSApplicationIcon"
  public static let cautionName: Name = "NSCaution"
  public static let infoName: Name = "NSInfo"
  public static let actionTemplateName: Name = "NSActionTemplate"
  public static let addTemplateName: Name = "NSAddTemplate"
  public static let removeTemplateName: Name = "NSRemoveTemplate"
  public static let statusAvailableName: Name = "NSStatusAvailable"
  public static let statusUnavailableName: Name = "NSStatusUnavailable"
}

open class NSGraphicsContext: NSObject {
  public convenience init?(bitmapImageRep bitmapRep: NSBitmapImageRep) { self.init() }
  public convenience init(cgContext graphicsPort: CGContext, flipped initialFlippedState: Bool) { self.init() }
  open class var current: NSGraphicsContext? {
    get { nil }
    set {}
  }
  open class func currentContextDrawingToScreen() -> Bool { true }
  open class func saveGraphicsState() {}
  open class func restoreGraphicsState() {}
  open func saveGraphicsState() {}
  open func restoreGraphicsState() {}
  open func flushGraphics() {}
  open var cgContext: CGContext { fatalError() }
  open var isFlipped: Bool { false }
  open var isDrawingToScreen: Bool { true }
  open var shouldAntialias = true
  open var imageInterpolation: NSImageInterpolation = .default
  open var compositingOperation: NSCompositingOperation = .sourceOver
  open var patternPhase = NSPoint.zero
}

open class NSBezierPath: NSObject {
  public enum LineCapStyle: UInt, Sendable { case butt = 0, round = 1, square = 2 }
  public enum LineJoinStyle: UInt, Sendable { case miter = 0, round = 1, bevel = 2 }
  public enum WindingRule: UInt, Sendable { case nonZero = 0, evenOdd = 1 }
  public enum ElementType: UInt, Sendable { case moveTo = 0, lineTo, curveTo, closePath, cubicCurveTo = 4, quadraticCurveTo = 5 }
  public convenience init(rect: NSRect) { self.init() }
  public convenience init(ovalIn rect: NSRect) { self.init() }
  public convenience init(roundedRect rect: NSRect, xRadius: CGFloat, yRadius: CGFloat) { self.init() }
  public convenience init(cgPath: CGPath) { self.init() }
  open class func fill(_ rect: NSRect) {}
  open class func stroke(_ rect: NSRect) {}
  open class func clip(_ rect: NSRect) {}
  open class func strokeLine(from point1: NSPoint, to point2: NSPoint) {}
  open class var defaultLineWidth: CGFloat {
    get { 1 }
    set {}
  }
  open var cgPath: CGPath {
    get { CGMutablePath() }
    set {}
  }
  open var lineWidth: CGFloat = 1
  open var lineCapStyle: LineCapStyle = .butt
  open var lineJoinStyle: LineJoinStyle = .miter
  open var windingRule: WindingRule = .nonZero
  open var miterLimit: CGFloat = 10
  open var flatness: CGFloat = 0.6
  open var isEmpty: Bool { true }
  open var currentPoint: NSPoint { .zero }
  open var bounds: NSRect { .zero }
  open var controlPointBounds: NSRect { .zero }
  open var elementCount: Int { 0 }
  open var reversed: NSBezierPath { self }
  open var flattened: NSBezierPath { self }
  open func move(to point: NSPoint) {}
  open func line(to point: NSPoint) {}
  open func curve(to endPoint: NSPoint, controlPoint1: NSPoint, controlPoint2: NSPoint) {}
  open func curve(to endPoint: NSPoint, controlPoint: NSPoint) {}
  open func relativeMove(to point: NSPoint) {}
  open func relativeLine(to point: NSPoint) {}
  open func close() {}
  open func removeAllPoints() {}
  open func setLineDash(_ pattern: UnsafePointer<CGFloat>?, count: Int, phase: CGFloat) {}
  open func stroke() {}
  open func fill() {}
  open func addClip() {}
  open func setClip() {}
  open func transform(using transform: AffineTransform) {}
  open func append(_ path: NSBezierPath) {}
  open func appendRect(_ rect: NSRect) {}
  open func appendOval(in rect: NSRect) {}
  open func appendRoundedRect(_ rect: NSRect, xRadius: CGFloat, yRadius: CGFloat) {}
  open func appendArc(withCenter center: NSPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, clockwise: Bool) {}
  open func appendArc(withCenter center: NSPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat) {}
  open func appendArc(from point1: NSPoint, to point2: NSPoint, radius: CGFloat) {}
  open func contains(_ point: NSPoint) -> Bool { false }
  open func element(at index: Int) -> ElementType { .moveTo }
  open func element(at index: Int, associatedPoints points: UnsafeMutablePointer<NSPoint>?) -> ElementType { .moveTo }
}
extension CGRect {
  public func fill(using operation: NSCompositingOperation = .copy) {}
  public func frame(withWidth width: CGFloat = 1, using operation: NSCompositingOperation = .copy) {}
  public func clip() {}
}
public func NSRectFill(_ rect: NSRect) {}
public func NSRectFillUsingOperation(_ rect: NSRect, _ op: NSCompositingOperation) {}
public func NSFrameRect(_ rect: NSRect) {}
public func NSFrameRectWithWidth(_ rect: NSRect, _ frameWidth: CGFloat) {}
public func NSRectClip(_ rect: NSRect) {}

open class NSShadow: NSObject {
  open var shadowOffset = NSSize.zero
  open var shadowBlurRadius: CGFloat = 0
  open var shadowColor: NSColor?
  open func set() {}
}
open class NSGradient: NSObject {
  public struct DrawingOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let drawsBeforeStartingLocation = DrawingOptions(rawValue: 1)
    public static let drawsAfterEndingLocation = DrawingOptions(rawValue: 2)
  }
  public convenience init?(starting startingColor: NSColor, ending endingColor: NSColor) { self.init() }
  public convenience init?(colors colorArray: [NSColor]) { self.init() }
  public convenience init?(colors colorArray: [NSColor], atLocations locations: UnsafePointer<CGFloat>?, colorSpace: NSColorSpace) { self.init() }
  open func draw(in rect: NSRect, angle: CGFloat) {}
  open func draw(in path: NSBezierPath, angle: CGFloat) {}
  open func draw(from startingPoint: NSPoint, to endingPoint: NSPoint, options: DrawingOptions = []) {}
  open func draw(in rect: NSRect, relativeCenterPosition: NSPoint) {}
}

open class NSCursor: NSObject {
  public init(image newImage: NSImage, hotSpot point: NSPoint) {}
  override init() {}
  open class var current: NSCursor { NSCursor() }
  open class var currentSystem: NSCursor? { nil }
  open class var arrow: NSCursor { NSCursor() }
  open class var iBeam: NSCursor { NSCursor() }
  open class var pointingHand: NSCursor { NSCursor() }
  open class var closedHand: NSCursor { NSCursor() }
  open class var openHand: NSCursor { NSCursor() }
  open class var resizeLeft: NSCursor { NSCursor() }
  open class var resizeRight: NSCursor { NSCursor() }
  open class var resizeLeftRight: NSCursor { NSCursor() }
  open class var resizeUp: NSCursor { NSCursor() }
  open class var resizeDown: NSCursor { NSCursor() }
  open class var resizeUpDown: NSCursor { NSCursor() }
  open class var crosshair: NSCursor { NSCursor() }
  open class var disappearingItem: NSCursor { NSCursor() }
  open class var operationNotAllowed: NSCursor { NSCursor() }
  open class var dragLink: NSCursor { NSCursor() }
  open class var dragCopy: NSCursor { NSCursor() }
  open class var contextualMenu: NSCursor { NSCursor() }
  open class func hide() {}
  open class func unhide() {}
  open class func setHiddenUntilMouseMoves(_ flag: Bool) {}
  open class func pop() {}
  open var image: NSImage { NSImage() }
  open var hotSpot: NSPoint { .zero }
  open func push() {}
  open func pop() {}
  open func set() {}
}

open class NSAppearance: NSObject, @unchecked Sendable {
  public struct Name: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let aqua = Name("NSAppearanceNameAqua")
    public static let darkAqua = Name("NSAppearanceNameDarkAqua")
    public static let vibrantLight = Name("NSAppearanceNameVibrantLight")
    public static let vibrantDark = Name("NSAppearanceNameVibrantDark")
    public static let accessibilityHighContrastAqua = Name("NSAppearanceNameAccessibilityAqua")
    public static let accessibilityHighContrastDarkAqua = Name("NSAppearanceNameAccessibilityDarkAqua")
  }
  public override init() {}
  public convenience init?(named name: Name) { self.init() }
  open var name: Name { .aqua }
  open var allowsVibrancy: Bool { false }
  open class var currentDrawing: NSAppearance { NSAppearance() }
  open func bestMatch(from appearances: [Name]) -> Name? { nil }
  open func performAsCurrentDrawingAppearance(_ block: () -> Void) {}
}

// MARK: Text

extension NSAttributedString.Key {
  public static let font = NSAttributedString.Key("NSFont")
  public static let paragraphStyle = NSAttributedString.Key("NSParagraphStyle")
  public static let foregroundColor = NSAttributedString.Key("NSColor")
  public static let backgroundColor = NSAttributedString.Key("NSBackgroundColor")
  public static let ligature = NSAttributedString.Key("NSLigature")
  public static let kern = NSAttributedString.Key("NSKern")
  public static let tracking = NSAttributedString.Key("NSTracking")
  public static let strikethroughStyle = NSAttributedString.Key("NSStrikethrough")
  public static let underlineStyle = NSAttributedString.Key("NSUnderline")
  public static let underlineColor = NSAttributedString.Key("NSUnderlineColor")
  public static let strokeColor = NSAttributedString.Key("NSStrokeColor")
  public static let strokeWidth = NSAttributedString.Key("NSStrokeWidth")
  public static let shadow = NSAttributedString.Key("NSShadow")
  public static let attachment = NSAttributedString.Key("NSAttachment")
  public static let link = NSAttributedString.Key("NSLink")
  public static let baselineOffset = NSAttributedString.Key("NSBaselineOffset")
  public static let toolTip = NSAttributedString.Key("NSToolTip")
}
public struct NSUnderlineStyle: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let single = NSUnderlineStyle(rawValue: 1)
  public static let thick = NSUnderlineStyle(rawValue: 2)
  public static let double = NSUnderlineStyle(rawValue: 9)
}
public enum NSTextAlignment: Int, Sendable { case left = 0, right = 1, center = 2, justified = 3, natural = 4 }
public enum NSLineBreakMode: UInt, Sendable {
  case byWordWrapping = 0, byCharWrapping, byClipping, byTruncatingHead, byTruncatingTail, byTruncatingMiddle
}
public enum NSWritingDirection: Int, Sendable { case natural = -1, leftToRight = 0, rightToLeft = 1 }
open class NSParagraphStyle: NSObject, @unchecked Sendable {
  open class var `default`: NSParagraphStyle { NSParagraphStyle() }
  open var lineSpacing: CGFloat { 0 }
  open var alignment: NSTextAlignment { .natural }
  open var lineBreakMode: NSLineBreakMode { .byWordWrapping }
}
open class NSMutableParagraphStyle: NSParagraphStyle, @unchecked Sendable {
  open override var lineSpacing: CGFloat {
    get { 0 }
    set {}
  }
  open override var alignment: NSTextAlignment {
    get { .natural }
    set {}
  }
  open override var lineBreakMode: NSLineBreakMode {
    get { .byWordWrapping }
    set {}
  }
  open var paragraphSpacing: CGFloat = 0
  open var paragraphSpacingBefore: CGFloat = 0
  open var firstLineHeadIndent: CGFloat = 0
  open var headIndent: CGFloat = 0
  open var tailIndent: CGFloat = 0
  open var minimumLineHeight: CGFloat = 0
  open var maximumLineHeight: CGFloat = 0
  open var lineHeightMultiple: CGFloat = 0
  open var baseWritingDirection: NSWritingDirection = .natural
  open var tabStops: [NSTextTab]! = []
  open var defaultTabInterval: CGFloat = 0
}
open class NSTextTab: NSObject {
  public struct OptionKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
  }
  public init(textAlignment alignment: NSTextAlignment, location loc: CGFloat, options: [OptionKey: Any] = [:]) {}
}
public struct NSStringDrawingOptions: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let usesLineFragmentOrigin = NSStringDrawingOptions(rawValue: 1)
  public static let usesFontLeading = NSStringDrawingOptions(rawValue: 2)
  public static let usesDeviceMetrics = NSStringDrawingOptions(rawValue: 8)
  public static let truncatesLastVisibleLine = NSStringDrawingOptions(rawValue: 32)
}
open class NSStringDrawingContext: NSObject {}
extension NSString {
  public typealias DrawingOptions = NSStringDrawingOptions
  public func size(withAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> NSSize { .zero }
  public func draw(at point: NSPoint, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {}
  public func draw(in rect: NSRect, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {}
  public func draw(with rect: NSRect, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil) {}
  public func draw(
    with rect: NSRect, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil, context: NSStringDrawingContext?) {}
  public func boundingRect(with size: NSSize, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil) -> NSRect {
    .zero
  }
  public func boundingRect(
    with size: NSSize, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil, context: NSStringDrawingContext?
  ) -> NSRect { .zero }
}
extension NSAttributedString {
  public func size() -> NSSize { .zero }
  public func draw(at point: NSPoint) {}
  public func draw(in rect: NSRect) {}
  public func draw(with rect: NSRect, options: NSStringDrawingOptions = []) {}
  public func draw(with rect: NSRect, options: NSStringDrawingOptions = [], context: NSStringDrawingContext?) {}
  public func boundingRect(with size: NSSize, options: NSStringDrawingOptions = []) -> NSRect { .zero }
  public func boundingRect(with size: NSSize, options: NSStringDrawingOptions = [], context: NSStringDrawingContext?) -> NSRect { .zero }
}
// On the Mac a String finds NSString's members by bridging.
extension String {
  public func size(withAttributes attrs: [NSAttributedString.Key: Any]? = nil) -> NSSize { .zero }
  public func draw(at point: NSPoint, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {}
  public func draw(in rect: NSRect, withAttributes attrs: [NSAttributedString.Key: Any]? = nil) {}
  public func draw(with rect: NSRect, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil) {}
  public func boundingRect(with size: NSSize, options: NSStringDrawingOptions = [], attributes: [NSAttributedString.Key: Any]? = nil) -> NSRect {
    .zero
  }
}
extension NSAffineTransform {
  public func concat() {}
  public func set() {}
  public func transform(_ path: NSBezierPath) -> NSBezierPath { path }
}
