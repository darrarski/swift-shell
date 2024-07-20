import Foundation

/// Environment variables representation.
public struct ShellEnvironment: Sendable {
  /// Empty environment varibales.
  public static let empty = ShellEnvironment()
  
  /// Environment variables derived from current process.
  public static var current: ShellEnvironment {
    ShellEnvironment(base: { ProcessInfo.processInfo.environment })
  }

  /// Custom environment varibales.
  ///
  /// - Parameter keyValues: Variables.
  /// - Returns: Environment variables representation.
  public static func custom(_ keyValues: [String: String]) -> ShellEnvironment {
    ShellEnvironment(base: { keyValues })
  }

  var base: @Sendable () -> [String: String] = { [:] }
  var custom: [String: String?] = [:]
  var combine: @Sendable (String, String) -> String = { $1 }
  
  /// Environment variables dictionary.
  public var keyValues: [String: String] {
    var keyValues = self.base().merging(
      custom.reduce(into: [String: String]()) { $0[$1.key] = $1.value },
      uniquingKeysWith: combine
    )
    for (key, _) in custom.filter({ $0.value == nil }) {
      keyValues.removeValue(forKey: key)
    }
    return keyValues
  }

  /// Get environment value with provided name.
  public subscript(name: String) -> String? {
    keyValues[name]
  }
  
  /// Merge enironment variables with provided dictionary. 
  ///
  /// If value at given key is `nil` in the `other` dictionary, then the variable with name equal to that key will be unset.
  ///
  /// - Parameters:
  ///   - other: A dictionary to merge.
  ///   - combine: A closure that takes the current and new values for any duplicate keys. The closure returns the desired value for the final dictionary.
  /// - Returns: Modified environment variables representation.
  public func merging(
    _ other: [String: String?],
    uniquingKeysWith combine: @escaping @Sendable (String, String) -> String = { $1 }
  ) -> ShellEnvironment {
    ShellEnvironment(
      base: { keyValues },
      custom: other,
      combine: combine
    )
  }
}

extension ShellEnvironment: Equatable {
  /// Shell environments are equal when their `keyValue` dictionaries are equal.
  public static func == (lhs: ShellEnvironment, rhs: ShellEnvironment) -> Bool {
    lhs.keyValues == rhs.keyValues
  }
}
