import SwiftUI
struct V: View {
  @State private var typed: String?
  @State private var other: String?
  var body: some View { VStack { TextField("", text: title); TextField("", text: second) } }
  private var title: Binding<String> {
    Binding<String>(get: { @MainActor in typed ?? "" }, set: { @MainActor new in typed = new })
  }
  private var second: Binding<String> {
    Binding<String>(get: { @MainActor in other ?? "" }, set: { @MainActor new in other = new })
  }
}
