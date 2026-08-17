import UIKit
import AVFoundation
import AVKit

public class BetterPlayerView: UIView {
    public var player: AVPlayer? {
        get { playerLayer.player }
        set { playerLayer.player = newValue }
    }

    public var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }

    public override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }
}
