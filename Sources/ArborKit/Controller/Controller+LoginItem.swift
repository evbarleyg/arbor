import ArborCore

extension Controller {
  /// `launch-at-login [on|off]`. Needs no Accessibility permission, so it works before `start()`.
  func launchAtLogin(_ enabled: Bool?) -> CommandResult {
    let result = Self.launchAtLogin(enabled, item: loginItem)
    if enabled != nil { Log.info("\(Command.launchAtLogin(enabled).text): \(result.message)") }
    return result
  }

  /// The same without a controller: `Arbor --launch-at-login off` is how `make uninstall` removes the
  /// login item whether or not Arbor is running.
  static func launchAtLogin(_ enabled: Bool?, item: (any LoginItem)?) -> CommandResult {
    guard let item else { return .failure("this build cannot open at login") }
    if case .unavailable(let reason) = item.status { return .failure(reason) }
    var note = ""
    // Waiting for approval counts as on: Arbor is registered, so `off` has something to remove and
    // registering again would change nothing.
    if let enabled, enabled != (item.status != .disabled) {
      do {
        try item.setEnabled(enabled)
      } catch {
        note = " (macOS refused: \(error))"
      }
    }
    // The reply is what macOS says now, whatever was asked for. A question gets a word a script can compare.
    switch item.status {
    case .enabled:
      return CommandResult(ok: enabled != false, message: enabled == nil ? "on" : "Arbor opens at login" + note)
    case .disabled:
      return CommandResult(ok: enabled != true, message: enabled == nil ? "off" : "Arbor does not open at login" + note)
    case .requiresApproval:
      let message =
        "Arbor is set to open at login but is switched off in System Settings → General → "
        + "Login Items & Extensions, and only you can switch it on there"
      return CommandResult(ok: enabled == nil, message: enabled == nil ? "off: \(message)" : message + note)
    case .unavailable(let reason):
      return .failure(reason)
    }
  }
}
