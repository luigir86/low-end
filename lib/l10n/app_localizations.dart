import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Low End'**
  String get appTitle;

  /// No description provided for @tunerTab.
  ///
  /// In en, this message translates to:
  /// **'Tuner'**
  String get tunerTab;

  /// No description provided for @metronomeTab.
  ///
  /// In en, this message translates to:
  /// **'Metronome'**
  String get metronomeTab;

  /// No description provided for @harmonyTab.
  ///
  /// In en, this message translates to:
  /// **'Harmony'**
  String get harmonyTab;

  /// No description provided for @metronomeStart.
  ///
  /// In en, this message translates to:
  /// **'Start the metronome'**
  String get metronomeStart;

  /// No description provided for @metronomeStop.
  ///
  /// In en, this message translates to:
  /// **'Stop the metronome'**
  String get metronomeStop;

  /// No description provided for @metronomeHint.
  ///
  /// In en, this message translates to:
  /// **'Tap to start'**
  String get metronomeHint;

  /// No description provided for @bpmValue.
  ///
  /// In en, this message translates to:
  /// **'{bpm} BPM'**
  String bpmValue(String bpm);

  /// No description provided for @timeSignature.
  ///
  /// In en, this message translates to:
  /// **'Time signature'**
  String get timeSignature;

  /// No description provided for @backgroundPlaying.
  ///
  /// In en, this message translates to:
  /// **'Playing in the background'**
  String get backgroundPlaying;

  /// Said by screen readers on the tab of a section that is sounding, where a dot shows it.
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get sectionPlaying;

  /// No description provided for @slower.
  ///
  /// In en, this message translates to:
  /// **'Slower'**
  String get slower;

  /// No description provided for @faster.
  ///
  /// In en, this message translates to:
  /// **'Faster'**
  String get faster;

  /// No description provided for @tapTempo.
  ///
  /// In en, this message translates to:
  /// **'Tap the tempo'**
  String get tapTempo;

  /// No description provided for @droneStop.
  ///
  /// In en, this message translates to:
  /// **'Stop the harmony'**
  String get droneStop;

  /// No description provided for @subdivisionLabel.
  ///
  /// In en, this message translates to:
  /// **'Subdivision'**
  String get subdivisionLabel;

  /// No description provided for @progressionLabel.
  ///
  /// In en, this message translates to:
  /// **'Progression'**
  String get progressionLabel;

  /// No description provided for @progressionMinorTwoFiveOne.
  ///
  /// In en, this message translates to:
  /// **'II–V–I minor'**
  String get progressionMinorTwoFiveOne;

  /// No description provided for @progressionBlues.
  ///
  /// In en, this message translates to:
  /// **'12-bar blues'**
  String get progressionBlues;

  /// Under I–♭VII–♭VI–V in the progression menu: its name and a well-known song that uses it.
  ///
  /// In en, this message translates to:
  /// **'Andalusian cadence, like {song}'**
  String progressionAndalusianLike(String song);

  /// Under I–VI–II–V in the progression menu: its name among jazz musicians (the Anatole, the A section of rhythm changes) and a well-known song that uses it.
  ///
  /// In en, this message translates to:
  /// **'The Anatole, like {song}'**
  String progressionAnatoleLike(String song);

  /// No description provided for @progressionCircleOfFifths.
  ///
  /// In en, this message translates to:
  /// **'Circle of fifths'**
  String get progressionCircleOfFifths;

  /// No description provided for @progressionMinorBlues.
  ///
  /// In en, this message translates to:
  /// **'Minor blues'**
  String get progressionMinorBlues;

  /// A well-known song that uses the progression, under its name in the progression menu.
  ///
  /// In en, this message translates to:
  /// **'Like {song}'**
  String progressionLike(String song);

  /// Under I–VI–IV–V in the progression menu: its common name (in Italian, the giro di Do) and a well-known song that uses it.
  ///
  /// In en, this message translates to:
  /// **'The ’50s progression, like {song}'**
  String progressionGiroLike(String song);

  /// No description provided for @progressionSectionPopRock.
  ///
  /// In en, this message translates to:
  /// **'Pop and rock'**
  String get progressionSectionPopRock;

  /// No description provided for @progressionSectionBlues.
  ///
  /// In en, this message translates to:
  /// **'Blues'**
  String get progressionSectionBlues;

  /// No description provided for @progressionSectionJazz.
  ///
  /// In en, this message translates to:
  /// **'Jazz'**
  String get progressionSectionJazz;

  /// No description provided for @thanksTitle.
  ///
  /// In en, this message translates to:
  /// **'Thanks'**
  String get thanksTitle;

  /// No description provided for @thanksInstagram.
  ///
  /// In en, this message translates to:
  /// **'Follow them on Instagram'**
  String get thanksInstagram;

  /// No description provided for @thanksText.
  ///
  /// In en, this message translates to:
  /// **'Thanks to the Power Flower Orchestra of Fossano, who inspired this app and put it to the test.'**
  String get thanksText;

  /// No description provided for @droneChordDiminished.
  ///
  /// In en, this message translates to:
  /// **'{note} diminished'**
  String droneChordDiminished(String note);

  /// No description provided for @referencePitch.
  ///
  /// In en, this message translates to:
  /// **'Reference A'**
  String get referencePitch;

  /// No description provided for @lowerPitch.
  ///
  /// In en, this message translates to:
  /// **'Lower the reference A'**
  String get lowerPitch;

  /// No description provided for @higherPitch.
  ///
  /// In en, this message translates to:
  /// **'Raise the reference A'**
  String get higherPitch;

  /// No description provided for @choosePitch.
  ///
  /// In en, this message translates to:
  /// **'Choose a standard reference A'**
  String get choosePitch;

  /// No description provided for @pitchBaroque.
  ///
  /// In en, this message translates to:
  /// **'Baroque'**
  String get pitchBaroque;

  /// No description provided for @pitchVerdi.
  ///
  /// In en, this message translates to:
  /// **'Verdi'**
  String get pitchVerdi;

  /// No description provided for @pitchConcert.
  ///
  /// In en, this message translates to:
  /// **'Concert pitch'**
  String get pitchConcert;

  /// No description provided for @pitchOrchestras.
  ///
  /// In en, this message translates to:
  /// **'Orchestras'**
  String get pitchOrchestras;

  /// No description provided for @referencePitchHint.
  ///
  /// In en, this message translates to:
  /// **'The frequency of {note}, for the tuner and the harmony.'**
  String referencePitchHint(String note);

  /// No description provided for @frequencyHz.
  ///
  /// In en, this message translates to:
  /// **'{frequency} Hz'**
  String frequencyHz(String frequency);

  /// No description provided for @stopSound.
  ///
  /// In en, this message translates to:
  /// **'Stop {name}'**
  String stopSound(String name);

  /// No description provided for @playSound.
  ///
  /// In en, this message translates to:
  /// **'Play {name}'**
  String playSound(String name);

  /// No description provided for @droneHint.
  ///
  /// In en, this message translates to:
  /// **'Touch a note to play it. Touch it again to stop.'**
  String get droneHint;

  /// No description provided for @chordLabel.
  ///
  /// In en, this message translates to:
  /// **'Chord'**
  String get chordLabel;

  /// No description provided for @noteAlone.
  ///
  /// In en, this message translates to:
  /// **'Note alone'**
  String get noteAlone;

  /// No description provided for @chordMajor.
  ///
  /// In en, this message translates to:
  /// **'Major'**
  String get chordMajor;

  /// No description provided for @chordMinor.
  ///
  /// In en, this message translates to:
  /// **'Minor'**
  String get chordMinor;

  /// No description provided for @chordDominant.
  ///
  /// In en, this message translates to:
  /// **'Dominant 7th (7)'**
  String get chordDominant;

  /// No description provided for @chordDominantFlat9.
  ///
  /// In en, this message translates to:
  /// **'Dominant 7th ♭9 (7♭9)'**
  String get chordDominantFlat9;

  /// No description provided for @chordMajor7.
  ///
  /// In en, this message translates to:
  /// **'Major 7th (maj7)'**
  String get chordMajor7;

  /// No description provided for @chordMinor7.
  ///
  /// In en, this message translates to:
  /// **'Minor 7th (m7)'**
  String get chordMinor7;

  /// No description provided for @chordHalfDiminished.
  ///
  /// In en, this message translates to:
  /// **'Half-diminished (m7♭5)'**
  String get chordHalfDiminished;

  /// No description provided for @chordDiminished.
  ///
  /// In en, this message translates to:
  /// **'Diminished (dim)'**
  String get chordDiminished;

  /// No description provided for @chordSus4.
  ///
  /// In en, this message translates to:
  /// **'Suspended 4th (sus4)'**
  String get chordSus4;

  /// The half-diminished seventh chord (m7♭5) in the middle of the drone dial.
  ///
  /// In en, this message translates to:
  /// **'{note} half-diminished'**
  String droneChordHalfDiminished(String note);

  /// In the media notification while a progression plays: its name and the key it is in, such as II–V–I in G. It does not change as the chords do.
  ///
  /// In en, this message translates to:
  /// **'{name} in {key}'**
  String progressionInKey(String name, String key);

  /// The chord in the middle of the drone dial, such as A major.
  ///
  /// In en, this message translates to:
  /// **'{note} major'**
  String droneChordMajor(String note);

  /// No description provided for @droneChordMinor.
  ///
  /// In en, this message translates to:
  /// **'{note} minor'**
  String droneChordMinor(String note);

  /// No description provided for @droneChordSeventh.
  ///
  /// In en, this message translates to:
  /// **'{note}7'**
  String droneChordSeventh(String note);

  /// No description provided for @audioUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sound could not start on this device.'**
  String get audioUnavailable;

  /// Web app: the sound failed to start, almost always because a download failed.
  ///
  /// In en, this message translates to:
  /// **'The sounds could not be downloaded. Check the connection and touch again.'**
  String get audioDownloadFailed;

  /// Harmony hub, between the touch and the first chord heard.
  ///
  /// In en, this message translates to:
  /// **'Getting the sounds ready…'**
  String get soundsPreparing;

  /// Web app: the first chord has been on its way for more than 5 seconds.
  ///
  /// In en, this message translates to:
  /// **'Downloading the sounds: the connection is slow. Please wait.'**
  String get soundsDownloadingSlowly;

  /// No description provided for @startListening.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get startListening;

  /// No description provided for @stopListening.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get stopListening;

  /// No description provided for @tunerWillPause.
  ///
  /// In en, this message translates to:
  /// **'Listening pauses what is playing'**
  String get tunerWillPause;

  /// No description provided for @tunerIdleHint.
  ///
  /// In en, this message translates to:
  /// **'Tuner paused: tap Listen'**
  String get tunerIdleHint;

  /// No description provided for @playAString.
  ///
  /// In en, this message translates to:
  /// **'Play a note'**
  String get playAString;

  /// No description provided for @micPermissionDenied.
  ///
  /// In en, this message translates to:
  /// **'Low End needs the microphone to hear your instrument. If you said no, allow it in the phone settings under Apps › Low End › Permissions.'**
  String get micPermissionDenied;

  /// No description provided for @micPermissionDeniedWeb.
  ///
  /// In en, this message translates to:
  /// **'Low End needs the microphone to hear your instrument. If you said no, allow it for this page in the browser settings, then tap Listen again.'**
  String get micPermissionDeniedWeb;

  /// No description provided for @micUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The microphone could not start on this device.'**
  String get micUnavailable;

  /// No description provided for @inTune.
  ///
  /// In en, this message translates to:
  /// **'In tune'**
  String get inTune;

  /// No description provided for @flat.
  ///
  /// In en, this message translates to:
  /// **'Flat'**
  String get flat;

  /// No description provided for @sharp.
  ///
  /// In en, this message translates to:
  /// **'Sharp'**
  String get sharp;

  /// The word over the tuner's cents bar
  ///
  /// In en, this message translates to:
  /// **'Cents'**
  String get centsTitle;

  /// No description provided for @centsValue.
  ///
  /// In en, this message translates to:
  /// **'{cents} cents'**
  String centsValue(String cents);

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// The first group of the settings page: what concerns the whole app.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Same as the phone'**
  String get languageSystem;

  /// No description provided for @noteNamesLabel.
  ///
  /// In en, this message translates to:
  /// **'Note names'**
  String get noteNamesLabel;

  /// No description provided for @noteNamesAuto.
  ///
  /// In en, this message translates to:
  /// **'Follow the language'**
  String get noteNamesAuto;

  /// No description provided for @noteNamesSolfege.
  ///
  /// In en, this message translates to:
  /// **'Do Re Mi'**
  String get noteNamesSolfege;

  /// No description provided for @noteNamesLetters.
  ///
  /// In en, this message translates to:
  /// **'C D E'**
  String get noteNamesLetters;

  /// No description provided for @circleLayoutLabel.
  ///
  /// In en, this message translates to:
  /// **'Harmony circle'**
  String get circleLayoutLabel;

  /// No description provided for @circleLayoutFifths.
  ///
  /// In en, this message translates to:
  /// **'Circle of fifths'**
  String get circleLayoutFifths;

  /// No description provided for @circleLayoutChromatic.
  ///
  /// In en, this message translates to:
  /// **'In semitones (C, C♯, D…)'**
  String get circleLayoutChromatic;

  /// No description provided for @aboutTooltip.
  ///
  /// In en, this message translates to:
  /// **'About Low End'**
  String get aboutTooltip;

  /// No description provided for @aboutLegalese.
  ///
  /// In en, this message translates to:
  /// **'Free and open-source software, released under the MIT License.'**
  String get aboutLegalese;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Metronome, harmony and tuner for musicians. Made by an amateur double bass player with the friends from the orchestra in mind, and useful to everyone. Low End works offline: the microphone is used only while the tuner is listening, and no sound or data leaves your phone.'**
  String get aboutDescription;

  /// No description provided for @aboutPiano.
  ///
  /// In en, this message translates to:
  /// **'Piano sounds: Salamander Grand Piano by Alexander Holm (public domain).'**
  String get aboutPiano;

  /// No description provided for @aboutBass.
  ///
  /// In en, this message translates to:
  /// **'Double bass sounds: Meatbass by Karoryfer Lecolds, played by Drogomir Smolken (CC0, public domain).'**
  String get aboutBass;

  /// The button of the Harmony row that shows the style playing and opens the menu of the styles.
  ///
  /// In en, this message translates to:
  /// **'Style: {style}'**
  String styleButton(String style);

  /// No description provided for @styleHeld.
  ///
  /// In en, this message translates to:
  /// **'Chord every bar'**
  String get styleHeld;

  /// No description provided for @styleBeat.
  ///
  /// In en, this message translates to:
  /// **'Chord on every beat'**
  String get styleBeat;

  /// No description provided for @styleArpeggio.
  ///
  /// In en, this message translates to:
  /// **'Arpeggio'**
  String get styleArpeggio;

  /// A jazz bass line, one note a beat, on a plucked double bass, with the piano comping above.
  ///
  /// In en, this message translates to:
  /// **'Walking bass'**
  String get styleWalking;

  /// The tempo is written like ♩ = 120.
  ///
  /// In en, this message translates to:
  /// **'Follows the metronome: {tempo}, {signature}'**
  String styleTempo(String tempo, String signature);

  /// No description provided for @beatUnitQuarter.
  ///
  /// In en, this message translates to:
  /// **'quarter note'**
  String get beatUnitQuarter;

  /// No description provided for @beatUnitDottedQuarter.
  ///
  /// In en, this message translates to:
  /// **'dotted quarter note'**
  String get beatUnitDottedQuarter;

  /// No description provided for @beatUnitEighth.
  ///
  /// In en, this message translates to:
  /// **'eighth note'**
  String get beatUnitEighth;

  /// No description provided for @pausedForTuner.
  ///
  /// In en, this message translates to:
  /// **'Paused while you tune'**
  String get pausedForTuner;

  /// Notice shown when the sound stops because the headphones were unplugged; it has a Resume button.
  ///
  /// In en, this message translates to:
  /// **'Paused: headphones unplugged'**
  String get pausedUnplugged;

  /// Notice shown in the web app when the browser cut the sound (a call, Siri, an alarm, the locked screen on an iPhone); it has a Resume button.
  ///
  /// In en, this message translates to:
  /// **'Paused: the sound was interrupted'**
  String get pausedInterrupted;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @keepScreenOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen on'**
  String get keepScreenOnTitle;

  /// No description provided for @keepScreenOnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'While it plays or the tuner listens'**
  String get keepScreenOnSubtitle;

  /// No description provided for @setTempo.
  ///
  /// In en, this message translates to:
  /// **'Type the tempo'**
  String get setTempo;

  /// No description provided for @continuousToneTitle.
  ///
  /// In en, this message translates to:
  /// **'Held tone'**
  String get continuousToneTitle;

  /// No description provided for @continuousToneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A steady tone instead of the piano struck again and again.'**
  String get continuousToneSubtitle;

  /// No description provided for @octaveNumberingLabel.
  ///
  /// In en, this message translates to:
  /// **'Octave numbers'**
  String get octaveNumberingLabel;

  /// No description provided for @octaveNumberingHint.
  ///
  /// In en, this message translates to:
  /// **'Only the number after the note name: the same note, a different number.'**
  String get octaveNumberingHint;

  /// No description provided for @octaveScientific.
  ///
  /// In en, this message translates to:
  /// **'Scientific (default)'**
  String get octaveScientific;

  /// No description provided for @octaveItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get octaveItalian;

  /// No description provided for @octaveExamples.
  ///
  /// In en, this message translates to:
  /// **'{a4} = 440 Hz, the bass low E is {e1}'**
  String octaveExamples(String a4, String e1);

  /// No description provided for @tuningChromatic.
  ///
  /// In en, this message translates to:
  /// **'Chromatic'**
  String get tuningChromatic;

  /// No description provided for @tuningInstrument.
  ///
  /// In en, this message translates to:
  /// **'Instrument'**
  String get tuningInstrument;

  /// Name of the Harmony field that shows and changes the tempo, the same as the metronome's.
  ///
  /// In en, this message translates to:
  /// **'Tempo'**
  String get tempoLabel;

  /// Name of the Harmony field that chooses between one chord and a progression.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get voicingLabel;

  /// No description provided for @voicingChordHint.
  ///
  /// In en, this message translates to:
  /// **'One note or chord, until you stop it'**
  String get voicingChordHint;

  /// No description provided for @voicingProgressionHint.
  ///
  /// In en, this message translates to:
  /// **'Chords in turn, in time with the metronome'**
  String get voicingProgressionHint;

  /// Under Chromatic in the tuner's instrument menu, where the other entries show their open strings.
  ///
  /// In en, this message translates to:
  /// **'Any note, no strings to choose'**
  String get tuningChromaticHint;

  /// No description provided for @tuningGuitar.
  ///
  /// In en, this message translates to:
  /// **'Guitar'**
  String get tuningGuitar;

  /// No description provided for @tuningViolin.
  ///
  /// In en, this message translates to:
  /// **'Violin'**
  String get tuningViolin;

  /// No description provided for @tuningViola.
  ///
  /// In en, this message translates to:
  /// **'Viola'**
  String get tuningViola;

  /// No description provided for @tuningCello.
  ///
  /// In en, this message translates to:
  /// **'Cello'**
  String get tuningCello;

  /// No description provided for @tuningUkulele.
  ///
  /// In en, this message translates to:
  /// **'Ukulele'**
  String get tuningUkulele;

  /// No description provided for @tuningBass.
  ///
  /// In en, this message translates to:
  /// **'Bass'**
  String get tuningBass;

  /// In the tuner's string mode: the number of the string being tuned, as a Roman numeral (I is the thinnest).
  ///
  /// In en, this message translates to:
  /// **'String {number}'**
  String tunerString(String number);

  /// In the tuner's string mode: the note actually heard, when it is not the string being tuned.
  ///
  /// In en, this message translates to:
  /// **'Heard {note}'**
  String tunerHeard(String note);

  /// No description provided for @swipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe up or down over the dial or the tabs to change section.'**
  String get swipeHint;

  /// No description provided for @gesturesLockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Lock the gestures'**
  String get gesturesLockedTitle;

  /// No description provided for @gesturesLockedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For rehearsals: no swiping between sections'**
  String get gesturesLockedSubtitle;

  /// No description provided for @inTuneZoneTitle.
  ///
  /// In en, this message translates to:
  /// **'In tune within'**
  String get inTuneZoneTitle;

  /// No description provided for @inTuneZoneSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How far off a note can be, in cents (hundredths of a semitone), and still show as in tune'**
  String get inTuneZoneSubtitle;

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'Gestures and shortcuts'**
  String get guideTitle;

  /// No description provided for @guideRing.
  ///
  /// In en, this message translates to:
  /// **'Each section starts and stops when you touch the middle of its dial. In Harmony, touch a note.'**
  String get guideRing;

  /// No description provided for @guideTempo.
  ///
  /// In en, this message translates to:
  /// **'Hold − or + and the tempo runs, faster and faster.'**
  String get guideTempo;

  /// No description provided for @guideSwipe.
  ///
  /// In en, this message translates to:
  /// **'Swipe left and right to change section.'**
  String get guideSwipe;

  /// No description provided for @guideVolume.
  ///
  /// In en, this message translates to:
  /// **'The volume is the phone\'s: use its volume keys.'**
  String get guideVolume;

  /// No description provided for @guideDone.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get guideDone;

  /// What holding a key of the drone does: C♯ written as D♭.
  ///
  /// In en, this message translates to:
  /// **'Write as {note}'**
  String writeAs(String note);

  /// No description provided for @progressionBluesShort.
  ///
  /// In en, this message translates to:
  /// **'Blues'**
  String get progressionBluesShort;

  /// The progression and its key: II–V–I in A major.
  ///
  /// In en, this message translates to:
  /// **'{progression} in {key}'**
  String keyLine(String progression, String key);

  /// No description provided for @keySheetTitle.
  ///
  /// In en, this message translates to:
  /// **'Key: {key}'**
  String keySheetTitle(String key);

  /// No description provided for @degreeName1.
  ///
  /// In en, this message translates to:
  /// **'Tonic'**
  String get degreeName1;

  /// No description provided for @degreeName2.
  ///
  /// In en, this message translates to:
  /// **'Supertonic'**
  String get degreeName2;

  /// No description provided for @degreeName3.
  ///
  /// In en, this message translates to:
  /// **'Mediant'**
  String get degreeName3;

  /// No description provided for @degreeName4.
  ///
  /// In en, this message translates to:
  /// **'Subdominant'**
  String get degreeName4;

  /// No description provided for @degreeName5.
  ///
  /// In en, this message translates to:
  /// **'Dominant'**
  String get degreeName5;

  /// No description provided for @degreeName6.
  ///
  /// In en, this message translates to:
  /// **'Submediant'**
  String get degreeName6;

  /// No description provided for @degreeName7.
  ///
  /// In en, this message translates to:
  /// **'Leading tone'**
  String get degreeName7;

  /// No description provided for @degreeName7Minor.
  ///
  /// In en, this message translates to:
  /// **'Subtonic'**
  String get degreeName7Minor;

  /// No description provided for @legendTitle.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get legendTitle;

  /// No description provided for @legendButton.
  ///
  /// In en, this message translates to:
  /// **'Legend and degrees'**
  String get legendButton;

  /// No description provided for @legendRoot.
  ///
  /// In en, this message translates to:
  /// **'Note sounding (the root)'**
  String get legendRoot;

  /// No description provided for @legendChord.
  ///
  /// In en, this message translates to:
  /// **'Other notes of the chord sounding'**
  String get legendChord;

  /// No description provided for @legendInKey.
  ///
  /// In en, this message translates to:
  /// **'Notes of the key'**
  String get legendInKey;

  /// No description provided for @legendOutOfKey.
  ///
  /// In en, this message translates to:
  /// **'Notes outside the key, faded'**
  String get legendOutOfKey;

  /// No description provided for @legendNumerals.
  ///
  /// In en, this message translates to:
  /// **'The Roman numerals give the degree of the key each chord is built on. Tap one on the circle to read it here.'**
  String get legendNumerals;

  /// No description provided for @legendDots.
  ///
  /// In en, this message translates to:
  /// **'The dots are the bars of the progression: the filled one is the chord sounding.'**
  String get legendDots;

  /// No description provided for @songsTitle.
  ///
  /// In en, this message translates to:
  /// **'Example songs'**
  String get songsTitle;

  /// No description provided for @songsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sets the key, the progression, the tempo and the style in one tap'**
  String get songsSubtitle;

  /// No description provided for @tunerHeld.
  ///
  /// In en, this message translates to:
  /// **'Holding the last note'**
  String get tunerHeld;

  /// No description provided for @aboutSource.
  ///
  /// In en, this message translates to:
  /// **'Source code: {url}'**
  String aboutSource(String url);

  /// No description provided for @subdivisionQuarters.
  ///
  /// In en, this message translates to:
  /// **'Quarter notes'**
  String get subdivisionQuarters;

  /// No description provided for @subdivisionEighths.
  ///
  /// In en, this message translates to:
  /// **'Eighth notes'**
  String get subdivisionEighths;

  /// No description provided for @subdivisionSwungEighths.
  ///
  /// In en, this message translates to:
  /// **'Swung eighth notes'**
  String get subdivisionSwungEighths;

  /// No description provided for @subdivisionTriplets.
  ///
  /// In en, this message translates to:
  /// **'Triplets'**
  String get subdivisionTriplets;

  /// No description provided for @subdivisionSixteenths.
  ///
  /// In en, this message translates to:
  /// **'Sixteenth notes'**
  String get subdivisionSixteenths;

  /// No description provided for @subdivisionSwungSixteenths.
  ///
  /// In en, this message translates to:
  /// **'Swung sixteenth notes'**
  String get subdivisionSwungSixteenths;

  /// No description provided for @backbeatTitle.
  ///
  /// In en, this message translates to:
  /// **'Click on 2 and 4'**
  String get backbeatTitle;

  /// No description provided for @backbeatSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Beats 1 and 3 stay silent, as on a jazz hi-hat. In 2/4 and 4/4.'**
  String get backbeatSubtitle;

  /// No description provided for @backbeatShort.
  ///
  /// In en, this message translates to:
  /// **'2 & 4'**
  String get backbeatShort;

  /// No description provided for @transpositionTitle.
  ///
  /// In en, this message translates to:
  /// **'Transposing instrument'**
  String get transpositionTitle;

  /// No description provided for @transpositionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'For B♭, E♭ and F instruments, the chromatic tuner names the written note'**
  String get transpositionSubtitle;

  /// No description provided for @transpositionConcert.
  ///
  /// In en, this message translates to:
  /// **'Concert pitch'**
  String get transpositionConcert;

  /// The key of a transposing instrument, such as B♭: the tuner then names its written notes.
  ///
  /// In en, this message translates to:
  /// **'in {key}'**
  String transpositionKey(String key);

  /// Name of the tab where the person plays a track of their own to study it. Short: it has to fit under an icon.
  ///
  /// In en, this message translates to:
  /// **'Player'**
  String get playerTab;

  /// No description provided for @playerTrack.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get playerTrack;

  /// No description provided for @playerChoose.
  ///
  /// In en, this message translates to:
  /// **'Choose a track'**
  String get playerChoose;

  /// No description provided for @playerPlay.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get playerPlay;

  /// No description provided for @playerPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get playerPause;

  /// The time of the listening point in a track, read by screen readers: 1:12 of 6:03.
  ///
  /// In en, this message translates to:
  /// **'{position} of {duration}'**
  String playerTimeOf(String position, String duration);

  /// Notice shown when the metronome and Harmony were paused because the Player started; it has a Resume button.
  ///
  /// In en, this message translates to:
  /// **'Paused while you listen'**
  String get pausedForPlayer;

  /// No description provided for @playerUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This file can\'t be opened.'**
  String get playerUnreadable;

  /// No description provided for @playerMissing.
  ///
  /// In en, this message translates to:
  /// **'The file is no longer available.'**
  String get playerMissing;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'es', 'fr', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
