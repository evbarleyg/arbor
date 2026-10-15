// pulse: something on the display that never stops moving, so that a film can tell a display that stands still from one on which
// nothing happens.
//
// camera.swift gets a frame whenever the display changed. While a motion of Arbor's plays, a wait between two frames is a display that
// stood still. Where nothing is meant to move (no stage, no Arbor at all: the controls) the same wait says nothing. So this tool keeps
// a small strip on top of everything, with two squares that cross it once a second, there and back:
//
//   the upper one   is moved by Core Animation in the render server, like the stand-ins of Arbor's stage: this process does nothing for it
//   the lower one   is put where it belongs sixty times a second by this process, like anything an app draws by itself
//
// With the strip up every frame differs from the one before, and the longest wait between two frames of a film IS how long the display
// stood still. Which of the squares moved in a frame says whose work got through.
//
//   pulse <log file> <x> <y>       the strip's top left corner, in global points, y down. It is 256 by 12 points. SIGTERM ends it
//
// It touches nobody's window and takes no click and no key. The log, in the grammar of sampler.swift's:
//   U late ms                      this process's own turn came that long after the one before (only over 100 is written: a hosted Mac is in no hurry with timers)
//   U flush ms                     handing the lower square's new place to the render server took that long (only over 20 is written)
//   U link ms                      the display's own beat, which macOS passes on to whoever asks (a display link), came that long after the one before (16.7 is on
//                                  time; only over 40 is written). It needs nobody to film the display: a witness where no camera runs
//   S turns=n                      at the end

import AppKit
import QuartzCore

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("pulse: \(message)\n".utf8))
  exit(64)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count == 3, let left = Double(arguments[1]), let top = Double(arguments[2]) else {
  fail("usage: pulse <log file> <x> <y>")
}
/// Not `guard let`: what that binds at the top of a file is no global, and the functions below could not use it.
let logFile: UnsafeMutablePointer<FILE> = {
  guard let file = fopen(arguments[0], "a") else { fail("cannot write to \(arguments[0])") }
  return file
}()

func now() -> Double { Date().timeIntervalSince1970 * 1000 }
func write(_ line: String) {
  fputs("\(Int64(now())) \(line)\n", logFile)
  fflush(logFile)
}

let width: CGFloat = 256
let height: CGFloat = 12
let side: CGFloat = 6

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
// A process nobody looks at gets its timers late. This one is looked at.
let activity = ProcessInfo.processInfo.beginActivity(
  options: [.userInitiated, .latencyCritical], reason: "the squares have to move on time")

guard let screen = NSScreen.screens.first else { fail("no display") }
let panel = NSPanel(
  contentRect: NSRect(x: CGFloat(left), y: screen.frame.maxY - CGFloat(top) - height, width: width, height: height),
  styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
panel.isOpaque = true
panel.backgroundColor = .black
panel.hasShadow = false
panel.hidesOnDeactivate = false
panel.ignoresMouseEvents = true
panel.animationBehavior = .none
// Above Arbor's stage, which is one above the floating windows.
panel.level = .screenSaver
panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

let view = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
let root = CALayer()
view.layer = root
view.wantsLayer = true
panel.contentView = view

func square(y: CGFloat, colour: NSColor) -> CALayer {
  let layer = CALayer()
  layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
  layer.position = CGPoint(x: side / 2, y: y)
  layer.backgroundColor = colour.cgColor
  root.addSublayer(layer)
  return layer
}

// Layers count y upwards.
let upper = square(y: height - side / 2, colour: .white)
let lower = square(y: side / 2, colour: .yellow)

let crossing = CABasicAnimation(keyPath: "position.x")
crossing.fromValue = side / 2
crossing.toValue = width - side / 2
crossing.duration = 1
crossing.autoreverses = true
crossing.repeatCount = .infinity
crossing.timingFunction = CAMediaTimingFunction(name: .linear)
upper.add(crossing, forKey: "crossing")
panel.orderFrontRegardless()

var turns = 0
var last = now()
let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { _ in
  let began = now()
  if began - last > 100 { write("U late \(Int(began - last))") }
  last = began
  turns += 1
  // There in one second and back in the next.
  let phase = (began / 1000).truncatingRemainder(dividingBy: 2)
  let share = CGFloat(phase < 1 ? phase : 2 - phase)
  CATransaction.begin()
  CATransaction.setDisableActions(true)
  lower.position.x = side / 2 + share * (width - side)
  CATransaction.commit()
  CATransaction.flush()
  let took = now() - began
  if took > 20 { write("U flush \(Int(took))") }
}
RunLoop.main.add(timer, forMode: .common)

final class Beat: NSObject {
  var last = now()
  @objc func tick(_ link: CADisplayLink) {
    let time = now()
    if time - last > 40 { write("U link \(Int(time - last))") }
    last = time
  }
}
let beat = Beat()
let link = screen.displayLink(target: beat, selector: #selector(Beat.tick(_:)))
link.add(to: .main, forMode: .common)

signal(SIGTERM, SIG_IGN)
let ending = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
ending.setEventHandler {
  write("S turns=\(turns)")
  exit(0)
}
ending.resume()
write("M pulse at \(Int(left)) \(Int(top)) \(Int(width)) \(Int(height))")
withExtendedLifetime((activity, ending, beat, link)) { application.run() }
