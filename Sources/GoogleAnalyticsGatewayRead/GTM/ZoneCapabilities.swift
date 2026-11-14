import GoogleAnalyticsGatewayCore

/// Tag Manager zone reads.
enum GTMZoneCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.zones.get"),
    field: "gtmZone",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.zone), .path("path"), required: true)
    ],
    result: .single(GTMModels.zone),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Zone."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.zones.list"),
    field: "gtmZones",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/zones",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "zone", GTMModels.zone),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Zones of a GTM container workspace."
  )
}
