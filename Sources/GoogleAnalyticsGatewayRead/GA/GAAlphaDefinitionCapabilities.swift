import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1alpha reads for the property-scoped definitions that have no
/// v1beta equivalent: audiences, calculated metrics, channel groups, expanded
/// data sets, and reporting data annotations.
enum GAAlphaDefinitionCapabilities {
  private static let property = "properties/{property}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.audiences.get"),
      field: "gaAudience",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/audiences/{audience}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.audience),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single Audience.",
      upstreamRejectionGuidance: "Audiences created before 2020 may not be supported, and "
        + "default audiences do not return their filter definitions."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.audiences.list"),
      field: "gaAudiences",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/audiences",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "audiences", GAAlphaModels.audience),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists Audiences on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.calculatedMetrics.get"),
      field: "gaCalculatedMetric",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/calculatedMetrics/{calculatedMetric}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.calculatedMetric),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single CalculatedMetric."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.calculatedMetrics.list"),
      field: "gaCalculatedMetrics",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/calculatedMetrics",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "calculatedMetrics", GAAlphaModels.calculatedMetric),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists CalculatedMetrics on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.channelGroups.get"),
      field: "gaChannelGroup",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/channelGroups/{channelGroup}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.channelGroup),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single ChannelGroup."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.channelGroups.list"),
      field: "gaChannelGroups",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/channelGroups",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "channelGroups", GAAlphaModels.channelGroup),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists ChannelGroups on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.expandedDataSets.get"),
      field: "gaExpandedDataSet",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/expandedDataSets/{expandedDataSet}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.expandedDataSet),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single ExpandedDataSet."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.expandedDataSets.list"),
      field: "gaExpandedDataSets",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/expandedDataSets",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "expandedDataSets", GAAlphaModels.expandedDataSet),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists ExpandedDataSets on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.reportingDataAnnotations.get"),
      field: "gaReportingDataAnnotation",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/reportingDataAnnotations/{annotation}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.reportingDataAnnotation),
      scopes: .analyticsReadonly,
      summary: "Lookup a single Reporting Data Annotation."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.reportingDataAnnotations.list"),
      field: "gaReportingDataAnnotations",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/reportingDataAnnotations",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("filter", .string, .query("filter")),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(
        collection: "reportingDataAnnotations",
        GAAlphaModels.reportingDataAnnotation
      ),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "List all Reporting Data Annotations on a property."
    )
  ]
}
