import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';

const sourceCodeUrl = 'https://github.com/luigir86/low-end';

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
    ],
  );
}
