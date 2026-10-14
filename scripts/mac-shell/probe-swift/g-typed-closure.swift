import SwiftUI
struct V: View {
  @State private var typed: String?
  var body: some View { TextField("", text: title) }
  private var title: Binding<String> {
    let get: @MainActor () -> String = { typed ?? "" }
    let set: @MainActor (String) -> Void = { new in typed = new }
    return Binding<String>(get: get, set: set)
  }
}
