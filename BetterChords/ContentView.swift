
import SwiftUI

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

struct ChordCategories: Decodable {
    let Triads: [ChordFormula]
    let SeventhChords: [ChordFormula]
    let Extensions: [ChordFormula]

    var allChords: [ChordFormula] {
        Triads + SeventhChords + Extensions
    }
}

struct ChordFormula: Decodable {
    let name: String
    let LHIntervals: [Int]
    let LHDegrees: [String]
    let LHScaleIntervals: [Int]?
    let LHScaleDegrees: [String]?
    let RHExtension: [Int]?
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
    @State private var selectedRoot = 0
    @State private var selectedChord = "maj"
    @State private var selectedInversion = 0
    @State private var selectedScale = ""
    @State private var chordScales: [String: [ScaleFormula]] = [:]

    private let inversionNames = [
        "Root position", "First inversion", "Second inversion", "Third inversion", "Fourth inversion"
    ]

    private var availableInversions: Range<Int> {
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
        default: return chord.replacingOccurrences(of: "#", with: "♯")
        }
    }
    @State private var chordIntervals: [String: [Int]] = [:]
    @State private var scaleChordIntervals: [String: [Int]] = [:]
    @State private var rightHandExtensions: [String: [Int]] = [:]
    @State private var triadNames: Set<String> = []
    @State private var extensionNames: Set<String> = []

    private var usesMajorSixSubstitution: Bool {
        selectedChord == "maj7" && selectedInversion == 1
    }

    private var usesMinorSixSubstitution: Bool {
        selectedChord == "minmaj7" && selectedInversion == 1
    }

    private var chordSymbol: String {
        guard roots.indices.contains(selectedRoot) else { return "" }
        let root = roots[selectedRoot].replacingOccurrences(of: "b", with: "♭")
        let suffix = selectedChord == "maj" ? "" : selectedChord
            .replacingOccurrences(of: "min", with: "m")
            .replacingOccurrences(of: "#", with: "♯")
        return root + suffix
    }

    @ViewBuilder
    private var chordSymbolView: some View {
        if selectedChord == "minmaj7" || selectedChord == "minmaj9" {
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
                        .font(.system(size: 30, weight: .bold))
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(chordSymbol)
        } else {
            Text(chordSymbol)
                .font(.system(size: 48, weight: .bold))
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
        let intervals = leftHandIntervals(for: formulaName, scale: scale).sorted()
        guard !intervals.isEmpty, intervals.indices.contains(inversion) else { return nil }

        let bassInterval = intervals[inversion]
        let bassNote = middleCNote + selectedRoot + bassInterval
        var notes = intervals.map { interval in
            bassNote + ((interval - bassInterval) % 12 + 12) % 12
        }.sorted()

        // Keep triads low, with their bass in the second octave.
        if triadNames.contains(selectedChord) {
            while notes.first! >= 24 { notes = notes.map { $0 - 12 } }
            while notes.first! < 12 { notes = notes.map { $0 + 12 } }
            return notes
        }

        // Move the whole voicing so its highest note ends in the target range.
        let usesDARange = !triadNames.contains(selectedChord)
        let highestAllowed = usesDARange ? 33 : 35
        while notes.last! > highestAllowed { notes = notes.map { $0 - 12 } }
        while notes.last! < (usesDARange ? 14 : 24) {
            notes = notes.map { $0 + 12 }
        }
        if usesDARange && notes.first! < 14 { return nil }
        return notes
    }

    private func hasValidVoicing(chord: String, root: Int, scale: String? = nil) -> Bool {
        let count = chord == "9" ? 2 : (extensionNames.contains(chord) ? 1 : min(chordIntervals[chord]?.count ?? 0, inversionNames.count))
        return (0..<count).contains { voicedChordNotes(inversion: $0, chord: chord, root: root, scale: scale) != nil }
    }

    private func selectValidInversion() {
        selectedInversion = availableInversions.first {
            voicedChordNotes(inversion: $0) != nil
        } ?? 0
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
        return (left, right)
    }

    private var selectedChordNotes: Set<Int> {
        if let dropVoicing { return dropVoicing.left.union([selectedRoot]) }
        return Set(voicedChordNotes(inversion: selectedInversion) ?? []).union([selectedRoot])
    }

    private var rightHandNotes: Set<Int> {
        if let dropVoicing { return dropVoicing.right }
        if selectedScale.isEmpty { return [] }
        if selectedScale != "Right hand extension" { return scaleNotes }
        guard let extensions = rightHandExtensions[selectedChord],
              let bass = voicedChordNotes(inversion: selectedInversion)?.first else { return [] }
        let intervals = (chordIntervals[selectedChord] ?? []).sorted()
        guard intervals.indices.contains(selectedInversion) else { return [] }
        var voicedRoot = bass - intervals[selectedInversion]
        if extensionNames.contains(selectedChord), let highestInterval = intervals.max() {
            voicedRoot = middleCNote + selectedRoot
            while voicedRoot + highestInterval > 33 { voicedRoot -= 12 }
        }
        return Set(extensions.map { voicedRoot + $0 }.filter { (0..<totalNotes).contains($0) })
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

    private var rightHandLabel: String {
        if selectedScale.isEmpty { return "RH" }
        // Keep long scale names readable in the single-row controls.
        switch selectedScale {
        case "Whole-Half Diminished": return "Whole–Half Dim."
        case "half-whole diminished": return "Half–Whole Dim."
        case "Locrian Natural 2": return "Locrian ♮2"
        case "Locrian Natural 6": return "Locrian ♮6"
        case "Melodic Minor Bebop": return "Melodic Min. Bebop"
        default: return selectedScale
        }
    }

    private func highlightedColor(_ note: Int) -> Color {
        let color: Color
        if note == selectedRoot {
            color = .green
        } else if rightHandNotes.contains(note) {
            color = .purple
        } else {
            color = .blue
        }
        guard isBlackKey(note) else { return color }
        if note == selectedRoot { return Color(red: 0.09, green: 0.44, blue: 0.20) }
        if rightHandNotes.contains(note) { return Color(red: 0.34, green: 0.12, blue: 0.44) }
        return Color(red: 0.0, green: 0.26, blue: 0.52)
    }

    private func inversionLabel(_ inversion: Int) -> String {
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
                Text(inversionLabel(selectedInversion))
                    .font(.system(size: 22, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
        }
        .accessibilityLabel("Inversion")
    }

    private func noteName(_ note: Int) -> String {
        let root = roots[selectedRoot]
        if note == selectedRoot { return NoteSpelling.name(root: root, interval: 0, degree: "1") }
        let pitchClass = (note - selectedRoot + 12) % 12
        func spell(_ intervals: [Int], _ degrees: [String]) -> String? {
            guard let index = intervals.firstIndex(where: { $0 % 12 == pitchClass }),
                  degrees.indices.contains(index) else { return nil }
            return NoteSpelling.name(root: root, interval: intervals[index], degree: degrees[index])
        }
        if rightHandNotes.contains(note) {
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

                        if selectedChord == "9" || selectedChord == "13" || selectedChord == "13(9)" {
                            inversionMenu
                        }

                        if !extensionNames.contains(selectedChord) {
                            inversionMenu
                        }

                        if extensionNames.contains(selectedChord) || !(chordScales[selectedChord] ?? []).isEmpty {
                            Menu {
                                Button {
                                    selectedScale = ""
                                } label: {
                                    if selectedScale.isEmpty {
                                        Label("RH", systemImage: "checkmark")
                                    } else {
                                        Text("RH")
                                    }
                                }
                                ForEach(["Drop 2", "Drop 3", "Drop 2 & 3"], id: \.self) { option in
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
                                if !(rightHandExtensions[selectedChord] ?? []).isEmpty {
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
                            .accessibilityValue(selectedScale.isEmpty ? "RH, no right-hand notes" : selectedScale)
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
        .onAppear {
            loadChordFormulas()
        }
        .onChange(of: selectedChord) { _, _ in
            selectedScale = defaultScale(for: selectedChord)
            selectValidInversion()
        }
        .onChange(of: selectedRoot) { _, _ in
            selectValidInversion()
        }
        .onChange(of: selectedScale) { _, _ in
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
    ContentView(initialChord: "maj")
}
