import ArborCore
import CoreGraphics

/// The field a name is typed into (⌃⌥N, docs/features/F20-named-spaces.md). Part of `OverlayScene`;
/// filled in by `Controller+NamedSpaces.swift`, shown by `NamePanel`.
///
/// Everything the panel says or does is decided here, where tests reach it. The panel shows `title` and
/// `initial`, asks `answer(to:)` after every keystroke for the line under the field, runs the answer's
/// command on ↩ and `cancel` on ⎋. It knows nothing of what is being named: another kind of name is another
/// case of `Subject`.
public struct NamePromptModel: Equatable, Sendable {
  public enum Subject: Equatable, Sendable {
    /// A space: the name it has now, what it holds in words ("Safari and Notes"), and the names of the
    /// display's other spaces with what each of them holds.
    case space(NodeID, current: String?, contents: String, others: [String: String])
  }

  public var display: DisplayID
  /// Where the panel goes, in global coordinates.
  public var frame: CGRect
  public var subject: Subject

  public init(display: DisplayID, frame: CGRect, subject: Subject) {
    self.display = display
    self.frame = frame
    self.subject = subject
  }

  public var title: String {
    switch subject {
    case .space(_, let current, _, _): current == nil ? "Name this space" : "Rename this space"
    }
  }

  /// What the field starts with, selected.
  public var initial: String {
    switch subject {
    case .space(_, let current, _, _): current ?? ""
    }
  }

  /// What ⎋, and a click anywhere else, run.
  public var cancel: Command { .askName(cancel: true) }

  public static let size = CGSize(width: 380, height: 96)

  /// In the upper middle of the display, where Spotlight has taught people to look for a field.
  public static func frame(in visibleFrame: CGRect) -> CGRect {
    CGRect(
      x: (visibleFrame.midX - size.width / 2).rounded(), y: (visibleFrame.minY + visibleFrame.height * 0.22).rounded(),
      width: size.width, height: size.height
    ).fitted(into: visibleFrame)
  }

  /// What ↩ would do with a text.
  public struct Answer: Equatable, Sendable {
    /// The command to run, or nil when the text will not do: the field stays open.
    public var command: Command?
    /// The line under the field.
    public var note: String
    /// The note says what is wrong with the text.
    public var isProblem = false

    public init(command: Command?, note: String, isProblem: Bool = false) {
      self.command = command
      self.note = note
      self.isProblem = isProblem
    }
  }

  /// A reply's words are a terminal's: they begin small and set commands in backticks. Under the field they are a sentence.
  public static func onScreen(_ reply: String) -> String {
    var words = ""
    for (place, part) in reply.split(separator: "`", omittingEmptySubsequences: false).enumerated() {
      words += place % 2 == 0 ? String(part) : "“\(part)”"
    }
    return words.prefix(1).uppercased() + words.dropFirst()
  }

  public func answer(to text: String) -> Answer {
    switch subject {
    case .space(_, let current, let contents, let others):
      guard text.contains(where: { !$0.isWhitespace && $0 != "/" }) else {
        guard let current else { return Answer(command: cancel, note: contents) }
        return Answer(command: .unname(nil), note: "↩ removes the name \(current)")
      }
      let name: String
      do {
        name = try SpaceName.tidied(text)
      } catch {
        return Answer(command: nil, note: Self.onScreen("\(error)"), isProblem: true)
      }
      if name == current { return Answer(command: cancel, note: contents) }
      // `others` leaves this space out, so its own name in other capitals is a plain renaming.
      if let other = SpaceName.exact(name, among: others.keys), let holds = others[other] {
        return Answer(command: .name(name), note: "↩ moves the name here from \(holds)")
      }
      return Answer(command: .name(name), note: "↩ names \(contents)")
    }
  }
}
