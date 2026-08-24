import GoogleAnalyticsGatewayCore

/// Google tag configuration reads. Tag Manager carries the Google tag settings
/// as a workspace resource, which is the surface that stands in for a
/// standalone gtag API.
enum GTMGtagConfigCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.gtagConfig.get"),
    field: "gtmGtagConfig",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.gtagConfig), .path("path"), required: true)
    ],
    result: .single(GTMModels.gtagConfig),
    scopes: .tagManagerReadonly,
    summary: "Gets a Google tag config."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.gtagConfig.list"),
    field: "gtmGtagConfigs",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/gtag_config",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "gtagConfig", GTMModels.gtagConfig),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all Google tag configs in a Container."
  )
}
