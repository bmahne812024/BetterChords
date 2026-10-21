
import SwiftUI

struct ChordFormulaFile: Decodable {
    let Roots: [String: String]
    let Chords: ChordCategories
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
    let RHExtension: [Int]?
    let Scales: [ScaleFormula]?
}

struct ScaleFormula: Decodable {
    let name: String
    let intervals: [Int]
}

struct ContentView: View {
    
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
    @State private var chordIntervals: [String: [Int]] = [:]
    @State private var rightHandExtensions: [String: [Int]] = [:]
    @State private var triadNames: Set<String> = []
    @State private var extensionNames: Set<String> = []

    private var usesMajorSixSubstitution: Bool {
        selectedChord == "maj7" && selectedInversion == 1
    }

    private func voicedChordNotes(inversion: Int, chord: String? = nil, root: Int? = nil) -> [Int]? {
        let selectedChord = chord ?? self.selectedChord
        let selectedRoot = root ?? self.selectedRoot
        let formulaName = selectedChord == "maj7" && inversion == 1 ? "6" : selectedChord
        let intervals = (chordIntervals[formulaName] ?? []).sorted()
        guard !intervals.isEmpty, intervals.indices.contains(inversion) else { return nil }

        let bassInterval = intervals[inversion]
        let bassNote = middleCNote + selectedRoot + bassInterval
        var notes = intervals.map { interval in
            bassNote + ((interval - bassInterval) % 12 + 12) % 12
        }.sorted()

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

    private func hasValidVoicing(chord: String, root: Int) -> Bool {
        let count = chord == "9" ? 2 : (extensionNames.contains(chord) ? 1 : min(chordIntervals[chord]?.count ?? 0, inversionNames.count))
        return (0..<count).contains { voicedChordNotes(inversion: $0, chord: chord, root: root) != nil }
    }

    private func selectValidInversion() {
        selectedInversion = availableInversions.first {
            voicedChordNotes(inversion: $0) != nil
        } ?? 0
    }

    private var selectedChordNotes: Set<Int> {
        Set(voicedChordNotes(inversion: selectedInversion) ?? []).union([selectedRoot])
    }

    private var rightHandNotes: Set<Int> {
        if !selectedScale.isEmpty { return scaleNotes }
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
              let highestInterval = chordIntervals[selectedChord]?.max() else { return [] }
        var voicedRoot = middleCNote + selectedRoot
        while voicedRoot + highestInterval > 33 { voicedRoot -= 12 }
        return Set(scale.intervals.map { voicedRoot + $0 }.filter { (0..<totalNotes).contains($0) })
    }

    private func highlightedColor(_ note: Int) -> Color {
        if note == selectedRoot { return .green }
        if rightHandNotes.contains(note) { return .purple }
        return .blue
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
                        Label(inversionNames[inversion], systemImage: "checkmark")
                    } else {
                        Text(inversionNames[inversion])
                    }
                }
                .disabled(!isAvailable)
            }
        } label: {
            HStack(spacing: 8) {
                Text(inversionNames[selectedInversion])
                    .font(.system(size: 28, weight: .bold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
            }
        }
        .accessibilityLabel("Inversion")
    }

    private func noteName(_ note: Int) -> String {
        roots[note % 12]
    }

    var body: some View {
        
        GeometryReader { geometry in
            
            let keyboardWidth = geometry.size.width * 0.95
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

                    HStack(spacing: 24) {
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
                                        .font(.system(size: 44, weight: .bold))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .accessibilityLabel("Root")
                        }

                        Menu {
                            ForEach(chordTypes, id: \.self) { chord in
                                Button {
                                    selectedChord = chord
                                } label: {
                                    if selectedChord == chord {
                                        Label(chord, systemImage: "checkmark")
                                    } else {
                                        Text(chord)
                                    }
                                }
                                .disabled(!hasValidVoicing(chord: chord, root: selectedRoot))
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Text(selectedChord)
                                    .font(.system(size: 44, weight: .bold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .accessibilityLabel("Chord")

                        if selectedChord == "9" || selectedChord == "13" {
                            inversionMenu
                        }

                        if extensionNames.contains(selectedChord) {
                            Menu {
                                Picker("Right hand", selection: $selectedScale) {
                                    Text("Right hand extension").tag("")
                                    ForEach(chordScales[selectedChord] ?? [], id: \.name) { scale in
                                        Text(scale.name).tag(scale.name)
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selectedScale.isEmpty ? "Right hand extension" : selectedScale)
                                        .font(.system(size: 28, weight: .bold))
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                            }
                            .tint(.purple)
                            .accessibilityLabel("Right hand")
                        } else {
                            inversionMenu
                            }
                    }
                    .font(.system(size: 32, weight: .bold))
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
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .padding(.bottom, 8)
                                    }
                                }
                                .frame(
                                    width: blackKeyWidth,
                                    height: blackKeyHeight
                                )
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
            if usesMajorSixSubstitution {
                Text("changed to major six to avoid dissonance on top of chord")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .onAppear {
            loadChordFormulas()
        }
        .onChange(of: selectedChord) { _, _ in
            if !(chordScales[selectedChord] ?? []).contains(where: { $0.name == selectedScale }) {
                selectedScale = ""
            }
            selectValidInversion()
        }
        .onChange(of: selectedRoot) { _, _ in
            selectValidInversion()
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
            rightHandExtensions = chords.reduce(into: [:]) { result, chord in
                result[chord.name] = chord.RHExtension ?? []
            }
            chordScales = chords.reduce(into: [:]) { result, chord in
                result[chord.name] = chord.Scales ?? []
            }
            chordTypes = chords.map(\.name)
            chordIntervals = chords.reduce(into: [:]) { result, chord in
                result[chord.name] = chord.LHIntervals
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
    ContentView()
}
