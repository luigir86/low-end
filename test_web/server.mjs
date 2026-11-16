// Serves a web build as GitHub Pages does (under /low-end/, no COOP/COEP
// headers: the app's service worker adds them), with iphone.js put first in
// index.html: WebDriver has no way to run a script before the page's own.
// Usage: node server.mjs <build/web> [port]: port 0 (the default) takes a
// free one, printed as it starts.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';

const root = path.resolve(process.argv[2] ?? '../build/web');
const port = Number(process.argv[3] ?? 0);
const shim = fs.readFileSync(new URL('./iphone.js', import.meta.url), 'utf8');
const types = {
  '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.wasm': 'application/wasm', '.json': 'application/json', '.png': 'image/png',
  '.flac': 'audio/flac', '.wav': 'audio/wav', '.otf': 'font/otf', '.ttf': 'font/ttf',
};

http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
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
      body = Buffer.from(data.toString().replace('<head>', `<head><script>${shim}</script>`));
    }
    res.writeHead(200, {
      'Content-Type': types[path.extname(full)] ?? 'application/octet-stream',
      'Cache-Control': 'no-cache',
    });
    res.end(body);
  });
}).listen(port, function () { console.log(`serving ${root} on ${this.address().port}`); });
