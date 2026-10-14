# F04: Tab strips for stacks

Status: ready
Depends on: F01

## Summary

Stacks (several windows sharing one slot, from any apps) already exist in the
model, and dropping a window on the middle of another stacks them when
`tabsEnabled` is on. What is missing is the tab strip that shows them.

## Behaviour

- A stack with two or more windows shows a strip of tabs across the top of its
  slot (28 points high); the active window sits below the strip.
- Each tab shows the app icon and window title; the active tab is highlighted.
  Tabs share the strip's width equally. (TrellisWM's demo, T12:
  equal-width tabs, a small dot before each title, the selected tab a lighter
  chip, and the window keeps its own title bar below the strip.)
- Dragging the active window's title bar moves the whole group, strip
  included, and dropping it docks or floats the stack as one (how-it-works
  move 2 drags a whole group to an edge). If a branch is already in review
  without this, merge it and do this as a follow-up.
- Clicking a tab activates that window. Dragging a tab out of the strip and
  releasing it elsewhere undocks that window (it floats where released, or
  docks if released over a drop target). A close button on hover closes the window (AXCloseButton press).
- Commands: `tab next`, `tab previous`, `tab <window>`; default keys ⌃⌥Tab / ⌃⌥⇧Tab.
- `tabsEnabled` defaults to true once the strip exists.

## Design notes

- `LayoutOptions.tabStripHeight`: when a stack has more than one present window, its
  window frame is the slot minus the strip; the layout reports the strip
  frame and its tabs (`Layout.tabStrips`).
- `OverlayPresenter.update` gains the strips; `FakeOverlays` records them and
  can click a tab. New `Sources/ArborKit/UI/TabStripPanel.swift`.
- Titles are shown in the UI but never logged.

## Acceptance criteria

1. Layout: a stack of two reserves the strip and reports it; a stack of one does not.
2. Scenario: dropping on the middle of a window stacks them; the strip appears; clicking a tab switches the visible window and parks the other.
3. Tearing a tab off floats it; the stack of one loses its strip.
4. `tab next/previous` cycle; focusing an inactive tab (⌘`) activates it (exists; keep it working).
5. `make check` passes.
