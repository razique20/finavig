// Cold-start verification of the auth flow: splash → welcome → login.
// Serves build/web fresh (empty localStorage = brand-new user), captures
// screenshots at each stage, and asserts on the URL hash transitions.
// Run: flutter build web && node tool/verify_splash_flow.mjs
import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import path from 'node:path';
import { mkdirSync, readdirSync } from 'node:fs';
import { createRequire } from 'node:module';

const ROOT = process.cwd();
const WEB = path.join(ROOT, 'build', 'web');
const OUT = path.join(ROOT, 'build', 'flow-verify');
const PORT = 8791;
const BASE = `http://127.0.0.1:${PORT}`;

const MIME = {
  '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css',
  '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.svg': 'image/svg+xml', '.wasm': 'application/wasm', '.ttf': 'font/ttf',
  '.otf': 'font/otf', '.map': 'application/json', '.ico': 'image/x-icon',
};

function serve() {
  return new Promise((resolve) => {
    const server = http.createServer(async (req, res) => {
      try {
        let p = decodeURIComponent(new URL(req.url, BASE).pathname);
        if (p === '/') p = '/index.html';
        let file = path.join(WEB, p);
        if (!existsSync(file) || !p.includes('.')) file = path.join(WEB, 'index.html');
        const data = await readFile(file);
        res.writeHead(200, { 'Content-Type': MIME[path.extname(file)] ?? 'application/octet-stream' });
        res.end(data);
      } catch {
        res.writeHead(500); res.end('error');
      }
    });
    server.listen(PORT, '127.0.0.1', () => resolve(server));
  });
}

// Resolve patchright from the newest installed CodeGPT extension standalone
// bundle (the path version-bumps with every extension update).
const extRoot = path.join(process.env.HOME, '.vscode', 'extensions');
const exts = readdirSync(extRoot)
  .filter((d) => d.startsWith('danielsanmedium.dscodegpt-'))
  .sort();
if (exts.length === 0) throw new Error('No CodeGPT extension with patchright found');
const require = createRequire(path.join(extRoot, exts.at(-1), 'standalone', 'package.json'));
const { chromium } = require('patchright');

async function waitForUrl(page, fragment, timeoutMs) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    if (page.url().includes(fragment)) return true;
    await page.waitForTimeout(200);
  }
  return false;
}

async function main() {
  mkdirSync(OUT, { recursive: true });
  const server = await serve();
  const browser = await chromium.launch({
    channel: 'chromium-headless-shell',
    executablePath: '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  });
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 }, // iPhone-ish — artwork is portrait
    deviceScaleFactor: 1,
  });
  const page = await context.newPage();

  const consoleErrors = [];
  const failedRequests = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text().slice(0, 300));
  });
  page.on('requestfailed', (req) => {
    failedRequests.push(`${req.url().slice(0, 120)} — ${req.failure()?.errorText ?? '?'}`);
  });

  const result = { stages: [] };

  // ── Cold start: fresh context = brand-new user, nothing seeded ──────────
  await page.goto(`${BASE}/`, { waitUntil: 'domcontentloaded' });
  await page.evaluate(() => localStorage.clear());

  // Early frame — pre/at first Flutter paint.
  await page.waitForTimeout(500);
  await page.screenshot({ path: path.join(OUT, '01_boot.png') });
  result.stages.push({ stage: 'boot(500ms)', url: page.url() });

  // Splash with the artwork (animation runs 1.8s + 1s hold).
  await page.waitForTimeout(1500);
  await page.screenshot({ path: path.join(OUT, '02_splash.png') });
  result.stages.push({ stage: 'splash(~2s)', url: page.url() });

  // New user → welcome screen. Poll the hash — splash routes at ~3s.
  const gotWelcome = await waitForUrl(page, '#/welcome', 20000);
  await page.waitForTimeout(900); // fade/slide settle
  await page.screenshot({ path: path.join(OUT, '03_welcome.png') });
  result.stages.push({ stage: 'welcome', url: page.url(), reached: gotWelcome });

  // Tap "Continue to Login" — full-width CTA near the bottom center.
  // Flutter web renders to canvas, so this is a coordinate tap, not a ref.
  await page.mouse.click(195, 760);
  const gotLogin = await waitForUrl(page, '#/login', 8000);
  await page.waitForTimeout(1200); // step transition settle
  await page.screenshot({ path: path.join(OUT, '04_login.png') });
  result.stages.push({ stage: 'login', url: page.url(), reached: gotLogin });

  // Structural proof the CTA persisted the welcome flag.
  result.hasSeenWelcome = await page.evaluate(
    () => localStorage.getItem('flutter.hasSeenWelcome'));

  result.consoleErrors = consoleErrors;
  result.failedRequests = failedRequests.slice(0, 10);

  console.log(JSON.stringify(result, null, 2));
  await browser.close();
  server.close();

  const ok = gotWelcome && gotLogin && result.hasSeenWelcome === 'true';
  console.log(ok ? 'FLOW OK' : 'FLOW FAILED');
  if (!ok) process.exit(1);
}

main().catch((e) => { console.error(e); process.exit(1); });
