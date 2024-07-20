import XCTest
@testable import SwiftShell

final class ShellCommandTests: XCTestCase {
  func testConvenientInit() {
    let command = ShellCommand(
      "/path/to/exec", "--flag1", "--flag2",
      environment: .custom(["KEY": "VALUE"]),
      workDirectory: "/path/to/workdir"
    )

    XCTAssertEqual(
      command,
      ShellCommand(
        executableURL: URL(filePath: "/path/to/exec"),
        arguments: ["--flag1", "--flag2"],
        environment: .custom(["KEY": "VALUE"]),
        workDirectory: URL(filePath: "/path/to/workdir")
      )
    )
  }
}
