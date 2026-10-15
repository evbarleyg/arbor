// Saves every canvas of gallery.html as a PNG:  node gallery.mjs <directory> [pixels per point]
//
// Needs Playwright with a Chromium. Where that is installed globally, say where:
// NODE_PATH=<the global node_modules>. PLAYWRIGHT_CHROMIUM names another browser than Playwright's own.

import { mkdirSync, writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

// `import` ignores NODE_PATH; `require` honours it.
const { chromium } = createRequire(import.meta.url)('playwright');

const target = resolve(process.argv[2] || 'gallery');
const scale = process.argv[3] ? `&scale=${Number(process.argv[3])}` : '';
const gallery = pathToFileURL(join(dirname(fileURLToPath(import.meta.url)), 'gallery.html')).href;
mkdirSync(target, { recursive: true });

const browser = await chromium.launch({ executablePath: process.env.PLAYWRIGHT_CHROMIUM || undefined });
const tab = await browser.newPage();
tab.on('pageerror', (error) => {
  console.error(String(error.stack || error));
  process.exitCode = 1;
});
for (const page of ['desktop', 'sizes', 'icons']) {
  await tab.goto(`${gallery}?page=${page}${scale}`);
  await tab.waitForSelector('body[data-painted]', { timeout: 30000 });
  const sheets = await tab.evaluate(() => [...document.querySelectorAll('canvas')].map((canvas) => (
    { name: canvas.id, data: canvas.toDataURL('image/png').split(',')[1] })));
  for (const { name, data } of sheets) {
    writeFileSync(join(target, `${name}.png`), Buffer.from(data, 'base64'));
  }
  const spent = await tab.evaluate(() => window.millisecondsPerDesktop);
  if (spent) console.log(`a whole desktop: ${spent.toFixed(1)} ms`);
}
await browser.close();
console.log(`saved to ${target}`);
