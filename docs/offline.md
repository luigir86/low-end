# Low End needs no internet

Checked on 16 October 2026, on the release build made from this code. Repeat the checks below before every release.

## Result

**The app has no way to use the network.** No `INTERNET` (or `ACCESS_NETWORK_STATE`) permission is in the release APK, there is no networking code in the app, and nothing is downloaded while it runs. Without that permission Android itself blocks any connection from the app.

## What was checked

1. **Permissions of the release APK** (the merged manifest, including everything the libraries add):

   ```
   aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk
   ```

   With the Player (ExoPlayer, which `just_audio` brings), the merged manifest would also hold `ACCESS_NETWORK_STATE`, which the library declares to stream; `android/app/src/main/AndroidManifest.xml` removes it with `tools:node="remove"`. Check the merged manifest after every dependency change: `find build/app -path '*merged_manifest*' -name AndroidManifest.xml`. The Player opens files chosen with the system's chooser (`content://`), never an address on the network.

   The only permissions are `RECORD_AUDIO` (tuner), `WAKE_LOCK`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` and `POST_NOTIFICATIONS` (playing with the screen off), and the app's own `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`, which AndroidX adds to protect its internal receivers. There is no network permission.

2. **Debug and profile builds.** `android/app/src/debug/AndroidManifest.xml` and `android/app/src/profile/AndroidManifest.xml` add `INTERNET`, because Flutter's tools (hot reload, the debugger, `--trace-startup`) talk to the running app through it. Those files are used only by `flutter run` and never by `flutter build apk --release` or `appbundle`; the release manifest above shows it.

3. **The app's code** (`lib/`): no `dart:io` networking, no `http`, no sockets, no `Image.network`, no `google_fonts`. The only web addresses are two links the player taps: *Source code* in About and *Follow them on Instagram* under Thanks in the settings (the page of the Power Flower Orchestra of Fossano). Each hands its address to the phone's browser (`url_launcher`); the app itself connects to nothing.

4. **Libraries.** Some packages in the dependency tree know about the network (`http` and `flutter_cache_manager` come with `audio_service`, which can fetch cover art). The app never gives them an address, the Dart compiler leaves unused code out, and a search of the release `classes.dex` finds no use of `HttpURLConnection`, `URLConnection`, `Socket`, `HttpsURLConnection` or OkHttp.

5. **Fonts and assets.** Edwin and Noto Music are bundled in the app (`assets/fonts/`); nothing is fetched at run time. The piano sounds are bundled too (`assets/piano/`), and every other sound is made in memory.

## Check it yourself

```
flutter build apk --release
aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk
```

must list no `INTERNET`. On a phone, *Settings → Apps → Low End → Mobile data and Wi-Fi* shows no data used, and with airplane mode on every feature works the same.

## The web app

The web app ([web.md](web.md)) is fetched once from GitHub Pages, like any website, and its service worker then keeps every file on the device: from the second opening it starts with airplane mode on. It is built with `--no-web-resources-cdn` and `canvasKitBaseUrl`, so even the drawing engine comes from the site and not from Google's servers. To check it, open the browser's developer tools on the *Network* tab: every request goes to `luigir86.github.io`, and none after the files are kept.

## Why it matters

It is what [PRIVACY.md](../PRIVACY.md) promises, and the Google Play *Data safety* answer ("no data collected or shared") rests on it. If a future feature ever needs the network, add the permission deliberately, update this page, the privacy policy and the Play declaration first.
