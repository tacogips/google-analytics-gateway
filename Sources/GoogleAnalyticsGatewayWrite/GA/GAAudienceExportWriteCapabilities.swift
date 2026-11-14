import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Data API v1beta audience export creation.
enum GAAudienceExportWriteCapabilities {
  private static let property = "properties/{property}"

  /// The Data API documents `analytics` and `analytics.readonly` as the accepted
  /// scopes for `CreateAudienceExport`, which is neither of the two shared
  /// presets: `analyticsReadonly` additionally admits `analytics.edit`, a scope
  /// this API does not accept at all, and `analyticsFull` drops the readonly
  /// scope Google does accept here. Stating the documented pair exactly means a
  /// credential Google would accept is not refused locally, while the
  /// recommendation stays the write-capable scope rather than a readonly one for
  /// what is a mutation.
  private static let audienceExportCreateScopes = ScopeRequirement(
    accepted: [ScopeRequirement.Scope.analytics, ScopeRequirement.Scope.analyticsReadonly],
    recommended: ScopeRequirement.Scope.analytics
  )

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.audienceExports.create"),
      field: "gaCreateAudienceExport",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsDataV1Beta,
      pathTemplate: "/v1beta/{parent}/audienceExports",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "audienceExport",
          .inputObject(GAWriteInputs.audienceExportCreate),
          .bodyRoot,
          required: true
        )
      ],
      // Creating an export starts a long-running operation, so Google answers
      // with the operation rather than with the export: the export is populated
      // asynchronously and is only queryable once it reports ACTIVE.
      result: .payload(field: "operation", GAWriteModels.audienceExportOperation),
      scopes: audienceExportCreateScopes,
      summary: "Creates an audience export for later retrieval.",
      upstreamRejectionGuidance: "Creating an export charges audience-export quota tokens and "
        + "the audience must already exist on the property; poll gaAudienceExport with the "
        + "returned name until its state is ACTIVE before calling gaQueryAudienceExport."
    )
  ]
}
