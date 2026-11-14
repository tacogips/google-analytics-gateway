import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1alpha mutations for the resources that live under a data
/// stream: the event create and event edit rules, the SKAdNetwork conversion
/// value schema, and the two per-stream singleton settings.
///
/// The two settings and the SKAdNetwork schema are singletons rather than
/// collections, so Google addresses them by their own fixed resource name — a
/// stream has exactly one of each, and the schema exists only under an iOS
/// stream.
enum GAAlphaDataStreamWriteCapabilities {
  private static let dataStream = "properties/{property}/dataStreams/{dataStream}"
  private static let eventCreateRule =
    "properties/{property}/dataStreams/{dataStream}/eventCreateRules/{eventCreateRule}"
  private static let eventEditRule =
    "properties/{property}/dataStreams/{dataStream}/eventEditRules/{eventEditRule}"
  private static let skAdNetworkConversionValueSchema =
    "properties/{property}/dataStreams/{dataStream}/sKAdNetworkConversionValueSchema/"
    + "{sKAdNetworkConversionValueSchema}"
  private static let dataRedactionSettings =
    "properties/{property}/dataStreams/{dataStream}/dataRedactionSettings"
  private static let enhancedMeasurementSettings =
    "properties/{property}/dataStreams/{dataStream}/enhancedMeasurementSettings"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.eventCreateRules.create"),
      field: "gaCreateEventCreateRule",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/eventCreateRules",
      arguments: [
        ArgumentDefinition("parent", .resourceName(dataStream), .path("parent"), required: true),
        ArgumentDefinition(
          "eventCreateRule",
          .inputObject(GAAlphaWriteInputs.eventCreateRuleCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "eventCreateRule", GAAlphaModels.eventCreateRule),
      scopes: .analyticsEdit,
      summary: "Creates an EventCreateRule.",
      upstreamRejectionGuidance: "The destination event name must be under 40 characters and "
        + "consist only of letters, digits, and underscores, starting with a letter."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.eventCreateRules.update"),
      field: "gaUpdateEventCreateRule",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(eventCreateRule), .path("name"), required: true),
        ArgumentDefinition(
          "eventCreateRule",
          .inputObject(GAAlphaWriteInputs.eventCreateRuleUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "eventCreateRule", GAAlphaModels.eventCreateRule),
      scopes: .analyticsEdit,
      summary: "Updates an EventCreateRule on a data stream."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.eventEditRules.create"),
      field: "gaCreateEventEditRule",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/eventEditRules",
      arguments: [
        ArgumentDefinition("parent", .resourceName(dataStream), .path("parent"), required: true),
        ArgumentDefinition(
          "eventEditRule",
          .inputObject(GAAlphaWriteInputs.eventEditRuleCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "eventEditRule", GAAlphaModels.eventEditRule),
      scopes: .analyticsEdit,
      summary: "Creates an EventEditRule.",
      upstreamRejectionGuidance: "A new rule is appended to the end of the stream's processing "
        + "order; use the reorder method to place it earlier."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.eventEditRules.update"),
      field: "gaUpdateEventEditRule",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(eventEditRule), .path("name"), required: true),
        ArgumentDefinition(
          "eventEditRule",
          .inputObject(GAAlphaWriteInputs.eventEditRuleUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "eventEditRule", GAAlphaModels.eventEditRule),
      scopes: .analyticsEdit,
      summary: "Updates an EventEditRule on a data stream.",
      upstreamRejectionGuidance: "A rule's processing order is assigned by Google and is changed "
        + "through the reorder method rather than through this update mask."
    ),

    // Reordering is addressed to the stream rather than to a rule, and Google
    // answers with an empty body, so the result is the same acknowledgement the
    // archive methods use.
    CapabilityDefinition(
      id: CapabilityID("ga.eventEditRules.reorder"),
      field: "gaReorderEventEditRules",
      tier: .writer,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/eventEditRules:reorder",
      arguments: [
        ArgumentDefinition("parent", .resourceName(dataStream), .path("parent"), required: true),
        ArgumentDefinition(
          "reorder",
          .inputObject(GAAlphaWriteInputs.reorderEventEditRules),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAWriteModels.archiveAcknowledgement),
      scopes: .analyticsEdit,
      summary: "Changes the processing order of the event edit rules on a data stream.",
      upstreamRejectionGuidance: "Every event edit rule on the stream must appear in the list "
        + "exactly once; a partial or duplicated list is refused."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.sKAdNetworkConversionValueSchema.create"),
      field: "gaCreateSKAdNetworkConversionValueSchema",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/sKAdNetworkConversionValueSchema",
      arguments: [
        ArgumentDefinition("parent", .resourceName(dataStream), .path("parent"), required: true),
        ArgumentDefinition(
          "skAdNetworkConversionValueSchema",
          .inputObject(GAAlphaWriteInputs.skAdNetworkConversionValueSchemaCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(
        field: "skAdNetworkConversionValueSchema",
        GAAlphaModels.skAdNetworkConversionValueSchema
      ),
      scopes: .analyticsEdit,
      summary: "Creates a SKAdNetworkConversionValueSchema.",
      upstreamRejectionGuidance: "The parent must be an iOS app data stream and may hold only one "
        + "schema. Fine values belong to the first postback window only, where they must be in "
        + "the range 0 to 63."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.sKAdNetworkConversionValueSchema.update"),
      field: "gaUpdateSKAdNetworkConversionValueSchema",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(skAdNetworkConversionValueSchema),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "skAdNetworkConversionValueSchema",
          .inputObject(GAAlphaWriteInputs.skAdNetworkConversionValueSchemaUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(
        field: "skAdNetworkConversionValueSchema",
        GAAlphaModels.skAdNetworkConversionValueSchema
      ),
      scopes: .analyticsEdit,
      summary: "Updates a SKAdNetworkConversionValueSchema on an iOS data stream."
    ),

    // The per-stream data redaction settings are a different resource from the
    // property-level data retention settings the v1beta writer patches, so the
    // field name says which one it addresses.
    CapabilityDefinition(
      id: CapabilityID("ga.dataStreams.updateDataRedactionSettings"),
      field: "gaUpdateStreamDataRedactionSettings",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(dataRedactionSettings),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "dataRedactionSettings",
          .inputObject(GAAlphaWriteInputs.streamDataRedactionSettingsUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "dataRedactionSettings", GAAlphaModels.dataRedactionSettings),
      scopes: .analyticsEdit,
      summary: "Updates the singleton data redaction settings for a web data stream.",
      upstreamRejectionGuidance: "The settings exist on web streams only. Query parameter keys must "
        + "not contain commas, and at least one key is required when query parameter redaction is "
        + "enabled."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.dataStreams.updateEnhancedMeasurementSettings"),
      field: "gaUpdateEnhancedMeasurementSettings",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(enhancedMeasurementSettings),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "enhancedMeasurementSettings",
          .inputObject(GAAlphaWriteInputs.enhancedMeasurementSettingsUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(
        field: "enhancedMeasurementSettings",
        GAAlphaModels.enhancedMeasurementSettings
      ),
      scopes: .analyticsEdit,
      summary: "Updates the singleton enhanced measurement settings for a web data stream.",
      upstreamRejectionGuidance: "The settings exist on web streams only, and the search query "
        + "parameter must not be empty, so naming it in the update mask requires a value."
    )
  ]
}
