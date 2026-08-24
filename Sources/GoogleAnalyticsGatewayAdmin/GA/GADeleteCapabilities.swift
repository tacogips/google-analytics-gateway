import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1beta deletes.
///
/// Every one of them takes the resource name twice: once bound into the path
/// and once as a `confirmName` echo the planner checks against the same
/// validated value, so a delete can only ever remove the resource the caller
/// named on purpose.
enum GADeleteCapabilities {
  private static let account = "accounts/{account}"
  private static let property = "properties/{property}"
  private static let conversionEvent = "properties/{property}/conversionEvents/{conversionEvent}"
  private static let dataStream = "properties/{property}/dataStreams/{dataStream}"
  private static let firebaseLink = "properties/{property}/firebaseLinks/{firebaseLink}"
  private static let googleAdsLink = "properties/{property}/googleAdsLinks/{googleAdsLink}"
  private static let keyEvent = "properties/{property}/keyEvents/{keyEvent}"
  private static let measurementProtocolSecret =
    "properties/{property}/dataStreams/{dataStream}/measurementProtocolSecrets/{secret}"

  static let all: [CapabilityDefinition] = [
    delete(
      id: "ga.accounts.delete",
      field: "gaDeleteAccount",
      pattern: account,
      summary: "Marks target Account as soft-deleted (ie: \"trashed\") and returns it."
    ),

    // `properties.delete` is the one GA4 delete that answers with the removed
    // resource rather than an empty body, so its confirmation is read back out
    // of the response instead of taken from the validated request.
    delete(
      id: "ga.properties.delete",
      field: "gaDeleteProperty",
      pattern: property,
      confirmation: .responseResourceName,
      summary: "Marks target Property as soft-deleted (ie: \"trashed\") and returns it."
    ),

    delete(
      id: "ga.conversionEvents.delete",
      field: "gaDeleteConversionEvent",
      pattern: conversionEvent,
      summary: "Deprecated: Use `DeleteKeyEvent` instead. Deletes a conversion event in a property."
    ),

    delete(
      id: "ga.dataStreams.delete",
      field: "gaDeleteDataStream",
      pattern: dataStream,
      summary: "Deletes a DataStream on a property."
    ),

    delete(
      id: "ga.firebaseLinks.delete",
      field: "gaDeleteFirebaseLink",
      pattern: firebaseLink,
      summary: "Deletes a FirebaseLink on a property."
    ),

    delete(
      id: "ga.googleAdsLinks.delete",
      field: "gaDeleteGoogleAdsLink",
      pattern: googleAdsLink,
      summary: "Deletes a GoogleAdsLink on a property."
    ),

    delete(
      id: "ga.keyEvents.delete",
      field: "gaDeleteKeyEvent",
      pattern: keyEvent,
      summary: "Deletes a Key Event."
    ),

    delete(
      id: "ga.measurementProtocolSecrets.delete",
      field: "gaDeleteMeasurementProtocolSecret",
      pattern: measurementProtocolSecret,
      summary: "Deletes target MeasurementProtocolSecret."
    )
  ]

  /// Every GA4 delete addresses `/v1beta/{name}` and differs only in the shape
  /// of the name, so one builder keeps the confirmation contract identical
  /// across all eight rather than restating it per resource.
  private static func delete(
    id: String,
    field: String,
    pattern: String,
    confirmation: DeletionConfirmation = .validatedRequestResourceNameOnEmptyBody,
    summary: String
  ) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .delete,
      method: .delete,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(pattern), .path("name"), required: true),
        ArgumentDefinition("confirmName", .resourceName(pattern), .confirm("name"), required: true)
      ],
      result: .deletion,
      deletionConfirmation: confirmation,
      scopes: .analyticsEdit,
      summary: summary
    )
  }
}
