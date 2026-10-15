# The words Arbor uses

One word per idea, the same in the menu, the help, the README, replies, the settings window and onboarding.
**If you write text a user can read, take the words from the left column.** Code may keep its own names.

Written by the executor swarm, 2026-10-14 (product review); for the documenter to review.

## Words users see

| Say | Meaning | Do not say | Why |
|---|---|---|---|
| **dock** (verb), **docked** | Put a window into the arrangement, where it shares the screen with its neighbours | "tile" as a verb, "snap", "the dock" as a noun | TrellisWM's word. As a noun it is macOS's Dock; "tile" is macOS 15's own feature, which Arbor asks people to turn off |
| **macOS tiles** | What macOS's own feature does to a window dragged to a screen edge, in a sentence about macOS: "macOS tiles a window that is dragged there" | for anything Arbor does | macOS's own word for its own act (Q23). Likewise "wallpaper" and "fill screen" where a setting of macOS's is quoted or explained by its label |
| **undock**, **undocked**; a **loose** window | Take a window out of the arrangement; it is like any Mac window again: "Undock Focused Window", "Undock All Windows" | float, floating (they stay the command's, the settings' and the specs' word), unmanaged | **Changed on 2026-10-15.** Four of four readers who knew nothing tripped over "Float" ("means nothing; I would not press it in a panic"), and Float All is a way out. "Undock" needs no learning once "dock" is learnt. The strings follow in a pull request of their own; until then the app still says Float |
| **the Desktop** (capital D) | The space between docked windows where floating windows live | wallpaper (that is only the picture), desktop space | TrellisWM's word. Say "macOS desktops" for Mission Control's Desktop 1, Desktop 2 |
| **space** (small s) | Anything the view can fill: a window, a group of windows, the Desktop, everything | node, container, split, workspace | TrellisWM's word ("neighbouring space") |
| **macOS Spaces** | Mission Control's desktops | Spaces on its own | So that it is never taken for the line above |
| **group** | A space made of several windows | split, container, column, row | What it looks like |
| **the view** | What is on screen now | camera position, viewport | "Dock at the left edge of the view" |
| **saved view** | A view kept under a number from 1 to 9 | bookmark, slot | TrellisWM's word |
| **name** (noun and verb), **named space** | A few words a space is called by: "Name This Space…", "go to Writing" | label, tag, title (windows have those), workspace | Saved views have numbers, spaces have names. Never "Spaces" alone as a title, which reads as macOS's; the menu lists names under Saved Views (docs/MENU.md) |
| **Go to…** | The palette (⌃⌥G) that finds a window, a saved view or a named space by typing, and takes the view there; or a command by its name in the menu, and runs it | finder (that is where macOS keeps files), picker, switcher, launcher, search | A menu's word for "take me there", and G is its key. The command is `find` |
| **zoom** | Any move in or out: pinching, stepping | | The general word |
| **fill the screen**, "fills the screen" | Zoom until one window fills the view: "Fill the Screen"; "Docked · ⌃⌥↩ fills the screen with it". Wherever it is taught, a few words more: "the menu bar stays, and it is not macOS's full screen" | frame, framed (they stay the specs' word; the command is `zoom`), maximise, full screen, zoom in, focus on | **Changed on 2026-10-15.** Twelve fresh readers, three a word, of 10 for "is the phrase clear": Fill the Screen 8 8 8, Focus On 6 6 6 (clashes with "focused window" and macOS's Focus), Zoom In 5 5 5 (bigger text, the Accessibility zoom), Frame 4 4 4 ("a border", "a screenshot"). Eight of the nine who did not have it proposed it unprompted. Twelve of twelve were not sure whether it is the green button's full screen, whatever the word: hence the few words more. A group or the Desktop "fills the screen" likewise. The strings follow; until then the app still says Frame |
| **step out**, **step in** | One level wider, one level closer | up, down, parent, child | TrellisWM's words |
| **Show Everything** | The widest view of a display | overview, root, home (that is the command for every display at once) | TrellisWM's words |
| **peek** (verb and noun), **outline** | Hold the Show Everything shortcut to look, let go to land: what is outlined is framed | overview mode, Exposé, quick look, spring-loaded (fine in an explanation), highlight, selection | Short, and says that it ends by itself. The focus ring is a **ring**; the thing a peek draws is an **outline** |
| **back**, **forward** | Where the view has been | history, undo (that is for the arrangement) | As in a browser |
| **out of view** | Where windows outside the view are. "3 windows are out of view" | hidden (⌘H hides), parked, minimised, off-screen, closed | The first fear of a newcomer is that they are gone. "Out of view" says they exist and that the view is what changed |
| **keep in view**; **pin**, **pinned** | A floating window that keeps its place on the display wherever the view goes, with **room** of its own beside every view where it lies near a screen edge (a **strip**, in the code and the specs only). Where it has none: "other windows can cover it here"; `state` says `covered`. The menu says what happens: Keep “Zoom” in View. The commands, the rule and `state` say `pin` | always on top (Arbor cannot promise it), sticky (that is macOS Spaces), companion | "In view" is the opposite of "out of view", which people already know |
| **summon**, **summoned** | Bring an app's window over the view for a moment; sent away, it is **out of view** | scratchpad, drop-down, Quake mode, stash (that is the code's word), hide (⌘H hides) | Says who acts and that it comes to you, not you to it |
| **guest** | A floating window that belongs to the view it opened over instead of the Desktop: it goes out of view and comes back with that view | child, attached, transient, sticky | It visits; docking it or closing what it opened over ends the visit. In `state` and the settings; menus and replies seldom need it |
| **tile** (noun only) | The small stand-in, with the app's colour and icon, for a window or group too small to use | cover, thumbnail, icon, placeholder | Already in the README. Never a verb |
| **minimap** | The small picture of a display's whole arrangement, with the space in view marked, that shows on ⌃⌥M and, if asked to, after the view has moved | overview, map (on its own), navigator, radar, thumbnail | What games and editors call it. One word, small m |
| **tab**, **tab group** | Several windows sharing one place under a strip of tabs | stack | TrellisWM's words. Stacks are a Dock and Finder feature |
| **gap** | The space between docked windows; drag it to resize both | seam, divider, gutter, handle | TrellisWM's word, and the setting is `gap` |
| **arrange** | Dock every window in a grid ("Arrange Windows"); and, of an app, be looked after by Arbor at all ("Don't Arrange Music") | manage, handle, tile | TrellisWM's menu uses both senses |
| **shortcut** | Keys that run a command | hotkey, key binding, chord | Apple's word. The `bindings` and `hotkeysEnabled` keys stay for old files; `shortcuts` is an alias of the `bindings` command |
| **display** | A monitor | screen (except "screen edge"), monitor | Apple's word |
| **focused window** | The window the keyboard types into | active, frontmost, current, key window | Already everywhere |
| **pause**, **resume** | Arbor lets go of windows, shortcuts and gestures for a while | disable, suspend, stop | Says that it comes back |
| **hold** (the view), **held**, **release** | "Hold This View: nothing moves the view, not even your own keys. For a shared screen." Replies: "the view is held" | lock, freeze, pin (that is for a window, F49), presenting mode | Says what stays and that it is let go again. The lock is only the icon |
| **hold still**, **holding still** | "Hold Still: Arbor moves nothing by itself; your keys, gestures and ⌘Tab still work. Starts by itself during calls." | do not disturb, quiet, call mode | The same verb and the same way out as hold, and true of recordings as well as calls |
| **Shortcuts Off in “App”**, "shortcuts are off in Emacs" | The app keeps ⌃⌥ and its drags for itself; its windows stay arranged | pass-through (that is only the command's and the setting's name), "while Emacs is frontmost", ignore, exclude | What a person sees is that the shortcuts are off (F41) |
| **camera** | The metaphor, in the README's first paragraph and onboarding's first sentence only | in menus, replies, settings | A good way to explain the idea once; after that people think about what they see, not about a camera |

## Words that stay in the code

`node`, `leaf`, `split`, `stack`, `seam`, `park`/`parked`, `managed`, `workspace`, `root`, `chord`, `binding`, `enforce`, `adopt`, `dormant`, `stash`/`stashed`.
Scripts meet four of them, and that is fine as long as the help explains them: `zoom-node` and the `n3` in replies (a space's number), and
`parked`, `managed`, `stashed` and `tree` in `arborctl state`.

## Names scripts see

JSON keys, values, exit codes and options are promised never to change once released, so there is one name per idea here too, the same in
`arborctl watch` (F24), the queries (F50) and `arborctl state`. Prose is British; names in a protocol are names (`minimized`).

| Idea | Name |
|---|---|
| Docked or floating | `docked`: true or false (as text, `docked` / `floating`) |
| Where a window is | `state`: `in-view`, `out-of-view`, `tile`, `minimized`, `hidden`, `full-screen`, `other-space`. New values may be added |
| What happened to a window | `change`: `opened`, `closed`, `adopted` (Arbor arranges it from now on), `released` (no longer), `docked`, `floated`, `state`, `renamed` |
| Words for a thing | `label`: Arbor's own words ("Mail and Notes", "display 1"). `name`: what the thing is called by whoever named it, never by Arbor: a space by a person, a display by macOS, its maker or a device over AirPlay. Names are sent to whoever watches, never logged, and stay out of traces |
| What kind of space | `kind`: `everything`, `desktop`, `window`, `group` |
| A display | `display`: its number, as commands take it (`@2`; 1 is the main display). `displayID`: its UUID, which survives unplugging |
| Numbers | An object that **is** a window or a display has `id`; one that refers to it says `window`, `display`, `displayID`. A display in `displays` has both `id` and `displayID`, so that one filter works on every payload |
| A space's number | `node`, for `zoom-node` |
| Rectangles | `{"x", "y", "width", "height"}`, global points, origin at the top left of the main display, y downward |
| Window titles | `title`, only when asked for with `--titles` (`state`, the debugging view, always has them) |
| Exit codes | 0 done; 1 Arbor said no; 2 not running; 3 `watch` was cut off; 4 no answer in time; 64 the line cannot be read and nothing was sent |
| A refusal | The reason on **stderr**, exit code 1, nothing on stdout, with `--json` too: the exit code always tells the truth. During a pause the queries answer the empty list with 0; `status` and the events say that it is a pause |
| Options | `arborctl`'s own (`--json`, `-q`, `--timeout`, `--keep-going`, `--help`, `--version`) anywhere on the line. Any other `--option` before the command word is refused (64); after it, it belongs to the command |
| Several commands | `a , b , c` on one line, or `arborctl - < file`. Both stop at the first failure unless `--keep-going` |

## Sentences to reuse

Onboarding, the HUD (F43), the README and replies should say these the same way.

- What Arbor is: "Dock windows side by side, then zoom between them."
- When windows leave the view for the first time: "Your other windows are out of view, not closed. ⌃⌥Space shows everything."
- The three ways back, always in this order: "Show Everything (⌃⌥Space) · Float All Windows (⌃⌥⇧F) puts your Mac back to normal · quitting Arbor brings every window back into view." The coach names one (Q29; three blurred for four readers of six): "⌃⌥⎋ pauses Arbor: every window is as it was. Quit does the same."
- Why Accessibility: "macOS lets an app move other apps' windows only with Accessibility permission. Arbor reads where windows are and their titles, moves them, and sends nothing anywhere."
- Why Screen Recording (optional): "With it, windows show their contents while they move. Without it they show their app's colour and icon. Nothing is recorded or stored."
