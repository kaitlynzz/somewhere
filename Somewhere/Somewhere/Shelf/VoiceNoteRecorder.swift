//
//  VoiceNoteRecorder.swift
//  Somewhere — Cooling shelf (Kaitlyn)
//
//  "why did you want it?" — record a quick voice note for a saved item.
//  The file goes into `AppGroup.voiceNotesDirectory` and its name into
//  `item.voiceNoteFileName`, so Nicole's context page can play it too.
//
//  Needs NSMicrophoneUsageDescription (set in the project's build settings).
//

import SwiftUI
import SwiftData
import AVFoundation
import UIKit

// MARK: - Recorder

@MainActor
@Observable
final class VoiceNoteRecorder {

    enum Phase: Equatable { case idle, recording, denied, failed }

    static let maxDuration: TimeInterval = 60
    private static let minDuration: TimeInterval = 0.6

    private(set) var phase: Phase = .idle
    private(set) var elapsed: TimeInterval = 0
    /// 0…1, for the little level meter.
    private(set) var level: Double = 0

    @ObservationIgnored private var recorder: AVAudioRecorder?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var fileName: String?

    var isRecording: Bool { phase == .recording }

    func start(for item: SavedItem) async {
        guard await AVAudioApplication.requestRecordPermission() else {
            phase = .denied
            return
        }

        // A new name every time, so players never show an old cached duration.
        let name = "\(item.id.uuidString)-\(Int(Date().timeIntervalSince1970)).m4a"
        let url = AppGroup.voiceNotesDirectory.appendingPathComponent(name)
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder.isMeteringEnabled = true
            guard recorder.record(forDuration: Self.maxDuration) else { throw CocoaError(.fileWriteUnknown) }

            self.recorder = recorder
            fileName = name
            elapsed = 0
            phase = .recording
            startTimer()
        } catch {
            print("Voice note recording failed: \(error)")
            phase = .failed
        }
    }

    /// Stops and returns the new file's name, or nil if it was too short to keep.
    func stop() -> String? {
        guard let recorder, let fileName else { return nil }
        let duration = recorder.currentTime
        recorder.stop()
        finish()

        guard duration >= Self.minDuration else {
            try? FileManager.default.removeItem(at: recorder.url)
            return nil
        }
        return fileName
    }

    func cancel() {
        guard let recorder else { return }
        recorder.stop()
        try? FileManager.default.removeItem(at: recorder.url)
        finish()
    }

    private func finish() {
        timer?.invalidate()
        timer = nil
        recorder = nil
        fileName = nil
        level = 0
        if phase == .recording { phase = .idle }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let recorder = self.recorder else { return }
                if !recorder.isRecording {
                    // Hit the 60-second limit; AVAudioRecorder stopped by itself.
                    self.phase = .idle
                    return
                }
                recorder.updateMeters()
                self.elapsed = recorder.currentTime
                let power = Double(recorder.averagePower(forChannel: 0))   // −160…0 dB
                self.level = max(0, min(1, (power + 50) / 50))
            }
        }
    }
}

// MARK: - Saving onto the item

enum ShelfVoiceNotes {
    /// Attaches a new recording to the item, deleting the one it replaces.
    static func attach(_ fileName: String, to item: SavedItem, in context: ModelContext) {
        if let old = item.voiceNoteURL { try? FileManager.default.removeItem(at: old) }
        item.voiceNoteFileName = fileName
        try? context.save()
    }

    static func remove(from item: SavedItem, in context: ModelContext) {
        if let old = item.voiceNoteURL { try? FileManager.default.removeItem(at: old) }
        item.voiceNoteFileName = nil
        try? context.save()
    }
}

// MARK: - View

/// Record / play / re-record the "why I wanted it" voice note.
/// Drop it anywhere you have a `SavedItem` (Mina: works after a save, too).
struct VoiceNoteRecorderView: View {
    let item: SavedItem

    @Environment(\.modelContext) private var context
    @Environment(\.openURL) private var openURL
    @State private var recorder = VoiceNoteRecorder()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            switch recorder.phase {
            case .recording:
                recordingRow
            case .denied:
                deniedRow
            case .idle, .failed:
                if let url = item.voiceNoteURL {
                    VoiceNoteRow(url: url)
                    HStack(spacing: 16) {
                        Button("re-record") { Task { await recorder.start(for: item) } }
                        Button("delete", role: .destructive) {
                            ShelfVoiceNotes.remove(from: item, in: context)
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.inkSoft)
                } else {
                    Button {
                        Task { await recorder.start(for: item) }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Theme.pink, in: Circle())
                            Text("record a voice note")
                                .font(Theme.body(15, weight: .medium))
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 0)
                        }
                        .padding(10)
                        .background(Theme.pinkSoft.opacity(0.6), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if recorder.phase == .failed {
                    Text("couldn't start recording. try again?")
                        .font(.caption)
                        .foregroundStyle(Theme.pink)
                }
            }
        }
        .sensoryFeedback(.start, trigger: recorder.isRecording) { _, now in now }
        .onDisappear {
            if let name = recorder.stop() { ShelfVoiceNotes.attach(name, to: item, in: context) }
        }
        .onChange(of: recorder.phase) { old, new in
            // The recorder stopped itself at the 60-second limit: keep what it got.
            if old == .recording, new == .idle, let name = recorder.stop() {
                ShelfVoiceNotes.attach(name, to: item, in: context)
            }
        }
    }

    private var recordingRow: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.pink)
                .frame(width: 10, height: 10)
                .opacity(0.4 + recorder.level * 0.6)

            Text(Duration.seconds(recorder.elapsed), format: .time(pattern: .minuteSecond))
                .font(.system(size: 15, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.ink)

            // Level meter
            GeometryReader { geo in
                Capsule().fill(Theme.pink.opacity(0.2))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Theme.pink)
                            .frame(width: max(6, geo.size.width * recorder.level))
                    }
            }
            .frame(height: 6)
            .animation(.linear(duration: 0.1), value: recorder.level)

            Button("cancel") { recorder.cancel() }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.inkSoft)

            Button {
                if let name = recorder.stop() { ShelfVoiceNotes.attach(name, to: item, in: context) }
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.pink, in: Circle())
            }
            .accessibilityLabel("Stop recording")
        }
        .padding(.horizontal, 14)
        .frame(height: 54)
        .background(Theme.pinkSoft.opacity(0.6), in: Capsule())
    }

    private var deniedRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("microphone is off for somewhere")
                .font(Theme.body(15, weight: .medium))
                .foregroundStyle(Theme.ink)
            Button("turn it on in Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
            }
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Theme.blue)
        }
    }
}
