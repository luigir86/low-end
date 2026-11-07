# Varianti interne del tema

## Aggiornamento corrente — accento unico

La [specifica del colore d’accento](colore-accento.md) aggiorna questa proposta:
il tema corrente si chiama **Anthracite & Accent**, con ottone predefinito e
rosso FFM conservato. `LowEndBrand.accent` governa anche marchio e avvio;
`LowEndThemeVariant.anthraciteAndAccent` è la variante corrente. Le descrizioni
Anthracite & Red seguenti documentano la decisione iniziale.

## Obiettivo

Rendere reversibile la revisione estetica con **Wood&Brass** e **Anthracite & Red**, selezionabili solo via codice. Nessuna scelta nelle impostazioni, azione per assistenti, preferenza salvata o configurazione per schermata.

## Contratto

- `LowEndTheme.variant` è la sola scelta dell'app; `LowEndTheme.dark` continua a essere il tema consumato dall'applicazione.
- `LowEndTheme.forVariant` costruisce entrambe le varianti per verifiche e anteprime. Nessuna condizione sul tema nelle schermate.
- Un solo costruttore mantiene tipografia Edwin, forme, misure, animazioni e componenti Material. `ColorScheme` e `LowEndColors` espongono ruoli, non nomi di temi.
- Wood&Brass conserva bronzo ed ebano e le miscele attuali; sono ammesse le migliorie comuni dello strobo neutro e del marchio di avvio comune.
- I colori del verdetto sono ruoli semantici della variante, con simboli e parole. Anthracite & Red usa rosso TAP, salvia e ocra come definito in `rosso-coerente-cornice.md`; Wood&Brass conserva i precedenti. Lo strobo resta neutro.
- Android e web usano il marchio di avvio rosso comune (vedi `../icona-avvio.md`), controllato dai test; il rollback non richiede altri file di configurazione.

## Consegna

Tre PR in ordine: questa specifica documentale; gestione interna con entrambe le palette mantenendo Wood&Brass attivo; attivazione di Anthracite & Red tramite la costante e aggiornamento delle descrizioni del tema corrente. Non effettuare merge automatici.

## Criteri di accettazione

Contrasto e tipografia verificati per entrambe le varianti; copyWith/lerp preservano tutti i ruoli. Nessuna modifica alle impostazioni o agli strumenti audio. Test di accessibilità, regressioni e layout esistenti superati; screenshot di revisione e build web controllati. La verifica su telefono dei colori e delle barre di sistema resta da fare prima della pubblicazione sullo store.

## Punti di integrazione

`LowEndThemeVariant` e `LowEndTheme.forVariant` risiedono in `lib/app/theme.dart`. La ruota armonica e la sua legenda usano `activeFill`/`onActiveFill`; lo strobo usa i tre ruoli neutri. Il costruttore comune configura Material, barra e rail. Nessuna variante viene salvata in `AppSettings` o esposta nelle azioni.

## Selezione corrente e rollback

Anthracite & Accent è il tema predefinito. Per tornare al precedente: impostare `LowEndTheme.variant = LowEndThemeVariant.woodAndBrass` in `lib/app/theme.dart` e ricompilare. Per ripristinare il tema corrente usare `LowEndThemeVariant.anthraciteAndAccent`. Non cambiano preferenze, schermate o risorse di avvio.
