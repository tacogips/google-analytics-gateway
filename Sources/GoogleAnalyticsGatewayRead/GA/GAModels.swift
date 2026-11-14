import GoogleAnalyticsGatewayCore

/// The stable output shapes of every GA4 resource this gateway reads.
///
/// The reader module owns them because a resource has one public shape
/// regardless of which tier returned it: a property read by `gaProperty` and a
/// property returned by `gaUpdateProperty` are the same document, so the writer
/// and admin modules import these values rather than restating them. Restating
/// would let the two drift, and the schema printer keys object types by name —
/// two shapes sharing a name would silently publish whichever the registry
/// happened to visit first.
///
/// Fields are typed from the GA4 Admin v1beta and Data v1beta discovery
/// documents. A subtree is left as `.json` only where Google's own schema is
/// recursive (a report filter expression), a union of unrelated resources (a
/// change-history resource), or an unbounded result grid (report rows) — cases
/// where a fixed shape would either truncate a legitimate response or need
/// editing every time Google adds a key.
public enum GAModels {

  // MARK: - Admin: accounts and properties

  public static let account = ModelShape(
    typeName: "GAAccount",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("createTime", .dateTime),
      ModelField("updateTime", .dateTime),
      ModelField("regionCode", .string),
      ModelField("deleted", .boolean),
      ModelField("gmpOrganization", .string)
    ]
  )

  public static let propertySummary = ModelShape(
    typeName: "GAPropertySummary",
    fields: [
      ModelField("property", .resourceName),
      ModelField("displayName", .string),
      ModelField("propertyType", .string),
      ModelField("parent", .resourceName),
      ModelField("canEdit", .boolean)
    ]
  )

  public static let accountSummary = ModelShape(
    typeName: "GAAccountSummary",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("account", .resourceName),
      ModelField("displayName", .string),
      ModelField("propertySummaries", .objectList(propertySummary))
    ]
  )

  public static let property = ModelShape(
    typeName: "GAProperty",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("propertyType", .string),
      ModelField("parent", .resourceName),
      ModelField("account", .resourceName),
      ModelField("industryCategory", .string),
      ModelField("timeZone", .string),
      ModelField("currencyCode", .string),
      ModelField("serviceLevel", .string),
      ModelField("createTime", .dateTime),
      ModelField("updateTime", .dateTime),
      ModelField("deleteTime", .dateTime),
      ModelField("expireTime", .dateTime)
    ]
  )

  public static let dataRetentionSettings = ModelShape(
    typeName: "GADataRetentionSettings",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("eventDataRetention", .string),
      ModelField("userDataRetention", .string),
      ModelField("resetUserDataOnNewActivity", .boolean)
    ]
  )

  public static let dataSharingSettings = ModelShape(
    typeName: "GADataSharingSettings",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("sharingWithGoogleSupportEnabled", .boolean),
      ModelField("sharingWithGoogleAssignedSalesEnabled", .boolean),
      ModelField("sharingWithGoogleAnySalesEnabled", .boolean),
      ModelField("sharingWithGoogleProductsEnabled", .boolean),
      ModelField("sharingWithOthersEnabled", .boolean)
    ]
  )

  // MARK: - Admin: data streams

  public static let webStreamData = ModelShape(
    typeName: "GAWebStreamData",
    fields: [
      ModelField("measurementId", .string),
      ModelField("firebaseAppId", .string),
      ModelField("defaultUri", .string)
    ]
  )

  public static let androidAppStreamData = ModelShape(
    typeName: "GAAndroidAppStreamData",
    fields: [
      ModelField("packageName", .string),
      ModelField("firebaseAppId", .string)
    ]
  )

  public static let iosAppStreamData = ModelShape(
    typeName: "GAIosAppStreamData",
    fields: [
      ModelField("bundleId", .string),
      ModelField("firebaseAppId", .string)
    ]
  )

  public static let dataStream = ModelShape(
    typeName: "GADataStream",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("type", .string),
      ModelField("createTime", .dateTime),
      ModelField("updateTime", .dateTime),
      ModelField("webStreamData", .object(webStreamData)),
      ModelField("androidAppStreamData", .object(androidAppStreamData)),
      ModelField("iosAppStreamData", .object(iosAppStreamData))
    ]
  )

  /// `secretValue` is the Measurement Protocol API secret itself. It is the
  /// value the caller asked for, so it is projected as read; the gateway's
  /// redaction machinery covers credentials the gateway holds, not resource
  /// content a reader explicitly requested.
  public static let measurementProtocolSecret = ModelShape(
    typeName: "GAMeasurementProtocolSecret",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("secretValue", .string)
    ]
  )

  // MARK: - Admin: custom definitions and events

  public static let customDimension = ModelShape(
    typeName: "GACustomDimension",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("parameterName", .string),
      ModelField("displayName", .string),
      ModelField("description", .string),
      ModelField("scope", .string),
      ModelField("disallowAdsPersonalization", .boolean)
    ]
  )

  public static let customMetric = ModelShape(
    typeName: "GACustomMetric",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("parameterName", .string),
      ModelField("displayName", .string),
      ModelField("description", .string),
      ModelField("measurementUnit", .string),
      ModelField("scope", .string),
      ModelField("restrictedMetricType", .stringList)
    ]
  )

  public static let conversionValue = ModelShape(
    typeName: "GAConversionValue",
    fields: [
      ModelField("value", .number),
      ModelField("currencyCode", .string)
    ]
  )

  public static let conversionEvent = ModelShape(
    typeName: "GAConversionEvent",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("eventName", .string),
      ModelField("createTime", .dateTime),
      ModelField("deletable", .boolean),
      ModelField("custom", .boolean),
      ModelField("countingMethod", .string),
      ModelField("defaultConversionValue", .object(conversionValue))
    ]
  )

  public static let keyEventDefaultValue = ModelShape(
    typeName: "GAKeyEventDefaultValue",
    fields: [
      ModelField("numericValue", .number),
      ModelField("currencyCode", .string)
    ]
  )

  public static let keyEvent = ModelShape(
    typeName: "GAKeyEvent",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("eventName", .string),
      ModelField("createTime", .dateTime),
      ModelField("deletable", .boolean),
      ModelField("custom", .boolean),
      ModelField("countingMethod", .string),
      ModelField("defaultValue", .object(keyEventDefaultValue))
    ]
  )

  // MARK: - Admin: product links

  public static let firebaseLink = ModelShape(
    typeName: "GAFirebaseLink",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("project", .string),
      ModelField("createTime", .dateTime)
    ]
  )

  public static let googleAdsLink = ModelShape(
    typeName: "GAGoogleAdsLink",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("customerId", .string),
      ModelField("canManageClients", .boolean),
      ModelField("adsPersonalizationEnabled", .boolean),
      ModelField("creatorEmailAddress", .string),
      ModelField("createTime", .dateTime),
      ModelField("updateTime", .dateTime)
    ]
  )

  // MARK: - Admin: change history

  /// `resourceBeforeChange` and `resourceAfterChange` are `ChangeHistoryResource`,
  /// a one-of over eight unrelated GA4 resources. Typing it would mean a shape
  /// whose every field is null but one, and a new branch each time Google makes
  /// another resource auditable, so the snapshot travels verbatim.
  public static let changeHistoryChange = ModelShape(
    typeName: "GAChangeHistoryChange",
    fields: [
      ModelField("resource", .resourceName),
      ModelField("action", .string),
      ModelField("resourceBeforeChange", .json),
      ModelField("resourceAfterChange", .json)
    ]
  )

  public static let changeHistoryEvent = ModelShape(
    typeName: "GAChangeHistoryEvent",
    fields: [
      ModelField("id", .string),
      ModelField("changeTime", .dateTime),
      ModelField("actorType", .string),
      ModelField("userActorEmail", .string),
      ModelField("changesFiltered", .boolean),
      ModelField("changes", .objectList(changeHistoryChange))
    ]
  )

  /// `searchChangeHistoryEvents` paginates through its request body rather than
  /// through query parameters, so it cannot be a `.connection`: the page
  /// argument binding writes `pageSize`/`pageToken` into the query string,
  /// which this method ignores. The response is projected whole instead, and
  /// `nextPageToken` is echoed back through the request body to page forward.
  public static let changeHistorySearchResult = ModelShape(
    typeName: "GAChangeHistorySearchResult",
    fields: [
      ModelField("changeHistoryEvents", .objectList(changeHistoryEvent)),
      ModelField("nextPageToken", .string)
    ]
  )

  // MARK: - Admin: access report

  public static let accessDimensionHeader = ModelShape(
    typeName: "GAAccessDimensionHeader",
    fields: [ModelField("dimensionName", .string)]
  )

  public static let accessMetricHeader = ModelShape(
    typeName: "GAAccessMetricHeader",
    fields: [ModelField("metricName", .string)]
  )

  /// Access-report rows are an unbounded grid of `dimensionValues` and
  /// `metricValues` whose meaning is positional against the headers above, so
  /// they are carried verbatim rather than re-shaped into a fixed type.
  public static let accessReport = ModelShape(
    typeName: "GAAccessReport",
    fields: [
      ModelField("dimensionHeaders", .objectList(accessDimensionHeader)),
      ModelField("metricHeaders", .objectList(accessMetricHeader)),
      ModelField("rows", .json),
      ModelField("rowCount", .integer),
      ModelField("quota", .json)
    ]
  )

  // MARK: - Data API: report headers

  public static let dimensionHeader = ModelShape(
    typeName: "GADimensionHeader",
    fields: [ModelField("name", .string)]
  )

  public static let metricHeader = ModelShape(
    typeName: "GAMetricHeader",
    fields: [
      ModelField("name", .string),
      ModelField("type", .string)
    ]
  )

  // MARK: - Data API: reports

  /// Rows, totals, maximums, and minimums are all `Row` grids: their width is
  /// the request's dimension and metric count and their height is the result
  /// size, so they are projected verbatim and read positionally against the
  /// typed headers. `metadata` and `propertyQuota` are nested reporting
  /// envelopes that Google extends independently of this gateway.
  public static let report = ModelShape(
    typeName: "GAReport",
    fields: [
      ModelField("kind", .string),
      ModelField("dimensionHeaders", .objectList(dimensionHeader)),
      ModelField("metricHeaders", .objectList(metricHeader)),
      ModelField("rows", .json),
      ModelField("totals", .json),
      ModelField("maximums", .json),
      ModelField("minimums", .json),
      ModelField("rowCount", .integer),
      ModelField("metadata", .json),
      ModelField("propertyQuota", .json)
    ]
  )

  public static let reportBatch = ModelShape(
    typeName: "GAReportBatch",
    fields: [
      ModelField("kind", .string),
      ModelField("reports", .objectList(report))
    ]
  )

  /// A pivot report's `pivotHeaders` nest one dimension-header list per pivot,
  /// so their depth follows the request rather than the schema.
  public static let pivotReport = ModelShape(
    typeName: "GAPivotReport",
    fields: [
      ModelField("kind", .string),
      ModelField("pivotHeaders", .json),
      ModelField("dimensionHeaders", .objectList(dimensionHeader)),
      ModelField("metricHeaders", .objectList(metricHeader)),
      ModelField("rows", .json),
      ModelField("aggregates", .json),
      ModelField("metadata", .json),
      ModelField("propertyQuota", .json)
    ]
  )

  public static let pivotReportBatch = ModelShape(
    typeName: "GAPivotReportBatch",
    fields: [
      ModelField("kind", .string),
      ModelField("pivotReports", .objectList(pivotReport))
    ]
  )

  public static let realtimeReport = ModelShape(
    typeName: "GARealtimeReport",
    fields: [
      ModelField("kind", .string),
      ModelField("dimensionHeaders", .objectList(dimensionHeader)),
      ModelField("metricHeaders", .objectList(metricHeader)),
      ModelField("rows", .json),
      ModelField("totals", .json),
      ModelField("maximums", .json),
      ModelField("minimums", .json),
      ModelField("rowCount", .integer),
      ModelField("propertyQuota", .json)
    ]
  )

  // MARK: - Data API: metadata and compatibility

  public static let dimensionMetadata = ModelShape(
    typeName: "GADimensionMetadata",
    fields: [
      ModelField("apiName", .string),
      ModelField("uiName", .string),
      ModelField("description", .string),
      ModelField("category", .string),
      ModelField("customDefinition", .boolean),
      ModelField("deprecatedApiNames", .stringList)
    ]
  )

  public static let metricMetadata = ModelShape(
    typeName: "GAMetricMetadata",
    fields: [
      ModelField("apiName", .string),
      ModelField("uiName", .string),
      ModelField("description", .string),
      ModelField("category", .string),
      ModelField("type", .string),
      ModelField("expression", .string),
      ModelField("customDefinition", .boolean),
      ModelField("blockedReasons", .stringList),
      ModelField("deprecatedApiNames", .stringList)
    ]
  )

  public static let comparisonMetadata = ModelShape(
    typeName: "GAComparisonMetadata",
    fields: [
      ModelField("apiName", .string),
      ModelField("uiName", .string),
      ModelField("description", .string)
    ]
  )

  public static let reportingMetadata = ModelShape(
    typeName: "GAReportingMetadata",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("dimensions", .objectList(dimensionMetadata)),
      ModelField("metrics", .objectList(metricMetadata)),
      ModelField("comparisons", .objectList(comparisonMetadata))
    ]
  )

  public static let dimensionCompatibility = ModelShape(
    typeName: "GADimensionCompatibility",
    fields: [
      ModelField("compatibility", .string),
      ModelField("dimensionMetadata", .object(dimensionMetadata))
    ]
  )

  public static let metricCompatibility = ModelShape(
    typeName: "GAMetricCompatibility",
    fields: [
      ModelField("compatibility", .string),
      ModelField("metricMetadata", .object(metricMetadata))
    ]
  )

  public static let compatibilityReport = ModelShape(
    typeName: "GACompatibilityReport",
    fields: [
      ModelField("dimensionCompatibilities", .objectList(dimensionCompatibility)),
      ModelField("metricCompatibilities", .objectList(metricCompatibility))
    ]
  )

  // MARK: - Data API: audience exports

  public static let audienceDimension = ModelShape(
    typeName: "GAAudienceDimension",
    fields: [ModelField("dimensionName", .string)]
  )

  public static let audienceExport = ModelShape(
    typeName: "GAAudienceExport",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("audience", .resourceName),
      ModelField("audienceDisplayName", .string),
      ModelField("dimensions", .objectList(audienceDimension)),
      ModelField("state", .string),
      ModelField("beginCreatingTime", .dateTime),
      ModelField("creationQuotaTokensCharged", .integer),
      ModelField("rowCount", .integer),
      ModelField("errorMessage", .string),
      ModelField("percentageCompleted", .number)
    ]
  )

  /// `audienceRows` is one row per exported user, keyed positionally to the
  /// export's `dimensions`, so it is carried verbatim like a report grid.
  public static let audienceExportQueryResult = ModelShape(
    typeName: "GAAudienceExportQueryResult",
    fields: [
      ModelField("audienceExport", .object(audienceExport)),
      ModelField("audienceRows", .json),
      ModelField("rowCount", .integer)
    ]
  )
}
