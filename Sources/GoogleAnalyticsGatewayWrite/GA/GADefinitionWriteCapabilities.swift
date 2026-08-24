import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1beta mutations for the per-property definitions: custom
/// dimensions, custom metrics, and the conversion and key events.
enum GADefinitionWriteCapabilities {
  private static let property = "properties/{property}"
  private static let customDimension = "properties/{property}/customDimensions/{customDimension}"
  private static let customMetric = "properties/{property}/customMetrics/{customMetric}"
  private static let conversionEvent = "properties/{property}/conversionEvents/{conversionEvent}"
  private static let keyEvent = "properties/{property}/keyEvents/{keyEvent}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.customDimensions.create"),
      field: "gaCreateCustomDimension",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/customDimensions",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "customDimension",
          .inputObject(GAWriteInputs.customDimensionCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "customDimension", GAModels.customDimension),
      scopes: .analyticsEdit,
      summary: "Creates a CustomDimension.",
      upstreamRejectionGuidance: "A property allows a limited number of custom dimensions per "
        + "scope; archive one that is no longer collected before creating another."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.customDimensions.update"),
      field: "gaUpdateCustomDimension",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(customDimension), .path("name"), required: true),
        ArgumentDefinition(
          "customDimension",
          .inputObject(GAWriteInputs.customDimensionUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "customDimension", GAModels.customDimension),
      scopes: .analyticsEdit,
      summary: "Updates a CustomDimension on a property."
    ),

    // Archiving is how a custom definition is retired: the Admin API has no
    // delete for one, and no method restores an archived definition, so the
    // dimension's data stops being reportable from here on.
    CapabilityDefinition(
      id: CapabilityID("ga.customDimensions.archive"),
      field: "gaArchiveCustomDimension",
      tier: .writer,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}:archive",
      arguments: [
        ArgumentDefinition("name", .resourceName(customDimension), .path("name"), required: true)
      ],
      result: .single(GAWriteModels.archiveAcknowledgement),
      scopes: .analyticsEdit,
      summary: "Archives a CustomDimension on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.customMetrics.create"),
      field: "gaCreateCustomMetric",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/customMetrics",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "customMetric",
          .inputObject(GAWriteInputs.customMetricCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "customMetric", GAModels.customMetric),
      scopes: .analyticsEdit,
      summary: "Creates a CustomMetric.",
      upstreamRejectionGuidance: "A metric measured in CURRENCY must declare a "
        + "restrictedMetricType, and a metric measured in anything else must leave it empty."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.customMetrics.update"),
      field: "gaUpdateCustomMetric",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(customMetric), .path("name"), required: true),
        ArgumentDefinition(
          "customMetric",
          .inputObject(GAWriteInputs.customMetricUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "customMetric", GAModels.customMetric),
      scopes: .analyticsEdit,
      summary: "Updates a CustomMetric on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.customMetrics.archive"),
      field: "gaArchiveCustomMetric",
      tier: .writer,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}:archive",
      arguments: [
        ArgumentDefinition("name", .resourceName(customMetric), .path("name"), required: true)
      ],
      result: .single(GAWriteModels.archiveAcknowledgement),
      scopes: .analyticsEdit,
      summary: "Archives a CustomMetric on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.conversionEvents.create"),
      field: "gaCreateConversionEvent",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/conversionEvents",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "conversionEvent",
          .inputObject(GAWriteInputs.conversionEventCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "conversionEvent", GAModels.conversionEvent),
      scopes: .analyticsEdit,
      summary: "Deprecated: use gaCreateKeyEvent instead. Creates a conversion event with the "
        + "specified attributes."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.conversionEvents.update"),
      field: "gaUpdateConversionEvent",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(conversionEvent), .path("name"), required: true),
        ArgumentDefinition(
          "conversionEvent",
          .inputObject(GAWriteInputs.conversionEventUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "conversionEvent", GAModels.conversionEvent),
      scopes: .analyticsEdit,
      summary: "Deprecated: use gaUpdateKeyEvent instead. Updates a conversion event with the "
        + "specified attributes."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.keyEvents.create"),
      field: "gaCreateKeyEvent",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/keyEvents",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "keyEvent",
          .inputObject(GAWriteInputs.keyEventCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "keyEvent", GAModels.keyEvent),
      scopes: .analyticsEdit,
      summary: "Creates a Key Event."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.keyEvents.update"),
      field: "gaUpdateKeyEvent",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(keyEvent), .path("name"), required: true),
        ArgumentDefinition(
          "keyEvent",
          .inputObject(GAWriteInputs.keyEventUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "keyEvent", GAModels.keyEvent),
      scopes: .analyticsEdit,
      summary: "Updates a Key Event."
    )
  ]
}
