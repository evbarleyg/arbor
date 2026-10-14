// A stand-in for SwiftUI: apps, scenes and menu commands, and the bridges to and from AppKit. See SwiftUI.swift.
import AppKit

// MARK: App and Scene

@MainActor @preconcurrency public protocol App {
  associatedtype Body: Scene
  @SceneBuilder @MainActor @preconcurrency var body: Body { get }
  @MainActor @preconcurrency init()
}
extension App {
  @MainActor @preconcurrency public static func main() {}
}
@MainActor @preconcurrency public protocol Scene {
  associatedtype Body: Scene
  @SceneBuilder @MainActor @preconcurrency var body: Body { get }
}
extension Never: Scene {}
/// A scene SwiftUI makes itself. Not in the SDK; see `_PrimitiveView`.
public protocol _PrimitiveScene: Scene where Body == Never {}
extension _PrimitiveScene {
  public nonisolated var body: Never { fatalError() }
}
/// Blocks of up to ten in the SDK; of any length here.
@resultBuilder public struct SceneBuilder {
  public static func buildExpression<Content: Scene>(_ content: Content) -> Content { content }
  public static func buildBlock<Content: Scene>(_ content: Content) -> Content { content }
  public static func buildBlock<each Content: Scene>(_ content: repeat each Content) -> some Scene { _SceneTuple() }
  public static func buildOptional<Content: Scene>(_ scene: Content?) -> some Scene { _SceneTuple() }
  public static func buildLimitedAvailability<Content: Scene>(_ scene: Content) -> some Scene { scene }
}
public struct _SceneTuple: _PrimitiveScene {
  nonisolated init() {}
}
extension Group: Scene, _PrimitiveScene where Content: Scene {
  public nonisolated init(@SceneBuilder content: () -> Content) {}
}

public struct PresentedWindowContent<Data: Codable & Hashable, Content: View>: _PrimitiveView {}
public struct WindowGroup<Content: View>: _PrimitiveScene {
  public init(@ViewBuilder content: () -> Content) {}
  public init(id: String, @ViewBuilder content: () -> Content) {}
  public init(_ title: Text, @ViewBuilder content: () -> Content) {}
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
  public init(_ title: Text, id: String, @ViewBuilder content: () -> Content) {}
  public init(_ titleKey: LocalizedStringKey, id: String, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, id: String, @ViewBuilder content: () -> Content) {}
  public init<D: Codable & Hashable, C: View>(for type: D.Type, @ViewBuilder content: @escaping (Binding<D?>) -> C)
  where Content == PresentedWindowContent<D, C> {}
  public init<D: Codable & Hashable, C: View>(id: String, for type: D.Type, @ViewBuilder content: @escaping (Binding<D?>) -> C)
  where Content == PresentedWindowContent<D, C> {}
  public init<D: Codable & Hashable, C: View>(
    for type: D.Type = D.self, @ViewBuilder content: @escaping (Binding<D>) -> C, defaultValue: @escaping () -> D
  ) where Content == PresentedWindowContent<D, C> {}
}
public struct Window<Content: View>: _PrimitiveScene {
  public init(_ title: Text, id: String, @ViewBuilder content: () -> Content) {}
  public init(_ titleKey: LocalizedStringKey, id: String, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, id: String, @ViewBuilder content: () -> Content) {}
}
/// One of the names that collide with Arbor's own (Layout.swift).
public struct Settings<Content: View>: _PrimitiveScene {
  public init(@ViewBuilder content: () -> Content) {}
}
public struct MenuBarExtra<Label: View, Content: View>: _PrimitiveScene {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
  public init(isInserted: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
}
extension MenuBarExtra where Label == Text {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
  public init(_ titleKey: LocalizedStringKey, isInserted: Binding<Bool>, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, isInserted: Binding<Bool>, @ViewBuilder content: () -> Content) {}
}
extension MenuBarExtra where Label == SwiftUI.Label<Text, Image> {
  public init(_ titleKey: LocalizedStringKey, image: String, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, image: String, @ViewBuilder content: () -> Content) {}
  public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, @ViewBuilder content: () -> Content) {}
  public init(_ titleKey: LocalizedStringKey, image: String, isInserted: Binding<Bool>, @ViewBuilder content: () -> Content) {}
  public init(_ titleKey: LocalizedStringKey, systemImage: String, isInserted: Binding<Bool>, @ViewBuilder content: () -> Content) {}
}

// MARK: Scene styles and modifiers

@MainActor @preconcurrency public protocol WindowStyle {}
public struct DefaultWindowStyle: WindowStyle {
  public init() {}
}
public struct HiddenTitleBarWindowStyle: WindowStyle {
  public init() {}
}
public struct TitleBarWindowStyle: WindowStyle {
  public init() {}
}
extension WindowStyle where Self == DefaultWindowStyle {
  public static var automatic: DefaultWindowStyle { DefaultWindowStyle() }
}
extension WindowStyle where Self == HiddenTitleBarWindowStyle {
  public static var hiddenTitleBar: HiddenTitleBarWindowStyle { HiddenTitleBarWindowStyle() }
}
extension WindowStyle where Self == TitleBarWindowStyle {
  public static var titleBar: TitleBarWindowStyle { TitleBarWindowStyle() }
}
@MainActor @preconcurrency public protocol WindowToolbarStyle {}
public struct DefaultWindowToolbarStyle: WindowToolbarStyle {
  public init() {}
}
public struct ExpandedWindowToolbarStyle: WindowToolbarStyle {
  public init() {}
}
public struct UnifiedWindowToolbarStyle: WindowToolbarStyle {
  public init() {}
  public init(showsTitle: Bool) {}
}
public struct UnifiedCompactWindowToolbarStyle: WindowToolbarStyle {
  public init() {}
  public init(showsTitle: Bool) {}
}
extension WindowToolbarStyle where Self == DefaultWindowToolbarStyle {
  public static var automatic: DefaultWindowToolbarStyle { DefaultWindowToolbarStyle() }
}
extension WindowToolbarStyle where Self == ExpandedWindowToolbarStyle {
  public static var expanded: ExpandedWindowToolbarStyle { ExpandedWindowToolbarStyle() }
}
extension WindowToolbarStyle where Self == UnifiedWindowToolbarStyle {
  public static var unified: UnifiedWindowToolbarStyle { UnifiedWindowToolbarStyle() }
  public static func unified(showsTitle: Bool) -> UnifiedWindowToolbarStyle { UnifiedWindowToolbarStyle(showsTitle: showsTitle) }
}
extension WindowToolbarStyle where Self == UnifiedCompactWindowToolbarStyle {
  public static var unifiedCompact: UnifiedCompactWindowToolbarStyle { UnifiedCompactWindowToolbarStyle() }
  public static func unifiedCompact(showsTitle: Bool) -> UnifiedCompactWindowToolbarStyle {
    UnifiedCompactWindowToolbarStyle(showsTitle: showsTitle)
  }
}
@MainActor @preconcurrency public protocol MenuBarExtraStyle {}
public struct AutomaticMenuBarExtraStyle: MenuBarExtraStyle {
  public init() {}
}
public struct PullDownMenuBarExtraStyle: MenuBarExtraStyle {
  public init() {}
}
public struct WindowMenuBarExtraStyle: MenuBarExtraStyle {
  public init() {}
}
extension MenuBarExtraStyle where Self == AutomaticMenuBarExtraStyle {
  public static var automatic: AutomaticMenuBarExtraStyle { AutomaticMenuBarExtraStyle() }
}
extension MenuBarExtraStyle where Self == PullDownMenuBarExtraStyle {
  public static var menu: PullDownMenuBarExtraStyle { PullDownMenuBarExtraStyle() }
}
extension MenuBarExtraStyle where Self == WindowMenuBarExtraStyle {
  public static var window: WindowMenuBarExtraStyle { WindowMenuBarExtraStyle() }
}
public struct WindowResizability: Sendable {
  public static var automatic: WindowResizability { WindowResizability() }
  public static var contentSize: WindowResizability { WindowResizability() }
  public static var contentMinSize: WindowResizability { WindowResizability() }
}
nonisolated extension Scene {
  public func commands<Content: Commands>(@CommandsBuilder content: () -> Content) -> some Scene { self }
  public func commandsRemoved() -> some Scene { self }
  public func commandsReplaced<Content: Commands>(@CommandsBuilder content: () -> Content) -> some Scene { self }
  public func windowStyle<S: WindowStyle>(_ style: S) -> some Scene { self }
  public func windowToolbarStyle<S: WindowToolbarStyle>(_ style: S) -> some Scene { self }
  public func windowResizability(_ resizability: WindowResizability) -> some Scene { self }
  public func menuBarExtraStyle<S: MenuBarExtraStyle>(_ style: S) -> some Scene { self }
  public func defaultSize(_ size: CGSize) -> some Scene { self }
  public func defaultSize(width: CGFloat, height: CGFloat) -> some Scene { self }
  public func defaultPosition(_ position: UnitPoint) -> some Scene { self }
  public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some Scene { self }
  public func keyboardShortcut(_ shortcut: KeyboardShortcut?) -> some Scene { self }
  public func keyboardShortcut(
    _ key: KeyEquivalent, modifiers: EventModifiers = .command, localization: KeyboardShortcut.Localization
  ) -> some Scene { self }
  public func handlesExternalEvents(matching conditions: Set<String>) -> some Scene { self }
  public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping (_ oldValue: V, _ newValue: V) -> Void) -> some Scene {
    self
  }
  public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some Scene { self }
  @available(*, deprecated, message: "Use `onChange` with a two or zero parameter action closure instead.")
  public func onChange<V: Equatable>(of value: V, perform action: @escaping (_ newValue: V) -> Void) -> some Scene { self }
  public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some Scene { self }
  public func environment<T: AnyObject & Observable>(_ object: T?) -> some Scene { self }
  public func environmentObject<T: ObservableObject>(_ object: T) -> some Scene { self }
  public func defaultAppStorage(_ store: UserDefaults) -> some Scene { self }
}

// MARK: Commands

@MainActor @preconcurrency public protocol Commands {
  associatedtype Body: Commands
  @CommandsBuilder @MainActor @preconcurrency var body: Body { get }
}
extension Never: Commands {}
/// Commands SwiftUI makes itself. Not in the SDK; see `_PrimitiveView`.
public protocol _PrimitiveCommands: Commands where Body == Never {}
extension _PrimitiveCommands {
  public nonisolated var body: Never { fatalError() }
}
/// Blocks of up to ten in the SDK; of any length here.
@resultBuilder public struct CommandsBuilder {
  public static func buildExpression<Content: Commands>(_ content: Content) -> Content { content }
  public static func buildBlock() -> EmptyCommands { EmptyCommands() }
  public static func buildBlock<C: Commands>(_ content: C) -> C { content }
  public static func buildBlock<each C: Commands>(_ content: repeat each C) -> some Commands { EmptyCommands() }
  public static func buildIf<C: Commands>(_ content: C?) -> C? { content }
  public static func buildEither<T: Commands, F: Commands>(first: T) -> _ConditionalContent<T, F> { fatalError() }
  public static func buildEither<T: Commands, F: Commands>(second: F) -> _ConditionalContent<T, F> { fatalError() }
  public static func buildLimitedAvailability<C: Commands>(_ content: C) -> some Commands { content }
}
extension Optional: Commands, _PrimitiveCommands where Wrapped: Commands {}
extension _ConditionalContent: Commands, _PrimitiveCommands where TrueContent: Commands, FalseContent: Commands {}
extension Group: Commands, _PrimitiveCommands where Content: Commands {
  public nonisolated init(@CommandsBuilder content: () -> Content) {}
}
public struct EmptyCommands: _PrimitiveCommands {
  public nonisolated init() {}
}
public struct CommandMenu<Content: View>: _PrimitiveCommands {
  public init(_ nameKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
  public init(_ name: Text, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ name: S, @ViewBuilder content: () -> Content) {}
}
public struct CommandGroupPlacement: Sendable {
  public static let appInfo = CommandGroupPlacement()
  public static let appSettings = CommandGroupPlacement()
  public static let systemServices = CommandGroupPlacement()
  public static let appVisibility = CommandGroupPlacement()
  public static let appTermination = CommandGroupPlacement()
  public static let newItem = CommandGroupPlacement()
  public static let saveItem = CommandGroupPlacement()
  public static let importExport = CommandGroupPlacement()
  public static let printItem = CommandGroupPlacement()
  public static let undoRedo = CommandGroupPlacement()
  public static let pasteboard = CommandGroupPlacement()
  public static let textEditing = CommandGroupPlacement()
  public static let textFormatting = CommandGroupPlacement()
  public static let toolbar = CommandGroupPlacement()
  public static let sidebar = CommandGroupPlacement()
  public static let windowSize = CommandGroupPlacement()
  public static let singleWindowList = CommandGroupPlacement()
  public static let windowList = CommandGroupPlacement()
  public static let windowArrangement = CommandGroupPlacement()
  public static let help = CommandGroupPlacement()
}
public struct CommandGroup<Content: View>: _PrimitiveCommands {
  public init(before group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {}
  public init(after group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {}
  public init(replacing group: CommandGroupPlacement, @ViewBuilder addition: () -> Content) {}
}
public struct SidebarCommands: _PrimitiveCommands {
  public init() {}
}
public struct ToolbarCommands: _PrimitiveCommands {
  public init() {}
}
public struct TextEditingCommands: _PrimitiveCommands {
  public init() {}
}
public struct TextFormattingCommands: _PrimitiveCommands {
  public init() {}
}
public struct InspectorCommands: _PrimitiveCommands {
  public init() {}
}

// MARK: SwiftUI inside AppKit

public struct NSHostingSizingOptions: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let minSize = NSHostingSizingOptions(rawValue: 1)
  public static let intrinsicContentSize = NSHostingSizingOptions(rawValue: 2)
  public static let maxSize = NSHostingSizingOptions(rawValue: 4)
  public static let preferredContentSize = NSHostingSizingOptions(rawValue: 8)
  public static let standardBounds: NSHostingSizingOptions = [.minSize, .intrinsicContentSize, .maxSize]
}
public struct NSHostingSceneBridgingOptions: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let title = NSHostingSceneBridgingOptions(rawValue: 1)
  public static let toolbars = NSHostingSceneBridgingOptions(rawValue: 2)
  public static let all: NSHostingSceneBridgingOptions = [.title, .toolbars]
}
/// Neither `init(frame:)` nor `init()`: a hosting view is made with its root view, and so is a subclass of it.
@MainActor @preconcurrency open class NSHostingView<Content: View>: NSView {
  public required init(rootView: Content) {
    self.rootView = rootView
    super.init(frame: .zero)
  }
  public required init?(coder aDecoder: NSCoder) { fatalError() }
  public var rootView: Content
  public var sizingOptions: NSHostingSizingOptions = .standardBounds
  public var safeAreaRegions: SafeAreaRegions = .all
  public var sceneBridgingOptions: NSHostingSceneBridgingOptions = []
}
@MainActor @preconcurrency open class NSHostingController<Content: View>: NSViewController {
  public init(rootView: Content) {
    self.rootView = rootView
    super.init(nibName: nil, bundle: nil)
  }
  public init?(coder: NSCoder, rootView: Content) { fatalError() }
  public required init?(coder: NSCoder) { fatalError() }
  public var rootView: Content
  public var sizingOptions: NSHostingSizingOptions = []
  public var safeAreaRegions: SafeAreaRegions = .all
  public var sceneBridgingOptions: NSHostingSceneBridgingOptions = []
  public func sizeThatFits(in size: CGSize) -> CGSize { .zero }
}

// MARK: AppKit inside SwiftUI

@MainActor @preconcurrency public protocol NSViewRepresentable: View where Body == Never {
  associatedtype NSViewType: NSView
  @MainActor @preconcurrency func makeNSView(context: Context) -> NSViewType
  @MainActor @preconcurrency func updateNSView(_ nsView: NSViewType, context: Context)
  @MainActor @preconcurrency static func dismantleNSView(_ nsView: NSViewType, coordinator: Coordinator)
  associatedtype Coordinator = Void
  @MainActor @preconcurrency func makeCoordinator() -> Coordinator
  @MainActor @preconcurrency func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSViewType, context: Context) -> CGSize?
  typealias Context = NSViewRepresentableContext<Self>
}
extension NSViewRepresentable where Coordinator == Void {
  public func makeCoordinator() {}
}
extension NSViewRepresentable {
  public static func dismantleNSView(_ nsView: NSViewType, coordinator: Coordinator) {}
  public func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSViewType, context: Context) -> CGSize? { nil }
  public var body: Never { fatalError() }
}
@MainActor @preconcurrency public struct NSViewRepresentableContext<View: NSViewRepresentable> {
  public let coordinator: View.Coordinator
  public var transaction: Transaction
  public var environment: EnvironmentValues
}
@MainActor @preconcurrency public protocol NSViewControllerRepresentable: View where Body == Never {
  associatedtype NSViewControllerType: NSViewController
  @MainActor @preconcurrency func makeNSViewController(context: Context) -> NSViewControllerType
  @MainActor @preconcurrency func updateNSViewController(_ nsViewController: NSViewControllerType, context: Context)
  @MainActor @preconcurrency static func dismantleNSViewController(_ nsViewController: NSViewControllerType, coordinator: Coordinator)
  associatedtype Coordinator = Void
  @MainActor @preconcurrency func makeCoordinator() -> Coordinator
  @MainActor @preconcurrency func sizeThatFits(
    _ proposal: ProposedViewSize, nsViewController: NSViewControllerType, context: Context
  ) -> CGSize?
  typealias Context = NSViewControllerRepresentableContext<Self>
}
extension NSViewControllerRepresentable where Coordinator == Void {
  public func makeCoordinator() {}
}
extension NSViewControllerRepresentable {
  public static func dismantleNSViewController(_ nsViewController: NSViewControllerType, coordinator: Coordinator) {}
  public func sizeThatFits(_ proposal: ProposedViewSize, nsViewController: NSViewControllerType, context: Context) -> CGSize? { nil }
  public var body: Never { fatalError() }
}
@MainActor @preconcurrency public struct NSViewControllerRepresentableContext<ViewController: NSViewControllerRepresentable> {
  public let coordinator: ViewController.Coordinator
  public var transaction: Transaction
  public var environment: EnvironmentValues
}

@MainActor @preconcurrency @propertyWrapper public struct NSApplicationDelegateAdaptor<DelegateType: NSObject & NSApplicationDelegate>:
  DynamicProperty
{
  public var wrappedValue: DelegateType { fatalError() }
  public init(_ delegateType: DelegateType.Type = DelegateType.self) {}
}
extension NSApplicationDelegateAdaptor where DelegateType: ObservableObject {
  public init(_ delegateType: DelegateType.Type = DelegateType.self) {}
  public var projectedValue: ObservedObject<DelegateType>.Wrapper { fatalError() }
}
