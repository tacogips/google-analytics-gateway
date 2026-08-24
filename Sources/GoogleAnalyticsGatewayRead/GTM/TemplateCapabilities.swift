import GoogleAnalyticsGatewayCore

/// Tag Manager custom-template reads.
enum GTMTemplateCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.templates.get"),
    field: "gtmTemplate",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.template), .path("path"), required: true)
    ],
    result: .single(GTMModels.template),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Template."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.templates.list"),
    field: "gtmTemplates",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/templates",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "template", GTMModels.template),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Templates of a GTM container workspace."
  )
}
