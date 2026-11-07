# Varianti interne del tema

## Obiettivo

Rendere reversibile la revisione estetica con **Wood&Brass** e **Anthracite & Red**, selezionabili solo via codice. Nessuna scelta nelle impostazioni, azione per assistenti, preferenza salvata o configurazione per schermata.

## Contratto

- `LowEndTheme.variant` è la sola scelta dell'app; `LowEndTheme.dark` continua a essere il tema consumato dall'applicazione.
- `LowEndTheme.forVariant` costruisce entrambe le varianti per verifiche e anteprime. Nessuna condizione sul tema nelle schermate.
- Un solo costruttore mantiene tipografia Edwin, forme, misure, animazioni e componenti Material. `ColorScheme` e `LowEndColors` espongono ruoli, non nomi di temi.
- Wood&Brass conserva bronzo ed ebano e le miscele attuali; sono ammesse le migliorie comuni dello strobo neutro e del fondo di avvio neutro.
- I colori del verdetto restano comuni, con simboli e parole. Lo strobo non deriva da primary/secondary.
- Android e web usano un fondo di avvio neutro comune, controllato dai test; il rollback non richiede altri file di configurazione.

## Consegna

Tre PR in ordine: questa specifica documentale; gestione interna con entrambe le palette mantenendo Wood&Brass attivo; attivazione di Anthracite & Red tramite la costante e aggiornamento delle descrizioni del tema corrente. Non effettuare merge automatici.

## Criteri di accettazione

Contrasto e tipografia verificati per entrambe le varianti; copyWith/lerp preservano tutti i ruoli. Nessuna modifica alle impostazioni o agli strumenti audio. Test di accessibilità, regressioni e layout esistenti superati; screenshot di revisione e build web controllati. La verifica su telefono dei colori e delle barre di sistema resta da fare prima della pubblicazione sullo store.

## Punti di integrazione

`LowEndThemeVariant` e `LowEndTheme.forVariant` risiedono in `lib/app/theme.dart`. La ruota armonica e la sua legenda usano `activeFill`/`onActiveFill`; lo strobo usa i tre ruoli neutri. Il costruttore comune configura Material, barra e rail. Nessuna variante viene salvata in `AppSettings` o esposta nelle azioni.

## Selezione corrente e rollback

Anthracite & Red è il tema predefinito. Per tornare al precedente: impostare `LowEndTheme.variant = LowEndThemeVariant.woodAndBrass` in `lib/app/theme.dart` e ricompilare. Per ripristinare Anthracite & Red usare `LowEndThemeVariant.anthraciteAndRed`. Non cambiano preferenze, schermate o risorse di avvio.
