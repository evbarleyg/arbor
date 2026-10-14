// A stand-in for UniformTypeIdentifiers (scripts/typecheck-mac/README.md). Never shipped, never run.
import Foundation

public struct UTType: Hashable, Sendable, Codable, CustomStringConvertible {
  public init?(_ identifier: String) {}
  public init?(filenameExtension: String, conformingTo supertype: UTType = .data) {}
  public init?(mimeType: String, conformingTo supertype: UTType = .data) {}
  public init(exportedAs identifier: String, conformingTo parentType: UTType? = nil) {}
  public init(importedAs identifier: String, conformingTo parentType: UTType? = nil) {}
  public var identifier: String { "" }
  public var preferredFilenameExtension: String? { nil }
  public var preferredMIMEType: String? { nil }
  public var localizedDescription: String? { nil }
  public var description: String { "" }
  public func conforms(to type: UTType) -> Bool { false }
  public static var item: UTType { UTType(exportedAs: "public.item") }
  public static var content: UTType { UTType(exportedAs: "public.content") }
  public static var data: UTType { UTType(exportedAs: "public.data") }
  public static var directory: UTType { UTType(exportedAs: "public.directory") }
  public static var folder: UTType { UTType(exportedAs: "public.folder") }
  public static var application: UTType { UTType(exportedAs: "com.apple.application") }
  public static var applicationBundle: UTType { UTType(exportedAs: "com.apple.application-bundle") }
  public static var text: UTType { UTType(exportedAs: "public.text") }
  public static var plainText: UTType { UTType(exportedAs: "public.plain-text") }
  public static var utf8PlainText: UTType { UTType(exportedAs: "public.utf8-plain-text") }
  public static var json: UTType { UTType(exportedAs: "public.json") }
  public static var propertyList: UTType { UTType(exportedAs: "com.apple.property-list") }
  public static var url: UTType { UTType(exportedAs: "public.url") }
  public static var fileURL: UTType { UTType(exportedAs: "public.file-url") }
  public static var image: UTType { UTType(exportedAs: "public.image") }
  public static var png: UTType { UTType(exportedAs: "public.png") }
  public static var jpeg: UTType { UTType(exportedAs: "public.jpeg") }
  public static var tiff: UTType { UTType(exportedAs: "public.tiff") }
  public static var heic: UTType { UTType(exportedAs: "public.heic") }
  public static var gif: UTType { UTType(exportedAs: "com.compuserve.gif") }
  public static var pdf: UTType { UTType(exportedAs: "com.adobe.pdf") }
  public static var zip: UTType { UTType(exportedAs: "public.zip-archive") }
}
