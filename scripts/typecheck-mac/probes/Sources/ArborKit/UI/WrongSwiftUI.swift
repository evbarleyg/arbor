// SwiftUI as it comes out when it is written without a compiler: misspelt labels and members, a value where a binding belongs, the wrong kind of
// alignment. selftest.py expects typecheck-mac to report every line that ends in "wrong". Never shipped, never run.
import SwiftUI

struct WrongItem { var name = "" }
@MainActor struct WrongSwiftUI {
  @State var on = false
  @State var text = ""
  @State var number = 1.0
  let items = [WrongItem()]
  var p01: some View { Text("a").frame(width: 10, heigth: 20) }  // wrong
  var p02: some View { Text("a").padding(.horizontl) }  // wrong
  var p03: some View { VStack(alignment: .top) { Text("a") } }  // wrong
  var p04: some View { Text("a").font(.titel) }  // wrong
  var p05: some View { Button("x", action: 5) }  // wrong
  var p06: some View { Text("a").foregroundStyle(.secondry) }  // wrong
  var p07: some View { Toggle("x", isOn: on) }  // wrong
  var p08: some View { Text("a").onChange(of: on) { a, b, c in } }  // wrong
  var p09: some View { Image(systemImage: "gear") }  // wrong
  var p10: some View { Text("a").bold(2) }  // wrong
  var p11: some View { Button("x") {}.keyboardShortcut(.defaultActon) }  // wrong
  var p12: some View { ForEach(items) { item in Text(item.name) } }  // wrong
  var p13: some View { Text("a").help(5) }  // wrong
  var p14: some View { Spacer(minLenght: 3) }  // wrong
  var p15: some View { Slider(value: number, in: 0...1) }  // wrong
  var p16: some View { TextField("x", text: text) }  // wrong
  var p17: some View { Picker("x", selection: $on) { Text("a").tag(1, 2) } }  // wrong
  var p18: some View { HStack(spacing: "4") { Text("a") } }  // wrong
  var p19: some View { Text("a").opacity("half") }  // wrong
  var p20: some View { Text("a").background(Color.accent) }  // wrong
  var p21: some View { Text("a").cornerRadius(radius: 4) }  // wrong
  var p22: some View { Text("a").frame(maxWidth: .infinite) }  // wrong
  var p23: some View { Form { Section(title: "x") { Text("a") } } }  // wrong
  var p24: some View { Text("a").disabled("no") }  // wrong
  var p25: some View { Text("a").lineLimit(true) }  // wrong
  var p26: some View { Label("x", systemName: "gear") }  // wrong
  var p27: some View { Text("a").padding(.top, "3") }  // wrong
  var p28: some View { Divider().frame(height: 1).foregroundColor("red") }  // wrong
  var p29: some View { Text("a").onAppear(5) }  // wrong
  var p30: some View { Text("a").fontWeight(.semiBold) }  // wrong
  // Only `body` is a view builder without saying so.
  var p31: some View { if on { Text("a") } else { Image(systemName: "gear") } }  // wrong
}
struct WrongView: View {}  // wrong
