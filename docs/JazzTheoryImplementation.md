# Jazz theory implementation

Implemented October 27, 2026, following approval of all 14 proposal items.

Open **Theory & Practice** on the main screen (or Theory in the bank toolbar).

| Proposal | Delivered behavior |
|---|---|
| 1 | Explicit chord families, including sixth, suspended, half-diminished and slash/polychord families. |
| 2 | Preserve exact chord or allow harmonic alternatives during voice leading; harmony changes are labeled. Named arrangements retain their interval geometry. |
| 3 | Explicit major, sixth, major-seventh, minor, minor-sixth and minor-major-seventh diminished destinations, with common-tone/leading-tone/slide explanations. |
| 4 | Defining, optional, omittable and contextual tones stored separately and explained in the theory panel. |
| 5 | Preferred sixth substitutions retained and identified in selection and saved cards; legacy notes remain unchanged. |
| 6 | Optional fixed highest melody note, applied when fitting and voice-leading voicings. |
| 7 | Barron, Hancock, quartal, Monk-style fragments, Powell-style shells and locked-hands arrangements. |
| 8 | Guide-tone and root-based shells distinguished; third-low/seventh-low rootless options added. |
| 9 | Hand spans, register, density and solo/bassist preferences, with unavailable-choice guidance. |
| 10 | Scale usage, target degrees, cautions and source links. |
| 11 | Optional key, destination and tonal/blues/modal setting; same-root colors labeled separately. |
| 12 | 7sus4(b9), 7(b9, #11), 7(b9, b13), Dorian b2 and selectable slash bass. |
| 13 | Ten transposable practice templates, tempo, repeat, sequential playback, bank append and bank playback. |
| 14 | Source metadata, schema versioning and expanded musical/runtime regression checks. |

## Library and practice

The library now contains 66 chord formulas, 200 chord–scale assignments, 32 distinct scales and 73 named hand arrangements. The ten practice templates cover major/minor ii–V–I, turnaround, Dameron turnaround, jazz blues, rhythm changes, Bird-style blues, a major-third tonic cycle, common-tone diminished and a minor line cliché.

## Compatibility and limits

Legacy bank documents remain readable. Saved hand notes are recalled verbatim; new identity, melody, bass and annotation fields are optional. Default performance preferences preserve existing placements. User banks are not rewritten during recall or template preview.

A named shape may be unavailable for a root, register, span or melody constraint. The app reports this rather than changing its construction. The existing C2–B6 keyboard and left-hand register limits remain. Fixed melody fitting uses available voicings and octave placements; it is not an unrestricted arrangement generator.

## Verification

The expanded audit exercises all 66 formulas, 2,220 interval/degree pairs, 120 transposed template cases, legacy bank round trips, explicit diminished destinations, named geometry, constraints, exact versus alternative voice leading, custom bass and existing playback/recall paths. Simulator build and visual practice checks accompany the audit. Playback scheduling is checked in the simulator; audio timbre has not been independently auditioned.
