import SwiftUI
import UniformTypeIdentifiers

struct ChordBankDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var bank: ChordBankFile
    init(bank: ChordBankFile) { self.bank = bank }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        bank = try JSONDecoder().decode(ChordBankFile.self, from: data)
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: try JSONEncoder().encode(bank))
    }
}
