// A stand-in for the little of CoreVideo that screen capture refers to (scripts/typecheck-mac/README.md). Never shipped, never run.
@_exported import CoreGraphics

public typealias CVReturn = Int32
public let kCVReturnSuccess: CVReturn = 0
public class CVBuffer {}
public typealias CVImageBuffer = CVBuffer
public typealias CVPixelBuffer = CVImageBuffer
public final class IOSurfaceRef {}
public let kCVPixelFormatType_32BGRA: OSType = 0x4247_5241
public let kCVPixelFormatType_32ARGB: OSType = 0x0000_0020
public let kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: OSType = 0x3432_3076
public let kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: OSType = 0x3432_3066
public struct CVPixelBufferLockFlags: OptionSet, Sendable {
  public let rawValue: UInt64
  public init(rawValue: UInt64) { self.rawValue = rawValue }
  public static let readOnly = CVPixelBufferLockFlags(rawValue: 1)
}
public func CVPixelBufferGetWidth(_ pixelBuffer: CVPixelBuffer) -> Int { 0 }
public func CVPixelBufferGetHeight(_ pixelBuffer: CVPixelBuffer) -> Int { 0 }
public func CVPixelBufferGetBytesPerRow(_ pixelBuffer: CVPixelBuffer) -> Int { 0 }
public func CVPixelBufferGetBaseAddress(_ pixelBuffer: CVPixelBuffer) -> UnsafeMutableRawPointer? { nil }
public func CVPixelBufferGetPixelFormatType(_ pixelBuffer: CVPixelBuffer) -> OSType { 0 }
public func CVPixelBufferGetIOSurface(_ pixelBuffer: CVPixelBuffer?) -> Unmanaged<IOSurfaceRef>? { nil }
@discardableResult public func CVPixelBufferLockBaseAddress(_ pixelBuffer: CVPixelBuffer, _ lockFlags: CVPixelBufferLockFlags) -> CVReturn { 0 }
@discardableResult public func CVPixelBufferUnlockBaseAddress(_ pixelBuffer: CVPixelBuffer, _ unlockFlags: CVPixelBufferLockFlags) -> CVReturn { 0 }
