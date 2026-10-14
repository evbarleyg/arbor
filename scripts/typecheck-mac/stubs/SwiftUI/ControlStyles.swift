// A stand-in for SwiftUI: the styles of controls and containers, each as a type, as a static member (`.pickerStyle(.segmented)`) and with the
// modifier that sets it. Only the styles macOS has. See SwiftUI.swift.

// MARK: What a style is given to work with

public struct ButtonRole: Equatable, Sendable {
  public static let destructive = ButtonRole()
  public static let cancel = ButtonRole()
}
public struct ButtonStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public let role: ButtonRole?
  public let label: Label
  public let isPressed: Bool
}
public struct PrimitiveButtonStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public let role: ButtonRole?
  public let label: Label
  public func trigger() {}
}
public struct ToggleStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public let label: Label
  @Binding public var isOn: Bool
  public var isMixed: Bool
}
public struct LabelStyleConfiguration {
  public struct Title: _PrimitiveView {}
  public struct Icon: _PrimitiveView {}
  public var title: Title { fatalError() }
  public var icon: Icon { fatalError() }
}
public struct GroupBoxStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public struct Content: _PrimitiveView {}
  public let label: Label
  public let content: Content
}
public struct ProgressViewStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public struct CurrentValueLabel: _PrimitiveView {}
  public let fractionCompleted: Double?
  public var label: Label?
  public var currentValueLabel: CurrentValueLabel?
}
public struct MenuStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public struct Content: _PrimitiveView {}
}
public struct DisclosureGroupStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public struct Content: _PrimitiveView {}
  public let label: Label
  public let content: Content
  @Binding public var isExpanded: Bool
}
public struct LabeledContentStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public struct Content: _PrimitiveView {}
  public let label: Label
  public let content: Content
}
public struct FormStyleConfiguration {
  public struct Content: _PrimitiveView {}
  public let content: Content
}
public struct ControlGroupStyleConfiguration {
  public struct Content: _PrimitiveView {}
  public struct Label: _PrimitiveView {}
  public let content: Content
  public let label: Label
}
public struct GaugeStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public struct CurrentValueLabel: _PrimitiveView {}
  public struct MinimumValueLabel: _PrimitiveView {}
  public struct MaximumValueLabel: _PrimitiveView {}
  public struct MarkedValueLabel: _PrimitiveView {}
  public var value: Double
  public var label: Label
  public var currentValueLabel: CurrentValueLabel?
  public var minimumValueLabel: MinimumValueLabel?
  public var maximumValueLabel: MaximumValueLabel?
}
public struct TextEditorStyleConfiguration {}
public struct DatePickerStyleConfiguration {
  public struct Label: _PrimitiveView {}
  public let label: Label
  @Binding public var selection: Date
  public var minimumDate: Date?
  public var maximumDate: Date?
  public var displayedComponents: DatePickerComponents
}

// MARK: Styles that draw a body

@MainActor @preconcurrency public protocol ButtonStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = ButtonStyleConfiguration
}
nonisolated extension View {
  public func buttonStyle<S: ButtonStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol PrimitiveButtonStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = PrimitiveButtonStyleConfiguration
}
public struct DefaultButtonStyle: PrimitiveButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension PrimitiveButtonStyle where Self == DefaultButtonStyle {
  public static var automatic: DefaultButtonStyle { DefaultButtonStyle() }
}
public struct BorderedButtonStyle: PrimitiveButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension PrimitiveButtonStyle where Self == BorderedButtonStyle {
  public static var bordered: BorderedButtonStyle { BorderedButtonStyle() }
}
public struct BorderedProminentButtonStyle: PrimitiveButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension PrimitiveButtonStyle where Self == BorderedProminentButtonStyle {
  public static var borderedProminent: BorderedProminentButtonStyle { BorderedProminentButtonStyle() }
}
public struct BorderlessButtonStyle: PrimitiveButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension PrimitiveButtonStyle where Self == BorderlessButtonStyle {
  public static var borderless: BorderlessButtonStyle { BorderlessButtonStyle() }
}
public struct PlainButtonStyle: PrimitiveButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension PrimitiveButtonStyle where Self == PlainButtonStyle {
  public static var plain: PlainButtonStyle { PlainButtonStyle() }
}
public struct LinkButtonStyle: PrimitiveButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension PrimitiveButtonStyle where Self == LinkButtonStyle {
  public static var link: LinkButtonStyle { LinkButtonStyle() }
}
public struct AccessoryBarButtonStyle: PrimitiveButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension PrimitiveButtonStyle where Self == AccessoryBarButtonStyle {
  public static var accessoryBar: AccessoryBarButtonStyle { AccessoryBarButtonStyle() }
}
public struct AccessoryBarActionButtonStyle: PrimitiveButtonStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension PrimitiveButtonStyle where Self == AccessoryBarActionButtonStyle {
  public static var accessoryBarAction: AccessoryBarActionButtonStyle { AccessoryBarActionButtonStyle() }
}
nonisolated extension View {
  public func buttonStyle<S: PrimitiveButtonStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol ToggleStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = ToggleStyleConfiguration
}
public struct DefaultToggleStyle: ToggleStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ToggleStyle where Self == DefaultToggleStyle {
  public static var automatic: DefaultToggleStyle { DefaultToggleStyle() }
}
public struct ButtonToggleStyle: ToggleStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ToggleStyle where Self == ButtonToggleStyle {
  public static var button: ButtonToggleStyle { ButtonToggleStyle() }
}
public struct CheckboxToggleStyle: ToggleStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ToggleStyle where Self == CheckboxToggleStyle {
  public static var checkbox: CheckboxToggleStyle { CheckboxToggleStyle() }
}
public struct SwitchToggleStyle: ToggleStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ToggleStyle where Self == SwitchToggleStyle {
  public static var `switch`: SwitchToggleStyle { SwitchToggleStyle() }
}
nonisolated extension View {
  public func toggleStyle<S: ToggleStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol LabelStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = LabelStyleConfiguration
}
public struct DefaultLabelStyle: LabelStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension LabelStyle where Self == DefaultLabelStyle {
  public static var automatic: DefaultLabelStyle { DefaultLabelStyle() }
}
public struct IconOnlyLabelStyle: LabelStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension LabelStyle where Self == IconOnlyLabelStyle {
  public static var iconOnly: IconOnlyLabelStyle { IconOnlyLabelStyle() }
}
public struct TitleOnlyLabelStyle: LabelStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension LabelStyle where Self == TitleOnlyLabelStyle {
  public static var titleOnly: TitleOnlyLabelStyle { TitleOnlyLabelStyle() }
}
public struct TitleAndIconLabelStyle: LabelStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension LabelStyle where Self == TitleAndIconLabelStyle {
  public static var titleAndIcon: TitleAndIconLabelStyle { TitleAndIconLabelStyle() }
}
nonisolated extension View {
  public func labelStyle<S: LabelStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol GroupBoxStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = GroupBoxStyleConfiguration
}
public struct DefaultGroupBoxStyle: GroupBoxStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension GroupBoxStyle where Self == DefaultGroupBoxStyle {
  public static var automatic: DefaultGroupBoxStyle { DefaultGroupBoxStyle() }
}
nonisolated extension View {
  public func groupBoxStyle<S: GroupBoxStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol ProgressViewStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = ProgressViewStyleConfiguration
}
public struct DefaultProgressViewStyle: ProgressViewStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ProgressViewStyle where Self == DefaultProgressViewStyle {
  public static var automatic: DefaultProgressViewStyle { DefaultProgressViewStyle() }
}
public struct LinearProgressViewStyle: ProgressViewStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ProgressViewStyle where Self == LinearProgressViewStyle {
  public static var linear: LinearProgressViewStyle { LinearProgressViewStyle() }
}
public struct CircularProgressViewStyle: ProgressViewStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ProgressViewStyle where Self == CircularProgressViewStyle {
  public static var circular: CircularProgressViewStyle { CircularProgressViewStyle() }
}
nonisolated extension View {
  public func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol MenuStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = MenuStyleConfiguration
}
public struct DefaultMenuStyle: MenuStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension MenuStyle where Self == DefaultMenuStyle {
  public static var automatic: DefaultMenuStyle { DefaultMenuStyle() }
}
public struct ButtonMenuStyle: MenuStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension MenuStyle where Self == ButtonMenuStyle {
  public static var button: ButtonMenuStyle { ButtonMenuStyle() }
}
public struct BorderlessButtonMenuStyle: MenuStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension MenuStyle where Self == BorderlessButtonMenuStyle {
  public static var borderlessButton: BorderlessButtonMenuStyle { BorderlessButtonMenuStyle() }
}
nonisolated extension View {
  public func menuStyle<S: MenuStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol DisclosureGroupStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = DisclosureGroupStyleConfiguration
}
public struct AutomaticDisclosureGroupStyle: DisclosureGroupStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension DisclosureGroupStyle where Self == AutomaticDisclosureGroupStyle {
  public static var automatic: AutomaticDisclosureGroupStyle { AutomaticDisclosureGroupStyle() }
}
nonisolated extension View {
  public func disclosureGroupStyle<S: DisclosureGroupStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol LabeledContentStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = LabeledContentStyleConfiguration
}
public struct AutomaticLabeledContentStyle: LabeledContentStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension LabeledContentStyle where Self == AutomaticLabeledContentStyle {
  public static var automatic: AutomaticLabeledContentStyle { AutomaticLabeledContentStyle() }
}
nonisolated extension View {
  public func labeledContentStyle<S: LabeledContentStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol FormStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = FormStyleConfiguration
}
public struct AutomaticFormStyle: FormStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension FormStyle where Self == AutomaticFormStyle {
  public static var automatic: AutomaticFormStyle { AutomaticFormStyle() }
}
public struct ColumnsFormStyle: FormStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension FormStyle where Self == ColumnsFormStyle {
  public static var columns: ColumnsFormStyle { ColumnsFormStyle() }
}
public struct GroupedFormStyle: FormStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension FormStyle where Self == GroupedFormStyle {
  public static var grouped: GroupedFormStyle { GroupedFormStyle() }
}
nonisolated extension View {
  public func formStyle<S: FormStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol ControlGroupStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = ControlGroupStyleConfiguration
}
public struct AutomaticControlGroupStyle: ControlGroupStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ControlGroupStyle where Self == AutomaticControlGroupStyle {
  public static var automatic: AutomaticControlGroupStyle { AutomaticControlGroupStyle() }
}
public struct NavigationControlGroupStyle: ControlGroupStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ControlGroupStyle where Self == NavigationControlGroupStyle {
  public static var navigation: NavigationControlGroupStyle { NavigationControlGroupStyle() }
}
public struct MenuControlGroupStyle: ControlGroupStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ControlGroupStyle where Self == MenuControlGroupStyle {
  public static var menu: MenuControlGroupStyle { MenuControlGroupStyle() }
}
public struct CompactMenuControlGroupStyle: ControlGroupStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ControlGroupStyle where Self == CompactMenuControlGroupStyle {
  public static var compactMenu: CompactMenuControlGroupStyle { CompactMenuControlGroupStyle() }
}
public struct PaletteControlGroupStyle: ControlGroupStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension ControlGroupStyle where Self == PaletteControlGroupStyle {
  public static var palette: PaletteControlGroupStyle { PaletteControlGroupStyle() }
}
nonisolated extension View {
  public func controlGroupStyle<S: ControlGroupStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol GaugeStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = GaugeStyleConfiguration
}
public struct DefaultGaugeStyle: GaugeStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension GaugeStyle where Self == DefaultGaugeStyle {
  public static var automatic: DefaultGaugeStyle { DefaultGaugeStyle() }
}
public struct LinearCapacityGaugeStyle: GaugeStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension GaugeStyle where Self == LinearCapacityGaugeStyle {
  public static var linearCapacity: LinearCapacityGaugeStyle { LinearCapacityGaugeStyle() }
}
public struct AccessoryLinearGaugeStyle: GaugeStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension GaugeStyle where Self == AccessoryLinearGaugeStyle {
  public static var accessoryLinear: AccessoryLinearGaugeStyle { AccessoryLinearGaugeStyle() }
}
public struct AccessoryLinearCapacityGaugeStyle: GaugeStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension GaugeStyle where Self == AccessoryLinearCapacityGaugeStyle {
  public static var accessoryLinearCapacity: AccessoryLinearCapacityGaugeStyle { AccessoryLinearCapacityGaugeStyle() }
}
public struct AccessoryCircularGaugeStyle: GaugeStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension GaugeStyle where Self == AccessoryCircularGaugeStyle {
  public static var accessoryCircular: AccessoryCircularGaugeStyle { AccessoryCircularGaugeStyle() }
}
public struct AccessoryCircularCapacityGaugeStyle: GaugeStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension GaugeStyle where Self == AccessoryCircularCapacityGaugeStyle {
  public static var accessoryCircularCapacity: AccessoryCircularCapacityGaugeStyle { AccessoryCircularCapacityGaugeStyle() }
}
nonisolated extension View {
  public func gaugeStyle<S: GaugeStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol TextEditorStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = TextEditorStyleConfiguration
}
public struct AutomaticTextEditorStyle: TextEditorStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension TextEditorStyle where Self == AutomaticTextEditorStyle {
  public static var automatic: AutomaticTextEditorStyle { AutomaticTextEditorStyle() }
}
public struct PlainTextEditorStyle: TextEditorStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension TextEditorStyle where Self == PlainTextEditorStyle {
  public static var plain: PlainTextEditorStyle { PlainTextEditorStyle() }
}
nonisolated extension View {
  public func textEditorStyle<S: TextEditorStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol DatePickerStyle {
  associatedtype Body: View
  @ViewBuilder @MainActor @preconcurrency func makeBody(configuration: Configuration) -> Body
  typealias Configuration = DatePickerStyleConfiguration
}
public struct DefaultDatePickerStyle: DatePickerStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension DatePickerStyle where Self == DefaultDatePickerStyle {
  public static var automatic: DefaultDatePickerStyle { DefaultDatePickerStyle() }
}
public struct CompactDatePickerStyle: DatePickerStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension DatePickerStyle where Self == CompactDatePickerStyle {
  public static var compact: CompactDatePickerStyle { CompactDatePickerStyle() }
}
public struct FieldDatePickerStyle: DatePickerStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension DatePickerStyle where Self == FieldDatePickerStyle {
  public static var field: FieldDatePickerStyle { FieldDatePickerStyle() }
}
public struct GraphicalDatePickerStyle: DatePickerStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension DatePickerStyle where Self == GraphicalDatePickerStyle {
  public static var graphical: GraphicalDatePickerStyle { GraphicalDatePickerStyle() }
}
public struct StepperFieldDatePickerStyle: DatePickerStyle {
  public init() {}
  public func makeBody(configuration: Configuration) -> some View { EmptyView() }
}
extension DatePickerStyle where Self == StepperFieldDatePickerStyle {
  public static var stepperField: StepperFieldDatePickerStyle { StepperFieldDatePickerStyle() }
}
nonisolated extension View {
  public func datePickerStyle<S: DatePickerStyle>(_ style: S) -> some View { self }
}
// MARK: Styles that are only a name

@MainActor @preconcurrency public protocol PickerStyle {}
public struct DefaultPickerStyle: PickerStyle {
  public init() {}
}
extension PickerStyle where Self == DefaultPickerStyle {
  public static var automatic: DefaultPickerStyle { DefaultPickerStyle() }
}
public struct InlinePickerStyle: PickerStyle {
  public init() {}
}
extension PickerStyle where Self == InlinePickerStyle {
  public static var inline: InlinePickerStyle { InlinePickerStyle() }
}
public struct MenuPickerStyle: PickerStyle {
  public init() {}
}
extension PickerStyle where Self == MenuPickerStyle {
  public static var menu: MenuPickerStyle { MenuPickerStyle() }
}
public struct SegmentedPickerStyle: PickerStyle {
  public init() {}
}
extension PickerStyle where Self == SegmentedPickerStyle {
  public static var segmented: SegmentedPickerStyle { SegmentedPickerStyle() }
}
public struct RadioGroupPickerStyle: PickerStyle {
  public init() {}
}
extension PickerStyle where Self == RadioGroupPickerStyle {
  public static var radioGroup: RadioGroupPickerStyle { RadioGroupPickerStyle() }
}
public struct PalettePickerStyle: PickerStyle {
  public init() {}
}
extension PickerStyle where Self == PalettePickerStyle {
  public static var palette: PalettePickerStyle { PalettePickerStyle() }
}
nonisolated extension View {
  public func pickerStyle<S: PickerStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol TextFieldStyle {}
public struct DefaultTextFieldStyle: TextFieldStyle {
  public init() {}
}
extension TextFieldStyle where Self == DefaultTextFieldStyle {
  public static var automatic: DefaultTextFieldStyle { DefaultTextFieldStyle() }
}
public struct PlainTextFieldStyle: TextFieldStyle {
  public init() {}
}
extension TextFieldStyle where Self == PlainTextFieldStyle {
  public static var plain: PlainTextFieldStyle { PlainTextFieldStyle() }
}
public struct RoundedBorderTextFieldStyle: TextFieldStyle {
  public init() {}
}
extension TextFieldStyle where Self == RoundedBorderTextFieldStyle {
  public static var roundedBorder: RoundedBorderTextFieldStyle { RoundedBorderTextFieldStyle() }
}
public struct SquareBorderTextFieldStyle: TextFieldStyle {
  public init() {}
}
extension TextFieldStyle where Self == SquareBorderTextFieldStyle {
  public static var squareBorder: SquareBorderTextFieldStyle { SquareBorderTextFieldStyle() }
}
nonisolated extension View {
  public func textFieldStyle<S: TextFieldStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol ListStyle {}
public struct DefaultListStyle: ListStyle {
  public init() {}
}
extension ListStyle where Self == DefaultListStyle {
  public static var automatic: DefaultListStyle { DefaultListStyle() }
}
public struct PlainListStyle: ListStyle {
  public init() {}
}
extension ListStyle where Self == PlainListStyle {
  public static var plain: PlainListStyle { PlainListStyle() }
}
public struct InsetListStyle: ListStyle {
  public init() {}
}
extension ListStyle where Self == InsetListStyle {
  public static var inset: InsetListStyle { InsetListStyle() }
}
public struct SidebarListStyle: ListStyle {
  public init() {}
}
extension ListStyle where Self == SidebarListStyle {
  public static var sidebar: SidebarListStyle { SidebarListStyle() }
}
public struct BorderedListStyle: ListStyle {
  public init() {}
}
extension ListStyle where Self == BorderedListStyle {
  public static var bordered: BorderedListStyle { BorderedListStyle() }
}
nonisolated extension View {
  public func listStyle<S: ListStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol TabViewStyle {}
public struct DefaultTabViewStyle: TabViewStyle {
  public init() {}
}
extension TabViewStyle where Self == DefaultTabViewStyle {
  public static var automatic: DefaultTabViewStyle { DefaultTabViewStyle() }
}
nonisolated extension View {
  public func tabViewStyle<S: TabViewStyle>(_ style: S) -> some View { self }
}

@MainActor @preconcurrency public protocol NavigationSplitViewStyle {}
public struct AutomaticNavigationSplitViewStyle: NavigationSplitViewStyle {
  public init() {}
}
extension NavigationSplitViewStyle where Self == AutomaticNavigationSplitViewStyle {
  public static var automatic: AutomaticNavigationSplitViewStyle { AutomaticNavigationSplitViewStyle() }
}
public struct BalancedNavigationSplitViewStyle: NavigationSplitViewStyle {
  public init() {}
}
extension NavigationSplitViewStyle where Self == BalancedNavigationSplitViewStyle {
  public static var balanced: BalancedNavigationSplitViewStyle { BalancedNavigationSplitViewStyle() }
}
public struct ProminentDetailNavigationSplitViewStyle: NavigationSplitViewStyle {
  public init() {}
}
extension NavigationSplitViewStyle where Self == ProminentDetailNavigationSplitViewStyle {
  public static var prominentDetail: ProminentDetailNavigationSplitViewStyle { ProminentDetailNavigationSplitViewStyle() }
}
nonisolated extension View {
  public func navigationSplitViewStyle<S: NavigationSplitViewStyle>(_ style: S) -> some View { self }
}
extension InsetListStyle {
  public init(alternatesRowBackgrounds: Bool) {}
}
extension ListStyle where Self == InsetListStyle {
  public static func inset(alternatesRowBackgrounds: Bool) -> InsetListStyle { InsetListStyle() }
}
extension BorderedListStyle {
  public init(alternatesRowBackgrounds: Bool) {}
}
extension ListStyle where Self == BorderedListStyle {
  public static func bordered(alternatesRowBackgrounds: Bool) -> BorderedListStyle { BorderedListStyle() }
}
