# Requisiti di Low End

Ricostruiti dal codice di `main` al 4 novembre 2026 (PR #97 compresa, PR #98 ancora aperta) e dalle decisioni prese nei thread. Ogni requisito ha un codice stabile: quando cambia, si aggiorna la riga e non si riusa il codice per altro.

Stato: **✓** realizzato e coperto da test automatici · **◐** realizzato, verificato solo a mano o in parte · **○** da verificare sul telefono o non realizzato · **?** da chiarire.

## 1. Scopo e destinatari

Low End è un'app gratuita e open source per **tutti i musicisti** (nata da un contrabbassista per gli amici dell'orchestra, ma la scheda dello store non parla di basso): un'**Armonia** che suona accordi e giri al pianoforte per suonarci sopra, un **Metronomo** che va a tempo con l'Armonia, un **Accordatore** cromatico e un **Player** che suona un brano proprio rallentandolo e ripetendone un passaggio. Android prima di tutto; per l'iPhone una web app (PWA) dallo stesso codice. Niente server, niente account, niente rete.

Fuori dallo scopo, per decisione presa: libreria PDF e conversione in MusicXML/MIDI (rimandate), timbri diversi dal pianoforte, account o cloud, gamification, donazioni (né nell'app né su GitHub), tema chiaro, bilanciamento dei volumi tra le sezioni.

## 2. Requisiti funzionali

### 2.1 Struttura generale (RF-GEN)

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-GEN-01 | Quattro sezioni, nell'ordine Metronomo, Armonia, Ascolto (il Player), Accordatore (ordine deciso il 6/11 dopo la prima prova; prima il Player era l'ultimo). Le schede e lo scorrimento laterale (in orizzontale: verticale, su quadrante o barra) **solo navigano**: non avviano né fermano suoni. | ◐ | `playback_flow_test`, `widget_test` |
| RF-GEN-02 | Ogni sezione avvia e ferma il proprio suono dal centro del proprio quadrante. | ✓ | `playback_flow_test` |
| RF-GEN-03 | L'app si riapre sulla sezione in cui era stata lasciata; alla prima installazione sull'Armonia. | ✓ | `memory_test` |
| RF-GEN-04 | Mentre una sezione suona, la sua scheda mostra un punto che pulsa. | ✓ | `regression_test` |
| RF-GEN-05 | "Blocca i gesti" disattiva soltanto lo scorrimento tra le sezioni; azioni e schede funzionano ancora. | ✓ | `gestures_and_tempo_test` |
| RF-GEN-06 | Guida dei gesti al primo avvio, suggerimento dello scorrimento una volta sola. | ✓ | `widget_test` |
| RF-GEN-07 | Il volume è quello multimediale del telefono; nessun controllo di volume o di bilanciamento nell'app. | ✓ | (vincolo) |

### 2.2 Armonia (RF-ARM)

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-ARM-01 | Dodici tasti di nota attorno al quadrante, per quinte o per semitoni (impostazione). Tocco: suona; tocco su un'altra: cambia; ritocco o centro: ferma. | ✓ | `drone_controller_test` |
| RF-ARM-02 | Do♯ e Fa♯ si possono scrivere Re♭ e Sol♭ (pressione lunga); il suono non cambia. | ✓ | `songs_and_degrees_test`, `accessibility_test` |
| RF-ARM-03 | La fondamentale suona sempre nell'ottava 3 (La3 = 220 Hz); niente scelta dell'ottava, e per questo il quadrante scrive il solo nome, senza numero d'ottava (l'accordatore lo tiene: lì distingue corde e registri; deciso il 6/11). Le altre note dell'accordo stanno strette sopra, come le suona una mano. | ✓ | `piano_test` |
| RF-ARM-04 | Modo **Accordo**: la nota da sola o uno di nove accordi (maggiore, minore, 7, 7♭9, maj7, m7, m7♭5, diminuito, sus4). Il menu ricorda l'ultima scelta tra nota sola e accordo. | ✓ | `drone_controller_test`, `minor_dominant_test` |
| RF-ARM-05 | Modo **Giro**: un accordo per battuta, giri di 4, 8 o 12 battute nella tonalità della nota toccata; nove giri in tre sezioni (pop/rock, blues, jazz), dal più facile. | ✓ | `progression_test` |
| RF-ARM-06 | Durante un giro il quadrante mostra la tonalità, i gradi in numeri romani e l'accordo che suona; le note fuori dall'accordo si attenuano. L'accordo mostrato cambia quando lo si **sente**, non quando lo si calcola. | ✓ | `songs_and_degrees_test`, `progression_test` |
| RF-ARM-07 | Stili al pianoforte: tenuto (una volta a battuta), su ogni battito, arpeggio, walking bass (contrabbasso pizzicato, una nota a battito, piano che accompagna sopra). Quinto stile: suono tenuto continuo al posto del pianoforte. **Intonazione** (deciso il 4/11): il suono tenuto è a intervalli puri, perché non batta e serva a intonare; il pianoforte, compreso il walking, è temperato. | ✓ | `walking_bass_test`, `piano_test`, `drone_controller_test` |
| RF-ARM-08 | **Brani**: nove brani di esempio, ognuno un preset completo (tonalità, giro, stile, tempo, metro, eventuali suddivisione e click sul 2 e 4). Un brano si legge e si scrive anche in JSON. | ✓ | `song_preset_test` |
| RF-ARM-09 | Cambiare brano mentre l'Armonia suona ferma subito il vecchio, prepara **un solo** nuovo loop e lo avvia mostrando l'attesa. | ✓ | `song_preset_test` (PR #98); prova sul telefono da fare |
| RF-ARM-10 | Cambiare nota o accordo negli stili a battito o arpeggio non fa inciampare il battito: il nuovo accordo entra sul battito successivo. Tenuto o in un giro, riparte dall'inizio della battuta. | ✓ | `piano_test` |
| RF-ARM-11 | Fermare o cambiare accordo lascia andare le note come un pianista (coda), invece di tagliarle. | ◐ | solo ascolto |
| RF-ARM-12 | Al primo avvio l'Armonia è sul giro I–VI–IV–V in La, stile a battito; dopo ricorda tutto ciò che il musicista ha scelto (non se suonava). | ✓ | `memory_test` |
| RF-ARM-13 | Se il primo suono tarda (registrazioni o motore ancora in arrivo) il centro del quadrante mostra l'attesa dopo 0,4 s, e dopo 5 s dice che la connessione è lenta; il giro resta sul primo accordo finché non lo si sente. | ✓ | `drone_wait_test` |
| RF-ARM-14 | L'Armonia segue tempo e metro del metronomo; senza metronomo usa il tempo e il metro impostati. | ✓ | `progression_test` |
| RF-ARM-15 | **Transizioni musicali** (deciso il 4/11, demo 3b e 3c in `audio-demo/transizioni/`). Mentre l'Armonia suona al pianoforte, cambiare **brano, giro, stile, o tonalità di un giro** non taglia il suono: il nuovo appare subito sullo schermo, il vecchio continua e **cala di volume** (fino a circa un terzo) fino alla **stanghetta** successiva, dove lascia andare le note mentre il nuovo attacca a volume pieno. Se alla stanghetta manca meno di un battito, il cambio passa alla battuta dopo. Con il metronomo che suona, la stanghetta è la sua, e un **brano** che cambia anche tempo o misura li fa cambiare al metronomo **sulla stessa stanghetta**: fino ad allora il click va avanti al vecchio tempo, sceso subito (entro un battito) a circa un sesto, più del pianoforte perché un colpo secco si sente più di un accordo tenuto, poi metronomo e pianoforte attaccano insieme il nuovo "uno" a volume pieno (deciso il 5/11; prima il metronomo cambiava al tocco). Se il nuovo giro del pianoforte è pronto solo dopo quella stanghetta (un walking, un telefono lento), il metronomo lo aspetta basso al vecchio tempo ed entrano comunque insieme, anche una battuta dopo (1.4.3; nella 1.4.2 il click ripartiva pieno sopra un pianoforte ancora basso). Al centro del quadrante si contano i **battiti** che mancano (3… 2… 1). Più cambi fatti insieme (un brano, un'azione con più argomenti) sono un solo cambio. Cambiare nota o accordo in modo Accordo resta sul battito (RF-ARM-10). | ◐ | `transitions_test`, `song_preset_test`; livello del calo da sentire sul telefono |
| RF-ARM-16 | **Tempo in Armonia** (deciso il 5/11): la prima riga dell'Armonia ha due metà come quella del Metronomo, Modalità e Tempo ("♩ = 80"), alte uguali. Il tempo è uno solo, quello del metronomo; toccarlo apre lo stesso foglio della matita, così il suono cambia una volta sola, all'OK. La misura resta nel Metronomo. | ✓ | `harmony_tempo_test` |

### 2.3 Metronomo (RF-MET)

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-MET-01 | Tempo da 30 a 250 BPM (fino a 400 in 7/8, dove conta le crome); predefinito 80 in 4/4. | ✓ | `metronome_controller_test` |
| RF-MET-02 | Il tempo si cambia con la ghiera interna (RF-MET-09), con − e + (pressione lunga che accelera e si ferma sui numeri tondi), con TAP, o scrivendolo (matita). Toccare il numero avvia e ferma. Sotto il numero il nome italiano del tempo. | ✓ | `gestures_and_tempo_test` |
| RF-MET-03 | Nove metri (1/1, 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8, 12/8) con i battiti raggruppati come si contano. | ✓ | `metronome_controller_test` |
| RF-MET-04 | Suddivisioni: semiminime, crome, crome swing, terzine, semicrome, semicrome swing (swing al 60%); solo nei metri in quarti. Click sul 2 e 4: solo in 2/4 e 4/4. | ✓ | `metronome_subdivision_test` |
| RF-MET-05 | Anello che si accende battito per battito, il primo marcato; la luce arriva **insieme** al suono (compensando il ritardo dell'uscita: altoparlante, cuffia, Bluetooth, browser). | ◐ | costanti di ritardo mai misurate sul telefono |
| RF-MET-06 | Il tempo non deriva mai: si suona in loop una battuta intera generata in memoria. | ✓ | `metronome_controller_test` |
| RF-MET-07 | Tempo, metro, suddivisione e click sul 2 e 4 si ricordano al riavvio. | ✓ | `row_test` |
| RF-MET-08 | **Cambi di tempo musicali** (deciso il 4/11): con la ghiera o con − e + (tocco o pressione lunga) il numero cambia subito, ma il suono (click e Armonia) passa al nuovo tempo solo quando il dito si ferma per 0,3 s, e prosegue dal punto della battuta in cui è. Con il TAP il numero segue i colpi e il suono cambia quando si smette di battere (dopo una volta e mezza l'intervallo tra i colpi, almeno 0,6 s). Il tempo scritto, quello di un brano e quello di un'azione si applicano subito. | ✓ | `transitions_test`, `metronome_controller_test` |
| RF-MET-09 | **Ghiera rapida del tempo** (approvata il 7/11): fascia esterna chiara e sottile (revisione 2: fino a 20 dp visibili e 36 dp sensibili), battiti all'interno senza aumentare l'ingombro del quadrante; orario aumenta, antiorario diminuisce, 90° = 30 BPM relativi. Nessun salto al contatto o a ore 12, nessun avvio/stop o cambio sezione durante il gesto. Rispetta limiti, persistenza e debounce RF-MET-08; centro, ±1, pressione lunga, TAP e matita restano disponibili. Slider accessibile separato dal pulsante centrale. Progetto e prove: [ghiera-metronomo.md](ghiera-metronomo.md). | ◐ | `metronome_tempo_dial_test`; ergonomia e lettore di schermo da provare sul telefono |

### 2.4 Insieme Armonia e Metronomo (RF-SYNC)

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-SYNC-01 | Armonia e Metronomo possono suonare insieme, a tempo. Quello avviato per secondo entra sulla stanghetta successiva dell'altro, con un conto alla rovescia al centro del quadrante. | ✓ | `drone_wait_test`, `metronome_controller_test` |
| RF-SYNC-02 | Fermare durante l'attesa annulla l'avvio. | ✓ | `playback_flow_test` |
| RF-SYNC-03 | Un cambio di tempo mentre suonano entrambi non sposta l'uno rispetto all'altro: il pianoforte torna sul battito del click. | ◐ | `loop_transport_test` (solo la matematica) |
| RF-SYNC-04 | Nessuno dei due avvia l'altro. | ✓ | `playback_flow_test` |

### 2.5 Accordatore (RF-ACC)

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-ACC-01 | Cromatico: si suona una nota e compare, senza scegliere la corda. Strobo circolare con la nota al centro, scala dei cent sotto (asse segnato ogni 5 cent, lancetta, asse colorato da 0 alla lancetta). | ✓ | `tuner_test` |
| RF-ACC-02 | Rilevamento YIN da 28 a 2800 Hz; con il basso scelto fino a 700 Hz (scarta voci e fruscio). | ✓ | `pitch_detector_test`, `bass_support_test`, `review/pitch_review_test` |
| RF-ACC-03 | Campo Strumento: cromatico, chitarra, basso, ukulele, violino, viola, violoncello, con il numero di corda. Predefinito **chitarra** (scelta voluta), poi l'ultimo scelto. | ✓ | `review/settings_review_test` |
| RF-ACC-04 | Strumenti traspositori (Si♭, Mi♭, Fa) in impostazioni: l'accordatore cromatico mostra la nota scritta. | ✓ | `tuner_transposition_test` |
| RF-ACC-05 | Verdetto: verde salvia intonato, giallo paglia vicino, rosso mattone lontano (scelti da Luigi il 7/11 al posto del verde acqua; per i daltonici restano parole, spunta, frecce e posizione); zona intonata ±2, ±5 (predefinito) o ±10 cent. Il colore del verdetto va sull'etichetta, sulla lancetta della scala dei cent e sulle bande dello strobo mentre una nota si sente (grigie a riposo o con la nota tenuta), mai unico segnale: spunta se intonato, una freccia se vicino, due se lontano (oltre 15 cent). | ✓ | `accessibility_test`, `tuner_strobe_test` |
| RF-ACC-06 | La A di riferimento (415–445 Hz, a passi di 1; scorciatoie 415, 432, 440, 442) è condivisa con l'Armonia. | ✓ | `regression_test` |
| RF-ACC-07 | Il microfono ascolta solo con l'accordatore sullo schermo; si spegne cambiando sezione, aprendo le impostazioni o mandando l'app in background. Niente riparte da solo. | ✓ | `regression_test`, `startup_test` |
| RF-ACC-08 | Entrare nell'accordatore non ferma niente: ascolta da solo solo se nulla suona. Toccare il quadrante (o `tuner_start`) mette in pausa Metronomo e Armonia, con un avviso e il pulsante "Riprendi". | ✓ | `playback_flow_test` |
| RF-ACC-09 | Il microfono non prende il focus audio: la musica di un'altra app continua. | ◐ | provato sul telefono una volta |
| RF-ACC-10 | Con un auricolare Bluetooth l'audio non deve restare in qualità telefonata (HFP) dopo l'accordatore. | ? | valutazione del 4/11 in attesa |

### 2.6 Impostazioni (RF-IMP)

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-IMP-01 | Ingranaggio in alto a destra, con dentro "Informazioni" (versione, licenze). | ✓ | `widget_test`, `review/layout_review_test` |
| RF-IMP-02 | Lingua (sistema, inglese, italiano, spagnolo, francese); nomi delle note (segue la lingua, Do Re Mi, C D E); numerazione delle ottave (scientifica La4 = 440, italiana/franco-belga La3 = 440) indipendente dai nomi. "Segue la lingua" dà Do Re Mi in italiano, spagnolo e francese (Do Ré Mi), C D E nelle altre. Le parole di accordi e tonalità ("maggiore", "major", "mayor", "majeur") seguono il sistema delle note, mai lettere con parole di un'altra lingua: con C D E si scrive "C♯ major" in ogni lingua; con Do Re Mi le parole sono quelle della lingua dell'app ("Do♯ mayor", "Ré majeur"), italiane se l'app è in inglese (deciso il 5/11 e il 6/11). Un altro sistema (il tedesco C D E… H, "C-Dur") si aggiunge come un valore in più di `NoteNames`, con le sue note e parole. | ✓ | `language_test`, `names_test`, `chord_words_test` |
| RF-IMP-03 | A di riferimento, cerchio (quinte o semitoni), schermo acceso mentre suona o ascolta (sì per default), blocco dei gesti, zona intonata, traspositore. | ✓ | `review/settings_review_test` |
| RF-IMP-04 | Tutto si salva solo sul telefono (backup Android spento); impostazioni illeggibili non bloccano mai l'avvio: si riparte dai valori predefiniti, un valore alla volta. | ✓ | `memory_test`, `row_test` |
| RF-IMP-05 | Nessuna scelta di tema: l'app è sempre scura. | ✓ | `theme_test` |

### 2.7 Suono in background e interruzioni (RF-BG)

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-BG-01 | Su Android, con lo schermo spento o l'app in background, Metronomo e Armonia continuano, con una notifica multimediale che dice cosa suona (play/pausa/stop). La notifica c'è solo mentre suona o dopo la sua pausa. | ◐ | provato sul telefono (PR #63) |
| RF-BG-02 | Staccare le cuffie mette in pausa come un lettore musicale (notifica in pausa, avviso con "Riprendi"). | ◐ | provato sul telefono |
| RF-BG-03 | Nella web app su iPhone, se il browser taglia l'audio (chiamata, schermo bloccato) l'app si mette in pausa invece di sembrare che suoni. | ○ | mai provato su iPhone |

### 2.8 Azioni per assistenti, "LLM first" (RF-LLM)

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-LLM-01 | Tutto ciò che il musicista può fare sullo schermo è anche un'azione con nome, argomenti JSON e risposta JSON con lo stato completo (`lib/actions/app_actions.dart`). | ✓ | `app_actions_test`, `review/actions_review_test` |
| RF-LLM-02 | Il catalogo `docs/llm-actions.json` è generato dal codice e un test lo tiene allineato. | ✓ | `app_actions_test` |
| RF-LLM-03 | Gli argomenti si controllano tutti prima di cambiare qualcosa: un argomento sbagliato non cambia nulla e l'errore si può leggere e correggere. | ✓ | `review/actions_review_test` |
| RF-LLM-04 | Link `lowend://action/...` su Android e `#/action/...` nel web. Un link non può cambiare le impostazioni salvate. | ✓ | `app_actions_test` |
| RF-LLM-05 | Le azioni seguono le stesse regole delle dita (un'azione di avvio apre la sua sezione, `tuner_start` mette in pausa gli altri…). | ✓ | `app_actions_test` |
| RF-LLM-06 | Prossimo passo proposto: Android App Functions. | ○ | non iniziato |

### 2.9 Web app per iPhone (RF-WEB)

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-WEB-01 | Stesso codice dell'app Android, pubblicato su GitHub Pages a ogni push su `main`; installabile con "Aggiungi a Home". | ✓ | workflow `web.yml` |
| RF-WEB-02 | Funziona offline dopo la prima apertura (service worker); i suoni in una cache a parte. | ◐ | banco di prova in cloud |
| RF-WEB-03 | Il primo suono parte anche su una rete lenta (nessun timeout del motore) e un download fallito si riprova al tocco seguente. | ✓ | `web_parts_test` |
| RF-WEB-04 | Il tasto silenzioso dell'iPhone non zittisce il click (sessione audio "playback"). | ○ | mai provato su iPhone |
| RF-WEB-05 | Le funzioni che solo Android ha (notifica, cuffie staccate, percorso audio) hanno un sostituto o mancano in modo dichiarato in `docs/web.md`. | ✓ | `web_parts_test` |

### 2.10 Player (RF-PLY)

Terzo tab, "Ascolto" in italiano (deciso il 6/11 e rivisto lo stesso giorno dopo la prima e la seconda prova di Luigi: revisione 3, bandiere A e B e striscia del passaggio): un brano proprio, scelto con il selettore di sistema, suonato dal quadrante, rallentato senza cambiare intonazione e con un passaggio che si ripete. Come si costruisce, e in quali passi: [player.md](player.md). Stato ○ finché la PR che lo realizza non è unita e provata sul telefono.

| Codice | Requisito | Stato | Test |
| --- | --- | --- | --- |
| RF-PLY-01 | Si sceglie un file audio con il selettore di sistema, senza permessi (Android `ACTION_OPEN_DOCUMENT`, web `<input type="file">`). Formati: quelli che legge il sistema (MP3, M4A/AAC, WAV, FLAC ovunque; Ogg/Opus su Android). I brani dei servizi in abbonamento non si aprono. Il campo Brano sta da solo nella terza riga sotto il quadrante e riapre il selettore (revisione 3). | ◐ | `player_controller_test` con file finti; telefono |
| RF-PLY-02 | Il centro del quadrante avvia e mette in pausa, come negli altri cerchi: tempo trascorso, durata e simbolo per riprodurre o mettere in pausa. Il lettore di schermo dice "Riproduci" o "Pausa". Senza brano il centro mostra "Scegli un brano" e il tocco apre il selettore. | ◐ | `player_panel_test` |
| RF-PLY-03 | Il toro è l'orologio del brano intero, sempre: il giro è la durata, da ore 12 in senso orario (niente vista Passaggio sul toro: lo zoom è la striscia di RF-PLY-17; revisione 3). Dentro, la forma d'onda (RF-PLY-15); fuori dal toro, in una fascia sottile dentro lo stesso cerchio degli altri tab (come la ghiera del Metronomo), le tacche a tempi tondi con il tempo scritto sulle lunghe (passo scelto da solo tra 1 s, 2 s, 5 s, 10 s, 15 s, 30 s, 1, 2, 5, 10, 20, 30, 60 minuti: il più piccolo che lascia al massimo 8 numeri, per esempio ogni 5 s su 0:27, ogni minuto su 6:03, ogni 2 minuti su 12:00; tacche corte in mezzo; nessun numero a meno del 6% dalla fine, per non toccare 0:00; su un quadrante sotto i 240 dp solo tacche); il punto di ascolto è un **cursore**, un segmento radiale su tutto lo spessore del toro, come nei programmi audio. Al centro tempo trascorso, durata e icona di riproduzione o pausa. Toccare il toro sposta l'ascolto. | ◐ | `player_ring_test`, `player_panel_test` |
| RF-PLY-04 | Il Player suona da solo. Avviarlo mette in pausa Metronomo e Armonia con l'avviso "In pausa mentre ascolti" e "Riprendi"; avviare Metronomo o Armonia mette in pausa il Player, senza avviso. Entrare nel tab non ferma niente. Accordatore in ascolto, cuffie staccate, una chiamata o un altro lettore lo mettono in pausa come le altre sezioni. | ○ | `playback_rules_test`, `playback_flow_test` |
| RF-PLY-05 | Notifica e schermo spento: titolo (o nome del file) e autore, play e pausa. | ○ | `playback_rules_test`; telefono |
| RF-PLY-06 | A fine brano, senza loop, si ferma e torna all'inizio. | ○ | `player_controller_test` |
| RF-PLY-07 | Errori chiari: "Questo file non si può aprire" (formato o protezione), "Il file non è più disponibile" (spostato o permesso perso). Il Player torna vuoto, l'app non si blocca. | ○ | `player_controller_test` |
| RF-PLY-08 | Velocità dal 50 al 125% senza cambiare intonazione: il campo accanto al Loop apre una lista corta (50, 60, 70, 75, 80, 85, 90, 100, 110, 125%); diversa da 100% è nell'accento; l'azione accetta ogni intero. | ○ | `player_controller_test`; ascolto al CANCELLO 3 |
| RF-PLY-09 | Segna inizio e Segna fine catturano il punto ascoltato con compensazione di 150 ms × velocità durante la riproduzione. In pausa usano il cursore esatto. Durata minima di un secondo. | ◐ | `player_loop_test`, `accessibility_test` |
| RF-PLY-10 | Spostamenti e ritocchi: A e B sono anche **maniglie sul toro** (cerchietti con la lettera, bersaglio di 48 dp) che si trascinano lungo il brano intero, con le 12 come muro; le aste della striscia rifiniscono e, tenute contro un bordo, allargano la striscia da quella parte finché il dito resta lì (si fermano a 1 s l'una dall'altra e nessun trascinamento cambia tab); con il lettore di schermo ogni asta è un cursore da 100 ms; l'azione `player_loop_nudge` sposta di quanto si vuole. Mentre suona, il suono segue quando A e B restano fermi per 0,3 s: ritoccando A riparte da A, ritoccando B riparte 2 s prima di B, mai prima di A. | ◐ | `player_loop_test`, `player_panel_test` |
| RF-PLY-11 | Il toro mostra il passaggio come arco con le maniglie A e B e permette il seek fuori dalle maniglie. Segnando B si ripete il passaggio e, se in riproduzione, si riparte da A. Toccare il toro fuori dal passaggio disattiva la ripetizione conservando A e B. | ◐ | `player_panel_test`, `player_loop_test` |
| RF-PLY-12 | Un solo pulsante, primo della seconda riga, dice il passo: Segna inizio e Segna fine (pieno d'accento come TAP, con la bandierina A o B), Loop attivo (pieno d'accento), Riattiva loop (A e B segnati, loop spento; solo bordo). Spegnere il loop tiene A e B; il pulsante Nuovo passaggio accanto alla striscia, sempre presente e spento senza A né B, li cancella (`player_loop_clear`). Stacco al giro: obiettivo sotto 30 ms su Android e sotto 80 ms sul web. | ◐ | `player_loop_test`, `player_panel_test`; misura sul telefono |
| RF-PLY-13 | Android: brano, passaggio e velocità tornano al prossimo avvio, senza leggere il file finché non si apre il tab o si preme play. Web: nessun ripristino. Brano nuovo: loop spento e 100%. | ◐ | `player_controller_test`, `player_memory_test`, `player_setup_test`, `startup_test` |
| RF-PLY-14 | Titolo e autore dai tag (Android: tutti i formati; web: ID3v2 degli MP3), altrimenti il nome del file senza estensione. | ◐ | `track_tags_test` |
| RF-PLY-15 | Forma d'onda dentro il toro: un picco ogni 10 ms, simmetrico attorno al centro dell'anello, in decibel su 48 dB rispetto al picco più alto. Si calcola fuori dal thread dello schermo dopo l'apertura (il brano suona subito); su Android si riempie in senso orario mentre il file si legge. Sul web solo per brani fino a 15 minuti e 40 MB. Colori del tema: bronzo dentro il passaggio a loop acceso, grigio fuori, sul toro e sulla striscia (RF-PLY-17). Niente spettrogramma (deciso il 6/11). | ◐ | `track_peaks_test`, `player_ring_test`; telefono e iPhone |
| RF-PLY-16 | Il pulsante e le azioni accessibili del toro segnano il punto ascoltato. Ciascun estremo sulla striscia è un cursore accessibile con passo di 100 ms. Il toro offre passi di 10 s. Bersagli di almeno 48 dp e stato espresso anche tramite testo. | ◐ | `accessibility_test` |
| RF-PLY-17 | Il layout condiviso mantiene coincidente il centro dei quadranti nelle quattro schede. La prima riga mostra la forma d’onda completa, poi il passaggio A–B con margini e aste mobili. La seconda contiene Loop e Velocità, la terza Brano. Il dettaglio si assesta dopo il ritocco e rispetta le animazioni ridotte. | ◐ | `player_ring_test`, `player_panel_test` |
| RF-PLY-18 | Gli errori di apertura sono annunciati nella prima riga. Senza brano i comandi Loop e Velocità sono disabilitati. | ◐ | `player_panel_test` |
| RF-PLY-19 | Titolo e autore al centro del quadrante (revisione 3), solo se il file ha almeno un tag (RF-PLY-14), su una riga sopra il tempo. Se non entra scorre come nelle vecchie radio, ma una sola passata quando si apre il brano e a ogni play, al massimo 5 s, poi resta fermo all'inizio (WCAG 2.2.2); con le animazioni ridotte non scorre mai. | ◐ | `marquee_test` |
| RF-PLY-20 | **Registrazione** (aggiunta il 7/11, corretta l'8/11): REC, accanto a Brano, mette in pausa il Player e registra dal microfono (permesso chiesto la prima volta; metronomo e Armonia continuano). Mentre registra, il cerchio mostra la ripresa e non il brano: l'onda rossa cresce col volume del microfono (letto 10 volte al secondo, misurato sul fondo scala, così una ripresa debole resta piccola) e una linea segna dove si è arrivati; il giro vale 1 minuto, poi 2, 5, 10, 15, 20, 30, 45, 60 minuti con le tacche aggiornate (aggiunto il 9/11). Stop apre la ripresa nel Player dall'inizio, **sopra** il brano che si stava studiando: quel brano resta quello ricordato e torna con velocità e passaggio quando la ripresa si elimina o si rimuove. Scarta butta la ripresa. Salva, Condividi ed Elimina compaiono solo con una ripresa aperta; una ripresa non salvata eliminata si riprende con Annulla nell'avviso. La ripresa è temporanea (cache dell'app, cancellata al prossimo avvio): Salva la esporta con il selettore di sistema (download sul web), Condividi la passa a un'altra app. Lasciare il tab, aprire le impostazioni, andare in background o avviare il Player fermano la registrazione tenendo la ripresa. Android: AAC in .m4a; web: WAV. | ◐ | `recording_test`, `player_panel_test`; telefono e iPhone |

Azioni per assistenti (RF-LLM): `player_open`, `player_play`, `player_pause`, `player_seek`, `player_speed`, `player_loop`, `player_mark`, `player_loop_nudge`, `player_loop_off`, `player_loop_clear`, `player_record`, `player_record_stop`; `get_state` con il blocco `player` (velocità, loop, `take` e `recording`); `open_section` accetta `player`. Salva e Condividi aprono finestre del telefono e restano alla persona. Verifica: `app_actions_test` (golden), `recording_test`.

## 3. Requisiti non funzionali

| Codice | Requisito | Misura o criterio | Stato |
| --- | --- | --- | --- |
| RNF-AVV-01 | **Avvio velocissimo** su Android: niente di pesante prima del primo frame; motore audio al primo suono, microfono dopo il primo frame. Il Player non crea il lettore e non legge file all'avvio (RF-PLY). | `startup_test`; `timeToFirstFrameMicros` da misurare con `--trace-startup` | ✓ test, ○ misura sul telefono mai registrata |
| RNF-AVV-02 | Avvio della web app: primo frame con meno di 3 MB scaricati; avvio dalla cache sotto 2 s. | banco `perf-web` (27/10: 1,8 s in cache) | ◐ |
| RNF-LAT-01 | **Dal tocco al suono** (deciso il 4/11), Android e web, su un telefono come il S20 FE: sempre **sotto 1 s**, obiettivo **0,5 s**, walking compreso. Vale per il primo suono; un cambio mentre suona segue RF-ARM-15 e RF-MET-08, dove aspettare il battito giusto è voluto. | Android mai misurato; web walking 0,7 s (PR #87) | ◐ |
| RNF-LAT-02 | La **fluidità conta più della velocità** (deciso il 4/11): meglio un'attesa visibile e un ingresso a tempo che un suono rapido ma brusco. | ascolto | ○ |
| RNF-LAT-03 | La luce del battito con il suono, entro 30 ms (proposta, da confermare dopo le misure). | costanti +20 ms altoparlante, +160 ms BT mai misurate | ○ |
| RNF-FLU-01 | **Fluidità**: lo schermo non si blocca più di 100 ms per un'azione del musicista (cambio sezione, accordo, brano, tempo), né su Android né nel web; il suono non si interrompe mentre si prepara quello nuovo. | brano: corretto dalla PR #98; tempo e stile nel web ancora a rischio | ○ |
| RNF-MEM-01 | Memoria contenuta su telefoni economici (proposta, da confermare dopo le misure: < 150 MB di picco suonando un walking di 12 battute). | mai misurata | ? |
| RNF-DIM-01 | App leggera: pochi pacchetti, codec inutili esclusi; dimensione dell'APK per architettura da tenere sotto controllo (oggi 13 MB di campioni). Con il Player (ExoPlayer) al massimo 2,5 MB più grande di prima, da misurare al CANCELLO 3 del Player. | `pubspec.yaml` | ◐ |
| RNF-UX-01 | **UI/UX** prima di tutto, in stile Material 3 e Android standard (durate e curve M3, pulsanti standard, menu uniformi); identità del marchio: sempre scuro, quadrante, strobo, font Edwin; temi a quattro colori Ebony & Bronze (attivo) e Rosso. | `style_test`, `theme_test`, `choice_menu_test`, `row_heights_test` | ✓ |
| RNF-UX-02 | Ogni testo visibile in inglese (riferimento), italiano, spagnolo e francese; niente testi o colori scritti nel codice. | `.arb`, `style_test` | ✓ |
| RNF-UX-03 | Layout senza overflow da 320×568 al tablet, in orizzontale, testo fino a 2×, in italiano e inglese, e in francese e spagnolo (le lingue più lunghe) sui telefoni più stretti. | `review/layout_review_test`, `dial_alignment_test` | ✓ |
| RNF-UX-04 | Due temi da quattro colori (marchio, accento, scuro, chiaro) scelti da una sola costante, `LowEndBrand.palette`: Ebony & Bronze e Rosso; nessuna scelta utente. Icona e avvio rigenerati dagli stessi colori; verdetti e strobo indipendenti dal tema (strobo grigio a riposo, colorato dal verdetto mentre una nota si sente, RF-ACC-05). Vedi `tema-ebano-bronzo.md`. | `theme_test`, `style_test`, revisione visiva | ○ |
| RNF-ACC-01 | **WCAG 2.1 AA** (volontario, Legge Stanca): etichette per lettori di schermo, bersagli di tocco, contrasto ≥ 3:1 sui controlli e 4,5:1 sul testo, colore mai unico segnale, animazioni ridotte rispettate. | `accessibility_test` | ✓ |
| RNF-PRIV-01 | **Nessuna rete**: niente codice di rete in `lib/`, nessun permesso `INTERNET` né `ACCESS_NETWORK_STATE` in release (il secondo lo porta ExoPlayer e si toglie nel manifest), nessun dato raccolto. | `docs/offline.md`, `PRIVACY.md` | ✓ |
| RNF-OSS-01 | **Open source MIT**; ogni componente e campione con licenza compatibile e citata (Salamander pubblico dominio, Meatbass CC0, Edwin e Noto Music OFL). | `THIRD_PARTY_NOTICES.md`, audit del 24/10 | ✓ |
| RNF-LLM-01 | **LLM first**: nessuna funzione solo da dita (vedi RF-LLM-01); la documentazione per assistenti aggiornata con il codice. | `app_actions_test` | ✓ |
| RNF-TEST-01 | Tutto si prova senza telefono: ogni cosa esterna dietro un'interfaccia con un gemello muto o finto. | ~430 test, CI su ogni PR | ✓ |
| RNF-TEST-02 | Il codice che parla davvero con il motore audio (loop, code, sincronia) è verificato con prove ripetibili. | `bar_loop_player_test` su un motore finto con il suo orologio (dal 5/11); nessun test sulle uscite `SoLoud*Output` | ◐ |
| RNF-AUD-01 | Qualità del suono "una coccola": pianoforte stereo 48 kHz, nessun clipping (limiter sul mix), niente click a inizio o fine. | ascolto (thread "Qualità del motore audio") | ◐ |
| RNF-REL-01 | Rilascio: versione nel `pubspec.yaml` alzata a ogni caricamento; targetSdk richiesto da Play; firma con la chiave di upload fuori dal repository. | `docs/release-checklist.md` | ◐ |

### Misure di partenza (4 novembre 2026, Galaxy S20 FE, `main` d372e31, build release, copia `.perf` accanto all'app del Play)

| Misura | `main` di oggi | Play 1.3.0 (29 ottobre) | Requisito |
| --- | --- | --- | --- |
| Avvio a freddo (`am start -W`, TotalTime, mediana di 5) | **1040 ms** (978–1977) | 314 ms (273–414) | RNF-AVV-01: **peggiorato di 3 volte** |
| Memoria a riposo subito dopo l'avvio (PSS totale / nativa) | **413–431 MB / 156–172 MB** | 155 MB / 30 MB | RNF-MEM-01: oltre la proposta di 150 MB |
| Memoria con Stand by Me dopo 15 s | 349 MB / 173 MB | – | |
| Memoria con Autumn Leaves (walking) dopo 15 s | 379 MB / 197 MB | – | |
| Dal comando (link d'azione) al suono (avvio dello stream AAudio) | 270–660 ms, mediana ~520 ms | – | RNF-LAT-01: sotto 1 s, vicino all'obiettivo di 0,5 s |
| Thread dello schermo fermo, cambio brano | 40–120 ms (Autumn Leaves fino a 120, Tune Up 110, Stand by Me 100) | – | RNF-FLU-01: appena sopra i 100 ms |
| Thread dello schermo fermo, cambio stile / tempo | 60 ms / 30 ms | – | RNF-FLU-01: rispettato |

Note: `dumpsys gfxinfo` non vede i frame di Flutter, quindi il blocco è misurato campionando ogni 10 ms il thread dello schermo; il tocco vero sullo schermo (non il link) va misurato filmando a 240 fps. Ipotesi da verificare per l'avvio e la memoria: aprendo sull'Armonia (dalla PR #96) l'app prepara subito pianoforte e contrabbasso (`preparePiano` dopo il primo frame, `prefetchBass: true`), cioè motore audio e decodifica di tutti i campioni all'avvio; conta anche l'APK unico da 70 MB contro quello diviso da 30 MB del Play. Trovato anche: il primo link d'azione dopo un avvio da `adb` apre altre istanze della schermata principale (tre nella pila), da controllare. Corretto il 4/11 (da rimisurare): pianoforte preparato 1,2 s dopo il primo frame, contrabbasso solo per il walking e letto a gruppi di dieci anche su Android, dove la decodifica gira sul thread dello schermo. Per un confronto giusto con il Play va misurato un APK diviso per architettura (`flutter build apk --split-per-abi`). Numeri grezzi e comandi: `C:\Users\ribal\Projects\LowEnd-misure\2026-11-04.md` sul PC di Luigi.

## 4. Vincoli già decisi (non riproporre)

Sempre tema scuro, un solo accento per variante interna; niente scelta utente, tema chiaro né colori per sezione. Niente donazioni. Niente scelta dell'ottava, preset per basso, forme d'accordo. Strumento predefinito dell'accordatore: chitarra. Nome "Low End", pacchetto `com.luigir86.low_end` (permanente). Scheda dello store rivolta a tutti i musicisti. Niente app iOS nativa: per l'iPhone solo la web app. Il click resta quello di oggi (niente woodblock modale).

## 5. Questioni aperte da decidere

1. **Bluetooth HFP dopo l'accordatore** (RF-ACC-10): valutazione in attesa.
2. Livello e durata del calo di volume (RF-ARM-15): da riascoltare sul telefono.
3. **Luce e memoria** (RNF-LAT-03, RNF-MEM-01): i numeri proposti si confermano dopo le misure del passo 1.

### Decise il 4 novembre 2026

- Intonazione: suono tenuto puro, pianoforte temperato (RF-ARM-07); `llm.md` e README corretti.
- Dal tocco al suono sotto 1 s, obiettivo 0,5 s; la fluidità prima della velocità (RNF-LAT-01, RNF-LAT-02).
- Transizioni musicali tra brani (RF-ARM-15) e cambi di tempo applicati quando il dito si ferma (RF-MET-08).
- Pagina di prova del microfono `web/prova-microfono.html` tolta.
