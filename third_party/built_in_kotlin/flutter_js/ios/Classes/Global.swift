import Foundation
import JavaScriptCore

@objc protocol GlobalJSExport : JSExport {
}

@objc class Global : NSObject, GlobalJSExport, JSInsert {
    func insert(_ jsContext: JSContext) {
        jsContext.setObject(self, forKeyedSubscript:"global" as (NSCopying & NSObjectProtocol))
        jsContext.evaluateScript("var window = global;")
    }
}