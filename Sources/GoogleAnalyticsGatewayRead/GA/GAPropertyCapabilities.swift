import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1beta property-scoped reads.
enum GAPropertyCapabilities {
  private static let property = "properties/{property}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.properties.get"),
      field: "gaProperty",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(property), .path("name"), required: true)
      ],
      result: .single(GAModels.property),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single GA Property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.list"),
      field: "gaProperties",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/properties",
      arguments: [
        // Google documents `filter` as required for this method even though the
        // discovery parameter is not flagged: without it the API answers 400,
        // so requiring it here turns a wasted round trip into a local error.
        ArgumentDefinition("filter", .string, .query("filter"), required: true),
        ArgumentDefinition("showDeleted", .boolean, .query("showDeleted")),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "properties", GAModels.property),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Returns child Properties under the specified parent Account.",
      upstreamRejectionGuidance: "The filter expression must name a parent or ancestor, for "
        + "example `parent:accounts/123` or `ancestor:accounts/123`."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.getDataRetentionSettings"),
      field: "gaDataRetentionSettings",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/dataRetentionSettings"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAModels.dataRetentionSettings),
      scopes: .analyticsReadonly,
      summary: "Returns the singleton data retention settings for this property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.runAccessReport"),
      field: "gaRunPropertyAccessReport",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{entity}:runAccessReport",
      arguments: [
        ArgumentDefinition("entity", .resourceName(property), .path("entity"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAReportInputs.accessReportRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAModels.accessReport),
      scopes: .analyticsReadonly,
      summary: "Returns a customized report of data access records to the property.",
      upstreamRejectionGuidance: "Access reports are retained for a limited window and are "
        + "available only to property administrators; confirm the date range is within "
        + "retention and that the credential administers this property."
    )
  ]
}
