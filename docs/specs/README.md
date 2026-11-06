# Specifiche di Low End

Questa cartella è il punto di partenza per lavorare "spec-driven": prima si scrive (o si corregge) **cosa** l'app deve fare, poi si scrivono i test che lo verificano, solo dopo si tocca il codice. Le spec sono state ricostruite il 4 novembre 2026 dal codice di `main` (fino alla PR #97), dai documenti in `docs/`, dal README, dal catalogo `docs/llm-actions.json` e dalle decisioni prese nei thread del progetto.

| File | Che cosa contiene |
| --- | --- |
| [requisiti.md](requisiti.md) | Requisiti funzionali (RF) e non funzionali (RNF), ognuno con un codice, lo stato attuale e i test che lo coprono; in fondo le questioni ancora da decidere |
| [architettura.md](architettura.md) | Com'è fatta l'app oggi: moduli, dipendenze, flussi a runtime, thread, dati, build |
| [valutazione.md](valutazione.md) | L'architettura misurata contro i requisiti: punti di forza, debolezze, duplicazioni, inefficienze, rischi di prestazioni |
| [piano.md](piano.md) | Un piano di miglioramento a passi piccoli, ognuno con valore, rischio e dimensione, da approvare uno per uno |
| [player.md](player.md) | Il piano di riferimento del Player (tab Ascolto): decisioni, progetto della schermata, passi e prove sul telefono |

## Come si usano

1. **Una modifica parte da qui.** Una nuova funzione o un cambio di comportamento si scrive prima in `requisiti.md` (nuovo codice o codice esistente aggiornato), poi si fa la PR del codice che lo realizza.
2. **Un codice per requisito.** Il codice (`RF-ARM-05`, `RNF-PERF-02`…) si cita nei messaggi di commit, nelle PR e, dove serve, nel nome o nel commento del test che lo verifica. Così si sa sempre perché un pezzo di codice esiste.
3. **Una sola fonte.** README, guide utente, `llm.md` e scheda del Play Store descrivono l'app a persone diverse; quando dicono cose diverse, vale `requisiti.md` e gli altri vanno corretti.
4. **Le decisioni prese restano scritte.** Le scelte di prodotto già fatte (niente tema chiaro, niente donazioni, niente scelta dell'ottava…) sono elencate come vincoli, così nessuno le ripropone per sbaglio.

Stato dei requisiti: **✓** realizzato e coperto da test automatici; **◐** realizzato ma verificato solo a mano o in parte; **○** non realizzato o da verificare sul telefono; **?** da chiarire con Luigi.
