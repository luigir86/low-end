# Colore d’accento unico

**Superato l'8 novembre 2026:** vedi [temi a quattro colori](tema-ebano-ottone.md).

Decisione di Luigi del 7 novembre 2026, successiva alla revisione Anthracite & Red.

## Scelta e superfici

`LowEndBrand.accent` in `lib/app/brand.dart` è l’unica scelta cromatica del tema
corrente, **Anthracite & Accent**. Il colore predefinito è `ffmRed` (`#A6282C`). Per provare l’ottone
(`#B69A58`), assegnare `brass` a `LowEndBrand.accent`.

L’accento governa riempimenti attivi, TAP, selezioni, battiti, Player, cornice,
indicatori di riproduzione, navigazione, icona e avvio Android/web/Flutter.
Antracite, grigi, tipografia, geometrie e comportamenti restano quelli attuali.
I colori funzionali del verdetto e dello strobo dell’accordatore restano separati.
Il leone resta avorio, con disegno, inclinazione e zone sicure approvati.

Il testo sui riempimenti sceglie l’inchiostro chiaro/scuro più leggibile. Il testo
selezionato della navigazione chiara deriva dall’accento, scurito quanto serve
per 4,5:1; il riempimento conserva il colore scelto esatto. L’indicatore della
rail deriva dall’accento e mantiene il contrasto con lo stesso inchiostro.
Non sono introdotte preferenze utente o configurazioni per schermata.

## Rigenerazione e prove

Dopo la modifica eseguire `flutter test tool/make_icons_test.dart` prima di
`flutter run`, build o test locali. Il generatore aggiorna PNG Android/PWA/store,
fondi XML Android, fondo del caricatore HTML e `background_color` del manifest.
`theme_color` del browser rimane antracite. Il riferimento originale del leone
resta invariato; non serve ridisegnarlo per provare un colore.

CI esegue la generazione prima di test, build Android e web; anche la
pubblicazione Pages la esegue. Le future PR di solo colore possono quindi
modificare una sola costante. Le risorse generate restano versionate come base
per le build locali: dopo un pull che cambia il colore vanno rigenerate.
L’icona già installata cambia con una nuova build/installazione; le cache PWA
e del launcher possono richiedere un aggiornamento prima di mostrarla.

`LowEndTheme.withAccent` permette prove di palette senza alterare la costante.
I test verificano le sei proposte (rosso, ottone, rame, petrolio, blu acciaio e
prugna), contrasto dei comandi e della navigazione, neutrali invariati,
coerenza dei fondi nativi/web e maschere del marchio.

Wood&Brass rimane disponibile come rollback storico indipendente: non è il
nuovo tema ottone, che mantiene i neutrali del tema antracite.
