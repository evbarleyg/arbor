import AppKit
for screen in NSScreen.screens {
  let f = screen.frame, v = screen.visibleFrame
  print("screen \(Int(f.minX)) \(Int(f.minY)) \(Int(f.width)) \(Int(f.height)) visible \(Int(v.minX)) \(Int(v.minY)) \(Int(v.width)) \(Int(v.height))")
}
