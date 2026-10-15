// A stand-in for AppKit: windows and panels. See Application.swift.

@MainActor open class NSWindowTabGroup: NSObject {
  open var identifier: NSWindow.TabbingIdentifier { "" }
  open var selectedWindow: NSWindow?
  open var windows: [NSWindow] { [] }
  open var isOverviewVisible = false
  open var isTabBarVisible: Bool { false }
  open func addWindow(_ window: NSWindow) {}
  open func insertWindow(_ window: NSWindow, at index: Int) {}
  open func removeWindow(_ window: NSWindow) {}
}

@MainActor public protocol NSWindowDelegate: NSObjectProtocol {
  func windowShouldClose(_ sender: NSWindow) -> Bool
  func windowWillClose(_ notification: Notification)
  func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize
  func windowDidResize(_ notification: Notification)
  func windowDidEndLiveResize(_ notification: Notification)
  func windowWillMove(_ notification: Notification)
  func windowDidMove(_ notification: Notification)
  func windowDidBecomeKey(_ notification: Notification)
  func windowDidResignKey(_ notification: Notification)
  func windowDidBecomeMain(_ notification: Notification)
  func windowDidResignMain(_ notification: Notification)
  func windowDidMiniaturize(_ notification: Notification)
  func windowDidDeminiaturize(_ notification: Notification)
  func windowDidChangeScreen(_ notification: Notification)
  func windowDidChangeBackingProperties(_ notification: Notification)
  func windowDidChangeOcclusionState(_ notification: Notification)
  func windowWillEnterFullScreen(_ notification: Notification)
  func windowDidEnterFullScreen(_ notification: Notification)
  func windowWillExitFullScreen(_ notification: Notification)
  func windowDidExitFullScreen(_ notification: Notification)
  func windowDidExpose(_ notification: Notification)
  func windowDidUpdate(_ notification: Notification)
}
extension NSWindowDelegate {
  public func windowShouldClose(_ sender: NSWindow) -> Bool { true }
  public func windowWillClose(_ notification: Notification) {}
  public func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize { frameSize }
  public func windowDidResize(_ notification: Notification) {}
  public func windowDidEndLiveResize(_ notification: Notification) {}
  public func windowWillMove(_ notification: Notification) {}
  public func windowDidMove(_ notification: Notification) {}
  public func windowDidBecomeKey(_ notification: Notification) {}
  public func windowDidResignKey(_ notification: Notification) {}
  public func windowDidBecomeMain(_ notification: Notification) {}
  public func windowDidResignMain(_ notification: Notification) {}
  public func windowDidMiniaturize(_ notification: Notification) {}
  public func windowDidDeminiaturize(_ notification: Notification) {}
  public func windowDidChangeScreen(_ notification: Notification) {}
  public func windowDidChangeBackingProperties(_ notification: Notification) {}
  public func windowDidChangeOcclusionState(_ notification: Notification) {}
  public func windowWillEnterFullScreen(_ notification: Notification) {}
  public func windowDidEnterFullScreen(_ notification: Notification) {}
  public func windowWillExitFullScreen(_ notification: Notification) {}
  public func windowDidExitFullScreen(_ notification: Notification) {}
  public func windowDidExpose(_ notification: Notification) {}
  public func windowDidUpdate(_ notification: Notification) {}
}

@MainActor open class NSWindow: NSResponder, NSAnimatablePropertyContainer, NSAppearanceCustomization, NSUserInterfaceItemIdentification {
  public struct StyleMask: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let borderless = StyleMask([])
    public static let titled = StyleMask(rawValue: 1 << 0)
    public static let closable = StyleMask(rawValue: 1 << 1)
    public static let miniaturizable = StyleMask(rawValue: 1 << 2)
    public static let resizable = StyleMask(rawValue: 1 << 3)
    public static let utilityWindow = StyleMask(rawValue: 1 << 4)
    public static let docModalWindow = StyleMask(rawValue: 1 << 6)
    public static let nonactivatingPanel = StyleMask(rawValue: 1 << 7)
    public static let unifiedTitleAndToolbar = StyleMask(rawValue: 1 << 12)
    public static let hudWindow = StyleMask(rawValue: 1 << 13)
    public static let fullScreen = StyleMask(rawValue: 1 << 14)
    public static let fullSizeContentView = StyleMask(rawValue: 1 << 15)
  }
  public enum BackingStoreType: UInt, Sendable { case buffered = 2 }
  public enum OrderingMode: Int, Sendable { case above = 1, below = -1, out = 0 }
  public enum TabbingMode: Int, Sendable { case automatic = 0, preferred = 1, disallowed = 2 }
  public enum UserTabbingPreference: Int, Sendable { case manual = 0, always = 1, inFullScreen = 2 }
  public enum TitleVisibility: Int, Sendable { case visible = 0, hidden = 1 }
  public enum ToolbarStyle: Int, Sendable { case automatic = 0, expanded, preference, unified, unifiedCompact }
  public enum AnimationBehavior: Int, Sendable { case `default` = 0, none = 2, documentWindow = 3, utilityWindow = 4, alertPanel = 5 }
  public enum SharingType: UInt, Sendable { case none = 0, readOnly = 1, readWrite = 2 }
  public enum ButtonType: UInt, Sendable {
    case closeButton = 0, miniaturizeButton, zoomButton, toolbarButton, documentIconButton, documentVersionsButton = 6
  }
  public enum SelectionDirection: UInt, Sendable { case directSelection = 0, selectingNext, selectingPrevious }
  public struct CollectionBehavior: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let canJoinAllSpaces = CollectionBehavior(rawValue: 1 << 0)
    public static let moveToActiveSpace = CollectionBehavior(rawValue: 1 << 1)
    public static let managed = CollectionBehavior(rawValue: 1 << 2)
    public static let transient = CollectionBehavior(rawValue: 1 << 3)
    public static let stationary = CollectionBehavior(rawValue: 1 << 4)
    public static let participatesInCycle = CollectionBehavior(rawValue: 1 << 5)
    public static let ignoresCycle = CollectionBehavior(rawValue: 1 << 6)
    public static let fullScreenPrimary = CollectionBehavior(rawValue: 1 << 7)
    public static let fullScreenAuxiliary = CollectionBehavior(rawValue: 1 << 8)
    public static let fullScreenNone = CollectionBehavior(rawValue: 1 << 9)
    public static let fullScreenAllowsTiling = CollectionBehavior(rawValue: 1 << 11)
    public static let fullScreenDisallowsTiling = CollectionBehavior(rawValue: 1 << 12)
    public static let primary = CollectionBehavior(rawValue: 1 << 16)
    public static let auxiliary = CollectionBehavior(rawValue: 1 << 17)
    public static let canJoinAllApplications = CollectionBehavior(rawValue: 1 << 18)
  }
  public struct OcclusionState: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let visible = OcclusionState(rawValue: 2)
  }
  public struct NumberListOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let allApplications = NumberListOptions(rawValue: 1)
    public static let allSpaces = NumberListOptions(rawValue: 16)
  }
  public struct Level: RawRepresentable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public init(_ rawValue: Int) { self.rawValue = rawValue }
    public static let normal = Level(0)
    public static let floating = Level(3)
    public static let submenu = Level(3)
    public static let tornOffMenu = Level(3)
    public static let mainMenu = Level(24)
    public static let statusBar = Level(25)
    public static let modalPanel = Level(8)
    public static let popUpMenu = Level(101)
    public static let screenSaver = Level(1000)
  }
  public typealias TabbingIdentifier = String
  public typealias FrameAutosaveName = String

  public init(contentRect: NSRect, styleMask style: StyleMask, backing backingStoreType: BackingStoreType, defer flag: Bool) { super.init() }
  public convenience init(
    contentRect: NSRect, styleMask style: StyleMask, backing backingStoreType: BackingStoreType, defer flag: Bool, screen: NSScreen?
  ) { self.init(contentRect: contentRect, styleMask: style, backing: backingStoreType, defer: flag) }
  public convenience init(contentViewController: NSViewController) {
    self.init(contentRect: .zero, styleMask: [], backing: .buffered, defer: true)
  }
  public convenience override init() { self.init(contentRect: .zero, styleMask: [], backing: .buffered, defer: true) }

  open class func frameRect(forContentRect cRect: NSRect, styleMask style: StyleMask) -> NSRect { cRect }
  open class func contentRect(forFrameRect fRect: NSRect, styleMask style: StyleMask) -> NSRect { fRect }
  open class func windowNumbers(options: NumberListOptions = []) -> [NSNumber]? { nil }
  open class func windowNumber(at point: NSPoint, belowWindowWithWindowNumber windowNumber: Int) -> Int { 0 }
  open class func standardWindowButton(_ b: ButtonType, for styleMask: StyleMask) -> NSButton? { nil }
  open class var allowsAutomaticWindowTabbing: Bool {
    get { true }
    set {}
  }
  open class var userTabbingPreference: UserTabbingPreference { .manual }

  open var title = ""
  open var subtitle = ""
  open var titleVisibility: TitleVisibility = .visible
  open var titlebarAppearsTransparent = false
  open var toolbarStyle: ToolbarStyle = .automatic
  open var toolbar: NSToolbar?
  open var identifier: NSUserInterfaceItemIdentifier?
  open weak var delegate: (any NSWindowDelegate)?
  open var windowController: NSWindowController?
  open var contentView: NSView?
  open var contentViewController: NSViewController?
  open var contentLayoutRect: NSRect { .zero }
  open var contentLayoutGuide: Any? { nil }
  open var styleMask: StyleMask = []
  open var frame: NSRect { .zero }
  open var screen: NSScreen? { nil }
  open var deepestScreen: NSScreen? { nil }
  open var backingScaleFactor: CGFloat { 2 }
  open var windowNumber: Int { 0 }
  open var level: Level = .normal
  open var collectionBehavior: CollectionBehavior = []
  open var animationBehavior: AnimationBehavior = .default
  open var sharingType: SharingType = .readOnly
  open var isReleasedWhenClosed = true
  open var isOpaque = true
  open var hasShadow = true
  open var alphaValue: CGFloat = 1
  open var backgroundColor: NSColor!
  open var ignoresMouseEvents = false
  open var acceptsMouseMovedEvents = false
  open var isMovable = true
  open var isMovableByWindowBackground = false
  open var hidesOnDeactivate = false
  open var allowsToolTipsWhenApplicationIsInactive = false
  open var canHide = true
  open var isExcludedFromWindowsMenu = false
  open var isRestorable = false
  open var displaysWhenScreenProfileChanges = false
  open var preventsApplicationTerminationWhenModal = true
  open var minSize = NSSize.zero
  open var maxSize = NSSize.zero
  open var contentMinSize = NSSize.zero
  open var contentMaxSize = NSSize.zero
  open var aspectRatio = NSSize.zero
  open var contentAspectRatio = NSSize.zero
  open var resizeIncrements = NSSize.zero
  open var minFullScreenContentSize = NSSize.zero
  open var maxFullScreenContentSize = NSSize.zero
  open var isVisible: Bool { false }
  open var isKeyWindow: Bool { false }
  open var isMainWindow: Bool { false }
  open var canBecomeKey: Bool { true }
  open var canBecomeMain: Bool { true }
  open var isMiniaturized: Bool { false }
  open var isZoomed: Bool { false }
  open var isOnActiveSpace: Bool { true }
  open var isSheet: Bool { false }
  open var isModalPanel: Bool { false }
  open var isFloatingPanel: Bool { false }
  open var inLiveResize: Bool { false }
  open var isResizable: Bool { true }
  open var worksWhenModal: Bool { false }
  open var occlusionState: OcclusionState { [] }
  open var firstResponder: NSResponder? { nil }
  open var initialFirstResponder: NSView?
  open var currentEvent: NSEvent? { nil }
  open var mouseLocationOutsideOfEventStream: NSPoint { .zero }
  open var parent: NSWindow?
  open var childWindows: [NSWindow]? { nil }
  open var sheets: [NSWindow] { [] }
  open var attachedSheet: NSWindow? { nil }
  open var sheetParent: NSWindow? { nil }
  open var tabbingIdentifier: TabbingIdentifier = ""
  open var tabbingMode: TabbingMode = .automatic
  open var tabGroup: NSWindowTabGroup? { nil }
  open var tabbedWindows: [NSWindow]? { nil }
  open var appearance: NSAppearance?
  open var effectiveAppearance: NSAppearance { NSAppearance() }
  open var colorSpace: NSColorSpace?
  open var frameAutosaveName: FrameAutosaveName { "" }
  open var representedURL: URL?
  open var isDocumentEdited = false
  open var viewsNeedDisplay = false
  open var autorecalculatesKeyViewLoop = false
  open var defaultButtonCell: NSButtonCell?

  open func frameRect(forContentRect contentRect: NSRect) -> NSRect { contentRect }
  open func contentRect(forFrameRect frameRect: NSRect) -> NSRect { frameRect }
  open func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
  open func setFrame(_ frameRect: NSRect, display flag: Bool) {}
  open func setFrame(_ frameRect: NSRect, display displayFlag: Bool, animate animateFlag: Bool) {}
  open func setFrameOrigin(_ point: NSPoint) {}
  open func setFrameTopLeftPoint(_ point: NSPoint) {}
  open func setContentSize(_ size: NSSize) {}
  open func cascadeTopLeft(from topLeftPoint: NSPoint) -> NSPoint { topLeftPoint }
  open func animationResizeTime(_ newFrame: NSRect) -> TimeInterval { 0 }
  open func center() {}
  open func makeKey() {}
  open func makeMain() {}
  open func makeKeyAndOrderFront(_ sender: Any?) {}
  open func becomeKey() {}
  open func resignKey() {}
  open func becomeMain() {}
  open func resignMain() {}
  open func orderFront(_ sender: Any?) {}
  open func orderBack(_ sender: Any?) {}
  open func orderOut(_ sender: Any?) {}
  open func orderFrontRegardless() {}
  open func order(_ place: OrderingMode, relativeTo otherWin: Int) {}
  open func close() {}
  open func performClose(_ sender: Any?) {}
  open func miniaturize(_ sender: Any?) {}
  open func deminiaturize(_ sender: Any?) {}
  open func performMiniaturize(_ sender: Any?) {}
  open func zoom(_ sender: Any?) {}
  open func performZoom(_ sender: Any?) {}
  open func toggleFullScreen(_ sender: Any?) {}
  open func display() {}
  open func displayIfNeeded() {}
  open func update() {}
  open func invalidateShadow() {}
  open func layoutIfNeeded() {}
  open func updateConstraintsIfNeeded() {}
  open func disableCursorRects() {}
  open func enableCursorRects() {}
  open func discardCursorRects() {}
  open func invalidateCursorRects(for view: NSView) {}
  open func resetCursorRects() {}
  @discardableResult open func makeFirstResponder(_ responder: NSResponder?) -> Bool { true }
  open func selectNextKeyView(_ sender: Any?) {}
  open func selectPreviousKeyView(_ sender: Any?) {}
  open func recalculateKeyViewLoop() {}
  open func sendEvent(_ event: NSEvent) {}
  open func postEvent(_ event: NSEvent, atStart flag: Bool) {}
  open func nextEvent(matching mask: NSEvent.EventTypeMask) -> NSEvent? { nil }
  open func nextEvent(matching mask: NSEvent.EventTypeMask, until expiration: Date?, inMode mode: RunLoop.Mode, dequeue deqFlag: Bool) -> NSEvent? {
    nil
  }
  open func trackEvents(
    matching mask: NSEvent.EventTypeMask, timeout: TimeInterval, mode: RunLoop.Mode,
    handler trackingHandler: @escaping (NSEvent?, UnsafeMutablePointer<ObjCBool>) -> Void) {}
  open func performDrag(with event: NSEvent) {}
  open func convertToScreen(_ rect: NSRect) -> NSRect { rect }
  open func convertFromScreen(_ rect: NSRect) -> NSRect { rect }
  open func convertPoint(toScreen point: NSPoint) -> NSPoint { point }
  open func convertPoint(fromScreen point: NSPoint) -> NSPoint { point }
  open func convertToBacking(_ rect: NSRect) -> NSRect { rect }
  open func convertFromBacking(_ rect: NSRect) -> NSRect { rect }
  open func backingAlignedRect(_ rect: NSRect, options: AlignmentOptions) -> NSRect { rect }
  open func addChildWindow(_ childWin: NSWindow, ordered place: OrderingMode) {}
  open func removeChildWindow(_ childWin: NSWindow) {}
  open func beginSheet(_ sheetWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {}
  open func beginCriticalSheet(_ sheetWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {}
  open func endSheet(_ sheetWindow: NSWindow) {}
  open func endSheet(_ sheetWindow: NSWindow, returnCode: NSApplication.ModalResponse) {}
  open func addTabbedWindow(_ window: NSWindow, ordered: OrderingMode) {}
  open func moveTabToNewWindow(_ sender: Any?) {}
  open func mergeAllWindows(_ sender: Any?) {}
  open func selectNextTab(_ sender: Any?) {}
  open func selectPreviousTab(_ sender: Any?) {}
  open func toggleTabBar(_ sender: Any?) {}
  open func toggleTabOverview(_ sender: Any?) {}
  open func standardWindowButton(_ b: ButtonType) -> NSButton? { nil }
  open func addTitlebarAccessoryViewController(_ childViewController: NSTitlebarAccessoryViewController) {}
  @discardableResult open func setFrameAutosaveName(_ name: FrameAutosaveName) -> Bool { true }
  @discardableResult open func setFrameUsingName(_ name: FrameAutosaveName) -> Bool { true }
  open func saveFrame(usingName name: FrameAutosaveName) {}
  open func setIsVisible(_ flag: Bool) {}
  open func setIsMiniaturized(_ flag: Bool) {}
  open func setIsZoomed(_ flag: Bool) {}
  open func fieldEditor(_ createFlag: Bool, for object: Any?) -> NSText? { nil }
  open func endEditing(for object: Any?) {}
  open func displayLink(target: Any, selector: Selector) -> CADisplayLink { CADisplayLink() }
  open func setAccessibilityElement(_ accessibilityElement: Bool) {}
  open func setAccessibilityLabel(_ accessibilityLabel: String?) {}
  open func setAccessibilityRole(_ accessibilityRole: NSAccessibility.Role?) {}
  open func setAccessibilitySubrole(_ accessibilitySubrole: NSAccessibility.Subrole?) {}
  open func setAccessibilityHidden(_ accessibilityHidden: Bool) {}

  public nonisolated static let didBecomeKeyNotification = NSNotification.Name("NSWindowDidBecomeKeyNotification")
  public nonisolated static let didResignKeyNotification = NSNotification.Name("NSWindowDidResignKeyNotification")
  public nonisolated static let didBecomeMainNotification = NSNotification.Name("NSWindowDidBecomeMainNotification")
  public nonisolated static let didResignMainNotification = NSNotification.Name("NSWindowDidResignMainNotification")
  public nonisolated static let didMoveNotification = NSNotification.Name("NSWindowDidMoveNotification")
  public nonisolated static let didResizeNotification = NSNotification.Name("NSWindowDidResizeNotification")
  public nonisolated static let didEndLiveResizeNotification = NSNotification.Name("NSWindowDidEndLiveResizeNotification")
  public nonisolated static let willCloseNotification = NSNotification.Name("NSWindowWillCloseNotification")
  public nonisolated static let didMiniaturizeNotification = NSNotification.Name("NSWindowDidMiniaturizeNotification")
  public nonisolated static let didDeminiaturizeNotification = NSNotification.Name("NSWindowDidDeminiaturizeNotification")
  public nonisolated static let didChangeScreenNotification = NSNotification.Name("NSWindowDidChangeScreenNotification")
  public nonisolated static let didChangeBackingPropertiesNotification = NSNotification.Name("NSWindowDidChangeBackingPropertiesNotification")
  public nonisolated static let didChangeOcclusionStateNotification = NSNotification.Name("NSWindowDidChangeOcclusionStateNotification")
  public nonisolated static let didEnterFullScreenNotification = NSNotification.Name("NSWindowDidEnterFullScreenNotification")
  public nonisolated static let didExitFullScreenNotification = NSNotification.Name("NSWindowDidExitFullScreenNotification")
  public nonisolated static let willEnterFullScreenNotification = NSNotification.Name("NSWindowWillEnterFullScreenNotification")
  public nonisolated static let willExitFullScreenNotification = NSNotification.Name("NSWindowWillExitFullScreenNotification")
}

@MainActor open class NSPanel: NSWindow {
  open override var isFloatingPanel: Bool {
    get { false }
    set {}
  }
  open var becomesKeyOnlyIfNeeded = false
  open override var worksWhenModal: Bool {
    get { false }
    set {}
  }
}

@MainActor open class NSWindowController: NSResponder {
  public init(window: NSWindow?) { super.init() }
  public required override init?(coder: NSCoder) { super.init(coder: coder) }
  public convenience override init() { self.init(window: nil) }
  open var window: NSWindow?
  open var isWindowLoaded: Bool { false }
  open var contentViewController: NSViewController?
  open var shouldCascadeWindows = true
  open var windowFrameAutosaveName: NSWindow.FrameAutosaveName = ""
  open func showWindow(_ sender: Any?) {}
  open func close() {}
  open func loadWindow() {}
  open func windowWillLoad() {}
  open func windowDidLoad() {}
}

@MainActor open class NSViewController: NSResponder, NSUserInterfaceItemIdentification {
  public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) { super.init() }
  public required override init?(coder: NSCoder) { super.init(coder: coder) }
  public convenience override init() { self.init(nibName: nil, bundle: nil) }
  open var view = NSView()
  open var viewIfLoaded: NSView? { nil }
  open var isViewLoaded: Bool { false }
  open var title: String?
  open var representedObject: Any?
  open var identifier: NSUserInterfaceItemIdentifier?
  open var preferredContentSize = NSSize.zero
  open var children: [NSViewController] = []
  open var parent: NSViewController? { nil }
  open func loadView() {}
  open func viewDidLoad() {}
  open func viewWillAppear() {}
  open func viewDidAppear() {}
  open func viewWillDisappear() {}
  open func viewDidDisappear() {}
  open func viewWillLayout() {}
  open func viewDidLayout() {}
  open func updateViewConstraints() {}
  open func addChild(_ childViewController: NSViewController) {}
  open func removeFromParent() {}
  open func dismiss(_ sender: Any?) {}
  open func presentAsSheet(_ viewController: NSViewController) {}
  open func presentAsModalWindow(_ viewController: NSViewController) {}
}
@MainActor open class NSTitlebarAccessoryViewController: NSViewController {
  open var layoutAttribute: NSLayoutConstraint.Attribute = .bottom
  open var fullScreenMinHeight: CGFloat = 0
  open var isHidden = false
}

@MainActor open class NSToolbar: NSObject {
  public typealias Identifier = String
  public enum DisplayMode: UInt, Sendable { case `default` = 0, iconAndLabel, iconOnly, labelOnly }
  public init(identifier: Identifier) {}
  open var isVisible = true
  open var displayMode: DisplayMode = .default
  open var allowsUserCustomization = false
  open var showsBaselineSeparator = true
}

@MainActor open class NSPopover: NSResponder {
  public enum Behavior: Int, Sendable { case applicationDefined = 0, transient = 1, semitransient = 2 }
  open var contentViewController: NSViewController?
  open var contentSize = NSSize.zero
  open var behavior: Behavior = .applicationDefined
  open var animates = true
  open var isShown: Bool { false }
  open var appearance: NSAppearance?
  open func show(relativeTo positioningRect: NSRect, of positioningView: NSView, preferredEdge: NSRectEdge) {}
  open func performClose(_ sender: Any?) {}
  open func close() {}
}

@MainActor open class NSAlert: NSObject {
  public enum Style: UInt, Sendable { case warning = 0, informational = 1, critical = 2 }
  public convenience init(error: any Error) { self.init() }
  open var messageText = ""
  open var informativeText = ""
  open var icon: NSImage!
  open var alertStyle: Style = .warning
  open var buttons: [NSButton] { [] }
  open var showsSuppressionButton = false
  open var suppressionButton: NSButton? { nil }
  open var accessoryView: NSView?
  open var showsHelp = false
  open var window: NSWindow { NSWindow() }
  @discardableResult open func addButton(withTitle title: String) -> NSButton { NSButton() }
  @discardableResult open func runModal() -> NSApplication.ModalResponse { .OK }
  open func beginSheetModal(for sheetWindow: NSWindow, completionHandler handler: ((NSApplication.ModalResponse) -> Void)? = nil) {}
  open func beginSheetModal(for sheetWindow: NSWindow) async -> NSApplication.ModalResponse { .OK }
  open func layout() {}
}

@MainActor open class NSSavePanel: NSPanel {
  open var url: URL? { nil }
  open var directoryURL: URL?
  open var nameFieldStringValue = ""
  open var message: String!
  open var prompt: String!
  open var canCreateDirectories = true
  open var showsHiddenFiles = false
  open var allowedFileTypes: [String]?
  open func runModal() -> NSApplication.ModalResponse { .OK }
  open func begin(completionHandler handler: @escaping (NSApplication.ModalResponse) -> Void) {}
  open func beginSheetModal(for window: NSWindow, completionHandler handler: @escaping (NSApplication.ModalResponse) -> Void) {}
}
@MainActor open class NSOpenPanel: NSSavePanel {
  open var urls: [URL] { [] }
  open var canChooseFiles = true
  open var canChooseDirectories = false
  open var allowsMultipleSelection = false
  open var resolvesAliases = true
}

public enum NSAccessibility {
  public struct Role: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let unknown = Role(rawValue: "AXUnknown")
    public static let button = Role(rawValue: "AXButton")
    public static let group = Role(rawValue: "AXGroup")
    public static let image = Role(rawValue: "AXImage")
    public static let staticText = Role(rawValue: "AXStaticText")
    public static let window = Role(rawValue: "AXWindow")
    public static let splitter = Role(rawValue: "AXSplitter")
    public static let handle = Role(rawValue: "AXHandle")
    public static let list = Role(rawValue: "AXList")
  }
  public struct Subrole: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let unknown = Subrole(rawValue: "AXUnknown")
    public static let standardWindow = Subrole(rawValue: "AXStandardWindow")
    public static let dialog = Subrole(rawValue: "AXDialog")
    public static let systemDialog = Subrole(rawValue: "AXSystemDialog")
    public static let floatingWindow = Subrole(rawValue: "AXFloatingWindow")
    public static let systemFloatingWindow = Subrole(rawValue: "AXSystemFloatingWindow")
  }
  public struct Notification: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let announcementRequested = Notification(rawValue: "AXAnnouncementRequested")
    public static let layoutChanged = Notification(rawValue: "AXLayoutChanged")
    public static let valueChanged = Notification(rawValue: "AXValueChanged")
    public static let titleChanged = Notification(rawValue: "AXTitleChanged")
  }
  public struct NotificationUserInfoKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let announcement = NotificationUserInfoKey(rawValue: "AXAnnouncementKey")
    public static let priority = NotificationUserInfoKey(rawValue: "AXPriorityKey")
  }
  public static func post(element: Any, notification: Notification) {}
  public static func post(element: Any, notification: Notification, userInfo: [NotificationUserInfoKey: Any]?) {}
}
public enum NSAccessibilityPriorityLevel: Int, Sendable { case low = 10, medium = 50, high = 90 }
