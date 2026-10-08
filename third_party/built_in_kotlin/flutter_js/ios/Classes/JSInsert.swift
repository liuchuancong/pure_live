import Foundation
import JavaScriptCore

@objc protocol JSInsert {
    func insert(_ jsContext: JSContext)
}