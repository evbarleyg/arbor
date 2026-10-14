// A stand-in for CoreMediaIO's hardware interface (scripts/typecheck-mac/README.md). Never shipped, never run.
// In Swift, because a C header on Linux cannot speak of DispatchQueue. Its headers say nothing about null, so pointers arrive implicitly unwrapped.
@_exported import CCoreMediaIO
import MacFoundation

public typealias CMIOObjectPropertyListenerBlock = (UInt32, UnsafePointer<CMIOObjectPropertyAddress>?) -> Void
public func CMIOObjectHasProperty(_ objectID: CMIOObjectID, _ address: UnsafePointer<CMIOObjectPropertyAddress>!) -> Bool { false }
public func CMIOObjectGetPropertyDataSize(
  _ objectID: CMIOObjectID, _ address: UnsafePointer<CMIOObjectPropertyAddress>!, _ qualifierDataSize: UInt32, _ qualifierData: UnsafeRawPointer!,
  _ dataSize: UnsafeMutablePointer<UInt32>!
) -> OSStatus { 0 }
public func CMIOObjectGetPropertyData(
  _ objectID: CMIOObjectID, _ address: UnsafePointer<CMIOObjectPropertyAddress>!, _ qualifierDataSize: UInt32, _ qualifierData: UnsafeRawPointer!,
  _ dataSize: UInt32, _ dataUsed: UnsafeMutablePointer<UInt32>!, _ data: UnsafeMutableRawPointer!
) -> OSStatus { 0 }
public func CMIOObjectSetPropertyData(
  _ objectID: CMIOObjectID, _ address: UnsafePointer<CMIOObjectPropertyAddress>!, _ qualifierDataSize: UInt32, _ qualifierData: UnsafeRawPointer!,
  _ dataSize: UInt32, _ data: UnsafeRawPointer!
) -> OSStatus { 0 }
public func CMIOObjectAddPropertyListenerBlock(
  _ objectID: CMIOObjectID, _ address: UnsafePointer<CMIOObjectPropertyAddress>!, _ dispatchQueue: DispatchQueue!,
  _ listener: CMIOObjectPropertyListenerBlock!
) -> OSStatus { 0 }
public func CMIOObjectRemovePropertyListenerBlock(
  _ objectID: CMIOObjectID, _ address: UnsafePointer<CMIOObjectPropertyAddress>!, _ dispatchQueue: DispatchQueue!,
  _ listener: CMIOObjectPropertyListenerBlock!
) -> OSStatus { 0 }
