import AppKit
import ArborCore
import Combine
import Foundation
import SwiftUI

/// The settings window: `SettingsPanelModel` on screen. Everything it shows and everything a click means is
/// decided there, where tests reach it; this file opens and closes the window, hands key presses to
/// the model while a shortcut is being recorded, and asks macOS which apps are running. The views are
/// in SettingsViews.swift and SettingsListViews.swift.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
  private let store: SettingsPanelStore
  private var window: NSWindow?
  private var keyMonitor: Any?
  /// The app that was in front when the window was opened, which gets the keyboard back when it closes.
  private var appBefore: NSRunningApplication?

  init(
    model: SettingsPanelModel, openFile: @escaping @MainActor () -> Void,
    openLoginItems: @escaping @MainActor () -> Void
  ) {
    store = SettingsPanelStore(model: model, openFile: openFile, openLoginItems: openLoginItems)
    super.init()
    model.onRecordingChanged = { [weak self] isRecording in self?.recordingChanged(isRecording) }
  }

  /// Opens the window, or brings it to the front, and turns it to `pane` if one is named.
  func show(at pane: SettingsPane?) {
    SettingsMainMenu.install()
    let window = self.window ?? makeWindow()
    self.window = window
    store.model.refreshApps()
    if let pane { store.model.go(to: pane) }
    if let front = NSWorkspace.shared.frontmostApplication,
      front.processIdentifier != NSRunningApplication.current.processIdentifier
    {
      appBefore = front
    }
    // Arbor is an accessory app: nothing brings it to the front unless it asks.
    NSApp.activate(ignoringOtherApps: true)
    if window.isMiniaturized { window.deminiaturize(nil) }
    window.makeKeyAndOrderFront(nil)
  }

  func close() {
    window?.close()
  }

  private func makeWindow() -> NSWindow {
    let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsRootView(store: store)))
    window.title = "Arbor Settings"
    window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
    window.setContentSize(NSSize(width: 780, height: 540))
    // Closing only hides it: the controller keeps it for the next time, and Arbor goes on running.
    window.isReleasedWhenClosed = false
    // Asked for from another macOS Space, it comes to that Space instead of pulling the user back to its own.
    window.collectionBehavior = [.moveToActiveSpace]
    window.delegate = self
    window.center()
    return window
  }

  // MARK: NSWindowDelegate

  /// Tiles and gap handles are panels at the normal level that come to the front whenever the layout is drawn
  /// again, which every change made here causes. While it is in use the window stays above them, or a gap's
  /// invisible handle would lie across its sliders.
  func windowDidBecomeKey(_ notification: Notification) {
    window?.level = .floating
    store.model.refreshApps()
  }

  /// A shortcut can only be recorded while the window gets the keys.
  func windowDidResignKey(_ notification: Notification) {
    window?.level = .normal
    store.model.cancelRecording()
  }

  /// An accessory app that closes its last window stays the active app, so that no window has the keyboard
  /// until something is clicked, and Arbor's own shortcuts find no focused window.
  func windowWillClose(_ notification: Notification) {
    store.model.cancelRecording()
    // A field that is being typed in loses the keyboard, and so hands over what was typed. The window is kept,
    // and would otherwise show it again, as if it were the setting, the next time.
    window?.makeFirstResponder(nil)
    if NSRunningApplication.current.isActive, let appBefore, !appBefore.isTerminated {
      // Since macOS 14 an app comes forward for certain only if the one in front makes way for it.
      NSApp.yieldActivation(to: appBefore)
      _ = appBefore.activate(options: [])
    }
    appBefore = nil
  }

  // MARK: Recording a shortcut

  private func recordingChanged(_ isRecording: Bool) {
    if let keyMonitor {
      NSEvent.removeMonitor(keyMonitor)
      self.keyMonitor = nil
    }
    guard isRecording else { return }
    keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      // Plain values, so that nothing that is not Sendable crosses into the main actor's closure.
      let code = UInt32(event.keyCode)
      let flags = event.modifierFlags.rawValue
      let used = MainActor.assumeIsolated { self?.keyDown(code: code, flags: flags) ?? false }
      return used ? nil : event
    }
  }

  private func keyDown(code: UInt32, flags: UInt) -> Bool {
    let held = NSEvent.ModifierFlags(rawValue: flags)
    var modifiers: KeyChord.Modifiers = []
    if held.contains(.control) { modifiers.insert(.control) }
    if held.contains(.option) { modifiers.insert(.option) }
    if held.contains(.shift) { modifiers.insert(.shift) }
    if held.contains(.command) { modifiers.insert(.command) }
    return store.model.keyPressed(code: code, modifiers: modifiers)
  }

  // MARK: What macOS knows

  /// The apps that are running and have a Dock icon, for `SettingsPanelModel`.
  static func runningApps() -> [SettingsPanelModel.AppChoice] {
    NSWorkspace.shared.runningApplications.compactMap { app in
      guard app.activationPolicy == .regular, let bundleID = app.bundleIdentifier else { return nil }
      return SettingsPanelModel.AppChoice(bundleID: bundleID, name: app.localizedName ?? bundleID)
    }
  }
}

/// Tells SwiftUI when the model has changed.
@MainActor
final class SettingsPanelStore: ObservableObject {
  let model: SettingsPanelModel
  /// Opens settings.json in the user's editor.
  let openFile: @MainActor () -> Void
  /// Opens System Settings at the list of apps that open at login.
  let openLoginItems: @MainActor () -> Void

  init(
    model: SettingsPanelModel, openFile: @escaping @MainActor () -> Void,
    openLoginItems: @escaping @MainActor () -> Void = {}
  ) {
    self.model = model
    self.openFile = openFile
    self.openLoginItems = openLoginItems
    model.onChange = { [weak self] in self?.objectWillChange.send() }
  }
}

/// An accessory app shows no menu bar, but key equivalents are still looked up in its main menu. Without
/// one, ⌘W does not close the window and ⌘C, ⌘V and ⌘A do nothing in its text fields.
@MainActor
enum SettingsMainMenu {
  static func install() {
    guard NSApp.mainMenu == nil else { return }
    let main = NSMenu()
    // The first menu is the app's own, whatever it is called. No Quit in it: ⌘Q pressed to be rid of a
    // settings window must not end the window manager.
    add("Arbor", [], to: main)
    add(
      "Edit",
      [
        ("Undo", "undo:", "z"), ("Redo", "redo:", "Z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"),
        ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a"),
      ], to: main)
    add("Window", [("Close", "performClose:", "w"), ("Minimize", "performMiniaturize:", "m")], to: main)
    NSApp.mainMenu = main
  }

  /// Actions by name, with no target: each goes to whatever in the key window answers to it.
  private static func add(_ title: String, _ items: [(title: String, action: String, key: String)], to main: NSMenu) {
    let menu = NSMenu(title: title)
    for item in items {
      menu.addItem(NSMenuItem(title: item.title, action: Selector((item.action)), keyEquivalent: item.key))
    }
    let holder = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    holder.submenu = menu
    main.addItem(holder)
  }
}
