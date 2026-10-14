// A stand-in for SwiftUI: the views that hold other views. Stacks, grids, scroll views, lists, forms, tabs, navigation. See SwiftUI.swift.

// MARK: Stacks

public struct HStack<Content: View>: _PrimitiveView {
  public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}
public struct VStack<Content: View>: _PrimitiveView {
  public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}
public struct ZStack<Content: View>: _PrimitiveView {
  public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {}
}
public struct Spacer: _PrimitiveView, Sendable {
  public var minLength: CGFloat?
  public init(minLength: CGFloat? = nil) { self.minLength = minLength }
}
public struct Divider: _PrimitiveView {
  public init() {}
}
public struct PinnedScrollableViews: OptionSet, Sendable {
  public let rawValue: UInt32
  public init(rawValue: UInt32) { self.rawValue = rawValue }
  public static let sectionHeaders = PinnedScrollableViews(rawValue: 1)
  public static let sectionFooters = PinnedScrollableViews(rawValue: 2)
}
public struct LazyHStack<Content: View>: _PrimitiveView {
  public init(
    alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(),
    @ViewBuilder content: () -> Content) {}
}
public struct LazyVStack<Content: View>: _PrimitiveView {
  public init(
    alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(),
    @ViewBuilder content: () -> Content) {}
}
public struct ViewThatFits<Content: View>: _PrimitiveView {
  public init(in axes: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: () -> Content) {}
}
public struct HSplitView<Content: View>: _PrimitiveView {
  public init(@ViewBuilder content: () -> Content) {}
}
public struct VSplitView<Content: View>: _PrimitiveView {
  public init(@ViewBuilder content: () -> Content) {}
}

// MARK: Grids

public struct Grid<Content: View>: _PrimitiveView {
  public init(
    alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}
public struct GridRow<Content: View>: _PrimitiveView {
  public init(alignment: VerticalAlignment? = nil, @ViewBuilder content: () -> Content) {}
}
public struct GridItem: Sendable {
  public enum Size: Sendable {
    case fixed(CGFloat)
    case flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity)
    case adaptive(minimum: CGFloat, maximum: CGFloat = .infinity)
  }
  public var size: Size
  public var spacing: CGFloat?
  public var alignment: Alignment?
  public init(_ size: Size = .flexible(), spacing: CGFloat? = nil, alignment: Alignment? = nil) {
    self.size = size
    self.spacing = spacing
    self.alignment = alignment
  }
}
public struct LazyVGrid<Content: View>: _PrimitiveView {
  public init(
    columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(),
    @ViewBuilder content: () -> Content) {}
}
public struct LazyHGrid<Content: View>: _PrimitiveView {
  public init(
    rows: [GridItem], alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(),
    @ViewBuilder content: () -> Content) {}
}
nonisolated extension View {
  public func gridCellColumns(_ count: Int) -> some View { self }
  public func gridCellAnchor(_ anchor: UnitPoint) -> some View { self }
  public func gridCellUnsizedAxes(_ axes: Axis.Set) -> some View { self }
  public func gridColumnAlignment(_ guide: HorizontalAlignment) -> some View { self }
}

// MARK: Geometry

public struct GeometryProxy {
  public var size: CGSize { .zero }
  public var safeAreaInsets: EdgeInsets { EdgeInsets() }
  public subscript<T>(anchor: Anchor<T>) -> T { fatalError() }
  public func frame(in coordinateSpace: CoordinateSpace) -> CGRect { .zero }
  public func frame(in coordinateSpace: some CoordinateSpaceProtocol) -> CGRect { .zero }
  public func bounds(of coordinateSpace: NamedCoordinateSpace) -> CGRect? { nil }
}
public struct GeometryReader<Content: View>: _PrimitiveView {
  public var content: (GeometryProxy) -> Content
  public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) { self.content = content }
}

// MARK: Scrolling

public struct ScrollView<Content: View>: _PrimitiveView {
  public var content: Content
  public var axes: Axis.Set
  public var showsIndicators: Bool
  public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
    self.content = content()
    self.axes = axes
    self.showsIndicators = showsIndicators
  }
}
public struct ScrollViewProxy {
  public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {}
}
public struct ScrollViewReader<Content: View>: _PrimitiveView {
  public var content: (ScrollViewProxy) -> Content
  public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) { self.content = content }
}
public struct ScrollBounceBehavior: Sendable {
  public static var automatic: ScrollBounceBehavior { ScrollBounceBehavior() }
  public static var always: ScrollBounceBehavior { ScrollBounceBehavior() }
  public static var basedOnSize: ScrollBounceBehavior { ScrollBounceBehavior() }
}
nonisolated extension View {
  public func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = [.vertical, .horizontal]) -> some View { self }
  public func scrollDisabled(_ disabled: Bool) -> some View { self }
  public func scrollContentBackground(_ visibility: Visibility) -> some View { self }
  public func scrollClipDisabled(_ disabled: Bool = true) -> some View { self }
  public func scrollBounceBehavior(_ behavior: ScrollBounceBehavior, axes: Axis.Set = [.vertical]) -> some View { self }
  public func scrollPosition(id: Binding<(some Hashable)?>, anchor: UnitPoint? = nil) -> some View { self }
  public func scrollTargetLayout(isEnabled: Bool = true) -> some View { self }
  public func defaultScrollAnchor(_ anchor: UnitPoint?) -> some View { self }
  public func scrollIndicatorsFlash(onAppear: Bool) -> some View { self }
  public func scrollIndicatorsFlash(trigger value: some Equatable) -> some View { self }
}

// MARK: List

public struct List<SelectionValue: Hashable, Content: View>: _PrimitiveView {
  public init(selection: Binding<Set<SelectionValue>>?, @ViewBuilder content: () -> Content) {}
  public init(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> Content) {}
  public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
}
/// A `Binding` to a collection is a collection too, so `List($items) { $item in … }` fits both the initialiser for bindings and the plain one.
/// The Mac takes the one for bindings; here the plain ones that have such a twin are disfavoured to the same end.
extension List {
  @_disfavoredOverload public init<Data: RandomAccessCollection, RowContent: View>(
    _ data: Data, selection: Binding<Set<SelectionValue>>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
  ) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {}
  public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(
    _ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<Set<SelectionValue>>?,
    @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
  ) where Content == ForEach<Data, ID, RowContent> {}
  public init<RowContent: View>(
    _ data: Range<Int>, selection: Binding<Set<SelectionValue>>?, @ViewBuilder rowContent: @escaping (Int) -> RowContent
  ) where Content == ForEach<Range<Int>, Int, RowContent> {}
  @_disfavoredOverload public init<Data: RandomAccessCollection, RowContent: View>(
    _ data: Data, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
  ) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {}
  public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(
    _ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue?>?,
    @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
  ) where Content == ForEach<Data, ID, RowContent> {}
  public init<RowContent: View>(
    _ data: Range<Int>, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Int) -> RowContent
  ) where Content == ForEach<Range<Int>, Int, RowContent> {}
  public init<Data: RandomAccessCollection, RowContent: View>(
    _ data: Data, selection: Binding<SelectionValue>, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
  ) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {}
  public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(
    _ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue>,
    @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
  ) where Content == ForEach<Data, ID, RowContent> {}
  public init<Data: MutableCollection & RandomAccessCollection, RowContent: View>(
    _ data: Binding<Data>, selection: Binding<Set<SelectionValue>>?, @ViewBuilder rowContent: @escaping (Binding<Data.Element>) -> RowContent
  )
  where
    Content == ForEach<LazyMapSequence<Data.Indices, (Data.Index, Data.Element.ID)>, Data.Element.ID, RowContent>, Data.Element: Identifiable,
    Data.Index: Hashable {}
  public init<Data: MutableCollection & RandomAccessCollection, RowContent: View>(
    _ data: Binding<Data>, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Binding<Data.Element>) -> RowContent
  )
  where
    Content == ForEach<LazyMapSequence<Data.Indices, (Data.Index, Data.Element.ID)>, Data.Element.ID, RowContent>, Data.Element: Identifiable,
    Data.Index: Hashable {}
}
extension List where SelectionValue == Never {
  public init(@ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<Data: RandomAccessCollection, RowContent: View>(
    _ data: Data, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
  ) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {}
  @_disfavoredOverload public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(
    _ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent
  ) where Content == ForEach<Data, ID, RowContent> {}
  public init<RowContent: View>(_ data: Range<Int>, @ViewBuilder rowContent: @escaping (Int) -> RowContent)
  where Content == ForEach<Range<Int>, Int, RowContent> {}
  public init<Data: MutableCollection & RandomAccessCollection, RowContent: View>(
    _ data: Binding<Data>, @ViewBuilder rowContent: @escaping (Binding<Data.Element>) -> RowContent
  )
  where
    Content == ForEach<LazyMapSequence<Data.Indices, (Data.Index, Data.Element.ID)>, Data.Element.ID, RowContent>, Data.Element: Identifiable,
    Data.Index: Hashable {}
  public init<Data: MutableCollection & RandomAccessCollection, ID: Hashable, RowContent: View>(
    _ data: Binding<Data>, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: @escaping (Binding<Data.Element>) -> RowContent
  ) where Content == ForEach<LazyMapSequence<Data.Indices, (Data.Index, ID)>, ID, RowContent>, Data.Index: Hashable {}
}
public struct ListItemTint: Sendable {
  public static func fixed(_ tint: Color) -> ListItemTint { ListItemTint() }
  public static func preferred(_ tint: Color) -> ListItemTint { ListItemTint() }
  public static let monochrome = ListItemTint()
}
public struct AlternatingRowBackgroundBehavior: Hashable, Sendable {
  public static let automatic = AlternatingRowBackgroundBehavior()
  public static let enabled = AlternatingRowBackgroundBehavior()
  public static let disabled = AlternatingRowBackgroundBehavior()
}
nonisolated extension View {
  public func listRowInsets(_ insets: EdgeInsets?) -> some View { self }
  public func listRowBackground<V: View>(_ view: V?) -> some View { self }
  public func listRowSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View { self }
  public func listRowSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View { self }
  public func listSectionSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View { self }
  public func listSectionSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View { self }
  public func listItemTint(_ tint: ListItemTint?) -> some View { self }
  public func listItemTint(_ tint: Color?) -> some View { self }
  public func alternatingRowBackgrounds(_ behavior: AlternatingRowBackgroundBehavior = .enabled) -> some View { self }
  public func badge(_ count: Int) -> some View { self }
  public func badge(_ label: Text?) -> some View { self }
  public func badge(_ key: LocalizedStringKey?) -> some View { self }
  @_disfavoredOverload public func badge<S: StringProtocol>(_ label: S?) -> some View { self }
  public func swipeActions<T: View>(
    edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> T
  ) -> some View { self }
  public func headerProminence(_ prominence: Prominence) -> some View { self }
  public func moveDisabled(_ isDisabled: Bool) -> some View { self }
  public func deleteDisabled(_ isDisabled: Bool) -> some View { self }
  public func selectionDisabled(_ isDisabled: Bool = true) -> some View { self }
}

// MARK: Form, Section and other boxes

public struct Form<Content: View>: _PrimitiveView {
  public init(@ViewBuilder content: () -> Content) {}
}
extension Form where Content == FormStyleConfiguration.Content {
  public init(_ configuration: FormStyleConfiguration) {}
}

public struct Section<Parent, Content, Footer> {}
extension Section: View, _PrimitiveView where Parent: View, Content: View, Footer: View {}
extension Section where Parent: View, Content: View, Footer: View {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent, @ViewBuilder footer: () -> Footer) {}
  @available(*, deprecated, renamed: "Section(content:header:footer:)")
  public init(header: Parent, footer: Footer, @ViewBuilder content: () -> Content) {}
}
extension Section where Parent == EmptyView, Content: View, Footer: View {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) {}
  @available(*, deprecated, renamed: "Section(content:footer:)")
  public init(footer: Footer, @ViewBuilder content: () -> Content) {}
}
extension Section where Parent: View, Content: View, Footer == EmptyView {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {}
  public init(isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) {}
  @available(*, deprecated, renamed: "Section(content:header:)")
  public init(header: Parent, @ViewBuilder content: () -> Content) {}
}
extension Section where Parent == EmptyView, Content: View, Footer == EmptyView {
  public init(@ViewBuilder content: () -> Content) {}
}
extension Section where Parent == Text, Content: View, Footer == EmptyView {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
  public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) {}
}

public struct GroupBox<Label: View, Content: View>: _PrimitiveView {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
  @available(*, deprecated, renamed: "GroupBox(content:label:)")
  public init(label: Label, @ViewBuilder content: () -> Content) {}
}
extension GroupBox where Label == EmptyView {
  public init(@ViewBuilder content: () -> Content) {}
}
extension GroupBox where Label == Text {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
}
extension GroupBox where Label == GroupBoxStyleConfiguration.Label, Content == GroupBoxStyleConfiguration.Content {
  public init(_ configuration: GroupBoxStyleConfiguration) {}
}

public struct LabeledContent<Label, Content> {}
extension LabeledContent: View, _PrimitiveView where Label: View, Content: View {}
extension LabeledContent where Label: View, Content: View {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
}
extension LabeledContent where Label == Text, Content: View {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
}
extension LabeledContent where Label == Text, Content == Text {
  public init<S: StringProtocol>(_ titleKey: LocalizedStringKey, value: S) {}
  @_disfavoredOverload public init<S1: StringProtocol, S2: StringProtocol>(_ title: S1, value: S2) {}
  public init<F: FormatStyle>(_ titleKey: LocalizedStringKey, value: F.FormatInput, format: F)
  where F.FormatInput: Equatable, F.FormatOutput == String {}
  @_disfavoredOverload public init<S: StringProtocol, F: FormatStyle>(_ title: S, value: F.FormatInput, format: F)
  where F.FormatInput: Equatable, F.FormatOutput == String {}
}
extension LabeledContent where Label == LabeledContentStyleConfiguration.Label, Content == LabeledContentStyleConfiguration.Content {
  public init(_ configuration: LabeledContentStyleConfiguration) {}
}

public struct DisclosureGroup<Label: View, Content: View>: _PrimitiveView {
  public init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) {}
  public init(isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) {}
}
extension DisclosureGroup where Label == Text {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {}
  public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ label: S, @ViewBuilder content: @escaping () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ label: S, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {}
}

public struct ContentUnavailableView<Label: View, Description: View, Actions: View>: _PrimitiveView {
  public init(
    @ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description = { EmptyView() },
    @ViewBuilder actions: () -> Actions = { EmptyView() }) {}
}
extension ContentUnavailableView where Label == SwiftUI.Label<Text, Image>, Description == Text?, Actions == EmptyView {
  public init(_ title: LocalizedStringKey, image name: String, description: Text? = nil) {}
  public init(_ title: LocalizedStringKey, systemImage name: String, description: Text? = nil) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, image name: String, description: Text? = nil) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage name: String, description: Text? = nil) {}
}
public struct SearchUnavailableContent {
  public struct Label: _PrimitiveView {}
  public struct Description: _PrimitiveView {}
  public struct Actions: _PrimitiveView {}
}
extension ContentUnavailableView
where
  Label == SearchUnavailableContent.Label, Description == SearchUnavailableContent.Description, Actions == SearchUnavailableContent.Actions
{
  public static var search:
    ContentUnavailableView<SearchUnavailableContent.Label, SearchUnavailableContent.Description, SearchUnavailableContent.Actions>
  { fatalError() }
  public static func search(
    text: String
  ) -> ContentUnavailableView<SearchUnavailableContent.Label, SearchUnavailableContent.Description, SearchUnavailableContent.Actions> {
    fatalError()
  }
}

// MARK: Tabs. `Tab` and its builder came with macOS 15.

public struct TabView<SelectionValue: Hashable, Content: View>: _PrimitiveView {
  public init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) {}
}
extension TabView where SelectionValue == Int {
  public init(@ViewBuilder content: () -> Content) {}
}
nonisolated extension View {
  public func tabItem<V: View>(@ViewBuilder _ label: () -> V) -> some View { self }
}

// MARK: Navigation

public struct NavigationSplitViewVisibility: Equatable, Codable, Sendable {
  public static var detailOnly: NavigationSplitViewVisibility { NavigationSplitViewVisibility() }
  public static var doubleColumn: NavigationSplitViewVisibility { NavigationSplitViewVisibility() }
  public static var all: NavigationSplitViewVisibility { NavigationSplitViewVisibility() }
  public static var automatic: NavigationSplitViewVisibility { NavigationSplitViewVisibility() }
}
public struct NavigationSplitViewColumn: Hashable, Sendable {
  public static var sidebar: NavigationSplitViewColumn { NavigationSplitViewColumn() }
  public static var content: NavigationSplitViewColumn { NavigationSplitViewColumn() }
  public static var detail: NavigationSplitViewColumn { NavigationSplitViewColumn() }
}
public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: _PrimitiveView {
  public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {}
  public init(
    columnVisibility: Binding<NavigationSplitViewVisibility>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content,
    @ViewBuilder detail: () -> Detail) {}
  public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) where Content == EmptyView {}
  public init(
    columnVisibility: Binding<NavigationSplitViewVisibility>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail
  ) where Content == EmptyView {}
  public init(
    preferredCompactColumn: Binding<NavigationSplitViewColumn>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content,
    @ViewBuilder detail: () -> Detail) {}
  public init(
    preferredCompactColumn: Binding<NavigationSplitViewColumn>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail
  ) where Content == EmptyView {}
}
public struct NavigationPath: Equatable {
  public init() {}
  public init<S: Sequence>(_ elements: S) where S.Element: Hashable {}
  public var count: Int { 0 }
  public var isEmpty: Bool { true }
  public mutating func append<V: Hashable>(_ value: V) {}
  public mutating func removeLast(_ k: Int = 1) {}
}
public struct NavigationStack<Data, Root: View>: _PrimitiveView {
  public init(@ViewBuilder root: () -> Root) where Data == NavigationPath {}
  public init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) where Data == NavigationPath {}
  public init(path: Binding<Data>, @ViewBuilder root: () -> Root)
  where Data: MutableCollection, Data: RandomAccessCollection, Data: RangeReplaceableCollection, Data.Element: Hashable {}
}
public struct NavigationLink<Label: View, Destination: View>: _PrimitiveView {
  public init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {}
  @available(*, deprecated, renamed: "NavigationLink(destination:label:)")
  public init(destination: Destination, @ViewBuilder label: () -> Label) {}
}
extension NavigationLink where Label == Text {
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder destination: () -> Destination) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder destination: () -> Destination) {}
}
extension NavigationLink where Destination == Never {
  public init<P: Hashable>(value: P?, @ViewBuilder label: () -> Label) {}
  public init<P: Hashable>(_ titleKey: LocalizedStringKey, value: P?) where Label == Text {}
  @_disfavoredOverload public init<S: StringProtocol, P: Hashable>(_ title: S, value: P?) where Label == Text {}
}
nonisolated extension View {
  public func navigationTitle(_ title: Text) -> some View { self }
  public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View { self }
  @_disfavoredOverload public func navigationTitle<S: StringProtocol>(_ title: S) -> some View { self }
  public func navigationTitle(_ title: Binding<String>) -> some View { self }
  public func navigationSubtitle(_ subtitle: Text) -> some View { self }
  public func navigationSubtitle(_ subtitleKey: LocalizedStringKey) -> some View { self }
  @_disfavoredOverload public func navigationSubtitle<S: StringProtocol>(_ subtitle: S) -> some View { self }
  public func navigationDestination<D: Hashable, C: View>(for data: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> some View { self }
  public func navigationDestination<V: View>(isPresented: Binding<Bool>, @ViewBuilder destination: () -> V) -> some View { self }
  public func navigationDestination<D: Hashable, C: View>(item: Binding<D?>, @ViewBuilder destination: @escaping (D) -> C) -> some View { self }
  public func navigationSplitViewColumnWidth(_ width: CGFloat) -> some View { self }
  public func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> some View { self }
}

// MARK: Time

public protocol TimelineSchedule {
  associatedtype Entries: Sequence where Entries.Element == Date
  func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries
  typealias Mode = TimelineScheduleMode
}
public enum TimelineScheduleMode: Hashable, Sendable { case normal, lowFrequency }
public struct PeriodicTimelineSchedule: TimelineSchedule, Sendable {
  public init(from startDate: Date, by interval: TimeInterval) {}
  public func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] { [] }
}
public struct EveryMinuteTimelineSchedule: TimelineSchedule, Sendable {
  public init() {}
  public func entries(from startDate: Date, mode: TimelineScheduleMode) -> [Date] { [] }
}
public struct AnimationTimelineSchedule: TimelineSchedule, Sendable {
  public init(minimumInterval: Double? = nil, paused: Bool = false) {}
  public func entries(from start: Date, mode: TimelineScheduleMode) -> [Date] { [] }
}
public struct ExplicitTimelineSchedule<Entries: Sequence>: TimelineSchedule where Entries.Element == Date {
  public init(_ dates: Entries) {}
  public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries { fatalError() }
}
extension TimelineSchedule where Self == PeriodicTimelineSchedule {
  public static func periodic(from startDate: Date, by interval: TimeInterval) -> PeriodicTimelineSchedule {
    PeriodicTimelineSchedule(from: startDate, by: interval)
  }
}
extension TimelineSchedule where Self == EveryMinuteTimelineSchedule {
  public static var everyMinute: EveryMinuteTimelineSchedule { EveryMinuteTimelineSchedule() }
}
extension TimelineSchedule where Self == AnimationTimelineSchedule {
  public static var animation: AnimationTimelineSchedule { AnimationTimelineSchedule() }
  public static func animation(minimumInterval: Double? = nil, paused: Bool = false) -> AnimationTimelineSchedule {
    AnimationTimelineSchedule(minimumInterval: minimumInterval, paused: paused)
  }
}
extension TimelineSchedule {
  public static func explicit<S: Sequence>(_ dates: S) -> ExplicitTimelineSchedule<S> where Self == ExplicitTimelineSchedule<S>, S.Element == Date {
    ExplicitTimelineSchedule(dates)
  }
}
public struct TimelineView<Schedule: TimelineSchedule, Content> {
  public struct Context {
    public enum Cadence: Comparable, Sendable { case live, seconds, minutes }
    public let date: Date
    public let cadence: Cadence
  }
}
extension TimelineView: View, _PrimitiveView where Content: View {
  public nonisolated init(_ schedule: Schedule, @ViewBuilder content: @escaping (TimelineViewDefaultContext) -> Content) {}
}
public typealias TimelineViewDefaultContext = TimelineView<EveryMinuteTimelineSchedule, Never>.Context
