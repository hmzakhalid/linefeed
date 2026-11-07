import AudioToolbox
import AVFoundation
import CoreAudio
import Foundation
import LinefeedCore

/// Deliberately not main-actor isolated: its tap runs on the audio thread.
final class AudioRecorder {
    private static let filePrefix = "Linefeed-"

    private var engine: AVAudioEngine?
    private var recordingURL: URL?
    private var configurationObserver: NSObjectProtocol?
    var onLevel: (@MainActor @Sendable (Float) -> Void)?
    /// macOS changed the audio route under a running recording (earphones in
    /// or out, a Bluetooth headset switching profile) and stopped the engine.
    var onInterruption: (@MainActor @Sendable () -> Void)?

    static func removeAbandonedRecordings() {
        let manager = FileManager.default
        guard let files = try? manager.contentsOfDirectory(
            at: manager.temporaryDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }
        for file in files where file.lastPathComponent.hasPrefix(filePrefix) && file.pathExtension == "caf" {
            let parts = file.deletingPathExtension().lastPathComponent.split(separator: "-", maxSplits: 2)
            if parts.count == 3, let processID = Int32(parts[1]), kill(processID, 0) == 0 { continue }
            try? manager.removeItem(at: file)
        }
    }

    func start(device: MicrophoneDevice) throws {
        if engine != nil { _ = stop() }
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        guard let audioUnit = inputNode.audioUnit else { throw LinefeedError.microphoneFailed(device.name) }

        var deviceID = device.id
        let status = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard status == noErr else { throw LinefeedError.microphoneFailed(device.name) }

        let format = inputNode.inputFormat(forBus: 0)
        guard format.channelCount > 0 else { throw LinefeedError.microphoneUnavailable }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Self.filePrefix)\(getpid())-\(UUID().uuidString).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let levelHandler = onLevel

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { buffer, _ in
            try? file.write(from: buffer)
            guard buffer.format.channelCount > 0, let samples = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return }
            let level = AudioLevel.of(UnsafeBufferPointer(start: samples, count: Int(buffer.frameLength)))
            Task { @MainActor in levelHandler?(level) }
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            inputNode.removeTap(onBus: 0)
            try? FileManager.default.removeItem(at: url)
            throw LinefeedError.microphoneFailed(device.name)
        }
        self.engine = engine
        recordingURL = url

        // The engine waits while this notification is delivered, so it must
        // not be torn down from inside the handler: hand off to the main queue.
        let interruptionHandler = onInterruption
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak engine] _ in
            guard let engine, !engine.isRunning else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { interruptionHandler?() }
            }
        }
    }

    func stop() -> URL? {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
        configurationObserver = nil
        engine?.inputNode.removeTap(onBus: 0)
        engine?.stop()
        engine = nil
        defer { recordingURL = nil }
        return recordingURL
    }
}
