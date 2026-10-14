// Ordinary, correct SwiftUI. selftest.py expects typecheck-mac to have nothing to say about it: a stand-in that cries wolf is not believed for long.
// One construct to a property, because one error in a builder's block hides the others. Never shipped, never run.
import SwiftUI

struct RightItem: Identifiable { var id = 0; var name = "" }
@MainActor struct RightSwiftUI {
  @State var on = false
  @State var text = ""
  @State var number = 1.0
  @State var choice = 1
  let items = [RightItem()]
  var p01: some View { Text("a").frame(width: 10, height: 20) }
  var p02: some View { Text("a").padding(.horizontal) }
  var p03: some View { VStack(alignment: .leading) { Text("a") } }
  var p04: some View { Text("a").font(.title) }
  var p05: some View { Button("x", action: {}) }
  var p06: some View { Text("a").foregroundStyle(.secondary) }
  var p07: some View { Toggle("x", isOn: $on) }
  var p08: some View { Text("a").onChange(of: on) { a, b in } }
  var p09: some View { Image(systemName: "gear") }
  var p10: some View { Text("a").bold() }
  var p11: some View { Button("x") {}.keyboardShortcut(.defaultAction) }
  var p12: some View { ForEach(items) { item in Text(item.name) } }
  var p13: some View { Text("a").help("b") }
  var p14: some View { Spacer(minLength: 3) }
  var p15: some View { Slider(value: $number, in: 0...1) }
  var p16: some View { TextField("x", text: $text) }
  var p17: some View { Picker("x", selection: $choice) { Text("a").tag(1) } }
  var p18: some View { HStack(spacing: 4) { Text("a") } }
  var p19: some View { Text("a").opacity(0.5) }
  var p20: some View { Text("a").background(Color.accentColor) }
  var p21: some View { Text("a").clipShape(RoundedRectangle(cornerRadius: 4)) }
  var p22: some View { Text("a").frame(maxWidth: .infinity) }
  var p23: some View { Form { Section("x") { Text("a") } } }
  var p24: some View { Text("a").disabled(true) }
  var p25: some View { Text("a").lineLimit(2) }
  var p26: some View { Label("x", systemImage: "gear") }
  var p27: some View { Text("a").padding(.top, 3) }
  var p28: some View { Divider().frame(height: 1).foregroundColor(.red) }
  var p29: some View { Text("a").onAppear {} }
  var p30: some View { Text("a").fontWeight(.semibold) }
  // What the features still to come are likely to reach for.
  var q01: some View { List(items) { item in Text(item.name) } }
  var q02: some View { ScrollView { LazyVStack { Text("a") } } }
  var q03: some View { TabView { Text("a").tabItem { Label("x", systemImage: "gear") } } }
  var q04: some View { Stepper("x", value: $choice, in: 0...9) }
  var q05: some View { GroupBox("x") { Text("a") } }
  var q06: some View { LabeledContent("x") { Text("a") } }
  var q07: some View { Grid { GridRow { Text("a"); Text("b") } } }
  var q08: some View { Text("a").sheet(isPresented: $on) { Text("b") } }
  var q09: some View { Text("a").alert("x", isPresented: $on) { Button("ok") {} } }
  var q10: some View { GeometryReader { proxy in Text("\(proxy.size.width)") } }
  var q11: some View { Text("a").animation(.easeInOut(duration: 0.2), value: on) }
  var q12: some View { Text("a").overlay(alignment: .topTrailing) { Circle().fill(.red) } }
  var q13: some View { ZStack { Color.clear; Text("a") }.contentShape(Rectangle()).onTapGesture {} }
  var q14: some View { Text("a").task { await Task.yield() } }
  var q15: some View { Menu("x") { Button("a") {}; Divider(); Toggle("b", isOn: $on) } }
  var q16: some View { ProgressView(value: number) }
  var q17: some View { Text("a").onHover { _ in } }
  var q18: some View { ColorPicker("x", selection: .constant(.red)) }
  var q19: some View { DisclosureGroup("x") { Text("a") } }
  var q20: some View { Text("a").toolbar { ToolbarItem(placement: .primaryAction) { Button("x") {} } } }
  var q21: some View { Picker("x", selection: $choice) { Text("a").tag(1) }.pickerStyle(.segmented) }
  var q22: some View { Button("x") {}.buttonStyle(.borderedProminent).controlSize(.large) }
  var q23: some View { Text("a").gesture(DragGesture().onChanged { _ in }) }
  var q24: some View { Text("a") + Text("b").foregroundColor(.secondary) }
  @ViewBuilder var q25: some View { if on { Text("a") } else { Image(systemName: "gear") } }
  var q26: some View { Text("a").accessibilityLabel("b").accessibilityHidden(false) }
  var q27: some View { Text("a").transition(.opacity).id(choice) }
  var q28: some View { NavigationSplitView { Text("a") } detail: { Text("b") } }
  var q29: some View { Text("a").focusable().onKeyPress(.escape) { .handled } }
  var q30: some View { Link("x", destination: URL(string: "https://example.com")!) }
}
