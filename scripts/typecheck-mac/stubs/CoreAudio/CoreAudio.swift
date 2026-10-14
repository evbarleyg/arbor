// A stand-in for CoreAudio's hardware interface (scripts/typecheck-mac/README.md). Never shipped, never run.
// In Swift, because a C header on Linux cannot speak of DispatchQueue. Nullability as in AudioHardware.h, which states it.
@_exported import CCoreAudio
import MacFoundation

public typealias AudioObjectPropertyListenerBlock = (UInt32, UnsafePointer<AudioObjectPropertyAddress>) -> Void
/// `@convention(c)` on the Mac: it must not capture anything. See the README.
public typealias AudioObjectPropertyListenerProc = (
  AudioObjectID, UInt32, UnsafePointer<AudioObjectPropertyAddress>, UnsafeMutableRawPointer?
) -> OSStatus
public func AudioObjectHasProperty(_ inObjectID: AudioObjectID, _ inAddress: UnsafePointer<AudioObjectPropertyAddress>) -> Bool { false }
public func AudioObjectIsPropertySettable(
  _ inObjectID: AudioObjectID, _ inAddress: UnsafePointer<AudioObjectPropertyAddress>, _ outIsSettable: UnsafeMutablePointer<DarwinBoolean>
) -> OSStatus { 0 }
public func AudioObjectGetPropertyDataSize(
  _ inObjectID: AudioObjectID, _ inAddress: UnsafePointer<AudioObjectPropertyAddress>, _ inQualifierDataSize: UInt32,
  _ inQualifierData: UnsafeRawPointer?, _ outDataSize: UnsafeMutablePointer<UInt32>
) -> OSStatus { 0 }
public func AudioObjectGetPropertyData(
  _ inObjectID: AudioObjectID, _ inAddress: UnsafePointer<AudioObjectPropertyAddress>, _ inQualifierDataSize: UInt32,
  _ inQualifierData: UnsafeRawPointer?, _ ioDataSize: UnsafeMutablePointer<UInt32>, _ outData: UnsafeMutableRawPointer
) -> OSStatus { 0 }
public func AudioObjectSetPropertyData(
  _ inObjectID: AudioObjectID, _ inAddress: UnsafePointer<AudioObjectPropertyAddress>, _ inQualifierDataSize: UInt32,
  _ inQualifierData: UnsafeRawPointer?, _ inDataSize: UInt32, _ inData: UnsafeRawPointer
) -> OSStatus { 0 }
public func AudioObjectAddPropertyListenerBlock(
  _ inObjectID: AudioObjectID, _ inAddress: UnsafePointer<AudioObjectPropertyAddress>, _ inDispatchQueue: DispatchQueue?,
  _ inListener: @escaping AudioObjectPropertyListenerBlock
) -> OSStatus { 0 }
public func AudioObjectRemovePropertyListenerBlock(
  _ inObjectID: AudioObjectID, _ inAddress: UnsafePointer<AudioObjectPropertyAddress>, _ inDispatchQueue: DispatchQueue?,
  _ inListener: @escaping AudioObjectPropertyListenerBlock
) -> OSStatus { 0 }
public func AudioObjectAddPropertyListener(
  _ inObjectID: AudioObjectID, _ inAddress: UnsafePointer<AudioObjectPropertyAddress>, _ inListener: AudioObjectPropertyListenerProc,
  _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus { 0 }
public func AudioObjectRemovePropertyListener(
  _ inObjectID: AudioObjectID, _ inAddress: UnsafePointer<AudioObjectPropertyAddress>, _ inListener: AudioObjectPropertyListenerProc,
  _ inClientData: UnsafeMutableRawPointer?
) -> OSStatus { 0 }
