import Foundation

extension ShellCommand {
  /// Creates shell command that executes provided Bash script.
  ///
  /// If `nil` `workingDirectory` is provided (default), the current working directory will be used.
  ///
  /// If `nil` `qualityOfService` is provided (default), a default QoS will be used.
  ///
  /// - Parameters:
  ///   - script: Bash script.
  ///   - environment: Environment variables (defaults to current process environment).
  ///   - workingDirectory: Working directory for the executable.
  ///   - qualityOfService: Quality of service level applied to the process.
  /// - Returns: Shell command representation.
  public static func bash(
    _ script: String,
    environment: ShellEnvironment = .current,
    workingDirectory: URL? = nil,
    qualityOfService: QualityOfService? = nil
  ) -> ShellCommand {
    ShellCommand(
      executableURL: URL(filePath: "/usr/bin/env"),
      arguments: ["bash", "-c", script],
      environment: environment,
      workingDirectory: workingDirectory,
      qualityOfService: qualityOfService
    )
  }
}
