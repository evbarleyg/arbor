# Traces

A trace is a recording of everything that passed between Arbor's logic and macOS for a while: what the window
system reported, what Arbor asked of it and what came back, the commands that ran, what the user did with
Arbor's overlays, and when scheduled work ran. Whoever has a Mac records one; from then on anyone can replay it
against the real `Controller`, on any platform, look at what happened, debug it, and keep it as a test.

Most of the agents writing Arbor cannot see how real apps behave. A trace is how they find out.

Copy the command, not the remark after `#`: at its prompt macOS's own shell, zsh, does not take `#` for a comment.

```bash
arborctl trace on safari-drag     # start recording
arborctl trace note dragging Safari to the left edge     # optional remarks, as often as you like
…do the thing…
arborctl trace off                # prints the file: <Arbor home>/traces/<date>-safari-drag.jsonl
arborctl trace status             # whether a trace is being recorded, or how the last one ended

make trace NAME=safari-drag       # all of the above, a privacy check, and a copy into collab/evidence/traces/
make trace-check FILE="<file>"    # every piece of free text in a trace, to read before committing it
make replay FILE="<file>"         # the story as text, with drawings of the layout ([STRICT=1] [VERBOSE=1])
```

Arbor's home is `~/Library/Application Support/Arbor` (or `$ARBOR_HOME`). arbor-sim understands the `trace` commands too, so
a simulated session can be recorded the same way; without an `ARBOR_HOME` its home is `arbor-guests-<uid>` in the temporary
directory, never the real Arbor's (its reply says where the file is).

## What is never in a trace

**Window titles.** They say what people are reading and writing. Each distinct title is replaced by `title[1]`, `title[2]`… in
the order they were first seen in that trace, so the same title always has the same token and what Arbor does with
titles still replays: re-matching windows by title works on tokens as it did on titles. An empty title stays empty. The number is closed in because much of Arbor looks for a text *anywhere* in a title (`Safari~text` in a
layout or a preset, Go to…): no token may be contained in another, and `title-1`, as tokens were written until 2026-10-14, was in `title-10`. Traces from before replay as they always did: to a replay a token is just a title.

Rules can ask for text in a title (`"title": "Inbox"`), and so can `holdStillFor` (`"us.zoom.xos Zoom Meeting"`); that text is part of a title too (its marks are `[h1]`, `[h2]`…). Each distinct pattern becomes
`[p1]`, `[p2]`… in the recorded settings, and the token of a title that contains a pattern ends with its mark:
`title[3][p1]`. Rules look for their pattern anywhere in the title, so a replayed rule matches exactly the windows the
real one matched.

Of a command's result only `ok` and `message` are kept; `state` and `text` hold titles.

**Words in commands that change settings.** `bind ctrl+opt+1 go Clients` holds a command like any other, and it is written as that command would be: `bind ctrl+opt+1 go name-1`, `bind … layout 104 | Notes`,
`bind … find …`. The part of a title in `rule add … title Payslip` gets a mark, `[p1]`, as the rules in the header do, so the rule matches in a replay what it matched.

**What cannot be read as a command.** The words in a command are hidden by reading the command's text, each kind of word in its own way. A text that cannot be read cannot be hidden that way, and that it cannot be
read does not mean that nobody meant it: a name longer than the reader allows, typed into the name field, is a command built in code, which never went through the reader. So the recorder fails closed: of
such a text only the verb is written, if it is one of Arbor's, and `…` (`layout …`, `… name`, or `…` alone), as a command, as what `bind` was given, and for a shortcut in the recorded settings; keys that are no
shortcut become `…1`, `…2`. What is written is no command either, so a replay stops at it, as it stopped at the text itself. Traces recorded before 2026-10-15 can hold such texts as they were typed: read them
with `make trace-check` before passing them on. `CanaryTests` puts one word, in forty shapes, into every command that carries words and looks for it in the trace and the log; `scripts/privacy-smoke.sh` does the
same with the files Arbor starts on.

**What is typed to find a window** (F27). It is part of a title, any part, so looking for whole titles does not catch it. `find diag` is written as `find title[1]`, the
token of the title of the window it found: in a replay that is the window's title, so the replayed command finds the same window. (For a window without a
title, a saved view or a named space: its name in the list. The recorder checks that the stand-in finds the same row among the rows as a replay will have them.) If nothing was found, or
the check fails, it is written as `find …`, which finds nothing, and “…” replaces what the reply quotes. The same goes for a shortcut somebody made for `find Inbox`, in the settings and when it is
pressed. What is typed into the Go to… palette stays in the palette: its rows are drawn and not recorded, and what is chosen is a number.

**The names of displays.** They can be people's ("Robin's iPad"). Each becomes `display-1`, `display-2`… in the order they were first seen: in the records of displays, and in replies, which call displays by their names
("…; display-1 keeps 6"). An entry of `displays` in settings.json can go by a part of a name; like the title pattern of a rule it becomes a mark, `[d1]`, and what stands for a name that contains it ends with the mark: `display-1[d1]`. In a replay the
display *has* that for a name, so the same entries match it and the replies come out the same. An entry that goes by a display's id stays as it is.

**What is typed.** Of the keyboard a trace holds Arbor's own shortcuts, how long ago a key was last released, and a running count of key presses, each at the
moments Arbor asked (when a command has to choose between the pointer and the keyboard). Never which keys.

Free text is searched as well: in the text of commands, their replies, remarks, and the arguments and results of lines recorded by name, every title this trace
has seen so far is replaced by its token, whoever put it there. (Not titles of fewer than four characters, nor a title that is just its app's name.) A
command that names a window by its title therefore replays: the replayed window has the token for a title.

**The names of spaces** (F20). A name is a client, a project, a person's own word for something. Each becomes `name-1`, `name-2`… in the order they were first seen, whatever its capitals,
everywhere: in the arrangements in the header (also those of displays that are not connected), in commands, in replies, where names stand as words of their own, and in the commands of people's own shortcuts. In a
replay the spaces *have* the tokens for names, so `go name-1` finds the same space. The beginning of a name (`go cli`) is written as the whole token of the space it found; what found nothing gets a token of its own,
because the reply quotes it.

**Parts of titles in `layout`** (F54). `layout Mail~pays | Notes` is written as `layout 104 | Notes`: every slot that asks for a title names the windows it got by their numbers, which is exact and gives nothing away. One that
got none keeps its app. The other slots stay as they were written. In the recorded settings, where it is what a shortcut runs, such a line is written without the part, `layout Mail | Notes`: a replay does not go by it, but it reads it, and `bindings` counts what it cannot read. A shortcut that runs `rule add … title Payslip` is written with the mark, and one that runs `bind` as the shortcut it would make.

**Replies.** A reply is free text that any command may write, and it quotes what people typed, named and wrote into their files. Replies become lines in one place (`TraceRecorder.scrubbed`), by one rule, in this order:

1. *Never more than the log may hold.* With a typo in settings.json, replies quote the file at the typo, for whoever wrote it, and that can be inside a rule's `title`. The log gets the line and the column instead (`Controller.forTheLog`), and so
   does a trace: "≈ settings.json cannot be read, keeping the settings in use: line 1, column 49".
2. *Whatever has a stand-in gets it*, the same one everywhere: titles, names, and the parts of titles that rules and `holdStillFor` go by, which are marks: `rule 1: com.apple.mail, title contains "[p1]" → float`. A replay has the stand-ins for titles, names and
   patterns, so its replies come out the same.
3. *The backstop.* A word of a command that the trace does not show in the `command` line is not shown in that command's reply either: `…` stands for it. So whoever hides a word in a command need not know which replies quote it, today or later.

A reply that 1 or 3 changed begins with `≈`: a replay will say something else.

Both are worked out just before the command runs, by asking what the command is about to ask itself (`Controller+TraceWords.swift`). That changes nothing and leaves no lines. `TraceWordsTests` fails for a command that takes words and is not
known there.

What a trace does hold in words: the names and bundle ids of the apps whose windows were open (all of them, not only those
that moved), process ids, the text of commands and their replies, your remarks, and the settings (shortcuts,
excluded apps). `make trace-check` lists all of it. Close what nobody should know you had open before you record.

And about the Mac and the hands on it: the version of macOS, the displays (their identifiers, sizes and how they are arranged), where the pointer was, and every press, drag and release of
the left mouse button while the trace was recorded, wherever it landed, with its place on the screen. None of it says what was clicked on, but it is the person's own. Look at a trace from
somebody's Mac before committing it.

## Limits

- A trace stops by itself at **20 MB or 10 minutes**, writes why as its last line, logs it, and `trace status` says so. It stops between two
  reactions, never inside one, so what it holds replays whole. arbor-sim has no limit of age: its clock is the script's (`wait 3600`).
- Each line goes to the file as it happens, so a trace survives Arbor crashing. A cut-off last line is dropped when reading.
- If the file cannot be written, recording stops and Arbor carries on.
- Quitting or pausing Arbor ends the trace: it has stopped looking at windows.
- Nothing deletes old traces: clear `<Arbor home>/traces/` yourself now and then.
- While nothing is recorded, the recording layer costs one test of a flag per call.

Start a trace when things are at rest: work that was already scheduled when recording began is not in the header.

## The format

JSON lines: one object per line, UTF-8. Blank lines and lines starting with `#` are skipped, so a committed trace can
carry remarks. Keys are sorted, except that `t` comes first. Rectangles are `[x, y, width, height]` and points `[x, y]`, in
global coordinates (origin top-left, y down), rounded to hundredths of a point. The types are in
`Sources/ArborCore/Trace.swift`; `Trace(text:)` and `TraceWriter` (`Sources/ArborKit/Trace/TraceFile.swift`) read and write them.

### The header

The first line is the world, and what Arbor knew of it, when recording started. A replay builds both from it, so a
trace needs nothing but itself, wherever in a session it was started.

| Key | |
|---|---|
| `trace` | The format's version, 1. A reader refuses versions newer than it knows. |
| `name`, `recorded` | The name given to `trace on`; when it started (ISO 8601, UTC) |
| `arbor`, `os` | Arbor's version (`dev` for a build that is not a bundle); the operating system as it describes itself |
| `displays` | `id`, `frame`, `visible` (the frame minus menu bar and Dock), `main` |
| `windows` | Every window the window system knew: `id`, `pid`, `bundle`, `app`, `title` (a token), `frame`, and `minimized`, `hidden`, `offSpace`, `fullScreen` where true |
| `settings` | The settings in effect, as in `settings.json`, title patterns replaced |
| `workspaces`, `dormant` | Each display's tree, camera, history, saved views and floating windows, as in `state.json`; the same for displays that were away |
| `parked`, `minimumSizes`, `focusHistory`, `ignored`, `onlyPIDs`, `appPlaced` | What Arbor had learned and `state.json` does not hold |
| `focused`, `cursor`, `mouseDown` | The focused window, the pointer, the left button |
| `thinning` | The thinning interval in seconds (below) |

Only `trace` and `displays` are required, so a trace written by hand for a test can be short.

### The lines

Every other line has `t`, the seconds since recording started, and one key that says what kind it is.

**Stimuli**: what Arbor reacts to. A replay delivers these.

| Line | Meaning |
|---|---|
| `{"event":"appeared","window":{…}}` | `WindowSystemEvents.windowAppeared`, with the whole snapshot |
| `{"event":"destroyed","id":7}` | |
| `{"event":"changed","user":true,"window":{…}}` | Moved, resized, minimized, hidden, renamed or changed Space. `user` is `userInitiated`: false when the window system took it for the echo of a frame Arbor set |
| `{"event":"focused","id":7}` | |
| `{"event":"dragBegan"｜"dragMoved"｜"dragEnded","id":7,"point":[x,y]}` | A title-bar drag |
| `{"event":"resizeBegan"｜"resizeEnded","id":7}` | An edge resize with the mouse |
| `{"event":"displaysChanged","to":[…]}` | With the displays there are from now on |
| `{"event":"keyboardFocusMoved"}` | The keyboard may be elsewhere though no window reported it |
| `{"command":"dock 7 left"}`, `{"command":"in","from":"shortcut"}` | A command is about to be performed. `from` is `shortcut`, `menu`, `gesture`, `script` or `url`, if whoever asked said so: the same words can mean another display from a shortcut than from a script (F56). `trace` commands are left out |
| `{"action":"tileActivated","display":"…","node":4}` | A click on a tile |
| `{"action":"seamDragged","display":"…","seam":{…},"by":-12}` | One step of a seam drag |
| `{"timer":"enforce-…"}` | Work scheduled under that key is about to run |
| `{"settings":{…}}` | Settings are about to be applied |

A stimulus with `"nested":true` arrived while Arbor was still reacting to an earlier one. A nested command, settings or timer line is
Arbor's own doing (the settings a `reload-settings` command applies, say): it happens again by itself in a replay and is not
delivered. A nested event came from inside a call Arbor was making (the fakes report that the keyboard moved from within `focus`), and a
replay delivers it from inside the same call, so that Arbor meets it in the same state.

**What Arbor did**, after the stimulus that made it do so:

| Line | Meaning |
|---|---|
| `{"call":"setFrame","id":7,"frame":[…],"result":[…],"took":0.021}` | The frame asked for and the frame the window took (`null`: no such window). `took` is how long the call lasted, when that is a millisecond or more |
| `{"call":"focus","id":7}` | |
| `{"call":"showDropPreview","frame":[…]}` | `null` hides it. Scenes (tiles and seam handles at rest) follow from the layout and are not recorded |
| `{"call":"focusedWindow"｜"cursorLocation"｜"isMouseButtonDown","result":…}` | Reads, with the answer |
| `{"call":"allWindows"｜"displays","result":[…]}`, `{"call":"start"｜"stop"}` | At a change of displays macOS moves windows itself, and no app says so (a lid closes: every window has new coordinates). Arbor reads all frames anew, and a replay takes them from this answer |
| `{"done":"dock 7 left","ok":true,"message":"…"}` | The command has been performed. A message that begins with `≈` is what was said, but not what a replay will say ("Known limits") |

**For people**; replays skip them, except that the mouse lines tell them where the pointer and the button are:

| Line | Meaning |
|---|---|
| `{"raw":"AXWindowMoved w7"}`, `{"raw":"leftMouseDown 360,92"}` | What macOS sent, as it arrived, before `AXWindowSystem` made events of it: Accessibility notifications with their window, mouse events with the pointer's place, `flagsChanged`, a press that landed on a tile or handle of Arbor's, and from the workspace `didActivateApplication pid 412` (the only sign of ⌘Tab), `activeSpaceDidChange` and `didChangeScreenParameters`; and `screens <id> x,y WxH; …`, the displays as AppKit shows them, whenever they are not as last written. The events say what Arbor understood, these what it was told |
| `{"note":"…"}` | A remark made with `trace note` |
| `{"end":"trace off","lines":212,"thinned":388}` | The last line: why recording stopped, the lines before this one, and how many were thinned away |

**Recorded by name.** A requirement added to a protocol since the format was made needs no kind of line of its own. It is written with the method's name, its
arguments and its result as plain JSON:

| Line | Meaning |
|---|---|
| `{"event":"dragCancelled","args":[7]}` | Something else the window system reported (a stimulus) |
| `{"event":"shortcut","args":["ctrl+opt+space","show-all","pressed"]}` | The key of one of Arbor's shortcuts went down or came up. The command it runs, if any, follows as a nested line; a key that is held is a peek (F51) |
| `{"action":"cheatSheetDismissed"}`, `{"action":"finderChose","args":[{"window":101}]}` | Something else the user did with an overlay (a stimulus) |
| `{"call":"raise","args":[7]}`, `{"call":"launchApp","args":["Safari"],"result":true}` | Something else Arbor asked for that a person can see. Strict replays compare name and arguments |
| `{"read":"inputActivity","result":{"keyPresses":9,"pointerIdle":0.25}}`, `{"read":"isHolding","args":["ctrl+opt+space"],"result":true}` | Another question Arbor asked, with the answer. JSON has no infinity: a hand that has not been used at all is left out |

That is also how an event, action or call from a newer Arbor is read, so nothing of it is lost; a replay says that it does not know the name and goes on. A line
that has none of the keys that say what kind it is is skipped with a warning.

### Thinning

A drag reports the pointer and the window's frame some sixty times a second each, and Arbor reacts to few of them. These
lines may be thinned: `dragMoved`; `changed` for the window being dragged or resized, when nothing but its frame changed; and
the raw `AXWindowMoved`, `AXWindowResized` and `leftMouseDragged`. The rule, for each of those kinds separately:

- a line is held back until the next line shows what it was worth;
- if anything else is recorded next, it is written first. So **every line Arbor reacted to is kept**, with what Arbor did
  after it, and so is **the last line of every run**: where the window was dropped is never lost;
- if the next line is another of its kind, it is dropped, unless the last one kept is 0.05 s older (`thinning` in
  the header). So a run keeps its first line and about twenty a second.

A question is not a reaction. Arbor asks for the modifier keys at every step of a drag (F09); a read recorded by name that gets the answer it got last time goes with the line it was
asked about, written or dropped with it. A new answer is news: it is kept, and so is its line, so a replay knows at which step ⌘ went down.

Seam drags are never thinned: each is a step, and the steps add up. The `end` line counts the lines that were dropped, without the questions that went with them.

## Recording: how it works

Three decorators wrap the platform seams, in the app and in the test harness alike, and share one `TraceRecorder`
(`Sources/ArborKit/Trace/`):

```
Controller ─▶ RecordingWindowSystem ─▶ AXWindowSystem      (or FakeWindowSystem)
           ─▶ RecordingOverlays     ─▶ AppKitOverlays      (or FakeOverlays)
           ─▶ RecordingScheduler    ─▶ MainQueueScheduler  (or ManualScheduler)
```

They forward every call and every callback unchanged. Neither side knows they are there; the whole test suite runs
through them. The controller's own part is small (`Controller+Trace.swift`): the `trace` command, the header, and `perform`,
which records each command and its result. Lines go to a `TraceSink`: a file in the app, memory in tests.

### When a protocol in `Platform/` gains a requirement

The compiler asks for the forwarding unless the requirement has a default implementation; then everything compiles and the real system silently stops being
called. `TraceForwardingTests` reads the sources and fails for any `func` of those protocols that a wrapper does not declare, and for any field of a snapshot that
a trace does not carry. One line in each of these places, and nothing in ArborCore:

| The requirement is | In its decorator (`Sources/ArborKit/Trace/`) | In `TraceReplayer.swift` |
|---|---|---|
| a question (`WindowSystem`) | `func inputActivity() -> InputActivity { recorder.read("inputActivity") { inner.inputActivity() } }` | in `ReplayWindowSystem`: `replayer?.answer(read: "inputActivity") ?? fake?.inputActivity() ?? …` |
| a call that shows (`WindowSystem`) | `func raise(_ w: WindowID) { recorder.call("raise", [w]) { inner.raise(w) } }` | `replayer?.answer(call: "raise", [w]); fake?.raise(w)` |
| the same with an answer | `recorder.call("launchApp", [name], returning: { inner.launchApp(name) })` | `replayer?.answer(call: "launchApp", [name])?.decoded() ?? fake?.launchApp(name) ?? false` |
| an event (`WindowSystemEvents`) | `func dragCancelled(_ id: WindowID) { recorder.event("dragCancelled", [id]) { events?.dragCancelled(id) } }` | an entry in `knownStimuli()` that takes the arguments apart and calls `bridge.events?.dragCancelled(id)` |
| an overlay action (`OverlayActions`) | `recorder.action("cheatSheetDismissed") { actions?.cheatSheetDismissed() }` | an entry in `knownStimuli()` that calls `harness.overlays.actions?.…` |
| something Arbor draws (`OverlayPresenter`) | forward it, unrecorded, as scenes are | nothing |
| a hint that changes what calls cost and nothing else (`moveTogether`) | forward it; a note with the time it took | an empty function |

Arguments and results must be `Codable` (for a plain struct or an option set, add the word). A `WindowSnapshot` goes as `recorder.window(snapshot)`, which replaces its title, and
comes back as `WindowSnapshot(arguments[n].decoded(as: TraceWindow.self)!)`. The spies at the end of `TraceRecorderTests.swift` need the method too. Then `make scenarios`: if a scenario depends
on the new requirement, its strict round trip says whether the replay is faithful.

### When the controller gains a way in

What reaches the controller through the protocols is recorded by the decorators. What the app calls on the controller itself is not, unless the method sees to it, and
then a replay does not do what the recording did. `TraceForwardingTests` lists the controller's public methods and fails for one it does not know. If the new one can change anything:

- A variant of `perform`: do all of it inside `traced(command, from: source) { … }` (`Controller+Trace.swift`). *All* of it: what happens before that call is written down as
  part of the reaction before, where a replay does not look for it. (`perform(_:from:)` ends a peek first; that is inside.)
- Anything else: a helper beside `traced(_:_:_:)` for shortcuts in `Controller+Trace.swift` that calls `recorder.event("name", [arguments…], body)`, the method's body inside it, and an entry in
  `knownStimuli()` in `TraceReplayer.swift` that takes the arguments apart and calls the method on `harness.controller`. Commands it runs follow as nested lines and are not run twice.
- A method whose every effect is a call of `perform` needs nothing (`gesture`, for now).
- A question put to macOS through a closure the app sets, not through a protocol: `traceRecorder?.read("name", [arguments…]) { … }` around the call, and in `TraceReplayer.boot()` a closure that
  answers with `answer(read: "name")`. The only one so far is `accessibilityProbe` (`mayUseAccessibility`): a loss of the permission replays, and ends the trace, as it ended the recording.

Before listing a method as changing nothing, read what it calls. `cameraDisplay()` and `commandDisplayID()` look like questions and are not: through `currentLead()` they call `InputLead.lead(for:…)`, which
remembers its answer. F20's `namedSpaces()` asked them, so opening the menu changed what the next shortcut followed, and no trace would have shown why. It was this test that made somebody look.

Scheduled work is recorded because its moment is not determined by its delay. On a Mac, work due in 0.25 s can run
before or after an event that arrives about then, and work due "at once" runs after the events that are already
waiting. A replay that went by the clock alone would get those orders wrong.

## Replaying

`TraceReplayer` (ArborTesting) builds a `Harness` from the header: the recorded windows and displays in the fake window
system, the recorded workspaces in the store, the recorded settings. It starts a real `Controller` on that, then goes
through the lines, moving the manual scheduler's clock to each line's time and delivering every stimulus.

**Answers.** What the controller asks of the window system is answered

1. by the same call among the lines recorded after the stimulus being delivered (the same window and a request within
   a point): the window takes the frame it took on the Mac;
2. else by the same request anywhere in the trace, nearest first: an app's answer depends on the request far more than on
   the moment;
3. else by the fake's own model, taught what the trace shows of the app: one that gave more than was asked has that minimum size, one that gave
   less that maximum. Unless its sizes come in steps: a terminal takes the whole number of characters nearest to what it is asked for, which half the
   time is more. Every size such a window was seen at lies on one grid, so the step is the greatest common divisor of their differences
   (Terminal: 681, 492 and 247 wide, a step of 7), and the model answers with the nearest point of the grid.

Reads are answered by the recorded read after the same stimulus, else by what the trace last said about the pointer, the
button and the focus.

**Scheduled work** runs where the trace says it ran. Work the trace does not mention (Arbor has gained it since) runs
when its time comes. Work waits for its line if that comes within five seconds of when it was due.

**Echoes.** A recorded snapshot carries the frame the window had in the recording. If that is where it already was in
the recording, the event is not about the window moving (it is the echo of a frame Arbor set, or a new title, or a flag),
and in the replay the window stays where the replayed Arbor put it. Only moves that came from outside Arbor are carried
over. So a trace stays meaningful after Arbor's layout has changed.

**Answers to `focus`.** macOS answers `focus(id)` with a focus event a moment later, unless the window had the focus already. That event is Arbor's own doing come
back, so it goes with the call: where the replayed Arbor no longer asks, the recorded `focused` (within a second of the recorded call) is not
delivered, and recorded reads that name that window do not count; where it asks for something the recording does not have, the replayer makes the
answer up. Otherwise a fix that consists of not focusing could never show in a replay, nor a new bug that consists of focusing.

### Two modes

| | **free** (the default) | **strict** |
|---|---|---|
| Question | Does today's Arbor cope with what happened on that Mac? | Does today's Arbor do exactly what the recorded one did? |
| Checks | The invariants | The invariants, and every `setFrame`, `focus` and `showDropPreview` in the recorded order with the recorded arguments, every command's `ok` and `message`, and no scheduled work missing that did something |
| Use | Traces that outlive changes to Arbor: everything in `collab/evidence/traces/` | A refactoring that must not change behaviour; debugging; the scenarios' round trip |

Reads are not compared in either mode: they change nothing.

**The invariants** (`ReplayInvariants`). After every stimulus: every tree is sound and its camera is in it; no window is in two
places; nothing arranged has ceased to exist; Arbor knows every window there is, and every one it arranges is docked or
floating somewhere. Along the way: no endless enforcement, which is ten put-backs in a row on one display with nothing in
between but windows changing; no asking in vain, which is the same request to the same window five times in a row with the same refusal. At the end, after two more seconds of scheduled work: every docked window in view is in its
slot or where it last settled when Arbor placed it (within 4 points), hidden ones are out of view, floating ones are on
some display. A trace that ends in the middle of a drag is not checked for where windows ended up.

**Problems** name the line of the file:

```
line 42: divergence: the recording has `setFrame w7 12,37 650×851 (taken)`; Arbor now does `setFrame w7 12,37 702×851`
line 97: invariant: endless enforcement: `enforce-main` has put windows back 10 times in a row with nothing in between but windows changing
```

### Seeing it

`arbor-sim replay <file> [--strict] [--verbose]` (or `make replay FILE=…`) prints the header, then every line with its number
and time, what Arbor did indented under what made it do so, problems where they showed, and a drawing of the replayed
layout whenever it has changed (not during a drag). Pointer moves, frames on the way, reads, saves and raw lines are
counted rather than printed, unless `--verbose`. Exit code 0: no problems; 1: problems; 2: the file cannot be read.

```
    4    1.021  drag of w32 began at 360,92
                … 41 line(s): pointer moves, frames on the way, reads, saves, what macOS sent
   46    1.902      showDropPreview 12,43 325×650
   52    2.310  drag of w32 ended at 3,400
   53    2.310      showDropPreview off
   54    2.331      setFrame w32 12,43 325×650 (taken) in 14 ms
display 9B2F6C1E-4A7D-4F03-8E15-6D0A3C5B7E21
+---------------------+..........................................
|w32 ArborTestWindows |.desktop                                 .
```

## Traces as tests

Every `*.jsonl` in `collab/evidence/traces/` is replayed in free mode by `TraceCorpusTests.everyCommittedTraceReplays`, on macOS
and Linux. Other tests there keep the folder honest: titles are tokens, files are under 200 KB, each has a line in the
folder's `README.md`.

**Ways back.** Arbor keeps windows out of view, so from whatever state it is in there must be a way back to a Mac with every window in sight. `everyWayBackReturnsEveryWindowFromEveryStateOfATrace` cuts each
trace before every stimulus, also in the middle of drags, which gives some three thousand states that real apps and a real pointer brought about, and from each tries `float-all`, quitting, and quitting, starting again and
`float-all`. Afterwards every window that is not minimized, hidden or on another Space must be at least half on a display. The one exception is a window that is being dragged, which `float-all` leaves in the hand that holds it.

**Expectations.** `<name>.expect` beside `<name>.jsonl` is checked against the state at the end of the replay. Its lines are
arbor-sim's `expect` forms (`collab/README.md`, "Scenarios"), with or without the word `expect`; `#` starts a remark.

```
# The window dragged to the edge docked, and the other kept floating.
docked 32
floating 33
```

**A bug nobody has fixed yet.** A trace that shows one would fail the test. Say so in its `.expect` file:

```
problem endless enforcement
```

takes every problem whose text contains those words off the list, and fails once there is none, so the test says when
the bug is fixed and the line can go.

**To add a trace**: `make trace NAME=<name>` (or copy the file), read what `make trace-check` lists, cut it short if it is long
(a trace is text: delete lines from the end, or record again with less in it), look at `make replay`, add a line to
`collab/evidence/traces/README.md` and, if the end state matters, an `.expect` file. From a cloud Mac:
`scripts/mac-shell/trace-demo.sh` is the example (`docs/TESTING.md`, "Seeing the real app from anywhere").

### When a replay of a scenario fails

`make scenarios` runs each scenario a second time while recording, and replays that trace in strict mode. Nothing has
changed between the two runs, so a divergence means that something reaches the controller, or leaves it, without being
recorded or replayed. Usual causes: a new requirement in a `Platform/` protocol that is forwarded but has no `TraceLine`; state
the controller keeps that the header does not carry (`Controller.traceHeader` and `restore(from:)`); a new way into the
controller that is neither a command, an event, an overlay action nor scheduled work.

**If it fails only some of the time**, the controller is choosing by the order of a `Dictionary` or a `Set`. That order changes with every
launch, and the replay is a second launch. Scenario 25 found the first one: with two windows under the pointer, `candidates.first(where:)`
gave the keyboard to either. Sort, or take a `min(by:)` whose last key is the window's number.

## Known limits

- **What `AXWindowSystem` made of things is baked in.** A trace holds its events, not what it would make of the same notifications today: whether a `changed` counted as an
  echo (`user`), when a drag began. A fix below the seam does not change a replay. The `raw` lines show what it had to go on.
  Where such a fix makes `AXWindowSystem` report something more, the line can be added by hand under a `#` remark that says so, until the trace is
  recorded again (`stubborn-fast`, `stubborn-slow`).
- Beyond echoes and answers to `focus`, what macOS did because of a call the replayed Arbor no longer makes is still delivered.

- What the app finds out about the Mac (`SystemFacts`: macOS's switches, event taps, other window managers) is not in a trace, so a strict replay does not compare `doctor`'s reply.
- Of what is above the seams only shortcuts are recorded (`shortcut` lines): menu clicks, pinches and ⌃⌥-drags appear as the commands they end as.
- What the controller remembers about the hands (which of pointer and keyboard led last, when the focus last moved: `Controller+Lead.swift`) is not in the header. The first command
  of a trace started in the middle of a session may choose differently in a replay.
- Work already scheduled when recording starts is not in the header; a strict replay may miss it.
- The undo history is not in the header (up to a hundred steps of two arrangements each, for every display). So an `undo` of a step from *before* the recording finds nothing to undo in a replay, and the replay goes on from another arrangement. A strict replay says so
  ("`undo` succeeded … now it fails with "nothing to undo""). **A free replay reports no problem** and simply ends elsewhere: give such a trace an `.expect` file, or start recording before the step. Steps taken while recording are undone in a replay as they were.
- `go <text>` that several names begin with changes nothing and lists them. The tokens all begin alike, so a replay says something else. The recorded reply then begins with `≈`, and a strict replay compares only whether the command succeeded.
- The keyboard layout is not in a trace: a replay has a US keyboard. `bind` and `unbind` go by the layout in use, so a trace from another keyboard with `bind ctrl+opt+ö …` in it, or with a reply that says what a key ran before, says something else in a strict replay.
- A command that changes settings reads settings.json first. If it finds news there (somebody saved the file within the last 0.3 s), the replay does not.
- Saved slots still waiting for their windows when recording starts (`Controller+PendingSlots.swift`, the first three minutes after a launch) are not in the
  header either. They take no space, so frames replay the same; a window that would have claimed one floats in the replay.
- `WindowSnapshot` fields added after a trace was recorded take their defaults in its replay. (`TraceForwardingTests` fails until a new field is carried.)
