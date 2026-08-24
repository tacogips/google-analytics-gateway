import GoogleAnalyticsGatewayCore

/// Output shapes that exist only on the writer surface.
///
/// Every other GA4 mutation answers with a resource the reader already models,
/// so it reuses `GAModels`. Two do not: an archive answers with Google's empty
/// message, and creating an audience export answers with a long-running
/// operation rather than the export itself.
public enum GAWriteModels {

  /// The acknowledgement of an archive.
  ///
  /// `archive` is declared to return `GoogleProtobufEmpty`, so a success carries
  /// `{}` and there is no resource to project: `name` is present in the shape
  /// because an empty response body still has to become an object the caller can
  /// select from, and it is null on every real success. The resource that was
  /// archived is the `name` argument the planner validated before the call.
  ///
  /// A `.deletion` result would model this exactly — it confirms from the
  /// validated request name — but the registry restricts that shape to delete
  /// operations in the admin tier, and `.payload` refuses an empty body outright.
  /// See the note in the writer registry report.
  public static let archiveAcknowledgement = ModelShape(
    typeName: "GAArchiveAcknowledgement",
    fields: [
      ModelField("name", .resourceName)
    ]
  )

  /// The long-running operation `CreateAudienceExport` answers with.
  ///
  /// `response` and `metadata` are `google.protobuf.Any` documents whose type
  /// depends on how far the export has progressed, and `error` is a
  /// `google.rpc.Status` with an open `details` list, so all three travel
  /// verbatim. The operation's `name` is the audience export's own resource
  /// name, which is what `gaAudienceExport` and `gaQueryAudienceExport` take.
  public static let audienceExportOperation = ModelShape(
    typeName: "GAAudienceExportOperation",
    fields: [
      ModelField("name", .resourceName),
      ModelField("done", .boolean),
      ModelField("response", .json),
      ModelField("metadata", .json),
      ModelField("error", .json)
    ]
  )
}
