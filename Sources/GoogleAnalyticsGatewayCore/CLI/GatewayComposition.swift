import Foundation

/// Builds the production object graph for one executable role.
///
/// The composition root exposes no mock transport, fixture path, alternate
/// host, or test-mode selector. Tests build their own graph by calling the
/// individual initializers directly; nothing in this type reads a flag or an
/// undocumented environment variable to change behavior.
public enum GatewayComposition {
  /// Builds the SDK runtime from exactly the supplied environment. Unlike the
  /// command frame, this path intentionally never reads process environment.
  public static func makeRuntime(
    role: RoleDescriptor,
    definitions: [CapabilityDefinition],
    environment: [String: String]
  ) throws -> GraphQLRuntime {
    try makeComposedRuntime(
      role: role,
      definitions: definitions,
      selection: CredentialSelection(configPath: nil, profileID: nil),
      environment: environment
    )
  }

  public static func makeCommandFrame(
    role: RoleDescriptor,
    definitions: [CapabilityDefinition],
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> CommandFrame {
    let registry = try CapabilityRegistry(tier: role.tier, definitions: definitions)
    let catalog = try GoogleAnalyticsSchemaCatalogExporter.export(role: role, definitions: definitions)
    let resolver = CredentialResolver(refresher: OAuthClient())
    let authService = AuthService(resolver: resolver, supportedTier: role.tier)
    let authCommands = AuthCommands(
      role: role,
      auth: authService,
      resolver: resolver,
      environment: environment
    )
    let makeRuntime: @Sendable (CredentialSelection) throws -> GraphQLRuntime = { selection in
      try Self.makeComposedRuntime(
        role: role,
        definitions: definitions,
        selection: selection,
        environment: environment
      )
    }
    return CommandFrame(
      role: role,
      registry: registry,
      catalog: catalog,
      makeRuntime: makeRuntime,
      authCommands: authCommands
    )
  }

  private static func makeComposedRuntime(
    role: RoleDescriptor,
    definitions: [CapabilityDefinition],
    selection: CredentialSelection,
    environment: [String: String]
  ) throws -> GraphQLRuntime {
    let registry = try CapabilityRegistry(tier: role.tier, definitions: definitions)
    let resolution = try ProfileSelector.resolve(
      selection: selection, tier: role.tier, environment: environment
    )
    let provider = ProfileCredentialProvider(
      profile: resolution.profile,
      environment: environment,
      resolver: CredentialResolver(refresher: OAuthClient())
    )
    let executor = CapabilityExecutor(
      planner: CapabilityPlanner(registry: registry),
      transport: URLSessionGoogleTransport(),
      credentials: provider
    )
    return GraphQLRuntime(executor: executor)
  }

  /// Runs a role's command line and terminates with the documented exit code.
  ///
  /// Business JSON goes to stdout; usage diagnostics go to stderr.
  public static func runMain(
    role: RoleDescriptor,
    definitions: [CapabilityDefinition],
    arguments: [String] = Array(CommandLine.arguments.dropFirst()),
    environment: [String: String] = ProcessInfo.processInfo.environment,
    completion: @Sendable (Int32) -> Int32 = { $0 }
  ) async -> Never {
    let outcome: CommandOutcome
    do {
      let frame = try makeCommandFrame(role: role, definitions: definitions, environment: environment)
      outcome = await frame.run(arguments: arguments)
    } catch let error as GatewayError {
      outcome = CommandOutcome(
        standardOutput: "",
        standardError: error.description + "\n",
        exitCode: error.exitCode
      )
    } catch {
      outcome = CommandOutcome(
        standardOutput: "",
        standardError: "An unexpected internal failure occurred.\n",
        exitCode: .internalFailure
      )
    }

    if !outcome.standardOutput.isEmpty {
      FileHandle.standardOutput.write(Data(outcome.standardOutput.utf8))
    }
    if !outcome.standardError.isEmpty {
      FileHandle.standardError.write(Data(outcome.standardError.utf8))
    }
    exit(completion(outcome.exitCode.rawValue))
  }
}
