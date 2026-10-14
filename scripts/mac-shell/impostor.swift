// impostor: a program that passes for Arbor, for the sabotage run (day-sabotage.sh).
//
// Some offences only Arbor can commit: a drop preview beside macOS's own, a busy process with nothing to do, a process that ends unasked or stays
// behind after Quit, a mouse-up that is held back. The detectors tell Arbor by its process. So the sabotage run, in which Arbor is not even built,
// compiles this in the place where Arbor's program would be, calls it Arbor's process, and tells it which offence to commit.
//
//   impostor            reads commands from its standard input, one per line, until that ends:
//     panel <level> x y w h    put up a panel at that window level and frame (global points, origin top-left); 3 is the level of Arbor's drop preview
//     unpanel                  put it away
//     spin <seconds>           keep one core busy that long
//     hold <ms> <seconds>      for that many seconds every left mouse-up waits that many milliseconds in an event tap before it goes on
//     die                      end at once, unasked, with exit code 3
//     quit                     end in good order
//
// It moves no window, reads nothing and writes nothing. Only for GitHub's Macs: the tap holds everybody's input while it is on.

import AppKit
import CoreGraphics
import Foundation

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("impostor: \(message)\n".utf8))
  exit(64)
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

@MainActor var panel: NSPanel?
nonisolated(unsafe) var tapPort: CFMachPort?
nonisolated(unsafe) var holdMilliseconds = 0.0

@MainActor func show(level: Int, frame: CGRect) {
  // AppKit counts from the bottom of the main display.
  let height = NSScreen.screens.first?.frame.maxY ?? 0
  let flipped = CGRect(x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height)
  let made = NSPanel(contentRect: flipped, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
  made.level = NSWindow.Level(rawValue: level)
  made.ignoresMouseEvents = true
  made.backgroundColor = NSColor.systemOrange.withAlphaComponent(0.4)
  made.isOpaque = false
  made.orderFrontRegardless()
  panel = made
}

@MainActor func hold(milliseconds: Double, seconds: Double) {
  holdMilliseconds = milliseconds
  let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .leftMouseUp { Thread.sleep(forTimeInterval: holdMilliseconds / 1000) }
    return Unmanaged.passUnretained(event)
  }
  tapPort = CGEvent.tapCreate(
    tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
    eventsOfInterest: CGEventMask(1) << CGEventMask(CGEventType.leftMouseUp.rawValue), callback: callback, userInfo: nil)
  guard let port = tapPort else { fail("macOS refused the tap") }
  CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0), .commonModes)
  CGEvent.tapEnable(tap: port, enable: true)
  DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
    CGEvent.tapEnable(tap: port, enable: false)
    CFMachPortInvalidate(port)
  }
}

let listening = Thread {
  while let line = readLine() {
    let words = line.split(separator: " ").map(String.init)
    let numbers = words.dropFirst().compactMap(Double.init)
    switch words.first {
    case "panel" where numbers.count == 5:
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          show(level: Int(numbers[0]), frame: CGRect(x: numbers[1], y: numbers[2], width: numbers[3], height: numbers[4]))
        }
      }
    case "unpanel":
      DispatchQueue.main.async {
        MainActor.assumeIsolated {
          panel?.orderOut(nil)
          panel = nil
        }
      }
    case "spin" where numbers.count == 1:
      let until = Date().addingTimeInterval(numbers[0])
      Thread {
        var waste = 0.0
        while Date() < until { waste += 1 }
        if waste < 0 { print(waste) }
      }.start()
    case "hold" where numbers.count == 2:
      DispatchQueue.main.async { MainActor.assumeIsolated { hold(milliseconds: numbers[0], seconds: numbers[1]) } }
    case "die":
      exit(3)
    case "quit":
      exit(0)
    default:
      FileHandle.standardError.write(Data("impostor: no such command: \(line)\n".utf8))
    }
  }
  exit(0)
}
listening.start()
app.run()
