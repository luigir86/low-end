# Roadmap di Low End

L'unico elenco di lavoro del progetto, per Luigi e per tutti gli assistenti (Claude, ChatGPT, Codex). Dice **in che ordine** si lavora; **cosa** l'app deve fare sta in [specs/requisiti.md](specs/requisiti.md). Aggiornato il 20 novembre 2026, dopo il bilancio del progetto e le decisioni di Luigi; il 26 novembre 2026 aggiunto il piano per far conoscere l'app.

Regole:

- Al massimo **due lavori in corso** alla volta.
- Un'idea nuova va in **Idee**, non subito in lavorazione.
- Una PR che chiude o cambia un punto aggiorna questo file nella stessa PR.
- Un cambio che si vede o si sente si prova sul telefono (anteprima o APK di prova) prima di unirlo; per test, documenti e pulizie basta la CI verde.
- Un rilascio ogni due o tre settimane: almeno tre giorni nel test chiuso, poi produzione graduale (20%, 50%, 100%).

## In corso

1. **Consolidare** (fino a circa il 5 dicembre 2026)
   - 1.7.1 nel test chiuso, poi in produzione con rilascio graduale (Luigi, da Play Console).
   - Una sessione di prove sul telefono con una lista fissa, partendo dal Player, e le misure mai prese: dal tocco al suono su Android, luce del battito contro suono (30 minuti a 120 bpm), memoria, avvio a freddo. I numeri vanno in [specs/requisiti.md](specs/requisiti.md), insieme agli stati verificati.
   - Documenti in ordine: questo elenco, [AGENTS.md](../AGENTS.md), il [modello di PR](../.github/pull_request_template.md) e l'[archivio](archivio/README.md) dei documenti superati sul tema.
2. **Fondazione Fossano Musica** (Luigi): colloqui per un pilota con maestri e allievi. Non serve codice.

## Prossimi, in ordine

1. **Web app: WebAssembly predefinito su Safari.** La prova `?motore=wasm` sull'iPhone è andata bene.
2. **Player: "Brano" diventa "Traccia"** nelle quattro lingue, prima dell'editor dei brani: nell'Armonia "Brano" è un'altra cosa.
3. **"Valuta Low End" nelle Informazioni.** Apre la pagina di Low End su Google Play, dove si danno le stelle e si scrive la recensione. Regole di Google: non si chiede un voto preciso ("5 stelle?") e un pulsante porta allo store, non apre la finestra di recensione dentro l'app. Nella web app non compare.
4. **Far conoscere Low End, spendendo poco** (deciso il 26 novembre 2026), dopo i punti 1-3 e con una versione 1.7.x senza le righe 16 e 17 delle prove sul telefono:
   - Post onesti scritti da Luigi stesso, mai da un assistente a suo nome: r/musicians, r/Bass, r/piano, r/jazz, TalkBass, Musiker-Board; in Italia i maestri tramite la Fondazione Fossano Musica. Prima si leggono le regole di ogni comunità sull'autopromozione; si dice chi ha fatto l'app e che è stata scritta con l'aiuto di assistenti AI.
   - Ogni mese i dati per paese in Play Console (installazioni, disinstallazioni, voti): le nuove lingue si scelgono da lì, non a intuito.
   - Il credito Google Ads (circa 400 €) aspetta la versione corretta e le prime recensioni; poi una prova piccola, in due o tre paesi, con un budget giornaliero basso, misurando costo per installazione e chi resta dopo una settimana.
5. **Revisione madrelingua di spagnolo e francese**, prima della 1.8: un foglio con le frasi in inglese, spagnolo e francese e le schermate, per tester madrelingua (anche a pagamento) o, meglio, musicisti.
6. **Brani e giri (1.8)**, finito il consolidamento: prima P0, il giro come dato, da solo e con i test; poi l'anello delle battute, "I miei brani" e la condivisione di un brano. A ogni passo grande, una prova con un musicista che non conosce l'app.

## Idee, non ora

- "LLM first" con Android App Functions: da rivalutare nel 2027 (deciso il 20 novembre 2026).
- Nuovi suoni per l'Armonia, dopo la 1.8: chitarra (bossa, strumming, shuffle, swing alla Freddie Green), assolo di sax, progressioni metal con batteria. Si parte da una demo della chitarra bossa.
- App nativa per iPhone: 99 € l'anno di Apple e un Mac, oppure tramite la Fondazione.
- Nomi delle note alla tedesca (H, B) come altro sistema di nomi.
- Ghiera del tempo nell'Armonia e cerchi della stessa misura in tutte le schede: scartate per ora (9 e 13 novembre), da ripensare più avanti.
- F-Droid: compila l'app dal codice, e un'app Flutter con il motore audio in C++ richiede una ricetta di build da mantenere; la sua politica sull'AI è ancora in discussione. Da rivalutare dopo la 1.8.
- Un'impostazione per scegliere il microfono, se la registrazione con cuffie Bluetooth dovesse ancora prendere quello sbagliato.

## No, deciso di non fare

- Partiture PDF, MusicXML, MIDI.
- Account, cloud, server, tracciamento.
- Donazioni.
- IzzyOnDroid: rifiuta le app scritte anche in parte con assistenti AI, come Low End (politica di inclusione, controllato il 26 novembre 2026).
- Altri negozi (Samsung Galaxy Store, Huawei AppGallery) e APK su GitHub: più lavoro a ogni rilascio per pochi utenti in più; restano Google Play e la web app per iPhone (deciso il 26 novembre 2026).
- Servizi di test a pagamento (12 tester per 14 giorni): l'app è già in produzione e i tester non sono musicisti.
- Punteggi e gamification.
- Tema chiaro: l'app è sempre scura.
- Ritmi del metronomo (clave, bossa).
- Un'impostazione di bilanciamento dei volumi.
- Timbri diversi per il tono continuo.
- Riscrivere da capo il motore audio: solo correzioni mirate, ognuna dimostrata prima da un test che fallisce.
