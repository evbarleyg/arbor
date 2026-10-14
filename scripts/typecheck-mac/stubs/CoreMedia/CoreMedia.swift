// A stand-in for the little of CoreMedia that screen capture refers to (scripts/typecheck-mac/README.md). Never shipped, never run.
@_exported import CoreVideo

public typealias CMTimeValue = Int64
public typealias CMTimeScale = Int32
public struct CMTime: Sendable, Equatable {
  public var value: CMTimeValue = 0
  public var timescale: CMTimeScale = 0
  public init() {}
  public init(value: CMTimeValue, timescale: CMTimeScale) {}
  public init(seconds: Double, preferredTimescale: CMTimeScale) {}
  public static let zero = CMTime()
  public static let invalid = CMTime()
  public static let indefinite = CMTime()
  public static let positiveInfinity = CMTime()
  public var seconds: Double { 0 }
  public var isValid: Bool { false }
}
public func CMTimeMake(value: Int64, timescale: Int32) -> CMTime { CMTime() }
public func CMTimeGetSeconds(_ time: CMTime) -> Double { 0 }
public final class CMFormatDescription {}
public final class CMSampleBuffer {
  public var isValid: Bool { false }
  public var imageBuffer: CVImageBuffer? { nil }
  public var presentationTimeStamp: CMTime { .zero }
  public var formatDescription: CMFormatDescription? { nil }
}
public func CMSampleBufferGetImageBuffer(_ sbuf: CMSampleBuffer) -> CVImageBuffer? { nil }
public func CMSampleBufferIsValid(_ sbuf: CMSampleBuffer) -> Bool { false }
public func CMSampleBufferGetSampleAttachmentsArray(_ sbuf: CMSampleBuffer, createIfNecessary: Bool) -> CFArray? { nil }
public func CMSampleBufferGetPresentationTimeStamp(_ sbuf: CMSampleBuffer) -> CMTime { .zero }
