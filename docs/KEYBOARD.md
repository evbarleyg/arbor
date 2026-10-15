# The keyboard map

Every shortcut of Arbor's own on one page: the nine that ship, the whole map that one setting brings back, what is set aside for
features being built, what must never be bound, and why. **Take keys from this page, not from what looks free in
`KeyBindings.swift`.** A global shortcut is taken away from every app on the Mac, so each one has to earn its place.

## The nine

As Arbor ships it takes nine keys, each ⌃⌥ and one key (`collab/QUESTIONS.md`, Q29; `collab/IDEAS.md`, I22). Nothing else is bound: no third
modifier, no digit, no other letter.

| Keys | Does | Command |
|---|---|---|
| ⌃⌥← / ⌃⌥→ | Dock the window in front at that side, or move it one place | `dock left` / `dock right` |
| ⌃⌥↩ | Frame it: it has the screen to itself. Again, and it is back | `zoom` |
| ⌃⌥Space | Show everything. Held: a peek, which has all four arrows and ⎋ for as long as it lasts (F51). ⌃⌥← and ⌃⌥→ dock nothing while the key is down: pressed early they begin the hold, pressed after ⎋ they do nothing | `show-all` |
| ⌃⌥[ | Back to where the view was | `back` |
| ⌃⌥Z | Undo the last change to the arrangement | `undo` |
| ⌃⌥F | Float the window in front, or take it back in | `toggle-float` |
| ⌃⌥G | Go to…: a window, a named space or a saved view, by typing | `find` |
| ⌃⌥⎋ | Pause and resume. **The one key that answers everywhere**: in a pause, and in apps that keep their own ⌃⌥ (F41) | `toggle-pause` |

- **The arrows dock** because docking is what a newcomer came for, and because it is what ⌃⌥ and an arrow do in the window tools people
  already know.
- **The rest is in the menu.** A command without a key shows none there, in the panel of shortcuts or in a line on screen. Three kinds have no row either, being
  nothing without a key: `neighbor`, `focus <direction>` and `home`. `arborctl` runs them, and `bind` gives them a key.
- **More keys, one at a time:** `arborctl bind ctrl+opt+d desktop`, the Shortcuts page of the settings window, or `bindings` in settings.json. The
  README has recipes.
- **More keys, all at once:** `arborctl set shortcuts all` ("Shortcuts: All of them" in the settings window) binds the whole map below instead of
  the nine; `set shortcuts core` goes back. `bindings` changes single keys on top of either.
- **The budget** (I25): at most ten, none with a modifier besides ⌃⌥. `LessByDefaultTests` fails on an eleventh: it takes the place of another. The
  tenth place stays free until use asks for it.
- **⌃⌥A is never bound again**, in either map (I16). With a widely used chat app in front it archived the open conversation there. Whatever
  the cause, the habit outlives Arbor: paused, quit or crashed, the same fingers reach the app. Arrange Windows is in the menu.
- **On other keyboards** eight of the nine are letters, arrows and keys that are the same everywhere. `[` is not one key in most of Europe: it stays where
  a US keyboard has it and is shown as what is printed there (⌃⌥Ü in Germany, ⌃⌥^ in France); see "Other keyboard layouts".

## The whole map: five rules

The rest of this page is about the whole map (`shortcuts` set to `all`), which shipped until the nine did. It is TrellisWM's published table and what
grew around it. There ⌃⌥ with an arrow looks and ⌃⌥⌘ with an arrow docks; the other seven of the nine are the same keys in both.

1. **⌃⌥ is Arbor.** Every shortcut contains ⌃⌥, and TrellisWM's published table works unchanged.
2. **⌃⌥ looks.** With arrows, Space, ↩, brackets, digits, `-`, `=`: the camera moves, the arrangement never changes.
3. **Add ⌘ to move.** The same key, applied to the focused window: ⌃⌥→ looks right, ⌃⌥⌘→ moves the window
   right; ⌃⌥0 resets the zoom, ⌃⌥⌘0 resets the sizes.
4. **Add ⇧ for the counterpart.** Recall and save, next and previous, undo and redo, one and all.
5. **⌃⌥ + letter is a verb by its initial.** Nothing uses ⌃⌥⌘ + letter (Xcode's territory) or all four
   modifiers (people map those to a hyper key for their own use).

## The map

Status: **T** published by TrellisWM, frozen. **shipped**: bound in the whole map today. **assigned** to a feature being built:
use exactly this key. **reserved**: keep free for that purpose, bound to nothing. A new feature's key goes into the whole map, never among the nine.

### Look (the camera)

| Keys | Command | Status |
|---|---|---|
| ⌃⌥Space | `show-all` | T |
| ⌃⌥Space, held | peek: everything shows while the keys are down, letting go frames what is outlined. A tap is TrellisWM's, unchanged, and a hold of under a second in which nothing was chosen counts as one: the first way home does not spring back for a slow press | shipped (F51) |
| ⌃⌥ + arrow, ⌃⌥⎋ while ⌃⌥Space is held | move the outline; give up and return. They have their usual meaning until 0.3 s after the press and from the moment the peek ends | shipped (F51) |
| ⌃⌥0 | `home`: everything, on every display ("view 0", and ⌘0 resets zoom in every Mac app). Also the way out for people whose ⌃⌥Space belongs to input sources or an IDE | shipped (product review) |
| ⌃⌥↑ / ⌃⌥↓ | `out` / `in` | T |
| ⌃⌥- / ⌃⌥= | zoom out / in, as ⌘- and ⌘= do in apps | reserved (F16) |
| ⌃⌥← / ⌃⌥→ | `neighbor left` / `right` | T |
| ⌃⌥⇧ + arrow | `focus <direction>`: the nearest window in view that way; when there is none, what `neighbor` does, then the next display. These keys ran `neighbor` before; framed on one window they still do the same, so nothing is unlearned | shipped (F22) |
| ⌃⌥↩ | `zoom`. With a floating window in front, which TrellisWM's key does nothing for, it is the window that fills the view, and goes back (QUESTIONS Q29) | T |
| ⌃⌥[ / ⌃⌥] | `back` / `forward` | T |
| ⌃⌥1–9 / ⌃⌥⇧1–9 | `view n` / `save-view n` | T |
| ⌃⌥D | `desktop` | shipped |
| ⌃⌥G | `find`, Go to…: **one** picker for windows, named spaces and saved views | shipped (F27) |
| ⌃⌥M | `minimap`: up for five seconds and taking clicks; again to put it away. Held, like ⌃⌥Space (F51): up while the keys are down, letting go frames what the pointer is over, and ⎋ gives up (it is ⌃⌥⎋ then, and does not pause) | shipped (F26) |
| ⌃⌥⇥ / ⌃⌥⇧⇥ | `tab next` / `tab previous` (⌃⇥ is the app's tabs, ⌃⌥⇥ Arbor's) | assigned (F04; built so on `feat/F04-tab-strips`) |

### Arrange

| Keys | Command | Status |
|---|---|---|
| ⌃⌥⌘ + arrow | `dock <edge>`: dock, or move one place | shipped |
| ⌃⌥⌘= / ⌃⌥⌘- | `grow` / `shrink` the focused window | shipped (F22) |
| ⌃⌥⌘0 | `balance`: equal sizes again | shipped (F22) |
| ⌃⌥⌘Space | `carry`: pick the focused window up and choose among the targets a drag has, with the arrows (⌃⌥Space looks at everything; add ⌘ and it moves anywhere) | reserved (F59) |
| ⌃⌥⌘[ / ⌃⌥⌘] | previous / next display, for a window | reserved (F59) |
| ⌃⌥F / ⌃⌥⇧F | `toggle-float` / `float-all` | shipped |
| none | `arrange`. It had ⌃⌥A until I16 | shipped, unbound on purpose |
| ⌃⌥⇧A | `toggle-auto-dock`: auto-docking on and off; a tick in the menu is enough for a switch flipped once a week | reserved (F23 ships the command and the menu item, unbound) |
| ⌃⌥Z / ⌃⌥⇧Z | `undo` / `redo` | shipped (F19) |
| ⌃⌥R / ⌃⌥⇧R | `rotate` the focused window's group (side by side ↔ stacked; again, and it is as it was) / `mirror` it | shipped (F22) |
| ⌃⌥N | `ask-name`: a field to type a name for the space in view into; again, or ⎋, closes it | shipped (F20) |
| ⌃⌥P | presets | reserved (I2); reach them through the menu and Go to… |
| ⌃⌥T | make a tab group with the neighbour | reserved (F04) |
| ⌃⌥B | backdrop on and off | reserved (F15) |
| ⌃⌥` and ⌃⌥' | `summon <app>`: which apps is for each person to say, so nothing is bound; these two keys, next to 1 and next to ↩, are kept free for it | reserved (F53); the README gives the `bindings` line |
| ⌃⌥⇧D | `toggle-pin`: keep the focused window in view (⌃⌥D looks at the Desktop, where floating windows live; ⇧ is the floating window that does not stay there) | reserved (F49); the menu reaches it, and the README gives the `bindings` line |

### Arbor itself

| Keys | Command | Status |
|---|---|---|
| ⌃⌥⎋ | `toggle-pause`: Arbor lets go of the windows and of every other shortcut; the same keys bring it back. **The one key that answers everywhere**: it stays registered during a pause and in apps that keep their own ⌃⌥ (F41) | shipped (product review) |
| ⌃⌥, | Settings… (Arbor is never the active app, so ⌘, cannot open its settings) | shipped (F12) |
| none | `hold`, `hold still`, `release`, `toggle-hold` (F58): chosen once per meeting, from the menu. A key that ends a hold is a key that can be slipped on in front of an audience | shipped, unbound on purpose |
| ⌃⌥⇧/ | `show-shortcuts`: the shortcuts in effect, on screen (⇧⌘/ is Help in every app) | shipped (F43) |

### Pointer and trackpad

| Gesture | Does | Status |
|---|---|---|
| ⌥ + pinch anywhere; pinch on the Desktop | zoom | T |
| ⌃⌥ + scroll anywhere (exactly ⌃⌥; a wheel may have ⇧ besides) | zoom, for Macs without a trackpad: up steps in toward the pointer, down steps out. ⌃ + scroll is macOS's Accessibility zoom, ⌥ + scroll is the apps'; ⌃⌥ + scroll is nobody's, as far as anyone knows: whether macOS's zoom, set to ⌃, also takes ⌃⌥ + scroll is the first thing to try on a Mac | shipped (F55) |
| ⇧-drag starting on the Desktop | frame the rectangle | T; shipped |
| ⌃⌥-drag anywhere | frame the rectangle | shipped (⇧⌘ until 2026-10-14; `frameRectangleModifier`) |
| **⌃⌥** + two fingers sideways; two fingers during a pinch of Arbor's | slide the view | assigned (F16). ⌥ + scroll **alone is never Arbor's**: editors, design tools, timelines and terminals use it, and ⌃⌥ is Arbor, with the pointer too |
| **⌘** held while dragging a window | dock: the previews come with the key and go with it. A plain drag only moves the window | shipped (Q29; until 2026-10-15 the other way round, F09), **instead of ⌥**; see "Conflicts". `dragDocks`: `held`, `always`, `never` |

The first five need an event tap. `pointerGestures` ("Trackpad and mouse gestures" in the settings window) is the one switch above them: off, no tap is installed, whatever their own settings say. **It ships off** (Q26), so none of the five works until it is switched on.

## Never bind by default

| Keys | Why |
|---|---|
| ⌃⌥A | a widely used chat app archives the open conversation with it (I16) |
| ⌃⌥⌘8, ⌃⌥⌘`,`, ⌃⌥⌘`.` | macOS Accessibility: invert colours, contrast down and up |
| ⌃⌥⌘ + letter, ⌃⌥⌘↩ | Xcode: ⌃⌥⌘F fix all issues, ⌃⌥⌘G test again, ⌃⌥⌘U run the test at the cursor, ⌃⌥⌘↩ assistant editor |
| ⌃⌥⇧⌘ + anything | the "hyper key" people build with Karabiner-Elements for their own shortcuts |
| ⌃⌥Q, ⌃⌥W | one slipped finger from ⌘Q and ⌘W; nothing near them should do anything surprising |
| ⌃⌥⌫ | reads as "delete"; Arbor never closes or deletes anything from the keyboard |
| ⌃⌥H, ⌃⌥V | Figma: distribute spacing. ⌃⌥H is also JetBrains' call hierarchy |
| ⌃⌥O, ⌃⌥I, ⌃⌥L | JetBrains: optimise imports, auto-indent; keep the home row of IDE users free |
| ⌃⌥H/J/K/L as arrows | eight more letters for what ⌃⌥⇧ and ⌃⌥⌘ + arrow already do; offer it as a README recipe for `bindings` |
| F-keys, anything without ⌃⌥ | rule 1 |

## Conflicts we accept, and what to say about them

How sure: **high** = long-documented defaults; **medium** = from memory of current versions, check on a Mac.

| Who | Keys | What happens | What Arbor does about it |
|---|---|---|---|
| macOS input sources (only with two or more keyboards or input methods set up) | ⌃⌥Space = "select next source in Input menu" | one of the two does nothing (high that it collides). The one measurement, on macOS 26.6.2, says Arbor gets the key, so it is the keyboard switch that dies | ⌃⌥0 does the same; onboarding and the README say so. `bindings` and the log list every shortcut that macOS has ticked for itself, this one only with two or more input sources (K126) |
| **VoiceOver** | ⌃⌥ *is* the VoiceOver modifier: every Arbor shortcut is a VoiceOver command | unusable together (high) | F42: when VoiceOver is on, say so once and offer Caps Lock as the VoiceOver modifier or Arbor's shortcuts off; never fight it |
| Rectangle, Magnet | ⌃⌥ + arrows, ↩, D, F, G, E, T, C, U, I, J, K, `-`, `=`, ⌫; ⌃⌥⌘←/→ | both react, or one silently wins (high) | onboarding checks whether one is running and says to quit it or turn its shortcuts off |
| macOS 14+ "Click wallpaper to reveal desktop" (on by default) | a **click** on the Desktop or in a gap | every window is swept to the screen edges; Accessibility reports nothing (seen on macOS 26.6: `collab/evidence/screens/2026-10-14-review-ux-3-wallpaper-click.png`) | not a key, but the same kind of clash: double-click, ⇧-drag and pinch on the Desktop all begin with that click. F42 detects it; the README asks for "Only in Stage Manager" |
| macOS 15+ window tiling | **⌥ held while dragging a window shows macOS's own tiling preview** (on by default); dragging to an edge tiles; dragging to the menu bar fills | F09's "hold ⌥ to drag without docking" would summon macOS's tiling instead (high) | use **⌘**, Apple's own "no snapping" key (Keynote and Pages guides, Finder's grid); while they are on the left, right and top edges are macOS's and Arbor stands aside (`MacTiling`, Q23). Measured: with ⌥ held macOS acts wherever the pointer is and whatever else is held, ⌃⌥⌘ included, so a shortcut of Arbor's pressed with a window in the hand makes the window macOS's for as long as the keys are down; onboarding links to Desktop & Dock → Windows and names the three switches |
| JetBrains IDEs | ⌃⌥Space class-name completion, ⌃⌥D Debug…, ⌃⌥R Run… | lost inside the IDE (medium) | Shortcuts Off in “App” (`pass-through`, F41); `bindings` can remove any default |
| Emacs, terminals with Option as Meta | every ⌃⌥ + letter is C-M-letter (C-M-f, C-M-a, C-M-d, C-M-Space…) | lost (high) | Shortcuts Off in “App” (`pass-through`, F41) |
| Remote desktops and virtual machines | ⌃⌥ is AltGr on Windows guests (⌃⌥Q = @, ⌃⌥E = € on German layouts), ⌃⌥ + arrows switch Linux workspaces | lost (high) | Shortcuts Off in “App” (`pass-through`, F41); ⌃⌥⎋ pauses by hand. Never listed by default: someone who frames a virtual machine still wants ⌃⌥Space to get out |
| Xcode, Sketch | ⌃⌥⌘ + arrows: navigate in the other editor (Xcode), bring to front / send to back (Sketch) | lost (medium) | accepted: rarely used, and A01 is worth it |
| Figma | ⌃⌥T tidy up | none while ⌃⌥T stays reserved and unbound | keep it unbound |
| Design tools (Figma, Sketch, Photoshop) | ⇧⌘-drag adds to a deep selection | none since 2026-10-14: the rectangle's keys are ⌃⌥. Arbor swallowed the drag everywhere while they were ⇧⌘, and does again for whoever sets `frameRectangleModifier` to that | — |
| Non-US keyboards | a key code names a **position**: 6 is Z on a US keyboard, Y on QWERTZ, W on AZERTY | none since F44: a letter, digit or sign is the key that types it on the layout in use, as in ⌘-shortcuts | what the layout cannot type alone (`[` `]` in Europe, digits in France) stays at its US position and is shown as printed there (⌃⌥Ü, ⌃⌥+; ⌃⌥1); two shortcuts that land on one key are reported by `bindings`; `us:z` and `shortcutsFollowLayout: false` ask for positions |

## What other apps have on Arbor's keys: the census of menu bars

A shortcut of Arbor's is taken from every app while Arbor holds it. The moment it does not (paused, quit, crashed) the same fingers reach the app in
front, which does with the key whatever it does: on a tester's Mac that was something that could not be taken back (`collab/IDEAS.md`, I16). So
**a key stays in the default map only while no app in this table has it on something that destroys or hides** (`collab/QUESTIONS.md`, Q29).

**What was read, before anything else: every app at the first window it shows on a fresh Mac: no account, no document, no project. Nobody signs in anywhere.** So the tables below say what an app shows in its menu bar to
somebody who has just opened it, and what some apps publish about themselves. They do not say what an app does once it is in use, and **they do not show that a census would have caught the fault it was built after**.

**Which map.** Nine keys ship, on ⌃⌥ (← → ↩ Space [ Z F G ⎋); the rest, 51 keys in all, is switched on by whoever wants it (`shortcuts`), and ⌃⌥A is bound in neither
(Q29; the head of this page). When the apps were read the first build's map still shipped, 52 keys, ⌃⌥A on `arrange` among them. The menu bars are held against **the whole map, whichever it is**; the second table, by the apps' own lists, was read for the nine and for ⌃⌥A, and
says what else it met.

### By their menu bars

`scripts/mac-shell/census-menu-keys.sh` opens the apps on a hosted Mac, reads each menu bar through Accessibility and brings the numbers back; `collab/evidence/menu-keys/` keeps them, one file per app, without a
single title; `MenuKeyCensusTests` holds the map against them in every `make check`, both ways: a clash that is not in its table fails, and so does a row of its table that is no longer found while Arbor has the key.
Whoever adds a default that one of these apps has hears of it there, and writes it into both tables, the test's and this one.

Read on 2026-10-15, macOS 26.6.2, US keyboard, in three runs: **82 menu bars**. 62 that a hosted Mac comes with (61 of Apple's apps and utilities: Finder, Mail, Messages, Notes, Safari, Terminal, Xcode and the rest; Chrome
for Testing), Chrome, Firefox and Edge, and 17 widely used free apps from the package manager: Slack, Discord, Telegram, Signal, WhatsApp, Zoom, Visual Studio Code, Sublime Text, Zed, iTerm2, Notion, Obsidian, Figma,
Spotify, Raycast, Postman, GitHub Desktop.

| Arbor's key | App | What it is there |
|---|---|---|
| ⌃⌥⌘← `dock left` | Xcode | Show Previous Location in History |
| ⌃⌥⌘→ `dock right` | Xcode | Show Next Location in History |
| with a finger on fn: ⌃⌥⇧← ⌃⌥⇧→ ⌃⌥⇧↑ ⌃⌥⇧↓ `focus …` | 81 of the 82: macOS's own Window → Move & Resize | Left, Right, Top, Bottom & Quarters: it arranges the windows in front |

**None of Arbor's shortcuts on ⌃⌥ and one key is in any of the 82**, the nine among them. ⌃⌥ without ⌘ is rare in menus: Xcode (⌃⌥; and ⌃⌥: walk the bookmarks), Sublime Text (⌃⌥⇥ and ⌃⌥⇧⇥: next and previous tab),
Figma (⌃⌥⇧D: Save Debug Info…), Visual Studio Code (⌃⌥⇧`: New Terminal Window). ⌃⌥⌘ is busier: Finder (1 to 7, C), Xcode (twenty items), Mail ([ and ]), Terminal (R, L, /), Notes (Z), Photos (M), Activity Monitor (S),
iTerm2 (two, with ⇧), Sublime Text and Visual Studio Code (one each).

**Keys this page assigns or reserves that are not in the map**, and so not under the test: ⌃⌥⇥ and ⌃⌥⇧⇥ (F04) are Sublime Text's next and previous tab; ⌃⌥⇧D (F49) is Figma's Save Debug Info…; ⌃⌥⌘[ and ⌃⌥⌘] (F59) are
Mail's previous and next unread mailbox and Xcode's previous and next destination. None destroys or hides. Whoever brings one of them into the map meets it in the test.

| Not read | Why |
|---|---|
| VLC | no menu bar in two runs; in the second, ten readings over half a minute, hidden and shown. (So had Print Center in that run, which had one in the two before: its rows are from those) |
| Warp | the download failed, in two runs |
| PowerShell | a shell in a Terminal window: no menu bar of its own in two runs; left out of the third |
| Screenshot | did not start as an app in two runs; left out of the third |
| Siri, Launchpad, Mission Control, Time Machine, Apps | views of macOS's own: never opened |
| Migration Assistant, Boot Camp Assistant, whatever is called Install… or Erase… | they log out, erase, migrate or install: never opened |
| All Xcodes but the selected one | one of the many on a hosted Mac |
| **Whatever an app shows only with an account, a document or a project** | Every app was read at the first window it shows on a fresh Mac: no Apple Account, nothing open, nobody signed in. That holds for the chat and call apps, for Notion, Figma, Spotify, Postman, GitHub Desktop and Raycast, and as much for Mail, Messages, Music or Xcode. **Nobody signs in anywhere: no account is made or borrowed for this** |

How blind that last row makes it, this page can tell in one place: "Never bind by default", above, has from memory ⌃⌥⌘F, ⌃⌥⌘G, ⌃⌥⌘U and ⌃⌥⌘↩ for Xcode. The census found G and U there, not F and not ↩. Either memory
is wrong or those two show only with a project open: not known.

**⌃⌥A is in none of the 82 either.** So that a census would have caught the fault it was built after is **not shown**: whether the app of that complaint has the key in a menu at all, or only once signed in, is not known,
and a hosted Mac cannot tell. What guards against that fault is not this table: it is that a key of Arbor's never reaches another app while Arbor's item is in the menu bar, and that ⌃⌥A leaves the map for good. The census
guards the defaults against what can be read. Its own proof that it would find such a key is four real rows on other keys, and a made-up app in a test.

**With a finger on fn.** On Apple's keyboards fn makes another key of ←, →, ↑, ↓ and ↩ (Home, End, Page Up, Page Down, Enter), and fn sits beside ⌃. Arbor does not hold ⌃⌥ with those five and will not: five more keys
taken on a guess. For each of Arbor's keys on an arrow or ↩ the test looks for what fn makes of it, written either way: by the other key's code, or as macOS writes its own Window → Move & Resize, with the Globe key among the
modifiers and the arrow's own code. **For ⌃⌥ alone: in no menu bar.** For ⌃⌥⇧ with an arrow: the third row of the table. Which of the two ways a real keyboard sends has not been tried with a finger. By their own lists (below), Zed
has ⌃⌥Page Up and ⌃⌥Page Down: they scroll.

### By their own lists

A page in an app's window can take a shortcut and show it in no menu, so for widely used apps there is a second table: what the app's own default keymap, its in-app list of shortcuts or the source of its help page says
about ⌃⌥ and one key on a Mac, read in the vendor's own repository or archive on 2026-10-15. **16 read; 14 not read: 12 could not be reached from where this was written, for 2 no list of their own was found. For
those the table is empty, not clean.**

| Key | Who has it, by its own list | Destroys or hides? |
|---|---|---|
| ⌃⌥←, ⌃⌥→ | Visual Studio Code and Zed: the cursor moves by part of a word (Zed's terminal: split the pane). JetBrains IDEs: resize the tool window. Rectangle: left and right half | no |
| ⌃⌥↩ | Visual Studio Code: run a chat's code in the terminal. Zed: run in place, in a notebook. Rectangle: maximize | no; two of them run something |
| ⌃⌥Space | Visual Studio Code: focus of the suggestion's details. JetBrains IDEs: class name completion | no |
| ⌃⌥F | Zed, JetBrains IDEs, Xcode (its list of 2011): forward by a word, or part of one. Rectangle: the centre third | no |
| ⌃⌥G | Rectangle: the last third | no |
| ⌃⌥[, ⌃⌥Z, ⌃⌥⎋ | nobody | |
| **⌃⌥D** `desktop`, in today's map and not among the nine | **Zed: deletes to the end of the part of a word.** JetBrains IDEs: Debug… | **yes, text, and ⌘Z brings it back** |
| others of today's map, not among the nine | ⌃⌥↑ ⌃⌥↓: Zed's terminal (split), JetBrains (resize), Rectangle (halves). ⌃⌥N, ⌃⌥R: Visual Studio Code, JetBrains. ⌃⌥M: JetBrains. ⌃⌥0: Zed. ⌃⌥⇧ with arrows, F, R: Visual Studio Code, Zed, JetBrains, Rectangle | no |

What else destroys or hides among all the ⌃⌥ chords read is on keys that are not Arbor's: ⌃⌥W closes a panel in Zed; ⌃⌥⌫ and ⌃⌥⌦ delete a word or part of one in Visual Studio Code, Zed and Xcode; ⌃⌥H does in Zed. "Never bind by
default", above, has had ⌃⌥W and ⌃⌥⌫ from the start.

- Read, with ⌃⌥ chords: Visual Studio Code, Zed, JetBrains IDEs (the macOS keymap), Xcode (only Apple's archived list of 2011), Rectangle, which is a window manager and takes its keys from every app, as Arbor does:
  whoever runs two has chosen.
- Read, none in its list: eleven more, chat apps, browsers (from their sources, not their help pages), a player, a notes app (editing shortcuts only), two terminals (one names few, the other's file calls itself incomplete) and
  a Git client among them.
- **Not read:** fourteen, most of the chat, call, design and mail apps built on web technology among them: the very apps this table was wanted for. What those of them that could be installed have in their menu bars is in
  the first table; the rest is **not known**.

### What the tables cannot say

- The first sees what an app shows **in its menu bar**, at the first window it shows, on a US keyboard. An app whose window is a web page can take a shortcut in the page and show it in no menu.
- **macOS does not tell Arbor when another program has registered the same key: then both get it, or the other alone.** Asked to register a hot key that another process already has, it says yes, in either
  order (measured on the same day): both programs then hear every press and both act; and a program that registered its own as exclusive gets the press alone, while
  Arbor goes on believing the key is its own. No list can show that, and `doctor` cannot either.
- A menu bar differs a little from one launch to the next, and an app goes on building it after it has one. The third run read each app until two readings three seconds apart agreed; the first two read once. A file keeps
  every shortcut ever read in that app, whatever the version: the README beside the files has the versions.

**Arbor itself reads no other app's menu bar** (the product owner, 2026-10-15). A reader in the app was built and dropped: whoever asks `arborctl` is typing into a terminal, so the app in front, the one that
would be read, is the terminal; and a menu bar was 41 to 894 items, and took an app between 30 ms and nine and a half seconds. The census guards the defaults, on GitHub's Macs and on nobody else's; a shortcut
a person makes is their own.

## Other keyboard layouts

A letter, digit or sign in a shortcut is the key that types it on the layout in use (F44, `KeyLayout.swift`). For whoever assigns the next default:

- **Letters are safe everywhere**: every Latin layout types all 26 alone, and for the others macOS supplies a Latin one.
- **Digits** are typed with ⇧ in France, Belgium and the Czech Republic. They stay on the digit keys and are shown as digits.
- **`,` `.` `-`** are typed alone on most European layouts, in other places than on a US keyboard; the shortcut follows them.
- **`[` `]` `\` `` ` `` `/` `;` `'` `=`** need ⇧ or ⌥ on most European layouts. They stay where a US keyboard has them and are shown as what is printed there (⌃⌥Ü), which
  nobody can guess from the documentation. TrellisWM's ⌃⌥[ and ⌃⌥] are frozen; do not add to them.
- **A sign with ⇧ means what ⇧ makes of it on a US keyboard**, if the layout types that with ⇧: ⌃⌥⇧/ (⌃⌥?) is ⌃⌥⇧ß in Germany and ⌃⌥⇧, in France, not ⌃⌥⇧7, which saves view 7. Digits with ⇧ stay digits.
- **Two signs can land on one key**: `/` falls back to the key that types `-` in Germany, and to the one that types `=` in France. So ⌃⌥- (reserved for F16) rules out ⌃⌥/ with the same modifiers; ⌃⌥⇧/ (F43) is fine.
  `everyDefaultShortcutWorksOnEveryLayoutAndNoTwoShareAKey` fails when a new default collides on a German, French, Dvorak or Russian keyboard.

## Command names that are already taken

Not keys, but the same race. `arbor-sim` has its own words that it handles **before** passing a line to the controller,
so a product command with one of these names cannot be driven in the simulator or in `collab/scenarios`:
`open`, `close`, `minimize`, `restore`, `focus`, `cursor`, `drag`, `move`, `pull`, `seam`, `tile`, `flush`, `quiet`, `loud`, `expect`,
`press`, `from`, `type`, `wait`, `keydown`, `keyup`, `key`, `mouse`, `hide`, `unhide`, `background-focus`, `displays`, `title`, `classic`, `settings-file`, `keyboard`, `min`, `fullscreen`, `transitions`, `field-type`, `field-cancel`, `map`, `revoke`, `grant`, `macos`, `pick-up`, `let-go`, `shove`;
and on branches not merged yet `dblclick`, `tab-tear`, `tab-click`, `tab-drop`, `strip-drag`.
A feature that needs one (`focus left`, `restore` for presets) must teach the simulator to tell the two apart in the same change
(`focus 101` is the user clicking a window; `focus left` is the command).

`go` is an alias of `neighbor` (`go left`) and goes to a named space (`go Writing`, F20): a direction word means the neighbour, anything
else a name, and a space cannot be named `left`, `right`, `up`, `down`, `top` or `bottom`, nor any other word that is read as a direction
(`l`, `r`, `u`, `d`, `north`, `south`, `east`, `west`).

## Reach

⌃⌥ is two neighbouring keys under the left ring and middle fingers; ⌃⌥⌘ is three in a row, pressed as one; ⌃⌥⇧ needs the little finger to
stretch, which suits the rarer counterpart actions. Everything a newcomer needs in the first ten minutes is ⌃⌥ plus a key that can be found without
looking: Space, ↩, the arrows, ⎋.
