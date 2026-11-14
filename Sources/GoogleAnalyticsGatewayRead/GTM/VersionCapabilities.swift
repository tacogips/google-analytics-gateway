import GoogleAnalyticsGatewayCore

/// Tag Manager container version reads, plus the version-header listing Google
/// exposes as a separate collection.
enum GTMVersionCapabilities {
  static let all: [CapabilityDefinition] = [get, live, headerList, latestHeader]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.versions.get"),
    field: "gtmVersion",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition(
        "path",
        .resourceName(GTMResourceNames.containerVersion),
        .path("path"),
        required: true
      ),
      ArgumentDefinition("containerVersionId", .string, .query("containerVersionId"))
    ],
    result: .single(GTMModels.containerVersion),
    scopes: .tagManagerReadonly,
    summary: "Gets a Container Version."
  )

  static let live = CapabilityDefinition(
    id: CapabilityID("gtm.versions.live"),
    field: "gtmLiveVersion",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/versions:live",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.container), .path("parent"), required: true)
    ],
    result: .single(GTMModels.containerVersion),
    scopes: .tagManagerReadonly,
    summary: "Gets the live (i.e. published) container version.",
    upstreamRejectionGuidance: "A container with no published version has no live version, which "
      + "Google reports as a missing resource rather than an empty result."
  )

  /// Google answers the version-header list with `ListContainerVersionsResponse`,
  /// whose entries are headers rather than whole versions.
  static let headerList = CapabilityDefinition(
    id: CapabilityID("gtm.versionHeaders.list"),
    field: "gtmVersionHeaders",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/version_headers",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.container), .path("parent"), required: true),
      ArgumentDefinition("includeDeleted", .boolean, .query("includeDeleted")),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "containerVersionHeader", GTMModels.containerVersionHeader),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all Container Versions of a GTM Container."
  )

  static let latestHeader = CapabilityDefinition(
    id: CapabilityID("gtm.versionHeaders.latest"),
    field: "gtmLatestVersionHeader",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/version_headers:latest",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.container), .path("parent"), required: true)
    ],
    result: .single(GTMModels.containerVersionHeader),
    scopes: .tagManagerReadonly,
    summary: "Gets the latest container version header."
  )
}
