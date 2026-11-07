# Anthracite & Red: rosso coerente e cornice

Proposta approvata il 7 novembre 2026. Integra `varianti-tema.md` e la proposta estetica precedente.

## Aspetto approvato

- Rosso istituzionale già usato da TAP (`#A6282C`) come unico accento di azioni e selezioni: Choose a track, Listen, primo beat, passaggio A→B e bandierine del Player, pallino corrente delle progressioni, impostazioni attive e intestazioni.
- Beat secondari neutri: grigi distinguibili, senza rosa.
- Pulsanti +/− con riempimento grigio chiaro, simboli antracite e senza bordo. Restano disabilitati agli estremi. Edit e Choose Library come TAP: fondo rosso, simbolo chiaro.
- Fascia superiore sottile rossa, Settings chiaro allineato a destra, target di almeno 48 dp. Nessun nuovo titolo. Il contenuto parte sotto la fascia, senza sovrapposizioni.
- Revisione approvata della navigazione inferiore: fondo quasi bianco `#ECECE9`, icona e nome selezionati nel rosso TAP con nome in grassetto; altre icone e nomi antracite `#3D3D3D`. Nessuna pillola selezionata. Linea continua rossa di 2 dp alla base, sotto l’area di sicurezza. Il pallino delle sezioni che suonano resta rosso TAP, anche su tab non selezionate; nessun pallino per l’accordatore. Fascia superiore e rail landscape restano rossi.
- Tutti i centri dei quadranti e il fondo dei controlli restano scuri. Il pannello grigio chiarissimo e i centri chiari sono stati esplicitamente esclusi.
- Ghiera esterna sottile: soltanto tacche, senza freccia né +/−. Nessuna modifica a gesti, tastiera, semantica o pulsanti +/− separati.
- Accordatore: rosso TAP, verde salvia `#8FA891`, giallo ocra `#C5A35A`; strobo neutro. Le soglie, le parole e i simboli di intonazione restano invariati.

## Integrazione

Conservare la scelta centralizzata della variante, senza impostazione utente. Separare l'accento di riempimento dai colori dei testi leggibili: non sostituire il rosa con rosso scuro indiscriminatamente in tutto Material. I piccoli testi devono mantenere contrasto; usare testo chiaro su riempimento rosso per selezioni e intestazioni, contorni chiari per indicatori rossi e testo neutro per il verdetto dell'accordatore. Il colore del verdetto resta nel simbolo e nella rappresentazione grafica.

Estendere i ruoli semantici del tema per i pulsanti di regolazione. Applicare gli stili nei componenti condivisi. Gli altri pulsanti di trasporto restano distinguibili dai +/− numerici. La variante Wood&Brass conserva la propria palette e i pulsanti precedenti; la pulizia della ghiera è comune.

## Verifica

Verificare contrasto del testo e segnali ridondanti per gli indicatori rossi, entrambe le varianti, focus e stati disabilitati. Eseguire formattazione, analisi, test esistenti (inclusi accessibilità, ghiera, layout e navigazione), build web Wasm e screenshot verticali/orizzontali con testo ingrandito. Documentare ogni verifica non disponibile. Su schermi bassi il contenuto può scorrere come già previsto; non introdurre sovrapposizioni o un nuovo ridimensionamento indipendente per sezione.

## Consegna

PR documentale, seguita da PR di implementazione basata su questa specifica. Nessun merge automatico.
