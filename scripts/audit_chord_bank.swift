import Foundation
@main struct Audit {
 static func main() throws {
  func chord(_ root: Int, _ left: Set<Int>, _ right: Set<Int> = []) -> SavedChord {
   SavedChord(title: "Test", root: root, chord: "9", inversion: 0, option: "", rootEnabled: true, left: left, right: right)
  }
  func pitches(_ notes: Set<Int>) -> [Int] { notes.map { $0 % 12 }.sorted() }
  let diminished = ChordContinuation.choices(after: "dim7")
  precondition(diminished.contains { $0.offset == 0 && $0.chord == "maj" && !$0.slide })
  for offset in [1, 4, 7, 10] {
   for quality in ["maj7", "min7"] {
    precondition(diminished.contains { $0.offset == offset && $0.chord == quality && !$0.slide })
   }
  }
  precondition(diminished.filter { !$0.slide }.count == 9)
  precondition(diminished.filter(\.slide).count == 2)
  precondition(Set(diminished.map(\.id)).count == diminished.count)
  precondition(ChordContinuation.choices(after: "dim").filter { !$0.slide }.count == 2)
  precondition(ChordContinuation.choices(after: "min7b5").contains { $0.chord == "7(b9)" && $0.offset == 5 })
  print("PASS: dim7 common-tone major, four major/minor destinations, slides, unique choices, and other diminished families")
  let source = chord(0, [16,21,22,26], [31,38])
  let data = try JSONEncoder().encode([source])
  let decoded = try JSONDecoder().decode([SavedChord].self, from: data)
  precondition(decoded == [source])
  let bank = ChordBankFile(title: "Practice progression", chords: [source])
  let bankData = try JSONEncoder().encode([bank])
  let reopened = try JSONDecoder().decode([ChordBankFile].self, from: bankData)
  precondition(reopened == [bank])
  var copy = bank; copy.id = UUID(); copy.title = "Alternate progression"
  precondition(copy.id != bank.id && bank.title == "Practice progression")
  var second = source; second.id = UUID()
  var history = ChordBankHistory()
  history.record(before: [], after: [source])
  history.record(before: [source], after: [source, second])
  let pair = [source, second]
  precondition(history.undo(current: pair) == [source])
  precondition(history.undo(current: [source]) == [])
  precondition(!history.canUndo && history.canRedo)
  precondition(history.redo(current: []) == [source])
  history.record(before: [source], after: [])
  precondition(!history.canRedo)
  precondition(history.undo(current: []) == [source])
  print("PASS: multi-step bank undo/redo, removal recovery, and redo cleared after a new edit")
  let intervals = [0,4,7,10,14], degrees = ["1","3","5","b7","9"]
  let same = ChordVoiceLeading.lead(from: source, to: source, intervals: intervals, degrees: degrees)!
  precondition(same.left == source.left && same.right == source.right)
  for root in 0..<12 {
   for offset in 0..<12 {
    let target = chord(root, Set([15,19,21,26].map { $0 + offset }), Set([33,38].map { $0 + offset }))
    let result = ChordVoiceLeading.lead(from: source, to: target, intervals: intervals, degrees: degrees)!
    precondition(result.id == target.id && result.root == target.root && result.bass == target.bass)
    precondition(pitches(result.left) == pitches(target.left) && pitches(result.right) == pitches(target.right))
    precondition(result.left.allSatisfy { (10...33).contains($0) })
    precondition(result.right.min()! > result.left.max()!)
    var otherBass = source; otherBass.root = 11; otherBass.rootEnabled = false
    let independent = ChordVoiceLeading.lead(from: otherBass, to: target, intervals: intervals, degrees: degrees)!
    precondition(independent.left == result.left && independent.right == result.right)
   }
  }
  let unequal = ChordVoiceLeading.movement(from: [16,19,23], to: [16,19,23,26])
  precondition(unequal.distances == [0,0,0])
  print("PASS: persistence, identity recall, 144 two-hand transitions, pitch counts, hand separation, bass independence, unequal voice counts")
 }
}
