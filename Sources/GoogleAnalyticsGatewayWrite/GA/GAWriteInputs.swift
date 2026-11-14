import GoogleAnalyticsGatewayCore

/// Request bodies for the GA4 writer-tier mutations.
///
/// Every shape is the resource's own discovery schema minus the fields Google
/// marks `Output only`, because sending one back is either ignored or refused.
/// Create and update are separate shapes wherever the two differ: a create must
/// carry the fields Google marks `Required`, while a patch names what it changes
/// through `updateMask` and would be unusable if it demanded them again, and a
/// field Google marks `Immutable` belongs to the create shape alone. Where the
/// two would be identical — a Measurement Protocol secret has one writable
/// field — one shape serves both.
///
/// `name` is deliberately absent from every shape. The route already carries the
/// resource name for a patch and Google assigns it on a create, so accepting one
/// in the body would only let a caller send a name that disagrees with the URL
/// the request is actually sent to.
///
/// Enumerations are typed from the discovery `enum` lists rather than left as
/// strings, so an unaccepted value is a named local validation error instead of
/// an upstream 400.
public enum GAWriteInputs {

  // MARK: - Shared arguments

  /// The field mask every GA4 Admin patch method takes.
  ///
  /// Google's discovery leaves the parameter's `required` flag unset, as it does
  /// for every query parameter, while the parameter's own documentation opens
  /// with "Required." on all ten patch methods this module registers. A patch
  /// sent without it is refused upstream, so it is required here and the refusal
  /// is a local validation error instead of a wasted round trip.
  public static let updateMask = ArgumentDefinition(
    "updateMask",
    .string,
    .query("updateMask"),
    required: true
  )

  // MARK: - Enumerations

  public static let propertyType = ArgumentValueType.enumeration(
    "GAPropertyType",
    [
      "PROPERTY_TYPE_UNSPECIFIED",
      "PROPERTY_TYPE_ORDINARY",
      "PROPERTY_TYPE_SUBPROPERTY",
      "PROPERTY_TYPE_ROLLUP"
    ]
  )

  public static let industryCategory = ArgumentValueType.enumeration(
    "GAIndustryCategory",
    [
      "INDUSTRY_CATEGORY_UNSPECIFIED",
      "AUTOMOTIVE",
      "BUSINESS_AND_INDUSTRIAL_MARKETS",
      "FINANCE",
      "HEALTHCARE",
      "TECHNOLOGY",
      "TRAVEL",
      "OTHER",
      "ARTS_AND_ENTERTAINMENT",
      "BEAUTY_AND_FITNESS",
      "BOOKS_AND_LITERATURE",
      "FOOD_AND_DRINK",
      "GAMES",
      "HOBBIES_AND_LEISURE",
      "HOME_AND_GARDEN",
      "INTERNET_AND_TELECOM",
      "LAW_AND_GOVERNMENT",
      "NEWS",
      "ONLINE_COMMUNITIES",
      "PEOPLE_AND_SOCIETY",
      "PETS_AND_ANIMALS",
      "REAL_ESTATE",
      "REFERENCE",
      "SCIENCE",
      "SPORTS",
      "JOBS_AND_EDUCATION",
      "SHOPPING"
    ]
  )

  public static let retentionDuration = ArgumentValueType.enumeration(
    "GARetentionDuration",
    [
      "RETENTION_DURATION_UNSPECIFIED",
      "TWO_MONTHS",
      "FOURTEEN_MONTHS",
      "TWENTY_SIX_MONTHS",
      "THIRTY_EIGHT_MONTHS",
      "FIFTY_MONTHS"
    ]
  )

  public static let dataStreamType = ArgumentValueType.enumeration(
    "GADataStreamType",
    [
      "DATA_STREAM_TYPE_UNSPECIFIED",
      "WEB_DATA_STREAM",
      "ANDROID_APP_DATA_STREAM",
      "IOS_APP_DATA_STREAM"
    ]
  )

  public static let dimensionScope = ArgumentValueType.enumeration(
    "GADimensionScope",
    ["DIMENSION_SCOPE_UNSPECIFIED", "EVENT", "USER", "ITEM"]
  )

  public static let metricScope = ArgumentValueType.enumeration(
    "GAMetricScope",
    ["METRIC_SCOPE_UNSPECIFIED", "EVENT"]
  )

  public static let measurementUnit = ArgumentValueType.enumeration(
    "GAMeasurementUnit",
    [
      "MEASUREMENT_UNIT_UNSPECIFIED",
      "STANDARD",
      "CURRENCY",
      "FEET",
      "METERS",
      "KILOMETERS",
      "MILES",
      "MILLISECONDS",
      "SECONDS",
      "MINUTES",
      "HOURS"
    ]
  )

  public static let restrictedMetricType = ArgumentValueType.enumerationList(
    "GARestrictedMetricType",
    ["RESTRICTED_METRIC_TYPE_UNSPECIFIED", "COST_DATA", "REVENUE_DATA"]
  )

  /// The conversion-event and key-event counting methods are separate types:
  /// Google spells the unspecified member differently in each schema, so one
  /// shared enumeration would accept a value the other method refuses.
  public static let conversionCountingMethod = ArgumentValueType.enumeration(
    "GAConversionCountingMethod",
    ["CONVERSION_COUNTING_METHOD_UNSPECIFIED", "ONCE_PER_EVENT", "ONCE_PER_SESSION"]
  )

  public static let keyEventCountingMethod = ArgumentValueType.enumeration(
    "GAKeyEventCountingMethod",
    ["COUNTING_METHOD_UNSPECIFIED", "ONCE_PER_EVENT", "ONCE_PER_SESSION"]
  )

  // MARK: - Accounts and properties

  public static let accountUpdate = InputObjectShape(
    typeName: "GAAccountUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition("regionCode", .string, .bodyJSON("regionCode"))
    ]
  )

  /// `parent` is `Immutable` rather than `Required` in the schema, but a
  /// property has to be created somewhere: without it the API answers 400, so
  /// requiring it here turns a wasted round trip into a local error. It accepts
  /// an account for an ordinary property and a property for a subproperty or
  /// rollup, which is the pair of formats Google documents.
  public static let propertyCreate = InputObjectShape(
    typeName: "GAPropertyCreateInput",
    fields: [
      ArgumentDefinition(
        "parent",
        .resourceName(["accounts/{account}", "properties/{property}"]),
        .bodyJSON("parent"),
        required: true
      ),
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition("timeZone", .string, .bodyJSON("timeZone"), required: true),
      ArgumentDefinition("propertyType", propertyType, .bodyJSON("propertyType")),
      ArgumentDefinition("industryCategory", industryCategory, .bodyJSON("industryCategory")),
      ArgumentDefinition("currencyCode", .string, .bodyJSON("currencyCode"))
    ]
  )

  public static let propertyUpdate = InputObjectShape(
    typeName: "GAPropertyUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition("timeZone", .string, .bodyJSON("timeZone")),
      ArgumentDefinition("industryCategory", industryCategory, .bodyJSON("industryCategory")),
      ArgumentDefinition("currencyCode", .string, .bodyJSON("currencyCode"))
    ]
  )

  public static let dataRetentionSettingsUpdate = InputObjectShape(
    typeName: "GADataRetentionSettingsUpdateInput",
    fields: [
      ArgumentDefinition("eventDataRetention", retentionDuration, .bodyJSON("eventDataRetention")),
      ArgumentDefinition("userDataRetention", retentionDuration, .bodyJSON("userDataRetention")),
      ArgumentDefinition(
        "resetUserDataOnNewActivity",
        .boolean,
        .bodyJSON("resetUserDataOnNewActivity")
      )
    ]
  )

  // MARK: - Data streams

  /// The web, Android, and iOS stream bodies carry one writable field each; the
  /// measurement and Firebase app ids Google returns alongside them are assigned
  /// upstream.
  public static let webStreamData = InputObjectShape(
    typeName: "GAWebStreamDataInput",
    fields: [
      ArgumentDefinition("defaultUri", .string, .bodyJSON("defaultUri"))
    ]
  )

  public static let androidAppStreamData = InputObjectShape(
    typeName: "GAAndroidAppStreamDataInput",
    fields: [
      ArgumentDefinition("packageName", .string, .bodyJSON("packageName"), required: true)
    ]
  )

  public static let iosAppStreamData = InputObjectShape(
    typeName: "GAIosAppStreamDataInput",
    fields: [
      ArgumentDefinition("bundleId", .string, .bodyJSON("bundleId"), required: true)
    ]
  )

  public static let dataStreamCreate = InputObjectShape(
    typeName: "GADataStreamCreateInput",
    fields: [
      ArgumentDefinition("type", dataStreamType, .bodyJSON("type"), required: true),
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition("webStreamData", .inputObject(webStreamData), .bodyJSON("webStreamData")),
      ArgumentDefinition(
        "androidAppStreamData",
        .inputObject(androidAppStreamData),
        .bodyJSON("androidAppStreamData")
      ),
      ArgumentDefinition(
        "iosAppStreamData",
        .inputObject(iosAppStreamData),
        .bodyJSON("iosAppStreamData")
      )
    ]
  )

  /// A stream's type and its app identifiers are immutable, so an update carries
  /// only the display name and the web stream's default URI.
  public static let dataStreamUpdate = InputObjectShape(
    typeName: "GADataStreamUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition("webStreamData", .inputObject(webStreamData), .bodyJSON("webStreamData"))
    ]
  )

  /// The display name is a Measurement Protocol secret's only writable field, so
  /// create and update take the same body. The secret value itself is generated
  /// by Google and cannot be supplied.
  public static let measurementProtocolSecret = InputObjectShape(
    typeName: "GAMeasurementProtocolSecretInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true)
    ]
  )

  // MARK: - Custom definitions

  public static let customDimensionCreate = InputObjectShape(
    typeName: "GACustomDimensionCreateInput",
    fields: [
      ArgumentDefinition("parameterName", .string, .bodyJSON("parameterName"), required: true),
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition("scope", dimensionScope, .bodyJSON("scope"), required: true),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition(
        "disallowAdsPersonalization",
        .boolean,
        .bodyJSON("disallowAdsPersonalization")
      )
    ]
  )

  public static let customDimensionUpdate = InputObjectShape(
    typeName: "GACustomDimensionUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition(
        "disallowAdsPersonalization",
        .boolean,
        .bodyJSON("disallowAdsPersonalization")
      )
    ]
  )

  public static let customMetricCreate = InputObjectShape(
    typeName: "GACustomMetricCreateInput",
    fields: [
      ArgumentDefinition("parameterName", .string, .bodyJSON("parameterName"), required: true),
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition("measurementUnit", measurementUnit, .bodyJSON("measurementUnit"), required: true),
      ArgumentDefinition("scope", metricScope, .bodyJSON("scope"), required: true),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("restrictedMetricType", restrictedMetricType, .bodyJSON("restrictedMetricType"))
    ]
  )

  public static let customMetricUpdate = InputObjectShape(
    typeName: "GACustomMetricUpdateInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName")),
      ArgumentDefinition("description", .string, .bodyJSON("description")),
      ArgumentDefinition("measurementUnit", measurementUnit, .bodyJSON("measurementUnit")),
      ArgumentDefinition("restrictedMetricType", restrictedMetricType, .bodyJSON("restrictedMetricType"))
    ]
  )

  // MARK: - Conversion and key events

  public static let conversionValue = InputObjectShape(
    typeName: "GAConversionValueInput",
    fields: [
      ArgumentDefinition("value", .number, .bodyJSON("value")),
      ArgumentDefinition("currencyCode", .string, .bodyJSON("currencyCode"))
    ]
  )

  public static let conversionEventCreate = InputObjectShape(
    typeName: "GAConversionEventCreateInput",
    fields: [
      ArgumentDefinition("eventName", .string, .bodyJSON("eventName"), required: true),
      ArgumentDefinition("countingMethod", conversionCountingMethod, .bodyJSON("countingMethod")),
      ArgumentDefinition(
        "defaultConversionValue",
        .inputObject(conversionValue),
        .bodyJSON("defaultConversionValue")
      )
    ]
  )

  public static let conversionEventUpdate = InputObjectShape(
    typeName: "GAConversionEventUpdateInput",
    fields: [
      ArgumentDefinition("countingMethod", conversionCountingMethod, .bodyJSON("countingMethod")),
      ArgumentDefinition(
        "defaultConversionValue",
        .inputObject(conversionValue),
        .bodyJSON("defaultConversionValue")
      )
    ]
  )

  public static let keyEventDefaultValue = InputObjectShape(
    typeName: "GAKeyEventDefaultValueInput",
    fields: [
      ArgumentDefinition("numericValue", .number, .bodyJSON("numericValue"), required: true),
      ArgumentDefinition("currencyCode", .string, .bodyJSON("currencyCode"), required: true)
    ]
  )

  public static let keyEventCreate = InputObjectShape(
    typeName: "GAKeyEventCreateInput",
    fields: [
      ArgumentDefinition("eventName", .string, .bodyJSON("eventName"), required: true),
      ArgumentDefinition("countingMethod", keyEventCountingMethod, .bodyJSON("countingMethod"), required: true),
      ArgumentDefinition("defaultValue", .inputObject(keyEventDefaultValue), .bodyJSON("defaultValue"))
    ]
  )

  public static let keyEventUpdate = InputObjectShape(
    typeName: "GAKeyEventUpdateInput",
    fields: [
      ArgumentDefinition("countingMethod", keyEventCountingMethod, .bodyJSON("countingMethod")),
      ArgumentDefinition("defaultValue", .inputObject(keyEventDefaultValue), .bodyJSON("defaultValue"))
    ]
  )

  // MARK: - Product links

  /// Google accepts either a project number or a project id in the `projects/`
  /// name at creation and always returns the number afterwards.
  public static let firebaseLinkCreate = InputObjectShape(
    typeName: "GAFirebaseLinkCreateInput",
    fields: [
      ArgumentDefinition(
        "project",
        .resourceName("projects/{project}"),
        .bodyJSON("project"),
        required: true
      )
    ]
  )

  public static let googleAdsLinkCreate = InputObjectShape(
    typeName: "GAGoogleAdsLinkCreateInput",
    fields: [
      ArgumentDefinition("customerId", .string, .bodyJSON("customerId"), required: true),
      ArgumentDefinition(
        "adsPersonalizationEnabled",
        .boolean,
        .bodyJSON("adsPersonalizationEnabled")
      )
    ]
  )

  /// The linked customer id is immutable, so personalized advertising is the one
  /// setting an update can change.
  public static let googleAdsLinkUpdate = InputObjectShape(
    typeName: "GAGoogleAdsLinkUpdateInput",
    fields: [
      ArgumentDefinition(
        "adsPersonalizationEnabled",
        .boolean,
        .bodyJSON("adsPersonalizationEnabled")
      )
    ]
  )

  // MARK: - Audience exports

  public static let audienceDimension = InputObjectShape(
    typeName: "GAAudienceDimensionInput",
    fields: [
      ArgumentDefinition("dimensionName", .string, .bodyJSON("dimensionName"), required: true)
    ]
  )

  public static let audienceExportCreate = InputObjectShape(
    typeName: "GAAudienceExportCreateInput",
    fields: [
      ArgumentDefinition(
        "audience",
        .resourceName("properties/{property}/audiences/{audience}"),
        .bodyJSON("audience"),
        required: true
      ),
      ArgumentDefinition(
        "dimensions",
        .inputObjectList(audienceDimension),
        .bodyJSON("dimensions"),
        required: true
      )
    ]
  )
}
