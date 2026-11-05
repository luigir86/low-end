# Release checklist (Google Play)

What the repository says, and what only the owner can check. "TO VERIFY"
marks anything that cannot be confirmed from the code.

## 1. Version and build

- [ ] `pubspec.yaml`: `version: 1.4.2+7` (name `1.4.2`, versionCode `7`).
      1.0.0+1 went to the closed test on 2026-10-19, 1.3.0+4 on 2026-10-29;
      1.4.0+5 (2026-11-05) stayed on "Preparing sounds", fixed in 1.4.1+6. The number after `+`
      must grow with every upload to Play.
- [ ] Target SDK: `flutter.targetSdkVersion` (36 with the current Flutter
      stable; minSdk 24, compileSdk 36). TO VERIFY in Play Console that 36 meets
      the current target-API deadline.
- [ ] Format: upload an **AAB**: `flutter build appbundle --release`
      (output: `build/app/outputs/bundle/release/app-release.aab`).
      The APK (`flutter build apk --release`) is for testing on the phone.
- [ ] `flutter build appbundle --release --analyze-size` once, to confirm that
      R8 / resource shrinking are active (the performance review could not
      confirm it; `build.gradle.kts` has no explicit minify setting).

## 2. Signing

- [ ] `android/app/build.gradle.kts` reads `android/key.properties`
      (git-ignored: `storeFile`, `storePassword`, `keyAlias`, `keyPassword`).
      With the file the release build is signed with that key; without it a
      release build stops with an error (`build.gradle.kts`), so nothing is
      signed with the debug key by mistake.
- [ ] In a git worktree `key.properties` is not present: copy it from the main
      checkout before building the AAB.
- [ ] TO VERIFY: the keystore (and its passwords) is backed up outside this PC
      and OneDrive-synced folders. Losing the upload key means a reset request
      to Play support. Enrol in Play App Signing when creating the app.
- [ ] After enrolment, the key in `key.properties` is the *upload* key; Play
      re-signs for users.

## 3. Permissions (AndroidManifest.xml) and how to justify them

| Permission | Why | Play declaration |
| --- | --- | --- |
| `RECORD_AUDIO` | The tuner listens to the instrument. Audio is analysed on the phone, never recorded or sent. Asked at run time, only for the tuner. | Data safety: no audio collected (processed on device only). |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | Metronome and harmony keep playing with the screen off (audio_service, type `mediaPlayback`). | Foreground-service form: type "Media playback"; core feature, user-started, shows a notification with the controls. |
| `POST_NOTIFICATIONS` | The foreground-service notification (Android 13+). | Nothing to declare beyond the above. |
| `WAKE_LOCK` | Keeps audio running with the screen off / screen on while playing. | Normal permission. |

- No `INTERNET` permission: the app cannot reach a network (docs/offline.md).
- `allowBackup="false"`; the exported service and receiver belong to
  audio_service (media controls). The `lowend://action/...` deep link only
  does what the on-screen buttons do (docs/llm.md).
- Compliance note: the foreground-service declaration in Play Console asks for
  a short video of the feature (start a sound, lock the screen, it keeps
  playing). TO VERIFY / to record by the owner.

## 4. Store listing

- [ ] Texts: `store/listing/en-US/` and `store/listing/it-IT/` (title ≤ 30,
      short ≤ 80, full ≤ 4000, release notes ≤ 500 characters; already within
      the limits, see store/README.md). Read them against
      `docs/specs/requisiti.md`: nothing promised that is not there, nothing
      said differently.
- [ ] Graphics: `store/graphics/icon-512.png`, feature graphic 1024×500 per
      language, phone screenshots in `store/graphics/phone/<locale>/`.
      Regenerate with
      `flutter test test_screenshots/store_screenshots_test.dart --update-goldens`
      only if the UI changes. TO VERIFY by eye that all screenshots (it and en)
      match the final UI.
- [ ] Privacy policy URL: Play needs a public URL. `PRIVACY.md` is in the
      repository; TO VERIFY that the repository (or a published page) is
      public and that the URL is entered in Play Console.
- [ ] Category, contact e-mail, content rating questionnaire, ads declaration
      (no ads), target audience: to be filled in by the owner.

## 5. Data safety form

Consistent with PRIVACY.md and the code (to be filled in by the owner):

- Data collected: **none**. Data shared: **none**.
- Microphone: processed on device, not stored, not sent: answer "no data
  collected".
- No accounts, no analytics, no ads, no crash reporting, no network.
- Settings kept in the app's own storage, removed with the app.
- Two links open outside the app (source code, the orchestra's Instagram);
  they leave the app through the browser and send nothing from the app.

## 6. Pre-upload checks

- [ ] `dart format --set-exit-if-changed lib test`, `flutter analyze`,
      `flutter test` green (CI runs the same).
- [ ] Release build installed on a real phone (Galaxy S20 FE tested by the
      developer): metronome, harmony (with the countdown), tuner and its
      "Resume" snackbar, screen off for a few minutes with sound playing,
      incoming call / headphones unplugged, Italian and English.
- [ ] Internal testing track first, then closed/open per Play's requirements
      for new personal accounts (TO VERIFY: the current testing requirements
      of the owner's developer account).

## 7. Known residual risks

- `ClickSound.bar` runs on the UI thread at each tempo, bar or subdivision
  change. Since 1.1.0 the clicks are made once and the WAV is written in one
  pass: about 5 ms for the slowest bar (30 BPM) on a desktop, three times
  less than before. Not measured on the phone.
- SoLoud is never de-initialised (negligible idle cost).
- Performance numbers are from code reading, not from `gfxinfo` on the
  phone (adb was not available to the review). Run
  `adb shell dumpsys gfxinfo com.luigir86.low_end` after a few minutes of play
  if you want a measure.
- The app has no crash reporting by design; the only feedback channel is the
  Play Console (Android vitals).
- Some audio devices may add latency (Bluetooth): not something the app can
  fix.
- Deep links `lowend://action/...` can be fired by any app on the phone; they
  only press the app's own buttons (no data is returned or read).
