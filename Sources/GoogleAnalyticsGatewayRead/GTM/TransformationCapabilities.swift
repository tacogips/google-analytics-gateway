import GoogleAnalyticsGatewayCore

/// Tag Manager transformation reads.
enum GTMTransformationCapabilities {
  static let all: [CapabilityDefinition] = [get, list]

  static let get = CapabilityDefinition(
    id: CapabilityID("gtm.transformations.get"),
    field: "gtmTransformation",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition(
        "path",
        .resourceName(GTMResourceNames.transformation),
        .path("path"),
        required: true
      )
    ],
    result: .single(GTMModels.transformation),
    scopes: .tagManagerReadonly,
    summary: "Gets a GTM Transformation."
  )

  static let list = CapabilityDefinition(
    id: CapabilityID("gtm.transformations.list"),
    field: "gtmTransformations",
    tier: .reader,
    operationClass: .read,
    method: .get,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/transformations",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("page", .page, .page)
    ],
    result: .connection(collection: "transformation", GTMModels.transformation),
    scopes: .tagManagerReadonly,
    maximumPageSize: GTMPagination.maximumPageSize,
    summary: "Lists all GTM Transformations of a GTM container workspace."
  )
}
