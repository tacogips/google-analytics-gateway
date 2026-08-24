import Foundation

/// The shared command frame.
///
/// Each executable's entry point selects a role and delegates here, so parsing,
/// validation, output shaping, and exit-code mapping cannot drift between
/// binaries. GraphQL execution binds the credential profile parsed from the
/// command line, so the runtime is constructed per invocation by an injected
/// factory rather than once at composition.
public struct CommandFrame: Sendable {
  private let role: RoleDescriptor
  private let registry: CapabilityRegistry
  private let makeRuntime: @Sendable (CredentialSelection) throws -> GraphQLRuntime
  private let authCommands: AuthCommands
  private let readFile: @Sendable (String) throws -> Data

  public init(
    role: RoleDescriptor,
    registry: CapabilityRegistry,
    makeRuntime: @escaping @Sendable (CredentialSelection) throws -> GraphQLRuntime,
    authCommands: AuthCommands,
    readFile: @escaping @Sendable (String) throws -> Data = CommandFrame.readFileFromDisk
  ) {
    self.role = role
    self.registry = registry
    self.makeRuntime = makeRuntime
    self.authCommands = authCommands
    self.readFile = readFile
  }

  public static let readFileFromDisk: @Sendable (String) throws -> Data = { path in
    guard let data = FileManager.default.contents(atPath: path) else {
      throw GatewayError(
        code: .fileOperationFailed,
        message: "The file at the supplied path could not be read.",
        recoveryGuidance: "Check that the path names a readable file."
      )
    }
    return data
  }

  public func run(arguments: [String]) async -> CommandOutcome {
    do {
      let command = try CommandParser.parse(arguments)
      return try await execute(command)
    } catch let error as GatewayError {
      return CommandOutcome(
        standardOutput: "",
        standardError: "\(error.description)\n\(usage)\n",
        exitCode: error.exitCode
      )
    } catch {
      return CommandOutcome(
        standardOutput: "",
        standardError: "An unexpected internal failure occurred.\n",
        exitCode: .internalFailure
      )
    }
  }

  private func execute(_ command: ParsedCommand) async throws -> CommandOutcome {
    switch command {
    case .help:
      return CommandOutcome(standardOutput: usage + "\n", standardError: "", exitCode: .success)
    case .version:
      return CommandOutcome(
        standardOutput: googleAnalyticsGatewayVersion + "\n",
        standardError: "",
        exitCode: .success
      )
    case .graphQLSchema:
      return CommandOutcome(
        standardOutput: GraphQLSchemaPrinter(registry: registry).print(),
        standardError: "",
        exitCode: .success
      )
    case .graphQLQuery(let document, let variables, let selection, let pretty):
      let decoded = try Self.decodeVariables(variables, source: "--variables")
      return await runGraphQL(
        document: document, variables: decoded, selection: selection, pretty: pretty
      )
    case .graphQLQueryFile(let path, let variablesPath, let selection, let pretty):
      let documentData = try readFile(path)
      guard let document = String(data: documentData, encoding: .utf8) else {
        throw GatewayError(
          code: .fileOperationFailed,
          message: "The query file is not valid UTF-8 text."
        )
      }
      let variablesData = try variablesPath.map { try readFile($0) }
      let decoded = try Self.decodeVariables(variablesData, source: "--variables-file")
      return await runGraphQL(
        document: document, variables: decoded, selection: selection, pretty: pretty
      )
    case .authOAuth2(let selection, let noBrowser, let timeoutSeconds):
      return authCommands.login(
        selection: selection, noBrowser: noBrowser, timeoutSeconds: timeoutSeconds
      )
    case .authStatus(let selection):
      return authCommands.status(selection: selection)
    case .authLogout(let selection):
      return authCommands.logout(selection: selection)
    case .doctor(let selection):
      return authCommands.doctor(selection: selection)
    }
  }

  private func runGraphQL(
    document: String,
    variables: [String: JSONValue],
    selection: CredentialSelection,
    pretty: Bool
  ) async -> CommandOutcome {
    let runtime: GraphQLRuntime
    do {
      runtime = try makeRuntime(selection)
    } catch let error as GatewayError {
      return CommandEnvelope.failure(error, pretty: pretty)
    } catch {
      return CommandEnvelope.failure(
        .internalFailure("The gateway runtime could not be constructed."), pretty: pretty
      )
    }
    let response = await runtime.execute(document: document, variables: variables)
    return CommandOutcome(
      standardOutput: response.rendered(pretty: pretty) + "\n",
      standardError: "",
      exitCode: response.exitCode
    )
  }

  public static func decodeVariables(_ data: Data?, source: String) throws -> [String: JSONValue] {
    guard let data, !data.isEmpty else { return [:] }
    return try JSONValue.decodeJSONObject(data, context: source)
  }

  /// Help text names only the commands linked into this binary.
  public var usage: String {
    var lines = [
      "Usage: \(role.executableName) [--pretty] [--config <path>] [--profile <id>] <command>",
      "",
      "Capability tier: \(role.tier.rawValue)",
      "",
      "Commands:",
      "  graphql query '<document>' [--variables '<json-object>']",
      "  graphql query-file <path> [--variables-file <path>]",
      "  graphql schema",
      "  auth oauth2 [--no-browser] [--timeout-seconds <n>]",
      "  auth status",
      "  auth logout",
      "  doctor",
      "  --help",
      "  --version",
      "",
      "Operations:"
    ]
    lines.append("  Query fields:    \(registry.queryDefinitions.count)")
    if registry.mutationDefinitions.isEmpty {
      lines.append("  Mutation fields: none (this binary is read-only)")
    } else {
      lines.append("  Mutation fields: \(registry.mutationDefinitions.count)")
    }
    lines.append("")
    lines.append("Environment:")
    lines.append("  \(CredentialProfileConfiguration.pathEnvironmentVariable)")
    lines.append("  \(ProfileSelector.fallbackAccessTokenVariable) (used when no config is present)")
    lines.append("")
    lines.append(
      "Exit codes: 0 success, 2 usage, 3 credential, 4 rejected, 5 transient, 6 local, 70 internal"
    )
    return lines.joined(separator: "\n")
  }
}
