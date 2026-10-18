import AppKit
import ArborCore
import CoreGraphics

/// Shows the field a name is typed into (`NamePromptModel`): one panel, on whichever display's scene has it.
@MainActor
final class NameField {
  private var panel: NamePanel?
  private var showingOn: DisplayID?

  func update(display: DisplayID, model: NamePromptModel?, actions: (any OverlayActions)?) {
    guard let model else {
      // Other displays' scenes have no field either, and must not close this one's.
      if showingOn == display { removeAll() }
      return
    }
    let panel = self.panel ?? NamePanel()
    self.panel = panel
    showingOn = display
    panel.run = { [weak actions] command in actions?.perform(command) }
    panel.show(model)
  }

  func removeAll() {
    showingOn = nil
    panel?.hide()
  }
}

/// A title, a field and a line of text. What they say, and what ↩ and ⎋ do, is the model's business.
///
/// Unlike Arbor's other panels this one takes the keyboard. It does so without making Arbor the active
/// app (`.nonactivatingPanel`), so the app in front stays in front, its window stays the focused window as
/// far as Accessibility can tell, and the keyboard returns to it when the panel goes.
final class NamePanel: OverlayPanel, NSTextFieldDelegate {
  var run: ((Command) -> CommandResult?)?
  /// Nil while the panel is hidden.
  private var model: NamePromptModel?
  private let titleLabel = NSTextField(labelWithString: "")
  private let field = NSTextField(string: "")
  private let noteLabel = NSTextField(labelWithString: "")
  /// Watches for clicks and key presses that go to other apps while the field is open.
  private var clickMonitor: Any?
  private let sightWatcher = SightWatcher()

  override init() {
    super.init()
    level = .modalPanel
    hasShadow = true
    ignoresMouseEvents = false
    collectionBehavior = [.ignoresCycle, .transient, .fullScreenAuxiliary]

    let background = PanelGround()
    contentView = background

    titleLabel.font = .systemFont(ofSize: 11, weight: .semibold)
    titleLabel.textColor = PanelInk.second
    field.font = .systemFont(ofSize: 20)
    field.isBordered = false
    field.isBezeled = false
    field.drawsBackground = false
    field.focusRingType = .none
    field.usesSingleLineMode = true
    field.lineBreakMode = .byTruncatingTail
    field.cell?.isScrollable = true
    field.textColor = PanelInk.main
    field.placeholderAttributedString = NSAttributedString(
      string: "Name", attributes: [.font: NSFont.systemFont(ofSize: 20), .foregroundColor: PanelInk.second])
    field.delegate = self
    noteLabel.font = .systemFont(ofSize: 11)
    noteLabel.lineBreakMode = .byTruncatingTail
    for view in [titleLabel, field, noteLabel] { background.addSubview(view) }
  }

  override var canBecomeKey: Bool { true }

  func show(_ new: NamePromptModel) {
    let wasHidden = model == nil
    model = new
    titleLabel.stringValue = new.title
    setFrame(ScreenGeometry.appKit(fromGlobal: new.frame), display: true)
    invalidateShadow()  // the shadow of a transparent window is shaped by what was last drawn
    // From the top: 12, the title, 6, the field, 6, the note. AppKit counts from the bottom.
    let (width, height) = (new.frame.width - 32, new.frame.height)
    titleLabel.frame = NSRect(x: 16, y: height - 28, width: width, height: 16)
    field.frame = NSRect(x: 16, y: height - 62, width: width, height: 28)
    noteLabel.frame = NSRect(x: 16, y: height - 84, width: width, height: 16)
    if wasHidden {
      // What has been typed stays when the model changes under an open field.
      field.stringValue = new.initial
      sightWatcher.begin(for: self) { [weak self] cause in
        Log.debug("the name field is put away by \(cause)")
        self?.cancel()
      }
      orderFrontRegardless()
      makeKey()
      field.selectText(nil)
      // `resignKey` should cover the clicks, but a field left on screen that no click puts away would be worse than
      // one that is closed twice, and the second time does nothing. A key press reaches another app only if macOS did
      // not give the field the keyboard (secure text entry does that): then it must not sit there looking as if it had.
      // The key that opened the field may still be down and repeating.
      clickMonitor = NSEvent.addGlobalMonitorForEvents(
        matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown]
      ) { [weak self] event in
        let isRepeat = event.type == .keyDown && event.isARepeat
        MainActor.assumeIsolated {
          guard let self, !isRepeat else { return }
          self.cancel()
        }
      }
    }
    showNote()
  }

  func hide() {
    // First, so that losing the keyboard by being hidden is not taken for a click elsewhere.
    model = nil
    if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
    clickMonitor = nil
    sightWatcher.end()
    orderOut(nil)
  }

  private func showNote(_ problem: String? = nil) {
    guard let model else { return }
    let answer = model.answer(to: field.stringValue)
    noteLabel.stringValue = problem ?? answer.note
    // What is wrong is said louder, not redder: red stood out by 2 to 1 over a red window, and by 3 at best.
    let isProblem = problem != nil || answer.isProblem
    noteLabel.textColor = isProblem ? PanelInk.main : PanelInk.second
    noteLabel.font = .systemFont(ofSize: 11, weight: isProblem ? .semibold : .regular)
  }

  private func submit() {
    guard let model else { return }
    guard let command = model.answer(to: field.stringValue).command else {
      NSSound.beep()
      return
    }
    // A command that succeeds closes the field by way of the next scene.
    if let result = run?(command), !result.ok {
      NSSound.beep()
      showNote(result.message)
    }
  }

  private func cancel() {
    guard let model else { return }
    _ = run?(model.cancel)
    // The next scene has closed the field by now. Should it ever not, a field that has been left must not stay up.
    if self.model != nil { hide() }
  }

  // MARK: The keyboard

  func controlTextDidChange(_ notification: Notification) { showNote() }

  func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
    if selector == #selector(NSResponder.insertNewline(_:)) {
      submit()
      return true
    }
    if selector == #selector(NSResponder.cancelOperation(_:)) {
      cancel()
      return true
    }
    return false
  }

  /// ⌘A, ⌘X, ⌘C and ⌘V are an Edit menu's work in other apps; Arbor has no menu bar.
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    guard event.type == .keyDown,
      event.modifierFlags.intersection([.command, .option, .control, .shift]) == .command,
      let key = event.charactersIgnoringModifiers, let editor = field.currentEditor()
    else { return super.performKeyEquivalent(with: event) }
    switch key {
    case "a": editor.selectAll(nil)
    case "x": editor.cut(nil)
    case "c": editor.copy(nil)
    case "v": editor.paste(nil)
    default: return super.performKeyEquivalent(with: event)
    }
    return true
  }

  /// A click in another window takes the keyboard away: the field has been left.
  override func resignKey() {
    super.resignKey()
    cancel()
  }
}
