# Privacy

*Italiano: vedi sotto.*

Low End collects no personal data. It has no server, no account and no internet permission: the app cannot send anything anywhere (see [docs/offline.md](docs/offline.md)).

- **Microphone.** The app uses the microphone in two places only, and Android asks your permission the first time; you can take it back in the phone settings at any time.
  - **Tuner.** It listens only while the tuner is on screen (you can also pause it), and stops as soon as you leave the tuner or the app goes to the background. The sound is analysed on the phone to find the note and is never recorded, saved or sent anywhere.
  - **Recording in the Player.** Only when you tap REC, until you tap Stop (leaving the Player or the app stops it too).
- **Player recordings.** A take is kept in the app's private temporary storage on the phone, where no other app can read it, and is deleted when you delete it or, at the latest, the next time the app starts. It leaves the app only if you choose: **Save** writes a copy where you pick, and **Share** hands a copy to the app you choose; that copy stays in the app's temporary storage for up to a day so the other app can read it. The app never uploads a take.
- **Your tracks.** The Player plays audio files you choose with the phone's file chooser. The app reads only those files, only to play them, and remembers which one you chose so it can reopen it; it keeps only the outline of the waveform in its temporary storage, to draw it faster next time. Nothing is copied or sent.
- **Notification.** To keep the metronome or the harmony playing with the screen off, the app shows a notification that says what is playing. It holds no personal data and goes nowhere.
- **Settings.** Your language, note names, reference A, the tempo and time signature of the metronome and similar choices are kept on the phone only, in the app's own storage, and removed with the app. Android's cloud backup is switched off for the app.
- **No network.** The app does not connect to the internet: no accounts, no analytics, no ads, no crash reporting, no fonts or files downloaded.
- **Links you tap.** The settings and About have two links, to the Power Flower Orchestra's Instagram page and to the source code on GitHub. They open the phone's browser only when you tap them; the app itself sends nothing.
- **Action links.** Other apps can open `lowend://action/...` links to press the app's buttons (see [docs/llm.md](docs/llm.md)). They can start a sound or show the tuner, but they cannot read your data or the microphone, and nothing leaves the phone.
- **Web app.** The version for iPhone and browsers ([docs/web.md](docs/web.md)) is downloaded from GitHub Pages, which, like any website, receives your IP address and browser details when the files are fetched ([GitHub's privacy statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement)). After that, the tuner and recorder use the microphone locally. Settings stay in the browser. Audio sharing requires an explicit choice.

If this ever changes (for example a future, optional online service), this page and the app will say so before anything is sent.

Questions: open an issue at https://github.com/luigir86/low-end/issues.

---

# Privacy (italiano)

Low End non raccoglie alcun dato personale. Non ha un server, non ha account e non ha il permesso di usare internet: l'app non può inviare nulla da nessuna parte (vedi [docs/offline.md](docs/offline.md)).

- **Microfono.** L'app usa il microfono solo in due punti, e Android chiede il permesso la prima volta; puoi revocarlo in qualsiasi momento dalle impostazioni del telefono.
  - **Accordatore.** Ascolta solo mentre l'accordatore è sullo schermo (puoi anche metterlo in pausa) e si ferma appena esci dall'accordatore o l'app va in secondo piano. Il suono è analizzato sul telefono per trovare la nota e non viene mai registrato, salvato o inviato.
  - **Registrazione in Ascolto.** Solo quando tocchi REC, fino a Stop (anche uscire dall'Ascolto o dall'app la ferma).
- **Registrazioni in Ascolto.** Una ripresa resta nella memoria temporanea privata dell'app sul telefono, che nessun'altra app può leggere, e viene cancellata quando la elimini o, al più tardi, al successivo avvio dell'app. Esce dall'app solo se lo scegli tu: **Salva** ne scrive una copia dove decidi e **Condividi** ne passa una copia all'app che scegli; quella copia resta nella memoria temporanea dell'app al massimo per un giorno, perché l'altra app possa leggerla. L'app non carica mai una ripresa da nessuna parte.
- **I tuoi brani.** Ascolto suona i file audio che scegli con il selettore di file del telefono. L'app legge solo quei file, solo per suonarli, e ricorda quale hai scelto per poterlo riaprire; tiene solo il profilo della forma d'onda nella sua memoria temporanea, per disegnarlo più in fretta la volta dopo. Nulla viene copiato o inviato.
- **Notifica.** Per far continuare metronomo e armonia con lo schermo spento, l'app mostra una notifica che dice cosa sta suonando. Non contiene dati personali e non va da nessuna parte.
- **Impostazioni.** Lingua, nomi delle note, La di riferimento, tempo e misura del metronomo e le altre scelte restano solo sul telefono, nella memoria dell'app, e spariscono con la disinstallazione. Il backup su cloud di Android è disattivato per l'app.
- **Nessuna rete.** L'app non si collega a internet: niente account, analisi, pubblicità, segnalazioni di errore, né font o file scaricati.
- **Link che tocchi.** Le impostazioni e le informazioni sull'app hanno due link, alla pagina Instagram della Power Flower Orchestra e al codice sorgente su GitHub. Aprono il browser del telefono solo se li tocchi; l'app stessa non invia nulla.
- **Link di azione.** Altre app possono aprire link `lowend://action/...` per premere i pulsanti dell'app (vedi [docs/llm.md](docs/llm.md)). Possono avviare un suono o mostrare l'accordatore, ma non leggono i tuoi dati né il microfono, e nulla esce dal telefono.
- **Web app.** La versione per iPhone e browser ([docs/web.md](docs/web.md)) si scarica da GitHub Pages, che, come ogni sito, riceve il tuo indirizzo IP e i dati del browser quando i file vengono scaricati ([informativa privacy di GitHub](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement)). In seguito accordatore e registrazione usano il microfono sul dispositivo. Le impostazioni restano nel browser. La condivisione avviene su tua richiesta.

Se questo cambiasse (per esempio con un futuro servizio online facoltativo), questa pagina e l'app lo diranno prima che venga inviato qualcosa.

Domande: apri una segnalazione su https://github.com/luigir86/low-end/issues.
