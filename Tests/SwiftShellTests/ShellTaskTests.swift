import ConcurrencyExtras
import CustomDump
import XCTest
@testable import SwiftShell

final class ShellTaskTests: XCTestCase {
  func testOutputAndError() async throws {
    let command = ShellCommand.bash(
      """
      echo "test output"
      echo "test error" 1>&2
      """)
    let task = ShellTask(command)
    try task.run()
    let output = await task.output()
    let error = await task.error()
    XCTAssertNoDifference(
      String(data: output, encoding: .utf8),
      "test output\n"
    )
    XCTAssertNoDifference(
      String(data: error, encoding: .utf8),
      "test error\n"
    )
  }

  func testExit() async throws {
    let command = ShellCommand.bash("exit 0")
    let task = ShellTask(command)
    try task.run()
    try await task.waitUntilExit()
  }

  func testFailureExit() async throws {
    let command = ShellCommand.bash("exit 7")
    let task = ShellTask(command)
    try task.run()
    await assertThrows(try await task.waitUntilExit()) { error in
      assertError(error, ShellTask.Failure.exit(7))
    }
  }

  func testTermination() async throws {
    let command = ShellCommand.bash("sleep 10")
    let task = ShellTask(command)
    try task.run()
    task.terminate()
    await assertThrows(try await task.waitUntilExit()) { error in
      assertError(error, ShellTask.Failure.uncaughtSignal(15))
    }
  }

  func testSendInputToNotRunningTask() async throws {
    let command = ShellCommand.bash("")
    let task = ShellTask(command)
    await assertThrows(try task.send(input: Data())) { error in
      assertError(error, ShellTask.SendInputToNotRunningTaskError())
    }
    try task.run()
    try await task.waitUntilExit()
    await assertThrows(try task.send(input: Data())) { error in
      assertError(error, ShellTask.SendInputToNotRunningTaskError())
    }
  }

  func testCommandWorkDirectory() throws {
    let command = ShellCommand.bash("", workDirectory: URL(filePath: "/tmp/\(UUID().uuidString)/"))
    try FileManager.default.createDirectory(at: command.workDirectory!, withIntermediateDirectories: true)
    let task = ShellTask(command)
    try task.run()
    XCTAssertNoDifference(task.process.currentDirectoryURL, command.workDirectory)
    try FileManager.default.removeItem(at: command.workDirectory!)
  }

  func testTaskWorkDirectory() throws {
    let command = ShellCommand.bash("", workDirectory: URL(filePath: "/tmp/"))
    let task = ShellTask(command)
    let taskWorkDirectory = URL(filePath: "/tmp/\(UUID().uuidString)/")
    try FileManager.default.createDirectory(at: taskWorkDirectory, withIntermediateDirectories: true)
    try task.run(in: taskWorkDirectory)
    XCTAssertNoDifference(task.process.currentDirectoryURL, taskWorkDirectory)
    try FileManager.default.removeItem(at: taskWorkDirectory)
  }

  func testCommandQoS() throws {
    let command = ShellCommand.bash("", qualityOfService: .utility)
    let task = ShellTask(command)
    try task.run()
    XCTAssertNoDifference(task.process.qualityOfService, command.qualityOfService)
  }

  func testTaskQoS() throws {
    let command = ShellCommand.bash("", qualityOfService: .utility)
    let task = ShellTask(command)
    try task.run(qualityOfService: .background)
    XCTAssertNoDifference(task.process.qualityOfService, .background)
  }

  func testInputOutput() async throws {
    let command = ShellCommand.bash(
      """
      echo "some output"
      echo "some error" 1>&2
      while IFS= read -r line; do
        echo "read line: $line"
      done < "${1:-/dev/stdin}"
      echo "finished reading lines"
      """
    )

    let task = ShellTask(command)
    let output = ActorIsolated<[String]>([])
    let error = ActorIsolated<[String]>([])

    let receivedOutput = KeyedExpectations<Int> { "received output #\($0)" }
    Task {
      let index = ActorIsolated(0)
      for await data in task.outputStream() {
        let string = String(data: data, encoding: .utf8)!
        await output.withValue { $0.append(string) }
        let index = await index.withValue { $0 += 1; return $0 }
        await receivedOutput[index].fulfill()
      }
    }

    let receivedError = KeyedExpectations<Int> { "received error #\($0)" }
    Task {
      let index = ActorIsolated(0)
      for await data in task.errorStream() {
        let string = String(data: data, encoding: .utf8)!
        await error.withValue { $0.append(string) }
        let index = await index.withValue { $0 += 1; return $0 }
        await receivedError[index].fulfill()
      }
    }

    try task.run()

    await fulfillment(of: [receivedOutput[1]], timeout: 1)
    await assertNoDifference(await output.value, ["some output\n"])

    await fulfillment(of: [receivedError[1]], timeout: 1)
    await assertNoDifference(await error.value, ["some error\n"])

    await output.setValue([])
    try task.send(input: "Hello".data(using: .utf8)!)
    try task.send(input: ", World!\n".data(using: .utf8)!)

    await fulfillment(of: [receivedOutput[2]], timeout: 1)
    await assertNoDifference(await output.value, ["read line: Hello, World!\n"])

    await output.setValue([])
    try task.send(input: "Goodbye!\n".data(using: .utf8)!)

    await fulfillment(of: [receivedOutput[3]], timeout: 1)
    await assertNoDifference(await output.value, ["read line: Goodbye!\n"])

    await output.setValue([])
    try task.endInput()

    await fulfillment(of: [receivedOutput[4]], timeout: 1)
    await assertNoDifference(await output.value, ["finished reading lines\n"])
  }
}
