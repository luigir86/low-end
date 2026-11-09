# Temi a quattro colori: Rosso e Ebony & Bronze

Decisione di Luigi dell'8 novembre 2026 (proposta "Simula tema colori"). L'accento proposto era l'ottone `#B8924E`; dopo il confronto delle anteprime Luigi ha scelto il bronzo originale dell'app `#D4A373`, più caldo (anteprime in `preview/ebony-brass/confronto_accenti.png` dei file di progetto). Sostituisce
la scelta del solo accento ([colore-accento](colore-accento.md)) e le varianti
interne Wood&Brass / Anthracite ([varianti-tema](varianti-tema.md)): il vecchio
codice Wood&Brass è stato tolto.

## Quattro colori

Un tema è un `BrandPalette` in `lib/app/brand.dart`, fatto di quattro colori:

| Ruolo | Rosso (7 novembre) | Ebony & Bronze (attivo) |
| --- | --- | --- |
| `brand`: fondo di icona e avvio | Rosso FFM `#A6282C` | Ebano `#141312` |
| `accent`: TAP, selezioni, primo battito, rail | Rosso FFM `#A6282C` | Bronzo `#D4A373` |
| `dark`: fondo delle schermate | Antracite `#242424` | Ebano `#141312` |
| `light`: scheda aperta della barra in basso, pulsanti +/− e ghiera (in versione calda, vedi sotto), leone | Grigio chiaro `#ECECE9` | Avorio `#F1E8D5` |

Il leone usa il colore chiaro. Il tema rosso conserva il suo leone avorio
`#FFF5E3` con il campo facoltativo `mark` (il quinto colore, solo dove serve).
Allo stesso modo il campo facoltativo `step` dà a +/− e alla ghiera un colore
proprio: Ebony & Bronze usa l'avorio caldo `#EDDEC6` (avorio con il 15% di
bronzo, 9 novembre 2026); senza `step` è `light` all'89% verso `dark`.

`LowEndBrand.palette` è l'unico punto di scelta; nessuna impostazione per chi usa
l'app. `LowEndTheme.forPalette` ricava tutto il resto in `lib/app/theme.dart`:
superfici, bordi, tasti spenti e testo attenuato sono miscele di `dark` e
`light` (grigi caldi con l'ebano, neutri con l'antracite); il disco è `dark`
scurito dell'11%; il fondo prima di Flutter (`startup`) è `dark` scurito del
33%. Testo sui riempimenti: l'inchiostro chiaro o scuro più leggibile, quindi
ebano sul bronzo. Le schede stanno sul fondo (ebano), sotto una sola riga sottile
dell'accento che sfuma verso il fondo per 12 dp (`NavigationEdge`, finisce
prima delle icone); niente riga sotto le schede né fascia dell'accento in alto,
dove il fondo arriva fino alla barra di stato (9 novembre 2026). Solo icone: quella aperta è avorio con l'icona piena, le altre grigio caldo
(più di 4,5:1); il pallino di una sezione che suona è dell'accento, come TAP.
Vale per la barra in basso e per il rail in orizzontale (dal 9 novembre 2026,
dopo una barra avorio con pillola).

Calore (9 novembre 2026): con il campo facoltativo `tint` i grigi si mescolano
da `dark` verso un colore proprio invece che verso `light`; Ebony & Bronze usa
la sabbia `#E3C9A6` (avorio con il 40% di bronzo), così bordi, riempimenti
scuri, testo attenuato e strobo a riposo sembrano legno e sabbia, non grigio.
Il testo è un bianco avorio `#F2E9DA`, l'errore e il REC sono terracotta
`#E8735F`, la forma d'onda del Player ha l'avorio caldo di +/−. Lo strobo a
riposo resta molto meno saturo dei verdetti.

Restano uguali in ogni tema: i colori del verdetto dell'accordatore (salvia,
paglia, mattone), il testo avorio, Edwin,
forme, misure e disposizione.

## Contrasti (Ebony & Bronze)

La ghiera del metronomo ha l'avorio caldo dei pulsanti +/− (`stepFill`,
`#EDDEC6`): ghiera e +/− cambiano entrambi il tempo; tacche e segni ebano 14:1.

Testo ebano sul bronzo 7,5:1; avorio su ebano 15:1; bronzo sul disco 8,3:1; schede
non scelte sull'ebano circa 6:1; verdetti sull'ebano tra 6,6:1 e 11:1.
`test/theme_test.dart` controlla entrambi i temi.

## Icona e avvio

`flutter test tool/make_icons_test.dart` rigenera icone Android/PWA/store,
fondi XML Android, fondo e `theme-color` della pagina web e `background_color`
/ `theme_color` del manifest dal tema scelto. Il disegno del leone è quello
approvato, cambia solo il colore. Con il tema rosso il generatore ricrea
esattamente i file del 7 novembre. CI esegue il generatore prima di test e build.

## Tornare al rosso

In `lib/app/brand.dart` impostare `static const palette = red;`, eseguire
`flutter test tool/make_icons_test.dart` e
`flutter test test_screenshots/store_screenshots_test.dart --update-goldens`,
poi ricompilare.
