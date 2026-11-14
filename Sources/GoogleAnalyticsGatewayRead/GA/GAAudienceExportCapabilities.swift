import GoogleAnalyticsGatewayCore

/// GA4 Data API v1beta audience export reads.
///
/// Creating an export is a writer-tier mutation; the reader sees the three
/// methods that inspect and retrieve one that already exists.
enum GAAudienceExportCapabilities {
  private static let property = "properties/{property}"
  private static let audienceExport = "properties/{property}/audienceExports/{audienceExport}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.audienceExports.get"),
      field: "gaAudienceExport",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(audienceExport), .path("name"), required: true)
      ],
      result: .single(GAModels.audienceExport),
      scopes: .analyticsReadonly,
      summary: "Gets configuration metadata about a specific audience export."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.audienceExports.list"),
      field: "gaAudienceExports",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{parent}/audienceExports",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "audienceExports", GAModels.audienceExport),
      scopes: .analyticsReadonly,
      maximumPageSize: 1000,
      summary: "Lists all audience exports for a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.audienceExports.query"),
      field: "gaQueryAudienceExport",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{name}:query",
      arguments: [
        ArgumentDefinition("name", .resourceName(audienceExport), .path("name"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.audienceExportQuery),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.audienceExportQueryResult),
      scopes: .analyticsReadonly,
      summary: "Retrieves an audience export of users.",
      upstreamRejectionGuidance: "An audience export is populated asynchronously after it is "
        + "created; query it only once gaAudienceExport reports the state ACTIVE."
    )
  ]
}
