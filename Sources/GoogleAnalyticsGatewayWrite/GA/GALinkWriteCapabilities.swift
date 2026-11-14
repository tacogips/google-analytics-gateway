import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1beta mutations for the linked-product resources.
///
/// A Firebase link has no patch method — Google's project name is immutable, so
/// the link is created or deleted rather than edited.
enum GALinkWriteCapabilities {
  private static let property = "properties/{property}"
  private static let googleAdsLink = "properties/{property}/googleAdsLinks/{googleAdsLink}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.firebaseLinks.create"),
      field: "gaCreateFirebaseLink",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/firebaseLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "firebaseLink",
          .inputObject(GAWriteInputs.firebaseLinkCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "firebaseLink", GAModels.firebaseLink),
      scopes: .analyticsEdit,
      summary: "Creates a FirebaseLink.",
      upstreamRejectionGuidance: "A property holds at most one FirebaseLink; delete the existing "
        + "link before creating another."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.googleAdsLinks.create"),
      field: "gaCreateGoogleAdsLink",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/googleAdsLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "googleAdsLink",
          .inputObject(GAWriteInputs.googleAdsLinkCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "googleAdsLink", GAModels.googleAdsLink),
      scopes: .analyticsEdit,
      summary: "Creates a GoogleAdsLink.",
      upstreamRejectionGuidance: "Linking requires administrative access to the Google Ads "
        + "customer as well as to the property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.googleAdsLinks.update"),
      field: "gaUpdateGoogleAdsLink",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(googleAdsLink), .path("name"), required: true),
        ArgumentDefinition(
          "googleAdsLink",
          .inputObject(GAWriteInputs.googleAdsLinkUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "googleAdsLink", GAModels.googleAdsLink),
      scopes: .analyticsEdit,
      summary: "Updates a GoogleAdsLink on a property."
    )
  ]
}
