import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Result shapes for the Tag Manager mutations whose response is a wrapper
/// rather than the resource itself.
///
/// A create or an update answers with the resource, which `.payload` already
/// wraps for GraphQL. The methods here answer with a documented response
/// message instead — `RevertTagResponse` carries `tag`, `SyncWorkspaceResponse`
/// carries the conflicts and the sync status — so the wrapper is modelled as a
/// shape and projected with `.single`. Every entity inside reuses the reader's
/// `GTMModels` shape, so a tag returned by a revert and a tag returned by a get
/// project identically.
public enum GTMWriteModels {

  // MARK: - Revert responses

  public static let revertedTag = ModelShape(
    typeName: "GtmRevertedTag",
    fields: [ModelField("tag", .object(GTMModels.tag))]
  )

  public static let revertedTrigger = ModelShape(
    typeName: "GtmRevertedTrigger",
    fields: [ModelField("trigger", .object(GTMModels.trigger))]
  )

  public static let revertedVariable = ModelShape(
    typeName: "GtmRevertedVariable",
    fields: [ModelField("variable", .object(GTMModels.variable))]
  )

  public static let revertedClient = ModelShape(
    typeName: "GtmRevertedClient",
    fields: [ModelField("client", .object(GTMModels.client))]
  )

  public static let revertedFolder = ModelShape(
    typeName: "GtmRevertedFolder",
    fields: [ModelField("folder", .object(GTMModels.folder))]
  )

  public static let revertedZone = ModelShape(
    typeName: "GtmRevertedZone",
    fields: [ModelField("zone", .object(GTMModels.zone))]
  )

  /// `RevertTemplateResponse` names the reverted custom template `template`.
  public static let revertedTemplate = ModelShape(
    typeName: "GtmRevertedTemplate",
    fields: [ModelField("template", .object(GTMModels.template))]
  )

  public static let revertedTransformation = ModelShape(
    typeName: "GtmRevertedTransformation",
    fields: [ModelField("transformation", .object(GTMModels.transformation))]
  )

  /// `RevertBuiltInVariableResponse` reports whether the built-in variable is
  /// enabled in the workspace after the revert, not the variable itself.
  public static let revertedBuiltInVariable = ModelShape(
    typeName: "GtmRevertedBuiltInVariable",
    fields: [ModelField("enabled", .boolean)]
  )

  // MARK: - Workspace responses

  /// `SyncWorkspaceResponse`.
  public static let syncWorkspaceResult = ModelShape(
    typeName: "GtmSyncWorkspaceResult",
    fields: [
      ModelField("syncStatus", .object(GTMModels.syncStatus)),
      ModelField("mergeConflict", .objectList(GTMModels.mergeConflict))
    ]
  )

  /// `QuickPreviewResponse`.
  public static let quickPreviewResult = ModelShape(
    typeName: "GtmQuickPreviewResult",
    fields: [
      ModelField("containerVersion", .object(GTMModels.containerVersion)),
      ModelField("compilerError", .boolean),
      ModelField("syncStatus", .object(GTMModels.syncStatus))
    ]
  )

  /// `CreateContainerVersionResponse`. `newWorkspacePath` is the workspace
  /// Google creates in place of the one the version consumed.
  public static let createVersionResult = ModelShape(
    typeName: "GtmCreateVersionResult",
    fields: [
      ModelField("containerVersion", .object(GTMModels.containerVersion)),
      ModelField("compilerError", .boolean),
      ModelField("newWorkspacePath", .resourceName),
      ModelField("syncStatus", .object(GTMModels.syncStatus))
    ]
  )

  /// `BulkUpdateWorkspaceResponse`.
  public static let bulkUpdateResult = ModelShape(
    typeName: "GtmBulkUpdateWorkspaceResult",
    fields: [ModelField("changes", .objectList(GTMModels.entity))]
  )

  /// `FolderEntities`: the tags, triggers, and variables inside one folder.
  /// Three collections in one body, so it is projected as an entity rather than
  /// as a connection over a single collection key.
  public static let folderEntities = ModelShape(
    typeName: "GtmFolderEntities",
    fields: [
      ModelField("tag", .objectList(GTMModels.tag)),
      ModelField("trigger", .objectList(GTMModels.trigger)),
      ModelField("variable", .objectList(GTMModels.variable)),
      ModelField("nextPageToken", .string)
    ]
  )

  // MARK: - Version responses

  /// `PublishContainerVersionResponse`.
  public static let publishResult = ModelShape(
    typeName: "GtmPublishVersionResult",
    fields: [
      ModelField("containerVersion", .object(GTMModels.containerVersion)),
      ModelField("compilerError", .boolean)
    ]
  )

  // MARK: - Empty responses

  /// The two mutations Google documents with an empty success body:
  /// `folders.move_entities_to_folder` and `workspaces.resolve_conflict`.
  ///
  /// Neither answers with a resource, and the framework has no result shape for
  /// a body-less success, so the acknowledgement declares the one field Google
  /// would echo if it echoed anything. It is projected from whatever object the
  /// response carries, which for these two methods is empty, so `path` is null
  /// on success and the caller's own request name is the identity.
  public static let acknowledgement = ModelShape(
    typeName: "GtmMutationAcknowledgement",
    fields: [ModelField("path", .resourceName)]
  )
}
