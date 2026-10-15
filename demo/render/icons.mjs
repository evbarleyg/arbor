// Writes each app's icon as Arbor would sample it, so that the colours of covers, tiles and the minimap in the film are the ones Arbor
// itself takes from these icons (`app <Name> icon <file>` in demo/film.txt, `IconColour` in ArborCore).
//
//   node demo/render/icons.mjs demo/icons
//
// One file per app: 24 x 24 pixels of four bytes, red, green, blue, alpha, colours not multiplied by alpha.

import { createRequire } from 'node:module';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  ({ chromium } = require(join(dirname(process.execPath), '..', 'lib', 'node_modules', 'playwright')));
}

const folder = resolve(process.argv[2] || 'icons');
mkdirSync(folder, { recursive: true });
const browser = await chromium.launch();
const page = await browser.newPage();
await page.goto(pathToFileURL(join(dirname(fileURLToPath(import.meta.url)), 'film.html')).href);
const icons = await page.evaluate(() => Object.fromEntries(Object.keys(Scenery.apps).map((app) => {
  const canvas = new OffscreenCanvas(24, 24);
  const ctx = canvas.getContext('2d');
  Scenery.icon(ctx, app, 0, 0, 24);
  return [app, Array.from(ctx.getImageData(0, 0, 24, 24).data)];
})));
await browser.close();
for (const [app, bytes] of Object.entries(icons)) writeFileSync(join(folder, `${app}.rgba`), Buffer.from(bytes));
console.error(`${Object.keys(icons).length} icons in ${folder}`);
