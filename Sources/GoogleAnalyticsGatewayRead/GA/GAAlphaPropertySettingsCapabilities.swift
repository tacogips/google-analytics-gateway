import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1alpha property-scoped settings singletons, plus the roll-up
/// and subproperty links that describe how a property draws on others.
enum GAAlphaPropertySettingsCapabilities {
  private static let property = "properties/{property}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.properties.getAttributionSettings"),
      field: "gaAttributionSettings",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(property)/attributionSettings"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.attributionSettings),
      scopes: .analyticsReadonly,
      summary: "Lookup for a AttributionSettings singleton."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.getGoogleSignalsSettings"),
      field: "gaGoogleSignalsSettings",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(property)/googleSignalsSettings"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.googleSignalsSettings),
      scopes: .analyticsReadonly,
      summary: "Lookup for Google Signals settings for a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.getReportingIdentitySettings"),
      field: "gaReportingIdentitySettings",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(property)/reportingIdentitySettings"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.reportingIdentitySettings),
      scopes: .analyticsReadonly,
      summary: "Returns the reporting identity settings for this property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.getUserProvidedDataSettings"),
      field: "gaGetUserProvidedDataSettings",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(property)/userProvidedDataSettings"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.userProvidedDataSettings),
      scopes: .analyticsReadonly,
      summary: "Looks up settings related to user-provided data for a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.rollupPropertySourceLinks.get"),
      field: "gaRollupPropertySourceLink",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(property)/rollupPropertySourceLinks/{link}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.rollupPropertySourceLink),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single roll-up property source Link.",
      upstreamRejectionGuidance: "Only roll-up properties have source links; asking any other "
        + "property type is an error rather than an empty result."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.rollupPropertySourceLinks.list"),
      field: "gaRollupPropertySourceLinks",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/rollupPropertySourceLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(
        collection: "rollupPropertySourceLinks",
        GAAlphaModels.rollupPropertySourceLink
      ),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists roll-up property source Links on a property.",
      upstreamRejectionGuidance: "Only roll-up properties have source links; asking any other "
        + "property type is an error rather than an empty result."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.subpropertyEventFilters.get"),
      field: "gaSubpropertyEventFilter",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(property)/subpropertyEventFilters/{filter}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.subpropertyEventFilter),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single subproperty Event Filter."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.subpropertyEventFilters.list"),
      field: "gaSubpropertyEventFilters",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/subpropertyEventFilters",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(
        collection: "subpropertyEventFilters",
        GAAlphaModels.subpropertyEventFilter
      ),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "List all subproperty Event Filters on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.subpropertySyncConfigs.get"),
      field: "gaSubpropertySyncConfig",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(property)/subpropertySyncConfigs/{config}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.subpropertySyncConfig),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single SubpropertySyncConfig."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.subpropertySyncConfigs.list"),
      field: "gaSubpropertySyncConfigs",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/subpropertySyncConfigs",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(
        collection: "subpropertySyncConfigs",
        GAAlphaModels.subpropertySyncConfig
      ),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "List all SubpropertySyncConfig resources for a property."
    )
  ]
}
