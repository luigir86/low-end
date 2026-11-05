# Piano di miglioramento

Proposta del 4 novembre 2026, da approvare **un passo alla volta**: nessun passo cambia il codice senza il via di Luigi. L'ordine segue due regole: prima si misura (altrimenti non si sa se un passo migliora), poi si toglie la causa dei blocchi dell'Armonia, solo dopo si riordina. Ogni passo è una PR a sé, piccola, con i test che già ci sono più quelli nuovi, e cita i codici di [requisiti.md](requisiti.md) e [valutazione.md](valutazione.md).

Dimensione: **S** mezza giornata di lavoro · **M** una o due giornate · **L** più giornate.

## Passi

| Passo | Che cosa | Risolve | Valore | Rischio | Dim. | Dipende da |
| --- | --- | --- | --- | --- | --- | --- |
| 0 | ✓ (4/11) **Decidere le questioni aperte** di `requisiti.md` §5, soprattutto i numeri obiettivo (tocco→suono, memoria, blocco massimo dello schermo) e l'intonazione del suono tenuto | requisiti senza misura | alto | nessuno | — | — |
| 1 | ✓ (4/11, Android; web da fare) **Misure di partenza**: sul S20 FE (Remote Control + DevTools) avvio, tocco→suono per stile, memoria di picco con un walking di 12 battute, blocchi dello schermo cambiando brano, stile e tempo; nel banco web gli stessi scenari, più "tieni premuto + con il walking". Un registro dei tempi solo in debug, nessun cambiamento visibile | P1–P7, RNF senza numero | alto | basso | M | 0 |
| 2 | ✓ (4/11) **Unire la PR #98** così com'è, come tampone per il cambio di brano | RF-ARM-09, P1 sui brani | alto | basso | — | — |
| 3 | ✓ (4–5/11: transizioni RF-ARM-15, tempo RF-MET-08, più cambi insieme = un solo loop, e un cambio uguale a ciò che suona non rifà il loop; il 5/11 Luigi ha scelto di non riscrivere il controller su un valore unico, che non cambierebbe ciò che si sente) **Un solo stato desiderato per l'Armonia**: un valore immutabile (la scelta del musicista, il tempo, il metro, suona sì o no) e un unico riconciliatore che lo confronta con ciò che suona e rifà il loop al massimo una volta. I setter di oggi restano come scorciatoie; `applySong`, `drone_play` con più argomenti e il ripristino passano per un'unica modifica; un cambio di tempo aspetta che il dito si fermi (RF-MET-08) e un cambio di brano lascia decadere il vecchio ed entra sul battito (RF-ARM-15). Sostituisce `applyAll` della #98 | D1, P2, RF-ARM-09, RF-ARM-15, RF-MET-08 | molto alto | medio | M–L | 1, 2 |
| 4 | **Nel web nessun mix intero sul thread dello schermo**: ogni mix a fette (non solo il pre-mix), la coda calcolata a fette insieme al loop o al momento in poche fette, buffer in `Float32` invece di `Float64` (metà memoria; da confermare all'ascolto e con `same_sound_test`) | P1, P4, P5 | alto | medio | M | 3 |
| 5 | **Su Android un isolate che resta vivo** e tiene i campioni: niente copia a ogni mix; dentro anche la coda e la conversione FLAC → Int16 | P3, P4, P7 | medio–alto | medio | M | 1, 4 |
| 6 | **Un solo meccanismo di coda e un solo allineamento luce-suono** per metronomo, Armonia (e, dove serve, accordatore): una piccola classe "esegui l'ultima richiesta" e una "orologio del suono" con latenza e conto alla rovescia | DU1, DU2 | medio | basso | S–M | 3 |
| 7 | **Riordino dei moduli** senza cambiare comportamento né nomi delle azioni: `features/harmony/` al posto di `features/tuner/drone/`, `BarClock` in un modulo comune, i brani in un modulo che coordina le due sezioni, i nomi di accordi e giri in un file di formattazione, una sola costante per la frequenza di campionamento e una funzione per la lunghezza della battuta | D4, DU3, DU4 | medio | basso | M | 3, 6 |
| 8 | **Regole tra sezioni fuori da `LowEndApp`**: pausa per l'accordatore, cuffie, interruzioni e notifica in due classi semplici, provate da test unitari senza montare l'app | D3, RF-ACC-08, RF-BG-01/02 | medio | basso | S–M | 7 |
| 9 | **Impostazioni dell'Armonia in una chiave sola** (JSON della scelta, lo stesso formato dei brani) con lettura delle chiavi vecchie una volta | D4, DU6 | basso–medio | basso | S | 3 |
| 10 | **Test del percorso audio**: un'interfaccia sottile sulle chiamate a SoLoud usate da `BarLoopPlayer` e `LoopTransport`, un motore finto con il suo orologio, e test di sostituzione dei loop, ingressi sulla stanghetta, code e dissolvenze | D5, RNF-TEST-02, RF-SYNC-03 | medio | basso | M | 7 |
| 11 | **Documenti a fonte unica**: guide, README, `llm.md` e scheda dello store rimandano ai requisiti per i comportamenti; aggiornare `docs/architecture.md` | DU7, §6 della valutazione | medio | nessuno | S | 0 |
| 12 | **Latenza misurata**: video al rallentatore della luce con il click su altoparlante, cuffia e Bluetooth; correggere le costanti; provare il buffer a 1024 frame su Android | P9, P10, RNF-LAT-03 | medio | basso | S–M | 1 |

## Percorso consigliato

1. **Fatti**: passo 0 (le decisioni del 4/11, in `requisiti.md`) e passo 2 (la #98 è in `main`).
2. **Poi** il passo 1, perché senza numeri i passi 3–5 non si possono giudicare.
3. **Il cuore**: passi 3 e 4. Sono loro che tolgono la classe di problemi da cui sono nate #97 e #98; dopo, cambiare stile, tonalità, tempo o brano mentre si suona costa al massimo un mix e non blocca lo schermo.
4. **Pulizia**, in qualunque ordine e quando c'è tempo: 5–11, ognuno indipendente e a basso rischio.

Una nuova funzione dell'Armonia (altri giri, altri stili, preset salvati dal musicista) conviene farla **dopo il passo 3**: con lo stato desiderato basta aggiungere un campo al valore, invece di un setter con le sue reazioni.

## Che cosa non propongo

- **Riscrivere il motore in C++/Oboe**: la precisione del tempo c'è già; i problemi sono a monte, nel modo in cui si decide quando mixare.
- **Un pacchetto di gestione dello stato** (Riverpod, Bloc): va contro la scelta di restare leggeri e non risolve D1, che è un problema di forma dello stato, non di libreria.
- **Il mix in un Web Worker** nel web: sarebbe la soluzione definitiva per P1, ma con Flutter web costa molto (un secondo programma compilato a parte). Da rivalutare solo se dopo il passo 4 i numeri non bastano.
- **Mix in tempo reale** (riverbero o pianoforte suonati dal motore invece che pre-mixati): cambia il suono e il modello del tempo; sconsigliato anche nell'analisi delle prestazioni web del 4/11.
