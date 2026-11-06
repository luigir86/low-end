# Low End for assistants and language models

Low End is built "LLM first": everything a player can do on screen is also an **action** with a name, JSON arguments and a JSON answer, so an assistant can tune, start a piano chord or read the tuner just like a finger can.

The actions live in [`lib/actions/app_actions.dart`](../lib/actions/app_actions.dart). The screens use the same controllers, so the two can never drift apart. The full catalog, in the tool format used by MCP and by the Claude, Gemini and OpenAI APIs, is in [`llm-actions.json`](llm-actions.json). It is generated from the code by `exportActions()` and a test keeps it in sync: after changing an action, run `flutter test test/app_actions_test.dart --update-goldens` to rewrite it.

## How the app behaves

The rules below are a summary for assistants; the full behaviour, one code per rule, is in [the requirements](specs/requisiti.md) (in Italian), and where the two differ the requirements are right.

Four sections: **Metronome**, **Harmony** (Armonia), **Tuner** and **Player**. Harmony keeps its original names in the actions: `drone_play`, `drone_stop`, `drone_set` and the section id `drone`. Know these rules before calling anything:

- **Each sound has its own switch.** The metronome, Harmony and the tuner are started and stopped on their own, from their own section (the middle of the dial). The tabs and the swipes only move between sections.
- **A start action opens its section.** `metronome_start` shows the metronome, `drone_play` shows Harmony, `tuner_start` shows the tuner. Stop actions (`metronome_stop`, `drone_stop`, `tuner_stop`) and all the `*_set` actions stay on the current section.
- **Metronome and Harmony can play together**, in time with each other: Harmony follows the tempo and time signature of the metronome. There is one tempo for both: Harmony shows it in its Tempo field (beside Mode), and touching it opens the same sheet as the metronome's pencil; for an assistant it is `metronome_set` with `bpm`. If one is already playing when the other starts, the new one waits for the next bar line of the first and a countdown of beats is shown on screen. While Harmony plays the piano, `drone_set` with a new song, progression, style or key fades the old loop and brings the new one in on the next bar line (all the arguments of one call are one change); the answer comes back at once with the new state. The answer comes back at once with `playing: true`, even during the wait. Stopping during the wait cancels the start.
- **The tuner listens through the microphone, so it cannot share the room with the other two.** It listens only while its section is on screen (it stops by itself when another section or the settings page opens, or the app goes to the background).
  - `open_section` with `tuner` does *not* stop anything: the tuner starts listening only if neither the metronome nor Harmony is playing, and not if it was paused with `tuner_stop`.
  - `tuner_start` always listens. If the metronome or Harmony is playing, it is **paused** (not forgotten): the player sees a notice with a "Resume" button, as when touching the tuner's dial. Nothing resumes by itself, and no action resumes it either: call `metronome_start` / `drone_play` again (which also leaves the tuner).
  - `tuner_stop` pauses the tuner like the Pause button: it stays paused, also when coming back to the section, until `tuner_start` or a touch on the dial.
  - `metronome_start` and `drone_play` leave the tuner, so its microphone turns off.
- **The Player plays alone.** `player_play` plays the track open, and pauses the metronome and Harmony if they play (the player sees a notice with a "Resume" button); `metronome_start`, `drone_play` and `tuner_start` pause the Player, without a notice. Only the person can choose the file: `player_open` opens the phone's file chooser and the answer comes when it closes. In the web app the chooser needs a touch on the page, so `player_open` fails there, and a link may not start the sound without a touch.
- **Locking the gestures** ("Blocca i gesti" in the settings) only disables swiping between sections. Actions, including `open_section`, still work.
- Loudness follows the phone's media volume; there is no volume or balance action. The piano (walking bass included) is in equal temperament; the held tone (style `tone`) is in pure intervals, so that it does not beat and can be tuned against.
- The app is always dark (bronze theme); there is no theme setting.

## Actions

| Action | Arguments | What it does |
|---|---|---|
| `get_state` | none | Changes nothing. Returns the section on screen, the tuner (status `idle`, `starting`, `listening`, `permissionDenied` or `failed`; the last reading with target note, played note, `written` note for a transposing instrument, frequency, cents, `in_tune`), Harmony (`playing`, note, `frequency_hz`, voicing, chord, progression, style, `held_tone`, `flat`, `progression_step`, `audio_failed`), the metronome (`playing`, `bpm`, `time_signature`, `subdivision`, `backbeat`), the Player (`track`: its `name` and `duration_s`, or null; `playing`; `position_s`; `problem`: `unreadable` or `missing` when the last file could not be opened) and the settings (reference A, language, note names, transposition, `octave_numbering`, `tuner_instrument`, `in_tune_cents`, `circle_layout`, `keep_screen_on`, `lock_gestures`). With an instrument chosen, the target is its nearest string |
| `open_section` | `section`: `tuner`, `drone` (Harmony), `metronome` or `player` | Shows the section. Starts and stops nothing, except the tuner's microphone as described above |
| `tuner_start` | none | Opens the tuner and listens; pauses the metronome and Harmony if they play. The answer says `listening`, or `permissionDenied` / `failed` |
| `tuner_stop` | none | Pauses the tuner and turns the microphone off, until `tuner_start` |
| `player_open` | none | Shows the Player and opens the phone's file chooser; the person picks an audio file (MP3, M4A, WAV, FLAC) and the track opens, not playing. Fails in the web app |
| `player_play` | none | Shows the Player and plays the open track from where it is; pauses the metronome and Harmony if they play. Fails if no track is open |
| `player_pause` | none | Pauses the Player; the position stays |
| `player_seek` | `seconds` (required, 0 or more) | Moves to a point of the track; beyond the end means the end. Fails if no track is open |
| `drone_play` | all optional: `song`, `note`, `voicing`, `chord`, `progression`, `style`, `held_tone`, `flat` | Opens Harmony, applies the arguments and plays the piano if it was not playing (if it was, only the arguments change). See below for the values |
| `drone_stop` | none | Stops Harmony, also during the countdown |
| `drone_set` | same as `drone_play` | Changes Harmony without starting, stopping or changing section |
| `metronome_start` | all optional: `time_signature`, `bpm`, `subdivision`, `backbeat` | Opens the metronome, applies the arguments and starts it if it was not playing |
| `metronome_stop` | none | Stops the metronome, also during the countdown |
| `metronome_set` | `time_signature`, `bpm`, `subdivision`, `backbeat` (at least one) | Changes the metronome without starting, stopping or changing section. Remembered for the next launch |
| `set_reference_pitch` | `hz` (required) | A4: a whole number of hertz from 415 to 445, shared by tuner and Harmony, saved in the settings |
| `settings_set` | all optional: `language`, `note_names`, `octave_numbering`, `tuner_instrument`, `in_tune_cents`, `transposition`, `circle_layout`, `keep_screen_on`, `lock_gestures` | Everything on the settings page and the tuner's Instrument field: app `language` (`system`, `en`, `it`, `es`, `fr`), `note_names` (`auto`, `solfege`, `letters`; chord words follow them: English with letters, the app language with solfège, Italian when the app is in English), `octave_numbering` (`scientific`, `italian`), `tuner_instrument` (`chromatic`, `guitar`, `bass`, `ukulele`, `violin`, `viola`, `cello`), `in_tune_cents` (2, 5, 10), the `transposition` of the chromatic tuner (`c`, `bFlat`, `eFlat`, `f`), `circle_layout` (`fifths`, `chromatic`), `keep_screen_on` and `lock_gestures` (booleans). If one value is wrong none is applied |

Values:

- `note`: A, Bb, F#, or La, Sib, Fa#. Harmony always plays the root in octave 3 (A3 = 220 Hz with A4 at 440), so an octave number is ignored. It is the root, or the key of a progression.
- `voicing`: `root` (the note alone), `chord`, `progression`. Until the player chooses, Harmony is on `progression` (`oneSixFourFive` in A, style `beat`); after that it keeps what was last chosen. On screen there are two choices, Chord and Progression; the note alone is the first entry of the chord menu.
- `chord` (with voicing `chord`): `major`, `minor`, `dominant` (7), `dominantFlat9` (7♭9), `major7`, `minor7`, `halfDiminished` (m7b5), `diminished`, `sus4`.
- `progression` (with voicing `progression`), in the order of the menu, from the easiest: pop and rock `oneSixFourFive` (the "giro di Do", the default), `oneFiveSixFour`, `andalusian` (minor key); blues `blues`, `minorBlues` (minor key, its V is a 7♭9); jazz `twoFiveOne` (Dm7 G7 Cmaj7 A7 in C: the VI7 turns the loop around to the II), `minorTwoFiveOne` (minor key, Dm7♭5 G7♭9 Cm7 Cm7, the I held for two bars with no turnaround, as Blue Bossa ends: the V of a minor key has the ♭9 of its harmonic minor, and the walking bass walks that scale), `oneSixTwoFive` (Cmaj7 A7 Dm7 G7 in C, the "Anatole" of I Got Rhythm), `circleOfFifths` (8 bars, as in Autumn Leaves, with E7♭9 into Am7, ending on A7 in C). One chord per bar, at the metronome tempo; every progression lasts 4, 8 or 12 bars.
- `style`: `held` (struck once a bar), `beat` (on every beat), `arpeggio` (one note a beat), `walking` (a walking bass: a jazz line on a plucked double bass, one note a beat, in the manner of Paul Chambers, with the piano comping lightly above; a single chord is walked over four bars), `tone` (a steady tone instead of the piano, the fifth entry of the style menu, same as `held_tone` `true`). A `root` voicing is always sustained. On screen the style is the button at the end of the chord row, which shows the picture of the style playing; the legend is the last entry of its menu.
- `held_tone`: `true` for a steady tone instead of the piano struck again and again (as `style` `tone`), `false` for the piano in the style last chosen. Given with a `style`, the two must agree. In `get_state`, `style` is `tone` while the held tone plays.
- `flat`: `true` writes the note, if it is C# or F#, as Db or Gb (on the dial and in the chord names); the sound is the same.
- `song`: an example song (`Stand by Me`, `With or Without You`, `Hit the Road Jack`, `Sweet Home Chicago`, `Mr. P.C.`, `Tune Up`, `Blue Bossa`, `I Got Rhythm`, `Autumn Leaves`): is a preset: sets its key, progression, tempo (the metronome to 4/4; to 2/4 for `I Got Rhythm`, whose chords change every half bar) and piano style (the held tone gives way to the piano), as touching it on screen does: `walking` for `Mr. P.C.`, `Tune Up`, `I Got Rhythm` and `Autumn Leaves`, `arpeggio` for `Blue Bossa`, `held` for `With or Without You`, `beat` for the others. A `style` or `held_tone` given too wins.
- `time_signature`: `1/1`, `2/4`, `3/4`, `4/4`, `5/4`, `6/8`, `7/8`, `9/8`, `12/8`. Applied before `bpm`, which is checked against it.
- `bpm`: a whole number from 30 to 250, or to 400 in 7/8. It counts the beat of the current time signature (quarters in x/4, dotted quarters in 6/8, 9/8, 12/8, eighths in 7/8), so the same number can be refused after the signature changes.
- `subdivision`: `quarters`, `eighths`, `swing_eighths`, `triplets`, `sixteenths`, `swing_sixteenths`. Only heard in bars counted in quarters.
- `backbeat`: `true` clicks only on beats 2 and 4. Only heard in 2/4 and 4/4.

Arguments are checked before anything changes: a call with one wrong argument does nothing. Every answer is `{"ok": true, "state": {...}}` or `{"ok": false, "error": "..."}`, with an error message an assistant can read and fix. Unknown names and unknown parameters are errors.

## Calling them today: action links

On Android the app opens links of the form

```
lowend://action/<action>?<argument>=<value>&...
```

for example `lowend://action/drone_play?note=D&voicing=chord&chord=minor` or `lowend://action/tuner_start`. Any assistant, shortcut or automation app that can open a link can use them (on Android, for example, Tasker, a home-screen shortcut, or `adb shell am start -d "lowend://action/drone_stop"` to try it).

- Values are read as text and converted by the type in the catalog: numbers for `bpm` and `hz`, and `true`/`false` (also `1`/`0`, `yes`/`no`) for booleans.
- Write sharps as `%23` (`note=F%23`) or use `b` for flats and `♯`; a bare `#` starts a fragment and cuts the link.
- A link opens the app if it is closed. A link gives no answer to the caller: to read the result, use an integration that calls the actions and gets the JSON (see below).
- In the web app (see [web.md](web.md)) the same actions are the page address followed by `#/action/...`, for example `https://luigir86.github.io/low-end/#/action/drone_play?note=D`. A browser lets a page make sound only after a touch on it, so a sound started by a link may be heard only from the first touch.
- Links cannot change the saved settings (`set_reference_pitch`, `settings_set`): any web page can open a link, and a page must not be able to change your reference A. An assistant that calls the actions directly can.
- Links can only do what the buttons do, and the same rules apply: `tuner_start` brings the tuner to the front, listens and pauses the metronome and Harmony; the microphone never listens with the tuner off screen.

## Next steps

1. **Android App Functions** (Android 16 and later): publish the same actions to the system so Gemini and other assistants can call them and read the answer, through a small Kotlin layer that forwards to the Dart actions.
2. **MCP server** (optional, for desktop assistants such as Claude): only if someone needs it, since it would need a network connection, which the app avoids today.

## AI Act

Exposing actions to an assistant does not make Low End an AI system: the assistant (Gemini, Claude…) is the AI system and its provider carries the obligations. Low End would change category only if it shipped its own model, for example a built-in chatbot. Then it would have to tell users they are talking to an AI (Article 50), an obligation that applies to free and open-source software too.
