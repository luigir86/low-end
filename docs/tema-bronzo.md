# Tema Bronzo per Low End

Stato: **storico**. Il codice Wood&Brass è stato tolto l'8 novembre 2026; il tema attivo è Ebony & Bronze ([temi a quattro colori](specs/tema-ebano-bronzo.md)). Vedi [varianti-tema](specs/varianti-tema.md) e [Anthracite & Red](tema-ffm.md). Sostituisce il tema "Orchestra" (un colore per scheda, chiaro e scuro), scartato da Luigi il 17 ottobre 2026. Le schermate del negozio sono in `store/graphics/phone/<lingua>/` (`flutter test test_screenshots/store_screenshots_test.dart --update-goldens`).

## 1. L'idea in una frase

Un solo colore per tutta l'app, il **bronzo miele** del leone dell'icona, su fondo **ebano**. Sempre scuro, senza scelta del tema. Tutto piatto.

## 2. Perché questa scelta

- **Un marchio solo.** Icona, grafica del negozio e app sono fatte dello stesso legno e bronzo su fondo scuro.
- **Più semplice.** Nessuna impostazione del tema, un solo insieme di colori da tenere leggibile.
- **Le schede si riconoscono dalla forma**: icona e nome nella barra, e tre cerchi diversi (battiti, circolo delle quinte, strobo).
- **Sempre scuro** riposa la vista sul palco e in sala prove. Il tema chiaro non è richiesto da WCAG 2.1 AA.

## 3. Palette

| Ruolo | Colore |
|---|---|
| Accento, bronzo | #D4A373 |
| Sfondo, ebano | #141312 (superfici #1C1B19, #262422, #312F2C) |
| Testo | #EFEDEA, attenuato #C9C5BF mescolato al 25% di bronzo |

Ogni altra tinta è il bronzo **mescolato nell'ebano** (`LowEndTheme.tint`): disco 10% (`LowEndColors.disc`), tasti e battiti spenti 26%, TAP e indicatore della scheda scelta 20%, note dell'accordo, battiti accesi dopo il primo  58% (`secondary`), bordi 75%. Il primo battito è il bronzo pieno; il primo battito è anche più largo. Mentre il metronomo suona, i battiti spenti si ritirano nel disco (`beatReceded`), un battito lasciato muto (click su 2 e 4) appena si accende (`beatSilent`) e i movimenti deboli di un gruppo del 6/8 sono più tenui (`beatWeak`): tre tinte con nome in `LowEndColors`, nessuna opacità scritta nelle schermate.

Il fondo di avvio Android/web usa il neutro comune `#181818`, indipendente dalla variante.

## 4. Verdetti dell'accordatore

Oggi i colori del verdetto colorano anche le bande dello strobo mentre una nota si sente: vedi [il tema attuale](tema-ffm.md) e RF-ACC-05.

Verde salvia #A4BF89 per una nota intonata, giallo paglia #DCCB79 per uno scarto lieve e rosso mattone #D98376 per uno scarto maggiore. Stanno solo sulla scritta del verdetto con la sua spunta o freccia (una freccia se vicino, due se lontano) e sulla lancetta della scala dei cent con il tratto d'asse da 0 alla lancetta; la nota resta bianca. Il giallo è lontano dal bronzo per tonalità (almeno 20 gradi, controllato da `test/theme_test.dart`), non solo per luminosità. Il verdetto è detto anche a parole e dal verso dello strobo: nessuna informazione affidata al solo colore.

## 5. Contrasto (WCAG)

`test/theme_test.dart` controlla: bronzo sullo sfondo almeno 4,5 : 1; bordi, battiti accesi e segmenti dello strobo sul disco almeno 3 : 1; testo su TAP e sulle note dell'accordo almeno 4,5 : 1; verdetti sul disco e sullo sfondo almeno 3 : 1.

## 6. Icona

Resta com'è: il leone in legno e bronzo su fondo scuro è già il tema.

## Migliorie comuni alle varianti

Lo strobo usa `strobeIdle` grigio a riposo, senza segnale o quando mantiene soltanto l’ultima nota. Durante una lettura attiva entrambi gli anelli usano i colori semantici del verdetto: verde entro la tolleranza, giallo fino a 15 cent e rosso oltre; la transizione dura `Durations.short4` e viene eliminata con movimento ridotto. I colori sono indipendenti da primary/secondary; parole e simboli del verdetto restano presenti. Le altre miscele Wood&Brass rimangono quelle descritte sopra. Il test di avvio verifica il neutro comune, non la superficie di ciascuna variante.
