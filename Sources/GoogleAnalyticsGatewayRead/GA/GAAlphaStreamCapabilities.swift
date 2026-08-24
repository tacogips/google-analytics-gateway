import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1alpha reads scoped to a data stream: event create and edit
/// rules, the SKAdNetwork conversion value schema, and the three stream
/// singletons (data redaction, enhanced measurement, global site tag).
enum GAAlphaStreamCapabilities {
  private static let dataStream = "properties/{property}/dataStreams/{dataStream}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.eventCreateRules.get"),
      field: "gaEventCreateRule",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(dataStream)/eventCreateRules/{rule}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.eventCreateRule),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single EventCreateRule."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.eventCreateRules.list"),
      field: "gaEventCreateRules",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/eventCreateRules",
      arguments: [
        ArgumentDefinition("parent", .resourceName(dataStream), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "eventCreateRules", GAAlphaModels.eventCreateRule),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists EventCreateRules on a web data stream."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.eventEditRules.get"),
      field: "gaEventEditRule",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(dataStream)/eventEditRules/{rule}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.eventEditRule),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single EventEditRule."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.eventEditRules.list"),
      field: "gaEventEditRules",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/eventEditRules",
      arguments: [
        ArgumentDefinition("parent", .resourceName(dataStream), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "eventEditRules", GAAlphaModels.eventEditRule),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists EventEditRules on a web data stream."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.sKAdNetworkConversionValueSchema.get"),
      field: "gaSKAdNetworkConversionValueSchema",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(dataStream)/sKAdNetworkConversionValueSchema/{schema}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.skAdNetworkConversionValueSchema),
      scopes: .analyticsReadonly,
      summary: "Looks up a single SKAdNetworkConversionValueSchema."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.sKAdNetworkConversionValueSchema.list"),
      field: "gaSKAdNetworkConversionValueSchemas",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/sKAdNetworkConversionValueSchema",
      arguments: [
        ArgumentDefinition("parent", .resourceName(dataStream), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      // The route segment is `sKAdNetworkConversionValueSchema` but the response
      // key is `skadnetworkConversionValueSchemas`.
      result: .connection(
        collection: "skadnetworkConversionValueSchemas",
        GAAlphaModels.skAdNetworkConversionValueSchema
      ),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists SKAdNetworkConversionValueSchema on a stream. Properties can have at most "
        + "one SKAdNetworkConversionValueSchema."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.dataStreams.getDataRedactionSettings"),
      field: "gaStreamDataRedactionSettings",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(dataStream)/dataRedactionSettings"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.dataRedactionSettings),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single DataRedactionSettings."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.dataStreams.getEnhancedMeasurementSettings"),
      field: "gaEnhancedMeasurementSettings",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(dataStream)/enhancedMeasurementSettings"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.enhancedMeasurementSettings),
      scopes: .analyticsReadonly,
      summary: "Returns the enhanced measurement settings for this data stream.",
      upstreamRejectionGuidance: "The stream must have enhanced measurement enabled for these "
        + "settings to take effect."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.dataStreams.getGlobalSiteTag"),
      field: "gaGlobalSiteTag",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(dataStream)/globalSiteTag"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.globalSiteTag),
      scopes: .analyticsReadonly,
      summary: "Returns the Site Tag for the specified web stream. Site Tags are immutable "
        + "singletons.",
      upstreamRejectionGuidance: "Only web data streams carry a site tag; an app stream has none."
    )
  ]
}
