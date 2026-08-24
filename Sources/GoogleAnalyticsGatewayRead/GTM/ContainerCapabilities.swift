import GoogleAnalyticsGatewayCore

/// Tag Manager container reads, including the tagging snippet and the
/// account-wide container lookup.
enum GTMContainerCapabilities {
  static let all: [CapabilityDefinition] = [get, list, snippet, lookup]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.containers.get"),
    field: "gtmContainer",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.container), .path("path"), required: true)
    ],
    result: .single(GTMModels.container),
    scopes: .tagManagerReadonly,
    summary: "Gets a Container."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.containers.list"),
    field: "gtmContainers",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/containers",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.account), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "container", GTMModels.container),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all Containers that belongs to a GTM Account."
  )

  static let snippet = CapabilityDefinition(
    id: CapabilityID("gtm.containers.snippet"),
    field: "gtmContainerSnippet",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:snippet",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.container), .path("path"), required: true)
    ],
    result: .single(GTMModels.containerSnippet),
    scopes: .tagManagerReadonly,
    summary: "Gets the tagging snippet for a Container."
  )

  /// The lookup is addressed by tag id or destination id rather than by a
  /// container path, so it is the one container read with no path argument.
  static let lookup = CapabilityDefinition(
    id: CapabilityID("gtm.containers.lookup"),
    field: "gtmLookupContainer",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/accounts/containers:lookup",
    arguments: [
      ArgumentDefinition("tagId", .string, .query("tagId")),
      ArgumentDefinition("destinationId", .string, .query("destinationId"))
    ],
    result: .single(GTMModels.container),
    scopes: .tagManagerReadonly,
    summary: "Looks up a Container by destination ID or tag ID.",
    upstreamRejectionGuidance: "Supply exactly one of tagId or destinationId; Google resolves the "
      + "container from that identifier alone and reports an unknown identifier as a missing container."
  )
}
