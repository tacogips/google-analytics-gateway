import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Data API v1alpha creates: audience lists, recurring audience lists, and
/// report tasks.
///
/// None of the three has an update or a delete method — a list is a snapshot and
/// a report task expires on its own after 72 hours — so creation is the whole
/// writer surface here, and the results are read back through
/// `GAAlphaDataCapabilities`.
enum GAAlphaDataWriteCapabilities {
  private static let property = "properties/{property}"

  /// The Data API documents `analytics` and `analytics.readonly` as the accepted
  /// scopes for these creates, which is neither of the two shared presets:
  /// `analyticsReadonly` additionally admits `analytics.edit`, a scope this API
  /// does not accept at all, and `analyticsFull` drops the readonly scope Google
  /// does accept here. This is the same pair `gaCreateAudienceExport` states for
  /// the v1beta create, for the same reason: a credential Google would accept is
  /// not refused locally, while the recommendation stays the write-capable scope
  /// rather than a readonly one for what is a mutation.
  private static let dataCreateScopes = ScopeRequirement(
    accepted: [ScopeRequirement.Scope.analytics, ScopeRequirement.Scope.analyticsReadonly],
    recommended: ScopeRequirement.Scope.analytics
  )

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.audienceLists.create"),
      field: "gaCreateAudienceList",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{parent}/audienceLists",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "audienceList",
          .inputObject(GAAlphaDataWriteInputs.audienceListCreate),
          .bodyRoot,
          required: true
        )
      ],
      // Creating a list starts a long-running operation, so Google answers with
      // the operation rather than with the list: the list is populated
      // asynchronously and is only queryable once it reports ACTIVE.
      result: .payload(field: "operation", GAAlphaWriteModels.dataOperation),
      scopes: dataCreateScopes,
      summary: "Creates an audience list for later retrieval.",
      upstreamRejectionGuidance: "Creating a list charges audience-export quota tokens and the "
        + "audience must already exist on the property; poll gaAudienceList with the returned "
        + "name until its state is ACTIVE before calling gaQueryAudienceList. A list is a "
        + "snapshot of the audience's membership at creation time, so two lists created on "
        + "different days differ."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.recurringAudienceLists.create"),
      field: "gaCreateRecurringAudienceList",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{parent}/recurringAudienceLists",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "recurringAudienceList",
          .inputObject(GAAlphaDataWriteInputs.recurringAudienceListCreate),
          .bodyRoot,
          required: true
        )
      ],
      // Unlike the other two creates on this surface, Google answers with the
      // resource itself: the recurring list exists immediately and it is the
      // daily audience lists it produces that are built asynchronously.
      result: .payload(
        field: "recurringAudienceList",
        GAAlphaDataModels.recurringAudienceList
      ),
      scopes: dataCreateScopes,
      summary: "Creates a recurring audience list.",
      upstreamRejectionGuidance: "The audience must already exist on the property. A recurring "
        + "list produces one audience list per day for activeDaysRemaining days; read its "
        + "audienceLists field through gaRecurringAudienceList to find the instances it has "
        + "created."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.reportTasks.create"),
      field: "gaCreateReportTask",
      tier: .writer,
      operationClass: .create,
      method: .post,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{parent}/reportTasks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition(
          "reportTask",
          .inputObject(GAAlphaDataWriteInputs.reportTaskCreate),
          .bodyRoot,
          required: true
        )
      ],
      // As with an audience list, the report is formed asynchronously and the
      // create answers with the operation that is forming it.
      result: .payload(field: "operation", GAAlphaWriteModels.dataOperation),
      scopes: dataCreateScopes,
      summary: "Initiates the creation of a report task.",
      upstreamRejectionGuidance: "Creating a report task charges quota tokens, and Google refuses "
        + "a definition whose dimensions and metrics cannot be combined or that names a field "
        + "this property has never collected. Poll gaReportTask with the returned name until its "
        + "state is ACTIVE before calling gaQueryReportTask; a task is retained for 72 hours."
    )
  ]
}
