import ArborCore

/// Commands that arrive as `arbor://` URLs (see CommandURL.swift for why they are treated apart).
extension Controller {
  /// The command an `arbor://` URL may run now. A URL that does not parse, or whose command is not
  /// accepted from URLs while `allowAllURLCommands` is off, or would take away something a person made
  /// (Controller+URLCost.swift), fails with the reason. The log hears of it in Arbor's own words.
  public func admit(url text: String) -> Result<Command, Command.ParseError> {
    var wasRead = false
    do {
      let command = try Command.parse(url: text)
      wasRead = true
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
      // And that only if it is one of Arbor's; and why a URL cannot be read quotes it, whatever its first word.
      let verb = text.drop { $0 != ":" }.dropFirst().drop { $0 == "/" }.prefix { !"/?#".contains($0) }
      let reason = !wasRead ? ": it cannot be read as a command" : Command.mayHoldPrivateWords(verb: verb) ? "" : ": \(error)"
      Log.error("refused a URL, arbor://\(Command.isVerb(verb) ? verb.lowercased() : "")…\(reason)")
      return .failure(error)
    } catch {
      return .failure(Command.ParseError(refusing: "\(error)"))
    }
  }
}
