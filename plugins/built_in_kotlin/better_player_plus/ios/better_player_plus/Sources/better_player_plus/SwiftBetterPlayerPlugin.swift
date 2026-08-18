import Foundation
import Flutter
import AVFoundation
import AVKit
import UIKit
import MediaPlayer

public class BetterPlayerPlugin: NSObject, FlutterPlugin, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private var players: [Int64: BetterPlayer] = [:]
    private let registrar: FlutterPluginRegistrar

    private var dataSourceDict: [Int64: [String: Any]] = [:]
    private var timeObserverIdDict: [Int64: Any] = [:]
    private var artworkImageDict: [Int64: MPMediaItemArtwork] = [:]
    private var cacheManager: CacheManager
    private var texturesCount: Int64 = -1
    private var notificationPlayer: BetterPlayer?
    private var remoteCommandsInitialized = false

    init(registrar: FlutterPluginRegistrar) {
        self.messenger = registrar.messenger()
        self.registrar = registrar
        self.cacheManager = CacheManager()
        super.init()
        self.cacheManager.setup()
    }

    @objc public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "better_player_channel", binaryMessenger: registrar.messenger())
        let instance = BetterPlayerPlugin(registrar: registrar)
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(instance, withId: "com.jhomlala/better_player")
    }

    public func createArgsCodec() -> (FlutterMessageCodec & NSObjectProtocol) { FlutterStandardMessageCodec.sharedInstance() }

    public func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        guard let dict = args as? [String: Any], let textureId = (dict["textureId"] as? NSNumber)?.int64Value, let player = players[textureId] else {
            return BetterPlayer()
        }
        return player
    }

    private func newTextureId() -> Int64 {
        texturesCount += 1
        return texturesCount
    }

    private func onPlayerSetup(_ player: BetterPlayer, result: FlutterResult) {
        let textureId = newTextureId()
        let eventChannel = FlutterEventChannel(name: "better_player_channel/videoEvents\(textureId)", binaryMessenger: messenger)
        player.setMixWithOthers(false)
        eventChannel.setStreamHandler(player)
        player.eventChannel = eventChannel
        players[textureId] = player
        result(["textureId": NSNumber(value: textureId)])
    }

    private func setupRemoteNotification(_ player: BetterPlayer) {
        notificationPlayer = player
        stopOtherUpdateListener(player)
        guard let dataSource = dataSourceDict[keyForPlayer(player)] else { return }
        let showNotification = (dataSource["showNotification"] as? NSNumber)?.boolValue ?? false
        let title = dataSource["title"] as? String
        let author = dataSource["author"] as? String
        let imageUrl = dataSource["imageUrl"] as? String
        if showNotification {
            setRemoteCommandsNotificationActive()
            setupRemoteCommands(player)
            setupRemoteCommandNotification(player, title: title, author: author, imageUrl: imageUrl)
            setupUpdateListener(player, title: title, author: author, imageUrl: imageUrl)
        }
    }

    private func setRemoteCommandsNotificationActive() {
        try? AVAudioSession.sharedInstance().setActive(true)
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }

    private func setRemoteCommandsNotificationNotActive() {
        if players.isEmpty {
            try? AVAudioSession.sharedInstance().setActive(false)
        }
        UIApplication.shared.endReceivingRemoteControlEvents()
    }

    private func setupRemoteCommands(_ player: BetterPlayer) {
        if remoteCommandsInitialized { return }
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.isEnabled = true
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self, let player = self.notificationPlayer else { return .commandFailed }
            if player.isPlaying { player.eventSink?(["event": "play"]) } else { player.eventSink?(["event": "pause"]) }
            return .success
        }

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self, let player = self.notificationPlayer else { return .commandFailed }
            player.eventSink?(["event": "play"]) ; return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self, let player = self.notificationPlayer else { return .commandFailed }
            player.eventSink?(["event": "pause"]) ; return .success
        }

        if #available(iOS 9.1, *) {
            commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
                guard let self = self, let player = self.notificationPlayer, let playbackEvent = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
                let time = CMTimeMakeWithSeconds(playbackEvent.positionTime, preferredTimescale: 1)
                let millis = BetterPlayerTimeUtils.cmTimeToMillis(time)
                player.seekTo(Int(millis))
                player.eventSink?(["event": "seek", "position": NSNumber(value: millis)])
                return .success
            }
        }
        remoteCommandsInitialized = true
    }

    private func setupRemoteCommandNotification(_ player: BetterPlayer, title: String?, author: String?, imageUrl: String?) {
        let positionSeconds = Double(player.position()) / 1000.0
        let durationSeconds = Double(player.duration()) / 1000.0
        var nowPlayingInfo: [String: Any] = [
            MPMediaItemPropertyArtist: author ?? "",
            MPMediaItemPropertyTitle: title ?? "",
            MPNowPlayingInfoPropertyElapsedPlaybackTime: NSNumber(value: positionSeconds),
            MPMediaItemPropertyPlaybackDuration: NSNumber(value: durationSeconds),
            MPNowPlayingInfoPropertyPlaybackRate: NSNumber(value: 1)
        ]

        if let imageUrl = imageUrl {
            let key = keyForPlayer(player)
            if let artwork = artworkImageDict[key] {
                nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
            } else {
                DispatchQueue.global(qos: .default).async { [weak self] in
                    guard let self = self else { return }
                    var tempImage: UIImage?
                    if imageUrl.contains("http") {
                        if let url = URL(string: imageUrl), let data = try? Data(contentsOf: url) { tempImage = UIImage(data: data) }
                    } else {
                        tempImage = UIImage(contentsOfFile: imageUrl)
                    }
                    if let image = tempImage {
                        let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
                        self.artworkImageDict[key] = artwork
                        nowPlayingInfo[MPMediaItemPropertyArtwork] = artwork
                    }
                    MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                }
            }
        } else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
        }
    }

    private func keyForPlayer(_ player: BetterPlayer) -> Int64 {
        for (key, value) in players where value === player { return key }
        return -1
    }

    private func setupUpdateListener(_ player: BetterPlayer, title: String?, author: String?, imageUrl: String?) {
        let id = player.player.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 1), queue: nil) { [weak self] _ in
            guard let self = self else { return }
            self.setupRemoteCommandNotification(player, title: title, author: author, imageUrl: imageUrl)
        }
        let key = keyForPlayer(player)
        timeObserverIdDict[key] = id
    }

    private func disposeNotificationData(_ player: BetterPlayer) {
        if player === notificationPlayer {
            notificationPlayer = nil
            remoteCommandsInitialized = false
        }
        let key = keyForPlayer(player)
        if let id = timeObserverIdDict[key] { player.player.removeTimeObserver(id); timeObserverIdDict.removeValue(forKey: key) }
        artworkImageDict.removeValue(forKey: key)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [:]
    }

    private func stopOtherUpdateListener(_ player: BetterPlayer) {
        let currentPlayerKey = keyForPlayer(player)
        for (textureId, timeObserver) in timeObserverIdDict where textureId != currentPlayerKey {
            if let playerToRemoveListener = players[textureId] {
                playerToRemoveListener.player.removeTimeObserver(timeObserver)
            }
        }
        timeObserverIdDict.removeAll()
    }
}

extension BetterPlayerPlugin {
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "init" {
            for (_, player) in players { player.dispose() }
            players.removeAll()
            result(nil)
            return
        }
        if call.method == "create" {
            let player = BetterPlayer(frame: .zero)
            onPlayerSetup(player, result: result)
            return
        }

        guard let argsMap = call.arguments as? [String: Any], let textureId = (argsMap["textureId"] as? NSNumber)?.int64Value, let player = players[textureId] else {
            result(FlutterMethodNotImplemented)
            return
        }

        switch call.method {
        case "setDataSource":
            player.clear()
            let dataSource = argsMap["dataSource"] as? [String: Any] ?? [:]
            dataSourceDict[textureId] = dataSource
            let assetArg = dataSource["asset"] as? String
            let uriArg = dataSource["uri"] as? String
            let key = dataSource["key"] as? String
            let certificateUrl = dataSource["certificateUrl"] as? String
            let licenseUrl = dataSource["licenseUrl"] as? String
            let headers = dataSource["headers"] as? [String: Any] ?? [:]
            let cacheKey = dataSource["cacheKey"] as? String
            let maxCacheSize = dataSource["maxCacheSize"] as? NSNumber
            let videoExtension = dataSource["videoExtension"] as? String
            let overriddenDuration = (dataSource["overriddenDuration"] as? NSNumber)?.intValue ?? 0

            let useCache = (dataSource["useCache"] as? NSNumber)?.boolValue ?? false
            if useCache { cacheManager.setMaxCacheSize(maxCacheSize) }

            if let assetArg = assetArg {
                let assetPath: String
                if let pkg = dataSource["package"] as? String, !pkg.isEmpty {
                    assetPath = registrar.lookupKey(forAsset: assetArg, fromPackage: pkg)
                } else {
                    assetPath = registrar.lookupKey(forAsset: assetArg)
                }
                player.setDataSourceAsset(assetPath, key: key, certificateUrl: certificateUrl, licenseUrl: licenseUrl, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration)
            } else if let uriArg = uriArg, let url = URL(string: uriArg) {
                player.setDataSourceURL(url, key: key, certificateUrl: certificateUrl, licenseUrl: licenseUrl, headers: headers, useCache: useCache, cacheKey: cacheKey, cacheManager: cacheManager, overriddenDuration: overriddenDuration, videoExtension: videoExtension)
            } else {
                result(FlutterMethodNotImplemented)
                return
            }
            result(nil)
        case "dispose":
            player.clear()
            disposeNotificationData(player)
            setRemoteCommandsNotificationNotActive()
            players.removeValue(forKey: textureId)
            if players.isEmpty { try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation]) }
            result(nil)
        case "setLooping":
            if let looping = (argsMap["looping"] as? NSNumber)?.boolValue { player.isLooping = looping }
            result(nil)
        case "setVolume":
            if let vol = (argsMap["volume"] as? NSNumber)?.doubleValue { player.setVolume(vol) }
            result(nil)
        case "play":
            setupRemoteNotification(player)
            player.play(); result(nil)
        case "position":
            result(NSNumber(value: player.position()))
        case "absolutePosition":
            result(NSNumber(value: player.absolutePosition()))
        case "seekTo":
            if let location = (argsMap["location"] as? NSNumber)?.intValue { player.seekTo(location) }
            result(nil)
        case "pause":
            player.pause(); result(nil)
        case "setSpeed":
            if let speed = (argsMap["speed"] as? NSNumber)?.doubleValue { player.setSpeed(speed, result: result) } else { result(nil) }
        case "setTrackParameters":
            let width = (argsMap["width"] as? NSNumber)?.intValue ?? 0
            let height = (argsMap["height"] as? NSNumber)?.intValue ?? 0
            let bitrate = (argsMap["bitrate"] as? NSNumber)?.intValue ?? 0
            player.setTrackParameters(width: width, height: height, bitrate: bitrate)
            result(nil)
        case "enablePictureInPicture":
            let left = (argsMap["left"] as? NSNumber)?.doubleValue ?? 0
            let top = (argsMap["top"] as? NSNumber)?.doubleValue ?? 0
            let width = (argsMap["width"] as? NSNumber)?.doubleValue ?? 0
            let height = (argsMap["height"] as? NSNumber)?.doubleValue ?? 0
            player.enablePictureInPicture(CGRect(x: left, y: top, width: width, height: height))
            result(nil)
        case "isPictureInPictureSupported":
            if #available(iOS 9.0, *), AVPictureInPictureController.isPictureInPictureSupported() {
                result(NSNumber(value: true)); return
            }
            result(NSNumber(value: false))
        case "disablePictureInPicture":
            player.disablePictureInPicture(); player.setPictureInPicture(false); result(nil)
        case "setAudioTrack":
            let name = argsMap["name"] as? String ?? ""
            let index = (argsMap["index"] as? NSNumber)?.intValue ?? 0
            player.setAudioTrack(name: name, index: index)
            result(nil)
        case "setMixWithOthers":
            let mix = (argsMap["mixWithOthers"] as? NSNumber)?.boolValue ?? false
            player.setMixWithOthers(mix)
            result(nil)
        case "preCache":
            let dataSource = argsMap["dataSource"] as? [String: Any] ?? [:]
            let urlArg = dataSource["uri"] as? String
            let cacheKey = dataSource["cacheKey"] as? String
            let headers = dataSource["headers"] as? [String: Any] ?? [:]
            let maxCacheSize = dataSource["maxCacheSize"] as? NSNumber
            let videoExtension = dataSource["videoExtension"] as? String
            if let urlArg = urlArg, let url = URL(string: urlArg) {
                if cacheManager.isPreCacheSupported(url: url, videoExtension: videoExtension) {
                    cacheManager.setMaxCacheSize(maxCacheSize)
                    cacheManager.preCacheURL(url, cacheKey: cacheKey, videoExtension: videoExtension, withHeaders: headers as NSDictionary as! [NSObject: AnyObject]) { _ in }
                } else {
                    NSLog("Pre cache is not supported for given data source.")
                }
            }
            result(nil)
        case "clearCache":
            cacheManager.clearCache(); result(nil)
        case "stopPreCache":
            let urlArg = argsMap["url"] as? String
            let cacheKey = argsMap["cacheKey"] as? String
            let videoExtension = argsMap["videoExtension"] as? String
            if let urlArg = urlArg, let url = URL(string: urlArg) {
                if cacheManager.isPreCacheSupported(url: url, videoExtension: videoExtension) {
                    cacheManager.stopPreCache(url, cacheKey: cacheKey) { _ in }
                } else {
                    NSLog("Stop pre cache is not supported for given data source.")
                }
            }
            result(nil)
        case "setAspectRatio":
            guard let aspectRatioValue = argsMap["ratio"] as? String else {
                result(nil)
                return
            }
            let aspectRatio: AVLayerVideoGravity = switch(aspectRatioValue) {
            case "aspect":
                    .resizeAspect
            case "fill":
                    .resizeAspectFill
            case "stretch":
                    .resize
            default: .resizeAspect
                
            }
            player.setAspectRatio(aspectRatio)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        for (_, player) in players { player.disposeSansEventChannel() }
        players.removeAll()
    }
}
