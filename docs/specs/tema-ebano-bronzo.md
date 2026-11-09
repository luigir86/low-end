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
| `light`: barra in basso, pulsanti +/−, ghiera del metronomo, leone | Grigio chiaro `#ECECE9` | Avorio `#F1E8D5` |

Il leone usa il colore chiaro. Il tema rosso conserva il suo leone avorio
`#FFF5E3` con il campo facoltativo `mark` (il quinto colore, solo dove serve).

`LowEndBrand.palette` è l'unico punto di scelta; nessuna impostazione per chi usa
l'app. `LowEndTheme.forPalette` ricava tutto il resto in `lib/app/theme.dart`:
superfici, bordi, tasti spenti e testo attenuato sono miscele di `dark` e
`light` (grigi caldi con l'ebano, neutri con l'antracite); il disco è `dark`
scurito dell'11%; il fondo prima di Flutter (`startup`) è `dark` scurito del
33%. Testo sui riempimenti: l'inchiostro chiaro o scuro più leggibile, quindi
ebano sul bronzo. La scheda scelta sulla barra chiara ha la pillola di Material 3, chiara
miscela della barra e dell'accento, con icona piena e nome in grassetto in
ebano (dal 9 novembre 2026; prima l'accento scurito senza pillola).

Restano uguali in ogni tema: i colori del verdetto dell'accordatore (salvia,
paglia, mattone), lo strobo grigio a riposo, il testo quasi bianco, Edwin,
forme, misure e disposizione.

## Contrasti (Ebony & Bronze)

La ghiera del metronomo ha l'avorio dei pulsanti +/− (`stepFill`, `light` all'89%):
ghiera e +/− cambiano entrambi il tempo; tacche ebano sulla ghiera 12,2:1.

Testo ebano sul bronzo 7,5:1; avorio su ebano 15:1; bronzo sul disco 8,3:1; scheda
scelta sull'avorio almeno 4,5:1; verdetti sull'ebano tra 6,6:1 e 11:1.
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
