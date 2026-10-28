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
