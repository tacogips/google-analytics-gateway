import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1beta property mutations, including the property's singleton
/// data retention settings.
enum GAPropertyWriteCapabilities {
  private static let property = "properties/{property}"
  private static let dataRetentionSettings = "properties/{property}/dataRetentionSettings"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.properties.create"),
      field: "gaCreateProperty",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/properties",
      arguments: [
        ArgumentDefinition(
          "property",
          .inputObject(GAWriteInputs.propertyCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "property", GAModels.property),
      scopes: .analyticsEdit,
      summary: "Creates a Google Analytics property with the specified location and attributes.",
      upstreamRejectionGuidance: "The parent must be an account the credential administers, and "
        + "the account must not already hold the maximum number of properties."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.update"),
      field: "gaUpdateProperty",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(property), .path("name"), required: true),
        ArgumentDefinition(
          "property",
          .inputObject(GAWriteInputs.propertyUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "property", GAModels.property),
      scopes: .analyticsEdit,
      summary: "Updates a property."
    ),

    // The retention settings are a singleton under the property rather than a
    // collection, so Google gives the method its own name and its own path
    // instead of a `properties.patch` on a child resource.
    CapabilityDefinition(
      id: CapabilityID("ga.properties.updateDataRetentionSettings"),
      field: "gaUpdateDataRetentionSettings",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(dataRetentionSettings),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "dataRetentionSettings",
          .inputObject(GAWriteInputs.dataRetentionSettingsUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "dataRetentionSettings", GAModels.dataRetentionSettings),
      scopes: .analyticsEdit,
      summary: "Updates the singleton data retention settings for this property.",
      upstreamRejectionGuidance: "Retention durations longer than the property's service level "
        + "allows are refused; a standard property is limited to TWO_MONTHS or FOURTEEN_MONTHS "
        + "of event data."
    )
  ]
}
