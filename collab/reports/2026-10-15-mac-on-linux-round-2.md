# The real Accessibility layer on Linux, round 2

Follows `2026-10-15-the-real-ax-layer-on-linux.md`, whose numbering it continues. What `make mac-on-linux` is: `scripts/mac-on-linux/README.md`. Nothing under `Sources/` is changed here: findings are written down, and listed in
`scripts/mac-on-linux/known-failures.txt`, each with a story that goes green when it is cured.

**State:** 272 stories and the walk, 1,001 checks green, 135 red and listed, none new; the self-test's 10 checks of the program's own book-keeping and 21 of 21 changes to the layer noticed; walk of 400 seeds × 6 kinds of manners: nothing new.

## What is new in the tool

| | |
|---|---|
| **The list of known failures excuses only what it was written for** (a review found that it excused a regression in the walk's own control) | `sometimes:` counts only with `--seeds`; a rule of the walk is listed with its number of seeds, and another number is news; the self-test wants a change to the layer to be red AND news |
| **A walk goes on past a listed fault** | The layer is stopped and started there, as at a pause. All six kinds of manners take 1,600 of 1,600 steps (were 1,195, 1,298 and 969 for three of them), and the run says so |
| **What the layer was heard to report** | `collab/evidence/mac-on-linux/heard.jsonl`, story by story, for whoever keeps stand-ins at the seam. The run rewrites it when it is out of date, and fails that once |
| **Other threads than the main one, on the model's clock** | Real threads that pass one baton (`stubs/FakeMacOS/Threads.swift`): queues, semaphores, groups, the main queue; `AXUIElementCopyMultipleAttributeValues`. For a layer that gives each app a lane of its own; the trunk's has none yet |
| **Arbor can be gone while the Mac goes on** | What it has sent is sent: an app that hangs finds it in its queue when it wakes |
| **The model held to its evidence** | Six delays corrected to what the traces say, two guesses marked, three facts from recordings built in. No story changed its verdict |
| Hygiene | Arguments that select nothing are refused (exit code 2); Arbor's pid on the model is fixed; one run at a time in a work folder; no clock but the model's in all of ArborKit; the stand-ins' own public names are reported wherever Arbor's code uses them; `SOURCES=` |

## New findings

### N9. Arbor starts, or resumes, while an app hangs: seconds of standing still, and after a long hang the app's windows are never known   (FOUND BY THE WALK)
Each retry to observe the app waits the whole timeout on the main thread; the retries come 0.25, 0.5, 1, 2, 4, 8, 8, 8 s apart. A hang of 5 s costs 4 s of main thread, one of 60 s costs 9 s. After the short hang the window is known within 3 s of the wake. After the long one
the retries are spent: the window is not known 3 s after the wake, nor half a minute after, until the app happens to come forward. *Stories:* "Arbor starts while an app hangs, which wakes 5 / 60 s later".

### N10. A window that its app had put away before Arbor started is announced as "open all along" when it is shown again   (FOUND BY THE WALK)
Apps with one window (Music, Notes, Calendar) put it away when it is closed; the window server keeps the number. The layer remembers what was put away from having seen it go. At a start it counts whatever the window server lists as there, so the window shown again is `found`, not
`appeared`, if the app reports the focus before the creation (green if "created" comes first). Whatever Arbor does for new windows does not happen. *Story:* "an app's one window was put away before Arbor started, and is shown again, the focus reported first".

### N11. A move that a hang swallows   (FOUND BY THE WALK, which shrank it to two steps)
An app moves its own window 1 ms before it hangs for 5 s. "Resized" and "moved" arrive while it hangs; each read waits a second and fails; when the app wakes nobody reads the frame again. Arbor goes on believing the old frame, and no `changed` is ever said. 50 ms before the hang: green.
*Story:* "an app moves its window 1 ms before it hangs for 5 s".

### Apps that hang or are slow while Arbor has something to ask of them (`tests/SlowApps.swift`): the trunk's baseline
Told by what is on the screen, so that they hold for a layer that asks on the main thread and for one with a lane for each app.

| story | the trunk |
|---|---|
| Arbor is quit 0, 0.3, 1 s after an app with windows out of view begins to hang | **The windows stay out of view for good** after the app wakes |
| An app hangs for 8 s at the first setting call, or at the reading back, of a move out of view; Arbor is quit meanwhile | **The park is carried out when the app wakes, 7 s after Arbor is gone**, as measured on a hosted Mac |
| … hangs at the very beginning of that move | Nothing was sent: all in view |
| Arbor is paused 0, 0.3, 1 s after such a hang | Taken within 4 s; windows back within 10 s of the wake |
| ⌘Tab away while Arbor's request for the keyboard waits 0.8 s for a slow app | **The call returns late, and raise and activate steal the keyboard** from where the person went; the ring follows |
| An app takes 0.7 s over every move, one window refusing its slot's width | **`arrange` answers after 3.3 s**; in the end no window lies over another |
| An app wakes after 0.7 s in the middle of a move; the main queue on time, or 20 ms late | Right places, no further pulling |
| The app opens a window, resizes a docked one, gets a new tab 5 ms after it wakes | Known, in view, right size, the tab in its place |
| A window moved by hand while Arbor moves its slow app's sibling | Told apart |

### More on drags (L1)
- **Coarse steps**, as a script makes them of a long drag (30 steps of 42 or 66 points): with the window server 50 or 100 ms late to start, or behind all the way, the trunk sees NO drag at all; on time it sees it at 21 ms. This is what a hosted Mac showed (three of four such drags never taken for drags).
- **The hand rests, the window comes after it in one leap**: lost on the trunk.
- **A selection during which the window changes by itself** (the pointer's way, against it, across, aslant, resized): never taken for a drag on the trunk. These are the controls for any cure of L1.
- **A system alert over the title bar** (another process, the level of modal panels): the alert gets the press and the window stays. The layer reports `pressed` and nothing else, and logs nothing. `makePress` skips whatever is not at level 0, so it takes the window underneath for the one pressed; harmless as long as that window stands
  still. To a script it looks just like L1: no drag, nothing logged.

## What agreed with a Mac without having been built for it
Told only that Safari and Finder drop a closing window from their list at once, the real layer on the model says `destroyed` and then `focused` of the sibling, 15 to 20 ms apart: the order, and about the gap, of recordings of hosted Macs (4 to 13 ms, once 91).

## Still to check on a real Mac
- Whether `AXFocusedWindow` names a window on another Space (one listed line of the walk rests on it).
- What is posted when the LAST window with the keyboard is minimized.
- The default timeout of a call: Apple's header suggests six seconds, the one measurement gave 1.55 s.
- Why a dragged window can end one step further than the pointer travelled (seen once; the model has a switch for it, no explanation).
