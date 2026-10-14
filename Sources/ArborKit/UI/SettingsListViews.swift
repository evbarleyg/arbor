import ArborCore
import Foundation
import SwiftUI

// The two panes of the settings window that edit a list, shortcuts and rules, and the line of a list of apps. As in SettingsViews.swift, each view draws what `SettingsPanelModel` says and calls its methods.

// MARK: Shortcuts

struct ShortcutsPane: View {
  @ObservedObject var store: SettingsPanelStore
  @State private var commandText: String = ""

  var body: some View {
    Form {
      if store.model.shortcutsAreOff {
        Section {
          Text("Keyboard shortcuts are switched off (General → Use keyboard shortcuts).")
            .foregroundStyle(.secondary)
        }
      }
      if let map = store.model.shortcutsMapRow {
        Section {
          SettingRowView(store: store, row: map)
        }
      }
      ForEach(store.model.shortcutSections) { section in
        Section(section.title) {
          ForEach(section.rows) { row in
            ShortcutRowView(store: store, row: row)
          }
        }
      }
      Section("A shortcut for another command") {
        newShortcut
      }
      SettingsProblemList(title: "Entries in settings.json that could not be used", lines: store.model.shortcutProblems)
      Section {
        if let question = store.model.question, question != .replaceFile {
          SettingsQuestionView(store: store, question: question)
        } else {
          HStack {
            Spacer()
            Button("Restore All Shortcuts…") { store.model.restoreAllShortcuts() }
              .disabled(!store.model.shortcutsAreChanged)
          }
        }
      }
    }
    .formStyle(.grouped)
  }

  private var newShortcut: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        TextField("", text: $commandText, prompt: Text("a command, such as dock left or set gap 0"))
          .labelsHidden()
          .textFieldStyle(.roundedBorder)
          .font(.system(.body, design: .monospaced))
          .accessibilityIdentifier("new-shortcut.field")
          .accessibilityLabel("A command to give a shortcut to")
        Button(isRecordingNew ? "Press the keys…" : "Record Shortcut") {
          if isRecordingNew {
            store.model.cancelRecording()
          } else {
            store.model.startRecording(commandText: commandText)
          }
        }
        .disabled(commandText.isEmpty)
      }
      if let clash = store.model.clash, clash.row.isNew {
        ShortcutClashView(store: store, clash: clash)
      }
      SettingsErrorText(text: store.model.errors[SettingsPanelModel.Pane.shortcuts.id])
    }
  }

  private var isRecordingNew: Bool { store.model.recording?.isNew == true }
}

struct ShortcutRowView: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.ShortcutRow

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 8) {
        // What a script or settings.json calls it goes small under what people call it.
        VStack(alignment: .leading, spacing: 2) {
          Text(row.title)
          Text(row.command.text)
            .font(.system(.caption, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        Spacer()
        Button {
          if isRecording {
            store.model.cancelRecording()
          } else {
            store.model.startRecording(row)
          }
        } label: {
          Text(keysTitle)
            .frame(minWidth: 110)
        }
        .help("Click, then press the new keys. Escape cancels.")
        .accessibilityIdentifier("record.\(row.command.text)")
        .accessibilityLabel("Shortcut for \(row.title): \(keysTitle)")
        Button {
          store.model.removeShortcut(row)
        } label: {
          Image(systemName: "minus.circle")
        }
        .buttonStyle(.borderless)
        .disabled(row.chord == nil)
        .help("Remove the shortcut")
        .accessibilityIdentifier("remove.\(row.command.text)")
        .accessibilityLabel("Remove the shortcut for \(row.title)")
        Button {
          store.model.restoreShortcut(row)
        } label: {
          Image(systemName: "arrow.uturn.backward.circle")
        }
        .buttonStyle(.borderless)
        .disabled(!row.isChanged)
        .help(row.standard == nil ? "Remove the shortcut" : "Back to the default")
        .accessibilityIdentifier("restore.\(row.command.text)")
        .accessibilityLabel("Restore the shortcut for \(row.title)")
      }
      if let clash = store.model.clash, clash.row == row {
        ShortcutClashView(store: store, clash: clash)
      }
      if let caution = row.caution {
        Text("Mind that \(caution).")
          .font(.caption)
          .foregroundStyle(.orange)
          .fixedSize(horizontal: false, vertical: true)
      }
      SettingsErrorText(text: store.model.errors[row.id])
    }
  }

  private var isRecording: Bool { store.model.recording == row }

  private var keysTitle: String {
    if isRecording { return "Press the keys…" }
    return row.label ?? "None"
  }
}

/// The keys just pressed belong to another command.
struct ShortcutClashView: View {
  @ObservedObject var store: SettingsPanelStore
  let clash: SettingsPanelModel.Clash

  var body: some View {
    HStack(spacing: 8) {
      Text(clash.message)
        .font(.caption)
        .foregroundStyle(.orange)
      Button("Use It Here Instead") { store.model.replaceHolder() }
        .controlSize(.small)
      Button("Cancel") { store.model.cancelRecording() }
        .controlSize(.small)
    }
  }
}

// MARK: Rules

struct RulesPane: View {
  @ObservedObject var store: SettingsPanelStore

  var body: some View {
    Form {
      Section {
        Text(
          "What happens to a new window of an app. Rules are checked from the top and the first that matches wins; "
            + "windows that are already open keep their place."
        )
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        ForEach(store.model.ruleRows) { row in
          RuleRowView(store: store, row: row)
        }
      }
      Section {
        HStack {
          AppMenu(title: "Add a Rule for…", apps: store.model.appsForRules) { app in
            store.model.addRule(app: app.bundleID)
          }
          .fixedSize()
          Spacer()
        }
        SettingsErrorText(text: store.model.errors[SettingsPanelModel.Pane.rules.id])
      }
      SettingsProblemList(title: "Entries in settings.json that could not be read", lines: store.model.skippedRules)
    }
    .formStyle(.grouped)
  }
}

struct RuleRowView: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.RuleRow
  /// The rule is about to change by what was typed here.
  @State private var changedByTheField = false
  @FocusState private var titleIsFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(spacing: 8) {
        Text("\(row.number).")
          .foregroundStyle(.secondary)
          .monospacedDigit()
        VStack(alignment: .leading, spacing: 1) {
          Text(row.appName)
          if row.appName != row.rule.app {
            Text(row.rule.app)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        Spacer()
        RuleOrderButtons(store: store, row: row)
      }
      HStack(spacing: 8) {
        Picker("", selection: kind) {
          ForEach(SettingsPanelModel.RuleKind.allCases) { kind in
            Text(kind.title)
              .tag(kind)
          }
        }
        .labelsHidden()
        .fixedSize()
        if let neighbour = row.neighbour {
          AppMenu(title: store.model.name(of: neighbour), apps: store.model.appsForRules) { app in
            store.model.setNeighbour(app.bundleID, of: row)
          }
          .fixedSize()
        }
        if row.edge != nil {
          Picker("", selection: edge) {
            ForEach(ArborCore.Edge.allCases, id: \.self) { edge in
              Text(edge.rawValue.capitalized)
                .tag(edge)
            }
          }
          .labelsHidden()
          .fixedSize()
        }
        Spacer()
      }
      TextField("", text: title, prompt: Text("Only windows whose title contains… (any title)"))
        .labelsHidden()
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("rule.\(row.number).title")
        .accessibilityLabel("Rule \(row.number): only windows whose title contains")
        .focused($titleIsFocused)
        .onSubmit { commitTitle() }
        .onChange(of: titleIsFocused) {
          if !titleIsFocused { commitTitle() }
        }
    }
    .padding(.vertical, 2)
    // Lines are told apart by their place. If another rule comes to this place, or this one changes by another hand, the field
    // gives the keyboard up, as a number's does: what it holds was not meant for what it is about now.
    .onChange(of: row.rule) {
      if !changedByTheField { titleIsFocused = false }
      changedByTheField = false
    }
  }

  private var kind: Binding<SettingsPanelModel.RuleKind> {
    Binding<SettingsPanelModel.RuleKind>.onMainActor(
      get: { row.kind },
      set: { kind in store.model.setKind(kind, of: row) })
  }

  private var edge: Binding<ArborCore.Edge> {
    Binding<ArborCore.Edge>.onMainActor(
      get: { row.edge ?? .right },
      set: { edge in store.model.setEdge(edge, of: row) })
  }

  private var title: Binding<String> {
    Binding<String>.onMainActor(
      get: { store.model.draft(in: row.titleField) ?? row.rule.title ?? "" },
      set: { new in store.model.type(new, into: row.titleField) })
  }

  /// (Before anything else is done to the line the model does this by itself.)
  private func commitTitle() { changedByTheField = store.model.handOver(row.titleField) }
}

struct RuleOrderButtons: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.RuleRow

  var body: some View {
    HStack(spacing: 4) {
      Button {
        store.model.moveRule(row, by: -1)
      } label: {
        Image(systemName: "chevron.up")
      }
      .disabled(!store.model.canMove(row, by: -1))
      .help("Check this rule earlier")
      .accessibilityLabel("Check rule \(row.number) earlier")
      Button {
        store.model.moveRule(row, by: 1)
      } label: {
        Image(systemName: "chevron.down")
      }
      .disabled(!store.model.canMove(row, by: 1))
      .help("Check this rule later")
      .accessibilityIdentifier("rule.\(row.number).down")
      .accessibilityLabel("Check rule \(row.number) later")
      Button {
        store.model.removeRule(row)
      } label: {
        Image(systemName: "trash")
      }
      .help("Remove this rule")
      .accessibilityIdentifier("rule.\(row.number).remove")
      .accessibilityLabel("Remove rule \(row.number)")
    }
    .buttonStyle(.borderless)
  }
}

// MARK: Lists of apps

/// What a list is for, the apps on it, and a menu to add one.
struct AppListRow: View {
  @ObservedObject var store: SettingsPanelStore
  let row: SettingsPanelModel.Row
  let listed: [SettingsPanelModel.AppChoice]
  let candidates: [SettingsPanelModel.AppChoice]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      SettingLabel(label: row.label, help: row.help)
      ForEach(listed) { app in
        HStack {
          VStack(alignment: .leading, spacing: 1) {
            Text(app.name)
            if app.name != app.bundleID {
              Text(app.bundleID)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          Spacer()
          Button {
            store.model.remove(app.bundleID, from: row.key)
          } label: {
            Image(systemName: "minus.circle")
          }
          .buttonStyle(.borderless)
          .help("Take it off the list")
          .accessibilityIdentifier("\(row.key).remove.\(app.bundleID)")
          .accessibilityLabel("Take \(app.name) off the list")
        }
      }
      AppMenu(title: "Add an App…", apps: candidates) { app in
        store.model.add(app.bundleID, to: row.key)
      }
      .fixedSize()
      .accessibilityIdentifier("\(row.key).add")
    }
  }
}

// MARK: Shared

/// A menu of running apps.
struct AppMenu: View {
  let title: String
  let apps: [SettingsPanelModel.AppChoice]
  let choose: @MainActor (SettingsPanelModel.AppChoice) -> Void

  var body: some View {
    Menu(title) {
      if apps.isEmpty {
        Text("No other app is running")
      }
      ForEach(apps) { app in
        Button(app.name) { choose(app) }
      }
    }
  }
}

extension Binding {
  /// A binding whose two closures run on the main actor, like everything else in a view.
  ///
  /// Instead of `Binding(get: { @MainActor in … }, set: { @MainActor new in … })` where the binding is wanted, which says the same and which
  /// Swift 6.3 (Xcode 26.4 to 26.6) crashes on: the initializer takes `@isolated(any)` closures of any `Value`, and that compiler
  /// dies making the piece between a main-actor closure that takes a `String`, say, and one of those. Here `Value` is still
  /// any type, so no such piece is made.
  @MainActor static func onMainActor(
    get: @escaping @MainActor () -> Value, set: @escaping @MainActor (Value) -> Void
  ) -> Binding<Value> {
    Binding(get: get, set: set)
  }
}
