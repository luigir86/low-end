# The web app (for iPhone and computers)

Low End also runs in a browser, from the same code as the Android app. On an iPhone it is added to the Home Screen and opens full screen, like an app, with no App Store. It is published for free on GitHub Pages:

**https://luigir86.github.io/low-end/**

The Android app stays the main one: the web app has the same four sections, but an iPhone does not let a web page do everything an app can (see *Limits*).

## Installing it

- **iPhone or iPad:** open the address in **Safari**, tap *Share* (the square with the arrow), then *Add to Home Screen*, and from then on open it from its icon. Safari 16.4 (iOS 16.4) or later. Best done at once, at the first opening: on an iPhone the app on the Home Screen keeps its files apart from Safari's, so what a Safari tab has kept is downloaded again for it. The app on the Home Screen also asks the phone to keep its files when space runs short (Safari may otherwise clear a site's files after some weeks without a visit); a page in a tab does not ask.
- **Android, Windows, Mac:** open it in Chrome or Edge; it works at once, and *Install app* in the browser's menu puts it among the apps.

The files are then kept on the phone: from the second opening it starts fast and works with no network. The very first opening reloads itself once, a moment after it appears, so that the sound is steady from the start (see *Sound* below). The recordings of the piano and the double bass (13 MB) are kept afterwards, in the background; until they all are, a sound not yet kept needs the network. A new version arrives by itself and is used from the opening after.

## Limits

| | Android app | Web app on iPhone |
| --- | --- | --- |
| Sound with the screen locked or in another app | Yes, with the media notification | No: iOS pauses the page's sound |
| Media notification, headphone buttons | Yes | No |
| Stops when the headphones come out | Yes | No |
| Beat light in time over Bluetooth | Yes (`AudioRoute`) | As far as the browser knows: the light waits for the delay the browser gives for its own sound (`SpeakerAudioRoute`) |
| Silent switch | Ignored (media volume) | Ignored too, with Safari's audio session (`web_audio_session.dart`) |
| Microphone permission | Asked once | iOS may ask again, even at every opening |
| "Open settings" after a no to the microphone | Yes | No: the message says where to allow it |
| Keeps the screen on | Yes | Yes, from iOS 18.4 for an app on the Home Screen |
| Player: choosing a file | Android's file chooser, the right to read the file is kept | The browser's file chooser, from a touch only (`player_open` fails); the track lasts as long as the page |
| Player with the screen locked or a call | Plays on with the notification; a call or another player pauses it | The page's audio element: it may play on where the engine's sound stops (not yet tried on an iPhone), and a call may pause it without the app being told, so the middle can say Pause while nothing sounds: two touches play it again |
| First opening | Instant | A few seconds (3.5 to 4 MB), then fast |
| Action links | `lowend://action/...` | `https://luigir86.github.io/low-end/#/action/...` |

## How it works

Nothing is a second app: `web/` holds the page, its icons (made by `tool/make_icons_test.dart`) and the start-up script, and a few classes have a web version.

- **Sound.** flutter_soloud ships the same engine compiled to WebAssembly. It has two builds: one mixes on its own thread (an AudioWorklet) and needs the page to be *cross-origin isolated*, the other mixes on the page's thread, where a slow frame can make it crackle. GitHub Pages cannot send the two headers isolation needs (COOP and COEP), so our service worker adds them. On the very first opening the worker only starts once the page is up: the page then reloads itself once, under the worker, unless a sound or the microphone has already started (`web/flutter_bootstrap.js`). So the steady build is used from the start, and the other only if the player touches play in that first moment. The worker takes over as soon as it keeps the app itself (3 MB, mostly already in the browser's cache), and only then the recordings, two at a time, asked for by the page a few seconds after each opening until they are all kept; they sit in a cache of their own, which a new version of the app keeps when they have not changed. Measured in Chromium: the page is isolated 7 s after it opens in 4G, 28 s in a slow 4G; before, the reload waited for all 17 MB, 22 s and 93 s.
- **Starting fast.** `web/flutter_bootstrap.js` loads the audio engine only after the first frame, so the dial appears without waiting for it; a sound asked for before then loads it at once (`lib/audio/web_audio_engine.dart`). The service worker keeps only the drawing engine and app build this browser uses (Flutter ships several engines, 37 MB together) and none of the audio engine's spare build.
- **The first sound.** A browser lets the audio engine sound only after a touch, but it may start before one, held silent. Once the page is isolated (from the second opening), the engine starts a moment after the first frame, once the sections are still (`LowEndApp`), and the first touch of any kind (a swipe, a menu, play itself) only wakes it (`web/flutter_bootstrap.js`), so the first sound need not wait for the engine. Measured in WebKit (Safari's engine) on a processor like an iPhone 11's, with the play touched 3 s after opening: the first click came 1.3 to 1.4 s after the touch when the engine started at the touch, 0.55 to 0.85 s now, and the first chord 0.65 to 0.9 s against 1.05 to 1.2 s (the walking progression, still mixing its loop then, 1.2 to 1.5 s against 1.4 to 2 s). After a sleep (see below) a touch wakes it in about a quarter of a second. In a page the engine warms up 100 ms before its first sound, against 300 ms on Android, where the speaker ramps up as it starts (`engineWarmUp`).
- **Asleep and interrupted.** With nothing to play the engine still mixes silence: 20 seconds after the last sound the page puts it to sleep, and the next touch wakes it. Safari on the iPhone also cuts the page's sound by itself, for a call, Siri, an alarm or the locked screen ("interrupted"): the app then stops what played and says so, with *Resume*, instead of looking as if it played on unheard (`SpeakerAudioRoute.interrupted`), and the next touch wakes the engine. Before each sound the app asks the page to wake the engine and waits until it plays (`ensureSoLoud`).
- **The engine's memory.** The engine's own thread shares its memory with the page, asked for with room to grow to 2 GB. Safari on the iPhone has refused shared memories that large (WebKit bug 255103), which would leave the app silent; `web/flutter_bootstrap.js` then asks again with room for 1 GB, then less: the engine needs far less (64 MB at start).
- **Drawing.** The app is built twice (`--wasm`), and Flutter's loader picks for each browser. Chrome, Edge and Samsung Internet run the app compiled to WebAssembly with Skwasm, which draws on its own thread when the page is isolated: the page's thread only builds the frames, so changing section and the turning strobe stay smoother. Safari (every browser on the iPhone) and Firefox run the JavaScript build with CanvasKit, which draws on the page's thread, as before. The service worker keeps only the pair this browser takes. Measured in Chromium with the processor slowed four times: over six changes of section the page's thread went from about 8 seconds of long tasks to none. While the sections slide, each section fades as one layer (`SectionFloat.page`), not its ring and each row apart: the browser blends two layers at each frame instead of eight.
- **Heavy work.** The piano's loops and the held tone are made in an isolate on the phone; a page has none, so `offThread` (`lib/audio/off_thread.dart`) makes them on the page's thread there. The loop a touch would play is mixed before the touch (`PianoOutput.prerender`, called by `DroneController.preparePiano` and again 0.4 s after the last change made while nothing plays); in a page a slice of a few milliseconds at a time (`lib/audio/in_steps.dart`), the screen drawn in between, and at full speed if the touch comes first. Measured in Chromium with the processor slowed twice (about a Galaxy S20 FE): the walking bass sounded 0.7 s after a touch 5 s after opening, against 3.2 s. The held tone is made by turning its waves a step at a time (no sine per sample: in a page each one is a call out to JavaScript), and the room (`Freeverb`) runs one filter at a time over the whole loop: the same sound, sample for sample (`test/same_sound_test.dart`). Getting the piano ready (decoding its recordings, a few seconds there) waits until the sections stop sliding (`AppNavigation.sliding`), and in a page the recordings then stay while it is open (`PianoOutput`), so that this happens once, with the finger still. Measured on a Galaxy S20 FE in Chrome over USB: the slide itself shows about 84 frames a second; the stall was this work, about 4 seconds on reaching the harmony.
- **Microphone.** The `record` package listens through the browser (getUserMedia) and gives the tuner the same 16 kHz samples, with automatic gain, echo cancelling and noise suppression switched off.
- **Where the sound goes.** `SpeakerAudioRoute` stands in for `AndroidAudioRoute`; `MediaNotificationAudio` does nothing on the web.
- **Links.** On the web the page address carries the action after `#`: `…/low-end/#/action/drone_play?note=A`. `LowEndApp` runs it as on Android, with the same rules, and puts the address back to the plain one so that a reload does not run it again.
- **Accessibility.** Flutter shows a web page to screen readers only when asked: `main.dart` asks at start.
- **No network after the first opening.** Everything comes from the site, nothing from Google's servers (`--no-web-resources-cdn`, `canvasKitBaseUrl` in `web/flutter_bootstrap.js`). `tool/web_offline.dart` writes `sw.js`, the service worker that keeps the files on the phone, and adds the COOP and COEP headers.

## Building and publishing

`.github/workflows/web.yml` builds and publishes the web app on every push to `main`. It needs GitHub Pages switched on once: *Settings › Pages › Build and deployment › Source: GitHub Actions*.

To build it by hand:

```
flutter build web --wasm --release --no-web-resources-cdn --base-href /low-end/
dart run tool/web_offline.dart build/web
```

To try it on the computer, `flutter run -d chrome` (no service worker, no isolation) or serve `build/web` under `/low-end/`.

## Trying it on an iPhone

Only a real iPhone tells how the web app sounds there; a Windows PC has no Safari. Things to check, in Safari and from the Home Screen:

1. The metronome at 80, 160 and 240: are the clicks even? Does it crackle when the screen changes (swiping between sections)?
2. With the silent switch on: is the click heard?
3. Harmony: how long does the first chord take? Do chords change on the beat?
4. Tuner: does it read a low E (41 Hz) and a high note? Does iOS ask for the microphone at every opening?
5. Lock the screen while it plays, then come back: does it show *Paused: the sound was interrupted*, and does *Resume* play again? The same with a call or an alarm.
6. Close it, turn on airplane mode, open it again: does it start?
7. Open it, wait a few seconds, then touch play: how long does the first click take? And after a minute with nothing playing?
8. With Spotify or Music playing, open the app and touch nothing: does the music go on? (It should stop only at the app's first sound.)
9. Close it and open it again several times: is there sound every time? (Safari's memory refusal would show from the second opening.)
