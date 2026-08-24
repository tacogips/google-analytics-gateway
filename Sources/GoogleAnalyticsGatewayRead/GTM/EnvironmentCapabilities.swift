import GoogleAnalyticsGatewayCore

/// Tag Manager environment reads.
enum GTMEnvironmentCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.environments.get"),
    field: "gtmEnvironment",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.environment), .path("path"), required: true)
    ],
    result: .single(GTMModels.environment),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Environment."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.environments.list"),
    field: "gtmEnvironments",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/environments",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.container), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "environment", GTMModels.environment),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Environments of a GTM Container."
  )
}
