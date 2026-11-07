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

All colours, shapes and text styles live in `lib/app/theme.dart` and `lib/app/style.dart`: two internal palettes, Wood&Brass and Anthracite & Red (the app is always dark, with no theme to choose; see [docs/specs/varianti-tema.md](docs/specs/varianti-tema.md), in Italian), and the tuner verdict colours. [docs/style.md](docs/style.md) is the style sheet: sizes, shapes and the layout of the three sections. Screens take them from the theme (`Theme.of(context)`, `LowEndColors.of(context)`) and never write a colour of their own. Change `LowEndTheme.variant` and rebuild to switch the product palette. The launcher and startup use the shared `LowEndBrand` mark and red, independently of the interface palette (see [icon and startup](docs/icona-avvio.md)). `Palette.startup` remains the neutral app background and browser chrome. `test/theme_test.dart` checks native/web branding and both palettes for contrast.

## Accessibility

Every screen must work with TalkBack/VoiceOver, with the largest text size and without relying on colour alone. `test/accessibility_test.dart` checks touch targets, labels and contrast: add new screens to it.

## Translations

Texts live in `lib/l10n/app_en.arb` (English, the reference), `app_it.arb` (Italian), `app_es.arb` (Spanish) and `app_fr.arb` (French): a new text goes in all four. To add a language, copy `app_en.arb` to `app_<code>.arb`, translate the values and run `flutter gen-l10n`; add the language to `supportedLanguages` in `lib/app/settings.dart` and to the `language` enum of `settings_set` in `lib/actions/app_actions.dart`, and if it names notes its own way, add a value to `NoteNames` in `lib/audio/pitch.dart` (see [docs/architecture.md](docs/architecture.md)).

## Licence

By contributing you agree that your work is released under the [MIT License](LICENSE).
