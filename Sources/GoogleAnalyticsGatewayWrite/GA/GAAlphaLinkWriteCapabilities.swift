import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1alpha mutations for the linked-product resources that the
/// v1beta surface does not expose: AdSense, BigQuery, Display & Video 360,
/// Search Ads 360, and the roll-up property source links.
///
/// An AdSense link and a roll-up property source link have no patch method —
/// every field Google accepts on them is immutable, so they are created or
/// deleted rather than edited. A Display & Video 360 link may also arrive as a
/// proposal, which is approved or cancelled instead of patched.
enum GAAlphaLinkWriteCapabilities {
  private static let property = "properties/{property}"
  private static let bigQueryLink = "properties/{property}/bigQueryLinks/{bigQueryLink}"
  private static let displayVideo360AdvertiserLink =
    "properties/{property}/displayVideo360AdvertiserLinks/{displayVideo360AdvertiserLink}"
  private static let displayVideo360AdvertiserLinkProposal =
    "properties/{property}/displayVideo360AdvertiserLinkProposals/"
    + "{displayVideo360AdvertiserLinkProposal}"
  private static let searchAds360Link = "properties/{property}/searchAds360Links/{searchAds360Link}"

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.adSenseLinks.create"),
      field: "gaCreateAdSenseLink",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/adSenseLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "adSenseLink",
          .inputObject(GAAlphaWriteInputs.adSenseLinkCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "adSenseLink", GAAlphaModels.adSenseLink),
      scopes: .analyticsEdit,
      summary: "Creates an AdSenseLink.",
      upstreamRejectionGuidance: "Linking requires access to the AdSense ad client as well as to "
        + "the property, and an ad client can be linked to one property at a time."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.bigQueryLinks.create"),
      field: "gaCreateBigQueryLink",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/bigQueryLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "bigQueryLink",
          .inputObject(GAAlphaWriteInputs.bigQueryLinkCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "bigQueryLink", GAAlphaModels.bigQueryLink),
      scopes: .analyticsEdit,
      summary: "Creates a BigQueryLink.",
      upstreamRejectionGuidance: "The credential must be able to create datasets in the named Cloud "
        + "project, the dataset location must be one BigQuery supports, and streaming export is "
        + "available to Analytics 360 properties only."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.bigQueryLinks.update"),
      field: "gaUpdateBigQueryLink",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(bigQueryLink), .path("name"), required: true),
        ArgumentDefinition(
          "bigQueryLink",
          .inputObject(GAAlphaWriteInputs.bigQueryLinkUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "bigQueryLink", GAAlphaModels.bigQueryLink),
      scopes: .analyticsEdit,
      summary: "Updates a BigQueryLink on a property.",
      upstreamRejectionGuidance: "The linked Cloud project and the dataset location are immutable; "
        + "naming either in the update mask is refused."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.displayVideo360AdvertiserLinks.create"),
      field: "gaCreateDisplayVideo360AdvertiserLink",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/displayVideo360AdvertiserLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "displayVideo360AdvertiserLink",
          .inputObject(GAAlphaWriteInputs.displayVideo360AdvertiserLinkCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(
        field: "displayVideo360AdvertiserLink",
        GAAlphaModels.displayVideo360AdvertiserLink
      ),
      scopes: .analyticsEdit,
      summary: "Creates a DisplayVideo360AdvertiserLink.",
      upstreamRejectionGuidance: "Creating the link directly requires administrative access to the "
        + "Display & Video 360 advertiser; without it, propose the link instead. Cost data sharing "
        + "can only be enabled when campaign data sharing is enabled."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.displayVideo360AdvertiserLinks.update"),
      field: "gaUpdateDisplayVideo360AdvertiserLink",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(displayVideo360AdvertiserLink),
          .path("name"),
          required: true
        ),
        ArgumentDefinition(
          "displayVideo360AdvertiserLink",
          .inputObject(GAAlphaWriteInputs.displayVideo360AdvertiserLinkUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(
        field: "displayVideo360AdvertiserLink",
        GAAlphaModels.displayVideo360AdvertiserLink
      ),
      scopes: .analyticsEdit,
      summary: "Updates a DisplayVideo360AdvertiserLink on a property.",
      upstreamRejectionGuidance: "After the link exists, campaign and cost data sharing can only be "
        + "changed from Display & Video 360, so personalized advertising is the only field this "
        + "method accepts in the update mask."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.displayVideo360AdvertiserLinkProposals.create"),
      field: "gaCreateDisplayVideo360AdvertiserLinkProposal",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/displayVideo360AdvertiserLinkProposals",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "displayVideo360AdvertiserLinkProposal",
          .inputObject(GAAlphaWriteInputs.displayVideo360LinkProposalCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(
        field: "displayVideo360AdvertiserLinkProposal",
        GAAlphaModels.displayVideo360AdvertiserLinkProposal
      ),
      scopes: .analyticsEdit,
      summary: "Creates a DisplayVideo360AdvertiserLinkProposal.",
      upstreamRejectionGuidance: "The validation email must belong to an admin on the target "
        + "Display & Video 360 advertiser; a proposal for an advertiser the credential already "
        + "administers is refused in favour of creating the link directly."
    ),

    // Approving consumes the proposal and produces a link, so the response is
    // the link rather than the proposal; the proposal's own name is the `name`
    // argument the planner validated before the call.
    CapabilityDefinition(
      id: CapabilityID("ga.displayVideo360AdvertiserLinkProposals.approve"),
      field: "gaApproveDisplayVideo360AdvertiserLinkProposal",
      tier: .writer,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}:approve",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(displayVideo360AdvertiserLinkProposal),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaWriteModels.approvedDisplayVideo360AdvertiserLink),
      scopes: .analyticsEdit,
      summary: "Approves a DisplayVideo360AdvertiserLinkProposal, converting it into a link.",
      upstreamRejectionGuidance: "Only a proposal awaiting review from Google Analytics can be "
        + "approved; one that originated in Analytics, or that has been withdrawn, declined, or "
        + "has expired, is refused."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.displayVideo360AdvertiserLinkProposals.cancel"),
      field: "gaCancelDisplayVideo360AdvertiserLinkProposal",
      tier: .writer,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}:cancel",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(displayVideo360AdvertiserLinkProposal),
          .path("name"),
          required: true
        )
      ],
      result: .payload(
        field: "displayVideo360AdvertiserLinkProposal",
        GAAlphaModels.displayVideo360AdvertiserLinkProposal
      ),
      scopes: .analyticsEdit,
      summary: "Cancels a DisplayVideo360AdvertiserLinkProposal, withdrawing or declining it.",
      upstreamRejectionGuidance: "Cancelling withdraws a proposal Analytics sent and declines one "
        + "Display & Video 360 sent; a proposal that is no longer awaiting review is refused."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.searchAds360Links.create"),
      field: "gaCreateSearchAds360Link",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/searchAds360Links",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "searchAds360Link",
          .inputObject(GAAlphaWriteInputs.searchAds360LinkCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "searchAds360Link", GAAlphaModels.searchAds360Link),
      scopes: .analyticsEdit,
      summary: "Creates a SearchAds360Link.",
      upstreamRejectionGuidance: "Linking requires administrative access to the Search Ads 360 "
        + "advertiser as well as to the property, and cost data sharing can only be enabled when "
        + "campaign data sharing is enabled."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.searchAds360Links.update"),
      field: "gaUpdateSearchAds360Link",
      tier: .writer,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(searchAds360Link), .path("name"), required: true),
        ArgumentDefinition(
          "searchAds360Link",
          .inputObject(GAAlphaWriteInputs.searchAds360LinkUpdate),
          .bodyRoot,
          required: true
        ),
        GAWriteInputs.updateMask
      ],
      result: .payload(field: "searchAds360Link", GAAlphaModels.searchAds360Link),
      scopes: .analyticsEdit,
      summary: "Updates a SearchAds360Link on a property.",
      upstreamRejectionGuidance: "After the link exists, campaign and cost data sharing can only be "
        + "changed from Search Ads 360, so the update mask may name only personalized advertising "
        + "and site stats sharing."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.rollupPropertySourceLinks.create"),
      field: "gaCreateRollupPropertySourceLink",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/rollupPropertySourceLinks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "rollupPropertySourceLink",
          .inputObject(GAAlphaWriteInputs.rollupPropertySourceLinkCreate),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(
        field: "rollupPropertySourceLink",
        GAAlphaModels.rollupPropertySourceLink
      ),
      scopes: .analyticsEdit,
      summary: "Creates a roll-up property source link.",
      upstreamRejectionGuidance: "The parent must be a roll-up property and the source must be a "
        + "property the credential administers; a source already linked to the roll-up is refused."
    )
  ]
}
