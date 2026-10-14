// A stand-in for AppKit: controls and the usual container views. See Application.swift.

@MainActor open class NSCell: NSObject {
  open var title = ""
  open var isEnabled = true
  open var controlSize: NSControl.ControlSize = .regular
  open var font: NSFont?
  open var alignment: NSTextAlignment = .natural
  open var lineBreakMode: NSLineBreakMode = .byWordWrapping
  open var wraps = false
  open var isScrollable = false
  open var truncatesLastVisibleLine = false
  open var usesSingleLineMode = false
  open var cellSize: NSSize { .zero }
}
@MainActor open class NSActionCell: NSCell {}
@MainActor open class NSButtonCell: NSActionCell {}
@MainActor open class NSTextFieldCell: NSActionCell {}

@MainActor open class NSControl: NSView {
  public struct StateValue: RawRepresentable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(_ rawValue: Int) { self.rawValue = rawValue }
    public static let mixed = StateValue(-1)
    public static let off = StateValue(0)
    public static let on = StateValue(1)
  }
  public enum ControlSize: UInt, Sendable { case regular = 0, small = 1, mini = 2, large = 3 }
  public enum ImagePosition: UInt, Sendable {
    case noImage = 0, imageOnly, imageLeft, imageRight, imageBelow, imageAbove, imageOverlaps, imageLeading, imageTrailing
  }
  open weak var target: AnyObject?
  open var action: Selector?
  open override var tag: Int {
    get { -1 }
    set {}
  }
  open var isEnabled = true
  open var isContinuous = false
  open var isHighlighted = false
  open var ignoresMultiClick = false
  open var controlSize: ControlSize = .regular
  open var cell: NSCell?
  open var objectValue: Any?
  open var stringValue = ""
  open var attributedStringValue = NSAttributedString(string: "")
  open var intValue: Int32 = 0
  open var integerValue = 0
  open var floatValue: Float = 0
  open var doubleValue: Double = 0
  open var font: NSFont?
  open var alignment: NSTextAlignment = .natural
  open var lineBreakMode: NSLineBreakMode = .byWordWrapping
  open var usesSingleLineMode = false
  open var allowsExpansionToolTips = false
  open var baseWritingDirection: NSWritingDirection = .natural
  open var formatter: Formatter?
  open func sizeToFit() {}
  open func sizeThatFits(_ size: NSSize) -> NSSize { size }
  @discardableResult open func sendAction(_ action: Selector?, to target: Any?) -> Bool { false }
  @discardableResult open func sendAction(on mask: NSEvent.EventTypeMask) -> Int { 0 }
  open func performClick(_ sender: Any?) {}
  open func takeStringValueFrom(_ sender: Any?) {}
  open func currentEditor() -> NSText? { nil }
  @discardableResult open func abortEditing() -> Bool { false }
  open func validateEditing() {}
  public nonisolated static let textDidBeginEditingNotification = NSNotification.Name("NSControlTextDidBeginEditingNotification")
  public nonisolated static let textDidEndEditingNotification = NSNotification.Name("NSControlTextDidEndEditingNotification")
  public nonisolated static let textDidChangeNotification = NSNotification.Name("NSControlTextDidChangeNotification")
}
@MainActor public protocol NSControlTextEditingDelegate: NSObjectProtocol {
  func controlTextDidBeginEditing(_ obj: Notification)
  func controlTextDidEndEditing(_ obj: Notification)
  func controlTextDidChange(_ obj: Notification)
  func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool
}
extension NSControlTextEditingDelegate {
  public func controlTextDidBeginEditing(_ obj: Notification) {}
  public func controlTextDidEndEditing(_ obj: Notification) {}
  public func controlTextDidChange(_ obj: Notification) {}
  public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool { false }
}

@MainActor open class NSButton: NSControl {
  public enum ButtonType: UInt, Sendable {
    case momentaryLight = 0, pushOnPushOff, toggle, `switch`, radio, momentaryChange, onOff, momentaryPushIn, accelerator, multiLevelAccelerator
  }
  public enum BezelStyle: UInt, Sendable {
    case automatic = 0, push = 1, flexiblePush = 2, disclosure = 5, circular = 7, helpButton = 9, smallSquare = 10, toolbar = 11,
      accessoryBarAction = 12, accessoryBar = 13, pushDisclosure = 14, badge = 15
    public static var rounded: BezelStyle { .push }
    public static var regularSquare: BezelStyle { .flexiblePush }
    public static var texturedRounded: BezelStyle { .toolbar }
    public static var roundRect: BezelStyle { .accessoryBarAction }
    public static var recessed: BezelStyle { .accessoryBar }
    public static var inline: BezelStyle { .badge }
  }
  public convenience init(title: String, image: NSImage, target: Any?, action: Selector?) { self.init() }
  public convenience init(title: String, target: Any?, action: Selector?) { self.init() }
  public convenience init(image: NSImage, target: Any?, action: Selector?) { self.init() }
  public convenience init(checkboxWithTitle title: String, target: Any?, action: Selector?) { self.init() }
  public convenience init(radioButtonWithTitle title: String, target: Any?, action: Selector?) { self.init() }
  open func setButtonType(_ type: ButtonType) {}
  open var title = ""
  open var attributedTitle = NSAttributedString(string: "")
  open var alternateTitle = ""
  open var image: NSImage?
  open var alternateImage: NSImage?
  open var imagePosition: NSControl.ImagePosition = .noImage
  open var imageScaling: NSImageScaling = .scaleProportionallyDown
  open var imageHugsTitle = false
  open var symbolConfiguration: NSImage.SymbolConfiguration?
  open var bezelStyle: BezelStyle = .automatic
  open var bezelColor: NSColor?
  open var contentTintColor: NSColor?
  open var isBordered = true
  open var isTransparent = false
  open var showsBorderOnlyWhileMouseInside = false
  open var hasDestructiveAction = false
  open var state: NSControl.StateValue = .off
  open var allowsMixedState = false
  open var keyEquivalent = ""
  open var keyEquivalentModifierMask: NSEvent.ModifierFlags = []
  open var isSpringLoaded = false
  open var sound: NSSound?
  open func setNextState() {}
  open func highlight(_ flag: Bool) {}
}
public enum NSImageScaling: UInt, Sendable { case scaleProportionallyDown = 0, scaleAxesIndependently, scaleNone, scaleProportionallyUpOrDown }
public enum NSImageAlignment: UInt, Sendable {
  case alignCenter = 0, alignTop, alignTopLeft, alignTopRight, alignLeft, alignBottom, alignBottomLeft, alignBottomRight, alignRight
}

@MainActor public protocol NSTextFieldDelegate: NSControlTextEditingDelegate {}
@MainActor open class NSTextField: NSControl {
  public enum BezelStyle: UInt, Sendable { case squareBezel = 0, roundedBezel = 1 }
  public convenience init(labelWithString stringValue: String) { self.init() }
  public convenience init(wrappingLabelWithString stringValue: String) { self.init() }
  public convenience init(labelWithAttributedString attributedStringValue: NSAttributedString) { self.init() }
  public convenience init(string stringValue: String) { self.init() }
  open var placeholderString: String?
  open var placeholderAttributedString: NSAttributedString?
  open var backgroundColor: NSColor?
  open var drawsBackground = false
  open var textColor: NSColor?
  open var isBordered = false
  open var isBezeled = false
  open var bezelStyle: BezelStyle = .squareBezel
  open var isEditable = false
  open var isSelectable = false
  open weak var delegate: (any NSTextFieldDelegate)?
  open var preferredMaxLayoutWidth: CGFloat = 0
  open var maximumNumberOfLines = 0
  open var allowsDefaultTighteningForTruncation = false
  open var allowsEditingTextAttributes = false
  open var isAutomaticTextCompletionEnabled = true
  open func selectText(_ sender: Any?) {}
}
@MainActor open class NSSecureTextField: NSTextField {}
@MainActor public protocol NSSearchFieldDelegate: NSTextFieldDelegate {}
@MainActor open class NSSearchField: NSTextField {
  open var sendsSearchStringImmediately = false
  open var sendsWholeSearchString = false
  open var recentSearches: [String] = []
}

@MainActor open class NSText: NSView {
  open var string = ""
  open var isEditable = true
  open var isSelectable = true
  open var isRichText = true
  open var drawsBackground = true
  open var backgroundColor: NSColor?
  open var font: NSFont?
  open var textColor: NSColor?
  open var alignment: NSTextAlignment = .natural
  open var selectedRange = NSRange()
  open var isFieldEditor = false
  open var isHorizontallyResizable = false
  open var isVerticallyResizable = true
  open var minSize = NSSize.zero
  open var maxSize = NSSize.zero
  open func scrollRangeToVisible(_ range: NSRange) {}
  open func sizeToFit() {}
  open func copy(_ sender: Any?) {}
  open func paste(_ sender: Any?) {}
  open func cut(_ sender: Any?) {}
  public nonisolated static let didChangeNotification = NSNotification.Name("NSTextDidChangeNotification")
}
@MainActor open class NSTextView: NSText {
  open var textContainerInset = NSSize.zero
  open var isAutomaticQuoteSubstitutionEnabled = false
  open var isAutomaticDashSubstitutionEnabled = false
  open var isAutomaticSpellingCorrectionEnabled = false
  open var isContinuousSpellCheckingEnabled = false
  open var allowsUndo = false
  open var usesFindBar = false
  open var textStorage: NSTextStorage? { nil }
  open class func scrollableTextView() -> NSScrollView { NSScrollView() }
  // NSTextInputClient: what an input method is in the middle of.
  open func hasMarkedText() -> Bool { false }
  open func markedRange() -> NSRange { NSRange() }
  open func unmarkText() {}
  open func insertText(_ string: Any, replacementRange: NSRange) {}
  open func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {}
}
open class NSTextStorage: NSMutableAttributedString {}

@MainActor open class NSImageView: NSControl {
  public enum FrameStyle: UInt, Sendable { case none = 0, photo, grayBezel, groove, button }
  public convenience init(image: NSImage) { self.init() }
  open var image: NSImage?
  open var imageScaling: NSImageScaling = .scaleProportionallyDown
  open var imageAlignment: NSImageAlignment = .alignCenter
  open var imageFrameStyle: FrameStyle = .none
  open var symbolConfiguration: NSImage.SymbolConfiguration?
  open var contentTintColor: NSColor?
  open var animates = false
  open var isEditable = false
}

@MainActor open class NSStackView: NSView {
  public enum Gravity: Int, Sendable { case top = 1, center = 2, bottom = 3
    public static var leading: Gravity { .top }
    public static var trailing: Gravity { .bottom }
  }
  public enum Distribution: Int, Sendable { case gravityAreas = -1, fill = 0, fillEqually, fillProportionally, equalSpacing, equalCentering }
  public struct VisibilityPriority: RawRepresentable, Hashable, Sendable {
    public let rawValue: Float
    public init(rawValue: Float) { self.rawValue = rawValue }
    public static let mustHold = VisibilityPriority(rawValue: 1000)
    public static let detachOnlyIfNecessary = VisibilityPriority(rawValue: 900)
    public static let notVisible = VisibilityPriority(rawValue: 0)
  }
  public convenience init(views: [NSView]) { self.init() }
  open var orientation: NSUserInterfaceLayoutOrientation = .horizontal
  open var alignment: NSLayoutConstraint.Attribute = .centerY
  open var edgeInsets = NSEdgeInsets()
  open var distribution: Distribution = .gravityAreas
  open var spacing: CGFloat = 8
  open var detachesHiddenViews = true
  open var arrangedSubviews: [NSView] { [] }
  open var views: [NSView] { [] }
  open func addArrangedSubview(_ view: NSView) {}
  open func insertArrangedSubview(_ view: NSView, at index: Int) {}
  open func removeArrangedSubview(_ view: NSView) {}
  open func addView(_ view: NSView, in gravity: Gravity) {}
  open func removeView(_ view: NSView) {}
  open func setViews(_ views: [NSView], in gravity: Gravity) {}
  open func setCustomSpacing(_ spacing: CGFloat, after view: NSView) {}
  open func customSpacing(after view: NSView) -> CGFloat { 0 }
  open func setHuggingPriority(_ priority: NSLayoutConstraint.Priority, for orientation: NSLayoutConstraint.Orientation) {}
  open func setClippingResistancePriority(_ priority: NSLayoutConstraint.Priority, for orientation: NSLayoutConstraint.Orientation) {}
  open func setVisibilityPriority(_ priority: VisibilityPriority, for view: NSView) {}
}

@MainActor open class NSVisualEffectView: NSView {
  public enum Material: Int, Sendable {
    case titlebar = 3, selection = 4, menu = 5, popover = 6, sidebar = 7, headerView = 10, sheet = 11, windowBackground = 12, hudWindow = 13,
      fullScreenUI = 15, toolTip = 17, contentBackground = 18, underWindowBackground = 21, underPageBackground = 22
  }
  public enum BlendingMode: Int, Sendable { case behindWindow = 0, withinWindow = 1 }
  public enum State: Int, Sendable { case followsWindowActiveState = 0, active = 1, inactive = 2 }
  open var material: Material = .windowBackground
  open var blendingMode: BlendingMode = .behindWindow
  open var state: State = .followsWindowActiveState
  open var maskImage: NSImage?
  open var isEmphasized = false
  open var interiorBackgroundStyle: NSView.BackgroundStyle { .normal }
}
extension NSView {
  public enum BackgroundStyle: Int, Sendable { case normal = 0, emphasized, raised, lowered }
}

@MainActor open class NSBox: NSView {
  public enum BoxType: UInt, Sendable { case primary = 0, separator = 2, custom = 4 }
  public enum TitlePosition: UInt, Sendable { case noTitle = 0, aboveTop, atTop, belowTop, aboveBottom, atBottom, belowBottom }
  open var boxType: BoxType = .primary
  open var titlePosition: TitlePosition = .atTop
  open var title = ""
  open var titleFont = NSFont()
  open var contentView: NSView?
  open var contentViewMargins = NSSize.zero
  open var isTransparent = false
  open var borderWidth: CGFloat = 1
  open var cornerRadius: CGFloat = 0
  open var borderColor = NSColor.clear
  open var fillColor = NSColor.clear
  open func sizeToFit() {}
}

@MainActor open class NSClipView: NSView {
  open var documentView: NSView?
  open var documentRect: NSRect { .zero }
  open var documentVisibleRect: NSRect { .zero }
  open var drawsBackground = true
  open var backgroundColor = NSColor.clear
  open func scroll(to newOrigin: NSPoint) {}
}
@MainActor open class NSScroller: NSControl {
  public enum Style: Int, Sendable { case legacy = 0, overlay = 1 }
  open class var preferredScrollerStyle: Style { .overlay }
}
@MainActor open class NSScrollView: NSView {
  public enum Elasticity: Int, Sendable { case automatic = 0, none = 1, allowed = 2 }
  open var documentView: NSView?
  open var contentView = NSClipView()
  open var documentVisibleRect: NSRect { .zero }
  open var contentSize: NSSize { .zero }
  open var hasVerticalScroller = false
  open var hasHorizontalScroller = false
  open var autohidesScrollers = false
  open var scrollerStyle: NSScroller.Style = .overlay
  open var borderType: NSBorderType = .noBorder
  open var drawsBackground = true
  open var backgroundColor = NSColor.clear
  open var verticalScrollElasticity: Elasticity = .automatic
  open var horizontalScrollElasticity: Elasticity = .automatic
  open var contentInsets = NSEdgeInsets()
  open var automaticallyAdjustsContentInsets = true
  open var allowsMagnification = false
  open var magnification: CGFloat = 1
  open func reflectScrolledClipView(_ cView: NSClipView) {}
  open func flashScrollers() {}
}
public enum NSBorderType: UInt, Sendable { case noBorder = 0, lineBorder, bezelBorder, grooveBorder }

@MainActor open class NSSlider: NSControl {
  public enum SliderType: UInt, Sendable { case linear = 0, circular = 1 }
  public enum TickMarkPosition: UInt, Sendable { case below = 0, above = 1
    public static var leading: TickMarkPosition { .above }
    public static var trailing: TickMarkPosition { .below }
  }
  public convenience init(target: Any?, action: Selector?) { self.init() }
  public convenience init(value: Double, minValue: Double, maxValue: Double, target: Any?, action: Selector?) { self.init() }
  open var sliderType: SliderType = .linear
  open var minValue: Double = 0
  open var maxValue: Double = 1
  open var altIncrementValue: Double = 0
  open var isVertical = false
  open var trackFillColor: NSColor?
  open var numberOfTickMarks = 0
  open var tickMarkPosition: TickMarkPosition = .below
  open var allowsTickMarkValuesOnly = false
}
@MainActor open class NSSwitch: NSControl {
  open var state: NSControl.StateValue = .off
}
@MainActor open class NSStepper: NSControl {
  open var minValue: Double = 0
  open var maxValue: Double = 59
  open var increment: Double = 1
  open var valueWraps = false
  open var autorepeat = true
}
@MainActor open class NSLevelIndicator: NSControl {
  open var minValue: Double = 0
  open var maxValue: Double = 1
}
@MainActor open class NSProgressIndicator: NSView {
  public enum Style: UInt, Sendable { case bar = 0, spinning = 1 }
  open var style: Style = .bar
  open var isIndeterminate = true
  open var controlSize: NSControl.ControlSize = .regular
  open var doubleValue: Double = 0
  open var minValue: Double = 0
  open var maxValue: Double = 100
  open var isDisplayedWhenStopped = true
  open func startAnimation(_ sender: Any?) {}
  open func stopAnimation(_ sender: Any?) {}
  open func increment(by delta: Double) {}
  open func sizeToFit() {}
}
@MainActor open class NSPopUpButton: NSButton {
  public init(frame buttonFrame: NSRect, pullsDown flag: Bool) { super.init(frame: buttonFrame) }
  public override init(frame frameRect: NSRect) { super.init(frame: frameRect) }
  public required init?(coder: NSCoder) { super.init(coder: coder) }
  open var pullsDown = false
  open var autoenablesItems = true
  open var itemArray: [NSMenuItem] { [] }
  open var numberOfItems: Int { 0 }
  open var itemTitles: [String] { [] }
  open var selectedItem: NSMenuItem? { nil }
  open var indexOfSelectedItem: Int { -1 }
  open var titleOfSelectedItem: String? { nil }
  open var lastItem: NSMenuItem? { nil }
  open func selectedTag() -> Int { -1 }
  open func addItem(withTitle title: String) {}
  open func addItems(withTitles itemTitles: [String]) {}
  open func insertItem(withTitle title: String, at index: Int) {}
  open func removeItem(withTitle title: String) {}
  open func removeItem(at index: Int) {}
  open func removeAllItems() {}
  open func item(at index: Int) -> NSMenuItem? { nil }
  open func item(withTitle title: String) -> NSMenuItem? { nil }
  open func indexOfItem(withTitle title: String) -> Int { -1 }
  open func indexOfItem(withTag tag: Int) -> Int { -1 }
  open func indexOfItem(withRepresentedObject obj: Any?) -> Int { -1 }
  open func select(_ item: NSMenuItem?) {}
  open func selectItem(at index: Int) {}
  open func selectItem(withTitle title: String) {}
  @discardableResult open func selectItem(withTag tag: Int) -> Bool { false }
  open func synchronizeTitleAndSelectedItem() {}
}
@MainActor open class NSSegmentedControl: NSControl {
  public enum SwitchTracking: UInt, Sendable { case selectOne = 0, selectAny, momentary, momentaryAccelerator }
  public enum Style: Int, Sendable { case automatic = 0, rounded, roundRect = 3, texturedSquare, smallSquare = 6, separated = 8, texturedRounded = 2, capsule = 5 }
  public enum Distribution: Int, Sendable { case fit = 0, fill, fillEqually, fillProportionally }
  public convenience init(labels: [String], trackingMode: SwitchTracking, target: Any?, action: Selector?) { self.init() }
  public convenience init(images: [NSImage], trackingMode: SwitchTracking, target: Any?, action: Selector?) { self.init() }
  open var segmentCount = 0
  open var selectedSegment = -1
  open var indexOfSelectedItem: Int { -1 }
  open var trackingMode: SwitchTracking = .selectOne
  open var segmentStyle: Style = .automatic
  open var segmentDistribution: Distribution = .fill
  open var selectedSegmentBezelColor: NSColor?
  open func setLabel(_ label: String, forSegment segment: Int) {}
  open func label(forSegment segment: Int) -> String? { nil }
  open func setImage(_ image: NSImage?, forSegment segment: Int) {}
  open func setWidth(_ width: CGFloat, forSegment segment: Int) {}
  open func setSelected(_ selected: Bool, forSegment segment: Int) {}
  open func isSelected(forSegment segment: Int) -> Bool { false }
  open func setEnabled(_ enabled: Bool, forSegment segment: Int) {}
  open func setToolTip(_ toolTip: String?, forSegment segment: Int) {}
  open func setTag(_ tag: Int, forSegment segment: Int) {}
  open func tag(forSegment segment: Int) -> Int { 0 }
}
@MainActor open class NSColorWell: NSControl {
  open var color = NSColor.black
  open var isActive: Bool { false }
  open var supportsAlpha = true
}
@MainActor open class NSGridView: NSView {
  public enum Placement: Int, Sendable { case inherited = 0, none, leading, center, trailing, fill
    public static var top: Placement { .leading }
    public static var bottom: Placement { .trailing }
  }
  public enum RowAlignment: Int, Sendable { case inherited = 0, none, firstBaseline, lastBaseline }
  public convenience init(views rows: [[NSView]]) { self.init() }
  public convenience init(numberOfColumns columnCount: Int, rows rowCount: Int) { self.init() }
  open var numberOfRows: Int { 0 }
  open var numberOfColumns: Int { 0 }
  open var rowSpacing: CGFloat = 6
  open var columnSpacing: CGFloat = 6
  open var xPlacement: Placement = .leading
  open var yPlacement: Placement = .top
  open var rowAlignment: RowAlignment = .none
  @discardableResult open func addRow(with views: [NSView]) -> NSGridRow { NSGridRow() }
  open func row(at index: Int) -> NSGridRow { NSGridRow() }
  open func column(at index: Int) -> NSGridColumn { NSGridColumn() }
  open func cell(atColumnIndex columnIndex: Int, rowIndex: Int) -> NSGridCell { NSGridCell() }
  open func mergeCells(inHorizontalRange hRange: NSRange, verticalRange vRange: NSRange) {}
  public static let sizedForContent: CGFloat = 0
}
@MainActor open class NSGridRow: NSObject {
  open var yPlacement: NSGridView.Placement = .inherited
  open var rowAlignment: NSGridView.RowAlignment = .inherited
  open var height: CGFloat = 0
  open var topPadding: CGFloat = 0
  open var bottomPadding: CGFloat = 0
  open var isHidden = false
  open func mergeCells(in range: NSRange) {}
}
@MainActor open class NSGridColumn: NSObject {
  open var xPlacement: NSGridView.Placement = .inherited
  open var width: CGFloat = 0
  open var leadingPadding: CGFloat = 0
  open var trailingPadding: CGFloat = 0
  open var isHidden = false
}
@MainActor open class NSGridCell: NSObject {
  open var contentView: NSView?
  open var xPlacement: NSGridView.Placement = .inherited
  open var yPlacement: NSGridView.Placement = .inherited
  open class var emptyContentView: NSView { NSView() }
}
@MainActor open class NSTabViewItem: NSObject {
  public convenience init(viewController: NSViewController) { self.init() }
  public convenience init(identifier: Any?) { self.init() }
  open var label = ""
  open var image: NSImage?
  open var view: NSView?
  open var viewController: NSViewController?
  open var identifier: Any?
}
@MainActor open class NSTabView: NSView {
  public enum TabType: UInt, Sendable { case topTabsBezelBorder = 0, leftTabsBezelBorder, bottomTabsBezelBorder, rightTabsBezelBorder, noTabsBezelBorder, noTabsLineBorder, noTabsNoBorder }
  open var tabViewType: TabType = .topTabsBezelBorder
  open var tabViewItems: [NSTabViewItem] = []
  open var selectedTabViewItem: NSTabViewItem? { nil }
  open var numberOfTabViewItems: Int { 0 }
  open func addTabViewItem(_ tabViewItem: NSTabViewItem) {}
  open func selectTabViewItem(at index: Int) {}
  open func selectTabViewItem(_ tabViewItem: NSTabViewItem?) {}
}
@MainActor open class NSTabViewController: NSViewController {
  public enum TabStyle: Int, Sendable { case segmentedControlOnTop = 0, segmentedControlOnBottom, toolbar, unspecified = -1 }
  open var tabStyle: TabStyle = .segmentedControlOnTop
  open var tabViewItems: [NSTabViewItem] = []
  open var selectedTabViewItemIndex = 0
  open var canPropagateSelectedChildViewControllerTitle = true
  open func addTabViewItem(_ tabViewItem: NSTabViewItem) {}
}
