// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get takeDiscard => 'Abandonner';

  @override
  String get takeDelete => 'Supprimer la prise';

  @override
  String get takeRemove => 'Retirer du lecteur';

  @override
  String get takeRecord => 'Enregistrer';

  @override
  String get takeDeleted => 'Enregistrement supprimé';

  @override
  String get takeUndo => 'Annuler';

  @override
  String get takeStop => 'Arrêter';

  @override
  String get takeRecording => 'Enregistrement';

  @override
  String get takeTemporary => 'Temporaire';

  @override
  String get takeSave => 'Sauvegarder';

  @override
  String get takeShare => 'Partager';

  @override
  String get takeReplaceQuestion => 'Remplacer l’enregistrement temporaire ?';

  @override
  String get takeKeep => 'Garder';

  @override
  String get takeReplace => 'Remplacer';

  @override
  String get takeError => 'L’opération audio a échoué. Réessayez.';

  @override
  String get takeShareUnavailable =>
      'Ce navigateur ne peut pas partager de fichiers audio. Sauvegardez le fichier puis joignez-le dans WhatsApp.';

  @override
  String get takeSaved => 'Sauvegardé';

  @override
  String get takeStarting => 'Activation du micro…';

  @override
  String get appTitle => 'Low End';

  @override
  String get tunerTab => 'Accordeur';

  @override
  String get metronomeTab => 'Métronome';

  @override
  String get harmonyTab => 'Harmonie';

  @override
  String get metronomeStart => 'Démarrer le métronome';

  @override
  String get metronomeStop => 'Arrêter le métronome';

  @override
  String get metronomeHint => 'Touchez pour démarrer';

  @override
  String get tempoDial => 'Molette du tempo';

  @override
  String get tempoDialHint =>
      'Glissez dans le sens horaire pour augmenter le tempo ; antihoraire pour le réduire';

  @override
  String get tempoDialCaption => 'Tournez pour régler le tempo';

  @override
  String bpmValue(String bpm) {
    return '$bpm BPM';
  }

  @override
  String get timeSignature => 'Mesure';

  @override
  String get backgroundPlaying => 'Lecture en arrière-plan';

  @override
  String get sectionPlaying => 'En lecture';

  @override
  String get slower => 'Plus lent';

  @override
  String get faster => 'Plus rapide';

  @override
  String get tapTempo => 'Battez le tempo';

  @override
  String get droneStop => 'Arrêter l’harmonie';

  @override
  String get subdivisionLabel => 'Subdivision';

  @override
  String get progressionLabel => 'Progression';

  @override
  String get progressionMinorTwoFiveOne => 'II–V–I mineur';

  @override
  String get progressionBlues => 'Blues de 12 mesures';

  @override
  String progressionAndalusianLike(String song) {
    return 'Cadence andalouse, comme $song';
  }

  @override
  String progressionAnatoleLike(String song) {
    return 'L’Anatole, comme $song';
  }

  @override
  String get progressionCircleOfFifths => 'Cycle des quintes';

  @override
  String get progressionMinorBlues => 'Blues mineur';

  @override
  String progressionLike(String song) {
    return 'Comme $song';
  }

  @override
  String progressionGiroLike(String song) {
    return 'La progression des années 50, comme $song';
  }

  @override
  String get progressionSectionPopRock => 'Pop et rock';

  @override
  String get progressionSectionBlues => 'Blues';

  @override
  String get progressionSectionJazz => 'Jazz';

  @override
  String get thanksTitle => 'Remerciements';

  @override
  String get thanksInstagram => 'Suivez-les sur Instagram';

  @override
  String get thanksText =>
      'Merci au Power Flower Orchestra de Fossano, qui a inspiré cette app et l’a mise à l’épreuve.';

  @override
  String droneChordDiminished(String note) {
    return '$note diminué';
  }

  @override
  String get referencePitch => 'La de référence';

  @override
  String get lowerPitch => 'Baisser le La de référence';

  @override
  String get higherPitch => 'Monter le La de référence';

  @override
  String get choosePitch => 'Choisir un La de référence standard';

  @override
  String get pitchBaroque => 'Baroque';

  @override
  String get pitchVerdi => 'Verdi';

  @override
  String get pitchConcert => 'Diapason standard';

  @override
  String get pitchOrchestras => 'Orchestres';

  @override
  String referencePitchHint(String note) {
    return 'La fréquence du $note, pour l’accordeur et l’harmonie.';
  }

  @override
  String frequencyHz(String frequency) {
    return '$frequency Hz';
  }

  @override
  String stopSound(String name) {
    return 'Arrêter $name';
  }

  @override
  String playSound(String name) {
    return 'Jouer $name';
  }

  @override
  String get droneHint =>
      'Touchez une note pour la faire sonner. Touchez-la à nouveau pour l’arrêter.';

  @override
  String get chordLabel => 'Accord';

  @override
  String get noteAlone => 'La note seule';

  @override
  String get chordMajor => 'Majeur';

  @override
  String get chordMinor => 'Mineur';

  @override
  String get chordDominant => 'Septième de dominante (7)';

  @override
  String get chordDominantFlat9 => 'Septième de dominante ♭9 (7♭9)';

  @override
  String get chordMajor7 => 'Septième majeure (maj7)';

  @override
  String get chordMinor7 => 'Septième mineure (m7)';

  @override
  String get chordHalfDiminished => 'Demi-diminué (m7♭5)';

  @override
  String get chordDiminished => 'Diminué (dim)';

  @override
  String get chordSus4 => 'Quarte suspendue (sus4)';

  @override
  String droneChordHalfDiminished(String note) {
    return '$note demi-diminué';
  }

  @override
  String progressionInKey(String name, String key) {
    return '$name en $key';
  }

  @override
  String droneChordMajor(String note) {
    return '$note majeur';
  }

  @override
  String droneChordMinor(String note) {
    return '$note mineur';
  }

  @override
  String droneChordSeventh(String note) {
    return '${note}7';
  }

  @override
  String get audioUnavailable => 'Le son n’a pas pu démarrer sur cet appareil.';

  @override
  String get audioDownloadFailed =>
      'Les sons n’ont pas pu être téléchargés. Vérifiez la connexion et touchez à nouveau.';

  @override
  String get soundsPreparing => 'Préparation des sons…';

  @override
  String get soundsDownloadingSlowly =>
      'Téléchargement des sons : la connexion est lente. Patientez.';

  @override
  String get startListening => 'Écouter';

  @override
  String get stopListening => 'Pause';

  @override
  String get tunerWillPause => 'Écouter met en pause ce qui joue';

  @override
  String get tunerIdleHint => 'Accordeur en pause : touchez Écouter';

  @override
  String get playAString => 'Jouez une note';

  @override
  String get micPermissionDenied =>
      'Low End a besoin du micro pour entendre votre instrument. Si vous avez refusé, autorisez-le dans les paramètres du téléphone, sous Applications › Low End › Autorisations.';

  @override
  String get micPermissionDeniedWeb =>
      'Low End a besoin du micro pour entendre votre instrument. Si vous avez refusé, autorisez-le pour cette page dans les paramètres du navigateur, puis touchez à nouveau Écouter.';

  @override
  String get micUnavailable => 'Le micro n’a pas pu démarrer sur cet appareil.';

  @override
  String get inTune => 'Juste';

  @override
  String get flat => 'Trop bas';

  @override
  String get sharp => 'Trop haut';

  @override
  String get centsTitle => 'Cents';

  @override
  String centsValue(String cents) {
    return '$cents cents';
  }

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get settingsGeneral => 'Général';

  @override
  String get languageLabel => 'Langue';

  @override
  String get languageSystem => 'Comme le téléphone';

  @override
  String get noteNamesLabel => 'Noms des notes';

  @override
  String get noteNamesAuto => 'Selon la langue';

  @override
  String get noteNamesSolfege => 'Do Ré Mi';

  @override
  String get noteNamesLetters => 'C D E';

  @override
  String get circleLayoutLabel => 'Cercle de l’harmonie';

  @override
  String get circleLayoutFifths => 'Cycle des quintes';

  @override
  String get circleLayoutFifthsShort => 'Quintes';

  @override
  String get circleLayoutChromatic => 'Par demi-tons (Do, Do♯, Ré…)';

  @override
  String get circleLayoutChromaticShort => 'Demi-tons';

  @override
  String get aboutTooltip => 'À propos de Low End';

  @override
  String get aboutLegalese =>
      'Logiciel libre et open source, publié sous licence MIT.';

  @override
  String get aboutDescription =>
      'Métronome, harmonie et accordeur pour musiciens. Créée par un contrebassiste amateur en pensant aux amis de l’orchestre, et utile à tous. Low End fonctionne hors ligne. L’accordeur écoute sur votre appareil. Dans le lecteur, vous pouvez enregistrer, sauvegarder et partager votre audio.';

  @override
  String get aboutPiano =>
      'Sons du piano : Salamander Grand Piano d’Alexander Holm (domaine public).';

  @override
  String get aboutBass =>
      'Sons de la contrebasse : Meatbass de Karoryfer Lecolds, jouée par Drogomir Smolken (CC0, domaine public).';

  @override
  String styleButton(String style) {
    return 'Style : $style';
  }

  @override
  String get styleHeld => 'Accord à chaque mesure';

  @override
  String get styleBeat => 'Accord à chaque temps';

  @override
  String get styleArpeggio => 'Arpège';

  @override
  String get styleWalking => 'Walking bass';

  @override
  String styleTempo(String tempo, String signature) {
    return 'Suit le métronome : $tempo, $signature';
  }

  @override
  String get beatUnitQuarter => 'noire';

  @override
  String get beatUnitDottedQuarter => 'noire pointée';

  @override
  String get beatUnitEighth => 'croche';

  @override
  String get pausedForTuner => 'En pause pendant que vous accordez';

  @override
  String get pausedUnplugged => 'En pause : écouteurs débranchés';

  @override
  String get pausedInterrupted => 'En pause : le son a été interrompu';

  @override
  String get resume => 'Reprendre';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String get keepScreenOnTitle => 'Garder l’écran allumé';

  @override
  String get keepScreenOnSubtitle =>
      'Pendant la lecture ou l’écoute de l’accordeur';

  @override
  String get setTempo => 'Saisir le tempo';

  @override
  String get continuousToneTitle => 'Son tenu';

  @override
  String get continuousToneSubtitle =>
      'Un son fixe au lieu du piano frappé encore et encore.';

  @override
  String get octaveNumberingLabel => 'Numéros des octaves';

  @override
  String get octaveNumberingHint =>
      'Seul le numéro après le nom de la note change : la note est la même.';

  @override
  String get octaveScientific => 'Scientifique (par défaut)';

  @override
  String get octaveScientificShort => 'Scientifique';

  @override
  String get octaveItalian => 'Franco-belge';

  @override
  String octaveExamples(String a4, String e1) {
    return '$a4 = 440 Hz, le Mi grave de la basse est $e1';
  }

  @override
  String get tuningChromatic => 'Chromatique';

  @override
  String get tuningInstrument => 'Instrument';

  @override
  String get tempoLabel => 'Tempo';

  @override
  String get voicingLabel => 'Mode';

  @override
  String get voicingChordHint =>
      'Une note ou un accord, jusqu’à ce que vous l’arrêtiez';

  @override
  String get voicingProgressionHint =>
      'Des accords à la suite, en rythme avec le métronome';

  @override
  String get tuningChromaticHint =>
      'N’importe quelle note, sans choisir de corde';

  @override
  String get tuningGuitar => 'Guitare';

  @override
  String get tuningViolin => 'Violon';

  @override
  String get tuningViola => 'Alto';

  @override
  String get tuningCello => 'Violoncelle';

  @override
  String get tuningUkulele => 'Ukulélé';

  @override
  String get tuningBass => 'Basse';

  @override
  String tunerString(String number) {
    return 'Corde $number';
  }

  @override
  String tunerHeard(String note) {
    return 'Entendu : $note';
  }

  @override
  String get swipeHint =>
      'Glissez vers le haut ou le bas sur le cercle ou les onglets pour changer de section.';

  @override
  String get gesturesLockedTitle => 'Verrouiller les gestes';

  @override
  String get gesturesLockedSubtitle =>
      'Pour les répétitions : pas de glissement entre les sections';

  @override
  String get inTuneZoneTitle => 'Juste à moins de';

  @override
  String get inTuneZoneSubtitle =>
      'De combien une note peut s’écarter, en cents (centièmes de demi-ton), tout en restant juste';

  @override
  String get guideTitle => 'Gestes et raccourcis';

  @override
  String get guideRing =>
      'Chaque section démarre et s’arrête quand vous touchez le centre de son cercle. Dans Harmonie, touchez une note.';

  @override
  String get guideTempo =>
      'Maintenez − ou + et le tempo défile, de plus en plus vite.';

  @override
  String get guideSwipe =>
      'Glissez à gauche et à droite pour changer de section.';

  @override
  String get guideVolume =>
      'Le volume est celui du téléphone : utilisez ses touches.';

  @override
  String get guideDone => 'Compris';

  @override
  String writeAs(String note) {
    return 'Écrire $note';
  }

  @override
  String get progressionBluesShort => 'Blues';

  @override
  String keyLine(String progression, String key) {
    return '$progression en $key';
  }

  @override
  String keySheetTitle(String key) {
    return 'Tonalité : $key';
  }

  @override
  String get degreeName1 => 'Tonique';

  @override
  String get degreeName2 => 'Sus-tonique';

  @override
  String get degreeName3 => 'Médiante';

  @override
  String get degreeName4 => 'Sous-dominante';

  @override
  String get degreeName5 => 'Dominante';

  @override
  String get degreeName6 => 'Sus-dominante';

  @override
  String get degreeName7 => 'Sensible';

  @override
  String get degreeName7Minor => 'Sous-tonique';

  @override
  String get legendTitle => 'Légende';

  @override
  String get legendButton => 'Légende et degrés';

  @override
  String get legendRoot => 'Note qui sonne (la fondamentale)';

  @override
  String get legendChord => 'Autres notes de l’accord qui sonne';

  @override
  String get legendInKey => 'Notes de la tonalité';

  @override
  String get legendOutOfKey => 'Notes hors de la tonalité, estompées';

  @override
  String get legendNumerals =>
      'Les chiffres romains indiquent le degré de la tonalité sur lequel chaque accord est construit. Touchez-en un sur le cercle pour le lire ici.';

  @override
  String get legendDots =>
      'Les points sont les mesures de la progression : le point plein est l’accord qui sonne.';

  @override
  String get songsTitle => 'Morceaux d’exemple';

  @override
  String get songsSubtitle =>
      'Règle la tonalité, la progression, le tempo et le style d’un seul geste';

  @override
  String get tunerHeld => 'Dernière note gardée';

  @override
  String aboutSource(String url) {
    return 'Code source : $url';
  }

  @override
  String get subdivisionQuarters => 'Noires';

  @override
  String get subdivisionEighths => 'Croches';

  @override
  String get subdivisionSwungEighths => 'Croches swing';

  @override
  String get subdivisionTriplets => 'Triolets';

  @override
  String get subdivisionSixteenths => 'Doubles croches';

  @override
  String get subdivisionSwungSixteenths => 'Doubles croches swing';

  @override
  String get backbeatTitle => 'Clic sur 2 et 4';

  @override
  String get backbeatSubtitle =>
      'Les temps 1 et 3 se taisent, comme la charleston dans le jazz. En 2/4 et 4/4.';

  @override
  String get backbeatShort => '2 et 4';

  @override
  String get transpositionTitle => 'Instrument transpositeur';

  @override
  String get transpositionSubtitle =>
      'Pour les instruments en Si♭, Mi♭ et Fa, l’accordeur chromatique indique la note écrite';

  @override
  String get transpositionConcert => 'Son réel';

  @override
  String transpositionKey(String key) {
    return 'en $key';
  }

  @override
  String get playerTab => 'Écoute';

  @override
  String get playerTrack => 'Morceau';

  @override
  String get playerChoose => 'Choisissez un morceau';

  @override
  String get playerPlay => 'Lire';

  @override
  String get playerPause => 'Pause';

  @override
  String playerTimeOf(String position, String duration) {
    return '$position sur $duration';
  }

  @override
  String get pausedForPlayer => 'En pause pendant que vous écoutez';

  @override
  String get playerUnreadable => 'Ce fichier ne peut pas être ouvert.';

  @override
  String get playerMissing => 'Le fichier n’est plus disponible.';

  @override
  String get playerSpeed => 'Vitesse';

  @override
  String get playerCaptureStart => 'Marquer le début';

  @override
  String get playerCaptureEnd => 'Marquer la fin';

  @override
  String get playerLoopActive => 'Boucle active';

  @override
  String get playerResumeLoop => 'Réactiver';

  @override
  String get playerNewPassage => 'Nouveau passage';

  @override
  String get playerLoop => 'Boucle';

  @override
  String get playerMarkStart => 'Marquer le début ici';

  @override
  String get playerMarkEnd => 'Marquer la fin ici';

  @override
  String playerStartAt(String time) {
    return 'Début $time';
  }

  @override
  String playerEndAt(String time) {
    return 'Fin $time';
  }

  @override
  String get guidePlayerLoop =>
      'Dans le lecteur, marquez le début puis la fin en écoutant. Faites glisser A et B le long du cercle pour les déplacer ; sur la forme d’onde en dessous pour affiner.';
}
