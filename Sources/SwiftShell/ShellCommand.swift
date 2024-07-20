import Foundation

/// Shell command representation.
public struct ShellCommand: Equatable, Sendable {
  /// Create shell command representation.
  ///
  /// If `nil` `workingDirectory` is provided (default), the current working directory will be used.
  ///
  /// If `nil` `qualityOfService` is provided (default), a default QoS will be used.
  ///
  /// - Parameters:
  ///   - executableURL: URL represening path to the executable.
  ///   - arguments: The command arguments used to launch the executable.
  ///   - environment: Environment variables (defaults to current process environment).
  ///   - workDirectory: Working directory for the executable.
  ///   - qualityOfService: Quality of service level applied to the process.
  public init(
    executableURL: URL,
    arguments: [String] = [],
    environment: ShellEnvironment = .current,
    workDirectory: URL? = nil,
    qualityOfService: QualityOfService? = nil
  ) {
    self.executableURL = executableURL
    self.arguments = arguments
    self.environment = environment
    self.workDirectory = workDirectory
    self.qualityOfService = qualityOfService
  }
  
  /// URL represening path to the executable.
  public var executableURL: URL
  
  /// The command arguments used to launch the executable.
  public var arguments: [String]
  
  /// Environment variables.
  public var environment: ShellEnvironment
  
  /// Working directory for the executable. 
  ///
  /// If `nil` (default), the current working directory will be used.
  public var workDirectory: URL?
  
  /// Quality of service level applied to the process.
  ///
  /// If `nil`, a default QoS will be used.
  public var qualityOfService: QualityOfService?
}

extension ShellCommand {
  /// Create shell command representation.
  ///
  /// If `nil` `workingDirectory` is provided (default), the current working directory will be used.
  ///
  /// If `nil` `qualityOfService` is provided (default), a default QoS will be used.
  ///
  /// - Parameters:
  ///   - command: Command to execute. First element should be the path to executable. Following arguments represents  arguments passed to the executable.
  ///   - environment: Environment variables (defaults to current process environment).
  ///   - workDirectory: Working directory for the executable.
  ///   - qualityOfService: Quality of service level applied to the process.
  public init(
    _ command: String...,
    environment: ShellEnvironment = .current,
    workDirectory: String? = nil,
    qualityOfService: QualityOfService? = nil
  ) {
    self.executableURL = URL(filePath: command.first!)
    self.arguments = command.suffix(from: 1).map { $0 }
    self.environment = environment
    self.workDirectory = workDirectory.map { URL(filePath: $0) }
    self.qualityOfService = qualityOfService
  }
}
