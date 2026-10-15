// A stand-in for AppKit (scripts/typecheck-mac/README.md). Never shipped. Names, types, optionals and actor isolation as in the
// macOS 14 SDK. This file: the application, other applications, the workspace, screens. What Arbor's Accessibility layer asks of the last three is
// answered by the model of a Mac (stubs/FakeMacOS), for `make mac-on-linux` (scripts/mac-on-linux/README.md); the rest does nothing.
@_exported import ApplicationServices
import FakeMacOS
@_exported import QuartzCore

public struct NSDeviceDescriptionKey: Hashable, RawRepresentable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(_ rawValue: String) { self.rawValue = rawValue }
  public static let resolution = NSDeviceDescriptionKey("NSDeviceResolution")
  public static let colorSpaceName = NSDeviceDescriptionKey("NSDeviceColorSpaceName")
  public static let bitsPerSample = NSDeviceDescriptionKey("NSDeviceBitsPerSample")
  public static let isScreen = NSDeviceDescriptionKey("NSDeviceIsScreen")
  public static let size = NSDeviceDescriptionKey("NSDeviceSize")
}

@MainActor open class NSScreen: NSObject {
  var _screen: FakeMac.Screen?
  /// The model's coordinates have their origin at the top left of the first screen; AppKit's at its bottom left, and y grows upwards.
  private static func _appKit(_ rect: CGRect) -> NSRect {
    NSRect(x: rect.minX, y: (FakeMac.current.screens.first?.frame.height ?? 0) - rect.maxY, width: rect.width, height: rect.height)
  }
  open class var screens: [NSScreen] {
    FakeMac.current.screens.map { model in
      let screen = NSScreen()
      screen._screen = model
      return screen
    }
  }
  open class var main: NSScreen? { screens.first }
  open class var deepest: NSScreen? { nil }
  open class var screensHaveSeparateSpaces: Bool { true }
  open var frame: NSRect { _screen.map { Self._appKit($0.frame) } ?? .zero }
  open var visibleFrame: NSRect { _screen.map { Self._appKit($0.visibleFrame) } ?? .zero }
  open var deviceDescription: [NSDeviceDescriptionKey: Any] {
    _screen.map { [NSDeviceDescriptionKey("NSScreenNumber"): NSNumber(value: $0.id)] } ?? [:]
  }
  open var backingScaleFactor: CGFloat { 2 }
  open var localizedName: String { _screen?.name ?? "" }
  open var safeAreaInsets: NSEdgeInsets { NSEdgeInsets() }
  open var auxiliaryTopLeftArea: NSRect? { nil }
  open var auxiliaryTopRightArea: NSRect? { nil }
  open var maximumFramesPerSecond: Int { 60 }
  open var minimumRefreshInterval: TimeInterval { 0 }
  open var maximumRefreshInterval: TimeInterval { 0 }
  open var displayUpdateGranularity: TimeInterval { 0 }
  open var colorSpace: NSColorSpace? { nil }
  open func convertRectToBacking(_ rect: NSRect) -> NSRect { rect }
  open func convertRectFromBacking(_ rect: NSRect) -> NSRect { rect }
  open func backingAlignedRect(_ rect: NSRect, options: AlignmentOptions) -> NSRect { rect }
  open func displayLink(target: Any, selector: Selector) -> CADisplayLink { CADisplayLink() }
  public nonisolated static let colorSpaceDidChangeNotification = NSNotification.Name("NSScreenColorSpaceDidChangeNotification")
}

open class NSRunningApplication: NSObject, @unchecked Sendable {
  nonisolated(unsafe) var _pid: pid_t = 0
  private var _app: FakeMac.App? { FakeMac.current.app(_pid) }
  /// Also for a process that has ended: the notice of its end carries one.
  convenience init(_pid: pid_t) {
    self.init()
    self._pid = _pid
  }
  public convenience init?(processIdentifier pid: pid_t) {
    guard FakeMac.current.app(pid) != nil else { return nil }
    self.init(_pid: pid)
  }
  open class func runningApplications(withBundleIdentifier bundleIdentifier: String) -> [NSRunningApplication] {
    FakeMac.current.apps.filter { $0.bundleID == bundleIdentifier }.map { NSRunningApplication(_pid: $0.pid) }
  }
  open class var current: NSRunningApplication { NSRunningApplication(_pid: FakeMac.getpid()) }
  open class func terminateAutomaticallyTerminableApplications() {}
  open var processIdentifier: pid_t { _pid }
  open var bundleIdentifier: String? { _app?.bundleID }
  open var bundleURL: URL? { nil }
  open var executableURL: URL? { nil }
  open var localizedName: String? { _app?.name }
  open var icon: NSImage? { nil }
  open var launchDate: Date? { nil }
  open var activationPolicy: NSApplication.ActivationPolicy { _app.flatMap { .init(rawValue: $0.policy.rawValue) } ?? .prohibited }
  open var isFinishedLaunching: Bool { true }
  open var isTerminated: Bool { _app == nil }
  open var isActive: Bool { _app != nil && FakeMac.current.frontmostByWorkspace === _app }
  open var isHidden: Bool { _app?.isHidden ?? false }
  open var ownsMenuBar: Bool { false }
  open var executableArchitecture: Int { 0 }
  @discardableResult open func hide() -> Bool {
    guard let _app else { return false }
    FakeMac.current.hide(_app)
    return true
  }
  @discardableResult open func unhide() -> Bool {
    guard let _app else { return false }
    FakeMac.current.unhide(_app)
    return true
  }
  @discardableResult open func terminate() -> Bool { false }
  @discardableResult open func forceTerminate() -> Bool { false }
  @discardableResult open func activate(options: NSApplication.ActivationOptions = []) -> Bool { FakeMac.current.askToActivate(_pid) }
  @discardableResult open func activate(from application: NSRunningApplication, options: NSApplication.ActivationOptions = []) -> Bool { false }
}

open class NSWorkspace: NSObject, @unchecked Sendable {
  private static let _center = NotificationCenter()
  private static let _shared: NSWorkspace = {
    let workspace = NSWorkspace()
    FakeMac.postsWorkspaceNotification = { name, pid in
      _center.post(
        name: NSNotification.Name(name), object: workspace, userInfo: pid.map { [applicationUserInfoKey: NSRunningApplication(_pid: $0)] })
    }
    return workspace
  }()
  open class var shared: NSWorkspace { _shared }
  /// A centre of its own, as on a Mac: what is posted here does not reach `NotificationCenter.default`.
  open var notificationCenter: NotificationCenter { Self._center }
  open var runningApplications: [NSRunningApplication] { FakeMac.current.apps.map { NSRunningApplication(_pid: $0.pid) } }
  /// AppKit's copy of what the system knows, which can be behind (`FakeMac.frontmostLagsNoticeBy`).
  open var frontmostApplication: NSRunningApplication? { FakeMac.current.frontmostByWorkspace.map { NSRunningApplication(_pid: $0.pid) } }
  open var menuBarOwningApplication: NSRunningApplication? { nil }
  open var accessibilityDisplayShouldReduceMotion: Bool { false }
  open var accessibilityDisplayShouldReduceTransparency: Bool { false }
  open var accessibilityDisplayShouldIncreaseContrast: Bool { false }
  open var accessibilityDisplayShouldDifferentiateWithoutColor: Bool { false }
  open var accessibilityDisplayShouldInvertColors: Bool { false }
  open var isVoiceOverEnabled: Bool { false }
  open var isSwitchControlEnabled: Bool { false }
  @discardableResult open func open(_ url: URL) -> Bool { false }
  open func open(
    _ url: URL, configuration: OpenConfiguration, completionHandler: (@Sendable (NSRunningApplication?, (any Error)?) -> Void)? = nil) {}
  open func open(_ url: URL, configuration: OpenConfiguration) async throws -> NSRunningApplication { NSRunningApplication() }
  open func open(
    _ urls: [URL], withApplicationAt applicationURL: URL, configuration: OpenConfiguration,
    completionHandler: (@Sendable (NSRunningApplication?, (any Error)?) -> Void)? = nil) {}
  open func openApplication(
    at applicationURL: URL, configuration: OpenConfiguration,
    completionHandler: (@Sendable (NSRunningApplication?, (any Error)?) -> Void)? = nil) {}
  open func openApplication(at applicationURL: URL, configuration: OpenConfiguration) async throws -> NSRunningApplication {
    NSRunningApplication()
  }
  @discardableResult open func selectFile(_ fullPath: String?, inFileViewerRootedAtPath rootFullPath: String) -> Bool { false }
  open func activateFileViewerSelecting(_ fileURLs: [URL]) {}
  open func urlForApplication(withBundleIdentifier bundleIdentifier: String) -> URL? { nil }
  open func urlForApplication(toOpen url: URL) -> URL? { nil }
  open func icon(forFile fullPath: String) -> NSImage { NSImage() }
  open func hideOtherApplications() {}
  open func desktopImageURL(for screen: NSScreen) -> URL? { nil }
  public struct DesktopImageOptionKey: Hashable, RawRepresentable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let imageScaling = DesktopImageOptionKey(rawValue: "NSWorkspaceDesktopImageScalingKey")
    public static let allowClipping = DesktopImageOptionKey(rawValue: "NSWorkspaceDesktopImageAllowClippingKey")
    public static let fillColor = DesktopImageOptionKey(rawValue: "NSWorkspaceDesktopImageFillColorKey")
  }
  open func setDesktopImageURL(_ url: URL, for screen: NSScreen, options: [DesktopImageOptionKey: Any] = [:]) throws {}
  open func desktopImageOptions(for screen: NSScreen) -> [DesktopImageOptionKey: Any]? { nil }
  open class OpenConfiguration: NSObject {
    open var activates = true
    open var addsToRecentItems = true
    open var hides = false
    open var hidesOthers = false
    open var createsNewApplicationInstance = false
    open var promptsUserIfNeeded = true
    open var arguments: [String] = []
    open var environment: [String: String] = [:]
  }
  public static let willLaunchApplicationNotification = NSNotification.Name("NSWorkspaceWillLaunchApplicationNotification")
  public static let didLaunchApplicationNotification = NSNotification.Name("NSWorkspaceDidLaunchApplicationNotification")
  public static let didTerminateApplicationNotification = NSNotification.Name("NSWorkspaceDidTerminateApplicationNotification")
  public static let didActivateApplicationNotification = NSNotification.Name("NSWorkspaceDidActivateApplicationNotification")
  public static let didDeactivateApplicationNotification = NSNotification.Name("NSWorkspaceDidDeactivateApplicationNotification")
  public static let didHideApplicationNotification = NSNotification.Name("NSWorkspaceDidHideApplicationNotification")
  public static let didUnhideApplicationNotification = NSNotification.Name("NSWorkspaceDidUnhideApplicationNotification")
  public static let activeSpaceDidChangeNotification = NSNotification.Name("NSWorkspaceActiveSpaceDidChangeNotification")
  public static let willSleepNotification = NSNotification.Name("NSWorkspaceWillSleepNotification")
  public static let didWakeNotification = NSNotification.Name("NSWorkspaceDidWakeNotification")
  public static let screensDidSleepNotification = NSNotification.Name("NSWorkspaceScreensDidSleepNotification")
  public static let screensDidWakeNotification = NSNotification.Name("NSWorkspaceScreensDidWakeNotification")
  public static let sessionDidBecomeActiveNotification = NSNotification.Name("NSWorkspaceSessionDidBecomeActiveNotification")
  public static let sessionDidResignActiveNotification = NSNotification.Name("NSWorkspaceSessionDidResignActiveNotification")
  public static let willPowerOffNotification = NSNotification.Name("NSWorkspaceWillPowerOffNotification")
  public static let accessibilityDisplayOptionsDidChangeNotification = NSNotification.Name("NSWorkspaceAccessibilityDisplayOptionsDidChangeNotification")
  public static let applicationUserInfoKey = "NSWorkspaceApplicationKey"
}

@MainActor public protocol NSApplicationDelegate: NSObjectProtocol {
  func applicationWillFinishLaunching(_ notification: Notification)
  func applicationDidFinishLaunching(_ notification: Notification)
  func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
  func applicationWillTerminate(_ notification: Notification)
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool
  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool
  func applicationWillBecomeActive(_ notification: Notification)
  func applicationDidBecomeActive(_ notification: Notification)
  func applicationWillResignActive(_ notification: Notification)
  func applicationDidResignActive(_ notification: Notification)
  func applicationDidChangeScreenParameters(_ notification: Notification)
  func applicationDidChangeOcclusionState(_ notification: Notification)
  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool
  func applicationDockMenu(_ sender: NSApplication) -> NSMenu?
  func application(_ application: NSApplication, open urls: [URL])
  func application(_ sender: NSApplication, openFile filename: String) -> Bool
}
extension NSApplicationDelegate {
  public func applicationWillFinishLaunching(_ notification: Notification) {}
  public func applicationDidFinishLaunching(_ notification: Notification) {}
  public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply { .terminateNow }
  public func applicationWillTerminate(_ notification: Notification) {}
  public func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
  public func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool { true }
  public func applicationWillBecomeActive(_ notification: Notification) {}
  public func applicationDidBecomeActive(_ notification: Notification) {}
  public func applicationWillResignActive(_ notification: Notification) {}
  public func applicationDidResignActive(_ notification: Notification) {}
  public func applicationDidChangeScreenParameters(_ notification: Notification) {}
  public func applicationDidChangeOcclusionState(_ notification: Notification) {}
  public func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
  public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? { nil }
  public func application(_ application: NSApplication, open urls: [URL]) {}
  public func application(_ sender: NSApplication, openFile filename: String) -> Bool { false }
}

@MainActor open class NSApplication: NSResponder {
  public enum ActivationPolicy: Int, Sendable { case regular = 0, accessory = 1, prohibited = 2 }
  public enum TerminateReply: UInt, Sendable { case terminateCancel = 0, terminateNow = 1, terminateLater = 2 }
  public enum RequestUserAttentionType: UInt, Sendable { case criticalRequest = 0, informationalRequest = 10 }
  public struct ModalResponse: RawRepresentable, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let OK = ModalResponse(rawValue: 1)
    public static let cancel = ModalResponse(rawValue: 0)
    public static let stop = ModalResponse(rawValue: -1000)
    public static let abort = ModalResponse(rawValue: -1001)
    public static let `continue` = ModalResponse(rawValue: -1002)
    public static let alertFirstButtonReturn = ModalResponse(rawValue: 1000)
    public static let alertSecondButtonReturn = ModalResponse(rawValue: 1001)
    public static let alertThirdButtonReturn = ModalResponse(rawValue: 1002)
  }
  public struct ActivationOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let activateAllWindows = ActivationOptions(rawValue: 1)
    public static let activateIgnoringOtherApps = ActivationOptions(rawValue: 2)
  }
  public struct PresentationOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let autoHideDock = PresentationOptions(rawValue: 1 << 0)
    public static let hideDock = PresentationOptions(rawValue: 1 << 1)
    public static let autoHideMenuBar = PresentationOptions(rawValue: 1 << 2)
    public static let hideMenuBar = PresentationOptions(rawValue: 1 << 3)
    public static let fullScreen = PresentationOptions(rawValue: 1 << 10)
  }
  public struct OcclusionState: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let visible = OcclusionState(rawValue: 2)
  }
  public struct AboutPanelOptionKey: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let credits = AboutPanelOptionKey(rawValue: "Credits")
    public static let applicationName = AboutPanelOptionKey(rawValue: "ApplicationName")
    public static let applicationIcon = AboutPanelOptionKey(rawValue: "ApplicationIcon")
    public static let version = AboutPanelOptionKey(rawValue: "Version")
    public static let applicationVersion = AboutPanelOptionKey(rawValue: "ApplicationVersion")
  }
  open class var shared: NSApplication { NSApplication() }
  open weak var delegate: (any NSApplicationDelegate)?
  open var keyWindow: NSWindow? { nil }
  open var mainWindow: NSWindow? { nil }
  open var windows: [NSWindow] { [] }
  open var orderedWindows: [NSWindow] { [] }
  open var mainMenu: NSMenu?
  open var servicesMenu: NSMenu?
  open var windowsMenu: NSMenu?
  open var helpMenu: NSMenu?
  open var isActive: Bool { false }
  open var isHidden: Bool { false }
  open var isRunning: Bool { false }
  open var currentEvent: NSEvent? { nil }
  open var modalWindow: NSWindow? { nil }
  open var applicationIconImage: NSImage!
  open var dockTile: NSDockTile { NSDockTile() }
  open var appearance: NSAppearance?
  open var effectiveAppearance: NSAppearance { NSAppearance() }
  open var presentationOptions: PresentationOptions = []
  open var currentSystemPresentationOptions: PresentationOptions { [] }
  open var occlusionState: OcclusionState { [] }
  open var isFullKeyboardAccessEnabled: Bool { false }
  open var userInterfaceLayoutDirection: NSUserInterfaceLayoutDirection { .leftToRight }
  open func activationPolicy() -> ActivationPolicy { .regular }
  @discardableResult open func setActivationPolicy(_ policy: ActivationPolicy) -> Bool { true }
  open func finishLaunching() {}
  open func run() {}
  open func stop(_ sender: Any?) {}
  open func hide(_ sender: Any?) {}
  open func unhide(_ sender: Any?) {}
  open func unhideWithoutActivation() {}
  open func hideOtherApplications(_ sender: Any?) {}
  open func unhideAllApplications(_ sender: Any?) {}
  open func activate(ignoringOtherApps flag: Bool) {}
  open func preventWindowOrdering() {}
  open func activate() {}
  open func deactivate() {}
  open func yieldActivation(to application: NSRunningApplication) {}
  open func yieldActivation(toApplicationWithBundleIdentifier bundleIdentifier: String) {}
  open func terminate(_ sender: Any?) {}
  open func reply(toApplicationShouldTerminate shouldTerminate: Bool) {}
  open func window(withWindowNumber windowNum: Int) -> NSWindow? { nil }
  open func sendEvent(_ event: NSEvent) {}
  open func postEvent(_ event: NSEvent, atStart flag: Bool) {}
  open func nextEvent(matching mask: NSEvent.EventTypeMask, until expiration: Date?, inMode mode: RunLoop.Mode, dequeue deqFlag: Bool) -> NSEvent? {
    nil
  }
  @discardableResult open func sendAction(_ action: Selector, to target: Any?, from sender: Any?) -> Bool { false }
  open func target(forAction action: Selector) -> Any? { nil }
  open func runModal(for window: NSWindow) -> ModalResponse { .OK }
  open func stopModal() {}
  open func stopModal(withCode returnCode: ModalResponse) {}
  open func abortModal() {}
  open func orderFrontStandardAboutPanel(_ sender: Any?) {}
  open func orderFrontStandardAboutPanel(options optionsDictionary: [AboutPanelOptionKey: Any] = [:]) {}
  open func orderFrontCharacterPalette(_ sender: Any?) {}
  open func arrangeInFront(_ sender: Any?) {}
  open func updateWindows() {}
  open func setWindowsNeedUpdate(_ needUpdate: Bool) {}
  @discardableResult open func requestUserAttention(_ requestType: RequestUserAttentionType) -> Int { 0 }
  open func cancelUserAttentionRequest(_ request: Int) {}
  open func enumerateWindows(options: WindowListOptions = [], using block: (NSWindow, UnsafeMutablePointer<ObjCBool>) -> Void) {}
  open func registerForRemoteNotifications() {}
  public struct WindowListOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let orderedFrontToBack = WindowListOptions(rawValue: 1)
  }
  public nonisolated static let didBecomeActiveNotification = NSNotification.Name("NSApplicationDidBecomeActiveNotification")
  public nonisolated static let didResignActiveNotification = NSNotification.Name("NSApplicationDidResignActiveNotification")
  public nonisolated static let willBecomeActiveNotification = NSNotification.Name("NSApplicationWillBecomeActiveNotification")
  public nonisolated static let willResignActiveNotification = NSNotification.Name("NSApplicationWillResignActiveNotification")
  public nonisolated static let didFinishLaunchingNotification = NSNotification.Name("NSApplicationDidFinishLaunchingNotification")
  public nonisolated static let willFinishLaunchingNotification = NSNotification.Name("NSApplicationWillFinishLaunchingNotification")
  public nonisolated static let willTerminateNotification = NSNotification.Name("NSApplicationWillTerminateNotification")
  public nonisolated static let didHideNotification = NSNotification.Name("NSApplicationDidHideNotification")
  public nonisolated static let didUnhideNotification = NSNotification.Name("NSApplicationDidUnhideNotification")
  public nonisolated static let didChangeScreenParametersNotification = NSNotification.Name("NSApplicationDidChangeScreenParametersNotification")
  public nonisolated static let didChangeOcclusionStateNotification = NSNotification.Name("NSApplicationDidChangeOcclusionStateNotification")
}
@MainActor public var NSApp: NSApplication! { NSApplication.shared }
public func NSApplicationMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 { 0 }

@MainActor open class NSDockTile: NSObject {
  open var badgeLabel: String?
  open var contentView: NSView?
  open var size: NSSize { .zero }
  open func display() {}
}
public enum NSUserInterfaceLayoutDirection: Int, Sendable { case leftToRight = 0, rightToLeft = 1 }
public enum NSUserInterfaceLayoutOrientation: Int, Sendable { case horizontal = 0, vertical = 1 }
public struct NSUserInterfaceItemIdentifier: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public init(_ rawValue: String) { self.rawValue = rawValue }
}
@MainActor public protocol NSUserInterfaceItemIdentification: NSObjectProtocol {
  var identifier: NSUserInterfaceItemIdentifier? { get set }
}
@MainActor public protocol NSUserInterfaceValidations: NSObjectProtocol {
  func validateUserInterfaceItem(_ item: any NSValidatedUserInterfaceItem) -> Bool
}
@MainActor public protocol NSValidatedUserInterfaceItem: NSObjectProtocol {
  var action: Selector? { get }
  var tag: Int { get }
}

open class NSSound: NSObject {
  open class func beep() {}
  public typealias Name = String
  public convenience init?(named name: Name) { self.init() }
  public convenience init?(contentsOf url: URL, byReference byRef: Bool) { self.init() }
  @discardableResult open func play() -> Bool { false }
  @discardableResult open func stop() -> Bool { false }
  open var volume: Float = 1
  open var isPlaying: Bool { false }
}
public func NSBeep() {}

open class NSPasteboard: NSObject {
  public struct PasteboardType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let string = PasteboardType("public.utf8-plain-text")
    public static let fileURL = PasteboardType("public.file-url")
    public static let URL = PasteboardType("public.url")
    public static let png = PasteboardType("public.png")
    public static let tiff = PasteboardType("public.tiff")
  }
  open class var general: NSPasteboard { NSPasteboard() }
  open var changeCount: Int { 0 }
  @discardableResult open func clearContents() -> Int { 0 }
  @discardableResult open func declareTypes(_ newTypes: [PasteboardType], owner newOwner: Any?) -> Int { 0 }
  @discardableResult open func setString(_ string: String, forType dataType: PasteboardType) -> Bool { false }
  @discardableResult open func setData(_ data: Data?, forType dataType: PasteboardType) -> Bool { false }
  open func string(forType dataType: PasteboardType) -> String? { nil }
  open func data(forType dataType: PasteboardType) -> Data? { nil }
}
