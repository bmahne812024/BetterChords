import Foundation

nonisolated struct SavedChord: Codable, Identifiable, Equatable {
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
    var bass: Set<Int> { rootEnabled ? [root] : [] }
    var notes: Set<Int> { left.union(right).union(bass) }
}

enum ChordVoiceLeading {
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

    static func lead(from source: SavedChord, to target: SavedChord, intervals: [Int], degrees: [String]) -> SavedChord? {
        guard !target.left.isEmpty else { return nil }
        let leftCandidates = candidates(for: target.left, range: 10...33).filter { notes in
            let pitch = (notes[0] - target.root + 12) % 12
            let degree = zip(intervals, degrees).first { $0.0 % 12 == pitch }?.1
            let number = degree.flatMap { Int($0.filter(\.isNumber)) }
            let floor = number.map { [3, 7].contains(($0 - 1) % 7 + 1) } == true ? 14 : 10
            return notes[0] >= floor
        }
        let rightCandidates = candidates(for: target.right, range: 10...59)
        var best: (left: [Int], right: [Int], score: Int, tie: Int, distances: [Int])?
        let sourceLeft = source.left.sorted(), sourceRight = source.right.sorted()
        for left in leftCandidates {
            let leftMove = movement(from: sourceLeft, to: left)
            for right in rightCandidates where right.isEmpty || right[0] > left.last! {
                let rightMove = movement(from: sourceRight, to: right)
                let score = leftMove.score + rightMove.score
                let tie = zip(left, target.left.sorted()).reduce(0) { $0 + abs($1.0 - $1.1) }
                    + zip(right, target.right.sorted()).reduce(0) { $0 + abs($1.0 - $1.1) }
                if best == nil || score < best!.score || (score == best!.score && tie < best!.tie) {
                    best = (left, right, score, tie, leftMove.distances + rightMove.distances)
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
