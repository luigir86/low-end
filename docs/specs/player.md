# Player (Ascolto): piano di riferimento

Il quarto tab di Low End: un brano proprio, rallentato senza cambiare intonazione, con un passaggio che si ripete. Questo file dice **come** si costruisce e in quali passi; **cosa** l'app deve fare sta in [requisiti.md](requisiti.md), sezione 2.10 (codici RF-PLY). Se i due file dicono cose diverse vale `requisiti.md`, e questo file va corretto.

Revisione 2, 6 novembre 2026: riscrive il piano dopo la prima prova di Luigi su PR #122 e #123. La revisione 1 (stesso giorno, prima del codice) è nella storia di git di questo file e nel documento "Tab Player: piano di implementazione"; la valutazione delle strade da cui è partita non serve più.

## 1. Come si usa

- **Spec prima del codice.** Una decisione nuova si scrive prima in `requisiti.md`, poi qui, poi nel codice. Ogni PR cita i codici RF-PLY che realizza, nei commit, nella descrizione e nei nomi dei test, e alla fine aggiorna la colonna Stato (◐ unita, ✓ dopo la prova sul telefono).
- **Per chi implementa (una sessione Sonnet che lavora da sola).** Leggi `CLAUDE.md`, `docs/architecture.md`, `docs/specs/README.md`, la sezione 2.10 di `requisiti.md` e questo file. Poi una PR alla volta, nell'ordine della sezione 6, ognuna su un ramo nuovo da `main` aggiornato e solo dopo che la precedente è unita. Ogni PR lascia l'app funzionante e passa format, analyze, test e le build APK e web della CI.
- **Le scelte di prodotto sono già fatte.** Una scelta tecnica non coperta qui: la più semplice che rispetta `CLAUDE.md`, scritta nella PR sotto "Scelte fatte". Fermati solo ai punti segnati CANCELLO, dove servono Luigi e il telefono. Le domande della sezione 10 hanno una risposta predefinita: usala senza aspettare.
- **Flutter nel container.** Se manca, scarica `flutter_linux_3.47.9-stable.tar.xz` da `https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/`, scompattalo fuori dal repository e metti `flutter/bin` nel PATH.
- **Da non fare:** spettrogramma, file_picker, just_audio_background, riconoscimento del tempo, registrazione (fase 1b, da approvare a parte), colori o testi scritti nel codice, dipendenze nuove oltre a quelle già in `pubspec.yaml`.

## 2. Dove siamo

In `main` dal 6/11:

| PR | Cosa porta | Codici |
| --- | --- | --- |
| #122 | Quarto tab: scelta del file, play e pausa dal centro, toro con le tacche e il punto di ascolto, regole con le altre sezioni, notifica, azioni `player_open`, `player_play`, `player_pause`, `player_seek` | RF-GEN-01, RF-PLY-01…07, 16 |
| #123 | Velocità 50-125%, loop A-B con "A qui" e "B qui", segmenti Inizio/Fine con − e + da 0,1 s, arco disegnato con pressione lunga, azioni `player_speed`, `player_loop`, `player_mark`, `player_loop_nudge`, `player_loop_off` | RF-PLY-08…12 |

File principali: `lib/audio/track_output.dart` e `just_audio_track_output.dart` (il motore, just_audio 0.10.6), `lib/audio/track_files.dart` e `system_track_files_{io,web}.dart` (i file), `android/.../TrackFiles.kt` (canale `low_end/track_files`), `lib/features/player/` (`player_controller.dart`, `player_dial.dart`, `player_panel.dart`, `clock_text.dart`), `lib/widgets/step_button.dart`.

Le prove sul telefono del CANCELLO 1 (velocità al 70 e al 50%, stacco del loop, peso dell'APK, iPhone) non sono ancora state riportate: passano al CANCELLO 2.

## 3. Cosa cambia dopo la prova di Luigi (6/11)

| Punto di Luigi | Decisione | Perché |
| --- | --- | --- |
| 1. Ascolto come terzo tab | Ordine Metronomo, Armonia, **Ascolto**, Accordatore. Il nome resta Player / Ascolto / Escucha / Écoute | Deciso da Luigi. La sezione si salva per nome, quindi niente migrazione |
| 2. A e B con "A qui / B qui" non è intuitivo; meglio toccare il toro | Il passaggio si sceglie **sul toro**: pressione lunga e scorrere disegna A-B (c'era già, ma nessuno lo vedeva: ora lo spiega la riga dei messaggi); le maniglie **A e B si trascinano direttamente**. I pulsanti "A qui" e "B qui" spariscono dallo schermo; "segna qui" resta per il lettore di schermo e per gli assistenti | Il gesto diretto è quello che Luigi si aspetta; serve però la vista Passaggio (sotto) perché sia preciso |
| 3. Il pallino non si capisce; meglio un segmento che scorre | Il punto di ascolto diventa un **cursore**: un segmento radiale che attraversa tutto lo spessore del toro, come la linea di riproduzione dei programmi audio | Letto "segmento" come la linea dei programmi audio, non come un arco |
| 4. Manca la forma d'onda del disegno | La **forma d'onda** entra subito (era la vecchia PR 4): i picchi del brano ogni 10 ms, disegnati dentro il toro, simmetrici attorno al suo centro. Niente spettrogramma | Lo spettrogramma costa migliaia di FFT e sul web bloccherebbe lo schermo; i picchi mostrano già attacchi, pieni e pianissimi, che è ciò che serve per mettere A e B |
| 5. − e + da 0,1 s sono troppo grossi e lontani da A e B | **Ogni estremo ha i suoi − e +**, sotto il suo tempo: A a sinistra, B a destra, il Loop in mezzo. Un tocco sposta di **10 ms**, tenuto accelera e dopo 2,4 s va di 100 ms. I tempi si leggono al centesimo (1:12,34) | Letto "pulsanti legati ai segmenti A e B" come − e + attaccati a ciascun estremo; la scelta Inizio/Fine sparisce |
| Aggiunta del piano | **Vista Passaggio**: con il loop acceso il giro del toro è il passaggio, più un margine prima e dopo; con il loop spento è il brano intero | Su un brano di 6 minuti un secondo vale circa 2 punti sul toro, meno della punta di un dito: senza questa vista il tocco diretto non può essere preciso. In un passaggio di 8 secondi un secondo vale circa 70 punti |

Restano come sono: motore e regole tra le sezioni, notifica, velocità e il suo foglio, la regola "il suono segue dopo 0,3 s di quiete", la pressione lunga per disegnare (lo scorrimento tra le sezioni resta libero), le azioni per assistenti (cambiano solo due descrizioni).

## 4. Requisiti in breve

Il testo che vale è in `requisiti.md`; qui solo dove si realizzano.

| Codice | In breve | PR |
| --- | --- | --- |
| RF-GEN-01 | Quattro sezioni: Metronomo, Armonia, Ascolto, Accordatore | 3 |
| RF-PLY-03 | Toro = orologio del brano, con cursore radiale, tacche e forma d'onda | 3 |
| RF-PLY-15 | Forma d'onda: picchi ogni 10 ms, fuori dal thread dello schermo, che si riempie mentre si legge; sul web fino a 15 minuti e 40 MB | 3 |
| RF-PLY-09 | "Segna qui" (meno 150 ms × velocità) solo per lettore di schermo e assistenti | 4 |
| RF-PLY-10 | − e + per ciascun estremo, 10 ms al tocco, 100 ms tenuti; tempi al centesimo | 4 |
| RF-PLY-11 | Sul toro: pressione lunga e scorrere disegna il passaggio; le maniglie A e B si trascinano | 4 |
| RF-PLY-12 | Interruttore Loop in mezzo tra A e B; acceso = ripete e mostra la vista Passaggio | 4 |
| RF-PLY-17 | Vista Passaggio: il giro è il passaggio con i margini; transizione animata | 4 |
| RF-PLY-18 | Riga dei messaggi: errori, oppure come si sceglie e si ritocca il passaggio | 4 |
| RF-PLY-16 | Accessibilità senza trascinare: azioni "segna qui" sul toro, − e + | 4 |
| RF-PLY-13 | Brano, loop e velocità tornano al prossimo avvio (Android) | 5 |
| RF-PLY-14 | Titolo e autore dai tag | 5 |

## 5. Progetto

### 5.1 La schermata

`PlayerPanel` resta un `DialLayout`: il quadrante e tre righe da 80 dp sotto. Larghezza minima da reggere 288 dp (telefono da 320), testo fino a 2×, quattro lingue (`layout_review_test` e `row_heights_test` girano già su ogni `AppSection`).

| Posto | Senza brano | Con brano, senza passaggio | Con passaggio |
| --- | --- | --- | --- |
| Toro | Anello spento; al centro cartella e "Scegli un brano" | Brano intero: forma d'onda, tacche, cursore | Maniglie A e B; loop acceso: vista Passaggio |
| Prima riga (`header`): messaggi | Vuota, o l'errore | "Tieni premuto sull'anello e scorri per scegliere un passaggio da ripetere" | "Trascina A e B sull'anello per ritoccare il passaggio" |
| Seconda riga (`upper`) | Brano ("Scegli un brano") e Velocità, come oggi | uguale | uguale |
| Terza riga (`lower`) | Gruppo A, Loop, gruppo B, spenti | uguale, spenti ("A –", "B –") | A, Loop, B accesi |

**Riga dei messaggi** (RF-PLY-18). Un solo testo centrato, al massimo due righe, `bodyMedium` in `onSurfaceVariant`. Un errore ("Questo file non si può aprire.", "Il file non è più disponibile.") prende il posto del suggerimento, in `colorScheme.error` e in `Semantics(liveRegion: true)`; oggi l'errore sta sotto i campi della seconda riga e va spostato qui. Il suggerimento non è una regione live: non deve parlare a ogni cambio.

**Terza riga** (RF-PLY-10, RF-PLY-12). `Row` con `Expanded(gruppo A)`, l'interruttore Loop, `Expanded(gruppo B)`, separati da `rowGap`. Un gruppo è una `Column` centrata: in alto il tempo ("A 1:12,34", `labelLarge`, `FittedBox(scaleDown)`), sotto due `StepButton` (− e +) affiancati con 8 dp in mezzo. Misure a 288 dp: (288 − 48 − 2 × 8) / 2 = 112 dp per gruppo, contro i 104 che servono (2 × 48 + 8). Il Loop è il `RowButton` di oggi (icone `repeat` / `repeat_on`, pieno mentre ripete, `Semantics(toggled:)`, almeno 48 dp). Senza passaggio i − e + hanno `onStep: null` (spenti come ogni `IconButton` di Material) e il tempo dice "A –"; il testo resta pieno, non spento, perché deve passare il controllo del contrasto.

Spariscono: il `SegmentedButton` Inizio/Fine, "A qui", "B qui", `PlayerController.edge` e `selectEdge`.

### 5.2 Il toro: strati e misure

`w` = spessore del toro (`ringOuter − ringInner` di `DialGeometry`, circa 50 dp su un quadrante da 300); le frazioni si misurano da `ringInner` verso fuori. Due `CustomPainter`, ognuno in un `RepaintBoundary` come oggi.

| Strato | Dove | Colore | Si ridisegna |
| --- | --- | --- | --- |
| Base | Tutto il toro, `paintSegment` con bordo | `outlineVariant`, bordo `outline` | Mai, salvo cambio di tema |
| Forma d'onda | Simmetrica attorno a 0,5 w; mezza altezza fino a 0,40 w; il silenzio resta una linea sottile (0,01 w) | Fuori dal passaggio `onSurfaceVariant`; dentro il passaggio, a loop acceso, `primary` | Quando arrivano picchi, cambia la finestra o il passaggio |
| Tacche | Bordo esterno, da 0,92 a 1,0 w, tratto 1,5 dp | `onSurfaceVariant` | Con la finestra |
| Cucitura (solo vista Passaggio) | Ore 12, tutto lo spessore, tratto 2 dp; la forma d'onda lascia libero 1° per parte | `outline` | Con la finestra |
| Maniglie A e B | Linea radiale su tutto lo spessore, 2 dp; impugnatura: disco di raggio 0,2 w con la lettera (A a 0,25 w, B a 0,75 w), bordo 1,5 dp | Linea e disco `primary`, lettera `onPrimary` in grassetto (0,26 w), bordo `surface` | Con passaggio e finestra |
| Cursore | Segmento radiale da −0,06 a 1,06 w: tratto 3 dp sopra un tratto 6 dp | `onSurface` sopra `surface` | A ogni frame mentre suona (secondo painter, mosso dal `Ticker` di oggi) |

La forma d'onda si disegna come una sola `Path` chiusa per colore (bordo esterno avanti, bordo interno indietro), non come centinaia di linee. Spicchi: `min(720, fotogrammi da 10 ms nella finestra)`. Uno spicchio non ancora letto non si disegna, così la forma si riempie in senso orario mentre il brano viene letto. All'arrivo dei primi picchi, una dissolvenza (`Durations.medium1`, `Easing.standard`), nessuna con le animazioni ridotte.

Le impugnature stanno a raggi diversi apposta: anche quando A e B sono vicinissimi (un passaggio breve nel brano intero) restano entrambe visibili e afferrabili. Il colore non è l'unico segnale (WCAG 1.4.1): il passaggio ha anche le maniglie con le lettere e l'interruttore Loop.

### 5.3 La finestra: brano intero o passaggio

Il toro mostra una finestra del brano, `RingWindow(from, to)`, mappata sul giro intero da ore 12 in senso orario. Funzioni pure in `player_dial.dart` (o in un file nuovo `ring_window.dart`), coperte da `player_ring_test`:

```dart
@immutable
class RingWindow {
  const RingWindow(this.from, this.to);
  final Duration from, to;

  /// Tutto il brano (RF-PLY-03).
  factory RingWindow.whole(Duration duration) => RingWindow(Duration.zero, duration);

  /// Il passaggio [a]-[b] con un margine per parte: un quarto della sua
  /// lunghezza, tra 0,5 e 10 s, senza uscire dal brano (RF-PLY-17).
  factory RingWindow.passage(Duration a, Duration b, Duration duration);

  Duration get length => to - from;
  double angleOf(Duration t);      // 0..2π, fuori dalla finestra si ferma ai bordi
  Duration timeAt(double angle);   // il contrario
  RingWindow lerp(RingWindow other, double t);
}

/// Tacche: 0,5 s sotto i 5 s di finestra, 1 s sotto i 20 s, 5 s sotto il
/// minuto, 10 s sotto i 2 minuti, 1 minuto fino a 20, poi 5 minuti. Cadono
/// sui multipli veri del brano (1:13,0, 1:14,0…), non della finestra.
Duration tickInterval(Duration windowLength);
List<Duration> tickTimes(RingWindow window);
```

`ringAngle`, `timeAtAngle` e le `tickTimes(duration)` di oggi diventano casi della finestra intera; i test esistenti restano veri.

**Quale finestra** (RF-PLY-17). Loop acceso: `RingWindow.passage(A, B, durata)`. Loop spento o senza passaggio: `RingWindow.whole(durata)`. Nient'altro decide la vista: non c'è un pulsante a parte (domanda 1 della sezione 10).

**Come cambia.**
- Il loop si accende o si spegne (interruttore, passaggio appena disegnato, tocco fuori dal passaggio): la finestra va da quella mostrata alla nuova in `Durations.medium4`, con `Easing.emphasizedDecelerate` entrando nel passaggio ed `Easing.emphasizedAccelerate` uscendo. Il passaggio sembra aprirsi fino a riempire il giro, e richiudersi al suo posto nel brano.
- A o B cambiano a loop acceso (trascinamento, − e +): la finestra **non** si muove mentre il dito lavora. Si riadatta quando A e B restano fermi per `PlayerController.settleAfter` (0,3 s) e nessuna maniglia è afferrata, in `Durations.short4` con `Easing.standard`.
- Con le animazioni ridotte (`MediaQuery.disableAnimations`) la finestra salta subito.

Il cursore dentro la vista Passaggio non può uscire dalla finestra: a loop acceso l'ascolto sta tra A e B; un tocco fuori spegne il loop e la vista torna al brano intero.

### 5.4 I gesti sul toro

| Gesto | Dove parte | Effetto |
| --- | --- | --- |
| Tocco | Sul toro, fuori dal centro e dalle impugnature | Sposta l'ascolto nel punto toccato della finestra mostrata. A loop acceso, fuori da A-B spegne il loop (regola di oggi), quindi la vista torna al brano intero |
| Trascinare un'impugnatura | Entro 24 dp dal centro del suo disco (bersaglio da 48 dp) o dalla sua linea radiale; se due sono vicine, la più vicina. Il bersaglio largo serve soprattutto nella vista Passaggio, dove le maniglie sono lontane: un dito che manca di poco la maniglia non deve cambiare sezione | Sposta quell'estremo seguendo il dito (`moveEdge`, sezione 5.6), con un tick aptico (`HapticFeedback.selectionClick`) all'inizio. Limiti: quelli di sempre (A ≤ B − 1 s, B ≥ A + 1 s, dentro il brano) e la finestra mostrata. Il centro del quadrante intanto mostra il tempo dell'estremo |
| Pressione lunga e scorrere | Sul toro, fuori dalle impugnature | Disegna un passaggio nuovo, come oggi; sotto 1 s vale come tocco. Lasciato il dito, il loop si accende e la vista va sul passaggio. Nella vista Passaggio disegna dentro la finestra |
| Scorrere | Ovunque fuori dalle impugnature | Cambia sezione, come negli altri tab |

**Il trascinamento delle maniglie vince sullo scorrimento tra le sezioni** solo quando parte da un'impugnatura. Il `PageView` riconosce lo scorrimento orizzontale dopo pochi punti di movimento: un riconoscitore normale arriverebbe in parità. Questo invece si dichiara vincitore già al tocco, ma solo sulle impugnature; altrove non partecipa e tocco, pressione lunga e scorrimento funzionano come prima. Verificato sui sorgenti di Flutter 3.47.9: `isPointerAllowed`, `resolvePointer` e il vincitore anticipato (`eagerWinner`) dell'arena.

```dart
/// Un trascinamento che vince subito, prima dello scorrimento tra le
/// sezioni, quando il dito si posa su un'impugnatura del passaggio
/// (RF-PLY-11); altrove non partecipa.
class _GripDrag extends PanGestureRecognizer {
  _GripDrag({required this.grips});

  /// L'estremo sotto [local] (coordinate del quadrante), o null.
  final LoopEdge? Function(Offset local) grips;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      grips(event.localPosition) != null && super.isPointerAllowed(event);

  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolvePointer(event.pointer, GestureDisposition.accepted);
  }
}
```

Si monta con un `RawGestureDetector` (`GestureRecognizerFactoryWithHandlers<_GripDrag>`) grande quanto il quadrante, accanto al `GestureDetector` di tocco e pressione lunga, sotto il pulsante del centro nello `Stack`. `onStart` sceglie l'estremo, `onUpdate` chiama `moveEdge` con il tempo sotto il dito, `onEnd` e `onCancel` lasciano l'impugnatura. Il dito non fa il giro oltre ore 12: come nel disegno di oggi, un salto di più di mezzo giro si ferma al bordo della finestra (il suo inizio o la sua fine). Una funzione pubblica `gripCenter(LoopEdge, RingWindow, …, Size)` dà ai test dove toccare.

### 5.5 Il centro del quadrante

Come oggi: play o pausa, oppure "Scegli un brano". Mentre un'impugnatura è afferrata, la riga del tempo sotto l'icona diventa quella dell'estremo, "A 1:12,34" o "B 1:31,00", e torna "1:12 / 6:03" quando il dito si alza.

### 5.6 Il controller

Modifiche a `PlayerController`:

| Prima | Dopo | PR |
| --- | --- | --- |
| `fineStep` 100 ms, `coarseStep` 1 s | `fineStep` 10 ms, `coarseStep` 100 ms (lo `StepButton` passa a `coarseStep` dopo 2,4 s, come oggi) | 4 |
| `edge`, `selectEdge(LoopEdge)` | Tolti: ogni estremo ha i suoi − e + | 4 |
| `nudge(edge, by)` | `moveEdge(LoopEdge edge, Duration to)`: posizione assoluta, stessi limiti, stessa quiete di 0,3 s prima che il suono segua (ritoccando A riparte da A, ritoccando B riparte 2 s prima di B, mai prima di A). `nudge` diventa `moveEdge(edge, attuale + by)` | 4 |
| `mark(edge)` | Uguale, senza `_edge`; lo usano solo le azioni del lettore di schermo e `player_mark` | 4 |
| — | `TrackPeaks? get peaks`: i picchi del brano aperto, null senza brano. La lettura parte quando `open` è riuscito, con il controllo di generazione di oggi, e si annulla con un brano nuovo, un errore o `dispose`. Il controller **non** notifica a ogni pezzo: il quadrante ascolta `peaks` | 3 |

`TrackPeaks` (`lib/features/player/track_peaks.dart`, Dart puro, `ChangeNotifier`):

```dart
class TrackPeaks extends ChangeNotifier {
  /// Ogni valore copre 10 ms di brano.
  static const frame = Duration(milliseconds: 10);

  /// Aggiunge i picchi letti dopo quelli già arrivati (0..32767, il campione
  /// più forte in valore assoluto di quei 10 ms, su tutti i canali).
  void add(Uint16List chunk);
  void finish();           // letto tutto
  void fail();             // non si può leggere: niente forma d'onda, niente messaggio
  int get length;          // fotogrammi arrivati
  bool get complete;
  int get version;         // cresce a ogni add, per la cache del painter

  /// Le altezze 0..1 di [count] spicchi uguali tra [from] e [to]: per ogni
  /// spicchio il picco più alto, in decibel rispetto al picco più alto
  /// arrivato finora, su 48 dB (0 dB = 1, −48 dB o meno = 0). NaN per gli
  /// spicchi non ancora letti.
  Float32List heights(Duration from, Duration to, int count);
}
```

I valori stanno in un solo `Uint16List` che raddoppia quando serve (20 minuti = 120.000 valori, 240 KB). `heights` scorre i fotogrammi della finestra: anche 120.000 letture per frame durante un'animazione di 400 ms restano sotto il millisecondo; il painter tiene il risultato finché finestra, `count` e `version` non cambiano.

### 5.7 La forma d'onda: Android e web

L'interfaccia cambia (PR 3). In `TrackFiles`, `envelope(track, points)` lascia il posto a:

```dart
/// I picchi di [track], uno ogni 10 ms, a pezzi dall'inizio mentre il file
/// si legge (RF-PLY-15). Lo stream finisce quando il brano è letto tutto, o
/// con un errore se non si può; annullare l'iscrizione ferma la lettura.
/// Sul web, oltre i limiti di RF-PLY-15, finisce subito con un errore.
Stream<Uint16List> peaks(TrackRef track, {required Duration duration});
```

`FakeTrackFiles` riceve uno `StreamController` per i test (pezzi a comando, errore, chiusura).

**Android.** File nuovo `android/.../TrackPeaks.kt`, sul modello di `TrackFiles.kt`, attaccato in `MainActivity.configureFlutterEngine` accanto agli altri. Un `EventChannel("low_end/track_peaks")`; gli argomenti di `listen` sono `{uri}`. Un solo brano alla volta: un `listen` nuovo chiude il precedente (l'`EventChannel` di Android chiama già `onCancel` sul vecchio). Attenzione all'ordine in Dart: il controller annulla l'iscrizione vecchia **prima** di aprire la nuova, perché un `cancel` arrivato dopo chiuderebbe quella nuova (sul lato Android `onCancel` ferma la lettura attiva, qualunque sia). Il lavoro va su un `Executors.newSingleThreadExecutor()` a priorità `THREAD_PRIORITY_BACKGROUND`, con un `AtomicBoolean` per l'annullamento:

1. `MediaExtractor.setDataSource(context, uri, null)`, prima traccia con `KEY_MIME` che comincia per `audio/`, `selectTrack`.
2. `MediaCodec.createDecoderByType(mime)`, `configure(format, null, null, 0)`, `start()`.
3. Ciclo: `dequeueInputBuffer(10_000)` → `readSampleData` → `queueInputBuffer` con `sampleTime` (a fine file `BUFFER_FLAG_END_OF_STREAM`); `dequeueOutputBuffer(info, 10_000)`: a `INFO_OUTPUT_FORMAT_CHANGED` rileggi frequenza, canali e `KEY_PCM_ENCODING` (assente = 16 bit); il primo buffer d'uscita parte dal fotogramma `info.presentationTimeUs / 10_000`, poi si contano i campioni, e ci si riallinea a `presentationTimeUs` solo se un buffer salta più di 10 ms rispetto al conto (così la forma d'onda segue la linea del tempo del file anche se il decoder salta un pezzo): ogni `frequenza / 100` campioni per canale chiudi un fotogramma con il picco assoluto su tutti i canali (16 bit così com'è; float × 32767). `releaseOutputBuffer(index, false)`.
4. Ogni 250 ms, e alla fine, manda i fotogrammi nuovi sul thread principale (`Handler(Looper.getMainLooper())`) come `ByteArray` di `UInt16` little-endian; alla fine `endOfStream()`. Codifiche diverse da 16 bit e float, o qualunque eccezione: `error("unreadable", …)`.
5. Sempre `stop()`/`release()` di codec ed extractor in `finally`, anche annullando.

In Dart (`system_track_files_io.dart`) i byte diventano `Uint16List` leggendo con `ByteData.getUint16(i * 2, Endian.little)`: il buffer del canale può non essere allineato a 2 byte, e `asUint16List` lancerebbe.

**Web.** `WebTrackFiles` tiene in una mappa `uri → web.File` il file scelto (oggi non lo tiene), e lo toglie in `release`. `peaks`: se il file manca, o `webPeaksAllowed(size, duration)` è falso (oltre 40 MB o oltre 15 minuti; funzione pura, così si prova anche fuori dal browser), errore subito: niente forma d'onda, il resto funziona. Altrimenti `file.arrayBuffer()` e una funzione nuova in `web/flutter_bootstrap.js`, accanto a `lowEndDecodeFlac`:

```js
// I picchi di un file audio, uno ogni 10 ms (Uint16Array, 0..32767), con il
// decodificatore del browser in un contesto offline a frequenza bassa: il
// browser ricampiona decodificando, e 15 minuti stereo occupano circa 58 MB
// invece di 320. Il ciclo cede la mano ogni mezzo milione di campioni, così
// lo schermo non si ferma (RNF-FLU-01).
window.lowEndPeaks = async function (data) {
  const Offline = window.OfflineAudioContext || window.webkitOfflineAudioContext;
  if (!Offline) throw new Error('no OfflineAudioContext');
  let context;
  try { context = new Offline(1, 1, 8000); } catch (e) { context = new Offline(1, 1, 22050); }
  const audio = await context.decodeAudioData(data);
  const frame = Math.round(audio.sampleRate / 100);
  const out = new Uint16Array(Math.ceil(audio.length / frame));
  let work = 0;
  for (let c = 0; c < audio.numberOfChannels; c++) {
    const f = audio.getChannelData(c);
    for (let i = 0; i < out.length; i++) {
      let peak = out[i];
      const end = Math.min(f.length, (i + 1) * frame);
      for (let j = i * frame; j < end; j++) {
        const v = Math.min(32767, Math.round(Math.abs(f[j]) * 32767));
        if (v > peak) peak = v;
      }
      out[i] = peak;
      work += frame;
      if (work > 500000) { work = 0; await new Promise((r) => setTimeout(r, 0)); }
    }
  }
  return out;
};
```

In Dart: `@JS('lowEndPeaks') external JSPromise<JSUint16Array> _peaks(JSArrayBuffer data);` come in `browser_flac_web.dart`; il risultato arriva in un solo pezzo. Va provato anche che `new Offline(1, 1, 8000)` funzioni su Safari dell'iPhone (se lancia, si passa a 22050: è già nel codice).

I limiti vanno scritti in `docs/web.md`.

### 5.8 Accessibilità (RF-PLY-16)

- Il toro resta uno slider ("1:12 di 6:03"); aumenta e diminuisci spostano di 10 s nel brano intero e di 1 s nella vista Passaggio.
- Sul toro due azioni personalizzate (`customSemanticsActions`): "Segna l'inizio qui" e "Segna la fine qui", che chiamano `mark`. È la strada senza trascinare per creare il passaggio; poi i − e + per ritoccarlo.
- Il tempo di ogni gruppo si annuncia con il suo nome: "Inizio 1:12,34", "Fine 1:31,00" (o "Inizio non segnato", "Fine non segnata": due chiavi, perché in italiano e in francese cambia il genere). I − e + tengono i nomi di oggi: "Inizio prima", "Inizio dopo", "Fine prima", "Fine dopo".
- Maniglie e forma d'onda sono disegno (`ExcludeSemantics`), come oggi il toro.

### 5.9 Azioni per assistenti

Nessuna azione nuova né tolta. Cambiano le descrizioni, poi si rigenera `docs/llm-actions.json` e si allinea `docs/llm.md`:
- `player_mark` (PR 4): non c'è più il pulsante; "Marks the start or the end of the loop at the point being heard (the screen reader's Mark the start here / Mark the end here)…".
- `player_loop_nudge` (PR 4): esempio "-0.01"; il minimo e il massimo restano ±10 s.
- `open_section` (PR 3): l'accordatore non si mette in ascolto da solo nemmeno quando suona il Player (il codice lo fa già, la descrizione non lo dice).

## 6. Passi

### PR 3: ordine dei tab, cursore e forma d'onda

Codici: RF-GEN-01, RF-PLY-03, RF-PLY-15, RNF-FLU-01, RNF-AVV-01.

1. **Ordine.** `AppSection { metronome, drone, player, tuner }` in `lib/app/app_navigation.dart`. Cerca ogni uso di `AppSection.values`, `.index`, liste di sezioni scritte a mano (schede, rail in orizzontale, `_screens` di `home_shell.dart`) e i test che scorrono da un tab all'altro contando le pagine (`playback_flow_test`, `widget_test`, `regression_test`, `memory_test`, quelli in `test/review/`). La sezione si salva per nome: nessuna migrazione, ma aggiungi un test che una sezione salvata `tuner` riapre l'accordatore. Aggiorna l'ordine scritto in README, `docs/user-guide.md`, `docs/manuale-utente.md`, `docs/llm.md`.
2. **Cursore.** `_PointPainter` diventa `_PlayheadPainter` (sezione 5.2).
3. **Picchi, Dart.** `TrackPeaks`, la nuova firma di `TrackFiles.peaks`, `FakeTrackFiles`, `PlayerController.peaks` (sezioni 5.6 e 5.7).
4. **Picchi, Android.** `TrackPeaks.kt` e il collegamento in `MainActivity`; `AndroidTrackFiles.peaks`.
5. **Picchi, web.** `lowEndPeaks` in `flutter_bootstrap.js`, la mappa dei file e `WebTrackFiles.peaks`; i limiti in `docs/web.md`.
6. **Disegno.** `RingWindow` (per ora solo `whole`), base, forma d'onda, tacche sul bordo esterno, dissolvenza (sezione 5.2). Il quadrante ascolta `player.peaks`.
7. **Testi e azioni.** Descrizione di `open_section`, golden rigenerato.
8. **Test** (sezione 8) e `requisiti.md` (Stato).

Da provare a fine PR, nella descrizione: un MP3 di 6 minuti e un M4A di 20 minuti sul S20 FE (tempo fino alla forma d'onda intera, schermo fluido mentre si riempie), un MP3 di 10 minuti sull'iPhone.

### PR 4: il passaggio sul toro

Codici: RF-PLY-09, 10, 11, 12, 16, 17, 18.

1. **Controller.** `fineStep`, `coarseStep`, `moveEdge`, via `edge` e `selectEdge` (sezione 5.6).
2. **Orologio al centesimo.** `clockText(time, hundredths: true)` → "1:12,34" (tronca, non arrotonda, come i decimi di oggi; i decimi non servono più e si tolgono se nessuno li usa).
3. **Finestra.** `RingWindow.passage`, `tickInterval` esteso, `lerp`, l'animazione tra le viste (sezione 5.3).
4. **Maniglie.** Disegno, `_GripDrag`, `gripCenter`, il tempo nel centro durante il trascinamento (sezioni 5.2, 5.4, 5.5).
5. **Righe.** Riga dei messaggi, seconda riga senza l'errore, terza riga A / Loop / B (sezione 5.1).
6. **Accessibilità.** Azioni personalizzate sul toro, nomi dei gruppi, passo del lettore secondo la vista (sezione 5.8).
7. **Testi e azioni.** Le chiavi della sezione 7; descrizioni di `player_mark` e `player_loop_nudge`; golden; `docs/llm.md`; guide utente (il passaggio si sceglie sull'anello).
8. **Test** (sezione 8) e `requisiti.md`.

Se la PR supera circa 1.500 righe cambiate, dividila: 4a controller, finestra e maniglie; 4b righe, accessibilità e testi.

### CANCELLO 2: prova di Luigi sul telefono e sull'iPhone

Sonnet si ferma qui e chiede a Luigi questa prova (circa 20 minuti). I risultati vanno nella colonna Stato di `requisiti.md`; la PR 5 parte solo dopo il suo via.

- Scegliere un passaggio sull'anello: si capisce dalla riga dei messaggi? Trascinare A e B è comodo? La vista Passaggio aiuta o disorienta?
- I − e + da 10 ms: giusti, troppo fini, troppo grossi?
- La forma d'onda corrisponde al suono? Prova: nella vista Passaggio metti A esattamente su un attacco netto e ascolta il giro. Se A cade sempre un po' prima o dopo, si misura lo scarto (sugli MP3 può arrivare a circa 50 ms, il ritardo dell'encoder) e si corregge.
- Rimasti dal CANCELLO 1: velocità al 70% e al 50% in cuffia su un brano orchestrale e uno ritmico ("si studia bene", "accettabile", "no"; un "no" al 70% porta alla strada C della fase 2, non a un cambio di questo piano); stacco al giro del loop su Android; peso dell'APK arm64 contro quello prima del Player (al massimo 2,5 MB in più); M4A di 20 minuti senza blocchi.
- iPhone, web app: apertura dall'app File, forma d'onda di un MP3 di 10 minuti, velocità senza cambio di intonazione, stacco al giro (obiettivo sotto 80 ms), cosa succede a schermo bloccato.

### PR 5: ricordare il brano, titolo e autore

Codici: RF-PLY-13, RF-PLY-14, RF-PLY-07 (file sparito), RNF-AVV-01. È la PR 3 della revisione 1, con un'aggiunta:

- **Android**: `canRead`, `tags`, `release` in `TrackFiles.kt` (permesso tra `persistedUriPermissions` e `openFileDescriptor(uri, "r")`; `MediaMetadataRetriever` per `METADATA_KEY_TITLE` e `METADATA_KEY_ARTIST`, sempre `release()`; `releasePersistableUriPermission` ignorando `SecurityException`).
- **Web**: `readId3Tags(Uint8List)` in `track_tags.dart` sui primi 128 KB (ID3v2.3 e 2.4; con unsynchronisation si rinuncia; header esteso saltato; dimensioni syncsafe; TIT2 titolo, TPE1 autore; codifiche 0 Latin-1, 1 UTF-16 con BOM, 2 UTF-16BE, 3 UTF-8; vuoto = null).
- **Ricordo**: `PlayerSetup` (uri, nome, dimensione, durata, velocità, A, B, loop acceso) come JSON nella chiave `player` di `AppSettings`, scritta solo fuori dal web e solo se è cambiata. `fromJson` ignora i campi sbagliati e risponde null senza uri: dati illeggibili non impediscono mai l'avvio.
- **Riapertura pigra**: all'avvio solo i campi, niente canale né lettore. Arrivando sul tab, una volta `canRead`: se è falso, "Il file non è più disponibile." e il ricordo si cancella. Il file si apre al primo play, da A se il loop è acceso.
- **Aggiunta: cache dei picchi.** Su Android `TrackPeaks.kt` salva i picchi finiti in `cacheDir/peaks/<sha1 dell'uri>-<dimensione>.u16`; con il file già in cache li manda in un solo pezzo. Il sistema può svuotare la cache: si rifà la lettura. Sul web niente cache (i brani non sopravvivono alla pagina).
- **Test**: andata e ritorno di `PlayerSetup` e JSON rovinato; avvio con un brano ricordato che non chiama né `open` né il canale; `canRead` una volta sola; file sparito; brano nuovo che azzera loop e velocità; tag in ritardo ignorati; `track_tags_test` con tag costruiti nel test.

### Dopo questo piano, da approvare a parte

- **Registra (fase 1b)**: microfono con il `MicInput` dell'accordatore, mono 48 kHz in RAM, WAV scritto in Dart, battuta d'attacco del metronomo, salvataggio con `ACTION_CREATE_DOCUMENT` o download, al massimo 10 minuti. Il campo Brano diventa un menu (Apri file…, Registra).
- **Fase 2**: pausa e conteggio prima di ogni giro, velocità che sale a ogni giro, trasposizione, brani recenti con il loro passaggio, barra di avanzamento nella notifica, strada C (Signalsmith Stretch) se il CANCELLO 2 boccia il rallentamento.
- **Fase 3**: TAP sul brano e click agganciato (due motori: prima si misura quanto si allontanano in 30 s).

## 7. Testi

Ogni testo nei quattro `.arb` (inglese di riferimento), poi `flutter gen-l10n`. Nei testi per chi usa l'app il toro si chiama "anello", come nelle guide.

| Chiave | en | it | es | fr | PR |
| --- | --- | --- | --- | --- | --- |
| `playerHintDraw` (nuova) | Hold on the ring and slide to choose a passage to repeat | Tieni premuto sull'anello e scorri per scegliere un passaggio da ripetere | Mantén pulsado el anillo y desliza para elegir un pasaje que repetir | Appuyez longuement sur l'anneau et glissez pour choisir un passage à répéter | 4 |
| `playerHintGrips` (nuova) | Drag A and B on the ring to adjust the passage | Trascina A e B sull'anello per ritoccare il passaggio | Arrastra A y B en el anillo para ajustar el pasaje | Faites glisser A et B sur l'anneau pour ajuster le passage | 4 |
| `playerMarkStart` (cambia) | Mark the start here | Segna l'inizio qui | Marcar el inicio aquí | Marquer le début ici | 4 |
| `playerMarkEnd` (cambia) | Mark the end here | Segna la fine qui | Marcar el final aquí | Marquer la fin ici | 4 |
| `playerStartAt` (nuova, `{time}`) | Start {time} | Inizio {time} | Inicio {time} | Début {time} | 4 |
| `playerEndAt` (nuova, `{time}`) | End {time} | Fine {time} | Final {time} | Fin {time} | 4 |
| `playerStartUnmarked` (nuova) | Start not marked | Inizio non segnato | Inicio sin marcar | Début non marqué | 4 |
| `playerEndUnmarked` (nuova) | End not marked | Fine non segnata | Final sin marcar | Fin non marquée | 4 |

Restano: `playerTab`, `playerTrack`, `playerChoose`, `playerPlay`, `playerPause`, `playerTimeOf`, `pausedForPlayer`, `playerUnreadable`, `playerMissing`, `playerSpeed`, `playerSpeedTitle`, `playerLoop`, `playerLoopStart`, `playerLoopEnd`, `playerStartEarlier`, `playerStartLater`, `playerEndEarlier`, `playerEndLater`. Si tolgono le chiavi che nessuno usa più. Spagnolo e francese restano da rileggere da un madrelingua, come il resto.

## 8. Test e verifica

Tutto gira senza telefono, con `SilentTrackOutput` e `FakeTrackFiles`.

| Test | Cosa verifica | PR |
| --- | --- | --- |
| `widget_test`, `playback_flow_test`, `memory_test` | Ordine dei tab e dello scorrimento; sezione salvata per nome | 3 |
| `track_peaks_test` (nuovo) | `add` a pezzi, `heights` (massimo per spicchio, scala in dB, NaN non letti, finestra parziale), `version`, `fail` | 3 |
| `player_controller_test` | `peaks` parte dopo `open`, si annulla con un brano nuovo, un errore in ritardo di un brano vecchio è ignorato | 3 |
| `player_ring_test` | `RingWindow` (intero, passaggio con margini ai bordi del brano, `angleOf` / `timeAt` andata e ritorno, `lerp`), `tickInterval` per ogni fascia, tacche sui multipli veri | 3, 4 |
| `player_panel_test` | Quadrante con picchi nulli, parziali e pieni senza errori; cursore presente solo a brano pronto | 3 |
| `web_parts_test` | `webPeaksAllowed` ai limiti di 40 MB e 15 minuti; fuori dal web nessuna parte del browser viene chiamata | 3 |
| `player_loop_test` | `moveEdge` (limiti, quiete di 0,3 s, ripartenza da A o da B − 2 s), passi da 10 e 100 ms, `mark` senza `edge` | 4 |
| `player_panel_test` | Trascinare da un'impugnatura sposta B **e non cambia sezione**; trascinare fuori dalle impugnature cambia sezione; pressione lunga e scorrere crea il passaggio e accende la vista Passaggio; tocco fuori dal passaggio spegne loop e vista; la finestra non si muove durante il trascinamento e si riadatta dopo; riga dei messaggi nei quattro stati; terza riga spenta senza passaggio | 4 |
| `accessibility_test` | Azioni "segna qui" sul toro, nomi dei gruppi, bersagli da 48 dp, contrasto; il tab Player è già nella lista | 4 |
| `layout_review_test`, `row_heights_test` | La terza riga a 288 dp e a testo 2× in quattro lingue | 4 |
| `app_actions_test` | Golden rigenerato | 3, 4 |

Verifica di ogni PR: CI verde (test, APK debug arm64, web `--wasm`); manifest unito senza `ACCESS_NETWORK_STATE`; quattro `.arb` completi; `requisiti.md` aggiornato; descrizione della PR con "Scelte fatte" e "Da provare sul telefono".

Trappola già incontrata: in `testWidgets` un `Future` creato in `setUp` (zona reale) e atteso nel corpo del test può restare appeso; le catene vanno create dentro la chiamata.

## 9. Rischi

| Rischio | Probabilità | Cosa si fa |
| --- | --- | --- |
| La forma d'onda in ritardo sul suono negli MP3 (ritardo dell'encoder, fino a circa 50 ms) | Media | Misura al CANCELLO 2; se si vede, si sposta di quanto dice l'intestazione LAME/Xing |
| Decodifica lenta su un telefono economico (20 minuti di M4A) | Media | Il brano suona subito e la forma si riempie mentre si legge; in PR 5 la cache evita di rifarla |
| Memoria del browser sull'iPhone | Media | Limiti di 15 minuti e 40 MB, da rivedere con la misura del CANCELLO 2 |
| Il trascinamento delle impugnature ruba lo scorrimento tra le sezioni | Bassa | Solo partendo da un'impugnatura; test dedicato |
| Impugnature troppo vicine nel brano intero | Certa per passaggi brevi | Raggi diversi per A e B; la vista Passaggio le allontana |
| Rallentamento di ExoPlayer "acquoso" sotto il 70% | Media | CANCELLO 2; altrimenti strada C in fase 2 |
| `setClip` ricarica la sorgente a ogni ritocco | Certa | Il suono segue solo dopo 0,3 s di quiete, come oggi |

## 10. Domande per Luigi

Sonnet non aspetta le risposte: usa la scelta predefinita e la cambia se Luigi decide diversamente.

1. **Vista Passaggio legata al Loop** (predefinito: sì, loop acceso = il giro è il passaggio), oppure un pulsante a parte per passare da brano intero a passaggio?
2. **Passi dei − e +**: 10 ms al tocco e 100 ms tenuti (predefinito), oppure 20 e 200 ms?
3. **Segnare "qui" mentre suona**: solo per lettore di schermo e assistenti (predefinito), oppure un pulsante "Segna qui" che a ogni tocco mette A, poi B, come un pedale da looper?
4. Ancora aperte dalla revisione 1: avviare metronomo o Armonia mette in pausa il Player senza avviso (predefinito) o con "Riprendi"? Registrazione subito dopo il CANCELLO 2 o più avanti?

Decise il 6/11 e non più aperte: nome (Ascolto), posizione (terzo tab), ritocchi più fini, forma d'onda e non spettrogramma.

## 11. Fatti verificati sui pacchetti

Valgono per il codice già unito e per chi lo tocca.

- just_audio 0.10.6: su Android ExoPlayer (media3) con Sonic per la velocità; sul web un elemento `<audio>` con `preservesPitch`.
- `just_audio_web` controlla la fine di una clip solo a ogni `timeupdate` (circa 250 ms): sul web il loop usa un timer proprio da 16 ms (`useClipLoop = !kIsWeb`).
- `setClip` ricarica la sorgente e rende la posizione relativa alla clip: `TrackOutput.position` è sempre assoluta nel brano.
- Il `Future` di `play()` finisce solo alla pausa; a fine brano just_audio resta "playing": il controller guarda lo stato `completed`.
- Il manifest di media3 aggiunge `ACCESS_NETWORK_STATE`: si toglie con `tools:node="remove"` (RNF-PRIV-01).
- Gli MP3 a bitrate variabile hanno bisogno di `flagMp3EnableIndexSeeking` per salti precisi.
- `handleInterruptions: false`: cuffie staccate e interruzioni le gestisce già `AudioRoute`.
- `just_audio_web` ignora l'evento `pause` dell'elemento: rischio con una chiamata sull'iPhone.
- `MainActivity` estende `AudioServiceActivity`, che non è una `ComponentActivity`: niente `registerForActivityResult`, si usa `startActivityForResult`.
- Flutter 3.47.9: un `OneSequenceGestureRecognizer` che chiama `resolvePointer(accepted)` dentro `addAllowedPointer` diventa il vincitore anticipato dell'arena quando questa si chiude, prima che il `PageView` superi la soglia dello scorrimento.
