import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1beta reads for the linked-product resources.
enum GALinkCapabilities {
  private static let property = "properties/{property}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.firebaseLinks.list"),
      field: "gaFirebaseLinks",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/firebaseLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "firebaseLinks", GAModels.firebaseLink),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists FirebaseLinks on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.googleAdsLinks.list"),
      field: "gaGoogleAdsLinks",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{parent}/googleAdsLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "googleAdsLinks", GAModels.googleAdsLink),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists GoogleAdsLinks on a property."
    )
  ]
}
