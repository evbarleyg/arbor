# Arbor: the guide

For people who use Arbor, not for people who build it. It describes what is on the trunk today; what is still on its way is
listed at the end, so that nothing here promises more than the build you have. Words are used as in [GLOSSARY.md](GLOSSARY.md); every shortcut
is in [KEYBOARD.md](KEYBOARD.md). Pictures will replace the drawings.

1. [The idea, on one page](#1-the-idea-on-one-page)
2. [The first ten minutes](#2-the-first-ten-minutes)
3. [A day with a browser, a chat, a terminal and calls](#3-a-day-with-a-browser-a-chat-a-terminal-and-calls)
4. [Making it yours](#4-making-it-yours)
5. [When something is wrong](#5-when-something-is-wrong)
6. [On its way](#6-on-its-way)

## 1. The idea, on one page

**Dock windows side by side, then zoom between them.**

A Mac's windows pile up. Arbor lets you give some of them a *place*: drag a window to a screen edge and it **docks** there, sharing the screen with whatever else is docked. Nothing overlaps. What is left
between the docked windows is **the Desktop**, where all your other windows **float** exactly as they always have.

```
+--------------------+....................+--------------------+
| Safari             | the Desktop        | Terminal           |
|                    |   ~~~~~~~~~~~~~~   |                    |
|                    |   ~ a floating ~   |                    |
|                    |   ~ window     ~   +--------------------+
|                    |   ~~~~~~~~~~~~~~   +--------------------+
|                    |                    | Slack              |
|                    |                    |                    |
+--------------------+....................+--------------------+
```

Three windows on a laptop screen are each too small to work in. That is what the second half is for. Think of a camera over this arrangement: it can show **everything**, as above, or move in until one part fills the screen.
Each part the view can fill is a **space**: a single window, a **group** of windows (Terminal and Slack above), the Desktop, or everything. Spaces nest as deep as you like.

```
 everything                     the group                       one window
+------+......+------+         +--------------------+          +--------------------+
|Safari|      | Term |  step   | Terminal           |   step   | Terminal           |
|      |      +------+   in    |                    |    in    |                    |
|      |      +------+  ---->  +--------------------+   ---->  |                    |
|      |      | Slack|         | Slack              |          |                    |
+------+......+------+         +--------------------+          +--------------------+
```

The real windows are resized to fit, so what you see is always the live app at a size you can use.

**Where do the others go?** Out of view. Only a move of the view takes a window out of view: docking, resizing, minimizing or closing something never does. They are not closed, hidden or minimised; they are where a photograph's surroundings are. Zoom out and they are back where they were. Switch to one with ⌘Tab or the Dock and
the view moves to show it: framed stays framed, so from one framed window you land on the other, framed, and ⌃⌥[ takes you back; from a group the view steps out just far enough to show both.

**You can see them go.** Every zoom, dock and close plays as one short motion: zooming in enlarges the whole arrangement, so the others slide out past the edges they live beyond, and zooming out brings them back from there. While they move, windows show their app's colour and icon. A click ends the motion at once; another shortcut carries on from where things are. macOS's "Reduce motion" switches it off, and so does `arborctl set animationDuration 0`.

That is all of it: **dock**, **float**, **zoom**. Everything else is a faster way to do one of the three.

| | Pointer | Keys |
|---|---|---|
| Dock | drag to a screen edge, or hold over another docked window's edge until the preview shows | ⌃⌥⌘ + arrow |
| Float | drag onto the Desktop, or anywhere with ⌘ held (in a view without the Desktop, only ⌘ takes a window out: let go without it, the window goes back to its place) | ⌃⌥F |
| Frame one window | | ⌃⌥↩ (again to return) |
| Step out, step in | with [the gestures switched on](#6-on-its-way): ⌥ + pinch, or pinch on the Desktop; with a mouse, ⌃⌥ + scroll down or up: a notch is one step, a flick goes all the way | ⌃⌥↑, ⌃⌥↓ |
| Show everything | | ⌃⌥Space |
| Peek: from one window to another | point while holding ⌃⌥Space | hold ⌃⌥Space, arrows, let go |
| Take it back | menu → Undo, which names the step ("Undo Dock") | ⌃⌥Z, and ⌃⌥⇧Z to do it again: the last 50 changes to the arrangement, Arrange and Float All among them, with the saved views they cost |

The keys follow one rule: **⌃⌥ looks, ⌃⌥⌘ moves, ⇧ does the opposite or the bigger version.**

### Where Arbor differs on purpose

Arbor was inspired by TrellisWM and is not a copy of it. Three things are different because we think them better, not because they are unfinished:

- **Nothing moves until you dock something.** When Arbor starts, every window stays where it is, at the size it has, and floats. You choose what gets a place. When it starts again later, what *you* docked goes back to its place.
- **Show Everything shows your real windows**, laid out smaller, not pictures of them. You can read, click and type in them at once, and Arbor needs no permission to record your screen. A window that cannot be that small shows as a tile with its app's colour and icon.
- **Nothing of Arbor's lies between your pointer and your windows.** While you drag, the preview is a picture that lets the mouse through: no layer of Arbor's covers the screen, so letting go always reaches the window.

### What Arbor promises

Seven things you can hold Arbor to. Each has a story of its own that is played after every change to Arbor (`collab/scenarios/rule-1…` to `rule-7…`), and examples beside it. Where today's build is known to fall short, it says so here; the whole list is section 1 of `collab/BOARD.md`.

1. **It does not fight macOS.** macOS has tiling of its own, and as it comes it wants the same screen edges and the same drags. Arbor looks before it arranges anything and tells you what it found (the welcome window; menu → Help → Check Setup…; `arborctl doctor`). While macOS's own tiling is on, Arbor stands aside wherever macOS acts: one preview at a time, and what it shows is what happens.
   *Not yet:* putting the switches right is still a walk through System Settings; Arbor will offer to do it in one step, and to put them back.
2. **Nothing moves until you dock something.** Starting Arbor for the first time moves nothing; a later start puts back what you had docked, shows everything, and takes nothing out of view. Nor does a window that opens, closes, goes to the Dock or comes back, an app that is hidden, or time that passes. A window you have not docked is yours: it floats where you left it, at the size you gave it.
   *Not yet:* a dock still pushes floating windows out of its way and can make them narrower, and a window that hangs over the edge of the screen is pulled in the first time anything else changes.
3. **No jolts.** A window moves once, straight to where it ends up. Arbor never pulls at a window you are dragging. Out of view means out of view: nothing flashes.
   *Not yet:* a window whose app refuses the size it is asked for takes a second move the first time Arbor meets it, and so does one that leaves full screen.
4. **The window you switch to is the window you get.** ⌘Tab, a click in the Dock, the Window menu: it comes to the front and into view, and the keyboard is in it. The view moves to it; it is never left behind another window.
5. **It leaves things as it found them.** Float All, Quit and a pause give every window back the size and the place it had before you docked it.
6. **A drag is yours from the press to the release.** The preview is a picture that lets the mouse through. Nothing of Arbor's can take the release, and however a drag ends, nothing is left on the screen that could take your next click.
7. **There is always a way back.** ⌃⌥Space shows everything on this display, ⌃⌥0 on all of them, ⌃⌥D whatever floats, ⌃⌥[ where you were, ⌃⌥Z takes the last change back, ⌃⌥⇧F makes it a normal Mac again, and so does quitting. No window is ever closed, hidden or minimised by Arbor.
   *Not yet:* ⌃⌥⇧F answers "nothing is docked" and does nothing while a floating window hangs out of view.

## 2. The first ten minutes

### Before you start: four switches

macOS has features of its own that want the same screen edges and the same clicks. In **System Settings → Desktop & Dock**:

| Switch | Set it to | Otherwise |
|---|---|---|
| Click wallpaper to reveal desktop | **Only in Stage Manager** | One click on the Desktop, or in a gap between docked windows, sweeps every window off to the sides. It looks as if Arbor lost them. A second click brings them back |
| Drag windows to screen edges to tile | off | The left and right edges of the screen are macOS's: pushed against one, a window gets half the screen from macOS, and Arbor offers nothing along them |
| Drag windows to menu bar to fill screen | off | The top edge is macOS's: held in the menu bar, a window fills the screen |
| Hold ⌥ key while dragging windows to tile | off | While ⌥ is down the window is macOS's wherever you let go |

**Arbor never fights macOS over a window. With macOS's tiling on, the left, right and top edges are macOS's.** Arbor shows no preview along them and docks nothing there, and leaves the window floating where macOS puts it. So there is one preview at a time, and what it shows is what happens. The bottom edge, the edges of docked windows and the keys stay Arbor's: ⌃⌥⌘← docks at the left at every setting. The first few times, a line on screen says who took the window and which key docks it. With the switches off, every edge is Arbor's to its last point.

Quit other window managers (Rectangle, Magnet, Amethyst and others use the same ⌃⌥ keys), and turn Stage Manager off.

Arbor checks all of this for you and changes none of it: the welcome window lists what stands in the way, worst first, and so do **Check Setup…** (menu → Help) and `arborctl doctor` at any later time.

### Launch and permission

Arbor has no Dock icon. At the first launch a **welcome window** opens by itself, with the permission it needs, what competes with it, and three moves to try, each ticked off as you make it on your own windows. After that Arbor is the small icon of three columns in the menu bar. On a MacBook with a notch and many menu bar icons it may be hidden behind the notch: quit a few, or hold ⌘ and drag icons to reorder them; opening Arbor again brings the welcome window back, as menu → Help → Welcome… does.

Once something is docked the icon grows into a row of small **buttons for where you are**: back, forward, the Desktop, everything, one for each saved view, and the menu. A right click anywhere on them opens the menu too. If the menu bar has no room, Arbor goes back to the single icon by itself; `arborctl set menuBarControls false` keeps it so.

macOS asks whether Arbor may use **Accessibility**. macOS lets an app move other apps' windows only with that permission. Arbor reads where windows are and their titles, moves them, and sends nothing anywhere. Switch it on in System Settings → Privacy &
Security → Accessibility; Arbor notices within a second. If the switch is already on but the menu still says that Arbor needs permission (this happens after installing a new build), switch it off and on again.

Nothing moves when permission arrives. Arbor arranges nothing until you ask.

### Three moves

1. **Dock.** Drag any window by its title bar to the left edge of the screen. A preview shows where it will land; let go. Drag another to the right edge. Windows that were floating where the docked ones now sit are nudged onto the Desktop between them.
2. **Frame.** Click one of the docked windows and press **⌃⌥↩**. It fills the screen. **Your other windows are out of view, not closed.**
3. **Show everything.** Press **⌃⌥Space** (or ⌃⌥↩ again). Everything is back.

Now try: ⌃⌥← and ⌃⌥→ while framed, to walk to the neighbouring space. ⌃⌥[ to go back, like a browser. Drag the gap between two docked windows to resize both. Drag a third window onto the **bottom edge of a docked window** to put it underneath: that makes a group, and ⌃⌥↑ from either
of its windows, framed, shows the group.

Arbor talks you through these the first few times, in a line low on the display: "Docked · ⌃⌥↩ frames it", "Your other windows are out of view, not closed · ⌃⌥Space shows
everything". After three times it takes each as read. The same line says why when a shortcut cannot do anything where you are ("No space to the left", "Nothing to step into:
Safari fills the view"), and confirms what you cannot see, such as a saved view. It fades by itself and never takes a click or the keyboard.

**⌃⌥⇧/** shows every shortcut on screen, and what the pointer and the trackpad do; any key or click puts the list away.

From the first dock on, a thin line in your accent colour runs round the **focused window**, in the gap, so that you can see where the keyboard is after windows have changed places. It goes away again when nothing is docked. `"focusRing": false` in the settings
switches it off.

Behind what is docked the wallpaper is a shade darker, so that the docked windows read as one surface and the Desktop between them as another. Icons on the Desktop can be clicked and dragged as always, also where it is darker.

### If you get lost

Always in this order:

1. **Show Everything**: ⌃⌥Space, or ⌃⌥0 for every display at once, or the menu bar icon.
2. **Float All Windows**: ⌃⌥⇧F, or the menu. Nothing is docked any more: a normal Mac.
3. **Quit Arbor**: every window comes back into view.

## 3. A day with a browser, a chat, a terminal and calls

### Morning: set the table once

Browser on the left, terminal on the right, chat under the terminal, the Desktop in the middle for everything else.

- Click the browser, **⌃⌥⌘←**. Click the terminal, **⌃⌥⌘→**.
- Drag the chat window onto the lower part of the terminal and let go when the preview covers its bottom half.
- Drag the gaps until the proportions suit you.

Arbor remembers the arrangement, per display, across restarts of Arbor and across a login, when apps bring their windows back. Starting Arbor puts what was docked back in its places and shows everything, whatever the view was when you quit, and a window you never docked is not moved. (A docked window too large for its place shows as a tile, as always when everything shows.) The view you quit in is one step back (**⌃⌥[**). An app that you quit and open again while Arbor runs does not get its places back yet: its windows float, and you dock them again.

In a hurry? **⌃⌥A** docks every window on the display in a grid. It replaces whatever arrangement was there.

### Give the places you work in a number

Frame the browser (⌃⌥↩) and press **⌃⌥⇧1**. Frame the terminal, press ⌃⌥↑ so that terminal and chat share the screen, and press **⌃⌥⇧2**. From now on **⌃⌥1** and **⌃⌥2** take you there from anywhere on that display, and ⌃⌥[ takes you back. Nine per display: the numbers belong to the display you are typing on; a name (below) is found from every display.

```
 ⌃⌥1                            ⌃⌥2                             ⌃⌥Space
+--------------------+         +--------------------+          +------+......+------+
| Safari             |         | Terminal           |          |Safari|      | Term |
|                    |         |                    |          |      |      +------+
|                    |         +--------------------+          |      |      +------+
|                    |         | Slack              |          |      |      | Slack|
+--------------------+         +--------------------+          +------+......+------+
```

### Or a name

Nine numbers are hard to keep apart. With terminal and chat on screen, press **⌃⌥N**, type `Code` and press ↩. The menu now lists Code under Saved Views, `arborctl go code` (or just `go co`) and
`arbor://go/code` take you there from anywhere, also from another display, and Arbor's replies call the space by its name.

A name stays with its windows. Close the chat and Code is the terminal alone; open an editor, press ⌃⌥⌘↓ while you are in Code, and it is part of Code. A name on a single window follows that window
wherever you dock it. When the last window of a named space closes or floats, the name goes with it. ⌃⌥N on a named space renames it; an empty field takes the name off. Arrange Windows and Float All Windows start afresh, names
included. Names are kept when you quit, and a display that is unplugged brings its names back with its arrangement.

### From one framed window to another

**Hold ⌃⌥Space.** Everything shows for as long as the keys are down. Point at the window you want, or walk the outline to it with the arrow keys, and let go: it fills the view and has the keyboard. ⌃⌥[ takes you back.
Changed your mind? Press ⎋, or let go without choosing: you are where you were. (A tap of ⌃⌥Space still shows everything and stays, and so does a slow one: under a second with nothing chosen is a tap.)

### Without reaching for the mouse

**⌃⌥⇧ + an arrow** moves the keyboard to the nearest window that way, docked or floating; the line round the focused window shows where it went. A tile in the way is zoomed into. With no window that way in view, the view moves to the neighbouring
space and the keyboard goes along, so framed on one window the same four keys walk you from window to window; past the last space they cross to the next display.

The focused window too small? **⌃⌥⌘=** grows it and **⌃⌥⌘-** shrinks it, taking room from and giving it to its neighbours; it never shrinks so far that it becomes a tile. **⌃⌥⌘0** balances the sizes of everything in view again.
**⌃⌥R** rotates the focused window's group: two windows side by side become one above the other. Press it again and they are as they were. **⌃⌥⇧R** mirrors the group: left becomes right. All five are also in the menu, under **Adjust**.
### Where is that window?

Most of your windows are out of view most of the time. That is the point, and it is why **⌃⌥G**, Go to…, exists. Press it, type a few letters of the app or of the window's title, press Return: the view moves to that window
and it has the keyboard. It does not matter what kept it out of view: another space, another tab, the Dock, ⌘H, another display, another macOS Space.
If you were framed on one window, the one you go to is framed in its place; from a group, the view steps out just far enough to show both.

```
 ⌃⌥G   inb ↩
+----------------------------------------------------------+
|  inb                                                     |
+----------------------------------------------------------+
| > Mail     Inbox — iCloud                    out of view |
|   Safari   Inbox (3) - Gmail                   minimised |
|   View 2   Mail, Slack                        saved view |
+----------------------------------------------------------+
```

The letters need not be together (`gc` finds Google Chrome), several words narrow it down (`saf docs`), capitals and accents do not matter. With nothing typed the list starts with the window you were in before this
one, so **⌃⌥G ↩** hops back and forth between two windows wherever they are. Named spaces and saved views are in the same list: `wri ↩`, `v2 ↩`. Escape, or a click anywhere else, closes it and changes nothing.

### Where am I?

**⌃⌥M** brings up the **minimap**, low on the display: the whole arrangement in small, each window in its app's colour, the Desktop as an outline, and a frame in your accent colour around what you are looking at. A saved view's number stands above it.

It stays for five seconds, longer while the pointer is on it, and it takes clicks: click a window in it and that window is framed, from wherever you were. ⌃⌥M again, or a click beside the picture, puts it away. Keep moving with the arrows and it stays with you. Or do it in one gesture, as with ⌃⌥Space: **hold** ⌃⌥M, move the pointer onto a window in the minimap, and let go. ⎋ while you hold gives up.

Would you like to see it after every move of the view, without asking? `arborctl set minimapDuration 0.9` shows it for that many seconds each time, out of reach of clicks. It stays away when the view goes to everything, which would only be a small picture of what is on screen.

### Reading and writing side by side

Frame a rectangle (with [the gestures switched on](#6-on-its-way)): hold **⇧** and drag, starting on the Desktop, in a gap or on a tile, around the windows you want; or hold **⌃⌥** and start anywhere. The view moves to the space that fits best. It is the quickest way to say "these two". Let go of the keys first to call it off.

### Something small for a moment

Calculator, a Finder window, a note: leave them floating. **⌃⌥D** gives the Desktop, and all of them, the whole screen; ⌃⌥[ returns. Small fixed-size windows can be docked too: they sit in the middle of their place.

If you would rather see no wallpaper around a window that floats alone, `arborctl set soleFloatTakesDesktop true`: the only floating window then takes the whole Desktop, and has its own size back as soon as a second one floats. Drag it and it is its own size again where you drop it; resize it and it stays as you leave it; `arborctl float` makes it take the Desktop again.

### A terminal for ten seconds

For the apps you visit many times a day for a moment (a terminal, a note, a password manager), give each a shortcut in `settings.json`: `"bindings": { "ctrl+opt+`": "summon Terminal" }`. ⌃⌥` then brings Terminal's window over whatever
you are looking at, with the keyboard in it; ⌃⌥` again, or a click on anything else, sends it out of view and you are where you were. It comes back where you last left it. Sent away, it is out of view in every view, until you summon it, ⌘Tab to it, or press ⌃⌥0, which puts it back on the Desktop: after ⌃⌥0 nothing is out of view, without exception. The README's "Summoning" has the details.

### A call comes in

A call window should stay put while you look things up, and floating windows go out of view when the view leaves the Desktop. So pin it: with the call window in front, choose **Keep "zoom.us" in View** from the menu. It
keeps its place on the display wherever you zoom, and Arbor never gives it the keyboard by itself. Drag it where you like: a pinned window moves and never docks (to dock it, use ⌃⌥⌘ + arrow or Dock Focused Window, or unpin it first). If you clicked in it and then move the view with a shortcut, the keyboard goes to the window that arrives. The same menu item, now with a tick, ends it.

To have every call pinned as it opens, use a rule (below): `{ "app": "us.zoom.xos", "title": "Meeting", "action": "pin" }`. The same goes for a timer, a music player or a reference document. The README's "Pinned windows" has the details and the limits.

Choose **Hold Still** from the menu when you share, and Arbor holds still: the view moves when you ask, with keys, gestures, ⌘Tab, Go to… or a click in the Dock, and not because a chat or a calendar pushed itself forward; such a window stays out of view and you go on typing where you
were. Arbor cannot see who asked. It goes by time: a change of app within half a second of a click or of letting go of ⌘ counts as yours, so a chat that picks that very moment gets through, and a switch made with Spotlight or a launcher is turned away. Arbor says so on screen, once for each app: "Terminal is out of view: holding still · ⌘Tab or ⌃⌥G goes there".
The menu bar icon is filled in meanwhile. **Release** in the menu ends it. `arborctl set holdStillWhileCameraIsOn true` makes a camera do it for you, once that has been seen at work: Arbor only reads that a camera is on, which macOS tells every app; it does not open it.

### Sharing your screen

- Share **a window** rather than the whole screen when you can: then nothing else can appear, whatever the view does. Keep that window in view while you share it.
- To share the whole screen, frame what you want to show first. Everything else is out of view, which is a tidy way to present.
- Then choose **Hold This View** from the menu. The icon turns into a lock, and the view stays exactly where it is: ⌃⌥Space, a pinch and ⌘Tab to something out of view do nothing, an app that pushes itself forward stays out of view, and new windows do not squeeze
  what you are showing. You can still work in the windows that are in view, go from one to the other with ⌃⌥⇧ + arrow, and rearrange them among themselves. `arborctl hold 60` releases by itself after an hour.
- To end it, choose **Release** from the menu or press ⌃⌥⎋. Neither moves anything: what was out of view stays there, and a window whose rule would have moved the view goes on floating. (⌃⌥⎋ pauses only when pressed again.)
- If you minimize, hide or close the window you are showing, by habit, the audience sees the wallpaper and nothing else. Bring the window back, or release.
- To move between things while you share, choose **Hold Still** instead: your own keys work, and nothing moves by itself.
- **Do not pause Arbor for this**: pausing brings every window into view.
- Look at the bottom corner of the screen: windows that are out of view leave a line there, one point wide. Nothing can be read in it.

The two in one sentence each. **Hold This View**: nothing moves the view, not even your own keys; for a shared screen. **Hold Still**: Arbor moves nothing by itself; your keys, gestures and ⌘Tab still work; starts by itself during calls.

### A game, a remote desktop, a virtual machine, Emacs

They need ⌃⌥ for themselves. For an app you use every day, bring it to the front and choose **Shortcuts Off in “App”** from Arbor's menu. From then on, in that app the keys and drags are its own, and its windows stay arranged like any
others; ⌘Tab or click elsewhere and Arbor's shortcuts are back. Only ⌃⌥⎋ keeps working there, and the key that summoned the app, if one did, to send it away again. The same menu item, now ticked, undoes it. One thing to know: walking onto such an app with ⌃⌥→ hands it the keyboard, so the way on is ⌘Tab or the pointer.

For now and then, **⌃⌥⎋** pauses Arbor: the Mac looks as if Arbor had quit. Every window goes back to where it was before Arbor touched it, in its own size and in view, nothing comes to the front that was not there, and windows, shortcuts and gestures are left alone. The menu bar icon dims. ⌃⌥⎋ again, and the arrangement and the view come back, minus whatever was closed meanwhile. (If all you want is ⌃⌥ for the app in front, Shortcuts Off in “App”, above, moves nothing.)
`arborctl pause 45` resumes by itself after 45 minutes. A game that changes the display's resolution can have this done for it: add it to Pause for (Settings… → Apps → Advanced, or `arborctl set pauseForApps add <bundle id>`), and Arbor pauses whenever it is in front and resumes when it is not. (⌃⌥⎋ inside such an app resumes by hand; pressed once more it is a pause of your own, which lasts until you end it.)

### Plugging in and unplugging a display

Each display has its own arrangement, view, saved views and names. Drag a window to another display and it joins that one. Unplug a display and its windows float on the main one; plug it back in, within thirty days, and they return to their places. Shortcuts
follow the keyboard: those that move the view act on the display you are typing on, those that move a window on the **focused** window. Only if you have moved the pointer since you last typed
do the view's shortcuts mean the display you are pointing at. A pinch always means what is under the pointer.
**Dock Focused Window ▸ Move to Next Display** sends the focused window across, docked or floating as it was, and the keyboard with it.

### macOS Spaces and full screen

Windows on another of macOS's Spaces keep their places and take no room until that Space shows again. A docked window that goes full screen gives its place to its neighbours for the time being and returns to it afterwards; Arbor's shortcuts do nothing to a window
while it is in full screen.

### Evening

Nothing to do. Quit Arbor or leave it running; log out or restart. Quitting brings every window into view, and the arrangement is there again next time, with everything showing.

## 4. Making it yours

**Settings…** in the menu, or ⌃⌥,, opens the settings window: the everyday settings by section, the rarer ones behind Advanced, a search field, the lists of apps under Apps (the ones Arbor does not arrange, the ones that keep their own ⌃⌥), and panes for Shortcuts and Rules. Everything applies as you change it, so keep a few windows docked behind it and watch. A value Arbor cannot use is refused under its control, with the reason.

Behind the window is a file, `~/Library/Application Support/Arbor/settings.json` (menu → Help → Settings File…); Arbor applies it as soon as you save it, and the open window follows. `arborctl set gap 16` changes one from the command line, and `arborctl settings` lists them all. A command changes only its own setting in the file; the rest stays as you wrote it. [SETTINGS.md](SETTINGS.md) describes every key.

**Shortcuts.** In Settings… → Shortcuts, click a shortcut and press the new keys (Escape cancels). If another command has them the window says which, and asks. The box at the bottom gives a shortcut to any command at all, `set gap 0` included. In the file, map a shortcut to a command, or to `null` to give a default back to your apps:

```json
"bindings": {
  "ctrl+opt+cmd+h": "dock left",
  "ctrl+opt+d": null
}
```

`arborctl bindings` shows what is in effect and explains anything it had to skip. ⌃⌥⇧/ shows your shortcuts, not the defaults, and so do the sentences on screen.

**Messages.** `"messages": "off"` silences the line on screen (a shortcut that cannot act beeps instead); `"all"` makes it show the reply to every shortcut, which is a good way to learn
what the keys do.

**Rules for new windows.** Settings… → Rules adds one for any running app. Checked in order, first match wins:

```json
"rules": [
  { "app": "com.apple.Terminal", "action": "dock right" },
  { "app": "com.tinyspeck.slackmacgap", "action": "dock beside com.apple.Terminal bottom" },
  { "app": "us.zoom.xos", "title": "Meeting", "action": "pin" },
  { "app": "com.apple.systempreferences", "action": "ignore" }
]
```

`"app": "*"` means any app, and `com.jetbrains.*` a family of them.

**New windows that dock by themselves.** If you come from yabai, AeroSpace or i3: menu → **Dock New Windows**. From then on a window you open takes half the place of the window you were working in (to its right if
that is wide, below it if it is tall). It is careful: small windows and windows of a fixed size float as always, so does a window there is no room for, nothing becomes a tile because a window opened, the view never moves, and windows
that were already open stay as they are. Your rules come first, so `{ "app": "com.apple.finder", "action": "float" }` keeps Finder out of it.

**Looks.** How dark the wallpaper is behind docked windows, whether it is blurred there, and what tiles show:

```json
"dimBehindArranged": 0.4,
"blurBehindArranged": 1,
"tileStyle": "name",
"appColourAmount": 0.5
```

`"dimBehindArranged": 0` leaves the wallpaper as bright as it is; `"tintBehindArranged"` lays your accent colour over it. A hairline runs round the Desktop where it lies between docked windows: `"desktopEdge": 0.3` makes it plain to see, `0` removes it. `"tileStyle"` is `"icon"`, `"name"` (the icon and the app's name) or `"plain"`, and a space you have named shows its name in all three; `"appColours": false` makes every tile the same grey. `"gapHandles": "hidden"` keeps gaps draggable without the small handle under the pointer, `"off"` makes
them plain gaps. None of this moves a window.

**Scripts.** Everything Arbor does is a command with a text form, the same everywhere. (Copy the command, not the remark after `#`: at its prompt macOS's own shell, zsh, does not take `#` for a comment.)

```bash
arborctl help                 # all of them; works without Arbor running
arborctl dock left            # the focused window
arborctl view 2
arborctl state | jq .state    # everything, as JSON
arborctl watch view           # a line of JSON whenever the view changes, for a status bar
open "arbor://view/2"         # from Raycast, Alfred, Shortcuts, a Stream Deck
```

`arborctl` exits with 0 when the command worked, 1 when Arbor said no (and why), 2 when Arbor is not running. URLs can only move the view and arrange windows, because any web page can open one; `allowAllURLCommands` lifts that. [Scripting Arbor](SCRIPTING.md) has every event of `watch`, a SketchyBar item that shows the space in view, and recipes for the shell and `jq`.

**A whole arrangement in one line.** `|` is side by side, `/` one above the other, brackets group, `[ ]` is a tab group, `:2` is twice the size:

```bash
arborctl layout "Safari:2 | (Mail / Notes)"     # windows that are not mentioned float
arborctl layout                                 # prints the arrangement you have, in the same notation
arborctl layout --open "Xcode:2 | (Simulator / Terminal)"   # opens what is not running
```

Arrange the windows by hand once, ask for the line, and bind it to a shortcut: `"ctrl+opt+cmd+1": "layout Safari:2 | (Mail / Notes)"`. [LAYOUTS.md](LAYOUTS.md) has the rest: several windows of one app, titles, other displays, URLs.

## 5. When something is wrong

| What you see | Why | What to do |
|---|---|---|
| **Every window flew to the sides** after a click on the Desktop or in a gap | macOS's "Click wallpaper to reveal desktop" | Click the wallpaper again. Then set it to "Only in Stage Manager" (section 2) |
| **A window is gone** | It is out of view | ⌃⌥0, or ⌘Tab to its app. Still gone: ⌃⌥⇧F. Still gone: quit Arbor and start it again; at launch it brings back anything left off screen |
| **The shortcuts do nothing** | No permission; another app has the keys; shortcuts are off, or off in this app; Arbor is paused | Open the menu: it says if permission is missing or Arbor is paused, and Shortcuts Off in “App” has a tick if they are off in the app in front. Quit Rectangle, Magnet and the like. ⌃⌥⇧/ or Keyboard Shortcuts… in the menu shows the shortcuts in effect; `arborctl bindings` lists them too and says if they are off right now, and why |
| **Only ⌃⌥Space does nothing**, or ⌃⌥Space no longer switches keyboards | With several keyboards or input methods set up, macOS uses the same keys for "Select next source in Input menu", and only one of the two gets them (on the one Mac where it was measured, Arbor) | ⌃⌥0 shows everything too. Free the key on either side: System Settings → Keyboard → Keyboard Shortcuts → Input Sources, or `arborctl unbind ctrl+opt+space` |
| **Show Everything springs back** when the keys come up | They were held for a second or more, or the pointer moved meanwhile, which is a peek: letting go returns to the outlined view | Let go within a second with the pointer at rest, or use ⌃⌥0, which never peeks. `"peek": false` in `settings.json` turns peeking off |
| **Clicks, scrolling or pinches feel late or go missing**, in any app, since you switched the gestures on | For the pinch, ⌃⌥ + scroll and the rectangle macOS shows Arbor each press, scroll and pinch first, and holds it until Arbor has answered | Settings… → Gestures → **Trackpad and mouse gestures** off, or `arborctl set pointerGestures false`: nothing waits for Arbor any more. Keys, the menu and dragging windows, gaps and tiles work as before. If that cures it, please tell us |
| **A beep** | The shortcut has nothing to do here, and `messages` is "off" | Set `messages` to "helpful" and Arbor says why on screen; or ask `arborctl` with the same command: `arborctl in` → "nothing is docked yet: drag a window to a screen edge…" |
| **A window pushed against the edge takes half the screen**, or all of it at the top, and is not docked | With macOS's own tiling on, the left, right and top edges are macOS's, and Arbor stands aside | ⌃⌥⌘ + an arrow docks it at once. Or switch off the three switches in section 2, and every edge is Arbor's |
| **A window shows as a coloured tile** with its icon | Its place is too small for it, or its app refused to shrink that far | Arbor has already moved the gaps as far as the Desktop and the neighbours could spare. Click the tile to zoom in on it. Give it more room by dragging a gap. Once there is room, Arbor asks the window again, out of view, and gives it the place if it fits |
| **An app keeps moving its own windows**, or looks wrong when docked | Some apps insist | Don't Arrange "App" in the menu |
| **The menu shows ⌃⌥Ü, the documentation ⌃⌥[** | A letter, digit or sign is the key that types it on your keyboard layout. What your layout cannot type on its own stays where a US keyboard has it, and the menu shows what is printed on that key | Trust the menu and `arborctl bindings`. To move it, bind the command to a key you like, written as your keyboard types it: `"ctrl+opt+ö": "back"`; `"ctrl+opt+ü": null` frees the old one |
| **I switch layouts all day and the shortcuts move** | They follow the layout, like ⌘-shortcuts | Set `shortcutsFollowLayout` to false: every shortcut is then a place on a US keyboard. Or write single ones as places: `ctrl+opt+us:z` |
| **With VoiceOver on, nothing works properly** | ⌃⌥ is VoiceOver's own modifier | In VoiceOver Utility → General choose Caps Lock as the modifier, or set `hotkeysEnabled` to false and use the menu |
| **The menu bar icon is a warning sign**, windows are missing and nothing brings them back | Arbor's Accessibility permission was taken away while windows were out of view. Without it Arbor cannot move anything, not even back, and quitting it does not help | Switch Arbor on again under System Settings → Privacy & Security → Accessibility (the menu, ⌃⌥Space and ⌃⌥0 lead there): every window comes into view at once. If you would rather not: ⌘Tab to the app and choose Window → Center (macOS 15 and later), or quit and reopen the app |
| **The permission switch is on, and Arbor still asks** | A new build has a new signature | Switch it off and on; or remove Arbor from the list with − and add it again |
| **My settings seem to be ignored** | A typing mistake in `settings.json` | `arborctl reload-settings` says where, and so does the log (menu → Help → Show Log); until it is mended Arbor keeps the settings it had, leaves the file alone, and refuses commands that change settings. `arborctl settings`, `arborctl bindings` and `arborctl rules` explain values and entries they could not use |
| **I want to start again** | | `arborctl reset everything` (the settings; a file Arbor could not read is kept as `settings.unreadable.json`). For the arrangement, quit Arbor and delete `state.json` in `~/Library/Application Support/Arbor` |
| **I want it gone** | | Quit Arbor (windows come back into view), delete Arbor.app and that folder, and remove it under Privacy & Security → Accessibility |

When reporting a problem, attach `arbor.log` from that folder. It contains window numbers and app identifiers, never window titles. `state.json` does contain titles: look before you share it.

## 6. On its way

Being built or waiting to be merged as this is written. When one lands, its section moves up into the guide.

| | What it will change here |
|---|---|
| Motion with the windows' own contents | With Screen Recording permission windows will keep their contents while they move. Not yet: wait for the release notes to say it has been seen on a Mac |
| A later start shows everything | Today a later start also goes back to the view you had, so windows can go out of view at once. It will end showing everything; ⌃⌥[ will go to where the view was |
| Tiles say which window they are | A tile will show the window's title under the icon, so that two windows of one app can be told apart (`tileStyle`, which will ship as `name`) |
| Tab groups | Drop a window on the middle of another: they share a place under a strip of tabs; ⌃⌥⇥ switches |
| Presets | Set the table with one command |
| Carry a window with the keyboard (⌃⌥⌘Space) | Everything a drag can do, from the keys: put a window under one other window, make a tab group |
| Clicks on the Desktop guarded | Built, and off until someone has tried it on a Mac (`guardDesktopClicks`). Then the first of the four switches in section 2 will no longer be needed |
| Trackpad and mouse gestures: the pinch, ⌃⌥ + scroll, the rectangle | Built, and off for now: for them macOS shows Arbor every pinch, scroll and press of the Mac first, in every app, and holds it until Arbor has answered. That waits until all its checks on a Mac are green. To have them today: Settings… → Gestures → **Trackpad and mouse gestures**, or `arborctl set pointerGestures true` |
| Double-click a title bar or the Desktop | More of what TrellisWM users' hands expect |
