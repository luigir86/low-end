# Contributing to Low End

Thanks for helping! Low End is a small, free app for musicians. Bug reports, translations and code are all welcome.

## Reporting a problem or an idea

Open an issue at https://github.com/luigir86/low-end/issues. For tuner problems, say which phone you use, which instrument and note, and whether you used the phone's microphone or an external one.

## Changing the code

1. Install [Flutter](https://docs.flutter.dev/get-started/install) and fork the repository. [docs/architecture.md](docs/architecture.md) explains how the app is built.
2. Make your change on a new branch.
3. Before opening a pull request, run:

   ```
   dart format lib test
   flutter analyze
   flutter test
   ```

4. Open a pull request explaining what changes for the player. If it changes what is on screen, update the user guides ([docs/user-guide.md](docs/user-guide.md) and [docs/manuale-utente.md](docs/manuale-utente.md)) and the texts in `lib/l10n/` too.

Keep the app light: please discuss in an issue before adding a new package, and avoid anything that tracks users or needs the internet.

## Look and feel

All colours, shapes and text styles live in `lib/app/theme.dart` and `lib/app/style.dart`. The app is always dark. Its colours come from one four-colour `BrandPalette` (brand, accent, dark, light) chosen by one constant, `LowEndBrand.palette` in `lib/app/brand.dart`: **Ebony & Bronze** is active (warm ebony `#18140F`, bronze `#D4A373`, ivory `#F1E8D5`); the earlier red palette stays available as `LowEndBrand.red`. Text on the accent adapts for contrast. Tuner verdict colours remain semantic and independent. No theme setting is exposed to users.

After changing the palette, run `flutter test tool/make_icons_test.dart` **before any local run/build/test**. It regenerates launcher/PWA/store icons, native Android backgrounds, HTML loader and manifest from the same constant as Flutter startup and controls. CI and Pages run this automatically, so a future colour-only PR can change just the constant. Generated files are also checked in as a convenient local starting point; regenerate after a colour-only pull. The approved lion drawing is unchanged; only its colours follow the palette.

`LowEndTheme.withAccent` builds previews with another accent. Screens consume `Theme.of(context)` and `LowEndColors.of(context)` without local colour choices. See [the four-colour themes](docs/specs/tema-ebano-bronzo.md), [icon and startup](docs/icona-avvio.md) and [style sheet](docs/style.md); superseded theme notes are in [docs/archivio/](docs/archivio/README.md). `test/theme_test.dart` checks both palettes and several accents for contrast, and native/web colour agreement.

## Accessibility

Every screen must work with TalkBack/VoiceOver, with the largest text size and without relying on colour alone. `test/accessibility_test.dart` checks touch targets, labels and contrast: add new screens to it.

## Translations

Texts live in `lib/l10n/app_en.arb` (English, the reference), `app_it.arb` (Italian), `app_es.arb` (Spanish) and `app_fr.arb` (French): a new text goes in all four. To add a language, copy `app_en.arb` to `app_<code>.arb`, translate the values and run `flutter gen-l10n`; add the language to `supportedLanguages` in `lib/app/settings.dart` and to the `language` enum of `settings_set` in `lib/actions/app_actions.dart`, and if it names notes its own way, add a value to `NoteNames` in `lib/audio/pitch.dart` (see [docs/architecture.md](docs/architecture.md)).

## Licence

By contributing you agree that your work is released under the [MIT License](LICENSE).
