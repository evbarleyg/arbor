# The shortcuts in the menu bars of the apps on a hosted Mac

What `scripts/mac-shell/census-menu-keys.sh` brought back (three runs on 2026-10-15, macOS 26.6.2, GitHub's Macs), one file per app, named by its bundle id. **Every distinct shortcut that was ever read in
that app's menu bar**, once: a menu bar differs a little from one launch to the next, and a shortcut seen once is one the app has. Three fields divided by tabs, as Accessibility gives them:

1. `AXMenuItemCmdModifiers`: 1 ⇧, 2 ⌥, 4 ⌃, 8 **no** ⌘, 16 fn (the Globe key; in no header);
2. `AXMenuItemCmdChar` as hexadecimal scalars, or `-`;
3. `AXMenuItemCmdVirtualKey`, or `-`.

No titles: they are not needed to find a clash, and on anybody's own Mac they can hold that person's words. The app reads no other app's menu bar at all; the script prints titles on GitHub's Macs only, where every title is the app's
own, and `docs/KEYBOARD.md`'s column "What it is there" is written from those.

`Sources/ArborTesting/MenuShortcut.swift` says what the numbers mean, `MenuKeyCensusTests` holds Arbor's map against every file here, and `docs/KEYBOARD.md` has the tables, with what was not read and why.

The added apps as the package manager gave them, which was not the same on every Mac: Slack 4.52.155 and 4.52.178, Discord 0.0.410 and 0.0.415, Telegram 12.10 and 13.0, Signal 8.26.0 and 8.30.0, WhatsApp 26.35.23 and 26.41.14, Zoom 7.1.5,
Visual Studio Code 1.136.1, Sublime Text build 4200, Zed 1.18.1, iTerm2 3.6.11, Notion 7.32.1, Obsidian 1.13.7, Figma 126.8.18, Spotify 1.3.4.258, Raycast 2.2.0.0, Postman 12.26.5, GitHub Desktop 3.6.5.

To add an app or read them anew, run the script, and in each folder it brought back (what a file here already has stays):

```bash
for f in menu-keys/*.tsv; do
  kept="$ARBOR/collab/evidence/menu-keys/$(basename "$f")"
  { cat "$kept" 2>/dev/null; awk -F '\t' 'NF >= 5 { print $1 "\t" $2 "\t" $3 }' "$f"; } | awk '!seen[$0]++' > "$kept.new" && mv "$kept.new" "$kept"
done
find "$ARBOR/collab/evidence/menu-keys" -name "*.tsv" -empty -delete    # an app that had no menu bar
```
