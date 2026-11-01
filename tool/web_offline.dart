// Writes sw.js into a web build: the service worker that keeps the web app's
// files on the phone, so that it opens fast and works with no network.
//   flutter build web --wasm --release --no-web-resources-cdn --base-href /low-end/
//   dart run tool/web_offline.dart build/web
// The deploy workflow (.github/workflows/web.yml) runs both.
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = Directory(args.isEmpty ? 'build/web' : args.first);
  if (!root.existsSync()) {
    stderr.writeln('No web build in ${root.path}: run flutter build web.');
    exit(1);
  }
  final files = <String>[];
  var hash = _fnvOffset;
  final all = root.listSync(recursive: true).whereType<File>().toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  for (final file in all) {
    final path = file.path
        .substring(root.path.length + 1)
        .replaceAll(Platform.pathSeparator, '/');
    if (!_kept(path)) continue;
    files.add(path);
    hash = _fnv(hash, utf8.encode(path));
    hash = _fnv(hash, file.readAsBytesSync());
  }
  for (final path in _engines.values.expand((paths) => paths)) {
    if (!File('${root.path}/$path').existsSync()) {
      stderr.writeln('$path is missing: the worker could not keep it.');
      exit(1);
    }
  }
  final version = hash.toRadixString(16).padLeft(8, '0');
  File('${root.path}/sw.js')
      .writeAsStringSync(_worker(version, ['./', ...files]));
  stdout.writeln('sw.js: version $version, ${files.length} files kept.');
}

/// Whether the phone keeps [path] as soon as the app is installed. Of the
/// drawing engine's builds (37 MB together) and of the app's two builds
/// (WebAssembly and JavaScript) only the browser's own are kept, chosen by
/// the worker itself (see _engines). The audio engine's
/// single-threaded build is used only before the worker takes over, when
/// the page is not isolated; if a browser ever keeps using it, the worker
/// keeps it the first time it is asked for. The sources and build scripts
/// that flutter_soloud ships next to its WebAssembly are never asked for.
bool _kept(String path) =>
    !path.startsWith('canvaskit/') &&
    !path.startsWith('main.dart.') &&
    !const {
      '.last_build_id',
      'flutter_service_worker.js',
      'sw.js',
      'assets/packages/flutter_soloud/web/libflutter_soloud_plugin.js',
      'assets/packages/flutter_soloud/web/libflutter_soloud_plugin.wasm',
    }.contains(path) &&
    !const ['.sh', '.bat', '.dart', '.deps', '.map'].any(path.endsWith);

/// The builds the worker picks from, as Flutter's loader does. Chrome, Edge
/// and Samsung Internet take the app compiled to WebAssembly and Skwasm, the
/// drawing engine that draws on its own thread: smoother, since the page's
/// thread is left to the app. Safari (every browser on the iPhone) and
/// Firefox take the app in JavaScript and the full CanvasKit, as before.
/// A Chrome too old for WebAssembly's garbage collector (before 119) falls
/// back to the JavaScript build, which the worker then keeps when asked.
const _engines = {
  'chromium': [
    'main.dart.mjs',
    'main.dart.wasm',
    'canvaskit/skwasm.js',
    'canvaskit/skwasm.wasm',
  ],
  'full': [
    'main.dart.js',
    'canvaskit/canvaskit.js',
    'canvaskit/canvaskit.wasm',
  ],
};

// FNV-1a, 32 bits: enough to tell one build from the next.
const _fnvOffset = 0x811c9dc5;

int _fnv(int hash, List<int> bytes) {
  for (final b in bytes) {
    hash = ((hash ^ b) * 0x01000193) & 0xffffffff;
  }
  return hash;
}

String _worker(String version, List<String> files) =>
    '''
// Made by tool/web_offline.dart: do not edit.
// Keeps Low End's files on the phone. A new version is kept whole before it
// takes over, and the old one is then thrown away.
const CACHE = 'low-end-$version';
const FILES = ${const JsonEncoder.withIndent('  ').convert(files)};

// The app and drawing engine this browser takes, as Flutter chooses them:
// WebAssembly and Skwasm in Chrome, Edge and Samsung Internet, JavaScript
// and the full CanvasKit in Safari (also on the iPhone) and Firefox.
const ENGINE = /Chrome\\//.test(self.navigator.userAgent)
  ? ${jsonEncode(_engines['chromium'])}
  : ${jsonEncode(_engines['full'])};

self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE)
      .then((cache) => cache.addAll([...FILES, ...ENGINE]))
      .then(() => self.skipWaiting()),
  );
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys
        .filter((key) => key.startsWith('low-end-') && key !== CACHE)
        .map((key) => caches.delete(key))))
      .then(() => self.clients.claim()),
  );
});

// Every file is given the two headers that GitHub Pages cannot send
// (COOP and COEP): with them the page is "cross-origin isolated", and the
// audio engine mixes on its own thread (an AudioWorklet) instead of the
// screen's, where a busy frame could make it crackle. The first opening,
// before this worker runs, goes without.
function isolated(response) {
  if (response.type === 'opaque') return response;
  const headers = new Headers(response.headers);
  headers.set('Cross-Origin-Opener-Policy', 'same-origin');
  headers.set('Cross-Origin-Embedder-Policy', 'require-corp');
  return new Response(response.body, {
    status: response.status,
    statusText: response.statusText,
    headers,
  });
}

// What is kept comes from the phone; anything else from the site, and is
// kept for next time.
self.addEventListener('fetch', (event) => {
  const request = event.request;
  if (request.method !== 'GET') return;
  if (new URL(request.url).origin !== self.location.origin) return;
  event.respondWith(caches.open(CACHE).then(async (cache) => {
    const kept = await cache.match(request, { ignoreSearch: true });
    if (kept) return isolated(kept);
    const response = await fetch(request);
    if (response.ok) cache.put(request, response.clone());
    return isolated(response);
  }));
});
''';
