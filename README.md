# 🐚 Swift Shell

![Swift v5.10](https://img.shields.io/badge/swift-v5.10-orange.svg)
![platform macOS](https://img.shields.io/badge/platform-macOS-blue.svg)

Library for running shell scripts and other executables from swift code.

## 📖 Documentation

The library is distributed as a swift package.

```swift
// in your Package.swift, add package dependency:
.package(url: "https://github.com/darrarski/swift-shell.git", from: "0.1.0"),

// and add the library as a dependency to your target:
.product(name: "SwiftShell", package: "swift-shell"),
```

The code is dressed in documentation comments that explain the purpose of each variable and function. The examples described below and the library [unit tests](Tests/SwiftShellTests) explain how to use it.

### Examples

Run bash script, send input, and retrieve the script's output:

```swift
let process = ShellProcess(.bash("IFS= read -r NAME; echo Hello, $NAME!"))
try await process.run()
try await process.send(input: "Swift\n".data(using: .utf8)!)
let output = try await process.output()!
print(String(data: output, encoding: .utf8)!) // Hello, Swift!
```

#### More examples

Check out the examples included in a [separate package](Examples/) in this repository:

- [InputOutputExample](Examples/Sources/InputOutputExample/InputOutputExample.swift)

## 🛠 Development

- Use Xcode (≥15.4).
- Clone the repository or create a fork & clone it.
- Open `SwiftShell.xcworkspace` in Xcode.
- Use the `SwiftShell` scheme for building and testing the library.
- Use other schemes to build or test examples.
- If you want to contribute, create a pull request containing your changes or bug fixes. Make sure to include tests for new/updated code.

## ☕️ Do you like the project?

I would love to hear if you like my work. I can help you apply any of the solutions used in this repository in your app too! Feel free to reach out to me, or if you just want to say "thanks", you can buy me a coffee.

<a href="https://www.buymeacoffee.com/darrarski" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="60" width="217" style="height: 60px !important;width: 217px !important;" ></a>

## 📄 License

Copyright © 2024 Dariusz Rybicki Darrarski

License: [MIT](LICENSE)
