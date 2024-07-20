import Foundation

/// Represents task that executes shell command.
public struct ShellTask: Sendable {
  /// Create shell task.
  /// - Parameter command: Shell command to execute.
  public init(_ command: ShellCommand) {
    self.command = command
  }
  
  /// Shell command to execute.
  public let command: ShellCommand
  
  let process = Process()
  let inputPipe = Pipe()
  let outputPipe = Pipe()
  let errorPipe = Pipe()
  
  /// Start process that executes the command.
  ///
  /// If `workDirectory` is provided, it will overwrite the one defined by the command.
  ///
  /// If `qualityOfService` is provided, it will overwrite the one defined by the command.
  ///
  /// - Parameters:
  ///   - workDirectory: Working directory for the process.
  ///   - qualityOfService: Quality of service level applied to the process.
  public func run(
     in workDirectory: URL? = nil,
     qualityOfService: QualityOfService? = nil
  ) throws {
    process.executableURL = command.executableURL
    process.arguments = command.arguments
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    process.environment = command.environment.keyValues
    if let workDirectory {
      process.currentDirectoryURL = workDirectory
    } else if let workDirectory = command.workDirectory {
      process.currentDirectoryURL = workDirectory
    }
    if let qualityOfService {
      process.qualityOfService = qualityOfService
    } else if let qualityOfService = command.qualityOfService {
      process.qualityOfService = qualityOfService
    }
    try process.run()
  }
  
  /// Send input data to running process.
  ///
  /// If the process is not running, `SendInputToNotRunningTaskError` will be thrown.
  ///
  /// - Parameter data: Input data.
  public func send(input data: Data) throws {
    guard process.isRunning else {
      throw SendInputToNotRunningTaskError()
    }
    try inputPipe.fileHandleForWriting.write(contentsOf: data)
  }
  
  /// Close input stream.
  ///
  /// Once closed, further tries to send input will fail.
  public func endInput() throws {
    try inputPipe.fileHandleForWriting.close()
  }
  
  /// Creates stream that emits standard output data.
  ///
  /// Only one stream should be created per task.
  ///
  /// - Returns: Async stream of standard output data.
  public func outputStream() -> AsyncStream<Data> {
    AsyncStream {
      let data = outputPipe.fileHandleForReading.availableData
      return data.isEmpty ? nil : data
    }
  }
  
  /// Reads standard output till the end and returns collected data.
  ///
  /// - Returns: Standard output data.
  public func output() async -> Data {
    await outputStream().reduce(into: Data()) { $0.append($1) }
  }
  
  /// Creates stream that emits standard error data.
  ///
  /// Only one stream should be created per task.
  ///
  /// - Returns: Async stream of standard error data.
  public func errorStream() -> AsyncStream<Data> {
    AsyncStream {
      let data = errorPipe.fileHandleForReading.availableData
      return data.isEmpty ? nil : data
    }
  }

  /// Reads standard error till the end and returns collected data.
  ///
  /// - Returns: Standard error data.
  public func error() async -> Data {
    await errorStream().reduce(into: Data()) { $0.append($1) }
  }
  
  /// Terminates running process.
  public func terminate() {
    process.terminate()
  }
  
  /// Waits until process exits.
  ///
  /// Returns successfully when process exits with code `EXIT_SUCCESS`. Otherwise throws `Failure`.
  public func waitUntilExit() async throws {
    try await withUnsafeThrowingContinuation { continuation in
      process.waitUntilExit()
      let code = process.terminationStatus
      switch process.terminationReason {
      case .exit:
        if code == EXIT_SUCCESS {
          continuation.resume()
        } else {
          continuation.resume(throwing: Failure.exit(code))
        }
      case .uncaughtSignal:
        continuation.resume(throwing: Failure.uncaughtSignal(code))
      @unknown default:
        continuation.resume(throwing: Failure.unknownTerminationReason(code))
      }
    }
  }
}

extension ShellTask {
  /// Represents task failure.
  public enum Failure: Error, Equatable {
    /// Task's process exited with code other than `EXIT_SUCCESS`. Contains exit code.
    case exit(Int32)

    /// Task's process terminated with uncaught signal. Contains exit code.
    case uncaughtSignal(Int32)

    /// Task's process termination reason is unknown. Contains exit code.
    case unknownTerminationReason(Int32)
  }
  
  /// Tried to send input when task's process is not running.
  public struct SendInputToNotRunningTaskError: Error, Equatable {}
}
