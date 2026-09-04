import GatewaySDKKit

public struct GoogleAnalyticsGatewaySDK: GatewaySDK, Sendable {
  public let provider = "google-analytics-gateway"
  public let tier: String
  public let catalog: GatewaySchemaCatalog
  private let role: RoleDescriptor
  private let makeRuntime: @Sendable ([String: String]) throws -> GraphQLRuntime

  public init(role: RoleDescriptor, definitions: [CapabilityDefinition]) throws {
    try self.init(
      role: role,
      definitions: definitions,
      runtimeFactory: { environment in
        try GatewayComposition.makeRuntime(role: role, definitions: definitions, environment: environment)
      }
    )
  }

  init(
    role: RoleDescriptor,
    definitions: [CapabilityDefinition],
    runtimeFactory: @escaping @Sendable ([String: String]) throws -> GraphQLRuntime
  ) throws {
    self.role = role
    tier = role.tier.rawValue
    catalog = try GoogleAnalyticsSchemaCatalogExporter.export(role: role, definitions: definitions)
    makeRuntime = runtimeFactory
  }

  public func execute(
    document: String,
    variables: [String: GatewayJSONValue],
    environment: [String: String]
  ) async -> GatewayEnvelope {
    do {
      let runtime = try makeRuntime(environment)
      return GoogleAnalyticsJSONBridge.envelope(await runtime.execute(
        document: document, variables: variables.mapValues(GoogleAnalyticsJSONBridge.coreValue)
      ))
    } catch {
      return GoogleAnalyticsJSONBridge.failure(error)
    }
  }

  public func invoke(
    _ request: GatewayOperationRequest,
    environment: [String: String]
  ) async -> GatewayEnvelope {
    if catalog.operation(named: request.operation) == nil,
      let requiredTier = Self.knownTier(for: request.operation),
      !role.tier.includes(requiredTier) {
      return GoogleAnalyticsJSONBridge.failure(GatewayError(
        code: .capabilityDenied,
        message: "Operation \(request.operation) requires the \(requiredTier.rawValue) tier.",
        requiredTier: requiredTier
      ))
    }
    do {
      let built = try GatewayDocumentBuilder(catalog: catalog).build(request)
      return await execute(
        document: built.document, variables: built.variables, environment: environment
      )
    } catch {
      return GatewayEnvelope.failure(error, exitCode: GatewayExitCode.usage.rawValue)
    }
  }

  private static func knownTier(for field: String) -> CapabilityTier? {
    CapabilityCatalog.knownTier(field: field, isMutation: false)
      ?? CapabilityCatalog.knownTier(field: field, isMutation: true)
  }
}
