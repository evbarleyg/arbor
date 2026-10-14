// A stand-in for ImageIO (scripts/typecheck-mac/README.md). Never shipped, never run.
@_exported import CoreGraphics

public final class CGImageSource {}
public final class CGImageDestination {}
public enum CGImageSourceStatus: Int32, Sendable {
  case statusUnexpectedEOF = -5, statusInvalidData = -4, statusUnknownType = -3, statusReadingHeader = -2, statusIncomplete = -1, statusComplete = 0
}
public func CGImageSourceCreateWithURL(_ url: CFURL, _ options: CFDictionary?) -> CGImageSource? { nil }
public func CGImageSourceCreateWithData(_ data: CFData, _ options: CFDictionary?) -> CGImageSource? { nil }
public func CGImageSourceGetCount(_ isrc: CGImageSource) -> Int { 0 }
public func CGImageSourceGetType(_ isrc: CGImageSource) -> CFString? { nil }
public func CGImageSourceGetStatus(_ isrc: CGImageSource) -> CGImageSourceStatus { .statusComplete }
public func CGImageSourceGetPrimaryImageIndex(_ isrc: CGImageSource) -> Int { 0 }
public func CGImageSourceCopyProperties(_ isrc: CGImageSource, _ options: CFDictionary?) -> CFDictionary? { nil }
public func CGImageSourceCopyPropertiesAtIndex(_ isrc: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CFDictionary? { nil }
public func CGImageSourceCreateImageAtIndex(_ isrc: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CGImage? { nil }
public func CGImageSourceCreateThumbnailAtIndex(_ isrc: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CGImage? { nil }
public func CGImageDestinationCreateWithURL(_ url: CFURL, _ type: CFString, _ count: Int, _ options: CFDictionary?) -> CGImageDestination? { nil }
public func CGImageDestinationCreateWithData(_ data: CFMutableData, _ type: CFString, _ count: Int, _ options: CFDictionary?) -> CGImageDestination? {
  nil
}
public func CGImageDestinationAddImage(_ idst: CGImageDestination, _ image: CGImage, _ properties: CFDictionary?) {}
public func CGImageDestinationSetProperties(_ idst: CGImageDestination, _ properties: CFDictionary?) {}
@discardableResult public func CGImageDestinationFinalize(_ idst: CGImageDestination) -> Bool { false }
public nonisolated(unsafe) let kCGImageSourceTypeIdentifierHint: CFString = "kCGImageSourceTypeIdentifierHint"
public nonisolated(unsafe) let kCGImageSourceShouldCache: CFString = "kCGImageSourceShouldCache"
public nonisolated(unsafe) let kCGImageSourceShouldCacheImmediately: CFString = "kCGImageSourceShouldCacheImmediately"
public nonisolated(unsafe) let kCGImageSourceShouldAllowFloat: CFString = "kCGImageSourceShouldAllowFloat"
public nonisolated(unsafe) let kCGImageSourceCreateThumbnailFromImageIfAbsent: CFString = "kCGImageSourceCreateThumbnailFromImageIfAbsent"
public nonisolated(unsafe) let kCGImageSourceCreateThumbnailFromImageAlways: CFString = "kCGImageSourceCreateThumbnailFromImageAlways"
public nonisolated(unsafe) let kCGImageSourceThumbnailMaxPixelSize: CFString = "kCGImageSourceThumbnailMaxPixelSize"
public nonisolated(unsafe) let kCGImageSourceCreateThumbnailWithTransform: CFString = "kCGImageSourceCreateThumbnailWithTransform"
public nonisolated(unsafe) let kCGImageSourceSubsampleFactor: CFString = "kCGImageSourceSubsampleFactor"
public nonisolated(unsafe) let kCGImageDestinationLossyCompressionQuality: CFString = "kCGImageDestinationLossyCompressionQuality"
public nonisolated(unsafe) let kCGImagePropertyPixelWidth: CFString = "PixelWidth"
public nonisolated(unsafe) let kCGImagePropertyPixelHeight: CFString = "PixelHeight"
public nonisolated(unsafe) let kCGImagePropertyDPIWidth: CFString = "DPIWidth"
public nonisolated(unsafe) let kCGImagePropertyDPIHeight: CFString = "DPIHeight"
public nonisolated(unsafe) let kCGImagePropertyOrientation: CFString = "Orientation"
