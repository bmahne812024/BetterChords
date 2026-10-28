# Jazz chord and scale data update

## Revised scope

At the user’s request, the Theory & Practice interface and its related controls, progression templates, playback changes and saved-bank schema changes have been removed. The existing app interface and behavior are restored from commit 0837d84, with a small empty-right-hand safety fix for the new shell voicings.

## Retained data additions

- Three chord colors: 7sus4(b9), 7(b9, #11), and 7(b9, b13).
- Dorian b2 and updated chord–scale assignments: 66 chord formulas, 200 assignments and 32 distinct scales in total.
- Additional named voicings, available through the existing voicing menu: Barron, Hancock, quartal, Monk-style fragments, Powell-style shells, guide-tone shells, rootless arrangements and locked hands. There are 73 named arrangements in total.
- Theory explanations and source metadata retained in the data file for reference; no separate theory interface.
- Pitch-policy entries for the three new chord colors, and checks supporting the expanded data.

Existing diminished resolution behavior from before the Theory & Practice commit is retained. User banks are not migrated or rewritten by this rollback. Existing range restrictions still apply to voicings.

## Validation

The chord and scale audit covers formula spellings, pitch sets, transposition, hand separation, available voicings, displayed-note labels and existing bank behavior. The app is also built for the iOS simulator.

## Expanded substitutions — October 27, 2026

The existing Substitutes sheet now offers the full curated choices rather than stopping at three. Every chord has recommendations, including slash/polychord entries. Two-hand mode also includes the current harmony so another arrangement can be selected without changing its symbol.

Major chords offer sus2, suspended add9, sixth/ninth and Lydian colors. Dominants offer suspended alternatives as well as natural and altered tensions. Minor, minor-major, half-diminished, diminished and augmented families have additional related choices. These are optional colors: changes to thirds, fifths, sixths, sevenths or tensions must fit the melody and progression. Brief cautions appear on the existing cards.

So What arrangements are available for 6/9, maj13, the new maj13(#11), 9sus4 and 13sus4, alongside the existing min11 arrangement. Further quartal stacks and fragments cover major, minor, suspended, dominant and half-diminished sounds. The library now contains 67 formulas, 201 scale assignments, 32 distinct scales and 90 named hand arrangements.

Construction references: [So What](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chord-voicings/so-what-chord/) and [quartal voicings](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chord-voicings/quartal-voicings/). The audit checks exact So What intervals in all keys, permitted pitches, chord coverage and preview/Use parity.
