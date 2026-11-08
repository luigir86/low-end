// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get takeDiscard => 'Discard';

  @override
  String get takeDelete => 'Delete recording';

  @override
  String get takeRemove => 'Remove from player';

  @override
  String get takeRecord => 'Record';

  @override
  String get takeRecordShort => 'REC';

  @override
  String get takeStop => 'Stop';

  @override
  String get takeRecording => 'Recording';

  @override
  String get takeTemporary => 'Temporary';

  @override
  String get takeSave => 'Save';

  @override
  String get takeShare => 'Share';

  @override
  String get takeReplaceQuestion => 'Replace the temporary recording?';

  @override
  String get takeKeep => 'Keep';

  @override
  String get takeReplace => 'Replace';

  @override
  String get takeError => 'Audio operation failed. Try again.';

  @override
  String get takeShareUnavailable =>
      'This browser cannot share audio files. Save the file and attach it in WhatsApp.';

  @override
  String get takeSaved => 'Saved';

  @override
  String get takeStarting => 'Starting microphone…';

  @override
  String get appTitle => 'Low End';

  @override
  String get tunerTab => 'Tuner';

  @override
  String get metronomeTab => 'Metronome';

  @override
  String get harmonyTab => 'Harmony';

  @override
  String get metronomeStart => 'Start the metronome';

  @override
  String get metronomeStop => 'Stop the metronome';

  @override
  String get metronomeHint => 'Tap to start';

  @override
  String get tempoDial => 'Tempo dial';

  @override
  String get tempoDialHint =>
      'Drag clockwise to increase the tempo; counterclockwise to decrease it';

  @override
  String get tempoDialCaption => 'Turn to set tempo';

  @override
  String bpmValue(String bpm) {
    return '$bpm BPM';
  }

  @override
  String get timeSignature => 'Time signature';

  @override
  String get backgroundPlaying => 'Playing in the background';

  @override
  String get sectionPlaying => 'Playing';

  @override
  String get slower => 'Slower';

  @override
  String get faster => 'Faster';

  @override
  String get tapTempo => 'Tap the tempo';

  @override
  String get droneStop => 'Stop the harmony';

  @override
  String get subdivisionLabel => 'Subdivision';

  @override
  String get progressionLabel => 'Progression';

  @override
  String get progressionMinorTwoFiveOne => 'II–V–I minor';

  @override
  String get progressionBlues => '12-bar blues';

  @override
  String progressionAndalusianLike(String song) {
    return 'Andalusian cadence, like $song';
  }

  @override
  String progressionAnatoleLike(String song) {
    return 'The Anatole, like $song';
  }

  @override
  String get progressionCircleOfFifths => 'Circle of fifths';

  @override
  String get progressionMinorBlues => 'Minor blues';

  @override
  String progressionLike(String song) {
    return 'Like $song';
  }

  @override
  String progressionGiroLike(String song) {
    return 'The ’50s progression, like $song';
  }

  @override
  String get progressionSectionPopRock => 'Pop and rock';

  @override
  String get progressionSectionBlues => 'Blues';

  @override
  String get progressionSectionJazz => 'Jazz';

  @override
  String get thanksTitle => 'Thanks';

  @override
  String get thanksInstagram => 'Follow them on Instagram';

  @override
  String get thanksText =>
      'Thanks to the Power Flower Orchestra of Fossano, who inspired this app and put it to the test.';

  @override
  String droneChordDiminished(String note) {
    return '$note diminished';
  }

  @override
  String get referencePitch => 'Reference A';

  @override
  String get lowerPitch => 'Lower the reference A';

  @override
  String get higherPitch => 'Raise the reference A';

  @override
  String get choosePitch => 'Choose a standard reference A';

  @override
  String get pitchBaroque => 'Baroque';

  @override
  String get pitchVerdi => 'Verdi';

  @override
  String get pitchConcert => 'Concert pitch';

  @override
  String get pitchOrchestras => 'Orchestras';

  @override
  String referencePitchHint(String note) {
    return 'The frequency of $note, for the tuner and the harmony.';
  }

  @override
  String frequencyHz(String frequency) {
    return '$frequency Hz';
  }

  @override
  String stopSound(String name) {
    return 'Stop $name';
  }

  @override
  String playSound(String name) {
    return 'Play $name';
  }

  @override
  String get droneHint => 'Touch a note to play it. Touch it again to stop.';

  @override
  String get chordLabel => 'Chord';

  @override
  String get noteAlone => 'Note alone';

  @override
  String get chordMajor => 'Major';

  @override
  String get chordMinor => 'Minor';

  @override
  String get chordDominant => 'Dominant 7th (7)';

  @override
  String get chordDominantFlat9 => 'Dominant 7th ♭9 (7♭9)';

  @override
  String get chordMajor7 => 'Major 7th (maj7)';

  @override
  String get chordMinor7 => 'Minor 7th (m7)';

  @override
  String get chordHalfDiminished => 'Half-diminished (m7♭5)';

  @override
  String get chordDiminished => 'Diminished (dim)';

  @override
  String get chordSus4 => 'Suspended 4th (sus4)';

  @override
  String droneChordHalfDiminished(String note) {
    return '$note half-diminished';
  }

  @override
  String progressionInKey(String name, String key) {
    return '$name in $key';
  }

  @override
  String droneChordMajor(String note) {
    return '$note major';
  }

  @override
  String droneChordMinor(String note) {
    return '$note minor';
  }

  @override
  String droneChordSeventh(String note) {
    return '${note}7';
  }

  @override
  String get audioUnavailable => 'Sound could not start on this device.';

  @override
  String get audioDownloadFailed =>
      'The sounds could not be downloaded. Check the connection and touch again.';

  @override
  String get soundsPreparing => 'Getting the sounds ready…';

  @override
  String get soundsDownloadingSlowly =>
      'Downloading the sounds: the connection is slow. Please wait.';

  @override
  String get startListening => 'Listen';

  @override
  String get stopListening => 'Pause';

  @override
  String get tunerWillPause => 'Listening pauses what is playing';

  @override
  String get tunerIdleHint => 'Tuner paused: tap Listen';

  @override
  String get playAString => 'Play a note';

  @override
  String get micPermissionDenied =>
      'Low End needs the microphone to hear your instrument. If you said no, allow it in the phone settings under Apps › Low End › Permissions.';

  @override
  String get micPermissionDeniedWeb =>
      'Low End needs the microphone to hear your instrument. If you said no, allow it for this page in the browser settings, then tap Listen again.';

  @override
  String get micUnavailable => 'The microphone could not start on this device.';

  @override
  String get inTune => 'In tune';

  @override
  String get flat => 'Flat';

  @override
  String get sharp => 'Sharp';

  @override
  String get centsTitle => 'Cents';

  @override
  String centsValue(String cents) {
    return '$cents cents';
  }

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsGeneral => 'General';

  @override
  String get languageLabel => 'Language';

  @override
  String get languageSystem => 'Same as the phone';

  @override
  String get noteNamesLabel => 'Note names';

  @override
  String get noteNamesAuto => 'Follow the language';

  @override
  String get noteNamesSolfege => 'Do Re Mi';

  @override
  String get noteNamesLetters => 'C D E';

  @override
  String get circleLayoutLabel => 'Harmony circle';

  @override
  String get circleLayoutFifths => 'Circle of fifths';

  @override
  String get circleLayoutChromatic => 'In semitones (C, C♯, D…)';

  @override
  String get aboutTooltip => 'About Low End';

  @override
  String get aboutLegalese =>
      'Free and open-source software, released under the MIT License.';

  @override
  String get aboutDescription =>
      'Metronome, harmony and tuner for musicians. Made by an amateur double bass player with the friends from the orchestra in mind, and useful to everyone. Low End works offline. The tuner listens on your device. In the Player you can record, save and share your own audio.';

  @override
  String get aboutPiano =>
      'Piano sounds: Salamander Grand Piano by Alexander Holm (public domain).';

  @override
  String get aboutBass =>
      'Double bass sounds: Meatbass by Karoryfer Lecolds, played by Drogomir Smolken (CC0, public domain).';

  @override
  String styleButton(String style) {
    return 'Style: $style';
  }

  @override
  String get styleHeld => 'Chord every bar';

  @override
  String get styleBeat => 'Chord on every beat';

  @override
  String get styleArpeggio => 'Arpeggio';

  @override
  String get styleWalking => 'Walking bass';

  @override
  String styleTempo(String tempo, String signature) {
    return 'Follows the metronome: $tempo, $signature';
  }

  @override
  String get beatUnitQuarter => 'quarter note';

  @override
  String get beatUnitDottedQuarter => 'dotted quarter note';

  @override
  String get beatUnitEighth => 'eighth note';

  @override
  String get pausedForTuner => 'Paused while you tune';

  @override
  String get pausedUnplugged => 'Paused: headphones unplugged';

  @override
  String get pausedInterrupted => 'Paused: the sound was interrupted';

  @override
  String get resume => 'Resume';

  @override
  String get openSettings => 'Open settings';

  @override
  String get keepScreenOnTitle => 'Keep the screen on';

  @override
  String get keepScreenOnSubtitle => 'While it plays or the tuner listens';

  @override
  String get setTempo => 'Type the tempo';

  @override
  String get continuousToneTitle => 'Held tone';

  @override
  String get continuousToneSubtitle =>
      'A steady tone instead of the piano struck again and again.';

  @override
  String get octaveNumberingLabel => 'Octave numbers';

  @override
  String get octaveNumberingHint =>
      'Only the number after the note name: the same note, a different number.';

  @override
  String get octaveScientific => 'Scientific (default)';

  @override
  String get octaveItalian => 'Italian';

  @override
  String octaveExamples(String a4, String e1) {
    return '$a4 = 440 Hz, the bass low E is $e1';
  }

  @override
  String get tuningChromatic => 'Chromatic';

  @override
  String get tuningInstrument => 'Instrument';

  @override
  String get tempoLabel => 'Tempo';

  @override
  String get voicingLabel => 'Mode';

  @override
  String get voicingChordHint => 'One note or chord, until you stop it';

  @override
  String get voicingProgressionHint =>
      'Chords in turn, in time with the metronome';

  @override
  String get tuningChromaticHint => 'Any note, no strings to choose';

  @override
  String get tuningGuitar => 'Guitar';

  @override
  String get tuningViolin => 'Violin';

  @override
  String get tuningViola => 'Viola';

  @override
  String get tuningCello => 'Cello';

  @override
  String get tuningUkulele => 'Ukulele';

  @override
  String get tuningBass => 'Bass';

  @override
  String tunerString(String number) {
    return 'String $number';
  }

  @override
  String tunerHeard(String note) {
    return 'Heard $note';
  }

  @override
  String get swipeHint =>
      'Swipe up or down over the dial or the tabs to change section.';

  @override
  String get gesturesLockedTitle => 'Lock the gestures';

  @override
  String get gesturesLockedSubtitle =>
      'For rehearsals: no swiping between sections';

  @override
  String get inTuneZoneTitle => 'In tune within';

  @override
  String get inTuneZoneSubtitle =>
      'How far off a note can be, in cents (hundredths of a semitone), and still show as in tune';

  @override
  String get guideTitle => 'Gestures and shortcuts';

  @override
  String get guideRing =>
      'Each section starts and stops when you touch the middle of its dial. In Harmony, touch a note.';

  @override
  String get guideTempo => 'Hold − or + and the tempo runs, faster and faster.';

  @override
  String get guideSwipe => 'Swipe left and right to change section.';

  @override
  String get guideVolume => 'The volume is the phone\'s: use its volume keys.';

  @override
  String get guideDone => 'Got it';

  @override
  String writeAs(String note) {
    return 'Write as $note';
  }

  @override
  String get progressionBluesShort => 'Blues';

  @override
  String keyLine(String progression, String key) {
    return '$progression in $key';
  }

  @override
  String keySheetTitle(String key) {
    return 'Key: $key';
  }

  @override
  String get degreeName1 => 'Tonic';

  @override
  String get degreeName2 => 'Supertonic';

  @override
  String get degreeName3 => 'Mediant';

  @override
  String get degreeName4 => 'Subdominant';

  @override
  String get degreeName5 => 'Dominant';

  @override
  String get degreeName6 => 'Submediant';

  @override
  String get degreeName7 => 'Leading tone';

  @override
  String get degreeName7Minor => 'Subtonic';

  @override
  String get legendTitle => 'Legend';

  @override
  String get legendButton => 'Legend and degrees';

  @override
  String get legendRoot => 'Note sounding (the root)';

  @override
  String get legendChord => 'Other notes of the chord sounding';

  @override
  String get legendInKey => 'Notes of the key';

  @override
  String get legendOutOfKey => 'Notes outside the key, faded';

  @override
  String get legendNumerals =>
      'The Roman numerals give the degree of the key each chord is built on. Tap one on the circle to read it here.';

  @override
  String get legendDots =>
      'The dots are the bars of the progression: the filled one is the chord sounding.';

  @override
  String get songsTitle => 'Example songs';

  @override
  String get songsSubtitle =>
      'Sets the key, the progression, the tempo and the style in one tap';

  @override
  String get tunerHeld => 'Holding the last note';

  @override
  String aboutSource(String url) {
    return 'Source code: $url';
  }

  @override
  String get subdivisionQuarters => 'Quarter notes';

  @override
  String get subdivisionEighths => 'Eighth notes';

  @override
  String get subdivisionSwungEighths => 'Swung eighth notes';

  @override
  String get subdivisionTriplets => 'Triplets';

  @override
  String get subdivisionSixteenths => 'Sixteenth notes';

  @override
  String get subdivisionSwungSixteenths => 'Swung sixteenth notes';

  @override
  String get backbeatTitle => 'Click on 2 and 4';

  @override
  String get backbeatSubtitle =>
      'Beats 1 and 3 stay silent, as on a jazz hi-hat. In 2/4 and 4/4.';

  @override
  String get backbeatShort => '2 & 4';

  @override
  String get transpositionTitle => 'Transposing instrument';

  @override
  String get transpositionSubtitle =>
      'For B♭, E♭ and F instruments, the chromatic tuner names the written note';

  @override
  String get transpositionConcert => 'Concert pitch';

  @override
  String transpositionKey(String key) {
    return 'in $key';
  }

  @override
  String get playerTab => 'Player';

  @override
  String get playerTrack => 'Track';

  @override
  String get playerChoose => 'Choose a track';

  @override
  String get playerHubHint => 'Tap to start';

  @override
  String get playerPlay => 'Play';

  @override
  String get playerPause => 'Pause';

  @override
  String playerTimeOf(String position, String duration) {
    return '$position of $duration';
  }

  @override
  String get pausedForPlayer => 'Paused while you listen';

  @override
  String get playerUnreadable => 'This file can\'t be opened.';

  @override
  String get playerMissing => 'The file is no longer available.';

  @override
  String get playerSpeed => 'Speed';

  @override
  String get playerSpeedTitle => 'Listening speed';

  @override
  String get playerCaptureStart => 'Mark start';

  @override
  String get playerCaptureEnd => 'Mark end';

  @override
  String get playerLoopActive => 'Loop active';

  @override
  String get playerResumeLoop => 'Resume loop';

  @override
  String get playerNewPassage => 'New passage';

  @override
  String get playerLoop => 'Loop';

  @override
  String get playerMarkStart => 'Mark the start here';

  @override
  String get playerMarkEnd => 'Mark the end here';

  @override
  String playerStartAt(String time) {
    return 'Start $time';
  }

  @override
  String playerEndAt(String time) {
    return 'End $time';
  }

  @override
  String get playerStartEarlier => 'Start earlier';

  @override
  String get playerStartLater => 'Start later';

  @override
  String get playerEndEarlier => 'End earlier';

  @override
  String get playerEndLater => 'End later';

  @override
  String get guidePlayerLoop =>
      'In Player, tap Mark start and Mark end while listening. Drag the waveform handles to refine the passage.';

  @override
  String get playerHintFlags =>
      'Drag A and B onto the ring to choose the passage to repeat';

  @override
  String get playerHintPlaceStart => 'Touch the ring where the passage starts';

  @override
  String get playerHintPlaceEnd => 'Touch the ring where the passage ends';

  @override
  String get playerHintNeedStart => 'Now bring A to where the passage starts';

  @override
  String get playerHintNeedEnd => 'Now bring B to where the passage ends';

  @override
  String get playerFlagStart => 'Flag A, start of the passage';

  @override
  String get playerFlagEnd => 'Flag B, end of the passage';
}
