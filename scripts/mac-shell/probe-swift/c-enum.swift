import SwiftUI
enum Kind: String, CaseIterable, Identifiable, Sendable { case a, b; var id: String { rawValue } }
struct V: View {
  @State private var kept: Kind = .a
  var body: some View { Picker("", selection: kind) { ForEach(Kind.allCases) { Text($0.rawValue).tag($0) } } }
  private var kind: Binding<Kind> {
    Binding<Kind>(get: { @MainActor in kept }, set: { @MainActor new in kept = new })
  }
}
