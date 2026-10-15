import ArborCore
@testable import ArborKit
import CoreGraphics
import FakeMacOS
import Foundation

// Storey one: the real `AXWindowSystem` alone on the model of a Mac, with a listener that writes down what it reports.

/// One thing the layer reported.
enum Heard: Equatable {
  case appeared(UInt32), found(UInt32), destroyed(UInt32), focused(UInt32)
  case changed(UInt32, byUser: Bool)
  case replaced(UInt32, by: UInt32)
  case keyboardMoved, pressed, displaysChanged, refused
  case dragBegan(UInt32), dragMoved(UInt32), dragEnded(UInt32), dragCancelled(UInt32)
  case resizeBegan(UInt32), resizeEnded(UInt32)

  var text: String {
    switch self {
    case .appeared(let id): "appeared w\(id)"
    case .found(let id): "found w\(id)"
    case .destroyed(let id): "destroyed w\(id)"
    case .focused(let id): "focused w\(id)"
    case .changed(let id, let byUser): "changed w\(id)\(byUser ? " (not by Arbor)" : " (echo)")"
    case .replaced(let old, let new): "replaced w\(old) by w\(new)"
    case .keyboardMoved: "keyboard moved"
    case .pressed: "pressed"
    case .displaysChanged: "displays changed"
    case .refused: "accessibility refused"
    case .dragBegan(let id): "drag began w\(id)"
    case .dragMoved(let id): "drag moved w\(id)"
    case .dragEnded(let id): "drag ended w\(id)"
    case .dragCancelled(let id): "drag cancelled w\(id)"
    case .resizeBegan(let id): "resize began w\(id)"
    case .resizeEnded(let id): "resize ended w\(id)"
    }
  }

  /// The window it is about.
  var window: UInt32? {
    switch self {
    case .appeared(let id), .found(let id), .destroyed(let id), .focused(let id), .changed(let id, _), .dragBegan(let id), .dragMoved(let id),
      .dragEnded(let id), .dragCancelled(let id), .resizeBegan(let id), .resizeEnded(let id):
      id
    case .replaced(_, let new): new
    case .keyboardMoved, .pressed, .displaysChanged, .refused: nil
    }
  }
}

@MainActor
final class Listener: WindowSystemEvents {
  private(set) var all: [Heard] = []
  /// The snapshot that came with the latest report about each window.
  private(set) var latest: [UInt32: WindowSnapshot] = [:]
  var mac: FakeMac?
  /// Somebody who wants to hear as well: storey two's controller.
  var next: (any WindowSystemEvents)?

  private func hear(_ event: Heard) {
    all.append(event)
    mac?.note("        Arbor's layer reports: \(event.text)")
  }

  /// Forgets what was heard so far, so that a story can ask about what follows.
  func clear() { all.removeAll() }
  func about(_ window: FakeMac.Window) -> [Heard] { all.filter { $0.window == window.number } }
  var texts: String { all.map(\.text).joined(separator: ", ") }
  /// Without the reports that come in numbers and say nothing about an order.
  var outline: [Heard] {
    all.filter {
      switch $0 {
      case .changed, .keyboardMoved, .dragMoved, .pressed: false
      default: true
      }
    }
  }

  func windowAppeared(_ window: WindowSnapshot) {
    latest[window.id.rawValue] = window
    hear(.appeared(window.id.rawValue))
    next?.windowAppeared(window)
  }
  func windowFound(_ window: WindowSnapshot) {
    latest[window.id.rawValue] = window
    hear(.found(window.id.rawValue))
    next?.windowFound(window)
  }
  func windowDestroyed(_ id: WindowID) {
    hear(.destroyed(id.rawValue))
    next?.windowDestroyed(id)
  }
  func windowChanged(_ window: WindowSnapshot, userInitiated: Bool) {
    latest[window.id.rawValue] = window
    hear(.changed(window.id.rawValue, byUser: userInitiated))
    next?.windowChanged(window, userInitiated: userInitiated)
  }
  func windowFocused(_ id: WindowID) {
    hear(.focused(id.rawValue))
    next?.windowFocused(id)
  }
  func applicationActivated(_ app: FrontmostApp?) { next?.applicationActivated(app) }
  func accessibilityWasRefused() {
    hear(.refused)
    next?.accessibilityWasRefused()
  }
  func dragBegan(_ id: WindowID, at point: CGPoint) {
    hear(.dragBegan(id.rawValue))
    next?.dragBegan(id, at: point)
  }
  func dragMoved(_ id: WindowID, to point: CGPoint) {
    hear(.dragMoved(id.rawValue))
    next?.dragMoved(id, to: point)
  }
  func dragEnded(_ id: WindowID, at point: CGPoint) {
    hear(.dragEnded(id.rawValue))
    next?.dragEnded(id, at: point)
  }
  func displaysChanged() {
    hear(.displaysChanged)
    next?.displaysChanged()
  }
  func resizeBegan(_ id: WindowID) {
    hear(.resizeBegan(id.rawValue))
    next?.resizeBegan(id)
  }
  func resizeEnded(_ id: WindowID) {
    hear(.resizeEnded(id.rawValue))
    next?.resizeEnded(id)
  }
  func keyboardFocusMoved() {
    hear(.keyboardMoved)
    next?.keyboardFocusMoved()
  }
  func dragCancelled(_ id: WindowID) {
    hear(.dragCancelled(id.rawValue))
    next?.dragCancelled(id)
  }
  func windowReplaced(_ old: WindowID, by window: WindowSnapshot) {
    latest[window.id.rawValue] = window
    hear(.replaced(old.rawValue, by: window.id.rawValue))
    next?.windowReplaced(old, by: window)
  }
  func pointerPressed() {
    hear(.pressed)
    next?.pointerPressed()
  }
}

/// A Mac with the real layer running on it.
@MainActor
final class StoreyOne {
  let mac = FakeMac()
  let layer = AXWindowSystem()
  let heard = Listener()

  /// `before` sets the Mac up as it is when Arbor starts. A second then passes, and the layer starts.
  init(_ story: Story, before: (FakeMac) -> Void = { _ in }) {
    FakeMac.current = mac
    before(mac)
    mac.pass(1)
    heard.mac = mac
    layer.events = heard
    mac.note("Arbor starts")
    layer.start()
    mac.pass(0.5)
    story.onFailure { [mac] in "    what happened on the Mac, and what Arbor's layer made of it:\n" + mac.journal.map { "      " + $0 }.joined(separator: "\n") }
    story.atTheEnd { [mac, layer] in
      layer.stop()
      mac.end()
    }
  }

  func snapshot(_ window: FakeMac.Window) -> WindowSnapshot? { layer.allWindows().first { $0.id.rawValue == window.number } }
  var known: [UInt32] { layer.allWindows().map(\.id.rawValue) }

  /// Where the keyboard is by the layer's last word on it: the window it last reported focused, or, if it has said since that the keyboard may be
  /// somewhere else, what it answers when asked (`WindowSystemEvents.keyboardFocusMoved`).
  var lastWordOnTheKeyboard: UInt32? {
    for event in heard.all.reversed() {
      if case .focused(let id) = event { return id }
      if event == .keyboardMoved { return layer.focusedWindow()?.rawValue }
    }
    return layer.focusedWindow()?.rawValue
  }
}
