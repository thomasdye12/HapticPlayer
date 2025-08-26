//
//  ViewController.swift
//  HapticPlayer
//
//  Created by Thomas Dye on 26/08/2025.
//

import UIKit

import SwiftUI

class ViewController: UIViewController {
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // Build your array here (same as in Preview)


        let clips = [
            HapticClip(
                title: "Apple F1 Demo",
                subtitle: "Remote AHAP",
                videoURL: .remoteURL(URL(string: "https://play-edge.itunes.apple.com/WebObjects/MZPlayLocal.woa/hls/subscription/playlist.m3u8?cc=GB&svcId=tvs.vds.4041&a=1809419955&isExternal=true&brandId=tvs.sbd.4000&id=1134594683&l=en-GB&aec=UHD")!),
                haptic: .remoteURL(URL(string: "https://vod-ak-svod.tv.apple.com/itunes-assets/HLSVideo211/v4/39/ab/de/39abde35-7e15-877a-4bc5-885724efdeb7/apx_touch_clip_evergreen.ahap")!),
                thumbSystemImage: "bolt.fill"
            ),
            HapticClip(
                title: "My Test Pattern",
                subtitle: "Bundled AHAP",
                videoURL: .bundled(name: "00BA71CD-2C54-415A-A68A-8358E677D750"),
                haptic: .bundled(name: "test"),
                thumbSystemImage: "waveform.path.badge.plus"
            )
        ]

        // Present SwiftUI
        let swiftUIView = HapticClipGridView(clips: clips)
        let host = UIHostingController(rootView: swiftUIView)
        host.modalPresentationStyle = .fullScreen
        present(host, animated: true)
    }
}


