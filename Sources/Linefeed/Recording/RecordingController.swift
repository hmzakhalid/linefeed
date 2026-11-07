import AppKit
import LinefeedCore
import Observation

@MainActor
@Observable
final class RecordingController {
    nonisolated static let lengthLimit: TimeInterval = 20 * 60

    /// Everything a recording needs from start to finish, fixed when it starts.
    private struct Session {
        let draft: SessionDraft
        let recognizer: Recognizer
        let language: DictationLanguage
    }

    private(set) var phase = RecordingPhase.idle {
        didSet {
            onPhaseChange()
            if phase == .idle, let whenIdle {
                self.whenIdle = nil
                whenIdle()
            }
        }
    }
    @ObservationIgnored var onPhaseChange: () -> Void = {}
    /// Runs once the next time Linefeed is idle, then is cleared.
    @ObservationIgnored var whenIdle: (() -> Void)?
    @ObservationIgnored var onReport: (RecordingReport) -> Void = { _ in }
    @ObservationIgnored var onSessionSaved: () -> Void = {}

    @ObservationIgnored private let settings: Settings
    @ObservationIgnored private let speech: SpeechEngine
    @ObservationIgnored private let microphones: Microphones
    @ObservationIgnored private let store: SessionStore
    @ObservationIgnored private let vocabulary: VocabularyStore
    @ObservationIgnored private let recorder = AudioRecorder()
    @ObservationIgnored private let pointer = PointerTracker()
    @ObservationIgnored private let trail = TrailOverlayController()
    @ObservationIgnored private let sounds = SoundCues()
    @ObservationIgnored private let island: RecordingIslandController

    @ObservationIgnored private var session: Session?
    @ObservationIgnored private var detector = CircleGestureDetector()
    @ObservationIgnored private var audioActivity = AudioActivityEvidence()
    /// Linefeed's own start sound reaches the microphone; it isn't speech.
    @ObservationIgnored private var listensAfter = Date.distantPast
    @ObservationIgnored private var screenshotTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var limitTimer: Timer?

    init(settings: Settings, speech: SpeechEngine, microphones: Microphones, store: SessionStore, vocabulary: VocabularyStore) {
        self.settings = settings
        self.speech = speech
        self.microphones = microphones
        self.store = store
        self.vocabulary = vocabulary
        island = RecordingIslandController(appearance: settings.island)
        recorder.onLevel = { [weak self] level in
            guard let self else { return }
            if Date() >= self.listensAfter { self.audioActivity.observe(level: level) }
            self.island.update(level: level)
        }
        recorder.onInterruption = { [weak self] in
            guard let self, case .recording = self.phase else { return }
            self.stop()
            self.tell(.microphoneChanged)
        }
        pointer.onMove = { [weak self] point in self?.pointerMoved(to: point) }
        settings.observe(\.island) { [weak self, settings] in self?.island.apply(settings.island) }
    }

    func handle(_ gesture: ShortcutGesture) {
        perform(RecordingCommand.resolve(gesture, in: phase))
    }

    func perform(_ command: RecordingCommand) {
        switch command {
        case .start(let mode): start(mode)
        case .stop: stop()
        case .promoteToHandsFree: promote()
        case .discard: discard(quietly: false)
        case .discardIfUntouched:
            if !audioActivity.detected, screenshotTasks.isEmpty { discard(quietly: true) }
        case .queue(let mode): if case .finishing = phase { phase = .finishing(queued: mode) }
        case .dropQueued: if case .finishing = phase { phase = .finishing(queued: nil) }
        case .ignore: break
        }
    }

    private func start(_ mode: RecordingMode) {
        guard phase == .idle else { return }
        do {
            guard let recognizer = speech.recognizer else { throw LinefeedError.speechNotReady }
            microphones.refresh()
            guard let microphone = microphones.device(for: settings.microphoneID) else {
                throw LinefeedError.microphoneUnavailable
            }
            let language = recognizer.model.language(for: settings.language)
            let draft = try store.begin(
                microphone: microphone.name,
                model: recognizer.model.title,
                language: language.title,
                mode: mode
            )
            listensAfter = settings.playsSounds ? Date().addingTimeInterval(sounds.play(.start)) : .distantPast
            do {
                try recorder.start(device: microphone)
            } catch {
                draft.discard()
                throw error
            }
            draft.markRecordingStarted()
            session = Session(draft: draft, recognizer: recognizer, language: language)
        } catch {
            tell(.problem(error))
            return
        }

        detector.reset()
        audioActivity.reset()
        screenshotTasks.removeAll()
        phase = .recording(mode)
        pointer.start()
        trail.start()
        island.show(language: session?.language.title ?? "", mode: mode)
        let timer = Timer(timeInterval: Self.lengthLimit, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, case .recording = self.phase else { return }
                self.stop()
                self.tell(.limitReached)
            }
        }
        limitTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private func promote() {
        guard case .recording(.quick) = phase else { return }
        phase = .recording(.handsFree)
        session?.draft.mode = .handsFree
        island.update(mode: .handsFree)
    }

    private func stop() {
        guard case .recording = phase, let session else { return }
        endCapture()
        session.draft.markRecordingEnded()
        let target = DeliveryTarget.current()
        phase = .finishing(queued: nil)
        island.showFinishing()
        let audio = recorder.stop()
        if settings.playsSounds { sounds.play(.stop) }
        let pending = screenshotTasks
        screenshotTasks.removeAll()
        let heardSpeech = audioActivity.detected
        self.session = nil
        Task {
            await finish(session, audio: audio, screenshots: pending, heardSpeech: heardSpeech, target: target)
        }
    }

    private func discard(quietly: Bool) {
        guard case .recording = phase, let session else { return }
        endCapture()
        if let audio = recorder.stop() {
            try? FileManager.default.removeItem(at: audio)
        }
        let pending = screenshotTasks
        pending.forEach { $0.cancel() }
        screenshotTasks.removeAll()
        self.session = nil
        phase = .idle
        if quietly {
            island.hide()
        } else {
            tell(.discarded)
        }
        if pending.isEmpty {
            session.draft.discard()
        } else {
            Task {
                for task in pending { await task.value }
                session.draft.discard()
            }
        }
    }

    private func finish(
        _ session: Session,
        audio: URL?,
        screenshots pending: [Task<Void, Never>],
        heardSpeech: Bool,
        target: DeliveryTarget?
    ) async {
        var recognized: TimedTranscript?
        var keptAudio = false
        if let audio {
            recognized = try? await session.recognizer.transcribe(audio, language: session.language)
            if recognized == nil {
                keptAudio = session.draft.keepAudio(audio)
            } else {
                try? FileManager.default.removeItem(at: audio)
            }
        }
        for task in pending { await task.value }

        let destination = target?.destination ?? .general
        var transcript: TimedTranscript?
        if let recognized {
            let language = session.language == .automatic ? DictationLanguage.detected(in: recognized.rawText) : session.language
            transcript = await polish(recognized, language: language, for: destination)
        }
        let saved = session.draft.session(with: transcript ?? .empty)
        let outcome = RecordingOutcome(
            transcript: transcript?.text,
            screenshotCount: saved.screenshotURLs.count,
            heardSpeech: heardSpeech
        )

        let report: RecordingReport
        switch outcome {
        case .nothingCaptured:
            session.draft.discard()
            report = .nothingCaptured
        case .captured, .transcriptionFailed:
            let result = await Delivery.deliver(
                saved,
                to: target,
                pasting: settings.insertsAutomatically && outcome == .captured
            )
            do {
                try store.save(saved)
                onSessionSaved()
                report = outcome == .captured
                    ? .delivered(result, hasText: !saved.manifest.transcript.text.isEmpty, screenshotCount: saved.screenshotURLs.count)
                    : .transcriptionFailed(screenshotCount: saved.screenshotURLs.count, keptAudio: keptAudio)
            } catch {
                report = .notSaved(result)
            }
        }
        let queued = if case .finishing(let mode) = phase { mode } else { RecordingMode?.none }
        phase = .idle
        tell(report)
        if let queued { start(queued) }
    }

    /// Style rules, then Apple Intelligence when chosen, then vocabulary again
    /// because a rewrite may have re-cased the person's terms.
    private func polish(_ recognized: TimedTranscript, language: DictationLanguage, for destination: TextDestination) async -> TimedTranscript {
        let polisher = settings.textPolisher(vocabulary: vocabulary.terms, language: language)
        var text = polisher.polish(recognized.rawText, for: destination)
        if settings.appliesSmartCleanup, !text.isEmpty, let cleaned = await SmartCleanup.clean(text, language: language) {
            text = polisher.applyTerms(to: cleaned, for: destination)
        }
        return TimedTranscript(text: text, rawText: recognized.rawText, duration: recognized.duration, words: recognized.words)
    }

    private func pointerMoved(to point: CGPoint) {
        guard case .recording = phase, let draft = session?.draft else { return }
        let now = ProcessInfo.processInfo.systemUptime
        trail.add(point: point.appKitPoint, at: now)
        guard let gesture = detector.add(point: point, at: now) else { return }
        let previous = screenshotTasks.last
        screenshotTasks.append(Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled else { return }
            do {
                let url = try await draft.addScreenshot(for: gesture, at: now)
                guard let self, case .recording = self.phase, self.session?.draft === draft else { return }
                self.trail.confirm(center: gesture.center.appKitPoint, radius: gesture.radius, at: now)
                self.island.confirmCapture(
                    url: url,
                    count: draft.screenshotURLs.count,
                    timecode: SessionTimecode.string(for: draft.offset(at: now))
                )
            } catch {
                guard let self, case .recording = self.phase, self.session?.draft === draft else { return }
                self.tell(.screenshotProblem(error))
            }
        })
    }

    private func endCapture() {
        limitTimer?.invalidate()
        limitTimer = nil
        pointer.stop()
        trail.stop()
    }

    private func tell(_ report: RecordingReport) {
        if let feedback = report.island {
            if case .recording = phase {
                island.flash(feedback.message, isError: feedback.style == .error)
            } else {
                island.finish(with: feedback)
            }
        }
        onReport(report)
    }
}
