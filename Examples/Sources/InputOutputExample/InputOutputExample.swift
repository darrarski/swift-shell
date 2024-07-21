import Foundation
import SwiftShell

/// Example of running bash script that read lines from input.
///
/// Output:
/// ```
/// [00:00.000] Example started
/// [00:00.003] <stdout> script output
/// [00:00.003] <stderr> script error
/// [00:01.011] <stdout> read line: Hello, World!
/// [00:02.027] <stdout> read line: Goodbye!
/// [00:03.063] <stdout> finished reading lines
/// [00:03.130] Example finished
/// ```
@main
struct InputOutputExample {
  static func main() async throws {
    let time = Time()
    fputs("[\(time.stamp)] Example started\n", stdout)

    // Define shell command that runs provided bash script:
    let command = ShellCommand.bash(
      """
      echo "script output"
      echo "script error" 1>&2
      while IFS= read -r line; do
        echo "read line: $line"
      done < "${1:-/dev/stdin}"
      echo "finished reading lines"
      """
    )
    
    // Create task that runs the command:
    let task = ShellTask(command)

    Task {
      // Iterate over script's standard output and print it to `stdout`:
      for await data in task.outputStream() {
        fputs("[\(time.stamp)] <stdout> \(String(data: data, encoding: .utf8)!)", stdout)
      }
    }

    Task {
      // Iterate over script's standard error and print it to `stdout`:
      for await data in task.errorStream() {
        fputs("[\(time.stamp)] <stderr> \(String(data: data, encoding: .utf8)!)", stdout)
      }
    }

    // Start executing the script:
    try task.run()

    // Send input to the script over time:
    try task.send(input: "Hello".data(using: .utf8)!)
    try await Task.sleep(for: .seconds(1))
    try task.send(input: ", World!\n".data(using: .utf8)!)
    try await Task.sleep(for: .seconds(1))
    try task.send(input: "Goodbye!\n".data(using: .utf8)!)
    try await Task.sleep(for: .seconds(1))

    // Finish sending input and wait till the scripts ends:
    try task.endInput()
    try await task.waitUntilExit()

    fputs("[\(time.stamp)] Example finished\n", stdout)
  }
}

/// Utility for generating timestamps.
struct Time {
  let start = Date()

  var stamp: String {
    let interval = Date.now.timeIntervalSince(start)
    let minutes = (interval / 60).rounded(.down)
    let seconds = (interval - minutes * 60).rounded(.down)
    let milliseconds = ((interval - interval.rounded(.down)) * Double(MSEC_PER_SEC)).rounded()
    return String(format: "%02.f:%02.f.%03.f", minutes, seconds, milliseconds)
  }
}
