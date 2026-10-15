# F57: New windows while a window is framed

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: partly done (`feat/F57-guest-windows`: `"guest"` and `"float"`; `"tab"` waits for F04)
Depends on: F01, F04. Picks up where F31 (new windows join the arrangement) stops: F31 lets a new window float "when the camera is on a single window", which is the case below
Size: small

## Summary

Framed on Safari, press ⌘N. The new window floats over the framed one, which looks fine. Then the view moves (⌃⌥→) and the new window is gone, and **Back does not bring it back**: it is a floating window, floating windows live on the Desktop,
and the person may never have been to the Desktop. In arbor-sim: `arrange`, `zoom 101`, `open Slack`, `neighbor right`, `back`. It is the most likely way to lose a window in the first hour, and it needs no mistake.

## Behaviour

Setting `newWindowsWhileFramed`:

- `"tab"` (default once F04 has shipped): a new standard window that opens while the view is on a single window or tab group **joins it as a tab**, selected. It has a place at once, it is where the person was looking, ⌃⌥⇥ reaches its neighbours, and it can be torn
  off. It is what a browser does with ⌘T.
- `"guest"` (default until then): the window floats, and belongs to the space it opened over instead of the Desktop: it goes out of view and comes back **with that space**. Docking it, pinning it, or dragging it to another display ends that; moving it does not (a nudge must not change where a window belongs; agreed with the product owner, 2026-10-14).
- `"float"`: today's behaviour.

In every mode:

- Rules (F11) win over this setting.
- Windows that cannot take the slot's size (small utility windows, anything whose size is fixed) are never tabbed; they are guests.
- When the view shows the Desktop, nothing changes: new windows float, or auto-docking decides. Over **any view the Desktop is not part of** (a window, a group) a new window is a guest, in `"tab"` mode too; only a single window or tab group takes tabs. (Product owner, 2026-10-14: the guide's own ⌃⌥2 is a group, and the window was lost there just the same.)
- The first time, F43 says: "New window added as a tab. Drag the tab out to give it its own place."

## Design notes

- `Workspace.guests: [WindowID: NodeID]?`; `placeFloatingWindows` treats "its host is the camera, or inside it" as it treats "the Desktop is in view" for other floating windows. `Remap` must carry hosts along when nodes merge; a guest whose host is gone becomes an ordinary floating window.
- `adoptNewWindow` (Controller+Rules.swift) is where the decision belongs, after rules.

## Acceptance criteria

1. The arbor-sim sequence above, in `"guest"` mode: after `back` the new window is in view again, at the frame it had.
2. In `"tab"` mode it is docked in the framed window's tab group and selected.
3. A rule for the app overrides both.
4. A fixed-size window becomes a guest in `"tab"` mode.
5. Closing the host turns its guests into ordinary floating windows; invariants hold.

## Shipped

- Setting `newWindowsWhileFramed`: `"guest"` (default) and `"float"`. Any other value, `"tab"` included, means `"guest"` for now.
- `Workspace.guests` (optional, so old `state.json` files load; saved with the arrangement). A new window that no rule claims and that opens over a view the Desktop is not part of (a window, a tab group, a group)
  becomes a guest of that space (`Controller+Guests.swift`, called from `adoptNewWindow`). So does a window found at launch or after a pause: it opened while Arbor was not looking.
- A guest is in view whenever its host is: at the frame the user last gave it when the Desktop is out of view, on the Desktop like any floating window when that is in view. Otherwise it is out of view. The Desktop
  still shows every floating window, guests included.
- Switching to a guest that is out of view (⌘Tab) frames its host. So does `zoom <guest>`; the shortcut for framing, pressed with a guest focused over its framed host, leaves the framed view like a second press on the host.
- Coming back to a view, the window in it that was used last gets the focus (`ensureFocusIsVisible`, `zoom <host>`). Focusing raises, so a guest that was in front of its host is in front again.
- A guest that comes back into view keeps its place in macOS's order; it is not raised (QUESTIONS Q20 and Q25, 2026-10-15; until then it was). ⌘Tab to the host leaves the host in front, which is the window switched to, and the guest behind it where it was.
  The ways to it: a switch to it (⌘Tab, ⌘`, the Dock, Go to…), `focus` or `zoom` with its number, and ⌃⌥D, which shows all that floats (`RaisesNothingElseTests`).
- A group left with one member hands that member its guests, as it does its saved views.
- `state` says `guestOf`; an unknown value of the setting is named in the log and means `"guest"`.
- The visit ends when the guest is docked, pinned, closed or moved to another display, its host closes, or `arrange` or `float-all` runs. Moving it on its display does not end it; its new place is remembered. A host that is
  moved in the arrangement keeps its guests.
- Tests: `GuestWindowTests` (criteria 1, 3 and 5, and the rest of the above), `WorkspaceTests` for the model, scenario `25-a-new-window-while-framed.sim`.

## Not shipped

- `"tab"` mode (criteria 2 and 4): needs F04's tab strips.
- F43's first-time message.
- A click on the host while both are in view raises it over its guest, as macOS does with any two windows. Arbor does not keep guests in front.
- A window floated by command or dropped as floating over a view without the Desktop becomes a guest in F48 (#41).
