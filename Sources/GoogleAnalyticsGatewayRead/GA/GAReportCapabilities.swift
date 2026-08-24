import GoogleAnalyticsGatewayCore

/// GA4 Data API v1beta reporting, metadata, and compatibility reads.
///
/// Every one of these is a POST that reads: the report specification is too
/// large for a query string, so Google puts it in a request body. They stay
/// `.read` operations in the reader tier, which is what keeps them out of the
/// GraphQL mutation root.
enum GAReportCapabilities {
  private static let property = "properties/{property}"

  /// Reporting refusals read as missing data unless the caller is told that a
  /// dimension or metric the property never collected is a request-shape
  /// problem rather than an absent resource.
  private static let incompatibleSelectionGuidance =
    "Google rejects a report whose dimensions and metrics cannot be combined, or that names "
      + "a field this property has never collected. Use gaCheckCompatibility to find a "
      + "compatible selection, and gaMetadata to list the fields the property reports on."

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.properties.runReport"),
      field: "gaRunReport",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{property}:runReport",
      arguments: [
        ArgumentDefinition("property", .resourceName(property), .path("property"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.reportRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.report),
      scopes: .analyticsReadonly,
      summary: "Returns a customized report of your Google Analytics event data.",
      upstreamRejectionGuidance: incompatibleSelectionGuidance
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.batchRunReports"),
      field: "gaBatchRunReports",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{property}:batchRunReports",
      arguments: [
        ArgumentDefinition("property", .resourceName(property), .path("property"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.batchReportRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.reportBatch),
      scopes: .analyticsReadonly,
      summary: "Returns multiple reports in a batch, all for the same Google Analytics property.",
      upstreamRejectionGuidance: incompatibleSelectionGuidance
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.runPivotReport"),
      field: "gaRunPivotReport",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{property}:runPivotReport",
      arguments: [
        ArgumentDefinition("property", .resourceName(property), .path("property"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.pivotReportRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.pivotReport),
      scopes: .analyticsReadonly,
      summary: "Returns a customized pivot report of your Google Analytics event data.",
      upstreamRejectionGuidance: "A pivot's fieldNames must be a subset of the request's "
        + "dimensions and no two pivots may share a dimension. "
        + incompatibleSelectionGuidance
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.batchRunPivotReports"),
      field: "gaBatchRunPivotReports",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{property}:batchRunPivotReports",
      arguments: [
        ArgumentDefinition("property", .resourceName(property), .path("property"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.batchPivotReportRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.pivotReportBatch),
      scopes: .analyticsReadonly,
      summary: "Returns multiple pivot reports in a batch, all for the same Google Analytics "
        + "property.",
      upstreamRejectionGuidance: incompatibleSelectionGuidance
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.runRealtimeReport"),
      field: "gaRunRealtimeReport",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{property}:runRealtimeReport",
      arguments: [
        ArgumentDefinition("property", .resourceName(property), .path("property"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.realtimeReportRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.realtimeReport),
      scopes: .analyticsReadonly,
      summary: "Returns a customized report of realtime event data for your property.",
      upstreamRejectionGuidance: "Realtime reporting accepts only the realtime dimensions and "
        + "metrics, which are a subset of the standard reporting fields."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.checkCompatibility"),
      field: "gaCheckCompatibility",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{property}:checkCompatibility",
      arguments: [
        ArgumentDefinition("property", .resourceName(property), .path("property"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.compatibilityRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.compatibilityReport),
      scopes: .analyticsReadonly,
      summary: "Lists dimensions and metrics that can be added to a report request and "
        + "maintain compatibility."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.getMetadata"),
      field: "gaMetadata",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/metadata"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAModels.reportingMetadata),
      scopes: .analyticsReadonly,
      summary: "Returns metadata for dimensions and metrics available in reporting methods."
    )
  ]
}
