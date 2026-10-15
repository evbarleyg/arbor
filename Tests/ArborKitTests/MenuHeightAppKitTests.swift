#if os(macOS)
  import AppKit
  import ArborCore
  @testable import ArborKit
  import ArborTesting
  import Testing

  /// `MenuModel.height`, which `MenuHeightTests` bounds everywhere, goes by sizes that were measured once
  /// (`MenuModel.Metrics`). Here macOS itself is asked, each time the tests run on a Mac: should a later system give a row
  /// more, the bound on Linux would hold and the ways out be below the fold again.
  @Suite @MainActor struct MenuHeightAppKitTests {
    /// As `StatusMenu.fill` builds it. Shortcuts, ticks and greying change no height.
    func menu(_ sections: [MenuModel.Section]) -> NSMenu {
      let menu = NSMenu()
      for (index, section) in sections.enumerated() {
        if index > 0 { menu.addItem(.separator()) }
        if let title = section.title { menu.addItem(.sectionHeader(title: title)) }
        for item in section.items {
          let row = NSMenuItem(title: item.title, action: nil, keyEquivalent: "")
          // A title with attributes of its own could come out higher.
          if item.isNews { row.attributedTitle = StatusMenu.news(item.title) }
          menu.addItem(row)
        }
      }
      return menu
    }

    /// The menu and every submenu, in every state.
    @Test(arguments: MenuHeightTests.running + MenuHeightTests.notRunning)
    func macOSMakesAMenuAsHighAsTheModelSays(state: String) {
      let states = MenuHeightTests()
      for (path, sections) in states.everyMenu(of: states.harness(in: state).controller.menuModel()) {
        let (real, model) = (Double(menu(sections).size.height), MenuModel.height(of: sections))
        if #available(macOS 26, *) {
          #expect(real == model, "\(state), \(path): macOS says \(real) points, the model \(model)")
        } else {
          // Earlier systems give less, so what fits by the model's sizes fits there.
          #expect(real <= model, "\(state), \(path): macOS says \(real) points, the model \(model)")
        }
      }
    }
  }
#endif
