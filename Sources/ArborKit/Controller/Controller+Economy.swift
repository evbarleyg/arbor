import ArborCore

/// Not doing things twice. What Arbor asks of other processes is what its latency is made of (`BudgetTests`
/// pins what commands may ask, `arbor-sim bench` prints it, and `arborctl stats` says what it cost on this Mac).
extension Controller {
  func statsReport(reset: Bool) -> CommandResult {
    if reset {
      stats.reset()
      return .success("counting afresh")
    }
    return CommandResult(ok: true, message: "statistics", text: stats.report())
  }
}

extension Command {
  /// The command's first word, which names it in the statistics.
  var verb: String { text.split(separator: " ").first.map(String.init) ?? text }
}
