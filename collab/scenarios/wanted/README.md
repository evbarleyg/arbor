# Wanted: every complaint a test

One scenario for each thing a person disliked when they used Arbor (`collab/IDEAS.md`, I25 e). **Each fails until it is answered.** So this
folder is not part of `make scenarios`. Run it by itself:

```bash
ARBOR_SCENARIOS=collab/scenarios/wanted ./scripts/scenarios.sh
```

- Each file's head names the idea, the ruling (`collab/QUESTIONS.md`) and the row of the board. It plays Arbor **as it comes**: no setting is changed to make it pass.
- Whoever answers a complaint takes its scenario as their red test, sees it fail for the reason it names, and **moves it up into `collab/scenarios`** in the change that turns it green. From then on `make check` holds it.
- A word the simulator does not know yet (`double-click`, `windows`, `side-by-side`, `set shortcuts`) is part of what is wanted. Its builder may choose another name, and changes the scenario with it. The story and what is expected stay.
- A new complaint gets a new file the day it is made, before anybody builds.
- An empty folder is the aim.

Not here: I21 (a browser would not dock on the right while another window was minimized). By key the simulator docks it, at real smallest sizes too. By a drag to the right edge with macOS's tiling as it comes nothing docks, minimized window or not, because that edge is macOS's (Q23): the likeliest story, not yet seen on a Mac (board 0.13).
