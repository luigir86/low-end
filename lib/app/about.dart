import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import 'version.dart';

const sourceCodeUrl = 'https://github.com/luigir86/low-end';

/// Low End's page on Google Play, where the stars and the reviews are given.
/// Google's rules: a button may only lead to the store (it never opens the
/// in-app review window) and never asks for a given number of stars.
const playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.luigir86.low_end';

/// The Instagram page of the Power Flower Orchestra of Fossano.
const orchestraUrl = 'https://www.instagram.com/powerflowerorchestra/';

/// Opens [url] in the browser; nothing happens if the phone has none.
Future<void> openLink(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (error) {
    debugPrint('Link could not be opened: $error');
  }
}

/// The About dialog: what the app does, its licence, and the licences of the
/// open-source packages it is built with (the MIT and BSD licences ask for
/// their notices to ship with the app).
void showLowEndAbout(BuildContext context) {
  final l10n = AppLocalizations.of(context);
  showAboutDialog(
    context: context,
    applicationName: l10n.appTitle,
    applicationVersion: appVersionLabel,
    applicationIcon: ExcludeSemantics(
      child: Image.asset('assets/brand/logo.png', width: 80, height: 80),
    ),
    applicationLegalese: l10n.aboutLegalese,
    children: [
      const SizedBox(height: 16),
      Text(l10n.aboutDescription),
      const SizedBox(height: 8),
      Text(l10n.aboutPiano),
      Text(l10n.aboutBass),
      const SizedBox(height: 8),
      // A link, not a text to copy from.
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => openLink(sourceCodeUrl),
          icon: const Icon(Icons.open_in_new, size: 18),
          label: Text(l10n.aboutSource(sourceCodeUrl)),
        ),
      ),
      // Only the Android app is on Google Play; the web app has no store.
      if (!kIsWeb)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const Key('rateLink'),
            onPressed: () => openLink(playStoreUrl),
            icon: const Icon(Icons.star_outline, size: 18),
            label: Text(l10n.aboutRate),
          ),
        ),
    ],
  );
}
