// desk: a small window to try input on, for the rounds of input (lib-walk.sh, input_round; docs/VIABLE.md, `input-held`).
//
// A round posts the same presses, keys, scrolls and a drag four times in a journey, and counts what arrives and how late. Real apps' windows will not do for that: in a pile of nine large
// windows eight title bars could be pressed where ten were needed, and the one meant for the keys was covered in three rounds of four. So the instrument brings its own: two of these, side
// by side, each a program of its own. A press on the title bar of the one that is not in front brings another app forward, every time; once they are the two frontmost windows nothing
// covers them; and the text in them takes arrow keys, scrolls and a drag that selects, and nothing comes of it.
//
//   desk <name> x y w h      opens the window there (global points, origin top-left), prints `<pid> <window number>`, and stays until it is ended
//
// SIGUSR1 brings it to the front, as a click on its icon in the Dock would. It does that itself: asked by another program, macOS brought a desk forward in four rounds of seven, and in the
// others two dozen presses, the keys and the drag went to the browser that lay over it.
//
// To Arbor it is an ordinary app with an ordinary window. It reads nothing and writes nothing.

import AppKit

func fail(_ message: String) -> Never {
  FileHandle.standardError.write(Data("desk: \(message)\n".utf8))
  exit(64)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let numbers = arguments.dropFirst().compactMap(Double.init)
guard arguments.count == 5, numbers.count == 4 else { fail("desk <name> x y w h") }

let app = NSApplication.shared
// With a place under ⌘Tab and in the Dock, so that it can be the app in front like any other.
app.setActivationPolicy(.regular)

// AppKit counts from the bottom of the main display.
let height = NSScreen.screens.first?.frame.maxY ?? 0
let window = NSWindow(
  contentRect: NSRect(x: 0, y: 0, width: numbers[2], height: numbers[3]), styleMask: [.titled, .closable, .miniaturizable, .resizable],
  backing: .buffered, defer: false)
window.title = "desk \(arguments[0])"
window.isReleasedWhenClosed = false
window.setFrame(NSRect(x: numbers[0], y: height - numbers[1] - numbers[3], width: numbers[2], height: numbers[3]), display: true)

let scroll = NSTextView.scrollableTextView()
scroll.hasVerticalScroller = true
if let text = scroll.documentView as? NSTextView {
  // Long enough to scroll either way from the middle.
  text.string = (1...200).map { "line \($0) of a text that is here to be scrolled, selected and walked through" }.joined(separator: "\n")
  text.isAutomaticSpellingCorrectionEnabled = false
  text.isContinuousSpellCheckingEnabled = false
  text.scrollRangeToVisible(NSRange(location: text.string.utf16.count / 2, length: 0))
  text.selectedRange = NSRange(location: text.string.utf16.count / 2, length: 0)
  window.initialFirstResponder = text
}
window.contentView = scroll
window.orderFrontRegardless()

print("\(ProcessInfo.processInfo.processIdentifier) \(window.windowNumber)")
fflush(stdout)

signal(SIGUSR1, SIG_IGN)
let forward = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
forward.setEventHandler {
  MainActor.assumeIsolated {
    app.activate(ignoringOtherApps: true)
    window.makeKeyAndOrderFront(nil)
  }
}
forward.resume()

app.run()
