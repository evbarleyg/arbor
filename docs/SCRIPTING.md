# Scripting Arbor

Everything Arbor does is a command with a text form, and everything that changes is an event. So a script, a
status bar, a launcher or a Stream Deck can do whatever the shortcuts and the menu do, and can know what you are looking at.

| You want to | Use |
|---|---|
| Do something | [`arborctl <command>`](#arborctl), or an [`arbor://` URL](#arbor-urls) where only a link fits |
| Know how things are now | [`arborctl state`](#arborctl-state) |
| Be told when things change | [`arborctl watch`](#arborctl-watch) |
| Try a script without touching your windows | [the simulator](#trying-a-script-without-touching-your-windows) |

## arborctl

`arborctl` sends one command to the running Arbor and prints the answer. It is inside the app, at
`Arbor.app/Contents/Helpers/arborctl`; `make install` links it into a folder on your `PATH`, or do it by hand. (Copy the command, not the remark after `#`: at its prompt macOS's own shell, zsh, does not take `#` for a comment.)

```bash
ln -s ~/Applications/Arbor.app/Contents/Helpers/arborctl /usr/local/bin/arborctl
arborctl help                        # every command
arborctl dock left                   # the focused window
arborctl dock 412 beside 388 bottom  # windows by number; the numbers are in `state` and in events
arborctl zoom 412 --json             # the raw reply, one line of JSON with "ok" and "message"
arborctl status --timeout 1          # give up after a second instead of five
arborctl zoom 412 -q && echo framed  # print nothing; the exit code says it all
arborctl --help                      # arborctl's own options, then every command; needs no running Arbor
```

`arborctl`'s own options (`--json`, `-q`, `--timeout`, `--keep-going`, `--help`, `--version`) count anywhere on the line. Any
other option belongs to the command if it follows the command's first word (`watch --titles`); before it, it is a mistake
(64). After `--` everything belongs to the command.

Answers go to standard output. Whatever went wrong goes to standard error, so `$(arborctl …)` holds an answer or nothing.
With `--json` the whole reply goes to standard output, refusals too.

**Exit codes**

| Code | Meaning |
|---|---|
| 0 | The command succeeded. For `watch`: Arbor quit, or whoever was reading the events left |
| 1 | Arbor said no: it does not know the command, or cannot do it now (the reason goes to standard error). Also a request longer than 64 KB, and the 65th connection at a time |
| 2 | Arbor could not be reached: it is not running |
| 3 | `watch` only: the events stopped without a goodbye, see [When it ends](#when-it-ends) |
| 4 | Arbor is running but did not answer in time (five seconds, or `--timeout`): it is probably waiting for an app that is busy. Do not start another. **It does not mean the command was not done**: Arbor has it and runs it when it gets to it, so trying again can do it twice, which undoes a `toggle-…` |
| 64 | `arborctl` did not understand its own arguments. Nothing was sent |

**Several commands at once.** On one line, with a comma by itself between them:

```bash
arborctl dock 412 left , dock 388 right , zoom 412
```

Or `arborctl -`, which reads commands from standard input, one per line. Blank lines and lines that
start with `#` are skipped, so a batch can be a commented file:

```bash
arborctl - < morning.arbor
printf 'dock 412 left\ndock 388 right\nzoom 412\n' | arborctl -
```

Each answer is printed before the next line is read, so a program can hold a conversation through two pipes. Either way it stops
at the first command that fails (a batch names its line on standard error, `arborctl: line 2: …`) and exits with that command's
code. With `--keep-going` it carries on and still exits with the first failure's code; it stops in any case when Arbor is not running.

**Completion.** `arborctl completions zsh|bash|fish` prints a script that completes commands and edges:

```bash
source <(arborctl completions zsh)                                             # in ~/.zshrc; the same for bash
arborctl completions fish > ~/.config/fish/completions/arborctl.fish
```

**Where it connects.** A Unix socket that only you can open, `~/Library/Application Support/Arbor/arbor.sock`.
`ARBOR_SOCKET` names another path, `ARBOR_HOME` another folder, for both Arbor and `arborctl`.

## `arbor://` URLs

For launchers, Shortcuts, Stream Deck buttons and links. The words of a command, separated by slashes:

```
arbor://show-all        arbor://dock/left        arbor://view/2        arbor://zoom/412
open arbor://dock/left                           # from a shell
```

Any web page, document or message can ask macOS to open a URL, so URLs can only move the view and arrange windows; the
[README](../README.md#urls) lists the commands. Everything else (`quit`, `pause`, the queries, `watch`…) is refused unless
`allowAllURLCommands` is true in `settings.json`. `arborctl` is never restricted.

A URL has nowhere to put an answer: one that is refused beeps, with the reason in Arbor's log (menu → Open Log), and a
command that cannot be done now does nothing. Use `arborctl` when a script needs to know.

## `arborctl state`

One line of JSON with everything Arbor knows: `{"ok":true,"message":"…","state":{…}}`.

```bash
arborctl state | jq -r '.state.windows[] | select(.docked) | "\(.id) \(.app)"'   # docked windows
arborctl state | jq '.state.displays[0].windowFrames'                          # where they are
arborctl state | jq '[.state.windows[] | select(.parked)] | length'            # how many are out of view
arborctl state --titles | jq -r '.state.windows[] | "\(.id) \(.title)"'          # with window titles
```

| `state.` | |
|---|---|
| `running`, `accessibility`, `paused` | Arbor is arranging windows; it has Accessibility permission; it is paused |
| `focused` | The focused window's number, if it has one |
| `displays[]` | `id` (the display's UUID), `frame`, `visibleFrame` (without the menu bar and the Dock), `camera` (the number of the space that fills the view), `canGoBack`, `canGoForward`, `savedViews` (`{"2": 7}`: saved view 2 is space 7), `floating` (window numbers), `windowFrames` (docked windows in view), `desktopFrame` (if the Desktop is in view), `tiles[]`, `tree` |
| `displays[].tree` | The arrangement: `root`, `desktop`, and `nodes` by number. A node's `kind` is `split` (a group: `axis`, `children`), `stack` (a window, or a tab group: `windows`, `active`) or `desktop`; `weight` is its share among its siblings |
| `windows[]` | `id`, `pid`, `app`, `bundleID`, `frame`, `display`, `title` (only with `--titles`), and whether it is `managed` (Arbor arranges it), `docked`, `parked` (out of view), `minimized`, `hidden` (⌘H) |

Rectangles are in points, with the origin at the top-left corner of the main display and y growing downward. In `state`
they are `[[x, y], [width, height]]`; events spell them out, `{"x": …, "y": …, "width": …, "height": …}`.
**Neither `state` nor the events hold a window title unless you ask** (`--titles`): a title can be anything you are reading or
writing, and `state` is what gets pasted into a report. The names you gave to spaces are in `displays[].names`.

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
| An event name Arbor does not know, or 16 clients are watching already | 1 |
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

## Recipes

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
connection. A request may be 64 KB long at most and must arrive within two seconds.

## Trying a script without touching your windows

`arbor-sim --serve` runs the real Arbor, minus the Mac: the same socket, commands and events, with pretend windows on a
pretend 1440×900 display. It builds on Linux too.

```bash
swift build
.build/debug/arbor-sim --serve /tmp/sim.sock &
export ARBOR_SOCKET=/tmp/sim.sock
arborctl watch view &
arborctl open Safari        # the simulator's own commands: open, close, focus, minimize, drag… (window numbers start at 101)
arborctl dock 101 left
arborctl zoom 101
arborctl quit
```

Or in one go, without a socket: `arbor-sim quiet "open Safari" watch "dock 101 left" "zoom 101"` prints the events after each step.
