// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Low End';

  @override
  String get tunerTab => 'Afinador';

  @override
  String get metronomeTab => 'Metrónomo';

  @override
  String get harmonyTab => 'Armonía';

  @override
  String get metronomeStart => 'Iniciar el metrónomo';

  @override
  String get metronomeStop => 'Detener el metrónomo';

  @override
  String get metronomeHint => 'Toca para empezar';

  @override
  String bpmValue(String bpm) {
    return '$bpm BPM';
  }

  @override
  String get timeSignature => 'Compás';

  @override
  String get backgroundPlaying => 'Sonando en segundo plano';

  @override
  String get sectionPlaying => 'Sonando';

  @override
  String get slower => 'Más lento';

  @override
  String get faster => 'Más rápido';

  @override
  String get tapTempo => 'Marca el tempo';

  @override
  String get droneStop => 'Detener la armonía';

  @override
  String get subdivisionLabel => 'Subdivisión';

  @override
  String get progressionLabel => 'Progresión';

  @override
  String get progressionMinorTwoFiveOne => 'II–V–I menor';

  @override
  String get progressionBlues => 'Blues de 12 compases';

  @override
  String progressionAndalusianLike(String song) {
    return 'Cadencia andaluza, como $song';
  }

  @override
  String progressionAnatoleLike(String song) {
    return 'El Anatole, como $song';
  }

  @override
  String get progressionCircleOfFifths => 'Círculo de quintas';

  @override
  String get progressionMinorBlues => 'Blues menor';

  @override
  String progressionLike(String song) {
    return 'Como $song';
  }

  @override
  String progressionGiroLike(String song) {
    return 'La progresión de los años 50, como $song';
  }

  @override
  String get progressionSectionPopRock => 'Pop y rock';

  @override
  String get progressionSectionBlues => 'Blues';

  @override
  String get progressionSectionJazz => 'Jazz';

  @override
  String get thanksTitle => 'Agradecimientos';

  @override
  String get thanksInstagram => 'Síguelos en Instagram';

  @override
  String get thanksText =>
      'Gracias a la Power Flower Orchestra de Fossano, que inspiró esta app y la puso a prueba.';

  @override
  String droneChordDiminished(String note) {
    return '$note disminuido';
  }

  @override
  String get referencePitch => 'La de referencia';

  @override
  String get lowerPitch => 'Bajar el La de referencia';

  @override
  String get higherPitch => 'Subir el La de referencia';

  @override
  String get choosePitch => 'Elige un La de referencia estándar';

  @override
  String get pitchBaroque => 'Barroco';

  @override
  String get pitchVerdi => 'Verdi';

  @override
  String get pitchConcert => 'Diapasón estándar';

  @override
  String get pitchOrchestras => 'Orquestas';

  @override
  String referencePitchHint(String note) {
    return 'La frecuencia de $note, para el afinador y la armonía.';
  }

  @override
  String frequencyHz(String frequency) {
    return '$frequency Hz';
  }

  @override
  String stopSound(String name) {
    return 'Detener $name';
  }

  @override
  String playSound(String name) {
    return 'Tocar $name';
  }

  @override
  String get droneHint =>
      'Toca una nota para que suene. Tócala de nuevo para detenerla.';

  @override
  String get chordLabel => 'Acorde';

  @override
  String get noteAlone => 'Solo la nota';

  @override
  String get chordMajor => 'Mayor';

  @override
  String get chordMinor => 'Menor';

  @override
  String get chordDominant => 'Séptima de dominante (7)';

  @override
  String get chordDominantFlat9 => 'Séptima de dominante con ♭9 (7♭9)';

  @override
  String get chordMajor7 => 'Séptima mayor (maj7)';

  @override
  String get chordMinor7 => 'Séptima menor (m7)';

  @override
  String get chordHalfDiminished => 'Semidisminuido (m7♭5)';

  @override
  String get chordDiminished => 'Disminuido (dim)';

  @override
  String get chordSus4 => 'Cuarta suspendida (sus4)';

  @override
  String droneChordHalfDiminished(String note) {
    return '$note semidisminuido';
  }

  @override
  String progressionInKey(String name, String key) {
    return '$name en $key';
  }

  @override
  String droneChordMajor(String note) {
    return '$note mayor';
  }

  @override
  String droneChordMinor(String note) {
    return '$note menor';
  }

  @override
  String droneChordSeventh(String note) {
    return '${note}7';
  }

  @override
  String get audioUnavailable =>
      'No se pudo iniciar el sonido en este dispositivo.';

  @override
  String get audioDownloadFailed =>
      'No se pudieron descargar los sonidos. Comprueba la conexión y toca de nuevo.';

  @override
  String get soundsPreparing => 'Preparando los sonidos…';

  @override
  String get soundsDownloadingSlowly =>
      'Descargando los sonidos: la conexión es lenta. Espera un momento.';

  @override
  String get startListening => 'Escuchar';

  @override
  String get stopListening => 'Pausa';

  @override
  String get tunerWillPause => 'Escuchar pone en pausa lo que suena';

  @override
  String get tunerIdleHint => 'Afinador en pausa: toca Escuchar';

  @override
  String get playAString => 'Toca una nota';

  @override
  String get micPermissionDenied =>
      'Low End necesita el micrófono para oír tu instrumento. Si dijiste que no, permítelo en los ajustes del teléfono, en Aplicaciones › Low End › Permisos.';

  @override
  String get micPermissionDeniedWeb =>
      'Low End necesita el micrófono para oír tu instrumento. Si dijiste que no, permítelo para esta página en los ajustes del navegador y toca Escuchar de nuevo.';

  @override
  String get micUnavailable =>
      'No se pudo iniciar el micrófono en este dispositivo.';

  @override
  String get inTune => 'Afinado';

  @override
  String get flat => 'Bajo';

  @override
  String get sharp => 'Alto';

  @override
  String get centsTitle => 'Cents';

  @override
  String centsValue(String cents) {
    return '$cents cents';
  }

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsGeneral => 'General';

  @override
  String get languageLabel => 'Idioma';

  @override
  String get languageSystem => 'Como el teléfono';

  @override
  String get noteNamesLabel => 'Nombres de las notas';

  @override
  String get noteNamesAuto => 'Según el idioma';

  @override
  String get noteNamesSolfege => 'Do Re Mi';

  @override
  String get noteNamesLetters => 'C D E';

  @override
  String get circleLayoutLabel => 'Círculo de la armonía';

  @override
  String get circleLayoutFifths => 'Círculo de quintas';

  @override
  String get circleLayoutChromatic => 'Por semitonos (Do, Do♯, Re…)';

  @override
  String get aboutTooltip => 'Acerca de Low End';

  @override
  String get aboutLegalese =>
      'Software libre y de código abierto, publicado con licencia MIT.';

  @override
  String get aboutDescription =>
      'Metrónomo, armonía y afinador para músicos. Hecha por un contrabajista aficionado pensando en los amigos de la orquesta, y útil para todos. Low End funciona sin conexión: el micrófono solo se usa mientras el afinador escucha, y ningún sonido ni dato sale de tu teléfono.';

  @override
  String get aboutPiano =>
      'Sonidos del piano: Salamander Grand Piano de Alexander Holm (dominio público).';

  @override
  String get aboutBass =>
      'Sonidos del contrabajo: Meatbass de Karoryfer Lecolds, tocado por Drogomir Smolken (CC0, dominio público).';

  @override
  String styleButton(String style) {
    return 'Estilo: $style';
  }

  @override
  String get styleHeld => 'Acorde en cada compás';

  @override
  String get styleBeat => 'Acorde en cada tiempo';

  @override
  String get styleArpeggio => 'Arpegio';

  @override
  String get styleWalking => 'Walking bass';

  @override
  String styleTempo(String tempo, String signature) {
    return 'Sigue al metrónomo: $tempo, $signature';
  }

  @override
  String get beatUnitQuarter => 'negra';

  @override
  String get beatUnitDottedQuarter => 'negra con puntillo';

  @override
  String get beatUnitEighth => 'corchea';

  @override
  String get pausedForTuner => 'En pausa mientras afinas';

  @override
  String get pausedUnplugged => 'En pausa: auriculares desconectados';

  @override
  String get pausedInterrupted => 'En pausa: el sonido se interrumpió';

  @override
  String get resume => 'Reanudar';

  @override
  String get openSettings => 'Abrir ajustes';

  @override
  String get keepScreenOnTitle => 'Mantener la pantalla encendida';

  @override
  String get keepScreenOnSubtitle => 'Mientras suena o el afinador escucha';

  @override
  String get setTempo => 'Escribe el tempo';

  @override
  String get continuousToneTitle => 'Sonido continuo';

  @override
  String get continuousToneSubtitle =>
      'Un sonido fijo en lugar del piano tocado una y otra vez.';

  @override
  String get octaveNumberingLabel => 'Números de las octavas';

  @override
  String get octaveNumberingHint =>
      'Solo cambia el número tras el nombre de la nota: la nota es la misma.';

  @override
  String get octaveScientific => 'Científica (predeterminada)';

  @override
  String get octaveItalian => 'Franco-belga';

  @override
  String octaveExamples(String a4, String e1) {
    return '$a4 = 440 Hz, el Mi grave del bajo es $e1';
  }

  @override
  String get tuningChromatic => 'Cromático';

  @override
  String get tuningInstrument => 'Instrumento';

  @override
  String get tempoLabel => 'Tempo';

  @override
  String get voicingLabel => 'Modo';

  @override
  String get voicingChordHint => 'Una nota o un acorde, hasta que lo detengas';

  @override
  String get voicingProgressionHint =>
      'Acordes uno tras otro, a tempo con el metrónomo';

  @override
  String get tuningChromaticHint => 'Cualquier nota, sin elegir cuerda';

  @override
  String get tuningGuitar => 'Guitarra';

  @override
  String get tuningViolin => 'Violín';

  @override
  String get tuningViola => 'Viola';

  @override
  String get tuningCello => 'Violonchelo';

  @override
  String get tuningUkulele => 'Ukelele';

  @override
  String get tuningBass => 'Bajo';

  @override
  String tunerString(String number) {
    return 'Cuerda $number';
  }

  @override
  String tunerHeard(String note) {
    return 'Suena $note';
  }

  @override
  String get swipeHint =>
      'Desliza arriba o abajo sobre el círculo o las pestañas para cambiar de sección.';

  @override
  String get gesturesLockedTitle => 'Bloquear los gestos';

  @override
  String get gesturesLockedSubtitle =>
      'Para los ensayos: sin deslizar entre secciones';

  @override
  String get inTuneZoneTitle => 'Afinado dentro de';

  @override
  String get inTuneZoneSubtitle =>
      'Cuánto puede desviarse una nota, en cents (centésimas de semitono), y seguir apareciendo afinada';

  @override
  String get guideTitle => 'Gestos y atajos';

  @override
  String get guideRing =>
      'Cada sección empieza y se detiene tocando el centro de su círculo. En Armonía, toca una nota.';

  @override
  String get guideTempo =>
      'Mantén pulsado − o + y el tempo corre, cada vez más rápido.';

  @override
  String get guideSwipe =>
      'Desliza a izquierda y derecha para cambiar de sección.';

  @override
  String get guideVolume => 'El volumen es el del teléfono: usa sus botones.';

  @override
  String get guideDone => 'Entendido';

  @override
  String writeAs(String note) {
    return 'Escribir como $note';
  }

  @override
  String get progressionBluesShort => 'Blues';

  @override
  String keyLine(String progression, String key) {
    return '$progression en $key';
  }

  @override
  String keySheetTitle(String key) {
    return 'Tonalidad: $key';
  }

  @override
  String get degreeName1 => 'Tónica';

  @override
  String get degreeName2 => 'Supertónica';

  @override
  String get degreeName3 => 'Mediante';

  @override
  String get degreeName4 => 'Subdominante';

  @override
  String get degreeName5 => 'Dominante';

  @override
  String get degreeName6 => 'Superdominante';

  @override
  String get degreeName7 => 'Sensible';

  @override
  String get degreeName7Minor => 'Subtónica';

  @override
  String get legendTitle => 'Leyenda';

  @override
  String get legendButton => 'Leyenda y grados';

  @override
  String get legendRoot => 'Nota que suena (la fundamental)';

  @override
  String get legendChord => 'Otras notas del acorde que suena';

  @override
  String get legendInKey => 'Notas de la tonalidad';

  @override
  String get legendOutOfKey => 'Notas fuera de la tonalidad, atenuadas';

  @override
  String get legendNumerals =>
      'Los números romanos indican el grado de la tonalidad sobre el que se construye cada acorde. Toca uno en el círculo para leerlo aquí.';

  @override
  String get legendDots =>
      'Los puntos son los compases de la progresión: el lleno es el acorde que suena.';

  @override
  String get songsTitle => 'Temas de ejemplo';

  @override
  String get songsSubtitle =>
      'Fija la tonalidad, la progresión, el tempo y el estilo con un toque';

  @override
  String get tunerHeld => 'Manteniendo la última nota';

  @override
  String aboutSource(String url) {
    return 'Código fuente: $url';
  }

  @override
  String get subdivisionQuarters => 'Negras';

  @override
  String get subdivisionEighths => 'Corcheas';

  @override
  String get subdivisionSwungEighths => 'Corcheas swing';

  @override
  String get subdivisionTriplets => 'Tresillos';

  @override
  String get subdivisionSixteenths => 'Semicorcheas';

  @override
  String get subdivisionSwungSixteenths => 'Semicorcheas swing';

  @override
  String get backbeatTitle => 'Clic en 2 y 4';

  @override
  String get backbeatSubtitle =>
      'Los tiempos 1 y 3 quedan en silencio, como el charles en el jazz. En 2/4 y 4/4.';

  @override
  String get backbeatShort => '2 y 4';

  @override
  String get transpositionTitle => 'Instrumento transpositor';

  @override
  String get transpositionSubtitle =>
      'Para instrumentos en Si♭, Mi♭ y Fa, el afinador cromático indica la nota escrita';

  @override
  String get transpositionConcert => 'Sonido real';

  @override
  String transpositionKey(String key) {
    return 'en $key';
  }

  @override
  String get playerTab => 'Escucha';

  @override
  String get playerTrack => 'Pista';

  @override
  String get playerChoose => 'Elige una pista';

  @override
  String get playerPlay => 'Reproducir';

  @override
  String get playerPause => 'Pausa';

  @override
  String playerTimeOf(String position, String duration) {
    return '$position de $duration';
  }

  @override
  String get pausedForPlayer => 'En pausa mientras escuchas';

  @override
  String get playerUnreadable => 'No se puede abrir este archivo.';

  @override
  String get playerMissing => 'El archivo ya no está disponible.';

  @override
  String get playerSpeed => 'Velocidad';

  @override
  String get playerSpeedTitle => 'Velocidad de escucha';

  @override
  String get playerLoop => 'Bucle';

  @override
  String get playerLoopStart => 'Inicio';

  @override
  String get playerLoopEnd => 'Fin';

  @override
  String get playerMarkStart => 'A aquí';

  @override
  String get playerMarkEnd => 'B aquí';

  @override
  String get playerStartEarlier => 'Inicio antes';

  @override
  String get playerStartLater => 'Inicio después';

  @override
  String get playerEndEarlier => 'Fin antes';

  @override
  String get playerEndLater => 'Fin después';

  @override
  String get guidePlayerLoop =>
      'En Escucha, mantén pulsado el círculo y desliza para dibujar un bucle.';
}
