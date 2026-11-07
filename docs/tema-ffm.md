# Anthracite & Red — revisione estetica Low End

**Aggiornamento:** il [colore d’accento unico](specs/colore-accento.md) mantiene questa struttura con ottone predefinito e rosso FFM disponibile.

Specifica della proposta approvata il 7 novembre 2026. La gestione interna è descritta in [varianti-tema](specs/varianti-tema.md).

L'antracite domina; rosso FFM `#A6282C` su barra di navigazione, TAP e selezioni, con testo quasi bianco. Controlli inattivi e contorni sono grigi, leggibili senza riempire la schermata di rosso. Edwin, geometrie, dimensioni, disposizione, gesti, testi e comportamento dei quattro strumenti rimangono invariati. Icona e immagini del negozio restano separate da questa modifica.

| Ruolo | Trattamento |
| --- | --- |
| Fondo e superfici | Antracite neutro, con livelli di elevazione scuri |
| Barra e TAP | Rosso FFM, scritte quasi bianche (circa 6,07:1) |
| Nota selezionata | Rosso FFM con testo chiaro e contorno leggibile |
| Accento per testo e piccole icone | Variante rossa schiarita per almeno 4,5:1 sulle superfici |
| Battiti attivi e altre note dell'accordo | Rossi graduati, almeno 3:1 sul disco |
| Controlli inattivi | Grigio, contorni almeno 3:1 sul disco |
| Testo | Quasi bianco, secondario grigio chiaro |
| Strobo | Grigi neutri, indipendenti dall'accento in entrambi i temi |
| Verdetto accordatore | Verde acqua, giallo e rosso esistenti, con parole, spunta e frecce |

Il rosso istituzionale non ha contrasto sufficiente per testo minuto sull'antracite: non va sostituito indiscriminatamente al bronzo. Separare riempimento selezionato, accento leggibile, contorni e strobo. Il primo battito conserva la maggiore larghezza; il verdetto resta distinto per posizione, simboli e parole anche quando il tema è rosso.

## Implementazione e verifica

1. Introdurre due varianti e un'unica costante in `lib/app/theme.dart`, usando lo stesso costruttore Material e gli stessi componenti.
2. Conservare la palette Wood&Brass; aggiungere i ruoli semantici necessari in `LowEndColors`, inclusi riempimento della nota, testo su di esso e tre livelli dello strobo.
3. Applicare Anthracite & Red anche al Player, alle finestre, alle impostazioni e alla navigazione orizzontale. Nessun controllo nuovo.
4. Rendere comune e neutro il fondo pre-Flutter Android/web; non serve modificarlo tornando a Wood&Brass.
5. Verificare entrambe le palette: testo 4,5:1, contorni/battiti/strobo 3:1, etichette di note e TAP, barra/rail. Eseguire format, analyze, test e build web; rivedere screenshot di tutti gli strumenti e impostazioni, verticale/orizzontale e testo grande.
6. Attivare Anthracite & Red cambiando la sola costante in una PR successiva. Tornare indietro richiede la stessa modifica e ricompilazione.

Revisione della specifica: nessuna dipendenza nuova, nessuna scelta o preferenza persistita, nessuna modifica all'audio o al layout. Il requisito del contrasto prevale sull'uso del rosso esatto per piccoli segni informativi.
