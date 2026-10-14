<!-- The description of a pull request. Read it through `scripts/public-check.py --text` before posting: docs/PUBLIC.md. -->

## What it changes for a person

<Two or three sentences somebody who has never seen the code can follow.>

- Board item:
- Spec: docs/features/<file>
- Reference items: T.., A..

## Before

<Parity line from `make parity` before the change, and what you saw when you
tried the current behaviour (sim output, scenario results, e2e).>

## What changed

<Files and behaviour, briefly.>

## Evidence

- `make check`: <test counts>
- `make parity`: <score before → after; any items that changed level>
- Scenarios: <which ran, which passed>
- Real windows: <what ran on a hosted Mac and what it brought back, or "nothing: Linux proves all of it, because …">

## Deviations from the spec

<What you did differently and why. "None" if none.>

## Still unchecked on real windows

<What, and the script that will check it on a hosted Mac. "Nothing" if nothing. What only a person at a desk could check is not done.>

## Questions and ideas raised

<Links to new Q-numbers in QUESTIONS.md and entries in IDEAS.md.>
