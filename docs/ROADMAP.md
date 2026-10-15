# Roadmap

Each feature has a spec in `docs/features/` with its status, dependencies,
the files it touches, and acceptance criteria. The spec is the source of
truth for its status; `collab/BOARD.md` is the source of truth for the order
of work; `docs/FEATURES.md` (generated) shows how Arbor compares with TrellisWM.

F18 to F29 and F37 are taken by features on the swarm's branches and arrive with them. F30 to F36 and F38 were
written by executors on 2026-10-14, for what TrellisWM does and no earlier spec plans; the documenter
has yet to review them, and they are not on the board yet. In the last
column "new" marks a file that does not exist yet.

| ID | Feature | Depends on | Headless-testable | Main files |
|---|---|---|---|---|
| [F01](features/F01-dock-and-zoom.md) | Dock and zoom (the core) | | yes | everything |
| [F02](features/F02-animated-transitions.md) | Animated transitions | F01 | the plan, not the picture | new `ArborCore/Plane.swift`, `ArborCore/Transition.swift`, `Controller+Transitions.swift`, `UI/Stage.swift`, `UI/StageDirector.swift`, `UI/WindowPictures.swift` |
| [F03](features/F03-trackpad-gestures.md) | Trackpad pinch and pan | F01 | interpreter only | `Input/GestureTap.swift`, `Input/EventTap.swift`, `ArborCore/GestureInterpreter.swift` |
| [F04](features/F04-tab-groups.md) | Tab strips for stacks | F01 | partly | `ArborCore/Layout.swift`, `Platform/OverlayPresenter.swift`, new `UI/TabStripPanel.swift` |
| [F05](features/F05-frame-a-rectangle.md) | Drag a rectangle to frame it | F01 | partly | `Input/RectangleFramer.swift`, `ArborCore/RectangleGesture.swift`, `Controller+FrameRect.swift` |
| [F06](features/F06-configurable-keybindings.md) | Key bindings in settings.json | F01 | yes | `Controller/KeyBindings.swift`, `ArborCore/Settings.swift`, `ArborCore/KeyChord.swift` |
| [F07](features/F07-resize-by-window-edges.md) | Resize docked windows by their own edges | F01 | yes | `Controller+Events.swift`, `Controller+EdgeResize.swift` |
| [F08](features/F08-displays-and-spaces.md) | Display reconnects and Spaces | F01 | yes | `Controller+Displays.swift`, `Controller+Spaces.swift`, `Platform/StateStore.swift`, `AX/AXWindowSystem.swift` |
| [F09](features/F09-drag-polish.md) | Drag polish: dwell, modifier, live reflow | F01 | yes | `Controller+Drag.swift`, `ArborCore/Drop.swift` |
| [F10](features/F10-menu-bar-and-onboarding.md) | Menu bar controls and onboarding | F01 | no | `UI/StatusMenu.swift`, new `UI/Onboarding.swift` |
| [F11](features/F11-app-rules.md) | Per-app rules | F01 | yes | `ArborCore/Settings.swift`, `ArborCore/AppRule.swift`, `Controller+Rules.swift` |
| [F12](features/F12-settings-window.md) | Settings window | F06, F11 | no | new `UI/SettingsWindow.swift` |
| [F13](features/F13-distribution.md) | Signing, notarization, updates | F01 | no | `scripts/`, `Resources/` |
| [F14](features/F14-double-click-actions.md) | Double-click actions | F01 (F05's event tap) | partly | new `Controller+DoubleClick.swift`, `WindowSystem.swift` |
| [F15](features/F15-appearance-options.md) | Appearance options | F01 | partly | `Settings.swift`, `OverlayPresenter.swift`, `UI/` |
| [F16](features/F16-continuous-zoom-and-pan.md) | Continuous zoom and pan | F02, F03 | partly | new core camera type on `ArborCore/Plane.swift`, `UI/Stage.swift` |
| [F17](features/F17-real-window-hardening.md) | Real-window hardening | F01 (after F07) | partly | `AX/AXWindowSystem.swift`, `Controller+Events.swift`, `arbor-e2e` |
| [F23](features/F23-automatic-docking.md) | Automatic docking: new windows join the arrangement | F11 | yes | `ArborCore/AutoDock.swift`, `ArborCore/AppRule.swift`, `Controller+AutoDock.swift`, `Controller+Rules.swift` |
| [F18](features/F18-sole-floating-window.md) | A window that floats alone takes the Desktop | F01 | yes | new `Controller+SoleFloat.swift`, `Controller+Layout.swift` |
| [F22](features/F22-keyboard-tiling-tools.md) | Keyboard tiling tools | F01, F06, F07, F11 | yes | new `ArborCore/DirectionalSearch.swift`, `ArborCore/TilingCommands.swift`, `Controller+KeyboardFocus.swift`, `Controller+Tiling.swift` |
| [F24](features/F24-events.md) | Events for scripts and status bars (`arborctl watch`) | F01 | yes | new `ArborCore/ArborEvent.swift`, `Controller/EventFeed.swift`, `IPC/ControlServer.swift`, `ArborIPC/` |
| [F25](features/F25-per-display-options.md) | Options per display | F01, F08 | yes | new `ArborCore/DisplayOptions.swift`, `Controller+DisplayOptions.swift`, `Settings.swift`, `WindowSystem.swift` |
| [F30](features/F30-full-screen-windows.md) | Full-screen windows | F08 | partly | `Platform/WindowSystem.swift`, `Controller+Events.swift`, `AX/AXWindowSystem.swift` |
| [F31](features/F31-new-windows-join.md) | New windows join the arrangement: superseded by F23 | | | |
| [F32](features/F32-float-all-everywhere.md) | Float All means all | F01 | yes | `ArborCore/Command.swift`, `Controller+Commands.swift` |
| F33 (its spec comes with `feat/F33-switches`) | The switches TrellisWM has | F01 | yes | `ArborCore/Settings.swift`, `ArborCore/LayoutTree.swift`, `ArborCore/Layout.swift` |
| [F34](features/F34-tab-groups-the-rest.md) | Tab groups, the rest | F04 | yes | `ArborCore/LayoutTree.swift`, `Platform/OverlayPresenter.swift`, `Platform/WindowSystem.swift` |
| [F35](features/F35-slots-survive-on-other-spaces.md) | A restart keeps the slots of windows on other Spaces | F08 | partly | `Platform/WindowSystem.swift`, `Controller.swift` (`reconcile`), `AX/AXWindowSystem.swift` |
| [F36](features/F36-appearance-leftovers.md) | Appearance leftovers | F10, F15 | partly | `ArborCore/Settings.swift`, `Platform/OverlayPresenter.swift`, `UI/` |
| [F38](features/F38-focus-as-macos-reports-it.md) | Focus, as macOS reports it | F01 | mostly | `Controller+Events.swift`, `ArborTesting/FakeWindowSystem.swift`, `AX/AXWindowSystem.swift` |
| [F40](features/F40-pause.md) | Pause and resume | F01, F06 | yes | new `Controller+Pause.swift` |
| [F41](features/F41-pass-through-apps.md) | Apps that keep their own ⌃⌥ | F06, F40 | yes | `KeyBindings.swift`, `WindowSystem.swift`, `App/ArborApp.swift` |
| [F42](features/F42-setup-check.md) | Setup check (`doctor`) | F10 | the rules | new core `SetupCheck`, `UI/` |
| [F43](features/F43-say-what-happened.md) | A heads-up line, and the shortcuts on screen | F06 | partly | `OverlayPresenter.swift`, `Command.swift`, `UI/` |
| [F44](features/F44-shortcuts-follow-the-keyboard-layout.md) | Shortcuts follow the keyboard layout | F06 | the mapping | `KeyChord.swift`, `Input/HotKeyCenter.swift` |
| [F45](features/F45-learned-sizes-expire.md) | Learned minimum sizes expire | F01 | yes | `Controller+Layout.swift` |
| [F46](features/F46-first-run-coach.md) | The first three minutes | F10, F42 | the progress | `UI/Onboarding.swift` |
| [F47](features/F47-dialogs-out-of-view.md) | No dialog opens out of view | F01 | the rule | `AX/AXWindowSystem.swift` |
| [F48](features/F48-floating-restores-size.md) | Floating restores a window's size | F01 | yes | `Workspace.swift`, `Controller+Commands.swift` |
| [F49](features/F49-pin.md) | Pin a window so that it stays in view | F01, F11 | yes | `Workspace.swift`, `Controller+Layout.swift` |
| [F50](features/F50-scripting.md) | A command line people enjoy scripting | F01 | mostly | `Command.swift`, `arborctl` |
| [F51](features/F51-peek.md) | Peek: hold to look, let go to land | F01 | yes | new core `Peek`, new `Controller+Peek.swift`, `Input/HotKeyCenter.swift`, new `UI/PeekOutlinePanel.swift` |
| [F52](features/F52-unplugged-display-becomes-a-space.md) | An unplugged display becomes a space | F08 | yes | `LayoutTree.swift`, `Controller+Displays.swift` |
| [F53](features/F53-summon.md) | Summon an app over any view | F49 | yes | new `Controller+Summon.swift` |
| [F54](features/F54-layouts-as-text.md) | Write an arrangement as a line of text | F01 | yes | new core `LayoutNotation` |
| [F55](features/F55-zoom-with-a-mouse.md) | Zoom with a mouse | F03 | interpreter | `GestureInterpreter.swift`, `Input/GestureTap.swift` |
| [F56](features/F56-keys-follow-the-keyboard.md) | Keys follow the keyboard, gestures the pointer | F01 | yes | new core `InputLead`, new `Controller+Lead.swift` |
| [F57](features/F57-new-windows-while-framed.md) | New windows while a window is framed | F04, F31 | yes | `Controller+Rules.swift`, `Workspace.swift` |
| [F58](features/F58-hold-the-view.md) | Hold the view (presenting) | F40 | yes | `Controller+Layout.swift` |
| [F59](features/F59-carry-with-the-keyboard.md) | Carry a window with the keyboard | F09 | yes | new `Controller+Carry.swift`, `Drop.swift` |
| [F60](features/F60-guard-the-wallpaper-click.md) | A click on the Desktop does not sweep the windows away | F05 | the decision | `Input/RectangleFramer.swift`, new core state machine |
| [F61](features/F61-room-before-tiles.md) | Make room before making a tile | F01 | yes | `LayoutTree.swift`, `Controller+Layout.swift`, `Workspace.swift` |
| [F63](features/F63-permission-taken-away.md) | Accessibility permission taken away while Arbor runs | F40, F41 | the decisions | new `Controller+Permission.swift`, `PermissionWatch.swift`, `App/ArborApp.swift` |

## Order of work

See `collab/BOARD.md`. Items touching different files can run in parallel;
expect small merge conflicts in the shared hot spots listed in `CLAUDE.md` and
resolve them by keeping both sides.
