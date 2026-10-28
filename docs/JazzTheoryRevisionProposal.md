# Jazz theory revision proposal

Date: October 27, 2026
Status: Superseded by the user’s narrowed scope: retain chord, scale and voicing data updates; remove Theory & Practice and its related app changes. See JazzTheoryImplementation.md.

Prepared using the jazz-theory skill and a read-only review of the app source and chord data. No simulator verification was performed for this review. The user subsequently approved implementation of all items.

## Current foundation

The library contains 63 chord formulas and 196 chord–scale pairings. Existing features include upper structures, open voicings, drop voicings, shells, a So What option, substitutions, approaches, continuations, voice leading, and saved chord banks.

## Proposed changes

| ID | Priority | Change | Purpose and example |
|---|---|---|---|
| 1 | High | Correct chord-family detection | Where next currently classifies names beginning with a number as dominant, including 6 and 6/9. Give these their appropriate family, explanations, and suggestions. |
| 2 | High | Separate voice leading from reharmonization | Offer Preserve exact chord and Allow harmonic alternatives. The current optimizer can change extensions or alterations to reduce movement; identify any such change explicitly. |
| 3 | High | Expand resolutions and explanations | Retain existing dim7 improvements. Offer destination qualities explicitly: major triad, sixth, maj7, minor, minor sixth, or minor-major seventh where appropriate. Distinguish common-tone and leading-tone resolutions from chromatic slides. |
| 4 | High | Separate chord identity from optional color | Store defining tones, optional tones, allowed omissions, and contextual tensions separately. Natural 11 should not automatically become required in C13 or universally prohibited. |
| 5 | High | Make existing harmonic substitutions explicit | Preserve the user's preferred maj7-to-sixth and minor-major-seventh-to-minor-sixth behavior, while clearly distinguishing it from literal inversion in selection, saved banks, and suggestions. |
| 6 | Medium | Add melody/top-note controls | Keep a selected melody note on top while browsing or voice-leading chords, supporting chord melody and vocal accompaniment. |
| 7 | Medium | Expand named voicing families | Add Barron, Hancock, general quartal, Monk-style fragments, Powell-style shells, and locked hands, preserving their distinct interval constructions and hand splits. |
| 8 | Medium | Clarify shell and rootless options | Distinguish the current root-based LH shell from third-and-seventh guide-tone shells. Expand labeled third-low and seventh-low rootless arrangements as appropriate. |
| 9 | Medium | Add playability preferences | Support hand-span, register, density, and solo-piano/with-bassist preferences. Explain whether unavailable choices conflict with range or requested harmony. |
| 10 | Medium | Explain scale choices | Distinguish conventional, colorful, and passing-tone-oriented choices, with useful targets and possible clashes. Avoid suggesting that all choices are interchangeable. |
| 11 | Medium | Add context to substitutions and continuations | Optional key, destination, and harmonic setting should distinguish a blues tonic C7 from C7 resolving to F. Separate same-root color changes from functional substitutions. |
| 12 | Later | Add selected missing chord colors | Consider sus-flat-nine/Phrygian chords, explicitly named altered-dominant combinations, and selectable slash basses where musically useful rather than duplicative. |
| 13 | Later | Add progression and practice tools | Major/minor ii–V–I, turnarounds, blues, rhythm changes, common-tone diminished approaches, and line clichés, with transposition and sequential playback. |
| 14 | Supporting | Strengthen data documentation and checks | Add source references and explanations. Validate spelling, defining tones, voicing construction, transposition, range, and saved-bank compatibility. Preserve user arrangements during migration. |

## Recommended sequence

1. Items 1–5 and the relevant checks from 14: musical accuracy, predictable behavior, and explicit harmonic choices.
2. Melody controls and expanded voicings, followed by playability and scale explanations.
3. Contextual suggestions, selected chord additions, and progression/practice tools.

The original implementation was subsequently narrowed by the user to chord and scale changes. The broader interface and practice features below are historical proposals, not current app features.

## Evidence and references

Code reviewed: BetterChords/ChordBank.swift, BetterChords/ChordTonePolicy.swift, BetterChords/ChordFormulas.json, BetterChords/ContentView.swift, BetterChords/ChordAudioPlayer.swift, scripts/audit_scales.py, and docs/ScaleResearch.md.

- [Combining Chord Voicings](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chord-voicings/combining-chord-voicings/): melody-aware choice and smooth transitions.
- [Kenny Barron Minor Chord Voicing](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chord-voicings/barron-chord/): distinct six-note minor voicing with eleventh on top.
- [Herbie Hancock Minor Chord Voicing](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chord-voicings/hancock-chord/): distinct six-note minor voicing with ninth on top.
- [Available Tensions](https://www.thejazzpianosite.com/jazz-piano-lessons/jazz-chords/available-tensions/): contextual tension explanations; teaching rules should not become universal pitch bans.

These are product proposals informed by source lessons and the current implementation, not claims that the source prescribes the proposed app design.
