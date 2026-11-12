//
//  VoiceNoteRow.swift
//  Somewhere — plays the "why I wanted it" voice note Kaitlyn's shelf records.
//

import SwiftUI
import AVFoundation

struct VoiceNoteRow: View {
    let url: URL
    @State private var player = VoiceNotePlayer()

    var body: some View {
        Button {
            player.toggle(url: url)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Theme.pink, in: Circle())

                ProgressView(value: player.progress)
                    .tint(Theme.pink)

                Text(Duration.seconds(player.duration(of: url)),
                     format: .time(pattern: .minuteSecond))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.inkSoft)
            }
            .padding(10)
            .background(Theme.pinkSoft.opacity(0.6), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(player.isPlaying ? "Pause voice note" : "Play voice note")
        .onDisappear { player.stop() }
    }
}

@Observable
final class VoiceNotePlayer: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    private(set) var progress: Double = 0

    // Not observed: changing these shouldn't redraw the view.
    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var cachedDuration: [URL: TimeInterval] = [:]

    func duration(of url: URL) -> Double {
        if let cached = cachedDuration[url] { return cached }
        let value = (try? AVAudioPlayer(contentsOf: url))?.duration ?? 0
        cachedDuration[url] = value
        return value
    }

    func toggle(url: URL) {
        if isPlaying { pause() } else { play(url: url) }
    }

    private func play(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
            try AVAudioSession.sharedInstance().setActive(true)
            if player?.url != url {
                player = try AVAudioPlayer(contentsOf: url)
                player?.delegate = self
            }
            player?.play()
            isPlaying = true
            startTimer()
        } catch {
            print("Voice note playback failed: \(error)")
        }
    }

    private func pause() {
        player?.pause()
        isPlaying = false
        timer?.invalidate()
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        progress = 0
        timer?.invalidate()
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let player = self.player, player.duration > 0 else { return }
                self.progress = player.currentTime / player.duration
            }
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
            self.timer?.invalidate()
        }
    }
}
