# Films: what a display shows, frame by frame

`arbor-sim film` plays a script against the real controller and writes down, sixty times a second, everything a display shows: where every
window is, what Arbor draws and how faint it is at that moment, where the pointer is, which keys are down. One line of JSON per frame.
No Mac, no permissions, no screen; the same script gives the same text every time.

It is for whoever wants to **see** or **judge** what Arbor does over time without a Mac:

- a painter turns the frames into pictures and a film (the demo film does);
- a judge reads them as numbers: does a window move once, does a stand-in end where its window is, how long is a motion, is a line on screen long enough to read?
- a comparison lays them beside what a real Mac recorded.

```bash
swift build --product arbor-sim
.build/debug/arbor-sim film script.txt --out frames.jsonl     # the story of the run is printed; --fps 30 for fewer frames
```

It exits with 1 if Arbor refused a line (unless `expect fail` follows it) or an `expect` did not hold: a film shows what Arbor does, so a script
that Arbor refuses makes no film.

## What is real and what is a stand-in

| | |
|---|---|
| Where windows go, what is docked, what is in view, focus, every model Arbor's views draw from, every timer | The real `Controller` and `ArborCore`, as in every scenario test |
| macOS and the apps | `FakeWindowSystem`: windows go where they are told, at once. What it has macOS or an app take its time over is filmed while it lasts. macOS's own tiling is **on, as a Mac comes**: its left, right and top edges are macOS's, which grows a window let go there to its tile as it was seen to on a Mac, and Arbor stands aside. A film of a drag to one of these edges says `mac-tiling off` first |
| The person | `FilmHands`: a pointer, a button and keys. A press on a title bar brings the window forward, moving on carries it along, in the order the Accessibility layer reports it |
| Fades, glides and the stage on which stand-ins travel | `OverlayPlayback` and `StagePlayback` (`Sources/ArborTesting/Film`): the rules and durations of the AppKit views, which do not build without AppKit, worked out for any moment. `StageTimingTests` holds the numbers against the views' own on a Mac. "Reduce motion" is taken to be off |
| Arbor's menu | The rows are `Controller.menuModel()`; where they sit is an estimate of what macOS does with them |

While they move, windows show their covers, as they do in the app as long as `windowPictures` is off; `set windowPictures true` in a script films them as pictures (`picture` 1, `cover` 0).

What a film cannot show is what only macOS knows: how long an app takes to obey, what the window server does to a frame, how a material looks, macOS's own preview of a tile, what
"click wallpaper to reveal desktop" makes of the same clicks.

## The script

Lines as in arbor-sim (`open`, `move`, `title`, `focus`, `expect`, every `arborctl` command…; not `transitions`, `watch` and `displays`: a film shows one display), `#` for
remarks, and the film's own. Lines that take time are filmed while they last; every other line happens between two frames. Time moves in whole frames: what a line's time
leaves over is carried to the next, so a film is as long as its lines say at any frame rate, but a moment in it can fall a frame earlier or later at another rate.

| Line | |
|---|---|
| `display <WxH> [bar <points>] [dock <points>]` | One display, with a menu bar and room kept for the Dock. This and the next three hold for the whole film: say them before the first frame |
| `app <Name> <#rrggbb>` | The colour Arbor takes from that app's icon: for covers, tiles and the minimap. `app <Name> icon <file>` has Arbor take it itself (`IconColour`) from the icon at 24 × 24 pixels: four bytes a pixel, red, green, blue, alpha, not multiplied by alpha; the path counts from the script's folder |
| `accent <#rrggbb>` | macOS's accent colour; its blue if nothing is said |
| `reserve <points>` | What the other items at the right of the menu bar take; Arbor's item is left of them |
| `launch`, `quit` | Arbor starts; Arbor quits as the app does. Windows opened before `launch` were there first |
| `wait <seconds>` | Time passes |
| `pointer <x> <y>` | The pointer is there, at once |
| `glide <x> <y>` | The pointer travels there as a hand moves it, carrying what it holds. Also `glide window <id> title`, `middle` or `<share of width> <share of height>`; `glide item [button]` (Arbor's menu bar item: `menu`, `everything`, `back`…); `glide menu <title>` (a row of the open menu). `in <seconds>` after any of them sets the time |
| `press`, `lift`, `click` | The mouse button, where the pointer is: on a title bar, a window, a tile, a gap, the minimap, a row of Go to…, Arbor's item, a row of its menu, the bare Desktop (which takes the keyboard from the windows). The story says what it landed on |
| `tap <shortcut> [for <seconds>]` | Down and up: `tap ctrl+opt+return`. While Go to… is open, `return`, `escape`, `up`, `down` and `tab` go to it |
| `keydown <shortcut>`, `keyup <shortcut>` | To hold one: a peek |
| `type <text> [each <seconds>]` | Into Go to…, a key at a time |
| `caption [text]`, `shot [text]`, `mark <name> [text]` | The film's own notes, of which Arbor knows nothing. They travel with every frame until they change |

## The frames

The first line holds what is true of the whole film:

```json
{"film":1,"fps":60,"display":{"frame":[0,0,1440,810],"visible":[0,24,1440,710]},"accent":"rgba(0,122,255,1.0)","windowRadius":17,"apps":{"Browser":"rgba(36,96,216,1.0)"}}
```

Every other line is a frame. Rectangles are `[x, y, width, height]` in global points, origin top-left, y down; colours are CSS colours; outlines are SVG paths (`Path2D` reads
them). A key is left out when there is nothing of the kind. From back to front, as macOS stacks them:

| Key | What | Follows |
|---|---|---|
| `n`, `t` | The frame's number and its time in seconds | |
| `backdrop` | The surface behind docked windows: one shape, or two while one fades into the other. `path`, `fill`, `opacity`, `desktopEdge` | `BackdropPanel` |
| `tiles` | `frame`, `opacity` and all of `TileArt`, in the tile's own coordinates | `TilePanel`, `TileDrawing` |
| `gapHandle` | The pill in the gap under the pointer, or being dragged | `SeamView` |
| `windows` | Every window that takes up room, **back to front**: `id`, `app`, `title`, `frame`, `focused`. Windows out of view are where Arbor put them | |
| `ring` | The focus ring, which lies directly above `window`: `line` and `flash` as bands (`frame`, `radius`, `thickness`, `innerRadius`), `flashOpacity`, `colour` | `FocusRingPanel` |
| `preview` | The drop preview: `frame`, `opacity` | `AppKitOverlays.showDropPreview` |
| `peek` | The outline of a peek | `PeekOutlinePanel` |
| `stage` | While windows move: `frame`, `opacity` (below 1 while it lifts), `surfaces`, and `standIns` back to front: `id`, `app`, `frame`, `opacity`, `cover`, `picture`, `colour`. It covers everything above, under the Dock and the menu bar. The real windows are at their final frames underneath from its first frame on | `Stage`, `StageDirector` |
| `nameField`, `minimap`, `shortcuts`, `headsUp`, `goTo` | Arbor's panels, above the stage. Inside `minimap` and `goTo` rectangles are measured from the panel's top-left corner | `NamePanel`, `MinimapPanel`, `CheatSheetPanel`, `HeadsUpPanel`, `FinderPanel` |
| `menuBar` | Arbor's item: `frame`, and a single `icon` or the `buttons` (`name`, `cell`, `chip`, `enabled`, `current`, `glyph`). A glyph is Arbor's `mark` as rectangles, a `digit`, or the name of a system `symbol` | `StatusMenu`, `ArborArtwork` |
| `menu` | Its menu while it is open: `frame` and `rows` (`kind`, `title`, `shortcut`, `enabled`, `ticked`, `highlighted`) | `StatusMenu` |
| `pointer` | `at`, `down` | |
| `keys` | What is held: `modifiers`, `key`, `label` | |
| `marks` | The film's own notes | |

Window titles are in a film. They are the simulator's: a film never holds anything of a person's Mac.
