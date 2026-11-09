// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get takeDiscard => 'Scarta';

  @override
  String get takeDelete => 'Elimina registrazione';

  @override
  String get takeRemove => 'Rimuovi dal player';

  @override
  String get takeRecord => 'Registra';

  @override
  String get takeDeleted => 'Registrazione eliminata';

  @override
  String get takeUndo => 'Annulla';

  @override
  String get takeStop => 'Stop';

  @override
  String get takeRecording => 'Registrazione';

  @override
  String get takeTemporary => 'Temporanea';

  @override
  String get takeSave => 'Salva';

  @override
  String get takeShare => 'Condividi';

  @override
  String get takeReplaceQuestion => 'Sostituire la registrazione temporanea?';

  @override
  String get takeKeep => 'Conserva';

  @override
  String get takeReplace => 'Sostituisci';

  @override
  String get takeError => 'Operazione audio non riuscita. Riprova.';

  @override
  String get takeShareUnavailable =>
      'Questo browser non può condividere file audio. Usa Salva, poi allega il file in WhatsApp.';

  @override
  String get takeSaved => 'Salvata';

  @override
  String get takeStarting => 'Microfono in attivazione…';

  @override
  String get appTitle => 'Low End';

  @override
  String get tunerTab => 'Accordatore';

  @override
  String get metronomeTab => 'Metronomo';

  @override
  String get harmonyTab => 'Armonia';

  @override
  String get metronomeStart => 'Avvia il metronomo';

  @override
  String get metronomeStop => 'Ferma il metronomo';

  @override
  String get metronomeHint => 'Tocca per avviare';

  @override
  String get tempoDial => 'Ghiera del tempo';

  @override
  String get tempoDialHint =>
      'Trascina in senso orario per aumentare il tempo; antiorario per diminuirlo';

  @override
  String get tempoDialCaption => 'Ruota per il tempo';

  @override
  String bpmValue(String bpm) {
    return '$bpm BPM';
  }

  @override
  String get timeSignature => 'Misura';

  @override
  String get backgroundPlaying => 'In riproduzione in background';

  @override
  String get sectionPlaying => 'In riproduzione';

  @override
  String get slower => 'Più lento';

  @override
  String get faster => 'Più veloce';

  @override
  String get tapTempo => 'Batti il tempo';

  @override
  String get droneStop => 'Ferma l\'armonia';

  @override
  String get subdivisionLabel => 'Suddivisione';

  @override
  String get progressionLabel => 'Progressione';

  @override
  String get progressionMinorTwoFiveOne => 'II–V–I minore';

  @override
  String get progressionBlues => 'Blues in 12 battute';

  @override
  String progressionAndalusianLike(String song) {
    return 'Cadenza andalusa, come $song';
  }

  @override
  String progressionAnatoleLike(String song) {
    return 'Anatole, come $song';
  }

  @override
  String get progressionCircleOfFifths => 'Ciclo delle quinte';

  @override
  String get progressionMinorBlues => 'Blues minore';

  @override
  String progressionLike(String song) {
    return 'Come $song';
  }

  @override
  String progressionGiroLike(String song) {
    return 'Giro di Do, come $song';
  }

  @override
  String get progressionSectionPopRock => 'Pop e rock';

  @override
  String get progressionSectionBlues => 'Blues';

  @override
  String get progressionSectionJazz => 'Jazz';

  @override
  String get thanksTitle => 'Ringraziamenti';

  @override
  String get thanksInstagram => 'Seguili su Instagram';

  @override
  String get thanksText =>
      'Grazie alla Power Flower Orchestra di Fossano, che ha ispirato e provato quest’app.';

  @override
  String droneChordDiminished(String note) {
    return '$note diminuito';
  }

  @override
  String get referencePitch => 'La di riferimento';

  @override
  String get lowerPitch => 'Abbassa il La di riferimento';

  @override
  String get higherPitch => 'Alza il La di riferimento';

  @override
  String get choosePitch => 'Scegli un La di riferimento standard';

  @override
  String get pitchBaroque => 'Barocco';

  @override
  String get pitchVerdi => 'Verdi';

  @override
  String get pitchConcert => 'Diapason standard';

  @override
  String get pitchOrchestras => 'Orchestre';

  @override
  String referencePitchHint(String note) {
    return 'La frequenza di $note, per l\'accordatore e l\'armonia.';
  }

  @override
  String frequencyHz(String frequency) {
    return '$frequency Hz';
  }

  @override
  String stopSound(String name) {
    return 'Ferma $name';
  }

  @override
  String playSound(String name) {
    return 'Suona $name';
  }

  @override
  String get droneHint =>
      'Tocca una nota per farla suonare. Toccala di nuovo per fermarla.';

  @override
  String get chordLabel => 'Accordo';

  @override
  String get noteAlone => 'Solo la nota';

  @override
  String get chordMajor => 'Maggiore';

  @override
  String get chordMinor => 'Minore';

  @override
  String get chordDominant => 'Settima di dominante (7)';

  @override
  String get chordDominantFlat9 => 'Settima di dominante con ♭9 (7♭9)';

  @override
  String get chordMajor7 => 'Settima maggiore (maj7)';

  @override
  String get chordMinor7 => 'Settima minore (m7)';

  @override
  String get chordHalfDiminished => 'Semidiminuito (m7♭5)';

  @override
  String get chordDiminished => 'Diminuito (dim)';

  @override
  String get chordSus4 => 'Quarta sospesa (sus4)';

  @override
  String droneChordHalfDiminished(String note) {
    return '$note semidiminuito';
  }

  @override
  String progressionInKey(String name, String key) {
    return '$name in $key';
  }

  @override
  String droneChordMajor(String note) {
    return '$note maggiore';
  }

  @override
  String droneChordMinor(String note) {
    return '$note minore';
  }

  @override
  String droneChordSeventh(String note) {
    return '${note}7';
  }

  @override
  String get audioUnavailable =>
      'Non è stato possibile avviare l\'audio su questo dispositivo.';

  @override
  String get audioDownloadFailed =>
      'Download dei suoni non riuscito: controlla la connessione e tocca di nuovo.';

  @override
  String get soundsPreparing => 'Preparo i suoni…';

  @override
  String get soundsDownloadingSlowly =>
      'Sto scaricando i suoni: la connessione è lenta. Attendi.';

  @override
  String get startListening => 'Ascolta';

  @override
  String get stopListening => 'Pausa';

  @override
  String get tunerWillPause => 'Ascoltare mette in pausa ciò che suona';

  @override
  String get tunerIdleHint => 'Accordatore in pausa: tocca Ascolta';

  @override
  String get playAString => 'Suona una nota';

  @override
  String get micPermissionDenied =>
      'Low End ha bisogno del microfono per sentire il tuo strumento. Se hai risposto di no, consentilo nelle impostazioni del telefono in App › Low End › Autorizzazioni.';

  @override
  String get micPermissionDeniedWeb =>
      'Low End ha bisogno del microfono per sentire il tuo strumento. Se hai risposto di no, consentilo a questa pagina nelle impostazioni del browser, poi tocca di nuovo Ascolta.';

  @override
  String get micUnavailable =>
      'Non è stato possibile avviare il microfono su questo dispositivo.';

  @override
  String get inTune => 'Intonato';

  @override
  String get flat => 'Calante';

  @override
  String get sharp => 'Crescente';

  @override
  String get centsTitle => 'Cent';

  @override
  String centsValue(String cents) {
    return '$cents cent';
  }

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsGeneral => 'Generale';

  @override
  String get languageLabel => 'Lingua';

  @override
  String get languageSystem => 'Come il telefono';

  @override
  String get noteNamesLabel => 'Nomi delle note';

  @override
  String get noteNamesAuto => 'Come la lingua';

  @override
  String get noteNamesSolfege => 'Do Re Mi';

  @override
  String get noteNamesLetters => 'C D E';

  @override
  String get circleLayoutLabel => 'Cerchio dell\'armonia';

  @override
  String get circleLayoutFifths => 'Cerchio delle quinte';

  @override
  String get circleLayoutChromatic => 'In semitoni (Do, Do♯, Re…)';

  @override
  String get aboutTooltip => 'Informazioni su Low End';

  @override
  String get aboutLegalese =>
      'Software libero e open source, distribuito con licenza MIT.';

  @override
  String get aboutDescription =>
      'Metronomo, armonia e accordatore per musicisti. Realizzata da un contrabbassista amatoriale pensando agli amici dell\'orchestra, ma utile a tutti. Low End funziona offline. L’accordatore ascolta sul dispositivo. In Ascolto puoi registrare, salvare e condividere il tuo audio.';

  @override
  String get aboutPiano =>
      'Suoni del pianoforte: Salamander Grand Piano di Alexander Holm (pubblico dominio).';

  @override
  String get aboutBass =>
      'Suoni del contrabbasso: Meatbass di Karoryfer Lecolds, suonato da Drogomir Smolken (CC0, pubblico dominio).';

  @override
  String styleButton(String style) {
    return 'Stile: $style';
  }

  @override
  String get styleHeld => 'Accordo a ogni battuta';

  @override
  String get styleBeat => 'Accordo a ogni tempo';

  @override
  String get styleArpeggio => 'Arpeggio';

  @override
  String get styleWalking => 'Walking bass';

  @override
  String styleTempo(String tempo, String signature) {
    return 'Segue il metronomo: $tempo, $signature';
  }

  @override
  String get beatUnitQuarter => 'semiminima';

  @override
  String get beatUnitDottedQuarter => 'semiminima puntata';

  @override
  String get beatUnitEighth => 'croma';

  @override
  String get pausedForTuner => 'In pausa mentre accordi';

  @override
  String get pausedUnplugged => 'In pausa: cuffie scollegate';

  @override
  String get pausedInterrupted => 'In pausa: il suono è stato interrotto';

  @override
  String get resume => 'Riprendi';

  @override
  String get openSettings => 'Apri impostazioni';

  @override
  String get keepScreenOnTitle => 'Tieni lo schermo acceso';

  @override
  String get keepScreenOnSubtitle => 'Mentre suona o l\'accordatore ascolta';

  @override
  String get setTempo => 'Scrivi il tempo';

  @override
  String get continuousToneTitle => 'Tono continuo';

  @override
  String get continuousToneSubtitle =>
      'Un suono fisso al posto del pianoforte ribattuto.';

  @override
  String get octaveNumberingLabel => 'Numeri delle ottave';

  @override
  String get octaveNumberingHint =>
      'Cambia solo il numero dopo il nome della nota: la nota è la stessa.';

  @override
  String get octaveScientific => 'Scientifica (predefinita)';

  @override
  String get octaveItalian => 'Italiana';

  @override
  String octaveExamples(String a4, String e1) {
    return '$a4 = 440 Hz, il Mi grave del basso è $e1';
  }

  @override
  String get tuningChromatic => 'Cromatico';

  @override
  String get tuningInstrument => 'Strumento';

  @override
  String get tempoLabel => 'Tempo';

  @override
  String get voicingLabel => 'Modalità';

  @override
  String get voicingChordHint => 'Una nota o un accordo, finché lo fermi';

  @override
  String get voicingProgressionHint =>
      'Accordi in sequenza, a tempo col metronomo';

  @override
  String get tuningChromaticHint => 'Qualsiasi nota, senza scegliere la corda';

  @override
  String get tuningGuitar => 'Chitarra';

  @override
  String get tuningViolin => 'Violino';

  @override
  String get tuningViola => 'Viola';

  @override
  String get tuningCello => 'Violoncello';

  @override
  String get tuningUkulele => 'Ukulele';

  @override
  String get tuningBass => 'Basso';

  @override
  String tunerString(String number) {
    return 'Corda $number';
  }

  @override
  String tunerHeard(String note) {
    return 'Senti $note';
  }

  @override
  String get swipeHint =>
      'Scorri in alto o in basso sul cerchio o sulle schede per cambiare sezione.';

  @override
  String get gesturesLockedTitle => 'Blocca i gesti';

  @override
  String get gesturesLockedSubtitle =>
      'Per le prove: niente scorrimenti tra le sezioni';

  @override
  String get inTuneZoneTitle => 'Intonato entro';

  @override
  String get inTuneZoneSubtitle =>
      'Quanto può scostarsi una nota (in cent, centesimi di semitono) e risultare ancora intonata';

  @override
  String get guideTitle => 'Gesti e scorciatoie';

  @override
  String get guideRing =>
      'Ogni sezione parte e si ferma toccando il centro del suo cerchio. In Armonia tocca una nota.';

  @override
  String get guideTempo =>
      'Tieni premuto − o + e il tempo scorre, sempre più veloce.';

  @override
  String get guideSwipe => 'Scorri a destra e a sinistra per cambiare sezione.';

  @override
  String get guideVolume =>
      'Il volume è quello del telefono: usa i suoi tasti.';

  @override
  String get guideDone => 'Ho capito';

  @override
  String writeAs(String note) {
    return 'Scrivi come $note';
  }

  @override
  String get progressionBluesShort => 'Blues';

  @override
  String keyLine(String progression, String key) {
    return '$progression in $key';
  }

  @override
  String keySheetTitle(String key) {
    return 'Tonalità: $key';
  }

  @override
  String get degreeName1 => 'Tonica';

  @override
  String get degreeName2 => 'Sopratonica';

  @override
  String get degreeName3 => 'Mediante';

  @override
  String get degreeName4 => 'Sottodominante';

  @override
  String get degreeName5 => 'Dominante';

  @override
  String get degreeName6 => 'Sopradominante';

  @override
  String get degreeName7 => 'Sensibile';

  @override
  String get degreeName7Minor => 'Sottotonica';

  @override
  String get legendTitle => 'Legenda';

  @override
  String get legendButton => 'Legenda e gradi';

  @override
  String get legendRoot => 'Nota che suona (la fondamentale)';

  @override
  String get legendChord => 'Altre note dell\'accordo che suona';

  @override
  String get legendInKey => 'Note della tonalità';

  @override
  String get legendOutOfKey => 'Note fuori tonalità, sbiadite';

  @override
  String get legendNumerals =>
      'I numeri romani dicono il grado della tonalità su cui poggia ogni accordo. Tocca un numero sul cerchio per leggerlo qui.';

  @override
  String get legendDots =>
      'I pallini sono le battute della progressione: quello pieno è l\'accordo che suona.';

  @override
  String get songsTitle => 'Brani d\'esempio';

  @override
  String get songsSubtitle =>
      'Imposta tonalità, progressione, tempo e stile in un tocco';

  @override
  String get tunerHeld => 'Nota in attesa';

  @override
  String aboutSource(String url) {
    return 'Codice sorgente: $url';
  }

  @override
  String get subdivisionQuarters => 'Semiminime';

  @override
  String get subdivisionEighths => 'Crome';

  @override
  String get subdivisionSwungEighths => 'Crome swing';

  @override
  String get subdivisionTriplets => 'Terzine';

  @override
  String get subdivisionSixteenths => 'Semicrome';

  @override
  String get subdivisionSwungSixteenths => 'Semicrome swing';

  @override
  String get backbeatTitle => 'Click su 2 e 4';

  @override
  String get backbeatSubtitle =>
      'I tempi 1 e 3 tacciono, come il charleston nel jazz. In 2/4 e 4/4.';

  @override
  String get backbeatShort => '2 e 4';

  @override
  String get transpositionTitle => 'Strumento traspositore';

  @override
  String get transpositionSubtitle =>
      'Per gli strumenti in Si♭, Mi♭ e Fa, l\'accordatore cromatico mostra la nota scritta';

  @override
  String get transpositionConcert => 'Suono reale';

  @override
  String transpositionKey(String key) {
    return 'in $key';
  }

  @override
  String get playerTab => 'Ascolto';

  @override
  String get playerTrack => 'Brano';

  @override
  String get playerChoose => 'Scegli un brano';

  @override
  String get playerHubHint => 'Tocca per avviare';

  @override
  String get playerPlay => 'Riproduci';

  @override
  String get playerPause => 'Pausa';

  @override
  String playerTimeOf(String position, String duration) {
    return '$position di $duration';
  }

  @override
  String get pausedForPlayer => 'In pausa mentre ascolti';

  @override
  String get playerUnreadable => 'Questo file non si può aprire.';

  @override
  String get playerMissing => 'Il file non è più disponibile.';

  @override
  String get playerSpeed => 'Velocità';

  @override
  String get playerCaptureStart => 'Segna inizio';

  @override
  String get playerCaptureEnd => 'Segna fine';

  @override
  String get playerLoopActive => 'Loop attivo';

  @override
  String get playerResumeLoop => 'Riattiva loop';

  @override
  String get playerNewPassage => 'Nuovo passaggio';

  @override
  String get playerLoop => 'Loop';

  @override
  String get playerMarkStart => 'Segna l\'inizio qui';

  @override
  String get playerMarkEnd => 'Segna la fine qui';

  @override
  String playerStartAt(String time) {
    return 'Inizio $time';
  }

  @override
  String playerEndAt(String time) {
    return 'Fine $time';
  }

  @override
  String get playerStartEarlier => 'Inizio prima';

  @override
  String get playerStartLater => 'Inizio dopo';

  @override
  String get playerEndEarlier => 'Fine prima';

  @override
  String get playerEndLater => 'Fine dopo';

  @override
  String get guidePlayerLoop =>
      'In Ascolto tocca Segna inizio e Segna fine mentre ascolti. Trascina le aste sulla forma d’onda per rifinire il passaggio.';

  @override
  String get playerHintFlags =>
      'Porta A e B sull\'anello per scegliere il passaggio da ripetere';

  @override
  String get playerHintPlaceStart => 'Tocca l\'anello dove inizia il passaggio';

  @override
  String get playerHintPlaceEnd => 'Tocca l\'anello dove finisce il passaggio';

  @override
  String get playerHintNeedStart => 'Ora porta A dove inizia il passaggio';

  @override
  String get playerHintNeedEnd => 'Ora porta B dove finisce il passaggio';

  @override
  String get playerFlagStart => 'Bandiera A, inizio del passaggio';

  @override
  String get playerFlagEnd => 'Bandiera B, fine del passaggio';
}
