import GoogleAnalyticsGatewayCore

/// Tag Manager trigger reads.
enum GTMTriggerCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.triggers.get"),
    field: "gtmTrigger",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.trigger), .path("path"), required: true)
    ],
    result: .single(GTMModels.trigger),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Trigger."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.triggers.list"),
    field: "gtmTriggers",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/triggers",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "trigger", GTMModels.trigger),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Triggers of a Container."
  )
}
