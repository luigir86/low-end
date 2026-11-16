// The web app in Safari's engine (WebKit, through WebKitGTK's MiniBrowser),
// with the iPhone's rules on: sound only after a touch, for Web Audio and
// for audio elements, and the audio session that refuses the microphone
// while it says music only (iphone.js). Each test opens the app as a player
// does from the second opening on: under its service worker, cross-origin
// isolated.
//
// Usage (docs/web.md, "Tests in Safari's engine"):
//   flutter build web --wasm --release --no-web-resources-cdn --base-href /low-end/
//   dart run tool/web_offline.dart build/web
//   xvfb-run -a node --test test_web/iphone_test.mjs
// LOW_END_WEB=<dir> tests another build; LOW_END_WEB_SHOTS=<dir> keeps a
// screenshot and the page's notes of each failed test there.
import { test, before, after, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Chrome, WebKit, sleep } from './webdriver.mjs';

const here = path.dirname(fileURLToPath(import.meta.url));
const build = process.env.LOW_END_WEB ?? path.join(here, '..', 'build', 'web');
const shots = process.env.LOW_END_WEB_SHOTS;
// LOW_END_WEB_BROWSER=chrome runs the same tests in Chrome, as on an Android
// phone: without the iPhone's audio session, so its checks are left out.
const iphone = process.env.LOW_END_WEB_BROWSER !== 'chrome';
let app;
let site;

let server;
let browser;

before(async () => {
  assert.ok(fs.existsSync(path.join(build, 'sw.js')),
    `No web build with its service worker in ${build}: see the usage above.`);
  // On a free port: a server left from another run would be tested instead.
  server = spawn(process.execPath, [path.join(here, 'server.mjs'), build], { stdio: ['ignore', 'pipe', 'inherit'] });
  const port = await new Promise((resolve, reject) => {
    server.stdout.on('data', (data) => {
      const found = /on (\d+)/.exec(String(data));
      if (found) resolve(found[1]);
    });
    server.on('exit', () => reject(new Error('The test server did not start.')));
  });
  site = `http://localhost:${port}/__site`;
  app = `http://localhost:${port}/low-end/`;
});

after(() => server?.kill());

afterEach(async (t) => {
  await setSite({ offline: 0, version: 1 });
  if (!browser) return;
  if (shots && t.passed === false) {
    fs.mkdirSync(shots, { recursive: true });
    const name = t.name.replace(/[^a-z0-9]+/gi, '_');
    await browser.screenshot(path.join(shots, `${name}.png`)).catch(() => {});
    const notes = { probe: await probe().catch(String), controls: await browser.run(labelsNow).catch(String) };
    fs.writeFileSync(path.join(shots, `${name}.json`), JSON.stringify(notes, null, 1));
  }
  await browser.quit();
  browser = null;
});

/// A new browser with the iPhone's touch rules (in Chrome, a phone's), and the
/// app opened in it.
/// With [firstOpening] the test goes on as soon as the app is on screen,
/// before its service worker is in; [storage] is put in the page's
/// localStorage first (iphoneMic: 'no' for a player who refuses the
/// microphone, see iphone.js).
async function openApp({ firstOpening = false, storage = {} } = {}) {
  browser = iphone
    ? await WebKit.start({ features: ['+RequiresUserGestureForAudioPlayback', '+RequiresUserGestureForMediaPlayback'] })
    : await Chrome.start();
  await browser.setWindow(412, 915).catch(() => {});
  await browser.go(`${app}__blank.html`);
  await browser.run((storage) => {
    localStorage.clear();
    for (const [key, value] of Object.entries(storage)) localStorage.setItem(key, value);
    // English, with the first-opening guide and hints already seen.
    for (const [key, value] of Object.entries({ seen_guide: true, seen_swipe_hint: true, language: 'en' })) {
      localStorage.setItem(`flutter.${key}`, JSON.stringify(value));
    }
  }, storage);
  await browser.go(app);
  await appOnScreen({ firstOpening });
  return browser;
}

/// Waits for the app on screen, under its service worker unless [firstOpening].
async function appOnScreen({ firstOpening = false } = {}) {
  // The first opening reloads itself once its service worker is in.
  await waitFor('the app on screen', () => browser.run((firstOpening) =>
    (firstOpening || (window.crossOriginIsolated && !!navigator.serviceWorker.controller)) &&
    !document.getElementById('loading') && document.querySelectorAll('flt-semantics[role="tab"]').length === 4,
  firstOpening), 90000);
  await sleep(1000);
}

/// Changes the site, as server.mjs explains: offline, or a new version.
async function setSite(state) {
  if (!site) return;
  await fetch(`${site}?${new URLSearchParams(state)}`);
}

/// The page's accessible controls: label, role and centre. Run in the page.
function labelsNow() {
  return [...document.querySelectorAll('flt-semantics')]
    .filter((e) => e.getAttribute('role') || e.getAttribute('aria-label'))
    .map((e) => {
      const r = e.getBoundingClientRect();
      return { label: (e.getAttribute('aria-label') || e.textContent || '').trim(), role: e.getAttribute('role'),
        x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width };
    })
    .filter((e) => e.w > 0);
}

async function find(pattern, { role = 'button', last = false } = {}) {
  const all = await browser.run(labelsNow);
  const matches = all.filter((c) => (!role || c.role === role) && pattern.test(c.label));
  const found = last ? matches.at(-1) : matches[0];
  return found ?? null;
}

async function tap(pattern, options) {
  const control = await waitFor(`a control ${pattern}`, () => find(pattern, options), 15000);
  await browser.tap(control.x, control.y);
  return control;
}

async function waitFor(what, check, timeout = 20000) {
  const end = Date.now() + timeout;
  let last;
  while (Date.now() < end) {
    try {
      last = await check();
      if (last) return last;
    } catch (error) {
      last = error;
    }
    await sleep(200);
  }
  throw new Error(`Waited ${timeout / 1000} s for ${what}; last: ${String(last).slice(0, 300)}`);
}

const probe = () => browser.run(() => JSON.parse(JSON.stringify(window.__iphone)));
/// Whether the audio session is of [type]: always, in Chrome, which has none.
const sessionIs = async (type) => !iphone || (await browser.run(() => navigator.audioSession.type)) === type;

/// Opens a section from its tab, and waits for the slide to end: a touch
/// while the sections slide is taken for the slide.
async function goTo(section) {
  await tap(new RegExp(`^${section}$`), { role: 'tab' });
  await sleep(1500);
}

async function soundAfter(action) {
  const before = (await probe()).sound;
  await action();
  return waitFor('a sound', async () => (await probe()).sound > before, 20000);
}

test('opens without errors, its sound set as music', async () => {
  await openApp();
  const notes = await probe();
  assert.deepEqual(notes.errors, []);
  assert.ok(await sessionIs('playback'));
});

test('Harmony sounds after a touch', async () => {
  await openApp();
  await goTo('Harmony');
  await soundAfter(() => tap(/^Play A\n/));
  assert.deepEqual((await probe()).errors, []);
});

test('the metronome sounds after a touch', async () => {
  await openApp();
  await goTo('Metronome');
  await soundAfter(() => tap(/^Start the metronome/));
  assert.deepEqual((await probe()).errors, []);
});

test('the tuner gets the microphone and reads a note', async () => {
  await openApp();
  await goTo('Tuner');
  // It listens as it comes on screen; a touch on the dial starts it if not.
  const listening = await waitFor('the tuner listening or offering to', async () =>
    (await find(/^Pause$/)) || (await find(/^(Listen|Start)/)), 15000);
  if (!/^Pause$/.test(listening.label)) await browser.tap(listening.x, listening.y);
  await waitFor('the microphone open', async () => (await probe()).mic.includes('open'), 15000);
  const notes = await probe();
  assert.deepEqual(notes.mic.filter((m) => m !== 'open'), [], 'the microphone was refused');
  assert.ok(await sessionIs('play-and-record'));
  // The mock microphone plays tones: a note is read.
  await waitFor('a note on the dial', () => find(/^[A-G][♯♭#b]?\d/, { role: null }), 15000);
  // Leaving the tuner gives the sound back to music.
  await goTo('Metronome');
  await waitFor('the session back to music', () => sessionIs('playback'), 10000);
  assert.deepEqual((await probe()).errors, []);
});

test('the Player records a take with REC and plays it', async () => {
  await openApp();
  await goTo('Player');
  await tap(/^Record$/);
  await waitFor('the microphone open', async () => (await probe()).mic.includes('open'), 15000);
  assert.deepEqual((await probe()).mic.filter((m) => m !== 'open'), [], 'the microphone was refused');
  await sleep(2500);
  await tap(/^Stop$/, { role: null });
  // The take opens in the Player, ready to play.
  await waitFor('the take in the Player', () => find(/^Temporary \d/), 15000);
  assert.ok(await sessionIs('playback'));
  await tap(/^Play$/);
  await waitFor('the take playing', async () => (await probe()).plays.length > 0, 15000);
  assert.deepEqual((await probe()).plays.filter((p) => p !== 'playing'), [], 'the audio element was refused');
  assert.deepEqual((await probe()).errors, []);
});

test('a sound cut by the phone offers Resume, which plays again', async () => {
  await openApp();
  await goTo('Metronome');
  await soundAfter(() => tap(/^Start the metronome/));
  // What Safari does for a call or the locked screen, as far as the page sees.
  await browser.run(() => { window.lowEndAudioContext.suspend(); });
  const resume = await waitFor('Resume', () => find(/^Resume$/), 10000);
  await soundAfter(() => browser.tap(resume.x, resume.y));
  assert.deepEqual((await probe()).errors, []);
});

test('the first opening sounds at once, and is not reloaded under the sound', async () => {
  await openApp({ firstOpening: true });
  await goTo('Harmony');
  await soundAfter(() => tap(/^Play A\n/));
  // The page would reload itself once its worker is in, unless a sound has
  // started: this one must go on.
  await browser.run(() => { window.__iphoneSamePage = true; });
  await sleep(8000);
  assert.equal(await browser.run(() => window.__iphoneSamePage === true), true, 'the page reloaded while it played');
  assert.deepEqual((await probe()).errors, []);
});

test('the tuner listens again when it comes back on screen', async () => {
  await openApp();
  await goTo('Tuner');
  await waitFor('the microphone open', async () => (await probe()).mic.includes('open'), 15000);
  await goTo('Metronome');
  await waitFor('the session back to music', () => sessionIs('playback'), 10000);
  const opened = (await probe()).mic.filter((m) => m === 'open').length;
  await goTo('Tuner');
  await waitFor('the microphone open again', async () =>
    (await probe()).mic.filter((m) => m === 'open').length > opened, 15000);
  await waitFor('a note on the dial', () => find(/^[A-G][♯♭#b]?\d/, { role: null }), 15000);
  assert.deepEqual((await probe()).errors, []);
});

test('after a no to the microphone the tuner says so and the sound stays music', async () => {
  await openApp({ storage: { iphoneMic: 'no' } });
  await goTo('Tuner');
  await waitFor('the microphone refused', async () => (await probe()).mic.includes('denied'), 15000);
  // The message says where to allow it, and offers to listen again.
  await waitFor('the message', () => find(/needs the microphone/, { role: null }), 10000);
  assert.ok(await sessionIs('playback'), 'a refused microphone left the session listening');
  // The metronome still plays.
  await goTo('Metronome');
  await soundAfter(() => tap(/^Start the metronome/));
  assert.deepEqual((await probe()).errors, []);
});

test('Choose a track asks for audio files, not for photos and videos', async () => {
  await openApp();
  await goTo('Player');
  await tap(/^Choose a track$/);
  const accept = await waitFor('the file chooser', async () => (await probe()).choosers[0], 10000);
  assert.ok(!/audio\/\*/.test(accept), `accept="${accept}" makes Safari on the iPhone offer photos and videos`);
  for (const extension of ['.mp3', '.m4a', '.wav']) assert.ok(accept.includes(extension), `${extension} missing from "${accept}"`);
});

test('with no network it opens again from the phone, and plays', async () => {
  await openApp();
  await setSite({ offline: 1 });
  await browser.go(app);
  await appOnScreen();
  await goTo('Metronome');
  await soundAfter(() => tap(/^Start the metronome/));
  await goTo('Tuner');
  // The metronome plays: the tuner waits for a touch to listen.
  await tap(/^Listen/);
  await waitFor('the microphone open', async () => (await probe()).mic.includes('open'), 15000);
  await waitFor('a note on the dial', () => find(/^[A-G][♯♭#b]?\d/, { role: null }), 15000);
  assert.deepEqual((await probe()).errors, []);
});

test('a new version is kept whole, then opens in place of the old one', async () => {
  await openApp();
  const keys = () => browser.runAsync(() => caches.keys());
  const old = (await keys()).filter((key) => !key.startsWith('low-end-sounds-'));
  assert.equal(old.length, 1, `one version kept, not ${old}`);
  await setSite({ version: 2 });
  // The browser looks for a new worker at each opening; the page open
  // meanwhile goes on.
  await browser.go(app);
  await appOnScreen();
  await waitFor('the new version kept, the old one thrown away', async () => {
    const now = await keys();
    return now.some((key) => key.startsWith('low-end-v2-')) && !now.includes(old[0]);
  }, 90000);
  assert.ok((await keys()).some((key) => key.startsWith('low-end-sounds-')), 'the recordings were thrown away too');
  await browser.go(app);
  await appOnScreen();
  const version = () => document.querySelector('meta[name="low-end-test-version"]').content;
  assert.equal(await browser.run(version), '2');
  await goTo('Metronome');
  await soundAfter(() => tap(/^Start the metronome/));
  assert.deepEqual((await probe()).errors, []);
});

/// Records a take of a few seconds in the Player, which opens it.
async function recordTake() {
  await goTo('Player');
  await tap(/^Record$/);
  await waitFor('the microphone open', async () => (await probe()).mic.includes('open'), 15000);
  await sleep(2500);
  await tap(/^Stop$/, { role: null });
  await waitFor('the take in the Player', () => find(/^Temporary \d/), 15000);
}

/// Saves or shares the take under the name the dialog offers.
async function exportTake(action) {
  await tap(new RegExp(`^${action}$`));
  await waitFor('the dialog with the name', () => find(/^/, { role: 'alertdialog' }), 10000);
  await sleep(1000);
  // The dialog's button, after the row's one it covers.
  await tap(new RegExp(`^${action}$`), { last: true });
}

test('a take is saved as a sound file, under its name', async () => {
  await openApp();
  await recordTake();
  await exportTake('Save');
  const saved = await waitFor('the file saved', async () => {
    const file = (await probe()).downloads[0];
    return file && file.size !== null ? file : null;
  }, 10000);
  assert.match(saved.name, /\.wav$/);
  assert.equal(saved.type, 'audio/wav');
  assert.ok(saved.size > 44 + 1000, `${saved.size} bytes: an empty take`);
  await waitFor('the take marked saved', () => find(/^Saved/), 10000);
  assert.deepEqual((await probe()).errors, []);
});

test('a take is shared as a sound file, from the touch', async () => {
  await openApp();
  await recordTake();
  await exportTake('Share');
  const shared = await waitFor('the take shared', async () => (await probe()).shares[0], 10000);
  assert.notEqual(shared.active, false, 'shared after the touch had ended: Safari refuses it');
  assert.equal(shared.files.length, 1);
  assert.match(shared.files[0].name, /\.wav$/);
  assert.equal(shared.files[0].type, 'audio/wav');
  assert.ok(shared.files[0].size > 44 + 1000, `${shared.files[0].size} bytes: an empty take`);
  assert.deepEqual((await probe()).errors, []);
});

test('a browser that cannot share says to save the file instead', async () => {
  await openApp({ storage: { iphoneShare: 'no' } });
  await recordTake();
  await exportTake('Share');
  // A notice at the top, read out by VoiceOver: in the page's text.
  await waitFor('the message', () => browser.run(() =>
    document.body.innerText.includes('cannot share audio files') ||
    [...document.querySelectorAll('flt-semantics')].some((e) => /cannot share audio files/.test(e.textContent + (e.getAttribute('aria-label') || '')))), 10000);
  assert.deepEqual((await probe()).errors, []);
});
