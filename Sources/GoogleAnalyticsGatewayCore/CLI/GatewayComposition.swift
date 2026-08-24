import Foundation

/// Builds the production object graph for one executable role.
///
/// The composition root exposes no mock transport, fixture path, alternate
/// host, or test-mode selector. Tests build their own graph by calling the
/// individual initializers directly; nothing in this type reads a flag or an
/// undocumented environment variable to change behavior.
public enum GatewayComposition {
  public static func makeCommandFrame(
    role: RoleDescriptor,
    definitions: [CapabilityDefinition],
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> CommandFrame {
    let registry = try CapabilityRegistry(tier: role.tier, definitions: definitions)
    let resolver = CredentialResolver(refresher: OAuthClient())
    let authService = AuthService(resolver: resolver, supportedTier: role.tier)
    let authCommands = AuthCommands(
      role: role,
      auth: authService,
      resolver: resolver,
      environment: environment
    )
    let makeRuntime: @Sendable (CredentialSelection) throws -> GraphQLRuntime = { selection in
      let resolution = try ProfileSelector.resolve(
        selection: selection,
        tier: role.tier,
        environment: environment
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
    return CommandFrame(
      role: role,
      registry: registry,
      makeRuntime: makeRuntime,
      authCommands: authCommands
    )
  }

  /// Runs a role's command line and terminates with the documented exit code.
  ///
  /// Business JSON goes to stdout; usage diagnostics go to stderr.
  public static func runMain(
    role: RoleDescriptor,
    definitions: [CapabilityDefinition]
  ) async -> Never {
    let arguments = Array(CommandLine.arguments.dropFirst())
    let outcome: CommandOutcome
    do {
      let frame = try makeCommandFrame(role: role, definitions: definitions)
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
    exit(outcome.exitCode.rawValue)
  }
}
