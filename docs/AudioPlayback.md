# Chord playback

The bottom-right Play button sounds the current chord once on a shared sampled piano, holding it for 2.5 seconds before releasing. Keyboard index 24 maps to MIDI 60 (Middle C); the five-octave keyboard spans MIDI 36–95. The separate low root is always included. Notes shared by hands/root are deduplicated.

Named scale mode: play only the visible blue LH chord and bass; omit the purple scale entirely. Other modes: include purple RH chord tones, including upper structures, full polychords, Double, LH Shell, Drop voicings, So What, and RH extensions. A named scale does not silently add back the RH extension it replaces.

Repeated taps stop old voices before retriggering. Selection changes release the previous chord. Foreground loss, interruptions, and unplugged headphones stop playback. Playback uses AVAudioEngine / AVAudioUnitSampler with an iOS playback audio session and mixes with other audio; no microphone permission or network connection is needed. The piano loads lazily on the first tap. Instrument gain scales with the number of sounding notes to preserve headroom. Ordinary release tails are retained; a new tap clears old tails before restarting.

## Samples

BetterChords/Audio/BetterChordsPiano.sf2 is a 2,201,314-byte piano-only extraction from GeneralUser GS v2.0.3 by S. Christian Collins. Source: https://github.com/mrbumpy409/GeneralUser-GS (main, retrieved 2026-10-23). The original license and attribution ship beside it. The source bank allows modification and inclusion in software projects; retain its full license and sample-origin disclosures. Only the Grand Piano preset and its referenced samples are retained. Reproduce with scripts/extract_piano_soundfont.py. Apple’s macOS system sound bank used for the earlier demonstration is not bundled.

## Validation

The chord audit checks all available scale modes omit RH scale notes, and that ordinary, drop, extension, upper-structure and So What modes include the appropriate hand sets plus bass. The extracted bank was loaded into AVAudioUnitSampler and all 60 displayed pitches rendered offline to check for missing samples. A full C13 sharp-eleven voicing was rendered with the playback gain to check headroom. Simulator builds and the visible play button are checked separately. Physical iPhone playback still requires a device run.

## RH menu labels

The RH menu keeps its default entry first, followed by labeled Voicings, Extensions, and Scales sections. Voicings contains Open/UST/So What where available, Double, LH Shell, and drop choices. Extensions is omitted when no RH extension is defined. A selected named scale displays as “Scale: …” in the closed control and accessibility value. Internal selection names, highlighted notes, and playback filtering are unchanged.
