import GoogleAnalyticsGatewayCore

/// GA4 Data API v1alpha reads: the funnel report, the property quota snapshot,
/// and the three asynchronous result resources — audience lists, recurring
/// audience lists, and report tasks — that v1beta does not expose.
///
/// Creating any of the three is a writer-tier mutation; the reader sees the
/// methods that inspect one that already exists and the `:query` methods that
/// retrieve its content. All three follow the same two-step contract as the
/// v1beta audience export: creation starts a long-running job, and the content
/// is only retrievable once the resource reports `ACTIVE`.
enum GAAlphaDataCapabilities {
  private static let property = "properties/{property}"
  private static let audienceList = "properties/{property}/audienceLists/{audienceList}"
  private static let recurringAudienceList =
    "properties/{property}/recurringAudienceLists/{recurringAudienceList}"
  private static let reportTask = "properties/{property}/reportTasks/{reportTask}"

  /// The `:query` methods refuse a resource that is still being built, which
  /// reads as a missing result rather than as a job that has not finished.
  private static let notYetActiveGuidance =
    "The result is produced asynchronously after creation; query it only once the resource "
      + "reports the state ACTIVE."

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.properties.runFunnelReport"),
      field: "gaRunFunnelReport",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{property}:runFunnelReport",
      arguments: [
        ArgumentDefinition("property", .resourceName(property), .path("property"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAAlphaDataInputs.funnelReportRequest),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAAlphaDataModels.funnelReport),
      scopes: .analyticsReadonly,
      summary: "Returns a customized funnel report of your Google Analytics event data.",
      upstreamRejectionGuidance: "A funnel report requires a funnel configuration whose steps "
        + "name dimensions and events this property has collected; Google refuses a funnel that "
        + "names a field the property does not report on."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.getPropertyQuotasSnapshot"),
      field: "gaPropertyQuotasSnapshot",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName("\(property)/propertyQuotasSnapshot"),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaDataModels.propertyQuotasSnapshot),
      scopes: .analyticsReadonly,
      summary: "Get all property quotas organized by quota category for a given property.",
      upstreamRejectionGuidance: "Reading the snapshot itself charges one property quota token "
        + "from the category with the most quota remaining, so it is not free to poll."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.audienceLists.get"),
      field: "gaAudienceList",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(audienceList), .path("name"), required: true)
      ],
      result: .single(GAAlphaDataModels.audienceList),
      scopes: .analyticsReadonly,
      summary: "Gets configuration metadata about a specific audience list."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.audienceLists.list"),
      field: "gaAudienceLists",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{parent}/audienceLists",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "audienceLists", GAAlphaDataModels.audienceList),
      scopes: .analyticsReadonly,
      maximumPageSize: 1000,
      summary: "Lists all audience lists for a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.audienceLists.query"),
      field: "gaQueryAudienceList",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{name}:query",
      arguments: [
        ArgumentDefinition("name", .resourceName(audienceList), .path("name"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAAlphaDataInputs.audienceListQuery),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAAlphaDataModels.audienceListQueryResult),
      scopes: .analyticsReadonly,
      summary: "Retrieves an audience list of users.",
      upstreamRejectionGuidance: notYetActiveGuidance
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.recurringAudienceLists.get"),
      field: "gaRecurringAudienceList",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition(
          "name",
          .resourceName(recurringAudienceList),
          .path("name"),
          required: true
        )
      ],
      result: .single(GAAlphaDataModels.recurringAudienceList),
      scopes: .analyticsReadonly,
      summary: "Gets configuration metadata about a specific recurring audience list."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.recurringAudienceLists.list"),
      field: "gaRecurringAudienceLists",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{parent}/recurringAudienceLists",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(
        collection: "recurringAudienceLists",
        GAAlphaDataModels.recurringAudienceList
      ),
      scopes: .analyticsReadonly,
      maximumPageSize: 1000,
      summary: "Lists all recurring audience lists for a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.reportTasks.get"),
      field: "gaReportTask",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(reportTask), .path("name"), required: true)
      ],
      result: .single(GAAlphaDataModels.reportTask),
      scopes: .analyticsReadonly,
      summary: "Gets report metadata about a specific report task.",
      upstreamRejectionGuidance: "A report task is retained for 72 hours after creation; after "
        + "that Google no longer knows the name."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.reportTasks.list"),
      field: "gaReportTasks",
      tier: .reader,
      operationClass: .read,
      method: .get,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{parent}/reportTasks",
      arguments: [
        ArgumentDefinition("parent", .resourceName(property), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      // Google documents no maximum for this page size, unlike the two audience
      // list methods, so the registry's undocumented-cap default applies.
      result: .connection(collection: "reportTasks", GAAlphaDataModels.reportTask),
      scopes: .analyticsReadonly,
      maximumPageSize: 1000,
      summary: "Lists all report tasks for a property."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.reportTasks.query"),
      field: "gaQueryReportTask",
      tier: .reader,
      operationClass: .read,
      method: .post,
      service: .analyticsDataV1Alpha,
      pathTemplate: "/v1alpha/{name}:query",
      arguments: [
        ArgumentDefinition("name", .resourceName(reportTask), .path("name"), required: true),
        ArgumentDefinition(
          "request",
          .inputObject(GAAlphaDataInputs.reportTaskQuery),
          .bodyRoot,
          required: true
        )
      ],
      result: .single(GAAlphaDataModels.reportTaskQueryResult),
      scopes: .analyticsReadonly,
      summary: "Retrieves a report task's content.",
      upstreamRejectionGuidance: notYetActiveGuidance
    )
  ]
}
