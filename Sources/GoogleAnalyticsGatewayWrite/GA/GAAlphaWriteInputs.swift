import GoogleAnalyticsGatewayCore

/// Request bodies for the GA4 Admin API v1alpha writer-tier mutations.
///
/// The rules are the ones `GAWriteInputs` already follows for the v1beta
/// surface: a shape is the resource's discovery schema minus every field Google
/// marks `Output only`, create and update are separate shapes wherever the two
/// differ — a create carries the `Required` fields, a patch names what it
/// changes through `updateMask` and would be unusable if it demanded them again,
/// and an `Immutable` field belongs to the create shape alone — and `name` is
/// absent everywhere because the route already carries it.
///
/// Two things are specific to the alpha surface. First, four of its resources
/// are defined by a filter expression that Google's own schema declares
/// recursively: an `AudienceFilterExpression`, a `ChannelGroupFilterExpression`,
/// an `ExpandedDataSetFilterExpression`, and a `SubpropertyEventFilterExpression`
/// each contain `andGroup`/`orGroup`/`notExpression` branches holding further
/// expressions of the same type. `InputObjectShape` is not recursive, so those
/// trees travel as `.json` and are validated upstream; every other nested
/// structure here is finite and is typed. Second, the alpha patches disagree
/// about `updateMask`: most document it as `Required`, but the reporting data
/// annotation, subproperty sync config, and reporting identity settings patches
/// document it as `Optional`, so those three take `optionalUpdateMask`.
///
/// Enumerations are typed from the discovery `enum` lists rather than left as
/// strings, so an unaccepted value is a named local validation error instead of
/// an upstream 400.
public enum GAAlphaWriteInputs {

  // MARK: - Shared arguments

  /// The field mask for the alpha patches whose `updateMask` documentation opens
  /// with "Optional." Sending one is still the only way to change a subset of
  /// the resource, so it is offered on every patch; it is simply not refused
  /// locally when it is absent.
  public static let optionalUpdateMask = ArgumentDefinition(
    "updateMask",
    .string,
    .query("updateMask")
  )

  /// The ID a calculated metric is created under. Google takes it as a query
  /// parameter rather than a body field, and documents it as "Required.", so it
  /// is the one create on this surface with a required argument outside the body.
  public static let calculatedMetricId = ArgumentDefinition(
    "calculatedMetricId",
    .string,
    .query("calculatedMetricId"),
    required: true
  )

  // MARK: - Resource-name patterns

  static let property = "properties/{property}"
  static let dataStream = "properties/{property}/dataStreams/{dataStream}"

  // MARK: - Enumerations

  public static let audienceLogCondition = ArgumentValueType.enumeration(
    "GAAudienceLogCondition",
    ["LOG_CONDITION_UNSPECIFIED", "AUDIENCE_JOINED", "AUDIENCE_MEMBERSHIP_RENEWED"]
  )

  public static let audienceExclusionDurationMode = ArgumentValueType.enumeration(
    "GAAudienceExclusionDurationMode",
    [
      "AUDIENCE_EXCLUSION_DURATION_MODE_UNSPECIFIED",
      "EXCLUDE_TEMPORARILY",
      "EXCLUDE_PERMANENTLY"
    ]
  )

  /// A calculated metric's unit list is not the custom metric's `MeasurementUnit`
  /// list — it orders `MILES` before `METERS` and Google spells the unspecified
  /// member differently — so one shared enumeration would accept a value the
  /// other method refuses.
  public static let calculatedMetricUnit = ArgumentValueType.enumeration(
    "GACalculatedMetricUnit",
    [
      "METRIC_UNIT_UNSPECIFIED",
      "STANDARD",
      "CURRENCY",
      "FEET",
      "MILES",
      "METERS",
      "KILOMETERS",
      "MILLISECONDS",
      "SECONDS",
      "MINUTES",
      "HOURS"
    ]
  )

  /// Shared by the event create and event edit rules, which both match a source
  /// event through a `MatchingCondition`.
  public static let matchingConditionComparisonType = ArgumentValueType.enumeration(
    "GAMatchingConditionComparisonType",
    [
      "COMPARISON_TYPE_UNSPECIFIED",
      "EQUALS",
      "EQUALS_CASE_INSENSITIVE",
      "CONTAINS",
      "CONTAINS_CASE_INSENSITIVE",
      "STARTS_WITH",
      "STARTS_WITH_CASE_INSENSITIVE",
      "ENDS_WITH",
      "ENDS_WITH_CASE_INSENSITIVE",
      "GREATER_THAN",
      "GREATER_THAN_OR_EQUAL",
      "LESS_THAN",
      "LESS_THAN_OR_EQUAL",
      "REGULAR_EXPRESSION",
      "REGULAR_EXPRESSION_CASE_INSENSITIVE"
    ]
  )

  public static let coarseConversionValue = ArgumentValueType.enumeration(
    "GACoarseConversionValue",
    ["COARSE_VALUE_UNSPECIFIED", "COARSE_VALUE_LOW", "COARSE_VALUE_MEDIUM", "COARSE_VALUE_HIGH"]
  )

  public static let reportingDataAnnotationColor = ArgumentValueType.enumeration(
    "GAReportingDataAnnotationColor",
    ["COLOR_UNSPECIFIED", "PURPLE", "BROWN", "BLUE", "GREEN", "RED", "CYAN", "ORANGE"]
  )

  /// The subproperty custom dimension and metric synchronization mode, used both
  /// by the provisioning request and by the sync config patch.
  public static let subpropertySynchronizationMode = ArgumentValueType.enumeration(
    "GASubpropertySynchronizationMode",
    ["SYNCHRONIZATION_MODE_UNSPECIFIED", "NONE", "ALL"]
  )

  public static let acquisitionConversionEventLookbackWindow = ArgumentValueType.enumeration(
    "GAAcquisitionConversionEventLookbackWindow",
    [
      "ACQUISITION_CONVERSION_EVENT_LOOKBACK_WINDOW_UNSPECIFIED",
      "ACQUISITION_CONVERSION_EVENT_LOOKBACK_WINDOW_7_DAYS",
      "ACQUISITION_CONVERSION_EVENT_LOOKBACK_WINDOW_30_DAYS"
    ]
  )

  public static let otherConversionEventLookbackWindow = ArgumentValueType.enumeration(
    "GAOtherConversionEventLookbackWindow",
    [
      "OTHER_CONVERSION_EVENT_LOOKBACK_WINDOW_UNSPECIFIED",
      "OTHER_CONVERSION_EVENT_LOOKBACK_WINDOW_30_DAYS",
      "OTHER_CONVERSION_EVENT_LOOKBACK_WINDOW_60_DAYS",
      "OTHER_CONVERSION_EVENT_LOOKBACK_WINDOW_90_DAYS"
    ]
  )

  public static let reportingAttributionModel = ArgumentValueType.enumeration(
    "GAReportingAttributionModel",
    [
      "REPORTING_ATTRIBUTION_MODEL_UNSPECIFIED",
      "PAID_AND_ORGANIC_CHANNELS_DATA_DRIVEN",
      "PAID_AND_ORGANIC_CHANNELS_LAST_CLICK",
      "GOOGLE_PAID_CHANNELS_LAST_CLICK"
    ]
  )

  public static let adsWebConversionDataExportScope = ArgumentValueType.enumeration(
    "GAAdsWebConversionDataExportScope",
    [
      "ADS_WEB_CONVERSION_DATA_EXPORT_SCOPE_UNSPECIFIED",
      "NOT_SELECTED_YET",
      "PAID_AND_ORGANIC_CHANNELS",
      "GOOGLE_PAID_CHANNELS"
    ]
  )

  public static let googleSignalsState = ArgumentValueType.enumeration(
    "GAGoogleSignalsState",
    ["GOOGLE_SIGNALS_STATE_UNSPECIFIED", "GOOGLE_SIGNALS_ENABLED", "GOOGLE_SIGNALS_DISABLED"]
  )

  public static let reportingIdentity = ArgumentValueType.enumeration(
    "GAReportingIdentity",
    ["IDENTITY_BLENDING_STRATEGY_UNSPECIFIED", "BLENDED", "OBSERVED", "DEVICE_BASED"]
  )

  // MARK: - Audiences

  public static let audienceEventTrigger = InputObjectShape(
    typeName: "GAAudienceEventTriggerInput",
    fields: [
      ArgumentDefinition("eventName", .string, .bodyJSON("eventName"), required: true),
      ArgumentDefinition("logCondition", audienceLogCondition, .bodyJSON("logCondition"), required: true)
    ]
  )

  /// `filterClauses` is the Audience's definition and is `Required` and
  /// `Immutable`: each clause holds an `AudienceFilterExpression`, whose
  /// `andGroup`, `orGroup`, and `notExpression` branches hold further
  /// expressions of the same type, so the tree passes through as JSON.
  public static let audienceCreate = InputObjectShape(
    typeName: "GAAudienceCreateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition("description", .string, .bodyJSON("description"), required: true),
      ArgumentDefinition(
        "membershipDurationDays",
        .integer,
        .bodyJSON("membershipDurationDays"),
        required: true
      ),
      ArgumentDefinition("filterClauses", .json, .bodyJSON("filterClauses"), required: true),
      ArgumentDefinition(
        "exclusionDurationMode",
        audienceExclusionDurationMode,
        .bodyJSON("exclusionDurationMode")
      ),
      ArgumentDefinition("eventTrigger", .inputObject(audienceEventTrigger), .bodyJSON("eventTrigger"))
    ]
  )

  /// The membership duration, the exclusion mode, and the filter clauses are all
  /// `Immutable`, so an Audience patch can only rename it, redescribe it, or
  /// change the event logged when a user joins.
  public static let audienceUpdate = InputObjectShape(
    typeName: "GAAudienceUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("eventTrigger", .inputObject(audienceEventTrigger), .bodyJSON("eventTrigger"))
    ]
  )

  // MARK: - Product links

  public static let adSenseLinkCreate = InputObjectShape(
    typeName: "GAAdSenseLinkCreateInput",
    fields: [
      ArgumentDefinition("adClientCode", .string, .bodyJSON("adClientCode"), required: true)
    ]
  )

  /// Google accepts either a project number or a project id in the `projects/`
  /// name at creation and always returns the number afterwards, exactly as it
  /// does for a Firebase link.
  public static let bigQueryLinkCreate = InputObjectShape(
    typeName: "GABigQueryLinkCreateInput",
    fields: [
      ArgumentDefinition(
        "project",
        .resourceName("projects/{project}"),
        .bodyJSON("project"),
        required: true
      ),
      ArgumentDefinition("datasetLocation", .string, .bodyJSON("datasetLocation"), required: true),
      ArgumentDefinition("dailyExportEnabled", .boolean, .bodyJSON("dailyExportEnabled")),
      ArgumentDefinition("streamingExportEnabled", .boolean, .bodyJSON("streamingExportEnabled")),
      ArgumentDefinition("freshDailyExportEnabled", .boolean, .bodyJSON("freshDailyExportEnabled")),
      ArgumentDefinition("includeAdvertisingId", .boolean, .bodyJSON("includeAdvertisingId")),
      ArgumentDefinition("exportStreams", .stringList, .bodyJSON("exportStreams")),
      ArgumentDefinition("excludedEvents", .stringList, .bodyJSON("excludedEvents"))
    ]
  )

  /// The linked project and the dataset's geographic location are `Immutable`,
  /// so a patch changes only what is exported and from which streams.
  public static let bigQueryLinkUpdate = InputObjectShape(
    typeName: "GABigQueryLinkUpdateInput",
    fields: [
      ArgumentDefinition("dailyExportEnabled", .boolean, .bodyJSON("dailyExportEnabled")),
      ArgumentDefinition("streamingExportEnabled", .boolean, .bodyJSON("streamingExportEnabled")),
      ArgumentDefinition("freshDailyExportEnabled", .boolean, .bodyJSON("freshDailyExportEnabled")),
      ArgumentDefinition("includeAdvertisingId", .boolean, .bodyJSON("includeAdvertisingId")),
      ArgumentDefinition("exportStreams", .stringList, .bodyJSON("exportStreams")),
      ArgumentDefinition("excludedEvents", .stringList, .bodyJSON("excludedEvents"))
    ]
  )

  public static let displayVideo360AdvertiserLinkCreate = InputObjectShape(
    typeName: "GADisplayVideo360AdvertiserLinkCreateInput",
    fields: [
      ArgumentDefinition("advertiserId", .string, .bodyJSON("advertiserId"), required: true),
      ArgumentDefinition("adsPersonalizationEnabled", .boolean, .bodyJSON("adsPersonalizationEnabled")),
      ArgumentDefinition("campaignDataSharingEnabled", .boolean, .bodyJSON("campaignDataSharingEnabled")),
      ArgumentDefinition("costDataSharingEnabled", .boolean, .bodyJSON("costDataSharingEnabled"))
    ]
  )

  /// Campaign and cost data sharing are `Immutable` and, after the link exists,
  /// changeable only from Display & Video 360, so personalized advertising is
  /// the one setting this patch can carry.
  public static let displayVideo360AdvertiserLinkUpdate = InputObjectShape(
    typeName: "GADisplayVideo360AdvertiserLinkUpdateInput",
    fields: [
      ArgumentDefinition("adsPersonalizationEnabled", .boolean, .bodyJSON("adsPersonalizationEnabled"))
    ]
  )

  /// `validationEmail` is `Input only`: Google uses it to confirm that the
  /// proposer knows an admin on the target advertiser and never returns it.
  public static let displayVideo360LinkProposalCreate = InputObjectShape(
    typeName: "GADisplayVideo360AdvertiserLinkProposalCreateInput",
    fields: [
      ArgumentDefinition("advertiserId", .string, .bodyJSON("advertiserId"), required: true),
      ArgumentDefinition("validationEmail", .string, .bodyJSON("validationEmail")),
      ArgumentDefinition("adsPersonalizationEnabled", .boolean, .bodyJSON("adsPersonalizationEnabled")),
      ArgumentDefinition("campaignDataSharingEnabled", .boolean, .bodyJSON("campaignDataSharingEnabled")),
      ArgumentDefinition("costDataSharingEnabled", .boolean, .bodyJSON("costDataSharingEnabled"))
    ]
  )

  public static let searchAds360LinkCreate = InputObjectShape(
    typeName: "GASearchAds360LinkCreateInput",
    fields: [
      ArgumentDefinition("advertiserId", .string, .bodyJSON("advertiserId"), required: true),
      ArgumentDefinition("adsPersonalizationEnabled", .boolean, .bodyJSON("adsPersonalizationEnabled")),
      ArgumentDefinition("siteStatsSharingEnabled", .boolean, .bodyJSON("siteStatsSharingEnabled")),
      ArgumentDefinition("campaignDataSharingEnabled", .boolean, .bodyJSON("campaignDataSharingEnabled")),
      ArgumentDefinition("costDataSharingEnabled", .boolean, .bodyJSON("costDataSharingEnabled"))
    ]
  )

  /// As with the Display & Video 360 link, campaign and cost data sharing are
  /// `Immutable` and afterwards owned by the linked product.
  public static let searchAds360LinkUpdate = InputObjectShape(
    typeName: "GASearchAds360LinkUpdateInput",
    fields: [
      ArgumentDefinition("adsPersonalizationEnabled", .boolean, .bodyJSON("adsPersonalizationEnabled")),
      ArgumentDefinition("siteStatsSharingEnabled", .boolean, .bodyJSON("siteStatsSharingEnabled"))
    ]
  )

  public static let rollupPropertySourceLinkCreate = InputObjectShape(
    typeName: "GARollupPropertySourceLinkCreateInput",
    fields: [
      ArgumentDefinition(
        "sourceProperty",
        .resourceName(property),
        .bodyJSON("sourceProperty"),
        required: true
      )
    ]
  )

  // MARK: - Calculated metrics, channel groups, and expanded data sets

  public static let calculatedMetricCreate = InputObjectShape(
    typeName: "GACalculatedMetricCreateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition("formula", .string, .bodyJSON("formula"), required: true),
      ArgumentDefinition("metricUnit", calculatedMetricUnit, .bodyJSON("metricUnit"), required: true),
      ArgumentDefinition("description", .string, .bodyJSON("description"))
    ]
  )

  public static let calculatedMetricUpdate = InputObjectShape(
    typeName: "GACalculatedMetricUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition("formula", .string, .bodyJSON("formula")),
      ArgumentDefinition("metricUnit", calculatedMetricUnit, .bodyJSON("metricUnit")),
      ArgumentDefinition("description", .string, .bodyJSON("description"))
    ]
  )

  /// One rule naming one channel. Only `expression` is left open: a
  /// `ChannelGroupFilterExpression` is recursive through `andGroup`, `orGroup`,
  /// and `notExpression`, but the rule that wraps it is not, so the display name
  /// stays typed. This mirrors `GAAlphaModels.groupingRule` on the read side,
  /// which draws the same boundary.
  public static let groupingRule = InputObjectShape(
    typeName: "GAGroupingRuleInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition("expression", .json, .bodyJSON("expression"), required: true)
    ]
  )

  /// Google caps a channel group at 50 grouping rules.
  private static let maximumGroupingRules = 50

  public static let channelGroupCreate = InputObjectShape(
    typeName: "GAChannelGroupCreateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition(
        "groupingRule",
        .inputObjectList(groupingRule),
        .bodyJSON("groupingRule"),
        required: true,
        maximumCount: maximumGroupingRules
      ),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("primary", .boolean, .bodyJSON("primary"))
    ]
  )

  public static let channelGroupUpdate = InputObjectShape(
    typeName: "GAChannelGroupUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition(
        "groupingRule",
        .inputObjectList(groupingRule),
        .bodyJSON("groupingRule"),
        maximumCount: maximumGroupingRules
      ),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("primary", .boolean, .bodyJSON("primary"))
    ]
  )

  /// The dimensions, the metrics, and the dimension filter of an expanded data
  /// set are all `Immutable`; the filter is an
  /// `ExpandedDataSetFilterExpression`, recursive through `andGroup` and
  /// `notExpression`, so it travels as JSON.
  public static let expandedDataSetCreate = InputObjectShape(
    typeName: "GAExpandedDataSetCreateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("dimensionNames", .stringList, .bodyJSON("dimensionNames")),
      ArgumentDefinition("metricNames", .stringList, .bodyJSON("metricNames")),
      ArgumentDefinition(
        "dimensionFilterExpression",
        .json,
        .bodyJSON("dimensionFilterExpression")
      )
    ]
  )

  public static let expandedDataSetUpdate = InputObjectShape(
    typeName: "GAExpandedDataSetUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition("description", .string, .bodyJSON("description"))
    ]
  )

  // MARK: - Event create and event edit rules

  /// Shared by both rule kinds: each matches its source event through a list of
  /// `MatchingCondition` values and rewrites parameters through a list of
  /// `ParameterMutation` values. Neither structure is recursive, so both are
  /// typed.
  public static let matchingCondition = InputObjectShape(
    typeName: "GAMatchingConditionInput",
    fields: [
      ArgumentDefinition("field", .string, .bodyJSON("field"), required: true),
      ArgumentDefinition(
        "comparisonType",
        matchingConditionComparisonType,
        .bodyJSON("comparisonType"),
        required: true
      ),
      ArgumentDefinition("value", .string, .bodyJSON("value"), required: true),
      ArgumentDefinition("negated", .boolean, .bodyJSON("negated"))
    ]
  )

  public static let parameterMutation = InputObjectShape(
    typeName: "GAParameterMutationInput",
    fields: [
      ArgumentDefinition("parameter", .string, .bodyJSON("parameter"), required: true),
      ArgumentDefinition("parameterValue", .string, .bodyJSON("parameterValue"), required: true)
    ]
  )

  /// Google caps a rule at ten conditions and twenty mutations, so the limits are
  /// enforced locally rather than by assembling a request it will refuse.
  private static let maximumEventConditions = 10
  private static let maximumParameterMutations = 20

  public static let eventCreateRuleCreate = InputObjectShape(
    typeName: "GAEventCreateRuleCreateInput",
    fields: [
      ArgumentDefinition("destinationEvent", .string, .bodyJSON("destinationEvent"), required: true),
      ArgumentDefinition(
        "eventConditions",
        .inputObjectList(matchingCondition),
        .bodyJSON("eventConditions"),
        required: true,
        maximumCount: maximumEventConditions
      ),
      ArgumentDefinition("sourceCopyParameters", .boolean, .bodyJSON("sourceCopyParameters")),
      ArgumentDefinition(
        "parameterMutations",
        .inputObjectList(parameterMutation),
        .bodyJSON("parameterMutations"),
        maximumCount: maximumParameterMutations
      )
    ]
  )

  public static let eventCreateRuleUpdate = InputObjectShape(
    typeName: "GAEventCreateRuleUpdateInput",
    fields: [
      ArgumentDefinition("destinationEvent", .string, .bodyJSON("destinationEvent")),
      ArgumentDefinition(
        "eventConditions",
        .inputObjectList(matchingCondition),
        .bodyJSON("eventConditions"),
        maximumCount: maximumEventConditions
      ),
      ArgumentDefinition("sourceCopyParameters", .boolean, .bodyJSON("sourceCopyParameters")),
      ArgumentDefinition(
        "parameterMutations",
        .inputObjectList(parameterMutation),
        .bodyJSON("parameterMutations"),
        maximumCount: maximumParameterMutations
      )
    ]
  )

  public static let eventEditRuleCreate = InputObjectShape(
    typeName: "GAEventEditRuleCreateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition(
        "eventConditions",
        .inputObjectList(matchingCondition),
        .bodyJSON("eventConditions"),
        required: true,
        maximumCount: maximumEventConditions
      ),
      ArgumentDefinition(
        "parameterMutations",
        .inputObjectList(parameterMutation),
        .bodyJSON("parameterMutations"),
        required: true,
        maximumCount: maximumParameterMutations
      )
    ]
  )

  public static let eventEditRuleUpdate = InputObjectShape(
    typeName: "GAEventEditRuleUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition(
        "eventConditions",
        .inputObjectList(matchingCondition),
        .bodyJSON("eventConditions"),
        maximumCount: maximumEventConditions
      ),
      ArgumentDefinition(
        "parameterMutations",
        .inputObjectList(parameterMutation),
        .bodyJSON("parameterMutations"),
        maximumCount: maximumParameterMutations
      )
    ]
  )

  /// `ReorderEventEditRulesRequest`. The order is the whole request: Google
  /// requires every rule on the stream to appear in the list, so a partial list
  /// is refused upstream rather than reordering a subset.
  public static let reorderEventEditRules = InputObjectShape(
    typeName: "GAReorderEventEditRulesInput",
    fields: [
      ArgumentDefinition("eventEditRules", .stringList, .bodyJSON("eventEditRules"), required: true)
    ]
  )

  // MARK: - SKAdNetwork conversion value schema

  public static let skAdNetworkEventMapping = InputObjectShape(
    typeName: "GASKAdNetworkEventMappingInput",
    fields: [
      ArgumentDefinition("eventName", .string, .bodyJSON("eventName"), required: true),
      // The two counts are int64 in Google's schema and are therefore carried as
      // strings, which is how the API both accepts and returns them.
      ArgumentDefinition("minEventCount", .string, .bodyJSON("minEventCount")),
      ArgumentDefinition("maxEventCount", .string, .bodyJSON("maxEventCount")),
      ArgumentDefinition("minEventValue", .number, .bodyJSON("minEventValue")),
      ArgumentDefinition("maxEventValue", .number, .bodyJSON("maxEventValue"))
    ]
  )

  public static let skAdNetworkConversionValue = InputObjectShape(
    typeName: "GASKAdNetworkConversionValueInput",
    fields: [
      ArgumentDefinition("coarseValue", coarseConversionValue, .bodyJSON("coarseValue"), required: true),
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      // Applicable to the first postback window only, where Google accepts 0-63.
      ArgumentDefinition("fineValue", .integer, .bodyJSON("fineValue")),
      ArgumentDefinition("lockEnabled", .boolean, .bodyJSON("lockEnabled")),
      ArgumentDefinition(
        "eventMappings",
        .inputObjectList(skAdNetworkEventMapping),
        .bodyJSON("eventMappings"),
        maximumCount: 3
      )
    ]
  )

  /// The order of `conversionValues` is the priority order: Google selects the
  /// first entry that evaluates to true, so the list is passed through as given.
  public static let postbackWindow = InputObjectShape(
    typeName: "GAPostbackWindowInput",
    fields: [
      ArgumentDefinition(
        "conversionValues",
        .inputObjectList(skAdNetworkConversionValue),
        .bodyJSON("conversionValues")
      ),
      ArgumentDefinition(
        "postbackWindowSettingsEnabled",
        .boolean,
        .bodyJSON("postbackWindowSettingsEnabled")
      )
    ]
  )

  public static let skAdNetworkConversionValueSchemaCreate = InputObjectShape(
    typeName: "GASKAdNetworkConversionValueSchemaCreateInput",
    fields: [
      ArgumentDefinition(
        "postbackWindowOne",
        .inputObject(postbackWindow),
        .bodyJSON("postbackWindowOne"),
        required: true
      ),
      ArgumentDefinition("postbackWindowTwo", .inputObject(postbackWindow), .bodyJSON("postbackWindowTwo")),
      ArgumentDefinition(
        "postbackWindowThree",
        .inputObject(postbackWindow),
        .bodyJSON("postbackWindowThree")
      ),
      ArgumentDefinition("applyConversionValues", .boolean, .bodyJSON("applyConversionValues"))
    ]
  )

  public static let skAdNetworkConversionValueSchemaUpdate = InputObjectShape(
    typeName: "GASKAdNetworkConversionValueSchemaUpdateInput",
    fields: [
      ArgumentDefinition("postbackWindowOne", .inputObject(postbackWindow), .bodyJSON("postbackWindowOne")),
      ArgumentDefinition("postbackWindowTwo", .inputObject(postbackWindow), .bodyJSON("postbackWindowTwo")),
      ArgumentDefinition(
        "postbackWindowThree",
        .inputObject(postbackWindow),
        .bodyJSON("postbackWindowThree")
      ),
      ArgumentDefinition("applyConversionValues", .boolean, .bodyJSON("applyConversionValues"))
    ]
  )

  // MARK: - Data stream singletons

  /// The v1alpha data redaction settings are a per-stream singleton and are a
  /// different resource from the property-level retention settings the v1beta
  /// writer patches.
  public static let streamDataRedactionSettingsUpdate = InputObjectShape(
    typeName: "GAStreamDataRedactionSettingsUpdateInput",
    fields: [
      ArgumentDefinition("emailRedactionEnabled", .boolean, .bodyJSON("emailRedactionEnabled")),
      ArgumentDefinition(
        "queryParameterRedactionEnabled",
        .boolean,
        .bodyJSON("queryParameterRedactionEnabled")
      ),
      ArgumentDefinition("queryParameterKeys", .stringList, .bodyJSON("queryParameterKeys"))
    ]
  )

  /// `searchQueryParameter` is `Required` on the resource, but this is a patch:
  /// a caller changing only `scrollsEnabled` names that one field in
  /// `updateMask` and must not be made to restate the search parameter, so it is
  /// optional here and Google's refusal of an empty value is reported through
  /// the capability's rejection guidance.
  public static let enhancedMeasurementSettingsUpdate = InputObjectShape(
    typeName: "GAEnhancedMeasurementSettingsUpdateInput",
    fields: [
      ArgumentDefinition("streamEnabled", .boolean, .bodyJSON("streamEnabled")),
      ArgumentDefinition("scrollsEnabled", .boolean, .bodyJSON("scrollsEnabled")),
      ArgumentDefinition("outboundClicksEnabled", .boolean, .bodyJSON("outboundClicksEnabled")),
      ArgumentDefinition("siteSearchEnabled", .boolean, .bodyJSON("siteSearchEnabled")),
      ArgumentDefinition("videoEngagementEnabled", .boolean, .bodyJSON("videoEngagementEnabled")),
      ArgumentDefinition("fileDownloadsEnabled", .boolean, .bodyJSON("fileDownloadsEnabled")),
      ArgumentDefinition("pageChangesEnabled", .boolean, .bodyJSON("pageChangesEnabled")),
      ArgumentDefinition("formInteractionsEnabled", .boolean, .bodyJSON("formInteractionsEnabled")),
      ArgumentDefinition("searchQueryParameter", .string, .bodyJSON("searchQueryParameter")),
      ArgumentDefinition("uriQueryParameter", .string, .bodyJSON("uriQueryParameter"))
    ]
  )

  // MARK: - Reporting data annotations

  /// `google.type.Date`, which the annotation uses for both a single date and
  /// the ends of a range. Google allows a zero component to mean "unspecified",
  /// so none of the three is required here.
  public static let calendarDate = InputObjectShape(
    typeName: "GACalendarDateInput",
    fields: [
      ArgumentDefinition("year", .integer, .bodyJSON("year")),
      ArgumentDefinition("month", .integer, .bodyJSON("month")),
      ArgumentDefinition("day", .integer, .bodyJSON("day"))
    ]
  )

  public static let reportingDataAnnotationDateRange = InputObjectShape(
    typeName: "GAReportingDataAnnotationDateRangeInput",
    fields: [
      ArgumentDefinition("startDate", .inputObject(calendarDate), .bodyJSON("startDate"), required: true),
      ArgumentDefinition("endDate", .inputObject(calendarDate), .bodyJSON("endDate"), required: true)
    ]
  )

  /// An annotation carries either `annotationDate` or `annotationDateRange`;
  /// Google refuses both at once, which is a constraint no input shape can
  /// express, so it is reported through the capability's rejection guidance.
  public static let reportingDataAnnotationCreate = InputObjectShape(
    typeName: "GAReportingDataAnnotationCreateInput",
    fields: [
      ArgumentDefinition("title", .string, .bodyJSON("title"), required: true),
      ArgumentDefinition("color", reportingDataAnnotationColor, .bodyJSON("color"), required: true),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("annotationDate", .inputObject(calendarDate), .bodyJSON("annotationDate")),
      ArgumentDefinition(
        "annotationDateRange",
        .inputObject(reportingDataAnnotationDateRange),
        .bodyJSON("annotationDateRange")
      )
    ]
  )

  public static let reportingDataAnnotationUpdate = InputObjectShape(
    typeName: "GAReportingDataAnnotationUpdateInput",
    fields: [
      ArgumentDefinition("title", .string, .bodyJSON("title")),
      ArgumentDefinition("color", reportingDataAnnotationColor, .bodyJSON("color")),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("annotationDate", .inputObject(calendarDate), .bodyJSON("annotationDate")),
      ArgumentDefinition(
        "annotationDateRange",
        .inputObject(reportingDataAnnotationDateRange),
        .bodyJSON("annotationDateRange")
      )
    ]
  )

  // MARK: - Subproperties

  /// `filterClauses` defines which events reach the subproperty. Each clause
  /// holds a `SubpropertyEventFilterExpression`, recursive through `orGroup` and
  /// `notExpression`, so the list travels as JSON.
  public static let subpropertyEventFilterCreate = InputObjectShape(
    typeName: "GASubpropertyEventFilterCreateInput",
    fields: [
      ArgumentDefinition(
        "applyToProperty",
        .resourceName(property),
        .bodyJSON("applyToProperty"),
        required: true
      ),
      ArgumentDefinition("filterClauses", .json, .bodyJSON("filterClauses"), required: true)
    ]
  )

  /// The subproperty the filter applies to is `Immutable`, so only the clauses
  /// can be patched.
  public static let subpropertyEventFilterUpdate = InputObjectShape(
    typeName: "GASubpropertyEventFilterUpdateInput",
    fields: [
      ArgumentDefinition("filterClauses", .json, .bodyJSON("filterClauses"), required: true)
    ]
  )

  public static let subpropertySyncConfigUpdate = InputObjectShape(
    typeName: "GASubpropertySyncConfigUpdateInput",
    fields: [
      ArgumentDefinition(
        "customDimensionAndMetricSyncMode",
        subpropertySynchronizationMode,
        .bodyJSON("customDimensionAndMetricSyncMode")
      )
    ]
  )

  // MARK: - Property provisioning

  /// `CreateRollupPropertyRequest`. The property itself reuses the v1beta create
  /// shape: a roll-up property is an ordinary `Property` message with
  /// `propertyType` set to `PROPERTY_TYPE_ROLLUP`, so restating it here would
  /// publish two input types for one Google schema.
  public static let createRollupProperty = InputObjectShape(
    typeName: "GACreateRollupPropertyInput",
    fields: [
      ArgumentDefinition(
        "rollupProperty",
        .inputObject(GAWriteInputs.propertyCreate),
        .bodyJSON("rollupProperty"),
        required: true
      ),
      ArgumentDefinition("sourceProperties", .stringList, .bodyJSON("sourceProperties"))
    ]
  )

  /// `ProvisionSubpropertyRequest`. The optional event filter is created on the
  /// ordinary parent property in the same call, which is why the request carries
  /// a whole filter rather than a reference to one.
  public static let provisionSubproperty = InputObjectShape(
    typeName: "GAProvisionSubpropertyInput",
    fields: [
      ArgumentDefinition(
        "subproperty",
        .inputObject(GAWriteInputs.propertyCreate),
        .bodyJSON("subproperty"),
        required: true
      ),
      ArgumentDefinition(
        "subpropertyEventFilter",
        .inputObject(subpropertyEventFilterCreate),
        .bodyJSON("subpropertyEventFilter")
      ),
      ArgumentDefinition(
        "customDimensionAndMetricSynchronizationMode",
        subpropertySynchronizationMode,
        .bodyJSON("customDimensionAndMetricSynchronizationMode")
      )
    ]
  )

  // MARK: - Property singletons

  public static let attributionSettingsUpdate = InputObjectShape(
    typeName: "GAAttributionSettingsUpdateInput",
    fields: [
      ArgumentDefinition(
        "acquisitionConversionEventLookbackWindow",
        acquisitionConversionEventLookbackWindow,
        .bodyJSON("acquisitionConversionEventLookbackWindow")
      ),
      ArgumentDefinition(
        "otherConversionEventLookbackWindow",
        otherConversionEventLookbackWindow,
        .bodyJSON("otherConversionEventLookbackWindow")
      ),
      ArgumentDefinition(
        "reportingAttributionModel",
        reportingAttributionModel,
        .bodyJSON("reportingAttributionModel")
      ),
      ArgumentDefinition(
        "adsWebConversionDataExportScope",
        adsWebConversionDataExportScope,
        .bodyJSON("adsWebConversionDataExportScope")
      )
    ]
  )

  /// `consent` records the property's acceptance of the Google Signals terms of
  /// service and is `Output only`, so enabling or disabling the feature is the
  /// only thing this patch carries.
  public static let googleSignalsSettingsUpdate = InputObjectShape(
    typeName: "GAGoogleSignalsSettingsUpdateInput",
    fields: [
      ArgumentDefinition("state", googleSignalsState, .bodyJSON("state"))
    ]
  )

  public static let reportingIdentitySettingsUpdate = InputObjectShape(
    typeName: "GAReportingIdentitySettingsUpdateInput",
    fields: [
      ArgumentDefinition("reportingIdentity", reportingIdentity, .bodyJSON("reportingIdentity"))
    ]
  )
}
