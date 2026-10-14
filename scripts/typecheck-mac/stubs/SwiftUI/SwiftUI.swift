// A stand-in for SwiftUI (scripts/typecheck-mac/README.md). Never shipped, never run. Names, labels, generics, builders and actor isolation as
// the macOS 14 API looks in the current SDK: `View` and its kin are main-actor protocols, the modifiers are `nonisolated`.
// This file: views, view builders, view modifiers, and the views everything else is made of.
//
// On a Mac `import SwiftUI` also brings Combine, Observation, CoreGraphics and Foundation, but not AppKit.
@_exported import Combine
@_exported import CoreGraphics
@_exported import Foundation
@_exported import Observation

// MARK: View

@MainActor @preconcurrency public protocol View {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency var body: Self.Body { get }
}

/// A view that SwiftUI draws itself. Not in the SDK, where each such view has a `body` nobody can see; a protocol of their own keeps
/// `struct Mine: View {}` an error here as there.
public protocol _PrimitiveView: View where Body == Never {}
extension _PrimitiveView {
  public nonisolated var body: Never { fatalError() }
}

extension Never: View {
  public typealias Body = Never
  public var body: Never { fatalError() }
}
extension Optional: View where Wrapped: View {
  public typealias Body = Never
  public var body: Never { fatalError() }
}

// MARK: ViewBuilder

@resultBuilder public struct ViewBuilder {
  public static func buildExpression<Content: View>(_ content: Content) -> Content { content }
  @available(*, unavailable, message: "this expression does not conform to 'View'")
  @_disfavoredOverload public static func buildExpression(_ invalid: Any) -> some View { EmptyView() }
  public static func buildBlock() -> EmptyView { EmptyView() }
  public static func buildBlock<Content: View>(_ content: Content) -> Content { content }
  public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<(repeat each Content)> { fatalError() }
  public static func buildIf<Content: View>(_ content: Content?) -> Content? { content }
  public static func buildEither<TrueContent: View, FalseContent: View>(first: TrueContent) -> _ConditionalContent<TrueContent, FalseContent> {
    fatalError()
  }
  public static func buildEither<TrueContent: View, FalseContent: View>(second: FalseContent) -> _ConditionalContent<TrueContent, FalseContent> {
    fatalError()
  }
  public static func buildLimitedAvailability<Content: View>(_ content: Content) -> AnyView { fatalError() }
}

public struct EmptyView: _PrimitiveView, Sendable {
  public nonisolated init() {}
}
public struct TupleView<T>: _PrimitiveView {
  public var value: T
  public init(_ value: T) { self.value = value }
}
public struct _ConditionalContent<TrueContent, FalseContent> {}
extension _ConditionalContent: View, _PrimitiveView where TrueContent: View, FalseContent: View {}
public struct AnyView: _PrimitiveView {
  public init<V: View>(_ view: V) {}
  public init<V: View>(erasing view: V) {}
}
public struct EquatableView<Content: Equatable & View>: _PrimitiveView {
  public var content: Content
  public init(content: Content) { self.content = content }
}
public struct Group<Content> {}
extension Group: View, _PrimitiveView where Content: View {
  public nonisolated init(@ViewBuilder content: () -> Content) {}
}

// MARK: ForEach

public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content> {
  public var data: Data
  public var content: (Data.Element) -> Content
}
extension ForEach: View, _PrimitiveView where Content: View {}
extension ForEach where ID == Data.Element.ID, Content: View, Data.Element: Identifiable {
  public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) { fatalError() }
}
extension ForEach where Content: View {
  public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) { fatalError() }
  public init<C: MutableCollection & RandomAccessCollection>(
    _ data: Binding<C>, @ViewBuilder content: @escaping (Binding<C.Element>) -> Content
  ) where Data == LazyMapSequence<C.Indices, (C.Index, ID)>, ID == C.Element.ID, C.Element: Identifiable, C.Index: Hashable { fatalError() }
  public init<C: MutableCollection & RandomAccessCollection>(
    _ data: Binding<C>, id: KeyPath<C.Element, ID>, @ViewBuilder content: @escaping (Binding<C.Element>) -> Content
  ) where Data == LazyMapSequence<C.Indices, (C.Index, ID)>, C.Index: Hashable { fatalError() }
}
extension ForEach where Data == Range<Int>, ID == Int, Content: View {
  /// A constant range: the Mac warns about any other.
  public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) { fatalError() }
}

public protocol DynamicViewContent: View {
  associatedtype Data: Collection
  var data: Data { get }
}
extension ForEach: DynamicViewContent where Content: View {}
nonisolated extension DynamicViewContent {
  public func onDelete(perform action: ((IndexSet) -> Void)?) -> some DynamicViewContent { self }
  public func onMove(perform action: ((IndexSet, Int) -> Void)?) -> some DynamicViewContent { self }
}

// MARK: ViewModifier

@MainActor @preconcurrency public protocol ViewModifier {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func body(content: Self.Content) -> Self.Body
  typealias Content = _ViewModifier_Content<Self>
}
public struct _ViewModifier_Content<Modifier: ViewModifier>: _PrimitiveView {}
extension ViewModifier where Body == Never {
  public func body(content: Content) -> Never { fatalError() }
}
extension ViewModifier {
  public nonisolated func concat<T>(_ modifier: T) -> ModifiedContent<Self, T> { ModifiedContent(content: self, modifier: modifier) }
}
public struct EmptyModifier: ViewModifier {
  public static let identity = EmptyModifier()
  public nonisolated init() {}
  public func body(content: Content) -> Never { fatalError() }
}
public struct ModifiedContent<Content, Modifier> {
  public var content: Content
  public var modifier: Modifier
  public nonisolated init(content: Content, modifier: Modifier) {
    self.content = content
    self.modifier = modifier
  }
}
extension ModifiedContent: View, _PrimitiveView where Content: View, Modifier: ViewModifier {}
extension ModifiedContent: ViewModifier where Content: ViewModifier, Modifier: ViewModifier {
  public func body(content: _ViewModifier_Content<Self>) -> Never { fatalError() }
}
extension ModifiedContent: Equatable where Content: Equatable, Modifier: Equatable {}
nonisolated extension View {
  public func modifier<T>(_ modifier: T) -> ModifiedContent<Self, T> { ModifiedContent(content: self, modifier: modifier) }
}
@MainActor @preconcurrency public protocol EnvironmentalModifier: ViewModifier where Body == Never {
  associatedtype ResolvedModifier: ViewModifier
  func resolve(in environment: EnvironmentValues) -> ResolvedModifier
}

// MARK: Previews. `#Preview` is a macro, which a stand-in cannot be.

@MainActor @preconcurrency public protocol PreviewProvider {
  associatedtype Previews: View
  @ViewBuilder @MainActor @preconcurrency static var previews: Previews { get }
}
