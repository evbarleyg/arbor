# Scripting Arbor

Everything Arbor does is a command with a text form, and the same text works from a terminal (`arborctl dock left`), a shortcut
(`"ctrl+opt+h": "dock left"` in `settings.json`), and a URL (`arbor://dock/left`). This page is for people who write Raycast scripts, SketchyBar
plugins, Hammerspoon glue, Shortcuts and dotfiles around them. `arborctl help` lists the commands; [LAYOUTS.md](LAYOUTS.md) is about whole
arrangements as a line of text.

| You want to | Use |
|---|---|
| Do something | [`arborctl <command>`](#arborctls-manners), or an [`arbor://` URL](#urls) where only a link fits |
| Say which window | [its app's name](#naming-a-window), `focused`, `pointer`, or its number |
| Know one thing now | [`windows`, `where`, `views`, `displays`, `version`](#asking): a line per item for `cut`, or `--json` for `jq` |
| Know everything now | [`arborctl state`](#json) |
| Be told when things change | [`arborctl watch`](#arborctl-watch) |
| Try a script without touching your windows | [the simulator](#trying-a-script-without-touching-your-windows) |

Every transcript and script marked `console` or shown as a worked example is run by the tests (`DocTranscriptTests`, `ScriptingExampleTests`) and prints what it says here, and every event is what Arbor sends, byte for byte (`ArborEventTests`).

## arborctl's manners

`arborctl` is inside the app, at `Arbor.app/Contents/Helpers/arborctl`; `make install` links it into a folder on your `PATH`, or do it by hand:

```bash
ln -s ~/Applications/Arbor.app/Contents/Helpers/arborctl /usr/local/bin/arborctl
```

```
arborctl [options] <command> [, <command>]…
arborctl [options] -                            commands from standard input, one per line
```

| Exit code | Meaning |
|---|---|
| 0 | done |
| 1 | Arbor said no. The reason is on **stderr**, so `$(…)` stays clean |
| 2 | Arbor is not running |
| 3 | `watch` was cut off: Arbor went away without saying that it was stopping |
| 4 | Arbor is there but no answer came in time. That does not mean "not done": Arbor has the command and runs it when it gets to it, so trying again can undo a toggle |
| 64 | the command cannot be read. Found out by `arborctl` itself, and nothing was sent |

| Option | |
|---|---|
| `--json` | print the answer as JSON (see below) |
| `-q`, `--quiet` | print neither answers nor refusals and keep the exit code: `arborctl -q zoom Safari \|\| open -a Safari`. A command that cannot be read (64) is still said: it is a mistake in the script, which silence would hide |
| `--timeout <seconds>` | how long to wait for each reply, from 0.1 to 600; 5 unless you say. Also `--timeout=2` |
| `--keep-going` | with several commands, carry on after one that failed |
| `--help`, `-h` | the help, or with a command its usage; works without Arbor running |
| `--version` | this `arborctl`'s version |
| `--` | what follows belongs to the command, whatever it looks like |

These are `arborctl`'s own, and they count **anywhere on the line**, because people append `--json`. Any other option belongs to the command if it follows the command's first
word (`windows --titles`, `layout --open`), and is a mistake before it.

<!-- windows: Safari, Mail -->
```console
$ arborctl dock Safari left
docked w101 at the left edge
$ echo $?
0
$ arborctl zoom Notes
arborctl: no window of Notes; `windows` lists them
$ echo $?
1
$ arborctl zom Safari
arborctl: unknown command `zom`; did you mean `zoom`?
$ echo $?
64
$ arborctl --titles windows
arborctl: unknown option --titles; `arborctl --help` lists them
$ echo $?
64
```

- Several commands in one call are separated by a comma on its own. All of them are read before the first is sent, and they stop at the first that fails. With `--keep-going` they
  carry on, unless Arbor is not there at all. Either way the exit code is the **first** failure's:

<!-- windows: Safari, Mail -->
```console
$ arborctl dock Safari left , dock Mail right , home
docked w101 at the left edge
docked w102 at the right edge
showing everything
$ arborctl float Safari , zoom Notes , home
w101 is floating
arborctl: no window of Notes; `windows` lists them
$ arborctl --keep-going zoom Notes , home
arborctl: no window of Notes; `windows` lists them
showing everything
$ echo $?
1
```

- `arborctl -` reads commands from standard input, one per line, written as in `settings.json`: a name with spaces in quotes. Blank lines and lines that start with `#` are skipped, so a
  batch can be a file with comments. It is read line by line as it arrives, so the other end can be a program that waits for each answer. It stops at the first failure like a
  line with commas, takes the same options, and says which line it was:

<!-- file: morning.arbor -->
```sh
# The morning: the browser on the left, mail and notes on the right.
dock Safari left
dock Mail right

dock "Sticky Notes" beside Mail bottom
home
```

<!-- windows: Safari, Mail -->
```console
$ arborctl - < morning.arbor
docked w101 at the left edge
docked w102 at the right edge
arborctl: line 5: no window of Sticky Notes; `windows` lists them
$ echo $?
1
$ arborctl --keep-going -q - < morning.arbor
$ echo $?
1
```

- `arborctl help <command>` prints a command's usage, its other names and the shortcuts bound to it now. `arborctl <command> --help` is the same.

```console
$ arborctl help zoom
zoom [window]
  frame one window on its own; without a window, again to return
  also: frame
  shortcut: ⌃⌥↩ zoom
```

- `arborctl completions zsh|bash|fish` prints a completion script; `arborctl help completions` says where to put it. It completes commands, edges, options and the apps that have windows.
- `arborctl --version` prints its own version, whether or not Arbor runs, and says so when the Arbor that is running is another build (after an update it may still be the
  old one). `arborctl version` asks the running Arbor for its own.
- `ARBOR_UNCHECKED=1` sends lines without reading them first, for talking to a newer Arbor than this `arborctl`.

## Naming a window

Wherever a command takes `[window]`, it takes any of these. Which window a name means is decided when the command runs.

| Write | Meaning |
|---|---|
| nothing | the focused window |
| `Safari`, `com.apple.Safari` | that app's most recently focused window that Arbor arranges; one that is minimised, hidden or on another macOS Space only if it has no other |
| `"Visual Studio Code"` | a name with spaces: quote it for the shell, and `arborctl` passes it on as one name |
| `412` | the window with that number, from `windows` |
| `focused` | the focused window, said out loud: `zoom focused` always frames, where `zoom` pressed twice returns |
| `pointer` | the window under the pointer |

Names work as in `layout`: capitals do not matter; the exact name or bundle id wins; failing that the last part of a bundle id (`Chrome`), then whole words
of the name (`Code`). An app called `left`, `beside`, `focused` and the like needs quotes inside the command (`arborctl zoom '"left"'`) or its bundle id.

<!-- windows: Safari, Mail, Visual Studio Code [com.microsoft.VSCode], Safari -->
<!-- focuses: 104 -->
```console
$ arborctl dock Safari left
docked w104 at the left edge
$ arborctl dock Mail beside Safari bottom
docked w102 below w104
$ arborctl dock "Visual Studio Code" right
docked w103 at the right edge
$ arborctl float vscode
w103 is floating
$ arborctl zoom Slack
arborctl: no window of Slack; `windows` lists them
```

**A number gone wrong is never taken for a name.** It is what a script's mistake looks like, and "no window of 4294967296" would send you looking for
an app. So a word with digits and no letters (`1.0`, `1,000`, `١٢`), what other tools print for a number (`1e3`, `0x10`, awk's `nan` and `inf`), and `w` or `n` with
nothing but digits after it are refused before anything is sent: `w$id` with `id` empty is `w`, with `id` already `w412` it is `ww412`, and `n7` is a
space, not a window. `1Password`, `7zip` and `w3m` are names like any other. An app that really is called `0xED` needs quotes, like `left`.

**Quotes hold a word together, in every command.** The shell takes yours off and `arborctl` puts them back round an argument with a space or a slash in it, so `arborctl summon "Visual Studio Code"`,
`arborctl bind "ctrl+opt+/" desktop` and `arborctl rule add com.apple.Safari float title "My Page"` arrive as you meant them. Where no shell is in between (a shortcut in `settings.json`, a line of a batch) you
write them yourself. Arbor takes them off again; only where a window can stand do they also say "this is a name": `dock "left" left`. A quote that nothing closes is a character like any other.

**Where a command keeps a list of apps** (`exclude`, `include`, `pass-through`) a name works too, for an app that has a window open or is on the list; the list gets its bundle id. An app that is not open goes by its
bundle id, and a word that is neither is refused rather than listed.

<!-- windows: Safari -->
```console
$ arborctl zoom w
arborctl: expected a window, and w is not a window's number; an app called w needs quotes, or its bundle id
$ echo $?
64
```

## Asking

Five small queries. As text, each prints one line per item with its fields separated by **tabs**, which is what `cut -f` splits at; when a person is
looking (stdout is a terminal), `arborctl` lines the columns up instead. With `--json`, each prints one array of objects on one line. Fields are only ever added, at the end.

### windows

The windows Arbor arranges, most recently focused first; those that are minimised, hidden or on another macOS Space come after the others. That is the order in which names are looked up, so the
first line with an app on it is the window its name means.

<!-- windows: Safari "Hacker News" [com.apple.Safari], Mail "Inbox" [com.apple.mail], Notes "Shopping" [com.apple.Notes], Slack "general" [com.tinyspeck.slackmacgap] -->
<!-- focuses: 102 -->
```console
$ arborctl layout "Safari | (Mail / Notes)"
arranged 3 windows
$ arborctl zoom Mail
framed w102
$ arborctl windows
102  docked    in-view      1  com.apple.mail             Mail
101  docked    out-of-view  1  com.apple.Safari           Safari
103  docked    out-of-view  1  com.apple.Notes            Notes
104  floating  out-of-view  1  com.tinyspeck.slackmacgap  Slack
$ arborctl windows | cut -f1,6
102	Mail
101	Safari
103	Notes
104	Slack
$ arborctl windows --json | jq -c '.[0]'
{"app":"Mail","bundleID":"com.apple.mail","display":1,"displayID":"main","docked":true,"focused":true,"frame":{"height":851,"width":1416,"x":12,"y":37},"id":102,"node":4,"pinned":false,"state":"in-view","summoned":false}
$ arborctl windows --json | jq -r '.[] | select(.state != "in-view") | .app'
Safari
Notes
Slack
```

| Field | Text | JSON | |
|---|---|---|---|
| 1 | `102` | `id` | the window's number, for as long as it lives |
| 2 | `docked` | `docked`, `pinned`, `summoned` | as text `docked`, `floating`, `pinned` (it floats, and `pin` keeps it in view) or `summoned` (it floats over the view until the keyboard goes elsewhere); in JSON each is true or false |
| 3 | `in-view` | `state` | `in-view`, `out-of-view`, `tile` (too small to use: a tile stands in for it), `minimized`, `hidden` (⌘H), `full-screen`, `other-space` (another macOS Space) |
| 4 | `1` | `display` | the display's number, as in `displays` and `layout @2` |
| | | `displayID` | the display's UUID, as in `displays` and in every event |
| 5 | `com.apple.mail` | `bundleID` | `-` as text, no key in JSON, for an app without one |
| 6 | `Mail` | `app` | |
| 7 | | `title` | only with `--titles` |
| | | `focused` | it has the keyboard |
| | | `frame` | where it is now, `{"x","y","width","height"}` |
| | | `node` | the space it is docked in, for `zoom-node`; no key when floating |

Titles can hold anything a person is reading or writing, so they are never printed unless asked for, and never logged:

```console
$ arborctl windows --titles | cut -f6,7
Mail	Inbox
Safari	Hacker News
Notes	Shopping
Slack	general
```

### where

What each display's view shows, in the words replies use: a status bar's label. It is the `view` event of [`watch`](#arborctl-watch), asked for instead of waited for.

```console
$ arborctl where
1  Mail  n4  depth 2 of 2  3 out of view
$ arborctl where | cut -f2
Mail
$ arborctl out
stepped out to Mail and Notes (n3)
$ arborctl where --json
[{"apps":["Mail","Notes"],"canGoBack":true,"canGoForward":false,"deepest":2,"depth":1,"display":1,"displayID":"main","kind":"group","label":"Mail and Notes","node":3,"outOfView":2,"windows":[102,103]}]
```

| Field | Text | JSON | |
|---|---|---|---|
| 1 | `1` | `display` | its number; `displayID` in JSON is its UUID |
| 2 | `Mail and Notes` | `label`, `name` | `label` is Arbor's word for the space: "everything", "the Desktop", up to three apps, or "5 windows". `name` is yours, if you gave it one (`arborctl name Writing`); as text that is what stands here |
| 3 | `n4` | `node` | the space that fills the view (a number in JSON): the one that was framed, or the nearest around it that has anything to show |
| 4 | `depth 1 of 2` | `depth`, `deepest` | how often `out` can be run from here, and from the deepest space |
| 5 | `2 out of view` | `outOfView` | windows of this display that `windows` lists as `out-of-view` |
| | | `kind` | `everything`, `desktop`, `window` or `group` |
| | | `windows`, `apps` | the docked windows in view, in reading order |
| | | `canGoBack`, `canGoForward` | |

### views, displays, version

```console
$ arborctl save-view 1
saved view 1: Mail and Notes (n3)
$ arborctl show-all
showing everything
$ arborctl save-view 2
saved view 2: everything
$ arborctl views
1  1  Mail and Notes  n3
1  2  everything      n1  current
$ arborctl views --json
[{"current":false,"display":1,"displayID":"main","label":"Mail and Notes","node":3,"view":1},{"current":true,"display":1,"displayID":"main","label":"everything","node":1,"view":2}]
$ arborctl displays
1  main  0,0,1440,900  main,pointer,focus  -  -
$ arborctl displays --json
[{"builtIn":true,"display":1,"displayID":"main","focus":true,"frame":{"height":900,"width":1440,"x":0,"y":0},"from":{},"gap":12,"id":"main","main":true,"minimumUsableHeight":160,"minimumUsableWidth":240,"pointer":true,"screenEdgeBand":12,"visibleFrame":{"height":875,"width":1440,"x":0,"y":25}}]
$ arborctl version
Arbor 0.9.0 (build 214, 47a2ba9)
$ arborctl version --json
{"build":"214","commit":"47a2ba9","schema":2,"version":"0.9.0"}
$ arborctl --version
arborctl 0.9.0 (build 214, 47a2ba9)
```

- `views`: display, view number (what `view` takes), the space in words (its `name` if you gave it one, else its `label`), node, and `current` for the one that is showing. JSON has both words, and adds `displayID`.
- `displays`: number (`@1` is the main display, then from left to right and top to bottom), UUID (it stays the same when the display is unplugged and comes back; `id` in JSON, and `displayID` too, to join on), frame as `x,y,width,height`,
  which of `main`, `pointer` and `focus` apply (`-` for none), what macOS calls it (`name`), and the options it has of its own, as `gap 6 (builtin)`: the value, and the entry of `displays` in
  `settings.json` that gave it. JSON adds `visibleFrame`, without the menu bar and the Dock; `builtIn`; the four options in effect, whoever gave them (`gap`, `minimumUsableWidth`,
  `minimumUsableHeight`, `screenEdgeBand`); and `from`, which names the entry for each that has one. Which entries were skipped and why is said on stderr, beside the table.
- `version`: the version, the number of the build and its commit. JSON leaves out what is not known (a build that is in no bundle is `dev` and nothing more) and adds `schema`,
  that of `state`'s JSON.
- Coordinates are global points with the origin at the top left of the main display and y growing downward.
- **During a pause** Arbor is not looking, so `windows`, `where`, `views` and `displays` answer with nothing (`[]` as JSON) and exit code 0. A pause is not a failure, and a status bar can tell the two apart by
  the exit code alone; `arborctl status` says that it is a pause. Before Arbor has started, or without Accessibility, they fail with 1 and the reason; but for `displays`, which has no rows then and still says what became of `settings.json`.

## JSON

- **`--json` prints the answer, not an envelope**, when the command has an answer of its own (the queries above, `layout`, `settings`). For any other command it prints the whole reply, `{"ok":true,"message":"…"}`.
- A refusal is never JSON on stdout: exit code 1, the reason on stderr.
- **Rectangles are objects**: `{"x":0,"y":25,"width":720,"height":875}`.
- Keys are camelCase and only ever added.
- **A word means one thing wherever it stands**, in these answers and in the events of `watch`: `docked` is true or false; `state` is where a window is; `label` is a space in
  words, and `name` only a name you gave one; `display` is a display's number, which commands take (`@2`), and `displayID` its UUID; what *is* a window or a display has an
  `id`, and what refers to one says `window`, `display` or `displayID`.

`arborctl state` prints everything at once, as it always has, inside the reply: `arborctl state | jq .state`. Its `schema` is 2 (1 wrote rectangles as `[[x,y],[width,height]]`, and in `windows` its `display` was the UUID, which is `displayID` now, as everywhere; `display` is the number).

```console
$ arborctl state | jq -c '.state.schema, .state.displays[0].visibleFrame'
2
{"height":875,"width":1440,"x":0,"y":25}
$ arborctl where --json | jq -r '.[0].label'
everything
```

| Key in `.state` | |
|---|---|
| `schema`, `running`, `paused`, `accessibility`, `focused` | |
| `displays[]` | `id`, `frame`, `visibleFrame`, `camera` (the node that fills the view), `tree`, `windowFrames` (docked windows in view, by number), `tiles[]`, `desktopFrame`, `floating[]`, `savedViews`, `canGoBack`, `canGoForward`, `named` (the numbers of the spaces that have a name), `names` (only with `--titles`: `{"Writing": 7}`) |
| `displays[].tree` | `root`, `desktop`, `nodes`: each node has `id`, `parent`, `weight` and `kind` (`split` with `axis` and `children`, `stack` with `windows` and `active`, or `desktop`) |
| `windows[]` | every window Arbor can see, arranged or not: `id`, `pid`, `app`, `bundleID`, `title` (only with `--titles`), `frame`, `managed`, `docked`, `parked` (out of view), `minimized`, `hidden`, `display`, `displayID` |

**`state` holds no words but Arbor's own, apps' names and bundle ids unless you ask** (`arborctl state --titles`): a title can be anything you are
reading or writing, the name of a space is your own word, and `state` is what gets pasted into a report. **A script that goes by titles or names
asks with the flag.** `go <name>` needs none. `where` and `views` do say a space's name, as replies and the `view` event do: they are what a status bar shows you.
Events hold no title unless you ask.

## `arborctl watch`

```bash
arborctl watch                      # every event
arborctl watch view focus           # only these kinds
arborctl watch focus --titles       # with window titles
```

`watch` stays connected and prints one event per line, as it happens: a JSON object whose first key is
`event`. Each line is written out at once, also into a pipe.

```json
{"event":"view","apps":["Safari"],"canGoBack":true,"canGoForward":false,"depth":1,"displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","kind":"window","label":"Safari","node":1,"outOfView":2,"windows":[412]}
```

### What you can rely on

- **The first line is [`hello`](#hello)**, with the whole state in the same words as the events, so a script needs no
  second request and misses nothing in between.
- **Events say how things are, not what was done.** Arbor waits until it has finished reacting to a command, a click
  or an app, then reports what is different from the last time. One command gives at most one `view` and one `layout`
  per display; something that changed and changed back in the same breath is never mentioned.
- **No repeats.** A line is sent only if something in it differs from the last line of its kind (for that display, or window).
- **One order**, when several things change together: `settings`, `started` or `resumed`, `displays`, `window`, `layout`,
  `view`, `focus`. A window is announced before anything mentions its number.
- **A filter** names the kinds you want. `hello`, `paused`, `resumed` and `quitting` come whatever the filter: whether Arbor is
  there at all is news for everyone.
- **Titles are private.** They are sent only to a client that asked with `--titles`, and are never logged. The name you gave a space (`name` in `view`) goes to
  every client: you typed it to be shown, and the socket is yours alone. It is never logged either.
- **Names stay.** Fields may be added; none will be renamed, removed or change meaning without `protocol` in `hello`
  going up. Ignore fields and events you do not know.
- **New values may appear** for `state`, `change` and `kind` without `protocol` going up, as Arbor learns new things to do with a window or a
  view. Treat a value you do not know as you treat a field you do not know: carry on.
- Fields with nothing to say are left out rather than `null`. In `jq`, `.savedView // "none"`.

### When it ends

| | `arborctl watch` exits with |
|---|---|
| Arbor quits: the last line is `{"event":"quitting"}`, sent after every window is back in view | 0 |
| The reader leaves, as in `arborctl watch \| head -n 1` | 0 |
| 16 clients are watching already | 1 |
| An event name Arbor does not know: found out by `arborctl` itself | 64 |
| Arbor is not running | 2 |
| Arbor is running but `hello` did not come in time (five seconds, or `--timeout`); after `hello` it waits as long as it takes | 4 |
| Arbor crashed or was killed; or **your script stopped reading**: Arbor never waits for a client, and hangs up on one that is 256 KB behind | 3 |

A pause does not end it. A script that should outlive Arbor connects again; `hello` brings it up to date:

```bash
while true; do
  arborctl watch view | my-handler
  sleep 5
done
```

### The events

#### hello

Always first. `version` is Arbor's ("dev" for a build outside the app bundle); `protocol` is 1. In `snapshot`, each entry of `displays`,
`windows`, `layouts` and `views` has the fields of the event `displays`, `window`, `layout` or `view` below, and `focus` those of `focus`. Displays, and with them
`layouts` and `views`, come with the main display first. `notArranged` lists the windows Arbor sees and leaves alone (Don't Arrange, an
`ignore` rule). While Arbor is not `running` (it is waiting for Accessibility permission, or `paused`) the lists are empty.

```json
{"event":"hello","protocol":1,"snapshot":{"accessibility":true,"displays":[{"builtIn":true,"displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","frame":{"height":982,"width":1512,"x":0,"y":0},"main":true,"name":"Built-in Retina Display"}],"focus":{"app":"Notes","bundleID":"com.apple.Notes","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","window":388},"layouts":[{"displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","dockedCount":2,"floatingCount":1,"frames":{"388":{"height":925,"width":488,"x":1012,"y":45},"412":{"height":925,"width":488,"x":12,"y":45}},"tileCount":0}],"notArranged":[207],"paused":false,"running":true,"views":[{"apps":["Safari","Notes"],"canGoBack":false,"canGoForward":false,"depth":0,"displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","kind":"everything","label":"everything","node":2,"outOfView":0,"windows":[412,388]}],"windows":[{"app":"Notes","bundleID":"com.apple.Notes","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","docked":true,"state":"in-view","window":388},{"app":"Safari","bundleID":"com.apple.Safari","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","docked":true,"state":"in-view","window":412},{"app":"Mail","bundleID":"com.apple.mail","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","docked":false,"state":"in-view","window":431}]},"version":"0.1.0"}
```

#### view

What a display shows has changed: the view moved, or it holds other windows now, or it was saved.

```json
{"event":"view","apps":["Safari","Notes"],"canGoBack":true,"canGoForward":false,"depth":1,"displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","kind":"group","label":"Safari and Notes","name":"Writing","node":4,"outOfView":3,"savedView":2,"windows":[412,388]}
```

| Field | |
|---|---|
| `displayID` | The display's UUID, as in every event. (`display` is kept for the display's number, which commands take; events do not carry it yet) |
| `label` | The space in view, in the words Arbor's replies use: "everything", "the Desktop", "Safari", "Safari and Notes", "2 Safari windows", "5 windows". **This is the status bar's label** |
| `kind` | `everything` (as after Show Everything), `desktop`, `window` (one window or tab group, framed) or `group` (a space of several) |
| `depth` | How many steps out (⌃⌥↑) it takes to see everything; 0 when everything is in view |
| `outOfView` | How many of the display's windows are out of view |
| `windows` | The docked windows in view, left to right and top to bottom. Windows that tiles stand in for, and floating windows, are not listed |
| `apps` | Their apps' names, in the same order (so an app with two windows appears twice) |
| `canGoBack`, `canGoForward` | Whether `back` and `forward` would do anything |
| `savedView` | The saved view that leads here (the lowest number, if several do); left out if none does |
| `name` | The name the space was given; left out if it has none |
| `node` | The space's number. `arborctl zoom-node <node>` goes there. Numbers belong to one display and last as long as the space does |

#### layout

A display was laid out differently: windows were docked, floated, resized, opened or closed, or the view moved.

```json
{"event":"layout","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","dockedCount":3,"floatingCount":1,"frames":{"388":{"height":925,"width":488,"x":1012,"y":45},"412":{"height":925,"width":488,"x":12,"y":45}},"tileCount":1}
```

| Field | |
|---|---|
| `dockedCount` | Windows docked on this display, in view or not |
| `floatingCount` | Windows floating on its Desktop, in view or not |
| `tileCount` | Tiles showing now |
| `frames` | Where each docked window in view is, by window number: `.frames["412"].width` |

#### focus

Another window is the focused window, or none that Arbor knows is (a click on the wallpaper, a sheet, a panel).

```json
{"event":"focus","app":"Safari","bundleID":"com.apple.Safari","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","window":412}
{"event":"focus","app":"Safari","bundleID":"com.apple.Safari","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","title":"Apple","window":412}
{"event":"focus"}
```

| Field | |
|---|---|
| `window`, `app`, `bundleID` | The window and its app. All left out when no window Arbor knows has the keyboard |
| `displayID` | The display whose arrangement holds it; left out for a window Arbor does not arrange |
| `title` | Only with `--titles`; then a new title of the focused window is an event too |

#### window

One line per window and change. Every line carries all the window's fields as they are now, so a script can simply keep the last line per window
(and forget the window at `closed` or `released`).

```json
{"event":"window","app":"Terminal","bundleID":"com.apple.Terminal","change":"opened","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","docked":false,"state":"in-view","window":455}
{"event":"window","app":"Terminal","bundleID":"com.apple.Terminal","change":"docked","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","docked":true,"state":"in-view","window":455}
{"event":"window","app":"Terminal","bundleID":"com.apple.Terminal","change":"state","displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","docked":true,"state":"out-of-view","window":455}
```

| `change` | |
|---|---|
| `opened` | It opened, and Arbor arranges it. New windows float; one that a rule docks at once is reported as `opened`, then `docked` |
| `closed` | It closed, or its app quit. The other fields are as they last were |
| `adopted` | It was open already, and Arbor arranges it from now on: after `started` and `resumed`, or when its app is arranged again |
| `released` | It is still open, and Arbor no longer arranges it: you chose Don't Arrange for its app. The other fields are as they last were |
| `docked`, `floated` | It is docked, or floats, on `displayID` now. Also sent when it goes to another display |
| `state` | Its `state` changed |
| `title` | Its title changed. Only with `--titles` |

| Field | |
|---|---|
| `window`, `app`, `bundleID`, `displayID` | The window, its app, and the display whose arrangement holds it |
| `docked` | Docked, as opposed to floating on the Desktop |
| `state` | `in-view`; `out-of-view` (outside the view, or a tab behind another); `tile` (in view, but a tile stands in for it); `minimized`; `hidden` (⌘H); `full-screen` (macOS's own, the green button); `other-space` (on another of macOS's Spaces) |
| `title` | Only with `--titles` |

#### displays

A display was connected, disconnected or changed size. All displays are listed, the main one first. Forget what you knew
about a display that is no longer listed; its windows are reported where they went.
`name` is what macOS calls the display (left out if that is not known) and `builtIn` says whether it is a laptop's or an iMac's own: the words `match` goes by
in the `displays` list of settings.json.

```json
{"event":"displays","displays":[{"builtIn":true,"displayID":"9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21","frame":{"height":982,"width":1512,"x":0,"y":0},"main":true,"name":"Built-in Retina Display"},{"builtIn":false,"displayID":"4C7A5B0E-9F2D-4B41-8E55-1A2B3C4D5E6F","frame":{"height":1440,"width":2560,"x":1512,"y":0},"main":false,"name":"Studio Display"}]}
```

#### settings

The settings changed (Reload Settings with an edited file, Don't Arrange…): `changed` names the keys of `settings.json` that did.

```json
{"event":"settings","changed":["gap","rules"]}
```

#### started, paused, resumed, quitting

```json
{"event":"started"}
{"event":"paused"}
{"event":"resumed"}
{"event":"quitting"}
```

- `started`: Arbor began arranging windows, for a client that connected while it was still waiting for Accessibility
  permission. The state follows as ordinary events, the windows as `adopted`.
- `paused`: Arbor has put every window back in view, in its own size, and lets go of windows, shortcuts and gestures. Nothing more is sent until the
  pause ends. Forget what you knew: windows come and go unobserved meanwhile.
- `resumed`: the pause is over. The state follows as after `started`.
- `quitting`: Arbor has put every window back in view and is about to go. Always the last line.

## URLs

`arbor://` and the command's words separated by slashes: `arbor://view/2`, `arbor://zoom/pointer`, `arbor://dock/focused/left`, `arbor://zoom/412`. `arbor://layout/` takes a whole line, percent-encoded ([LAYOUTS.md](LAYOUTS.md)).

Any web page can ask macOS to open a URL, so URLs only look and arrange; everything else is refused unless `allowAllURLCommands` is on (see the README).
That goes for **an app's name** too: `arbor://zoom/Terminal` would let a page pick the window your keyboard types into, which a number it cannot know does not. With the setting on, names work as
anywhere; a word of a URL cannot hold a space, so apps with spaces in their names go by bundle id. A launcher that can run a command has `arborctl zoom Terminal`.

## Three worked examples

### Raycast: frame an app by name

A [script command](https://github.com/raycast/script-commands). Save it in your script directory as `arbor-frame.sh` and make it executable. In `silent` mode Raycast shows the last line printed.

<!-- example: raycast -->
```bash
#!/bin/bash
# @raycast.schemaVersion 1
# @raycast.title Frame App
# @raycast.mode silent
# @raycast.packageName Arbor
# @raycast.argument1 { "type": "text", "placeholder": "app" }
PATH="$PATH:/usr/local/bin:$HOME/bin"

# The reply is on stdout and a refusal on stderr: this keeps only the refusal.
if reason=$(arborctl zoom "$1" 2>&1 >/dev/null); then
  echo "Framed $1"
else
  echo "${reason#arborctl: }"
  exit 1
fi
```

### SketchyBar: where am I?

An item that shows what the view holds and how many windows are out of view. In `sketchybarrc`:

```bash
sketchybar --add item arbor left --set arbor update_freq=2 script="$CONFIG_DIR/plugins/arbor.sh"
```

and `plugins/arbor.sh`:

<!-- example: sketchybar -->
```bash
#!/bin/bash
# Fields of `arborctl where`: display, name, node, depth, out of view. The first line is the main display.
if line=$(arborctl where 2>/dev/null | head -n 1) && [ -n "$line" ]; then
  name=$(printf '%s' "$line" | cut -f2)
  hidden=$(printf '%s' "$line" | cut -f5 | cut -d' ' -f1)
  [ "$hidden" = 0 ] && label="$name" || label="$name  +$hidden"
  sketchybar --set "$NAME" drawing=on label="$label"
else
  # Arbor is not running, or is paused.
  sketchybar --set "$NAME" drawing=off
fi
```

### Shortcuts: set the table

An "Open URLs" action is all it takes, and it works from the menu bar, Siri, Focus filters and automations:

<!-- windows: Safari, Mail, Notes -->
```console
$ open "arbor://layout/Safari:2%20%7C%20(Mail%20%2F%20Notes)"
$ arborctl layout
Safari:2 | (Mail / Notes) | Desktop:0.75
```

## More recipes, with `watch`

### The space in view, in SketchyBar

An item that shows what you are looking at ("everything", "Safari and Notes"), how many windows are out of view, and the saved
view's shortcut. In `sketchybarrc`:

```bash
sketchybar --add item arbor left --set arbor icon=▦ label=–
"$CONFIG_DIR/plugins/arbor.sh" &
```

`plugins/arbor.sh`:

```bash
#!/bin/bash
# One long-running process: every change of the main display's view becomes a new label.
while true; do
  arborctl watch view displays | jq --unbuffered -rn '
    def text:
      (.name // .label)
      + (if .outOfView > 0 then "  +\(.outOfView)" else "" end)
      + (if .savedView then "  ⌃⌥\(.savedView)" else "" end);
    foreach inputs as $event (null;                              # carried along: which display is the main one
      if $event.event == "hello" then $event.snapshot.displays[0].displayID
      elif $event.event == "displays" then $event.displays[0].displayID
      else . end;
      . as $main
      | if $event.event == "paused" then "paused"
        else (if $event.event == "hello" then $event.snapshot.views[] else $event end)
             | select(.label and .displayID == $main) | text
        end)' |
  while read -r label; do
    sketchybar --set arbor label="$label"
  done
  sketchybar --set arbor label=–        # Arbor is not running; try again in a while
  sleep 5
done
```

For an item per display, `sketchybar --query displays` lists each display's `UUID` beside its `arrangement-id`;
the UUID is Arbor's `displayID`.

### React to the view, without jq

`event` is always the first key and the others are in alphabetical order, so shell patterns and `grep` are enough for simple things:

```bash
# Quiet while one window is framed.
arborctl watch view | while read -r event; do
  case $event in
    *'"kind":"window"'*) shortcuts run "Do Not Disturb On" ;;
    '{"event":"view"'*) shortcuts run "Do Not Disturb Off" ;;
  esac
done

arborctl watch | grep --line-buffered '^{"event":"focus"'
```

### jq one-liners

```bash
arborctl watch | head -n 1 | jq .state                                                   # the state now, in the events' words
arborctl watch view    | jq -r 'select(.event == "view") | .label'                       # where the view is, in words
arborctl watch focus   | jq --unbuffered -r 'select(.event == "focus") | .app // "–"'    # the focused app, for a status bar
arborctl watch layout  | jq -r 'select(.event == "layout") | "\(.docked) docked, \(.floating) floating, \(.tiles) tiles"'
arborctl watch window | jq -r 'select(.change == "opened") | "\(.app) opened window \(.window)"'
arborctl watch window | jq -r 'select(.state == "out-of-view") | "\(.app) is out of view"'
arborctl watch window | jq -r --unbuffered 'select(.change == "opened" and .bundleID == "com.apple.Terminal") | .window' |
  while read -r window; do arborctl dock "$window" bottom; done                          # a rule, by hand
```

`jq` holds its output back when it writes into a pipe: pass `--unbuffered` whenever something reads from it.

### Without arborctl

The protocol is small enough for any language: connect, write one line, read lines. Keep your side open; Arbor
takes a client that closes its writing side to have left.

```python
import json, os, socket

path = os.path.expanduser("~/Library/Application Support/Arbor/arbor.sock")
with socket.socket(socket.AF_UNIX) as arbor:
    arbor.connect(path)
    arbor.sendall(b"watch view\n")
    for line in arbor.makefile(encoding="utf-8"):
        event = json.loads(line)
        if event["event"] == "view":
            print(event["label"], event["outOfView"])
```

Any other command gets one line of JSON back (`ok`, `message`, and sometimes `state` or `text`), and then Arbor closes the
connection. A request may be 64 KB long at most and must arrive within two seconds. Arbor keeps 64 connections at a time and refuses the 65th.

## Trying a script without touching your windows

`arbor-sim --serve` runs the real Arbor, minus the Mac: the same socket, commands and events, with pretend windows on a
pretend 1440×900 display. It builds on Linux too.

```bash
swift build
.build/debug/arbor-sim --serve /tmp/sim.sock &
export ARBOR_SOCKET=/tmp/sim.sock ARBOR_UNCHECKED=1   # unchecked: `arborctl` reads a line before it sends it, and does not know the simulator's own words
arborctl watch view &
arborctl open Safari        # the simulator's own commands: open, close, focus, minimize, drag… (window numbers start at 101)
arborctl dock 101 left
arborctl zoom 101
arborctl quit
```

Or in one go, without a socket: `arbor-sim quiet "open Safari" watch "dock 101 left" "zoom 101"` prints the events after each step.
