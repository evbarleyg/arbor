// A stand-in for SwiftUI: what comes up over a view (sheets, popovers, alerts, dialogues, inspectors) and toolbars. See SwiftUI.swift.

// MARK: Sheets and popovers

public enum PopoverAttachmentAnchor {
  case rect(Anchor<CGRect>.Source)
  case point(UnitPoint)
}
nonisolated extension View {
  public func sheet<Content: View>(
    isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content
  ) -> some View { self }
  public func sheet<Item: Identifiable, Content: View>(
    item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View { self }
  public func popover<Content: View>(
    isPresented: Binding<Bool>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping () -> Content
  ) -> some View { self }
  public func popover<Item: Identifiable, Content: View>(
    item: Binding<Item?>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge = .top,
    @ViewBuilder content: @escaping (Item) -> Content
  ) -> some View { self }
  public func interactiveDismissDisabled(_ isDisabled: Bool = true) -> some View { self }
  public func inspector<V: View>(isPresented: Binding<Bool>, @ViewBuilder content: () -> V) -> some View { self }
  public func inspectorColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> some View { self }
  public func inspectorColumnWidth(_ width: CGFloat) -> some View { self }
}

// MARK: Alerts

nonisolated extension View {
  public func alert<A: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View { self }
  @_disfavoredOverload public func alert<S: StringProtocol, A: View>(
    _ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A
  ) -> some View { self }
  public func alert<A: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View { self }
  public func alert<A: View, M: View>(
    _ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M
  ) -> some View { self }
  @_disfavoredOverload public func alert<S: StringProtocol, A: View, M: View>(
    _ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M
  ) -> some View { self }
  public func alert<A: View, M: View>(
    _ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M
  ) -> some View { self }
  public func alert<A: View, T>(
    _ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A
  ) -> some View { self }
  @_disfavoredOverload public func alert<S: StringProtocol, A: View, T>(
    _ title: S, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A
  ) -> some View { self }
  public func alert<A: View, T>(_ title: Text, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View {
    self
  }
  public func alert<A: View, M: View, T>(
    _ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A,
    @ViewBuilder message: (T) -> M
  ) -> some View { self }
  @_disfavoredOverload public func alert<S: StringProtocol, A: View, M: View, T>(
    _ title: S, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M
  ) -> some View { self }
  public func alert<A: View, M: View, T>(
    _ title: Text, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M
  ) -> some View { self }
  public func alert<E: LocalizedError, A: View>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: () -> A) -> some View { self }
  public func alert<E: LocalizedError, A: View, M: View>(
    isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: (E) -> A, @ViewBuilder message: (E) -> M
  ) -> some View { self }
}

// MARK: Confirmation dialogues

public struct DialogSeverity: Equatable, Sendable {
  public static let automatic = DialogSeverity()
  public static let standard = DialogSeverity()
  public static let critical = DialogSeverity()
}
nonisolated extension View {
  public func confirmationDialog<A: View>(
    _ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A
  ) -> some View { self }
  @_disfavoredOverload public func confirmationDialog<S: StringProtocol, A: View>(
    _ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A
  ) -> some View { self }
  public func confirmationDialog<A: View>(
    _ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A
  ) -> some View { self }
  public func confirmationDialog<A: View, M: View>(
    _ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A,
    @ViewBuilder message: () -> M
  ) -> some View { self }
  @_disfavoredOverload public func confirmationDialog<S: StringProtocol, A: View, M: View>(
    _ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A,
    @ViewBuilder message: () -> M
  ) -> some View { self }
  public func confirmationDialog<A: View, M: View>(
    _ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A,
    @ViewBuilder message: () -> M
  ) -> some View { self }
  public func confirmationDialog<A: View, T>(
    _ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?,
    @ViewBuilder actions: (T) -> A
  ) -> some View { self }
  @_disfavoredOverload public func confirmationDialog<S: StringProtocol, A: View, T>(
    _ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A
  ) -> some View { self }
  public func confirmationDialog<A: View, M: View, T>(
    _ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?,
    @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M
  ) -> some View { self }
  @_disfavoredOverload public func confirmationDialog<S: StringProtocol, A: View, M: View, T>(
    _ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A,
    @ViewBuilder message: (T) -> M
  ) -> some View { self }
  public func dialogSeverity(_ severity: DialogSeverity) -> some View { self }
  public func dialogIcon(_ icon: Image?) -> some View { self }
  public func dialogSuppressionToggle(isSuppressed: Binding<Bool>) -> some View { self }
  public func dialogSuppressionToggle(_ titleKey: LocalizedStringKey, isSuppressed: Binding<Bool>) -> some View { self }
  public func dialogSuppressionToggle(_ label: Text, isSuppressed: Binding<Bool>) -> some View { self }
  @_disfavoredOverload public func dialogSuppressionToggle<S: StringProtocol>(_ title: S, isSuppressed: Binding<Bool>) -> some View { self }
}

// MARK: Toolbars

@MainActor @preconcurrency public protocol ToolbarContent {
  associatedtype Body: ToolbarContent
  @ToolbarContentBuilder @MainActor @preconcurrency var body: Body { get }
}
extension Never: ToolbarContent {}
/// Toolbar content SwiftUI makes itself. Not in the SDK; see `_PrimitiveView`.
public protocol _PrimitiveToolbarContent: ToolbarContent where Body == Never {}
extension _PrimitiveToolbarContent {
  public nonisolated var body: Never { fatalError() }
}
@MainActor @preconcurrency public protocol CustomizableToolbarContent: ToolbarContent where Body: CustomizableToolbarContent {}
extension Never: CustomizableToolbarContent {}
/// Blocks of up to ten in the SDK; of any length here.
@resultBuilder public struct ToolbarContentBuilder {
  public static func buildExpression<Content: ToolbarContent>(_ content: Content) -> Content { content }
  public static func buildBlock<Content: ToolbarContent>(_ content: Content) -> some ToolbarContent { content }
  public static func buildBlock<each Content: ToolbarContent>(_ content: repeat each Content) -> some ToolbarContent { _ToolbarTuple() }
  public static func buildIf<Content: ToolbarContent>(_ content: Content?) -> Content? { content }
  public static func buildEither<TrueContent: ToolbarContent, FalseContent: ToolbarContent>(
    first: TrueContent
  ) -> _ConditionalContent<TrueContent, FalseContent> { fatalError() }
  public static func buildEither<TrueContent: ToolbarContent, FalseContent: ToolbarContent>(
    second: FalseContent
  ) -> _ConditionalContent<TrueContent, FalseContent> { fatalError() }
  public static func buildLimitedAvailability<Content: ToolbarContent>(_ content: Content) -> some ToolbarContent { content }
}
public struct _ToolbarTuple: _PrimitiveToolbarContent {
  nonisolated init() {}
}
extension Optional: ToolbarContent, _PrimitiveToolbarContent where Wrapped: ToolbarContent {}
extension _ConditionalContent: ToolbarContent, _PrimitiveToolbarContent where TrueContent: ToolbarContent, FalseContent: ToolbarContent {}
extension Group: ToolbarContent, _PrimitiveToolbarContent where Content: ToolbarContent {
  public nonisolated init(@ToolbarContentBuilder content: () -> Content) {}
}
public struct ToolbarItemPlacement: Sendable {
  public static let automatic = ToolbarItemPlacement()
  public static let principal = ToolbarItemPlacement()
  public static let navigation = ToolbarItemPlacement()
  public static let primaryAction = ToolbarItemPlacement()
  public static let secondaryAction = ToolbarItemPlacement()
  public static let status = ToolbarItemPlacement()
  public static let confirmationAction = ToolbarItemPlacement()
  public static let cancellationAction = ToolbarItemPlacement()
  public static let destructiveAction = ToolbarItemPlacement()
  public static let keyboard = ToolbarItemPlacement()
}
public struct ToolbarItem<ID, Content: View>: _PrimitiveToolbarContent {}
extension ToolbarItem where ID == Void {
  public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
}
extension ToolbarItem: CustomizableToolbarContent where ID == String {
  public init(id: String, placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
}
public struct ToolbarItemGroup<Content: View>: _PrimitiveToolbarContent {
  public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
}
public struct ToolbarPlacement: Sendable {
  public static var automatic: ToolbarPlacement { ToolbarPlacement() }
  public static var windowToolbar: ToolbarPlacement { ToolbarPlacement() }
}
public struct ToolbarRole: Sendable {
  public static var automatic: ToolbarRole { ToolbarRole() }
  public static var editor: ToolbarRole { ToolbarRole() }
}
nonisolated extension View {
  public func toolbar<Content: View>(@ViewBuilder content: () -> Content) -> some View { self }
  public func toolbar<Content: ToolbarContent>(@ToolbarContentBuilder content: () -> Content) -> some View { self }
  public func toolbar<Content: CustomizableToolbarContent>(id: String, @ToolbarContentBuilder content: () -> Content) -> some View { self }
  public func toolbar(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { self }
  public func toolbarBackground<S: ShapeStyle>(_ style: S, for bars: ToolbarPlacement...) -> some View { self }
  public func toolbarBackground(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { self }
  public func toolbarRole(_ role: ToolbarRole) -> some View { self }
}
