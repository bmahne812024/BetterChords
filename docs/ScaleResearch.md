# Scale research and voicing choices

Research date: October 21, 2026.

The library now has 97 chord/scale choices across 24 chord formulas (29 distinct scales). This pass appended 73 choices. All prior chord formulas, RH extensions, scale names, interval values, degrees, and ordering were preserved.

These are choices for improvisation, not a promise that every note works as a sustained chord tone. The progression and melody still determine the best choice. Pentatonic scales can omit guide tones; bebop and blues scales deliberately include passing tones. The new assignments below are an application of the cited theory to the app's exact LH voicings.

## Choices added

The app keeps the original choices first. An em dash means the chord already had the appropriate choices for its exact voicing.

| JSON chord | Scales appended |
| --- | --- |
| `maj` | Major Pentatonic, Major Bebop, Harmonic Major, Major Blues |
| `min` | Melodic Minor, Harmonic Minor, Minor Pentatonic, Minor Blues, Dorian #4 |
| `dim` | Whole-Half Diminished, Locrian, Locrian Natural 2 |
| `aug` | Whole Tone, Lydian Augmented, Augmented |
| `sus2` | Suspended Pentatonic, Major Pentatonic, Major, dominant, Dorian |
| `sus4` | Suspended Pentatonic, dominant, Dorian, Natural Minor |
| `6` | Major, Lydian, Major Pentatonic, Major Bebop, Major Blues |
| `min6` | Dorian, Melodic Minor, Dorian #4, Melodic Minor Bebop |
| `7` | dominant, Lydian dominant, dominant bebop, half-whole diminished, Major Pentatonic, Minor Blues |
| `maj7` | Major, Lydian, Major Bebop, Major Pentatonic |
| `min7` | Dorian, Natural Minor, Phrygian, Minor Pentatonic, Minor Blues, Dorian Bebop, Dorian #4 |
| `minmaj7` | Melodic Minor Bebop |
| `min7b5` | Locrian Natural 2, Locrian, Locrian Natural 6 |
| `dim7` | Whole-Half Diminished |
| `9` | Mixolydian b6, Major Pentatonic |
| `13` | — |
| `13(9)` | — |
| `9(#11, #5)` | — |
| `9(#5)` | — |
| `9(13)` | — |
| `maj9` | Major, Lydian, Major Bebop, Major Pentatonic |
| `min6/9` | Dorian, Melodic Minor, Dorian #4, Melodic Minor Bebop |
| `minmaj9` | Harmonic Minor, Melodic Minor Bebop |
| `min9` | Dorian, Natural Minor, Minor Pentatonic, Minor Blues, Dorian Bebop, Dorian #4 |

## Research basis

- [Gary Burton / Berklee Online: Jazz Scales You Need to Know](https://online.berklee.edu/takenote/jazz-improvisation-10-scales/) supports Ionian/Major and Lydian for major harmony, the modal palette, and the distinction between diminished and dominant applications.
- [University of Puget Sound: How to Determine Chord-Scale Relationships](https://musictheory.pugetsound.edu/mt21c/HowToDetermineChord-ScaleRelationships.html) supplies the method: account for the chord's extensions and alterations when choosing the surrounding scale. This is why the app's written ninths and thirteenths matter, rather than just its menu family.
- [Jamey Aebersold: Jazz Handbook, Scale Syllabus, printed page 14](https://www.jazzbooks.com/mm5/download/FQBK-handbook.pdf#page=15) is a cross-check for major, pentatonic, harmonic-major, dominant, half-diminished, suspended, and diminished families. Its alternatives have different amounts of tension; their inclusion does not make them interchangeable in every progression.
- [The Jazz Piano Site: Melodic Minor Modes](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-scales/melodic-minor-modes/) supports Lydian Augmented for augmented-major harmony, Lydian dominant, and Locrian Natural 2 for half-diminished harmony. Jazz melodic minor uses the ascending form in both directions.
- [The Jazz Piano Site: Minor Scales](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-scales/minor-scales/) gives the natural/melodic/harmonic minor, Dorian, Phrygian, Dorian #4, Locrian, and Locrian Natural 6 formulas and related chord families.
- [The Jazz Piano Site: Pentatonic Scale](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-scales/pentatonic-scale/) supports major/minor pentatonics and the C–D–F–G–B♭ suspended pentatonic (the notes of B♭ major pentatonic, reordered from C). Applying that same suspended palette to sus2 is an inference: it contains the complete sus2 triad while avoiding a third.
- [The Jazz Piano Site: Bebop Scales](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-scales/bebop-scales/) supplies major, Dorian, dominant, and melodic-minor bebop formulas. Added notes are passing tones. In this app, “Dorian Bebop” includes both minor and major thirds; “Melodic Minor Bebop” includes both ♭6 and natural 6.
- [The Jazz Piano Site: Diminished Scale](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-scales/diminished-scale/) distinguishes whole-half for diminished chords from half-whole for dominant chords. Whole-half uses `bb7` for the diminished seventh so that chord-tone spelling stays meaningful, including double flats where necessary.
- [The Jazz Piano Site: Augmented Scale](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-scales/augmented-scale/) supports the six-note augmented scale and augmented-triad applications. It is a more colorful alternative; it also contains passing tones outside the triad.
- [PianoGroove: Blues Scales](https://www.pianogroove.com/blues-piano-lessons/blues-scale-improvisation-tutorial/) supplies the major and minor blues formulas and their usage. Major blues adds a minor third to major pentatonic; minor blues adds a flat fifth to minor pentatonic. These are melodic colors, not replacements for the LH chord formula.

## Choices deliberately excluded

- Altered has ♭9 and ♯9, not a natural 9. It was not added to the rootless ninth voicings that explicitly sustain a natural ninth. It also replaces the perfect fifth, so it was not added to the app's unaltered `7` voicing, which holds that fifth.
- Half-whole diminished was not added to `9`, `13(9)`, or `9(13)`: they hold a natural 9. It remains available on `13`, whose LH omits the ninth, and is now on `7`.
- Whole Tone was not copied to plain `7`, whose written fifth is natural. The user's existing Whole Tone choice on `9` was preserved; it is an altered color and replaces the RH extension when selected.
- Harmonic Minor was added to `minmaj9`, but not `minmaj7`: the latter becomes `min6` in first inversion under the user's rule. Harmonic Minor has ♭6, which would oppose that sustained natural 6. Melodic Minor and Melodic Minor Bebop retain the natural 6.
- Locrian was not added to minor chords with a natural fifth. Phrygian was not added to `min9`, because its ♭2 opposes the written natural ninth. Existing Phrygian on the minor triad was preserved and added to `min7`, which has no ninth.
- Lydian Augmented was not added to major chords that hold a natural fifth, nor to altered dominant ninths that hold a minor seventh. It is available on the augmented triad.

## Placement and selection

- Scales remain purple; chord and low-root colors are unchanged.
- The JSON's octave numbers remain in effect. When a complete scale would overlap the LH, the app shifts that complete scale upward in octaves, without changing intervals or clipping notes.
- An invalid LH voicing remains unavailable. The right-hand menu now also disables a scale if its conditional LH formula has no valid placement (for example, adding the ninth to A `9(#11, #5)`).
- Chords with a written RH extension retain that as their initial RH option. Chords without one start with their first scale; the menu no longer offers an empty “Right hand extension” for them.
- Selecting a different scale preserves the chosen inversion if it remains valid. Changing the chord or root still defaults to the first available voicing, as requested previously.
- A scale replaces the RH extension; the two are not overlaid. The user's special `LHScaleIntervals` and major-six/minor-six substitutions remain active.

## Validation

Run `python3 scripts/audit_scales.py` from the repository. It validates the JSON, unique names, interval/degree agreement, and all chord-group links. It then extracts the actual Swift model, spelling, LH voicing, scale placement, and note-label functions into a temporary command-line audit; the test does not maintain a second implementation of the placement algorithm.

The October 21 pass checked 863 interval/degree pairs, 2,864 valid root/chord/inversion/scale combinations, and 35,419 displayed-note labels. It excluded 220 unavailable voicings. All scales were complete, within the 60-key keyboard, and strictly above the highest LH note. The highest used key was index 59. The iOS Simulator build passed.
