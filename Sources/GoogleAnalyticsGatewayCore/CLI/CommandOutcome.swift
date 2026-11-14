import Foundation

/// The captured result of running a command.
public struct CommandOutcome: Sendable, Equatable {
  public let standardOutput: String
  public let standardError: String
  public let exitCode: GatewayExitCode

  public init(standardOutput: String, standardError: String, exitCode: GatewayExitCode) {
    self.standardOutput = standardOutput
    self.standardError = standardError
    self.exitCode = exitCode
  }
}

/// The identity of the running executable.
public struct RoleDescriptor: Sendable {
  public let executableName: String
  public let tier: CapabilityTier

  public init(executableName: String, tier: CapabilityTier) {
    self.executableName = executableName
    self.tier = tier
  }

  public static let reader = RoleDescriptor(
    executableName: "google-analytics-gateway-reader", tier: .reader
  )
  public static let writer = RoleDescriptor(
    executableName: "google-analytics-gateway-writer", tier: .writer
  )
  public static let admin = RoleDescriptor(
    executableName: "google-analytics-gateway-admin", tier: .admin
  )
}

/// JSON envelope helpers shared by non-GraphQL commands (`auth`, `doctor`) so
/// their stdout matches the GraphQL contract's data/errors shape.
enum CommandEnvelope {
  static func success(_ value: JSONValue, pretty: Bool = false) -> CommandOutcome {
    let envelope = JSONValue.object(["data": value])
    return CommandOutcome(
      standardOutput: envelope.encodedJSON(pretty: pretty) + "\n",
      standardError: "",
      exitCode: .success
    )
  }

  static func failure(_ error: GatewayError, pretty: Bool = false) -> CommandOutcome {
    let envelope = JSONValue.object([
      "data": .null,
      "errors": .array([.object([
        "message": .string(error.message),
        "extensions": error.extensions
      ])])
    ])
    return CommandOutcome(
      standardOutput: envelope.encodedJSON(pretty: pretty) + "\n",
      standardError: "",
      exitCode: error.exitCode
    )
  }
}
