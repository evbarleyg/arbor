import ArborCore

/// What a trace may hold of the words people type into commands (docs/TRACES.md, "What is never in a trace").
///
/// Titles are replaced wherever they turn up whole. That does not catch what is typed to *find* something: the beginning of a
/// name (`go cli`), a part of a title (`layout Mail~pays | Notes`). Nor may it simply be crossed out, or the command would not do in a
/// replay what it did in the recording. So it is replaced by what it stood for at that moment, in a form that stands
/// for the same thing in a replay: a space's whole name, which becomes its token, or a window's number.
extension Controller: TraceWordsSource {
  public func wordsForTrace(
    inCommand text: String, from source: CommandSource?
  ) -> (text: String, names: Set<String>, sameReply: Bool) {
    guard let command = try? Command.parse(text) else { return (TitleTokens.unreadable(text), everySpaceName(), false) }
    // Looking things up asks which hand leads, and `InputLead` remembers what it answered (F56). Recording changes nothing.
    let before = following
    defer { following = before }
    let (resolved, sameReply) = from(source ?? following.source) { self.resolved(command) }
    // What was typed and found nothing stays, so it counts as a name: replies quote it.
    return (resolved.text, everySpaceName().union(resolved.namesInText), sameReply)
  }

  private func resolved(_ command: Command) -> (Command, sameReply: Bool) {
    switch command {
    case .goToSpace(let typed):
      switch search(for: typed) {
      case .found(let space): return (.goToSpace(space.name), true)
      // The reply lists the names that begin so. Tokens all begin alike, so nothing that could stand for what was typed picks out the
      // same ones. The command changes nothing either way.
      case .several: return (command, false)
      case .none: break
      }
    case .unname(let typed?):
      if case .found(let space) = search(for: typed, wholeNameOnly: true) { return (.unname(space.name), true) }
    case .layout(let spec, let display, let open) where spec.slots.contains { $0.title != nil }:
      return (.layout(withoutTitles(spec, on: display), display: display, open: open), true)
    // Their replies quote history, some of which the trace has rewritten: the line above, for one (F19).
    case .undo, .redo: return (command, false)
    case .settings(.bind(let chord, let text)):
      // What a shortcut is made to run is a command like any other, with the same words in it. A replay does not go by it: the line of
      // a shortcut that was pressed says what it ran.
      // One that cannot be read is no command, and `bind` is refused. Somebody's words are in it all the same.
      guard let inner = try? Command.parse(text) else { return (.settings(.bind(chord: chord, command: TitleTokens.unreadable(text))), false) }
      // What `find` is to look for is any part of a title. On its own it has a stand-in by now (`textForTrace`), which finds the same;
      // here nothing is looked for yet.
      // The reply repeats the command as it was typed, so it comes out the same only if nothing had to be replaced.
      if case .find(.some) = inner { return (.settings(.bind(chord: chord, command: inner.textForLog)), false) }
      let (shown, sameReply) = resolved(inner)
      return (.settings(.bind(chord: chord, command: shown.text)), sameReply && shown == inner)
    default: break
    }
    return (command, true)
  }

  /// `spec` with every slot that asks for a title naming the windows it gets by their numbers, which is exact and gives nothing
  /// away. One that gets none keeps its app. The other slots stay as they were written.
  private func withoutTitles(_ spec: LayoutNotation.Spec, on display: String?) -> LayoutNotation.Spec {
    var current: LayoutTree?
    if case .display(let id) = chooseDisplay(display) { current = workspaces[id]?.tree }
    let windows = spec.resolve(windowCandidates(), current: current).windows
    var next = 0
    func rewritten(_ space: LayoutNotation.Space) -> LayoutNotation.Space {
      switch space.kind {
      case .desktop:
        return space
      case .group(let axis, let members):
        return LayoutNotation.Space(.group(axis, members.map(rewritten)), size: space.size)
      case .windows(let slots):
        var named: [WindowSlot] = []
        for slot in slots {
          let found = next < windows.count ? windows[next] : []
          next += 1
          if slot.title == nil {
            named.append(slot)
          } else if found.isEmpty {
            named.append(WindowSlot(slot.owner, takesAll: slot.takesAll))
          } else {
            named += found.map(WindowSlot.window)
          }
        }
        return LayoutNotation.Space(.windows(named), size: space.size)
      }
    }
    return LayoutNotation.Spec(root: rewritten(spec.root))
  }

  /// The header holds the arrangements, with their names, and the settings, with the commands of people's own shortcuts.
  func hideWords(in header: inout TraceHeader, _ titles: inout TitleTokens) {
    for name in SpaceName.sorted(everySpaceName()) { _ = titles.nameToken(for: name) }
    var tokens = titles
    header.workspaces = header.workspaces.mapValues { $0.renamingSpaces { tokens.nameToken(for: $0) } }
    header.dormant = header.dormant.mapValues { $0.renamingSpaces { tokens.nameToken(for: $0) } }
    titles = tokens
    header.settings = titles.sanitisedBindings(header.settings)
  }
}

extension Controller {
  /// A reply that says why settings.json cannot be read quotes the file at the typo, for whoever wrote it, and the typo can be inside a
  /// rule's `title`. The log gets the line and the column instead (`forTheLog`), and so does a trace.
  public func asItMayBeLogged(_ text: String) -> String { forTheLog(text) }

  /// `rule add … title Payslip`, `rule change 2 … title Payslip`, and either of them as what a shortcut is made to run.
  public func partsOfTitles(inCommand text: String) -> [String] {
    switch try? Command.parse(text) {
    case .settings(.addRule(let rule)), .settings(.changeRule(_, let rule)): [rule.title].compactMap { $0 }
    case .settings(.bind(_, let command)): partsOfTitles(inCommand: command)
    default: []
    }
  }
}
