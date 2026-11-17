// Serves a web build as GitHub Pages does (under /low-end/, no COOP/COEP
// headers: the app's service worker adds them), with iphone.js put first in
// index.html: WebDriver has no way to run a script before the page's own.
// Usage: node server.mjs <build/web> [port]: port 0 (the default) takes a
// free one, printed as it starts. LOW_END_WEB_BROWSER=chrome leaves out the
// iPhone's own rules (navigator.audioSession), as Chrome on Android has none.
//
// The tests turn the site's state from outside the browser:
//   /__site?offline=1  every request fails, as with no network (0 back on);
//   /__site?version=2  a new version is published: its worker has a new
//                      version name, and index.html says it is version 2.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] ?? '../build/web');
const port = Number(process.argv[3] ?? 0);
const notIphone = process.env.LOW_END_WEB_BROWSER === 'chrome';
const shim = (notIphone ? 'window.__notIphone = true;\n' : '') +
  fs.readFileSync(new URL('./iphone.js', import.meta.url), 'utf8');
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png',
  '.flac': 'audio/flac', '.wav': 'audio/wav', '.otf': 'font/otf', '.ttf': 'font/ttf',
};
const site = { offline: false, version: 1 };

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/__site') {
    if (url.searchParams.has('offline')) site.offline = url.searchParams.get('offline') === '1';
    if (url.searchParams.has('version')) site.version = Number(url.searchParams.get('version'));
    res.writeHead(200, { 'Content-Type': 'application/json' });
    return res.end(JSON.stringify(site));
  }
  if (site.offline) return req.socket.destroy();
  if (url.pathname === '/low-end/__blank.html') {
    res.writeHead(200, { 'Content-Type': 'text/html' });
    return res.end('<!doctype html><title>blank</title>');
  }
  if (!url.pathname.startsWith('/low-end/')) {
    res.writeHead(302, { Location: '/low-end/' });
    return res.end();
  }
  let file = decodeURIComponent(url.pathname.slice('/low-end/'.length)) || 'index.html';
  if (file.endsWith('/')) file += 'index.html';
  const full = path.join(root, file);
  if (!full.startsWith(root)) { res.writeHead(403); return res.end(); }
  fs.readFile(full, (error, data) => {
    if (error) { res.writeHead(404); return res.end(); }
    let body = data;
    if (file === 'index.html') {
      body = Buffer.from(data.toString().replace('<head>',
        `<head><meta name="low-end-test-version" content="${site.version}"><script>${shim}</script>`));
    }
    if (file === 'sw.js' && site.version !== 1) {
      body = Buffer.from(data.toString().replace("const CACHE = 'low-end-", `const CACHE = 'low-end-v${site.version}-`));
    }
    res.writeHead(200, {
      'Content-Type': types[path.extname(full)] ?? 'application/octet-stream',
      'Cache-Control': 'no-cache',
    });
    res.end(body);
  });
}).listen(port, function () { console.log(`serving ${root} on ${this.address().port}`); });
