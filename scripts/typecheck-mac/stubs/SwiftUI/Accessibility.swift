// A stand-in for SwiftUI: what views tell VoiceOver. See SwiftUI.swift.
// In the SDK a view that already has an accessibility modifier gets the next one from an extension of `ModifiedContent`, which returns the same
// type again; here every one comes from `View` and wraps once more. Only code that spells such a type out could tell.

public struct AccessibilityAttachmentModifier: ViewModifier {
  public func body(content: Content) -> Never { fatalError() }
}
public struct AccessibilityTraits: SetAlgebra, Sendable {
  public init() {}
  public static let isButton = AccessibilityTraits()
  public static let isHeader = AccessibilityTraits()
  public static let isSelected = AccessibilityTraits()
  public static let isLink = AccessibilityTraits()
  public static let isSearchField = AccessibilityTraits()
  public static let isImage = AccessibilityTraits()
  public static let playsSound = AccessibilityTraits()
  public static let isKeyboardKey = AccessibilityTraits()
  public static let isStaticText = AccessibilityTraits()
  public static let isSummaryElement = AccessibilityTraits()
  public static let updatesFrequently = AccessibilityTraits()
  public static let startsMediaSession = AccessibilityTraits()
  public static let allowsDirectInteraction = AccessibilityTraits()
  public static let causesPageTurn = AccessibilityTraits()
  public static let isModal = AccessibilityTraits()
  public static let isToggle = AccessibilityTraits()
  public func contains(_ member: AccessibilityTraits) -> Bool { false }
  public func union(_ other: AccessibilityTraits) -> AccessibilityTraits { self }
  public func intersection(_ other: AccessibilityTraits) -> AccessibilityTraits { self }
  public func symmetricDifference(_ other: AccessibilityTraits) -> AccessibilityTraits { self }
  public mutating func insert(_ newMember: AccessibilityTraits) -> (inserted: Bool, memberAfterInsert: AccessibilityTraits) { (false, self) }
  public mutating func remove(_ member: AccessibilityTraits) -> AccessibilityTraits? { nil }
  public mutating func update(with newMember: AccessibilityTraits) -> AccessibilityTraits? { nil }
  public mutating func formUnion(_ other: AccessibilityTraits) {}
  public mutating func formIntersection(_ other: AccessibilityTraits) {}
  public mutating func formSymmetricDifference(_ other: AccessibilityTraits) {}
}
public struct AccessibilityChildBehavior: Hashable, Sendable {
  public static let ignore = AccessibilityChildBehavior()
  public static let contain = AccessibilityChildBehavior()
  public static let combine = AccessibilityChildBehavior()
}
public struct AccessibilityActionKind: Equatable, Sendable {
  public static let `default` = AccessibilityActionKind()
  public static let escape = AccessibilityActionKind()
  public static let delete = AccessibilityActionKind()
  public static let showMenu = AccessibilityActionKind()
  init() {}
  public init(named name: Text) {}
}
public enum AccessibilityAdjustmentDirection: Hashable, Sendable { case increment, decrement }
public enum AccessibilityHeadingLevel: UInt, Hashable, Sendable { case unspecified, h1, h2, h3, h4, h5, h6 }
public struct AccessibilityTextContentType: Sendable {
  public static let plain = AccessibilityTextContentType()
  public static let console = AccessibilityTextContentType()
  public static let fileSystem = AccessibilityTextContentType()
  public static let messaging = AccessibilityTextContentType()
  public static let narrative = AccessibilityTextContentType()
  public static let sourceCode = AccessibilityTextContentType()
  public static let spreadsheet = AccessibilityTextContentType()
  public static let wordProcessing = AccessibilityTextContentType()
}
public enum AccessibilityLabeledPairRole: Hashable, Sendable { case label, content }
@propertyWrapper public struct AccessibilityFocusState<Value: Hashable>: DynamicProperty {
  @propertyWrapper public struct Binding {
    init(_made: Void) {}
    public var wrappedValue: Value {
      get { fatalError() }
      nonmutating set {}
    }
    public var projectedValue: AccessibilityFocusState<Value>.Binding { self }
  }
  public init() where Value == Bool {}
  public init<T: Hashable>() where Value == T? {}
  public var wrappedValue: Value {
    get { fatalError() }
    nonmutating set {}
  }
  public var projectedValue: AccessibilityFocusState<Value>.Binding { Binding(_made: ()) }
}

nonisolated extension View {
  public func accessibilityLabel(_ label: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  @_disfavoredOverload public func accessibilityLabel<S: StringProtocol>(_ label: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
    fatalError()
  }
  public func accessibilityValue(_ valueDescription: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityValue(_ valueKey: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  @_disfavoredOverload public func accessibilityValue<S: StringProtocol>(_ value: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
    fatalError()
  }
  public func accessibilityHint(_ hint: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityHint(_ hintKey: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  @_disfavoredOverload public func accessibilityHint<S: StringProtocol>(_ hint: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
    fatalError()
  }
  public func accessibilityInputLabels(_ inputLabels: [Text]) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityInputLabels(_ inputLabelKeys: [LocalizedStringKey]) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
    fatalError()
  }
  public func accessibilityHidden(_ hidden: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityIdentifier(_ identifier: String) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilitySortPriority(_ sortPriority: Double) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityTextContentType(_ value: AccessibilityTextContentType) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
    fatalError()
  }
  public func accessibilityRespondsToUserInteraction(
    _ respondsToUserInteraction: Bool = true
  ) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityActivationPoint(_ activationPoint: CGPoint) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityActivationPoint(_ activationPoint: UnitPoint) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityAction(
    _ actionKind: AccessibilityActionKind = .default, _ handler: @escaping () -> Void
  ) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityAction(named name: Text, _ handler: @escaping () -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
    fatalError()
  }
  public func accessibilityAction(
    named nameKey: LocalizedStringKey, _ handler: @escaping () -> Void
  ) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  @_disfavoredOverload public func accessibilityAction<S: StringProtocol>(
    named name: S, _ handler: @escaping () -> Void
  ) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityAdjustableAction(
    _ handler: @escaping (AccessibilityAdjustmentDirection) -> Void
  ) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { fatalError() }
  public func accessibilityScrollAction(_ handler: @escaping (Edge) -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> {
    fatalError()
  }

  public func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View { self }
  public func accessibilityChildren<V: View>(@ViewBuilder children: () -> V) -> some View { self }
  public func accessibilityRepresentation<V: View>(@ViewBuilder representation: () -> V) -> some View { self }
  public func accessibilityFocused<Value: Hashable>(_ binding: AccessibilityFocusState<Value>.Binding, equals value: Value) -> some View { self }
  public func accessibilityFocused(_ condition: AccessibilityFocusState<Bool>.Binding) -> some View { self }
  public func accessibilityLabeledPair<ID: Hashable>(role: AccessibilityLabeledPairRole, id: ID, in namespace: Namespace.ID) -> some View { self }
  public func accessibilityLinkedGroup<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View { self }
  public func accessibilityShowsLargeContentViewer() -> some View { self }
  public func accessibilityIgnoresInvertColors(_ active: Bool = true) -> some View { self }
}
