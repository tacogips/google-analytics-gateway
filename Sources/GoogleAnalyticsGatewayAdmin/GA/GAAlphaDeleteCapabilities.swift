import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1alpha deletes.
///
/// They carry the same contract as the v1beta deletes in
/// `GADeleteCapabilities`: the resource name is supplied twice, once bound into
/// `/v1alpha/{name}` and once as a `confirmName` echo the planner checks against
/// the same validated value, so a delete can only ever remove the resource the
/// caller named on purpose. Every one of them answers `200` with an empty body,
/// so the confirmation is read back from the validated request.
///
/// Two scopes are in play. The access-binding deletes remove a person's access
/// rather than a configuration resource, and Google gates them behind
/// `analytics.manage.users`; everything else here takes `analytics.edit`.
enum GAAlphaDeleteCapabilities {
  private static let property = "properties/{property}"
  private static let dataStream = "properties/{property}/dataStreams/{dataStream}"

  static let accountAccessBinding = "accounts/{account}/accessBindings/{accessBinding}"
  static let propertyAccessBinding = "properties/{property}/accessBindings/{accessBinding}"

  static let all: [CapabilityDefinition] = [
    delete(
      id: "ga.accounts.accessBindings.delete",
      field: "gaDeleteAccountAccessBinding",
      pattern: accountAccessBinding,
      scopes: .analyticsManageUsers,
      summary: "Deletes an access binding on an account or property."
    ),

    delete(
      id: "ga.properties.accessBindings.delete",
      field: "gaDeletePropertyAccessBinding",
      pattern: propertyAccessBinding,
      scopes: .analyticsManageUsers,
      summary: "Deletes an access binding on an account or property."
    ),

    delete(
      id: "ga.adSenseLinks.delete",
      field: "gaDeleteAdSenseLink",
      pattern: "\(property)/adSenseLinks/{adSenseLink}",
      summary: "Deletes an AdSenseLink."
    ),

    delete(
      id: "ga.bigQueryLinks.delete",
      field: "gaDeleteBigQueryLink",
      pattern: "\(property)/bigQueryLinks/{bigQueryLink}",
      summary: "Deletes a BigQueryLink on a property."
    ),

    delete(
      id: "ga.calculatedMetrics.delete",
      field: "gaDeleteCalculatedMetric",
      pattern: "\(property)/calculatedMetrics/{calculatedMetric}",
      summary: "Deletes a CalculatedMetric on a property."
    ),

    delete(
      id: "ga.channelGroups.delete",
      field: "gaDeleteChannelGroup",
      pattern: "\(property)/channelGroups/{channelGroup}",
      summary: "Deletes a ChannelGroup on a property."
    ),

    delete(
      id: "ga.eventCreateRules.delete",
      field: "gaDeleteEventCreateRule",
      pattern: "\(dataStream)/eventCreateRules/{rule}",
      summary: "Deletes an EventCreateRule."
    ),

    delete(
      id: "ga.eventEditRules.delete",
      field: "gaDeleteEventEditRule",
      pattern: "\(dataStream)/eventEditRules/{rule}",
      summary: "Deletes an EventEditRule."
    ),

    delete(
      id: "ga.sKAdNetworkConversionValueSchema.delete",
      field: "gaDeleteSKAdNetworkConversionValueSchema",
      pattern: "\(dataStream)/sKAdNetworkConversionValueSchema/{schema}",
      summary: "Deletes target SKAdNetworkConversionValueSchema."
    ),

    delete(
      id: "ga.displayVideo360AdvertiserLinkProposals.delete",
      field: "gaDeleteDisplayVideo360AdvertiserLinkProposal",
      pattern: "\(property)/displayVideo360AdvertiserLinkProposals/{proposal}",
      summary: "Deletes a DisplayVideo360AdvertiserLinkProposal on a property. This can only be "
        + "used on cancelled proposals.",
      guidance: "Google refuses a proposal that has not been cancelled; withdraw or cancel the "
        + "proposal before deleting it."
    ),

    delete(
      id: "ga.displayVideo360AdvertiserLinks.delete",
      field: "gaDeleteDisplayVideo360AdvertiserLink",
      pattern: "\(property)/displayVideo360AdvertiserLinks/{link}",
      summary: "Deletes a DisplayVideo360AdvertiserLink on a property."
    ),

    delete(
      id: "ga.expandedDataSets.delete",
      field: "gaDeleteExpandedDataSet",
      pattern: "\(property)/expandedDataSets/{expandedDataSet}",
      summary: "Deletes a ExpandedDataSet on a property."
    ),

    delete(
      id: "ga.reportingDataAnnotations.delete",
      field: "gaDeleteReportingDataAnnotation",
      pattern: "\(property)/reportingDataAnnotations/{annotation}",
      summary: "Deletes a Reporting Data Annotation."
    ),

    delete(
      id: "ga.rollupPropertySourceLinks.delete",
      field: "gaDeleteRollupPropertySourceLink",
      pattern: "\(property)/rollupPropertySourceLinks/{link}",
      summary: "Deletes a roll-up property source link.",
      guidance: "Only a roll-up property has source links, so Google refuses this call on a "
        + "property of any other type."
    ),

    delete(
      id: "ga.searchAds360Links.delete",
      field: "gaDeleteSearchAds360Link",
      pattern: "\(property)/searchAds360Links/{link}",
      summary: "Deletes a SearchAds360Link on a property."
    ),

    delete(
      id: "ga.subpropertyEventFilters.delete",
      field: "gaDeleteSubpropertyEventFilter",
      pattern: "\(property)/subpropertyEventFilters/{filter}",
      summary: "Deletes a subproperty event filter."
    )
  ]

  /// Every v1alpha delete addresses `/v1alpha/{name}` and differs only in the
  /// shape of the name and the scope Google gates it behind, so one builder
  /// keeps the confirmation contract identical across all sixteen.
  private static func delete(
    id: String,
    field: String,
    pattern: String,
    scopes: ScopeRequirement = .analyticsEdit,
    summary: String,
    guidance: String? = nil
  ) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .delete,
      method: .delete,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(pattern), .path("name"), required: true),
        ArgumentDefinition("confirmName", .resourceName(pattern), .confirm("name"), required: true)
      ],
      result: .deletion,
      scopes: scopes,
      summary: summary,
      upstreamRejectionGuidance: guidance
    )
  }
}
