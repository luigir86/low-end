# Low End: user guide

*Italiano: [manuale-utente.md](manuale-utente.md).* What every control does is also written, with a code each, in [the requirements](specs/requisiti.md) (in Italian); where this guide says something else, the requirements are right.

Low End is a metronome, a piano harmony section and a tuner in one app. It was made by an amateur double bass player with the friends from the orchestra in mind, and it is meant for every musician. It is free, shows no ads, collects nothing and needs no internet. It always has the same dark look, bronze on ebony; there is no theme to choose.

## The three sections

The tabs at the bottom (on the left when the phone is sideways) are **Metronome**, **Harmony** and **Tuner**. The app opens on the section you left it on (on Harmony the first time).

- A **tab** only takes you to its section: it never starts or stops anything. **Each section starts and stops its own sound from the middle of its dial.**
- **Swipe** left or right to change section. With the phone turned sideways the tabs move to a column on the left and the settings gear stays top right: **swipe up or down** over the dial or the tabs (not over the rows on the right, which may scroll) to change section. It has to be a quick flick: a slow drag does nothing. The first time you turn the phone sideways a short hint says so.
- For rehearsals, **Lock the gestures** in the settings turns off the swipes between sections. The tabs still work.
- The first time you open the app a one-page **gesture guide** appears. It is also in *Settings → Gestures and shortcuts*.
- Under every dial there are three rows. Metronome and Harmony leave the first empty and use the second and third, so their controls sit lower, near the thumb; the tuner uses all three, with the cents bar first, next to the strobe, then the Instrument field and the reference A.

The volume is the phone's: use its volume keys.

## Metronome

- **Start and stop**: touch the ring or the number in the middle. The ring lights up beat by beat, with the first beat marked, and a short, dry click keeps the time, a little higher on the first beat.
- **Tempo**: from 30 to 250 BPM (in 7/8, where the tempo counts eighths, up to 400), with its Italian name (Largo, Andante, Allegro…) under the number. Touch the pencil to type it; touch **+** or **−** to move by one, or hold them: the tempo runs by one, faster and faster, then in steps of 5; or tap **TAP** (the coloured button, in the second row) in the rhythm you want.
- **The second row** has two fields. The first is the **time signature**, with "4/4" in it (touch it to choose): 1/1 (one click per bar, to keep a tempo without counting), 2/4, 3/4, 4/4, 5/4, 6/8, 7/8, 9/8 and 12/8. In 6/8, 9/8 and 12/8 the tempo counts dotted quarter notes (♩.), the way you conduct them; in 7/8 it counts eighths.
- **Subdivision** (what fills the beat): the second field opens a menu: a quarter note (the beat alone), two beamed eighths, three beamed triplets, four beamed sixteenths (softer clicks between the beats, to place the notes), and **swung eighths** and **swung sixteenths**, written straight and played long-short, as MuseScore plays "Swing" (the second note of the pair at 60%). With the click on 2 and 4 on, only beats 2 and 4 are subdivided. The piano of the Harmony tab does not follow: it stays straight. In the bars counted in eighths (6/8, 7/8, 9/8, 12/8) the beat is played alone and this field is dimmed.
- **Click on 2 and 4**: at the bottom of the time signature list. Beats 1 and 3 stay silent, as on a jazz hi-hat; the ring still shows them. It is heard in 2/4 and 4/4, and the box then reads "4/4 · 2 & 4".
- The tempo, the time signature, the subdivision and the click on 2 and 4 are kept when you close the app.
- Changing the time signature while it plays takes effect at once, without a gap. A new tempo from **+** and **−** shows at once and is heard once you lift your finger (after 0.3 s); with **TAP** the number follows your taps and the sound changes when you stop tapping. The beat carries on from where it is. A typed tempo changes at once, and so does a song, except while Harmony plays: then the metronome fades with it and changes together with it, on the bar line where its new chords come in, even if that is a bar later.

## Harmony

Twelve keys round a dial (by default in the circle of fifths; you can ask for semitones in Settings).

- **Touch a key** to play it on a real piano, in time with the metronome. **Touch it again**, or the middle of the dial, to stop; touching the middle while it is stopped plays the last note again. The harmony and the metronome can play together or alone.
- **Hold C♯ or F♯** to write them D♭ or G♭.
- **Mode** (the left half of the second row): **Chord** or **Progression**. The right half is the **Tempo** (♩ = 80): it is the metronome's own tempo, and touching it opens the same sheet as the metronome's pencil, so the sound changes once, when you press OK (the time signature stays in the Metronome). **Chord**: the note alone (the first entry of the menu, in the third row), or major, minor, dominant 7, dominant 7♭9, maj7, m7, half-diminished (m7♭5), diminished or sus4, built on the note. While it sounds, the middle of the dial writes the chord out note by note (A C♯ E, as in a progression); the note alone shows its frequency instead. **Progression**: one chord per bar, in the key of the note you touched, each four, eight or twelve bars long, as musical phrases are, so the loop always starts again where you expect it. The menu goes from the easiest to the richest, in three sections. **Pop and rock**: I–VI–IV–V (*The ’50s progression, like Stand by Me*; in Italy the "giro di Do"), I–V–VI–IV (*Like With or Without You*) and I–♭VII–♭VI–V (in a minor key, *Andalusian cadence, like Hit the Road Jack*). **Blues**: the twelve-bar blues (*Like Sweet Home Chicago*) and the minor blues (*Like Mr. P.C.*). **Jazz**: II–V–I with the I held for two bars (*Like Tune Up*), minor II–V–I (*Like Blue Bossa*), I–VI–II–V (*The Anatole, like I Got Rhythm*) and the eight-bar circle of fifths (*Like Autumn Leaves*). The blues and jazz ones are in sevenths, the others in triads. The first, I–VI–IV–V, is the one chosen until you pick another. While Harmony sounds, the dial fades the notes you do not hear; with a progression it fades the notes outside the key and writes the Roman numerals (II, V, I) small on the notes they stand on, and they stay put: read II, then go to V. Touch a numeral to see what it stands for. In the middle of the dial a row of dots shows the bars of the progression, the filled one being the chord sounding.
- **Changing while it plays**: a new song, progression, style, or key of a progression shows at once; the piano goes on, getting quieter, to the end of the bar, and the new one comes in on the next "one" (with the metronome playing, on its "one"; if less than a beat is left, at the end of the next bar). A new song played with the metronome going changes the metronome too on that same "one": until then the click keeps the old tempo, getting quieter with the piano, then both take up the new one together. Meanwhile the middle of the dial counts the beats to go. A note or a chord in Chord mode changes on the next beat.
- **Example songs**: the button left of the progression menu (in Progression mode); touching one sets the key, the progression, the tempo and the piano style in one go, as a preset. The jazz standards marked with footprints (Mr. P.C., Tune Up, I Got Rhythm, Autumn Leaves) play on the walking bass. I Got Rhythm sets the metronome to 2/4 (the others to 4/4): its chords change every half bar, so in 2/4 each still lasts one bar. Each says who made it known; they are listed in the same order and sections as the progression menu.
- **Style** (the button at the end of the third row, showing the picture of the style playing): the chord struck once a bar (a whole-note chord), on every beat (quarter-note chords), played as an arpeggio (rising quarter notes), or the **walking bass** (footprints: a jazz line on a plucked double bass, one note a beat, with the piano comping lightly above), all at the metronome's tempo and time signature; then the **held tone** (a wave: a steady tone instead of the piano). The root always sounds in octave 3 (A3 = 220 Hz), which the phone's own speaker plays well; the rest of the chord sits close together above it, as a pianist's hand plays it. At the bottom, **Legend and degrees**, which explains the colours of the dial and the numerals.
- What you choose here (the note, the mode, the chord, the progression or song, the style, the held tone, D♭ or G♭) is kept when you close the app, as the metronome's tempo is. The very first time, Harmony opens on **Progression**, I–VI–IV–V in A (A F♯m D E7, the key of Stand by Me), struck on every beat. Nothing starts by itself when the app opens.
- **Starting together**: if the metronome is already playing, the harmony comes in on the metronome's next bar line, and until then the middle of the dial counts the beats to go. The same goes for the metronome when you start it while the harmony plays.

## Tuner

- The tuner listens by itself when you open the section, if nothing else is playing (the first time Android asks for the **microphone**). Play a note: its name appears in the middle of the round strobe. The rings of the strobe turn anticlockwise when the note is **flat** and clockwise when it is **sharp**, faster the further off you are, and stand still when you are **in tune** (within 5 cents by default; the settings offer 2 or 10). Under the dial, in the first row, a scale shows the same thing by position: a needle moves along an axis marked every 5 cents, and the axis is coloured from 0 to the needle, so the longer the stretch the further off you are; it is green when in tune, yellow then red the further off you are, and a note that is only being held after the string stopped fades. The words *Flat*, *In tune* and *Sharp* and the number of cents are written too, with a tick when in tune, one arrow when close and two when far off, and a screen reader reads them out.
- **Listen / Pause**: touch the middle of the dial to start or pause it whenever you want; it stays paused until you touch it again.
- **If the metronome or the harmony is playing**, coming to the tuner stops nothing: the dial says *Listen* and *Listening pauses what is playing*. Touch the dial and they pause, so the microphone hears only your instrument, with a notice *Paused while you tune* and a **Resume** button that starts them again. Nothing resumes by itself when you leave the tuner.
- The reference A is in the third row: **−** and **+** move by 1 Hz, and the pencil takes a typed value or one of the standard ones (415, 432, 440, 442 Hz).
- It hears notes from 28 Hz up to 2800 Hz (the top of the violin and of the flute), and it names any note, with no string to choose first. With the bass chosen it listens up to 700 Hz only, so that voices do not get in the way.
- **Transposing instruments**: in *Settings*, choose B♭ (clarinet, trumpet, soprano and tenor sax), E♭ (alto and baritone sax) or F (horn), and the chromatic tuner names the **written** note, with the key beside "Chromatic" in the Instrument field and on the dial.
- The **Instrument** field always names what you are tuning. Its menu starts with Chromatic (any note), then guitar, violin, viola, cello, ukulele and bass with their open strings; with an instrument the tuner shows the number of the string. The last instrument stays remembered.
- The tuner stops listening when you leave the section, open the settings or send the app to the background.
- The sound is analysed on the phone and never recorded or sent anywhere.
- If you said no to the microphone, allow it in the phone settings under *Apps › Low End › Permissions*; the app shows a button that opens that page.

## Settings

The gear at the top opens the settings, in three groups:

| Group | Setting | Choices |
| --- | --- | --- |
| General | Language | Same as the phone, English, Italian, Spanish, French |
| General | Note names | Follow the language, Do Re Mi, C D E |
| General | Keep the screen on | While something plays or the tuner listens (on by default) |
| General | Lock the gestures | Turns off the swipes between sections |
| General | Octave numbers | Scientific (A4 = 440 Hz, a bass's low E is E1; the default) or Italian (La3 = 440 Hz); only the number changes |
| Tuner | Reference A | every hertz from 415 to 445, for the tuner and the harmony |
| Tuner | In tune within | ±2, ±5 or ±10 cents |
| Tuner | Transposing instrument | C (concert pitch), B♭, E♭, F |
| Harmony | Harmony circle | Circle of fifths, or in semitones |

At the bottom, **Gestures and shortcuts** shows the one-page guide again.

**Thanks** is for the Power Flower Orchestra of Fossano, who inspired this app and put it to the test; its button opens their Instagram page in the phone's browser. **About Low End** (at the bottom of the settings) shows the licence, the source-code link (also opened in the browser) and, under *View licences*, the licences of everything the app is built with, fonts and piano sounds included.

## Playing with the screen off

The metronome and the harmony keep playing when you lock the phone or switch to another app. A notification says what is playing, with buttons to pause or resume, and to stop. Android may ask permission to show notifications the first time.

If you **unplug the headphones** (or a Bluetooth headset goes away), the sound stops at once instead of carrying on from the phone's speaker, with a notice *Paused: headphones unplugged* and a **Resume** button. The notification stays, paused: its play button starts the sound again, as on a music player.

## Questions and problems

Write to ribaluigi@gmail.com or open an issue at https://github.com/luigir86/low-end/issues.
