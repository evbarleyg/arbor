# F50: A command line people enjoy scripting

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: in progress (parts 1 to 4 are done; part 5, URLs that wait and call back, is written and held back)
Depends on: F01; complements I5 (`watch`)
Size: medium; each part stands alone

## Summary

"Everything is a command" is Arbor's best idea for the people who will recommend it: those who write Raycast scripts, SketchyBar plugins, Hammerspoon glue and dotfiles. The verbs are good. What a script needs around them is
not there yet: naming a window without first parsing JSON, output made for `jq` and for `cut`, and answers to "where am I?".

## Behaviour

**1. Name windows by app.** Wherever a command takes `[window]`, it also takes an app name or bundle id: `zoom Safari`, `dock com.apple.Terminal right`, `dock Mail beside Safari bottom`, `float Slack`. It means that app's most recently
focused window that Arbor arranges. No match: "no window of Safari; `windows` lists them". Numbers keep meaning window ids. `focused` and `pointer` (the window under the pointer) are also accepted.

**2. Small queries**, each one line per item as plain text, and JSON with `--json`:

| Command | Text output |
|---|---|
| `windows` | `412  docked    in-view      com.apple.Safari    Safari` (id, docked/floating/pinned, in-view/out-of-view/tile/minimised, bundle id, app). No titles unless `--titles` |
| `where` | `main  Safari and Mail  (n5)  depth 1 of 3  2 out of view`: one line per display: what the view shows, in the words replies use. This is the SketchyBar label |
| `views` | `1  Safari (n3)` per saved view, and named spaces when I1 lands |
| `displays` | id, frame, which has the pointer, which has the focus |
| `version` | `arbor 0.1.0 (1)`; `arborctl --version` also prints its own, and warns when they differ |

**3. JSON that is pleasant.** Rectangles are `{"x":0,"y":25,"width":720,"height":875}`, not Foundation's `[[0,25],[720,875]]`. `state` gets `"schema": 2`; keys are camelCase and only ever added. Document the schema in `docs/SCRIPTING.md` with
three worked examples: a Raycast script command, a SketchyBar item, a Shortcuts action through the URL.

**4. `arborctl` manners.**
- `--json` anywhere on the line, not only first. `-q` prints nothing and keeps the exit code.
- Exit codes, documented: 0 done, 1 Arbor said no (the reason on **stderr**, so `$(…)` stays clean), 2 cannot reach Arbor, 64 the command does not parse (checked locally, without a round trip).
- Several commands in one call: `arborctl dock Safari left , dock Mail right , home`; stops at the first failure.
- `arborctl help <command>` prints that command's usage, aliases and default shortcut.
- An unknown command suggests the nearest: "unknown command `zom`; did you mean `zoom`?"
- `arborctl completions zsh|bash|fish`.

**5. URLs.**
- A URL that arrives while Arbor is still starting waits for it, instead of failing in the log.
- `arbor://x-callback-url/<command>?x-success=…&x-error=…` for Shortcuts.
- Which commands a URL may run has shipped (`Command.isAllowedFromURL`, setting `allowAllURLCommands`): any web page can ask the browser to open an `arbor://` link.

## Design notes

- Names are resolved by the controller, not the parser: `Command` cases take a `WindowRef` (`.id`, `.app(String)`, `.focused`, `.pointer`) where they take `WindowID?` today. It is a wide, mechanical change in two hot spots; do it when few branches are open.
- An app called "left" or "beside" cannot be addressed by name; bundle ids always work.
- `CommandResult.text` stays the human form; add `json: JSONValue?`.

## Acceptance criteria

1. Every example in part 1 parses, round-trips through `text`, and acts on the most recently focused window of that app.
2. Each query has a text test and a JSON test; no titles without `--titles`.
3. Rectangles decode as objects; `arbor-e2e` reads schema 2.
4. Exit codes and stderr as listed (macOS CI runs `arborctl` against the e2e instance).
5. The three examples in `docs/SCRIPTING.md` are run by a test or by e2e.

## Shipped / Not shipped

Shipped: parts 1 to 4; `docs/SCRIPTING.md` is the manual, and every transcript and script in it is run by a test.

Different from the spec (`collab/QUESTIONS.md` has each decision):
- **`Command`'s cases still hold `WindowID`s.** Dozens of places build and match them. A command with names in it is wrapped instead: `.naming(command with stand-in numbers, [WindowRef])`,
  made by the parser's one helper for window words and undone by the controller. Nothing that builds or matches a plain command changed, and commands added later take names without doing anything.
- **Text output is separated by tabs**, which is what `cut -f` splits at; `arborctl` lines the columns up when stdout is a terminal, so a person sees the table in the spec.
- `windows` has a display column (4th), and more states of not being in view: `hidden`, `full-screen`, `other-space`. `where`, `views` and `displays` begin with the display's number (`@1` is the main one), not its id, which on a real Mac is a UUID.
- `--json` prints a query's answer alone, not the reply around it. For other commands it prints the reply, as before; a refusal is on stderr with exit code 1 even then (it used to be exit code 0).
- `help <command>`, suggestions and completions are read out of the help text rather than from a second table.
- `ARBOR_UNCHECKED=1` skips the local check, for a newer Arbor or `arbor-sim --serve`.
- **The JSON speaks the words of the events** (`watch`): `docked` true or false, `state` where the spec's table has in-view/out-of-view (`minimized`), `label` for a space in words, `display` and `displayID`. `version` is F13's `BuildInfo`.
- **More manners than were asked for**, so that there is one `arborctl`: `--timeout`, `--keep-going`, `--`, `arborctl - < file`, exit codes 3 (`watch`) and 4 (no answer in time), any other option before the command is 64, a line break in an argument is 64.
- **A link may not name a window by its app** unless `allowAllURLCommands` is on: by name a page could pick the window that gets the keyboard. `focused` and `pointer` it may say.
- **A number gone wrong is never a name**: "numbers keep meaning window ids", so `4294967296`, `1e3`, `w` and `n1` are refused rather than looked for among the apps. In quotes they are names.

Not shipped: part 5, of which both halves are written and held back. A URL that waits for the start would move every window twice where a launch brings an arrangement back: once by the start, once by its own command. x-callback URLs want a Mac to say what Shortcuts really sends as `x-success`, so that Arbor can hold callbacks to a list of schemes it opens rather than a list of those it does not. Nor `spaces` as a query row (F20). It takes in I5 (`watch`, the socket), F25 (`displays`) and the options `arborctl` had before: there is one `arborctl`, one `displays` and one manual, and `cli-smoke.sh` and `watch-smoke.sh` drive the real binary over a real socket, exit codes 3 and 4 among what they check.

How it is proven. Linux: everything above, through the real controller, the real `Arborctl.run` and, in the two smoke scripts, the real binary over a real socket; `ScriptingMovesTests` holds names, queries and refusals to "a window moves once, and only if it was asked about". A Mac: three headings in `arbor-e2e` ("name a window by its app", "arborctl's exit codes and streams", "the small queries": criteria 3 and 4), which the `real-windows` job runs unattended; they have not run yet. Nothing is left for a person to look at.
