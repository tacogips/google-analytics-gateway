import GoogleAnalyticsGatewayCore

/// Request bodies for the GA4 read methods that POST a report specification.
///
/// Each shape names the fields Google documents for the method's request
/// message, minus the resource name the route already carries. The common
/// selectors — date ranges, dimensions, metrics, limit, offset — are typed, so
/// a misspelled key is a local validation error rather than an upstream 400.
/// Three families of subtree stay `.json` on purpose:
///
/// - `dimensionFilter` and `metricFilter` are `FilterExpression`, which is
///   directly recursive through `andGroup`, `orGroup`, and `notExpression`.
///   An `InputObjectShape` cannot describe a self-referencing type without
///   bottoming out at some arbitrary depth.
/// - `orderBys`, `cohortSpec`, `comparisons`, and `dimensionExpression` are
///   one-of trees whose branches Google extends independently; a fixed shape
///   would reject a document the API accepts.
/// - Everything else is typed.
///
/// Every field binds `.bodyJSON` with its upstream spelling, which is both what
/// the request builder reads for the JSON key and what the registry requires of
/// any `.json` value: an unvalidated document may travel in a request body and
/// nowhere else.
public enum GAReportInputs {

  // MARK: - Shared enumerations

  public static let metricAggregations = ArgumentValueType.enumerationList(
    "GAMetricAggregation",
    ["METRIC_AGGREGATION_UNSPECIFIED", "TOTAL", "MINIMUM", "MAXIMUM", "COUNT"]
  )

  public static let compatibilityFilter = ArgumentValueType.enumeration(
    "GACompatibilityFilter",
    ["COMPATIBILITY_UNSPECIFIED", "COMPATIBLE", "INCOMPATIBLE"]
  )

  public static let changeHistoryAction = ArgumentValueType.enumerationList(
    "GAChangeHistoryAction",
    ["ACTION_TYPE_UNSPECIFIED", "CREATED", "UPDATED", "DELETED"]
  )

  public static let changeHistoryResourceType = ArgumentValueType.enumerationList(
    "GAChangeHistoryResourceType",
    [
      "CHANGE_HISTORY_RESOURCE_TYPE_UNSPECIFIED",
      "ACCOUNT",
      "PROPERTY",
      "FIREBASE_LINK",
      "GOOGLE_ADS_LINK",
      "GOOGLE_SIGNALS_SETTINGS",
      "CONVERSION_EVENT",
      "MEASUREMENT_PROTOCOL_SECRET",
      "CUSTOM_DIMENSION",
      "CUSTOM_METRIC",
      "DATA_RETENTION_SETTINGS",
      "DISPLAY_VIDEO_360_ADVERTISER_LINK",
      "DISPLAY_VIDEO_360_ADVERTISER_LINK_PROPOSAL",
      "DATA_STREAM",
      "ATTRIBUTION_SETTINGS"
    ]
  )

  // MARK: - Data API selectors

  public static let dateRange = InputObjectShape(
    typeName: "GADateRangeInput",
    fields: [
      ArgumentDefinition("startDate", .string, .bodyJSON("startDate"), required: true),
      ArgumentDefinition("endDate", .string, .bodyJSON("endDate"), required: true),
      ArgumentDefinition("name", .string, .bodyJSON("name"))
    ]
  )

  public static let dimension = InputObjectShape(
    typeName: "GADimensionInput",
    fields: [
      ArgumentDefinition("name", .string, .bodyJSON("name"), required: true),
      ArgumentDefinition("dimensionExpression", .json, .bodyJSON("dimensionExpression"))
    ]
  )

  public static let metric = InputObjectShape(
    typeName: "GAMetricInput",
    fields: [
      ArgumentDefinition("name", .string, .bodyJSON("name"), required: true),
      ArgumentDefinition("expression", .string, .bodyJSON("expression")),
      ArgumentDefinition("invisible", .boolean, .bodyJSON("invisible"))
    ]
  )

  public static let minuteRange = InputObjectShape(
    typeName: "GAMinuteRangeInput",
    fields: [
      ArgumentDefinition("startMinutesAgo", .integer, .bodyJSON("startMinutesAgo")),
      ArgumentDefinition("endMinutesAgo", .integer, .bodyJSON("endMinutesAgo")),
      ArgumentDefinition("name", .string, .bodyJSON("name"))
    ]
  )

  public static let pivot = InputObjectShape(
    typeName: "GAPivotInput",
    fields: [
      ArgumentDefinition("fieldNames", .stringList, .bodyJSON("fieldNames"), required: true),
      ArgumentDefinition("orderBys", .json, .bodyJSON("orderBys")),
      ArgumentDefinition("offset", .integer, .bodyJSON("offset")),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit")),
      ArgumentDefinition("metricAggregations", metricAggregations, .bodyJSON("metricAggregations"))
    ]
  )

  // MARK: - Data API request bodies

  public static let reportRequest = InputObjectShape(
    typeName: "GAReportRequestInput",
    fields: [
      ArgumentDefinition("dateRanges", .inputObjectList(dateRange), .bodyJSON("dateRanges")),
      ArgumentDefinition("dimensions", .inputObjectList(dimension), .bodyJSON("dimensions")),
      ArgumentDefinition("metrics", .inputObjectList(metric), .bodyJSON("metrics")),
      ArgumentDefinition("dimensionFilter", .json, .bodyJSON("dimensionFilter")),
      ArgumentDefinition("metricFilter", .json, .bodyJSON("metricFilter")),
      ArgumentDefinition("orderBys", .json, .bodyJSON("orderBys")),
      ArgumentDefinition("comparisons", .json, .bodyJSON("comparisons")),
      ArgumentDefinition("cohortSpec", .json, .bodyJSON("cohortSpec")),
      ArgumentDefinition("offset", .integer, .bodyJSON("offset")),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit")),
      ArgumentDefinition("metricAggregations", metricAggregations, .bodyJSON("metricAggregations")),
      ArgumentDefinition("currencyCode", .string, .bodyJSON("currencyCode")),
      ArgumentDefinition("keepEmptyRows", .boolean, .bodyJSON("keepEmptyRows")),
      ArgumentDefinition("returnPropertyQuota", .boolean, .bodyJSON("returnPropertyQuota"))
    ]
  )

  public static let pivotReportRequest = InputObjectShape(
    typeName: "GAPivotReportRequestInput",
    fields: [
      ArgumentDefinition("dateRanges", .inputObjectList(dateRange), .bodyJSON("dateRanges")),
      ArgumentDefinition("dimensions", .inputObjectList(dimension), .bodyJSON("dimensions")),
      ArgumentDefinition("metrics", .inputObjectList(metric), .bodyJSON("metrics")),
      ArgumentDefinition("pivots", .inputObjectList(pivot), .bodyJSON("pivots")),
      ArgumentDefinition("dimensionFilter", .json, .bodyJSON("dimensionFilter")),
      ArgumentDefinition("metricFilter", .json, .bodyJSON("metricFilter")),
      ArgumentDefinition("comparisons", .json, .bodyJSON("comparisons")),
      ArgumentDefinition("cohortSpec", .json, .bodyJSON("cohortSpec")),
      ArgumentDefinition("currencyCode", .string, .bodyJSON("currencyCode")),
      ArgumentDefinition("keepEmptyRows", .boolean, .bodyJSON("keepEmptyRows")),
      ArgumentDefinition("returnPropertyQuota", .boolean, .bodyJSON("returnPropertyQuota"))
    ]
  )

  public static let batchReportRequest = InputObjectShape(
    typeName: "GABatchReportRequestInput",
    fields: [
      ArgumentDefinition(
        "requests",
        .inputObjectList(reportRequest),
        .bodyJSON("requests"),
        required: true,
        maximumCount: 5
      )
    ]
  )

  public static let batchPivotReportRequest = InputObjectShape(
    typeName: "GABatchPivotReportRequestInput",
    fields: [
      ArgumentDefinition(
        "requests",
        .inputObjectList(pivotReportRequest),
        .bodyJSON("requests"),
        required: true,
        maximumCount: 5
      )
    ]
  )

  public static let realtimeReportRequest = InputObjectShape(
    typeName: "GARealtimeReportRequestInput",
    fields: [
      ArgumentDefinition("dimensions", .inputObjectList(dimension), .bodyJSON("dimensions")),
      ArgumentDefinition("metrics", .inputObjectList(metric), .bodyJSON("metrics")),
      ArgumentDefinition("minuteRanges", .inputObjectList(minuteRange), .bodyJSON("minuteRanges")),
      ArgumentDefinition("dimensionFilter", .json, .bodyJSON("dimensionFilter")),
      ArgumentDefinition("metricFilter", .json, .bodyJSON("metricFilter")),
      ArgumentDefinition("orderBys", .json, .bodyJSON("orderBys")),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit")),
      ArgumentDefinition("metricAggregations", metricAggregations, .bodyJSON("metricAggregations")),
      ArgumentDefinition("returnPropertyQuota", .boolean, .bodyJSON("returnPropertyQuota"))
    ]
  )

  public static let compatibilityRequest = InputObjectShape(
    typeName: "GACompatibilityRequestInput",
    fields: [
      ArgumentDefinition("dimensions", .inputObjectList(dimension), .bodyJSON("dimensions")),
      ArgumentDefinition("metrics", .inputObjectList(metric), .bodyJSON("metrics")),
      ArgumentDefinition("dimensionFilter", .json, .bodyJSON("dimensionFilter")),
      ArgumentDefinition("metricFilter", .json, .bodyJSON("metricFilter")),
      ArgumentDefinition("compatibilityFilter", compatibilityFilter, .bodyJSON("compatibilityFilter"))
    ]
  )

  public static let audienceExportQuery = InputObjectShape(
    typeName: "GAAudienceExportQueryInput",
    fields: [
      ArgumentDefinition("offset", .integer, .bodyJSON("offset")),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit"))
    ]
  )

  // MARK: - Admin API request bodies

  public static let accessDateRange = InputObjectShape(
    typeName: "GAAccessDateRangeInput",
    fields: [
      ArgumentDefinition("startDate", .string, .bodyJSON("startDate"), required: true),
      ArgumentDefinition("endDate", .string, .bodyJSON("endDate"), required: true)
    ]
  )

  public static let accessDimension = InputObjectShape(
    typeName: "GAAccessDimensionInput",
    fields: [
      ArgumentDefinition("dimensionName", .string, .bodyJSON("dimensionName"), required: true)
    ]
  )

  public static let accessMetric = InputObjectShape(
    typeName: "GAAccessMetricInput",
    fields: [
      ArgumentDefinition("metricName", .string, .bodyJSON("metricName"), required: true)
    ]
  )

  public static let accessReportRequest = InputObjectShape(
    typeName: "GAAccessReportRequestInput",
    fields: [
      ArgumentDefinition(
        "dateRanges",
        .inputObjectList(accessDateRange),
        .bodyJSON("dateRanges"),
        maximumCount: 2
      ),
      ArgumentDefinition("dimensions", .inputObjectList(accessDimension), .bodyJSON("dimensions"), maximumCount: 9),
      ArgumentDefinition("metrics", .inputObjectList(accessMetric), .bodyJSON("metrics"), maximumCount: 10),
      ArgumentDefinition("dimensionFilter", .json, .bodyJSON("dimensionFilter")),
      ArgumentDefinition("metricFilter", .json, .bodyJSON("metricFilter")),
      ArgumentDefinition("orderBys", .json, .bodyJSON("orderBys")),
      ArgumentDefinition("offset", .integer, .bodyJSON("offset")),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit")),
      ArgumentDefinition("timeZone", .string, .bodyJSON("timeZone")),
      ArgumentDefinition("expandGroups", .boolean, .bodyJSON("expandGroups")),
      ArgumentDefinition("includeAllUsers", .boolean, .bodyJSON("includeAllUsers")),
      ArgumentDefinition("returnEntityQuota", .boolean, .bodyJSON("returnEntityQuota"))
    ]
  )

  /// `searchChangeHistoryEvents` carries its page size and page token in the
  /// request body rather than the query string, so they are declared here
  /// instead of through the shared `.page` argument binding, which writes query
  /// parameters this method would ignore.
  public static let changeHistorySearchRequest = InputObjectShape(
    typeName: "GAChangeHistorySearchInput",
    fields: [
      ArgumentDefinition(
        "property",
        .resourceName("properties/{property}"),
        .bodyJSON("property")
      ),
      ArgumentDefinition("resourceType", changeHistoryResourceType, .bodyJSON("resourceType")),
      ArgumentDefinition("action", changeHistoryAction, .bodyJSON("action")),
      ArgumentDefinition("actorEmail", .stringList, .bodyJSON("actorEmail")),
      ArgumentDefinition("earliestChangeTime", .string, .bodyJSON("earliestChangeTime")),
      ArgumentDefinition("latestChangeTime", .string, .bodyJSON("latestChangeTime")),
      ArgumentDefinition("pageSize", .integer, .bodyJSON("pageSize")),
      ArgumentDefinition("pageToken", .string, .bodyJSON("pageToken"))
    ]
  )
}
