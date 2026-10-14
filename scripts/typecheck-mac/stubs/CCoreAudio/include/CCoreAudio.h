// The types and constants of CoreAudio's hardware interface (scripts/typecheck-mac/README.md). In C, so that Swift imports them as it
// imports Apple's: these enums have a type, so the constants arrive with it. The functions are in stubs/CoreAudio.
#ifndef CCOREAUDIO_H
#define CCOREAUDIO_H
#include "CMacTypes.h"

typedef UInt32 AudioObjectID;
typedef UInt32 AudioClassID;
typedef AudioObjectID AudioDeviceID;
typedef AudioObjectID AudioStreamID;
typedef UInt32 AudioObjectPropertySelector;
typedef UInt32 AudioObjectPropertyScope;
typedef UInt32 AudioObjectPropertyElement;
typedef struct AudioObjectPropertyAddress {
  AudioObjectPropertySelector mSelector;
  AudioObjectPropertyScope mScope;
  AudioObjectPropertyElement mElement;
} AudioObjectPropertyAddress;

enum : OSStatus { kAudioHardwareNoError = 0, kAudioHardwareNotRunningError = 0x73746F70, kAudioHardwareUnspecifiedError = 0x77686174,
                  kAudioHardwareUnknownPropertyError = 0x77686F3F, kAudioHardwareBadObjectError = 0x216F626A, kAudioHardwareBadDeviceError = 0x21646576 };
enum : AudioObjectID { kAudioObjectUnknown = 0 };
enum : AudioObjectPropertyScope { kAudioObjectPropertyScopeGlobal = 0x676C6F62, kAudioObjectPropertyScopeInput = 0x696E7074,
                                  kAudioObjectPropertyScopeOutput = 0x6F757470, kAudioObjectPropertyScopePlayThrough = 0x70747275 };
enum : AudioObjectPropertyElement { kAudioObjectPropertyElementMain = 0 };
enum : AudioObjectPropertySelector { kAudioObjectPropertySelectorWildcard = 0x2A2A2A2A };
enum : AudioObjectPropertySelector { kAudioObjectPropertyBaseClass = 0x62636C73, kAudioObjectPropertyClass = 0x636C6173,
                                     kAudioObjectPropertyOwner = 0x73746476, kAudioObjectPropertyName = 0x6C6E616D,
                                     kAudioObjectPropertyManufacturer = 0x6C6D616B, kAudioObjectPropertyOwnedObjects = 0x6F776E64 };
enum : int { kAudioObjectSystemObject = 1 };
enum : AudioObjectPropertySelector { kAudioHardwarePropertyDevices = 0x64657623, kAudioHardwarePropertyDefaultInputDevice = 0x64496E20,
                                     kAudioHardwarePropertyDefaultOutputDevice = 0x644F7574,
                                     kAudioHardwarePropertyDefaultSystemOutputDevice = 0x734F7574, kAudioHardwarePropertyProcessObjectList = 0x70727323 };
enum : AudioObjectPropertySelector { kAudioDevicePropertyDeviceUID = 0x75696420, kAudioDevicePropertyTransportType = 0x7472616E,
                                     kAudioDevicePropertyDeviceIsAlive = 0x6C69766E, kAudioDevicePropertyDeviceIsRunning = 0x676F696E,
                                     kAudioDevicePropertyStreams = 0x73746D23, kAudioDevicePropertyNominalSampleRate = 0x6E737274,
                                     kAudioDevicePropertyDeviceIsRunningSomewhere = 0x676F6E65, kAudioDevicePropertyHogMode = 0x6F696E6B,
                                     kAudioDevicePropertyStreamConfiguration = 0x736C6179 };
enum : AudioObjectPropertySelector { kAudioProcessPropertyPID = 0x70706964, kAudioProcessPropertyBundleID = 0x70626964,
                                     kAudioProcessPropertyIsRunning = 0x7069723F, kAudioProcessPropertyIsRunningInput = 0x70697269,
                                     kAudioProcessPropertyIsRunningOutput = 0x7069726F };
#endif
