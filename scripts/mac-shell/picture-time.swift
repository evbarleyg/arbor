// picture-time: how long ScreenCaptureKit takes to picture 1, 4 and 8 windows, one after another and all at once.
// For scripts/mac-shell/probe-glide.sh, which compiles it (swiftc -O -swift-version 5).
//
// A stand-in that is a picture of its window has to be taken when the motion is asked for, if none is to be kept about: then the first frame waits for
// the pictures. This says for how long. It asks as Sources/ArborKit/UI/WindowPictures.swift does: SCScreenshotManager.captureImage with a filter for
// one window, whatever covers it, at the display's scale.
//
//   picture-time <window>…
//
// It prints milliseconds and pixels and nothing else. NO PICTURE IS WRITTEN ANYWHERE: each is let go of as soon as it has come. It never reads a title.
// Needs Screen Recording; without it, it says so, asks nobody, and ends with exit code 0.
//   scale <n>                                    of the main display
//   list <ms> <windows>                          the list of windows every picture starts from; twice, because the first time is the dearest
//   window <id> <w>x<h>                          the pixels asked for
//   pictures <n> in-turn <ms in all> <failed> each <ms>…
//   pictures <n> at-once <ms in all> <failed>

import AppKit
import ScreenCaptureKit

func now() -> Double { Double(DispatchTime.now().uptimeNanoseconds) / 1_000_000 }
func text(_ value: Double) -> String { String(format: "%.1f", value) }

guard CGPreflightScreenCaptureAccess() else {
  print("no-permission: Screen Recording is not granted here, and nobody is asked for it")
  exit(0)
}

/// What a completion handler leaves for the thread that waits for it.
final class Box<Value>: @unchecked Sendable {
  private let lock = NSLock()
  private var kept: Value
  init(_ value: Value) { kept = value }
  var value: Value {
    get { lock.lock(); defer { lock.unlock() }; return kept }
    set { lock.lock(); kept = newValue; lock.unlock() }
  }
  func change(_ body: (inout Value) -> Void) { lock.lock(); body(&kept); lock.unlock() }
}

func listed() -> [SCWindow] {
  let found = Box<[SCWindow]>([])
  let done = DispatchSemaphore(value: 0)
  SCShareableContent.getExcludingDesktopWindows(false, onScreenWindowsOnly: true) { content, _ in
    found.value = content?.windows ?? []
    done.signal()
  }
  // Nobody is there to answer a dialog.
  if done.wait(timeout: .now() + 10) == .timedOut { print("no-answer: ScreenCaptureKit did not list the windows within 10 s"); exit(0) }
  return found.value
}

let scale = NSScreen.main?.backingScaleFactor ?? 1
print("scale \(text(Double(scale)))")
var all: [SCWindow] = []
for _ in 1...2 {
  let began = now()
  all = listed()
  print("list \(text(now() - began)) \(all.count)")
}
let wanted = CommandLine.arguments.dropFirst().compactMap { CGWindowID($0) }
let windows = wanted.compactMap { id in all.first { $0.windowID == id } }
for id in wanted where !windows.contains(where: { $0.windowID == id }) { print("not-listed \(id)") }

/// It has to outlive every configuration it is given to, which does not retain it (WindowPictures.swift met the crash).
let noBackground = NSColor.clear.cgColor

func ask(_ window: SCWindow, then: @escaping @Sendable (Bool) -> Void) {
  let configuration = SCStreamConfiguration()
  configuration.width = max(Int(window.frame.width * scale), 1)
  configuration.height = max(Int(window.frame.height * scale), 1)
  configuration.scalesToFit = true
  configuration.showsCursor = false
  configuration.ignoreShadowsSingleWindow = true
  configuration.backgroundColor = noBackground
  SCScreenshotManager.captureImage(contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration) { image, _ in
    then(image != nil)
  }
}

for window in windows { print("window \(window.windowID) \(Int(window.frame.width * scale))x\(Int(window.frame.height * scale))") }
for count in [1, 4, 8] where count <= windows.count {
  var each: [String] = []
  var failed = 0
  let began = now()
  for window in windows.prefix(count) {
    let asked = now()
    let came = Box(false)
    let done = DispatchSemaphore(value: 0)
    ask(window) { came.value = $0; done.signal() }
    if done.wait(timeout: .now() + 10) == .timedOut || !came.value { failed += 1 }
    each.append(text(now() - asked))
  }
  print("pictures \(count) in-turn \(text(now() - began)) \(failed) each \(each.joined(separator: " "))")

  let missing = Box(count)
  let together = DispatchGroup()
  let again = now()
  for window in windows.prefix(count) {
    together.enter()
    ask(window) { came in
      if came { missing.change { $0 -= 1 } }
      together.leave()
    }
  }
  _ = together.wait(timeout: .now() + 10)
  print("pictures \(count) at-once \(text(now() - again)) \(missing.value)")
}
