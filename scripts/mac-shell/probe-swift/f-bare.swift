import SwiftUI
struct V: View {
  @State private var typed: String?
  var body: some View { TextField("", text: title) }
  private var title: Binding<String> {
    Binding<String>(get: { typed ?? "" }, set: { new in typed = new })
  }
}
