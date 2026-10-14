import AppKit
import ArborCore
import SwiftUI

/// The welcome window (docs/features/F10-menu-bar-and-onboarding.md). Its first page says what Arbor does and
/// shows the permissions and macOS settings that matter, with whether each is in order; its second has
/// three moves to try, ticked off as the user makes them. It opens at launch while Accessibility
/// permission is missing, from Welcome… and Check Setup… in the menu, and when Arbor is opened again.
///
/// What it says, and when it turns the page, is decided by an `OnboardingSession`; this file lays the
/// session's model out, asks it to look at the Mac again once a second, and reports the buttons.
@MainActor
final class OnboardingWindow: NSObject, NSWindowDelegate {
  private var session: OnboardingSession?
  private let onButton: @MainActor (OnboardingModel.Row.ID) -> Void
  private let onAction: @MainActor (Command) -> CommandResult
  private let onLogin: @MainActor () -> Void
  private let icon = ArborArtwork.appIcon(side: 128)
  private let mark = ArborArtwork.menuBarIcon()
  private var window: NSPanel?
  private var content: NSHostingView<OnboardingView>?
  /// What the window last showed.
  private var shown: OnboardingModel?
  private var timer: Timer?
  /// It has gone to the side for the three moves, in this showing. From then on it stays where it is put.
  private var isAside = false

  /// - Parameters:
  ///   - onButton: a row's button was clicked.
  ///   - onAction: a row's button that runs a command of Arbor's was clicked.
  ///   - onLogin: the Open at Login box was clicked.
  init(
    controller: Controller, onButton: @escaping @MainActor (OnboardingModel.Row.ID) -> Void,
    onAction: @escaping @MainActor (Command) -> CommandResult, onLogin: @escaping @MainActor () -> Void
  ) {
    self.onButton = onButton
    self.onAction = onAction
    self.onLogin = onLogin
    super.init()
    session = OnboardingSession(controller: controller) { [weak self] _ in self?.render() }
  }

  /// Opens the window on `page`, or turns it to that page and brings it to the front.
  /// - Parameter page: nil for no page in particular: an open window stays as it is, a new one starts at the first.
  func show(_ page: OnboardingFlow.Page?) {
    guard let session else { return }
    let window = self.window ?? makeWindow(session)
    self.window = window
    if window.isVisible {
      if let page { session.go(to: page) }
    } else {
      session.begin(on: page ?? .permissions)
      isAside = false
      render()
      window.center()
      stepAside()
    }
    // In front of everything, without making Arbor the active app (see `makeWindow`).
    window.orderFrontRegardless()
    window.makeKey()
    startTimer()
  }

  /// A panel that does not activate Arbor, however it is opened or clicked. The moves on the second
  /// page act on the focused window, which is the focused window of the active app: were that Arbor,
  /// ⌃⌥↩ would find this window, which Arbor does not arrange, and do nothing.
  private func makeWindow(_ session: OnboardingSession) -> NSPanel {
    let content = ClickThroughHostingView(rootView: view(session.model))
    self.content = content
    let window = WelcomeWindow(
      contentRect: NSRect(origin: .zero, size: content.fittingSize),
      styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
    window.title = "Arbor"
    window.contentView = content
    window.hidesOnDeactivate = false
    window.isFloatingPanel = false
    // Left open on another of the macOS Spaces it still counts as visible, and would not come when called.
    window.collectionBehavior = [.moveToActiveSpace]
    // This object holds the window, and lets go of it after it has closed.
    window.isReleasedWhenClosed = false
    window.delegate = self
    return window
  }

  /// - Parameter rowsHeight: the height to give the rows of the first page, which then scroll. Nil lets them
  ///   take what they need.
  private func view(_ model: OnboardingModel, rowsHeight: CGFloat? = nil) -> OnboardingView {
    OnboardingView(
      model: model, icon: icon, mark: mark, rowsHeight: rowsHeight, onButton: onButton,
      onAction: { [weak self] command in
        guard let self else { return }
        self.session?.actionEnded(self.onAction(command))
      },
      onLogin: { [weak self] in
        self?.onLogin()
        self?.session?.refresh()
      },
      onPrimary: { [weak self] in
        if model.page == .permissions {
          self?.session?.go(to: .firstSteps)
        } else {
          self?.window?.close()
        }
      },
      onBack: { [weak self] in self?.session?.go(to: .permissions) })
  }

  /// Shows the session's model, and fits the window to it with its title bar staying where it is.
  private func render() {
    guard let session, let window, let content else { return }
    let model = session.model
    let old = window.frame
    let visible = (window.screen ?? NSScreen.main)?.visibleFrame
    // With much to say on a small display the rows scroll, so that the buttons below them stay in reach. Measured on
    // views of their own: the one on show is set once, or its scroll view would be made anew and jump back to the top
    // whenever a fact changes.
    var rowsHeight: CGFloat?
    if let visible {
      let available = visible.height - window.frameRect(forContentRect: .zero).height
      if height(of: view(model)) > available {
        // What everything but the rows takes, found by giving the rows a known height.
        let rest = height(of: view(model, rowsHeight: 100)) - 100
        rowsHeight = max(available - rest, 100)
      }
    }
    content.rootView = view(model, rowsHeight: rowsHeight)
    content.layoutSubtreeIfNeeded()
    var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: content.fittingSize))
    frame.origin = NSPoint(x: old.minX, y: old.maxY - frame.height)
    // Growing downward must not push the buttons under the Dock.
    if let visible, frame.minY < visible.minY { frame.origin.y = visible.minY }
    if frame != old { window.setFrame(frame, display: true) }
    // The moves are made in other apps' windows, one of which then fills the display: stay above them.
    window.level = model.page == .firstSteps ? .floating : .normal
    if window.isVisible { stepAside() }
    // Whoever has just put something right did it in System Settings, which lies over this window.
    if window.isVisible, let shown, model.isWorthComingForward(after: shown) { window.orderFrontRegardless() }
    shown = model
  }

  /// The first move is a drag to a screen edge, and most people take the left. So for the three moves the window waits at the
  /// right, where it covers neither that edge nor what docks there.
  private func stepAside() {
    guard !isAside, let window, session?.model.page == .firstSteps,
      let visible = (window.screen ?? NSScreen.main)?.visibleFrame
    else { return }
    isAside = true
    var frame = window.frame
    frame.origin.x = visible.maxX - frame.width - 24
    window.setFrame(frame, display: true)
  }

  private func height(of view: OnboardingView) -> CGFloat { NSHostingView(rootView: view).fittingSize.height }

  // MARK: Staying current

  private func startTimer() {
    guard timer == nil else { return }
    let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
      MainActor.assumeIsolated { self?.session?.refresh() }
    }
    // Common modes, so that it goes on while a menu is open or the window is dragged.
    RunLoop.main.add(timer, forMode: .common)
    self.timer = timer
  }

  func windowWillClose(_ notification: Notification) {
    timer?.invalidate()
    timer = nil
    session?.end()
    // After AppKit has finished closing it.
    DispatchQueue.main.async { [weak self] in self?.releaseClosedWindow() }
  }

  private func releaseClosedWindow() {
    guard let window, !window.isVisible else { return }  // opened again in the meantime
    window.delegate = nil
    window.contentView = nil
    self.window = nil
    content = nil
  }
}

/// Buttons answer the first click even while another window has the keyboard.
private final class ClickThroughHostingView<Content: View>: NSHostingView<Content> {
  override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// Arbor has no main menu to give ⌘W to its windows.
private final class WelcomeWindow: NSPanel {
  override func performKeyEquivalent(with event: NSEvent) -> Bool {
    if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
      event.charactersIgnoringModifiers == "w"
    {
      performClose(nil)
      return true
    }
    return super.performKeyEquivalent(with: event)
  }
}

struct OnboardingView: View {
  let model: OnboardingModel
  let icon: NSImage
  /// Arbor's mark as the menu bar shows it.
  let mark: NSImage
  let rowsHeight: CGFloat?
  let onButton: @MainActor (OnboardingModel.Row.ID) -> Void
  let onAction: @MainActor (Command) -> Void
  let onLogin: @MainActor () -> Void
  let onPrimary: @MainActor () -> Void
  let onBack: @MainActor () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      header
      if model.page == .permissions {
        if let rowsHeight {
          ScrollView { rows }
            .frame(height: rowsHeight)
        } else {
          rows
        }
      } else {
        steps
        waysBack
        loginBox
      }
      footer
    }
    .padding(24)
    .frame(width: 560)
  }

  private var header: some View {
    HStack(alignment: .center, spacing: 14) {
      Image(nsImage: icon)
        .resizable()
        .frame(width: 76, height: 76)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 4) {
        Text(model.title)
          .font(.title.bold())
        Text(model.summary)
          .foregroundStyle(.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
    }
  }

  // MARK: The first page

  private var rows: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(model.rows) { row in
        rowView(row)
        if row.id != model.rows.last?.id {
          Divider().padding(.leading, 46)
        }
      }
    }
    .modifier(Box())
  }

  private func rowView(_ row: OnboardingModel.Row) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: 10) {
      Image(systemName: symbol(for: row.state))
        .font(.system(size: 15))
        .foregroundStyle(colour(for: row.state))
        .frame(width: 24)
        .accessibilityLabel(row.status)
      VStack(alignment: .leading, spacing: 4) {
        // The button shares the title's line, so that the text below has the whole width.
        HStack(alignment: .firstTextBaseline, spacing: 6) {
          Text(row.title)
            .font(.headline)
          Text(row.importance)
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer(minLength: 8)
          if let action = row.action {
            // The one step has the place beside the title. The way to do it by hand comes last, under the text.
            Button(action.title) { onAction(action.command) }
              .buttonStyle(.borderedProminent)
          } else if let undo = row.undo {
            Button(undo.title) { onAction(undo.command) }
          } else if let title = row.button {
            if row.state == .required {
              Button(title) { onButton(row.id) }
                .buttonStyle(.borderedProminent)
            } else {
              Button(title) { onButton(row.id) }
            }
          }
        }
        if !row.detail.isEmpty {
          Text(row.detail)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(row.points, id: \.self) { point in
          HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("•")
              .foregroundStyle(.secondary)
            Text(point)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
        if !row.afterword.isEmpty {
          Text(row.afterword)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
        }
        if !row.failure.isEmpty {
          Text(row.failure)
            .font(.callout)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
        }
        if row.action != nil || row.undo != nil, !row.isSatisfied, let title = row.button {
          Button(title) { onButton(row.id) }
            .padding(.top, 2)
        }
        if !row.done.isEmpty {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.done)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            // Beside the title when that place is free.
            if row.action != nil, let undo = row.undo {
              Button(undo.title) { onAction(undo.command) }
            }
          }
        }
      }
    }
    .padding(12)
  }

  private func symbol(for state: OnboardingModel.Row.State) -> String {
    switch state {
    case .done: "checkmark.circle.fill"
    case .required: "exclamationmark.circle.fill"
    case .recommended: "exclamationmark.triangle.fill"
    case .optional: "circle"
    case .note: "info.circle"
    }
  }

  private func colour(for state: OnboardingModel.Row.State) -> Color {
    switch state {
    case .done: .green
    case .required: .red
    case .recommended: .orange
    case .optional, .note: .secondary
    }
  }

  // MARK: The second page

  private var steps: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(model.steps) { step in
        HStack(alignment: .firstTextBaseline, spacing: 10) {
          Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 15))
            .foregroundStyle(step.isDone ? Color.green : Color.secondary)
            .frame(width: 24)
            .accessibilityLabel(step.isDone ? "Done" : "Not done yet")
          VStack(alignment: .leading, spacing: 3) {
            Text(step.lead)
              .font(.headline)
            Text(step.text)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
          Spacer(minLength: 0)
        }
        .padding(12)
        if step.id != model.steps.last?.id {
          Divider().padding(.leading, 46)
        }
      }
    }
    .modifier(Box())
  }

  private var waysBack: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(model.waysBackTitle)
        .font(.headline)
      ForEach(model.waysBack, id: \.self) { way in
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text("•")
            .foregroundStyle(.secondary)
          Text(way)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.horizontal, 12)
  }

  /// A tick box in all but name: a real one wants a binding, and the state is macOS's, not this view's.
  @ViewBuilder private var loginBox: some View {
    if let isOn = model.opensAtLogin {
      Button {
        onLogin()
      } label: {
        Label(model.loginTitle, systemImage: isOn ? "checkmark.square.fill" : "square")
      }
      .buttonStyle(.plain)
      .padding(.horizontal, 12)
      .accessibilityValue(isOn ? "On" : "Off")
    }
  }

  // MARK: Both

  private var footer: some View {
    HStack(alignment: .center, spacing: 10) {
      if model.footnoteShowsMark {
        Image(nsImage: mark)
          .renderingMode(.template)
          .foregroundStyle(.secondary)
          .accessibilityHidden(true)
      }
      Text(model.footnote)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 12)
      if let back = model.backButton {
        Button(back) { onBack() }
      }
      Button(model.primaryButton) { onPrimary() }
        .keyboardShortcut(.defaultAction)
        .disabled(!model.isPrimaryEnabled)
    }
  }
}

/// The faintly shaded box with a hairline around it that groups rows, as in System Settings.
private struct Box: ViewModifier {
  func body(content: Content) -> some View {
    content
      .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.035)))
      .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.primary.opacity(0.08), lineWidth: 1))
  }
}
