# F42: Setup check

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: mostly done with F10 (`feat/F10-menu-bar`: `doctor`, `SystemFacts`, `MacSwitch`, `CompetingApp`, `Controller+Doctor.swift`, the first page of the welcome window), including the wallpaper click, Stage Manager, Moom,
BetterSnapTool, Loop, Swish and the paused state; and with `feat/F42-setup-check-rest`: F41's apps (a note in `doctor`, a row in the welcome window), the keyboard layout and the shortcuts it moves, a process named `yabai`, the worst first, and
a line in the log at launch for every problem. With `guardDesktopClicks` on (F60) the wallpaper click is a note. **Left**: symbolic hot key 61 (K126, being built as `SystemShortcuts`; its `systemShortcutClashes` replaces the count of input sources), an unreadable
`settings.json` (comes with F12's `settingsFileProblem`), "Turn it off for me", `--json`
Depends on: F10 (shows it), F06
Size: small, for what is left

## Summary

Most of what will go wrong in someone's first week is not a bug in Arbor but something else on the Mac wanting the same keys, the same screen edges or the
same windows. All of it can be detected. Today the README mentions one switch. Arbor should look, say what it found in plain words, and link to the fix.

## Behaviour

`arborctl doctor`, a page in onboarding (F10), and **Check Setup…** in the menu show the same list. Each finding has a severity (problem, advice, fine), one
sentence, and what to do. Nothing is changed without being asked; where a switch is a plain default (the four `com.apple.WindowManager` ones) the finding may carry a button, "Turn it off for me", next to the link.

| Check | How (macOS layer) | Says |
|---|---|---|
| Accessibility | `AXIsProcessTrusted()` | problem: Arbor cannot move windows. If the switch is already on, turn it off and on again (a new build has a new signature) |
| Screen Recording | `CGPreflightScreenCaptureAccess()` | advice: moving windows show colour and icon instead of their contents |
| macOS tiling | `UserDefaults(suiteName: "com.apple.WindowManager")`: `EnableTilingByEdgeDrag`, `EnableTopTilingByEdgeDrag`, `EnableTilingOptionAccelerator`; absent means on; macOS 15+ | problem: dragging to an edge triggers both. Desktop & Dock → Windows, turn off the three "tile" switches |
| **Click wallpaper to reveal desktop** | same domain, `EnableStandardClickToShowDesktop`; absent means on; macOS 14+. **Seen on macOS 26.6** (`collab/evidence/screens/2026-10-14-review-ux-3-wallpaper-click.png`): one click in the middle of Arbor's Desktop swept all three docked windows to the screen edges (2 to 4% left in view); Accessibility reported nothing, so Arbor still believed them in their slots; a second click brought them back | problem: a click on the Desktop or in a gap sends every window away, and double-click (F14), ⇧-drag (F05) and pinch on the Desktop all start with such a click. Desktop & Dock → "Click wallpaper to reveal desktop" → Only in Stage Manager |
| Stage Manager | same domain, `GloballyEnabled` | problem: it moves windows itself; use one or the other |
| Another window manager running | `NSWorkspace.runningApplications`: Rectangle, Rectangle Pro, Magnet, Amethyst, AeroSpace, Moom, BetterSnapTool, Loop, Swish, TrellisWM; a process named `yabai` | problem: same keys, same windows. Quit it or turn off its shortcuts |
| VoiceOver | `NSWorkspace.shared.isVoiceOverEnabled` | problem: ⌃⌥ is VoiceOver's modifier. Use Caps Lock for VoiceOver (VoiceOver Utility → General), or turn Arbor's shortcuts off |
| ⌃⌥Space taken by input sources | more than one enabled input source, and symbolic hot key 61 enabled in `com.apple.symbolichotkeys` | advice: macOS uses ⌃⌥Space to switch keyboards; ⌃⌥0 shows everything too |
| Shortcuts that failed to register | `HotKeyCenter.register`'s result, held against what Arbor wants to hold now (`KeysHeld`) | problem: lists them; also in Check Setup, at the end of their lines in `bindings`, and in the log with macOS's answer. A hosted Mac (macOS 26) never refused one, whoever else held the key: a second holder cannot be seen this way |
| Apps that need ⌃⌥ | running apps against F41's list | advice: Shortcuts Off in "App" |
| Keyboard layout | built as F44: not needed any more, except that `bindings`' collisions on the layout in use belong in the report | `Controller.effectiveBindings.problems` |
| Skipped `bindings` and `rules`, unreadable `settings.json` | what `bindings` and `rules` already report | problem: which and why |

## Design notes

- Pure and testable: `SetupFacts` (a struct of plain values the macOS layer fills in) → `SetupCheck.findings(_:) -> [Finding]` in ArborCore. The macOS layer only reads.
- `doctor` is a query; its text form is one line per finding, worst first, `✘`, `!`, `✔`; `--json` gives the list.
- The bundle ids and defaults keys above are from memory of current versions. **Check each on a Mac** before relying on it, and treat an unreadable value as "unknown", never as a problem. On a fresh macOS 26.6 all five
  `com.apple.WindowManager` keys are absent (`collab/evidence/2026-10-14-review-ux-mac.txt`), and the wallpaper click was active, so for that one at least "absent means on" holds.

## Acceptance criteria

1. Unit tests: each fact alone produces its finding; a clean Mac produces only ✔ lines; unknown values produce nothing.
2. `doctor` works before Accessibility is granted.
3. (was "Manual"; board, section 5) On a hosted Mac: each switch is written by script and **seen to act** (a drag to the top fills the display, or no longer does); the finding changes without restarting Arbor. On the versions of macOS that hosted runners offer; the notes name them.
