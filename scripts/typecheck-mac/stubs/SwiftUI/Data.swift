// A stand-in for SwiftUI: where a view's data lives. The property wrappers, bindings, the environment, preferences. See SwiftUI.swift.
import MacFoundation

public protocol DynamicProperty {
  mutating func update()
}
extension DynamicProperty {
  public mutating func update() {}
}

// MARK: State and bindings

@propertyWrapper public struct State<Value>: DynamicProperty {
  public init(wrappedValue value: Value) {}
  public init(initialValue value: Value) {}
  public var wrappedValue: Value {
    get { fatalError() }
    nonmutating set {}
  }
  public var projectedValue: Binding<Value> { fatalError() }
}
extension State: Sendable where Value: Sendable {}
extension State where Value: ExpressibleByNilLiteral {
  public init() {}
}

/// The closures are `@Sendable` in the SDK, so they are not on the main actor merely because the view that makes them is. `@preconcurrency`
/// turns what follows from that into warnings: reading a view's `@State` or a main-actor model in them is reported here as on the Mac,
/// and compiles. `{ @MainActor in … }` is silent in both places.
@propertyWrapper @dynamicMemberLookup public struct Binding<Value> {
  public var transaction: Transaction
  @preconcurrency public init(get: @escaping @isolated(any) @Sendable () -> Value, set: @escaping @isolated(any) @Sendable (Value) -> Void) {
    fatalError()
  }
  @preconcurrency public init(
    get: @escaping @isolated(any) @Sendable () -> Value, set: @escaping @isolated(any) @Sendable (Value, Transaction) -> Void
  ) { fatalError() }
  public init(projectedValue: Binding<Value>) { self = projectedValue }
  public static func constant(_ value: Value) -> Binding<Value> { fatalError() }
  public var wrappedValue: Value {
    get { fatalError() }
    nonmutating set {}
  }
  public var projectedValue: Binding<Value> { self }
  public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> { fatalError() }
}
extension Binding: @unchecked Sendable where Value: Sendable {}
extension Binding: DynamicProperty {}
extension Binding {
  public init<V>(_ base: Binding<V>) where Value == V? { fatalError() }
  public init?(_ base: Binding<Value?>) { fatalError() }
  public init<V: Hashable>(_ base: Binding<V>) where Value == AnyHashable { fatalError() }
  public func transaction(_ transaction: Transaction) -> Binding<Value> { self }
  public func animation(_ animation: Animation? = .default) -> Binding<Value> { self }
}
extension Binding: Identifiable where Value: Identifiable {
  public var id: Value.ID { wrappedValue.id }
}
extension Binding: Sequence where Value: MutableCollection {
  public typealias Element = Binding<Value.Element>
  public typealias Iterator = IndexingIterator<Binding<Value>>
  public typealias SubSequence = Slice<Binding<Value>>
}
extension Binding: Collection where Value: MutableCollection {
  public typealias Index = Value.Index
  public typealias Indices = Value.Indices
  public var startIndex: Value.Index { wrappedValue.startIndex }
  public var endIndex: Value.Index { wrappedValue.endIndex }
  public var indices: Value.Indices { wrappedValue.indices }
  public func index(after i: Value.Index) -> Value.Index { i }
  public func formIndex(after i: inout Value.Index) {}
  public subscript(position: Value.Index) -> Binding<Value.Element> { fatalError() }
}
extension Binding: BidirectionalCollection where Value: BidirectionalCollection, Value: MutableCollection {
  public func index(before i: Value.Index) -> Value.Index { i }
  public func formIndex(before i: inout Value.Index) {}
}
extension Binding: RandomAccessCollection where Value: MutableCollection, Value: RandomAccessCollection {}

@propertyWrapper @dynamicMemberLookup public struct Bindable<Value> {
  public var wrappedValue: Value
  public var projectedValue: Bindable<Value> { self }
  @available(*, unavailable, message: "The wrapped value must be an object that conforms to Observable")
  public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
  @available(*, unavailable, message: "The wrapped value must be an object that conforms to Observable")
  public init(projectedValue: Bindable<Value>) { self = projectedValue }
}
extension Bindable where Value: AnyObject {
  public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> { fatalError() }
}
extension Bindable where Value: AnyObject, Value: Observable {
  public init(wrappedValue: Value) { fatalError() }
  public init(_ wrappedValue: Value) { fatalError() }
  public init(projectedValue: Bindable<Value>) { self = projectedValue }
}
extension Bindable: Identifiable where Value: Identifiable {
  public var id: Value.ID { wrappedValue.id }
}
extension Bindable: Sendable where Value: Sendable {}

// MARK: Observable objects

@propertyWrapper public struct ObservedObject<ObjectType: ObservableObject>: DynamicProperty {
  @MainActor @preconcurrency @dynamicMemberLookup public struct Wrapper {
    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> { fatalError() }
  }
  public init(initialValue: ObjectType) {}
  public init(wrappedValue: ObjectType) {}
  @MainActor @preconcurrency public var wrappedValue: ObjectType {
    get { fatalError() }
    set {}
  }
  @MainActor @preconcurrency public var projectedValue: Wrapper { Wrapper() }
}
@propertyWrapper public struct StateObject<ObjectType: ObservableObject>: DynamicProperty {
  public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) {}
  @MainActor @preconcurrency public var wrappedValue: ObjectType { fatalError() }
  @MainActor @preconcurrency public var projectedValue: ObservedObject<ObjectType>.Wrapper { fatalError() }
}
@propertyWrapper public struct EnvironmentObject<ObjectType: ObservableObject>: DynamicProperty {
  @MainActor @preconcurrency @dynamicMemberLookup public struct Wrapper {
    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> { fatalError() }
  }
  public init() {}
  @MainActor @preconcurrency public var wrappedValue: ObjectType { fatalError() }
  @MainActor @preconcurrency public var projectedValue: Wrapper { Wrapper() }
}

// MARK: User defaults and scenes

@propertyWrapper public struct AppStorage<Value>: DynamicProperty {
  init(_made: Void) {}
  public var wrappedValue: Value {
    get { fatalError() }
    nonmutating set {}
  }
  public var projectedValue: Binding<Value> { fatalError() }
}
extension AppStorage: Sendable where Value: Sendable {}
extension AppStorage {
  public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Bool {}
  public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Int {}
  public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Double {}
  public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == String {}
  public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == URL {}
  public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Data {}
  public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == Int {}
  public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == String {}
  public init<R: RawRepresentable>(_ key: String, store: UserDefaults? = nil) where Value == R?, R.RawValue == String {}
  public init<R: RawRepresentable>(_ key: String, store: UserDefaults? = nil) where Value == R?, R.RawValue == Int {}
}
extension AppStorage where Value: ExpressibleByNilLiteral {
  public init(_ key: String, store: UserDefaults? = nil) where Value == Bool? {}
  public init(_ key: String, store: UserDefaults? = nil) where Value == Int? {}
  public init(_ key: String, store: UserDefaults? = nil) where Value == Double? {}
  public init(_ key: String, store: UserDefaults? = nil) where Value == String? {}
  public init(_ key: String, store: UserDefaults? = nil) where Value == URL? {}
  public init(_ key: String, store: UserDefaults? = nil) where Value == Data? {}
}
@propertyWrapper public struct SceneStorage<Value>: DynamicProperty {
  init(_made: Void) {}
  public var wrappedValue: Value {
    get { fatalError() }
    nonmutating set {}
  }
  public var projectedValue: Binding<Value> { fatalError() }
}
extension SceneStorage {
  public init(wrappedValue: Value, _ key: String) where Value == Bool {}
  public init(wrappedValue: Value, _ key: String) where Value == Int {}
  public init(wrappedValue: Value, _ key: String) where Value == Double {}
  public init(wrappedValue: Value, _ key: String) where Value == String {}
  public init(wrappedValue: Value, _ key: String) where Value == URL {}
  public init(wrappedValue: Value, _ key: String) where Value == Data {}
  public init(wrappedValue: Value, _ key: String) where Value: RawRepresentable, Value.RawValue == Int {}
  public init(wrappedValue: Value, _ key: String) where Value: RawRepresentable, Value.RawValue == String {}
}
extension SceneStorage where Value: ExpressibleByNilLiteral {
  public init(_ key: String) where Value == Bool? {}
  public init(_ key: String) where Value == Int? {}
  public init(_ key: String) where Value == Double? {}
  public init(_ key: String) where Value == String? {}
  public init(_ key: String) where Value == URL? {}
  public init(_ key: String) where Value == Data? {}
}

// MARK: Focus

@propertyWrapper public struct FocusState<Value: Hashable>: DynamicProperty {
  @propertyWrapper public struct Binding {
    init(_made: Void) {}
    public var wrappedValue: Value {
      get { fatalError() }
      nonmutating set {}
    }
    public var projectedValue: FocusState<Value>.Binding { self }
  }
  public init() where Value == Bool {}
  public init<T: Hashable>() where Value == T? {}
  public var wrappedValue: Value {
    get { fatalError() }
    nonmutating set {}
  }
  public var projectedValue: FocusState<Value>.Binding { Binding(_made: ()) }
}
public protocol FocusedValueKey {
  associatedtype Value
}
public struct FocusedValues {
  public subscript<Key: FocusedValueKey>(key: Key.Type) -> Key.Value? {
    get { nil }
    set {}
  }
}
@propertyWrapper public struct FocusedValue<Value>: DynamicProperty {
  public init(_ keyPath: KeyPath<FocusedValues, Value?>) {}
  public init(_ objectType: Value.Type) where Value: AnyObject, Value: Observable {}
  public var wrappedValue: Value? { nil }
}
@propertyWrapper public struct FocusedBinding<Value>: DynamicProperty {
  public init(_ keyPath: KeyPath<FocusedValues, Binding<Value>?>) {}
  public var wrappedValue: Value? {
    get { nil }
    nonmutating set {}
  }
  public var projectedValue: Binding<Value?> { fatalError() }
}
@propertyWrapper public struct Namespace: DynamicProperty, Sendable {
  public struct ID: Hashable, Sendable {}
  public init() {}
  public var wrappedValue: ID { ID() }
}

// MARK: The environment

public protocol EnvironmentKey {
  associatedtype Value
  static var defaultValue: Value { get }
}
@propertyWrapper public struct Environment<Value>: DynamicProperty {
  public init(_ keyPath: KeyPath<EnvironmentValues, Value>) {}
  public init(_ objectType: Value.Type) where Value: AnyObject, Value: Observable {}
  public init<T: AnyObject & Observable>(_ objectType: T.Type) where Value == T? {}
  public var wrappedValue: Value { fatalError() }
}
extension Environment: Sendable where Value: Sendable {}

public enum ColorScheme: CaseIterable, Hashable, Sendable { case light, dark }
public enum ColorSchemeContrast: CaseIterable, Hashable, Sendable { case standard, increased }
public enum ControlSize: CaseIterable, Hashable, Sendable { case mini, small, regular, large, extraLarge }
public enum ControlActiveState: CaseIterable, Hashable, Sendable { case key, active, inactive }
public enum ScenePhase: Comparable, Hashable, Sendable { case background, inactive, active }
public enum LegibilityWeight: Hashable, Sendable { case regular, bold }
public enum Visibility: CaseIterable, Hashable, Sendable { case automatic, visible, hidden }
public enum Prominence: Hashable, Sendable { case standard, increased }
public enum DynamicTypeSize: Hashable, Comparable, CaseIterable, Sendable {
  case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge, accessibility1, accessibility2, accessibility3, accessibility4, accessibility5
  public var isAccessibilitySize: Bool { false }
}
public struct RedactionReasons: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let placeholder = RedactionReasons(rawValue: 1)
  public static let privacy = RedactionReasons(rawValue: 2)
  public static let invalidated = RedactionReasons(rawValue: 4)
}
public struct ScrollIndicatorVisibility: Equatable, Sendable {
  public static var automatic: ScrollIndicatorVisibility { ScrollIndicatorVisibility() }
  public static var visible: ScrollIndicatorVisibility { ScrollIndicatorVisibility() }
  public static var hidden: ScrollIndicatorVisibility { ScrollIndicatorVisibility() }
  public static var never: ScrollIndicatorVisibility { ScrollIndicatorVisibility() }
}
public struct MenuOrder: Equatable, Hashable, Sendable {
  public static let automatic = MenuOrder()
  public static let fixed = MenuOrder()
}
public struct ButtonRepeatBehavior: Hashable, Sendable {
  public static let automatic = ButtonRepeatBehavior()
  public static let enabled = ButtonRepeatBehavior()
  public static let disabled = ButtonRepeatBehavior()
}
public struct SpringLoadingBehavior: Hashable, Sendable {
  public static let automatic = SpringLoadingBehavior()
  public static let enabled = SpringLoadingBehavior()
  public static let disabled = SpringLoadingBehavior()
}
public struct ContentTransition: Equatable, Sendable {
  public static let identity = ContentTransition()
  public static let opacity = ContentTransition()
  public static let interpolate = ContentTransition()
  public static func numericText(countsDown: Bool = false) -> ContentTransition { ContentTransition() }
}

@MainActor @preconcurrency public struct DismissAction {
  public func callAsFunction() {}
}
@MainActor @preconcurrency public struct OpenURLAction {
  public struct Result: Sendable {
    public static let handled = Result()
    public static let discarded = Result()
    public static let systemAction = Result()
    public static func systemAction(_ url: URL) -> Result { Result() }
  }
  public init(handler: @escaping (URL) -> Result) {}
  public func callAsFunction(_ url: URL) {}
  public func callAsFunction(_ url: URL, completion: @escaping (_ accepted: Bool) -> Void) {}
}
@MainActor @preconcurrency public struct OpenWindowAction {
  public func callAsFunction<D: Codable & Hashable>(value: D) {}
  public func callAsFunction(id: String) {}
  public func callAsFunction<D: Codable & Hashable>(id: String, value: D) {}
}
@MainActor @preconcurrency public struct DismissWindowAction {
  public func callAsFunction() {}
  public func callAsFunction(id: String) {}
  public func callAsFunction<D: Codable & Hashable>(value: D) {}
  public func callAsFunction<D: Codable & Hashable>(id: String, value: D) {}
}
@MainActor @preconcurrency public struct OpenSettingsAction {
  public func callAsFunction() {}
}
@MainActor @preconcurrency public struct DismissSearchAction {
  public func callAsFunction() {}
}
public struct RefreshAction: Sendable {
  public func callAsFunction() async {}
}
public struct RenameAction {
  public func callAsFunction() {}
}
public struct ResetFocusAction {
  public func callAsFunction(in namespace: Namespace.ID) {}
}
@available(*, deprecated, message: "Use EnvironmentValues.isPresented or EnvironmentValues.dismiss")
public struct PresentationMode {
  public var isPresented: Bool { false }
  public mutating func dismiss() {}
}

/// The keys of macOS 14. `@Entry`, which declares a new one in a line, is a macro and so not here: write the `EnvironmentKey` out.
public struct EnvironmentValues: CustomStringConvertible {
  public init() {}
  public var description: String { "" }
  public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
    get { K.defaultValue }
    set {}
  }
  public subscript<T: AnyObject & Observable>(objectType: T.Type) -> T? {
    get { nil }
    set {}
  }

  public var colorScheme: ColorScheme = .light
  public var colorSchemeContrast: ColorSchemeContrast { .standard }
  public var locale = Locale.current
  public var calendar = Calendar.current
  public var timeZone = TimeZone.current
  public var layoutDirection: LayoutDirection = .leftToRight
  public var displayScale: CGFloat = 1
  public var pixelLength: CGFloat { 1 }
  public var imageScale: Image.Scale = .medium
  public var font: Font?
  public var legibilityWeight: LegibilityWeight?
  public var dynamicTypeSize: DynamicTypeSize = .large
  public var lineLimit: Int?
  public var lineSpacing: CGFloat = 0
  public var multilineTextAlignment: TextAlignment = .leading
  public var truncationMode: Text.TruncationMode = .tail
  public var minimumScaleFactor: CGFloat = 1
  public var allowsTightening = false
  public var textCase: Text.Case?
  public var autocorrectionDisabled = false
  public var symbolRenderingMode: SymbolRenderingMode?
  public var symbolVariants: SymbolVariants = .none
  public var redactionReasons: RedactionReasons = []
  public var contentTransition: ContentTransition = .identity
  public var contentTransitionAddsDrawingGroup = false
  public var backgroundMaterial: Material?
  public var backgroundStyle: AnyShapeStyle?

  public var isEnabled = true
  public var isFocused: Bool { false }
  public var isPresented: Bool { false }
  public var isSearching: Bool { false }
  public var isScrollEnabled = true
  public var controlSize: ControlSize = .regular
  public var controlActiveState: ControlActiveState = .key
  public var scenePhase: ScenePhase = .active
  public var headerProminence: Prominence = .standard
  public var menuIndicatorVisibility: Visibility = .automatic
  public var menuOrder: MenuOrder = .automatic
  public var buttonRepeatBehavior: ButtonRepeatBehavior { .automatic }
  public var springLoadingBehavior: SpringLoadingBehavior { .automatic }
  public var keyboardShortcut: KeyboardShortcut? { nil }
  public var horizontalScrollIndicatorVisibility: ScrollIndicatorVisibility = .automatic
  public var verticalScrollIndicatorVisibility: ScrollIndicatorVisibility = .automatic
  public var defaultMinListRowHeight: CGFloat = 0
  public var defaultMinListHeaderHeight: CGFloat?
  public var supportsMultipleWindows: Bool { true }
  public var undoManager: UndoManager? { nil }

  public var dismiss: DismissAction { fatalError() }
  public var dismissSearch: DismissSearchAction { fatalError() }
  public var dismissWindow: DismissWindowAction { fatalError() }
  public var openURL: OpenURLAction {
    get { fatalError() }
    set {}
  }
  public var openWindow: OpenWindowAction { fatalError() }
  public var openSettings: OpenSettingsAction { fatalError() }
  public var refresh: RefreshAction? { nil }
  public var rename: RenameAction? { nil }
  public var resetFocus: ResetFocusAction { ResetFocusAction() }
  @available(*, deprecated, message: "Use isPresented or dismiss")
  public var presentationMode: Binding<PresentationMode> { fatalError() }

  public var accessibilityEnabled = false
  public var accessibilityReduceMotion: Bool { false }
  public var accessibilityReduceTransparency: Bool { false }
  public var accessibilityDifferentiateWithoutColor: Bool { false }
  public var accessibilityInvertColors: Bool { false }
  public var accessibilityShowButtonShapes: Bool { false }
  public var accessibilityDimFlashingLights: Bool { false }
  public var accessibilityPlayAnimatedImages: Bool { true }
  public var accessibilityVoiceOverEnabled: Bool { false }
  public var accessibilitySwitchControlEnabled: Bool { false }
}

nonisolated extension View {
  public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some View { self }
  public func environment<T: AnyObject & Observable>(_ object: T?) -> some View { self }
  public func environmentObject<T: ObservableObject>(_ object: T) -> some View { self }
  public func transformEnvironment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, transform: @escaping (inout V) -> Void) -> some View {
    self
  }
  public func defaultAppStorage(_ store: UserDefaults) -> some View { self }
}

// MARK: Preferences

public protocol PreferenceKey {
  associatedtype Value
  static var defaultValue: Value { get }
  static func reduce(value: inout Value, nextValue: () -> Value)
}
extension PreferenceKey where Value: ExpressibleByNilLiteral {
  public static var defaultValue: Value { nil }
}
nonisolated extension View {
  public func preference<K: PreferenceKey>(key: K.Type = K.self, value: K.Value) -> some View { self }
  public func transformPreference<K: PreferenceKey>(_ key: K.Type = K.self, _ callback: @escaping (inout K.Value) -> Void) -> some View { self }
  /// `@Sendable` since the macOS 15.2 SDK: hop to the main actor inside it, or change only a `Binding`.
  public func onPreferenceChange<K: PreferenceKey>(
    _ key: K.Type = K.self, perform action: @escaping @Sendable (K.Value) -> Void
  ) -> some View where K.Value: Equatable { self }
  public func anchorPreference<A, K: PreferenceKey>(
    key _: K.Type = K.self, value: Anchor<A>.Source, transform: @escaping (Anchor<A>) -> K.Value
  ) -> some View { self }
  public func transformAnchorPreference<A, K: PreferenceKey>(
    key _: K.Type = K.self, value: Anchor<A>.Source, transform: @escaping (inout K.Value, Anchor<A>) -> Void
  ) -> some View { self }
  public func backgroundPreferenceValue<Key: PreferenceKey, T: View>(
    _ key: Key.Type = Key.self, @ViewBuilder _ transform: @escaping (Key.Value) -> T
  ) -> some View { self }
  public func backgroundPreferenceValue<K: PreferenceKey, V: View>(
    _ key: K.Type, alignment: Alignment = .center, @ViewBuilder _ transform: @escaping (K.Value) -> V
  ) -> some View { self }
  public func overlayPreferenceValue<Key: PreferenceKey, T: View>(
    _ key: Key.Type = Key.self, @ViewBuilder _ transform: @escaping (Key.Value) -> T
  ) -> some View { self }
  public func overlayPreferenceValue<K: PreferenceKey, V: View>(
    _ key: K.Type, alignment: Alignment = .center, @ViewBuilder _ transform: @escaping (K.Value) -> V
  ) -> some View { self }
}
