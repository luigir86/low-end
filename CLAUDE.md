# Low End (Flutter, Android)

A free metronome, piano harmony ("Armonia", `drone` in the code), tuner and track player for musicians. No backend, no network, no tracking. Architecture: `docs/architecture.md`; actions for assistants: `docs/llm.md`.

## Commands

```
flutter pub get
flutter gen-l10n          # after editing lib/l10n/*.arb (generated Dart files are committed)
dart format lib test      # always before committing
flutter analyze
flutter test              # or one file: flutter test test/app_actions_test.dart
flutter test test/app_actions_test.dart --update-goldens   # regenerates docs/llm-actions.json
flutter build web --wasm --release --no-web-resources-cdn   # the web app for iPhone (docs/web.md)
```

## Structure

- `lib/app/` shell, settings, theme (always dark, bronze), guide; `lib/features/{metronome,tuner,harmony,songs,player}/` controllers + screens; `lib/audio/` sound and microphone behind interfaces with silent/fake twins for tests; `lib/actions/app_actions.dart` the action layer; `lib/l10n/` English (reference), Italian, Spanish and French.
- State is plain `ChangeNotifier` controllers passed by `AudioScope`; no state-management package.

## Product rules (keep them true)

- Four sections (metronome, Harmony, tuner, Player); tabs only navigate. Each section starts/stops its own sound from the centre of its dial. No balance setting.
- Entering the tuner stops nothing; touching the tuner dial (or `tuner_start`) pauses the metronome and Harmony with a "Resume" snackbar.
- The Player plays alone: starting it pauses the metronome and Harmony with a "Resume" snackbar; starting either of them pauses the Player; touching the tuner dial pauses it too.
- Harmony started while the click plays enters on the metronome's bar line with a countdown (and vice versa).
- "Lock gestures" only disables swiping between sections.
- The web app (`web/`, docs/web.md) is the same code: anything Android-only (MethodChannel, `dart:io`, `Isolate.run`) needs a web path too; check it with the web build.

## Conventions

- Anything the player can do must also be an action in `lib/actions/app_actions.dart`; if you change an action or its description, regenerate `docs/llm-actions.json` and update `docs/llm.md`.
- Every user-visible text goes in all four `.arb` files (en, it, es, fr); never hard-code strings or colours (use the theme).
- Add new screens to `test/accessibility_test.dart`. Tests use the silent/fake outputs, no phone needed.

## Known traps

- Files use CRLF on this Windows setup (`core.autocrlf=true`): edit tools that match multi-line text may fail; the actions golden test tolerates CRLF.
- The working clone on the PC is `C:\Users\ribal\Projects\LowEnd`, outside OneDrive; the old copies under OneDrive are obsolete. The upload key lives outside the repository (see `android/key.properties`): never move or delete it.
- `lib/l10n/app_localizations*.dart` are generated: change the `.arb` and run `flutter gen-l10n`, never edit them by hand.
- Python is not installed; use Dart or shell for scripts. Flutter is in `C:\src\flutter\bin`.
- Work in the worktree/branch you were given; do not stash or reset.
