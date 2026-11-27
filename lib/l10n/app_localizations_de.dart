// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get takeDiscard => 'Verwerfen';

  @override
  String get takeRecord => 'Aufnehmen';

  @override
  String get takeDeleted => 'Aufnahme verworfen';

  @override
  String get takeUndo => 'Rückgängig';

  @override
  String get takeStop => 'Stopp';

  @override
  String get takeRecording => 'Aufnahme';

  @override
  String get takeTemporary => 'Vorläufig';

  @override
  String get takeSave => 'Speichern';

  @override
  String get takeShare => 'Teilen';

  @override
  String get takeReplaceQuestion => 'Die vorläufige Aufnahme ersetzen?';

  @override
  String get takeKeep => 'Behalten';

  @override
  String get takeReplace => 'Ersetzen';

  @override
  String get takeError =>
      'Audiovorgang fehlgeschlagen. Bitte erneut versuchen.';

  @override
  String get takeShareUnavailable =>
      'Dieser Browser kann keine Audiodateien teilen. Speichere die Datei und hänge sie in WhatsApp an.';

  @override
  String get takeSaved => 'Gespeichert';

  @override
  String get takeStarting => 'Mikrofon wird gestartet…';

  @override
  String takeFileName(int number, String date) {
    return 'Aufnahme${number}_$date';
  }

  @override
  String get takeNameLabel => 'Dateiname';

  @override
  String get appTitle => 'Low End';

  @override
  String get tunerTab => 'Stimmgerät';

  @override
  String get metronomeTab => 'Metronom';

  @override
  String get harmonyTab => 'Harmonie';

  @override
  String get metronomeStart => 'Metronom starten';

  @override
  String get metronomeStop => 'Metronom stoppen';

  @override
  String get metronomeHint => 'Zum Starten tippen';

  @override
  String get tempoDial => 'Temporad';

  @override
  String get tempoDialHint =>
      'Im Uhrzeigersinn ziehen, um das Tempo zu erhöhen; gegen den Uhrzeigersinn, um es zu verringern';

  @override
  String get tempoDialCaption => 'Drehen für das Tempo';

  @override
  String bpmValue(String bpm) {
    return '$bpm BPM';
  }

  @override
  String get timeSignature => 'Taktart';

  @override
  String get backgroundPlaying => 'Spielt im Hintergrund';

  @override
  String get sectionPlaying => 'Spielt';

  @override
  String get slower => 'Langsamer';

  @override
  String get faster => 'Schneller';

  @override
  String get tapTempo => 'Tempo tippen';

  @override
  String get droneStop => 'Harmonie stoppen';

  @override
  String get subdivisionLabel => 'Unterteilung';

  @override
  String get progressionLabel => 'Akkordfolge';

  @override
  String get progressionMinorTwoFiveOne => 'II–V–I in Moll';

  @override
  String get progressionBlues => '12-taktiger Blues';

  @override
  String progressionAndalusianLike(String song) {
    return 'Andalusische Kadenz, wie $song';
  }

  @override
  String progressionAnatoleLike(String song) {
    return 'Anatole, wie $song';
  }

  @override
  String get progressionCircleOfFifths => 'Quintenzirkel';

  @override
  String get progressionMinorBlues => 'Moll-Blues';

  @override
  String progressionLike(String song) {
    return 'Wie $song';
  }

  @override
  String progressionGiroLike(String song) {
    return '50er-Jahre-Folge, wie $song';
  }

  @override
  String get progressionSectionPopRock => 'Pop und Rock';

  @override
  String get progressionSectionBlues => 'Blues';

  @override
  String get progressionSectionJazz => 'Jazz';

  @override
  String get thanksTitle => 'Danke';

  @override
  String get thanksInstagram => 'Folge ihnen auf Instagram';

  @override
  String get thanksText =>
      'Danke an das Power Flower Orchestra aus Fossano, das diese App angeregt und auf die Probe gestellt hat.';

  @override
  String droneChordDiminished(String note) {
    return '$note vermindert';
  }

  @override
  String get referencePitch => 'Kammerton A';

  @override
  String get lowerPitch => 'Kammerton A senken';

  @override
  String get higherPitch => 'Kammerton A erhöhen';

  @override
  String get choosePitch => 'Einen üblichen Kammerton wählen';

  @override
  String get pitchBaroque => 'Barock';

  @override
  String get pitchVerdi => 'Verdi';

  @override
  String get pitchConcert => 'Normalstimmton';

  @override
  String get pitchOrchestras => 'Orchester';

  @override
  String referencePitchHint(String note) {
    return 'Die Frequenz von $note, für das Stimmgerät und die Harmonie.';
  }

  @override
  String frequencyHz(String frequency) {
    return '$frequency Hz';
  }

  @override
  String stopSound(String name) {
    return '$name stoppen';
  }

  @override
  String playSound(String name) {
    return '$name spielen';
  }

  @override
  String get droneHint => 'Zum Starten eine Note tippen';

  @override
  String get chordLabel => 'Akkord';

  @override
  String get noteAlone => 'Nur der Ton';

  @override
  String get chordMajor => 'Dur';

  @override
  String get chordMinor => 'Moll';

  @override
  String get chordDominant => 'Dominantseptakkord (7)';

  @override
  String get chordDominantFlat9 => 'Dominantseptakkord mit ♭9 (7♭9)';

  @override
  String get chordMajor7 => 'Großer Septakkord (maj7)';

  @override
  String get chordMinor7 => 'Moll-Septakkord (m7)';

  @override
  String get chordHalfDiminished => 'Halbvermindert (m7♭5)';

  @override
  String get chordDiminished => 'Vermindert (dim)';

  @override
  String get chordSus4 => 'Vorhaltsquarte (sus4)';

  @override
  String droneChordHalfDiminished(String note) {
    return '$note halbvermindert';
  }

  @override
  String progressionInKey(String name, String key) {
    return '$name in $key';
  }

  @override
  String droneChordMajor(String note) {
    return '$note-Dur';
  }

  @override
  String droneChordMinor(String note) {
    return '$note-Moll';
  }

  @override
  String droneChordSeventh(String note) {
    return '${note}7';
  }

  @override
  String get audioUnavailable =>
      'Der Ton konnte auf diesem Gerät nicht starten.';

  @override
  String get audioDownloadFailed =>
      'Die Klänge konnten nicht geladen werden. Prüfe die Verbindung und tippe erneut.';

  @override
  String get soundsPreparing => 'Klänge werden vorbereitet…';

  @override
  String get soundsDownloadingSlowly =>
      'Die Klänge werden geladen: Die Verbindung ist langsam. Bitte warten.';

  @override
  String get startListening => 'Hören';

  @override
  String get stopListening => 'Pause';

  @override
  String get tunerWillPause => 'Hören pausiert, was gerade spielt';

  @override
  String get tunerIdleHint => 'Stimmgerät pausiert: Tippe auf Hören';

  @override
  String get playAString => 'Spiele einen Ton';

  @override
  String get micPermissionDenied =>
      'Low End braucht das Mikrofon, um dein Instrument zu hören. Falls du abgelehnt hast, erlaube es in den Einstellungen des Telefons unter Apps › Low End › Berechtigungen.';

  @override
  String get micPermissionDeniedWeb =>
      'Low End braucht das Mikrofon, um dein Instrument zu hören. Falls du abgelehnt hast, erlaube es dieser Seite in den Browsereinstellungen und tippe dann erneut auf Hören.';

  @override
  String get micUnavailable =>
      'Das Mikrofon konnte auf diesem Gerät nicht starten.';

  @override
  String get inTune => 'Gestimmt';

  @override
  String get flat => 'Zu tief';

  @override
  String get sharp => 'Zu hoch';

  @override
  String get centsTitle => 'Cent';

  @override
  String centsValue(String cents) {
    return '$cents Cent';
  }

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsGeneral => 'Allgemein';

  @override
  String get languageLabel => 'Sprache';

  @override
  String get languageSystem => 'Wie das Telefon';

  @override
  String get noteNamesLabel => 'Notennamen';

  @override
  String get noteNamesAuto => 'Wie die Sprache';

  @override
  String get noteNamesSolfege => 'Do Re Mi';

  @override
  String get noteNamesLetters => 'C D E';

  @override
  String get noteNamesGerman => 'C D E … H';

  @override
  String get circleLayoutLabel => 'Harmonie-Kreis';

  @override
  String get circleLayoutFifths => 'Quintenzirkel';

  @override
  String get circleLayoutFifthsShort => 'Quinten';

  @override
  String get circleLayoutChromatic => 'In Halbtönen (C, C♯, D…)';

  @override
  String get circleLayoutChromaticShort => 'Halbtöne';

  @override
  String get aboutTooltip => 'Über Low End';

  @override
  String get aboutLegalese =>
      'Freie Open-Source-Software unter der MIT-Lizenz.';

  @override
  String get aboutDescription =>
      'Metronom, Harmonie und Stimmgerät für Musiker. Gemacht von einem Hobby-Kontrabassisten mit den Freunden aus dem Orchester im Sinn, und nützlich für alle. Low End funktioniert offline. Das Stimmgerät hört auf deinem Gerät zu. Im Player kannst du eigene Aufnahmen machen, speichern und teilen.';

  @override
  String get aboutPiano =>
      'Klavierklänge: Salamander Grand Piano von Alexander Holm (gemeinfrei).';

  @override
  String get aboutBass =>
      'Kontrabassklänge: Meatbass von Karoryfer Lecolds, gespielt von Drogomir Smolken (CC0, gemeinfrei).';

  @override
  String styleButton(String style) {
    return 'Stil: $style';
  }

  @override
  String get styleHeld => 'Akkord jeden Takt';

  @override
  String get styleBeat => 'Akkord auf jedem Schlag';

  @override
  String get styleArpeggio => 'Arpeggio';

  @override
  String get styleWalking => 'Walking Bass';

  @override
  String styleTempo(String tempo, String signature) {
    return 'Folgt dem Metronom: $tempo, $signature';
  }

  @override
  String get beatUnitQuarter => 'Viertelnote';

  @override
  String get beatUnitDottedQuarter => 'punktierte Viertelnote';

  @override
  String get beatUnitEighth => 'Achtelnote';

  @override
  String get pausedInterrupted => 'Pausiert: Der Ton wurde unterbrochen';

  @override
  String get resume => 'Fortsetzen';

  @override
  String get openSettings => 'Einstellungen öffnen';

  @override
  String get keepScreenOnTitle => 'Bildschirm anlassen';

  @override
  String get keepScreenOnSubtitle =>
      'Solange etwas spielt oder das Stimmgerät hört';

  @override
  String get setTempo => 'Tempo eingeben';

  @override
  String get continuousToneTitle => 'Gehaltener Ton';

  @override
  String get continuousToneSubtitle =>
      'Ein gleichmäßiger Ton statt des immer neu angeschlagenen Klaviers.';

  @override
  String get octaveNumberingLabel => 'Oktavnummern';

  @override
  String get octaveNumberingHint =>
      'Nur die Zahl nach dem Notennamen: derselbe Ton, eine andere Zahl.';

  @override
  String get octaveScientific => 'Wissenschaftlich (Standard)';

  @override
  String get octaveScientificShort => 'Wissenschaftlich';

  @override
  String get octaveItalian => 'Italienisch';

  @override
  String octaveExamples(String a4, String e1) {
    return '$a4 = 440 Hz, das tiefe E des Basses ist $e1';
  }

  @override
  String get tuningChromatic => 'Chromatisch';

  @override
  String get tuningInstrument => 'Instrument';

  @override
  String get tempoLabel => 'Tempo';

  @override
  String get voicingLabel => 'Modus';

  @override
  String get voicingChordHint => 'Ein Ton oder Akkord, bis du ihn stoppst';

  @override
  String get voicingProgressionHint =>
      'Akkorde nacheinander, im Takt des Metronoms';

  @override
  String get tuningChromaticHint => 'Jeder Ton, ohne Saitenwahl';

  @override
  String get tuningGuitar => 'Gitarre';

  @override
  String get tuningViolin => 'Violine';

  @override
  String get tuningViola => 'Bratsche';

  @override
  String get tuningCello => 'Cello';

  @override
  String get tuningUkulele => 'Ukulele';

  @override
  String get tuningBass => 'Bass';

  @override
  String tunerString(String number) {
    return 'Saite $number';
  }

  @override
  String tunerHeard(String note) {
    return 'Gehört: $note';
  }

  @override
  String get swipeHint =>
      'Wische über dem Kreis oder den Tabs nach oben oder unten, um den Bereich zu wechseln.';

  @override
  String get gesturesLockedTitle => 'Gesten sperren';

  @override
  String get gesturesLockedSubtitle =>
      'Für die Probe: kein Wischen zwischen den Bereichen';

  @override
  String get inTuneZoneTitle => 'Gestimmt innerhalb';

  @override
  String get inTuneZoneSubtitle =>
      'Wie weit ein Ton abweichen darf, in Cent (Hundertstel eines Halbtons), und noch als gestimmt gilt';

  @override
  String get guideTitle => 'Gesten und Abkürzungen';

  @override
  String get guideRing =>
      'Jeder Bereich startet und stoppt, wenn du die Mitte seines Kreises berührst. In Harmonie berühre eine Note.';

  @override
  String get guideTempo =>
      'Halte − oder + gedrückt und das Tempo läuft, immer schneller.';

  @override
  String get guideSwipe =>
      'Wische nach links und rechts, um den Bereich zu wechseln.';

  @override
  String get guideVolume =>
      'Die Lautstärke ist die des Telefons: Nutze seine Lautstärketasten.';

  @override
  String get guideDone => 'Verstanden';

  @override
  String writeAs(String note) {
    return 'Als $note schreiben';
  }

  @override
  String get progressionBluesShort => 'Blues';

  @override
  String barOfBars(int bar, int count) {
    return 'Takt $bar von $count';
  }

  @override
  String keyLine(String progression, String key) {
    return '$progression in $key';
  }

  @override
  String keySheetTitle(String key) {
    return 'Tonart: $key';
  }

  @override
  String get degreeName1 => 'Tonika';

  @override
  String get degreeName2 => 'Supertonika';

  @override
  String get degreeName3 => 'Mediante';

  @override
  String get degreeName4 => 'Subdominante';

  @override
  String get degreeName5 => 'Dominante';

  @override
  String get degreeName6 => 'Submediante';

  @override
  String get degreeName7 => 'Leitton';

  @override
  String get degreeName7Minor => 'Subtonika';

  @override
  String get legendTitle => 'Legende';

  @override
  String get legendButton => 'Legende und Stufen';

  @override
  String get legendRoot => 'Klingender Ton (der Grundton)';

  @override
  String get legendChord => 'Weitere Töne des klingenden Akkords';

  @override
  String get legendInKey => 'Töne der Tonart';

  @override
  String get legendOutOfKey => 'Töne außerhalb der Tonart, blass';

  @override
  String get legendNumerals =>
      'Die römischen Zahlen nennen die Stufe der Tonart, auf der jeder Akkord steht. Tippe eine auf dem Kreis an, um sie hier zu lesen.';

  @override
  String get legendBars =>
      'In der Mitte stehen die Takte der Akkordfolge als römische Ziffern, in Reihen zu vier wie auf einem Leadsheet: Der fett gedruckte ist der klingende Takt.';

  @override
  String get songsTitle => 'Beispielstücke';

  @override
  String get songsSubtitle =>
      'Stellt Tonart, Akkordfolge, Tempo und Stil mit einem Tipp ein';

  @override
  String get tunerHeld => 'Letzter Ton gehalten';

  @override
  String aboutSource(String url) {
    return 'Quellcode: $url';
  }

  @override
  String get aboutRate => 'Low End auf Google Play bewerten';

  @override
  String get subdivisionQuarters => 'Viertel';

  @override
  String get subdivisionEighths => 'Achtel';

  @override
  String get subdivisionSwungEighths => 'Swing-Achtel';

  @override
  String get subdivisionTriplets => 'Triolen';

  @override
  String get subdivisionSixteenths => 'Sechzehntel';

  @override
  String get subdivisionSwungSixteenths => 'Swing-Sechzehntel';

  @override
  String get backbeatTitle => 'Klick auf 2 und 4';

  @override
  String get backbeatSubtitle =>
      'Schläge 1 und 3 bleiben stumm, wie die Hi-Hat im Jazz. In 2/4 und 4/4.';

  @override
  String get backbeatShort => '2 & 4';

  @override
  String get transpositionTitle => 'Transponierendes Instrument';

  @override
  String get transpositionSubtitle =>
      'Für Instrumente in B, Es und F zeigt das chromatische Stimmgerät den notierten Ton';

  @override
  String get transpositionConcert => 'Klingend';

  @override
  String transpositionKey(String key) {
    return 'in $key';
  }

  @override
  String get playerTab => 'Player';

  @override
  String get playerTrack => 'Stück';

  @override
  String get playerChoose => 'Ein Stück wählen';

  @override
  String get playerPlay => 'Abspielen';

  @override
  String get playerPause => 'Pause';

  @override
  String playerTimeOf(String position, String duration) {
    return '$position von $duration';
  }

  @override
  String get playerUnreadable => 'Diese Datei lässt sich nicht öffnen.';

  @override
  String get playerMissing => 'Die Datei ist nicht mehr verfügbar.';

  @override
  String get playerSpeed => 'Tempo';

  @override
  String get playerCaptureStart => 'Start setzen';

  @override
  String get playerCaptureEnd => 'Ende setzen';

  @override
  String get playerLoopActive => 'Schleife aktiv';

  @override
  String get playerResumeLoop => 'Schleife an';

  @override
  String get playerNewPassage => 'Neue Stelle';

  @override
  String get playerLoop => 'Schleife';

  @override
  String get playerMarkStart => 'Start hier setzen';

  @override
  String get playerMarkEnd => 'Ende hier setzen';

  @override
  String playerStartAt(String time) {
    return 'Start $time';
  }

  @override
  String playerEndAt(String time) {
    return 'Ende $time';
  }

  @override
  String get guidePlayerLoop =>
      'Tippe im Player beim Hören auf Start setzen und Ende setzen. Ziehe A und B am Kreis entlang, um sie zu verschieben; auf der Wellenform darunter zum Feinjustieren.';
}
