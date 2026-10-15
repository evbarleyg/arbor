// Paints the frames of a film and encodes them.
//
//   node demo/render/render.mjs <frames.jsonl> <out.mp4> [--from <s>] [--to <s>] [--workers <n>] [--stills <dir>] [--every <n>]
//                               [--plain <width>] [--keep]
//
// Each worker is a page of a headless Chromium that holds the whole film and paints every n-th stretch of it; the pictures go to a
// folder beside the output as PNG files and ffmpeg makes the film of them. `--stills <dir>` only saves pictures (every `--every`-th
// frame) to look at. `--plain <width>` paints the display, that many pixels wide, with a strip for the keys under it: for the loop in the
// README.
// Needs Playwright with Chromium, and ffmpeg.

import { createRequire } from 'node:module';
import { spawnSync } from 'node:child_process';
import { mkdirSync, readdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  // Installed for everybody rather than for this folder.
  ({ chromium } = require(join(dirname(process.execPath), '..', 'lib', 'node_modules', 'playwright')));
}

const args = process.argv.slice(2);
const option = (name, fallback) => {
  const index = args.indexOf(name);
  if (index < 0) return fallback;
  const [, value] = args.splice(index, 2);
  return value;
};
const flag = (name) => {
  const index = args.indexOf(name);
  if (index >= 0) args.splice(index, 1);
  return index >= 0;
};
const from = Number(option('--from', 0));
const to = Number(option('--to', Infinity));
const workers = Number(option('--workers', 4));
const stills = option('--stills', null);
const every = Number(option('--every', 1));
const plain = Number(option('--plain', 0));
const keep = flag('--keep');
const [input, output] = args;
if (!input || (!output && !stills)) {
  console.error('usage: render.mjs <frames.jsonl> <out.mp4> [--from s] [--to s] [--workers n] [--stills dir] [--every n] [--plain width] [--keep]');
  process.exit(2);
}

const here = dirname(fileURLToPath(import.meta.url));
const text = readFileSync(input, 'utf8');
const film = JSON.parse(text.slice(0, text.indexOf('\n')));
const count = text.split('\n').filter(Boolean).length - 1;
const first = Math.max(Math.round(from * film.fps), 0);
const last = Math.min(Math.round(to * film.fps), count);
const wanted = [];
for (let n = first; n < last; n += every) wanted.push(n);

const folder = resolve(stills || `${output}.frames`);
mkdirSync(folder, { recursive: true });
// What an earlier run left would be taken for part of this film.
for (const name of readdirSync(folder)) if (/^\d{6}\.png$/.test(name)) rmSync(join(folder, name));
if (output && !stills) rmSync(output, { force: true });
// `Paint.STRIP`: 96 points under the display.
const size = plain ? [plain, Math.round(plain * (film.display.frame[3] + 96) / film.display.frame[2] / 2) * 2] : [1920, 1080];

const browser = await chromium.launch();
const started = Date.now();
let done = 0;
await Promise.all(Array.from({ length: Math.min(workers, wanted.length) }, async (_, worker) => {
  const page = await browser.newPage({ viewport: { width: size[0], height: size[1] } });
  page.on('pageerror', (error) => { console.error(`page: ${error.message}`); process.exitCode = 1; });
  await page.goto(pathToFileURL(join(here, 'film.html')).href);
  await page.evaluate(() => document.fonts.ready);
  await page.evaluate(([t, s]) => { Film.load(t); Film.size(...s); }, [text, size]);
  for (let index = worker; index < wanted.length; index += workers) {
    const n = wanted[index];
    const name = stills ? `${String(n).padStart(6, '0')}.png` : `${String(index).padStart(6, '0')}.png`;
    writeFileSync(join(folder, name), Buffer.from(await page.evaluate(([n, p]) => Film.png(n, p), [n, !!plain]), 'base64'));
    done += 1;
    if (done % 300 === 0) console.error(`${done} of ${wanted.length} pictures, ${((Date.now() - started) / done).toFixed(0)} ms each`);
  }
}));
await browser.close();
console.error(`${wanted.length} pictures in ${((Date.now() - started) / 1000).toFixed(1)} s`);
if (process.exitCode) {
  console.error('something went wrong in a page: no film');
  process.exit(process.exitCode);
}
if (stills) process.exit(0);

// yuv420p and +faststart so that phones and browsers play it; a CRF low enough that thin lines and small text stay clean. The colours are turned into
// BT.709 and the film says so: ffmpeg's own choice is BT.601 without a word, which a player that takes a film of this size for BT.709 shows a shade off.
const encoded = spawnSync('ffmpeg', [
  '-y', '-loglevel', 'error', '-framerate', String(film.fps / every), '-i', join(folder, '%06d.png'),
  '-frames:v', String(wanted.length), '-c:v', 'libx264', '-preset', 'slow', '-crf', '20',
  '-vf', 'scale=out_color_matrix=bt709:out_range=tv', '-pix_fmt', 'yuv420p', '-colorspace', 'bt709', '-color_primaries', 'bt709', '-color_trc', 'bt709', '-color_range', 'tv',
  '-movflags', '+faststart',
  '-f', 'mp4', `${output}.part`,
], { stdio: 'inherit' });
if (encoded.status !== 0) {
  // The pictures took minutes: they stay, for another try.
  console.error(`ffmpeg ${encoded.error ? `did not start: ${encoded.error.message}` : `ended with ${encoded.status}`}; the pictures are in ${folder}`);
  rmSync(`${output}.part`, { force: true });
  process.exit(1);
}
// Under its name only once it is whole.
renameSync(`${output}.part`, output);
if (!keep) rmSync(folder, { recursive: true });
