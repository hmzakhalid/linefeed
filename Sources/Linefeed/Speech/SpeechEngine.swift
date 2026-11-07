import AVFoundation
import CoreML
import FluidAudio
import Foundation
import LinefeedCore
import Observation

@MainActor
@Observable
final class SpeechEngine {
    enum State: Equatable {
        case checking
        case missing
        case downloading(percent: Int)
        case loading
        case ready
        case failed
    }

    /// The model `state` describes.
    private(set) var model: SpeechModel
    private(set) var state = State.checking
    @ObservationIgnored private var manager: AsrManager?
    @ObservationIgnored private var preparation = UUID()

    init(model: SpeechModel) {
        self.model = model
    }

    var isBusy: Bool {
        switch state {
        case .checking, .downloading, .loading: return true
        case .missing, .ready, .failed: return false
        }
    }

    func isInstalled(_ model: SpeechModel) -> Bool {
        AsrModels.modelsExist(at: AsrModels.defaultCacheDirectory(for: model.version), version: model.version)
    }

    func prepare(_ model: SpeechModel, downloading: Bool = false) async {
        if model == self.model, state == .ready || (isBusy && state != .checking) { return }
        let request = UUID()
        preparation = request
        self.model = model
        manager = nil
        guard downloading || isInstalled(model) else {
            state = .missing
            return
        }
        state = downloading ? .downloading(percent: 0) : .loading
        do {
            let models: AsrModels
            if downloading {
                models = try await AsrModels.downloadAndLoad(version: model.version, encoderComputeUnits: .cpuAndGPU) { [weak self] update in
                    Task { @MainActor in
                        guard let self, self.preparation == request else { return }
                        self.state = .downloading(percent: Int(update.fractionCompleted * 100))
                    }
                }
            } else {
                models = try await AsrModels.loadFromCache(version: model.version, encoderComputeUnits: .cpuAndGPU)
            }
            guard preparation == request else { return }
            let concurrency = min(8, max(4, ProcessInfo.processInfo.activeProcessorCount / 2))
            manager = AsrManager(config: ASRConfig(parallelChunkConcurrency: concurrency), models: models)
            state = .ready
        } catch {
            guard preparation == request else { return }
            state = .failed
        }
    }

    /// The loaded model, held by a recording from start to finish so that
    /// switching models meanwhile can't take it away.
    var recognizer: Recognizer? {
        guard state == .ready, let manager else { return nil }
        return Recognizer(model: model, manager: manager)
    }
}

struct Recognizer: Sendable {
    let model: SpeechModel
    fileprivate let manager: AsrManager

    /// Shorter recordings can't hold a word, and the recognizer refuses them.
    private static let shortestSpeech: TimeInterval = 0.3

    /// The recognizer's words with their timing; polishing happens afterwards.
    func transcribe(_ url: URL, language: DictationLanguage) async throws -> TimedTranscript {
        let file = try AVAudioFile(forReading: url)
        let duration = Double(file.length) / file.processingFormat.sampleRate
        guard duration >= Self.shortestSpeech else {
            return TimedTranscript(text: "", rawText: "", duration: duration, words: [])
        }
        var decoderState = TdtDecoderState.make(decoderLayers: await manager.decoderLayerCount)
        let result = try await manager.transcribe(url, decoderState: &decoderState, language: language.hint)
        let words = buildWordTimings(from: result.tokenTimings ?? []).map {
            TimedTranscriptWord(text: $0.word, startTime: $0.startTime, endTime: $0.endTime)
        }
        return TimedTranscript(text: result.text, rawText: result.text, duration: result.duration, words: words)
    }
}
