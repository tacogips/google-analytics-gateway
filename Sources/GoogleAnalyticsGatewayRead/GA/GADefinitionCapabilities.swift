import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1beta reads for the per-property definitions: custom
/// dimensions, custom metrics, and the conversion and key events.
enum GADefinitionCapabilities {
  private static let property = "properties/{property}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.customDimensions.get"),
      field: "gaCustomDimension",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/customDimensions/{customDimension}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAModels.customDimension),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single CustomDimension."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.customDimensions.list"),
      field: "gaCustomDimensions",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/customDimensions",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "customDimensions", GAModels.customDimension),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists CustomDimensions on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.customMetrics.get"),
      field: "gaCustomMetric",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/customMetrics/{customMetric}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAModels.customMetric),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single CustomMetric."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.customMetrics.list"),
      field: "gaCustomMetrics",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/customMetrics",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "customMetrics", GAModels.customMetric),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists CustomMetrics on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.conversionEvents.get"),
      field: "gaConversionEvent",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/conversionEvents/{conversionEvent}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAModels.conversionEvent),
      scopes: .analyticsReadonly,
      summary: "Retrieve a single conversion event."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.conversionEvents.list"),
      field: "gaConversionEvents",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/conversionEvents",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "conversionEvents", GAModels.conversionEvent),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Returns a list of conversion events in the specified parent property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.keyEvents.get"),
      field: "gaKeyEvent",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/keyEvents/{keyEvent}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAModels.keyEvent),
      scopes: .analyticsReadonly,
      summary: "Retrieve a single key event."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.keyEvents.list"),
      field: "gaKeyEvents",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/keyEvents",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "keyEvents", GAModels.keyEvent),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Returns a list of key events in the specified parent property."
    )
  ]
}
