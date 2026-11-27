# Roadmap di Low End

L'unico elenco di lavoro del progetto, per Luigi e per tutti gli assistenti (Claude, ChatGPT, Codex). Dice **in che ordine** si lavora; **cosa** l'app deve fare sta in [specs/requisiti.md](specs/requisiti.md). Aggiornato il 20 novembre 2026, dopo il bilancio del progetto e le decisioni di Luigi.

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
3. **"Valuta Low End" nelle Informazioni.** Apre la pagina di Low End su Google Play, dove si danno le stelle e si scrive la recensione. Regole di Google: non si chiede un voto preciso ("5 stelle?") e un pulsante porta allo store, non apre la finestra di recensione dentro l'app. Nella web app non compare. Fatto nella PR "Valuta Low End" (pulsante nelle Informazioni e azione `rate_app`): resta la prova sul telefono, poi esce con il prossimo rilascio raggruppato.
4. **Revisione madrelingua di spagnolo, francese e tedesco**, prima della 1.8: un foglio con le frasi in inglese, spagnolo, francese e tedesco e le schermate, per tester madrelingua (anche a pagamento) o, meglio, musicisti. Il tedesco (testi dell'app, nomi delle note C D E … H con B = Si♭, "C-Dur" e "a-Moll", scheda Play de-DE e schermate) è stato aggiunto il 26 novembre 2026 su richiesta di Luigi e parte con la prossima release raggruppata, dopo questa revisione.
5. **Armonia: il giro al centro come uno spartito** (deciso da Luigi il 27/11, RF-ARM-18): radice ferma, nome del giro, numeri romani di tutto il giro al posto dei pallini. PR in bozza; prova sul telefono (anche testo grande), poi esce con il prossimo rilascio raggruppato.
6. **Brani e giri (1.8)**, finito il consolidamento: prima P0, il giro come dato, da solo e con i test; poi l'anello delle battute (che toglie dal centro la griglia dei numeri romani), "I miei brani" e la condivisione di un brano. A ogni passo grande, una prova con un musicista che non conosce l'app.

## Idee, non ora

- "LLM first" con Android App Functions: da rivalutare nel 2027 (deciso il 20 novembre 2026).
- Nuovi suoni per l'Armonia, dopo la 1.8: chitarra (bossa, strumming, shuffle, swing alla Freddie Green), assolo di sax, progressioni metal con batteria. Si parte da una demo della chitarra bossa.
- App nativa per iPhone: 99 € l'anno di Apple e un Mac, oppure tramite la Fondazione.
- Ghiera del tempo nell'Armonia e cerchi della stessa misura in tutte le schede: scartate per ora (9 e 13 novembre), da ripensare più avanti.
- Un'impostazione per scegliere il microfono, se la registrazione con cuffie Bluetooth dovesse ancora prendere quello sbagliato.

## No, deciso di non fare

- Partiture PDF, MusicXML, MIDI.
- Account, cloud, server, tracciamento.
- Donazioni.
- Punteggi e gamification.
- Tema chiaro: l'app è sempre scura.
- Ritmi del metronomo (clave, bossa).
- Un'impostazione di bilanciamento dei volumi.
- Timbri diversi per il tono continuo.
- Riscrivere da capo il motore audio: solo correzioni mirate, ognuna dimostrata prima da un test che fallisce.
