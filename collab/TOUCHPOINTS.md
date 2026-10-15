# Touchpoints: each time the maintainer was needed

The purpose of this project, in the maintainer's words (issue #4): "to see if we can reach truly autonomous development from someone who's non-technical, like me, and replicate a consumer-grade app."
So the number that matters here is **how often, and for how long, a person was needed**. The target is near zero beyond identity, money and what cannot be undone.

Kept by the product owner. One row each time, written the same day. Minutes are estimates. **Nothing private**: never which apps or machines, no names, no sums, no quotations from private conversations.

**Kinds.** *Needed*: identity, money, an irreversible act: only a person can. *Avoidable*: the swarm asked, or made the person step in, where a rule, a default or a check would have done. *Their own wish*: nobody asked; they chose to.
Every avoidable row names what would have avoided it, and that becomes a board item or a rule (last column) until the same row cannot happen again.

## The count

| Day | Needed | Avoidable | Their own wish |
|---|---|---|---|
| 2026-10-14 | 4 matters, 5 times, 10 min | 7 matters, 10 times, 36 min | once, 30 min, and two pointers |

## 2026-10-14

| # | Kind | What for | Min | What would have avoided it | Now |
|---|---|---|---|---|---|
| 1 | needed | To approve that the repository goes public | 2 | Nothing: irreversible | stays theirs |
| 2 | needed | To give the agents' account write access and accept the invitation | 5 | Nothing: identity | done once |
| 3 | needed | To say that agents may merge to `main` when every check passes | 1 | Nothing the first time: it hands over authority | a standing word; not asked again |
| 4 | avoidable | Had to set the privacy rules for going public themselves | 10 | Private by default: no person's name, machine, apps, logs or pictures in anything public, before anybody asks | the rules are written; a lint on files, commits and comments (board, guardrails) |
| 5 | avoidable | Had to ask for short, plain updates after long technical ones | 3 | Write for a non-technical reader from the first line | one digest a day, five plain lines |
| 6 | avoidable | Was asked three times to choose between publishing now and waiting for a fix | 5 | One recommendation, with a default that applies on silence | issue #4, section 5: 24 hours, then the default |
| 7 | avoidable | Was asked, twice, whether public posts that broke their own rule should be reworded | 4 | The rule was authority enough | mend first, report after; the lint catches it before it is posted |
| 8 | avoidable | Was told of a warning that did not apply to them | 2 | Report only what needs a decision | the digest holds decisions and defaults, no noise |
| 9 | avoidable | Was asked about a line in a commit message | 2 | Harmless; should not have been raised | product and process questions go to the product owner |
| 10 | avoidable | Was walked through options for getting more Macs | 10 | Decide within the rule that stands (free services only) and report the outcome | issue #4, section 1; the queue's priorities |
| 11 | needed | To say whether work written before the repository went public may be brought over into it. The agents' own safeguards rightly refuse that on an agent's word. **Answered: yes**, through one hand, after an automatic privacy scan that nobody can override. Asked twice: the first yes could not be tied to a question anybody could see, so it was asked again in a form that keeps question and answer together | 2 | It is theirs to say, since it cannot be undone. Asking once, in so many words, at the moment of going public, as part of "bring over what has not landed" | answered; the road works |
| 12 | their own wish | Drove the reference app for about half an hour | 30 | Not to be avoided: it gave the project issue #3, the most valuable half hour of the day. What it found is now looked for by machines: `docs/VIABLE.md` | the day with real apps at macOS's default settings |

**Two pointers they gave unasked, both right**, and the question each leaves:

- *The tests pass and the real Mac disagrees.* What would have let the swarm see that by itself? A count of the differences between the stand-ins and real Macs, kept from the first day, and a rule that nothing is "done" on stand-ins alone. Now: ring 2 of `docs/VIABLE.md`.
- *The Macs are the bottleneck.* What would have shown it? Measuring where an hour of waiting goes before adding hands. Now: Mac minutes per landed fix are on the scoreboard, and a Mac run has to name the question only a Mac can answer.

**Eight notes they gave unasked, after working with the first build** (2026-10-14; `collab/IDEAS.md`, I16 to I23; ruled on as `collab/QUESTIONS.md`, Q29). They quit Arbor afterwards and went back to macOS's own tiling, and said so in a handoff the same evening, with two more notes on how the swarm could have known (I24, I25). Half an hour of theirs turned the second build round: less by default. The question they leave is the hardest so far:

- *Nothing in sixteen detectors, four rings and a day with real apps said that Arbor does too much.* Every instrument asks whether Arbor does rightly what it does; none asks whether a person wanted it done. What would have let the swarm see it by itself? A control that counts: for each act of a day, what changed on screen with Arbor that would not have changed without it, and whether the act asked for it. Readers who are given the app's behaviour, not its words, and asked what surprised them. And a rule for defaults, now Q29's: would a person who has read nothing be surprised? Then it is off.
- *Eight of ten were no fault by our own books: the gap is not between the fake and the Mac but between the spec and the person* (the keeper of the ledger, who checked each complaint against what was written and tested at that commit). Arbor did what the specs said, and some 5,800 tests held it to that. The other two were known, ruled on and not built. On Linux, walks that play a newcomer with Arbor as it shipped: in 86 % a plain drag docks, in 89 % it moves a window nobody touched, in 43 % a floating window is taken out of view: the maintainer's session was no bad luck, it was the median. What was never asked: whether a person wanted what Arbor did.
- *A key of Arbor's destroyed something in another app.* No test looked outside Arbor's own windows. Now: board 0.1, and a table of what each of Arbor's keys does in the apps people run.

## What still needs a person, and the default if nobody answers

| What | Why only they can | Default on silence |
|---|---|---|
| A Developer ID, so that a download opens without a warning | identity and money | Arbor ships signed ad hoc, and `docs/INSTALL.md` says what macOS will ask and why. **What the default costs, seen on a hosted Mac on 2026-10-15:** macOS refuses a downloaded Arbor; the way round is four steps through two dialogs, System Settings and an administrator's password, and in both dialogs the blue default button is Move to Trash. An ordinary person will not get through that: without the ID Arbor can be viable for people who build it or paste one line into Terminal, and for nobody else |
| The first tag and release | irreversible, under their name | none is made until `docs/VIABLE.md` says `VIABLE`; then the product owner proposes it in the digest, and it waits for their word |
| A key for a model at the far end of a hosted Mac, for the newcomer's eval (IDEAS I24) | money, each month | nobody asks; the eval runs in its slower form through Git, one screenshot and one action a round |
