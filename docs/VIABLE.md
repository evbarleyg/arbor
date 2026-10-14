# The viable gate

When is Arbor good enough to hand to somebody who did not build it? Issue #4 answers in one sentence: **20 synthetic user-hours across apps, displays and both
settings of macOS tiling, with no lost or stuck window, no jolt, no focus error and no lost size; then the polish rubric passes on the five moves.**
This page says what each of those words means in numbers, so that a program gives the verdict and nobody has to be asked to look.

- The verdict is about **one commit**. It is `VIABLE`, `NOT VIABLE`, or `INVALID` where nothing shows that the detectors catch anything (section 5), with the reasons and the ledger of runs it rests on.
- The numbers are in the block in section 1. `scripts/mac-shell/viable.py` reads them **from this page**: there is no second copy.
- Kept by the product owner. A number changes only by a pull request that says why, never in the same pull request as a fix it would excuse.
- It replaces the half hour on one person's Mac that issue #3 ends with (`collab/QUESTIONS.md`, Q19). Its measure is the same: no jolt, no lost or stuck window, nothing moved that the person did not move.

**State, 2026-10-14: a draft that binds.** The sampler, the day and five detectors exist on a branch (`scripts/mac-shell/day.sh`, `sampler.swift`, `jolts.py`). Section 9 lists what is still to be built, and by which lane.
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
    "idle": 40
  },
  "fail_max": 0,
  "odd_unexplained_max": 0,
  "share_of_acts_judged_min": 0.9,
  "share_of_runs_that_do_not_count_max": 0.2,
  "sampler": {"late_ms": 100, "share_of_samples_late_max": 0.01, "blind_ms_max": 250},
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

## 5. The detectors: what counts as a failure

A detector reads what a run recorded and never asks Arbor what it believes. **One `FAIL` from any of them, in any run that counts, and the commit is `NOT VIABLE`.**
Distances are in points. "Changes" means by more than 2, because apps round and Retina screens deal in halves.

| Id | Rule (#3) | `FAIL` when | Reads | State |
|---|---|---|---|---|
| `moved-unasked` | 2 | a window changes its frame during an act that may not move it (section 6) | samples | `jolts.py`, rule 2 |
| `jolt` | 3 | for one act a window moves more than once (two changes more than 250 ms apart), or goes more than 6 points out of the straight road to where it ends up, or opens in one place and is then moved to another | samples | `jolts.py`, rule 3 |
| `pulled` | 3, 6 | while the button is down the dragged window is more than 6 points from where the pointer carries it | samples | partly: `drags=` |
| `flash` | 3 | a window that is out of view at both ends of an act shows more than its parking strip in any sample between; or any window leaves the screen and comes back within one act that did not ask for it | samples | partly |
| `fought` | 1 | after a drag that macOS answered (the window ends in one of macOS's own tile frames, or its preview was up) Arbor moves that window, docks it or shows a preview of its own; or Arbor moves any window before the first run has shown what it found | samples, `arbor.log` | to build |
| `lost` | the measure of a severity 1 | at the end of an act that did not take it out of view, less than half of a window is on any display; or at a point where everything must be in view (after ⌃⌥0, pause, Float All, Quit) a window shows less than its own frame did | samples | `jolts.py`, rule L |
| `stuck` | 3, 4 | a window is moved by Arbor more than three times in two seconds with nobody acting; or a window a real drag let go of is neither where it was let go nor where the preview was; or after Quit a click on an app's Dock icon does not bring its window to the front | samples | partly |
| `behind` | 4 | the window switched to does not end in front of every other ordinary window | samples (order) | `jolts.py`, rule 4 |
| `focus` | 4 | the window switched to does not end wholly in view with its app in front and itself its app's focused window; a key typed into a witness window arrives elsewhere; or the app in front changes during an act that is no switch | samples, `apptool`, the witness | partly |
| `size-lost` | 5 | after pause, Float All or Quit a window's size differs from its own: the last size it had while nobody but its person and its app decided it. After Float All and Quit its place too | samples | `jolts.py`, rule 5 (place: today `ODD`) |
| `input-held` | 6 | the button is not up within 50 ms of the posted mouse-up; a click 300 ms after a drop does not arrive in the window that lies there; a key, click or scroll that is not Arbor's does not reach the witness, or reaches it more than 10 ms later (99th percentile) than in the run without Arbor | the witness, samples | to build |
| `slow` | 3 | a window Arbor moves is not at rest 1,500 ms after the act's event was posted (`ODD` from 700 ms: the motion takes 460). The first act after a start has 3,000 (`ODD` from 1,500) | samples | partly: `settled=` |
| `crash` | severity 2 | Arbor's process ends unasked; a crash report of Arbor's appears; `arborctl status` takes longer than a second; Quit takes longer than five | the script | partly |
| `busy` | daily use | during `idle` acts Arbor uses more than 1 % of a core on average, or writes more than 20 lines of log a minute | `ps`, `arbor.log` | to build |
| `left-behind` | 5 | after Quit a process, a panel or an event tap of Arbor's is still there | the window list, `ps` | partly |
| `told` | privacy | a canary word turns up in anything the run brings back but the pictures. Every document and page the script opens has one in its title | `grep` over the artifacts | to build |

**What the samples see, and what they do not.** The sampler sees the real windows, which Arbor moves under its stage while stand-ins travel over them. So a `jolt` in the samples is a fault, and no `jolt` in the samples is not yet a smooth motion: what shows meanwhile is the film's to judge (section 8).

**What is macOS's own and no finding:** the road of a window into the Dock and out of it; and what a window does in its first 600 ms within 24 points of where it first showed, since macOS pops windows open.
A frame that its person left hanging over an edge is theirs: given back as it was, it is not `lost`.

**`ODD`** is what a detector cannot judge alone (a window changed size while it was dragged; the window in front changed three times). An `ODD` is explained within a day: it is macOS's or the app's doing because the run without Arbor shows it at the same act,
or it becomes a `FAIL`. With one unexplained the verdict is `NOT VIABLE`. One class explains itself and is only listed: a sheet or a dialog that follows its window, when that window was moved in the same act.

**Three controls, without which a silent detector means nothing:**

1. **Without Arbor** (`day-control.sh`): each cell is played at least once with Arbor not running. What the same journey (script, seed, cell, cast) shows there too, by the same detector at the same act, is not Arbor's: `viable.py` compares, and lists it.
   Nothing else excuses a `FAIL`.
2. **Sabotage**: at least one run per gate in which a tool of the harness, not Arbor, commits offences at acts it writes down: moves a window twice, moves one nobody named, flashes one, covers the window switched to, takes the keyboard, leaves a size wrong after Quit,
   holds a mouse-up, kills Arbor, writes a canary into a log. **Every detector of section 1 must have caught an offence of its own**, at the act where it was committed. One offence may set off several detectors; a report at an act where nothing was committed is a false alarm.
   One miss, one false alarm, or one detector that was never tried, and the gate is `INVALID`, whatever the other runs say.
3. **Each detector's own test** on written samples (`jolts.py --self-test`), part of `make check`.

## 6. What an act may move

Each window at most once, straight to where it ends up.

| Act | May move |
|---|---|
| Arbor starts for the first time; `idle`; a switch to a window in view; anything done to a floating window but a drag of it | nothing |
| Arbor starts again | what was docked when it stopped. No window that is in view goes out of view (Q16) |
| A window opens | nothing, and the new window stays where its app put it (`newWindows` ships `"float"`) |
| A dock, by key or drag | that window and the docked windows. **No floating window, ever** (Q20) |
| A float; a docked window closes, is minimized or hidden, or comes back | that window and the docked windows. There and back is nothing: hidden and unhidden, every window is where it was |
| A drag | the dragged window goes where the pointer goes. Everything else waits for the button |
| A move of the view; a switch to a window out of view | the docked windows; floating windows only out of view and back to exactly where they were |
| A gap or an edge is dragged | the windows on both sides of it |
| Pause, resume, Float All, Quit | anything; afterwards `size-lost` and `lost` have their say |
| macOS's own (full screen, Mission Control, a Space, the wallpaper click) | what the run without Arbor shows macOS moving. When it is over, every window is where it was before |
| A display comes, goes, moves or changes size | the windows on the displays concerned; afterwards nothing is `lost` |

## 7. Which runs count

A run counts when all of this holds. One that does not counts for nothing either way, with one exception: **a `crash` counts always**.

- It ran on a hosted Mac, unattended, on the commit being judged, started by the workflow in the repository, and the script took under 600 seconds from its first line to its last. The toolchain and the build come before it and have their own target (board, section 2).
- It brought back its manifest, the samples, `arbor.log`, a trace (`docs/TRACES.md`), the findings as JSON, and a picture and a story for every finding.
- The sampler saw enough: at most 1 % of its samples came more than 100 ms after the one before. An act during which it was blind for more than 250 ms is not judged. (The first hosted day reached 33 samples a second with blind spells of up to 1.5 s; a cure is being tried. These two numbers are unproven until it has run.)
- At least 90 % of its acts were judged, and at least six apps of its cast opened a window.

If more than a fifth of a gate's runs do not count, the gate is `INVALID`: too many fell out to believe the rest.
- At `defaults`, macOS's tiling was seen to act before Arbor started.

**No run is left out and none is repeated until it passes.** `viable.py check --runs` is given every run of the gate's workflow on that commit as GitHub lists them, with how often each was started. One that the ledger lacks is a reason; one that GitHub does not know, or that is there twice, makes the gate `INVALID`;
without the list the verdict is never `VIABLE`. A run that was started again counts with every attempt. A run that ended before its report is in the ledger too: it was started, so it is accounted for.

**The manifest** (`run.json`, written by the script):

```json
{"gate": 1, "commit": "<40 hex>", "run": "<GitHub's run id>", "attempt": 1, "script": "day.sh", "kind": "day | walk | sit | control | sabotage", "seed": "<from the commit, for a walk>",
 "tiling": "defaults", "tiling_seen_to_act": true, "display": "laptop", "cast": "stock", "apps": ["com.apple.Safari", "…"], "settings": "shipped", "macos": "<version and build>", "seconds": 540}
```

It is written when the run begins and completed when it ends. A sabotage run's also has `"offences": [{"detector": "jolt", "id": "idle#3"}, …]`. An act's `id` is its slug and which act of that slug it is in its run, so that it means the same act in the run without Arbor.

**The findings** are what `jolts.py report --json` writes, with two more keys a step: `"act"`, its kind from section 4, and `"judged"`; and one more a finding: `"detector"`, its id from section 5. The naming is the detector's own business: `viable.py` refuses a finding that names none. That Arbor died is `crash`, whoever noticed.

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

Every measure is first tried on a metronome: a square of the camera's own that moves rightly once and wrongly in known ways. If the judge misreads it, that run's score is void. The judge builds nothing it judges.

What the product owner asks of the rubric, whatever else it holds. The first five are measured, from the sampler, the stage's own log of frames and the film; the rest are judged from the film by an agent that has the rubric and no stake in the answer.

| Row | Passes when |
|---|---|
| Length | the motion takes `animationDuration` (460 ms) give or take 60 |
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
| The detectors marked "to build" or "partly": `fought`, `input-held`, `busy`, `told`, `pulled`, `flash`, `stuck`, `focus` with the witness | D |
| The sabotage tool and its run | D |
| The casts `browsers` and `awkward`; the cell `two` (does a hosted Mac allow `vdisplay.m`?); the two `sit` runs | D, N |
| The rules of section 5 as rules of the Linux walks: there for `jolt`, `moved-unasked`, `lost`, `focus`, `behind`, `size-lost` (`ChaosRunner.detector(for:)` says which rule is which detector; known failures carry a severity). **No net yet:** `flash`, `stuck`, and `fought`, which waits for macOS's tiling in the stand-in. `moved-unasked` is to be rewritten against section 6 | L |
| Walks that write a script for a real Mac, seeded from the commit. The first version has `switch`, `open-close`, `dock-key`, `drag`, `view`, `way-out` and `quit-and-start`; display changes, hiding, native tabs and full screen come from the written days | L, after D's vocabulary is on the trunk |
| The ledger of differences, each row saying which detector it touches | N |
| `docs/POLISH.md`, the films of the five moves, the stage's log of frames, the judge | Q |
| `make viable`; `viable.py --self-test` as part of `make check`; the workflow that starts a gate, lists its runs for `--runs` and keeps to the queue's priorities. (`scripts/mac-shell/viable.py` itself is there) | O, D |
