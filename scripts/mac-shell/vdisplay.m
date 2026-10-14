// vdisplay: a second display, dark mode and a look at Spaces, for Mac shell scripts.
//
// GitHub's Macs have one display, so nothing of Arbor's that concerns several (unplugging and replugging,
// a camera per display, drags between displays, negative coordinates, parking beside a neighbour) could run on
// real macOS. CoreGraphics can make a display out of nothing: CGVirtualDisplay, which is private and
// undocumented (DeskPad, BetterDisplay and Chromium's tests use it).
//
// PRIVATE API. Arbor's rule against it protects the app; this is a test helper, compiled on the Mac by
// scripts/mac-shell/lib.sh (display_add and friends), and belongs to no target in Package.swift. The classes
// and functions are looked up by name at run time, so where they are missing it says so and exits with 69.
// What changes the system (add, move, appearance with an argument) is refused with 77 anywhere but on GitHub's Macs,
// which are thrown away after the run ($GITHUB_ACTIONS is true), as lib.sh's wrappers refuse it too.
//
//   vdisplay add <width> <height> [name] [--serial n] [--hidpi]
//                                   prints "<display id> <uuid>" once the display is on line, then keeps it
//                                   alive until the process ends: killing it unplugs the display
//   vdisplay move <display id> <x> <y>   the display's origin in global coordinates, for this login session
//   vdisplay list                   id uuid x y w h scale main|- vendor model serial, one line per display
//   vdisplay appearance [dark|light]     set, then print, the system's appearance
//   vdisplay spaces                 per display: its uuid, how many Spaces it has, which one shows (from 1)

#import <ApplicationServices/ApplicationServices.h>
#import <Foundation/Foundation.h>
#import <dlfcn.h>

// MARK: What CoreGraphics does not declare

@interface CGVirtualDisplayDescriptor : NSObject
@property(retain, nonatomic) dispatch_queue_t queue;
- (void)setDispatchQueue:(dispatch_queue_t)queue;
@property(retain, nonatomic) NSString *name;
@property(nonatomic) unsigned int maxPixelsWide;
@property(nonatomic) unsigned int maxPixelsHigh;
@property(nonatomic) CGSize sizeInMillimeters;
@property(nonatomic) unsigned int vendorID;
@property(nonatomic) unsigned int productID;
@property(nonatomic) unsigned int serialNum;
@property(copy, nonatomic) void (^terminationHandler)(id, id);
@end

@interface CGVirtualDisplayMode : NSObject
- (instancetype)initWithWidth:(unsigned int)width height:(unsigned int)height refreshRate:(double)refreshRate;
@end

@interface CGVirtualDisplaySettings : NSObject
@property(nonatomic) unsigned int hiDPI;
@property(retain, nonatomic) NSArray *modes;
@end

@interface CGVirtualDisplay : NSObject
@property(readonly, nonatomic) unsigned int displayID;
- (instancetype)initWithDescriptor:(CGVirtualDisplayDescriptor *)descriptor;
- (BOOL)applySettings:(CGVirtualDisplaySettings *)settings;
@end

// MARK: Helpers

enum { EXIT_USAGE = 64, EXIT_UNAVAILABLE = 69, EXIT_SOMEBODYS_MAC = 77, EXIT_REFUSED = 1 };

static int fail(int code, NSString *message) {
  fprintf(stderr, "vdisplay: %s\n", message.UTF8String);
  return code;
}

static BOOL onThrowawayMac(void) {
  const char *value = getenv("GITHUB_ACTIONS");
  return value && strcmp(value, "true") == 0;
}

static void *skyLight(const char *name) {
  static void *library;
  if (!library) library = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY);
  return library ? dlsym(library, name) : NULL;
}

static NSString *uuidOf(CGDirectDisplayID display) {
  CFUUIDRef uuid = CGDisplayCreateUUIDFromDisplayID(display);
  if (!uuid) return @"-";
  NSString *text = CFBridgingRelease(CFUUIDCreateString(NULL, uuid));
  CFRelease(uuid);
  return text;
}

static BOOL isActive(CGDirectDisplayID display) {
  CGDirectDisplayID active[16];
  uint32_t count = 0;
  CGGetActiveDisplayList(16, active, &count);
  for (uint32_t index = 0; index < count; index++) {
    if (active[index] == display) return YES;
  }
  return NO;
}

// MARK: Commands

// Kept from being released while the process waits.
static CGVirtualDisplay *theDisplay;
static dispatch_source_t parentWatch;

static int add(unsigned int width, unsigned int height, NSString *name, unsigned int serial, BOOL hiDPI) {
  Class descriptorClass = NSClassFromString(@"CGVirtualDisplayDescriptor");
  Class modeClass = NSClassFromString(@"CGVirtualDisplayMode");
  Class settingsClass = NSClassFromString(@"CGVirtualDisplaySettings");
  Class displayClass = NSClassFromString(@"CGVirtualDisplay");
  if (!descriptorClass || !modeClass || !settingsClass || !displayClass) {
    return fail(EXIT_UNAVAILABLE, @"this macOS has no CGVirtualDisplay");
  }

  CGVirtualDisplayDescriptor *descriptor = [(CGVirtualDisplayDescriptor *)[descriptorClass alloc] init];
  // A queue of its own: the main thread is busy waiting for the display below.
  dispatch_queue_t queue = dispatch_queue_create("vdisplay", DISPATCH_QUEUE_SERIAL);
  if ([descriptor respondsToSelector:@selector(setDispatchQueue:)]) {
    [descriptor setDispatchQueue:queue];
  } else {
    descriptor.queue = queue;
  }
  descriptor.name = name;
  descriptor.maxPixelsWide = width * (hiDPI ? 2 : 1);
  descriptor.maxPixelsHigh = height * (hiDPI ? 2 : 1);
  // About 110 points to the inch, as a desktop monitor has.
  descriptor.sizeInMillimeters = CGSizeMake(width * 25.4 / 110, height * 25.4 / 110);
  // Vendor, product and serial number are what macOS knows a display by when it comes back.
  descriptor.vendorID = 0xA7B0;
  descriptor.productID = 0x0001;
  descriptor.serialNum = serial;
  descriptor.terminationHandler = ^(id context, id display) {
    fprintf(stderr, "vdisplay: the window server ended the display\n");
    exit(EXIT_REFUSED);
  };

  theDisplay = [(CGVirtualDisplay *)[displayClass alloc] initWithDescriptor:descriptor];
  if (!theDisplay) return fail(EXIT_REFUSED, @"the window server refused to make a display");

  CGVirtualDisplaySettings *settings = [(CGVirtualDisplaySettings *)[settingsClass alloc] init];
  settings.hiDPI = hiDPI ? 1 : 0;
  settings.modes = @[ [(CGVirtualDisplayMode *)[modeClass alloc] initWithWidth:width height:height refreshRate:60] ];
  if (![theDisplay applySettings:settings]) return fail(EXIT_REFUSED, @"the display refused its mode");

  CGDirectDisplayID display = theDisplay.displayID;
  for (int tries = 0; tries < 100 && !isActive(display); tries++) usleep(50 * 1000);
  if (!isActive(display)) return fail(EXIT_REFUSED, @"the display did not come on line within 5 s");
  printf("%u %s\n", display, uuidOf(display).UTF8String);
  fflush(stdout);

  // Nobody is left to unplug it once the script that asked for it is gone.
  pid_t parent = getppid();
  parentWatch = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
  dispatch_source_set_timer(parentWatch, DISPATCH_TIME_NOW, NSEC_PER_SEC, NSEC_PER_SEC / 10);
  dispatch_source_set_event_handler(parentWatch, ^{
    if (getppid() != parent) exit(0);
  });
  dispatch_resume(parentWatch);
  dispatch_main();
}

static int move(CGDirectDisplayID display, int32_t x, int32_t y) {
  if (!isActive(display)) return fail(EXIT_REFUSED, [NSString stringWithFormat:@"no display %u", display]);
  CGDisplayConfigRef configuration = NULL;
  CGError error = CGBeginDisplayConfiguration(&configuration);
  if (error == kCGErrorSuccess) error = CGConfigureDisplayOrigin(configuration, display, x, y);
  if (error != kCGErrorSuccess) {
    if (configuration) CGCancelDisplayConfiguration(configuration);
    return fail(EXIT_REFUSED, [NSString stringWithFormat:@"could not configure the display (error %d)", error]);
  }
  // For the session: it has to outlive this process.
  error = CGCompleteDisplayConfiguration(configuration, kCGConfigureForSession);
  if (error != kCGErrorSuccess) {
    return fail(EXIT_REFUSED, [NSString stringWithFormat:@"the arrangement was refused (error %d)", error]);
  }
  CGRect bounds = CGDisplayBounds(display);
  printf("%d %d %d %d\n", (int)bounds.origin.x, (int)bounds.origin.y, (int)bounds.size.width, (int)bounds.size.height);
  return 0;
}

static int list(void) {
  CGDirectDisplayID active[16];
  uint32_t count = 0;
  CGGetActiveDisplayList(16, active, &count);
  for (uint32_t index = 0; index < count; index++) {
    CGDirectDisplayID display = active[index];
    CGRect bounds = CGDisplayBounds(display);
    CGDisplayModeRef mode = CGDisplayCopyDisplayMode(display);
    double scale = mode && bounds.size.width > 0 ? CGDisplayModeGetPixelWidth(mode) / bounds.size.width : 1;
    if (mode) CGDisplayModeRelease(mode);
    printf("%u %s %d %d %d %d %g %s %u %u %u\n", display, uuidOf(display).UTF8String, (int)bounds.origin.x,
           (int)bounds.origin.y, (int)bounds.size.width, (int)bounds.size.height, scale,
           CGDisplayIsMain(display) ? "main" : "-", CGDisplayVendorNumber(display), CGDisplayModelNumber(display),
           CGDisplaySerialNumber(display));
  }
  return 0;
}

static int appearance(NSString *wanted) {
  void (*set)(bool) = (void (*)(bool))skyLight("SLSSetAppearanceThemeLegacy");
  bool (*get)(void) = (bool (*)(void))skyLight("SLSGetAppearanceThemeLegacy");
  if (!set || !get) return fail(EXIT_UNAVAILABLE, @"this macOS has no SLSSetAppearanceThemeLegacy");
  if (wanted) set([wanted isEqualToString:@"dark"]);
  printf("%s\n", get() ? "dark" : "light");
  return 0;
}

static int spaces(void) {
  int (*connection)(void) = (int (*)(void))skyLight("SLSMainConnectionID");
  CFArrayRef (*copySpaces)(int) = (CFArrayRef(*)(int))skyLight("SLSCopyManagedDisplaySpaces");
  if (!connection || !copySpaces) return fail(EXIT_UNAVAILABLE, @"this macOS has no SLSCopyManagedDisplaySpaces");
  NSArray *displays = CFBridgingRelease(copySpaces(connection()));
  for (NSDictionary *display in displays) {
    NSArray *all = display[@"Spaces"];
    id current = display[@"Current Space"][@"id64"];
    NSUInteger position = 0;
    for (NSUInteger index = 0; index < all.count; index++) {
      if ([all[index][@"id64"] isEqual:current]) position = index + 1;
    }
    printf("%s %lu %lu\n", [display[@"Display Identifier"] description].UTF8String, (unsigned long)all.count,
           (unsigned long)position);
  }
  return 0;
}

int main(int argc, const char *argv[]) {
  @autoreleasepool {
    NSMutableArray<NSString *> *words = [NSMutableArray array];
    unsigned int serial = 1;
    BOOL hiDPI = NO;
    for (int index = 1; index < argc; index++) {
      NSString *word = @(argv[index]);
      if ([word isEqualToString:@"--hidpi"]) {
        hiDPI = YES;
      } else if ([word isEqualToString:@"--serial"] && index + 1 < argc) {
        serial = (unsigned int)strtoul(argv[++index], NULL, 10);
      } else {
        [words addObject:word];
      }
    }
    NSString *command = words.firstObject;

    BOOL changesTheSystem = [@[ @"add", @"move" ] containsObject:command ?: @""]
        || ([command isEqualToString:@"appearance"] && words.count > 1);
    if (changesTheSystem && !onThrowawayMac()) {
      return fail(EXIT_SOMEBODYS_MAC, @"this Mac is somebody's: displays and the appearance are changed only on GitHub's throwaway Macs");
    }

    if ([command isEqualToString:@"add"] && words.count >= 3) {
      int width = words[1].intValue, height = words[2].intValue;
      if (width < 320 || height < 200 || width > 8192 || height > 8192) {
        return fail(EXIT_USAGE, @"a display is between 320x200 and 8192x8192");
      }
      @try {
        return add((unsigned int)width, (unsigned int)height, words.count > 3 ? words[3] : @"Arbor Test Display", serial, hiDPI);
      } @catch (NSException *exception) {
        // The classes are there but are not what they were when this was written.
        return fail(EXIT_UNAVAILABLE, [NSString stringWithFormat:@"CGVirtualDisplay has changed: %@", exception.reason]);
      }
    }
    if ([command isEqualToString:@"move"] && words.count == 4) {
      return move((CGDirectDisplayID)strtoul(words[1].UTF8String, NULL, 10), words[2].intValue, words[3].intValue);
    }
    if ([command isEqualToString:@"list"]) return list();
    if ([command isEqualToString:@"appearance"]) {
      NSString *wanted = words.count > 1 ? words[1] : nil;
      if (wanted && ![@[ @"dark", @"light" ] containsObject:wanted]) return fail(EXIT_USAGE, @"appearance takes dark or light");
      return appearance(wanted);
    }
    if ([command isEqualToString:@"spaces"]) return spaces();
    return fail(EXIT_USAGE, @"usage: vdisplay add <width> <height> [name] [--serial n] [--hidpi] | move <id> <x> <y> | list | "
                            @"appearance [dark|light] | spaces");
  }
}
