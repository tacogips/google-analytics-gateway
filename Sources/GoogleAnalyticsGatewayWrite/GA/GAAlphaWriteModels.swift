import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Output shapes for the v1alpha mutations whose response is a documented
/// wrapper message rather than the resource itself.
///
/// Every other alpha mutation answers with a resource `GAAlphaModels` already
/// describes, so it reuses that shape and `.payload` wraps it for GraphQL. Three
/// admin-surface responses cannot: `CreateRollupPropertyResponse` carries a
/// property *and* the
/// source links created alongside it, `ProvisionSubpropertyResponse` carries a
/// property *and* an event filter, and
/// `ApproveDisplayVideo360AdvertiserLinkProposalResponse` carries the link the
/// approval produced rather than the proposal that was approved. The wrapper is
/// modelled here and projected with `.single`, which is how `GTMWriteModels`
/// handles the same situation on the Tag Manager surface. Every entity inside
/// reuses the reader's shape, so a property returned by a roll-up create and a
/// property returned by a get project identically.
///
/// The fourth is the Data API's long-running operation, which is a wrapper for
/// a different reason: the resource it will produce does not exist yet.
public enum GAAlphaWriteModels {

  /// The long-running operation the Data API v1alpha creates answer with.
  ///
  /// `CreateAudienceList` and `CreateReportTask` both start an asynchronous job
  /// and return the operation rather than the resource, exactly as
  /// `CreateAudienceExport` does on the v1beta surface. `response` and
  /// `metadata` are `google.protobuf.Any` documents whose type depends on how
  /// far the job has progressed, and `error` is a `google.rpc.Status` with an
  /// open `details` list, so all three travel verbatim. The operation's `name`
  /// is the resource name of the audience list or report task being built,
  /// which is what the matching reader field takes.
  public static let dataOperation = ModelShape(
    typeName: "GADataOperation",
    fields: [
      ModelField("name", .resourceName),
      ModelField("done", .boolean),
      ModelField("response", .json),
      ModelField("metadata", .json),
      ModelField("error", .json)
    ]
  )

  /// `CreateRollupPropertyResponse`. Creating a roll-up property also creates
  /// one source link per property named in `sourceProperties`, and Google
  /// returns them together because the links carry the ids a caller needs to
  /// manage the sources afterwards.
  public static let createRollupPropertyResult = ModelShape(
    typeName: "GACreateRollupPropertyResult",
    fields: [
      ModelField("rollupProperty", .object(GAModels.property)),
      ModelField("rollupPropertySourceLinks", .objectList(GAAlphaModels.rollupPropertySourceLink))
    ]
  )

  /// `ProvisionSubpropertyResponse`. The event filter is present only when the
  /// request asked for one; it belongs to the ordinary parent property, not to
  /// the subproperty that was just created.
  public static let provisionSubpropertyResult = ModelShape(
    typeName: "GAProvisionSubpropertyResult",
    fields: [
      ModelField("subproperty", .object(GAModels.property)),
      ModelField("subpropertyEventFilter", .object(GAAlphaModels.subpropertyEventFilter))
    ]
  )

  /// `ApproveDisplayVideo360AdvertiserLinkProposalResponse`. Approving consumes
  /// the proposal and produces a link, so the response names the link; the
  /// proposal's own resource name is the `name` argument the planner validated
  /// before the call.
  public static let approvedDisplayVideo360AdvertiserLink = ModelShape(
    typeName: "GAApprovedDisplayVideo360AdvertiserLink",
    fields: [
      ModelField(
        "displayVideo360AdvertiserLink",
        .object(GAAlphaModels.displayVideo360AdvertiserLink)
      )
    ]
  )
}
