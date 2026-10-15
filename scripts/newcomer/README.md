# The newcomer's eval

The parity score counts features and the day's detectors count faults. Neither says whether Arbor is easy, calm and worth having.
This does (collab/IDEAS.md, I24): **somebody who has never seen this repository gets what a stranger gets** (the top of the README, a build to
install, a Mac) **and a short list of tasks, sees nothing but pictures of the screen, and acts only with real keys, clicks and drags.** The same
tasks are played with Arbor not there, with what macOS itself offers. Arbor has to do better than that, task by task, to count as an
improvement.

The newcomer is an agent. There is no model at the far end of the runner, which would take a key and money: it sits wherever agents sit, and
the two talk **through Git, one picture and one act a round.**

## In short

```bash
scripts/newcomer/start.sh n1 macos               # a hosted Mac as it comes; prints what to tell the newcomer when the first picture is up
scripts/newcomer/start.sh n2 arbor 3deb36a       # the same, with Arbor built from that commit lying zipped in Downloads, as a browser would have left it
# … a newcomer plays each: a fresh one every time, for whoever has played once is no newcomer …
scripts/newcomer/fetch.sh n1 n2
scripts/newcomer/score.py .newcomer/n2 .newcomer/n1
scripts/newcomer/rehearse.py -v                  # all of it on Linux, against a Mac of a hundred lines: part of `make lint`
```

One run holds one Mac for up to two hours, and only one runs at a time. No call to GitHub's API is made anywhere.

## Who the newcomer is

Whoever has read this repository is not one. It is started **without the source and without anybody's notes**, and is told two lines:

    git clone --depth 1 --single-branch --branch mac-shell-out/newcomer.<run>.screen <this repository's address> mac
    cd mac && cat HOWTO.md

That branch holds one commit with no history: [HOWTO.md](kit/HOWTO.md) (its words of use), `mac` (a shell script: its eyes and hands), with Arbor the first 45
lines of the README of the build under test, and the newest picture. It needs git, a shell, python3 (for the check that reads its remarks), the right to push here, and
eyes. **All runs that are compared are played by the same kind of newcomer, told the same two lines**, and promptly: with Arbor the Mac waits about ten minutes for `ready`,
no longer than leaves every task its whole time.

**It needs somebody's leave.** Its words travel as pushes to a public repository, from a session that was told next to nothing. Where agents work under a permission check, that check
may refuse exactly this, and did, the first night: a session without the repository was not allowed to push to it, and neither a relay nor a helper inside another session is a
way round, being the same pushes by another path. Whoever is responsible for the newcomer has to say, in their own words, that it may push to
`mac-shell-out/newcomer.<run>.action`. Until then the rig can be tried by whoever keeps it, which proves the rig and scores nothing.

## The tasks

The maintainer's seven and one of the product owner's (3), in [tasks.py](tasks.py), in words that say what is wanted and never how. With macOS alone the first and the last fall away.

| | the task | minutes | done when the window server shows |
|---|---|---|---|
| 1 | install and start it | 15 | Arbor runs and has the Accessibility permission |
| 2 | two windows side by side | 10 | TextEdit left of Safari, no overlap, each 30 to 70 % wide and 85 % high, together 85 % of the room, neither behind anything |
| 3 | an arrangement comes back | 10 | Safari filled the screen at some time, and at the end it and TextEdit are where they were at the task's beginning, to 12 points |
| 4 | one window fills the screen, and stays | 10 | Calendar covers 90 % of the room between menu bar and Dock, or is in full screen; and still does eight seconds later |
| 5 | find a window that went out of view | 10 | all of Notes lies between menu bar and Dock with nothing in front of it |
| 6 | undo a mistake | 10 | a Finder window took up the left half at some time, and at the end every window is where it was at the task's beginning |
| 7 | go back to how the Mac was | 10 | every window is where it was when the newcomer said `ready`, and as big (`first.jpg` in its folder is the picture it saw then) |
| 8 | quit, and leave the Mac as it was found | 8 | no Arbor, nothing of Arbor's on the screen, and every window as in 7 |

Each follows from the one before, as on a real desk: what fills the screen in 4 is what hides Notes in 5. Nothing is put right in between: a hand from outside would move windows, and
Arbor would answer it. So whoever fails one task may find a later one done, or have less to bring back; the rig writes down where each task began, and the score
says "already so" or "not comparable" instead of "better". The newcomer is not told whether it was right.
"In front" means ordinary windows and panels that float above them, of other apps: not the line Arbor draws round the focused window, which hides nothing. A window that was closed
and opened again is still "the Finder window". The limits are there so that one task cannot eat the run: a round takes a quarter of a minute, and a job two hours at the most.

## The score

[score.py](score.py) prints the tasks down and, for each run, across: **done** (by the table above, whatever the newcomer thought), **acts** (every chord is one), **wrong turns** (it
said so, or nothing on the screen changed), **stuck**, **surprised**, **looked up** (it said so), **windows moved untouched**, of those the **unasked**, **seconds**; then what lies
behind the numbers, every remark word for word, and what a round cost. Its header says exactly what counts as what. The verdict against macOS alone rests on what needs nobody's word:
done, acts, acts that changed nothing, moved untouched. What was said stands beside it: how often somebody says it is surprised depends on who it is.

*Moved untouched* needs nobody's opinion. Before and after every act the rig reads the window server's list. A window counts as touched if it lay under the press or the
release, or, for keys, had the keyboard before or after. Any other whose frame changed was moved by somebody else: Arbor, macOS or its app, which is what the
run without Arbor is there to tell apart. What moves between two rounds or after the last act, while nobody does anything, was touched by nobody. It is meant literally: an Arrange
that was asked for counts the windows it moves. So beside it stands **unasked**: those the act did not even name, by the table in docs/VIABLE.md, section 6, read from the
commands in Arbor's log and the windows it had docked. Two numbers, so that nobody can argue the first away. The sampler of `make day`
writes down every frame of every window sixty times a second (`samples.log`), for whoever wants to see the road and not only the ends.

**Every surprise becomes an entry in collab/IDEAS.md or a scenario**, as collab/reality.json does for faults. A transcript goes into the repository only
through `scripts/public-check.py --text`.

What the newcomer is spared is said in the score's first lines, never passed over:

- **The password.** macOS asks for the account's before it lets the Accessibility switch be flipped or a refused download be opened, and nobody knows a hosted Mac's. The newcomer
  meets the request, finds the switch and flips it; when the dialog comes it says `password`, which counts as an act, and [help.sh](help.sh) does what the switch would have.
  Nothing happens unless macOS is asking, and nothing but the very build under test is ever let past.
- **After the first task.** One wall must not cost the others: if Arbor is not ready when the time for installing is up, it is installed, started and given the permission. The task stays
  not done, "then helped".
- **Gatekeeper**, only when asked. There is no release, so the build is made on the spot and laid in Downloads as a zip, marked as a browser marks a download: macOS then refuses it, as it
  will refuse every stranger's download until a build is notarized, and what that costs is part of the score. `unmarked` spares the newcomer that, as a control.
- **The last pixels.** macOS tiles a window dragged to the very edge of the screen, where a hand always arrives because the pointer stops there. A drag that ends within eight points of
  an edge ends on it.
- What cannot be done at all: a pinch, a key held down while something else is done.

## How a round goes

```
  the hosted Mac                                    GitHub                                        the newcomer
  rig.py: picture, status ──▶ courier.sh ──push──▶  mac-shell-out/newcomer.<run>.screen  ──fetch──▶  ./mac … shows it
  rig.py: fetch every 2 s  ◀─────────────────────   mac-shell-out/newcomer.<run>.action  ◀──push───  ./mac click 200 300
  words.py takes it apart; pointer, witness act; the sampler says when the windows rest; the window list is read again
  journal.jsonl ──▶ courier.sh ──push──▶            mac-shell-out/newcomer.<run>.record             (not for the newcomer)
```

- Every branch holds **one commit without history**, pushed with force, made as the output of a Mac shell run is: so no clone grows by a picture a round, no
  workflow starts (a commit without workflows starts none), `scripts/public-clone.py` knows the kind, and `scripts/housekeeping.py` takes them away after a day.
- A message is the number of the picture it answers, remarks, and at most one act. One that answers an older picture came too late (a task's time was up meanwhile): it is
  dropped, and `./mac` tells its sender.
- The run is started by a push to `newcomer-start/<run>`, whose subject says what is asked for; the courier deletes that branch at the end.
- `./mac` takes only the picture and the lines about it from what it fetches, never itself: what runs in the newcomer's sandbox is what it cloned and could read.

## What can go wrong, and what is done about it

**What can leak.** Everything on those branches is public at once, and for good: a picture that has been pushed over can still be fetched by whoever knows its id.
- *From the newcomer.* `./mac` sends nothing it has not taken apart. An act is numbers, `holding`, `keep` and the names of keys, and anything else after it is refused. A remark can hold
  letters, digits, spaces and `. , : ; ' ( ) ? ! + -`, so no path, link or address can be spelled; a host, a name or a number still can, so remarks and text to be typed are read by the
  repository's own `public-check.py`, which travels in the kit, and where that is missing or cannot tell, they are not sent. Commits are made under the name the workflows use, in UTC.
  The rig writes into the journal what it understood, never what came.
- *From the Mac.* It is a throwaway: the account is GitHub's `runner`, the documents are made up, nobody is signed in to anything, and the source of the build is deleted before the first picture.
- *The token.* Pushing takes one, pictures of the screen are public, and the newcomer can open a terminal. So the token is in no file, no argument and no lasting environment of
  the account the newcomer acts in: one step hands it to [courier.sh](courier.sh) on standard input, and the courier, a copy that is root's own, runs as root, finds its tools in the system's
  folders, and does nothing but push two folders and delete one branch. **That keeps the token from showing by accident; it is no wall.** The account may use `sudo` without a password, so
  whatever runs in it with intent can get at the token for as long as the job lasts. Three things run there: acts, which only who may push here can send, and who has more than the token gives;
  the build under test, which therefore has to be on a branch of this repository (the workflow refuses a commit that is only a stranger's pull request); and whatever a newcomer
  might download, which macOS's guards meet as always, since nothing but the build under test is helped past them.
  The token may write contents: branches, tags and releases, `main` and `swarm/trunk` among them as long as no ruleset keeps workflows out, which is the maintainer's to set
  (docs/REPOSITORY.md), for this workflow as for "Mac shell".

**What can hang.** Every wait has an end: `ready`, each task, the run (a hundred and ten minutes from the job's start), the script (`MAC_SHELL_LIMIT`), the step, the job. Every tool the rig calls
has a time limit. The journal is pushed every round, so a job that is killed outright has still told what it saw. Mouse buttons and keys are let go of at the end of each task.

**Nonsense.** Nothing is passed on as it came. A line is taken apart into a verb, numbers within the picture, names of keys from a list, or printable characters, and
put together again ([words.py](words.py)); whatever does not fit does nothing, costs a round, and is answered in words. `rehearse.py` tries bytes that are no text, a megabyte, a shell's words.

## What it does not tell

An agent is not a person: it reads every word on the screen, never gets impatient, and sees stills, so motion is lost on it, and what flashes by between two
pictures is seen by the sampler alone. One run is one newcomer: two runs differ. Seconds are mostly the way through Git. It is a net for "I could not find it", "it did what I had
not asked for" and "it took five steps", not a measure of delight.
