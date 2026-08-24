import GoogleAnalyticsGatewayCore

/// The stable output shapes of the GA4 resources that only the Admin API
/// v1alpha surface exposes.
///
/// They live beside `GAModels` rather than inside it because the two are
/// versioned independently: everything here is reachable only through
/// `/v1alpha`, and Google reserves the right to change an alpha resource in a
/// way it never would for the v1beta shapes. Keeping them in their own value
/// makes that boundary visible at the call site.
///
/// The reader module owns them for the same reason it owns `GAModels`: a
/// resource has one public shape whichever tier returned it, so the writer and
/// admin modules import these values instead of restating them.
///
/// Fields are typed from the GA4 Admin v1alpha discovery document. A subtree is
/// left as `.json` only where Google's own schema is recursive — the audience,
/// channel-group, expanded-data-set, and subproperty filter expressions are all
/// trees whose `andGroup`/`orGroup`/`notExpression` branches contain further
/// expressions of the same type, so no fixed shape can hold them.
public enum GAAlphaModels {

  // MARK: - Audiences

  public static let audienceEventTrigger = ModelShape(
    typeName: "GAAudienceEventTrigger",
    fields: [
      ModelField("eventName", .string),
      ModelField("logCondition", .string)
    ]
  )

  /// `filterClauses` is an `AudienceFilterClause` list whose simple and sequence
  /// filters nest `AudienceFilterExpression`, which contains further expression
  /// lists of its own. The tree travels verbatim.
  public static let audience = ModelShape(
    typeName: "GAAudience",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("description", .string),
      ModelField("membershipDurationDays", .integer),
      ModelField("adsPersonalizationEnabled", .boolean),
      ModelField("eventTrigger", .object(audienceEventTrigger)),
      ModelField("exclusionDurationMode", .string),
      ModelField("filterClauses", .json),
      ModelField("createTime", .dateTime)
    ]
  )

  // MARK: - Access bindings

  public static let accessBinding = ModelShape(
    typeName: "GAAccessBinding",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("user", .string),
      ModelField("roles", .stringList)
    ]
  )

  // MARK: - Product links

  public static let adSenseLink = ModelShape(
    typeName: "GAAdSenseLink",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("adClientCode", .string)
    ]
  )

  public static let bigQueryLink = ModelShape(
    typeName: "GABigQueryLink",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("project", .string),
      ModelField("createTime", .dateTime),
      ModelField("dailyExportEnabled", .boolean),
      ModelField("streamingExportEnabled", .boolean),
      ModelField("freshDailyExportEnabled", .boolean),
      ModelField("includeAdvertisingId", .boolean),
      ModelField("datasetLocation", .string),
      ModelField("exportStreams", .stringList),
      ModelField("excludedEvents", .stringList)
    ]
  )

  public static let displayVideo360AdvertiserLink = ModelShape(
    typeName: "GADisplayVideo360AdvertiserLink",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("advertiserId", .string),
      ModelField("advertiserDisplayName", .string),
      ModelField("adsPersonalizationEnabled", .boolean),
      ModelField("campaignDataSharingEnabled", .boolean),
      ModelField("costDataSharingEnabled", .boolean)
    ]
  )

  public static let linkProposalStatusDetails = ModelShape(
    typeName: "GALinkProposalStatusDetails",
    fields: [
      ModelField("linkProposalInitiatingProduct", .string),
      ModelField("linkProposalState", .string),
      ModelField("requestorEmail", .string)
    ]
  )

  public static let displayVideo360AdvertiserLinkProposal = ModelShape(
    typeName: "GADisplayVideo360AdvertiserLinkProposal",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("advertiserId", .string),
      ModelField("advertiserDisplayName", .string),
      ModelField("linkProposalStatusDetails", .object(linkProposalStatusDetails)),
      ModelField("validationEmail", .string),
      ModelField("adsPersonalizationEnabled", .boolean),
      ModelField("campaignDataSharingEnabled", .boolean),
      ModelField("costDataSharingEnabled", .boolean)
    ]
  )

  public static let searchAds360Link = ModelShape(
    typeName: "GASearchAds360Link",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("advertiserId", .string),
      ModelField("advertiserDisplayName", .string),
      ModelField("adsPersonalizationEnabled", .boolean),
      ModelField("campaignDataSharingEnabled", .boolean),
      ModelField("costDataSharingEnabled", .boolean),
      ModelField("siteStatsSharingEnabled", .boolean)
    ]
  )

  public static let rollupPropertySourceLink = ModelShape(
    typeName: "GARollupPropertySourceLink",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("sourceProperty", .resourceName)
    ]
  )

  // MARK: - Custom definitions

  public static let calculatedMetric = ModelShape(
    typeName: "GACalculatedMetric",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("calculatedMetricId", .string),
      ModelField("displayName", .string),
      ModelField("description", .string),
      ModelField("formula", .string),
      ModelField("metricUnit", .string),
      ModelField("restrictedMetricType", .stringList),
      ModelField("invalidMetricReference", .boolean)
    ]
  )

  /// A grouping rule's `expression` is a `ChannelGroupFilterExpression`, whose
  /// `andGroup` and `orGroup` branches hold further expressions of the same
  /// type, so the rule's name is typed and its condition carried verbatim.
  public static let groupingRule = ModelShape(
    typeName: "GAGroupingRule",
    fields: [
      ModelField("displayName", .string),
      ModelField("expression", .json)
    ]
  )

  public static let channelGroup = ModelShape(
    typeName: "GAChannelGroup",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("description", .string),
      ModelField("groupingRule", .objectList(groupingRule)),
      ModelField("systemDefined", .boolean),
      ModelField("primary", .boolean)
    ]
  )

  /// `dimensionFilterExpression` is an `ExpandedDataSetFilterExpression`, a
  /// recursive and/or/not tree, so it is carried verbatim.
  public static let expandedDataSet = ModelShape(
    typeName: "GAExpandedDataSet",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("description", .string),
      ModelField("dimensionNames", .stringList),
      ModelField("metricNames", .stringList),
      ModelField("dimensionFilterExpression", .json),
      ModelField("dataCollectionStartTime", .dateTime)
    ]
  )

  // MARK: - Event rules

  public static let matchingCondition = ModelShape(
    typeName: "GAMatchingCondition",
    fields: [
      ModelField("field", .string),
      ModelField("comparisonType", .string),
      ModelField("value", .string),
      ModelField("negated", .boolean)
    ]
  )

  public static let parameterMutation = ModelShape(
    typeName: "GAParameterMutation",
    fields: [
      ModelField("parameter", .string),
      ModelField("parameterValue", .string)
    ]
  )

  public static let eventCreateRule = ModelShape(
    typeName: "GAEventCreateRule",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("destinationEvent", .string),
      ModelField("eventConditions", .objectList(matchingCondition)),
      ModelField("sourceCopyParameters", .boolean),
      ModelField("parameterMutations", .objectList(parameterMutation))
    ]
  )

  public static let eventEditRule = ModelShape(
    typeName: "GAEventEditRule",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("displayName", .string),
      ModelField("eventConditions", .objectList(matchingCondition)),
      ModelField("parameterMutations", .objectList(parameterMutation)),
      ModelField("processingOrder", .integer)
    ]
  )

  // MARK: - Reporting data annotations

  /// Google's `google.type.Date`: a calendar date as three numbers rather than
  /// an RFC 3339 string, so it cannot use the `.date` scalar.
  public static let calendarDate = ModelShape(
    typeName: "GACalendarDate",
    fields: [
      ModelField("year", .integer),
      ModelField("month", .integer),
      ModelField("day", .integer)
    ]
  )

  public static let reportingDataAnnotationDateRange = ModelShape(
    typeName: "GAReportingDataAnnotationDateRange",
    fields: [
      ModelField("startDate", .object(calendarDate)),
      ModelField("endDate", .object(calendarDate))
    ]
  )

  /// An annotation carries either a single date or a range, never both, so both
  /// fields are optional and exactly one is populated per response.
  public static let reportingDataAnnotation = ModelShape(
    typeName: "GAReportingDataAnnotation",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("title", .string),
      ModelField("description", .string),
      ModelField("annotationDate", .object(calendarDate)),
      ModelField("annotationDateRange", .object(reportingDataAnnotationDateRange)),
      ModelField("color", .string),
      ModelField("systemGenerated", .boolean)
    ]
  )

  // MARK: - Subproperties

  /// `filterClauses` holds `SubpropertyEventFilterExpression` trees whose
  /// `orGroup` and `notExpression` branches recur, so they travel verbatim.
  public static let subpropertyEventFilter = ModelShape(
    typeName: "GASubpropertyEventFilter",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("applyToProperty", .resourceName),
      ModelField("filterClauses", .json)
    ]
  )

  public static let subpropertySyncConfig = ModelShape(
    typeName: "GASubpropertySyncConfig",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("applyToProperty", .resourceName),
      ModelField("customDimensionAndMetricSyncMode", .string)
    ]
  )

  // MARK: - SKAdNetwork conversion value schema

  /// `minEventCount` and `maxEventCount` are int64, which Google serializes as
  /// JSON strings; the integer projection accepts that representation.
  public static let skAdNetworkEventMapping = ModelShape(
    typeName: "GASKAdNetworkEventMapping",
    fields: [
      ModelField("eventName", .string),
      ModelField("minEventCount", .integer),
      ModelField("maxEventCount", .integer),
      ModelField("minEventValue", .number),
      ModelField("maxEventValue", .number)
    ]
  )

  /// Named for its SKAdNetwork origin so it does not collide with
  /// `GAModels.conversionValue`, the unrelated default value of a v1beta
  /// conversion event.
  public static let skAdNetworkConversionValue = ModelShape(
    typeName: "GASKAdNetworkConversionValue",
    fields: [
      ModelField("displayName", .string),
      ModelField("fineValue", .integer),
      ModelField("coarseValue", .string),
      ModelField("eventMappings", .objectList(skAdNetworkEventMapping)),
      ModelField("lockEnabled", .boolean)
    ]
  )

  public static let postbackWindow = ModelShape(
    typeName: "GAPostbackWindow",
    fields: [
      ModelField("conversionValues", .objectList(skAdNetworkConversionValue)),
      ModelField("postbackWindowSettingsEnabled", .boolean)
    ]
  )

  public static let skAdNetworkConversionValueSchema = ModelShape(
    typeName: "GASKAdNetworkConversionValueSchema",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("applyConversionValues", .boolean),
      ModelField("postbackWindowOne", .object(postbackWindow)),
      ModelField("postbackWindowTwo", .object(postbackWindow)),
      ModelField("postbackWindowThree", .object(postbackWindow))
    ]
  )

  // MARK: - Property and stream singletons

  public static let attributionSettings = ModelShape(
    typeName: "GAAttributionSettings",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("acquisitionConversionEventLookbackWindow", .string),
      ModelField("otherConversionEventLookbackWindow", .string),
      ModelField("reportingAttributionModel", .string),
      ModelField("adsWebConversionDataExportScope", .string)
    ]
  )

  public static let googleSignalsSettings = ModelShape(
    typeName: "GAGoogleSignalsSettings",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("state", .string),
      ModelField("consent", .string)
    ]
  )

  public static let reportingIdentitySettings = ModelShape(
    typeName: "GAReportingIdentitySettings",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("reportingIdentity", .string)
    ]
  )

  public static let userProvidedDataSettings = ModelShape(
    typeName: "GAUserProvidedDataSettings",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("userProvidedDataCollectionEnabled", .boolean),
      ModelField("automaticallyDetectedDataCollectionEnabled", .boolean)
    ]
  )

  public static let dataRedactionSettings = ModelShape(
    typeName: "GADataRedactionSettings",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("emailRedactionEnabled", .boolean),
      ModelField("queryParameterRedactionEnabled", .boolean),
      ModelField("queryParameterKeys", .stringList)
    ]
  )

  public static let enhancedMeasurementSettings = ModelShape(
    typeName: "GAEnhancedMeasurementSettings",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("streamEnabled", .boolean),
      ModelField("scrollsEnabled", .boolean),
      ModelField("outboundClicksEnabled", .boolean),
      ModelField("siteSearchEnabled", .boolean),
      ModelField("videoEngagementEnabled", .boolean),
      ModelField("fileDownloadsEnabled", .boolean),
      ModelField("pageChangesEnabled", .boolean),
      ModelField("formInteractionsEnabled", .boolean),
      ModelField("searchQueryParameter", .string),
      ModelField("uriQueryParameter", .string)
    ]
  )

  /// `snippet` is the JavaScript tag Google generates for the stream. It is the
  /// value the caller asked for, so it is projected as read.
  public static let globalSiteTag = ModelShape(
    typeName: "GAGlobalSiteTag",
    fields: [
      ModelField("name", .resourceName, required: true),
      ModelField("snippet", .string)
    ]
  )
}
