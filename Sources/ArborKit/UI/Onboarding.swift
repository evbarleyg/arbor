import AppKit
import ArborCore
import SwiftUI

/// The welcome window (docs/features/F10-menu-bar-and-onboarding.md). Its first page says what Arbor does and
/// shows the permissions and macOS settings that matter, with whether each is in order; its second has
/// four moves to try, ticked off as the user makes them. It opens at launch while Accessibility
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
  /// Somebody has taken hold of it during the moves, in this showing: from then on it stays where it is put.
  private var staysPut = false
  /// Where it is gliding to.
  private var destination: NSRect?

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
      staysPut = false
      shown = nil
      render()
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

  /// Shows the session's model, fits the window to it and puts it where `OnboardingModel.placement` says.
  private func render() {
    guard let session, let window, let content else { return }
    let model = session.model
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
    let size = window.frameRect(forContentRect: NSRect(origin: .zero, size: content.fittingSize)).size
    if let visible {
      let placement = OnboardingModel.placement(
        page: model.page, previous: shown?.page, staysPut: staysPut, old: ScreenGeometry.global(fromAppKit: destination ?? window.frame),
        size: size, visible: ScreenGeometry.global(fromAppKit: visible), desktops: model.desktops)
      move(window, to: ScreenGeometry.appKit(fromGlobal: placement.frame), gliding: placement.glides)
    } else {
      window.setContentSize(content.fittingSize)
    }
    // The moves are made in other apps' windows, one of which then fills the display: stay above them.
    window.level = model.page == .firstSteps ? .floating : .normal
    // Whoever has just put something right did it in System Settings, which lies over this window.
    if window.isVisible, let shown, model.isWorthComingForward(after: shown) { window.orderFrontRegardless() }
    shown = model
  }

  private func move(_ window: NSWindow, to frame: NSRect, gliding: Bool) {
    guard frame != destination ?? window.frame else { return }
    let glides = gliding && window.isVisible && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    if !glides {
      endGlide(window)
      window.setFrame(frame, display: true)
      return
    }
    // Through the animator, not `setFrame(_:display:animate:)`, which holds the main thread for as long as the window is under way.
    destination = frame
    NSAnimationContext.runAnimationGroup(
      { context in
        context.duration = 0.25
        window.animator().setFrame(frame, display: true)
      },
      completionHandler: { [weak self] in
        MainActor.assumeIsolated {
          if self?.destination == frame { self?.destination = nil }
        }
      })
  }

  /// Where it is now, it stays: an animation of no length replaces the one under way.
  private func endGlide(_ window: NSWindow) {
    guard destination != nil else { return }
    destination = nil
    NSAnimationContext.runAnimationGroup { context in
      context.duration = 0
      window.animator().setFrame(window.frame, display: false)
    }
  }

  /// Sent when somebody takes hold of the window, not when it moves itself. On the first page that says nothing about the moves.
  func windowWillMove(_ notification: Notification) {
    guard session?.model.page == .firstSteps, let window else { return }
    staysPut = true
    // Not out of their hand.
    endGlide(window)
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
    VStack(alignment: .leading, spacing: isCompact ? 12 : 20) {
      header
      if model.page == .permissions {
        if let rowsHeight {
          ScrollView { rows }
            .frame(height: rowsHeight)
        } else {
          rows
        }
      } else {
        if !model.keysLegend.isEmpty {
          Text(model.keysLegend)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, -6)
        }
        steps
        offer
        waysBack
        loginBox
      }
      footer
    }
    .padding(isCompact ? 16 : 24)
    .frame(width: OnboardingModel.width(of: model.page))
  }

  /// For the moves: the window lies over the windows they are made on.
  private var isCompact: Bool { model.page == .firstSteps }

  private var header: some View {
    HStack(alignment: .center, spacing: isCompact ? 10 : 14) {
      Image(nsImage: icon)
        .resizable()
        .frame(width: isCompact ? 36 : 76, height: isCompact ? 36 : 76)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: isCompact ? 1 : 4) {
        Text(model.title)
          .font(isCompact ? .title3.bold() : .title.bold())
        Text(model.summary)
          .font(isCompact ? .caption : .body)
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
          if row.action != nil {
            // Its buttons come under the text that says what they are for.
          } else if row.isSatisfied, let undo = row.undo {
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
        if let action = row.action {
          // The one step, and beside it the way to do the same by hand.
          HStack(spacing: 8) {
            Button(action.title) { onAction(action.command) }
              .buttonStyle(.borderedProminent)
            if let title = row.button {
              // A link, so that there is one button to decide about.
              Button(title) { onButton(row.id) }
                .buttonStyle(.link)
            }
          }
          .padding(.vertical, 4)
        }
        if !row.afterword.isEmpty {
          Text(row.afterword)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !row.failure.isEmpty {
          Text(row.failure)
            .font(.callout)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
        }
        if !row.done.isEmpty {
          HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(row.done)
              .font(.callout)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
            // Beside the title when the row is in order and that place is free.
            if !row.isSatisfied, let undo = row.undo {
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
    // The next thing to do, not something that has gone wrong: it is the first thing a newcomer sees.
    case .required: "arrow.right.circle.fill"
    // A suggestion. A warning sign beside "Recommended" reads as if the Mac had a fault.
    case .recommended: "lightbulb.fill"
    case .optional: "circle"
    case .note: "info.circle"
    }
  }

  private func colour(for state: OnboardingModel.Row.State) -> Color {
    switch state {
    case .done: .green
    case .required: .accentColor
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
              .foregroundStyle(step.isDone ? Color.secondary : Color.primary)
              .fixedSize(horizontal: false, vertical: true)
            if step.isNext {
              Text(step.text)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
          }
          Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        if step.id != model.steps.last?.id {
          Divider().padding(.leading, 46)
        }
      }
    }
    .modifier(Box())
  }

  @ViewBuilder private var offer: some View {
    if let offer = model.offer {
      VStack(alignment: .leading, spacing: 4) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(offer.text)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
          Spacer(minLength: 0)
          Button(offer.action.title) { onAction(offer.action.command) }
        }
        if !offer.failure.isEmpty {
          Text(offer.failure)
            .font(.callout)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(.horizontal, 12)
    }
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
