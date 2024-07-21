import Foundation
import SwiftShell

/// Example of running bash script that read lines from input.
///
/// Example output:
/// ```
/// [00:00.000020981] Example started
/// [00:00.003635049] <stdout> script output
/// [00:00.003684998] <stderr> script error
/// [00:01.052050948] <stdout> read line: Hello, World!
/// [00:02.116451979] <stdout> read line: Goodbye!
/// [00:03.166569948] <stdout> finished reading lines
/// [00:03.166733027] Example finished
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
    
    // Create process that runs the command:
    let process = ShellProcess(command)

    Task {
      // Iterate over process's standard output and print it to `stdout`:
      for await data in process.outputStream() {
        fputs("[\(time.stamp)] <stdout> \(String(data: data, encoding: .utf8)!)", stdout)
      }
    }

    Task {
      // Iterate over process's standard error and print it to `stdout`:
      for await data in process.errorStream() {
        fputs("[\(time.stamp)] <stderr> \(String(data: data, encoding: .utf8)!)", stdout)
      }
    }

    // Run the process and start executing the script:
    try await process.run()

    // Send input to the script over time:
    try await process.send(input: "Hello".data(using: .utf8)!)
    try await Task.sleep(for: .seconds(1))
    try await process.send(input: ", World!\n".data(using: .utf8)!)
    try await Task.sleep(for: .seconds(1))
    try await process.send(input: "Goodbye!\n".data(using: .utf8)!)
    try await Task.sleep(for: .seconds(1))

    // Finish sending input and wait till the process ends:
    try await process.endInput()
    try await process.waitUntilExit()

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
    let nanoseconds = ((interval - interval.rounded(.down)) * Double(NSEC_PER_SEC)).rounded()
    return String(format: "%02.f:%02.f.%09.f", minutes, seconds, nanoseconds)
  }
}
