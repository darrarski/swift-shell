import AsyncAlgorithms
import Foundation
import SwiftShell

/// Example of running bash script and decorating its output with color and time prefix.
///
/// Standard output is colored in cyan, standard error in red. Timestamps are blue.
///
/// Example output (whithout colors):
/// ```
/// [00:00.008749962] Hello, World!
/// [00:01.031383991] Progress: ##########
/// [00:06.773244977] Done!
/// [00:06.773244977]
/// ```
@main
struct DecorateOutputExample {
  static func main() async throws {
    // Define shell command that runs provided bash script:
    let command = ShellCommand.bash(
      """
      echo -n "Hello"
      sleep 0.5
      echo -n ", World!"
      sleep 0.5
      echo -n "\nProgress: "
      sleep 0.5
      for ((i=1; i<=10; i++)); do
        if [[ $(expr $i % 3) -eq 0 ]]; then
          echo -n "#" 1>&2
        else
          echo -n "#"
        fi
        sleep 0.5
      done
      echo -n "\nDone! \n"
      """
    )

    // Create process that runs the command:
    let process = ShellProcess(command)

    // Asynchronously iterate over process's output, decorate it, and print to `stdout`:
    let printTaks = Task {
      let time = Time()
      let allOutput = merge(
        process.outputStream()
          .map { String(data: $0, encoding: .utf8)!.color(.cyan) },
        process.errorStream()
          .map { String(data: $0, encoding: .utf8)!.color(.red) }
      ).prefixLines(with: "[\(time.stamp)] ".color(.blue))

      for await string in allOutput {
        fputs(string, stdout)
        await Task.yield()
      }
    }

    // Run the process and start executing the script:
    try await process.run()

    // Wait till the process ends:
    try await process.waitUntilExit()

    // Wait till the print task ends:
    await printTaks.value
  }
}

/// Utility for generating timestamps.
struct Time {
  let start = Date()

  var stamp: String {
    let interval = Date.now.timeIntervalSince(start)
    let minutes = (interval / 60).rounded(.down)
    let seconds = (interval - minutes * 60).rounded(.down)
    let nanoseconds = ((interval - interval.rounded(.down)) * Double(NSEC_PER_SEC)).rounded()
    return String(format: "%02.f:%02.f.%09.f", minutes, seconds, nanoseconds)
  }
}

/// Bash color modifiers
enum BashColor: String {
  case red = "\u{001B}[1;31m"
  case blue = "\u{001B}[1;34m"
  case cyan = "\u{001B}[1;36m"
  case reset = "\u{001B}[0m"
}

extension String {
  /// Apply bash color modifiers.
  ///
  /// - Parameter color: Color modifier.
  /// - Returns: String with bash color moifiers applied.
  func color(_ color: BashColor) -> String {
    self.components(separatedBy: .newlines)
      .map { "\(color.rawValue)\($0)\(BashColor.reset.rawValue)" }
      .joined(separator: "\n")
  }
}

extension AsyncSequence where Element == String {
  /// Prefix each line in output with provided string.
  ///
  /// - Parameter prefix: Prefix string.
  /// - Returns: Stream that emits strings with prefixed lines.
  func prefixLines(
    with prefix: @escaping @autoclosure @Sendable () -> String
  ) -> AsyncStream<String> {
    var iterator = makeAsyncIterator()
    var newLine = true
    return AsyncStream {
      guard var string = try? await iterator.next() else { return nil }
      let prefix = prefix()
      if newLine { string = "\(prefix)\(string)" }
      newLine = string.firstMatch(of: /\n$/) != nil
      string.replace(/\n(.+)$/.anchorsMatchLineEndings()) { "\n\(prefix)\($0.output.1)" }
      return string
    }
  }
}
