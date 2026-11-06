# Google Play release kit

Everything the Play Console asks for, ready to copy. Nothing here is built into the app.

```
store/
  listing/<locale>/      en-US, it-IT, es-ES, fr-FR: title, short and full description, release notes
  graphics/icon-512.png  app icon (512 × 512)
  graphics/<locale>/feature-graphic-1024x500.png  (text: tool/feature_graphic_text_test.dart)
  graphics/phone/<locale>/*.png   phone screenshots (1156 × 2312), four per language
```

Default language of the listing: English (United States), with Italian (Italy), Spanish (Spain, es-ES) and French (France, fr-FR) as translations. Spanish and French were written by Claude: have a musician who speaks each language read them before publishing.

## Build the bundle

```bash
flutter build appbundle --release
```

The file is `build/app/outputs/bundle/release/app-release.aab`. It is signed with the **upload key** read from `android/key.properties` (git-ignored; see `android/app/build.gradle.kts`). Without that file a release build stops with an error, so an APK signed with the debug key can never be shared by mistake.

**Keep the keystore and its passwords safe and backed up outside the repository**. Enrol in *Play App Signing* when you create the app: Google keeps the real app-signing key, and the upload key can be replaced through Play support if it is ever lost.

Raise `version:` in `pubspec.yaml` (the number after `+` must grow with every upload) and `appVersion` in `lib/app/version.dart` (shown in About; `version_test` keeps them equal) before each new bundle.

## Store listing

The texts in `listing/` describe the app to the people on Google Play; what it does is written in [docs/specs/requisiti.md](../docs/specs/requisiti.md), and before each release the texts are read against it (see the release checklist): what they promise must be there, as the requirements say it.

| Field | Value |
| --- | --- |
| App name | Low End: Metronome & Tuner (it: Low End: Metronomo Accordatore; es: Low End: Metrónomo y Afinador; fr: Low End: Métronome & Accordeur) |
| Category | Music & Audio |
| Free or paid | Free |
| Contains ads | No |
| Contact email | ribaluigi@gmail.com |
| Website | https://github.com/luigir86/low-end |
| Privacy policy | https://github.com/luigir86/low-end/blob/main/PRIVACY.md |

## App content (declarations)

- **Data safety**: the app collects **no data** and shares none. The microphone is processed on the phone and never stored or sent; the app has no network access (no `INTERNET` permission). Answer "No" to "Does your app collect or share any of the required user data types?". Data is not encrypted in transit because nothing is in transit.
- **Permissions to explain**: `RECORD_AUDIO` (tuner), `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (metronome and harmony keep playing with the screen off, with a notification), `POST_NOTIFICATIONS` (that notification), `WAKE_LOCK` (keeps playback running; keeps the screen on if the player asks).
- **Foreground service declaration**: type *Media playback*. Short video to attach: start the metronome, lock the screen, show the notification.
- **Content rating** (IARC questionnaire): no violence, no sexual content, no gambling, no user-generated content, no sharing of location. Expected result: PEGI 3 / Everyone.
- **Target audience**: 13 and over is the simplest choice (no ads, no data, but it is not aimed at children). Choosing "under 13" would add the Families policy requirements.
- **Ads**: none. **News app**: no. **Government app**: no. **Financial features**: none. **Health features**: none.
- **Open source**: MIT, source at https://github.com/luigir86/low-end (it is in the description). Third-party licences: [THIRD_PARTY_NOTICES.md](../THIRD_PARTY_NOTICES.md).
- **Trader status** (EU, asked again in the new Console form from November 2026): Low End is free, with no ads, no purchases and no donations, published by a private person, so the expected answer is "not a trader". Only the owner can make this declaration; a trader must show an address and a phone number on the listing.

## Play policy check (October 2026 update)

Checked against the manifest and the code on 2026-10-30; nothing to change in the app.

- Local network, manage contacts, location, all files access, SMS / call log, accessibility API: the app asks for none of them (see the permissions above).
- AppFunctions: the app has none. The `lowend://action/...` links are ordinary deep links that do only what the buttons do (docs/llm.md); if Android AppFunctions are added later, each must describe its action truthfully and do nothing more.
- Subscriptions, payments, cryptocurrency, Japan payments authorisation: no purchases of any kind.
- Play Age Signals: optional API, not needed (no content or feature depends on age).
- App quality thresholds for memory and code optimisation (February 2027): the release build relies on Flutter's default R8 shrinking; check Android vitals and the app quality page in Play Console once before the deadline.

## Before going to production

New personal developer accounts must run a **closed test with at least 12 testers opted in for 14 days in a row** before they can apply for production access. Upload the bundle to the closed-testing track first, invite the testers by email or a Google Group, and apply for production when the 14 days are done.

## Checks made

- Licences of all dependencies: permissive (MIT, BSD, Apache-2.0, zlib, public domain); see THIRD_PARTY_NOTICES.md.
- Known vulnerabilities (OSV database): none in the 108 Dart packages or the 88 external Android libraries.
- Manifest: no `INTERNET`, backup off, only the launcher activity, the `lowend://` action link, the media service and its button receiver are exported.
- The `lowend://action/...` links can start the sound or bring up the tuner from any web page or app. They do only what the buttons do, the microphone needs the permission the player gave and a visible tuner screen, and nothing leaves the phone, so this is documented rather than blocked (docs/llm.md).

## Updating the listing

- Texts are in `store/listing/<locale>/`: title (30 characters at most), short description (80), full description (4000), release notes (500). They describe the app for every musician; the double bass appears only in the line saying who made it.
- Feature graphics: change the line in `tool/feature_graphic_text_test.dart` and run `flutter test tool/feature_graphic_text_test.dart`.
- Phone screenshots (1156 × 2312): `flutter test test_screenshots/store_screenshots_test.dart --update-goldens` writes them into `store/graphics/phone/<locale>/`.
- The proof that the app needs no internet is in [docs/offline.md](../docs/offline.md); the privacy policy URL above points to [PRIVACY.md](../PRIVACY.md), which is also in Italian (Play accepts one URL for every language).
