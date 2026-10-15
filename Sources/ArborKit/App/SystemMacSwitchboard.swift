import ArborCore
import ArborIPC
import Foundation

/// The real switches: the `com.apple.WindowManager` defaults of the person's account, which is where System Settings → Desktop & Dock
/// keeps them.
///
/// Tried on macOS 26.6 and on 15.7 with every switch as a Mac comes (`scripts/mac-shell/probe-switches.sh`): a window held at the left
/// edge, at the menu bar and anywhere with ⌥ down brought up macOS's preview and was tiled, and a click on the wallpaper swept every window
/// aside. A second after the keys of all four were written as false, by `defaults write` or by a program, none of that happened any more; a second
/// after they were removed again, all of it did. Nothing was restarted, neither WindowManager nor the Dock, and no window moved.
@MainActor
final class SystemMacSwitchboard: MacSwitchboard {
  private let ledger: MacSwitchLedger

  init(ledger: MacSwitchLedger = MacSwitchLedger(file: ArborPaths.home.appendingPathComponent(MacSwitchLedger.fileName))) {
    self.ledger = ledger
  }

  func stored(_ item: MacSwitch) -> Bool? { MacFacts.stored(item.defaultsKey) }

  func store(_ value: Bool?, for item: MacSwitch) {
    guard let defaults = MacFacts.windowManagerDefaults else { return }
    if let value {
      defaults.set(value, forKey: item.defaultsKey)
    } else {
      defaults.removeObject(forKey: item.defaultsKey)
    }
    // Handed over now: `Arbor --fix-setup undo` exits a moment later, and what is still on its way then is lost.
    defaults.synchronize()
  }

  /// Read every time, small as it is: `Arbor --fix-setup undo` is another process, and what it took back a paused Arbor must not take again.
  func records() -> [MacSwitchRecord]? { ledger.read() }

  func keep(_ records: [MacSwitchRecord]) -> Bool {
    guard (try? ArborPaths.ensureHome()) != nil, ledger.write(records) else {
      Log.error("could not write \(MacSwitchLedger.fileName)")
      return false
    }
    return true
  }
}
