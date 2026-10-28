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


## Altered dominants added October 22, 2026

Four new Major-group extensions use conventional dominant-seventh names: `7(#9)`, `7(b9)`, `7(#9, #5)`, and `7(b9, b5)`. They omit the root from the LH; the separate bass root remains present. Explicit `LHVoicings` and `LHVoicingLabels` store two forms, built from the third and from the flat seventh. The existing second-D to third-A range (indices 14–33) applies to each complete voicing. Unavailable forms are disabled; root/chord changes choose the first fitting form.

| Chord | Built from 3rd | Built from 7th | RH extension | Scales |
| --- | --- | --- | --- | --- |
| 7(#9) | 4, 10, 15 | 10, 15, 16 | 19, 24 | Half-whole diminished; Altered |
| 7(b9) | 4, 10, 13 | 10, 13, 16 | 19, 24 | Half-whole diminished; Phrygian Dominant; Altered |
| 7(#9, #5) | 4, 8, 10, 15 | 10, 15, 16, 20 | 20, 24 | Altered |
| 7(b9, b5) | 4, 6, 10, 13 | 10, 13, 16, 18 | 18, 24 | Half-whole diminished; Altered |

The RH dyads are app-specific arrangements of the written fifth (perfect, raised, or lowered) and root. Their entire register shifts by octaves as necessary to stay strictly above the LH. A scale replaces that dyad. No natural ninth or perfect fifth is forced into an explicitly altered LH formula.

Altered uses stored semitones `24, 25, 27, 28, 30, 32, 34, 36`, with tension-oriented spelling degrees `1, b9, #9, 3, b5, #5, b7, 8`. Phrygian Dominant uses `24, 25, 28, 29, 31, 32, 34, 36` with `1, b2, 3, 4, 5, b6, b7, 8`. Existing Half-whole Diminished data is reused unchanged in pitch and degree, with the upper-octave offset. Every included scale contains all explicitly voiced LH pitch classes. Whole Tone and unaltered dominant/bebop scales are excluded because they omit the requested altered ninth.

Sources and arrangement rationale:

- [Jazz Nomenclature Packet](https://jazzday.com/media/Dyas-Jazz-Nomenclature-Packet-Complete.pdf): chord-symbol chart includes these exact four chord types; the chord-scale discussion distinguishes diminished and altered dominant pitch collections.
- [The Jazz Piano Site: Rootless Voicings](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chord-voicings/rootless-voicings/): third- and seventh-based forms, retaining guide tones and altering tensions.
- [The Jazz Piano Site: Melodic Minor Modes and Altered Scale](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-scales/melodic-minor-modes/): altered tensions and omission of the natural fifth.
- [The Jazz Piano Site: Diminished Scale](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-scales/diminished-scale/): half-whole use over dominant flat-nine chords.
- Dr. Mark Watkins, BYU–Idaho, [Fundamentals of Jazz Improvisation, Theory 2](https://content.byui.edu/file/be14498b-aa3f-4b2a-b9e6-4fb3fdbd1d12/1/05%20Theory%202.pdf), pages 5–8: Phrygian Dominant over V7(b9) and Altered over altered fifths/ninths.

The earlier placement section describes the October 21 defaults. Current menus default to empty `RH` per the later user request, and offer Double, LH Shell, Drop options, extensions, and scales where supported.


## Additional chord families, October 22, 2026

Nineteen additional formulas complete the previously proposed list. Existing formulas and scale choices are preserved. Rootless major/minor forms use third/seventh basses, sixth chords use third/sixth, add9 uses third/fifth, and suspended forms use fourth/seventh. Each entire LH voicing must fit indices 14–33. RH extensions are app arrangements of supporting chord tones or available tensions, placed above the LH as complete octave-shifted groups. Scales replace the extension and are checked against every explicit LH pitch class.

| Chord | LH intervals | LH degrees | RH extension | RH degrees | Scales |
| --- | --- | --- | --- | --- | --- |
| 6/9 | 4, 7, 9, 14 | 3, 5, 6, 9 | 19, 24 | 12, 15 | Major; Lydian; Major Pentatonic; Major Bebop |
| add9 | 4, 7, 14 | 3, 5, 9 | 19, 24 | 12, 15 | Major; Lydian; Major Pentatonic; Harmonic Major |
| maj13 | 4, 9, 11, 14 | 3, 13, 7, 9 | 19, 24 | 12, 15 | Major; Lydian; Major Bebop |
| maj7(#11) | 4, 6, 11 | 3, #11, 7 | 19, 24 | 12, 15 | Lydian |
| maj9(#11) | 4, 6, 11, 14 | 3, #11, 7, 9 | 19, 24 | 12, 15 | Lydian |
| min11 | 3, 5, 10, 14 | b3, 11, b7, 9 | 19, 24 | 12, 15 | Dorian; Natural Minor; Dorian Bebop |
| min13 | 3, 9, 10, 14 | b3, 13, b7, 9 | 19, 24 | 12, 15 | Dorian; Dorian Bebop; Dorian #4 |
| 7sus4 | 5, 7, 10 | 4, 5, b7 | 19, 24 | 12, 15 | dominant; dominant bebop; Dorian; Suspended Pentatonic |
| 9sus4 | 5, 10, 14 | 4, b7, 9 | 19, 24 | 12, 15 | dominant; dominant bebop; Dorian; Suspended Pentatonic |
| 13sus4 | 5, 9, 10, 14 | 4, 13, b7, 9 | 19, 24 | 12, 15 | dominant; dominant bebop; Dorian |
| 7(#11) | 4, 6, 10 | 3, #11, b7 | 19, 24 | 12, 15 | Lydian dominant; Whole Tone; half-whole diminished; Altered |
| 9(#11) | 4, 6, 10, 14 | 3, #11, b7, 9 | 19, 24 | 12, 15 | Lydian dominant; Whole Tone |
| 13(#11) | 4, 6, 9, 10 | 3, #11, 13, b7 | 26, 31, 36 | 16, 19, 22 | Lydian dominant; half-whole diminished |
| 7(b9, #5) | 4, 8, 10, 13 | 3, #5, b7, b9 | 20, 24 | #12, 15 | Altered; Phrygian Dominant |
| 7(#9, #11) | 4, 6, 10, 15 | 3, #11, b7, #9 | 19, 24 | 12, 15 | half-whole diminished; Altered |
| 13(b9) | 4, 9, 10, 13 | 3, 13, b7, b9 | 19, 24 | 12, 15 | half-whole diminished |
| min9b5 | 3, 6, 10, 14 | b3, b5, b7, 9 | 17, 24 | 11, 15 | Locrian Natural 2 |
| min11b5 | 3, 5, 6, 10, 14 | b3, 11, b5, b7, 9 | 24, 29 | 15, 18 | Locrian Natural 2 |
| maj7(#5) | 4, 8, 11 | 3, #5, 7 | 26, 36 | 16, 22 | Lydian Augmented; Augmented |

All scale patterns reuse the existing validated data, shifted to a stored starting offset of 24. Minor 13 requires a natural sixth, so Natural Minor is excluded. Minor ninth/eleventh flat-five requires a natural ninth, so Locrian Natural 2 is used rather than ordinary Locrian. The augmented-major seventh requires both a raised fifth and a major seventh, excluding Whole Tone. 13(b9) retains a natural thirteenth and uses Half-whole Diminished, excluding Altered and Phrygian Dominant. Suspended scales can include a third as a passing scale tone, but the LH chord contains the fourth and no third.

For compact rootless maj13/min13 voicings, the fifth is supplied by the RH extension rather than crowded into the LH. For 13(#11), the LH retains the sharp eleventh and thirteenth; the RH extension supplies ninth, fifth, and root. Minor 11 flat-five keeps its ninth and eleventh in the LH so it remains distinct from Minor 9 flat-five.

Sources: [Jazz Nomenclature Packet, chord and chord-scale charts](https://jazzday.com/media/Dyas-Jazz-Nomenclature-Packet-Complete.pdf), [TJPS rootless voicing principles](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chord-voicings/rootless-voicings/), and the scale-specific sources documented above. The exact LH/RH distributions are arrangements for this app, not verbatim transcriptions of the source examples.

## Slash chords and full polychords

Major extensions now include V/I and II/I (upper major triad over the selected bass), plus V over I and II over I (two full major triads). For C these are G/C, D/C, G over C, and D over C. Slash symbols use a diagonal slash; full polychords use vertically stacked chord names with a horizontal divider. Upper names transpose and spell from the fifth or second of the selected root.

Full polychords default to the lower major triad in blue and the upper major triad in purple; the separate low root remains green. Their RH default is labeled “Upper chord.” Lower inversions retain the existing low triad register. The upper triad stays above the lower chord; choosing a scale replaces it with that scale. V/I and V over I offer Major, Lydian, Major Bebop, and Harmonic Major. II/I and II over I offer Lydian and Lydian Dominant, both containing the upper major triad’s sharp fourth. Every offered scale contains all explicitly voiced chord pitch classes. Exact registers and hand splits are app arrangements.

References: [University of Puget Sound: Polychords](https://musictheory.pugetsound.edu/mt21c/polychords.html), [The Jazz Piano Site: Polychords](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chords/polychords/), and [Slash Chords](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chords/slash-chords/).

### Additional borrowed-triad slash chords

Major extensions also include bVI/I, bVII/I, and bIII/I: A-flat/C, B-flat/C, and E-flat/C in C. These are upper major triads over a single bass note, not full lower chords. They transpose through the shared slash-chord spelling function. bVI/I offers Natural Minor, Phrygian, and Harmonic Minor; bVII/I offers Dominant, Dorian, and Natural Minor; bIII/I offers Natural Minor, Dorian, and Phrygian. All these scale formulas already exist in the library and contain the bass plus every upper-triad pitch class. Augmented Major 7 already exists as maj7(#5) in the Augmented group, with Lydian Augmented and Augmented scales.

## Upper structures and So What voicings

Added 7(#5), 7(b5), 7alt, 7(b13), 9(b13), and Minor Add9. These keep separate symbols for augmented dominant versus augmented major seventh, and for an added ninth without a seventh. 7alt uses a representative 3–b13–b7–#9 voicing, not every possible alteration at once.

Optional HandVoicings data now defines complete hand splits. UST labels identify the upper triad relative to the selected root (m denotes a minor upper triad). Blue LH uses third/seventh guide tones; purple RH uses the upper triad. Options preserve defining alterations and extensions (the natural fifth may be omitted), and match an existing non-bebop, non-blues chord scale. Major-third shells exclude natural eleventh clashes; dominant shells exclude a simultaneous major seventh. Upper triads have their own degree spelling. These are app-specific arrangements informed by Berklee's upper-structure approach, not transcribed school exercises.

So What is offered for Minor, Minor 7, and Minor 11: relative pitches 0,5 | 10,15,19 (three fourths and a major third), with two blue notes below three purple notes. This adds b7/11 color to the minor triad. It is not offered on Minor 9/13 or altered-minor chords because the standard shape omits defining requested extensions or conflicts with altered tones. Both modes retain the separate low green root and fit the blue notes inside the existing D–A range. Their fixed hand arrangement disables the ordinary inversion control; selecting another RH mode restores it. Default RH behavior is unchanged.

Sources: [Berklee Upper Structure Triad Applications](https://college.berklee.edu/courses/ilpn-235), [Berklee piano voicing principles](https://online.berklee.edu/takenote/basic-piano-voicing-techniques/), and [Indiana University jazz piano proficiency](https://intranet.music.indiana.edu/departments/academic/jazz/Jazz%20Piano%20Proficiency%20for%20Non-pianists.html) (public search index lists So What voicings; direct access currently requires institutional sign-in). For the shape's construction, see [UNT dissertation on Thad Jones](https://digital.library.unt.edu/ark:/67531/metadc801875/m2/1/high_res_d/dissertation.pdf), p.76.

## Open worship voicings

Added IV/I (F/C in C), minor ii/I (Dm/C in C), and Sus4(add9), with no seventh added to the latter. Both slash chords use one bass note, not a full lower C chord. Stack metadata now optionally specifies a minor upper-triad quality, so slash symbols transpose as minor chords where appropriate. IV/I and ii/I offer Major, Dominant, and Dorian; Sus4(add9) offers Major, Dominant, Dorian, Natural Minor, and Suspended Pentatonic. Each offered scale contains the bass and all explicitly voiced chord tones.

The fixed Open RH option is available for Major, Minor, Add9, Minor Add9, sus2, sus4, Sus4(add9), 7sus4, 9sus4, and 13sus4. It retains the separate green bass, plays a fifth in blue, and distributes the remaining chord tones above it in purple. For C major this is low C | G | C–E; Cadd9 is low C | G | D–E–C. Root/third/seventh colors are preserved as appropriate; ordinary major/minor Open options do not introduce extra extensions. Open is a hand arrangement, not an automatic voice-leading feature, and uses the same fixed-voicing inversion control behavior as UST and So What. Playback includes the entire Open hand split plus bass.

These are arrangements for BetterChords informed by [Worship Arts Conservatory's guide to added ninths, suspensions, and slash chords](https://worshiparts.net/resources/worship-training/ultimate-guide-to-understanding-worship-chords/) and [Jon Payne's WorshipGod piano workshop, register and fifth/octave/ninth patterns](https://sovereigngracemusic.s3.amazonaws.com/wp-content/uploads/20230821180853/advanced_piano_techniques-wg09-jpayne.pdf). Exact note distributions are not transcriptions from those sources.


## October 27, 2026 — approved theory expansion

The library now has 66 formulas, 200 chord–scale assignments and 32 unique scales. Scale entries carry usage, target-degree, caution and source metadata. Chord metadata distinguishes defining tones from optional colors, omissions and contextual tensions. The later scope revision keeps the data additions and removes the Theory & Practice interface and related app features. See [JazzTheoryImplementation.md](JazzTheoryImplementation.md) for the retained changes.
