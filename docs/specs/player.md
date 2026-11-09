# Player (Ascolto): come è fatto

Il terzo tab di Low End: un brano proprio, rallentato senza cambiare intonazione, con un passaggio che si ripete, e la registrazione di sé per riascoltarsi. Questo file dice **come** è costruito; **cosa** l'app deve fare sta in [requisiti.md](requisiti.md), sezione 2.10 (codici RF-PLY). Se i due file dicono cose diverse vale `requisiti.md`, e questo file va corretto.

**Revisione 6, 9 novembre 2026: A e B si spostano dal cerchio** (sezione 2.2). **Revisione 5, 9 novembre 2026: controlli riordinati** (sezione 2.1). **Revisione 4, 7–8 novembre 2026.** Dopo la prova di Luigi la cattura del passaggio è passata da bandiere A e B negli angoli (revisione 3, PR #130–#133) a un solo pulsante con due tocchi (PR #148), con la forma d'onda sempre nella prima riga; si è aggiunta la registrazione (PR #154, #159; corretta l'8/11). Luigi l'ha provata sul telefono e la tiene. Le revisioni 1–3, con le loro alternative e le domande, sono nella storia di git di questo file.

## 1. Come si usa

1. **Brano** (terza riga) apre il selettore di sistema; il centro del quadrante, senza brano, fa lo stesso.
2. Il **centro** avvia e mette in pausa; mostra tempo trascorso, durata e il simbolo di riproduzione o pausa, e sopra titolo e autore se il file ha i tag.
3. Il **toro** è l'orologio del brano intero: dentro la forma d'onda; fuori, in una fascia sottile, le tacche a tempi tondi con i numeri (0:00, 1:00, 2:00…: al massimo 8, il passo si adatta alla durata); il cursore dove si ascolta. Toccarlo sposta l'ascolto; il passaggio vi appare come arco. A e B vi compaiono come **maniglie** (cerchietti con la lettera) che si trascinano lungo il cerchio: è il modo normale di spostare il passaggio.
4. **Segna inizio → Segna fine → Loop attivo** (seconda riga, a sinistra, pieno d'accento come TAP, con la bandierina A o B finché si segna): il primo tocco segna A dove si sente, il secondo B; il passaggio si ripete subito da A. Lo stesso pulsante poi spegne e riaccende il loop ("Riattiva loop"); A e B restano.
5. La **striscia** (prima riga) mostra la forma d'onda dritta: il brano intero finché il passaggio non è completo, poi il passaggio con un margine per parte. Le due aste si trascinano per rifinire (al centesimo); un'asta tenuta contro un bordo allarga la striscia da quella parte finché il dito resta lì; il tocco altrove sposta l'ascolto. Il pulsante **Nuovo passaggio** accanto (icona, sempre al suo posto, spento finché non c'è A o B) cancella A e B.
6. **Velocità** (seconda riga, a destra): un tocco apre una lista corta, 50, 60, 70, 75, 80, 85, 90, 100, 110, 125%. Diversa da 100% il valore e il bordo sono nell'accento. Le azioni accettano ogni valore intero dal 50 al 125.
7. **REC** (terza riga, il pallino rosso accanto a Brano) registra dal microfono; **Stop** (al posto di REC) apre la ripresa nel Player per riascoltarla, **Scarta** la butta. Con una ripresa aperta il campo ne dice la durata e accanto a REC compaiono **Salva**, **Condividi** ed **Elimina**; eliminata (o rimossa dopo il salvataggio), torna il brano che si stava studiando con passaggio e velocità. Una ripresa non salvata eliminata si riprende per qualche secondo con **Annulla** nell'avviso; REC o un altro brano sopra una ripresa non salvata chiedono prima.

## 2. La schermata

Stesso `DialLayout` degli altri tab: quadrante con il centro allineato tra i quattro tab, poi tre righe da 64 dp con 16 dp tra loro.

| Posto | Senza brano | Brano aperto | Durante la registrazione |
| --- | --- | --- | --- |
| Toro | Anello spento | Forma d'onda, tacche e tempi fuori dal toro, cursore, arco del passaggio | Come prima, spento |
| Centro | Cartella e "Scegli un brano" | Titolo/autore, tempo, durata, play/pausa | Pallino e tempo della ripresa |
| Prima riga | Vuota, o l'errore del file | Striscia e Nuovo passaggio (spento senza A né B) | Inattiva |
| Seconda riga | Spenta | Pulsante del passaggio, Velocità | Inattiva |
| Terza riga | Brano e REC | Brano e REC; con una ripresa: durata, REC, Salva, Condividi, Elimina | Campo Registrazione con pallino e tempo, Stop, Scarta |

### 2.1 Forma dei controlli (revisione 5)

Dopo la prova di Luigi del 9/11 (REC e "Segna inizio" più bassi del campo accanto, cerchi solo nel Player, foglio della velocità ingombrante, pulsanti che comparivano e sparivano):

- Ogni controllo delle righe è alto 56 dp come i campi e ogni pulsante è un `RowButton` (rettangolo arrotondato del tema, come − / + e TAP); le icone sono larghe 48 dp, con nome per TalkBack e suggerimento.
- Il pulsante del passaggio è pieno d'accento come TAP mentre si segna (bandierina con A o B) e con il loop attivo, solo bordato con "Riattiva loop" (cambiato il 9/11 su richiesta di Luigi: prima era pallido come − / +).
- Nuovo passaggio sta accanto alla striscia, dove sono A e B: vicino a Velocità sembrava "torna a 100%".
- Restano sempre al loro posto Nuovo passaggio e REC; Salva, Condividi ed Elimina compaiono solo con una ripresa (scelta di Luigi). Il campo della ripresa mostra la durata, che entra anche a 360 dp e nella colonna in orizzontale.
- Anteprime: `preview/player-controlli/` nella cartella del progetto.

### 2.2 Spostare A e B (revisione 6)

Luigi, 9/11: trascinare le aste sulla striscia ingrandita era scomodo, la striscia si fermava ai bordi del passaggio e il brano intero non si rivedeva. Le due viste ora lavorano insieme:

- **Cerchio = spostamenti.** Le maniglie A e B sul toro (raggio un quarto dello spessore dell'anello, 10–16 dp, bersaglio 48 dp, `FlagDrag` come sulla striscia: lo scorrimento tra i tab parte fuori dalle maniglie). L'angolo si conta di seguito, quindi le 12 sono un muro e non un salto dalla fine all'inizio. Toccata senza trascinarla, una maniglia diventa la bandiera attiva. Su 6 minuti un millimetro di cerchio vale circa 2–3 decimi di secondo.
- **Striscia = ritocchi.** Un'asta tenuta a meno di 24 dp da un'estremità allarga la finestra da quella parte dell'1% ogni 16 ms (almeno 20 ms), portandosi dietro l'asta; lasciata, la finestra si riadatta al passaggio dopo 0,3 s.
- Anteprima: `preview/player-controlli/passaggio-proposta.png` nella cartella del progetto.

## 3. Il codice

| File | Ruolo |
| --- | --- |
| `lib/features/player/player_controller.dart` | Stato del Player: brano, velocità, A/B, loop (`captureOrToggle`, `place`, `nudge`, `clearPassage`), memoria (`setup`, `restore`, `activate`), la ripresa sopra il brano studiato (`_beforeTake`, `removeRecording`) |
| `lib/features/player/recording_controller.dart` | La registrazione: REC, Stop, Scarta; si ferma da sola lasciando il tab, aprendo le impostazioni, mandando l'app in background o avviando il Player |
| `lib/audio/take_recorder.dart` | `TakeRecorder`: il microfono reale (`record`: AAC .m4a su Android, WAV sul web) e `FakeTakeRecorder` per i test |
| `lib/audio/system_track_files_io.dart`, `_web.dart`, `android/.../TakeFiles.kt` | Selettore, permessi dei file, cartella temporanea delle riprese, Salva (`ACTION_CREATE_DOCUMENT` / download) e Condividi (FileProvider / Web Share) |
| `lib/features/player/player_panel.dart` | Le tre righe; `recording_controls.dart` la riga della registrazione e quella della ripresa |
| `player_dial.dart`, `passage_strip.dart`, `ring_wave.dart`, `ring_window.dart`, `flag_painter.dart`, `flag_drag.dart` | Quadrante, striscia, forma d'onda, finestra della striscia, aste e il loro trascinamento (che non cambia tab) |

### 3.1 La ripresa e il brano studiato

`PlayerController.open` con una `RecordedTrack` non rilascia il brano aperto: ne tiene la `PlayerSetup` (brano, velocità, A, B, loop) in `_beforeTake`, che `setup` continua a restituire, così il brano studiato resta quello ricordato al prossimo avvio. Una seconda ripresa sostituisce la prima; il brano sotto resta lo stesso. `removeRecording` (Elimina, Rimuovi) o una ripresa che non si apre lo riportano con `restore` + `activate`: si riapre a A, alla sua velocità, al primo play. Scegliere un altro file con una ripresa aperta lascia andare anche il brano sotto (tranne se è lo stesso file). Una ripresa non è mai ricordata da sola.

### 3.2 Regole della registrazione

- REC mette in pausa il Player; metronomo e Armonia continuano (ci si può registrare sul click).
- Il microfono si apre solo dopo il permesso; un permesso negato o un microfono occupato si dicono con un avviso.
- Lasciare il tab, aprire le impostazioni, andare in background o avviare il Player fermano la registrazione **tenendo** la ripresa, come Stop.
- Le riprese stanno nella cache dell'app (`takes/<sessione>`), cancellate all'avvio successivo; le copie condivise in `shared-takes` per 24 ore, perché l'app che le riceve possa leggerle.

## 4. Azioni per assistenti

`player_open`, `player_play`, `player_pause`, `player_seek`, `player_speed`, `player_loop`, `player_mark`, `player_loop_nudge`, `player_loop_off`, `player_loop_clear`, `player_record`, `player_record_stop` (con `discard`); `get_state` ha il blocco `player` con `take` e `recording`. Salva e Condividi aprono finestre del telefono e restano alla persona. Descrizioni in `lib/actions/app_actions.dart`, golden `docs/llm-actions.json`, guida `docs/llm.md`.

## 5. Test

| Test | Cosa verifica |
| --- | --- |
| `player_controller_test`, `player_loop_test`, `player_memory_test` | Apertura, errori, velocità, A/B e loop, memoria |
| `player_ring_test` | Tempi sul cerchio: passo tondo, al massimo 8 numeri, niente numero accanto a 0:00, numero sempre fuori dalla sua tacca, fascia del Player nello stesso cerchio |
| `player_panel_test` | Centro, toro, striscia, righe; REC, Scarta durante la richiesta del permesso, Stop, Salva, Condividi, Rimuovi, Elimina con Annulla, lista delle velocità, maniglie del cerchio, striscia che si allarga, pulsante pieno con la lettera |
| `recording_test` | Ripresa sopra il brano studiato e ritorno, seconda ripresa, altro file, Scarta, permesso negato, microfono occupato, stop lasciando il tab o le impostazioni o avviando il Player, azioni |
| `player_ring_test`, `track_peaks_test`, `marquee_test`, `track_tags_test` | Geometria, forma d'onda, titolo che scorre, tag |
| `accessibility_test`, `app_actions_test` | Nomi e bersagli; golden delle azioni |

## 6. Da provare sul telefono

Stacco al giro del loop (sotto 30 ms su Android, 80 ms sul web), velocità al 70 e 50%, dimensione dell'APK, iPhone (registrazione e condivisione nel browser), registrazione con cuffie Bluetooth (rischio di qualità telefonica, vedi la nota sull'accordatore).

## 7. Fatti verificati sui pacchetti

Valgono per il codice già unito e per chi lo tocca.

- just_audio 0.10.6: su Android ExoPlayer (media3) con Sonic per la velocità; sul web un elemento `<audio>` con `preservesPitch`.
- `just_audio_web` controlla la fine di una clip solo a ogni `timeupdate` (circa 250 ms): sul web il loop usa un timer proprio da 16 ms (`useClipLoop = !kIsWeb`).
- `just_audio_web` 0.4.16 tiene il lettore del primo brano sotto l'indirizzo della lista di just_audio, che non cambia: un secondo brano avrebbe durata, forma d'onda e suono del primo. Sul web l'uscita ferma il lettore prima di ogni brano nuovo, e il caricamento ne crea uno nuovo (`freshPlayerPerTrack = kIsWeb`, test `just_audio_track_output_test.dart`).
- `setClip` ricarica la sorgente e rende la posizione relativa alla clip: `TrackOutput.position` è sempre assoluta nel brano.
- Il `Future` di `play()` finisce solo alla pausa; a fine brano just_audio resta "playing": il controller guarda lo stato `completed`.
- Il manifest di media3 aggiunge `ACCESS_NETWORK_STATE`: si toglie con `tools:node="remove"` (RNF-PRIV-01).
- Gli MP3 a bitrate variabile hanno bisogno di `flagMp3EnableIndexSeeking` per salti precisi.
- `handleInterruptions: false`: cuffie staccate e interruzioni le gestisce già `AudioRoute`.
- `just_audio_web` ignora l'evento `pause` dell'elemento: rischio con una chiamata sull'iPhone.
- `MainActivity` estende `AudioServiceActivity`, che non è una `ComponentActivity`: niente `registerForActivityResult`, si usa `startActivityForResult`.
- Flutter 3.47.9: un `OneSequenceGestureRecognizer` che chiama `resolvePointer(accepted)` dentro `addAllowedPointer` diventa il vincitore anticipato dell'arena quando questa si chiude, prima che il `PageView` superi la soglia dello scorrimento.
- Flutter: `RenderBox.hitTest` scarta i punti fuori dalla sua misura, quindi un figlio di uno `Stack` dipinto fuori (`clipBehavior: Clip.none`) non riceve tocchi lì. Per questo le bandiere stanno dentro il riquadro del quadrante.
- Flutter: un nodo `Semantics` senza gesti non ferma il dito; `onTapHint` cambia quello che il lettore di schermo dice per il doppio tocco.
