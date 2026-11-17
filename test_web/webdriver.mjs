// A small W3C WebDriver client for WebKitWebDriver, which drives WebKitGTK's
// MiniBrowser: Safari's engine on Linux.
import { spawn } from 'node:child_process';

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

/// Each browser gets a port of its own: a driver started on the port of
/// the one just closed found it still taken now and then, and exited.
let nextPort = 4444;

export class WebKit {
  /// [features]: WebKit settings to switch on or off, as '+Name' or '-Name'.
  static async start({ port = nextPort++, features = [] } = {}) {
    const driver = spawn('WebKitWebDriver', [`--port=${port}`], {
      env: { ...process.env, DISPLAY: process.env.DISPLAY ?? ':99' },
      stdio: 'ignore',
    });
    const base = `http://127.0.0.1:${port}`;
    let up = false;
    for (let i = 0; i < 100 && !up; i++) {
      try { await fetch(`${base}/status`); up = true; } catch { await sleep(100); }
    }
    if (!up) {
      driver.kill();
      throw new Error(`WebKitWebDriver did not start on port ${port}`);
    }
    const args = [
      '--automation',
      '--enable-media-stream=true',
      '--enable-mock-capture-devices=true',
      '--enable-write-console-messages-to-stdout=true',
    ];
    if (features.length) args.push(`--features=${features.join(',')}`);
    const binary = process.env.MINIBROWSER ??
      '/usr/lib/x86_64-linux-gnu/webkit2gtk-4.1/MiniBrowser';
    const reply = await (await fetch(`${base}/session`, {
      method: 'POST',
      body: JSON.stringify({ capabilities: { alwaysMatch: {
        browserName: 'MiniBrowser',
        'webkitgtk:browserOptions': { binary, args },
      } } }),
    })).json();
    const id = reply.value?.sessionId;
    if (!id) throw new Error(`No WebKit session: ${JSON.stringify(reply).slice(0, 300)}`);
    const browser = new WebKit();
    browser.driver = driver;
    browser.base = `${base}/session/${id}`;
    return browser;
  }

  async command(method, path, body) {
    const response = await fetch(this.base + path, {
      method, body: body === undefined ? undefined : JSON.stringify(body),
    });
    const json = await response.json().catch(() => ({}));
    if (json.value?.error) throw new Error(`${json.value.error}: ${json.value.message}`);
    return json.value;
  }

  go(url) { return this.command('POST', '/url', { url }); }

  /// Runs [fn] in the page with [args] and returns what it returns.
  run(fn, ...args) {
    return this.command('POST', '/execute/sync', {
      script: `return (${fn}).apply(null, arguments)`, args,
    });
  }

  /// Like [run], waiting for the promise [fn] returns.
  runAsync(fn, ...args) {
    return this.command('POST', '/execute/async', {
      script: `const done = arguments[arguments.length - 1];
        Promise.resolve((${fn}).apply(null, Array.from(arguments).slice(0, -1)))
          .then(done, (e) => done({ error: String(e) }));`,
      args,
    });
  }

  setWindow(width, height) {
    return this.command('POST', '/window/rect', { width, height, x: 0, y: 0 });
  }

  /// A tap, as the mouse: WebKitGTK turns WebDriver touches into it anyway.
  tap(x, y) {
    return this.command('POST', '/actions', { actions: [{
      type: 'pointer', id: 'finger', parameters: { pointerType: 'mouse' },
      actions: [
        { type: 'pointerMove', duration: 0, x: Math.round(x), y: Math.round(y), origin: 'viewport' },
        { type: 'pointerDown', button: 0 },
        { type: 'pause', duration: 60 },
        { type: 'pointerUp', button: 0 },
      ],
    }] });
  }

  async screenshot(file) {
    const png = await this.command('GET', '/screenshot');
    (await import('node:fs')).writeFileSync(file, Buffer.from(png, 'base64'));
  }

  async quit() {
    try { await fetch(this.base, { method: 'DELETE' }); } catch {}
    if (this.driver.exitCode !== null || this.driver.signalCode !== null) return;
    const exited = new Promise((resolve) => this.driver.once('exit', resolve));
    this.driver.kill();
    await Promise.race([exited, sleep(5000)]);
  }
}

/// The same, for Chrome through ChromeDriver: the browser of the Android
/// phones that open the web app. Sound only after a touch, as on a phone;
/// the microphone allowed without asking, a fake one that plays a tone.
/// CHROMEDRIVER names the driver (GitHub's runners give its folder in
/// CHROMEWEBDRIVER), CHROME the browser.
export class Chrome extends WebKit {
  static async start({ port = 4445 } = {}) {
    const binary = process.env.CHROMEDRIVER ??
      (process.env.CHROMEWEBDRIVER ? `${process.env.CHROMEWEBDRIVER}/chromedriver` : 'chromedriver');
    const driver = spawn(binary, [`--port=${port}`], { stdio: 'ignore' });
    const base = `http://127.0.0.1:${port}`;
    for (let i = 0; i < 100; i++) {
      try { await fetch(`${base}/status`); break; } catch { await sleep(100); }
    }
    const options = {
      args: [
        '--headless=new',
        '--no-sandbox',
        '--window-size=412,915',
        '--autoplay-policy=user-gesture-required',
        '--use-fake-ui-for-media-stream',
        '--use-fake-device-for-media-stream',
      ],
    };
    if (process.env.CHROME) options.binary = process.env.CHROME;
    const reply = await (await fetch(`${base}/session`, {
      method: 'POST',
      body: JSON.stringify({ capabilities: { alwaysMatch: {
        browserName: 'chrome', 'goog:chromeOptions': options,
      } } }),
    })).json();
    const id = reply.value?.sessionId;
    if (!id) throw new Error(`No Chrome session: ${JSON.stringify(reply).slice(0, 300)}`);
    const browser = new Chrome();
    browser.driver = driver;
    browser.base = `${base}/session/${id}`;
    return browser;
  }

  /// A tap as a finger: Chrome passes WebDriver touches on as touches.
  tap(x, y) {
    return this.command('POST', '/actions', { actions: [{
      type: 'pointer', id: 'finger', parameters: { pointerType: 'touch' },
      actions: [
        { type: 'pointerMove', duration: 0, x: Math.round(x), y: Math.round(y), origin: 'viewport' },
        { type: 'pointerDown', button: 0 },
        { type: 'pause', duration: 60 },
        { type: 'pointerUp', button: 0 },
      ],
    }] });
  }
}
