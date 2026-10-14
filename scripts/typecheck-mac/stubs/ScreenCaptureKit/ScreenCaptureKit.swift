// A stand-in for ScreenCaptureKit as of macOS 14 (scripts/typecheck-mac/README.md). Never shipped, never run.
// None of its classes is Sendable; Arbor imports it `@preconcurrency`.
@_exported import CoreMedia

open class SCRunningApplication: NSObject {
  open var bundleIdentifier: String { "" }
  open var applicationName: String { "" }
  open var processID: pid_t { 0 }
}
open class SCWindow: NSObject {
  open var windowID: CGWindowID { 0 }
  open var frame: CGRect { .zero }
  open var title: String? { nil }
  open var windowLayer: Int { 0 }
  open var owningApplication: SCRunningApplication? { nil }
  open var isOnScreen: Bool { false }
  open var isActive: Bool { false }
}
open class SCDisplay: NSObject {
  open var displayID: CGDirectDisplayID { 0 }
  open var width: Int { 0 }
  open var height: Int { 0 }
  open var frame: CGRect { .zero }
}
public enum SCShareableContentStyle: Int, Sendable { case none = 0, window, display, application }
open class SCShareableContentInfo: NSObject {
  open var style: SCShareableContentStyle { .none }
  open var pointPixelScale: Float { 1 }
  open var contentRect: CGRect { .zero }
}
open class SCShareableContent: NSObject {
  open class var current: SCShareableContent {
    get async throws { SCShareableContent() }
  }
  open class func getWithCompletionHandler(_ completionHandler: @escaping @Sendable (SCShareableContent?, (any Error)?) -> Void) {}
  open class func getExcludingDesktopWindows(
    _ excludeDesktopWindows: Bool, onScreenWindowsOnly: Bool, completionHandler: @escaping @Sendable (SCShareableContent?, (any Error)?) -> Void) {}
  // The results of Objective-C's completion handlers may cross to the caller's actor.
  open class func excludingDesktopWindows(_ excludeDesktopWindows: Bool, onScreenWindowsOnly: Bool) async throws -> sending SCShareableContent {
    SCShareableContent()
  }
  open class func excludingDesktopWindows(_ excludeDesktopWindows: Bool, onScreenWindowsOnlyBelow window: SCWindow) async throws
    -> sending SCShareableContent
  { SCShareableContent() }
  open class func excludingDesktopWindows(_ excludeDesktopWindows: Bool, onScreenWindowsOnlyAbove window: SCWindow) async throws
    -> sending SCShareableContent
  { SCShareableContent() }
  open class func info(for filter: SCContentFilter) -> SCShareableContentInfo { SCShareableContentInfo() }
  open var windows: [SCWindow] { [] }
  open var displays: [SCDisplay] { [] }
  open var applications: [SCRunningApplication] { [] }
}
open class SCContentFilter: NSObject {
  public init(desktopIndependentWindow window: SCWindow) {}
  public init(display: SCDisplay, excludingWindows excluded: [SCWindow]) {}
  public init(display: SCDisplay, including includedWindows: [SCWindow]) {}
  public init(display: SCDisplay, including applications: [SCRunningApplication], exceptingWindows: [SCWindow]) {}
  public init(display: SCDisplay, excludingApplications applications: [SCRunningApplication], exceptingWindows: [SCWindow]) {}
  open var style: SCShareableContentStyle { .none }
  open var pointPixelScale: Float { 1 }
  open var contentRect: CGRect { .zero }
}
public enum SCCaptureResolutionType: Int, Sendable { case automatic = 0, best, nominal }
public enum SCPresenterOverlayAlertSetting: Int, Sendable { case system = 0, never, always }
open class SCStreamConfiguration: NSObject {
  open var width = 0
  open var height = 0
  open var minimumFrameInterval = CMTime.zero
  open var pixelFormat: OSType = 0
  open var scalesToFit = false
  open var preservesAspectRatio = true
  open var streamName: String?
  open var showsCursor = true
  open var backgroundColor: CGColor = .clear
  open var sourceRect = CGRect.zero
  open var destinationRect = CGRect.zero
  open var queueDepth = 3
  open var colorMatrix: CFString = ""
  open var colorSpaceName: CFString = ""
  open var capturesAudio = false
  open var sampleRate = 48000
  open var channelCount = 2
  open var excludesCurrentProcessAudio = false
  open var ignoreShadowsDisplay = false
  open var ignoreShadowsSingleWindow = false
  open var captureResolution: SCCaptureResolutionType = .automatic
  open var capturesShadowsOnly = false
  open var shouldBeOpaque = false
  open var ignoreGlobalClipDisplay = false
  open var ignoreGlobalClipSingleWindow = false
  open var presenterOverlayPrivacyAlertSetting: SCPresenterOverlayAlertSetting = .system
}
open class SCScreenshotManager: NSObject {
  open class func captureImage(contentFilter: SCContentFilter, configuration config: SCStreamConfiguration) async throws -> sending CGImage {
    fatalError()
  }
  open class func captureImage(
    contentFilter: SCContentFilter, configuration config: SCStreamConfiguration,
    completionHandler: (@Sendable (CGImage?, (any Error)?) -> Void)? = nil) {}
  open class func captureSampleBuffer(contentFilter: SCContentFilter, configuration config: SCStreamConfiguration) async throws
    -> sending CMSampleBuffer
  { fatalError() }
}
public enum SCStreamOutputType: Int, Sendable { case screen = 0, audio = 1 }
public enum SCFrameStatus: Int, Sendable { case complete = 0, idle, blank, suspended, started, stopped }
public struct SCStreamFrameInfo: RawRepresentable, Hashable, Sendable {
  public let rawValue: String
  public init(rawValue: String) { self.rawValue = rawValue }
  public static let status = SCStreamFrameInfo(rawValue: "SCStreamUpdateFrameStatus")
  public static let displayTime = SCStreamFrameInfo(rawValue: "SCStreamUpdateFrameDisplayTime")
  public static let scaleFactor = SCStreamFrameInfo(rawValue: "SCStreamUpdateFrameDisplayResolution")
  public static let contentScale = SCStreamFrameInfo(rawValue: "SCStreamUpdateFrameContentScale")
  public static let contentRect = SCStreamFrameInfo(rawValue: "SCStreamUpdateFrameContentRect")
  public static let dirtyRects = SCStreamFrameInfo(rawValue: "SCStreamUpdateFrameDirtyRect")
}
public protocol SCStreamOutput: NSObjectProtocol {
  func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType)
}
extension SCStreamOutput {
  public func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {}
}
public protocol SCStreamDelegate: NSObjectProtocol {
  func stream(_ stream: SCStream, didStopWithError error: any Error)
}
extension SCStreamDelegate {
  public func stream(_ stream: SCStream, didStopWithError error: any Error) {}
}
open class SCStream: NSObject {
  public init(filter contentFilter: SCContentFilter, configuration streamConfig: SCStreamConfiguration, delegate: (any SCStreamDelegate)?) {}
  open func addStreamOutput(_ output: any SCStreamOutput, type: SCStreamOutputType, sampleHandlerQueue: DispatchQueue?) throws {}
  open func removeStreamOutput(_ output: any SCStreamOutput, type: SCStreamOutputType) throws {}
  open func updateContentFilter(_ contentFilter: SCContentFilter) async throws {}
  open func updateConfiguration(_ streamConfig: SCStreamConfiguration) async throws {}
  open func startCapture() async throws {}
  open func stopCapture() async throws {}
  open func startCapture(completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {}
  open func stopCapture(completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {}
}
public struct SCStreamError: Error, Sendable {
  public enum Code: Int, Sendable {
    case userDeclined = -3801, failedToStart = -3802, missingEntitlements = -3803, failedApplicationConnectionInvalid = -3804,
      failedApplicationConnectionInterrupted = -3805, failedNoMatchingApplicationContext = -3806, attemptToStartStreamState = -3807,
      attemptToStopStreamState = -3808, attemptToUpdateFilterState = -3809, attemptToConfigState = -3810, internalError = -3811,
      invalidParameter = -3812, noWindowList = -3813, noDisplayList = -3814, noCaptureSource = -3815, removingStream = -3816,
      userStopped = -3817, failedToStartAudioCapture = -3818, failedToStopAudioCapture = -3819, systemStoppedStream = -3821
  }
  public let code: Code
  public static var errorDomain: String { "com.apple.ScreenCaptureKit.SCStreamErrorDomain" }
  public static var userDeclined: Code { .userDeclined }
}
