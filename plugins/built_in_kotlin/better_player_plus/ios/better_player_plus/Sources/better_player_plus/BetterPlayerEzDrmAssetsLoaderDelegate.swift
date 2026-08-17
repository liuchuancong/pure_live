import Foundation
import AVFoundation

public class BetterPlayerEzDrmAssetsLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    public let certificateURL: URL
    public let licenseURL: URL?

    private var assetId: String = ""
    private let defaultLicenseServerURL = URL(string: "https://fps.ezdrm.com/api/licenses/")!

    public init(_ certificateURL: URL, withLicenseURL licenseURL: URL?) {
        self.certificateURL = certificateURL
        self.licenseURL = licenseURL
        super.init()
    }

    private func getContentKeyAndLeaseExpiryFromKeyServerModule(request spc: Data, assetId: String, customParams: String) -> Data? {
        let finalLicenseURL = licenseURL ?? defaultLicenseServerURL
        guard let ksmURL = URL(string: "\(finalLicenseURL.absoluteString)\(assetId)\(customParams)") else { return nil }
        var request = URLRequest(url: ksmURL)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-type")
        request.httpBody = spc

        let semaphore = DispatchSemaphore(value: 0)
        var resultData: Data?
        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            resultData = data
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + 30)
        return resultData
    }

    private func getAppCertificate() throws -> Data {
        return try Data(contentsOf: certificateURL)
    }

    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest) -> Bool {
        guard let assetURI = loadingRequest.request.url else { return false }
        let urlString = assetURI.absoluteString
        let scheme = assetURI.scheme ?? ""
        guard scheme == "skd" else { return false }

        if urlString.count >= 36 {
            let startIndex = urlString.index(urlString.endIndex, offsetBy: -36)
            assetId = String(urlString[startIndex...])
        }

        let certificate: Data
        do {
            certificate = try getAppCertificate()
        } catch {
            loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorClientCertificateRejected))
            return true
        }

        let requestBytes: Data
        do {
            guard let contentIdData = urlString.data(using: .utf8) else {
                loadingRequest.finishLoading(with: nil)
                return true
            }
            requestBytes = try loadingRequest.streamingContentKeyRequestData(forApp: certificate, contentIdentifier: contentIdData, options: nil)
        } catch {
            loadingRequest.finishLoading(with: nil)
            return true
        }

        let passthruParams = "?customdata=\(assetId)"
        let responseData = getContentKeyAndLeaseExpiryFromKeyServerModule(request: requestBytes, assetId: assetId, customParams: passthruParams)

        if let responseData = responseData, !responseData.isEmpty {
            loadingRequest.dataRequest?.respond(with: responseData)
            loadingRequest.finishLoading()
        } else {
            loadingRequest.finishLoading(with: NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse))
        }
        return true
    }

    public func resourceLoader(_ resourceLoader: AVAssetResourceLoader, shouldWaitForRenewalOfRequestedResource renewalRequest: AVAssetResourceRenewalRequest) -> Bool {
        return self.resourceLoader(resourceLoader, shouldWaitForLoadingOfRequestedResource: renewalRequest)
    }
}
