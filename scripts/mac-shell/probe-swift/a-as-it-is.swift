import SwiftUI
struct V: View {
  @State private var typed: String?
  var body: some View { TextField("", text: title) }
  private var title: Binding<String> {
    Binding<String>(get: { @MainActor in typed ?? "" }, set: { @MainActor new in typed = new })
  }
}
