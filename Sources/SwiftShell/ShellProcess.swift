import Foundation

/// Represents shell process.
public actor ShellProcess {
  /// Create shell process.
  ///
  /// If `nil` `environment` is provided (default), current process environment is used.
  ///
  /// If `nil` `currentDirectoryURL` is provided (default), current working directory is used.
  ///
  /// If `nil` `qualityOfService` is provided (default), a default QoS class is used.
  ///
  /// - Parameters:
  ///   - executableURL: URL represening path to the executable.
  ///   - arguments: The command arguments used to launch the executable.
  ///   - environment: Environment variables dictionary.
  ///   - currentDirectoryURL: Working directory for the executable.
  ///   - qualityOfService: Quality of service class applied to the process.
  public init(
    executableURL: URL,
    arguments: [String]? = nil,
    environment: [String: String]? = nil,
    currentDirectoryURL: URL? = nil,
    qualityOfService: QualityOfService? = nil
  ) {
    process.standardInput = inputPipe
    process.standardOutput = outputPipe
    process.standardError = errorPipe
    process.executableURL = executableURL
    process.arguments = arguments
    process.environment = environment
    process.currentDirectoryURL = currentDirectoryURL
    process.qualityOfService = qualityOfService ?? .default
  }

  let process = Process()
  let inputPipe = Pipe()
  let outputPipe = Pipe()
  let errorPipe = Pipe()

  // MARK: - Lifecycle

  /// Represents shell process failure.
  public enum Failure: Error, Equatable, Sendable {
    /// Process exited with code that represents failure.
    case exit(Int32)

    /// Process terminated with uncaught signal.
    case uncaughtSignal(Int32)

    /// Process termination reason is unknown.
    case unknown(Int32)

    /// Process termination status code.
    public var status: Int32 {
      switch self {
      case .exit(let status),
          .uncaughtSignal(let status),
          .unknown(let status):
        return status
      }
    }
  }

  /// A status that indicates whether the process is running.
  ///
  /// `true` if the process is still running, otherwise `false`. `false` means either the process could not run or it has terminated.
  public var isRunning: Bool {
    process.isRunning
  }

  /// Runs the process.
  public func run() throws {
    try process.run()
  }

  /// Terminates the process.
  ///
  /// This method has no effect if the process was run and has already finished executing. If the process hasn’t been run yet, this method raises an NSInvalidArgumentException.
  ///
  /// The method uses `SIGTERM` signal. It’s not always possible to terminate the process because it might be ignoring the signal.
  public func terminate() {
    process.terminate()
  }

  /// Waits until process exits and returns termination status code.
  ///
  /// This method can throw `Failure` error when:
  /// - Termination status code does not pass validation with `isSuccess` closure.
  /// - Process terminates after receiving uncaught signal.
  /// - Process terminates for unknown reason.
  ///
  /// - Parameter isSuccess: A closure that validates termination status code. It should return `true` if provided code represents success. Defaults to a closure that returns `true` if code is equal to `EXIT_SUCCESS`.
  /// - Returns: Termination status code.
  @discardableResult
  public func waitUntilExit(
    validate isSuccess: @Sendable (Int32) -> Bool = { $0 == EXIT_SUCCESS }
  ) throws -> Int32 {
    process.waitUntilExit()
    let status = process.terminationStatus
    switch process.terminationReason {
    case .exit:
      guard isSuccess(status) else {
        throw Failure.exit(status)
      }
    case .uncaughtSignal:
      throw Failure.uncaughtSignal(status)
    @unknown default:
      throw Failure.unknown(status)
    }
    return status
  }

  // MARK: - Input & Output

  /// Represents process input failure.
  public enum InputError: Error, Equatable, Sendable {
    /// Could not send input to process, because it's not running.
    case processIsNotRunning
  }

  /// Send input data to running process.
  ///
  /// If the process is not running this method throws `InputError`.
  ///
  /// - Parameter data: Input data.
  public func send(input data: Data) throws {
    guard isRunning else { throw InputError.processIsNotRunning }
    try inputPipe.fileHandleForWriting.write(contentsOf: data)
  }

  /// Close input stream.
  ///
  /// Once closed, further tries to send input will fail.
  public func endInput() throws {
    try inputPipe.fileHandleForWriting.close()
  }

  /// Reads standard output to the end and returns data.
  ///
  /// - Returns: Standard output data.
  public func output() throws -> Data? {
    try outputPipe.fileHandleForReading.readToEnd()
  }

  /// Creates stream that emits standard output data.
  ///
  /// Only one stream should be created per process.
  ///
  /// - Returns: Async stream of standard output data.
  public nonisolated func outputStream() -> AsyncStream<Data> {
    AsyncStream {
      let data = self.outputPipe.fileHandleForReading.availableData
      return data.isEmpty ? nil : data
    }
  }

  /// Reads standard error to the end and returns data.
  ///
  /// - Returns: Standard error data.
  public func error() throws -> Data? {
    try errorPipe.fileHandleForReading.readToEnd()
  }

  /// Creates stream that emits standard error data.
  ///
  /// Only one stream should be created per process.
  ///
  /// - Returns: Async stream of standard error data.
  public nonisolated func errorStream() -> AsyncStream<Data> {
    AsyncStream {
      let data = self.errorPipe.fileHandleForReading.availableData
      return data.isEmpty ? nil : data
    }
  }
}

extension ShellProcess {
  /// Create process that execures provided shell command.
  ///
  /// If `nil` `workingDirectory` is provided (default), the command's working directory will be used.
  ///
  /// If `nil` `qualityOfService` is provided (default), the command's QoS will be used.
  ///
  /// - Parameters:
  ///   - command: Shell command to execute.
  ///   - currentDirectoryURL: Working directory for the executable.
  ///   - qualityOfService: Quality of service class applied to the process.
  public init(
    _ command: ShellCommand,
    currentDirectoryURL: URL? = nil,
    qualityOfService: QualityOfService? = nil
  ) {
    self.init(
      executableURL: command.executableURL,
      arguments: command.arguments,
      environment: command.environment.keyValues,
      currentDirectoryURL: currentDirectoryURL ?? command.workingDirectory,
      qualityOfService: qualityOfService ?? command.qualityOfService
    )
  }
}
