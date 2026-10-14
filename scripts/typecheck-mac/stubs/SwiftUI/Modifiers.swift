// A stand-in for SwiftUI: the modifiers every view has, by what they are about. Those that belong to one kind of view or to a topic with a file
// of its own (lists, navigation, animation, the environment, styles, presentation, accessibility, gestures) are declared there.
// All are `nonisolated`, as in the SDK, and most return `some View`. See SwiftUI.swift.

// MARK: Size and position

nonisolated extension View {
  public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View { self }
  @available(*, deprecated, message: "Please pass one or more parameters.")
  public func frame() -> some View { self }
  public func frame(
    minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil,
    maxHeight: CGFloat? = nil, alignment: Alignment = .center
  ) -> some View { self }
  public func containerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center) -> some View { self }
  public func containerRelativeFrame(_ axes: Axis.Set, count: Int, span: Int = 1, spacing: CGFloat, alignment: Alignment = .center) -> some View {
    self
  }
  public func containerRelativeFrame(
    _ axes: Axis.Set, alignment: Alignment = .center, _ length: @escaping (CGFloat, Axis) -> CGFloat
  ) -> some View { self }
  public func fixedSize() -> some View { self }
  public func fixedSize(horizontal: Bool, vertical: Bool) -> some View { self }
  public func layoutPriority(_ value: Double) -> some View { self }
  public func padding(_ insets: EdgeInsets) -> some View { self }
  public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View { self }
  public func padding(_ length: CGFloat) -> some View { self }
  public func safeAreaPadding(_ insets: EdgeInsets) -> some View { self }
  public func safeAreaPadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View { self }
  public func safeAreaPadding(_ length: CGFloat) -> some View { self }
  public func contentMargins(_ edges: Edge.Set = .all, _ insets: EdgeInsets, for placement: ContentMarginPlacement = .automatic) -> some View {
    self
  }
  public func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat?, for placement: ContentMarginPlacement = .automatic) -> some View {
    self
  }
  public func contentMargins(_ length: CGFloat, for placement: ContentMarginPlacement = .automatic) -> some View { self }
  public func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> some View { self }
  public func safeAreaInset<V: View>(
    edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V
  ) -> some View { self }
  public func safeAreaInset<V: View>(
    edge: HorizontalEdge, alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V
  ) -> some View { self }
  public func offset(_ offset: CGSize) -> some View { self }
  public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some View { self }
  public func position(_ position: CGPoint) -> some View { self }
  public func position(x: CGFloat = 0, y: CGFloat = 0) -> some View { self }
  public func aspectRatio(_ aspectRatio: CGFloat? = nil, contentMode: ContentMode) -> some View { self }
  public func aspectRatio(_ aspectRatio: CGSize, contentMode: ContentMode) -> some View { self }
  public func scaledToFit() -> some View { self }
  public func scaledToFill() -> some View { self }
  public func zIndex(_ value: Double) -> some View { self }
  /// The closures are `@Sendable` in the current SDK.
  @preconcurrency public func alignmentGuide(
    _ g: HorizontalAlignment, computeValue: @escaping @Sendable (ViewDimensions) -> CGFloat
  ) -> some View { self }
  @preconcurrency public func alignmentGuide(
    _ g: VerticalAlignment, computeValue: @escaping @Sendable (ViewDimensions) -> CGFloat
  ) -> some View { self }
  public func coordinateSpace(_ name: NamedCoordinateSpace) -> some View { self }
  @available(*, deprecated, message: "use coordinateSpace(_:) instead")
  public func coordinateSpace<T: Hashable>(name: T) -> some View { self }
  /// Back-deployed to macOS 13. What is measured is worked out off the main actor.
  public func onGeometryChange<T: Equatable & Sendable>(
    for type: T.Type, of transform: @escaping @Sendable (GeometryProxy) -> T, action: @escaping (T) -> Void
  ) -> some View { self }
  public func onGeometryChange<T: Equatable & Sendable>(
    for type: T.Type, of transform: @escaping @Sendable (GeometryProxy) -> T, action: @escaping (_ oldValue: T, _ newValue: T) -> Void
  ) -> some View { self }
}
public struct ContentMarginPlacement: Sendable {
  public static var automatic: ContentMarginPlacement { ContentMarginPlacement() }
  public static var scrollContent: ContentMarginPlacement { ContentMarginPlacement() }
  public static var scrollIndicators: ContentMarginPlacement { ContentMarginPlacement() }
}

// MARK: Behind and in front

nonisolated extension View {
  @_disfavoredOverload public func background<Background: View>(_ background: Background, alignment: Alignment = .center) -> some View { self }
  public func background<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View { self }
  public func background(ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { self }
  public func background<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { self }
  public func background<S: Shape>(in shape: S, fillStyle: FillStyle = FillStyle()) -> some View { self }
  public func background<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { self }
  public func background<S: InsettableShape>(in shape: S, fillStyle: FillStyle = FillStyle()) -> some View { self }
  public func background<S: ShapeStyle, T: InsettableShape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { self }
  public func backgroundStyle<S: ShapeStyle>(_ style: S) -> some View { self }
  @_disfavoredOverload public func overlay<Overlay: View>(_ overlay: Overlay, alignment: Alignment = .center) -> some View { self }
  public func overlay<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View { self }
  public func overlay<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { self }
  public func overlay<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { self }
  public func border<S: ShapeStyle>(_ content: S, width: CGFloat = 1) -> some View { self }
}

// MARK: Colour and drawing

nonisolated extension View {
  public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View { self }
  public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle>(_ primary: S1, _ secondary: S2) -> some View { self }
  public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle, S3: ShapeStyle>(_ primary: S1, _ secondary: S2, _ tertiary: S3) -> some View {
    self
  }
  public func foregroundColor(_ color: Color?) -> some View { self }
  public func tint<S: ShapeStyle>(_ tint: S?) -> some View { self }
  public func tint(_ tint: Color?) -> some View { self }
  @available(*, deprecated, message: "Use the asset catalog's accent color or View.tint(_:) instead.")
  public func accentColor(_ accentColor: Color?) -> some View { self }
  public func opacity(_ opacity: Double) -> some View { self }
  public func hidden() -> some View { self }
  public func clipped(antialiased: Bool = false) -> some View { self }
  public func clipShape<S: Shape>(_ shape: S, style: FillStyle = FillStyle()) -> some View { self }
  public func cornerRadius(_ radius: CGFloat, antialiased: Bool = true) -> some View { self }
  public func mask<Mask: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> Mask) -> some View { self }
  @available(*, deprecated, message: "Use overload where mask accepts a @ViewBuilder instead.")
  public func mask<Mask: View>(_ mask: Mask) -> some View { self }
  public func shadow(
    color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0
  ) -> some View { self }
  public func blur(radius: CGFloat, opaque: Bool = false) -> some View { self }
  public func brightness(_ amount: Double) -> some View { self }
  public func contrast(_ amount: Double) -> some View { self }
  public func saturation(_ amount: Double) -> some View { self }
  public func grayscale(_ amount: Double) -> some View { self }
  public func colorMultiply(_ color: Color) -> some View { self }
  public func colorInvert() -> some View { self }
  public func hueRotation(_ angle: Angle) -> some View { self }
  public func luminanceToAlpha() -> some View { self }
  public func blendMode(_ blendMode: BlendMode) -> some View { self }
  public func compositingGroup() -> some View { self }
  public func drawingGroup(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear) -> some View { self }
  public func scaleEffect(_ scale: CGSize, anchor: UnitPoint = .center) -> some View { self }
  public func scaleEffect(_ s: CGFloat, anchor: UnitPoint = .center) -> some View { self }
  public func scaleEffect(x: CGFloat = 1.0, y: CGFloat = 1.0, anchor: UnitPoint = .center) -> some View { self }
  public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View { self }
  public func rotation3DEffect(
    _ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0, perspective: CGFloat = 1
  ) -> some View { self }
  public func transformEffect(_ transform: CGAffineTransform) -> some View { self }
  public func preferredColorScheme(_ colorScheme: ColorScheme?) -> some View { self }
  @available(*, deprecated, renamed: "preferredColorScheme(_:)")
  public func colorScheme(_ colorScheme: ColorScheme) -> some View { self }
  public func redacted(reason: RedactionReasons) -> some View { self }
  public func unredacted() -> some View { self }
  public func privacySensitive(_ sensitive: Bool = true) -> some View { self }
  public func flipsForRightToLeftLayoutDirection(_ enabled: Bool) -> some View { self }
}
public enum ColorRenderingMode: Hashable, Sendable { case nonLinear, linear, extendedLinear }

// MARK: Text and symbols

nonisolated extension View {
  public func font(_ font: Font?) -> some View { self }
  public func fontWeight(_ weight: Font.Weight?) -> some View { self }
  public func fontWidth(_ width: Font.Width?) -> some View { self }
  public func fontDesign(_ design: Font.Design?) -> some View { self }
  public func bold(_ isActive: Bool = true) -> some View { self }
  public func italic(_ isActive: Bool = true) -> some View { self }
  public func monospaced(_ isActive: Bool = true) -> some View { self }
  public func monospacedDigit() -> some View { self }
  public func underline(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> some View { self }
  public func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> some View { self }
  public func kerning(_ kerning: CGFloat) -> some View { self }
  public func tracking(_ tracking: CGFloat) -> some View { self }
  public func baselineOffset(_ baselineOffset: CGFloat) -> some View { self }
  public func textCase(_ textCase: Text.Case?) -> some View { self }
  public func textScale(_ scale: Text.Scale, isEnabled: Bool = true) -> some View { self }
  public func lineLimit(_ number: Int?) -> some View { self }
  public func lineLimit(_ limit: PartialRangeFrom<Int>) -> some View { self }
  public func lineLimit(_ limit: PartialRangeThrough<Int>) -> some View { self }
  public func lineLimit(_ limit: ClosedRange<Int>) -> some View { self }
  public func lineLimit(_ limit: Int, reservesSpace: Bool) -> some View { self }
  public func lineSpacing(_ lineSpacing: CGFloat) -> some View { self }
  public func multilineTextAlignment(_ alignment: TextAlignment) -> some View { self }
  public func truncationMode(_ mode: Text.TruncationMode) -> some View { self }
  public func minimumScaleFactor(_ factor: CGFloat) -> some View { self }
  public func allowsTightening(_ flag: Bool) -> some View { self }
  public func textSelection<S: TextSelectability>(_ selectability: S) -> some View { self }
  public func autocorrectionDisabled(_ disable: Bool = true) -> some View { self }
  public func dynamicTypeSize(_ size: DynamicTypeSize) -> some View { self }
  public func dynamicTypeSize<T: RangeExpression>(_ range: T) -> some View where T.Bound == DynamicTypeSize { self }
  public func imageScale(_ scale: Image.Scale) -> some View { self }
  public func symbolVariant(_ variant: SymbolVariants) -> some View { self }
  public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> some View { self }
}

// MARK: Identity

nonisolated extension View {
  public func id<ID: Hashable>(_ id: ID) -> some View { self }
  public func tag<V: Hashable>(_ tag: V) -> some View { self }
}

// MARK: Controls

nonisolated extension View {
  public func disabled(_ disabled: Bool) -> some View { self }
  public func labelsHidden() -> some View { self }
  public func controlSize(_ controlSize: ControlSize) -> some View { self }
  public func buttonBorderShape(_ shape: ButtonBorderShape) -> some View { self }
  public func buttonRepeatBehavior(_ behavior: ButtonRepeatBehavior) -> some View { self }
  public func horizontalRadioGroupLayout() -> some View { self }
  public func menuIndicator(_ visibility: Visibility) -> some View { self }
  public func menuOrder(_ order: MenuOrder) -> some View { self }
  public func help(_ textKey: LocalizedStringKey) -> some View { self }
  public func help(_ text: Text) -> some View { self }
  @_disfavoredOverload public func help<S: StringProtocol>(_ text: S) -> some View { self }
  public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View { self }
  public func keyboardShortcut(_ shortcut: KeyboardShortcut) -> some View { self }
  public func keyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View { self }
  public func keyboardShortcut(
    _ key: KeyEquivalent, modifiers: EventModifiers = .command, localization: KeyboardShortcut.Localization
  ) -> some View { self }
  public func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> some View { self }
  public func submitScope(_ isBlocking: Bool = true) -> some View { self }
  public func submitLabel(_ submitLabel: SubmitLabel) -> some View { self }
  public func contextMenu<MenuItems: View>(@ViewBuilder menuItems: () -> MenuItems) -> some View { self }
  public func contextMenu<M: View, P: View>(@ViewBuilder menuItems: () -> M, @ViewBuilder preview: () -> P) -> some View { self }
  public func contextMenu<I: Hashable, M: View>(
    forSelectionType itemType: I.Type = I.self, @ViewBuilder menu: @escaping (Set<I>) -> M, primaryAction: ((Set<I>) -> Void)? = nil
  ) -> some View { self }
  public func searchable(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil) -> some View { self }
  public func searchable(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey) -> some View { self }
  @_disfavoredOverload public func searchable<S: StringProtocol>(
    text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: S
  ) -> some View { self }
  public func searchable(
    text: Binding<String>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil
  ) -> some View { self }
  public func refreshable(@_inheritActorContext action: @escaping @Sendable () async -> Void) -> some View { self }
}
public struct SearchFieldPlacement: Sendable {
  public static let automatic = SearchFieldPlacement()
  public static let toolbar = SearchFieldPlacement()
  public static let sidebar = SearchFieldPlacement()
}

// MARK: Focus

public struct FocusInteractions: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let activate = FocusInteractions(rawValue: 1)
  public static let edit = FocusInteractions(rawValue: 2)
  public static var automatic: FocusInteractions { FocusInteractions(rawValue: 4) }
}
public struct DefaultFocusEvaluationPriority: Sendable {
  public static let automatic = DefaultFocusEvaluationPriority()
  public static let userInitiated = DefaultFocusEvaluationPriority()
}
nonisolated extension View {
  public func focused<Value: Hashable>(_ binding: FocusState<Value>.Binding, equals value: Value) -> some View { self }
  public func focused(_ condition: FocusState<Bool>.Binding) -> some View { self }
  public func focusable(_ isFocusable: Bool = true) -> some View { self }
  public func focusable(_ isFocusable: Bool = true, interactions: FocusInteractions) -> some View { self }
  @available(*, deprecated, message: "Use FocusState or isFocused instead.")
  public func focusable(_ isFocusable: Bool = true, onFocusChange: @escaping (_ isFocused: Bool) -> Void = { _ in }) -> some View { self }
  public func focusEffectDisabled(_ disabled: Bool = true) -> some View { self }
  public func focusSection() -> some View { self }
  public func focusScope(_ namespace: Namespace.ID) -> some View { self }
  public func prefersDefaultFocus(_ prefersDefaultFocus: Bool = true, in namespace: Namespace.ID) -> some View { self }
  public func defaultFocus<V: Hashable>(
    _ binding: FocusState<V>.Binding, _ value: V, priority: DefaultFocusEvaluationPriority = .automatic
  ) -> some View { self }
  public func focusedValue<Value>(_ keyPath: WritableKeyPath<FocusedValues, Value?>, _ value: Value) -> some View { self }
  public func focusedValue<Value>(_ keyPath: WritableKeyPath<FocusedValues, Value?>, _ value: Value?) -> some View { self }
  public func focusedSceneValue<T>(_ keyPath: WritableKeyPath<FocusedValues, T?>, _ value: T) -> some View { self }
  public func focusedSceneValue<T>(_ keyPath: WritableKeyPath<FocusedValues, T?>, _ value: T?) -> some View { self }
}

// MARK: Things that happen

public enum HoverPhase: Equatable, Sendable {
  case active(CGPoint)
  case ended
}
public struct ContentShapeKinds: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let interaction = ContentShapeKinds(rawValue: 1)
  public static let dragPreview = ContentShapeKinds(rawValue: 2)
  public static let focusEffect = ContentShapeKinds(rawValue: 8)
  public static let accessibility = ContentShapeKinds(rawValue: 32)
}
nonisolated extension View {
  public func onAppear(perform action: (() -> Void)? = nil) -> some View { self }
  public func onDisappear(perform action: (() -> Void)? = nil) -> some View { self }
  public func task(
    priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void
  ) -> some View { self }
  public func task<T: Equatable>(
    id value: T, priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void
  ) -> some View { self }
  public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void) -> some View {
    self
  }
  public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some View { self }
  @available(*, deprecated, message: "Use `onChange` with a two or zero parameter action closure instead.")
  public func onChange<V: Equatable>(of value: V, perform action: @escaping (_ newValue: V) -> Void) -> some View { self }
  public func onReceive<P: Publisher>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> some View where P.Failure == Never { self }
  public func onHover(perform action: @escaping (Bool) -> Void) -> some View { self }
  public func onContinuousHover(coordinateSpace: CoordinateSpace = .local, perform action: @escaping (HoverPhase) -> Void) -> some View { self }
  public func onContinuousHover(
    coordinateSpace: some CoordinateSpaceProtocol = .local, perform action: @escaping (HoverPhase) -> Void
  ) -> some View { self }
  public func onOpenURL(perform action: @escaping (URL) -> Void) -> some View { self }
  public func handlesExternalEvents(preferring: Set<String>, allowing: Set<String>) -> some View { self }
  public func allowsHitTesting(_ enabled: Bool) -> some View { self }
  public func contentShape<S: Shape>(_ shape: S, eoFill: Bool = false) -> some View { self }
  public func contentShape<S: Shape>(_ kind: ContentShapeKinds, _ shape: S, eoFill: Bool = false) -> some View { self }
  public func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View { self }
  public func onKeyPress(_ key: KeyEquivalent, phases: KeyPress.Phases, action: @escaping (KeyPress) -> KeyPress.Result) -> some View { self }
  public func onKeyPress(
    keys: Set<KeyEquivalent>, phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result
  ) -> some View { self }
  public func onKeyPress(
    characters: CharacterSet, phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result
  ) -> some View { self }
  public func onKeyPress(phases: KeyPress.Phases = [.down, .repeat], action: @escaping (KeyPress) -> KeyPress.Result) -> some View { self }
  public func onCommand(_ selector: Selector, perform action: (() -> Void)?) -> some View { self }
  public func onExitCommand(perform action: (() -> Void)?) -> some View { self }
  public func onMoveCommand(perform action: ((MoveCommandDirection) -> Void)?) -> some View { self }
  public func onDeleteCommand(perform action: (() -> Void)?) -> some View { self }
}
