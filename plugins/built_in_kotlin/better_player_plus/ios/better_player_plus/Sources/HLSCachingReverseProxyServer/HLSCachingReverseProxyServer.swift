import Foundation
import GCDWebServer
import PINCache

public final class HLSCachingReverseProxyServer {
    public init(webServer: GCDWebServer, urlSession: URLSession, cache: PINCache) {
        _ = webServer
        _ = urlSession
        _ = cache
    }

    public func start(port: Int) {
        _ = port
    }

    public func reverseProxyURL(from url: URL) -> URL? {
        url
    }
}

