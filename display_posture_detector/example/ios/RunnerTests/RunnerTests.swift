import Flutter
import UIKit
import XCTest

@testable import display_posture_detector

class RunnerTests: XCTestCase {

  func testUnknownMethodReturnsNotImplemented() {
    let plugin = DisplayPostureDetectorPlugin()
    let call = FlutterMethodCall(methodName: "unknownMethod", arguments: nil)

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertTrue((result as AnyObject) === FlutterMethodNotImplemented)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
