// The types and constants of CoreMediaIO's hardware interface (scripts/typecheck-mac/README.md). In C, so that Swift imports them as it
// imports Apple's: these enums have no type, so the constants arrive as Int. The functions are in stubs/CoreMediaIO.
#ifndef CCOREMEDIAIO_H
#define CCOREMEDIAIO_H
#include "CMacTypes.h"

typedef UInt32 CMIOObjectID;
typedef UInt32 CMIOClassID;
typedef CMIOObjectID CMIODeviceID;
typedef CMIOObjectID CMIOStreamID;
typedef UInt32 CMIOObjectPropertySelector;
typedef UInt32 CMIOObjectPropertyScope;
typedef UInt32 CMIOObjectPropertyElement;
typedef struct CMIOObjectPropertyAddress {
  CMIOObjectPropertySelector mSelector;
  CMIOObjectPropertyScope mScope;
  CMIOObjectPropertyElement mElement;
} CMIOObjectPropertyAddress;

enum { kCMIOObjectPropertyScopeGlobal = 0x676C6F62, kCMIOObjectPropertyElementMain = 0, kCMIOObjectClassID = 0x616F626A,
       kCMIOObjectClassIDWildcard = 0x2A2A2A2A, kCMIOObjectUnknown = 0 };
enum { kCMIOObjectPropertySelectorWildcard = 0x2A2A2A2A, kCMIOObjectPropertyScopeWildcard = 0x2A2A2A2A, kCMIOObjectPropertyElementWildcard = 0xFFFFFFFF };
enum { kCMIOObjectPropertyClass = 0x636C6173, kCMIOObjectPropertyOwner = 0x73746476, kCMIOObjectPropertyName = 0x6C6E616D,
       kCMIOObjectPropertyManufacturer = 0x6C6D616B, kCMIOObjectPropertyOwnedObjects = 0x6F776E64 };
enum { kCMIOObjectSystemObject = 1 };
enum { kCMIOHardwarePropertyDevices = 0x64657623, kCMIOHardwarePropertyDefaultInputDevice = 0x64496E20,
       kCMIOHardwarePropertyAllowScreenCaptureDevices = 0x79657320 };
enum { kCMIODevicePropertyScopeInput = 0x696E7074, kCMIODevicePropertyScopeOutput = 0x6F757470 };
enum { kCMIODevicePropertyDeviceUID = 0x75696420, kCMIODevicePropertyModelUID = 0x6D756964, kCMIODevicePropertyTransportType = 0x7472616E,
       kCMIODevicePropertyDeviceIsAlive = 0x6C69766E, kCMIODevicePropertyDeviceIsRunning = 0x676F696E,
       kCMIODevicePropertyDeviceIsRunningSomewhere = 0x676F6E65, kCMIODevicePropertyStreams = 0x73746D23 };
enum { kCMIOHardwareNoError = 0, kCMIOHardwareUnknownPropertyError = 0x77686F3F, kCMIOHardwareBadObjectError = 0x216F626A };
#endif
