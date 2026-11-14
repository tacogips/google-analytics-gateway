import GoogleAnalyticsGatewayCore

/// Tag Manager tag reads.
enum GTMTagCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.tags.get"),
    field: "gtmTag",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.tag), .path("path"), required: true)
    ],
    result: .single(GTMModels.tag),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Tag."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.tags.list"),
    field: "gtmTags",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/tags",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "tag", GTMModels.tag),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Tags of a Container."
  )
}
