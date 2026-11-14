import GoogleAnalyticsGatewayCore

/// GA4 Admin API v1alpha reads for the product links that the v1beta surface
/// does not expose: AdSense, BigQuery, Display & Video 360 (links and their
/// proposals), and Search Ads 360.
enum GAAlphaLinkCapabilities {
  private static let property = "properties/{property}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.adSenseLinks.get"),
      field: "gaAdSenseLink",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/adSenseLinks/{adSenseLink}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.adSenseLink),
      scopes: .analyticsReadonly,
      summary: "Looks up a single AdSenseLink."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.adSenseLinks.list"),
      field: "gaAdSenseLinks",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/adSenseLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      // Google keys the response `adsenseLinks`, lower-cased in the middle,
      // while the route and resource are spelled `adSenseLinks`.
      result: .connection(collection: "adsenseLinks", GAAlphaModels.adSenseLink),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists AdSenseLinks on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.bigQueryLinks.get"),
      field: "gaBigQueryLink",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/bigQueryLinks/{bigQueryLink}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.bigQueryLink),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single BigQuery Link."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.bigQueryLinks.list"),
      field: "gaBigQueryLinks",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/bigQueryLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      // As with AdSense, the response key drops the interior capital.
      result: .connection(collection: "bigqueryLinks", GAAlphaModels.bigQueryLink),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists BigQuery Links on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.displayVideo360AdvertiserLinks.get"),
      field: "gaDisplayVideo360AdvertiserLink",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/displayVideo360AdvertiserLinks/{link}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.displayVideo360AdvertiserLink),
      scopes: .analyticsReadonly,
      summary: "Look up a single DisplayVideo360AdvertiserLink."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.displayVideo360AdvertiserLinks.list"),
      field: "gaDisplayVideo360AdvertiserLinks",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/displayVideo360AdvertiserLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(
        collection: "displayVideo360AdvertiserLinks",
        GAAlphaModels.displayVideo360AdvertiserLink
      ),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists all DisplayVideo360AdvertiserLinks on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.displayVideo360AdvertiserLinkProposals.get"),
      field: "gaDisplayVideo360AdvertiserLinkProposal",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/displayVideo360AdvertiserLinkProposals/{proposal}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.displayVideo360AdvertiserLinkProposal),
      scopes: .analyticsReadonly,
      summary: "Lookup for a single DisplayVideo360AdvertiserLinkProposal."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.displayVideo360AdvertiserLinkProposals.list"),
      field: "gaDisplayVideo360AdvertiserLinkProposals",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/displayVideo360AdvertiserLinkProposals",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(
        collection: "displayVideo360AdvertiserLinkProposals",
        GAAlphaModels.displayVideo360AdvertiserLinkProposal
      ),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists DisplayVideo360AdvertiserLinkProposals on a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.searchAds360Links.get"),
      field: "gaSearchAds360Link",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("properties/{property}/searchAds360Links/{link}"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaModels.searchAds360Link),
      scopes: .analyticsReadonly,
      summary: "Look up a single SearchAds360Link."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.searchAds360Links.list"),
      field: "gaSearchAds360Links",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/searchAds360Links",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "searchAds360Links", GAAlphaModels.searchAds360Link),
      scopes: .analyticsReadonly,
      maximumPageSize: 200,
      summary: "Lists all SearchAds360Links on a property."
    )
  ]
}
