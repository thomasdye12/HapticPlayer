//
//  SwiftUiview.swift
//  HapticPlayer
//
//  Created by Thomas Dye on 26/08/2025.
//

import SwiftUI
import AVKit

// MARK: - Model
struct HapticClip: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let videoURL: SyncedHapticVideoViewController.HapticSource
    let haptic: SyncedHapticVideoViewController.HapticSource
    let thumbSystemImage: String?   // simple icon for now (you can swap for real artwork later)
}

// MARK: - UIKit -> SwiftUI wrapper
struct SyncedHapticVideoWrapper: UIViewControllerRepresentable {
    let clip: HapticClip

    func makeUIViewController(context: Context) -> SyncedHapticVideoViewController {
        SyncedHapticVideoViewController(videoURL: clip.videoURL, haptic: clip.haptic)
    }

    func updateUIViewController(_ uiViewController: SyncedHapticVideoViewController, context: Context) {
        // No-op; not changing once presented
    }
}

// MARK: - SwiftUI grid of clips
struct HapticClipGridView: View {
    let clips: [HapticClip]

    @State private var selectedClip: HapticClip?
    @State private var showPlayer = false

    // Adjust columns to taste
    private let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(clips) { clip in
                        Button {
                            selectedClip = clip
                            showPlayer = true
                        } label: {
                            ClipCard(clip: clip)
                        }
                        .buttonStyle(.plain)
//                        .contextMenu {
//                            if let url = URL(string: "https://example.com") {
//                                ShareLink(item: url) { Label("Share", systemImage: "square.and.arrow.up") }
//                            }
//                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("Haptic Clips")
        }
        .fullScreenCover(item: $selectedClip) { clip in
            SyncedHapticVideoWrapper(clip: clip)
                .ignoresSafeArea() // AVPlayerViewController goes edge-to-edge
        }
    }
}

// MARK: - Card UI
private struct ClipCard: View {
    let clip: HapticClip

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 110)

                // Simple system image placeholder; replace with your thumbnails
                if let sys = clip.thumbSystemImage {
                    Image(systemName: sys)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.primary)
                } else {
                    Image(systemName: "waveform.path")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(clip.title)
                    .font(.headline)
                    .lineLimit(1)

                if let sub = clip.subtitle, !sub.isEmpty {
                    Text(sub)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.tertiarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(.separator), lineWidth: 0.5)
        )
    }
}
