# The viable gate

When is Arbor good enough to hand to somebody who did not build it? Issue #4 answers in one sentence: **20 synthetic user-hours across apps, displays and both
settings of macOS tiling, with no lost or stuck window, no jolt, no focus error and no lost size; then the polish rubric passes on the five moves.**
This page says what each of those words means in numbers, so that a program gives the verdict and nobody has to be asked to look.

- The verdict is about **one commit**. It is `VIABLE`, `NOT VIABLE`, or `INVALID` where nothing shows that the detectors catch anything (section 5), with the reasons and the ledger of runs it rests on.
- The numbers are in the block in section 1. `scripts/mac-shell/viable.py` reads them **from this page**: there is no second copy.
- Kept by the product owner; the checker is kept by the lane that keeps the detectors, which feeds it real runs. A number changes only by a pull request that says why, never in the same pull request as a fix it would excuse.
- It replaces the half hour on one person's Mac that issue #3 ends with (`collab/QUESTIONS.md`, Q19). Its measure is the same: no jolt, no lost or stuck window, nothing moved that the person did not move.

**State, 2026-10-15: agreed** by the four lanes it rests on (the detectors, the walks, the stand-ins, the rubric). The sampler, the day and most detectors are in a pull request (`scripts/mac-shell/day.sh`, `sampler.swift`, `jolts.py`) and have played their first days on hosted Macs. Section 9 lists what is still to be built, and by which lane.
Until all of it is there the verdict is `INVALID`, for want of evidence: `scripts/mac-shell/viable.py check` on an empty ledger lists what is missing.

## 1. The numbers

```json
{
  "gate": 1,
  "acts_per_user_hour": 120,
  "user_hours": 20,
  "run_seconds_max": 600,
  "tiling": ["defaults", "off"],
  "display": ["laptop", "desk", "two"],
  "user_hours_per_cell_min": 3,
  "cast": ["stock", "browsers", "awkward"],
  "user_hours_per_cast_min": 4,
  "reduce_motion": {
    "acts_that_move_per_tiling_min": 60,
    "kinds_that_move": ["dock-key", "drag", "drag-where-macos-tiles", "view", "resize", "way-out", "quit-and-start"],
    "share_of_acts_max": 0.25
  },
  "real_apps_min": 12,
  "apps_per_run_min": 6,
  "share_of_acts_from_walks_min": 0.5,
  "acts_min": {
    "switch": 480,
    "open-close": 300,
    "dock-key": 160,
    "drag": 240,
    "drag-where-macos-tiles": 80,
    "view": 400,
    "resize": 80,
    "macos-own": 80,
    "way-out": 60,
    "quit-and-start": 20,
    "display-change": 20,
    "idle": 40,
    "tile-click": 10
  },
  "fail_max": 0,
  "odd_unexplained_max": 0,
  "share_of_acts_judged_min": 0.9,
  "share_of_runs_that_do_not_count_max": 0.2,
  "sampler": {"late_ms": 100, "share_of_samples_late_max": 0.01, "blind_ms_max": 250},
  "input": {"kinds": ["down", "forward", "up", "key", "dragged", "scroll"], "release_ms_max": 100, "p50_more_ms_max": 10, "forward_p50_more_ms_max": 100, "events_per_kind_min": 10, "share_of_journeys_that_judge_a_kind_min": 0.5},
  "share_of_acts_not_performed_max": 0.03,
  "detectors": ["moved-unasked", "jolt", "pulled", "flash", "fought", "lost", "stuck", "behind", "focus", "size-lost", "input-held", "slow", "crash", "busy", "left-behind", "told"],
  "controls": {"without_arbor_per_cell_min": 1, "sabotage_runs_min": 1, "sabotage_offences_missed_max": 0},
  "linux": {"walks": 10000, "acts_per_walk": 300, "violations_max": 0, "known_failures_of_severity_1_or_2_max": 0},
  "stand_ins": {"open_divergences_that_touch_a_detector_max": 0},
  "polish": {"moves": 5, "appearance": ["light", "dark"], "rows_failing_max": 0}
}
```

## 2. The four rings

Each ring is cheaper than the next, so each must be green before the next is paid for. All four are run on the same commit.

| Ring | Where | What it says | Lane |
|---|---|---|---|
| 1. The walks | Linux | In 10,000 random walks of 300 acts against the real controller and the rude stand-in, half of them with the stand-in's macOS tiling on, no rule of section 5 is broken, and no known failure of severity 1 or 2 is being excused | L |
| 2. The stand-ins tell the truth | Linux, from recordings | The ledger of differences between the stand-ins and real Macs has no open row that touches a rule of section 5. With such a row open, ring 1 says nothing about that rule | N |
| 3. The 20 user-hours | hosted Macs | Sections 3 to 7 | D, with L's walks |
| 4. The polish rubric | hosted Macs film, agents judge | Section 8 | Q |

## 3. A synthetic user-hour

**An act** is one thing a person does: switches to a window, opens or closes one, docks, drags, moves the view, pauses, quits, or leaves the Mac alone for 30 seconds. The script marks where it begins, says what it may move (section 6), waits
until the screen has been quiet, and marks the end (`begin`, `end` in `lib-day.sh`). What happens between an act's end and the next act's beginning counts for the act that ended: it came late.

**A user-hour is 120 judged acts.** A busy person does something to a window about twice a minute. That is an assumption, written here so that it can be argued with. A script needs about four seconds an act, so a run of under ten minutes
holds about one user-hour, and **20 user-hours are 2,400 judged acts in at least 20 runs**.

**It is not 20 hours by the clock, and we do not pretend it is.** What only the clock brings has its own acts (`idle`: 30 seconds in which nothing is done, apps going about their business; two runs of the gate are nearly all idle) and its own ring: on Linux
the walks let hours and days pass, because there the clock is the test's.

Only **judged** acts count. An act is not judged before Arbor's first start, while the sampler was blind (section 7), or when its run does not count. Acts after Quit are judged: that is where a window that stays stuck shows. What was seen during a blind act stays a finding; the act only adds nothing to the hours.

## 4. Across what

**macOS's own window management** (`tiling`), half the hours each way:

| Value | Means |
|---|---|
| `defaults` | As macOS comes: drag to the edges tiles, drag to the menu bar fills, ⌥ shows the tiling preview, a click on the wallpaper reveals the desktop. **The script checks that they act** (one drag to the top without Arbor fills the display) before anything counts: a switch that is written and not obeyed proves nothing |
| `off` | All four switched off, as `docs/GUIDE.md` has advised so far |

**Displays** (`display`). A hosted Mac has one display whose size a script can set, and a second one can be made with `scripts/mac-shell/vdisplay.m`:

| Value | Means |
|---|---|
| `laptop` | 1440×900, or the nearest on offer |
| `desk` | 1920×1080 |
| `two` | `laptop`, and a virtual 1920×1080 beside it that is plugged in, unplugged, moved to the other side and given another size in the course of the run (`display-change`) |

Six cells, at least 3 user-hours in each. If a hosted Mac turns out not to allow a virtual display, `two` cannot be filled, the verdict stays `NOT VIABLE`, and the product owner decides what Arbor then says about second displays. It is not quietly dropped.

**Apps** (`cast`): only what a hosted Mac has or can get free, without an account.

| Cast | What is in it | Why |
|---|---|---|
| `stock` | Finder, Safari, TextEdit, Terminal, Notes, Calendar, System Settings, Preview, Mail | What everybody has |
| `browsers` | Safari, Chrome, Firefox, Edge, several windows each, and two of `stock` | Toolkits that are not Apple's; many windows of one app |
| `awkward` | A window of fixed size; one whose smallest width is over half of `laptop`; native tabs (Finder, Terminal); an open panel and a sheet; a window in full screen; an app with no window; an Electron or Java app if one can be had; and Arbor's own test windows that refuse, snap back, answer late and hang | Manners, which is where window managers fail |

At least 12 different real apps over the whole gate, at least 4 user-hours with each cast, each cast at both values of `tiling`.

**macOS's Reduce Motion**: off, as a person's Mac comes (hosted Macs come with it on, so the script switches it before Arbor starts). But at each value of `tiling` at least 60 acts that move windows are played with it **on**: then Arbor shows no motion, there is no stage to hide anything (section 5), and whatever a window does on its way is seen and judged. At most a quarter of all acts, since it is not how a Mac comes.
Like tiling it has to be **seen to act**: the samples show Arbor's stage at least once in a run with Reduce Motion off, and never in a run with it on (`stage_seen` in the manifest). Otherwise the run does not count.

**Arbor's settings: as they ship**, from an empty `ARBOR_HOME`, the release build that `make app` makes. Runs with other settings are hunts: welcome, and not counted.

**Who writes the journey.** At most half of the acts come from days written by hand (`day.sh`). The rest come from **walks**: the generator of the Linux walks, writing the same acts for a real Mac, from a seed that is taken from the commit's own hash.
A path that is learnt by heart proves little, and a seed nobody could choose cannot be chosen to pass.

**The mixture.** `acts_min` in section 1 gives the fewest acts of each kind over the whole gate:

| Kind | Acts |
|---|---|
| `switch` | ⌘Tab, ⌘`, a click in the Dock, the Window menu, a click on the window, Go to…: to windows in view and out of view |
| `open-close` | ⌘N, opening a document or an app, ⌘W, ⌘M and back from the Dock, ⌘H and back, ⌘Q |
| `dock-key` | docking, floating, swapping and moving by shortcut or menu |
| `drag` | a real drag of a title bar with the real pointer: to dock, to float, to move a floating window, called off half-way |
| `drag-where-macos-tiles` | those of them that end, or pass slowly, where macOS itself reacts: the top edge, the side edges, the corners. Counted within `drag` |
| `view` | frame, step in and out, walk, back and forward, show everything, the Desktop, peek, saved views, posted pinches and ⌃⌥ + scroll |
| `resize` | a gap dragged, a docked window's own edge dragged, grow and shrink |
| `macos-own` | full screen and back, Mission Control, another Space and back, a click on the wallpaper and a second one |
| `way-out` | pause and resume, Float All, Show Everything on every display |
| `quit-and-start` | Quit from the menu, every window reached afterwards, Arbor started again. At least once in every run |
| `display-change` | see `two` |
| `idle` | 30 seconds of nothing |
| `tile-click` | a click on a tile, which `laptop` with four or more docked apps brings about |

## 5. The detectors: what counts as a failure

A detector reads what a run recorded and never asks Arbor what it believes. **One `FAIL` from any of them, in any run that counts, and the commit is `NOT VIABLE`.**
Distances are in points. "Changes" means by more than 2, because apps round and Retina screens deal in halves.

| Id | Rule (#3) | `FAIL` when | Reads | State |
|---|---|---|---|---|
| `moved-unasked` | 2 | a window changes its frame during an act that may not move it (section 6) | samples | `jolts.py`, rule 2 |
| `jolt` | 3 | for one act a window moves more than once (two changes more than 250 ms apart), or goes more than 6 points out of the straight road to where it ends up, or opens in one place and is then moved to another | samples | `jolts.py`, rule 3 |
| `pulled` | 3, 6 | while the button is down, from one sample to the next, the dragged window moves over 40 points further than the pointer did; or, over the drag so far, it is more than 40 points ahead of where the pointer carries it, or more than 150 behind. (Not "it is where the pointer carries it": with no Arbor running macOS holds a dragged window back where its edge meets another's, 49 points after a drag of 130, clamps it under the menu bar, and holds it for a while with its bottom on the Dock's top or on the bottom of a display: 198 points behind after a drag of 333 downwards. While an edge rests on one of these lines, up and down are measured anew. It never runs ahead; 18 points were seen with nobody pulling) | samples | `jolts.py` |
| `flash` | 3 | a window that is out of view at both ends of an act shows more than its parking strip in any sample between; or any window leaves the screen and comes back within one act that did not ask for it | samples | partly |
| `fought` | 1 | in a drag that macOS answers (its preview is up at the drop, or the window ends in one of macOS's own tile frames) Arbor's preview is up in a sample in which the pointer is within 12 points (`screenEdgeBand`) of an edge that is macOS's (Q23: one after the other is both reacting; further in, the preview of a docked window's own edge is honest), or Arbor docks the window, or the window moves again afterwards; or both previews are up in one sample of any drag; or after a double-click on a title bar that macOS answers Arbor moves that window (Q22); or Arbor moves any window before the first run has shown what it found | samples | `jolts.py`: both at once, docked, moved again. The rest to build |
| `lost` | the measure of a severity 1 | at the end of an act that did not take it out of view, less than half of a window is on any display; or at a point where everything must be in view (after Show Everything, ⌃⌥0, pause, Float All, Quit) a window shows less than its own frame did, and no tile stands for it where a tile may (below) | samples | `jolts.py`, rule L |
| `stuck` | 3, 4 | a window is moved by Arbor more than three times in two seconds with nobody acting; or a window a real drag let go of is, within 24 points, in none of five places: where it was let go, where Arbor's preview was, in macOS's own tile where macOS answered the drag, under the pointer by its title bar at its own size (F48), back where it was taken from (a drag called off); or after Quit a click on an app's Dock icon does not bring its window to the front | samples | partly |
| `behind` | 4 | the window switched to does not end in front of every other ordinary window; or a window kept in view that has its strip (Q25) is overlapped by a window Arbor arranges. One for which there was no room, and of which Arbor says so, may be covered | samples (order) | `jolts.py`, rule 4 |
| `focus` | 4 | the window switched to does not end wholly in view with its app in front and itself its app's focused window; a key typed into a witness window arrives elsewhere; or the app in front changes during an act that is no switch | samples, `apptool`, the witness | partly |
| `size-lost` | 5 | after pause, Float All or Quit a window's size differs from its own: the last size it had while nobody but its person and its app decided it. After pause, Float All and Quit its place too, and nothing is raised (Q21) | samples | `jolts.py`, rule 5 (place: today `ODD`) |
| `input-held` | 6 | the button is not up within 100 ms of the posted mouse-up, anywhere in the journey, asked while a process of Arbor's exists and throughout a run that never had one (it was 50: with Arbor quit, one release in 118 took 57 ms on a hosted Mac; a limit that a Mac without Arbor breaks measures the Mac); a click 300 ms after a drop does not arrive in the window that lies there; or, in a **round of input** (below) with Arbor, an event that was posted does not reach the witness at all, or half of the events of a kind reach it more than 10 ms later with Arbor than in the round without Arbor beside it, 100 ms for a press on a window of an app that is not in front | the witness, samples | `jolts.py`; the rounds have not met a Mac |
| `slow` | 3 | a window Arbor moves is not at rest 1,500 ms after the act's event was posted; the first act after a start has 3,000. From 700 ms (1,500 after a start) it is listed, as a class that explains itself, and goes on the scoreboard: the motion takes 460. Hosted Macs get no numbers of their own: release and debug builds were measured within 50 ms of each other there, and with the icons out of the way docks and frames take 580 to 710 ms | samples | partly: `settled=` |
| `crash` | severity 2 | Arbor's process ends unasked; a crash report of Arbor's appears; `arborctl status` takes longer than a second; Quit takes longer than five | the script | partly |
| `busy` | daily use | during `idle` acts Arbor uses more than 1 % of a core on average, or writes more than 20 lines of log a minute | `ps`, `arbor.log` | to build |
| `left-behind` | 5 | after Quit a process, a panel or an event tap of Arbor's is still there | the window list, `ps` | partly |
| `told` | privacy | a canary word turns up in anything the run brings back but the pictures. Every document and page the script opens has one in its title | `grep` over the artifacts | to build |

**What the samples see, and what they do not.** The sampler sees the real windows, which Arbor moves under its stage while stand-ins travel over them. What the stage covers nobody sees, so **what a real window does while a stand-in travels for it counts as one change, seen when the stage comes down**; what it does after that counts in full. Only that is forgiven: a window on another display than the stage's, one at a level above the stage, and one that shows through a hole in it
(from the motion's second step on: whatever takes no part in the move) are in plain sight and are judged sample by sample. The stage's own log of frames says which windows have stand-ins; until it is there, the windows below the stage on its display.
No `jolt` in the samples is therefore not yet a smooth motion: what shows meanwhile is the film's to judge (section 8). And whoever has Reduce Motion on has no stage: hence the hours of section 4 in which nothing is forgiven.

**A tile counts as in view only after Show Everything and ⌃⌥0**, never after pause, Float All or Quit, where the real window must be there. It has to be seen: the samples must show a window of Arbor's at the tile's frame. Which window a tile stands for only Arbor can say (`arborctl state`): the one place where a detector takes Arbor's word, and the word is tried: `tile-click` acts click a tile, and the real window it was said to stand for must come wholly into view, with the keyboard (`focus`). The window with the keyboard is never the tile.

**What is macOS's own and no finding:** the road of a window into the Dock and out of it; and what a window does in its first 600 ms within 24 points of where it first showed, since macOS pops windows open.
A frame that its person left hanging over an edge is theirs: given back as it was, it is not `lost`.

**`ODD`** is what a detector cannot judge alone (a window changed size while it was dragged; the window in front changed three times). An `ODD` is explained within a day: it is macOS's or the app's doing because the run without Arbor shows it at the same act,
or it becomes a `FAIL`. With one unexplained the verdict is `NOT VIABLE`. Three classes explain themselves and are only listed: a sheet or a dialog that follows its window, when that window was moved in the same act; an act that was slow but within `slow`'s limit; and an act that could not be performed (below).

**Who holds input back is asked in rounds, and every journey carries its own control for it, on its own Mac** (decided 2026-10-15). A round of input is the same few dozen events every time: presses on title bars of apps that are not in front (`forward`), presses on the app in front (`down`), their releases (`up`), keys, plain scrolls, a drag inside a window (`dragged`). It is played four times: **before** Arbor starts, when it has **started**, before the **last** Quit, and **after** it.
**A round says what it posted, by kind** (presses in front and behind counted together, since where a press falls varies). With Arbor, fewer arrivals than were posted is a `FAIL`: what macOS does behind a tap gone wrong is to drop events, never to delay them, and a median over those that did arrive would pass. Without Arbor it is the instrument's own trouble, and the journey says nothing of that kind.
Started is held to before, last to after, by the median of each kind: the measure brackets the journey, because a Mac drifts. Fewer than 10 events of a kind in a round say nothing, and **a kind is judged in a journey only if both pairs have them**: Arbor with an arrangement, its panels and its observers at work is the more telling of the two, and must not go unjudged in silence. What one pair finds is found, whatever the other says. If before and after, both without Arbor, differ by more than the limit for a kind, the journey says nothing of that kind: the Mac moved, or something was left in the way of input, and nobody can tell which.
Silence is not read in the commit's favour: **each of the six kinds is judged in at least half of the journeys that count, or the gate is `INVALID`.** The rounds are instruments, not acts: they count towards no user-hour and no `acts_min`, and every detector stays awake through them. What arrives outside the rounds is listed by kind and nothing is concluded from it.
Why not a percentile over the journey against the run without Arbor, which is what this page asked for at first: it compares mixtures, and Macs. macOS itself holds a press on a window of an app that is not in front until it has brought the app forward, 17 to 137 ms with no Arbor running, while any other press takes 1 ms. A day full of such presses, against runs without Arbor that had two of them, gave "69 ms against 21" and went on the board as a fault of Arbor's; with the same sixteen presses in every round, the round without Arbor was the slowest of seven.
Two hosted Macs differed by 35 against 76 ms at the median of that kind with nobody holding anything, one drifted from 41 to 76 within seven minutes, and the latest release of a round took 5 to 27 ms. So: the median, the same Mac, minutes apart.

**An act that could not be performed is not judged, and listed** (a press that did not take hold of a title bar: once in 49 acts without Arbor, once in 96 with). It counts towards no `acts_min` and lowers its run's share of judged acts. It is a `FAIL` only where the same act was performed in that journey's own control: then something took the window from under the pointer.
Over the whole ledger at most 3 % of the acts of the journeys that count may go unperformed; above that the gate is `INVALID`: either the instrument is sick or Arbor does take windows from under the pointer, and nobody can tell which from a count.

**Three controls, without which a silent detector means nothing:**

1. **Without Arbor** (`day-control.sh`): each cell is played at least once with Arbor not running. What the same journey (script, seed, cell, cast, Reduce Motion) shows there too, by the same detector at the same act, is not Arbor's: `viable.py` compares, and lists it.
   Nothing else excuses a `FAIL`.
2. **Sabotage**: at least one run per gate in which a tool of the harness, not Arbor, commits offences at acts it writes down: moves a window twice, moves one nobody named, flashes one, covers the window switched to, takes the keyboard, leaves a size wrong after Quit,
   holds a mouse-up, kills Arbor, writes a canary into a log. **Every detector of section 1 must have caught an offence of its own**, at the act where it was committed. One offence may set off several detectors; a report at an act where nothing was committed is a false alarm.
   One miss, one false alarm, or one detector that was never tried, and the gate is `INVALID`, whatever the other runs say.
3. **Each detector's own test** on written samples (`jolts.py --self-test`), part of `make check`.

## 6. What an act may move

Each window at most once, straight to where it ends up: that holds in every row, "anything" included. With Arbor's settings as they ship.

| Act | May move |
|---|---|
| Arbor starts for the first time; `idle`; a switch to a window in view; anything done to a floating window but a drag of it | nothing. One exception, at a start and when a window opens: what nobody could get hold of (no 24 points of its title bar on any display) may be fetched, once. Anything else stays: what is found counts as left, and people do park windows three quarters off an edge |
| Arbor starts again | what was docked when it stopped. No window that is in view goes out of view (Q16) |
| A window opens | nothing, and the new window stays where its app put it (`newWindows` ships `"float"`) |
| A dock, by key or by a drag with ⌘ held | that window and the docked windows. **No floating window, ever** (Q20) |
| A float; a docked window closes, is minimized or hidden, or comes back | that window and the docked windows. There and back is nothing: hidden and unhidden, every window is where it was |
| A drag | the dragged window goes where the pointer goes. Everything else waits for the button (`reflowWhileDragging` ships false). **A plain drag of a floating window is what it is without Arbor** (Q29): nothing of Arbor's shows, nothing else moves at the release. A docked window dragged plainly comes out, and the docked windows close its place |
| A move of the view; a switch to a window out of view | the docked windows. **No floating window** (Q29 withdraws Q20's one exception) |
| What a person asks macOS for: a double-click on a title bar, full screen, a size or a place set by hand | what macOS makes of it. **Arbor reverses none of it** (IDEAS I25 a) |
| A gap or an edge is dragged | the windows on both sides of it |
| A window is kept in view, let go of again, or dragged or resized while it is kept in view | a docked window that is pinned goes to its own earlier size, once; after that the pinned window moves by the hand only. The docked windows, which make room beside it (Q25) |
| Pause, resume, Float All, Quit; the permission lost and returned, which is a pause and a resume | anything, once; afterwards `size-lost` and `lost` have their say |
| Undo, redo | what the step moved |
| A peek; a hold | a peek that ends where it began is there and back: nothing. A hold moves nothing; a release the person chose brings in what waited |
| Summon, and sending away | the summoned window |
| A setting that shapes the layout is changed (the gap, the smallest usable sizes) | the docked windows |
| An app is excluded, or a rule comes to match (a late title too) | that app's or that rule's windows, and the docked windows, as at a float or a dock |
| macOS's own (full screen, Mission Control, a Space, the wallpaper click) | what the run without Arbor shows macOS moving. When it is over, every window is where it was before |
| A display comes, goes, moves or changes size | the windows on the displays concerned; afterwards nothing is `lost` |

## 7. Which runs count

A run counts when all of this holds. One that does not counts for nothing either way, with one exception: **a `crash` counts always**.

- It ran on a hosted Mac, unattended, on the commit being judged, started by the workflow in the repository, and the script took under 600 seconds from its first line to its last. The toolchain and the build come before it and have their own target (board, section 2).
- It brought back its manifest, the samples, `arbor.log`, a trace (`docs/TRACES.md`), the findings as JSON, and a picture and a story for every finding.
- The sampler saw enough: at most 1 % of its samples came more than 100 ms after the one before, **counted over one stretch, from the first act that counts to the last, with everything between**. What comes before, while a cast of apps starts cold and nothing is judged, says nothing about what was judged; the whole run's figures stay in the findings and in the ledger. An act during which the sampler was blind for more than 250 ms is not judged. (Measured on hosted Macs at about 38 samples a second, over that stretch: 0 of 4,098, 0.12 % and 0.10 %. Over whole runs: 1.6 to 1.9 % before a cure, 0.24 and 0.49 % after it, 1.13 % on a short run, 71 of whose 72 late samples fell while the apps started. The number stays at 1 %: 2 % would admit the sampler as it was before its cure.)
- At least 90 % of its acts were judged, and at least six apps of its cast opened a window.
- A journey says of which kinds of input its rounds say anything (`"input": {"judged": […]}` in the findings): otherwise the witness saw nothing, or no round was played.

If more than a fifth of a gate's runs do not count, the gate is `INVALID`: too many fell out to believe the rest.
- At `defaults`, macOS's tiling was seen to act before Arbor started.

**No run is left out and none is repeated until it passes.** `viable.py check --runs` is given every run of the gate's workflow on that commit as GitHub lists them, with how often each was started. One that the ledger lacks is a reason; one that GitHub does not know, or that is there twice, makes the gate `INVALID`;
without the list the verdict is never `VIABLE`. A run that was started again counts with every attempt. A run that ended before its report is in the ledger too: it was started, so it is accounted for.

**A hosted Mac's failure does not sink a commit, and who says that a part never ran is GitHub or the batch, never an absence** (decided 2026-10-15):

1. Whoever starts a gate fixes its parts and which job, that is which Mac, plays which.
2. A job that gets a Mac writes, before its first script, a stub of a manifest for each of its parts (`"started": false`). A script overwrites its own as it begins (`"started": true`). So a batch that is stopped because its Mac is spoilt leaves stubs, not holes.
3. `--runs` is GitHub's own list of the jobs that got a Mac: a line for each job and attempt, with the parts it was given (`<run id> <attempt> <first part>-<last part>`). **Every attempt of a run has a line**: of one in which no job got a Mac, `<run id> <attempt> -`. An attempt that is nowhere may be the one that went badly, and GitHub lists a run's latest attempt unless it is asked for all: a later attempt whose earlier ones the list says nothing of is a reason.
4. Every part of every listed job has a manifest in that attempt, stub or real: one that is missing is a reason, and a manifest of a part that no listed job covers makes the gate `INVALID`. A manifest that was started counts with every attempt and is never replaced.
   A stub, or a part whose job never got a Mac, may be supplied by a later attempt of the same run under the same number. A part that no attempt played is a reason. A stub that lies beside acts, findings or an account of the sampler's or the witness's contradicts itself: `INVALID`.

**The manifest** (`run.json`, written by the script):

```json
{"gate": 1, "commit": "<40 hex>", "run": "<GitHub's run id>", "attempt": 1, "part": 1, "parts": 1, "script": "day.sh", "kind": "day | walk | sit | control | sabotage", "seed": "<from the commit, for a walk>",
 "tiling": "defaults", "tiling_seen_to_act": true, "display": "laptop", "cast": "stock", "apps": ["com.apple.Safari", "…"], "settings": "shipped", "reduce_motion": false, "stage_seen": true, "macos": "<version and build>", "seconds": 540}
```

It is written when the run begins and completed when it ends. One run of GitHub's may play several scripts, one after the other on one Mac or spread over several: each is a run of the gate with a manifest of its own. `"part"` and `"parts"` count over the whole run of GitHub's, all its Macs together, and are fixed by whoever starts it, before the first script begins, so that none can be left out afterwards. A script alone in its run is part 1 of 1 and says so: `viable.py` refuses a manifest without them.
Such scripts share a Mac, and apps remember their windows' frames from the script before. That is as on a person's Mac, which is never fresh: where a window is when Arbor first starts is its own frame. Arbor's own home is empty each time. A sabotage run's also has `"offences": [{"detector": "jolt", "id": "idle#3"}, …]`. An act's `id` is its slug and which act of that slug it is in its run, so that it means the same act in the run without Arbor.

**The findings** are what `jolts.py report --json` writes, with three more keys a step: `"act"`, its kind from section 4 (`"instrument"` for a round of input, which is no act), `"judged"` and `"performed"`; and one more a finding: `"detector"`, its id from section 5. The naming is the detector's own business: `viable.py` refuses a finding that names none. That Arbor died is `crash`, whoever noticed.

**The ledger** is `collab/viable/<commit>.json`: the manifests, each run's count of judged acts by kind, and every finding with its detector, level and act. Everything in it comes from hosted Macs. `viable.py` makes it, checks it against section 1 and prints the table and the verdict.

**After a fix the count begins again at nought**, since the fix is a new commit. Two things keep that affordable: a commit is first given **two** user-hours (one at each value of `tiling`), and the other eighteen only if those are clean; and a commit that differs from a judged one
only outside `Sources`, `Resources` and `Package.swift` inherits its ledger.

**What `VIABLE` is worth.** Nothing in 2,400 acts means, at the usual 95 %, fewer than one failure in 800 acts: it still allows one every six or seven user-hours. So the count goes on after the gate: a user-hour or two every night on `main`, and the scoreboard shows failures per 1,000 acts over all of them.

## 8. Then the polish rubric

Only on a commit whose rings 1 to 3 are green. The rubric itself is `docs/POLISH.md`, kept by lane Q; the gate asks that **no row fails, on any of the five moves, in light and in dark, in the look that ships** (colour and icon: Q15).

The five moves are those of the reference's public how-it-works page, watched and never copied: no assets, no code, no wording. In Arbor's words and the page's order:

1. make a tab group by dropping one window on another (F04, F34);
2. dock, rearrange, nest, and see what does not fit become a tile;
3. double-click the Desktop, or a title bar, to go there (F14);
4. drag a rectangle to frame what it holds, and save the view;
5. show everything, and pinch in (F16).

A move Arbor cannot make yet counts as failed, not as left out. So the gate waits for all four trains of the board's section 3.

**"In the look that ships" means the look and the switches** (decided 2026-10-15). The gate reads films made as Arbor ships, on a Mac as it comes: every setting at its default, macOS's own tiling on. A move that does nothing there scores nothing. On the day this was written that was two and a half of the five: the rectangle and the pinch behind `pointerGestures`, and the drag to a side or the top edge, which is macOS's while its tiling is on (the board's 1.52 and 1.53). The judge keeps a second column, with everything switched on and with macOS's tiling off: it says how good a move will be on the day it ships, and it never passes a gate.

Every measure is first tried on a metronome: a square of the camera's own that moves rightly once and wrongly in known ways. If the judge misreads it, that run's score is void. The judge builds nothing it judges.

**Both looks are scored.** Hosted Macs come with Reduce Transparency switched on, which is why every system material came out there as one flat colour and this page once said that no hosted Mac can show glass. Switched off, they draw blur and translucency. So the look that ships is scored, and the flat look beside it, which is what a person with Reduce Transparency sees; nothing in Arbor may rest on translucency (`collab/QUESTIONS.md`, "materials"). In the look that ships, over the worst grounds (a saturated red, a saturated blue, white, black), measured on pictures: words a person must read to act are at least 4.5 to 1, secondary words at least 3 to 1, and nothing Arbor draws as text is under 3. Seen so, each blurred and tinted by what lies behind it, in light and dark, at 1x and on a virtual Retina display: the line on screen, the shortcuts, the minimap, the name field, Go to…, the settings window's sidebar and macOS's own menus and alerts; not yet `blurBehindArranged`. **The look a Mac comes with, Reduce Transparency off, is scored first.** Two cautions: Increase Contrast switches Reduce Transparency on again by itself; and a window's own picture from the window server shows the material without what lies behind it, so legibility on glass is measured on pictures of the screen.

What the product owner asks of the rubric, whatever else it holds. The first five are measured, from the sampler, the stage's own log of frames and the film; the rest are judged from the film by an agent that has the rubric and no stake in the answer.

| Row | Passes when |
|---|---|
| Length | the motion takes `animationDuration` (460 ms) give or take 60. A motion that is corrected, because an app had the last word on its frame, gets what is left of it, at least 150 ms: up to 610 in all |
| Curve | fast start, gentle settle: no stand-in ever goes back on its road, none overshoots by more than 2 points |
| Cadence | no two frames of the stage are more than 34 ms apart, with eight windows. The stage's own log is the app's view of it; the film is the screen's |
| Hand-over | at the first and the last frame each stand-in is within 2 points of its real window; and inside each window's own rectangle, window to card to window is a fade: no step of more than 10 % of full scale from one frame to the next (some 130 ms or more). Measured inside the rectangle, because a window that grows changes the whole display's brightness, rightly |
| Nothing stray | no panel of Arbor's is on screen for less than 100 ms, and none is left 500 ms after the motion. Seen from outside, by the sampler |
| No flicker | nothing blinks, tears or shows through: not the wallpaper, not shadows, not text |
| Crisp | overlays, tiles, tab strips and the preview are sharp at both scales, their corners follow the windows', their text is legible on a light and on a dark wallpaper |
| One thing | the move reads as one motion with one meaning: a person who has never seen Arbor can say what happened |

## 9. Still to be built, and by whom

| What | Lane |
|---|---|
| `day.sh`, `sampler.swift`, `jolts.py` on the trunk; `"act"`, `"judged"` and `"detector"` in the JSON; `run.json`; the blindness of section 1 read from this page; `everything=1` at the second start; a place not given back after Float All or Quit becomes a `FAIL` | D |
| What section 5's last column still calls "to build" or "partly": `input-held` and the witness; event taps in `left-behind`; the new clauses of `fought`, `pulled` and `stuck`; the forgiveness under the stage narrowed to windows that have a stand-in | D |
| Days with Reduce Motion on; `"reduce_motion"` and `"stage_seen"` in `run.json`; `tile-click` acts | D |
| The sabotage tool and its run | D |
| The casts `browsers` and `awkward`; the cell `two` (does a hosted Mac allow `vdisplay.m`?); the two `sit` runs | D, N |
| The rules of section 5 as rules of the Linux walks: on the trunk for `jolt`, `moved-unasked`, `lost`, `focus`, `behind`, `size-lost` (`ChaosRunner.detector(for:)` says which rule is which detector; known failures carry a severity). **No net yet:** `flash`, `stuck`, and `fought`, which waits for macOS's tiling in the stand-in. `moved-unasked` is to be rewritten against section 6 | L |
| Walks that write a script for a real Mac, seeded from the commit. The first version has `switch`, `open-close`, `dock-key`, `drag`, `view`, `way-out` and `quit-and-start`; display changes, hiding, native tabs and full screen come from the written days | L, after D's vocabulary is on the trunk |
| The ledger of differences, each row saying which detector it touches | N |
| `docs/POLISH.md`, the films of the five moves, the stage's log of frames, the judge | Q |
| `"part"` and `"parts"` handed to every script by whoever starts a run, counted over all its Macs | O |
| `make viable`; `viable.py --self-test` as part of `make check`; the workflow that starts a gate, lists its runs for `--runs` and keeps to the queue's priorities. (`scripts/mac-shell/viable.py` itself is there) | O, D |

## 10. Beside the gate: what a person feels

The gate asks whether Arbor does rightly what it does. The first person to work with it quit it for macOS's own tiling, and no detector had said why: none asks whether the person wanted it done (`collab/HANDOFF-2026-10-14-maintainer.md`; `collab/IDEAS.md`, I24 and I25; `collab/QUESTIONS.md`, Q29). So `VIABLE` is no longer enough to hand Arbor to somebody. Beside it, on the same commit, at the switches that ship:

1. **Unasked actions: none.** By section 6's table, in every run that counts: a window the act does not name that moved, and an act of the person's that Arbor reversed. Each is a `FAIL` at the weight of `lost`.
2. **Against macOS alone: worse on no journey.** The same journeys with Arbor and in the control, scored on steps, keys and surprises.
3. **The budget is kept**: at most ten default shortcuts, none with a modifier besides ⌃⌥, one item in the menu bar.
4. **No default of Arbor's is a key of a common app's.**
5. **No complaint is unanswered**: `collab/scenarios/wanted/` is empty.
6. **The newcomer's eval**: better than macOS alone, task by task.

Their numbers go into the block of section 1 when each instrument has shown, on the first build, that it catches what the maintainer met.
