import ArborCore
import Foundation
import SwiftUI

// The settings window's frame and the panes made from the schema. Each view draws what
// `SettingsPanelModel` says and calls one of its methods; none decides anything. They are kept small, with
// explicit types, because SwiftUI's errors are expensive where no compiler is at hand. The accessibility identifiers
// are for scripts, which find a control by them (scripts/mac-shell/shots-F12.sh): a setting's key, with `.slider` or
// `.field` where a setting has two controls.

struct SettingsRootView: View {
  @ObservedObject var store: SettingsPanelStore

  var body: some View {
    HStack(spacing: 0) {
      SettingsSidebar(store: store)
        .frame(width: 200)
      Divider()
      SettingsDetail(store: store)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    // The ideal size is said outright: a window takes its size from what it hosts, and a form's own ideal height is that
    // of everything in it, forty shortcuts, say.
    .frame(minWidth: 720, idealWidth: 780, maxWidth: .infinity, minHeight: 440, idealHeight: 540, maxHeight: .infinity)
  }
}

struct SettingsSidebar: View {
  @ObservedObject var store: SettingsPanelStore

  var body: some View {
    VStack(spacing: 0) {
      TextField("Search", text: search)
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("search")
        .accessibilityLabel("Search the settings")
        .padding(10)
      List(selection: selection) {
        ForEach(store.model.panes) { pane in
          Label(pane.title, systemImage: pane.symbol)
            .tag(pane)
            .accessibilityIdentifier("pane.\(pane.word)")
        }
      }
      .listStyle(.sidebar)
      // The list's own background is a shade lighter than the window's in the dark look, where the field above it
      // and the line below it then stood on darker strips.
      .scrollContentBackground(.hidden)
      Text(store.model.version)
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(8)
    }
  }

  private var search: Binding<String> {
    Binding<String>(
      get: { @MainActor in store.model.search },
      set: { @MainActor new in store.model.search = new })
  }

  /// Nothing is selected during a search; choosing a pane ends it.
  private var selection: Binding<SettingsPanelModel.Pane?> {
    Binding<SettingsPanelModel.Pane?>(
      get: { @MainActor in store.model.isSearching ? nil : store.model.pane },
      set: { @MainActor pane in
        if let pane { store.model.go(to: pane) }
      })
  }
}

struct SettingsDetail: View {
  @ObservedObject var store: SettingsPanelStore

  var body: some View {
    VStack(spacing: 0) {
      SettingsFileBanner(store: store)
      pane
    }
  }

  @ViewBuilder private var pane: some View {
    if store.model.isSearching {
      SettingsSearchResults(store: store)
    } else {
      switch store.model.pane {
      case .section(let section): SettingsSectionPane(store: store, section: section)
      case .shortcuts: ShortcutsPane(store: store)
      case .rules: RulesPane(store: store)
      }
    }
  }
}

/// What is wrong with settings.json, above everything else.
struct SettingsFileBanner: View {
  @ObservedObject var store: SettingsPanelStore

  var body: some View {
    if let problem = store.model.fileProblem {
      VStack(alignment: .leading, spacing: 6) {
        Text("settings.json cannot be read")
          .font(.headline)
        Text("\(problem). Arbor keeps the settings it had, and changes nothing until the file is mended.")
          .fixedSize(horizontal: false, vertical: true)
        if store.model.question == .replaceFile {
          SettingsQuestionView(store: store, question: .replaceFile)
        } else {
          HStack {
            Button("Open the File") { store.openFile() }
            Button("Replace It with the Defaults…") { store.model.replaceFileWithDefaults() }
          }
        }
        SettingsErrorText(text: store.model.errors["file"])
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.orange.opacity(0.2))
    } else if !store.model.valueProblems.isEmpty {
      VStack(alignment: .leading, spacing: 4) {
        Text("Some values in settings.json could not be used as written")
          .font(.headline)
        // By their place: two lines can say the same.
        ForEach(Array(store.model.valueProblems.enumerated()), id: \.offset) { _, line in
          Text(line)
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
      .padding(12)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.yellow.opacity(0.15))
    }
  }
}

/// What the window asks before it does what cannot be taken back, in the place of the button that was clicked.
struct SettingsQuestionView: View {
  @ObservedObject var store: SettingsPanelStore
  let question: SettingsPanelModel.Question

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(question.text)
        .fixedSize(horizontal: false, vertical: true)
      HStack {
        Button(question.confirmation) { store.model.answer(yes: true) }
          .accessibilityIdentifier("question.yes")
        Button("Cancel") { store.model.answer(yes: false) }
          .accessibilityIdentifier("question.no")
      }
    }
  }
}

/// Why a change was refused, under the control it was made with.
struct SettingsErrorText: View {
  let text: String?

  var body: some View {
    if let text {
      Text(text)
        .font(.caption)
        .foregroundStyle(.red)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

/// A list of things in settings.json that could not be used, under a pane's own content.
struct SettingsProblemList: View {
  let title: String
  let lines: [String]

  var body: some View {
    if !lines.isEmpty {
      Section(title) {
        ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
          Text(line)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
  }
}

// MARK: A section of the schema

struct SettingsSectionPane: View {
  @ObservedObject var store: SettingsPanelStore
  let section: SettingsSection

  var body: some View {
    VStack(spacing: 0) {
      form
      // Under the form and not in it: there it was a card of its own, empty but for a button mostly greyed out.
      if store.model.canRestoreDefaults(in: section) {
        Divider()
        HStack {
          SettingsErrorText(text: store.model.errors[SettingsPanelModel.Pane.section(section).id])
          Spacer()
          Button("Restore Defaults") { store.model.restoreDefaults(in: section) }
            .disabled(store.model.changedKeys(in: section).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
      }
    }
  }

  private var form: some View {
    Form {
      if hasLoginItem || !store.model.rows(in: section).isEmpty {
        Section {
          if hasLoginItem {
            LoginItemRow(store: store)
          }
          ForEach(store.model.rows(in: section)) { row in
            SettingRowView(store: store, row: row)
          }
        }
      }
      if !store.model.advancedRows(in: section).isEmpty {
        Section {
          DisclosureGroup(isExpanded: advanced) {
            // What is behind a group is no row of the form. Left to itself it has neither the lines between rows nor their
            // room, and what is narrower than the form, a list of apps, stands in the middle.
            VStack(alignment: .leading, spacing: 0) {
              ForEach(store.model.advancedRows(in: section)) { row in
                Divider()
                SettingRowView(store: store, row: row)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.vertical, 9)
              }
            }
            .padding(.top, 8)
          } label: {
            // By itself only the triangle opens the group: seven points of a line that looks like a button.
            Text("Advanced")
              .frame(maxWidth: .infinity, alignment: .leading)
              .contentShape(Rectangle())
              .onTapGesture { advanced.wrappedValue.toggle() }
          }
        }
      }
    }
    .formStyle(.grouped)
  }

  private var hasLoginItem: Bool { section == .general && store.model.hasLoginItem }

  private var advanced: Binding<Bool> {
    Binding<Bool>(
      get: { @MainActor in store.model.openAdvanced.contains(section) },
      set: { @MainActor new in store.model.setAdvanced(new, in: section) })
  }
}

struct SettingsSearchResults: View {
  @ObservedObject var store: SettingsPanelStore

  var body: some View {
    Form {
      if store.model.found.isEmpty {
        Text("No setting matches “\(store.model.search)”.")
          .foregroundStyle(.secondary)
      }
      ForEach(store.model.found.sections) { found in
        Section(found.section.title) {
          ForEach(found.rows) { row in
            SettingRowView(store: store, row: row)
          }
        }
      }
      if !store.model.found.shortcuts.isEmpty {
        Section("Shortcuts") {
          ForEach(store.model.found.shortcuts) { row in
            ShortcutRowView(store: store, row: row)
          }
        }
      }
      if !store.model.found.panes.isEmpty {
        Section {
          ForEach(store.model.found.panes) { pane in
            Button {
              store.model.go(to: pane)
            } label: {
              Label(pane.title, systemImage: pane.symbol)
            }
            .buttonStyle(.link)
          }
        }
      }
    }
    .formStyle(.grouped)
  }
}

struct LoginItemRow: View {
  @ObservedObject var store: SettingsPanelStore

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Toggle(isOn: isOn) {
        SettingLabel(label: "Open at Login", help: "Start Arbor whenever you log in to this Mac.")
      }
      .accessibilityIdentifier("login")
      SettingsErrorText(text: store.model.errors["login"])
      if store.model.loginItemNeedsApproval {
        Button("Open Login Items…") { store.openLoginItems() }
          .controlSize(.small)
      }
    }
  }

  private var isOn: Binding<Bool> {
    Binding<Bool>(
      get: { @MainActor in store.model.opensAtLogin },
      set: { @MainActor new in store.model.setOpensAtLogin(new) })
  }
}

// MARK: One setting

struct SettingLabel: View {
  let label: String
  let help: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label)
      Text(help)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
    }
  }
}

struct SettingRowView: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.Row

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      control
      SettingsErrorText(text: row.error)
    }
  }

  @ViewBuilder private var control: some View {
    switch row.control {
    case .toggle(let isOn):
      ToggleSettingRow(store: store, row: row, isOn: isOn)
    case .number(let value, let range, let step, let unit):
      NumberSettingRow(store: store, row: row, value: value, range: range, step: step, unit: unit)
    case .choice(let value, let choices):
      ChoiceSettingRow(store: store, row: row, value: value, choices: choices)
    case .text(let value, let example):
      TextSettingRow(store: store, row: row, value: value, example: example)
    case .apps(let listed, let candidates):
      AppListRow(store: store, row: row, listed: listed, candidates: candidates)
    case .list(let summary):
      ListSettingRow(store: store, row: row, summary: summary)
    }
  }
}

struct ToggleSettingRow: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.Row
  let isOn: Bool

  var body: some View {
    Toggle(isOn: binding) {
      SettingLabel(label: row.label, help: row.help)
    }
    .accessibilityIdentifier(row.key)
  }

  private var binding: Binding<Bool> {
    Binding<Bool>(get: { @MainActor in isOn }, set: { @MainActor new in store.model.set(row.key, to: new) })
  }
}

/// A slider and a field. The slider changes the setting when it is let go of, not on the way: every
/// change moves real windows and writes a file.
struct NumberSettingRow: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.Row
  let value: Double
  let range: ClosedRange<Double>
  let step: Double
  let unit: String
  /// Where the slider is while it is held.
  @State private var held: Double?
  @State private var isHeld = false
  /// The number is about to change by what was typed here.
  @State private var changedByTheField = false
  @FocusState private var fieldIsFocused: Bool

  var body: some View {
    LabeledContent {
      HStack(spacing: 8) {
        Slider(value: slider, in: range, onEditingChanged: { isHeld in sliderChanged(isHeld) })
          .frame(width: 150)
          .accessibilityIdentifier("\(row.key).slider")
          .accessibilityLabel(row.label)
        TextField("", text: field)
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
          .multilineTextAlignment(.trailing)
          .frame(width: 60)
          .accessibilityIdentifier("\(row.key).field")
          .accessibilityLabel(unit.isEmpty ? row.label : "\(row.label), \(unit)")
          .focused($fieldIsFocused)
          .onSubmit { commitField() }
          .onChange(of: fieldIsFocused) {
            if !fieldIsFocused { commitField() }
          }
          // Beside a slider at 86 a field that had the keyboard went on saying 40. The model no longer takes for typing what
          // a field merely says again; and should a field with the keyboard not take what it is told to show, it gives the
          // keyboard up when its number changes by another hand: the slider's (below) or somebody's outside the
          // window. After its own Return it keeps it, so that Tab goes on from there.
          .onChange(of: value) {
            if !changedByTheField, store.model.draft(in: .setting(row.key)) == nil { fieldIsFocused = false }
            changedByTheField = false
          }
        // As wide as the widest unit, so that the fields of a pane stand in one column.
        Text(unit)
          .foregroundStyle(.secondary)
          .frame(width: 26, alignment: .leading)
      }
    } label: {
      SettingLabel(label: row.label, help: row.help)
    }
  }

  /// Moved by anything but a drag (arrow keys, VoiceOver) there is no letting go to wait for.
  private var slider: Binding<Double> {
    Binding<Double>(
      get: { @MainActor in held ?? value },
      set: { @MainActor moved in
        if isHeld { held = moved } else { store.model.set(row.key, to: moved) }
      })
  }

  private func sliderChanged(_ isHeldNow: Bool) {
    isHeld = isHeldNow
    if isHeldNow {
      // In this order: a field that loses the keyboard hands over what was typed, and the windows would move for it.
      store.model.forget(.setting(row.key))
      fieldIsFocused = false
    }
    guard !isHeldNow, let final = held else { return }
    held = nil
    store.model.set(row.key, to: final)
  }

  private var field: Binding<String> {
    Binding<String>(
      get: { @MainActor in store.model.draft(in: .setting(row.key)) ?? shownNumber },
      set: { @MainActor new in
        // What the field says while the slider is held is what the slider gave it to show.
        if !isHeld { store.model.type(new, into: .setting(row.key)) }
      })
  }

  /// The field follows the slider while it moves.
  private var shownNumber: String {
    SettingsPanelModel.text(held.map { SettingsPanelModel.snapped($0, in: range, step: step) } ?? value)
  }

  private func commitField() { changedByTheField = store.model.handOver(.setting(row.key)) }
}

struct ChoiceSettingRow: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.Row
  let value: String
  let choices: [SettingEntry.Choice]

  var body: some View {
    Picker(selection: binding) {
      ForEach(choices, id: \.value) { choice in
        Text(choice.label)
          .tag(choice.value)
      }
    } label: {
      SettingLabel(label: row.label, help: row.help)
    }
    .accessibilityIdentifier(row.key)
  }

  private var binding: Binding<String> {
    Binding<String>(
      get: { @MainActor in value },
      set: { @MainActor new in store.model.set(row.key, to: new) })
  }
}

struct TextSettingRow: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.Row
  let value: String
  let example: String
  /// The text is about to change by what was typed here.
  @State private var changedByTheField = false
  @FocusState private var isFocused: Bool

  var body: some View {
    LabeledContent {
      TextField("", text: binding, prompt: Text(example))
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .frame(width: 160)
        .accessibilityIdentifier("\(row.key).field")
        .accessibilityLabel(row.label)
        .focused($isFocused)
        .onSubmit { commit() }
        .onChange(of: isFocused) {
          if !isFocused { commit() }
        }
        // As a number's field does (above).
        .onChange(of: value) {
          if !changedByTheField, store.model.draft(in: .setting(row.key)) == nil { isFocused = false }
          changedByTheField = false
        }
    } label: {
      SettingLabel(label: row.label, help: row.help)
    }
  }

  private var binding: Binding<String> {
    Binding<String>(
      get: { @MainActor in store.model.draft(in: .setting(row.key)) ?? value },
      set: { @MainActor new in store.model.type(new, into: .setting(row.key)) })
  }

  private func commit() { changedByTheField = store.model.handOver(.setting(row.key)) }
}

/// A list the window has no editor for.
struct ListSettingRow: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.Row
  let summary: String

  var body: some View {
    LabeledContent {
      HStack(spacing: 8) {
        Text(summary)
          .foregroundStyle(.secondary)
        Button("Open the File") { store.openFile() }
          .controlSize(.small)
      }
    } label: {
      SettingLabel(label: row.label, help: row.help)
    }
    .accessibilityIdentifier(row.key)
  }
}
