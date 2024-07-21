import ConcurrencyExtras
import CustomDump
import XCTest
@testable import SwiftShell

final class ShellProcessTests: XCTestCase {
  func testIsRunning() async throws {
    let process = ShellProcess(
      executableURL: URL(filePath: "/usr/bin/env"),
      arguments: ["bash", "-c", "sleep 10"]
    )
    await assertNoDifference(await process.isRunning, false)
    try await process.run()
    await assertNoDifference(await process.isRunning, true)
    await process.terminate()
    _ = try? await process.waitUntilExit()
    await assertNoDifference(await process.isRunning, false)
  }

  func testExitSuccess() async throws {
    let process = ShellProcess(
      executableURL: URL(filePath: "/usr/bin/env"),
      arguments: ["bash", "-c", "exit \(EXIT_SUCCESS)"]
    )
    try await process.run()
    let status = try await process.waitUntilExit()
    XCTAssertNoDifference(status, EXIT_SUCCESS)
  }

  func testExitCustomSuccess() async throws {
    let EXIT_CUSTOM_SUCCESS: Int32 = 7
    let process = ShellProcess(
      executableURL: URL(filePath: "/usr/bin/env"),
      arguments: ["bash", "-c", "exit \(EXIT_CUSTOM_SUCCESS)"]
    )
    try await process.run()
    let status = try await process.waitUntilExit { $0 == EXIT_CUSTOM_SUCCESS }
    XCTAssertNoDifference(status, EXIT_CUSTOM_SUCCESS)
  }

  func testExitFailure() async throws {
    let process = ShellProcess(
      executableURL: URL(filePath: "/usr/bin/env"),
      arguments: ["bash", "-c", "exit \(EXIT_FAILURE)"]
    )
    try await process.run()
    await assertThrows(try await process.waitUntilExit()) { error in
      assertError(error, ShellProcess.Failure.exit(EXIT_FAILURE))
      let status = (error as? ShellProcess.Failure)?.status
      XCTAssertNoDifference(status, EXIT_FAILURE)
    }
  }

  func testTermination() async throws {
    let process = ShellProcess(
      executableURL: URL(filePath: "/usr/bin/env"),
      arguments: ["bash", "-c", "sleep 10"]
    )
    try await process.run()
    await process.terminate()
    await assertThrows(try await process.waitUntilExit()) { error in
      assertError(error, ShellProcess.Failure.uncaughtSignal(SIGTERM))
      let status = (error as? ShellProcess.Failure)?.status
      XCTAssertNoDifference(status, SIGTERM)
    }
  }

  func testSendInputToNotRunningProcess() async throws {
    let process = ShellProcess(.bash(""))
    await assertThrows(try await process.send(input: "hello".data(using: .utf8)!)) { error in
      assertError(error, ShellProcess.InputError.processIsNotRunning)
    }
  }

  func testOutputAndError() async throws {
    let process = ShellProcess(
      executableURL: URL(filePath: "/usr/bin/env"),
      arguments: ["bash", "-c", """
      echo "test output"
      echo "test error" 1>&2
      """]
    )
    try await process.run()
    let output = try await process.output()
    let error = try await process.error()
    XCTAssertNoDifference(
      output.map { String(data: $0, encoding: .utf8) },
      "test output\n"
    )
    XCTAssertNoDifference(
      error.map { String(data: $0, encoding: .utf8) },
      "test error\n"
    )
  }

  func testInputOutputErrorStreams() async throws {
    let process = ShellProcess(
      executableURL: URL(filePath: "/usr/bin/env"),
      arguments: ["bash", "-c", """
      while IFS= read -r line; do
        if [[ $line =~ ^! ]]; then
          echo "read line: $line" 1>&2
        else
          echo "read line: $line"
        fi
      done < "${1:-/dev/stdin}"
      echo "finished reading lines"
      """]
    )
    struct State: Equatable, Sendable {
      var output: [String] = []
      var error: [String] = []
    }
    let state = ActorIsolated(State())

    let receivedOutput = KeyedExpectations<Int> { "received output #\($0)" }
    Task { @MainActor in
      let index = ActorIsolated(0)
      for await data in process.outputStream() {
        let string = String(data: data, encoding: .utf8)!
        await state.withValue { $0.output.append(string) }
        let index = await index.withValue { $0 += 1; return $0 }
        await receivedOutput[index].fulfill()
      }
    }

    let receivedError = KeyedExpectations<Int> { "received error #\($0)" }
    Task {
      let index = ActorIsolated(0)
      for await data in process.errorStream() {
        let string = String(data: data, encoding: .utf8)!
        await state.withValue { $0.error.append(string) }
        let index = await index.withValue { $0 += 1; return $0 }
        await receivedError[index].fulfill()
      }
    }

    try await process.run()

    try await process.send(input: "Hello".data(using: .utf8)!)
    try await process.send(input: ", World!\n".data(using: .utf8)!)
    await fulfillment(of: [receivedOutput[1]], timeout: 1)
    await assertNoDifference(
      await state.value,
      State(output: ["read line: Hello, World!\n"])
    )
    await state.setValue(State())

    try await process.send(input: "Goodbye.\n".data(using: .utf8)!)
    await fulfillment(of: [receivedOutput[2]], timeout: 1)
    await assertNoDifference(
      await state.value,
      State(output: ["read line: Goodbye.\n"])
    )
    await state.setValue(State())

    try await process.send(input: "! test error\n".data(using: .utf8)!)
    await fulfillment(of: [receivedError[1]], timeout: 1)
    await assertNoDifference(
      await state.value,
      State(error: ["read line: ! test error\n"])
    )
    await state.setValue(State())

    try await process.endInput()
    await fulfillment(of: [receivedOutput[3]], timeout: 1)
    await assertNoDifference(
      await state.value,
      State(output: ["finished reading lines\n"])
    )
  }

  func testInitWithCommand() async {
    let command = ShellCommand(
      executableURL: URL(filePath: "/test/path/exec"),
      arguments: ["arg1", "arg2"],
      environment: .custom(["VAR1": "value1", "VAR2": "value2"])
    )
    let process = ShellProcess(command)

    await assertNoDifference(await process.process.executableURL, command.executableURL)
    await assertNoDifference(await process.process.arguments, command.arguments)
    await assertNoDifference(await process.process.environment, command.environment.keyValues)
  }

  func testInitWithCommandWorkDir() async {
    let command = ShellCommand(
      executableURL: URL(filePath: "/test/path/exec"),
      workingDirectory: URL(fileURLWithPath: "/test/path/workdir/")
    )
    let process = ShellProcess(command)

    await assertNoDifference(await process.process.currentDirectoryURL, command.workingDirectory)
  }

  func testInitWithCommandWorkingDirOverwrite() async {
    let command = ShellCommand(
      executableURL: URL(filePath: "/test/path/exec"),
      workingDirectory: URL(fileURLWithPath: "/test/path/workdir/")
    )
    let workDir = URL(filePath: "/test/path/workdir2/")
    let process = ShellProcess(command, currentDirectoryURL: workDir)

    await assertNoDifference(await process.process.currentDirectoryURL, workDir)
  }

  func testInitWithCommandQoS() async {
    let command = ShellCommand(
      executableURL: URL(filePath: "/test/path/exec"),
      qualityOfService: .background
    )
    let process = ShellProcess(command)

    await assertNoDifference(await process.process.qualityOfService, command.qualityOfService)
  }

  func testInitWithCommandQoSOverwrite() async {
    let command = ShellCommand(
      executableURL: URL(filePath: "/test/path/exec"),
      qualityOfService: .background
    )
    let qualityOfService = QualityOfService.utility
    let process = ShellProcess(command, qualityOfService: qualityOfService)

    await assertNoDifference(await process.process.qualityOfService, qualityOfService)
  }
}
