import Flutter
import JavaScriptCore
import UIKit

public class SwiftFlutterJsPlugin: NSObject, FlutterPlugin {
    private var jsEngineMap = [Int: JSContextFoundation]()
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "io.abner.flutter_js", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterJsPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initEngine":
            let engineId = call.arguments as! Int
            jsEngineMap[engineId] = JSContextFoundation()
            result(engineId)
        case "evaluate":
            let argsMap = call.arguments as! NSDictionary
            let command: String = argsMap.value(forKey: "command") as! String
            let engineId: Int = argsMap.value(forKey: "engineId") as! Int
            let convertTo: String = argsMap.value(forKey: "convertTo") as! String

            if let jsEngine = jsEngineMap[engineId] {
                jsEngine.exceptionHandler = { _, exception in
                    let exceptionDictionary = exception?.toDictionary()
                    print("[JSCotextFoundation][Exception] \(String(describing: exception)) at line \(String(describing: exceptionDictionary?["line"])):\(String(describing: exceptionDictionary?["column"]))")
                    result(FlutterError(code: "EvaluateError",
                                        message: String(describing: exception),
                                        details: nil))
                }

                let resultJsValue: JSValue = jsEngine.evaluateScript(command)
                if convertTo != nil {
                    if convertTo == "array" {
                        result(resultJsValue.toArray())
                    } else if convertTo == "object" {
                        result(resultJsValue.toDictionary())
                    } else {
                        result(resultJsValue.toString())
                    }
                } else {
                    result(resultJsValue.toString())
                }

            } else {
                result(FlutterError(code: "EvaluateError",
                                    message: "jsEngine was not found",
                                    details: nil))
            }
        case "close":
            result(FlutterMethodNotImplemented)
            break
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
