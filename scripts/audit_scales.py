#!/usr/bin/env python3
"""Validate JSON and audit the Swift app's actual spelling/placement functions.

Run: python3 scripts/audit_scales.py
Requires Xcode's Swift compiler. Generated audit files stay in a temporary directory.
"""
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
JSON_PATH = ROOT / 'BetterChords/ChordFormulas.json'
SOURCE = ROOT / 'BetterChords/ContentView.swift'


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        assert key not in result, f'Duplicate JSON key: {key}'
        result[key] = value
    return result


def validate_data():
    data = json.loads(JSON_PATH.read_text(), object_pairs_hook=unique_object)
    chords = [c for values in data['Chords'].values() for c in values]
    assert len({c['name'] for c in chords}) == len(chords)
    grouped = [name for g in data['ChordGroups'] for name in g['chords']]
    assert len(grouped) == len(set(grouped))
    assert set(grouped) == {c['name'] for c in chords}
    count = 0
    patterns = {}
    # Documented sparse pentatonic / blues choices may imply a chord tone.
    # Other choices must contain every explicitly voiced LH pitch class.
    implied_tones = {
        ('7', 'Major Pentatonic'): {10},
        ('7', 'Minor Blues'): {4},
        ('9', 'Major Pentatonic'): {10},
        ('maj7', 'Major Pentatonic'): {11},
        ('maj9', 'Major Pentatonic'): {11},
        ('min9', 'Minor Pentatonic'): {2},
        ('min9', 'Minor Blues'): {2},
    }
    for chord in chords:
        pairs = [(chord['LHIntervals'], chord['LHDegrees'])]
        for ints, degrees in [('LHScaleIntervals', 'LHScaleDegrees'), ('RHExtension', 'RHDegrees'), ('RHChordIntervals', 'RHChordDegrees')]:
            if ints in chord:
                pairs.append((chord[ints], chord[degrees]))
        if 'LHVoicings' in chord:
            base_pitches = {i % 12 for i in chord['LHIntervals']}
            for voicing in chord['LHVoicings']:
                assert voicing == sorted(set(voicing)), chord['name']
                voiced_pitches = {i % 12 for i in voicing}
                # Major 7 #5 offers both rootless and complete inversions.
                allowed_pitches = [base_pitches]
                if chord['name'] == 'maj7(#5)':
                    allowed_pitches.append(base_pitches | {0})
                assert voiced_pitches in allowed_pitches, chord['name']
            if 'LHVoicingLabels' in chord:
                assert len(chord['LHVoicingLabels']) == len(chord['LHVoicings'])
        for option in chord.get('HandVoicings', []):
            pairs += [(option['LHIntervals'], option['LHDegrees']), (option['RHIntervals'], option['RHDegrees'])]
            assert option['LHIntervals'] and option['RHIntervals']
            if option['name'].startswith('UST '):
                voiced = {i % 12 for i in option['LHIntervals'] + option['RHIntervals']}
                assert {i % 12 for i in chord['LHIntervals']} - {0, 7} <= voiced
                assert any(voiced | {0} <= {i % 12 for i in scale['intervals']} for scale in chord['Scales'])
        names = []
        assert chord.get('Scales'), f'No scales for {chord["name"]}'
        for scale in chord['Scales']:
            names.append(scale['name'].casefold())
            intervals = scale['intervals']
            assert intervals == sorted(set(intervals))
            assert intervals[-1] - intervals[0] == 12, scale['name']
            assert intervals[0] in (12, 24), scale['name']
            normalized = tuple(i - intervals[0] for i in intervals)
            identity = (normalized, tuple(scale['degrees']))
            assert patterns.setdefault(scale['name'], identity) == identity, f'Conflicting formula: {scale["name"]}'
            lh = chord.get('LHScaleIntervals', chord['LHIntervals'])
            missing = {i % 12 for i in lh + chord.get('RHChordIntervals', [])} - {i % 12 for i in intervals}
            assert missing == implied_tones.get((chord['name'], scale['name']), set()), (chord['name'], scale['name'], missing)
            pairs.append((intervals, scale['degrees']))
        assert len(names) == len(set(names)), f'Duplicate scale in {chord["name"]}'
        for intervals, degrees in pairs:
            assert len(intervals) == len(degrees), chord['name']
            for interval, degree in zip(intervals, degrees):
                match = re.fullmatch(r'([b#]*)([1-9][0-9]*)', degree)
                assert match, degree
                alteration = degree.count('#') - degree.count('b')
                major = [0, 2, 4, 5, 7, 9, 11][(int(match[2]) - 1) % 7]
                assert (major + alteration) % 12 == interval % 12, (chord['name'], interval, degree)
                count += 1
    print(f'PASS: {len(chords)} chords, {len(patterns)} distinct scales, {count} interval/degree pairs', flush=True)


def swift_function(source, marker):
    """Extract an existing pure function, keeping its implementation under test."""
    start = source.index(marker)
    opening = source.index('{', start)
    depth = 1
    end = opening + 1
    while depth:
        if source[end] == '{':
            depth += 1
        elif source[end] == '}':
            depth -= 1
        end += 1
    return source[start:end].replace('private ', '')


def run_swift_audit():
    source = SOURCE.read_text()
    models = source[source.index('struct ChordFormulaFile'):source.index('struct ContentView')]
    methods = source[source.index('    private func leftHandIntervals'):source.index('    private func highlightedColor')]
    methods = methods.replace('private ', '').replace('func selectValidInversion()', 'mutating func selectValidInversion()')
    labels = swift_function(source, '    private func noteName')
    available = source[source.index('    private var availableInversions'):source.index('    @State private var chordTypes')].replace('private ', '')
    harness = '''import Foundation
MODELS
struct Audit {
let middleCNote = 24
let totalNotes = 60
let inversionNames = ["Root", "First", "Second", "Third", "Fourth"]
var selectedRoot = 0
var rootEnabled = true
var selectedChord = "maj"
var selectedInversion = 0
var selectedScale = ""
var roots: [String] = []
var formulas: [String: ChordFormula] = [:]
var chordIntervals: [String: [Int]] = [:]
var scaleChordIntervals: [String: [Int]] = [:]
var rightHandExtensions: [String: [Int]] = [:]
var chordScales: [String: [ScaleFormula]] = [:]
var triadNames: Set<String> = []
var extensionNames: Set<String> = []
var usesMajorSixSubstitution: Bool { selectedChord == "maj7" && selectedInversion == 1 }
var usesMinorSixSubstitution: Bool { selectedChord == "minmaj7" && selectedInversion == 1 }
AVAILABLE
METHODS
LABELS
}
let data = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
let decoded = try JSONDecoder().decode(ChordFormulaFile.self, from: data)
var a = Audit()
a.roots = (0..<12).map { decoded.Roots[String($0)]! }
a.triadNames = Set(decoded.Chords.Triads.map(\\.name))
a.extensionNames = Set(decoded.Chords.Extensions.map(\\.name))
for c in decoded.Chords.allChords {
    a.formulas[c.name] = c
    a.chordIntervals[c.name] = c.LHIntervals
    a.scaleChordIntervals[c.name] = c.LHScaleIntervals
    a.rightHandExtensions[c.name] = c.RHExtension ?? []
    a.chordScales[c.name] = c.Scales ?? []
}
func pitchClass(of name: String) -> Int {
    let natural: [Character: Int] = ["C":0,"D":2,"E":4,"F":5,"G":7,"A":9,"B":11]
    let alteration = name.dropFirst().reduce(0) { value, character in
        value + (character == "♭" ? -1 : character == "♯" ? 1 : character == "𝄫" ? -2 : character == "𝄪" ? 2 : 0)
    }
    return (natural[name.first!]! + alteration + 24) % 12
}
func expectedFloor(_ chord: ChordFormula, bass: Int) -> Int {
    let pitch = (bass % 12 + 12) % 12
    for (interval, degree) in zip(chord.LHIntervals, chord.LHDegrees) where interval % 12 == pitch {
        let number = Int(degree.filter { $0.isNumber })!
        if [3, 7].contains((number - 1) % 7 + 1) { return 14 }
    }
    return 10
}
precondition(NoteSpelling.name(root:"Db", interval:3, degree:"b3") == "F♭")
precondition(NoteSpelling.name(root:"Db", interval:6, degree:"b5") == "A𝄫")
precondition(NoteSpelling.name(root:"Db", interval:9, degree:"bb7") == "C𝄫")
precondition(NoteSpelling.name(root:"B", interval:8, degree:"#5") == "F𝄪")
var checked = 0
var disabled = 0
var highest = 0
var labelsChecked = 0
for chord in decoded.Chords.allChords {
    a.selectedChord = chord.name
    for root in 0..<12 {
        a.selectedRoot = root
        for scale in chord.Scales ?? [] {
            a.selectedScale = scale.name
            let availability = a.availableInversions.contains { a.voicedChordNotes(inversion:$0) != nil }
            precondition(a.hasValidVoicing(chord:chord.name, root:root, scale:scale.name) == availability)
            for inversion in a.availableInversions {
                a.selectedInversion = inversion
                guard let lh = a.voicedChordNotes(inversion:inversion) else { disabled += 1; continue }
                let floor = expectedFloor(chord, bass: lh.first! - root)
                precondition(lh.allSatisfy { (floor...33).contains($0) })
                precondition(a.chordPlaybackNotes == Set(lh).union([root]), "Scale leaked into chord playback")
                let notes = a.scaleNotes.sorted()
                let description = "\\(root) \\(chord.name) inversion \\(inversion) \\(scale.name)"
                precondition(notes.count == scale.intervals.count, "Clipped scale: \\(description)")
                precondition(notes.first! > lh.last!, "Overlap: \\(description)")
                precondition(notes.allSatisfy { (0..<60).contains($0) }, description)
                let difference = zip(notes, scale.intervals).map { $0 - $1 }
                precondition(Set(difference).count == 1 && difference[0] % 12 == root, "Changed scale spacing: \\(description)")
                for note in Set(lh).union(notes).union([root]) {
                    precondition(pitchClass(of:a.noteName(note)) == note % 12, "Incorrect label: \\(description), \\(note), \\(a.noteName(note))")
                    labelsChecked += 1
                }
                // Changing scales should preserve a valid selected inversion.
                let oldInversion = a.selectedInversion
                if a.voicedChordNotes(inversion:a.selectedInversion) == nil { a.selectValidInversion() }
                precondition(a.selectedInversion == oldInversion)
                highest = max(highest, notes.last!)
                checked += 1
            }
        }
    }
}
// Every valid inversion supports all three drop patterns and the empty RH default.
var dropsChecked = 0
for chord in decoded.Chords.allChords {
    a.selectedChord = chord.name
    precondition(a.defaultScale(for: chord.name).isEmpty)
    for root in 0..<12 {
        a.selectedRoot = root
        for inversion in a.availableInversions {
            a.selectedInversion = inversion
            a.selectedScale = ""
            guard let close = a.voicedChordNotes(inversion: inversion) else { continue }
            precondition(a.rightHandNotes == a.coreRightHandNotes(inversion: inversion))
            precondition(a.chordPlaybackNotes == Set(close).union([root]).union(a.rightHandNotes))
            a.selectedScale = "Double"
            precondition(a.rightHandNotes == Set(close.map { $0 + 12 }).union(a.coreRightHandNotes(inversion: inversion)))
            precondition(a.selectedChordNotes == Set(close).union([root]))
            precondition(a.rightHandNotes.allSatisfy { (0..<60).contains($0) })
            precondition(a.dropOptions.contains("Drop 2 & 3") == !a.triadNames.contains(chord.name))
            for option in a.dropOptions {
                a.selectedScale = option
                guard let drop = a.dropVoicing else { fatalError("Missing drop voicing") }
                let expected = Set(close.map { $0 % 12 })
                precondition(Set(drop.left.union(drop.right).map { $0 % 12 }) == expected)
                precondition(drop.left.allSatisfy { (expectedFloor(chord, bass: drop.left.min()! - root)...33).contains($0) })
                precondition(drop.left.isDisjoint(with: drop.right))
                precondition(drop.left.count == a.dropPositions.count)
                precondition(drop.left.count + drop.right.count == close.count)
                precondition(a.selectedChordNotes.contains(root))
                precondition(a.chordPlaybackNotes == drop.left.union(drop.right).union([root]).union(a.coreRightHandNotes(inversion: inversion)))
                for note in drop.left.union(drop.right) {
                    precondition(pitchClass(of: a.noteName(note)) == note % 12)
                }
                dropsChecked += 1
            }
        }
    }
}
print("PASS: \(dropsChecked) drop voicings, hand separation, spelling, and empty RH defaults")
var shellsChecked = 0
for chord in decoded.Chords.allChords {
    a.selectedChord = chord.name
    a.selectedScale = "LH Shell"
    for root in 0..<12 {
        a.selectedRoot = root
        for inversion in a.availableInversions {
            a.selectedInversion = inversion
            guard let notes = a.voicedChordNotes(inversion: inversion) else { continue }
            if chord.LHIntervals.first == 0 && inversion != 0 {
                precondition(a.selectedShell == nil)
                continue
            }
            if chord.LHIntervals.first != 0 && !chord.LHIntervals.contains(where: { [10,11].contains($0%12) }) {
                precondition(a.selectedShell == nil)
                continue
            }
            let loweredShell = ["9", "13", "9(13)", "13(9)"].contains(chord.name)
            if loweredShell && root + 10 >= notes.first! {
                precondition(a.selectedShell == nil)
                continue
            }
            guard let shell = a.selectedShell else { continue }
            if loweredShell {
                let shift = shell.left.min()! - root
                precondition(shift % 12 == 0)
                precondition(shell.left == Set([root + shift, root + 10 + shift]))
                precondition(shell.right == Set(notes.map { $0 + shift }))
            }
            if chord.LHIntervals.first == 0 {
                let shift = shell.left.min()! - notes.first!
                precondition(shift % 12 == 0)
                precondition(shell.left == Set([notes.first! + shift, notes.last! + shift]))
            } else {
                let seventh = chord.LHIntervals.first(where: { [10,11].contains($0 % 12) })! % 12
                precondition(Set(shell.left.map { ($0-root+12)%12 }) == Set([0,seventh]))
            }
            precondition(Set(shell.right.map { $0%12 }) == Set(notes.map { $0%12 }))
            precondition(shell.left.allSatisfy { (expectedFloor(chord, bass: shell.left.min()! - root)...33).contains($0) })
            precondition(shell.right.min()! > shell.left.max()!)
            precondition(a.selectedChordNotes.contains(root))
            for note in shell.left.union(shell.right) {
                precondition(pitchClass(of:a.noteName(note)) == note%12)
            }
            shellsChecked += 1
        }
    }
}
print("PASS: \(shellsChecked) shells, hand separation, spelling, and inversion restrictions")
a.selectedChord="min6/9"; a.selectedRoot=0; a.selectedScale=""
precondition(Array(a.availableInversions) == [0,1])
precondition(a.voicedChordNotes(inversion:0) == [15,19,21,26])
precondition(a.voicedChordNotes(inversion:1) == [21,26,27,31])
precondition(a.voicedChordNotes(inversion:2) == nil)
var rhChecked = 0
for chord in decoded.Chords.allChords where !(chord.RHExtension ?? []).isEmpty {
    a.selectedChord = chord.name
    a.selectedScale = "Right hand extension"
    for root in 0..<12 {
        a.selectedRoot = root
        for inversion in a.availableInversions {
            a.selectedInversion = inversion
            guard let lh = a.voicedChordNotes(inversion: inversion) else { continue }
            let rh = a.rightHandNotes
            precondition(a.chordPlaybackNotes == Set(lh).union(rh).union([root]))
            precondition(rh.count == chord.RHExtension!.count)
            precondition(rh.min()! > lh.max()!)
            precondition(rh.allSatisfy { (0..<60).contains($0) })
            for note in rh { precondition(pitchClass(of:a.noteName(note)) == note%12) }
            rhChecked += 1
        }
    }
}
let alteredChords = ["7(#9)", "7(b9)", "7(#9, #5)", "7(b9, b5)"]
for name in alteredChords {
    a.selectedChord = name
    a.selectedScale = ""
    precondition(Array(a.availableInversions) == [0,1])
    for root in 0..<12 {
        a.selectedRoot = root
        a.selectValidInversion()
        precondition(a.voicedChordNotes(inversion:a.selectedInversion) != nil)
        for inversion in a.availableInversions {
            guard let notes = a.voicedChordNotes(inversion:inversion) else { continue }
            let expectedBass = inversion == 0 ? 4 : 10
            precondition((notes.first!-root+12)%12 == expectedBass)
            precondition(notes.allSatisfy { (14...33).contains($0) })
        }
    }
}
print("PASS: \(rhChecked) RH extensions above LH without clipping; altered dominant basses/ranges/defaults")
var explicitChecked = 0
for chord in decoded.Chords.allChords {
    guard let voicings = chord.LHVoicings, let labels = chord.LHVoicingLabels else { continue }
    a.selectedChord = chord.name
    a.selectedScale = ""
    precondition(labels.count == voicings.count)
    for root in 0..<12 {
        a.selectedRoot = root
        precondition(a.hasValidVoicing(chord:chord.name,root:root))
        a.selectValidInversion()
        precondition(a.voicedChordNotes(inversion:a.selectedInversion) != nil)
        for inversion in a.availableInversions {
            guard let notes = a.voicedChordNotes(inversion:inversion) else { continue }
            precondition((notes.first!-root+12)%12 == voicings[inversion].first!%12)
            if chord.Stack?.kind == "polychord" {
                precondition(notes.allSatisfy { (expectedFloor(chord, bass: notes.first! - root)...33).contains($0) })
                a.selectedInversion = inversion
                let upper = a.coreRightHandNotes(inversion: inversion)
                precondition(upper.count == 3 && upper.min()! > notes.last!)
                precondition(upper.allSatisfy { (0..<60).contains($0) })
                for note in upper { precondition(pitchClass(of:a.noteName(note)) == note%12) }
            } else {
                precondition(notes.allSatisfy { (expectedFloor(chord, bass: notes.first! - root)...33).contains($0) })
            }
            explicitChecked += 1
        }
    }
}
print("PASS: \(explicitChecked) explicit voicings: bass, bass-dependent range, and valid default in every root")
// Root and fifth basses may reach B-flat; thirds and sevenths retain D.
a.selectedChord="maj7(#5)"; a.selectedRoot=0; a.selectedScale=""
precondition(a.voicedChordNotes(inversion:2) == [12,16,20,23])
a.selectedRoot=10
precondition(a.voicedChordNotes(inversion:2) == [22,26,30,33])
precondition(a.leftHandFloor(bassInterval:0, intervals:[0,4,8,11], degrees:["1","3","#5","7"]) == 10)
a.selectedRoot=1
precondition(a.voicedChordNotes(inversion:2) == [13,17,21,24])
for root in 0..<12 {
    a.selectedRoot=root
    for inversion in [0,1,4] {
        if let notes=a.voicedChordNotes(inversion:inversion) {
            precondition(notes.allSatisfy { (14...33).contains($0) })
        }
    }
}
// Full upper chords remain present in the default mode, unlike slash bass chords.
a.selectedRoot=0; a.selectedScale=""; a.selectedInversion=0
a.selectedChord="V over I"
precondition(a.voicedChordNotes(inversion:0) == [12,16,19])
precondition(a.rightHandNotes == Set([31,35,38]))
a.selectedChord="II over I"
precondition(a.voicedChordNotes(inversion:0) == [12,16,19])
precondition(a.rightHandNotes == Set([26,30,33]))
a.selectedChord="V/I"
precondition(a.rightHandNotes.isEmpty)
precondition(NoteSpelling.name(root:"Db", interval:7, degree:"5") == "A♭")
precondition(NoteSpelling.name(root:"B", interval:2, degree:"2") == "C♯")
var handChecks = 0
for chord in decoded.Chords.allChords {
    a.selectedChord = chord.name
    for option in chord.HandVoicings ?? [] {
        a.selectedScale = option.name
        for root in 0..<12 {
            a.selectedRoot = root
            guard let hands = a.handVoicing(option) else { fatalError("Hand option out of range") }
            let bassDegree = option.LHDegrees[option.LHIntervals.firstIndex(of: option.LHIntervals.min()!)!]
            let bassNumber = Int(bassDegree.filter { $0.isNumber })!
            let floor = [3, 7].contains((bassNumber - 1) % 7 + 1) ? 14 : 10
            precondition(hands.left.allSatisfy { (floor...33).contains($0) })
            precondition(hands.right.min()! > hands.left.max()!)
            precondition(hands.right.allSatisfy { (0..<60).contains($0) })
            precondition(hands.left.count == option.LHIntervals.count)
            precondition(hands.right.count == option.RHIntervals.count)
            precondition(a.leftHandNotes == hands.left && a.rightHandNotes == hands.right)
            precondition(a.chordPlaybackNotes == hands.left.union(hands.right).union([root]))
            for note in hands.left.union(hands.right).union([root]) {
                precondition(pitchClass(of:a.noteName(note)) == note%12)
            }
            handChecks += 1
        }
    }
}
a.selectedRoot=0; a.selectedChord="min7"; a.selectedScale="So What"
precondition(a.leftHandNotes == Set([12,17]))
precondition(a.rightHandNotes == Set([22,27,31]))
print("PASS: \(handChecks) upper-structure / So What hand splits across all roots")
// Open worship shapes preserve their defining tones and keep the bass separate.
a.selectedRoot=0; a.selectedScale="Open"; a.selectedInversion=0
for (name, right) in [("maj", [24,28]), ("min", [24,27]), ("add9", [26,28,36]), ("sus2", [24,26]), ("sus4", [24,29]), ("sus4(add9)", [26,29,36])] {
    a.selectedChord=name
    precondition(a.leftHandNotes == Set([19]))
    precondition(a.rightHandNotes == Set(right))
    precondition(a.chordPlaybackNotes == Set(right).union([0,19]))
}
precondition(a.formulas["IV/I"]!.LHIntervals == [5,9,12])
precondition(a.formulas["ii/I"]!.LHIntervals == [2,5,9])
precondition(a.formulas["ii/I"]!.Stack!.upperQuality == "minor")
precondition(NoteSpelling.name(root:"C", interval:2, degree:"2") + "m/C" == "Dm/C")
// The original, explicitly requested substitutions still apply.
a.selectedChord="maj7"; a.selectedRoot=0; a.selectedScale="Major"
precondition(a.voicedChordNotes(inversion:1) == [16,19,21,24])
a.selectedChord="minmaj7"; a.selectedScale="Melodic Minor"
precondition(a.voicedChordNotes(inversion:1) == [15,19,21,24])
a.selectedChord="9(#11, #5)"; a.selectedScale="Whole Tone"
precondition(a.leftHandIntervals(for:a.selectedChord) == [4,8,10,14])
a.selectedScale=""
precondition(a.leftHandIntervals(for:a.selectedChord) == [4,8,10])
// Scale mode must be disabled when adding the ninth cannot fit the LH range.
a.selectedRoot=9
precondition(!a.hasValidVoicing(chord:a.selectedChord, root:9, scale:"Whole Tone"))
precondition(a.hasValidVoicing(chord:a.selectedChord, root:9, scale:""))
print("PASS: \\(checked) root/chord/inversion/scale combinations; \\(disabled) invalid voicings excluded")
print("PASS: \\(labelsChecked) displayed-note labels; highest key index \\(highest); no scale clipping or overlap")
'''
    for token, value in [('MODELS', models), ('AVAILABLE', available), ('METHODS', methods), ('LABELS', labels)]:
        harness = harness.replace(token, value)
    with tempfile.TemporaryDirectory(prefix='betterchords-scale-audit-') as directory:
        path = Path(directory) / 'audit.swift'
        path.write_text(harness)
        # Give the compiler its own writable cache rather than requiring a home-directory cache.
        env = dict(os.environ, CLANG_MODULE_CACHE_PATH=str(Path(directory) / 'module-cache'))
        subprocess.run(['swift', '-module-cache-path', str(Path(directory) / 'swift-cache'), str(path), str(JSON_PATH)], env=env, check=True)


if __name__ == '__main__':
    validate_data()
    run_swift_audit()
