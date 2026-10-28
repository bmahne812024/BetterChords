import AVFoundation
import Combine
import Foundation

/// One shared sampled piano plays the exact visible voicing, without recordings per chord.
@MainActor
final class ChordAudioPlayer: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published var errorMessage: String?

    @Published private(set) var playingStep: Int?
    private var progressionTask: Task<Void, Never>?

    private var engine: AVAudioEngine?
    private var sampler: AVAudioUnitSampler?
    private var soundingNotes = Set<UInt8>()
    private var releaseTask: Task<Void, Never>?

    func play(keyIndices: Set<Int>) {
        stop()
        sound(keyIndices: keyIndices)
    }

    func playProgression(_ events: [(notes: Set<Int>, beats: Double)], bpm: Int, repeating: Bool = false) {
        stop()
        guard !events.isEmpty, (30...240).contains(bpm),
              events.allSatisfy({ !$0.notes.isEmpty && $0.beats > 0 && $0.beats <= 32 }) else { return }
        progressionTask = Task { [weak self] in
            repeat {
                for (index, event) in events.enumerated() {
                    guard !Task.isCancelled, let self else { return }
                    self.playingStep = index
                    self.sound(keyIndices: event.notes)
                    // Progression durations, rather than the single-chord preview timer, own release.
                    self.releaseTask?.cancel(); self.releaseTask = nil
                    do { try await Task.sleep(for: .seconds(event.beats * 60 / Double(bpm))) }
                    catch { return }
                }
            } while repeating && !Task.isCancelled
            self?.releaseNotes()
            self?.playingStep = nil
            self?.progressionTask = nil
        }
    }

    private func sound(keyIndices: Set<Int>) {
        releaseNotes()
        errorMessage = nil
        // Key index 24 is Middle C (MIDI 60); the keyboard starts at C2.
        let notes = Set(keyIndices.filter { (0..<60).contains($0) }.map { UInt8($0 + 36) })
        guard !notes.isEmpty else { return }
        do {
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            #endif
            try preparePiano()
            guard let sampler, let engine else { return }
            if !engine.isRunning { try engine.start() }
            // Clear release tails on retrigger, and reserve headroom for dense voicings.
            sampler.sendController(120, withValue: 0, onChannel: 0)
            sampler.masterGain = -12 - 20 * log10(max(1, Float(notes.count) / 4))
            // All note-ons are sent together, with no arpeggio or scale sequencing.
            for note in notes.sorted() { sampler.startNote(note, withVelocity: 78, onChannel: 0) }
            soundingNotes = notes
            isPlaying = true
            releaseTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(2.5)) } catch { return }
                guard !Task.isCancelled else { return }
                self?.stop()
            }
        } catch {
            stop()
            errorMessage = "Couldn’t play the chord. Please try again."
        }
    }

    func stop() {
        progressionTask?.cancel()
        progressionTask = nil
        playingStep = nil
        releaseNotes()
    }

    private func releaseNotes() {
        releaseTask?.cancel()
        releaseTask = nil
        for note in soundingNotes { sampler?.stopNote(note, onChannel: 0) }
        soundingNotes.removeAll()
        isPlaying = false
    }

    func suspend() {
        stop()
        sampler?.sendController(120, withValue: 0, onChannel: 0)
        engine?.pause()
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    private func preparePiano() throws {
        guard engine == nil else { return }
        guard let url = Bundle.main.url(forResource: "BetterChordsPiano", withExtension: "sf2") else {
            throw CocoaError(.fileNoSuchFile)
        }
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        try sampler.loadSoundBankInstrument(at: url, program: 0,
                                            bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB), bankLSB: 0)
        // Leave headroom for the bass and both hands sounding simultaneously.
        engine.mainMixerNode.outputVolume = 0.65
        sampler.masterGain = -12
        engine.prepare()
        self.engine = engine
        self.sampler = sampler
    }
}
