import Foundation
import JavaScriptCore

public enum JSContextFoundationError: Error {
    case fileNotFound
    case fileNotLoaded
    case fileNotDownloaded
}

open class JSContextFoundation : JSContext {
    public override init!(virtualMachine: JSVirtualMachine!) {
        super.init(virtualMachine: virtualMachine)

        exceptionHandler = { context, exception in
            let exceptionDictionary = exception?.toDictionary()
            print("[JSCotextFoundation][Exception] \(String(describing: exception)) at line \(String(describing: exceptionDictionary?["line"])):\(String(describing: exceptionDictionary?["column"]))")
        }

        insert()
    }

    public convenience override init!() {
        self.init(virtualMachine: JSVirtualMachine())
    }

    open func requireWithPath(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw JSContextFoundationError.fileNotFound
        }
        guard let script = try? String(contentsOfFile: path, encoding: String.Encoding.utf8) else {
            throw JSContextFoundationError.fileNotLoaded
        }

        evaluateScript(script)
    }

    open func requireWithUrl(_ url: URL, completionHandler: @escaping (Error?) -> Void) {
        let task = URLSession.shared.dataTask(with: url, completionHandler: { (data, response, error) -> Void in
            if let error = error {
                completionHandler(error)
            }
            else {
                guard let httpResponse = response as? HTTPURLResponse else {
                    completionHandler(JSContextFoundationError.fileNotDownloaded)
                    return
                }

                switch httpResponse.statusCode {
                case 404:
                    completionHandler(JSContextFoundationError.fileNotFound)
                default:
                    guard let data = data, let script = String(data: data, encoding: String.Encoding.utf8) as String? else {
                        completionHandler(JSContextFoundationError.fileNotDownloaded)
                        return
                    }

                    self.evaluateScript(script)
                    completionHandler(nil)
                }
            }
        })

        task.resume()
    }

    fileprivate func insert() {
        let jsInsertArray: [JSInsert] = [Global(), Console()]
        for jsInsert in jsInsertArray {
            jsInsert.insert(self)
        }
    }
}