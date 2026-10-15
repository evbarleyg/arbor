#!/bin/bash
# Makes the demo films: demo/make.sh <folder> [--stills]
# See demo/README.md. Needs swift, node with Playwright's Chromium, ffmpeg, and the fonts Inter and DejaVu Sans.
set -euo pipefail
# The folder is where the caller says, seen from where the caller stands.
mkdir -p "${1:?usage: demo/make.sh <folder> [--stills]}"
out=$(cd "$1" && pwd)
cd "$(dirname "$0")/.."
# Nothing of an earlier run is left to be taken for this one's. Stills make no films, so they take none away.
rm -f "$out"/*.jsonl "$out"/*.jsonl.failed
[ "${2:-}" = --stills ] || rm -f "$out"/arbor-demo.mp4 "$out"/arbor-demo-short.mp4 "$out"/arbor-loop.webp

swift build --product arbor-sim
node demo/render/icons.mjs demo/icons

# Every script is played and held to the rules before anything is painted: painting takes minutes, and three films belong together.
play() { # <script> <audit's words>…
  local name=$1
  shift
  if ! .build/debug/arbor-sim film "demo/$name.txt" --out "$out/$name.jsonl" > "$out/$name-story.txt"; then
    echo "demo/$name.txt: Arbor does not do what the script says; no film. From $out/$name-story.txt:" >&2
    grep -E "FAILED|OUT OF DATE|cannot|usage" "$out/$name-story.txt" >&2 || tail -n 3 "$out/$name-story.txt" >&2
    exit 1
  fi
  echo "demo/$name.txt: $(tail -n 1 "$out/$name-story.txt")"
  node demo/render/audit.mjs "$out/$name.jsonl" "$@"
}
play film 60-90
play short 25-50
play loop 8-13 --loop

if [ "${2:-}" = --stills ]; then
  node demo/render/render.mjs "$out/film.jsonl" --stills "$out/stills" --every 60
  node demo/render/render.mjs "$out/short.jsonl" --stills "$out/stills-short" --every 60
  exit
fi

node demo/render/render.mjs "$out/film.jsonl" "$out/arbor-demo.mp4"
node demo/render/render.mjs "$out/short.jsonl" "$out/arbor-demo-short.mp4"
# The loop for the README: the display with a strip for the keys under it, a good ten seconds that end as they begin.
node demo/render/render.mjs "$out/loop.jsonl" "$out/loop.mp4" --plain 960 --every 2
# WebP's colours are BT.601, the film's BT.709.
ffmpeg -y -loglevel error -i "$out/loop.mp4" -vf scale=in_color_matrix=bt709:out_color_matrix=bt601 -c:v libwebp_anim -loop 0 -quality 72 -compression_level 6 "$out/arbor-loop.webp"
rm -f "$out/loop.mp4"
ls -l "$out/arbor-demo.mp4" "$out/arbor-demo-short.mp4" "$out/arbor-loop.webp"
