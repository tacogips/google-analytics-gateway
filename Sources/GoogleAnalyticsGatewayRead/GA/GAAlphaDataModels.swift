import GoogleAnalyticsGatewayCore

/// The stable output shapes of the GA4 resources that only the Data API
/// v1alpha surface exposes: funnel reports, report tasks, audience lists,
/// recurring audience lists, and the property quota snapshot.
///
/// They live beside `GAModels` for the same reason `GAAlphaModels` does: every
/// shape here is reachable only through `/v1alpha` on
/// `analyticsdata.googleapis.com`, a surface Google explicitly ships at alpha
/// stability "with the intention of gathering feedback on syntax and
/// capabilities before entering beta". Keeping the alpha data shapes in their
/// own value makes that boundary visible at the call site and keeps a change
/// Google makes here from touching the v1beta report types.
///
/// Fields are typed from the Data API v1alpha discovery document. The column
/// headers of every report are typed and reuse `GAModels.dimensionHeader` and
/// `GAModels.metricHeader`, because a header is a fixed pair of scalars and a
/// caller reads the grid positionally against it. The grids themselves — `rows`,
/// `totals`, `maximums`, `minimums`, `audienceRows` — are `Row` lists whose
/// width is the request's dimension and metric count, so they travel verbatim
/// exactly as they do in `GAModels.report`. An `int64` field is `.string`
/// because Google encodes it as a JSON string, not a number.
public enum GAAlphaDataModels {

  // MARK: - Property quotas

  public static let quotaStatus = ModelShape(
    typeName: "GAQuotaStatus",
    fields: [
      ModelField("consumed", .integer),
      ModelField("remaining", .integer)
    ]
  )

  /// `PropertyQuota`. The v1beta report shapes carry this envelope as `.json`
  /// because it is incidental there — a report returns it only when the request
  /// asked for it. On the alpha surface it is the whole subject of
  /// `getPropertyQuotasSnapshot`, so it is typed once here and reused by the
  /// funnel report rather than being modelled twice at different fidelities.
  public static let propertyQuota = ModelShape(
    typeName: "GAPropertyQuota",
    fields: [
      ModelField("tokensPerDay", .object(quotaStatus)),
      ModelField("tokensPerHour", .object(quotaStatus)),
      ModelField("concurrentRequests", .object(quotaStatus)),
      ModelField("serverErrorsPerProjectPerHour", .object(quotaStatus)),
      ModelField("potentiallyThresholdedRequestsPerHour", .object(quotaStatus)),
      ModelField("tokensPerProjectPerHour", .object(quotaStatus))
    ]
  )

  public static let propertyQuotasSnapshot = ModelShape(
    typeName: "GAPropertyQuotasSnapshot",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("corePropertyQuota", .object(propertyQuota)),
      ModelField("realtimePropertyQuota", .object(propertyQuota)),
      ModelField("funnelPropertyQuota", .object(propertyQuota))
    ]
  )

  // MARK: - Funnel reports

  /// `samplesReadCount` and `samplingSpaceSize` are `int64`, which Google
  /// encodes as decimal strings.
  public static let samplingMetadata = ModelShape(
    typeName: "GASamplingMetadata",
    fields: [
      ModelField("samplesReadCount", .string),
      ModelField("samplingSpaceSize", .string)
    ]
  )

  public static let funnelResponseMetadata = ModelShape(
    typeName: "GAFunnelResponseMetadata",
    fields: [
      ModelField("samplingMetadatas", .objectList(samplingMetadata))
    ]
  )

  public static let funnelSubReport = ModelShape(
    typeName: "GAFunnelSubReport",
    fields: [
      ModelField("dimensionHeaders", .objectList(GAModels.dimensionHeader)),
      ModelField("metricHeaders", .objectList(GAModels.metricHeader)),
      ModelField("rows", .json),
      ModelField("metadata", .object(funnelResponseMetadata))
    ]
  )

  /// `RunFunnelReportResponse`. The two sub reports are different combinations
  /// of dimensions and metrics over the same funnel, and Google always returns
  /// both; the visualization is present only when the request named a
  /// `funnelVisualizationType`.
  public static let funnelReport = ModelShape(
    typeName: "GAFunnelReport",
    fields: [
      ModelField("kind", .string),
      ModelField("funnelTable", .object(funnelSubReport)),
      ModelField("funnelVisualization", .object(funnelSubReport)),
      ModelField("propertyQuota", .object(propertyQuota))
    ]
  )

  // MARK: - Report tasks

  /// The `Dimension`, `Metric`, and `DateRange` a report task echoes back are
  /// the same selectors the request carried, so they are typed here rather than
  /// left opaque. `dimensionExpression` is the one open branch: it is a one-of
  /// tree whose cases Google extends independently.
  public static let dimensionSpec = ModelShape(
    typeName: "GADimensionSpec",
    fields: [
      ModelField("name", .string),
      ModelField("dimensionExpression", .json)
    ]
  )

  public static let metricSpec = ModelShape(
    typeName: "GAMetricSpec",
    fields: [
      ModelField("name", .string),
      ModelField("expression", .string),
      ModelField("invisible", .boolean)
    ]
  )

  public static let dateRangeSpec = ModelShape(
    typeName: "GADateRangeSpec",
    fields: [
      ModelField("startDate", .date),
      ModelField("endDate", .date),
      ModelField("name", .string)
    ]
  )

  /// `ReportDefinition`. `dimensionFilter` and `metricFilter` are
  /// `FilterExpression`, which is directly recursive through `andGroup`,
  /// `orGroup`, and `notExpression`; `orderBys` and `cohortSpec` are one-of
  /// trees. None of the four can be held by a fixed shape, so they travel
  /// verbatim. `limit` and `offset` are `int64` strings.
  public static let reportDefinition = ModelShape(
    typeName: "GAReportDefinition",
    fields: [
      ModelField("dimensions", .objectList(dimensionSpec)),
      ModelField("metrics", .objectList(metricSpec)),
      ModelField("dateRanges", .objectList(dateRangeSpec)),
      ModelField("dimensionFilter", .json),
      ModelField("metricFilter", .json),
      ModelField("orderBys", .json),
      ModelField("cohortSpec", .json),
      ModelField("offset", .string),
      ModelField("limit", .string),
      ModelField("metricAggregations", .stringList),
      ModelField("currencyCode", .string),
      ModelField("keepEmptyRows", .boolean),
      ModelField("samplingLevel", .string)
    ]
  )

  public static let reportMetadata = ModelShape(
    typeName: "GAReportTaskMetadata",
    fields: [
      ModelField("state", .string),
      ModelField("beginCreatingTime", .dateTime),
      ModelField("creationQuotaTokensCharged", .integer),
      ModelField("taskRowCount", .integer),
      ModelField("totalRowCount", .integer),
      ModelField("errorMessage", .string)
    ]
  )

  public static let reportTask = ModelShape(
    typeName: "GAReportTask",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("reportDefinition", .object(reportDefinition)),
      ModelField("reportMetadata", .object(reportMetadata))
    ]
  )

  /// `QueryReportTaskResponse`. `metadata` is `ResponseMetaData`, the same
  /// reporting envelope `GAModels.report` carries verbatim, so it is projected
  /// the same way here.
  public static let reportTaskQueryResult = ModelShape(
    typeName: "GAReportTaskQueryResult",
    fields: [
      ModelField("dimensionHeaders", .objectList(GAModels.dimensionHeader)),
      ModelField("metricHeaders", .objectList(GAModels.metricHeader)),
      ModelField("rows", .json),
      ModelField("totals", .json),
      ModelField("maximums", .json),
      ModelField("minimums", .json),
      ModelField("rowCount", .integer),
      ModelField("metadata", .json)
    ]
  )

  // MARK: - Audience lists

  /// `WebhookNotification`. The `channelToken` a caller supplies is echoed back
  /// so the webhook receiver can authenticate the notification; it is the
  /// caller's own value, not a credential this gateway issues.
  public static let webhookNotification = ModelShape(
    typeName: "GAWebhookNotification",
    fields: [
      ModelField("uri", .string),
      ModelField("channelToken", .string)
    ]
  )

  /// `AudienceList`, the alpha counterpart of `GAModels.audienceExport`. It
  /// carries two fields the export does not: the webhook configuration, and the
  /// recurring audience list that produced this instance, which is empty for a
  /// list created directly.
  public static let audienceList = ModelShape(
    typeName: "GAAudienceList",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("audience", .resourceName),
      ModelField("audienceDisplayName", .string),
      ModelField("dimensions", .objectList(GAModels.audienceDimension)),
      ModelField("state", .string),
      ModelField("beginCreatingTime", .dateTime),
      ModelField("creationQuotaTokensCharged", .integer),
      ModelField("rowCount", .integer),
      ModelField("errorMessage", .string),
      ModelField("percentageCompleted", .number),
      ModelField("recurringAudienceList", .resourceName),
      ModelField("webhookNotification", .object(webhookNotification))
    ]
  )

  /// `QueryAudienceListResponse`. `audienceRows` is one row per exported user,
  /// keyed positionally to the list's `dimensions`, so it is carried verbatim
  /// like a report grid.
  public static let audienceListQueryResult = ModelShape(
    typeName: "GAAudienceListQueryResult",
    fields: [
      ModelField("audienceList", .object(audienceList)),
      ModelField("audienceRows", .json),
      ModelField("rowCount", .integer)
    ]
  )

  /// `RecurringAudienceList`. `audienceLists` is the list of audience list
  /// resource names produced so far, most recent last, each of which
  /// `gaAudienceList` and `gaQueryAudienceList` accept.
  public static let recurringAudienceList = ModelShape(
    typeName: "GARecurringAudienceList",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("audience", .resourceName),
      ModelField("audienceDisplayName", .string),
      ModelField("dimensions", .objectList(GAModels.audienceDimension)),
      ModelField("activeDaysRemaining", .integer),
      ModelField("audienceLists", .stringList),
      ModelField("webhookNotification", .object(webhookNotification))
    ]
  )
}
