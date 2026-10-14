# Settings

<!-- Generated from Sources/ArborCore/SettingsSchema.swift (`arborctl settings --markdown`). Do not edit:
     change the schema and run the tests, which rewrite this file. -->

Arbor keeps its settings in `~/Library/Application Support/Arbor/settings.json` (menu → Open Settings
File). There are four ways to change one, and each takes effect at once and shows in the others:

- **The settings window**: Settings… in the menu, or ⌃⌥,. It has the sections below, the settings marked
  *Advanced* behind a disclosure, a search field, and panes for your shortcuts and rules. A few settings are not
  in it, for the few who look for them; they are marked too.
- **A command**: `arborctl set gap 16`. `arborctl get gap` prints one value, `arborctl settings` lists them
  all and marks the ones you changed, `arborctl reset gap` goes back to the default, `arborctl reset all`
  resets everything except your shortcuts, rules and lists of apps, and `arborctl reset everything` resets
  those too. Keys ignore case, and `on`/`off`, `yes`/`no` and `1`/`0` also mean true and false. A value
  outside what the table allows is refused, with the reason, and changes nothing. A command changes only its
  own setting in the file; the rest stays as you wrote it, keys Arbor does not know included.
- **The file**: Arbor watches it and applies an edit as soon as it is saved. Missing keys take their
  defaults. A number outside its range is moved to the nearest end of it, and any other value Arbor cannot
  use goes back to its default; `arborctl settings` and the log say which, and the file keeps what you wrote
  until you `set` or `reset` that key. While the file is not valid JSON Arbor keeps the settings it has and
  refuses commands that change settings; `arborctl reload-settings` says where the typo is. `arborctl reset
  everything` is the way out: it writes a new file and keeps the old one as `settings.unreadable.json`.
- **A keyboard shortcut**: `arborctl bind ctrl+opt+x set gap 0`, or `set focusRing toggle` for a switch.

## General

| Key | Default | Values | What it does |
|---|---|---|---|
| `hotkeysEnabled` | `true` | true or false | **Use keyboard shortcuts.** Global keyboard shortcuts: ⌃⌥ moves the view and ⌃⌥⌘ moves windows, unless you change them. |
| `peek` | `true` | true or false | **Hold Show Everything to peek.** While the Show Everything shortcut is held everything shows, and letting go frames the outlined space. Off, holding it does the same as a tap. |
| `stepInToward` | `auto` | auto or pointer or focus | **Shortcuts follow.** Which display a shortcut acts on, and which space Step In steps toward. Gestures always follow the pointer. `auto`: Whichever was used last. `pointer`: The pointer. `focus`: The focused window. *Advanced.* |
| `shortcutsFollowLayout` | `true` | true or false | **Shortcuts follow the keyboard layout.** A letter, digit or sign in a shortcut means the key that types it on the keyboard layout in use, as in ⌘ shortcuts. Off, it means that key's place on a US keyboard. *Advanced.* |
| `automaticUpdateChecks` | `false` | true or false | **Check for updates.** Ask GitHub for a newer release a minute after starting and once a week. No window opens: the menu then offers the update, and nothing is ever downloaded. Off, Arbor uses the network only when asked to. |
| `bindings` | `{}` | an object that maps shortcuts to commands | **Your shortcuts.** Changes to the shortcuts: a shortcut and the command it runs, or null to remove a default one. Change it with `bind <shortcut> <command>` and `unbind <shortcut>`. |
| `messages` | `helpful` | helpful or all or off | **Messages on screen.** A line on screen after a shortcut, a gesture or a menu item: what went wrong, what changed out of view, and a few hints for newcomers. `helpful`: When it helps. `all`: After every command. `off`: Never. |

## Windows

| Key | Default | Values | What it does |
|---|---|---|---|
| `gap` | `12` | 0 to 100 pt | **Gap.** Space between docked windows, and between them and the screen edges. |
| `minimumUsableWidth` | `240` | 0 to 1000 pt | **Smallest usable width.** A space narrower than this shows a tile with the app's colour and icon instead of its window. |
| `minimumUsableHeight` | `160` | 0 to 1000 pt | **Smallest usable height.** A space shorter than this shows a tile instead of its window. |
| `arrangeDesktopWeight` | `0.5` | 0.1 to 3 | **Desktop width in Arrange.** How wide Arrange Windows leaves the Desktop, relative to the windows beside it. *Advanced.* |
| `rules` | `[]` | a list of rules | **Rules.** What happens to new windows of particular apps. Rules are checked in order and the first match wins. Change it with `rule add`, `rule change`, `rule remove` and `rule move`. |
| `ruleTitleWait` | `2` | 0 to 60 s | **Wait for a window's title.** How long a new window's title is checked against rules that have a title: browsers and editors set the real title a moment after the window opens. 0 checks only the first title. *Not in the settings window.* |
| `newWindowsWhileFramed` | `guest` | guest or float | **New windows while framed.** A window that opens over a view that does not show the Desktop (a framed window, a group) can go out of view and come back with that view, or belong to the Desktop like any floating window. `guest`: Stay with that view. `float`: Belong to the Desktop. |
| `tileRetryMinutes` | `10` | 0 to 1440 min | **Ask tiles again after.** A window that is a tile because it once refused the size of its space is asked again, out of view, after this long. 0 never asks; `relayout` always does. *Not in the settings window.* |
| `summonStays` | `false` | true or false | **Summoned windows stay.** A summoned window stays over the view when another window gets the keyboard, until it is summoned away. Off, turning to another window sends it out of view. *Advanced.* |
| `makeRoom` | `true` | true or false | **Make room before making a tile.** Before a window becomes a tile because its app will not shrink that far, move the gaps around it and take the room from the Desktop and from neighbours that can spare it. *Advanced.* |
| `soleFloatTakesDesktop` | `false` | true or false | **Lone window fills the Desktop.** Beside docked windows, the only floating window takes the whole Desktop and follows it. It has its own size back as soon as a second window floats. Moved or resized by hand, it stays as you leave it. *Advanced.* |
| `resizeStep` | `40` | 1 to 1000 pt | **Grow and Shrink by.** How much bigger or smaller Grow and Shrink (⌃⌥⌘= and ⌃⌥⌘-) make the focused window at a time. *Advanced.* |
| `displays` | `[]` | a list of entries: `match` and the settings that differ there | **Options per display.** Other values of the gap, the smallest usable size and the screen edge band for particular displays. The first entry that matches a display and sets a value gives it. Change it with a text editor; `displays` shows what is in effect on each display. *Advanced.* |
| `newWindows` | `float` | float or dock | **New windows.** What a new window does when no rule matches it. Docked, it takes half the place of the docked window you were working in, if there is room; small windows and windows of a fixed size float. Dock New Windows in the menu is the same switch. `toggle-auto-dock` switches it too. `float`: Float where they open. `dock`: Dock beside the focused window. |
| `autoDockMinimumWidth` | `400` | 0 to 3000 pt | **Narrowest window docked.** Where new windows dock by themselves, one that opens narrower than this floats. That is `dock auto` and a rule for `*`; a rule that names an app docks its windows whatever their size. *Advanced.* |
| `autoDockMinimumHeight` | `300` | 0 to 3000 pt | **Shortest window docked.** Where new windows dock by themselves, one that opens shorter than this floats. That is `dock auto` and a rule for `*`; a rule that names an app docks its windows whatever their size. *Advanced.* |
| `shareRemovedSpace` | `true` | true or false | **Share a leaving window's space.** The space of a window that leaves is shared by its whole group. Off, it goes to the neighbour before it and nothing else moves. *Advanced.* |
| `shrinkOutOfView` | `false` | true or false | **Shrink windows out of view.** Windows that go out of view are also shrunk, to 320 by 200 points at most, until they come back. *Advanced.* |

## Dragging

| Key | Default | Values | What it does |
|---|---|---|---|
| `screenEdgeBand` | `12` | 0 to 100 pt | **Screen edge band.** How close to a screen edge the pointer must come for a dragged window to dock there. *Advanced.* |
| `windowEdgeFraction` | `0.3` | 0 to 0.5 | **Window edge band.** The band along a window's edges, as a share of its size, where a dropped window docks beside it. *Advanced.* |
| `dropDwell` | `0.15` | 0 to 2 s | **Hold over a target.** How long a dragged window must be held over a window or tile before it can be dropped there. Screen edges never wait. *Advanced.* |
| `previewDrags` | `true` | true or false | **Drop preview.** Show where a dragged window will land. Without it nothing has to be held either. *Advanced.* |
| `reflowWhileDragging` | `false` | true or false | **Make room while dragging.** While you drag, the other windows close up and make room, showing what letting go would do. *Not in the settings window.* |
| `keepPushed` | `true` | true or false | **Pushed windows stay aside.** With reflowWhileDragging: floating windows pushed aside stay there until the drag ends. *Not in the settings window.* |

## Tabs

| Key | Default | Values | What it does |
|---|---|---|---|
| `tabsEnabled` | `false` | true or false | **Tab groups.** Dropping a window on the middle of another makes the two a tab group. *Not in the settings window.* |

## Gestures

| Key | Default | Values | What it does |
|---|---|---|---|
| `gesturesEnabled` | `true` | true or false | **Pinch to zoom.** A trackpad pinch with ⌥ held, or over the Desktop, zooms the view in and out. |
| `pinchThreshold` | `0.25` | 0.05 to 2 | **Pinch travel for one step.** How far a pinch must travel for one step; smaller is more sensitive. *Advanced.* |
| `frameRectangleModifier` | `ctrl+opt` | modifier keys joined by +, such as shift+cmd, or none | **Frame a rectangle with.** Hold these keys and drag a rectangle to frame what it covers; none turns this off. |
| `frameRectangleOnDesktop` | `true` | true or false | **⇧-drag on the Desktop frames.** A ⇧-drag that starts on the Desktop, in a gap or on a tile also frames a rectangle. |
| `continuousZoom` | `false` | true or false | **Continuous zoom.** Not finished: the view will follow the fingers during a pinch, and pan with ⌥ and two fingers. For now a pinch steps as before. *Not in the settings window.* |
| `guardDesktopClicks` | `false` | true or false | **Guard clicks on the Desktop.** Experimental. While something is docked, a plain click on the bare Desktop is kept from macOS, which would sweep every window aside (“Click wallpaper to reveal desktop”). Drags, icons and widgets are left alone. *Advanced.* |
| `scrollZoom` | `true` | true or false | **Zoom with ⌃⌥ and scroll.** Scrolling with ⌃⌥ held zooms: up steps in toward the pointer, down steps out. Off with Pinch to zoom too. |
| `scrollZoomThreshold` | `40` | 4 to 400 pt | **Scroll travel for one step.** How far a Magic Mouse or trackpad must scroll for one step; smaller is more sensitive. A wheel steps once per notch. *Advanced.* |
| `scrollOnDesktopZooms` | `false` | true or false | **Scroll on the Desktop zooms.** Scrolling on the Desktop, in a gap or on a tile zooms without the keys. Every scroll on the Mac then passes through Arbor. *Advanced.* |

## Calls

| Key | Default | Values | What it does |
|---|---|---|---|
| `holdStillWhileCameraIsOn` | `false` | true or false | **While a camera is on.** Hold still by itself during a call: the view moves only when you ask. Arbor reads from macOS that some app has a camera running, and opens none itself. Experimental; Hold Still in the menu does the same by hand. *Advanced.* |
| `holdStillWhileMicrophoneIsOn` | `false` | true or false | **While a microphone is on.** The same for calls without a camera. Experimental: other things than calls may keep a microphone running. *Advanced.* |
| `holdStillFor` | `[]` | a list of bundle ids, each with part of a title after it if you like | **While one of these is open.** Arbor also holds still while a window like one of these is open: an app's bundle id and, if you like, part of the window's title, such as "us.zoom.xos Zoom Meeting". Change it with a text editor. *Advanced.* |

## Appearance

| Key | Default | Values | What it does |
|---|---|---|---|
| `focusRing` | `true` | true or false | **Focus ring.** Draw a line around the focused window, if Arbor arranges it. |
| `focusRingWidth` | `3` | 1 to 12 pt | **Focus ring width.** How thick the line around the focused window is. *Advanced.* |
| `focusRingColour` | `accent` | accent, #RRGGBB or #RRGGBBAA | **Focus ring colour.** The colour of the line: accent is the accent colour chosen in System Settings. *Advanced.* |
| `focusRingRadius` | `0` | 0 to 60 pt | **Focus ring corners.** The radius of the window corners the line follows; 0 picks that of the macOS Arbor runs on. *Not in the settings window.* |
| `animationDuration` | `0.46` | 0 to 2 s | **Motion.** How long a zoom, a dock or a close takes to play; 0 applies everything at once. “Reduce motion” in System Settings turns the motion off as well. |
| `minimapDuration` | `0` | 0 to 10 s | **Show minimap after each move.** For how long the minimap shows by itself after the view has moved. 0 is off; its shortcut shows it either way. |
| `dimBehindArranged` | `0.25` | 0 to 1 | **Darken behind docked windows.** How much darker the wallpaper is behind docked windows, so that they read as one surface: from as it is to black. 0 leaves it as it is, 1 is black. |
| `blurBehindArranged` | `0` | 0 to 1 | **Blur behind docked windows.** How much the wallpaper is blurred behind docked windows: from sharp to all the blur macOS has. 0 leaves it sharp, 1 is all the blur macOS has. *Advanced.* |
| `tileStyle` | `icon` | icon or name or plain | **Tiles show.** What the tile of a window too small to use shows on its colour. `icon`: The icon. `name`: The icon and the name. `plain`: Only the colour. |
| `appColours` | `true` | true or false | **Tiles in their app's colour.** A tile takes on the colour of its app's icon. Off, every tile is the same grey. *Advanced.* |
| `appColourAmount` | `0.25` | 0 to 1 | **How much of the app's colour.** How much of its app's colour goes into a tile: from grey to the colour itself. 0 is grey, 1 is the colour itself. *Advanced.* |
| `gapHandles` | `shown` | shown or hidden or off | **Gaps between windows.** Whether dragging a gap resizes the windows on both sides of it, and whether a handle shows in the gap under the pointer. A window's own edges resize it either way. `resize` moves a window's edge whatever this says. `shown`: Drag them, with a handle. `hidden`: Drag them, nothing drawn. `off`: Only gaps. |
| `windowPictures` | `false` | true or false | **Pictures of moving windows.** Not ready: it has crashed Arbor and has not been tried since it was mended. While they move, windows are still pictures of themselves instead of their app's colour and icon. Needs Screen & System Audio Recording permission; nothing is recorded or stored. *Not in the settings window.* |
| `tintBehindArranged` | `0` | 0 to 1 | **Tint behind docked windows.** How much of your accent colour is laid over the wallpaper behind docked windows. *Advanced.* |
| `desktopEdge` | `0.05` | 0 to 1 | **Line around the Desktop.** How strong the hairline around the Desktop is where it lies between docked windows; 0 draws none. *Advanced.* |
| `tileFade` | `0.2` | 0 to 1 s | **Tiles fade for.** How long a tile takes to fade in and out; 0 shows and hides it at once. *Not in the settings window.* |

## Menu Bar

| Key | Default | Values | What it does |
|---|---|---|---|
| `menuBarControls` | `true` | true or false | **Buttons in the menu bar.** Buttons for back, forward, the Desktop, everything and each saved view; right-click them for the menu. Off, a single icon opens the menu. |
| `historyButtons` | `true` | true or false | **Back and forward buttons.** Whether the buttons include back and forward. *Advanced.* |
| `menuBarFill` | `0.25` | 0 to 1 | **Fill of the current button.** How opaque the background of the button for where you are is, from 0 to 1. *Not in the settings window.* |

## Apps

| Key | Default | Values | What it does |
|---|---|---|---|
| `excludedBundleIDs` | `[]` | a list of bundle ids | **Don't arrange.** Arbor leaves the windows of these apps alone: it never docks, moves or sends them out of view. Change it with `set excludedBundleIDs add <app>` and `set excludedBundleIDs remove <app>`, or `exclude [bundle id]` and `include <bundle id>`. |
| `passThroughApps` | `[]` | a list of bundle ids | **Shortcuts off in.** Apps that keep ⌃⌥ for themselves: while one of them is in front Arbor gives up its shortcuts and gestures, and goes on arranging windows. Change it with `set passThroughApps add <app>` and `set passThroughApps remove <app>`, or `pass-through [bundle id] [on\|off]`. |
| `pauseForApps` | `[]` | a list of bundle ids | **Pause for.** Arbor pauses for as long as one of these apps is in front. Change it with `set pauseForApps add <app>` and `set pauseForApps remove <app>`. *Advanced.* |

## Scripting

| Key | Default | Values | What it does |
|---|---|---|---|
| `allowAllURLCommands` | `false` | true or false | **Every command from URLs.** Let arbor:// URLs run every command, not only those that move the view and arrange windows; any web page or document can open such a URL. |

Shortcuts and rules are described in the [README](../README.md#keyboard).
