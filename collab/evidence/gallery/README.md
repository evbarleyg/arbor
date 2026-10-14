# Everything Arbor draws

Pictures of the real app on GitHub's hosted Macs (macOS 26.6, 1024 by 768 at one pixel to the point unless a row says otherwise), each
looked at and judged: can it be read, is it aligned, does the text fit, does it look as if macOS had drawn it, is it quiet, does it say
what a person needs in words they know. For whoever judges the look; nothing here comes from a person's Mac.

**New on 2026-10-15: translucency.** The hosted Macs come with Reduce Transparency switched on, which is why every material used to come out
flat. The gallery switches it off, so the light and dark columns now show what a person sees as macOS ships: panels that blur and take on
the colour of what lies behind them. The windows behind are as saturated as windows get, on purpose. That look had never been seen,
and it is where the faults are [35].

In a third of the whole-screen pictures of the run's second and third script a macOS alert about "Python" is in front: the script's own doing [41].

This branch holds pictures and is not for merging. `scripts/mac-shell/shots-gallery.sh` and its three companions (branch `test/gallery`) take them
all in one run of 24 minutes on one Mac.

**Looked at: 88 of 90 things Arbor draws, at least once (98 %); 184 of the 270 pictures it takes to have each in the light look, the dark one and with Increase Contrast (68 %).** ✔ fine · ◐ fine, with a remark · ✘ wrong · ? cannot be judged on a hosted Mac · ○ nobody has seen it yet. Numbers in brackets are rows of the table of findings below.

Where the pictures come from: `tour`: `shots-gallery.sh` at `look/after-1` `5b27a81` (the trunk at `5f18637` with #50, #79 and #85), run 38669956766; `moves`: `shots-gallery-moves.sh`, the same run; `looks`: `shots-gallery-looks.sh`, the same run; `off`: `shots-offscreen.sh`, the same run: what the macOS-only tests draw without a screen; `demo`: `shots-demo.sh` at `a391fe4`, run 38648865335; `menu`: `shots-F10.sh` at `a391fe4`, run 38648865173; `rest`: `shots-F15.sh` at `a391fe4`, run 38648865844; `line`: `shots-F43.sh` at `a391fe4`, run 38648856444; `settings`: `shots-F12.sh` at `a391fe4`, run 38648842531; `displays`: `check-displays.sh`, another lane's run of 2026-10-15, before #17 and #28.

## After pull request #190: the panels, measured

The second run (38685258262, `look/after-2` `886617e`: the trunk at `07b2bfc` with #79, #85 and #190) took every panel that holds words over plain wallpapers, the worst
there is behind a panel: a saturated red, a saturated blue, white, black. Upper row the light look, lower row the dark one, pixel for pixel. **The product owner's rule:** on pictures of the
screen, in the look a Mac comes with, words a person must read to act at least 4.5 to 1, all other words at least 3.

| Faintest word on the panel, by the judges' ruler (`stills.py read`) | Before, over a red and a blue window | After: light over red, blue, white, black | After: dark over red, blue, white, black |
|---|---|---|---|
| Go to…: what the field is for | 1.0 to 1.3 | 5.9, 6.2, 6.7, 5.4 | 6.7, 6.1, 5.1, 7.8 |
| Go to…: titles | 1.8 to 2.4 | 10.8 and better | 7.3 and better |
| Go to…: notes at the right (10 points) | 1.1 to 1.4 | 5.2 and better | 4.9 and better |
| Go to…: the selected row | 4.0 (white on the accent) | 6.1 | 6.3 |
| Shortcuts: headings, last line | 1.3 to 2.1 | 5.7, 6.1, 6.8, 5.0 | 6.1, 5.5, 4.1, 7.9 |
| Shortcuts: rows and keys | 4.6 and better | 7.9 and better | 5.8 and better |
| Name field: heading, placeholder, note | 2.0 to 3.9 | 4.5 and better | 4.1 and better |
| The line on screen | 4.3 (light) | 10.2, 11.5, –, 7.9 | 9.3, 8.2, 5.8, 12.8 |

With Reduce Transparency every ground is one flat colour whatever lies behind (232 to 235 light, 33 to 36 dark) and the faintest word is 6.5 and 7.4.

| | |
|---|---|
| Go to… | <a href="after-go-to.png"><img src="after-go-to.png" width="900"></a> |
| Go to…, typed | <a href="after-go-to-typed.png"><img src="after-go-to-typed.png" width="900"></a> |
| The shortcuts | <a href="after-shortcuts.png"><img src="after-shortcuts.png" width="900"></a> |
| The field for a name | <a href="after-name.png"><img src="after-name.png" width="900"></a> |
| The line on screen, a capsule now | <a href="after-line.png"><img src="after-line.png" width="900"></a> |
| The minimap: windows out of view have an edge | <a href="after-minimap.png"><img src="after-minimap.png" width="700"></a> |
| Over windows, as in the rows below: Go to… with a title of 115 letters | <a href="after-go-to-on-windows-light.png"><img src="after-go-to-on-windows-light.png" width="440"></a> <a href="after-go-to-on-windows-dark.png"><img src="after-go-to-on-windows-dark.png" width="440"></a> |
| The shortcuts | <a href="after-shortcuts-on-windows-light.png"><img src="after-shortcuts-on-windows-light.png" width="440"></a> <a href="after-shortcuts-on-windows-dark.png"><img src="after-shortcuts-on-windows-dark.png" width="440"></a> |
| The answer to Check for Updates…: macOS's own alert; dark, and light with Increase Contrast | <a href="after-alert.png"><img src="after-alert.png" width="600"></a> |
| With Increase Contrast, three times enlarged: the focus ring's outermost point, the second line of the drop preview and of peek's outline, the dragged handle's edge | <a href="after-lines-contrast.png"><img src="after-lines-contrast.png" width="900"></a> |

### Board 0.12: a few windows side by side (pull request #252; run 38708392030 on a hosted Mac, 32 checks of 32)

| | |
|---|---|
| The line under the rows; three ticked by ⌘↩; two by ⌘-click and ⇧-click; a fifth refused. ✔ The number in its circle reads at a glance, on the selected row too; the note makes way; nothing jumps. (This run has Reduce Transparency on, as the runners come.) | <a href="side-by-side-ticks.png"><img src="side-by-side-ticks.png" width="900"></a> |
| ↩: in the order ticked, filling the screen | <a href="side-by-side-docked.png"><img src="side-by-side-docked.png" width="440"></a> |
| One of two was in the Dock: the other is in its half at once, the place beside it kept open while macOS flies the window out; then both | <a href="side-by-side-place-kept-open.png"><img src="side-by-side-place-kept-open.png" width="440"></a> <a href="side-by-side-both-there.png"><img src="side-by-side-both-there.png" width="440"></a> |

### From other lanes' runs, looked at here

| | |
|---|---|
| **The menu after #81** (hosted Mac, 1024 by 768): an ordinary day 486 points, the most lines there can be 593, paused 152; it was 822 and scrolled. ✔ The ways out are always on screen; three submenus hold what is rarely wanted; nothing is cut. ◐ The two sentences that say what is the matter are greyed items, which is macOS's grey for what cannot be chosen (1.9 to 1): with the product owner. | <a href="after-menu.png"><img src="after-menu.png" width="900"></a> |
| **The settings window after #207**: ✔ behind Advanced the rows have their lines and the room of the rows above, and "Pause for" stands at the left with the others [39]; Calls seen for the first time, reads well. ◐ Gestures: with the master switch off, as it ships, the four switches under it still look on; General with Advanced open scrolls for seven points; the sidebar's Search is a plain field without a magnifying glass. | <a href="after-settings.png"><img src="after-settings.png" width="900"></a> |

### For the product owner: the drop preview, four ways

Drawn by AppKit without a screen, at two pixels to the point (shown at half size), over pale, busy and accent-coloured content, light and dark. From the left: as it is, over the dragged window; under it, with the window's corners; under it, three points out, radius 20; the system's own, white, under it.

<a href="preview-variants.png"><img src="preview-variants.png" width="1100"></a>

The eyes' verdict, and the product owner's (2026-10-15): **the second**. Under the window the thing in the hand stays what it is; the window's own corners say "a window will be here"; the accent says "Arbor". The system's white vanishes over pale content in the light look.

**The rows below are the first run's, before #190.** They will be taken again as two tours, "as it ships" and "the options", once the defaults of the second build (less by default: no ring, one icon, no motion, no surface) are on the trunk.

## In the menu bar

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **The menu bar item: back, forward, the Desktop, everything, saved views, the menu** | <a href="bar-buttons-light.png"><img src="bar-buttons-light.png" width="240"></a> | <a href="bar-buttons-dark.png"><img src="bar-buttons-dark.png" width="240"></a> | <a href="bar-buttons-contrast.png"><img src="bar-buttons-contrast.png" width="240"></a> | ✔ Glyphs are sharp, evenly spaced, in the menu bar's own ink; the view you are in has a quiet plate. Seven controls are a lot for a menu bar, but each is one a person asked for by saving a view. |
| **The same with nine saved views** | <a href="bar-nine-light.png"><img src="bar-nine-light.png" width="240"></a> |  |  | ◐ 290 points wide. Every view that equals the present one is marked, which here is seven of nine: right, and odd to see. |
| **As a single icon, before anything is docked** | <a href="bar-icon-light.png"><img src="bar-icon-light.png" width="240"></a> | <a href="bar-icon-dark.png"><img src="bar-icon-dark.png" width="240"></a> | <a href="bar-icon-contrast.png"><img src="bar-icon-contrast.png" width="240"></a> | ✔ Reads as a layout at 16 points. |
| **Paused, with the line that says so** | <a href="bar-paused-light.png"><img src="bar-paused-light.png" width="240"></a> | <a href="bar-paused-dark.png"><img src="bar-paused-dark.png" width="240"></a> | <a href="bar-paused-contrast.png"><img src="bar-paused-contrast.png" width="240"></a> | ✔ Dimmed, still findable. The line says until when, and that the windows are back. |
| **A button's help tag** | <a href="bar-tooltip-light.png"><img src="bar-tooltip-light.png" width="240"></a> |  |  | ✔ macOS's own. |
| **The menu** | <a href="menu-light.png"><img src="menu-light.png" width="240"></a> | <a href="menu-dark.png"><img src="menu-dark.png" width="240"></a> | <a href="menu-contrast.png"><img src="menu-contrast.png" width="240"></a> | ◐ macOS's own menu, tinted by what lies behind it as every menu of macOS 26 is. About 820 points high: on this display the ways out are below the fold [2]. ↑ and ↓ come out as small triangles [3]. |
| **The whole menu, on 1600 by 900** | <a href="menu-whole-light.png"><img src="menu-whole-light.png" width="240"></a> |  |  | ✔ Four headed groups, then Pause and Quit. 705 points. |
| **Saved Views ▸** | <a href="menu-saved-views-light.png"><img src="menu-saved-views-light.png" width="240"></a> |  |  | ✔ A heading, nine views with their keys, Name This Space… |
| **Dock Focused Window ▸** | <a href="menu-dock-light.png"><img src="menu-dock-light.png" width="240"></a> |  |  | ✔ The edge it is at already is greyed. Move to Next Display stands apart. |
| **Adjust ▸** | <a href="menu-adjust-light.png"><img src="menu-adjust-light.png" width="240"></a> |  |  | ✔  |
| **Help ▸** | <a href="menu-help-light.png"><img src="menu-help-light.png" width="240"></a> |  |  | ✔  |
| **About Arbor** | <a href="about-light.png"><img src="about-light.png" width="240"></a> |  |  | ◐ macOS's own panel. “Free and open source (MIT)” and, two lines on, “MIT License”. |
| **The menu while paused** | <a href="menu-paused-light.png"><img src="menu-paused-light.png" width="240"></a> |  |  | ✔ One line of plain words, then the way out. |
| **The menu without Accessibility permission** | <a href="menu-no-permission-light.png"><img src="menu-no-permission-light.png" width="240"></a> |  |  | ✔  |
| **The app icon** | <a href="icon-light.png"><img src="icon-light.png" width="240"></a> |  |  | ✔ Holds down to 16 points, where the two small squares become one. |

## At rest: what lies around the windows

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **The line round the focused window, and the surface behind two columns** | <a href="ring-light.png"><img src="ring-light.png" width="240"></a> | <a href="ring-dark.png"><img src="ring-dark.png" width="240"></a> | <a href="ring-contrast.png"><img src="ring-contrast.png" width="240"></a> | ◐ Three points of the accent colour in the gap, concentric with the window's corners. On a bright wallpaper the surface reads as a thick dark frame round each column, not as one surface [24]. |
| **The line's corners at two pixels to the point** | <a href="ring-2x-light.png"><img src="ring-2x-light.png" width="240"></a> |  |  | ✔ Crisp, concentric, no wallpaper between window and line. |
| **The same arrangement without the surface (`dimBehindArranged` 0)** | <a href="surface-none-light.png"><img src="surface-none-light.png" width="240"></a> | <a href="surface-none-dark.png"><img src="surface-none-dark.png" width="240"></a> |  | ✔ For comparison. |
| **Blur behind docked windows (off as it ships)** | <a href="surface-blur-light.png"><img src="surface-blur-light.png" width="240"></a> |  |  | ? Taken with Reduce Transparency on, so it shows nothing [19]. In the gallery's next run. |
| **Tint behind docked windows (off as it ships)** | <a href="surface-tint-light.png"><img src="surface-tint-light.png" width="240"></a> |  |  | ✔  |
| **The hairline round the Desktop** | <a href="desktop-edge-light.png"><img src="desktop-edge-light.png" width="240"></a> | <a href="desktop-edge-dark.png"><img src="desktop-edge-dark.png" width="240"></a> |  | ◐ At its default it cannot be seen on this wallpaper, which does no harm. The picture also shows a floated window lying behind a docked one, slivers of it in the margins [23]. |
| **Tiles as they ship with #79: two windows of one app, the Desktop's, a group's** | <a href="tiles-light.png"><img src="tiles-light.png" width="240"></a> | <a href="tiles-dark.png"><img src="tiles-dark.png" width="240"></a> | <a href="tiles-contrast.png"><img src="tiles-contrast.png" width="240"></a> | ✔ **The two can be told apart**: “Untitled”, “Notes on oaks”. Calm plates with the window's corners and shadow; 11 points, legible in all three looks; the group's miniature and its count read at once. |
| **A tile's help tag** | <a href="tile-tag-light.png"><img src="tile-tag-light.png" width="240"></a> | <a href="tile-tag-dark.png"><img src="tile-tag-dark.png" width="240"></a> | <a href="tile-tag-contrast.png"><img src="tile-tag-contrast.png" width="240"></a> | ✔ macOS's own tag, and it does come up over a panel of an app that is never active. Where the caption is drawn whole it says the same twice, and covers it. |
| **The same a moment later: the view is held** | <a href="tiles-held-light.png"><img src="tiles-held-light.png" width="240"></a> | <a href="tiles-held-dark.png"><img src="tiles-held-dark.png" width="240"></a> | <a href="tiles-held-contrast.png"><img src="tiles-held-contrast.png" width="240"></a> | ✔ The titles are gone from the tiles, and from the tag that was up: the app's name stands in. The menu bar item has become the hold's. |
| **Tiles with icons alone (`tileStyle` `icon`)** | <a href="tiles-icons-light.png"><img src="tiles-icons-light.png" width="240"></a> | <a href="tiles-icons-dark.png"><img src="tiles-icons-dark.png" width="240"></a> | <a href="tiles-icons-contrast.png"><img src="tiles-icons-contrast.png" width="240"></a> | ✔ What shipped before #79: two tiles alike [29]. |
| **Two Safari windows on a laptop's 1440 points, one a tile; a tile 63 points wide** | <a href="tiles-laptop-light.png"><img src="tiles-laptop-light.png" width="240"></a> | <a href="tiles-laptop-dark.png"><img src="tiles-laptop-dark.png" width="240"></a> |  | ✔ The board's measure. “Shopping” fits whole into 63 points and is drawn. |
| **Tiles at two pixels to the point** | <a href="tiles-2x-light.png"><img src="tiles-2x-light.png" width="240"></a> |  |  | ✔  |
| **Tiles without icons** | <a href="tiles-plain-light.png"><img src="tiles-plain-light.png" width="240"></a> |  |  | ✔  |
| **Tiles without the app's colour** | <a href="tiles-grey-light.png"><img src="tiles-grey-light.png" width="240"></a> | <a href="tiles-grey-dark.png"><img src="tiles-grey-dark.png" width="240"></a> |  | ◐ Nearly white in the light look: the brightest thing on the screen. |
| **Tiles in the app's full colour** | <a href="tiles-colour-light.png"><img src="tiles-colour-light.png" width="240"></a> | <a href="tiles-colour-dark.png"><img src="tiles-colour-dark.png" width="240"></a> |  | ✔  |
| **A tile the size of a window (its app refused the place)** | <a href="tile-large-light.png"><img src="tile-large-light.png" width="240"></a> |  |  | ✔  |
| **The handle in a gap, under the pointer** | <a href="gap-hover-light.png"><img src="gap-hover-light.png" width="240"></a> | <a href="gap-hover-dark.png"><img src="gap-hover-dark.png" width="240"></a> | <a href="gap-hover-contrast.png"><img src="gap-hover-contrast.png" width="240"></a> | ◐ A white pill with a soft shadow: shows on any wallpaper. The pointer stays an arrow [20]. |
| **The handle while it is dragged** | <a href="gap-dragged-light.png"><img src="gap-dragged-light.png" width="240"></a> |  |  | ✔ Accent colour. |
| **A gap with a floating window behind it** | <a href="gap-covered-light.png"><img src="gap-covered-light.png" width="240"></a> |  |  | ✘ The floating window shows through the gap and takes the press: no handle, no resize [4]. |
| **One window framed** | <a href="framed-light.png"><img src="framed-light.png" width="240"></a> | <a href="framed-dark.png"><img src="framed-dark.png" width="240"></a> |  | ✔  |

## With real apps

Ten of Apple's own apps on the hosted Mac.

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **Each window a tile** | <a href="apps-tiles-light.png"><img src="apps-tiles-light.png" width="240"></a> | <a href="apps-tiles-dark.png"><img src="apps-tiles-dark.png" width="240"></a> |  | ✔ The first look at real icons and the colours Arbor takes from them: each tile is plainly its app's, none shouts. “Start Page”, “runner — -bash — 21×11”, “Connection Issue.”: titles say what names could not. |
| **Each column a group's tile** | <a href="apps-groups-light.png"><img src="apps-groups-light.png" width="240"></a> |  |  | ✔ Miniatures in the apps' colours with their icons, and a count. |
| **Go to…** | <a href="apps-go-to-light.png"><img src="apps-go-to-light.png" width="240"></a> | <a href="apps-go-to-dark.png"><img src="apps-go-to-dark.png" width="240"></a> |  | ◐ Icons help where names and titles repeat each other (“Music  Music”). |
| **The minimap** | <a href="apps-minimap-light.png"><img src="apps-minimap-light.png" width="240"></a> | <a href="apps-minimap-dark.png"><img src="apps-minimap-dark.png" width="240"></a> |  | ✔ In the apps' colours it reads as the arrangement at once. |

## While something is dragged

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **The drop preview** | <a href="preview-light.png"><img src="preview-light.png" width="240"></a> | <a href="preview-dark.png"><img src="preview-dark.png" width="240"></a> | <a href="preview-contrast.png"><img src="preview-contrast.png" width="240"></a> | ✘ It lies over the window that is being dragged: tints it, and its border crosses the title bar [1]. Since #17 a second, light line inside the accent one shows on any content [21]. |
| **Beside macOS's own tiling preview, at two pixels to the point (before #28, when both answered one drag)** | <a href="preview-system-light.png"><img src="preview-system-light.png" width="240"></a> |  |  | ◐ The system's: a white line of two points, a radius of about twenty, under the window in the hand [37]. |
| **The rectangle of a ⌃⌥-drag** | <a href="band-light.png"><img src="band-light.png" width="240"></a> |  |  | ✘ Before #17: accent colour on content of that colour, all but invisible [21]. The picture after it is owed. |

## What Arbor says

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **The line on screen: a key that could not act** | <a href="line-problem-light.png"><img src="line-problem-light.png" width="240"></a> | <a href="line-problem-dark.png"><img src="line-problem-dark.png" width="240"></a> | <a href="line-problem-contrast.png"><img src="line-problem-contrast.png" width="240"></a> | ✔ Low and centred, 15 points, clear of the Dock; takes no click. 5 to 1 and better over the reddest of windows. |
| **A sentence that names keys** | <a href="line-sentence-light.png"><img src="line-sentence-light.png" width="240"></a> | <a href="line-sentence-dark.png"><img src="line-sentence-dark.png" width="240"></a> | <a href="line-sentence-contrast.png"><img src="line-sentence-contrast.png" width="240"></a> | ✔  |
| **A hint** | <a href="line-hint-light.png"><img src="line-hint-light.png" width="240"></a> | <a href="line-hint-dark.png"><img src="line-hint-dark.png" width="240"></a> | <a href="line-hint-contrast.png"><img src="line-hint-contrast.png" width="240"></a> | ◐ Since #17 the keys to press are as plain as the sentence [17]. The spec says capsule; the corners are 12 points on 38 [18]. |
| **The line at two pixels to the point** | <a href="line-2x-light.png"><img src="line-2x-light.png" width="240"></a> |  |  | ✔  |
| **The panel of shortcuts** | <a href="sheet-light.png"><img src="sheet-light.png" width="240"></a> | <a href="sheet-dark.png"><img src="sheet-dark.png" width="240"></a> | <a href="sheet-contrast.png"><img src="sheet-contrast.png" width="240"></a> | ✘ Keys end and titles begin on one line down each column; nothing clipped; the rows read well (5 to 1). The headings (1.4 to 2.1 to 1) and “Press any key to close” (1.4) do not [35]. Corners of 12 points on a panel this size are those of an older macOS [25]. |
| **The panel at its own size, at two pixels to the point** | <a href="sheet-2x-light.png"><img src="sheet-2x-light.png" width="240"></a> |  |  | ◐ Handsome, and three colours at once. |
| **The panel with the person's own shortcuts** | <a href="sheet-own-light.png"><img src="sheet-own-light.png" width="240"></a> |  |  | ✔ One rebound digit unfolds “1–9” into nine lines: long, and true. |

## Panels that take the keyboard

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **Go to…** | <a href="go-to-light.png"><img src="go-to-light.png" width="240"></a> | <a href="go-to-dark.png"><img src="go-to-dark.png" width="240"></a> | <a href="go-to-contrast.png"><img src="go-to-contrast.png" width="240"></a> | ✘ **The first sight of it.** The field's own words cannot be read (1.1 to 1); the titles, which are what tells six windows of one app apart, are the fainter half of each row (1.9 to 2.4); the notes at the right are all but gone (1.1 to 1.4) [35]. With Increase Contrast everything is plain. |
| **The same as the window server hands it over, without what is behind it** | <a href="go-to-alone-light.png"><img src="go-to-alone-light.png" width="240"></a> | <a href="go-to-alone-dark.png"><img src="go-to-alone-dark.png" width="240"></a> | <a href="go-to-alone-contrast.png"><img src="go-to-alone-contrast.png" width="240"></a> | ✔ The layout is sound: one line a row, icon, app, title, note; the selected row concentric with the panel. |
| **Nothing matches** | <a href="go-to-none-light.png"><img src="go-to-none-light.png" width="240"></a> | <a href="go-to-none-dark.png"><img src="go-to-none-dark.png" width="240"></a> | <a href="go-to-none-contrast.png"><img src="go-to-none-contrast.png" width="240"></a> | ✔ Shrinks to the field and two words. |
| **At two pixels to the point, with two displays** | <a href="go-to-2x-light.png"><img src="go-to-2x-light.png" width="240"></a> |  |  | ◐ “in view, on Arbor Test Display”: the longest note is the faintest text. |
| **The field for a name, empty** | <a href="name-light.png"><img src="name-light.png" width="240"></a> | <a href="name-dark.png"><img src="name-dark.png" width="240"></a> | <a href="name-contrast.png"><img src="name-contrast.png" width="240"></a> | ✔ **First sight.** Its labels are macOS's own and take on the ground's colour, which keeps them at 4 to 5 to 1 where Go to…'s grey falls to 2 [35]. |
| **…and typed into** | <a href="name-typed-light.png"><img src="name-typed-light.png" width="240"></a> | <a href="name-typed-dark.png"><img src="name-typed-dark.png" width="240"></a> | <a href="name-typed-contrast.png"><img src="name-typed-contrast.png" width="240"></a> | ✔ The line under the field says what ↩ will do. |
| **The minimap** | <a href="minimap-light.png"><img src="minimap-light.png" width="240"></a> | <a href="minimap-dark.png"><img src="minimap-dark.png" width="240"></a> | <a href="minimap-contrast.png"><img src="minimap-contrast.png" width="240"></a> | ✘ **First sight.** In the light look it reads at once: the view marked, the rest paler. In the dark look over a strong colour what is out of view all but merges with the ground [36]. |
| **Peek's outline** | <a href="peek-light.png"><img src="peek-light.png" width="240"></a> | <a href="peek-dark.png"><img src="peek-dark.png" width="240"></a> | <a href="peek-contrast.png"><img src="peek-contrast.png" width="240"></a> | ✘ **First sight.** The outline and the line round the focused window, both accent blue, round two windows at once [38]. |

## The settings window

Each pane by itself, as the window server hands it over. All since #17.

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **The window over an arrangement** | <a href="settings-on-screen-light.png"><img src="settings-on-screen-light.png" width="240"></a> |  | <a href="settings-on-screen-contrast.png"><img src="settings-on-screen-contrast.png" width="240"></a> | ✔ Opens in front, centred. The sidebar lets a little of the red window through, as macOS's own do. |
| **General** | <a href="settings-general-light.png"><img src="settings-general-light.png" width="240"></a> | <a href="settings-general-dark.png"><img src="settings-general-dark.png" width="240"></a> | <a href="settings-general-contrast.png"><img src="settings-general-contrast.png" width="240"></a> | ✔ A grouped form as macOS draws it. Restore Defaults is a bar under the form [14]; the sidebar is one shade in the dark look [26]. |
| **General, Advanced open** | <a href="settings-general-advanced-light.png"><img src="settings-general-advanced-light.png" width="240"></a> | <a href="settings-general-advanced-dark.png"><img src="settings-general-advanced-dark.png" width="240"></a> | <a href="settings-general-advanced-contrast.png"><img src="settings-general-advanced-contrast.png" width="240"></a> | ◐ **Nobody had seen an advanced row** [27]. They stand closer together than the rows above and have no lines between them. |
| **Windows** | <a href="settings-windows-light.png"><img src="settings-windows-light.png" width="240"></a> | <a href="settings-windows-dark.png"><img src="settings-windows-dark.png" width="240"></a> | <a href="settings-windows-contrast.png"><img src="settings-windows-contrast.png" width="240"></a> | ✔ Plain words [8]. |
| **Windows, Advanced open** | <a href="settings-windows-advanced-light.png"><img src="settings-windows-advanced-light.png" width="240"></a> | <a href="settings-windows-advanced-dark.png"><img src="settings-windows-advanced-dark.png" width="240"></a> | <a href="settings-windows-advanced-contrast.png"><img src="settings-windows-advanced-contrast.png" width="240"></a> | ✔  |
| **Dragging** | <a href="settings-dragging-light.png"><img src="settings-dragging-light.png" width="240"></a> | <a href="settings-dragging-dark.png"><img src="settings-dragging-dark.png" width="240"></a> | <a href="settings-dragging-contrast.png"><img src="settings-dragging-contrast.png" width="240"></a> | ✔ 30 % [12]. |
| **Gestures** | <a href="settings-gestures-light.png"><img src="settings-gestures-light.png" width="240"></a> | <a href="settings-gestures-dark.png"><img src="settings-gestures-dark.png" width="240"></a> | <a href="settings-gestures-contrast.png"><img src="settings-gestures-contrast.png" width="240"></a> | ◐ Modifier keys are typed as `ctrl+opt` [15]. |
| **Gestures, Advanced open** | <a href="settings-gestures-advanced-light.png"><img src="settings-gestures-advanced-light.png" width="240"></a> | <a href="settings-gestures-advanced-dark.png"><img src="settings-gestures-advanced-dark.png" width="240"></a> | <a href="settings-gestures-advanced-contrast.png"><img src="settings-gestures-advanced-contrast.png" width="240"></a> | ✔  |
| **Calls** | <a href="settings-calls-light.png"><img src="settings-calls-light.png" width="240"></a> | <a href="settings-calls-dark.png"><img src="settings-calls-dark.png" width="240"></a> | <a href="settings-calls-contrast.png"><img src="settings-calls-contrast.png" width="240"></a> | ✔ **First sight.** Says what it reads from macOS and that it opens no camera itself. |
| **Appearance** | <a href="settings-appearance-light.png"><img src="settings-appearance-light.png" width="240"></a> | <a href="settings-appearance-dark.png"><img src="settings-appearance-dark.png" width="240"></a> | <a href="settings-appearance-contrast.png"><img src="settings-appearance-contrast.png" width="240"></a> | ✔ 25 %; “color” [22]; Tiles show: The icon and the name. |
| **Appearance, Advanced open** | <a href="settings-appearance-advanced-light.png"><img src="settings-appearance-advanced-light.png" width="240"></a> | <a href="settings-appearance-advanced-dark.png"><img src="settings-appearance-advanced-dark.png" width="240"></a> | <a href="settings-appearance-advanced-contrast.png"><img src="settings-appearance-advanced-contrast.png" width="240"></a> | ✔  |
| **Menu Bar** | <a href="settings-menu-bar-light.png"><img src="settings-menu-bar-light.png" width="240"></a> | <a href="settings-menu-bar-dark.png"><img src="settings-menu-bar-dark.png" width="240"></a> | <a href="settings-menu-bar-contrast.png"><img src="settings-menu-bar-contrast.png" width="240"></a> | ✔  |
| **Menu Bar, Advanced open** | <a href="settings-menu-bar-advanced-light.png"><img src="settings-menu-bar-advanced-light.png" width="240"></a> | <a href="settings-menu-bar-advanced-dark.png"><img src="settings-menu-bar-advanced-dark.png" width="240"></a> | <a href="settings-menu-bar-advanced-contrast.png"><img src="settings-menu-bar-advanced-contrast.png" width="240"></a> | ✔  |
| **Apps** | <a href="settings-apps-light.png"><img src="settings-apps-light.png" width="240"></a> | <a href="settings-apps-dark.png"><img src="settings-apps-dark.png" width="240"></a> | <a href="settings-apps-contrast.png"><img src="settings-apps-contrast.png" width="240"></a> | ✔ Bundle ids only because the sample apps are not installed. |
| **Apps, Advanced open** | <a href="settings-apps-advanced-light.png"><img src="settings-apps-advanced-light.png" width="240"></a> | <a href="settings-apps-advanced-dark.png"><img src="settings-apps-advanced-dark.png" width="240"></a> | <a href="settings-apps-advanced-contrast.png"><img src="settings-apps-advanced-contrast.png" width="240"></a> | ✘ “Pause for” stands a hundred points to the right of everything else [39]. |
| **Scripting** | <a href="settings-scripting-light.png"><img src="settings-scripting-light.png" width="240"></a> | <a href="settings-scripting-dark.png"><img src="settings-scripting-dark.png" width="240"></a> | <a href="settings-scripting-contrast.png"><img src="settings-scripting-contrast.png" width="240"></a> | ✔  |
| **Shortcuts** | <a href="settings-shortcuts-light.png"><img src="settings-shortcuts-light.png" width="240"></a> | <a href="settings-shortcuts-dark.png"><img src="settings-shortcuts-dark.png" width="240"></a> | <a href="settings-shortcuts-contrast.png"><img src="settings-shortcuts-contrast.png" width="240"></a> | ✔ The menu's titles, the script's word small beneath, in headed groups [7] [13]. |
| **Rules** | <a href="settings-rules-light.png"><img src="settings-rules-light.png" width="240"></a> | <a href="settings-rules-dark.png"><img src="settings-rules-dark.png" width="240"></a> | <a href="settings-rules-contrast.png"><img src="settings-rules-contrast.png" width="240"></a> | ✔  |
| **Recording a shortcut** | <a href="settings-recording-light.png"><img src="settings-recording-light.png" width="240"></a> |  |  | ✔  |
| **Keys that another command has** | <a href="settings-clash-light.png"><img src="settings-clash-light.png" width="240"></a> | <a href="settings-clash-dark.png"><img src="settings-clash-dark.png" width="240"></a> |  | ◐ Before #17: “runs desktop now” [11]. |
| **Keys that every app would lose** | <a href="settings-caution-light.png"><img src="settings-caution-light.png" width="240"></a> |  |  | ✔  |
| **A search** | <a href="settings-search-light.png"><img src="settings-search-light.png" width="240"></a> |  |  | ◐ Before #17: “ring” also finds “during a call” [16]. |
| **A value that is refused** | <a href="settings-refused-light.png"><img src="settings-refused-light.png" width="240"></a> | <a href="settings-refused-dark.png"><img src="settings-refused-dark.png" width="240"></a> |  | ◐ Before #17: “`gap` must be…” under the field called Gap [9]. |
| **settings.json cannot be read** | <a href="settings-broken-light.png"><img src="settings-broken-light.png" width="240"></a> | <a href="settings-broken-dark.png"><img src="settings-broken-dark.png" width="240"></a> |  | ✔ Said above everything, with both ways out as buttons. |
| **…and asks before it replaces the file** | <a href="settings-broken-asks-light.png"><img src="settings-broken-asks-light.png" width="240"></a> |  |  | ✔  |

## Other windows

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **The answer to Check for Updates…** | <a href="update-light.png"><img src="update-light.png" width="240"></a> | <a href="update-dark.png"><img src="update-dark.png" width="240"></a> | <a href="update-contrast.png"><img src="update-contrast.png" width="240"></a> | ✘ **First sight.** The words are right. The buttons touch the window's bottom edge: twenty points of margin are missing [40]. Beside macOS 26's own alert (in many of these pictures) it is a window from another decade. |
| **The welcome window, Check Setup** |  |  |  | ○ Lane H looks at the first run. |
| **Tab strips** |  |  |  | ○ Lane J; not on the trunk yet. |

## Motion

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **A window framed: pictures about 160 ms apart** | <a href="motion-light.png"><img src="motion-light.png" width="240"></a> |  |  | ✘ **First sight.** A red window travels as a dark green card with an icon 150 points high, and turns red again on arrival. At rest the same stand-in, a tile, is pale with an icon of 48: two looks for one thing [42]. |
| **The card gives way to the window** | <a href="motion-fade-light.png"><img src="motion-fade-light.png" width="240"></a> | <a href="motion-fade-dark.png"><img src="motion-fade-dark.png" width="240"></a> |  | ✔ A cross-fade, in place. |
| **A tile fading in** | <a href="tile-fade-light.png"><img src="tile-fade-light.png" width="240"></a> |  |  | ✔  |

## Other looks

| What | Light | Dark | Increase Contrast | Verdict |
|---|---|---|---|---|
| **Increase Contrast, dark** | <a href="contrast-light.png"><img src="contrast-light.png" width="240"></a> | <a href="contrast-dark.png"><img src="contrast-dark.png" width="240"></a> | <a href="contrast-contrast.png"><img src="contrast-contrast.png" width="240"></a> | ✔ The whole tour was taken in both looks; the light one is the fourth column of every row. Everything can be read, and macOS itself draws an outline round every panel and every tile. Nothing in Arbor's sources asks whether it is on, and little needs to. |
| **Reduce Transparency** | <a href="opaque-light.png"><img src="opaque-light.png" width="240"></a> |  |  | ✔ What every earlier picture showed [19]. Flat, and legible throughout. |

## Findings

How bad: **1** cannot be read or used · **2** looks wrong to anybody · **3** not as macOS would do it · **4** polish · **P** for the product owner · **—** no fault of Arbor's.

| # | What | Picture | What is wrong | How bad | State |
|---|---|---|---|---|---|
| 1 | Drop preview | preview | Drawn over the dragged window. Cure: at the normal level, ordered just under that window, as the focus ring is ordered just over its own. Touches `OverlayPresenter` and every script that finds the preview by its level | 3 | decided, with [37] |
| 2 | Menu | menu | 29 rows, about 820 points. With two state lines it would not fit 900. On a small display the ways out at its end scroll out of sight | P | #81; **seen**: 486 points on an ordinary day, 593 at the most |
| 3 | Menu | menu | ↑ and ↓ show as small solid triangles. The key equivalents are AppKit's own, so this may be macOS 26's way: to be compared with Finder's Go menu | 4 | open |
| 4 | Gap handle | gap-covered | Handles are ordered behind everything at their level, so a floating window that lies behind the docked ones owns the gap. Two checks of `shots-demo.sh` are red for it | 3 | open |
| 5 | Line on screen | line-stale | A command that needs no line of its own leaves the last one up, though it may no longer be true. A test holds it so (`aSilentCommandLeavesTheLineAlone`) | P | landed with #50 |
| 6 | `shots-F10.sh` | menu-help | Type-select goes astray where the menu scrolls; `23-about-own` takes the focus ring for the About panel | — | done: `large-01` to `large-06` |
| 7 | Settings, Shortcuts | settings-shortcuts | Script names instead of the menu's titles | 2 | landed with #17; **seen to work** in the gallery's run |
| 8 | Settings, help | settings-windows, settings-appearance, settings-search | Backticks drawn as backticks; the file's names for choices; “not yet seen at work on a Mac”, “written from memory” | 2 | landed with #17; **seen to work** in the gallery's run |
| 9 | Settings, refusals | settings-refused | The terminal's words under the control | 3 | landed with #17; its state is not in the gallery's tour, so the picture after it is owed |
| 10 | Settings, refusals | settings-stale | A refusal made because of the file outlives the file | 2 | landed with #17; its state is not in the gallery's tour, so the picture after it is owed |
| 11 | Settings, clash | settings-clash | “runs desktop now” | 3 | landed with #17; its state is not in the gallery's tour, so the picture after it is owed |
| 12 | Settings, shares | settings-appearance, settings-dragging | 0.25 and 0.3 where a person thinks 25 % and 30 % | 4 | landed with #17; **seen to work** in the gallery's run |
| 13 | Settings, Shortcuts | settings-shortcuts | No groups | 4 | landed with #17; **seen to work** in the gallery's run |
| 14 | Settings, Restore Defaults | settings-general | A card of its own, empty but for a greyed button | 4 | landed with #17; **seen to work** in the gallery's run |
| 15 | Settings, text fields | settings-gestures | Modifier keys and a colour are typed as text | 4 | open |
| 16 | Settings, search | settings-search | Matches inside words | 4 | landed with #17; its state is not in the gallery's tour, so the picture after it is owed |
| 17 | Line on screen | line-hint | The hint's contrast is 3.1 and 3.6 to 1; 4.5 is what text of that size needs | 3 | landed with #17; **seen to work** in the gallery's run |
| 18 | Line on screen | line-hint | Not the capsule the spec asks for | 4 | #190; **seen**: a capsule |
| 19 | Hosted Macs | surface-blur | **Corrected.** Materials came out flat because the runners come with Reduce Transparency switched on, as they come with Reduce Motion. Switched off before Arbor starts, blur and translucency are drawn | — | the gallery switches it off; the other scripts do not yet |
| 20 | Gap handle | gap-hover | No resize pointer: macOS lets only the active app set the pointer, and Arbor never is | 3 | no cure in public API |
| 21 | Rectangle, preview | band | Accent colour alone vanishes on content of that colour. Cure: a light line inside the accent one | 3 | landed with #17; seen on the preview and on peek's outline; the rectangle's picture is owed |
| 22 | Spelling | sheet, settings-appearance | “Neighbouring”, “colour” in an app whose system says “color” | P | #85; seen in the gallery's run |
| 23 | Floating windows | desktop-edge | A window floated by a command with its number stays behind the docked ones. A person's Float acts on the window in front, so this may be the script's doing | — | open |
| 24 | Surface | surface | Two columns: two frames, not one surface | P | decided (2026-10-15): `dimBehindArranged` ships 0, and stays an option |
| 25 | Corner radii |  | 12 (line, panel of shortcuts, minimap), 14 (name), 16 (Go to…), 17 (what stands for a window) | 4 | #190; **seen**: 20 for panels, a capsule for the line, from one table |
| 26 | Settings, sidebar | settings-general | Three shades in the dark look | 3 | landed with #17; **seen to work** in the gallery's run |
| 27 | Settings, Advanced | settings-advanced | Only the triangle opens it, seven points of a line that looks like a button | 3 | landed with #17; **seen to work** in the gallery's run |
| 28 | Settings, number fields | settings-slider | A field with the keyboard follows neither its slider nor a change from outside. Four checks of `shots-F12.sh` are red for it | 2 | landed with #17; its state is not in the gallery's tour, so the picture after it is owed |
| 29 | Tiles | overview | Two windows of one app: two tiles alike. Only a click tells which is which | 2 | #79; **seen to work**: titles, the help tag, the app's name the moment a hold begins |
| 30 | Line on screen |  | From the films: after a dock into two columns the line lies astride the gap, half on each window | 4 | open; macOS's own panels are centred too |
| 31 | Line on screen |  | From the films: “Too small to show: click the tile” stands at the foot of the display, far from the tile it speaks of | 3 | open |
| 32 | Saved views |  | From the films: a view of two windows of one app is listed as “Safari and Safari” | 3 | landed with #104 |
| 33 | Focus ring |  | From the films: when its window is dragged off, the ring stays behind as an empty outline for 100 ms | 3 | open |
| 34 | Out of view |  | From the films: a line one pixel wide of the windows out of view shows at the right edge, beside the Dock | 3 | open |
| 35 | Text on translucent panels | go-to, sheet | What Arbor draws itself in macOS's secondary and tertiary greys stays grey whatever the ground has become. Over a red or a blue window: Go to…'s placeholder 1.1 to 1, its titles 1.9 to 2.4, its notes 1.1 to 1.4; the panel of shortcuts' headings 1.4 to 2.1, its last line 1.4 to 3.8. Main text holds 5 to 8. The field for a name uses macOS's own labels, which take on the ground's colour, and holds 4 to 5 | 1 | #190; **seen and measured**: the table at the top |
| 36 | Minimap | minimap | In the dark look over a strong colour the windows out of view merge with the ground; with Increase Contrast they are dark green on black | 2 | #190; **seen**: an edge for every plate out of view |
| 37 | Drop preview | preview-system | macOS's own tiling preview: a neutral white line of two points, a radius of about twenty, under the window | P | decided: under the window in the hand, the window's own corners, the accent with its light line inside; to be built when a drag with ⌘ is what asks for it |
| 38 | Peek | peek | Two frames in one colour at once: the outline, and the line round the focused window | 3 | landed with #130 |
| 39 | Settings, Apps | settings-apps-advanced | Behind Advanced, “Pause for” and its list stand a hundred points to the right of everything else | 3 | #207; **seen to work** |
| 40 | Update window | update | The buttons touch the bottom edge: the window is some twenty points too short for what it holds | 2 | #190; **seen**: macOS's own alert |
| 41 | The gallery itself |  | Its stand-in for GitHub (`python3 -m http.server`) brings up macOS's alert about local networks, which stays in front for the rest of the job; the update window stays open under the pictures of the line; “3” matches no title since the titles changed; no preview came up for the drag on the Retina display | — | mended for the next run |
| 42 | Motion | motion | What stands for a window has two looks: at rest a pale plate (a quarter of the app's colour) with an icon of 48 points, in motion a card in the app's full colour with an icon that grows to 150. A red window turns dark green and back | 2 | shelved: motion ships off in the second build. Written and read: branch `feat/the-card-is-the-tile` |
| 44 | Update alert |  | “…Could not connect to the server..”: macOS's own words end in a full stop, and Arbor adds one | 4 | #190 |
| 45 | Go to… |  | The magnifying glass in the second ink: 2.75 to 3.0 to 1 in the light look, its ring being one point thin | 4 | #190: in the main ink |
| 46 | The gallery itself |  | The ⌃⌥-drag of the second run drew no rectangle (five checks red); `nc` had not begun to listen in two of five tours, so the alert says that GitHub could not be reached, and stays, there being no Later to click | — | open |
| 43 | A display unplugged |  | A virtual display removed and Arbor quit two seconds later: the four windows that had been on it are under 90 % on screen afterwards. No picture | — | handed to the lane for displays |
