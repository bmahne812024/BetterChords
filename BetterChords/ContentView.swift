
import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct ChordFormulaFile: Decodable {
    let Roots: [String: String]
    let Chords: ChordCategories
    let ChordGroups: [ChordGroup]
}

struct ChordGroup: Decodable {
    let name: String
    let triad: String
    let chords: [String]
}

struct ChordStackFormula: Decodable {
    let kind: String
    let upperInterval: Int
    let upperDegree: String
    let upperQuality: String?
}

struct ChordCategories: Decodable {
    let Triads: [ChordFormula]
    let SeventhChords: [ChordFormula]
    let Extensions: [ChordFormula]

    var allChords: [ChordFormula] {
        Triads + SeventhChords + Extensions
    }
}

struct HandVoicingFormula: Decodable {
    let name: String
    let LHIntervals: [Int]
    let LHDegrees: [String]
    let RHIntervals: [Int]
    let RHDegrees: [String]
}

struct ChordFormula: Decodable {
    let name: String
    let LHIntervals: [Int]
    let LHVoicings: [[Int]]?
    let LHVoicingLabels: [String]?
    let LHDegrees: [String]
    let LHScaleIntervals: [Int]?
    let LHScaleDegrees: [String]?
    let RHExtension: [Int]?
    let RHChordIntervals: [Int]?
    let RHChordDegrees: [String]?
    let Stack: ChordStackFormula?
    let HandVoicings: [HandVoicingFormula]?
    let RHDegrees: [String]?
    let Scales: [ScaleFormula]?
}

struct ScaleFormula: Decodable {
    let name: String
    let intervals: [Int]
    let degrees: [String]
}

enum NoteSpelling {
    static func name(root: String, interval: Int, degree: String) -> String {
        let letters = Array("CDEFGAB")
        let pitches = [0, 2, 4, 5, 7, 9, 11]
        guard let first = root.first, let rootIndex = letters.firstIndex(of: first),
              let number = Int(degree.filter(\.isNumber)), number > 0 else { return root }
        let rootAlteration = root.dropFirst().reduce(0) { value, character in
            value + ((character == "b" || character == "♭") ? -1 : ((character == "#" || character == "♯") ? 1 : 0))
        }
        let letterIndex = (rootIndex + number - 1) % 7
        let pitch = (pitches[rootIndex] + rootAlteration + interval) % 12
        var alteration = (pitch - pitches[letterIndex] + 12) % 12
        if alteration > 6 { alteration -= 12 }
        let accidental: String
        switch alteration {
        case -2: accidental = "𝄫"
        case -1: accidental = "♭"
        case 0: accidental = ""
        case 1: accidental = "♯"
        case 2: accidental = "𝄪"
        default: accidental = String(repeating: alteration < 0 ? "♭" : "♯", count: abs(alteration))
        }
        return String(letters[letterIndex]) + accidental
    }
}

struct SubstituteArrangement {
    let chord: String
    let option: String
    let inversion: Int
    let left: Set<Int>
    let right: Set<Int>
    let bass: Set<Int>
    var notes: Set<Int> { left.union(right).union(bass) }
}

struct ContentView: View {
    init(initialChord: String = "maj") {
        _selectedChord = State(initialValue: initialChord)
    }
    
    let totalNotes = 60
    private let middleCNote = 24
    
    // C# D# F# G# A#
    let blackKeyPositions: Set<Int> = [1, 3, 6, 8, 10]
    
    @State private var roots: [String] = []
    @StateObject private var chordAudio = ChordAudioPlayer()
    @Environment(\.scenePhase) private var scenePhase
    @State private var selectedRoot = 0
    @State private var rootEnabled = true
    @State private var showingSubstitutes = false
    @State private var substitutesUseTwoHands = false
    @State private var substituteOptions: [String: String] = [:]
    @State private var pendingSubstitute: SubstituteArrangement?
    @AppStorage("betterChords.bank.v1") private var savedChordData = Data()
    @State private var showingChordBank = false
    @State private var recalledBankChord: SavedChord?
    @State private var bankHistory = ChordBankHistory()
    @State private var bankUndo: [UUID: SavedChord] = [:]
    @State private var bankError: String?
    @AppStorage("betterChords.bank.library.v1") private var bankLibraryData = Data()
    @AppStorage("betterChords.bank.title") private var bankTitle = "Untitled Bank"
    @AppStorage("betterChords.bank.currentID") private var currentBankID = ""
    @State private var namingBank = false
    @State private var proposedBankTitle = ""
    @State private var openingBank = false
    @State private var importingBank = false
    @State private var exportingBank = false
    @State private var approachExpanded = false
    @State private var approachCount = 1
    @State private var approachChoice = ""
    @State private var approachPreview: [SavedChord] = []
    @State private var approachTargetID: UUID?

    @State private var selectedChord = "maj"
    @State private var selectedInversion = 0
    @State private var selectedScale = ""
    @State private var chordScales: [String: [ScaleFormula]] = [:]

    private let inversionNames = [
        "Root position", "First inversion", "Second inversion", "Third inversion", "Fourth inversion"
    ]

    private var availableInversions: Range<Int> {
        if let voicings = formulas[selectedChord]?.LHVoicings { return 0..<voicings.count }
        if selectedChord == "9" { return 0..<2 }
        return 0..<(extensionNames.contains(selectedChord) ? 1 : min(chordIntervals[selectedChord]?.count ?? 3, inversionNames.count))
    }

    @State private var chordTypes: [String] = []
    @State private var formulas: [String: ChordFormula] = [:]
    @State private var chordGroups: [ChordGroup] = []

    private var selectedGroup: ChordGroup? {
        chordGroups.first { $0.chords.contains(selectedChord) }
    }

    private func extensionLabel(_ chord: String) -> String {
        if chord == selectedGroup?.triad { return "No extension" }
        switch chord {
        case "maj7": return "Major 7"
        case "maj9": return "Major 9"
        case "min6": return "Minor 6"
        case "min6/9": return "Minor 6/9"
        case "min7": return "Minor 7"
        case "min9": return "Minor 9"
        case "minmaj7": return "Minor Major 7"
        case "minmaj9": return "Minor Major 9"
        case "dim7": return "Diminished 7"
        case "min7b5": return "Minor 7♭5"
        default:
            let label: String
            if chord.hasPrefix("maj") { label = "Major " + chord.dropFirst(3) }
            else if chord.hasPrefix("min") { label = "Minor " + chord.dropFirst(3) }
            else { label = chord }
            return label.replacingOccurrences(of: "#", with: "♯").replacingOccurrences(of: "b", with: "♭")
        }
    }
    @State private var chordIntervals: [String: [Int]] = [:]
    @State private var scaleChordIntervals: [String: [Int]] = [:]
    @State private var rightHandExtensions: [String: [Int]] = [:]
    @State private var triadNames: Set<String> = []
    @State private var extensionNames: Set<String> = []

    private var usesMajorSixSubstitution: Bool {
        selectedChord == "maj7" && selectedInversion == 1 && selectedHandFormula == nil
    }

    private var usesMinorSixSubstitution: Bool {
        selectedChord == "minmaj7" && selectedInversion == 1 && selectedHandFormula == nil
    }

    private var stackedChordNames: (upper: String, lower: String)? {
        guard let stack = formulas[selectedChord]?.Stack, roots.indices.contains(selectedRoot) else { return nil }
        let root = roots[selectedRoot]
        return (NoteSpelling.name(root: root, interval: stack.upperInterval, degree: stack.upperDegree) + (stack.upperQuality == "minor" ? "m" : ""),
                root.replacingOccurrences(of: "b", with: "♭"))
    }

    private var chordSymbol: String {
        if let names = stackedChordNames {
            return formulas[selectedChord]?.Stack?.kind == "polychord"
                ? "\(names.upper) over \(names.lower)" : "\(names.upper)/\(names.lower)"
        }
        guard roots.indices.contains(selectedRoot) else { return "" }
        let root = roots[selectedRoot].replacingOccurrences(of: "b", with: "♭")
        let suffix = selectedChord == "maj" ? "" : selectedChord
            .replacingOccurrences(of: "min", with: "m")
            .replacingOccurrences(of: "#", with: "♯")
            .replacingOccurrences(of: "b", with: "♭")
        return root + suffix
    }

    private var chordSymbolParts: (base: String, extensionText: String) {
        guard roots.indices.contains(selectedRoot) else { return ("", "") }
        let root = roots[selectedRoot].replacingOccurrences(of: "b", with: "♭")
        if selectedChord == "maj" { return (root, "") }
        if selectedChord.hasPrefix("min") {
            let extensionText = String(selectedChord.dropFirst(3))
                .replacingOccurrences(of: "b", with: "♭")
                .replacingOccurrences(of: "#", with: "♯")
            return (root + "m", extensionText)
        }
        // All remaining quality marks, extensions, and alterations are raised.
        return (root, selectedChord.replacingOccurrences(of: "#", with: "♯").replacingOccurrences(of: "b", with: "♭"))
    }

    @ViewBuilder
    private var chordSymbolView: some View {
        if let names = stackedChordNames {
            if formulas[selectedChord]?.Stack?.kind == "polychord" {
                VStack(spacing: 1) {
                    Text(names.upper)
                    Rectangle().frame(height: 2)
                    Text(names.lower)
                }
                .font(.system(size: 32, weight: .bold))
                .frame(width: 76)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chordSymbol)
            } else {
                Text(chordSymbol)
                    .font(.system(size: 48, weight: .bold))
            }
        } else if selectedChord == "minmaj7" || selectedChord == "minmaj9" {
            HStack(spacing: 5) {
                Text(roots.indices.contains(selectedRoot)
                     ? roots[selectedRoot].replacingOccurrences(of: "b", with: "♭") : "")
                    .font(.system(size: 48, weight: .bold))
                VStack(spacing: -5) {
                    Text("△")
                        .font(.system(size: 28, weight: .medium))
                    Text("−")
                        .font(.system(size: 28, weight: .medium))
                }
                if selectedChord == "minmaj9" {
                    Text("9")
                        .font(.system(size: 28, weight: .bold))
                        .offset(y: -12)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chordSymbol)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(chordSymbolParts.base)
                    .font(.system(size: 48, weight: .bold))
                if !chordSymbolParts.extensionText.isEmpty {
                    Text(chordSymbolParts.extensionText)
                        .font(.system(size: 28, weight: .bold))
                        .baselineOffset(18)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chordSymbol)
        }
    }

    private func leftHandIntervals(for chord: String, scale: String? = nil) -> [Int] {
        let scaleName = scale ?? selectedScale
        if !scaleName.isEmpty,
           (chordScales[chord] ?? []).contains(where: { $0.name == scaleName }),
           let intervals = scaleChordIntervals[chord] {
            return intervals
        }
        return chordIntervals[chord] ?? []
    }

    private func leftHandFloor(bassInterval: Int, intervals: [Int], degrees: [String]) -> Int {
        let pitch = (bassInterval % 12 + 12) % 12
        let degree = zip(intervals, degrees).first { ($0.0 % 12 + 12) % 12 == pitch }?.1
        let number = degree.flatMap { Int($0.filter(\.isNumber)) }
        let startsOnThirdOrSeventh = number.map { [3, 7].contains(($0 - 1) % 7 + 1) } ?? false
        return startsOnThirdOrSeventh ? 14 : 10 // D3 or B♭2; upper limit stays A4.
    }

    private func voicedChordNotes(inversion: Int, chord: String? = nil, root: Int? = nil, scale: String? = nil) -> [Int]? {
        let selectedChord = chord ?? self.selectedChord
        let selectedRoot = root ?? self.selectedRoot
        let formulaName: String
        if inversion == 1 && selectedChord == "maj7" {
            formulaName = "6"
        } else if inversion == 1 && selectedChord == "minmaj7" {
            formulaName = "min6"
        } else {
            formulaName = selectedChord
        }
        let intervals: [Int]
        let bassInterval: Int
        if let voicings = formulas[formulaName]?.LHVoicings {
            guard voicings.indices.contains(inversion), !voicings[inversion].isEmpty else { return nil }
            intervals = voicings[inversion].sorted()
            bassInterval = intervals[0]
        } else {
            intervals = leftHandIntervals(for: formulaName, scale: scale).sorted()
            guard !intervals.isEmpty, intervals.indices.contains(inversion) else { return nil }
            bassInterval = intervals[inversion]
        }
        let bassNote = middleCNote + selectedRoot + bassInterval
        var notes = intervals.map { interval in
            bassNote + ((interval - bassInterval) % 12 + 12) % 12
        }.sorted()

        // Keep triads low, with their bass in the second octave.
        if triadNames.contains(selectedChord) || formulas[selectedChord]?.Stack?.kind == "polychord" {
            while notes.first! >= 24 { notes = notes.map { $0 - 12 } }
            while notes.first! < 12 { notes = notes.map { $0 + 12 } }
        }

        let formula = formulas[formulaName]
        let lowestAllowed = leftHandFloor(bassInterval: bassInterval,
                                          intervals: formula?.LHIntervals ?? [],
                                          degrees: formula?.LHDegrees ?? [])
        // Third/seventh basses stay in D–A; other basses may reach B♭ below D.
        while notes.last! > 33 { notes = notes.map { $0 - 12 } }
        while notes.first! < lowestAllowed {
            notes = notes.map { $0 + 12 }
        }
        guard notes.last! <= 33 else { return nil }
        return notes
    }

    private func hasValidVoicing(chord: String, root: Int, scale: String? = nil) -> Bool {
        let count = formulas[chord]?.LHVoicings?.count ?? (chord == "9" ? 2 : (extensionNames.contains(chord) ? 1 : min(chordIntervals[chord]?.count ?? 0, inversionNames.count)))
        return (0..<count).contains { voicedChordNotes(inversion: $0, chord: chord, root: root, scale: scale) != nil }
    }

    private func selectValidInversion() {
        selectedInversion = availableInversions.first {
            voicedChordNotes(inversion: $0) != nil
        } ?? 0
    }

    private var dropOptions: [String] {
        triadNames.contains(selectedChord)
            ? ["Drop 2", "Drop 3"]
            : ["Drop 2", "Drop 3", "Drop 2 & 3"]
    }

    private var dropPositions: [Int] {
        switch selectedScale {
        case "Drop 2": return [2]
        case "Drop 3": return [3]
        case "Drop 2 & 3": return [2, 3]
        default: return []
        }
    }

    private var dropVoicing: (left: Set<Int>, right: Set<Int>)? {
        guard let closeNotes = voicedChordNotes(inversion: selectedInversion) else { return nil }
        return makeDropVoicing(notes: closeNotes, positions: dropPositions, chord: selectedChord, root: selectedRoot)
    }

    private func makeDropVoicing(notes closeNotes: [Int], positions: [Int], chord: String, root: Int) -> (left: Set<Int>, right: Set<Int>)? {
        guard !positions.isEmpty, closeNotes.count >= (positions.max() ?? 0) else { return nil }
        // Raise the close voicing one octave, then drop the requested voices.
        // Count from the top of the original voicing for combined drops.
        let upperNotes = closeNotes.map { $0 + 12 }
        let droppedIndices = Set(positions.map { upperNotes.count - $0 })
        let left = Set(droppedIndices.map { upperNotes[$0] - 12 })
        let right = Set(upperNotes.indices.filter { !droppedIndices.contains($0) }.map { upperNotes[$0] })
        guard left.union(right).allSatisfy({ (0..<totalNotes).contains($0) }) else { return nil }
        return boundedHandVoicing(left: left, right: right, chord: chord, root: root)
    }

    private func boundedHandVoicing(left: Set<Int>, right: Set<Int>, chord: String? = nil, root: Int? = nil) -> (left: Set<Int>, right: Set<Int>)? {
        let selectedChord = chord ?? self.selectedChord
        let selectedRoot = root ?? self.selectedRoot
        guard let bass = left.min(), let top = left.max(), let formula = formulas[selectedChord] else { return nil }
        let floor = leftHandFloor(bassInterval: bass - selectedRoot,
                                  intervals: formula.LHIntervals, degrees: formula.LHDegrees)
        var shift = 0
        while top + shift > 33 { shift -= 12 }
        while bass + shift < floor { shift += 12 }
        let adjustedLeft = Set(left.map { $0 + shift })
        let adjustedRight = Set(right.map { $0 + shift })
        guard adjustedLeft.allSatisfy({ (floor...33).contains($0) }),
              adjustedRight.allSatisfy({ (0..<totalNotes).contains($0) }) else { return nil }
        return (adjustedLeft, adjustedRight)
    }

    private func shellVoicing(inversion: Int, chord: String? = nil, root: Int? = nil) -> (left: Set<Int>, right: Set<Int>)? {
        let selectedChord = chord ?? self.selectedChord
        let selectedRoot = root ?? self.selectedRoot
        guard let intervals = chordIntervals[selectedChord],
              let notes = voicedChordNotes(inversion: inversion, chord: selectedChord, root: selectedRoot, scale: ""),
              let bottom = notes.first, let top = notes.last else { return nil }
        if ["9", "13", "9(13)", "13(9)"].contains(selectedChord) {
            let left = Set([selectedRoot, selectedRoot + 10])
            let right = Set(notes)
            // Keep the existing chord register and lower the shell one octave.
            // Disable combinations whose hands would overlap.
            guard left.max()! < bottom else { return nil }
            return boundedHandVoicing(left: left, right: right, chord: selectedChord, root: selectedRoot)
        }
        let left: Set<Int>
        if intervals.first == 0 {
            // Traditional chords use only their root-position outer voices.
            guard inversion == 0 else { return nil }
            left = Set([bottom, top])
        } else {
            // Rootless voicings retain their actual seventh (major or minor).
            guard let seventh = intervals.first(where: { [10, 11].contains($0 % 12) }) else { return nil }
            var rootNote = 12 + selectedRoot
            while rootNote + seventh % 12 > 33 { rootNote -= 12 }
            left = Set([rootNote, rootNote + seventh % 12])
        }
        var right = notes.map { $0 + 12 }
        // Keep the complete RH voicing strictly above the shell.
        while right.min()! <= left.max()! { right = right.map { $0 + 12 } }
        guard left.union(right).allSatisfy({ (0..<totalNotes).contains($0) }) else { return nil }
        return boundedHandVoicing(left: left, right: Set(right), chord: selectedChord, root: selectedRoot)
    }

    private var selectedShell: (left: Set<Int>, right: Set<Int>)? {
        selectedScale == "LH Shell" ? shellVoicing(inversion: selectedInversion) : nil
    }

    private var selectedHandFormula: HandVoicingFormula? {
        formulas[selectedChord]?.HandVoicings?.first { $0.name == selectedScale }
    }

    private func handVoicing(_ formula: HandVoicingFormula) -> (left: Set<Int>, right: Set<Int>)? {
        guard let bassInterval = formula.LHIntervals.min() else { return nil }
        let lowestAllowed = leftHandFloor(bassInterval: bassInterval,
                                          intervals: formula.LHIntervals, degrees: formula.LHDegrees)
        var anchor = 12 + selectedRoot
        var left = formula.LHIntervals.map { anchor + $0 }
        while left.max()! > 33 { anchor -= 12; left = formula.LHIntervals.map { anchor + $0 } }
        while left.min()! < lowestAllowed { anchor += 12; left = formula.LHIntervals.map { anchor + $0 } }
        guard left.allSatisfy({ (lowestAllowed...33).contains($0) }) else { return nil }
        var right = formula.RHIntervals.map { anchor + $0 }
        while right.min()! <= left.max()! { right = right.map { $0 + 12 } }
        guard right.allSatisfy({ (0..<totalNotes).contains($0) }) else { return nil }
        return (Set(left), Set(right))
    }

    private var selectedHandVoicing: (left: Set<Int>, right: Set<Int>)? {
        guard let formula = selectedHandFormula else { return nil }
        return handVoicing(formula)
    }

    private var activeBankVoicing: SavedChord? {
        guard let saved = recalledBankChord, saved.root == selectedRoot,
              saved.chord == selectedChord, saved.inversion == selectedInversion,
              saved.option == selectedScale else { return nil }
        return saved
    }

    private var leftHandNotes: Set<Int> {
        if let saved = activeBankVoicing { return saved.left }
        if let selectedHandVoicing { return selectedHandVoicing.left }
        if let selectedShell { return selectedShell.left }
        if let dropVoicing { return dropVoicing.left }
        return Set(voicedChordNotes(inversion: selectedInversion) ?? [])
    }

    private var selectedChordNotes: Set<Int> {
        rootEnabled ? leftHandNotes.union([selectedRoot]) : leftHandNotes.subtracting([selectedRoot])
    }

    private var chordPlaybackNotes: Set<Int> {
        if let saved = activeBankVoicing {
            return saved.left.union(saved.right).union(rootEnabled ? [selectedRoot] : [])
        }
        let isScale = (chordScales[selectedChord] ?? []).contains { $0.name == selectedScale }
        return selectedChordNotes.union(isScale ? [] : rightHandNotes)
    }

    private func coreRightHandNotes(inversion: Int, chord: String? = nil, root: Int? = nil) -> Set<Int> {
        let selectedChord = chord ?? self.selectedChord
        let selectedRoot = root ?? self.selectedRoot
        guard let formula = formulas[selectedChord],
              let intervals = formula.RHChordIntervals, !intervals.isEmpty,
              let left = voicedChordNotes(inversion: inversion, chord: selectedChord, root: selectedRoot, scale: ""),
              let bass = left.first, let highest = left.last else { return [] }
        let bassInterval = formula.LHVoicings?[inversion].first ?? formula.LHIntervals[inversion]
        let voicedRoot = bass - bassInterval
        var notes = intervals.map { voicedRoot + $0 }
        while notes.min()! <= highest { notes = notes.map { $0 + 12 } }
        guard notes.allSatisfy({ (0..<totalNotes).contains($0) }) else { return [] }
        return Set(notes)
    }

    private var rightHandNotes: Set<Int> {
        if let saved = activeBankVoicing { return saved.right }
        if let selectedHandVoicing { return selectedHandVoicing.right }
        if (chordScales[selectedChord] ?? []).contains(where: { $0.name == selectedScale }) {
            return scaleNotes
        }
        return additionalRightHandNotes.union(coreRightHandNotes(inversion: selectedInversion))
    }

    private var additionalRightHandNotes: Set<Int> {
        if selectedScale == "Double" {
            return Set((voicedChordNotes(inversion: selectedInversion) ?? []).map { $0 + 12 })
        }
        if let selectedShell { return selectedShell.right }
        if let dropVoicing { return dropVoicing.right }
        if selectedScale.isEmpty { return [] }
        if selectedScale != "Right hand extension" { return scaleNotes }
        guard let extensions = rightHandExtensions[selectedChord],
              let bass = voicedChordNotes(inversion: selectedInversion)?.first else { return [] }
        let intervals = (chordIntervals[selectedChord] ?? []).sorted()
        let bassInterval: Int
        if let voicings = formulas[selectedChord]?.LHVoicings,
           voicings.indices.contains(selectedInversion), let first = voicings[selectedInversion].first {
            bassInterval = first
        } else {
            guard intervals.indices.contains(selectedInversion) else { return [] }
            bassInterval = intervals[selectedInversion]
        }
        var voicedRoot = bass - bassInterval
        if extensionNames.contains(selectedChord), let highestInterval = intervals.max() {
            voicedRoot = middleCNote + selectedRoot
            while voicedRoot + highestInterval > 33 { voicedRoot -= 12 }
        }
        guard let highestLeft = voicedChordNotes(inversion: selectedInversion)?.max(), !extensions.isEmpty else { return [] }
        var notes = extensions.map { voicedRoot + $0 }
        while notes.min()! <= highestLeft { notes = notes.map { $0 + 12 } }
        while notes.max()! >= totalNotes && notes.min()! - 12 > highestLeft {
            notes = notes.map { $0 - 12 }
        }
        guard notes.allSatisfy({ (0..<totalNotes).contains($0) }) else { return [] }
        return Set(notes)
    }

    private var scaleNotes: Set<Int> {
        guard let scale = chordScales[selectedChord]?.first(where: { $0.name == selectedScale }),
              let highestInterval = leftHandIntervals(for: selectedChord).max(),
              let highestChordNote = voicedChordNotes(inversion: selectedInversion)?.max(),
              !scale.intervals.isEmpty else { return [] }
        var voicedRoot: Int
        if triadNames.contains(selectedChord) {
            voicedRoot = selectedRoot
            while voicedRoot <= highestChordNote { voicedRoot += 12 }
            voicedRoot -= 12
        } else {
            voicedRoot = middleCNote + selectedRoot
            while voicedRoot + highestInterval > 33 { voicedRoot -= 12 }
        }
        var notes = scale.intervals.map { voicedRoot + $0 }
        // Preserve the entire scale and its spacing; move only by whole octaves.
        while notes.min()! <= highestChordNote { notes = notes.map { $0 + 12 } }
        while notes.max()! >= totalNotes && notes.min()! - 12 > highestChordNote {
            notes = notes.map { $0 - 12 }
        }
        guard notes.allSatisfy({ (0..<totalNotes).contains($0) }) else { return [] }
        return Set(notes)
    }

    private func defaultScale(for chord: String) -> String {
        return ""
    }

    private var emptyRightHandLabel: String {
        (formulas[selectedChord]?.RHChordIntervals ?? []).isEmpty ? "RH" : "Upper chord"
    }

    private var rightHandLabel: String {
        if selectedScale.isEmpty { return emptyRightHandLabel }
        guard (chordScales[selectedChord] ?? []).contains(where: { $0.name == selectedScale }) else {
            return selectedScale
        }
        // Keep long scale names readable in the single-row controls.
        let name: String
        switch selectedScale {
        case "Whole-Half Diminished": name = "Whole–Half Dim."
        case "half-whole diminished": name = "Half–Whole Dim."
        case "Locrian Natural 2": name = "Locrian ♮2"
        case "Locrian Natural 6": name = "Locrian ♮6"
        case "Melodic Minor Bebop": name = "Melodic Min. Bebop"
        default: name = selectedScale
        }
        return "Scale: " + name
    }

    private func highlightedColor(_ note: Int) -> Color {
        let color: Color
        if leftHandNotes.contains(note) {
            color = .blue
        } else if note == selectedRoot {
            color = .green
        } else if rightHandNotes.contains(note) {
            color = .purple
        } else {
            color = .blue
        }
        guard isBlackKey(note) else { return color }
        if leftHandNotes.contains(note) { return Color(red: 0.0, green: 0.26, blue: 0.52) }
        if note == selectedRoot { return Color(red: 0.09, green: 0.44, blue: 0.20) }
        if rightHandNotes.contains(note) { return Color(red: 0.34, green: 0.12, blue: 0.44) }
        return Color(red: 0.0, green: 0.26, blue: 0.52)
    }

    private func inversionLabel(_ inversion: Int) -> String {
        if let labels = formulas[selectedChord]?.LHVoicingLabels, labels.indices.contains(inversion) {
            return labels[inversion]
        }
        if selectedChord == "min6/9" { return inversion == 0 ? "Built from 3rd" : "Built from 6th" }
        if selectedChord == "9" && inversion == 0 { return "Built from 3rd" }
        if selectedChord == "9" && inversion == 1 { return "Built from 7th" }
        if (selectedChord == "13" || selectedChord == "13(9)") && inversion == 0 {
            return "Built from 7th"
        }
        return inversionNames[inversion]
    }

    private var inversionMenu: some View {
        Menu {
            if activeBankVoicing != nil {
                Button("Return to preset voicing") { recalledBankChord = nil; selectValidInversion() }
            }
            ForEach(availableInversions, id: \.self) { inversion in
                let isAvailable = voicedChordNotes(inversion: inversion) != nil
                Button {
                    guard isAvailable else { return }
                    selectedInversion = inversion
                } label: {
                    if selectedInversion == inversion {
                        Label(inversionLabel(inversion), systemImage: "checkmark")
                    } else {
                        Text(inversionLabel(inversion))
                    }
                }
                .disabled(!isAvailable)
            }
        } label: {
            HStack(spacing: 8) {
                Text(activeBankVoicing != nil ? "Saved voicing" : selectedHandFormula == nil ? inversionLabel(selectedInversion) : "Fixed voicing")
                    .font(.system(size: 22, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .disabled(selectedHandFormula != nil)
        .accessibilityLabel("Inversion")
    }

    private func noteName(_ note: Int) -> String {
        let root = roots[selectedRoot]
        if let formula = selectedHandFormula, let hands = selectedHandVoicing {
            let intervals = hands.left.contains(note) ? formula.LHIntervals : formula.RHIntervals
            let degrees = hands.left.contains(note) ? formula.LHDegrees : formula.RHDegrees
            if let index = intervals.firstIndex(where: { $0 % 12 == (note - selectedRoot + 12) % 12 }) {
                return NoteSpelling.name(root: root, interval: intervals[index], degree: degrees[index])
            }
        }
        if note % 12 == selectedRoot { return NoteSpelling.name(root: root, interval: 0, degree: "1") }
        if selectedScale == "LH Shell", selectedShell?.left.contains(note) == true {
            let pitch = (note - selectedRoot + 12) % 12
            if pitch == 0 { return NoteSpelling.name(root: root, interval: 0, degree: "1") }
            if pitch == 10 { return NoteSpelling.name(root: root, interval: 10, degree: "b7") }
            if pitch == 11 { return NoteSpelling.name(root: root, interval: 11, degree: "7") }
        }
        let pitchClass = (note - selectedRoot + 12) % 12
        func spell(_ intervals: [Int], _ degrees: [String]) -> String? {
            guard let index = intervals.firstIndex(where: { $0 % 12 == pitchClass }),
                  degrees.indices.contains(index) else { return nil }
            return NoteSpelling.name(root: root, interval: intervals[index], degree: degrees[index])
        }
        if rightHandNotes.contains(note) {
            if let formula = formulas[selectedChord],
               !(chordScales[selectedChord] ?? []).contains(where: { $0.name == selectedScale }),
               let name = spell(formula.RHChordIntervals ?? [], formula.RHChordDegrees ?? []) { return name }
            if let scale = chordScales[selectedChord]?.first(where: { $0.name == selectedScale }),
               let name = spell(scale.intervals, scale.degrees) { return name }
            if selectedScale == "Right hand extension", let formula = formulas[selectedChord],
               let name = spell(formula.RHExtension ?? [], formula.RHDegrees ?? []) { return name }
        }
        let name = usesMajorSixSubstitution ? "6" : (usesMinorSixSubstitution ? "min6" : selectedChord)
        if let formula = formulas[name] {
            let usesScale = !selectedScale.isEmpty && (formula.Scales ?? []).contains(where: { $0.name == selectedScale })
            let intervals = usesScale ? (formula.LHScaleIntervals ?? formula.LHIntervals) : formula.LHIntervals
            let degrees = usesScale ? (formula.LHScaleDegrees ?? formula.LHDegrees) : formula.LHDegrees
            if let name = spell(intervals, degrees) { return name }
        }
        return roots[note % 12]
    }

    private var rightHandMenu: some View {
        Menu {
            if activeBankVoicing != nil {
                Button("Return to preset voicing") { recalledBankChord = nil; selectValidInversion() }
            }
            Button {
                selectedScale = ""
            } label: {
                if selectedScale.isEmpty {
                    Label(emptyRightHandLabel, systemImage: "checkmark")
                } else {
                    Text(emptyRightHandLabel)
                }
            }
            Section("Voicings") {
                ForEach(formulas[selectedChord]?.HandVoicings ?? [], id: \.name) { option in
                    Button {
                        selectedScale = option.name
                    } label: {
                        if selectedScale == option.name {
                            Label(option.name, systemImage: "checkmark")
                        } else {
                            Text(option.name)
                        }
                    }
                    .disabled(handVoicing(option) == nil)
                }
                Button {
                    selectedScale = "Double"
                } label: {
                    if selectedScale == "Double" {
                        Label("Double", systemImage: "checkmark")
                    } else {
                        Text("Double")
                    }
                }
                Button {
                    selectedScale = "LH Shell"
                } label: {
                    if selectedScale == "LH Shell" {
                        Label("LH Shell", systemImage: "checkmark")
                    } else {
                        Text("LH Shell")
                    }
                }
                .disabled(shellVoicing(inversion: selectedInversion) == nil)
                ForEach(dropOptions, id: \.self) { option in
                    Button {
                        selectedScale = option
                    } label: {
                        if selectedScale == option {
                            Label(option, systemImage: "checkmark")
                        } else {
                            Text(option)
                        }
                    }
                }
            }
            if !(rightHandExtensions[selectedChord] ?? []).isEmpty {
                Section("Extensions") {
                    Button {
                        selectedScale = "Right hand extension"
                    } label: {
                        if selectedScale == "Right hand extension" {
                            Label("Right hand extension", systemImage: "checkmark")
                        } else {
                            Text("Right hand extension")
                        }
                    }
                }
            }
            if !(chordScales[selectedChord] ?? []).isEmpty {
                Section("Scales") {
                    ForEach(chordScales[selectedChord] ?? [], id: \.name) { scale in
                        let isAvailable = hasValidVoicing(chord: selectedChord, root: selectedRoot, scale: scale.name)
                        Button {
                            guard isAvailable else { return }
                            selectedScale = scale.name
                        } label: {
                            if selectedScale == scale.name {
                                Label(scale.name, systemImage: "checkmark")
                            } else {
                                Text(scale.name)
                            }
                        }
                        .disabled(!isAvailable)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(rightHandLabel)
                    .font(.system(size: 22, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .tint(.purple)
        .accessibilityLabel("Right hand")
        .accessibilityValue((chordScales[selectedChord] ?? []).contains(where: { $0.name == selectedScale }) ? "Scale: " + selectedScale : (selectedScale.isEmpty ? emptyRightHandLabel : selectedScale))
    }

    private var substituteChoices: [(chord: String, reason: String, notes: Set<Int>)] {
        let families: [[String]] = [
            ["6/9", "maj9", "maj7", "maj13", "6", "add9", "maj", "maj7(#11)", "maj9(#11)"],
            ["min9", "min11", "min7", "min13", "min(add9)", "min"],
            ["min6", "min6/9", "minmaj7", "minmaj9"],
            ["9", "13", "7", "13(9)", "9(13)", "7(#11)", "9(#11)", "13(#11)"],
            ["7(#9)", "7(b9)", "7(#9, #5)", "7(b9, b5)", "7alt", "7(b9, #5)", "7(#9, #11)", "13(b9)", "7(b13)", "9(b13)", "7(#5)", "7(b5)", "9(#5)", "9(#11, #5)"],
            ["min7b5", "min9b5", "min11b5"],
            ["sus4", "sus4(add9)", "7sus4", "9sus4", "13sus4"],
            ["aug", "maj7(#5)"], ["dim", "dim7"]
        ]
        guard let family = families.first(where: { $0.contains(selectedChord) }) else { return [] }
        return family.filter { $0 != selectedChord }.compactMap { chord -> (chord: String, reason: String, notes: Set<Int>)? in
            guard hasValidVoicing(chord: chord, root: selectedRoot, scale: "") else { return nil }
            let count = formulas[chord]?.LHVoicings?.count ?? (chord == "9" ? 2 : (extensionNames.contains(chord) ? 1 : min(chordIntervals[chord]?.count ?? 0, inversionNames.count)))
            let voicings = (0..<count).compactMap { voicedChordNotes(inversion: $0, chord: chord, scale: "") }
            guard let notes = voicings.first else { return nil }
            let pitches = rootEnabled ? Set(notes).union([selectedRoot]) : Set(notes).subtracting([selectedRoot])
            return (chord, substituteReason(chord), pitches)
        }.prefix(3).map { $0 }
    }

    private func substituteArrangements(for chord: String, twoHands: Bool) -> [SubstituteArrangement] {
        guard let formula = formulas[chord] else { return [] }
        let count = formula.LHVoicings?.count ?? (chord == "9" ? 2 : (extensionNames.contains(chord) ? 1 : min(formula.LHIntervals.count, inversionNames.count)))
        let options = twoHands
            ? (triadNames.contains(chord) ? [] : ["Drop 2 & 3"]) + ["Drop 2", "Drop 3", "LH Shell", "Double"] + (formula.HandVoicings ?? []).map(\.name)
            : [""]
        return options.compactMap { option in
            for inversion in 0..<count {
                guard let close = voicedChordNotes(inversion: inversion, chord: chord, scale: "") else { continue }
                let core = coreRightHandNotes(inversion: inversion, chord: chord)
                let hands: (left: Set<Int>, right: Set<Int>)?
                if let custom = formula.HandVoicings?.first(where: { $0.name == option }) {
                    hands = handVoicing(custom)
                } else {
                    switch option {
                    case "": hands = (Set(close), core)
                    case "Double": hands = (Set(close), Set(close.map { $0 + 12 }).union(core))
                    case "LH Shell":
                        if let shell = shellVoicing(inversion: inversion, chord: chord) {
                            hands = (shell.left, shell.right.union(core))
                        } else { hands = nil }
                    default:
                        let positions = option == "Drop 2" ? [2] : option == "Drop 3" ? [3] : [2, 3]
                        if let drop = makeDropVoicing(notes: close, positions: positions, chord: chord, root: selectedRoot) {
                            hands = (drop.left, drop.right.union(core))
                        } else { hands = nil }
                    }
                }
                guard let hands, !hands.left.isEmpty,
                      twoHands == !hands.right.isEmpty,
                      hands.left.union(hands.right).allSatisfy({ (0..<totalNotes).contains($0) }) else { continue }
                let left = rootEnabled ? hands.left : hands.left.subtracting([selectedRoot])
                return SubstituteArrangement(chord: chord, option: option, inversion: inversion,
                                             left: left, right: hands.right,
                                             bass: rootEnabled ? [selectedRoot] : [])
            }
            return nil
        }
    }

    private func substituteReason(_ chord: String) -> String {
        if chord == "aug" || chord == "dim" { return "A simpler triad; leaves out the seventh." }
        if chord == "maj7(#5)" { return "Adds a major seventh to the augmented triad." }
        if chord == "dim7" { return "Adds a diminished seventh for more tension." }
        if chord.contains("#11") { return "A brighter raised-eleventh color." }
        if chord.contains("alt") || chord.contains("b9") || chord.contains("#9") || chord.contains("b13") || chord.contains("#5") || chord.contains("b5") {
            return "An alternative tension color; check against the melody."
        }
        if chord.contains("13") { return "A fuller thirteenth color." }
        if chord.contains("11") { return "An open eleventh color." }
        if chord == "6" || chord == "min6" || chord.contains("6/9") { return "A softer sixth-based color; changes the seventh sound." }
        if chord.contains("9") { return "Adds or changes the ninth color." }
        if chord.contains("maj7") { return "A major-seventh color; check against the melody." }
        if chord.contains("7") { return "A simpler seventh-chord color." }
        return "A simpler version of the same chord family."
    }

    private func substituteSymbol(_ chord: String) -> String {
        let root = roots.indices.contains(selectedRoot) ? roots[selectedRoot].replacingOccurrences(of: "b", with: "♭") : ""
        let suffix = chord == "maj" ? "" : chord == "min" ? "m" : chord.replacingOccurrences(of: "min", with: "m")
        return root + suffix.replacingOccurrences(of: "#", with: "♯").replacingOccurrences(of: "b", with: "♭")
    }

    private func substituteKeyboard(_ arrangement: SubstituteArrangement) -> some View {
        let notes = arrangement.notes
        let first = ((notes.min() ?? 12) / 12) * 12
        let highestNote: Int = notes.max() ?? 24
        let lastOctave: Int = (highestNote / 12 + 1) * 12 - 1
        let desiredLast: Int = max(first + 23, lastOctave)
        let last: Int = min(totalNotes - 1, desiredLast)
        let whites = (first...last).filter { !isBlackKey($0) }
        return GeometryReader { geometry in
            let width = geometry.size.width / CGFloat(whites.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whites, id: \.self) { note in
                        Rectangle().fill(substituteKeyColor(note, arrangement: arrangement, unselected: .white))
                            .overlay(Rectangle().stroke(.black, lineWidth: 0.5))
                            .frame(width: width)
                    }
                }
                ForEach((first...last).filter { isBlackKey($0) }, id: \.self) { note in
                    Rectangle().fill(substituteKeyColor(note, arrangement: arrangement, unselected: .black))
                        .frame(width: width * 0.65, height: geometry.size.height * 0.62)
                        .offset(x: CGFloat(whites.filter { $0 < note }.count) * width - width * 0.325)
                }
            }
        }
        .frame(height: 56)
        .accessibilityLabel("Keyboard preview")
        .accessibilityValue("Left hand: \(arrangement.left.count) notes. Right hand: \(arrangement.right.count) notes. Bass root \(arrangement.bass.isEmpty ? "off" : "on").")
    }

    private func substituteKeyColor(_ note: Int, arrangement: SubstituteArrangement, unselected: Color) -> Color {
        if arrangement.left.contains(note) { return .blue }
        if arrangement.bass.contains(note) { return .green }
        if arrangement.right.contains(note) { return .purple }
        return unselected
    }

    private func substituteCard(chord: String) -> some View {
        let arrangements = substituteArrangements(for: chord, twoHands: substitutesUseTwoHands)
        let arrangement = arrangements.first(where: { $0.option == substituteOptions[chord] }) ?? arrangements.first
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(substituteSymbol(chord)).font(.title3.bold())
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                if let arrangement, substitutesUseTwoHands {
                    Picker("Arrangement", selection: Binding(
                        get: { arrangement.option },
                        set: { chordAudio.stop(); substituteOptions[chord] = $0 }
                    )) {
                        ForEach(arrangements, id: \.option) { item in Text(item.option).tag(item.option) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityLabel("Arrangement for " + substituteSymbol(chord))
                }
            }
            if let arrangement {
                substituteKeyboard(arrangement)
                HStack {
                    Button { chordAudio.play(keyIndices: arrangement.notes) } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .accessibilityLabel("Play " + substituteSymbol(chord) + " " + (substitutesUseTwoHands ? arrangement.option : "left hand"))
                    Spacer()
                    Button("Use") {
                        chordAudio.stop()
                        recalledBankChord = nil
                        pendingSubstitute = arrangement
                        selectedChord = arrangement.chord
                        showingSubstitutes = false
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Use " + substituteSymbol(chord))
                }
            } else {
                Text("No valid arrangement in this range.").foregroundStyle(.secondary)
            }
        }
        .padding(12).frame(width: 260)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var substitutesSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Voicing", selection: $substitutesUseTwoHands) {
                    Text("Left hand").tag(false)
                    Text("Two hands").tag(true)
                }
                .pickerStyle(.segmented)
                .onChange(of: substitutesUseTwoHands) { _, _ in chordAudio.stop() }
                if substituteChoices.isEmpty {
                    Text("No same-root suggestions are available for this chord yet.")
                        .foregroundStyle(.secondary)
                }
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(substituteChoices, id: \.chord) { choice in
                            substituteCard(chord: choice.chord)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            .padding(12)
            .frame(maxHeight: .infinity, alignment: .top)
            .navigationTitle("Substitutes for " + chordSymbol)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingSubstitutes = false } } }
        }
        .preferredColorScheme(.dark)
    }

    private var savedChords: [SavedChord] {
        (try? JSONDecoder().decode([SavedChord].self, from: savedChordData)) ?? []
    }

    @discardableResult
    private func writeChordBank(_ chords: [SavedChord], recordHistory: Bool = true) -> Bool {
        do {
            if !savedChordData.isEmpty { _ = try JSONDecoder().decode([SavedChord].self, from: savedChordData) }
            let previous = savedChords
            let encoded = try JSONEncoder().encode(chords)
            savedChordData = encoded
            if recordHistory { bankHistory.record(before: previous, after: chords) }
            return true
        } catch {
            bankError = "Couldn’t save the chord bank. Your previous saved data has been kept."
            return false
        }
    }

    private func restoreBankHistory(redo: Bool) {
        var history = bankHistory
        let restored = redo ? history.redo(current: savedChords) : history.undo(current: savedChords)
        guard let restored, writeChordBank(restored, recordHistory: false) else { return }
        chordAudio.stop()
        bankHistory = history
        bankUndo = [:]
        approachPreview = []; approachExpanded = false
    }

    private func saveCurrentChord() {
        guard formulas[selectedChord] != nil else { return }
        showingChordBank = true
        let saved = SavedChord(title: chordSymbol, root: selectedRoot, chord: selectedChord,
                               inversion: selectedInversion, option: selectedScale, rootEnabled: rootEnabled,
                               left: leftHandNotes.intersection(chordPlaybackNotes),
                               right: rightHandNotes.intersection(chordPlaybackNotes),
                               voiceLed: activeBankVoicing?.voiceLed ?? false,
                               movementSummary: activeBankVoicing?.movementSummary)
        guard !saved.left.isEmpty else { bankError = "Select a chord voicing before saving."; return }
        if writeChordBank(savedChords + [saved]) { showingChordBank = true }
    }

    private func recallChord(_ saved: SavedChord) {
        guard formulas[saved.chord] != nil, (0..<12).contains(saved.root),
              saved.notes.allSatisfy({ (0..<totalNotes).contains($0) }) else {
            bankError = "This saved chord is unavailable."; return
        }
        chordAudio.stop()
        pendingSubstitute = nil
        selectedRoot = saved.root
        selectedChord = saved.chord
        selectedInversion = saved.inversion
        selectedScale = saved.option
        rootEnabled = saved.rootEnabled
        recalledBankChord = saved
        showingChordBank = false
    }

    private func voiceLeadChord(at index: Int) {
        var chords = savedChords
        guard index > 0, chords.indices.contains(index), let formula = formulas[chords[index].chord] else { return }
        let target = chords[index]
        let hand = formula.HandVoicings?.first { $0.name == target.option }
        guard let adjusted = ChordVoiceLeading.lead(from: chords[index - 1], to: target,
                                                    intervals: hand?.LHIntervals ?? formula.LHIntervals,
                                                    degrees: hand?.LHDegrees ?? formula.LHDegrees) else {
            bankError = "No voice leading fits this hand split and range. The saved chord is unchanged."; return
        }
        chords[index] = adjusted
        if writeChordBank(chords) { bankUndo[target.id] = target }
    }

    private func undoVoiceLeading(_ saved: SavedChord) {
        var chords = savedChords
        guard let index = chords.firstIndex(where: { $0.id == saved.id }), let previous = bankUndo[saved.id] else { return }
        chords[index] = previous
        if writeChordBank(chords) { bankUndo[saved.id] = nil }
    }

    private func moveSavedChord(_ saved: SavedChord, by offset: Int) {
        var chords = savedChords
        guard let index = chords.firstIndex(where: { $0.id == saved.id }), chords.indices.contains(index + offset) else { return }
        chords.swapAt(index, index + offset)
        writeChordBank(chords)
    }

    private var bankLibrary: [ChordBankFile] {
        ((try? JSONDecoder().decode([ChordBankFile].self, from: bankLibraryData)) ?? [])
            .sorted { $0.modified > $1.modified }
    }

    private var currentBankFile: ChordBankFile {
        ChordBankFile(id: UUID(uuidString: currentBankID) ?? UUID(), title: bankTitle, chords: savedChords)
    }

    @discardableResult
    private func storeBank(_ bank: ChordBankFile) -> Bool {
        do {
            var library = bankLibraryData.isEmpty ? [] : try JSONDecoder().decode([ChordBankFile].self, from: bankLibraryData)
            library.removeAll { $0.id == bank.id }
            library.insert(bank, at: 0)
            bankLibraryData = try JSONEncoder().encode(library)
            return true
        } catch { bankError = "Couldn’t save the bank library. Previous banks have been kept."; return false }
    }

    private func saveNamedBank(asNew: Bool) {
        let title = asNew ? proposedBankTitle.trimmingCharacters(in: .whitespacesAndNewlines) : bankTitle
        guard !title.isEmpty else { bankError = "Enter a name for your bank."; return }
        var bank = currentBankFile
        if asNew { bank.id = UUID() }
        bank.title = title
        if storeBank(bank) { bankTitle = title; currentBankID = bank.id.uuidString }
    }

    private func preserveCurrentBank() -> Bool {
        guard !savedChords.isEmpty || !currentBankID.isEmpty else { return true }
        let bank = currentBankFile
        guard storeBank(bank) else { return false }
        currentBankID = bank.id.uuidString
        return true
    }

    private func openBank(_ bank: ChordBankFile) {
        if currentBankID == bank.id.uuidString { openingBank = false; return }
        guard preserveCurrentBank(), writeChordBank(bank.chords, recordHistory: false) else { return }
        bankTitle = bank.title; currentBankID = bank.id.uuidString
        var recent = bank; recent.modified = Date(); _ = storeBank(recent)
        bankHistory = ChordBankHistory(); bankUndo = [:]; approachPreview = []; approachChoice = ""; openingBank = false
    }

    private func importBank(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            var bank = try JSONDecoder().decode(ChordBankFile.self, from: Data(contentsOf: url))
            guard !bank.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  Set(bank.chords.map(\.id)).count == bank.chords.count,
                  bank.chords.allSatisfy({ formulas[$0.chord] != nil && (0..<12).contains($0.root) && !$0.left.isEmpty && $0.notes.allSatisfy { (0..<totalNotes).contains($0) } }) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            bank.id = UUID()
            openBank(bank)
        } catch { bankError = "Couldn’t open this chord bank: " + error.localizedDescription }
    }

    private var bankFileMenu: some View {
        Menu {
            Button("New Bank") {
                guard preserveCurrentBank(), writeChordBank([], recordHistory: false) else { return }
                bankTitle = "Untitled Bank"; currentBankID = ""; bankHistory = ChordBankHistory(); bankUndo = [:]; approachPreview = []
            }
            Button("Save") {
                if currentBankID.isEmpty { proposedBankTitle = bankTitle; namingBank = true }
                else { saveNamedBank(asNew: false) }
            }
            Button("Save As…") { proposedBankTitle = bankTitle; namingBank = true }
            Button("Open…") { openingBank = true }
            Menu("Open Recent") {
                ForEach(Array(bankLibrary.prefix(8))) { bank in
                    Button(bank.title) { openBank(bank) }
                }
            }.disabled(bankLibrary.isEmpty)
            Divider()
            Button("Import Bank File…") { importingBank = true }
            Button("Export Bank File…") { exportingBank = true }
        } label: {
            HStack(spacing: 6) {
                Text("File")
                Image(systemName: "chevron.down").font(.caption.bold())
            }.padding(.horizontal, 10).padding(.vertical, 7)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var bankOpenSheet: some View {
        NavigationStack {
            List(bankLibrary) { bank in
                Button { openBank(bank) } label: {
                    VStack(alignment: .leading) {
                        Text(bank.title)
                        Text("\(bank.chords.count) chords").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .overlay { if bankLibrary.isEmpty { ContentUnavailableView("No saved banks", systemImage: "folder", description: Text("Use File → Save As to name a bank.")) } }
            .navigationTitle("Open Chord Bank")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cancel") { openingBank = false } } }
        }.preferredColorScheme(.dark)
    }

    private var approachChoices: [ChordApproach] {
        guard let target = savedChords.first else { return [] }
        return ChordApproach.choices(count: approachCount, target: target.chord, minor: target.chord.hasPrefix("min"))
    }

    private func previewApproach() {
        guard let target = savedChords.first,
              let recipe = approachChoices.first(where: { $0.id == approachChoice }) ?? approachChoices.first else { return }
        var generated: [SavedChord] = []
        for step in recipe.steps {
            let root = (target.root + step.offset + 12) % 12
            guard let formula = formulas[step.chord] else { bankError = "This approach is unavailable."; return }
            var saved: SavedChord
            if recipe.id.hasPrefix("Half-step") {
                let shift = step.offset
                saved = target
                saved.id = UUID(); saved.root = root
                saved.left = Set(target.left.map { $0 + shift })
                saved.right = Set(target.right.map { $0 + shift })
                saved.voiceLed = false; saved.movementSummary = nil
            } else {
                let count = formula.LHVoicings?.count ?? min(formula.LHIntervals.count, inversionNames.count)
                guard let inversion = (0..<count).first(where: { voicedChordNotes(inversion: $0, chord: step.chord, root: root, scale: "") != nil }),
                      let close = voicedChordNotes(inversion: inversion, chord: step.chord, root: root, scale: "") else {
                    bankError = "No voicing fits this approach."; return
                }
                let drop = target.right.isEmpty ? nil : makeDropVoicing(notes: close, positions: [2, 3], chord: step.chord, root: root)
                    ?? makeDropVoicing(notes: close, positions: [2], chord: step.chord, root: root)
                guard target.right.isEmpty || drop != nil else { bankError = "No two-hand voicing fits this approach."; return }
                saved = SavedChord(title: "", root: root, chord: step.chord, inversion: inversion,
                                   option: drop == nil ? "" : "Approach voicing", rootEnabled: target.rootEnabled,
                                   left: drop?.left ?? Set(close), right: drop?.right ?? [])
            }
            let suffix = step.chord == "maj" ? "" : step.chord.replacingOccurrences(of: "min", with: "m")
            saved.title = roots[root].replacingOccurrences(of: "b", with: "♭") + suffix.replacingOccurrences(of: "#", with: "♯").replacingOccurrences(of: "b", with: "♭")
            generated.append(saved)
        }
        // Work backward toward the fixed destination; the target card never changes.
        var next = target
        for index in generated.indices.reversed() {
            let chord = generated[index]
            guard let formula = formulas[chord.chord],
                  let fitted = ChordVoiceLeading.lead(from: next, to: chord, intervals: formula.LHIntervals, degrees: formula.LHDegrees) else {
                bankError = "No approach fits the voicing range."; return
            }
            generated[index] = fitted; next = fitted
        }
        approachPreview = generated; approachTargetID = target.id
    }

    private func randomizeApproach() {
        let alternatives = approachChoices.filter { $0.id != approachChoice }
        approachChoice = (alternatives.isEmpty ? approachChoices : alternatives).randomElement()?.id ?? ""
        approachPreview = []
        previewApproach()
    }

    private var approachCard: some View {
        Group {
            if approachExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Lead to first chord").font(.headline)
                        Spacer()
                        Button { withAnimation { approachExpanded = false } } label: {
                            Image(systemName: "chevron.left")
                        }.accessibilityLabel("Collapse approaches")
                    }
                    Picker("Chords", selection: Binding(get: { approachCount }, set: {
                        approachCount = $0; randomizeApproach()
                    })) {
                        ForEach(1...4, id: \.self) { Text("\($0)").tag($0) }
                    }.pickerStyle(.segmented)
                    Picker("Approach", selection: Binding(get: { approachChoice }, set: {
                        approachChoice = $0; approachPreview = []; previewApproach()
                    })) {
                        ForEach(approachChoices) { Text($0.id).tag($0.id) }
                    }.labelsHidden()
                    Text(approachPreview.map(\.title).joined(separator: " → ")).font(.caption).lineLimit(2)
                    HStack {
                        Menu("Play") {
                            ForEach(approachPreview) { chord in Button(chord.title) { chordAudio.play(keyIndices: chord.notes) } }
                            if let target = savedChords.first { Button("Target: " + target.title) { chordAudio.play(keyIndices: target.notes) } }
                        }.disabled(approachPreview.isEmpty)
                        Button { randomizeApproach() } label: { Image(systemName: "shuffle") }
                            .accessibilityLabel("Random approach")
                        Spacer()
                        Button("Insert", systemImage: "plus") {
                            guard !approachPreview.isEmpty, savedChords.first?.id == approachTargetID else { return }
                            if writeChordBank(approachPreview + savedChords) {
                                approachPreview = []; bankUndo = [:]
                                withAnimation { approachExpanded = false }
                            }
                        }.buttonStyle(.borderedProminent).disabled(approachPreview.isEmpty)
                    }
                }
                .padding(12).frame(width: 270)
            } else {
                Button {
                    randomizeApproach()
                    withAnimation { approachExpanded = true }
                } label: {
                    Image(systemName: "plus").font(.system(size: 26, weight: .semibold))
                        .frame(width: 52, height: 148)
                }.accessibilityLabel("Add approach chords before first chord")
            }
        }
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
        .onChange(of: savedChords.first) { _, _ in
            approachPreview = []; approachExpanded = false
        }
    }

    private func bankCard(_ saved: SavedChord, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(index + 1). \(saved.title)").font(.headline).lineLimit(1).minimumScaleFactor(0.7)
                Spacer()
                Menu {
                    Button("Move left") { moveSavedChord(saved, by: -1) }.disabled(index == 0)
                    Button("Move right") { moveSavedChord(saved, by: 1) }.disabled(index == savedChords.count - 1)
                    Button("Remove", role: .destructive) {
                        if writeChordBank(savedChords.filter { $0.id != saved.id }) { bankUndo[saved.id] = nil }
                    }
                } label: { Image(systemName: "ellipsis.circle") }
                .accessibilityLabel("Options for saved chord \(index + 1)")
            }
            Text(saved.voiceLed ? "Voice led" : saved.option.isEmpty ? "Left hand" : saved.option)
                .font(.caption).foregroundStyle(.secondary).lineLimit(1)
            substituteKeyboard(SubstituteArrangement(chord: saved.chord, option: saved.option,
                                inversion: saved.inversion, left: saved.left, right: saved.right, bass: saved.bass))
            HStack {
                Button { chordAudio.play(keyIndices: saved.notes) } label: { Label("Play", systemImage: "play.fill") }
                    .accessibilityLabel("Play saved chord \(index + 1), \(saved.title)")
                Spacer()
                Button("Recall") { recallChord(saved) }.buttonStyle(.borderedProminent)
                Button(role: .destructive) {
                    if writeChordBank(savedChords.filter { $0.id != saved.id }) { bankUndo[saved.id] = nil }
                } label: { Image(systemName: "trash") }
                .accessibilityLabel("Remove saved chord \(index + 1)")
            }
            if let summary = saved.movementSummary {
                Text(summary).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
            }
        }
        .padding(12).frame(width: 230)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private var chordBankSheet: some View {
        NavigationStack {
            ScrollView(.horizontal) {
                HStack(alignment: .center, spacing: 12) {
                    if !savedChords.isEmpty { approachCard }
                    if savedChords.isEmpty {
                        Text("Save chords from the keyboard, then use Voice Lead between cards to adjust the next chord.")
                            .frame(width: 340).foregroundStyle(.secondary)
                    }
                    ForEach(Array(savedChords.enumerated()), id: \.element.id) { index, saved in
                        if index > 0 {
                            VStack(spacing: 8) {
                                Button { chordAudio.stop(); voiceLeadChord(at: index) } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: "arrow.right")
                                        Text("Voice Lead").font(.caption.bold())
                                    }
                                }.buttonStyle(.bordered)
                                .accessibilityLabel("Voice lead chord \(index + 1) from chord \(index)")
                                if bankUndo[saved.id] != nil { Button("Undo") { undoVoiceLeading(saved) }.font(.caption) }
                            }
                        }
                        bankCard(saved, index: index)
                    }
                }.padding(12)
            }
            .navigationTitle(bankTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        chordAudio.stop()
                        withAnimation(.easeInOut(duration: 0.3)) { showingChordBank = false }
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 25, weight: .bold)).frame(width: 44, height: 44)
                    }.accessibilityLabel("Close Chord Bank")
                }
                ToolbarItem(placement: .topBarLeading) { bankFileMenu }
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { restoreBankHistory(redo: false) } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }.disabled(!bankHistory.canUndo).accessibilityLabel("Undo bank edit")
                    Button { restoreBankHistory(redo: true) } label: {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                    }.disabled(!bankHistory.canRedo).accessibilityLabel("Redo bank edit")
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Save chord", systemImage: "plus") { saveCurrentChord() } }
            }
            .sheet(isPresented: $openingBank) { bankOpenSheet }
            .alert("Save Bank As", isPresented: $namingBank) {
                TextField("Bank title", text: $proposedBankTitle)
                Button("Save") { saveNamedBank(asNew: true) }
                Button("Cancel", role: .cancel) { }
            } message: { Text("Give this chord bank a name.") }
            .fileExporter(isPresented: $exportingBank,
                          document: ChordBankDocument(bank: currentBankFile), contentType: .json,
                          defaultFilename: bankTitle) { result in
                if case .failure(let error) = result { bankError = error.localizedDescription }
            }
            .fileImporter(isPresented: $importingBank, allowedContentTypes: [.json]) { result in
                importBank(result)
            }
            .alert("Chord Bank", isPresented: Binding(get: { bankError != nil }, set: { if !$0 { bankError = nil } })) {
                Button("OK", role: .cancel) { bankError = nil }
            } message: { Text(bankError ?? "") }
        }.preferredColorScheme(.dark)
    }

    var body: some View {
        
        GeometryReader { geometry in
            
            let keyboardWidth = geometry.size.width * 0.975
            let keyboardHeight = geometry.size.height * 0.40
            
            let whiteKeyCount = countWhiteKeys()
            let whiteKeyWidth = keyboardWidth / CGFloat(whiteKeyCount)
            
            let blackKeyWidth = whiteKeyWidth * 0.65
            let blackKeyHeight = keyboardHeight * 0.62
            
            ZStack {
                
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // MARK: - Root and Chord Pickers

                    HStack(spacing: 14) {
                        if !roots.isEmpty {
                            Menu {
                                ForEach(0..<roots.count, id: \.self) { index in
                                    Button {
                                        selectedRoot = index
                                    } label: {
                                        if selectedRoot == index {
                                            Label(roots[index], systemImage: "checkmark")
                                        } else {
                                            Text(roots[index])
                                        }
                                    }
                                    .disabled(!hasValidVoicing(chord: selectedChord, root: index))
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(roots[selectedRoot])
                                        .font(.system(size: 32, weight: .bold))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                            }
                            .accessibilityLabel("Root")
                            .tint(.green)
                        }

                        Menu {
                            ForEach(chordGroups, id: \.triad) { group in
                                Button {
                                    selectedChord = group.triad
                                } label: {
                                    if selectedGroup?.triad == group.triad {
                                        Label(group.name, systemImage: "checkmark")
                                    } else {
                                        Text(group.name)
                                    }
                                }
                                .disabled(!hasValidVoicing(chord: group.triad, root: selectedRoot))
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(selectedGroup?.name ?? selectedChord)
                                    .font(.system(size: 22, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .accessibilityLabel("Triad")

                        Menu {
                            ForEach(selectedGroup?.chords ?? [], id: \.self) { chord in
                                Button {
                                    selectedChord = chord
                                } label: {
                                    if selectedChord == chord {
                                        Label(extensionLabel(chord), systemImage: "checkmark")
                                    } else {
                                        Text(extensionLabel(chord))
                                    }
                                }
                                .disabled(!hasValidVoicing(chord: chord, root: selectedRoot))
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(extensionLabel(selectedChord))
                                    .font(.system(size: 22, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                        }
                        .accessibilityLabel("Extension")

                        if formulas[selectedChord]?.LHVoicings != nil || selectedChord == "9" || selectedChord == "13" || selectedChord == "13(9)" {
                            inversionMenu
                        }

                        if !extensionNames.contains(selectedChord) {
                            inversionMenu
                        }

                        if extensionNames.contains(selectedChord) || !(chordScales[selectedChord] ?? []).isEmpty {
                            rightHandMenu
                        }
                    }
                    .font(.system(size: 22, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: keyboardWidth)
                    .tint(.blue)

                    // MARK: - Keyboard
                    
                    ZStack(alignment: .topLeading) {
                        
                        // =========================
                        // WHITE KEYS
                        // =========================
                        
                        HStack(spacing: 0) {
                            
                            ForEach(0..<totalNotes, id: \.self) { note in
                                
                                if !isBlackKey(note) {
                                    
                                    let isSelected =
                                        selectedChordNotes.contains(note) || rightHandNotes.contains(note)
                                    
                                    ZStack(alignment: .bottom) {
                                        
                                        Rectangle()
                                            .fill(
                                                isSelected
                                                ? highlightedColor(note)
                                                : Color.white
                                            )
                                        
                                        if isSelected && !roots.isEmpty {
                                            
                                            Text(noteName(note))
                                                .font(.caption)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.4)
                                                .fontWeight(.bold)
                                                .foregroundStyle(.white)
                                                .padding(.bottom, 8)
                                        }
                                    }
                                    .frame(
                                        width: whiteKeyWidth,
                                        height: keyboardHeight
                                    )
                                    .overlay {
                                        
                                        Rectangle()
                                            .stroke(
                                                Color.black,
                                                lineWidth: 1
                                            )
                                    }
                                }
                            }
                        }
                        
                        
                        // =========================
                        // BLACK KEYS
                        // =========================
                        
                        ForEach(0..<totalNotes, id: \.self) { note in
                            
                            if isBlackKey(note) {
                                
                                let whiteKeysBefore =
                                    numberOfWhiteKeysBefore(note)
                                
                                let isSelected =
                                    selectedChordNotes.contains(note) || rightHandNotes.contains(note)
                                
                                ZStack(alignment: .bottom) {
                                    
                                    Rectangle()
                                        .fill(
                                            isSelected
                                            ? highlightedColor(note)
                                            : Color.black
                                        )
                                    
                                    if isSelected && !roots.isEmpty {
                                        
                                        Text(noteName(note))
                                            .font(.caption2)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.4)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .padding(.bottom, 8)
                                    }
                                }
                                .frame(
                                    width: blackKeyWidth,
                                    height: blackKeyHeight
                                )
                                .overlay {
                                    Rectangle()
                                        .strokeBorder(Color.black, lineWidth: 2)
                                }
                                .offset(
                                    x:
                                        CGFloat(whiteKeysBefore)
                                        * whiteKeyWidth
                                        - blackKeyWidth / 2
                                )
                            }
                        }
                        
                        
                        // =========================
                        // MIDDLE C LABEL
                        // =========================
                        
                        let middleCWhiteKeyPosition =
                            numberOfWhiteKeysBefore(middleCNote)
                        
                        VStack(spacing: 1) {
                            
                            Image(systemName: "arrow.up")
                                .font(.system(size: 10))
                            
                            Text("Middle C")
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.white)
                        .frame(width: whiteKeyWidth * 3)
                        .position(
                            x:
                                CGFloat(middleCWhiteKeyPosition)
                                * whiteKeyWidth
                                + whiteKeyWidth / 2,
                            
                            y:
                                keyboardHeight + 18
                        )
                    }
                    .frame(
                        width: keyboardWidth,
                        height: keyboardHeight + 40,
                        alignment: .top
                    )
                }
                .frame(
                    width: geometry.size.width,
                    height: geometry.size.height
                )
            }
        }
        .overlay(alignment: .bottom) {
            VStack(spacing: 4) {
                chordSymbolView
                    .foregroundStyle(.white)
                if usesMajorSixSubstitution || usesMinorSixSubstitution {
                    Text(usesMinorSixSubstitution
                         ? "changed to minor six to avoid dissonance on top of chord"
                         : "changed to major six to avoid dissonance on top of chord")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.bottom, 12)
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                chordAudio.play(keyIndices: chordPlaybackNotes)
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(chordAudio.isPlaying ? Color.blue : Color.blue.opacity(0.8), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(formulas[selectedChord] == nil)
            .accessibilityLabel("Play chord")
            .accessibilityHint("Plays the bass and chord voicing, without scale notes")
            .padding(.trailing, 18)
            .padding(.bottom, 12)
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 16) {
                Toggle("Root", isOn: $rootEnabled)
                .toggleStyle(.switch)
                .tint(.green)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize()
                .accessibilityHint("Shows and plays the bass root when enabled")
                Button("Substitutes") { showingSubstitutes = true }
                    .font(.system(size: 15, weight: .semibold))
                    .buttonStyle(.bordered)
                    .tint(.blue)
            }
                .padding(.leading, 18)
                .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingSubstitutes, onDismiss: { chordAudio.stop() }) {
            substitutesSheet
        }
        .allowsHitTesting(!showingChordBank)
        .accessibilityHidden(showingChordBank)
        .overlay(alignment: .topLeading) {
            if showingChordBank {
                chordBankSheet
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background { Color.black.ignoresSafeArea() }
                    .transition(.move(edge: .top))
                    .zIndex(1)
            } else {
                Button {
                    chordAudio.stop()
                    withAnimation(.easeInOut(duration: 0.3)) { showingChordBank = true }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 25, weight: .bold))
                        .frame(width: 48, height: 48)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Open Chord Bank")
                .padding(.leading, 16)
                .padding(.top, 4)
            }
        }
        .alert("Playback unavailable", isPresented: Binding(
            get: { chordAudio.errorMessage != nil },
            set: { if !$0 { chordAudio.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { chordAudio.errorMessage = nil }
        } message: {
            Text(chordAudio.errorMessage ?? "")
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { chordAudio.suspend() }
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in
            chordAudio.suspend()
        }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            if let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               AVAudioSession.RouteChangeReason(rawValue: value) == .oldDeviceUnavailable {
                chordAudio.suspend()
            }
        }
        .onDisappear { chordAudio.suspend() }
        .onAppear {
            loadChordFormulas()
        }
        .onChange(of: selectedChord) { _, _ in
            chordAudio.stop()
            if activeBankVoicing != nil { return }
            recalledBankChord = nil
            if let arrangement = pendingSubstitute, arrangement.chord == selectedChord {
                selectedScale = arrangement.option
                selectedInversion = arrangement.inversion
                pendingSubstitute = nil
            } else {
                selectedScale = defaultScale(for: selectedChord)
                selectValidInversion()
            }
        }
        .onChange(of: selectedRoot) { _, _ in
            chordAudio.stop()
            if activeBankVoicing != nil { return }
            recalledBankChord = nil
            if let formula = selectedHandFormula, handVoicing(formula) == nil { selectedScale = "" }
            selectValidInversion()
        }
        .onChange(of: rootEnabled) { _, _ in
            chordAudio.stop()
        }
        .onChange(of: selectedInversion) { _, _ in
            chordAudio.stop()
            if activeBankVoicing != nil { return }
            recalledBankChord = nil
            if selectedScale == "LH Shell" && shellVoicing(inversion: selectedInversion) == nil {
                selectedScale = ""
            }
        }
        .onChange(of: selectedScale) { _, _ in
            chordAudio.stop()
            if activeBankVoicing != nil { return }
            recalledBankChord = nil
            if voicedChordNotes(inversion: selectedInversion) == nil {
                selectValidInversion()
            }
        }
    }
    
    
    // MARK: - Load ChordFormulas.json
    
    func loadChordFormulas() {
        
        guard let url = Bundle.main.url(
            forResource: "ChordFormulas",
            withExtension: "json"
        ) else {
            print("Could not find ChordFormulas.json")
            return
        }
        
        do {
            
            let data = try Data(contentsOf: url)
            
            let decoded =
                try JSONDecoder().decode(
                    ChordFormulaFile.self,
                    from: data
                )
            
            roots = (0..<12).compactMap { index in
                decoded.Roots[String(index)]
            }
            
            triadNames = Set(decoded.Chords.Triads.map(\.name))
            extensionNames = Set(decoded.Chords.Extensions.map(\.name))
            let chords = decoded.Chords.allChords
            formulas = Dictionary(uniqueKeysWithValues: chords.map { ($0.name, $0) })
            chordGroups = decoded.ChordGroups
            rightHandExtensions = chords.reduce(into: [:]) { result, chord in
                result[chord.name] = chord.RHExtension ?? []
            }
            chordScales = chords.reduce(into: [:]) { result, chord in
                result[chord.name] = chord.Scales ?? []
            }
            selectedScale = defaultScale(for: selectedChord)
            chordTypes = chords.map(\.name)
            chordIntervals = chords.reduce(into: [:]) { result, chord in
                result[chord.name] = chord.LHIntervals
            }
            scaleChordIntervals = chords.reduce(into: [:]) { result, chord in
                result[chord.name] = chord.LHScaleIntervals
            }
            if !chordTypes.contains(selectedChord), let firstChord = chordTypes.first {
                selectedChord = firstChord
            }
            selectValidInversion()
            
        } catch {
            print("Error loading ChordFormulas.json:")
            print(error)
        }
    }
    
    
    // MARK: - Piano Functions
    
    func isBlackKey(_ note: Int) -> Bool {
        
        let positionInOctave = note % 12
        
        return blackKeyPositions.contains(
            positionInOctave
        )
    }
    
    
    func countWhiteKeys() -> Int {
        
        (0..<totalNotes)
            .filter { !isBlackKey($0) }
            .count
    }
    
    
    func numberOfWhiteKeysBefore(_ note: Int) -> Int {
        
        (0..<note)
            .filter { !isBlackKey($0) }
            .count
    }
}


#Preview(traits: .landscapeLeft) {
    ContentView(initialChord: "maj7(#5)")
}
