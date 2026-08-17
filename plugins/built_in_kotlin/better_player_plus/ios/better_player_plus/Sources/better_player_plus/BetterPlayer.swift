import Foundation
import Flutter
import AVFoundation
import AVKit
import UIKit

private var timeRangeContext = 0
private var statusContext = 0
private var playbackLikelyToKeepUpContext = 0
private var playbackBufferEmptyContext = 0
private var playbackBufferFullContext = 0
private var presentationSizeContext = 0

public class BetterPlayer: NSObject, FlutterPlatformView, FlutterStreamHandler, AVPictureInPictureControllerDelegate {
    public private(set) var player: AVPlayer
    public private(set) var loaderDelegate: BetterPlayerEzDrmAssetsLoaderDelegate?
    public var eventChannel: FlutterEventChannel?
    public var eventSink: FlutterEventSink?
    public var preferredTransform: CGAffineTransform = .identity
    public private(set) var disposed: Bool = false
    public private(set) var isPlaying: Bool = false
    public var isLooping: Bool = false
    public private(set) var isInitialized: Bool = false
    public private(set) var key: String? = nil
    public private(set) var failedCount: Int = 0
    private var videoGravity: AVLayerVideoGravity = .resizeAspect
    private weak var playerView: UIView?

    public var playerLayerRef: AVPlayerLayer?
    public var pictureInPicture: Bool = false
    public var observersAdded: Bool = false
    public var stalledCount: Int = 0
    public var isStalledCheckStarted: Bool = false
    public var playerRate: Float = 1.0
    public var overriddenDuration: Int = 0
    public var lastAvPlayerTimeControlStatus: AVPlayer.TimeControlStatus? = nil

    private var pipController: AVPictureInPictureController?
    private var restoreUIOnPipStop: ((Bool) -> Void)?

    public override init() {
        self.player = AVPlayer()
        super.init()
        self.player.actionAtItemEnd = .none
        if #available(iOS 10.0, *) {
            self.player.automaticallyWaitsToMinimizeStalling = false
        }
        self.observersAdded = false
        self.isInitialized = false
        self.isPlaying = false
        self.disposed = false
    }

    public convenience init(frame: CGRect) {
        self.init()
    }

    public func view() -> UIView {
        let playerView = BetterPlayerView(frame: .zero)
        playerView.player = player
        if let playerLayer = playerView.layer as? AVPlayerLayer {
            playerLayer.videoGravity = self.videoGravity
        }
        
        self.playerView = playerView
        return playerView
    }
    
    // MARK: - Aspect Ratio Handling
    public func setAspectRatio(_ gravity: AVLayerVideoGravity) {
        self.videoGravity = gravity
        
        if let playerLayer = playerView?.layer as? AVPlayerLayer {
            playerLayer.videoGravity = gravity
        }
        
        if let pipLayer = playerLayerRef {
            pipLayer.videoGravity = gravity
        }
    }

    // MARK: - Observers
    private func addObservers(_ item: AVPlayerItem) {
        if !observersAdded {
            player.addObserver(self, forKeyPath: "rate", options: [], context: nil)
            item.addObserver(self, forKeyPath: "loadedTimeRanges", options: [], context: &timeRangeContext)
            item.addObserver(self, forKeyPath: "status", options: [], context: &statusContext)
            item.addObserver(self, forKeyPath: "presentationSize", options: [], context: &presentationSizeContext)
            item.addObserver(self, forKeyPath: "playbackLikelyToKeepUp", options: [], context: &playbackLikelyToKeepUpContext)
            item.addObserver(self, forKeyPath: "playbackBufferEmpty", options: [], context: &playbackBufferEmptyContext)
            item.addObserver(self, forKeyPath: "playbackBufferFull", options: [], context: &playbackBufferFullContext)
            NotificationCenter.default.addObserver(self, selector: #selector(itemDidPlayToEndTime(_:)), name: .AVPlayerItemDidPlayToEndTime, object: item)
            observersAdded = true
        }
    }

    private func removeObservers() {
        if observersAdded {
            player.removeObserver(self, forKeyPath: "rate", context: nil)
            player.currentItem?.removeObserver(self, forKeyPath: "status", context: &statusContext)
            player.currentItem?.removeObserver(self, forKeyPath: "presentationSize", context: &presentationSizeContext)
            player.currentItem?.removeObserver(self, forKeyPath: "loadedTimeRanges", context: &timeRangeContext)
            player.currentItem?.removeObserver(self, forKeyPath: "playbackLikelyToKeepUp", context: &playbackLikelyToKeepUpContext)
            player.currentItem?.removeObserver(self, forKeyPath: "playbackBufferEmpty", context: &playbackBufferEmptyContext)
            player.currentItem?.removeObserver(self, forKeyPath: "playbackBufferFull", context: &playbackBufferFullContext)
            NotificationCenter.default.removeObserver(self)
            observersAdded = false
        }
    }

    @objc private func itemDidPlayToEndTime(_ notification: Notification) {
        if isLooping {
            if let p = notification.object as? AVPlayerItem {
                p.seek(to: .zero, completionHandler: nil)
            }
        } else {
            if let eventSink = eventSink {
                eventSink(["event": "completed", "key": key as Any])
                removeObservers()
            }
        }
    }

    private func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
        var degrees = CGFloat(radians * 180.0 / .pi)
        if degrees < 0 { degrees += 360 }
        return degrees
    }

    private func getVideoComposition(transform: CGAffineTransform, asset: AVAsset, videoTrack: AVAssetTrack) -> AVMutableVideoComposition {
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: .zero, duration: asset.duration)
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
        layerInstruction.setTransform(preferredTransform, at: .zero)

        let videoComposition = AVMutableVideoComposition()
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        var width = videoTrack.naturalSize.width
        var height = videoTrack.naturalSize.height
        let rotationDegrees = Int(round(radiansToDegrees(atan2(preferredTransform.b, preferredTransform.a))))
        if rotationDegrees == 90 || rotationDegrees == 270 {
            width = videoTrack.naturalSize.height
            height = videoTrack.naturalSize.width
        }
        videoComposition.renderSize = CGSize(width: width, height: height)

        let nominalFrameRate = videoTrack.nominalFrameRate
        var fps: Int32 = 30
        if nominalFrameRate > 0 { fps = Int32(ceil(nominalFrameRate)) }
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: fps)
        return videoComposition
    }

    private func fixTransform(_ videoTrack: AVAssetTrack) -> CGAffineTransform {
        var transform = videoTrack.preferredTransform
        let rotationDegrees = Int(round(radiansToDegrees(atan2(transform.b, transform.a))))
        if rotationDegrees == 90 {
            transform.tx = videoTrack.naturalSize.height
            transform.ty = 0
        } else if rotationDegrees == 180 {
            transform.tx = videoTrack.naturalSize.width
            transform.ty = videoTrack.naturalSize.height
        } else if rotationDegrees == 270 {
            transform.tx = 0
            transform.ty = videoTrack.naturalSize.width
        }
        return transform
    }

    public func setDataSourceAsset(_ assetPath: String, key: String?, certificateUrl: String?, licenseUrl: String?, cacheKey: String?, cacheManager: CacheManager, overriddenDuration: Int) {
        if let path = Bundle.main.path(forResource: assetPath, ofType: nil) {
            let url = URL(fileURLWithPath: path)
            setDataSourceURL(url, key: key, certificateUrl: certificateUrl, licenseUrl: licenseUrl, headers: [:], useCache: false, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration, videoExtension: nil)
        }
    }

    public func setDataSourceURL(_ url: URL, key: String?, certificateUrl: String?, licenseUrl: String?, headers: [AnyHashable: Any], useCache: Bool, cacheKey: String?, cacheManager: CacheManager, overriddenDuration: Int, videoExtension: String?) {
        self.overriddenDuration = 0
        var finalHeaders = headers
        if finalHeaders["dummy"] == nil {} // keep dictionary type stable

        let item: AVPlayerItem
        if useCache {
            let _cacheKey = cacheKey
            let _videoExt = videoExtension
            item = cacheManager.getCachingPlayerItemForNormalPlayback(url, cacheKey: _cacheKey, videoExtension: _videoExt, headers: finalHeaders as NSDictionary as! [NSObject: AnyObject]) ?? AVPlayerItem(url: url)
        } else {
            let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": finalHeaders])
            if let certificateUrl = certificateUrl, !certificateUrl.isEmpty {
                let certURL = URL(string: certificateUrl)
                let licURL = licenseUrl.flatMap { URL(string: $0) }
                if let certURL = certURL {
                    let delegate = BetterPlayerEzDrmAssetsLoaderDelegate(certURL, withLicenseURL: licURL)
                    self.loaderDelegate = delegate
                    let qos = DispatchQoS.QoSClass.default
                    let streamQueue = DispatchQueue(label: "streamQueue", qos: DispatchQoS(qosClass: qos, relativePriority: -1), attributes: [])
                    asset.resourceLoader.setDelegate(delegate, queue: streamQueue)
                }
            }
            item = AVPlayerItem(asset: asset)
        }
        if #available(iOS 10.0, *), overriddenDuration > 0 {
            self.overriddenDuration = overriddenDuration
        }
        setDataSourcePlayerItem(item, key: key)
    }

    private func setDataSourcePlayerItem(_ item: AVPlayerItem, key: String?) {
        self.key = key
        self.stalledCount = 0
        self.isStalledCheckStarted = false
        self.playerRate = 1
        player.replaceCurrentItem(with: item)

        let asset = item.asset
        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            if asset.statusOfValue(forKey: "tracks", error: nil) == .loaded {
                let tracks = asset.tracks(withMediaType: .video)
                if let videoTrack = tracks.first {
                    videoTrack.loadValuesAsynchronously(forKeys: ["preferredTransform"]) { [weak self] in
                        guard let self = self, !self.disposed else { return }
                        if videoTrack.statusOfValue(forKey: "preferredTransform", error: nil) == .loaded {
                            self.preferredTransform = self.fixTransform(videoTrack)
                            let videoComposition = self.getVideoComposition(transform: self.preferredTransform, asset: asset, videoTrack: videoTrack)
                            item.videoComposition = videoComposition
                        }
                    }
                }
            }
        }
        addObservers(item)
    }

    private func handleStalled() {
        if isStalledCheckStarted { return }
        isStalledCheckStarted = true
        startStalledCheck()
    }

    private func startStalledCheck() {
        if let currentItem = player.currentItem {
            if currentItem.isPlaybackLikelyToKeepUp || (availableDuration() - CMTimeGetSeconds(currentItem.currentTime())) > 10.0 {
                play()
            } else {
                stalledCount += 1
                if stalledCount > 60 {
                    if let eventSink = eventSink {
                        let error = FlutterError(code: "VideoError", message: "Failed to load video: playback stalled", details: nil)
                        eventSink(error)
                    }
                    return
                }
                perform(#selector(startStalledCheckObjC), with: nil, afterDelay: 1)
            }
        }
    }

    @objc private func startStalledCheckObjC() { startStalledCheck() }

    private func availableDuration() -> TimeInterval {
        guard let timeRange = player.currentItem?.loadedTimeRanges.first?.timeRangeValue else { return 0 }
        let startSeconds = CMTimeGetSeconds(timeRange.start)
        let durationSeconds = CMTimeGetSeconds(timeRange.duration)
        return startSeconds + durationSeconds
    }

    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "rate" {
            if #available(iOS 10.0, *), let pipController = pipController, pipController.isPictureInPictureActive {
                if let last = lastAvPlayerTimeControlStatus, last == player.timeControlStatus {
                    return
                }
                if player.timeControlStatus == .paused {
                    lastAvPlayerTimeControlStatus = player.timeControlStatus
                    eventSink?(["event": "pause"])
                    return
                }
                if player.timeControlStatus == .playing {
                    lastAvPlayerTimeControlStatus = player.timeControlStatus
                    eventSink?(["event": "play"])
                }
            }

            if isPlaying && playerRate > 0 && player.rate > 0 && abs(player.rate - playerRate) > 0.0001 {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self, self.isPlaying, self.player.rate > 0,
                          abs(self.player.rate - self.playerRate) > 0.0001 else { return }
                    self.applyPlayerRate()
                }
            }

            if player.rate == 0 && CMTimeCompare(player.currentItem?.currentTime() ?? .zero, .zero) == 1 && (player.currentItem?.duration ?? .zero).isValid && CMTimeCompare(player.currentItem?.currentTime() ?? .zero, player.currentItem?.duration ?? .zero) == -1 && isPlaying {
                handleStalled()
            }
        }

        if context == &timeRangeContext {
            if let eventSink = eventSink, let item = object as? AVPlayerItem {
                var values: [[NSNumber]] = []
                for rangeValue in item.loadedTimeRanges {
                    let range = rangeValue.timeRangeValue
                    var start = NSNumber(value: BetterPlayerTimeUtils.cmTimeToMillis(range.start))
                    var end = NSNumber(value: BetterPlayerTimeUtils.cmTimeToMillis(range.start) + BetterPlayerTimeUtils.cmTimeToMillis(range.duration))
                    if let endTime = player.currentItem?.forwardPlaybackEndTime, !CMTIME_IS_INVALID(endTime) {
                        let endTimeMs = BetterPlayerTimeUtils.cmTimeToMillis(endTime)
                        if end.int64Value > endTimeMs { end = NSNumber(value: endTimeMs) }
                    }
                    values.append([start, end])
                }
                eventSink(["event": "bufferingUpdate", "values": values, "key": key as Any])
            }
        } else if context == &presentationSizeContext {
            onReadyToPlay()
        } else if context == &statusContext {
            if let item = object as? AVPlayerItem {
                switch item.status {
                case .failed:
                    NSLog("Failed to load video: \(String(describing: item.error?.localizedDescription))")
                    if let eventSink = eventSink {
                        let message = "Failed to load video: \(item.error?.localizedDescription ?? "unknown")"
                        let error = FlutterError(code: "VideoError", message: message, details: nil)
                        eventSink(error)
                    }
                case .unknown:
                    break
                case .readyToPlay:
                    onReadyToPlay()
                @unknown default:
                    break
                }
            }
        } else if context == &playbackLikelyToKeepUpContext {
            if player.currentItem?.isPlaybackLikelyToKeepUp == true {
                updatePlayingState()
                eventSink?(["event": "bufferingEnd", "key": key as Any])
            }
        } else if context == &playbackBufferEmptyContext {
            eventSink?(["event": "bufferingStart", "key": key as Any])
        } else if context == &playbackBufferFullContext {
            eventSink?(["event": "bufferingEnd", "key": key as Any])
        }
    }

    public func updatePlayingState() {
        guard isInitialized, key != nil else { return }
        if !observersAdded, let current = player.currentItem { addObservers(current) }
        if isPlaying {
            applyPlayerRate()
        } else {
            player.pause()
        }
    }

    private func applyPlayerRate() {
        if #available(iOS 16, *) {
            player.defaultRate = playerRate
        }
        if #available(iOS 10.0, *) {
            player.playImmediately(atRate: playerRate)
        } else {
            player.play()
            player.rate = playerRate
        }
    }

    public func onReadyToPlay() {
        guard let eventSink = eventSink, !isInitialized, key != nil else { return }
        guard player.currentItem != nil else { return }
        guard player.status == .readyToPlay else { return }

        let size = player.currentItem?.presentationSize ?? .zero
        var width = size.width
        var height = size.height

        let asset = player.currentItem!.asset
        let onlyAudio = asset.tracks(withMediaType: .video).count == 0
        if !onlyAudio && height == .zero && width == .zero {
            return
        }
        let isLive = CMTIME_IS_INDEFINITE(player.currentItem!.duration)
        if !isLive && duration() == 0 { return }

        if let track = player.currentItem?.tracks.first?.assetTrack {
            let naturalSize = track.naturalSize
            let prefTrans = track.preferredTransform
            let realSize = naturalSize.applying(prefTrans)
            width = abs(realSize.width) != 0 ? abs(realSize.width) : width
            height = abs(realSize.height) != 0 ? abs(realSize.height) : height
        }

        let durMs = BetterPlayerTimeUtils.cmTimeToMillis(player.currentItem!.asset.duration)
        if overriddenDuration > 0 && durMs > Int64(overriddenDuration) {
            player.currentItem?.forwardPlaybackEndTime = CMTimeMake(value: Int64(overriddenDuration/1000), timescale: 1)
        }

        isInitialized = true
        updatePlayingState()
        eventSink(["event": "initialized",
                   "duration": NSNumber(value: duration()),
                   "width": NSNumber(value: Float(width)),
                   "height": NSNumber(value: Float(height)),
                   "key": key as Any])
    }

    public func play() {
        stalledCount = 0
        isStalledCheckStarted = false
        isPlaying = true
        updatePlayingState()
    }

    public func pause() {
        isPlaying = false
        updatePlayingState()
    }

    public func position() -> Int64 {
        return BetterPlayerTimeUtils.cmTimeToMillis(player.currentTime())
    }

    public func absolutePosition() -> Int64 {
        let interval = player.currentItem?.currentDate()?.timeIntervalSince1970 ?? 0
        return BetterPlayerTimeUtils.timeIntervalToMillis(interval)
    }

    public func duration() -> Int64 {
        let time: CMTime
        if #available(iOS 13, *) {
            time = player.currentItem?.duration ?? .zero
        } else {
            time = player.currentItem?.asset.duration ?? .zero
        }
        if let endTime = player.currentItem?.forwardPlaybackEndTime, !CMTIME_IS_INVALID(endTime) {
            return BetterPlayerTimeUtils.cmTimeToMillis(endTime)
        }
        return BetterPlayerTimeUtils.cmTimeToMillis(time)
    }

    public func seekTo(_ location: Int) {
        let wasPlaying = isPlaying
        if wasPlaying { player.pause() }
        player.seek(to: CMTimeMake(value: Int64(location), timescale: 1000), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
            guard let self = self else { return }
            if wasPlaying { self.applyPlayerRate() }
        }
    }

    public func setVolume(_ volume: Double) {
        let v = max(0.0, min(1.0, volume))
        player.volume = Float(v)
    }

    public func setSpeed(_ speed: Double, result: FlutterResult) {
        if speed < 0 || speed > 2.0 {
            result(FlutterError(code: "unsupported_speed", message: "Speed must be >= 0.0 and <= 2.0", details: nil))
            return
        }

        playerRate = Float(speed == 0.0 ? 1.0 : speed)
        if isPlaying {
            applyPlayerRate()
        }
        result(nil)
    }

    public func setTrackParameters(width: Int, height: Int, bitrate: Int) {
        player.currentItem?.preferredPeakBitRate = Double(bitrate)
        if #available(iOS 11.0, *) {
            if width == 0 && height == 0 {
                player.currentItem?.preferredMaximumResolution = .zero
            } else {
                player.currentItem?.preferredMaximumResolution = CGSize(width: width, height: height)
            }
        }
    }

    public func setPictureInPicture(_ pictureInPicture: Bool) {
        self.pictureInPicture = pictureInPicture
        if #available(iOS 9.0, *) {
            if let pip = pipController, self.pictureInPicture && !pip.isPictureInPictureActive {
                DispatchQueue.main.async { pip.startPictureInPicture() }
            } else if let pip = pipController, !self.pictureInPicture && pip.isPictureInPictureActive {
                DispatchQueue.main.async { pip.stopPictureInPicture() }
            }
        }
    }

    public func setRestoreUserInterfaceForPIPStopCompletionHandler(_ restore: Bool) {
        restoreUIOnPipStop?(restore)
        restoreUIOnPipStop = nil
    }

    private func setupPipController() {
        if #available(iOS 9.0, *) {
            try? AVAudioSession.sharedInstance().setActive(true)
            UIApplication.shared.beginReceivingRemoteControlEvents()
            if pipController == nil, let layer = playerLayerRef, AVPictureInPictureController.isPictureInPictureSupported() {
                pipController = AVPictureInPictureController(playerLayer: layer)
                pipController?.delegate = self
            }
        }
    }

    public func enablePictureInPicture(_ frame: CGRect) {
        disablePictureInPicture()
        usePlayerLayer(frame)
    }

    private func usePlayerLayer(_ frame: CGRect) {
        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = self.videoGravity
        if #available(iOS 13.0, *) {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootVC = window.rootViewController {
                layer.frame = frame
                layer.needsDisplayOnBoundsChange = true
                rootVC.view.layer.addSublayer(layer)
                rootVC.view.layer.needsDisplayOnBoundsChange = true
                playerLayerRef = layer
                pipController = nil
                setupPipController()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.setPictureInPicture(true)
                }
            }
        } else {
            if let window = UIApplication.shared.keyWindow ?? UIApplication.shared.windows.first,
               let rootVC = window.rootViewController {
                layer.frame = frame
                layer.needsDisplayOnBoundsChange = true
                rootVC.view.layer.addSublayer(layer)
                rootVC.view.layer.needsDisplayOnBoundsChange = true
                playerLayerRef = layer
                pipController = nil
                setupPipController()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.setPictureInPicture(true)
                }
            }
        }
    }

    public func disablePictureInPicture() {
        setPictureInPicture(true)
        if let layer = playerLayerRef {
            layer.removeFromSuperlayer()
            playerLayerRef = nil
            eventSink?(["event": "pipStop"])
        }
    }

    // MARK: - AVPictureInPictureControllerDelegate
    public func pictureInPictureControllerDidStopPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        disablePictureInPicture()
    }

    public func pictureInPictureControllerDidStartPictureInPicture(_ pictureInPictureController: AVPictureInPictureController) {
        eventSink?(["event": "pipStart"])
    }

    public func pictureInPictureController(_ pictureInPictureController: AVPictureInPictureController, restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void) {
        restoreUIOnPipStop = completionHandler
        setRestoreUserInterfaceForPIPStopCompletionHandler(true)
    }

    // MARK: - Audio & Tracks
    public func setAudioTrack(name: String, index: Int) {
        guard let group = player.currentItem?.asset.mediaSelectionGroup(forMediaCharacteristic: .audible) else { return }
        let options = group.options
        for audioTrackIndex in 0..<options.count {
            let option = options[audioTrackIndex]
            let metas = AVMetadataItem.metadataItems(from: option.commonMetadata, withKey: "title" as (NSCopying & NSObjectProtocol), keySpace: AVMetadataKeySpace(rawValue: "comn"))
            if let title = metas.first?.stringValue, title == name && audioTrackIndex == index {
                player.currentItem?.select(option, in: group)
            }
        }
    }

    public func setMixWithOthers(_ mixWithOthers: Bool) {
        if mixWithOthers {
            try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        } else {
            try? AVAudioSession.sharedInstance().setCategory(.playback)
        }
    }

    // MARK: - FlutterStreamHandler
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        onReadyToPlay()
        return nil
    }

    public func clear() {
        isInitialized = false
        isPlaying = false
        disposed = false
        failedCount = 0
        key = nil
        guard player.currentItem != nil else { return }
        removeObservers()
        player.currentItem?.asset.cancelLoading()
    }

    public func disposeSansEventChannel() {
        do {
            clear()
        }
    }

    public func dispose() {
        pause()
        disposeSansEventChannel()
        eventChannel?.setStreamHandler(nil)
        disablePictureInPicture()
        setPictureInPicture(false)
        disposed = true
    }
}
