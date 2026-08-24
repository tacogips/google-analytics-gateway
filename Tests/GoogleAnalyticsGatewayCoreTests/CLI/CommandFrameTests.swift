import Foundation
import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayTestSupport
import Testing

/// The command frame is the boundary an operator actually meets: what lands on
/// stdout, what lands on stderr, and which exit code the shell sees. The runtime
/// is injected, so none of this needs a credential or a network.
@Suite("Command frame")
struct CommandFrameTests {
  static func authCommands(
    role: RoleDescriptor = .reader,
    environment: [String: String] = [:],
    loginError: GatewayError? = nil
  ) -> AuthCommands {
    AuthCommands(
      role: role,
      auth: StubAuthManager(loginError: loginError),
      resolver: CredentialResolver(tokenStore: RecordingTokenStore()),
      environment: environment
    )
  }

  static func frame(
    role: RoleDescriptor = .reader,
    transport: RecordingTransport = RecordingTransport(),
    environment: [String: String] = [:],
    runtimeError: GatewayError? = nil,
    files: [String: String] = [:]
  ) throws -> CommandFrame {
    let registry = try SampleCapabilities.registry(tier: role.tier)
    let runtime = try SampleCapabilities.runtime(transport: transport, tier: role.tier)
    return CommandFrame(
      role: role,
      registry: registry,
      makeRuntime: { _ in
        if let runtimeError { throw runtimeError }
        return runtime
      },
      authCommands: authCommands(role: role, environment: environment),
      readFile: { path in
        guard let contents = files[path] else {
          throw GatewayError(code: .fileOperationFailed, message: "No fixture file at the supplied path.")
        }
        return Data(contents.utf8)
      }
    )
  }

  @Test("graphql schema prints the registry's SDL and exits successfully")
  func printsSchema() async throws {
    let outcome = await (try Self.frame()).run(arguments: ["graphql", "schema"])

    #expect(outcome.exitCode == .success)
    #expect(outcome.standardError.isEmpty)
    #expect(outcome.standardOutput.contains("# google-analytics-gateway reader schema"))
    #expect(outcome.standardOutput.contains("type Query {"))
    #expect(outcome.standardOutput.contains("sampleDataStreams("))
    #expect(!outcome.standardOutput.contains("type Mutation {"))
  }

  @Test("--version prints the single version constant")
  func printsVersion() async throws {
    let outcome = await (try Self.frame()).run(arguments: ["--version"])

    #expect(outcome.exitCode == .success)
    #expect(outcome.standardOutput == googleAnalyticsGatewayVersion + "\n")
  }

  @Test("--help names the tier and its operation counts")
  func printsUsage() async throws {
    let outcome = await (try Self.frame()).run(arguments: ["--help"])

    #expect(outcome.exitCode == .success)
    #expect(outcome.standardOutput.contains("Capability tier: reader"))
    #expect(outcome.standardOutput.contains("Mutation fields: none (this binary is read-only)"))
    #expect(outcome.standardOutput.contains(CredentialProfileConfiguration.pathEnvironmentVariable))
  }

  @Test("An unknown command exits with the usage code and writes nothing to stdout")
  func rejectsUnknownCommand() async throws {
    let outcome = await (try Self.frame()).run(arguments: ["explain"])

    #expect(outcome.exitCode == .usage)
    #expect(outcome.standardOutput.isEmpty)
    #expect(outcome.standardError.contains("VALIDATION_ERROR"))
    #expect(outcome.standardError.contains("Usage:"))
  }

  @Test("A forbidden override exits with the usage code")
  func rejectsForbiddenOverride() async throws {
    let outcome = await (try Self.frame()).run(arguments: ["--api-host", "analytics.example.com", "doctor"])

    #expect(outcome.exitCode == .usage)
    #expect(outcome.standardError.contains("--api-host"))
  }

  @Test("graphql query renders the response envelope on stdout")
  func runsInlineQuery() async throws {
    let transport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let outcome = await (try Self.frame(transport: transport)).run(arguments: [
      "graphql", "query",
      "{ sampleDataStream(name: \"properties/123456/dataStreams/789\") { name } }"
    ])

    #expect(outcome.exitCode == .success)
    #expect(outcome.standardError.isEmpty)
    let envelope = try JSONValue.decodeJSON(Data(outcome.standardOutput.utf8))
    #expect(envelope["data"]?["sampleDataStream"]?["name"]?.stringValue
      == "properties/123456/dataStreams/789")
    #expect(envelope["extensions"]?["requestId"]?.stringValue == fixtureRequestID)
    #expect(await transport.requestCount == 1)
  }

  @Test("graphql query-file reads the document through the injected file seam")
  func runsQueryFile() async throws {
    let transport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let frame = try Self.frame(
      transport: transport,
      files: [
        "/fixtures/query.graphql":
          "{ sampleDataStream(name: \"properties/123456/dataStreams/789\") { name } }",
        "/fixtures/variables.json": "{}"
      ]
    )

    let outcome = await frame.run(arguments: [
      "graphql", "query-file", "/fixtures/query.graphql", "--variables-file", "/fixtures/variables.json"
    ])

    #expect(outcome.exitCode == .success)
    #expect(await transport.requestCount == 1)
  }

  @Test("A missing query file is a local resource failure, not a usage error")
  func reportsMissingQueryFile() async throws {
    let outcome = await (try Self.frame()).run(arguments: [
      "graphql", "query-file", "/fixtures/absent.graphql"
    ])

    #expect(outcome.exitCode == .localResource)
    #expect(outcome.standardError.contains("FILE_OPERATION_FAILED"))
  }

  @Test("Malformed --variables JSON is a usage error before any request")
  func rejectsMalformedVariables() async throws {
    let transport = RecordingTransport()
    let outcome = await (try Self.frame(transport: transport)).run(arguments: [
      "graphql", "query", "{ sampleDataStreams(parent: \"properties/1\") { nodes { name } } }",
      "--variables", "not-json"
    ])

    #expect(outcome.exitCode == .usage)
    #expect(await transport.requestCount == 0)
  }

  @Test("A runtime that cannot be constructed answers in the GraphQL error envelope")
  func reportsRuntimeConstructionFailure() async throws {
    let frame = try Self.frame(runtimeError: GatewayError(
      code: .capabilityDenied,
      message: "Profile analytics-admin requires the admin tier.",
      requiredTier: .admin
    ))

    let outcome = await frame.run(arguments: [
      "graphql", "query", "{ sampleDataStream(name: \"properties/1/dataStreams/2\") { name } }"
    ])

    #expect(outcome.exitCode == .usage)
    #expect(outcome.standardError.isEmpty, "A structured failure belongs on stdout with the envelope")
    let envelope = try JSONValue.decodeJSON(Data(outcome.standardOutput.utf8))
    #expect(envelope["data"]?.isNull == true)
    #expect(envelope["errors"]?.arrayValue?.first?["extensions"]?["code"]?.stringValue
      == "CAPABILITY_DENIED")
    #expect(envelope["errors"]?.arrayValue?.first?["extensions"]?["requiredTier"]?.stringValue == "admin")
  }

  @Test("A GraphQL failure exit code is the highest severity among its errors")
  func mapsGraphQLFailureExitCode() async throws {
    let transport = RecordingTransport(outcomes: [
      .response(UpstreamResponse(statusCode: 404, body: Data(SampleFixtures.errorEnvelope.utf8)))
    ])
    let outcome = await (try Self.frame(transport: transport)).run(arguments: [
      "graphql", "query", "{ sampleDataStream(name: \"properties/123456/dataStreams/789\") { name } }"
    ])

    #expect(outcome.exitCode == .rejectedRequest)
    #expect(outcome.standardOutput.contains("NOT_FOUND"))
  }

  @Test("doctor reports the synthesized configuration without printing a token")
  func reportsDoctorForSynthesizedProfile() async throws {
    let frame = try Self.frame(environment: [
      ProfileSelector.fallbackAccessTokenVariable: fixtureAccessToken
    ])

    let outcome = await frame.run(arguments: ["doctor"])

    #expect(outcome.exitCode == .success)
    let envelope = try JSONValue.decodeJSON(Data(outcome.standardOutput.utf8))
    let report = try #require(envelope["data"]?.objectValue)
    #expect(report["configSource"]?.stringValue == "SYNTHESIZED_DEFAULT")
    #expect(report["tier"]?.stringValue == "reader")
    #expect(report["profileId"]?.stringValue == ProfileSelector.fallbackProfileID)
    #expect(report["accessTokenEnvironmentVariableSet"]?.boolValue == true)
    #expect(report["oauthClientConfigured"]?.boolValue == false)
    #expect(!outcome.standardOutput.contains(fixtureAccessToken))
  }

  @Test("auth status answers the presence flags and never a token value")
  func reportsAuthStatus() async throws {
    let frame = try Self.frame(environment: [
      ProfileSelector.fallbackAccessTokenVariable: fixtureAccessToken
    ])

    let outcome = await frame.run(arguments: ["auth", "status"])

    #expect(outcome.exitCode == .success)
    let envelope = try JSONValue.decodeJSON(Data(outcome.standardOutput.utf8))
    #expect(envelope["data"]?["environmentTokenAvailable"]?.boolValue == true)
    #expect(envelope["data"]?["state"]?.stringValue == "ready")
    #expect(!outcome.standardOutput.contains(fixtureAccessToken))
  }

  @Test("auth oauth2 refuses to run against the synthesized profile")
  func refusesLoginWithoutConfiguration() async throws {
    let outcome = await (try Self.frame()).run(arguments: ["auth", "oauth2"])

    #expect(outcome.exitCode == .usage)
    let envelope = try JSONValue.decodeJSON(Data(outcome.standardOutput.utf8))
    #expect(envelope["errors"]?.arrayValue?.first?["extensions"]?["code"]?.stringValue
      == "VALIDATION_ERROR")
  }
}
