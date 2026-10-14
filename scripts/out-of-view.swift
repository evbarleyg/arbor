// Counts the windows that are all but off every display, as the window server has them, and prints the number.
//
//   swift scripts/out-of-view.swift
//
// scripts/install.sh asks before it takes Arbor away. A window that Arbor has moved out of view sits at the edge of a display with a point
// of it showing, and Arbor is what brings it back: when it quits, or, after an accident, when it next starts. An Arbor that may not
// move windows (its Accessibility switch is off, or belongs to a build with another signature) or that hangs puts nothing back,
// whatever it answers. So nobody is asked but the window server, which needs no permission to say where windows are.
//
// It reads no title and names no app. Exit code 2: the window server did not say.

import CoreGraphics
import Foundation

var ids = [CGDirectDisplayID](repeating: 0, count: 32)
var count: UInt32 = 0
guard CGGetActiveDisplayList(UInt32(ids.count), &ids, &count) == .success, count > 0,
  let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
else { exit(2) }
let displays = ids.prefix(Int(count)).map { CGDisplayBounds($0) }

var outOfView = 0
for info in list {
  // Ordinary windows of a size somebody would miss. Panels, menus and the specks some apps keep are nobody's loss.
  guard (info[kCGWindowLayer as String] as? NSNumber)?.intValue == 0,
    let bounds = (info[kCGWindowBounds as String] as? NSDictionary).flatMap({ CGRect(dictionaryRepresentation: $0 as CFDictionary) }),
    bounds.width >= 50, bounds.height >= 50
  else { continue }
  // What a person drags aside keeps enough of its title bar to be dragged back: macOS sees to that.
  let shows = displays.contains { display in
    let part = display.intersection(bounds)
    return !part.isNull && part.width > 8 && part.height > 8
  }
  if !shows { outOfView += 1 }
}
print(outOfView)
