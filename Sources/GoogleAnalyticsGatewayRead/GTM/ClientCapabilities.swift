import GoogleAnalyticsGatewayCore

/// Tag Manager server-side client reads.
enum GTMClientCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.clients.get"),
    field: "gtmClient",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.client), .path("path"), required: true)
    ],
    result: .single(GTMModels.client),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Client."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.clients.list"),
    field: "gtmClients",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/clients",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "client", GTMModels.client),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Clients of a GTM container workspace."
  )
}
