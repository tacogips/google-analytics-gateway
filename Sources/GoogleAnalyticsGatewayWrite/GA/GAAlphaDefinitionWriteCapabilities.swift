import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1alpha mutations for the property-level analysis definitions:
/// audiences, calculated metrics, channel groups, and expanded data sets.
///
/// None of the four has a delete method. An audience is retired by archiving it,
/// which is the same one-way retirement the v1beta custom dimensions and metrics
/// use; the other three are deleted through the admin tier.
enum GAAlphaDefinitionWriteCapabilities {
  private static let property = "properties/{property}"
  private static let audience = "properties/{property}/audiences/{audience}"
  private static let calculatedMetric = "properties/{property}/calculatedMetrics/{calculatedMetric}"
  private static let channelGroup = "properties/{property}/channelGroups/{channelGroup}"
  private static let expandedDataSet = "properties/{property}/expandedDataSets/{expandedDataSet}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.audiences.create"),
      field: "gaCreateAudience",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/audiences",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "audience",
          .inputObject(GAAlphaWriteInputs.audienceCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "audience", GAAlphaModels.audience),
      scopes: .analyticsEdit,
      summary: "Creates an Audience.",
      upstreamRejectionGuidance: "The membership duration cannot exceed 540 days, and a property "
        + "holds a limited number of audiences; archive one before creating another."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.audiences.update"),
      field: "gaUpdateAudience",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(audience), .path("name"), required: true),
        ArgumentDefinition(
          "audience",
          .inputObject(GAAlphaWriteInputs.audienceUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "audience", GAAlphaModels.audience),
      scopes: .analyticsEdit,
      summary: "Updates an Audience on a property.",
      upstreamRejectionGuidance: "An audience's filter clauses, membership duration, and exclusion "
        + "duration mode are immutable; naming one in the update mask is refused."
    ),

    // Archiving is how an audience is retired: the Admin API has no delete for
    // one, and no method restores an archived audience.
    CapabilityDefinition(
      id: CapabilityID("ga.audiences.archive"),
      field: "gaArchiveAudience",
      tier: .writer,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}:archive",
      arguments: [
        ArgumentDefinition("name", .resourceName(audience), .path("name"), required: true)
      ],
      result: .single(GAWriteModels.archiveAcknowledgement),
      scopes: .analyticsEdit,
      summary: "Archives an Audience on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.calculatedMetrics.create"),
      field: "gaCreateCalculatedMetric",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/calculatedMetrics",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        GAAlphaWriteInputs.calculatedMetricId,
        ArgumentDefinition(
          "calculatedMetric",
          .inputObject(GAAlphaWriteInputs.calculatedMetricCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "calculatedMetric", GAAlphaModels.calculatedMetric),
      scopes: .analyticsEdit,
      summary: "Creates a CalculatedMetric.",
      upstreamRejectionGuidance: "The formula may reference at most five distinct custom metrics, "
        + "and the calculated metric id must be unique within the property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.calculatedMetrics.update"),
      field: "gaUpdateCalculatedMetric",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(calculatedMetric), .path("name"), required: true),
        ArgumentDefinition(
          "calculatedMetric",
          .inputObject(GAAlphaWriteInputs.calculatedMetricUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "calculatedMetric", GAAlphaModels.calculatedMetric),
      scopes: .analyticsEdit,
      summary: "Updates a CalculatedMetric on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.channelGroups.create"),
      field: "gaCreateChannelGroup",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/channelGroups",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "channelGroup",
          .inputObject(GAAlphaWriteInputs.channelGroupCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "channelGroup", GAAlphaModels.channelGroup),
      scopes: .analyticsEdit,
      summary: "Creates a ChannelGroup.",
      upstreamRejectionGuidance: "A channel group holds at most 50 grouping rules, and marking one "
        + "as primary unsets the property's previous primary group."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.channelGroups.update"),
      field: "gaUpdateChannelGroup",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(channelGroup), .path("name"), required: true),
        ArgumentDefinition(
          "channelGroup",
          .inputObject(GAAlphaWriteInputs.channelGroupUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "channelGroup", GAAlphaModels.channelGroup),
      scopes: .analyticsEdit,
      summary: "Updates a ChannelGroup on a property.",
      upstreamRejectionGuidance: "The display name and grouping rules of the Google Analytics "
        + "predefined Default Channel Group cannot be updated."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.expandedDataSets.create"),
      field: "gaCreateExpandedDataSet",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/expandedDataSets",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "expandedDataSet",
          .inputObject(GAAlphaWriteInputs.expandedDataSetCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "expandedDataSet", GAAlphaModels.expandedDataSet),
      scopes: .analyticsEdit,
      summary: "Creates an ExpandedDataSet.",
      upstreamRejectionGuidance: "Dimension and metric names must be ones the Data API publishes "
        + "for the property, and a property holds a limited number of expanded data sets."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.expandedDataSets.update"),
      field: "gaUpdateExpandedDataSet",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(expandedDataSet), .path("name"), required: true),
        ArgumentDefinition(
          "expandedDataSet",
          .inputObject(GAAlphaWriteInputs.expandedDataSetUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "expandedDataSet", GAAlphaModels.expandedDataSet),
      scopes: .analyticsEdit,
      summary: "Updates an ExpandedDataSet on a property.",
      upstreamRejectionGuidance: "The dimensions, metrics, and dimension filter of an expanded data "
        + "set are immutable; only the display name and description can be changed."
    )
  ]
}
