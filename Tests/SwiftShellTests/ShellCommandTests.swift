import CustomDump
import XCTest
@testable import SwiftShell

final class ShellCommandTests: XCTestCase {
  func testConvenientInit() {
    XCTAssertNoDifference(
      ShellCommand(
        "/path/to/exec", "--flag1", "--flag2"
      ),
      ShellCommand(
        executableURL: URL(filePath: "/path/to/exec"),
        arguments: ["--flag1", "--flag2"]
      )
    )
    XCTAssertNoDifference(
      ShellCommand(
        "/path/to/exec", "--flag1", "--flag2",
        environment: .custom(["KEY": "VALUE"]),
        workingDirectory: "/path/to/workdir/",
        qualityOfService: .utility
      ),
      ShellCommand(
        executableURL: URL(filePath: "/path/to/exec"),
        arguments: ["--flag1", "--flag2"],
        environment: .custom(["KEY": "VALUE"]),
        workingDirectory: URL(filePath: "/path/to/workdir/"),
        qualityOfService: .utility
      )
    )
  }
}
