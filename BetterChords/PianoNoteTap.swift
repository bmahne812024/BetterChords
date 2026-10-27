import SwiftUI

struct PianoNoteTap: ViewModifier {
    let note: Int
    let highlighted: Bool
    let name: String
    let play: (Int) -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { if highlighted { play(note) } }
            .accessibilityHidden(!highlighted)
            .accessibilityLabel("Play \(name), octave \(note / 12 + 2)")
            .accessibilityAddTraits(.isButton)
    }
}
