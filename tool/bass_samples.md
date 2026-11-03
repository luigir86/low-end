# Double bass recordings

The files are in `assets/bass/`, read only when the walking bass plays.

Nine notes (D#1 to D#3, a minor third apart) from **Meatbass** by Karoryfer
Lecolds: a 1958 Otto Rubner double bass, tuned in fifths (C-G-D-A) with
Spirocore strings, played and mapped by Drogomir Smolken and recorded by
Ludwik Zamenhof, plucked (`Samples/pizz`). Three of the four touches are kept
(`v2` the ghost notes, two takes; `v3` the normal touch and `v4` the firm one,
four takes each), so that the same note twice is never quite the same.
Released under CC0 1.0 (public domain dedication):
https://github.com/sfzinstruments/karoryfer.meatbass.

Each file is mono, 48 kHz 16-bit FLAC (from the 44.1 kHz 24-bit originals,
resampled with ffmpeg's soxr), cut to 2 s from the pluck with the last 0.5 s
faded out, at a common level (each take of a touch as loud as the others, the
touches keeping their difference), by `tool/prepare_bass.dart`, which also
measured the tuning of each take in `BassSamples.tuning`. About 3.5 MB in all.
