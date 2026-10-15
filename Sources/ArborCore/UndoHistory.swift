import CoreGraphics

/// One change to one display's arrangement that `undo` can take back.
///
/// Trees are values, so a step is simply the display's workspace as it was before the change.
public struct UndoStep: Equatable, Sendable {
  /// One change can touch two displays (a window dragged from one to the other). It is recorded
  /// as one step on each, and the steps share an id so they can be taken back together.
  public var id: Int
  /// What the change was, in the words of a command: `dock w101 left`.
  public var label: String
  /// The same in a word or two for a menu, which puts "Undo" or "Redo" before it: "Dock".
  public var title: String
  /// The workspace to go back to.
  public var workspace: Workspace
  /// Where the floating windows that were on screen then actually were. The workspace remembers
  /// where the user put each one, which is not always where it is: docked windows push them aside.
  public var frames: [WindowID: CGRect]
  /// The workspace just after the change. Whatever differs between it and the workspace at the time
  /// of the undo was done since (a camera move, a saved view), and is kept: see
  /// `Workspace.restored(over:since:)`.
  public var changedTo: Workspace
  /// Set while the change may still be going on (a seam being dragged): more of the same change,
  /// recorded under the same key, extends this step instead of adding one.
  public var continuation: String?
  /// A change that cannot be taken back (a docked window closed). It is kept so that `undo` can say so
  /// once, rather than reach past it to an older change as if that had been the last one.
  public var isIrreversible: Bool
  /// Who had the keyboard before the change, for a change that said who gets it (`side-by-side`): going back gives it back. Nil for
  /// all others, after which the keyboard stays where it is.
  public var keyboard: WindowID?

  public init(
    id: Int, label: String, title: String? = nil, workspace: Workspace, frames: [WindowID: CGRect] = [:],
    changedTo: Workspace, continuation: String? = nil, isIrreversible: Bool = false, keyboard: WindowID? = nil
  ) {
    self.id = id
    self.label = label
    self.title = title ?? Self.title(from: label)
    self.workspace = workspace
    self.frames = frames
    self.changedTo = changedTo
    self.continuation = continuation
    self.isIrreversible = isIrreversible
    self.keyboard = keyboard
  }
}

extension UndoStep {
  /// The first word of a label as a title: "Float All" from `float-all here`.
  public static func title(from label: String) -> String {
    (label.split(separator: " ").first ?? "").split(separator: "-")
      .map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
  }
}

/// The steps `undo` and `redo` walk through, kept per display. It only stores them: fitting an old
/// workspace to the windows that exist now is the controller's job (Controller+Undo.swift).
public struct UndoHistory: Equatable, Sendable {
  public enum Direction: Sendable {
    case undo, redo

    public var opposite: Direction { self == .undo ? .redo : .undo }
  }

  /// A display's workspace on either side of a change.
  public struct Change: Equatable, Sendable {
    public var before: Workspace
    /// See `UndoStep.frames`.
    public var framesBefore: [WindowID: CGRect]
    public var after: Workspace

    public init(before: Workspace, framesBefore: [WindowID: CGRect] = [:], after: Workspace) {
      self.before = before
      self.framesBefore = framesBefore
      self.after = after
    }
  }

  /// How many steps are kept per display and direction; the oldest are dropped first.
  public static let limit = 50

  private var undoSteps: [DisplayID: [UndoStep]] = [:]
  private var redoSteps: [DisplayID: [UndoStep]] = [:]
  private var nextID = 1
  /// Which windows have changed their number, oldest first, since `forgetRenumberings()`: for whoever holds a workspace
  /// from the past that is not a step yet.
  public private(set) var renumberings: [Renumbering] = []

  public struct Renumbering: Equatable, Sendable {
    public var old: WindowID
    public var new: WindowID
  }

  public init() {}

  public mutating func forgetRenumberings() { renumberings = [] }

  /// The steps on `display`, oldest first: the last one is the next to be taken.
  public func steps(_ direction: Direction, on display: DisplayID) -> [UndoStep] {
    (direction == .undo ? undoSteps : redoSteps)[display] ?? []
  }

  /// Records one change, given the workspace of every display it changed. Those displays can no
  /// longer redo: what they would go forward to was replaced by this change.
  ///
  /// With `key`, a change that follows another one recorded under the same key, with nothing in
  /// between, extends that step, until `finishContinuation` closes it.
  ///
  /// `keepingRedo` is for a change nobody asked for just now (a rule docked a new window): whoever has just
  /// undone something can still put it back.
  public mutating func record(
    _ label: String, title: String? = nil, changes: [DisplayID: Change], continuing key: String? = nil,
    keepingRedo: Bool = false, keyboard: WindowID? = nil
  ) {
    guard !changes.isEmpty else { return }
    if let key, changes.keys.allSatisfy({ undoSteps[$0]?.last?.continuation == key }) {
      for (display, change) in changes {
        undoSteps[display]![undoSteps[display]!.count - 1].changedTo = change.after
      }
      return
    }
    let id = nextID
    nextID += 1
    for (display, change) in changes {
      push(
        UndoStep(
          id: id, label: label, title: title, workspace: change.before, frames: change.framesBefore,
          changedTo: change.after, continuation: key, keyboard: keyboard),
        to: .undo, on: display)
      if !keepingRedo { redoSteps[display] = nil }
    }
  }

  /// Notes a change that cannot be taken back, given the workspace it left on every display it changed.
  /// Several in a row (an app quitting closes all its windows) count as one, the last. Redo is
  /// left alone: what it would put back is fitted to the windows that exist, like any step.
  public mutating func recordIrreversible(_ label: String, leaving workspaces: [DisplayID: Workspace]) {
    guard !workspaces.isEmpty else { return }
    let id = nextID
    nextID += 1
    for (display, workspace) in workspaces {
      if undoSteps[display]?.last?.isIrreversible == true { undoSteps[display]!.removeLast() }
      push(
        UndoStep(id: id, label: label, workspace: workspace, changedTo: workspace, isIrreversible: true),
        to: .undo, on: display)
    }
  }

  /// Closes the steps left open under `key` (every open step when nil), so the next change starts a new one.
  public mutating func finishContinuation(_ key: String? = nil) {
    for display in undoSteps.keys {
      for index in undoSteps[display]!.indices {
        guard let open = undoSteps[display]![index].continuation, key == nil || open == key else { continue }
        undoSteps[display]![index].continuation = nil
      }
    }
  }

  /// Removes and returns the newest step on `display`, keyed by display, together with the steps
  /// of the same change on other displays. Those come along only where they are the newest too: a
  /// display that has changed again since keeps its step until its own turn comes. Empty when
  /// there is nothing to take.
  public mutating func take(_ direction: Direction, on display: DisplayID) -> [DisplayID: UndoStep] {
    var stacks = direction == .undo ? undoSteps : redoSteps
    guard let step = stacks[display]?.popLast() else { return [:] }
    var taken = [display: step]
    for other in stacks.keys where other != display && stacks[other]?.last?.id == step.id {
      taken[other] = stacks[other]!.removeLast()
    }
    if direction == .undo { undoSteps = stacks } else { redoSteps = stacks }
    return taken
  }

  /// Adds a step as the newest on `display`. Unlike `record`, this leaves the other direction
  /// alone: it is how a step that was taken comes back as its opposite.
  public mutating func push(_ step: UndoStep, to direction: Direction, on display: DisplayID) {
    var steps = steps(direction, on: display)
    steps.append(step)
    if steps.count > Self.limit { steps.removeFirst(steps.count - Self.limit) }
    if direction == .undo { undoSteps[display] = steps } else { redoSteps[display] = steps }
  }

  /// `old` has become `new`, the same window under another number: every step goes on meaning that window.
  public mutating func renumber(_ old: WindowID, as new: WindowID) {
    func renumbered(_ steps: [UndoStep]) -> [UndoStep] {
      steps.map { step in
        var step = step
        step.workspace.renumber(old, as: new)
        step.changedTo.renumber(old, as: new)
        if let frame = step.frames.removeValue(forKey: old) { step.frames[new] = frame }
        if step.keyboard == old { step.keyboard = new }
        return step
      }
    }
    undoSteps = undoSteps.mapValues(renumbered)
    redoSteps = redoSteps.mapValues(renumbered)
    renumberings.append(Renumbering(old: old, new: new))
  }

  /// Forgets everything about a display (it was disconnected).
  public mutating func removeAll(on display: DisplayID) {
    undoSteps[display] = nil
    redoSteps[display] = nil
  }
}

extension Command {
  /// The command as text with the window it acts on spelled out, for telling the user what an
  /// undo took back: `dock left` with w101 focused is `dock w101 left`. `focused` is only asked for
  /// when the command leaves its window out (finding the focused window means asking its app).
  ///
  /// **No label holds part of a window's title or the name of a space.** Replies quote labels, replies are logged, and by
  /// the time of the undo the name may have been taken off, so that nothing could tell any more that the word was one.
  public func label(focused: @autoclosure () -> WindowID?) -> String {
    func w(_ window: WindowID?) -> String { (window ?? focused()).map { " \($0)" } ?? "" }
    switch self {
    case .dock(let window, let edge):
      return "dock" + w(window) + " \(edge.rawValue)"
    case .dockBeside(let window, let target, let edge):
      return "dock" + w(window) + " beside \(target) \(edge.rawValue)"
    case .float(let window):
      return "float" + w(window)
    case .toggleFloat(let window):
      return "toggle-float" + w(window)
    case .resize(let window, let edge, _):
      // Without the amount: several in a row become one step (`mergesWithRepeats`).
      return "resize" + w(window) + " \(edge.rawValue)"
    case .pin(let window):
      return "pin" + w(window)
    case .unpin(let window):
      return "unpin" + w(window)
    case .togglePin(let window):
      return "toggle-pin" + w(window)
    case .grow:
      return "grow" + w(nil)
    case .shrink:
      return "shrink" + w(nil)
    case .swap(let window, let direction):
      return "swap" + w(window) + " \(direction.directionWord)"
    case .moveToDisplay(let target, let window):
      return "move-to-display \(target.text)" + w(window)
    case .layout:
      return logText
    default:
      // By its first word alone: `name` and `unname`, which are steps when a group goes that only the name held
      // together (F62), and whatever else is made of such words.
      return Self.mayHoldPrivateWords(verb: verb) ? verb : textWithoutNames
    }
  }

  /// The command in a word or two, for "Undo …" in a menu. Nil where the first word of its text will do.
  public var undoTitle: String? {
    switch self {
    case .arrangeAll: "Arrange"
    case .pin, .togglePin: "Keep in View"
    case .sideBySide: "Dock Side by Side"
    default: nil
    }
  }

  /// Whether the same command again, straight away, goes on with one adjustment rather than making
  /// another change: a dozen taps on a shortcut that each move an edge a little are one resize.
  /// "The same" is judged by `label(focused:)`.
  public var mergesWithRepeats: Bool {
    switch self {
    case .resize, .grow, .shrink: true
    default: false
    }
  }
}
