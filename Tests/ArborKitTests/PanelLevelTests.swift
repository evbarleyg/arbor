#if os(macOS)
  import AppKit
  import Testing

  @testable import ArborKit

  /// The table "Who is above whom" in docs/ARCHITECTURE.md, held to the code. The panels are made and never shown. The
  /// stage's panel and the drop preview's are private to their files, and Arbor's titled windows set their level when they
  /// are opened: for those the table has only the reader.
  @Suite @MainActor struct PanelLevelTests {
    private let floating = NSWindow.Level.floating.rawValue

    private var overlays: [(name: String, panel: NSPanel)] {
      [
        ("backdrop", BackdropPanel()), ("tile", TilePanel()), ("gap handle", SeamPanel()), ("focus ring", FocusRingPanel()),
        ("peek outline", PeekOutlinePanel()), ("rubber band", RubberBandPanel()), ("Go to…", FinderPanel()),
        ("shortcuts", CheatSheetPanel()), ("minimap", MinimapPanel()), ("heads-up line", HeadsUpPanel()),
        ("name field", NamePanel()),
      ]
    }

    @Test func thePanelsAreStackedAsTheTableSays() {
      let expected: [String: Int] = [
        "tile": 0, "gap handle": 0, "focus ring": 0, "peek outline": floating, "rubber band": floating,
        "Go to…": floating + 2, "shortcuts": floating + 2, "minimap": floating + 2, "heads-up line": floating + 3,
        "name field": NSWindow.Level.modalPanel.rawValue,
      ]
      for (name, panel) in overlays {
        if let level = expected[name] {
          #expect(panel.level.rawValue == level, "\(name)")
        } else {
          #expect(panel.level.rawValue < 0, "\(name) lies under every app's windows")
        }
      }
    }

    /// A stationary panel stays on screen in Mission Control, over the windows' miniatures (seen on a Mac, with tiles).
    @Test func everyOverlayHidesInMissionControl() {
      for (name, panel) in overlays {
        #expect(panel.collectionBehavior.contains(.transient), "\(name)")
        #expect(!panel.collectionBehavior.contains(.stationary), "\(name)")
      }
    }

    /// Without `.fullScreenAuxiliary` a panel does not show over another app's full-screen window. What a person asked for
    /// there does; the heads-up line only while it answers them (`HeadsUpModel.isAnswer`).
    @Test func onlyWhatAPersonAskedForShowsOverAFullScreenWindow() {
      let asked = ["peek outline", "rubber band", "Go to…", "shortcuts", "name field"]
      for (name, panel) in overlays {
        #expect(panel.collectionBehavior.contains(.fullScreenAuxiliary) == asked.contains(name), "\(name)")
      }
      let line = HeadsUpPanel()
      line.showsOverFullScreen = true
      #expect(line.collectionBehavior.contains(.fullScreenAuxiliary))
      #expect(line.collectionBehavior.contains(.transient), "and nothing else changed")
      line.showsOverFullScreen = false
      #expect(!line.collectionBehavior.contains(.fullScreenAuxiliary))
    }

    /// What shows a title, a name a person gave or which other apps are open is not for an audience.
    @Test func whatShowsSomethingPrivateKeepsOutOfPictures() {
      for (name, panel) in overlays {
        #expect((panel.sharingType == .none) == ["Go to…", "minimap", "name field"].contains(name), "\(name)")
      }
    }

    /// None of them makes Arbor the active app, and only three can have the keyboard.
    @Test func onlyThreePanelsTakeTheKeyboard() {
      for (name, panel) in overlays {
        #expect(panel.styleMask.contains(.nonactivatingPanel), "\(name)")
        #expect(panel.canBecomeKey == ["Go to…", "shortcuts", "name field"].contains(name), "\(name)")
        #expect(!panel.canBecomeMain, "\(name)")
      }
    }
  }
#endif
