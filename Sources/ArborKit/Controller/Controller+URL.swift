import ArborCore

/// Commands that arrive as `arbor://` URLs (see CommandURL.swift for why they are treated apart).
extension Controller {
  /// The command an `arbor://` URL may run now. A URL that does not parse, or whose command is not
  /// accepted from URLs while `allowAllURLCommands` is off, or would take away something a person made
  /// (Controller+URLCost.swift), fails with the reason, which is also logged.
  public func admit(url text: String) -> Result<Command, Command.ParseError> {
    do {
      let command = try Command.parse(url: text)
      guard command.isAllowedFromURL || settings.allowAllURLCommands else {
        let verb = command.nameWhenRefusedFromURL
        throw Command.ParseError(
          refusing: "`\(verb)` is not accepted from URLs; set allowAllURLCommands to true in settings.json to allow it")
      }
      if !settings.allowAllURLCommands, let reason = refusalForWhatALinkWouldCost(command) {
        throw Command.ParseError(refusing: reason)
      }
      return .success(command)
    } catch let error as Command.ParseError {
      // Only its first word. What follows can be part of a window title (`rule/add/…/title/…`, also after
      // `bind`; `layout/Safari~…`) or the name of a space (F20), and so can what the reason quotes; neither
      // is ever logged. The log escapes and shortens what it is given, so a hostile URL cannot forge or flood it.
      let verb = text.drop { $0 != ":" }.dropFirst().drop { $0 == "/" }.prefix { !"/?#".contains($0) }
      let mayHoldPrivateWords = Command.mayHoldPrivateWords(verb: verb)
      Log.error("refused a URL, arbor://\(verb)…" + (mayHoldPrivateWords ? "" : ": \(error)"))
      return .failure(error)
    } catch {
      return .failure(Command.ParseError(refusing: "\(error)"))
    }
  }
}
