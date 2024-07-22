import Foundation
import SwiftShell

/// Example of running bash script that read lines from input.
///
/// Example output:
/// ```
/// <stdout> script output
/// <stderr> script error
/// <stdout> read line: Hello, World!
/// <stdout> read line: Goodbye!
/// <stdout> finished reading lines
/// ```
@main
struct InputOutputExample {
  static func main() async throws {
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

    let stdoutPrintTask = Task {
      // Iterate over process's standard output and print it to `stdout`:
      for await data in process.outputStream() {
        fputs("<stdout> " + String(data: data, encoding: .utf8)!, stdout)
      }
    }

    let stderrPrintTask = Task {
      // Iterate over process's standard error and print it to `stdout`:
      for await data in process.errorStream() {
        fputs("<stderr> " + String(data: data, encoding: .utf8)!, stdout)
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

    // Wait till print tasks ends:
    await stdoutPrintTask.value
    await stderrPrintTask.value
  }
}
