import Cocoa
import FlutterMacOS
import XCTest
@testable import media_kit_video

class RunnerTests: XCTestCase {

  func testExample() {
    // If you add code to the Runner application, consider adding tests here.
    // See https://developer.apple.com/documentation/xctest for more information about using XCTest.
  }

  func testOpenGLSymbolLoaderLoadsRequiredFunctions() {
    for symbol in ["glGetString", "glBindFramebuffer", "glFlush"] {
      symbol.withCString {
        XCTAssertNotNil(OpenGLSymbolLoader.load($0), symbol)
      }
    }
  }

  func testOpenGLSymbolLoaderRejectsMissingNames() {
    XCTAssertNil(OpenGLSymbolLoader.load(nil))

    "pure_live_missing_opengl_symbol".withCString {
      XCTAssertNil(OpenGLSymbolLoader.load($0))
    }
  }

}
