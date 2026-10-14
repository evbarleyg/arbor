# F50: A command line people enjoy scripting

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: ready
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
