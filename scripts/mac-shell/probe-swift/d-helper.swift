import SwiftUI
extension Binding {
  @MainActor static func onMain(get: @escaping @MainActor () -> Value, set: @escaping @MainActor (Value) -> Void) -> Binding<Value> {
    Binding(get: get, set: set)
  }
}
struct V: View {
  @State private var typed: String?
  var body: some View { TextField("", text: title) }
  private var title: Binding<String> {
    .onMain(get: { typed ?? "" }, set: { new in typed = new })
  }
}
