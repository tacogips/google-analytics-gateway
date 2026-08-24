import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1beta data stream and Measurement Protocol secret reads.
enum GADataStreamCapabilities {
  private static let property = "properties/{property}"
  private static let dataStream = "properties/{property}/dataStreams/{dataStream}"
  private static let secret =
    "properties/{property}/dataStreams/{dataStream}/measurementProtocolSecrets/{secret}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.dataStreams.get"),
      field: "gaDataStream",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(dataStream), .path("name"), required: true)
      ],
      result: .single(GAModels.dataStream),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single DataStream."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.dataStreams.list"),
      field: "gaDataStreams",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/dataStreams",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "dataStreams", GAModels.dataStream),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists DataStreams on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.measurementProtocolSecrets.get"),
      field: "gaMeasurementProtocolSecret",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(secret), .path("name"), required: true)
      ],
      result: .single(GAModels.measurementProtocolSecret),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single MeasurementProtocolSecret."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.measurementProtocolSecrets.list"),
      field: "gaMeasurementProtocolSecrets",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/measurementProtocolSecrets",
      arguments: [
        ArgumentDefinition("parent", .resourceName(dataStream), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(
        collection: "measurementProtocolSecrets",
        GAModels.measurementProtocolSecret
      ),
      scopes: .analyticsReadonly,
      // Google caps this list at 10 rather than the 200 the other admin lists
      // allow, so an over-large page is refused here instead of being silently
      // coerced upstream.
      maximumPageSize: 10,
      summary: "Returns child MeasurementProtocolSecrets under the specified parent Property."
    )
  ]
}
