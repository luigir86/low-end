# Valutazione dell'architettura contro i requisiti

Base: [requisiti.md](requisiti.md) e [architettura.md](architettura.md), codice di `main` al 4 novembre 2026. Dove scrivo "misurato" c'è un numero da un banco di prova o dal telefono; dove scrivo "stima" o "probabile" è una lettura del codice che va confermata misurando.

## In sintesi

L'app è **solida nelle fondamenta**: i requisiti di prodotto sono quasi tutti realizzati e coperti da test, il tempo è esatto per costruzione (loop di battute intere), la privacy e l'accessibilità sono verificate in automatico, e lo strato di azioni per assistenti è raro in un'app di questo tipo. I problemi stanno in **due punti**: l'**Armonia**, dove lo stato viene cambiato da tanti setter che ognuno rifà il suono, e il **costo del mix dei loop**, che nel web gira sul thread dello schermo. I blocchi di oggi (#97, #98) nascono esattamente lì, e ne verranno altri dello stesso tipo finché quei due punti non cambiano forma. Il resto sono duplicazioni e confini tra moduli da riordinare, a basso rischio.

## 1. Punti di forza

| # | Punto | Requisiti serviti |
| --- | --- | --- |
| F1 | **Tempo esatto per costruzione**: metronomo e Armonia sono loop di battute intere nel motore, l'ingresso del secondo è programmato sul clock del motore (`playScheduled`, `stopScheduled`). Niente timer per il suono, quindi niente deriva. | RF-MET-06, RF-SYNC-01 |
| F2 | **Ogni cosa esterna dietro un'interfaccia con un gemello finto**: ~430 test girano senza telefono né scheda audio, in un minuto. | RNF-TEST-01 |
| F3 | **Strato di azioni unico e generato**: catalogo JSON prodotto dal codice, controllato da un test, argomenti validati prima di toccare lo stato. | RF-LLM-01…05, RNF-LLM-01 |
| F4 | **Nessuna dipendenza pesante**: niente pacchetto di gestione dello stato, sei pacchetti a runtime, codec inutili esclusi. | RNF-DIM-01, RNF-AVV-01 |
| F5 | **Avvio pulito**: un solo `await` (le impostazioni) prima del primo frame, motore e microfono dopo; verificato da `startup_test`. | RNF-AVV-01 |
| F6 | **Tolleranza agli errori**: impostazioni illeggibili, motore che non parte, download fallito: l'app mostra uno stato e si riprova, senza crash. | RF-IMP-04, RF-WEB-03 |
| F7 | **Qualità verificata in automatico** su accessibilità, contrasto, overflow fino a 320 px e testo 2×, stili centralizzati. | RNF-ACC-01, RNF-UX-01…03 |
| F8 | **Un solo codice per Android e web**, con le differenze dietro le stesse interfacce dei finti dei test. | RF-WEB-01, RF-WEB-05 |
| F9 | **Commenti che spiegano il perché**: quasi ogni scelta non ovvia ha la sua ragione scritta accanto. | manutenzione |

## 2. Debolezze strutturali

### D1. L'Armonia cambia per piccoli passi, e ogni passo rifà il suono (alta)

`DroneController` espone sette setter; ognuno cambia un campo e chiama `_sync()`, che rifà il loop se suona. Chi deve cambiare più cose insieme (un brano, un'azione `drone_play` con più argomenti, il ripristino) passa per stati intermedi che nessuno vuole sentire. Il tempo del metronomo, che arriva con il suo ascoltatore, rifà il loop una volta in più. La coda `_pending`/`_queued` limita i danni ma non li evita: il primo stato intermedio parte comunque.

È la causa del blocco cambiando brano (PR #98). La PR lo corregge con un `applyAll` e un flag `_batching`, cioè una pezza sul caso dei brani; `drone_play` con più argomenti e le azioni che toccano insieme Armonia e metronomo restano esposti allo stesso problema.

La forma che toglie il problema alla radice c'è già quasi: `DroneSetup` è un valore immutabile con tutta la scelta del musicista. Se il controller tenesse **uno stato desiderato** (setup + tempo + metro + suona/non suona) e un unico riconciliatore che confronta il desiderato con ciò che sta suonando, ogni modifica, singola o multipla, costerebbe al massimo un mix.

### D2. `DroneController` fa quattro mestieri (media)

In 841 righe: teoria (gradi, ortografia, note della tonalità), politica del suono (pianoforte o suono tenuto, quando ripartire dall'inizio, entrare sul battito), orchestrazione del motore (coda, pre-mix, preparazione, conteggio delle battute con `Timer`) e stato dell'interfaccia (attesa dopo 0,4 s, "connessione lenta" dopo 5 s). Ogni nuova funzione dell'Armonia tocca questo file; i test devono passare dal controller anche per verificare la teoria.

### D3. `LowEndApp` è il punto dove finisce tutto ciò che non ha un posto (media)

Oltre a creare gli oggetti, contiene le regole tra sezioni (pausa per l'accordatore, cuffie, interruzioni), la macchina a stati della notifica, il testo della notifica, i link, l'avvio anticipato del motore web e la preparazione del pianoforte. Sono regole di prodotto (RF-ACC-08, RF-BG-01/02) che oggi si possono provare solo montando l'intera app.

*Corretto il 5/11 (passo 8):* le regole tra sezioni e la notifica sono in `app/playback_rules.dart` (`PauseRules`, `NowPlayingNotification`), provate da `playback_rules_test` con due sezioni finte; in `LowEndApp` restano il collegamento e lo snackbar.

### D4. Confini tra moduli rovesciati (bassa, ma costa a ogni modifica)

- Il **metronomo importa l'Armonia** per l'interfaccia `BarClock` (dovrebbe essere il contrario, o un modulo comune).
- L'Armonia vive in **`features/tuner/drone/`** e si chiama ancora `drone` ovunque nel codice: chi legge cerca "harmony" e non lo trova.
- `applySong` (un brano che coordina due sezioni) sta dentro la cartella dell'Armonia e chiama il metronomo.
- La **notifica** in `LowEndApp` usa funzioni di nome che stanno in `drone_panel.dart`, cioè in un file di schermata.
- `AppSettings` conosce i tipi interni di Armonia e Metronomo e li salva in 25 chiavi singole: aggiungere un campo all'Armonia vuol dire toccare controller, `DroneSetup`, impostazioni, test della memoria e azioni.

*Corretto il 5/11 (passi 7 e 9):* `features/harmony/`, `BarClock` in `features/metronome/bar_clock.dart` (il metronomo non importa più l'Armonia), `applySong` in `features/songs/`, i nomi in `harmony_names.dart`; l'Armonia è salvata in una sola chiave JSON con le parole dei brani (`droneSetupToJson`). Il nome `drone` nel codice resta, come nelle azioni.

### D5. Singleton globali nel percorso audio (media)

`SoLoud.instance`, `LoopTransport.instance` e l'avviatore del motore sono globali. Per questo `BarLoopPlayer` e le uscite `SoLoud*` non hanno test automatici: la parte più delicata (sostituzione dei loop, code, ingressi sulla stanghetta, dissolvenze) si verifica solo a orecchio sul telefono (RNF-TEST-02 ○). `loop_transport_test` prova solo la matematica.

*In parte corretto il 5/11 (passo 10):* `BarLoopPlayer` e `LoopTransport` passano per `LoopEngine` (le chiamate a SoLoud che usano) e ricevono il trasporto; `bar_loop_player_test` segue su un motore finto con il suo orologio sostituzioni, ingressi sulla stanghetta, code e dissolvenze. Restano globali l'avviatore del motore e le uscite `SoLoud*`, e l'orecchio sul telefono resta l'ultima prova.

### D6. Il web è un secondo programma nascosto (media)

`kIsWeb` compare in 11 file; `web/flutter_bootstrap.js` (262 righe) sostituisce `window.AudioContext` e `WebAssembly.Memory` per aggirare comportamenti di flutter_soloud e di Safari; il service worker è generato da uno script Dart. È tutto documentato, ma dipende da dettagli interni di flutter_soloud e del browser che possono cambiare a ogni aggiornamento, e niente lo prova su Safari vero (nessuno ha un iPhone).

## 3. Duplicazioni

| # | Che cosa | Dove | Effetto |
| --- | --- | --- | --- |
| DU1 | **Tre meccanismi di coda** per lo stesso problema (applicare l'ultima richiesta senza sovrapporsi) | `MetronomeController._sync` (`_syncing`/`_syncAgain`), `DroneController._sync` (`_pending`/`_queued`), `TunerController` (`_generation`) | Tre modi di sbagliare; la correzione di uno non arriva agli altri. *Corretto il 5/11 (passo 6) per metronomo e Armonia:* `LatestRequest`; l'accordatore tiene `_generation`, che scarta le letture vecchie e non accoda lavori |
| DU2 | **Allineamento della luce al suono** e **conto alla rovescia** | `MetronomeController._apply` e `DroneController._playPiano` (stessa logica `fresh`/`carryOn` con `outputLatency`), due `waitLeft` | Una correzione della latenza va fatta due volte. *Corretto il 5/11 (passo 6):* `SoundClock` |
| DU3 | **Frequenza di campionamento** dichiarata quattro volte | `engineSampleRate`, `ClickSound.sampleRate`, `PianoSamples.sampleRate`, `WalkingBass.sampleRate` (e `DroneSound` che punta a `ClickSound`) | `ClickSound.sampleRate` è usato come costante globale in 22 punti. *Corretto il 5/11 (passo 7):* `audioSampleRate` in `audio/audio_format.dart` |
| DU4 | **Lunghezza della battuta** calcolata in quattro posti | `MetronomeController.barLength`, `SoLoudPianoOutput.play`, `SoLoudClickOutput.play` (dalla lunghezza del WAV), `PianoSound.renderSteps` | Arrotondamenti diversi possono separare di qualche campione la battuta vista e quella sentita. *Corretto il 5/11 (passo 7):* `pulseFrames` e `barDuration` in `audio_format.dart` |
| DU5 | **Tre cache con tre durate** | `PianoLibrary` (30 s dopo lo stop, 2 min se preparata, per sempre nel web, 8 note in più), pre-mix `_ahead` (una chiave testuale), `SoLoudToneOutput._sources` | Difficile sapere quanta memoria si usa e quando si libera |
| DU6 | **Nomi dei valori** in tre vocabolari | nomi delle azioni (`swing_eighths`), chiavi e valori salvati, enum Dart | Ogni nuovo valore va aggiunto in tre mappe. *In parte corretto il 5/11 (passo 9):* l'Armonia salvata usa le parole dei brani |
| DU7 | **Lo stesso comportamento descritto sei volte** | README, `user-guide.md`, `manuale-utente.md`, `llm.md`, `architecture.md`, scheda dello store | Le descrizioni divergono: il suono tenuto è a intervalli puri nel codice, "equal temperament" in `llm.md`, "just intonation" è un'idea futura nel README. *Corretto il 4–5/11 (passo 11):* le divergenze corrette, e README, guide, `llm.md`, `architecture.md` e la scheda dello store rimandano a `requisiti.md`, che vale in caso di dubbio |

## 4. Inefficienze e rischi di prestazioni

| # | Problema | Dove | Requisito a rischio | Fonte |
| --- | --- | --- | --- | --- |
| P1 | **Il mix del loop nel web è sul thread dello schermo** e, quando non c'è il pre-mix pronto (tocco subito, cambio di stile, di tonalità, di tempo, di brano), è **intero**, non a fette: `offThread` nel web è un semplice `Future`. Walking di 12 battute: 3,2 s a CPU ×2, 11 s a ×6. | `SoLoudPianoOutput.play` → `_render` | RNF-FLU-01, RNF-LAT-01 | misurato (banco perf-web, 4/11); corretto il 5/11 (passo 4): ogni mix a fette |
| P2 | **Ogni cambio di tempo con l'Armonia che suona rifà tutto il loop**: tenere premuto + con un walking vuol dire un mix completo per ogni passo che la coda lascia passare; nel web, schermo fermo per secondi. Il pre-mix non aiuta perché la chiave include il tempo. | `_onClockChanged` → `_sync` | RNF-FLU-01 | probabile, da misurare |
| P3 | **Su Android i campioni sono copiati nell'isolate a ogni mix**: `Isolate.run` copia tutto ciò che la funzione cattura, cioè le note decodificate (fino a decine di MB con il contrabbasso). | `SoLoudPianoOutput._render` | RNF-LAT-01, RNF-MEM-01 | corretto il 5/11 (passo 5, isolate del pianoforte su Android; P4 a fette nel web), da misurare sul telefono |
| P4 | **La coda (rilascio delle note) è mixata sul thread dello schermo**, in modo sincrono, a ogni stop e a ogni cambio d'accordo, su Android e nel web. | `BarLoopPlayer._Tail.load` → `PianoSound.tailWav` | RNF-FLU-01 | corretto il 5/11 (passo 5, isolate del pianoforte su Android; P4 a fette nel web), da misurare sul telefono |
| P5 | **Buffer grandi in doppia precisione**: il mix di un giro lungo usa due `Float64List` della lunghezza del loop (~28 MB per un giro di 12 battute a 80 BPM), poi il riverbero ne crea altri, poi il WAV; più le copie verso e dall'isolate. Picco di memoria stimato oltre 100 MB su un giro lungo. | `PianoSound.renderSteps`, `Freeverb.loopSteps` | RNF-MEM-01 | corretto il 5/11 (passo 4): mix e riverbero in `Float32`, metà memoria |
| P6 | **Il contrabbasso si legge tutto** (90 file) appena pronto il pianoforte, anche se non si userà mai il walking; nel web a gruppi di dieci sul thread della pagina. | `prefetchBass: true`, `PianoLibrary._doubleBass` | RNF-FLU-01, RNF-MEM-01 | corretto il 4/11: contrabbasso solo per il walking, a gruppi di dieci anche su Android |
| P7 | **La conversione FLAC → Int16 è sul thread dello schermo** su Android (mezzo milione di campioni per canale), e la decodifica di miniaudio potrebbe esserlo anch'essa. | `PianoLibrary._channel` | RNF-FLU-01 | corretto il 5/11 (passo 5, isolate del pianoforte su Android; P4 a fette nel web), da misurare sul telefono |
| P8 | **Tutto il pannello dell'Armonia si ricostruisce** a ogni notifica del controller (cambio d'accordo a ogni battuta, timer dell'attesa). | `DronePanel` con `ListenableBuilder` sul controller intero | RNF-FLU-01 (marginale) | lettura del codice |
| P9 | **Buffer del motore a 2048 frame** (~43 ms) su Android: più latenza del necessario per il tocco e per la luce. Abbassarlo a 1024 è in attesa di una prova su iPhone. | `engineBufferFrames` | RNF-LAT-01, RNF-LAT-03 | noto, in attesa |
| P10 | **Le latenze d'uscita sono costanti scritte a mano** (+20 ms altoparlante, +160 ms Bluetooth) e mai misurate. | `outputLatencyFor` | RNF-LAT-03 | noto |

## 5. Copertura dei requisiti

- Coperti da test automatici: tutti gli RF di Metronomo, Accordatore, Impostazioni e Azioni; quasi tutta l'Armonia.
- Verificati solo a mano: suono in background e notifica (RF-BG-01/02), code delle note (RF-ARM-11), sincronia dopo un cambio di tempo (RF-SYNC-03), focus audio del microfono (RF-ACC-09).
- Mai verificati: tutto ciò che riguarda l'iPhone (RF-BG-03, RF-WEB-04), la latenza della luce (RNF-LAT-03), l'avvio misurato sul telefono (RNF-AVV-01), la memoria (RNF-MEM-01).
- **Requisiti non funzionali senza un numero**: latenza dal tocco al suono, memoria, durata massima di un blocco dello schermo. Oggi "veloce" e "fluido" si giudicano a sensazione, e un peggioramento non lo vede nessun test.

## 6. Cose piccole trovate strada facendo

- `web/prova-microfono.html` (PR #88, "temporanea"): tolta il 4/11.
- Il README dice "The second row under the dial (the first is left empty)": riletta il 5/11, è giusta (sotto il quadrante tre righe, la prima vuota per Metronomo e Armonia).
- `docs/architecture.md` non parla dei brani né del lavoro a fette nel web: aggiornato il 5/11 (passo 11).
- Il pacchetto e le azioni dicono `drone`, l'interfaccia dice Armonia: è voluto per le azioni (compatibilità), ma nel codice interno non serve più.
