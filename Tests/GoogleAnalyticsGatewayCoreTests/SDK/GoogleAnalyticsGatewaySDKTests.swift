import GatewaySDKKit
import GoogleAnalyticsGatewayAdmin
@testable import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayTestSupport
import GoogleAnalyticsGatewayWrite
import Testing

@Suite("Google Analytics Gateway SDK")
struct GoogleAnalyticsGatewaySDKTests {
  private final class EnvironmentRecorder: @unchecked Sendable {
    private var values: [[String: String]] = []

    func append(_ environment: [String: String]) { values.append(environment) }
    var latest: [String: String]? { values.last }
  }

  private final class FactoryRecorder: @unchecked Sendable {
    private var calls = 0

    func record() { calls += 1 }
    var callCount: Int { calls }
  }

  private struct UnexpectedFactoryError: Error {}

  private static func runtime(
    role: RoleDescriptor,
    definitions: [CapabilityDefinition],
    transport: RecordingTransport,
    credentials: any CredentialProvider = RecordingCredentialProvider()
  ) throws -> GraphQLRuntime {
    let registry = try CapabilityRegistry(tier: role.tier, definitions: definitions)
    let executor = CapabilityExecutor(
      planner: CapabilityPlanner(registry: registry),
      transport: transport,
      credentials: credentials,
      requestIDFactory: { fixtureRequestID }
    )
    return GraphQLRuntime(executor: executor, requestIDFactory: { fixtureRequestID })
  }

  private static func schemaTypeNames(_ schema: String) -> Set<String> {
    Set(schema.split(separator: "\n").compactMap { line in
      let parts = line.split(separator: " ")
      guard parts.count >= 2, ["type", "input", "enum"].contains(String(parts[0])) else {
        return nil
      }
      return String(parts[1].prefix { $0 != "{" })
    })
  }

  private static func rootFieldNames(_ schema: String, root: String) -> Set<String> {
    guard let start = schema.range(of: "type \(root) {") else { return [] }
    var names: Set<String> = []
    for line in schema[start.upperBound...].split(separator: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed == "}" { break }
      guard let first = trimmed.first, first.isLowercase, !trimmed.hasPrefix("\"") else { continue }
      let name = trimmed.prefix { $0 != "(" && $0 != ":" }
      if !name.isEmpty { names.insert(String(name)) }
    }
    return names
  }

  private static func fieldSignatures(_ schema: String, typeName: String) -> [String: String] {
    let headers = ["type \(typeName) {", "input \(typeName) {"]
    guard let header = headers.first(where: { schema.range(of: $0) != nil }),
          let start = schema.range(of: header) else { return [:] }
    var signatures: [String: String] = [:]
    for line in schema[start.upperBound...].split(separator: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed == "}" { break }
      guard let colon = trimmed.lastIndex(of: ":"), !trimmed.hasPrefix("\"") else { continue }
      let field = trimmed[..<colon].prefix { $0 != "(" }.trimmingCharacters(in: .whitespaces)
      let type = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespaces)
      if !field.isEmpty, !type.isEmpty { signatures[String(field)] = type }
    }
    return signatures
  }

  private static func catalogFieldSignatures(_ type: GatewayNamedType) -> [String: String] {
    if let fields = type.objectFields {
      return Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.type.graphQLString) })
    }
    if let fields = type.inputFields {
      return Dictionary(uniqueKeysWithValues: fields.map { ($0.name, $0.type.graphQLString) })
    }
    return [:]
  }

  @Test("Tier constructors export valid cumulative catalogs")
  func exportsTierSafeCatalogs() throws {
    let reader = try GoogleAnalyticsGatewaySDK.reader()
    let writer = try GoogleAnalyticsGatewaySDK.writer()
    let admin = try GoogleAnalyticsGatewaySDK.admin()

    #expect(reader.catalog.validate().isEmpty)
    #expect(writer.catalog.validate().isEmpty)
    #expect(admin.catalog.validate().isEmpty)
    #expect(reader.catalog.operations.allSatisfy { $0.tier == "reader" })
    #expect(Set(reader.catalog.operations.map(\.name)).isSubset(of: Set(writer.catalog.operations.map(\.name))))
    #expect(Set(writer.catalog.operations.map(\.name)).isSubset(of: Set(admin.catalog.operations.map(\.name))))
  }

  @Test("Tier convenience constructors exactly export their cumulative definitions")
  func convenienceConstructorsMatchTheirCatalogsExactly() throws {
    let cases: [(GoogleAnalyticsGatewaySDK, [CapabilityDefinition])] = [
      (try .reader(), ReadCapabilities.all),
      (try .writer(), WriteCapabilities.cumulative),
      (try .admin(), AdminCapabilities.cumulative)
    ]

    for (sdk, definitions) in cases {
      let expectedQueries = Set(definitions.filter { !$0.operationClass.isMutation }.map(\.field))
      let expectedMutations = Set(definitions.filter { $0.operationClass.isMutation }.map(\.field))
      #expect(Set(sdk.catalog.operations(of: .query).map(\.name)) == expectedQueries)
      #expect(Set(sdk.catalog.operations(of: .mutation).map(\.name)) == expectedMutations)
    }
  }

  @Test("Tier catalogs exactly match their registries and runtime schemas")
  func matchesExactTierCatalogsAndSchemas() throws {
    let tiers: [(RoleDescriptor, [CapabilityDefinition])] = [
      (.reader, ReadCapabilities.all),
      (.writer, WriteCapabilities.cumulative),
      (.admin, AdminCapabilities.cumulative)
    ]

    for (role, definitions) in tiers {
      let sdk = try GoogleAnalyticsGatewaySDK(role: role, definitions: definitions)
      let registry = try CapabilityRegistry(tier: role.tier, definitions: definitions)
      let schema = GraphQLSchemaPrinter(registry: registry).print()
      let expectedQueries = Set(registry.queryDefinitions.map(\.field))
      let expectedMutations = Set(registry.mutationDefinitions.map(\.field))
      let catalogQueries = Set(sdk.catalog.operations(of: .query).map(\.name))
      let catalogMutations = Set(sdk.catalog.operations(of: .mutation).map(\.name))

      #expect(catalogQueries == expectedQueries, "\(role.tier.rawValue) queries")
      #expect(catalogMutations == expectedMutations, "\(role.tier.rawValue) mutations")
      #expect(Self.rootFieldNames(schema, root: "Query") == catalogQueries)
      #expect(Self.rootFieldNames(schema, root: "Mutation") == catalogMutations)
      #expect(
        Self.schemaTypeNames(schema).subtracting(["Query", "Mutation"])
          == Set(sdk.catalog.types.map(\.name)),
        "\(role.tier.rawValue) named types"
      )
    }
  }

  @Test("Catalog object and input field signatures exactly match runtime SDL")
  func catalogFieldSignaturesMatchRuntimeSchemas() throws {
    let tiers: [(RoleDescriptor, [CapabilityDefinition])] = [
      (.reader, ReadCapabilities.all),
      (.writer, WriteCapabilities.cumulative),
      (.admin, AdminCapabilities.cumulative)
    ]

    for (role, definitions) in tiers {
      let catalog = try GoogleAnalyticsSchemaCatalogExporter.export(role: role, definitions: definitions)
      let registry = try CapabilityRegistry(tier: role.tier, definitions: definitions)
      let runtimeSDL = GraphQLSchemaPrinter(registry: registry).print()
      for type in catalog.types where type.objectFields != nil || type.inputFields != nil {
        #expect(
          Self.catalogFieldSignatures(type) == Self.fieldSignatures(runtimeSDL, typeName: type.name),
          "\(role.tier.rawValue) \(type.name)"
        )
      }
    }
  }

  @Test("Known higher tier named operations fail before runtime construction")
  func deniesKnownHigherTierOperation() async throws {
    let reader = try GoogleAnalyticsGatewaySDK.reader()
    let envelope = await reader.invoke(
      GatewayOperationRequest(operation: "gaCreateDataStream"), environment: [:]
    )
    #expect(envelope.exitCode == GatewayExitCode.usage.rawValue)
    #expect(envelope.errors.first?.code == GatewayErrorCode.capabilityDenied.rawValue)
  }

  @Test("Named higher-tier denial does not construct a runtime or resolve credentials")
  func namedHigherTierDenialHasNoSideEffects() async throws {
    let factory = FactoryRecorder()
    let transport = RecordingTransport()
    let credentials = RecordingCredentialProvider()
    let sdk = try GoogleAnalyticsGatewaySDK(
      role: .reader,
      definitions: ReadCapabilities.all,
      runtimeFactory: { _ in
        factory.record()
        return try Self.runtime(
          role: .reader,
          definitions: ReadCapabilities.all,
          transport: transport,
          credentials: credentials
        )
      }
    )

    let envelope = await sdk.invoke(GatewayOperationRequest(operation: "gtmUserPermission"), environment: [:])
    #expect(envelope.exitCode == GatewayExitCode.usage.rawValue)
    #expect(envelope.errors.first?.code == GatewayErrorCode.capabilityDenied.rawValue)
    #expect(factory.callCount == 0)
    #expect(credentials.resolutionCount == 0)
    #expect(await transport.requestCount == 0)
  }

  @Test("Known and unexpected runtime factory failures stay stable")
  func mapsRuntimeFactoryFailures() async throws {
    let known = try GoogleAnalyticsGatewaySDK(
      role: .reader,
      definitions: ReadCapabilities.all,
      runtimeFactory: { _ in throw GatewayError.authentication("Credential selection failed.") }
    )
    let knownEnvelope = await known.execute(document: "query { gaDataStream { name } }", variables: [:], environment: [:])
    #expect(knownEnvelope.exitCode == GatewayExitCode.credential.rawValue)
    #expect(knownEnvelope.errors.first?.code == GatewayErrorCode.authenticationFailed.rawValue)

    let unexpected = try GoogleAnalyticsGatewaySDK(
      role: .reader,
      definitions: ReadCapabilities.all,
      runtimeFactory: { _ in throw UnexpectedFactoryError() }
    )
    let unexpectedEnvelope = await unexpected.execute(
      document: "query { gaDataStream { name } }", variables: [:], environment: [:]
    )
    #expect(unexpectedEnvelope.exitCode == GatewayExitCode.internalFailure.rawValue)
    #expect(unexpectedEnvelope.errors.first?.code == GatewayErrorCode.internalError.rawValue)
    #expect(unexpectedEnvelope.errors.first?.message == "The gateway runtime could not be constructed.")
  }

  @Test("SDK runtime factory receives only the caller environment")
  func passesExactEnvironmentToRuntimeFactory() async throws {
    let recorder = EnvironmentRecorder()
    let runtime = try SampleCapabilities.runtime(transport: RecordingTransport(), tier: .reader)
    let sdk = try GoogleAnalyticsGatewaySDK(
      role: .reader,
      definitions: ReadCapabilities.all,
      runtimeFactory: { environment in
        recorder.append(environment)
        return runtime
      }
    )
    _ = await sdk.execute(document: "query { nope }", variables: [:], environment: ["SDK_TEST": "only-this"])
    #expect(recorder.latest == ["SDK_TEST": "only-this"])
  }

  @Test("SDK invokes representative reader writer and admin operations")
  func invokesAuthorizedOperationsThroughRecordingTransport() async throws {
    let readerTransport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let readerCredentials = RecordingCredentialProvider()
    let readerDefinitions = ReadCapabilities.all
    let readerRuntime = try Self.runtime(
      role: .reader, definitions: readerDefinitions, transport: readerTransport, credentials: readerCredentials
    )
    let reader = try GoogleAnalyticsGatewaySDK(
      role: .reader, definitions: readerDefinitions, runtimeFactory: { _ in readerRuntime }
    )
    let readerEnvelope = await reader.invoke(GatewayOperationRequest(
      operation: "gaDataStream",
      variables: ["name": .string("properties/123456/dataStreams/789")],
      selection: .fields(["name"])
    ), environment: [:])
    #expect(readerEnvelope.exitCode == GatewayExitCode.success.rawValue)
    #expect(readerEnvelope.requestId == fixtureRequestID)
    #expect(readerEnvelope.rawOutput.contains("\"gaDataStream\":{\"name\":"))
    let readerRequest = try await readerTransport.firstRequest()
    #expect(readerRequest.method == .get)
    #expect(readerRequest.url.absoluteString == "https://analyticsadmin.googleapis.com/v1beta/properties/123456/dataStreams/789")
    #expect(readerRequest.path == "/v1beta/properties/123456/dataStreams/789")
    #expect(readerRequest.queryItems.isEmpty)
    #expect(readerRequest.capabilityID == CapabilityID("ga.dataStreams.get"))
    #expect(readerRequest.requestID == fixtureRequestID)
    #expect(readerRequest.hasAuthorization)
    #expect(!readerRequest.headerNames.contains("Authorization"))
    #expect(readerCredentials.resolutionCount == 1)

    let writerTransport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let writerCredentials = RecordingCredentialProvider()
    let writerDefinitions = WriteCapabilities.cumulative
    let writerRuntime = try Self.runtime(
      role: .writer, definitions: writerDefinitions, transport: writerTransport, credentials: writerCredentials
    )
    let writer = try GoogleAnalyticsGatewaySDK(
      role: .writer, definitions: writerDefinitions, runtimeFactory: { _ in writerRuntime }
    )
    let writerEnvelope = await writer.invoke(GatewayOperationRequest(
      operation: "gaCreateDataStream",
      variables: [
        "parent": .string("properties/123456"),
        "dataStream": .object(["type": .string("WEB_DATA_STREAM")])
      ],
      selection: .fields(["dataStream.name"])
    ), environment: [:])
    #expect(writerEnvelope.exitCode == GatewayExitCode.success.rawValue)
    #expect(writerEnvelope.rawOutput.contains("\"dataStream\":{\"name\":"))
    let writerRequest = try await writerTransport.firstRequest()
    #expect(writerRequest.method == .post)
    #expect(writerRequest.url.absoluteString == "https://analyticsadmin.googleapis.com/v1beta/properties/123456/dataStreams")
    #expect(writerRequest.path == "/v1beta/properties/123456/dataStreams")
    #expect(writerRequest.queryItems.isEmpty)
    #expect(writerRequest.capabilityID == CapabilityID("ga.dataStreams.create"))
    #expect(writerRequest.requestID == fixtureRequestID)
    #expect(writerRequest.bodyDescription == "json:{\"type\":\"WEB_DATA_STREAM\"}")
    #expect(writerRequest.hasAuthorization)
    #expect(writerCredentials.resolutionCount == 1)

    let adminTransport = RecordingTransport.succeeding(json: "{}")
    let adminCredentials = RecordingCredentialProvider()
    let adminDefinitions = AdminCapabilities.cumulative
    let adminRuntime = try Self.runtime(
      role: .admin, definitions: adminDefinitions, transport: adminTransport, credentials: adminCredentials
    )
    let admin = try GoogleAnalyticsGatewaySDK(
      role: .admin, definitions: adminDefinitions, runtimeFactory: { _ in adminRuntime }
    )
    let name = "properties/123456/dataStreams/789"
    let adminEnvelope = await admin.invoke(GatewayOperationRequest(
      operation: "gaDeleteDataStream",
      variables: ["name": .string(name), "confirmName": .string(name)]
    ), environment: [:])
    #expect(adminEnvelope.exitCode == GatewayExitCode.success.rawValue)
    #expect(adminEnvelope.rawOutput.contains("\"deletedName\":\"\(name)\""))
    let adminRequest = try await adminTransport.firstRequest()
    #expect(adminRequest.method == .delete)
    #expect(adminRequest.url.absoluteString == "https://analyticsadmin.googleapis.com/v1beta/properties/123456/dataStreams/789")
    #expect(adminRequest.path == "/v1beta/properties/123456/dataStreams/789")
    #expect(adminRequest.queryItems.isEmpty)
    #expect(adminRequest.capabilityID == CapabilityID("ga.dataStreams.delete"))
    #expect(adminRequest.requestID == fixtureRequestID)
    #expect(adminRequest.bodyDescription == "none")
    #expect(adminRequest.hasAuthorization)
    #expect(adminCredentials.resolutionCount == 1)
  }

  @Test("Raw SDK execution denies known writer operations before credentials and transport")
  func rawExecutionDeniesAboveTierBeforeSideEffects() async throws {
    let transport = RecordingTransport()
    let credentials = RecordingCredentialProvider()
    let runtime = try Self.runtime(
      role: .reader, definitions: ReadCapabilities.all, transport: transport, credentials: credentials
    )
    let reader = try GoogleAnalyticsGatewaySDK(
      role: .reader, definitions: ReadCapabilities.all, runtimeFactory: { _ in runtime }
    )

    let envelope = await reader.execute(
      document: "mutation { gaCreateDataStream { dataStream { name } } }",
      variables: [:],
      environment: [:]
    )
    #expect(envelope.exitCode == GatewayExitCode.usage.rawValue)
    #expect(envelope.errors.first?.code == GatewayErrorCode.capabilityDenied.rawValue)
    #expect(credentials.resolutionCount == 0)
    #expect(await transport.requestCount == 0)
  }

  @Test("Raw SDK execution matches graphql query under fixed seams")
  func rawExecutionMatchesCommandFrame() async throws {
    let document = "query { gaDataStream(name: \"properties/123456/dataStreams/789\") { name } }"
    let sdkTransport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let sdkRuntime = try Self.runtime(
      role: .reader, definitions: ReadCapabilities.all, transport: sdkTransport
    )
    let sdk = try GoogleAnalyticsGatewaySDK(
      role: .reader, definitions: ReadCapabilities.all, runtimeFactory: { _ in sdkRuntime }
    )
    let envelope = await sdk.execute(document: document, variables: [:], environment: [:])

    let cliTransport = RecordingTransport.succeeding(json: SampleFixtures.dataStream)
    let cliRuntime = try Self.runtime(
      role: .reader, definitions: ReadCapabilities.all, transport: cliTransport
    )
    let registry = try CapabilityRegistry(tier: .reader, definitions: ReadCapabilities.all)
    let frame = CommandFrame(
      role: .reader,
      registry: registry,
      catalog: try GoogleAnalyticsSchemaCatalogExporter.export(role: .reader, definitions: ReadCapabilities.all),
      makeRuntime: { _ in cliRuntime },
      authCommands: AuthCommands(
        role: .reader,
        auth: StubAuthManager(),
        resolver: CredentialResolver(tokenStore: RecordingTokenStore()),
        environment: [:]
      )
    )
    let outcome = await frame.run(arguments: ["graphql", "query", document])
    #expect(outcome.exitCode == .success)
    #expect(envelope.rawOutput == outcome.standardOutput.trimmingCharacters(in: .newlines))
    #expect(envelope.requestId == fixtureRequestID)
    #expect(await sdkTransport.requestCount == 1)
    #expect(await cliTransport.requestCount == 1)
  }

  @Test("Exporter preserves catalog metadata and deterministic ordering")
  func exportsCatalogMetadata() throws {
    let first = try GoogleAnalyticsSchemaCatalogExporter.export(role: .reader, definitions: ReadCapabilities.all)
    let second = try GoogleAnalyticsSchemaCatalogExporter.export(role: .reader, definitions: ReadCapabilities.all)
    #expect(first == second)
    #expect(first.namedType("PageInfo") != nil)
    #expect(first.operations.allSatisfy { $0.domain == "ga" || $0.domain == "gtm" })
    #expect(first.operations == first.operations.sorted { lhs, rhs in
      if lhs.kind != rhs.kind { return lhs.kind == .query }
      return lhs.name < rhs.name
    })
    let name = try #require(first.operation(named: "gaDataStream")?.arguments.first { $0.name == "name" })
    #expect(name.type == .nonNull(.named("ID")))
    #expect(name.description?.contains("properties/{property}/dataStreams/{dataStream}") == true)

    let registry = try CapabilityRegistry(tier: .reader, definitions: ReadCapabilities.all)
    let runtimeSDL = GraphQLSchemaPrinter(registry: registry).print()
    #expect(first.operations.allSatisfy { runtimeSDL.contains("  \($0.name)") })
    #expect(first.types.allSatisfy { type in
      runtimeSDL.contains("type \(type.name) ")
        || runtimeSDL.contains("input \(type.name) ")
        || runtimeSDL.contains("enum \(type.name) ")
    })
  }

  @Test("Exporter maps every structural result and input shape deterministically")
  func exportsStructuralCatalogShapes() throws {
    func published(_ source: CapabilityDefinition, id: String, field: String) -> CapabilityDefinition {
      CapabilityDefinition(
        id: CapabilityID(id), field: field, tier: source.tier,
        operationClass: source.operationClass, method: source.method, service: source.service,
        pathTemplate: source.pathTemplate, arguments: source.arguments, result: source.result,
        deletionConfirmation: source.deletionConfirmation, scopes: source.scopes,
        maximumPageSize: source.maximumPageSize, status: source.status, summary: source.summary,
        upstreamRejectionGuidance: source.upstreamRejectionGuidance
      )
    }
    let source = SampleCapabilities.getDataStream
    let download = CapabilityDefinition(
      id: CapabilityID("ga.fixture.download"),
      field: "gaDownloadFixture",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: source.service,
      pathTemplate: source.pathTemplate,
      arguments: [
        source.arguments[0],
        ArgumentDefinition("destination", .string, .destinationPath, required: true)
      ],
      result: .fileOutput(FileOutputShape.shape),
      scopes: source.scopes,
      summary: "Downloads a fixture."
    )
    let catalog = try GoogleAnalyticsSchemaCatalogExporter.export(
      role: .admin,
      definitions: [
        published(SampleCapabilities.listDataStreams, id: "ga.sample.list", field: "gaSampleDataStreams"),
        published(SampleCapabilities.getDataStream, id: "ga.sample.get", field: "gaSampleDataStream"),
        published(SampleCapabilities.createDataStream, id: "ga.sample.create", field: "gaSampleCreateDataStream"),
        published(SampleCapabilities.deleteDataStream, id: "ga.sample.delete", field: "gaSampleDeleteDataStream"),
        download
      ]
    )
    let expectedResults: [(String, GatewayTypeRef)] = [
      ("gaSampleDataStreams", .named("SampleDataStreamConnection")),
      ("gaSampleDataStream", .named("SampleDataStream")),
      ("gaSampleCreateDataStream", .named("SampleDataStreamPayload")),
      ("gaSampleDeleteDataStream", .named("DeletionPayload")),
      ("gaDownloadFixture", .nonNull(.named("DownloadedFile")))
    ]
    for (operationName, result) in expectedResults {
      #expect(catalog.operation(named: operationName)?.result == result)
    }

    let operation = try #require(catalog.operation(named: "gaDownloadFixture"))
    #expect(operation.result == .nonNull(.named("DownloadedFile")))
    let output = try #require(catalog.namedType("DownloadedFile")?.objectFields)
    #expect(output == [
      GatewayField(name: "byteCount", type: .nonNull(.named("Int"))),
      GatewayField(name: "contentType", type: .named("String")),
      GatewayField(name: "path", type: .nonNull(.named("String")))
    ])
    #expect(catalog.namedType("SampleDataStreamConnection")?.objectFields == [
      GatewayField(name: "nodes", type: .nonNull(.list(.nonNull(.named("SampleDataStream"))))),
      GatewayField(name: "pageInfo", type: .nonNull(.named("PageInfo")))
    ])
    #expect(catalog.namedType("SampleDataStreamPayload")?.objectFields == [
      GatewayField(name: "dataStream", type: .nonNull(.named("SampleDataStream")))
    ])
    #expect(catalog.namedType("DeletionPayload")?.objectFields == [
      GatewayField(name: "deletedName", type: .nonNull(.named("String")))
    ])
    #expect(catalog.namedType("PageInput")?.inputFields == [
      GatewayArgument(name: "nextPageToken", type: .named("String")),
      GatewayArgument(name: "pageSize", type: .named("Int"))
    ])
    #expect(catalog.namedType("SampleDataStreamInput")?.inputFields == [
      GatewayArgument(name: "displayName", type: .nonNull(.named("String")), isRequired: true),
      GatewayArgument(name: "streamKind", type: .nonNull(.named("SampleStreamKind")), isRequired: true),
      GatewayArgument(name: "webStreamData", type: .named("SampleWebStreamDataInput"))
    ])
    #expect(catalog.namedType("SampleStreamKind")?.enumValues == ["IOS_APP_DATA_STREAM", "WEB_DATA_STREAM"])
    #expect(catalog.namedType("SampleDataStream")?.objectFields == [
      GatewayField(name: "createTime", type: .named("String")),
      GatewayField(name: "displayName", type: .named("String")),
      GatewayField(name: "name", type: .nonNull(.named("String"))),
      GatewayField(name: "streamKind", type: .named("String")),
      GatewayField(name: "webStreamData", type: .named("SampleWebStreamData"))
    ])
  }

  @Test("Exporter fails atomically for unsupported prefixes and type collisions")
  func rejectsInvalidCatalogDefinitions() {
    let source = SampleCapabilities.getDataStream
    let invalidPrefix = CapabilityDefinition(
      id: CapabilityID("other.get"), field: "otherGet", tier: .reader,
      operationClass: source.operationClass, method: source.method, service: source.service,
      pathTemplate: source.pathTemplate, arguments: source.arguments, result: source.result,
      deletionConfirmation: source.deletionConfirmation, scopes: source.scopes,
      maximumPageSize: source.maximumPageSize, status: source.status, summary: source.summary,
      upstreamRejectionGuidance: source.upstreamRejectionGuidance
    )
    #expect(throws: GatewayError.self) {
      try GoogleAnalyticsSchemaCatalogExporter.export(role: .reader, definitions: [invalidPrefix])
    }

    let conflictingShape = ModelShape(
      typeName: SampleCapabilities.dataStream.typeName,
      fields: [ModelField("different", .string)]
    )
    let collision = CapabilityDefinition(
      id: CapabilityID("gtm.collision.get"), field: "gtmCollision", tier: .reader,
      operationClass: source.operationClass, method: source.method, service: source.service,
      pathTemplate: source.pathTemplate, arguments: source.arguments, result: .single(conflictingShape),
      deletionConfirmation: source.deletionConfirmation, scopes: source.scopes,
      maximumPageSize: source.maximumPageSize, status: source.status, summary: source.summary,
      upstreamRejectionGuidance: source.upstreamRejectionGuidance
    )
    #expect(throws: GatewayError.self) {
      try GoogleAnalyticsSchemaCatalogExporter.export(
        role: .reader, definitions: [SampleCapabilities.getDataStream, collision]
      )
    }
  }

  @Test("JSON bridge preserves integer and floating point identity")
  func bridgesJSONAndResponseEnvelope() {
    let original = SampleJSONCapabilities.arbitraryDocument
    #expect(GoogleAnalyticsJSONBridge.coreValue(GoogleAnalyticsJSONBridge.gatewayValue(original)) == original)
    let response = GraphQLResponse(
      data: original,
      errors: [GatewayError.validation("Invalid input.")],
      requestID: "request-1"
    )
    let envelope = GoogleAnalyticsJSONBridge.envelope(response)
    #expect(envelope.data == GoogleAnalyticsJSONBridge.gatewayValue(original))
    #expect(envelope.errors.first?.code == GatewayErrorCode.validationError.rawValue)
    #expect(envelope.requestId == "request-1")
    #expect(envelope.rawOutput == response.rendered(pretty: false))
  }
}
