# F11: Per-app rules

Status: done (verified headlessly; real-window check pending)
Depends on: F01

## Summary

New windows always float today. Rules let users say what happens to new
windows of a given app: dock them at an edge, dock them beside another app's
window, float them, or leave them alone. Exclusion already exists
(`excludedBundleIDs`); rules generalise it.

## Behaviour

`settings.json` gains an optional `rules` array, checked in order; the first
match wins:

```json
"rules": [
  { "app": "com.apple.Terminal", "action": "dock right" },
  { "app": "com.apple.mail", "title": "Inbox", "action": "dock left" },
  { "app": "com.tinyspeck.slackmacgap", "action": "dock beside com.apple.mail bottom" },
  { "app": "com.apple.systempreferences", "action": "float" },
  { "app": "com.apple.finder", "action": "ignore" }
]
```

- `app`: bundle id, exact match, required. `title`: optional, case-insensitive substring.
- `action`:
  - `float`: today's behaviour;
  - `dock <edge>`: dock at that edge of the current view on the window's display;
  - `dock beside <bundle id> <edge>`: dock beside the most recently focused docked
    window of that app on the same display, or fall back to `dock <edge>`;
  - `ignore`: never arrange this window (like exclusion, but per rule).
- Rules apply only to windows that appear while Arbor is running, not to
  windows restored from `state.json` or adopted at launch.
- Invalid rules are skipped and logged.
- `arborctl rules` (new query command) prints the effective rules and, for the
  focused window, which rule matches.

## Design notes

- A new pure `Sources/ArborCore/AppRule.swift`: `AppRule` (Codable, decoding the
  action from its text), `RuleAction`, and
  `AppRule.firstMatch(in:bundleID:title:)`. Unit-test it in ArborCoreTests.
- Add `rules: [AppRule]` at the end of `Settings`.
- `Controller.windowAppeared` calls `adopt(_:rescue:)`; route new windows
  through a new `Controller+Rules.swift` that applies the matching rule after
  adopting. `ignore` should make `filter.manages` false for that window id
  (keep a set of ignored window ids).
- "Most recently focused" needs a small focus history in the controller
  (window ids, most recent first); `windowFocused` is the place to record it.

## Acceptance criteria

1. A new Terminal window with rule `dock right` is docked at the right edge of the view.
2. Title matching picks the right rule; non-matching titles fall through to later rules.
3. `dock beside <app> <edge>` docks next to that app's window, and falls back
   to `dock <edge>` when the app has no docked window on that display.
4. `ignore` leaves the window untouched (never parked or moved) for its lifetime.
5. Windows present at launch and windows restored from state are unaffected by rules.
6. Bad rules are skipped with a logged reason; the other rules still apply.
7. An old `settings.json` without `rules` still loads.
8. `make check` passes.

## Shipped

- `ArborCore/AppRule.swift`: `AppRule`, `RuleAction` (parsed from and written
  as its text) and `AppRule.firstMatch(in:bundleID:title:)`. `Settings.rules`
  is read entry by entry; an entry that cannot be read is skipped and its reason
  ("entry 3 (com.apple.Notes): `action` is missing") goes to
  `Settings.skippedRules`, which is logged when settings.json is read and shown
  by `arborctl rules`.
- `Controller+Rules.swift`: `windowAppeared` adopts new windows through
  `adoptNewWindow`, which applies the first matching rule. `dock <edge>` docks at
  that edge of the camera on the window's display. `dock beside` uses a focus
  history recorded in `windowFocused` (cleared in `windowDestroyed`); docked
  windows of that app not focused since Arbor started count as least recent, so
  a window restored from state still works as a target. `ignore` adds the window
  to `WindowFilter.ignoredWindowIDs`, so every `filter.manages`/`isManaged`
  check fails for it until it closes.
- `rules` query command (also works before Accessibility is granted), and a
  `rule <bundle id> <action>` command in arbor-sim.
- Tests: `ArborCoreTests/AppRuleTests.swift` (parsing, matching, decoding,
  skipped entries, old settings files) and `ArborKitTests/RuleTests.swift`
  (one or more scenarios per acceptance criterion).

### Follow-ups (2026-10-14, QUESTIONS Q3 and Q4)

- **`ignore` for windows Arbor did not see open (Q4).** A window whose first matching rule is
  `ignore` is left alone wherever Arbor comes across it: at launch (before the saved arrangement
  is matched against the open windows, so it also leaves that arrangement), when its app is
  included again, and when the window system never announced it. So an ignored window stays
  ignored across a restart with nothing saved. The other actions still apply only to new
  windows. This changes criterion 5 for `ignore` only.
- **Late titles (Q3).** For `ruleTitleWait` seconds (default 2, at most 60, 0 turns it off) after
  a window opens, a change of title checks the rules that rank above the one that matched so
  far. A better match takes over, whatever the earlier rule did: it can dock, move, undock, ignore
  or stop ignoring the window. The result is what it would have been with the title there from
  the start: a window that has the focus is revealed if its slot is too small, and a late
  `float` or `ignore` puts the window back where its app opened it.
  - Nothing waits unless a rule for that app ranks above the match.
  - The time runs from when the window opened, not from its latest title.
  - What the user arranges is not undone: a drag, an edge resize or a command aimed at the window
    ends its wait; `arrange` and `float-all` end every wait. So do closing the window, a change
    of settings, and quitting.
  - Nothing is rearranged while the mouse is dragging or resizing a window, or for a window that takes
    no space (minimized, hidden, on another Space); the next title within the wait still counts.
- Tests: `ArborKitTests/RuleFollowUpTests.swift`. arbor-sim gained `title <id> <text>`; rules with a title
  are added there with F12's `rule add <bundle id> <action> title <text>`.

## Not shipped

- Real-window check: verified with unit tests, scenario tests and arbor-sim
  only; no Accessibility permission was available.
- An ignored window found off-screen at launch is not brought back, unlike other windows, **unless Arbor put it
  there**: some apps keep helper windows there on purpose, and `ignore` means leave alone. A window that
  Arbor itself moved out of view (in this run, or in the last one, which may not have quit cleanly) is brought
  into view before it is ignored, because afterwards nothing would ever fetch it, not even quitting. It comes back as it
  was before Arbor arranged it, if any arrangement remembers that. "Arbor put it there" means: Arbor has it down as
  out of view; or it sits exactly in the corner Arbor uses for a window of its size; or the last run arranged it and only a
  sliver of it shows. While it cannot be brought back (no display, an app that does not answer, full screen) it is not
  ignored. (Found by the chaos lab, rule `parked-unmanaged`, and by a review of the first fix.) The same goes for a window whose
  app was excluded by hand in settings.json between a crash and the next start: it is brought into view at that start.
- For a window that was already open, a rule with a `title` sees the title of that moment. A
  window ignored as "Trash" that is titled "Documents" when Arbor restarts is not ignored, and a docked
  browser window whose tab matches an `ignore` rule at that moment leaves the arrangement.
  Only rules without a title are exact across a restart.
- A window docked for a moment by a rule and then floated or ignored by a better one leaves its
  traces: floating windows it pushed stay pushed, and its row keeps the shares it had with it.
- Rules are applied once, when a window appears; changing them does not
  rearrange open windows. Windows Arbor first sees after a Space switch count
  as new (Spaces are F08).
- When Arbor rewrites settings.json (`exclude`, `include`), entries it could
  not read are dropped from the file, as unknown keys already are. F12's
  round-trip criterion covers keeping them.
