import SwiftUI
struct V: View {
  @State private var typed: String = ""
  @FocusState private var focused: Bool
  var body: some View {
    TextField("", text: $typed).focused($focused).onSubmit { commit() }
      .onChange(of: focused) { if !focused { commit() } }
      .onChange(of: typed) { typed = "" }
  }
  private func commit() { typed = "" }
}
