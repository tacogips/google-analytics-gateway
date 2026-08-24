import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1alpha property mutations: the two provisioning verbs that
/// create a property of a non-ordinary type, the subproperty resources, the
/// reporting data annotations, and the three property-level singleton settings.
///
/// The provisioning verbs are addressed to the collection rather than to a
/// property — a roll-up or a subproperty does not exist yet when the call is
/// made — so neither takes a path argument, and each answers with a wrapper
/// message rather than with the property alone.
enum GAAlphaPropertyWriteCapabilities {
  private static let property = "properties/{property}"
  private static let subpropertyEventFilter =
    "properties/{property}/subpropertyEventFilters/{subpropertyEventFilter}"
  private static let subpropertySyncConfig =
    "properties/{property}/subpropertySyncConfigs/{subpropertySyncConfig}"
  private static let reportingDataAnnotation =
    "properties/{property}/reportingDataAnnotations/{reportingDataAnnotation}"
  private static let attributionSettings = "properties/{property}/attributionSettings"
  private static let googleSignalsSettings = "properties/{property}/googleSignalsSettings"
  private static let reportingIdentitySettings = "properties/{property}/reportingIdentitySettings"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.properties.createRollupProperty"),
      field: "gaCreateRollupProperty",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/properties:createRollupProperty",
      arguments: [
        ArgumentDefinition(
          "request",
          .inputObject(GAAlphaWriteInputs.createRollupProperty),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAAlphaWriteModels.createRollupPropertyResult),
      scopes: .analyticsEdit,
      summary: "Creates a roll-up property and all roll-up property source links.",
      upstreamRejectionGuidance: "Roll-up properties are an Analytics 360 feature. Every source "
        + "must be a property the credential administers under the same account as the roll-up."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.provisionSubproperty"),
      field: "gaProvisionSubproperty",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/properties:provisionSubproperty",
      arguments: [
        ArgumentDefinition(
          "request",
          .inputObject(GAAlphaWriteInputs.provisionSubproperty),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAAlphaWriteModels.provisionSubpropertyResult),
      scopes: .analyticsEdit,
      summary: "Creates a subproperty and an optional subproperty event filter.",
      upstreamRejectionGuidance: "Subproperties are an Analytics 360 feature. The subproperty's "
        + "parent must be an ordinary property the credential administers, and the event filter is "
        + "created on that parent rather than on the new subproperty."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.subpropertyEventFilters.create"),
      field: "gaCreateSubpropertyEventFilter",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/subpropertyEventFilters",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "subpropertyEventFilter",
          .inputObject(GAAlphaWriteInputs.subpropertyEventFilterCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "subpropertyEventFilter", GAAlphaModels.subpropertyEventFilter),
      scopes: .analyticsEdit,
      summary: "Creates a subproperty event filter.",
      upstreamRejectionGuidance: "The parent must be the ordinary property that feeds the "
        + "subproperty, and the subproperty named in applyToProperty must already exist."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.subpropertyEventFilters.update"),
      field: "gaUpdateSubpropertyEventFilter",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(subpropertyEventFilter),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "subpropertyEventFilter",
          .inputObject(GAAlphaWriteInputs.subpropertyEventFilterUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "subpropertyEventFilter", GAAlphaModels.subpropertyEventFilter),
      scopes: .analyticsEdit,
      summary: "Updates a subproperty event filter.",
      upstreamRejectionGuidance: "The subproperty a filter applies to is immutable; only the filter "
        + "clauses can be changed."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.subpropertySyncConfigs.update"),
      field: "gaUpdateSubpropertySyncConfig",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(subpropertySyncConfig),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "subpropertySyncConfig",
          .inputObject(GAAlphaWriteInputs.subpropertySyncConfigUpdate),
          .bodyRoot,
          required: true
        ),
        GAAlphaWriteInputs.optionalUpdateMask
      ],
      result: .payload(field: "subpropertySyncConfig", GAAlphaModels.subpropertySyncConfig),
      scopes: .analyticsEdit,
      summary: "Updates a subproperty synchronization configuration.",
      upstreamRejectionGuidance: "A sync config is provisioned by Google alongside the subproperty "
        + "and cannot be created here. While the mode is ALL, custom dimensions and metrics cannot "
        + "be configured locally on the subproperty."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.reportingDataAnnotations.create"),
      field: "gaCreateReportingDataAnnotation",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/reportingDataAnnotations",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "reportingDataAnnotation",
          .inputObject(GAAlphaWriteInputs.reportingDataAnnotationCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(
        field: "reportingDataAnnotation",
        GAAlphaModels.reportingDataAnnotation
      ),
      scopes: .analyticsEdit,
      summary: "Creates a Reporting Data Annotation.",
      upstreamRejectionGuidance: "An annotation carries either a single date or a date range, not "
        + "both, and every date component must be set to a real calendar date."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.reportingDataAnnotations.update"),
      field: "gaUpdateReportingDataAnnotation",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(reportingDataAnnotation),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "reportingDataAnnotation",
          .inputObject(GAAlphaWriteInputs.reportingDataAnnotationUpdate),
          .bodyRoot,
          required: true
        ),
        GAAlphaWriteInputs.optionalUpdateMask
      ],
      result: .payload(
        field: "reportingDataAnnotation",
        GAAlphaModels.reportingDataAnnotation
      ),
      scopes: .analyticsEdit,
      summary: "Updates a Reporting Data Annotation.",
      upstreamRejectionGuidance: "System-generated annotations cannot be updated. Omitting the "
        + "update mask replaces every field of the annotation."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.updateAttributionSettings"),
      field: "gaUpdateAttributionSettings",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(attributionSettings),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "attributionSettings",
          .inputObject(GAAlphaWriteInputs.attributionSettingsUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "attributionSettings", GAAlphaModels.attributionSettings),
      scopes: .analyticsEdit,
      summary: "Updates the singleton attribution settings for this property.",
      upstreamRejectionGuidance: "Changing the attribution model reprocesses historical as well as "
        + "future conversion and revenue data, and the data-driven model is available only to "
        + "properties that meet Google's data volume threshold."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.updateGoogleSignalsSettings"),
      field: "gaUpdateGoogleSignalsSettings",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(googleSignalsSettings),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "googleSignalsSettings",
          .inputObject(GAAlphaWriteInputs.googleSignalsSettingsUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "googleSignalsSettings", GAAlphaModels.googleSignalsSettings),
      scopes: .analyticsEdit,
      summary: "Updates the singleton Google Signals settings for this property.",
      upstreamRejectionGuidance: "Google Signals cannot be enabled until the property's account has "
        + "accepted the Google Signals terms of service, which is recorded in the read-only "
        + "consent field."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.updateReportingIdentitySettings"),
      field: "gaUpdateReportingIdentitySettings",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(reportingIdentitySettings),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "reportingIdentitySettings",
          .inputObject(GAAlphaWriteInputs.reportingIdentitySettingsUpdate),
          .bodyRoot,
          required: true
        ),
        GAAlphaWriteInputs.optionalUpdateMask
      ],
      result: .payload(
        field: "reportingIdentitySettings",
        GAAlphaModels.reportingIdentitySettings
      ),
      scopes: .analyticsEdit,
      summary: "Updates the singleton reporting identity settings for this property.",
      upstreamRejectionGuidance: "The blended and observed strategies require Google Signals or "
        + "user-id collection to be in use; without either, the property stays device-based."
    )
  ]
}
