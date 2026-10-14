import SwiftUI
struct Buttons: View {
  let before: @MainActor () -> Void
  var body: some View { Button("x") { before() } }
}
struct Menus: View {
  let choose: @MainActor (String) -> Void
  var body: some View { Menu("m") { Button("x") { choose("x") } } }
}
struct V: View {
  @State private var typed: String?
  var body: some View { VStack { Buttons(before: { commit() }); Menus { app in typed = app } } }
  private func commit() { typed = nil }
}
