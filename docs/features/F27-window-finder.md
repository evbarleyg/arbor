# F27: Go to… (the window finder)

Written by the executor swarm, 2026-10-14; for the documenter to review.

Status: done (`feat/A-window-finder`); a Mac has compiled it and shown the palette on real windows, no real key has been pressed in it yet: see "Not shipped"
Depends on: F01, F06, F08, F56
Reference items: none (TrellisWM has nothing like it); parity A27

## Summary

In Arbor most windows are out of view most of the time. That is the point of it, and it makes "where is that window?" the question a
user asks most often. The answer has to cost one shortcut and a few letters: press ⌃⌥G, type `inb`, press Return, and the view moves to
Mail's Inbox, whatever kept it out of view. The same palette goes to named spaces (F20) and saved views: one picker
for everywhere the view can go (docs/KEYBOARD.md).

## Behaviour

### The palette

- ⌃⌥G, "Go to…" in the menu, or `find` opens the palette on the display commands act on (F56: the one being typed on, for a shortcut), a quarter of the way
  down, about 600 points wide. It takes the keyboard without making Arbor the active app, so the app the user was in stays active behind it.
- It lists **every window Arbor arranges, on every display**, then the windows it was told to leave alone (Don't Arrange, `ignore` rules), then **every named space** and **every saved view**, up to nine rows at a time:
  the app's icon, the app's name, the window's title, and at the right a short note on where the window is:
  `in view`, `out of view`, `tile`, `tab`, `floating`, `floating, out of view`, `kept in view` (pinned), `summoned`, `out of view until summoned`, `minimised`, `hidden` (⌘H), `full screen`, `on another macOS Space`, `not arranged`; with several
  displays also `, on Studio Display` (a display without a name is `display 2`; two of the same make are `DELL U2720Q (1)` and `(2)`).
- A saved view's row shows its number where a window has its icon, "View 3", the apps it holds ("Safari, the Desktop, Notes") and the note `saved view`.
- A named space's row shows the first letter of its name where a window has its icon, the name, the apps it holds and the note `space`. A name that two displays have is listed for both, which `go <name>` cannot do.
- **Order with nothing typed**: windows that have had the keyboard, the latest first, but the focused window after them; then the windows that never had
  it, as they are laid out; then the named spaces, in the order `go` looks in; then the saved views. So Return straight after ⌃⌥G goes to the window the user was in before, as ⌘Tab does, and doing
  it again comes back. The focused window is never first, also right after launch, when no other window has had the keyboard yet.
- **Typing filters and ranks** (below). The best match is selected, if it is a place (see "It finds commands too"). Matched letters are set off.
- ↓ and ⇥ select the next row, ↑ and ⇧⇥ the previous one, going round at the ends; Page Up and Page Down move by a palette's length and stop
  at the ends; the list scrolls just far enough. Return chooses the selected row, ⌘1–⌘9 and a click choose a row directly. Moving the
  pointer over the rows changes nothing. ⌘A, ⌘X, ⌘C and ⌘V work in the field.
- **Not for an audience**: the palette lists titles, so it keeps out of shared screens and recordings, as the minimap does and as far as macOS honours it (`sharingType`).
- **The palette always closes**: when a row is chosen, on Escape, on ⌃⌥G again, when the keyboard goes to another window (a click elsewhere, ⌘Tab, a window that
  opens), on a click on a tile or a gap handle, when any other command runs (a shortcut, ⌃⌥Space held or tapped among them, the menu, a script, also one that opens a window of Arbor's own or changes a setting; queries excepted), when a window is dragged, an app
  comes forward, the macOS Space changes, the displays change or sleep, on `pause` and on quit. If macOS does not let it have the keyboard (a password field has
  it), the next key typed closes it. Closing it changes nothing: no window moves and the app behind it has the keyboard again.
- It does not open while a window is being dragged.
- The list is a **snapshot** from the moment the palette opened. Nothing is added, removed or reordered under the user's hands. If what they
  choose has gone meanwhile (the window closed), the palette beeps, says "That window has closed", and stays open with a fresh list and the text as typed.
- With no windows at all, `find` fails ("there are no windows to go to") instead of opening an empty palette.

### Matching (`FinderQuery`)

- The text is split at spaces into words. Every word must match, in any order.
- A word matches when its letters appear, in order but not necessarily together, in "app title" (for a view: "View 3 Safari, Notes").
- Case and accents are ignored both ways: `saf`, `SAF` and `säf` find Safari, `cafe` finds Café. So are skin tones and other emoji variations, invisible
  characters, and the difference between typographers' and typewriter quotes and dashes. ß is ss, æ ae, œ oe, ø o, ł l, đ and ð d, þ th, ı i. An unfinished
  Korean syllable finds the finished one.
- Of all the ways to lay a word over a row the best counts: letters at the start of a word are worth more (also after a capital inside a word, and where
  digits meet letters), most of all for the word's first letter; letters that follow each other are worth more; letters skipped between two
  matches cost a little; letters in the app's name are worth more than letters in the title.
- **The name of a space typed in full comes before everything else**, whatever apps and titles are called the same, so that `go-to Writing` and `go Writing` end in the same place. Short of the whole name it is a match like any other.
- Equally good matches: the one with less left over first (`mail`: Mail before Mailplane), counting only the texts that matched, so three Safari windows
  are equal for `saf` whatever their titles. Still equal: the order of the list, so the most recently used first and the focused window last.
- Work is bounded: 80 characters of a name, 200 of a title, 8 words and 64 letters of a query. The rest is ignored. Titles are also shown cut to 200
  characters, with a space for every line break.

### Going there

Choosing a **window**, and `reveal [window]`:

1. its app is unhidden if it was hidden, and the window brought back from the Dock if it was minimised;
2. its tab is shown if another tab of its group was showing;
3. the view moves as it does after ⌘Tab. From one framed window, tab group or the Desktop, the level is kept: the chosen window is framed, or the
   Desktop if it floats. From a group or everything, the view zooms out just far enough to include it, or frames it if it would be too small to show
   at that level; for a floating window, out to where the Desktop shows, or onto the Desktop if that would be a tile there;
4. it gets the keyboard.

- A window already in view is only focused: nothing moves.
- A window on another macOS Space, or in full screen, is only focused, which makes macOS switch Spaces; the view follows when its Space shows. Moving it
  earlier would rearrange the Space the user is leaving.
- A window on another display is revealed there; the other displays stay as they are and **the pointer is not moved**. From then on shortcuts act on
  the display gone to, because they follow the keyboard (F56).
- A pinned window (F49) is in view already: it is only focused. A window that was summoned and sent away (F53) is summoned again, at once and where it was the last time; the view stays, and
  when it is sent away again the keyboard goes back to where it was.
- A window Arbor leaves alone is brought back from the Dock or from ⌘H and focused, where it is: neither the view nor the window moves.
- While a window is being dragged, `reveal` fails ("a window is being dragged; drop it first").
- While the view is held (F58): `hold` refuses `find` and `reveal`, closes an open palette and greys the menu item. `hold still`, which a call starts by itself, lets them through: they
  are the person's own asking, the one window chosen comes into view and the hold stays in force. ✔ `whileHoldingStillTheViewStillGoesWhereItIsAsked`,
  `whileHoldingStillAWindowComesBackFromTheDockIntoView`, `whileHoldingStillAWindowThatWasSentAwayIsSummoned`. Not yet: a window on another macOS Space.

Choosing a **saved view** moves the view of its own display there, as `view <n>` does for the display under the pointer.

### It finds commands too (board 0.14)

With nine keys bound (QUESTIONS Q29, 1) everything else is "in the menu and in Go to…". Whoever knows what a thing is called types a few letters of it and picks it: ⌃⌥G `bal` ↓ ↩ balances the sizes.

**Letters and Return do what they did before commands were listed: they go to the best place, or beep.** ⌃⌥G, a few letters, Return, without a look, is what Go to… is for, and the fingers do it also when the app they mean is not open, or has
just closed behind the palette. Three rules see to it, for every command alike; there is no list of commands too weighty for a reflex.

1. **The list is what it was, with the commands after it.** The places that match come first, in the order they always had, however they were found; then the commands. So the row that is selected and the rows ⌘1–⌘9 point at are the same as before, as far as there
   are places. **Only ↓ or ⇥ past the last place leads on to the commands.** ↑ and ⇧⇥ from the top go round to the last place, and Page Down stops there however often it is pressed, as ever: `pa` ↑ ↩ is the last of Pages' windows, not Pause Arbor below it. Coming
   up out of the commands, ↑ stays among the places likewise. The price: a place that holds the letters here and there stands above a command that was spelt out (`undo`: TextEdit's Untitled Document). Typing on sends it away.
2. **A command has to be named to be listed.** Every word typed is the beginning of a word of its way through the menu, letters together: `bal`, `siz`, `dock left`, `dont arr` (the apostrophe need not be typed, and a word of nothing but signs, like the ▸
   of a name that was copied, asks for nothing). Nothing scattered, nothing from inside a word, no initials: that is how a title is found, of which nobody knows the words; a command's are in the menu to be read. **And by a word of its own**: Don’t Arrange
   “Safari” is about Safari and is not called Safari. What stands between quotation marks narrows (`dont saf`) and lists nothing by itself. Every word counts, also beyond the eight that a place is found by.
3. **Return alone never runs a command.** Where no place matches, the command on top is shown, not selected, and the line under the rows says "↓ picks a command, ↩ runs it"; Return beeps. Picked by hand it runs: ↓, ↑, ⇥, a Page key, then Return; a click; ⌘ and
   the row's digit. ↓ and the Page keys pick the first row, ↑ the last. Whatever is typed afterwards unpicks, and so does a fresh list in which the picked row is no more; where a place is left, such a list selects a place.

Found on the way to the second build. Over "Focused Window ▸ Don’t Arrange “Safari”" the letters of `notes` are scattered: `notes`, Notes closes behind the palette, Return ("That window has closed"), Return again: Safari
was out of the arrangement, and settings.json said so. By thinking on from there: `pa` ↩ for Pages paused Arbor, `ar` ↩ for Arc arranged everything, `sa` ↩ for Safari saved view 1, `shortcuts` ↩ for the app of that name switched Arbor's shortcuts off in the
app in front, which is a whole first word: no rule about how much to type closes it. And by a reader who was asked what Return can still run: in Safari's one window `saf` ↓ ↩, for the next of its windows, took Safari out of the arrangement, since the rows about
the app in front hold its name; and by a second reader: `pa` ↑ ↩ with two windows of Pages, counted rightly, paused Arbor, and `sa` Page Down ↩ saved view 8.

**What is left.** ↓, ⇥ or a digit that counts on a place that is not there comes to a command, if one begins with the same letters: `pa` ↓ ↩ or `pa` ⌘2, for the second of Pages' windows when there is one, pauses Arbor. It takes a wrong count; a shared beginning is
common (`sa`, `ar`, `ke`, `re`, `st`, `ho` all begin a command's word). Nothing short of a key of their own for the commands closes that, since ↓, ⇥ and the digits mean places already: a question for the product owner (QUESTIONS).

- **The rows are the menu's**, read from the menu as it stands when the palette opens (`Controller+FinderCommands.swift`): every row that runs a command, under the name the menu gives it then
  ("Undo Dock", "Don’t Arrange “Safari”"), with the key in effect and the tick the menu shows. A row added to the menu is found here without another line. A row of a submenu is called by its way
  there: "Dock Focused Window ▸ Left", "Saved Views ▸ Save This View As ▸ View 3", so `left`, `dock left` and `save 3` all find theirs, and the row says where in the menu it is. A command the menu has under two names
  (holding still: Release, and the tick on Hold Still) is found by either.
- Then the commands that have a key in the whole map and no row in the menu (Space to the Left, Window Above, Show Everything on All Displays), under their titles in the panel of shortcuts.
- Not listed: Go to… itself; the rows that lead to a window, a saved view or a named space, which are listed as the places they are; and what only the app can do and is no command (Settings File…, Show Log, About Arbor, Quit Arbor).
- **The rows are about the display the palette is on**, when they are read and when one is run. The menu is about the display under the pointer, which chose it; here the pointer may rest anywhere. "Undo Dock" undoes that display's Dock, and
  "View 3 (replace)" says so of that display's view 3.
- **With nothing typed the list is what it always was**: places. A command comes when it is called by name. The empty field says "A window, a space, a saved view or a command".
- **Among themselves** the commands whose name begins with a word that was typed come first (`dock`: Dock Focused Window ▸ Left before Undo Dock), then the menu's order decides, which has the ways back and what is used most first (`float`: Float Focused Window
  before Float All Windows).
- Under Arrange Again a row of the menu is an app's name and nothing else. Here it is marked as the menu marks a name in the midst of a title: "Arrangement ▸ Arrange Again ▸ “Calendar”".
- A command's row shows ⌘ where a window has its icon, and at the right `command`, with ✓ if the menu ticks it, and its key if it has one: `command ✓, ⌃⌥Space`.
- **Picked and chosen, it runs as its key would**: the palette closes, the app behind it has the keyboard again, and the command acts on the window the palette opened over. It is answered on screen as a key is (F43). One undo takes it back.
- **What the menu greys out is listed, so that it is found where it is looked for, and says `command, not now`. Chosen, it runs nothing**: the palette beeps, says "“View ▸ Step Out” can do nothing just now" and stays. The menu greys a row out because it would
  fail, or because it would do something else than it says: Float Focused Window is `toggle-float`, which would dock a window that floats. Whether a row can act is asked when it is chosen, not when the palette opened.
- **Only in the palette.** `find <text>`, which goes somewhere without showing anything, finds places and nothing else: a script, a binding or (where all links are allowed) a link that says `find` names a place, and must not thereby
  run whatever it spells.
- With no windows at all `find` still fails: for what remains then there is the menu. While the view is held there is no palette.
- With `messageLevel` off a key that fails beeps, which is the app's doing; a command from the palette that fails after all is silent.
- A trace holds the choice as `{"command":"dock left"}`, the log its first word. No row's command holds a name somebody gave.

✔ `everyCommandInTheMenuIsFoundByItsNameInTheMenu`, `aCommandTheMenuHasUnderTwoNamesIsFoundByEither`, `everyCommandThatHasAKeyInTheWholeMapIsFoundWhetherOrNotTheMenuHasIt`, `withAllShortcutsOffEveryCommandIsStillFound`,
`itRunsOnTheWindowThePaletteOpenedOver`, `lettersAndReturnMeantForAnAppThatIsNotOpenRunNothing`, `notesClosesBehindThePaletteAndReturnIsPressedTwice`, `afterAPlaceHasGoneASecondReturnRunsNothing`, `theNameOfTheAppInFrontAndTheArrowStayAmongThePlaces`, `theArrowUpAndPageDownStayAmongThePlaces`, `pickedWithTheArrowItRuns`, `theRowsAreAboutTheDisplayThePaletteIsOnWhereverThePointerRests`, `andTheCommandActsThere`, `chosenItRunsNothingAndThePaletteSaysSoAndStays`, `aRowNeverDoesTheOppositeOfWhatItSays`,
`findWithTextGoesToPlacesAndRunsNothing`, `aLinkThatSaysFindRunsNothingEvenWhereAllLinksAreAllowed`, `aTraceHoldsTheChoiceAndReplaysIt`, `aCommandThatChangesASettingReplaysToTheSameSetting` (`GoToFindsCommandsTests`);
`theListIsWhatItWasWithTheCommandsAfterIt`, `amongManyPlacesTheListScrollsAsItDid`, `onlyTheArrowDownPastTheLastPlaceLeadsToTheCommands`, `lettersScatteredOverACommandsNameDoNotListIt`, `aCommandIsListedOnlyWhenEveryWordTypedBeginsAWordOfItsName`, `anAppsNameInACommandsNameSaysWhomItIsAboutAndDoesNotListIt`,
`ofACommandEveryWordCountsHoweverManyAreTyped`, `returnAloneNeverChoosesACommand`, `pickedByHandItIsChosen`, `aFreshListUnpicksUnlessThePickedRowIsStillThere`, `aPickDoesNotPassToTheCommandThatTookThePlacesRow`,
`whereAPlaceIsLeftAFreshListSelectsAPlace` (`FinderCommandRowTests`); scenario 94.
Not yet: no key has been pressed in it on a Mac, and nobody has looked at a row (`scripts/mac-shell/shots-finder.sh` takes the picture).

### Commands

| Command | Does |
|---|---|
| `find` (also `go-to`) | Opens the palette; closes it if it is open |
| `find <text…>` | Goes straight to the best match, without the palette: `arborctl find safari docs`. Fails with "no window, space or saved view matches “…”" |
| `reveal [window]` | Brings one window (default: the focused one) into view and focuses it |

The list itself is printed by F50's `windows`. This feature had a `windows` of its own; the product owner took it out before it could land: one command, one vocabulary.

`arbor://` URLs may run neither (product owner). The palette would take the keyboard from whatever the user is typing; and a link that un-minimises, unhides and focuses a window picked by words
in its title, perhaps in the middle of a shared screen, is more than moving the view and arranging. Launchers have `arborctl`. With `allowAllURLCommands` they work: `arbor://find/safari/docs`.

### Privacy

Titles are shown and never logged. What the user types to find a title is part of one, so `find` is logged without its text ("find: w103: w103 is in view and
focused"), a space's name is replaced in it as everywhere in the log (F20), and the reply that quotes it ("no window … matches “…”") goes to the caller only. Whoever else logs a command uses `Command.textForLog`.

## Design notes

- Pure, in ArborCore, shared by the palette and the tests' stand-in: `FinderQuery` (matching), `FinderSelection` (clamping, going round, scrolling, places to rows),
  `FinderSession` (list + text + matches + selection), `FinderLayout` (where the palette and its parts go on any display), `FinderModel` (rows, destinations, places).
- **Folding** does not use Foundation's `folding(options:locale:)`, which answers differently on macOS and Linux (ß, ﬁ…). It uses canonical decomposition, which
  Unicode defines, then the standard library's character properties, then a table of a dozen letters. `FinderFoldingTests` pins what is relied on.
- **The best alignment** is found with a table of word × text, filled in one pass per row because a gap's cost grows evenly. A test compares it with trying
  every alignment on thousands of random small cases.
- `Controller+Finder.swift` makes the list and goes there. `reveal` reuses `bringIntoView`, which the focus reports use too and which already shows tabs and moves the camera, so tab groups (F04) need nothing extra.
- Seams: `OverlayPresenter.showFinder(_:)`, `OverlayActions.finderChose(_:)` and `finderDismissed()`; `WindowSystem.setMinimized(_:_:)` and `unhideApp(pid:)`; `DisplaySnapshot.name`.
- **macOS reports late and in any order.** Un-minimising and unhiding are confirmed a moment after the request, and the focus report can come first. The command does not wait: for it alone (`onItsWayBack`)
  `reveal(_:leaf:on:)` picks the view as if the window were back already, and the window takes its place when macOS says so. The reports, which move the camera only for a window that is present and has the keyboard
  (Controller+Focus.swift), then find it in view. `FakeWindowSystem.restoresLate` plays that order in tests.
- **Space switches.** Switching Spaces brings an app forward, before or after Arbor has learnt which windows show now. `AXWindowSystem.reportFocus` leaves out a window still taken to be on another Space, and every rescan after
  a switch reports the front app's focused window again, so the report comes when the window counts as present, however long the transition takes. In the controller, the review's `runPostponedRelayouts` lays out before a
  report is judged; what this feature once added for that (`layOutIfNewlyPresent`) has been taken out again. Its tests stay.
- **Closing** is decided twice, on purpose. The panel knows first (`resignKey`, event monitors, workspace notifications); the controller knows for certain, and in tests (`closeFinderBecauseTheUserLeft`,
  `closeFinder(before:)`). A palette left floating over everything, deaf, is the one failure this feature must not have.
- `UI/FinderPanel.swift`: a borderless non-activating `NSPanel` that can become key, an `NSVisualEffectView`, one custom view that draws everything, and an `NSTextField`. No decisions in it.
- Named spaces: rows come from F20's `namedSpaces()`; `FinderCandidate.isAName` is what lets the whole name win.

## Acceptance criteria

1. The list is most recently focused first, the focused window after the others that had the keyboard; Return on an empty query alternates between two windows. ✔ `theListIsMostRecentlyFocusedFirstWithTheFocusedWindowAfterTheOthers`, `returnOnAnEmptyQueryGoesBackAndForthBetweenTwoWindows`, `theFocusedWindowIsNeverFirst`
2. Choosing a window out of view focuses it, closes the palette, and `back` returns; from a group the camera moves just far enough, from a framed window the chosen one is framed. ✔ `fromAGroupChoosingAWindowOutOfViewMovesTheCameraJustFarEnoughAndFocusesIt`, `fromAFramedWindowChoosingAWindowFramesTheChosenOne`, `returnAtOnceHopsBetweenTwoFramedWindows`, `fromAFramedWindowAFloatingWindowFramesTheDesktop`
3. A window in view is only focused; revealing twice is the same as once; the echo of the focus changes nothing. ✔ `choosingAWindowInViewOnlyFocusesIt`, `revealingTwiceIsTheSameAsOnce`, `theEchoOfTheFocusChangesNothing`
4. A hidden tab is shown, in view or out of it. ✔ `choosingAHiddenTabShowsIt`, `aHiddenTabOfAGroupOutOfViewIsShownAndBroughtIntoView`
5. Minimised windows and windows of hidden apps come back to their places, whichever order macOS reports in. ✔ `aMinimizedWindowIsRestoredAndBroughtIntoView`, `aWindowOfAHiddenAppComesBackWithItsApp`, `theResultDoesNotDependOnWhenMacOSReports`
6. Tiles are framed; floating windows bring the Desktop back, even where it would be a tile. ✔ `aTileIsFramed`, `fromAGroupAFloatingWindowOutOfViewBringsTheDesktopBack`, `aFloatingWindowIsShownEvenWhenTheDesktopIsTooSmallToShow`
7. A window on another macOS Space is only focused; a trip to another Space and back leaves the camera where it was. ✔ `aWindowOnAnotherSpaceIsOnlyFocusedAndTheCameraFollowsWhenItsSpaceShows`, `aTripToAnotherSpaceAndBackLeavesTheCameraWhereItWas`
8. A window on the second display is revealed there, this display and the pointer stay, and shortcuts follow. ✔ `aWindowOnTheOtherDisplayIsRevealedThereAndThisDisplayStaysAsItIs`, `shortcutsFollowToTheDisplayThePickerWentTo`
9. What was chosen has gone: a beep, a notice, a fresh list, the text kept. ✔ `choosingAWindowThatHasClosedSaysSoAndKeepsThePaletteOpenWithAFreshList`, `aSavedViewThatHasGoneSaysSo`
10. Saved views are listed with the apps they hold, found by number and by app, and recalled on their own display. ✔ `savedViewsAreListedAfterTheWindowsWithTheAppsTheyShow`, `choosingASavedViewMovesTheCameraThere`, `savedViewsOfEveryDisplayAreListedAndRecalledOnTheirOwn`
11. `find <text>` goes to the best match; with no match it fails, says so and changes nothing. ✔ `findWithTextGoesStraightToTheBestMatch`, `findWithNoMatchFailsAndSaysSo`
12. The palette always closes, and changes nothing by closing. ✔ `everyShortcutClosesIt`, `escapeClosesItAndChangesNothing`, `findAgainClosesThePalette`, `pausingClosesItAndItStaysShutUntilArborResumes`, `shutdownClosesIt`, `itClosesWhenAnotherWindowTakesTheKeyboard`,
    `aLateReportFromTheWindowItOpenedOverLeavesItOpen`, `anyOtherCommandClosesIt`, `queriesLeaveItOpen`, `itClosesWhenAWindowIsDragged`, `itDoesNotOpenWhileAWindowIsDragged`, `aDisplayThatGoesAwayClosesThePalette`, `findWithTextClosesAnOpenPalette`
13. Neither titles nor queries reach the log. ✔ `neitherTitlesNorQueriesAreLogged`, `theLogNeverSeesWhatWasLookedFor`
14. Matching: order, words, case, accents, scripts, emoji, ranges, ties, limits, hostile input, the same on macOS and Linux. ✔ `FinderQueryTests`, `FinderFoldingTests`
15. Selection and geometry: clamping, going round, pages, any display. ✔ `FinderSelectionTests`, `FinderSessionTests`, `FinderLayoutTests`
16. `make check`, `make scenarios` and `make parity` pass. ✔

## Shipped

Everything above, with 147 tests, `collab/scenarios/27-go-to.sim`, in arbor-sim `find`, `finder-type`, `finder-move`, `finder-choose [n]` and `finder-cancel`, and in `arbor-e2e` nine steps on real windows (`GoTo.swift`).

On a Mac: it compiles, all tests pass, and `arbor-e2e` has seen the palette come and go, a window found by its title, and a window brought back from the Dock
to its slot with the keyboard.

## Not shipped

- **No real key has been pressed in the palette.** `arbor-e2e` posts no input, so that it can run on a Mac somebody is using. It sees the palette come, AppKit and Accessibility say who has the keyboard, and the palette go.
  `scripts/mac-shell/shots-finder.sh` types with real key events, clicks, presses ⌘Tab, opens Mission Control and swipes Spaces (the last two on throwaway Macs only), takes pictures and checks the state; it has never run
  on a Mac. **Nobody has looked at a picture of the palette.**
- Presets (F21) would be a fourth kind of row.
- The list does not follow changes while the palette is open, by design.
- No VoiceOver support in the palette: the rows are drawn, not accessibility elements.
- Dialogs, panels and the windows of apps without a Dock icon are not listed: Arbor does not hear of them.
- **While one window is framed, choosing another steps out to the group that holds both.** Decided otherwise by the product owner: it should frame the chosen one. That is ⌘Tab's rule too, so it changes in `reveal(_:leaf:on:)`, for both, by its owner.
- "Go to…" chosen from the menu bar: whether the palette keeps the keyboard when the menu's tracking ends has to be tried on a Mac (view review).
- A click on an input method's candidate while composing is let through; not tried.
- Recency is not saved: after a relaunch the list starts in layout order.
