// Holds a film to the storyboard's rules that a machine can check, before anybody spends time painting it.
//
//   node demo/render/audit.mjs <frames.jsonl> [<least>-<most> seconds] [--loop]
//
// The film is 60 to 90 seconds long, or as long as is said; a caption has at most 50 characters, stays for at least 2.5 seconds (a note under it: 80, and 5), and never meets what the hands do at the
// other end of the band; keys are shown for long enough to be read; the frames hold nothing that the painter would leave out. `--loop`: the last frame is the first again, and no keys are shown in either.
// Exits with 1 and says what is wrong.
//
// What a caption says of places and sizes, which `expect` has no words for, a script says with marks of its own:
//
//   mark keep.<name> on             remember where every window is now, once for each name; `start` is the film's first frame: it needs no mark and takes none
//   mark same.<name> <id> <id>…     these windows are where they were then, at the size they had, to the point: Arbor itself takes a window
//                                   that is one point from its place to be there, and leaves it, as at the end of a gap's drag
//   mark still.<name> <id> <id>…    exactly there, and neither they nor their stand-ins have moved in any frame since
//   mark taller <a> <b>             window a is taller than window b; `wider` likewise; `alike`: they have the same size
//
// A claim holds for as long as its mark stands, in every frame, and it is about what is seen: while windows travel as stand-ins it does not hold. So a script says it
// once things have come to rest and takes it back (`mark same.<name>`) before the next thing moves. A mark that nobody reads is a slip of the pen, and is said.

import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  ({ chromium } = require(join(dirname(process.execPath), '..', 'lib', 'node_modules', 'playwright')));
}

const words = process.argv.slice(2).filter((word) => !word.startsWith('--'));
const loop = process.argv.includes('--loop');
const text = readFileSync(words[0], 'utf8');
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto(pathToFileURL(join(dirname(fileURLToPath(import.meta.url)), 'film.html')).href);
await page.evaluate(() => document.fonts.ready);
const problems = await page.evaluate(([text, range, loop]) => {
  Film.load(text);
  const { film, frames, timeline } = Film;
  const at = (n) => `${(n / film.fps).toFixed(1)} s`;
  const problems = [];
  const length = frames.length / film.fps;
  const [least, most] = (range).split('-').map(Number);
  if (length < least || length > most) problems.push(`the film is ${length.toFixed(1)} s long: ${least} to ${most} are wanted`);
  for (const caption of timeline.captions) {
    const stay = ((caption.end ?? frames.length) - caption.start) / film.fps;
    if (caption.text.length > 50) problems.push(`${at(caption.start)}: "${caption.text}" has ${caption.text.length} characters`);
    if (stay < 2.5) problems.push(`${at(caption.start)}: "${caption.text}" stays for only ${stay.toFixed(1)} s`);
  }
  for (const note of timeline.notes) {
    const stay = ((note.end ?? frames.length) - note.start) / film.fps;
    if (note.text.length > 80) problems.push(`${at(note.start)}: the note "${note.text}" has ${note.text.length} characters`);
    if (stay < 5) problems.push(`${at(note.start)}: the note "${note.text}" stays for only ${stay.toFixed(1)} s`);
  }
  for (const span of timeline.hands) {
    if (span.keys && (span.end - span.start) / film.fps < 0.5) problems.push(`${at(span.start)}: ${span.keys.join(' ')} shows for under half a second`);
  }
  const places = (n) => new Map(frames[n].windows.map((window) => [String(window.id), window.frame]));
  const equal = (a, b) => !!a && !!b && a.every((value, index) => Math.abs(value - b[index]) < 0.5);
  const near = (a, b) => !!a && !!b && a.every((value, index) => Math.abs(value - b[index]) <= 1);
  const read = /^(shot|caption|note|look|clock|taller|wider|alike|(keep|same|still|bounce|badge)\.\w+|card\.\d+)$/;
  const kept = { start: 0 };
  const told = new Set();
  const since = {};
  frames.forEach((frame, n) => {
    for (const key of Paint.unpainted(frame)) {
      if (!told.has(`key ${key}`)) problems.push(`${at(n)}: the frames hold "${key}", which the painter would leave out`);
      told.add(`key ${key}`);
    }
    const before = n > 0 ? frames[n - 1].marks ?? {} : {};
    for (const [key, value] of Object.entries(frame.marks ?? {})) {
      if (!read.test(key)) {
        if (!told.has(`mark ${key}`)) problems.push(`${at(n)}: nobody reads the mark "${key}"`);
        told.add(`mark ${key}`);
        continue;
      }
      const [verb, name] = key.split('.');
      const fresh = before[key] !== value;
      if (verb === 'keep' && name === 'start') {
        if (!told.has(key)) problems.push(`${at(n)}: "start" is the film's first frame; a mark that moves it empties every claim about it`);
        told.add(key);
        continue;
      }
      if (verb === 'keep' && fresh) kept[name] = n;
      if (!['same', 'still', 'taller', 'wider', 'alike'].includes(verb)) continue;
      // Said once for each time the claim is made, in the first frame that belies it.
      const claim = `${key} ${value}`;
      if (fresh) { told.delete(claim); since[claim] = n; }
      if (told.has(claim)) continue;
      const belied = (m, text) => { problems.push(`${at(m)}: ${text} (mark ${claim}, said at ${at(since[claim])})`); told.add(claim); };
      const ids = String(value).split(' ');
      const now = places(n);
      const gone = ids.filter((id) => !now.has(id));
      if (gone.length) { belied(n, `there is no window ${gone.join(', ')}`); continue; }
      if (frame.stage) { belied(n, 'the windows are travelling: what is seen is their stand-ins'); continue; }
      if (['taller', 'wider', 'alike'].includes(verb)) {
        const [a, b] = ids.map((id) => now.get(id));
        const size = ([, , width, height]) => `${width} x ${height}`;
        const holds = ids.length === 2
          && (verb === 'alike' ? Math.abs(a[2] - b[2]) <= 1 && Math.abs(a[3] - b[3]) <= 1 : verb === 'wider' ? a[2] > b[2] : a[3] > b[3]);
        if (!holds) belied(n, `${ids[0]} (${size(a)}) and ${ids[1]} (${b ? size(b) : 'nothing'}): not ${verb}`);
        continue;
      }
      if (!(name in kept)) { belied(n, `nothing was kept as "${name}"`); continue; }
      const then = places(kept[name]);
      for (let m = verb === 'still' && fresh ? kept[name] + 1 : n; m <= n && !told.has(claim); m += 1) {
        const seen = places(m);
        for (const standIn of frames[m].stage?.standIns ?? []) seen.set(String(standIn.id), standIn.frame);
        const moved = ids.filter((id) => !(verb === 'same' ? near : equal)(seen.get(id), then.get(id)));
        if (moved.length) belied(m, moved.map((id) => `${id} is at ${seen.get(id)?.join(' ')}, not at ${then.get(id)?.join(' ')}`).join('; '));
      }
    }
  });
  if (loop) {
    const bare = ({ n, t, ...rest }) => JSON.stringify(rest);
    const [first, last] = [frames[0], frames[frames.length - 1]];
    if (bare(first) !== bare(last)) {
      const keys = [...new Set([...Object.keys(first), ...Object.keys(last)])].filter((key) => !['n', 't'].includes(key) && JSON.stringify(first[key]) !== JSON.stringify(last[key]));
      problems.push(`the loop does not end as it begins: ${keys.join(', ')} differ`);
    }
    // Nor is anything of the film's own left over, which would go out like a light where the loop begins again.
    for (const n of [0, frames.length - 1]) if (timeline.at(n).hands) problems.push(`${at(n)}: the loop begins again while keys are still shown`);
  }
  const ctx = document.getElementById('picture').getContext('2d');
  let meeting = null;
  frames.forEach((_, n) => {
    const { caption, hands, room } = Paint.bandWidths(ctx, timeline.at(n));
    const meets = caption > 0 && hands > 0 && caption + hands + 48 > room;
    if (meets && meeting === null) problems.push(`${at(n)}: the caption (${Math.round(caption)}) and the hands (${Math.round(hands)}) meet`);
    meeting = meets ? n : null;
  });
  return problems;
}, [text, words[1] || '60-90', loop]);
await browser.close();
for (const problem of problems) console.error(problem);
console.error(problems.length ? `${problems.length} problem(s)` : 'the film keeps the rules a machine can check');
process.exit(problems.length ? 1 : 0);
