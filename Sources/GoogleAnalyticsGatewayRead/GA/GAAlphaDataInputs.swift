import GoogleAnalyticsGatewayCore

/// Request bodies for the GA4 Data API v1alpha read methods that POST a
/// specification.
///
/// The rules are the ones `GAReportInputs` already follows for the v1beta
/// surface, and the selectors those two surfaces share — `DateRange`,
/// `Dimension` — are reused from it rather than restated, because a date range
/// is the same message whichever version accepts it. What is specific here is
/// the funnel: `Funnel`, `Segment`, and `FilterExpression` are all directly
/// recursive in Google's own schema — a funnel step holds a
/// `FunnelFilterExpression` whose `andGroup`, `orGroup`, and `notExpression`
/// branches hold further expressions of the same type, and a segment nests
/// condition groups the same way — so an `InputObjectShape` could only describe
/// them by bottoming out at some arbitrary depth, which would reject documents
/// the API accepts. Those three travel as `.json` and are validated upstream;
/// everything finite around them is typed.
public enum GAAlphaDataInputs {

  public static let funnelVisualizationType = ArgumentValueType.enumeration(
    "GAFunnelVisualizationType",
    ["FUNNEL_VISUALIZATION_TYPE_UNSPECIFIED", "STANDARD_FUNNEL", "TRENDED_FUNNEL"]
  )

  /// `FunnelBreakdown` adds a dimension to the funnel table sub report.
  public static let funnelBreakdown = InputObjectShape(
    typeName: "GAFunnelBreakdownInput",
    fields: [
      ArgumentDefinition(
        "breakdownDimension",
        .inputObject(GAReportInputs.dimension),
        .bodyJSON("breakdownDimension")
      ),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit"))
    ]
  )

  /// `FunnelNextAction` adds a dimension to the funnel visualization sub report.
  public static let funnelNextAction = InputObjectShape(
    typeName: "GAFunnelNextActionInput",
    fields: [
      ArgumentDefinition(
        "nextActionDimension",
        .inputObject(GAReportInputs.dimension),
        .bodyJSON("nextActionDimension")
      ),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit"))
    ]
  )

  public static let funnelReportRequest = InputObjectShape(
    typeName: "GAFunnelReportRequestInput",
    fields: [
      ArgumentDefinition(
        "dateRanges",
        .inputObjectList(GAReportInputs.dateRange),
        .bodyJSON("dateRanges")
      ),
      ArgumentDefinition("funnel", .json, .bodyJSON("funnel")),
      ArgumentDefinition(
        "funnelBreakdown",
        .inputObject(funnelBreakdown),
        .bodyJSON("funnelBreakdown")
      ),
      ArgumentDefinition(
        "funnelNextAction",
        .inputObject(funnelNextAction),
        .bodyJSON("funnelNextAction")
      ),
      ArgumentDefinition(
        "funnelVisualizationType",
        funnelVisualizationType,
        .bodyJSON("funnelVisualizationType")
      ),
      ArgumentDefinition("segments", .json, .bodyJSON("segments")),
      ArgumentDefinition("dimensionFilter", .json, .bodyJSON("dimensionFilter")),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit")),
      ArgumentDefinition("returnPropertyQuota", .boolean, .bodyJSON("returnPropertyQuota"))
    ]
  )

  public static let audienceListQuery = InputObjectShape(
    typeName: "GAAudienceListQueryInput",
    fields: [
      ArgumentDefinition("offset", .integer, .bodyJSON("offset")),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit"))
    ]
  )

  public static let reportTaskQuery = InputObjectShape(
    typeName: "GAReportTaskQueryInput",
    fields: [
      ArgumentDefinition("offset", .integer, .bodyJSON("offset")),
      ArgumentDefinition("limit", .integer, .bodyJSON("limit"))
    ]
  )
}
