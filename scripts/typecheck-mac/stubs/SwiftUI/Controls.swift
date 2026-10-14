// A stand-in for SwiftUI: the controls. Their styles are in ControlStyles.swift. See SwiftUI.swift.

// MARK: Button

public struct Button<Label: View>: _PrimitiveView {
  @preconcurrency public init(action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {}
  @preconcurrency public init(role: ButtonRole?, action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {}
}
extension Button where Label == Text {
  @preconcurrency public init(_ titleKey: LocalizedStringKey, action: @escaping @MainActor () -> Void) {}
  @preconcurrency @_disfavoredOverload public init<S: StringProtocol>(_ title: S, action: @escaping @MainActor () -> Void) {}
  @preconcurrency public init(_ titleKey: LocalizedStringKey, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
  @preconcurrency @_disfavoredOverload public init<S: StringProtocol>(_ title: S, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
}
extension Button where Label == SwiftUI.Label<Text, Image> {
  @preconcurrency public init(_ titleKey: LocalizedStringKey, systemImage: String, action: @escaping @MainActor () -> Void) {}
  @preconcurrency @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, action: @escaping @MainActor () -> Void) {}
  @preconcurrency public init(_ titleKey: LocalizedStringKey, systemImage: String, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
  @preconcurrency @_disfavoredOverload public init<S: StringProtocol>(
    _ title: S, systemImage: String, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
}
extension Button where Label == PrimitiveButtonStyleConfiguration.Label {
  public init(_ configuration: PrimitiveButtonStyleConfiguration) {}
}
public struct ButtonBorderShape: Equatable, Sendable {
  public static let automatic = ButtonBorderShape()
  public static let capsule = ButtonBorderShape()
  public static let roundedRectangle = ButtonBorderShape()
  public static let circle = ButtonBorderShape()
  public static func roundedRectangle(radius: CGFloat) -> ButtonBorderShape { ButtonBorderShape() }
}

// MARK: Toggle

public struct Toggle<Label: View>: _PrimitiveView {
  public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {}
  public init<C: RandomAccessCollection>(sources: C, isOn: KeyPath<C.Element, Binding<Bool>>, @ViewBuilder label: () -> Label) {}
}
extension Toggle where Label == Text {
  public init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) {}
  public init<C: RandomAccessCollection>(_ titleKey: LocalizedStringKey, sources: C, isOn: KeyPath<C.Element, Binding<Bool>>) {}
  @_disfavoredOverload public init<S: StringProtocol, C: RandomAccessCollection>(
    _ title: S, sources: C, isOn: KeyPath<C.Element, Binding<Bool>>) {}
}
extension Toggle where Label == SwiftUI.Label<Text, Image> {
  public init(_ titleKey: LocalizedStringKey, systemImage: String, isOn: Binding<Bool>) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, isOn: Binding<Bool>) {}
}
extension Toggle where Label == ToggleStyleConfiguration.Label {
  public init(_ configuration: ToggleStyleConfiguration) {}
}

// MARK: Picker

public struct Picker<Label: View, SelectionValue: Hashable, Content: View>: _PrimitiveView {
  public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
  public init<C: RandomAccessCollection>(
    sources: C, selection: KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
  @available(*, deprecated, renamed: "Picker(selection:content:label:)")
  public init(selection: Binding<SelectionValue>, label: Label, @ViewBuilder content: () -> Content) {}
}
extension Picker where Label == Text {
  public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
  public init<C: RandomAccessCollection>(
    _ titleKey: LocalizedStringKey, sources: C, selection: KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content) {}
}
extension Picker where Label == SwiftUI.Label<Text, Image> {
  public init(_ titleKey: LocalizedStringKey, systemImage: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
  @_disfavoredOverload public init<S: StringProtocol>(
    _ title: S, systemImage: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
}

// MARK: Slider

public struct Slider<Label: View, ValueLabel: View>: _PrimitiveView {}
extension Slider {
  public init<V: BinaryFloatingPoint>(
    value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder minimumValueLabel: () -> ValueLabel,
    @ViewBuilder maximumValueLabel: () -> ValueLabel, onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) where V.Stride: BinaryFloatingPoint {}
  public init<V: BinaryFloatingPoint>(
    value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label,
    @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel,
    onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) where V.Stride: BinaryFloatingPoint {}
}
extension Slider where ValueLabel == EmptyView {
  public init<V: BinaryFloatingPoint>(
    value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) where V.Stride: BinaryFloatingPoint {}
  public init<V: BinaryFloatingPoint>(
    value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label,
    onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) where V.Stride: BinaryFloatingPoint {}
}
extension Slider where Label == EmptyView, ValueLabel == EmptyView {
  public init<V: BinaryFloatingPoint>(
    value: Binding<V>, in bounds: ClosedRange<V> = 0...1, onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) where V.Stride: BinaryFloatingPoint {}
  public init<V: BinaryFloatingPoint>(
    value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) where V.Stride: BinaryFloatingPoint {}
}

// MARK: Stepper

public struct Stepper<Label: View>: _PrimitiveView {
  public init(
    @ViewBuilder label: () -> Label, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?,
    onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
}
extension Stepper {
  public init<V: Strideable>(
    value: Binding<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
  public init<V: Strideable>(
    value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label,
    onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
  public init<F: ParseableFormatStyle>(
    value: Binding<F.FormatInput>, step: F.FormatInput.Stride = 1, format: F, @ViewBuilder label: () -> Label,
    onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) where F.FormatInput: BinaryFloatingPoint, F.FormatOutput == String {}
  public init<F: ParseableFormatStyle>(
    value: Binding<F.FormatInput>, in bounds: ClosedRange<F.FormatInput>, step: F.FormatInput.Stride = 1, format: F,
    @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }
  ) where F.FormatInput: BinaryFloatingPoint, F.FormatOutput == String {}
}
extension Stepper where Label == Text {
  public init(
    _ titleKey: LocalizedStringKey, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?,
    onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
  @_disfavoredOverload public init<S: StringProtocol>(
    _ title: S, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
  public init<V: Strideable>(
    _ titleKey: LocalizedStringKey, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
  @_disfavoredOverload public init<S: StringProtocol, V: Strideable>(
    _ title: S, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
  public init<V: Strideable>(
    _ titleKey: LocalizedStringKey, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1,
    onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
  @_disfavoredOverload public init<S: StringProtocol, V: Strideable>(
    _ title: S, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
}

// MARK: Text input

public struct TextField<Label: View>: _PrimitiveView {}
extension TextField where Label == Text {
  public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>) {}
  public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text?) {}
  public init(_ titleKey: LocalizedStringKey, text: Binding<String>, axis: Axis) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>, axis: Axis) {}
  public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?, axis: Axis) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text?, axis: Axis) {}
  public init<F: ParseableFormatStyle>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil)
  where F.FormatOutput == String {}
  @_disfavoredOverload public init<S: StringProtocol, F: ParseableFormatStyle>(
    _ title: S, value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil
  ) where F.FormatOutput == String {}
  public init<F: ParseableFormatStyle>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil)
  where F.FormatOutput == String {}
  @_disfavoredOverload public init<S: StringProtocol, F: ParseableFormatStyle>(
    _ title: S, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil
  ) where F.FormatOutput == String {}
  public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter) {}
  @_disfavoredOverload public init<S: StringProtocol, V>(_ title: S, value: Binding<V>, formatter: Formatter) {}
  public init<V>(_ titleKey: LocalizedStringKey, value: Binding<V>, formatter: Formatter, prompt: Text?) {}
  @_disfavoredOverload public init<S: StringProtocol, V>(_ title: S, value: Binding<V>, formatter: Formatter, prompt: Text?) {}
  @available(*, deprecated, message: "Use FocusState and onSubmit instead.")
  public init(
    _ titleKey: LocalizedStringKey, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void, onCommit: @escaping () -> Void) {}
  @available(*, deprecated, message: "Use FocusState and onSubmit instead.")
  public init(_ titleKey: LocalizedStringKey, text: Binding<String>, onEditingChanged: @escaping (Bool) -> Void) {}
  @available(*, deprecated, message: "Use onSubmit instead.")
  public init(_ titleKey: LocalizedStringKey, text: Binding<String>, onCommit: @escaping () -> Void) {}
}
extension TextField {
  public init(text: Binding<String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) {}
  public init(text: Binding<String>, prompt: Text? = nil, axis: Axis, @ViewBuilder label: () -> Label) {}
  public init<F: ParseableFormatStyle>(value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil, @ViewBuilder label: () -> Label)
  where F.FormatOutput == String {}
  public init<F: ParseableFormatStyle>(value: Binding<F.FormatInput>, format: F, prompt: Text? = nil, @ViewBuilder label: () -> Label)
  where F.FormatOutput == String {}
  public init<V>(value: Binding<V>, formatter: Formatter, prompt: Text? = nil, @ViewBuilder label: () -> Label) {}
}
public struct SecureField<Label: View>: _PrimitiveView {}
extension SecureField where Label == Text {
  public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>) {}
  public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text?) {}
}
extension SecureField {
  public init(text: Binding<String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) {}
}
public struct TextEditor: _PrimitiveView {
  public init(text: Binding<String>) {}
}
public struct SubmitTriggers: OptionSet, Sendable {
  public let rawValue: UInt
  public init(rawValue: UInt) { self.rawValue = rawValue }
  public static let text = SubmitTriggers(rawValue: 1)
  public static let search = SubmitTriggers(rawValue: 2)
}
public struct SubmitLabel: Sendable {
  public static var done: SubmitLabel { SubmitLabel() }
  public static var go: SubmitLabel { SubmitLabel() }
  public static var send: SubmitLabel { SubmitLabel() }
  public static var join: SubmitLabel { SubmitLabel() }
  public static var route: SubmitLabel { SubmitLabel() }
  public static var search: SubmitLabel { SubmitLabel() }
  public static var `return`: SubmitLabel { SubmitLabel() }
  public static var next: SubmitLabel { SubmitLabel() }
  public static var `continue`: SubmitLabel { SubmitLabel() }
}
public protocol TextSelectability {
  static var allowsSelection: Bool { get }
}
public struct EnabledTextSelectability: TextSelectability {
  public static let allowsSelection = true
}
public struct DisabledTextSelectability: TextSelectability {
  public static let allowsSelection = false
}
extension TextSelectability where Self == EnabledTextSelectability {
  public static var enabled: EnabledTextSelectability { EnabledTextSelectability() }
}
extension TextSelectability where Self == DisabledTextSelectability {
  public static var disabled: DisabledTextSelectability { DisabledTextSelectability() }
}

// MARK: Menu

public struct Menu<Label: View, Content: View>: _PrimitiveView {}
extension Menu {
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) where Label == Text {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) where Label == Text {}
  public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content)
  where Label == SwiftUI.Label<Text, Image> {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, systemImage: String, @ViewBuilder content: () -> Content)
  where Label == SwiftUI.Label<Text, Image> {}
  public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, primaryAction: @escaping () -> Void) {}
  public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Void) where Label == Text {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Void)
  where Label == Text {}
}
extension Menu where Label == MenuStyleConfiguration.Label, Content == MenuStyleConfiguration.Content {
  public init(_ configuration: MenuStyleConfiguration) {}
}

// MARK: Links

public struct Link<Label: View>: _PrimitiveView {
  public init(destination: URL, @ViewBuilder label: () -> Label) {}
}
extension Link where Label == Text {
  public init(_ titleKey: LocalizedStringKey, destination: URL) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, destination: URL) {}
}
public struct DefaultSettingsLinkLabel: _PrimitiveView {}
public struct SettingsLink<Label: View>: _PrimitiveView {
  public init(@ViewBuilder label: () -> Label) {}
}
extension SettingsLink where Label == DefaultSettingsLinkLabel {
  public init() {}
}
public struct HelpLink: _PrimitiveView {
  public init(action: @escaping () -> Void) {}
  public init(destination: URL) {}
}

// MARK: Dates and colours

public struct DatePickerComponents: OptionSet, Sendable {
  public let rawValue: UInt
  public init(rawValue: UInt) { self.rawValue = rawValue }
  public static let hourAndMinute = DatePickerComponents(rawValue: 1)
  public static let hourMinuteAndSecond = DatePickerComponents(rawValue: 2)
  public static let date = DatePickerComponents(rawValue: 4)
}
public struct DatePicker<Label: View>: _PrimitiveView {
  public typealias Components = DatePickerComponents
}
extension DatePicker {
  public init(selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {}
  public init(
    selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date],
    @ViewBuilder label: () -> Label) {}
  public init(
    selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: Components = [.hourAndMinute, .date],
    @ViewBuilder label: () -> Label) {}
  public init(
    selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: Components = [.hourAndMinute, .date],
    @ViewBuilder label: () -> Label) {}
}
extension DatePicker where Label == Text {
  public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
  public init(
    _ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: ClosedRange<Date>,
    displayedComponents: Components = [.hourAndMinute, .date]) {}
  public init(
    _ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeFrom<Date>,
    displayedComponents: Components = [.hourAndMinute, .date]) {}
  public init(
    _ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeThrough<Date>,
    displayedComponents: Components = [.hourAndMinute, .date]) {}
  @_disfavoredOverload public init<S: StringProtocol>(
    _ title: S, selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
  @_disfavoredOverload public init<S: StringProtocol>(
    _ title: S, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
}
public struct ColorPicker<Label: View>: _PrimitiveView {
  public init(selection: Binding<Color>, supportsOpacity: Bool = true, @ViewBuilder label: () -> Label) {}
  public init(selection: Binding<CGColor>, supportsOpacity: Bool = true, @ViewBuilder label: () -> Label) {}
}
extension ColorPicker where Label == Text {
  public init(_ titleKey: LocalizedStringKey, selection: Binding<Color>, supportsOpacity: Bool = true) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, selection: Binding<Color>, supportsOpacity: Bool = true) {}
  public init(_ titleKey: LocalizedStringKey, selection: Binding<CGColor>, supportsOpacity: Bool = true) {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S, selection: Binding<CGColor>, supportsOpacity: Bool = true) {}
}

// MARK: Progress

public struct ProgressView<Label: View, CurrentValueLabel: View>: _PrimitiveView {}
extension ProgressView where CurrentValueLabel == EmptyView {
  public init() where Label == EmptyView {}
  public init(@ViewBuilder label: () -> Label) {}
  public init(_ titleKey: LocalizedStringKey) where Label == Text {}
  @_disfavoredOverload public init<S: StringProtocol>(_ title: S) where Label == Text {}
}
extension ProgressView {
  public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0) where Label == EmptyView, CurrentValueLabel == EmptyView {}
  public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label) where CurrentValueLabel == EmptyView {}
  public init<V: BinaryFloatingPoint>(
    value: V?, total: V = 1.0, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {}
  public init<V: BinaryFloatingPoint>(_ titleKey: LocalizedStringKey, value: V?, total: V = 1.0)
  where Label == Text, CurrentValueLabel == EmptyView {}
  @_disfavoredOverload public init<S: StringProtocol, V: BinaryFloatingPoint>(_ title: S, value: V?, total: V = 1.0)
  where Label == Text, CurrentValueLabel == EmptyView {}
  public init(_ progress: Progress) where Label == EmptyView, CurrentValueLabel == EmptyView {}
  public init(_ configuration: ProgressViewStyleConfiguration)
  where Label == ProgressViewStyleConfiguration.Label, CurrentValueLabel == ProgressViewStyleConfiguration.CurrentValueLabel {}
}
public struct Gauge<Label: View, CurrentValueLabel: View, BoundsLabel: View, MarkedValueLabels: View>: _PrimitiveView {}
extension Gauge {
  public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label)
  where CurrentValueLabel == EmptyView, BoundsLabel == EmptyView, MarkedValueLabels == EmptyView {}
  public init<V: BinaryFloatingPoint>(
    value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel
  ) where BoundsLabel == EmptyView, MarkedValueLabels == EmptyView {}
  public init<V: BinaryFloatingPoint>(
    value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel,
    @ViewBuilder minimumValueLabel: () -> BoundsLabel, @ViewBuilder maximumValueLabel: () -> BoundsLabel
  ) where MarkedValueLabels == EmptyView {}
}

// MARK: Groups of controls

public struct ControlGroup<Content: View>: _PrimitiveView {
  public init(@ViewBuilder content: () -> Content) {}
}
extension ControlGroup where Content == ControlGroupStyleConfiguration.Content {
  public init(_ configuration: ControlGroupStyleConfiguration) {}
}
extension ControlGroup {
  public init<C: View, L: View>(@ViewBuilder content: () -> C, @ViewBuilder label: () -> L) where Content == LabeledControlGroupContent<C, L> {}
  public init<C: View>(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> C) where Content == LabeledControlGroupContent<C, Text> {}
  @_disfavoredOverload public init<C: View, S: StringProtocol>(_ title: S, @ViewBuilder content: () -> C)
  where Content == LabeledControlGroupContent<C, Text> {}
}
public struct LabeledControlGroupContent<Content: View, Label: View>: _PrimitiveView {}

// MARK: Keys

public struct KeyEquivalent: Hashable, Sendable, ExpressibleByExtendedGraphemeClusterLiteral {
  public var character: Character
  public init(_ character: Character) { self.character = character }
  public init(extendedGraphemeClusterLiteral: Character) { character = extendedGraphemeClusterLiteral }
  public static let upArrow = KeyEquivalent("\u{F700}")
  public static let downArrow = KeyEquivalent("\u{F701}")
  public static let leftArrow = KeyEquivalent("\u{F702}")
  public static let rightArrow = KeyEquivalent("\u{F703}")
  public static let escape = KeyEquivalent("\u{1B}")
  public static let delete = KeyEquivalent("\u{8}")
  public static let deleteForward = KeyEquivalent("\u{F728}")
  public static let home = KeyEquivalent("\u{F729}")
  public static let end = KeyEquivalent("\u{F72B}")
  public static let pageUp = KeyEquivalent("\u{F72C}")
  public static let pageDown = KeyEquivalent("\u{F72D}")
  public static let clear = KeyEquivalent("\u{F739}")
  public static let tab = KeyEquivalent("\t")
  public static let space = KeyEquivalent(" ")
  public static let `return` = KeyEquivalent("\r")
}
public struct EventModifiers: OptionSet, Sendable {
  public let rawValue: Int
  public init(rawValue: Int) { self.rawValue = rawValue }
  public static let capsLock = EventModifiers(rawValue: 1)
  public static let shift = EventModifiers(rawValue: 2)
  public static let control = EventModifiers(rawValue: 4)
  public static let option = EventModifiers(rawValue: 8)
  public static let command = EventModifiers(rawValue: 16)
  public static let numericPad = EventModifiers(rawValue: 32)
  @available(*, deprecated, message: "Function modifier is reserved for system applications")
  public static let function = EventModifiers(rawValue: 64)
  public static let all = EventModifiers(rawValue: 127)
}
public struct KeyboardShortcut: Hashable, Sendable {
  public struct Localization: Hashable, Sendable {
    public static let automatic = Localization()
    public static let withoutMirroring = Localization()
    public static let custom = Localization()
  }
  public static let defaultAction = KeyboardShortcut(.return, modifiers: [])
  public static let cancelAction = KeyboardShortcut(.escape, modifiers: [])
  public var key: KeyEquivalent
  public var modifiers: EventModifiers
  public var localization: Localization
  public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) { self.init(key, modifiers: modifiers, localization: .automatic) }
  public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command, localization: Localization) {
    self.key = key
    self.modifiers = modifiers
    self.localization = localization
  }
  public func hash(into hasher: inout Hasher) {}
  public static func == (lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Bool { false }
}
public struct KeyPress: Sendable {
  public struct Phases: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let down = Phases(rawValue: 1)
    public static let `repeat` = Phases(rawValue: 2)
    public static let up = Phases(rawValue: 4)
    public static let all = Phases(rawValue: 7)
  }
  public enum Result: Sendable { case handled, ignored }
  public let phase: Phases
  public let key: KeyEquivalent
  public let characters: String
  public let modifiers: EventModifiers
}
public enum MoveCommandDirection: Hashable, Sendable { case up, down, left, right }
