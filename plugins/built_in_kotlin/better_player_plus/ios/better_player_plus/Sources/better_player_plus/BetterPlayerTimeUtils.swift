import Foundation
import AVFoundation

public enum BetterPlayerTimeUtils {
    public static func cmTimeToMillis(_ time: CMTime) -> Int64 {
        guard time.timescale != 0 else { return 0 }
        return Int64(time.value) * 1000 / Int64(time.timescale)
    }

    public static func timeIntervalToMillis(_ interval: TimeInterval) -> Int64 {
        return Int64(interval * 1000.0)
    }
}
