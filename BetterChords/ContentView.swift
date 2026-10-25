
import SwiftUI
import AVFoundation

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
        guard !dropPositions.isEmpty,
              let closeNotes = voicedChordNotes(inversion: selectedInversion),
              closeNotes.count >= (dropPositions.max() ?? 0) else { return nil }
        // Raise the close voicing one octave, then drop the requested voices.
        // Count from the top of the original voicing for combined drops.
        let upperNotes = closeNotes.map { $0 + 12 }
        let droppedIndices = Set(dropPositions.map { upperNotes.count - $0 })
        let left = Set(droppedIndices.map { upperNotes[$0] - 12 })
        let right = Set(upperNotes.indices.filter { !droppedIndices.contains($0) }.map { upperNotes[$0] })
        guard left.union(right).allSatisfy({ (0..<totalNotes).contains($0) }) else { return nil }
        return boundedHandVoicing(left: left, right: right)
    }

    private func boundedHandVoicing(left: Set<Int>, right: Set<Int>) -> (left: Set<Int>, right: Set<Int>)? {
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

    private func shellVoicing(inversion: Int) -> (left: Set<Int>, right: Set<Int>)? {
        guard let intervals = chordIntervals[selectedChord],
              let notes = voicedChordNotes(inversion: inversion),
              let bottom = notes.first, let top = notes.last else { return nil }
        if ["9", "13", "9(13)", "13(9)"].contains(selectedChord) {
            let left = Set([selectedRoot, selectedRoot + 10])
            let right = Set(notes)
            // Keep the existing chord register and lower the shell one octave.
            // Disable combinations whose hands would overlap.
            guard left.max()! < bottom else { return nil }
            return boundedHandVoicing(left: left, right: right)
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
        return boundedHandVoicing(left: left, right: Set(right))
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

    private var leftHandNotes: Set<Int> {
        if let selectedHandVoicing { return selectedHandVoicing.left }
        if let selectedShell { return selectedShell.left }
        if let dropVoicing { return dropVoicing.left }
        return Set(voicedChordNotes(inversion: selectedInversion) ?? [])
    }

    private var selectedChordNotes: Set<Int> {
        rootEnabled ? leftHandNotes.union([selectedRoot]) : leftHandNotes.subtracting([selectedRoot])
    }

    private var chordPlaybackNotes: Set<Int> {
        let isScale = (chordScales[selectedChord] ?? []).contains { $0.name == selectedScale }
        return selectedChordNotes.union(isScale ? [] : rightHandNotes)
    }

    private func coreRightHandNotes(inversion: Int) -> Set<Int> {
        guard let formula = formulas[selectedChord],
              let intervals = formula.RHChordIntervals, !intervals.isEmpty,
              let left = voicedChordNotes(inversion: inversion, scale: ""),
              let bass = left.first, let highest = left.last else { return [] }
        let bassInterval = formula.LHVoicings?[inversion].first ?? formula.LHIntervals[inversion]
        let voicedRoot = bass - bassInterval
        var notes = intervals.map { voicedRoot + $0 }
        while notes.min()! <= highest { notes = notes.map { $0 + 12 } }
        guard notes.allSatisfy({ (0..<totalNotes).contains($0) }) else { return [] }
        return Set(notes)
    }

    private var rightHandNotes: Set<Int> {
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
                Text(selectedHandFormula == nil ? inversionLabel(selectedInversion) : "Fixed voicing")
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
            Toggle("Root", isOn: $rootEnabled)
                .toggleStyle(.switch)
                .tint(.green)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .fixedSize()
                .accessibilityHint("Shows and plays the bass root when enabled")
                .padding(.leading, 18)
                .padding(.bottom, 24)
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
            selectedScale = defaultScale(for: selectedChord)
            selectValidInversion()
        }
        .onChange(of: selectedRoot) { _, _ in
            chordAudio.stop()
            if let formula = selectedHandFormula, handVoicing(formula) == nil { selectedScale = "" }
            selectValidInversion()
        }
        .onChange(of: rootEnabled) { _, _ in
            chordAudio.stop()
        }
        .onChange(of: selectedInversion) { _, _ in
            chordAudio.stop()
            if selectedScale == "LH Shell" && shellVoicing(inversion: selectedInversion) == nil {
                selectedScale = ""
            }
        }
        .onChange(of: selectedScale) { _, _ in
            chordAudio.stop()
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
