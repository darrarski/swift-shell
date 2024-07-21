import CustomDump
import XCTest

func assertNoDifference<Value: Equatable>(
  _ actual: @autoclosure @Sendable () async -> Value,
  _ expected: Value,
  file: StaticString = #filePath,
  line: UInt = #line
) async {
  let actual = await actual()
  XCTAssertNoDifference(
    actual,
    expected,
    file: file,
    line: line
  )
}

final actor KeyedExpectations<Key: Hashable>: @unchecked Sendable {
  init(description: @escaping @Sendable (Key) -> String) {
    self.description = description
  }

  private let description: (Key) -> String
  private var expectations: [Key: XCTestExpectation] = [:]

  subscript(_ key: Key) -> XCTestExpectation {
    if let expectation = expectations[key] {
      return expectation
    } else {
      let expectation = XCTestExpectation(description: description(key))
      expectations[key] = expectation
      return expectation
    }
  }
}

func assertThrows<T>(
  _ expression: @autoclosure @Sendable () async throws -> T,
  message: String = "Expected to throw error.",
  _ errorHandler: (any Error) -> Void = { _ in },
  file: StaticString = #filePath,
  line: UInt = #line
) async {
  do {
    _ = try await expression()
    XCTFail(message, file: file, line: line)
  } catch {
    errorHandler(error)
  }
}

func assertError<T>(
  _ actual: any Error,
  _ expected: T,
  file: StaticString = #filePath,
  line: UInt = #line
) where T: Error, T: Equatable {
  guard let actual = actual as? T else {
    var actualDump = ""
    customDump(actual, to: &actualDump)
    XCTFail("Expected \(T.self), but got \(actualDump).", file: file, line: line)
    return
  }
  XCTAssertNoDifference(actual, expected, file: file, line: line)
}
