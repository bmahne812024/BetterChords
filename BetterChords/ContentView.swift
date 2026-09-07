
import SwiftUI

struct ChordFormulaFile: Decodable {
    let Roots: [String: String]
}

struct ContentView: View {
    
    let totalNotes = 60
    
    // C# D# F# G# A#
    let blackKeyPositions: Set<Int> = [1, 3, 6, 8, 10]
    
    @State private var roots: [String] = []
    @State private var selectedRoot = 0
    
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
                    
                    // MARK: - Root Picker
                    
                    if !roots.isEmpty {
                        
                        Menu {
                            ForEach(0..<roots.count, id: \.self) { index in
                                
                                Button(roots[index]) {
                                    selectedRoot = index
                                }
                            }
                        } label: {
                            HStack {
                                Text(roots[selectedRoot])
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(.blue)
                                
                                
                            }
                            .foregroundStyle(.white)
                        }
                        
                    }
                    
                    
                    // MARK: - Keyboard
                    
                    ZStack(alignment: .topLeading) {
                        
                        // =========================
                        // WHITE KEYS
                        // =========================
                        
                        HStack(spacing: 0) {
                            
                            ForEach(0..<totalNotes, id: \.self) { note in
                                
                                if !isBlackKey(note) {
                                    
                                    let isSelected =
                                        note == selectedRoot
                                    
                                    ZStack(alignment: .bottom) {
                                        
                                        Rectangle()
                                            .fill(
                                                isSelected
                                                ? Color.blue
                                                : Color.white
                                            )
                                        
                                        if isSelected && !roots.isEmpty {
                                            
                                            Text(roots[selectedRoot])
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
                                    note == selectedRoot
                                
                                ZStack(alignment: .bottom) {
                                    
                                    Rectangle()
                                        .fill(
                                            isSelected
                                            ? Color.blue
                                            : Color.black
                                        )
                                    
                                    if isSelected && !roots.isEmpty {
                                        
                                        Text(roots[selectedRoot])
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
                        
                        let middleCNote = 24
                        
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
        .onAppear {
            loadRoots()
        }
    }
    
    
    // MARK: - Load ChordFormulas.json
    
    func loadRoots() {
        
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
            
            print("Loaded roots:")
            print(roots)
            
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


#Preview {
    ContentView()
}
