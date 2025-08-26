//
//  SyncedHapticVideoViewController.swift
//  HapticPlayer
//
//  Created by Thomas Dye on 26/08/2025.
//



import UIKit
import AVKit
import CoreHaptics

final class SyncedHapticVideoViewController: UIViewController {

    enum HapticSource {
        case remoteURL(URL)
        case bundled(name: String) // without ".ahap"
    }

    // MARK: - Public API

    init(videoURL: HapticSource, haptic: HapticSource) {
        self.videoURL = videoURL
        self.hapticSource = haptic
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Private

    private let videoURL: HapticSource
    private let hapticSource: HapticSource

    private let avController = AVPlayerViewController()
    private var player: AVPlayer!
    private var timeObserver: Any?

    private var engine: CHHapticEngine?
    private var hapticPlayer: CHHapticAdvancedPatternPlayer?
    private var supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics

    private var isPrepared = false
    private var hasStartedHaptics = false

    private var kvoAdded_timeControlStatus = false
    private var kvoAdded_itemStatus = false

    // Re-pin cadence (seconds) for gentle drift correction
    private let repinInterval: Double = 0.3
    private var lastRepinAt: CFTimeInterval = 0

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        setupVideo()
        setupHapticsEngine()
        prepareHapticsAndVideo()
    }

    deinit { teardown() }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isMovingFromParent || isBeingDismissed { teardown() }
    }

    // MARK: - Setup

    private func setupVideo() {
        loadVideoURL(hapticSource: videoURL) { [weak self] data in
            guard let self = self else { return }
            guard let data = data else { print("AHAP: failed to download/load data"); return }
            player = AVPlayer(url: data)
            avController.player = player
            avController.exitsFullScreenWhenPlaybackEnds = true
            avController.view.translatesAutoresizingMaskIntoConstraints = false
            
            addChild(avController)
            view.addSubview(avController.view)
            avController.didMove(toParent: self)
            
            NSLayoutConstraint.activate([
                avController.view.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
                avController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                avController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                avController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
            ])
            
            // Mirror AVPlayerViewController controls
            player.addObserver(self, forKeyPath: "timeControlStatus", options: [.new, .old], context: nil)
            kvoAdded_timeControlStatus = true
            
            player.addObserver(self, forKeyPath: "currentItem.status", options: [.new], context: nil)
            kvoAdded_itemStatus = true
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(itemDidPlayToEnd),
                name: .AVPlayerItemDidPlayToEndTime,
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(timeJumped),
                name: .AVPlayerItemTimeJumped,
                object: player.currentItem
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(playbackStalled),
                name: .AVPlayerItemPlaybackStalled,
                object: player.currentItem
            )
            
            // Gentle periodic re-pin
            timeObserver = player.addPeriodicTimeObserver(
                forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
                queue: .main
            ) { [weak self] _ in
                self?.periodicRepinIfNeeded()
            }
        }
    }

    private func setupHapticsEngine() {
        guard supportsHaptics else { return }
        do {
            engine = try CHHapticEngine()
            engine?.playsHapticsOnly = true
            engine?.stoppedHandler = { reason in
                print("Haptics engine stopped: \(reason.rawValue)")
            }
            engine?.resetHandler = { [weak self] in
                DispatchQueue.main.async {
                    print("Haptics engine reset – rebuilding player")
                    self?.isPrepared = false
                    self?.hasStartedHaptics = false
                    self?.prepareHapticsPattern()
                }
            }
        } catch {
            print("Haptics engine init failed: \(error)")
            supportsHaptics = false
        }
    }

    private func prepareHapticsAndVideo() {
        player.currentItem?.preferredForwardBufferDuration = 1.5
        prepareHapticsPattern()
    }

    private func loadAHAPData(hapticSource:HapticSource, completion: @escaping (Data?) -> Void) {
        switch hapticSource {
        case .bundled(let name):
            guard let url = Bundle.main.url(forResource: name, withExtension: "ahap"),
                  let data = try? Data(contentsOf: url) else {
                completion(nil); return
            }
            completion(data)

        case .remoteURL(let url):
            URLSession.shared.dataTask(with: url) { data, _, _ in
                completion(data)
            }.resume()
        }
    }
    private func loadVideoURL(hapticSource:HapticSource, completion: @escaping (URL?) -> Void) {
        switch hapticSource {
        case .bundled(let name):
            guard let url = Bundle.main.url(forResource: name, withExtension: "mov"),
                  let data = try? Data(contentsOf: url) else {
                completion(nil); return
            }
            completion(url)

        case .remoteURL(let url):
            completion(url)
        }
    }

    private func prepareHapticsPattern() {
        guard supportsHaptics else { return }

        loadAHAPData(hapticSource: hapticSource) { [weak self] data in
            guard let self = self else { return }
            guard let data = data else { print("AHAP: failed to download/load data"); return }

            do {
                guard let dict = try JSONSerialization.jsonObject(with: data) as? [CHHapticPattern.Key: Any] else {
                    print("AHAP: invalid JSON structure"); return
                }

                DispatchQueue.main.async {
                    do {
                        try self.engine?.start()
                        let pattern = try CHHapticPattern(dictionary: dict)
                        self.hapticPlayer = try self.engine?.makeAdvancedPlayer(with: pattern)
                        self.hasStartedHaptics = false
                        self.isPrepared = true
                        print("AHAP: prepared")
                    } catch {
                        print("AHAP: prepare error -> \(error)")
                    }
                }
            } catch {
                print("AHAP: JSON error -> \(error)")
            }
        }
    }

    // MARK: - Sync helpers

    private func videoTimeSeconds() -> Double {
        guard let item = player.currentItem else { return 0 }
        let t = item.currentTime().seconds
        return t.isFinite ? t : 0
    }

    private func repinHaptics(to videoSeconds: Double) {
        guard supportsHaptics, let hp = hapticPlayer else { return }
        do {
            try engine?.start()
            try hp.seek(toOffset: videoSeconds)
            if !hasStartedHaptics {
                try hp.start(atTime: 0)
                hasStartedHaptics = true
            } else if player.timeControlStatus == .playing {
                try hp.resume(atTime: 0)
            }
        } catch {
            print("Haptics repin error -> \(error)")
        }
    }

    private func periodicRepinIfNeeded() {
        guard supportsHaptics,
              player.timeControlStatus == .playing,
              hapticPlayer != nil else { return }

        let now = CACurrentMediaTime()
        if now - lastRepinAt >= repinInterval {
            lastRepinAt = now
            repinHaptics(to: videoTimeSeconds())
        }
    }

    // MARK: - AVPlayer events

    @objc private func itemDidPlayToEnd() {
        stopHapticsAndResetFlag()
    }

    @objc private func timeJumped() {
        // Fired on user scrubs/seeks/skip
        repinHaptics(to: videoTimeSeconds())
    }

    @objc private func playbackStalled() {
        // Pause haptics so they don't drift ahead
        guard let hp = hapticPlayer else { return }
        do { try hp.pause(atTime: 0) } catch { }
    }

    // Mirror AVPlayerViewController built-in controls via KVO
    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?, change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {

        if keyPath == "timeControlStatus" {
            switch player.timeControlStatus {
            case .playing:
                repinHaptics(to: videoTimeSeconds())
            case .paused, .waitingToPlayAtSpecifiedRate:
                if let hp = hapticPlayer { try? hp.pause(atTime: 0) }
            @unknown default:
                break
            }
        } else if keyPath == "currentItem.status" {
            // Handle ready/failed if you want
        }
    }

    private func stopHapticsAndResetFlag() {
        guard let hp = hapticPlayer else { return }
        do { try hp.stop(atTime: 0) } catch { }
        hasStartedHaptics = false
    }

    // MARK: - Teardown

    private func teardown() {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil

        NotificationCenter.default.removeObserver(self)

        if kvoAdded_timeControlStatus {
            player.removeObserver(self, forKeyPath: "timeControlStatus")
            kvoAdded_timeControlStatus = false
        }
        if kvoAdded_itemStatus {
            player.removeObserver(self, forKeyPath: "currentItem.status")
            kvoAdded_itemStatus = false
        }

        stopHapticsAndResetFlag()
        try? engine?.stop()
        engine = nil
        hapticPlayer = nil
    }
}
