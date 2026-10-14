// A stand-in for MacTypes.h and a little of the Apple Event headers (scripts/typecheck-mac/README.md). In C, so that Swift
// imports it as it imports Apple's: constants of an anonymous enum arrive as Int, those of an enum with a type as that type.
#ifndef CMACTYPES_H
#define CMACTYPES_H
#include <stdint.h>

typedef int32_t OSStatus;
typedef int16_t OSErr;
typedef uint32_t FourCharCode;
typedef FourCharCode OSType;
typedef FourCharCode ResType;
typedef unsigned char Boolean;
typedef uint16_t UniChar;
typedef unsigned long UniCharCount;
typedef unsigned long ByteCount;
typedef unsigned long ItemCount;
typedef uint32_t OptionBits;
typedef uint8_t UInt8;
typedef uint16_t UInt16;
typedef uint32_t UInt32;
typedef int32_t SInt32;
typedef int16_t SInt16;

typedef FourCharCode AEEventClass;
typedef FourCharCode AEEventID;
typedef FourCharCode AEKeyword;
typedef ResType DescType;
enum : AEKeyword { keyDirectObject = 0x2D2D2D2D };
enum { kInternetEventClass = 0x4755524C, kAEGetURL = 0x4755524C, kCoreEventClass = 0x61657674, kAEOpenApplication = 0x6F617070,
       kAEReopenApplication = 0x72617070, kAEQuitApplication = 0x71756974 };
enum { paramErr = -50, userCanceledErr = -128, procNotFound = -600 };
#endif
