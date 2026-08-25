import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Request bodies for the GA4 Data API v1alpha writer-tier creates.
///
/// Each shape is the resource's discovery schema minus every field Google marks
/// `Output only`, and minus `name`, which the route already carries. That leaves
/// very little: an audience list is defined by the audience it snapshots and the
/// dimensions to capture, a recurring audience list adds how many days it should
/// keep producing instances, and a report task is defined entirely by its report
/// definition.
///
/// The report definition follows the same split `GAReportInputs.reportRequest`
/// uses on the v1beta surface — typed selectors, `.json` for the recursive
/// filter expressions and the one-of trees — because it is the same message with
/// two extra keys.
public enum GAAlphaDataWriteInputs {

  public static let samplingLevel = ArgumentValueType.enumeration(
    "GASamplingLevel",
    ["SAMPLING_LEVEL_UNSPECIFIED", "LOW", "MEDIUM", "UNSAMPLED"]
  )

  /// `WebhookNotification`. Google POSTs the resource to `uri` each time the
  /// long-running operation changes state, echoing `channelToken` so the
  /// receiver can authenticate the call. The token is the caller's own secret
  /// and is passed through unread.
  public static let webhookNotification = InputObjectShape(
    typeName: "GAWebhookNotificationInput",
    fields: [
      ArgumentDefinition("uri", .string, .bodyJSON("uri")),
      ArgumentDefinition("channelToken", .string, .bodyJSON("channelToken"))
    ]
  )

  public static let audienceListCreate = InputObjectShape(
    typeName: "GAAudienceListCreateInput",
    fields: [
      ArgumentDefinition(
        "audience",
        .resourceName("properties/{property}/audiences/{audience}"),
        .bodyJSON("audience"),
        required: true
      ),
      ArgumentDefinition(
        "dimensions",
        .inputObjectList(GAWriteInputs.audienceDimension),
        .bodyJSON("dimensions"),
        required: true
      ),
      ArgumentDefinition(
        "webhookNotification",
        .inputObject(webhookNotification),
        .bodyJSON("webhookNotification")
      )
    ]
  )

  public static let recurringAudienceListCreate = InputObjectShape(
    typeName: "GARecurringAudienceListCreateInput",
    fields: [
      ArgumentDefinition(
        "audience",
        .resourceName("properties/{property}/audiences/{audience}"),
        .bodyJSON("audience"),
        required: true
      ),
      ArgumentDefinition(
        "dimensions",
        .inputObjectList(GAWriteInputs.audienceDimension),
        .bodyJSON("dimensions"),
        required: true
      ),
      ArgumentDefinition("activeDaysRemaining", .integer, .bodyJSON("activeDaysRemaining")),
      ArgumentDefinition(
        "webhookNotification",
        .inputObject(webhookNotification),
        .bodyJSON("webhookNotification")
      )
    ]
  )

  public static let reportDefinition = InputObjectShape(
    typeName: "GAReportDefinitionInput",
    fields: [
      ArgumentDefinition(
        "dateRanges",
        .inputObjectList(GAReportInputs.dateRange),
        .bodyJSON("dateRanges")
      ),
      ArgumentDefinition(
        "dimensions",
        .inputObjectList(GAReportInputs.dimension),
        .bodyJSON("dimensions")
      ),
      ArgumentDefinition(
        "metrics",
        .inputObjectList(GAReportInputs.metric),
        .bodyJSON("metrics")
      ),
      ArgumentDefinition("dimensionFilter", .json, .bodyJSON("dimensionFilter")),
      ArgumentDefinition("metricFilter", .json, .bodyJSON("metricFilter")),
      ArgumentDefinition("orderBys", .json, .bodyJSON("orderBys")),
      ArgumentDefinition("cohortSpec", .json, .bodyJSON("cohortSpec")),
      ArgumentDefinition("offset", .integer, .bodyJSON("offset")),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit")),
      ArgumentDefinition(
        "metricAggregations",
        GAReportInputs.metricAggregations,
        .bodyJSON("metricAggregations")
      ),
      ArgumentDefinition("currencyCode", .string, .bodyJSON("currencyCode")),
      ArgumentDefinition("keepEmptyRows", .boolean, .bodyJSON("keepEmptyRows")),
      ArgumentDefinition("samplingLevel", samplingLevel, .bodyJSON("samplingLevel"))
    ]
  )

  /// `ReportTask`'s only writable field is the report definition, so the create
  /// body is the one-key wrapper Google documents rather than the definition
  /// itself.
  public static let reportTaskCreate = InputObjectShape(
    typeName: "GAReportTaskCreateInput",
    fields: [
      ArgumentDefinition(
        "reportDefinition",
        .inputObject(reportDefinition),
        .bodyJSON("reportDefinition")
      )
    ]
  )
}
