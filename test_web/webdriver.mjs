// A small W3C WebDriver client for WebKitWebDriver, which drives WebKitGTK's
// MiniBrowser: Safari's engine on Linux.
import { spawn } from 'node:child_process';

export const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

export class WebKit {
  /// [features]: WebKit settings to switch on or off, as '+Name' or '-Name'.
  static async start({ port = 4444, features = [] } = {}) {
    const driver = spawn('WebKitWebDriver', [`--port=${port}`], {
      env: { ...process.env, DISPLAY: process.env.DISPLAY ?? ':99' },
      stdio: 'ignore',
    });
    const base = `http://127.0.0.1:${port}`;
    for (let i = 0; i < 100; i++) {
      try { await fetch(`${base}/status`); break; } catch { await sleep(100); }
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
    this.driver.kill();
  }
}
