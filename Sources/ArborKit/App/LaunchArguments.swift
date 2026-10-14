import ArborCore
import Foundation

/// What the Arbor binary does when it is started from a shell with one of these arguments, instead
/// of becoming the app. They answer without a running Arbor, which the scripts need:
///
///     Arbor.app/Contents/MacOS/Arbor --version
///     Arbor.app/Contents/MacOS/Arbor --launch-at-login [on|off]    # `make uninstall` uses `off`
///
/// Anything else is left alone: macOS passes arguments of its own to apps.
@MainActor
enum LaunchArguments {
  /// The exit code, or nil when Arbor should start as the app.
  static func run(_ arguments: [String]) -> Int32? {
    switch arguments.first {
    case "--version":
      print("Arbor \(BuildInfo(infoDictionary: Bundle.main.infoDictionary).text)")
      return 0
    case "--launch-at-login":
      guard case .launchAtLogin(let enabled)? = try? Command.parse(words: ["launch-at-login"] + arguments.dropFirst())
      else {
        print("usage: Arbor --launch-at-login [on|off]")
        return 64
      }
      let result = Controller.launchAtLogin(enabled, item: SystemLoginItem())
      print(result.message)
      return result.ok ? 0 : 1
    default:
      return nil
    }
  }
}
