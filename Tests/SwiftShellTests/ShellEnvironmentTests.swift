import XCTest
@testable import SwiftShell

final class ShellEnvironmentTests: XCTestCase {
  func testEmpty() {
    let env = ShellEnvironment.empty
    XCTAssertEqual(env.keyValues, [:])
  }

  func testCustom() {
    let env = ShellEnvironment.custom(["KEY": "VALUE"])
    XCTAssertEqual(env.keyValues, ["KEY": "VALUE"])
  }

  func testCurrent() {
    let env = ShellEnvironment.current
    XCTAssertEqual(env.keyValues, ProcessInfo.processInfo.environment)
  }

  func testOverwriteValue() {
    let env = ShellEnvironment
      .custom(["PATH": "/usr/bin"])
      .merging(["PATH": "/usr/sbin"])

    XCTAssertEqual(env["PATH"], "/usr/sbin")
  }

  func testSetValueIfNotSet() {
    let envWithPath = ShellEnvironment.custom(["PATH": "/usr/bin"])
    let envWithoutPath = ShellEnvironment.empty

    func setPathIfMissing(_ env: ShellEnvironment) -> ShellEnvironment {
      env.merging(["PATH": "/usr/sbin"]) { oldValue, _ in oldValue }
    }

    XCTAssertEqual(setPathIfMissing(envWithPath)["PATH"], "/usr/bin")
    XCTAssertEqual(setPathIfMissing(envWithoutPath)["PATH"], "/usr/sbin")
  }

  func testModifyValue() {
    let env = ShellEnvironment
      .custom(["PATH": "/usr/bin"])
      .merging(["PATH": "/usr/sbin"]) { oldValue, newValue in
        "\(newValue):\(oldValue)"
      }

    XCTAssertEqual(env["PATH"], "/usr/sbin:/usr/bin")
  }

  func testRemoveValue() {
    let env = ShellEnvironment
      .custom(["PATH": "/usr/bin"])
      .merging(["PATH": nil])

    XCTAssertNil(env["PATH"])
  }

  func testEquality() {
    XCTAssertEqual(
      ShellEnvironment.custom(["A": "1"]),
      ShellEnvironment.empty.merging(["A": "1"])
    )
    XCTAssertNotEqual(
      ShellEnvironment.custom(["A": "1"]),
      ShellEnvironment.empty.merging(["A": "2"])
    )
  }
}
