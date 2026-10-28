import Foundation

nonisolated struct SavedChord: Codable, Identifiable, Equatable, Sendable {
    var id = UUID()
    var title: String
    var root: Int
    var chord: String
    var inversion: Int
    var option: String
    var rootEnabled: Bool
    var left: Set<Int>
    var right: Set<Int>
    var voiceLed = false
    var movementSummary: String?
    var bassNote: Int? = nil
    var harmonicIdentity: String? = nil
    var melodyNote: Int? = nil
    var annotation: String? = nil
    var soundingChord: String {
        if let harmonicIdentity { return harmonicIdentity }
        // Interpret legacy sixth substitutions without rewriting their saved notes.
        let pitches = Set(left.union(right).map { ($0 - root + 120) % 12 })
        if inversion == 1 && pitches.contains(9) && !pitches.contains(11) {
            if chord == "maj7" { return "6" }
            if chord == "minmaj7" { return "min6" }
        }
        return chord
    }
    var bass: Set<Int> { rootEnabled ? [bassNote ?? root] : [] }
    var notes: Set<Int> { left.union(right).union(bass) }
}

nonisolated enum ChordVoiceLeading {
    private static func cost(_ distance: Int) -> Int {
        distance + max(0, distance - 2) * 12
    }

    // Keep corresponding voices in order. With unequal counts, match an ordered
    // subset and let added/removed voices incur a fixed cost instead of crossing.
    static func movement(from source: [Int], to target: [Int]) -> (score: Int, distances: [Int]) {
        if source.count == target.count {
            let distances = zip(source, target).map { abs($0 - $1) }
            return (distances.reduce(0) { $0 + cost($1) }, distances)
        }
        struct Match { var score: Int; var distances: [Int] }
        var table = Array(repeating: Array(repeating: Match(score: 0, distances: []), count: target.count + 1), count: source.count + 1)
        for i in 0...source.count {
            for j in 0...target.count {
                if i == 0 { table[i][j].score = j * 36; continue }
                if j == 0 { table[i][j].score = i * 36; continue }
                let distance = abs(source[i - 1] - target[j - 1])
                let previous = table[i - 1][j - 1]
                let matched = Match(score: previous.score + cost(distance), distances: previous.distances + [distance])
                let deleted = Match(score: table[i - 1][j].score + 36, distances: table[i - 1][j].distances)
                let inserted = Match(score: table[i][j - 1].score + 36, distances: table[i][j - 1].distances)
                table[i][j] = [matched, deleted, inserted].min { $0.score < $1.score }!
            }
        }
        let result = table[source.count][target.count]
        return (result.score, result.distances)
    }

    // Preserve each hand's pitch-class multiset, including octave doublings.
    static func candidates(for notes: Set<Int>, range: ClosedRange<Int>) -> [[Int]] {
        if notes.isEmpty { return [[]] }
        let counts = Dictionary(grouping: notes, by: { $0 % 12 }).mapValues(\.count)
        var result: [[Int]] = []
        func visit(_ next: Int, _ remaining: [Int: Int], _ chosen: [Int]) {
            if chosen.count == notes.count { result.append(chosen); return }
            guard next <= range.upperBound else { return }
            for note in next...range.upperBound where (remaining[note % 12] ?? 0) > 0 {
                var rest = remaining
                rest[note % 12, default: 0] -= 1
                visit(note + 1, rest, chosen + [note])
            }
        }
        visit(range.lowerBound, counts, [])
        return result
    }

    static func lead(from source: SavedChord, to target: SavedChord, intervals: [Int], degrees: [String], preferences: VoicingPreferences = .init(), preserveShape: Bool = false) -> SavedChord? {
        guard !target.left.isEmpty else { return nil }
        let targetLeft = target.left.sorted(), targetRight = target.right.sorted()
        let leftCandidates = candidates(for: target.left, range: preferences.leftRange).filter { notes in
            if preserveShape {
                let shift = notes[0] - targetLeft[0]
                guard zip(notes, targetLeft).allSatisfy({ $0.0 - $0.1 == shift }) else { return false }
            }
            let pitch = (notes[0] - target.root + 12) % 12
            let degree = zip(intervals, degrees).first { $0.0 % 12 == pitch }?.1
            let number = degree.flatMap { Int($0.filter(\.isNumber)) }
            let floor = number.map { [3, 7].contains(($0 - 1) % 7 + 1) } == true ? 14 : 10
            return notes[0] >= floor
        }
        let rightCandidates = candidates(for: target.right, range: 10...59).filter { notes in
            guard preserveShape, let first = notes.first, let original = targetRight.first else { return true }
            return zip(notes, targetRight).allSatisfy { $0.0 - $0.1 == first - original }
        }
        var best: (left: [Int], right: [Int], score: Int, tie: Int, distances: [Int])?
        let sourceLeft = source.left.sorted(), sourceRight = source.right.sorted()
        let originalLeft = target.left.sorted(), originalRight = target.right.sorted()
        let rightMoves = rightCandidates.map { right in
            (notes: right, move: movement(from: sourceRight, to: right),
             tie: zip(right, originalRight).reduce(0) { $0 + abs($1.0 - $1.1) })
        }
        for left in leftCandidates {
            let leftMove = movement(from: sourceLeft, to: left)
            let leftTie = zip(left, originalLeft).reduce(0) { $0 + abs($1.0 - $1.1) }
            for right in rightMoves where preferences.accepts(left: Set(left), right: Set(right.notes)) {
                if preserveShape, let first = right.notes.first, let original = targetRight.first,
                   first - original != left[0] - targetLeft[0] { continue }
                let score = leftMove.score + right.move.score
                let tie = leftTie + right.tie
                if best == nil || score < best!.score || (score == best!.score && tie < best!.tie) {
                    best = (left, right.notes, score, tie, leftMove.distances + right.move.distances)
                }
            }
        }
        guard let best else { return nil }
        var result = target
        result.left = Set(best.left)
        result.right = Set(best.right)
        result.voiceLed = true
        let held = best.distances.filter { $0 == 0 }.count
        let steps = best.distances.filter { (1...2).contains($0) }.count
        let leaps = best.distances.filter { $0 > 2 }.count
        result.movementSummary = "\(held) held · \(steps) by step · \(leaps) larger moves"
        let countChange = abs(source.left.count - target.left.count) + abs(source.right.count - target.right.count)
        if countChange > 0 { result.movementSummary! += " · \(countChange) added/removed voices" }
        return result
    }
}

nonisolated struct ChordBankFile: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var chords: [SavedChord]
    var modified = Date()
    var schemaVersion: Int? = 2
}

struct ChordApproach: Identifiable {
    struct Step { let offset: Int; let chord: String }
    let id: String
    let steps: [Step]
    static func choices(count: Int, target: String, minor: Bool) -> [ChordApproach] {
        let five = minor ? "7(b9)" : "9"
        switch count {
        case 1: return [
            .init(id: "V → I", steps: [.init(offset: 7, chord: five)]),
            .init(id: "♭II7 → I", steps: [.init(offset: 1, chord: "7(#11)")]),
            .init(id: "Half-step slide → I", steps: [.init(offset: -1, chord: target)]),
            .init(id: "♭VII7 → I", steps: [.init(offset: 10, chord: "9")])]
        case 2: return [
            .init(id: minor ? "iiø–V → i" : "ii–V → I", steps: [.init(offset: 2, chord: minor ? "min7b5" : "min9"), .init(offset: 7, chord: five)]),
            .init(id: "II7–V → I", steps: [.init(offset: 2, chord: "9"), .init(offset: 7, chord: five)]),
            .init(id: "ii–♭II7 → I", steps: [.init(offset: 2, chord: minor ? "min7b5" : "min9"), .init(offset: 1, chord: "7(#11)")]),
            .init(id: "II7–♭II7 → I", steps: [.init(offset: 2, chord: "9"), .init(offset: 1, chord: "7(#11)")]),
            .init(id: "ivm–♭VII7 → I", steps: [.init(offset: 5, chord: "min9"), .init(offset: 10, chord: "9")])]
        case 3: return [
            .init(id: "VI7–ii–V → I", steps: [.init(offset: 9, chord: "7(b9)"), .init(offset: 2, chord: minor ? "min7b5" : "min9"), .init(offset: 7, chord: five)]),
            .init(id: "VI7–II7–V → I", steps: [.init(offset: 9, chord: "7(b9)"), .init(offset: 2, chord: "9"), .init(offset: 7, chord: five)]),
            .init(id: "VI7–ii–♭II7 → I", steps: [.init(offset: 9, chord: "7(b9)"), .init(offset: 2, chord: "min9"), .init(offset: 1, chord: "7(#11)")]),
            .init(id: "♭III7–II7–♭II7 → I", steps: [.init(offset: 3, chord: "9"), .init(offset: 2, chord: "9"), .init(offset: 1, chord: "7(#11)")])]
        default: return [
            .init(id: "iii–VI7–ii–V → I", steps: [.init(offset: 4, chord: minor ? "min7b5" : "min7"), .init(offset: 9, chord: "7(b9)"), .init(offset: 2, chord: minor ? "min7b5" : "min9"), .init(offset: 7, chord: five)]),
            .init(id: "III7–VI7–II7–V → I", steps: [.init(offset: 4, chord: "7(b9)"), .init(offset: 9, chord: "7(b9)"), .init(offset: 2, chord: "9"), .init(offset: 7, chord: five)]),
            .init(id: "iii–VI7–ii–♭II7 → I", steps: [.init(offset: 4, chord: "min7"), .init(offset: 9, chord: "7(b9)"), .init(offset: 2, chord: "min9"), .init(offset: 1, chord: "7(#11)")]),
            .init(id: "III7–♭III7–II7–♭II7 → I", steps: [.init(offset: 4, chord: "9"), .init(offset: 3, chord: "9"), .init(offset: 2, chord: "9"), .init(offset: 1, chord: "7(#11)")])]
        }
    }
}

nonisolated struct ChordBankHistory {
    private(set) var undoStack: [[SavedChord]] = []
    private(set) var redoStack: [[SavedChord]] = []
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    mutating func record(before: [SavedChord], after: [SavedChord]) {
        guard before != after else { return }
        undoStack.append(before)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack = []
    }
    mutating func undo(current: [SavedChord]) -> [SavedChord]? {
        guard let previous = undoStack.popLast() else { return nil }
        redoStack.append(current)
        return previous
    }
    mutating func redo(current: [SavedChord]) -> [SavedChord]? {
        guard let next = redoStack.popLast() else { return nil }
        undoStack.append(current)
        return next
    }
}

nonisolated struct ChordContinuation: Identifiable {
    let label: String
    let offset: Int
    let chord: String
    var slide = false
    var id: String { "\(offset):\(chord)" }

    static func choices(after chord: String) -> [ChordContinuation] {
        var choices: [ChordContinuation]
        if chord == "dim7" {
            choices = [.init(label: "Common-tone resolution to major", offset: 0, chord: "maj")]
            // Each note of a fully diminished seventh can act as a leading tone.
            for (offset, label) in [(1, "up a half step"), (4, "up a major third"),
                                    (7, "up a fifth"), (10, "up a minor seventh")] {
                choices += [.init(label: "Resolve \(label) to major", offset: offset, chord: "maj7"),
                            .init(label: "Resolve \(label) to minor", offset: offset, chord: "min7")]
            }
        } else if chord.contains("dim") {
            choices = [.init(label: "Resolve up a half step", offset: 1, chord: "maj7"),
                       .init(label: "Resolve to minor", offset: 1, chord: "min7")]
        } else if chord.contains("b5") && chord.hasPrefix("min") {
            choices = [.init(label: "Minor ii–V", offset: 5, chord: "7(b9)"),
                       .init(label: "Relative major", offset: 3, chord: "maj7")]
        } else if JazzChordFamily.of(chord) == .suspended {
            choices = [.init(label: "Release suspension to dominant", offset: 0, chord: "7"),
                       .init(label: "Resolve to major tonic", offset: 5, chord: "maj"),
                       .init(label: "Resolve to minor tonic", offset: 5, chord: "min6")]
        } else if chord.hasPrefix("min") {
            choices = [.init(label: "ii–V motion", offset: 5, chord: "9"),
                       .init(label: "Up to relative major", offset: 3, chord: "maj7"),
                       .init(label: "Major color below", offset: 8, chord: "maj7"),
                       .init(label: "Turn toward dominant", offset: 7, chord: "7(b9)")]
        } else if JazzChordFamily.of(chord) == .dominant {
            choices = [.init(label: "Resolve up a fourth", offset: 5, chord: "maj7"),
                       .init(label: "Resolve to minor", offset: 5, chord: "min7"),
                       .init(label: "Tritone resolution", offset: -1, chord: "maj7"),
                       .init(label: "Tritone to minor", offset: -1, chord: "min7"),
                       .init(label: "Deceptive minor", offset: 2, chord: "min7")]
        } else {
            choices = [.init(label: "Up a fourth", offset: 5, chord: "maj7"),
                       .init(label: "Relative minor", offset: 9, chord: "min7"),
                       .init(label: "Move to ii", offset: 2, chord: "min7"),
                       .init(label: "Turn toward dominant", offset: 7, chord: "9")]
        }
        choices += [.init(label: "Slide down a half step", offset: -1, chord: chord, slide: true),
                    .init(label: "Slide up a half step", offset: 1, chord: chord, slide: true)]
        var seen: Set<String> = []
        return choices.filter { seen.insert($0.id).inserted }
    }
}

nonisolated struct BankKeyboardEdit: Equatable {
    let cardID: UUID?
    let root: Int
    let chord: String
    let inversion: Int
    let option: String
    let rootEnabled: Bool
    let recalled: SavedChord?
    var preferences: VoicingPreferences? = nil
    var bassNote: Int? = nil
}

nonisolated struct VoiceLeadingCandidate: Sendable {
    var chord: SavedChord
    let intervals: [Int]
    let degrees: [String]
    var preserveShape = false
}

extension ChordVoiceLeading {
    nonisolated static func chordOptions(for chord: String) -> [String] {
        let families = [
            ["maj", "maj7", "maj9", "maj13", "maj7(#11)", "maj9(#11)"],
            ["6", "6/9", "add9"],
            ["min", "min7", "min9", "min11", "min13", "min(add9)"],
            ["min6", "min6/9"], ["minmaj7", "minmaj9"],
            ["7", "9", "13", "13(9)", "9(13)", "7(#11)", "9(#11)", "13(#11)", "7(b9)", "7(#9)", "7alt", "13(b9)", "7(b13)", "9(b13)", "7(b9, #11)", "7(b9, b13)"],
            ["min7b5", "min9b5", "min11b5"],
            ["sus4", "sus4(add9)", "7sus4", "9sus4", "13sus4", "7sus4(b9)"]
        ]
        return [chord] + (families.first { $0.contains(chord) } ?? []).filter { $0 != chord }
    }

    nonisolated static func best(from fixed: SavedChord, candidates: [VoiceLeadingCandidate], original: SavedChord, preferences: VoicingPreferences = .init()) -> SavedChord? {
        var best: (chord: SavedChord, score: Int, tie: Int)?
        for candidate in candidates {
            guard let fitted = lead(from: fixed, to: candidate.chord, intervals: candidate.intervals, degrees: candidate.degrees, preferences: preferences, preserveShape: candidate.preserveShape) else { continue }
            let score = movement(from: fixed.left.sorted(), to: fitted.left.sorted()).score
                + movement(from: fixed.right.sorted(), to: fitted.right.sorted()).score
            // Keep the current harmony/arrangement on a movement tie.
            let tie = (fitted.chord == original.chord ? 0 : 2) + (fitted.option == original.option ? 0 : 1)
            if best == nil || score < best!.score || (score == best!.score && tie < best!.tie) {
                best = (fitted, score, tie)
            }
        }
        return best?.chord
    }
}

// MARK: - Context, identity and playability
nonisolated enum JazzChordFamily: String, Codable, CaseIterable {
    case major, minor, minorMajor, dominant, suspended, diminished, halfDiminished, augmented, slash
    static func of(_ chord: String) -> Self {
        if (chord.contains("/") || chord.contains(" over ")) && !["6/9", "min6/9"].contains(chord) { return .slash }
        if chord.hasPrefix("min"), chord.contains("b5") { return .halfDiminished }
        if chord.hasPrefix("minmaj") { return .minorMajor }
        if chord.hasPrefix("min") { return .minor }
        if chord.hasPrefix("dim") { return .diminished }
        if chord == "aug" || chord == "maj7(#5)" { return .augmented }
        if chord.contains("sus") { return .suspended }
        if chord == "6" || chord == "6/9" || chord == "add9" || chord.hasPrefix("maj") { return .major }
        return .dominant
    }
}

nonisolated struct ChordTheoryMetadata: Codable {
    let family: String
    let defining: [Int]
    let optional: [Int]
    let omittable: [Int]
    let contextual: [Int]
    let explanation: String
    let sources: [String]
}

nonisolated struct HarmonicContext: Equatable {
    var key: Int? = nil
    var setting = "Tonal"
    var destination: Int? = nil
}

nonisolated struct VoicingPreferences: Codable, Equatable, Sendable {
    var leftSpan = 23
    var rightSpan = 59
    var register = "Current"
    var density = "Any"
    var topNote: Int? = nil // Keyboard index; MIDI = index + 36.
    var role = "Solo piano"

    var leftRange: ClosedRange<Int> {
        switch register { case "Lower": return 10...26; case "Higher": return 19...33; default: return 10...33 }
    }
    func accepts(left: Set<Int>, right: Set<Int>) -> Bool {
        guard let low = left.min(), let high = left.max(), left.allSatisfy(leftRange.contains),
              high - low <= leftSpan, right.allSatisfy({ (0..<60).contains($0) }) else { return false }
        if let rlo = right.min(), let rhi = right.max() {
            guard rlo > high, rhi - rlo <= rightSpan else { return false }
        }
        let count = left.count + right.count
        if density == "Sparse" && count > 4 { return false }
        if density == "Rich" && count < 5 { return false }
        if let topNote, left.union(right).max() != topNote { return false }
        return true
    }
    // Whole-octave placement preserves pitch identities. Named families keep their geometry.
    func fit(left: Set<Int>, right: Set<Int>, preserveShape: Bool = false, minimumLeft: Int = 10) -> (left: Set<Int>, right: Set<Int>)? {
        let shifts = [0, -12, 12, -24, 24, -36, 36]
        for l in shifts {
            for r in preserveShape ? [l] : shifts {
                let lhs = Set(left.map { $0 + l }), rhs = Set(right.map { $0 + r })
                if lhs.min().map({ $0 >= minimumLeft }) == true && accepts(left: lhs, right: rhs) { return (lhs, rhs) }
            }
        }
        return nil
    }
    var guidance: String {
        "No arrangement fits the chosen top note, hand span, register and density. Try another voicing or relax one preference."
    }
}

nonisolated enum JazzTheory {
    static func soundingQuality(_ selected: String, inversion: Int, fixed: Bool) -> String {
        if !fixed && inversion == 1 {
            if selected == "maj7" { return "6" }
            if selected == "minmaj7" { return "min6" }
        }
        return selected
    }
    static func symbol(root: Int, chord: String, bass: Int? = nil) -> String {
        let names = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
        let suffix = chord == "maj" ? "" : chord.replacingOccurrences(of: "min", with: "m").replacingOccurrences(of: "#", with: "♯").replacingOccurrences(of: "b", with: "♭")
        let result = names[(root % 12 + 12) % 12] + suffix
        if let bass, bass % 12 != root % 12 { return result + "/" + names[(bass % 12 + 12) % 12] }
        return result
    }
    static func note(_ index: Int) -> String {
        let names = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
        return names[(index % 12 + 12) % 12] + String((index + 36) / 12 - 1)
    }
    static func contextChoices(after chord: String, root: Int, context: HarmonicContext, quality: String) -> [ChordContinuation] {
        var result = ChordContinuation.choices(after: chord)
        if context.setting == "Blues" && JazzChordFamily.of(chord) == .dominant {
            result = [.init(label: "Blues tonic: move to IV7", offset: 5, chord: "7"),
                      .init(label: "Blues turnaround: move to V7", offset: 7, chord: "7"),
                      .init(label: "Blues tonic: stay on I7", offset: 0, chord: "9")]
        } else if context.setting == "Modal" {
            result = [.init(label: "Modal color: sustain this center", offset: 0, chord: chord),
                      .init(label: "Modal planing: move up a whole step", offset: 2, chord: chord),
                      .init(label: "Modal planing: move down a whole step", offset: -2, chord: chord)]
        }
        if quality != "Suggested" {
            let family = JazzChordFamily.of(chord)
            if family == .diminished || family == .dominant {
                result = result.map { choice in
                    if choice.slide { return choice }
                    return ChordContinuation(label: (JazzChordFamily.of(chord) == .diminished && choice.offset == 0 ? "Common-tone embellishment" : "Resolution") + " · chosen tonic color", offset: choice.offset, chord: quality)
                }
            }
        }
        if let destination = context.destination {
            result = result.filter { (root + $0.offset + 12) % 12 == destination }
        }
        var seen: Set<String> = []
        return result.filter { seen.insert($0.id).inserted }.sorted { a, b in
            guard let key = context.key else { return false }
            let aHome = (root + a.offset + 12) % 12 == key
            let bHome = (root + b.offset + 12) % 12 == key
            return aHome && !bHome
        }
    }
}

nonisolated struct PracticeStep: Sendable {
    let root: Int
    let chord: String
    var beats: Double = 4
    var bass: Int? = nil
}
nonisolated struct JazzPracticeTemplate: Identifiable, Sendable {
    let id: String
    let explanation: String
    let steps: [PracticeStep]
    static let all: [JazzPracticeTemplate] = {
        func s(_ root: Int, _ chord: String, _ beats: Double = 4, _ bass: Int? = nil) -> PracticeStep {
            PracticeStep(root: root, chord: chord, beats: beats, bass: bass)
        }
        let rhythmA = [s(0,"6",2),s(9,"7",2),s(2,"min7",2),s(7,"7",2),
                       s(0,"6",2),s(9,"7",2),s(2,"min7",2),s(7,"7",2),
                       s(0,"7"),s(5,"maj7",2),s(6,"dim7",2),
                       s(0,"6",2),s(7,"7",2),s(0,"6",2),s(7,"7",2)]
        let bridge = [s(4,"7",8),s(9,"7",8),s(2,"7",8),s(7,"7",8)]
        return [
            .init(id:"Major ii–V–I", explanation:"Predominant → dominant → major tonic; four bars.", steps:[s(2,"min9"),s(7,"13"),s(0,"maj9",8)]),
            .init(id:"Minor iiø–V–i", explanation:"Half-diminished ii and altered dominant resolve to minor sixth.", steps:[s(2,"min7b5"),s(7,"7(b9)"),s(0,"min6",8)]),
            .init(id:"Turnaround", explanation:"I–VI7–ii–V returns to the tonic on the next repeat.", steps:[s(0,"6",2),s(9,"7(b9)",2),s(2,"min9",2),s(7,"9",2)]),
            .init(id:"Dameron turnaround", explanation:"Imaj7–♭IIImaj7–♭VImaj7–♭IImaj7; a contrasting return to I.", steps:[s(0,"maj7"),s(3,"maj7"),s(8,"maj7"),s(1,"maj7")]),
            .init(id:"Jazz blues · 12 bars", explanation:"Tonic dominant blues with a quick IV, ii–V and turnaround.", steps:[s(0,"7"),s(5,"7"),s(0,"7"),s(0,"7"),s(5,"7"),s(6,"dim7"),s(0,"7"),s(9,"7"),s(2,"min7"),s(7,"7"),s(0,"7",2),s(9,"7",2),s(2,"min7",2),s(7,"7",2)]),
            .init(id:"Rhythm changes · 32 bars", explanation:"One AABA variant, transposed from C. Each A is eight bars; the bridge chains dominants.", steps:rhythmA + rhythmA + bridge + rhythmA),
            .init(id:"Bird-style blues · 12 bars", explanation:"A major-tonic bebop blues variant with descending ii–V motion.", steps:[s(0,"maj7"),s(11,"min7b5",2),s(4,"7",2),s(9,"min7",2),s(2,"7",2),s(7,"min7",2),s(0,"7",2),s(5,"maj7"),s(5,"min7",2),s(10,"7",2),s(4,"min7",2),s(9,"7",2),s(3,"min7",2),s(8,"7",2),s(2,"min7"),s(7,"7"),s(0,"maj7",2),s(9,"7",2),s(2,"min7",2),s(7,"7",2)]),
            .init(id:"Major-third tonic cycle", explanation:"Three major-third-related centers, each approached by its dominant; a Coltrane-style exercise, not a song transcription.", steps:[s(7,"7",2),s(0,"maj7",2),s(11,"7",2),s(4,"maj7",2),s(3,"7",2),s(8,"maj7",2)]),
            .init(id:"Common-tone diminished", explanation:"I–I°7–I retains the root while neighboring voices resolve.", steps:[s(0,"maj"),s(0,"dim7"),s(0,"maj",8)]),
            .init(id:"Minor line cliché", explanation:"A descending bass under tonic minor: 1–7–♭7–6. Seventh/sixth colors are explicit.", steps:[s(0,"min",4,0),s(0,"minmaj7",4,11),s(0,"min7",4,10),s(0,"min6",4,9)])
        ]
    }()
}
