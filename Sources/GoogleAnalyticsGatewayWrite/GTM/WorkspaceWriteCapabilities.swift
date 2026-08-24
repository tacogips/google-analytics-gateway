import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager workspace mutations: the workspace itself, the sync and
/// conflict-resolution verbs that reconcile it with the latest container
/// version, the quick preview, the bulk change apply, and the version creation
/// that consumes it.
///
/// The scopes differ by method even inside this one resource. Editing,
/// syncing, resolving, and bulk-updating a workspace are container edits;
/// quick preview and version creation build a container version and are
/// documented against the container-versions scope.
enum GTMWorkspaceWriteCapabilities {
  static let all: [CapabilityDefinition] = [
    create, update, sync, resolveConflict, quickPreview, createVersion, bulkUpdate
  ]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.create"),
    field: "gtmCreateWorkspace",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/workspaces",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.container), .path("parent"), required: true),
      ArgumentDefinition("workspace", .inputObject(GTMWriteInputs.workspace), .bodyRoot, required: true)
    ],
    result: .payload(field: "workspace", GTMModels.workspace),
    scopes: .tagManagerEditContainers,
    summary: "Creates a Workspace."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.update"),
    field: "gtmUpdateWorkspace",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.workspace), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("workspace", .inputObject(GTMWriteInputs.workspace), .bodyRoot, required: true)
    ],
    result: .payload(field: "workspace", GTMModels.workspace),
    scopes: .tagManagerEditContainers,
    summary: "Updates a Workspace."
  )

  static let sync = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.sync"),
    field: "gtmSyncWorkspace",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:sync",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.workspace), .path("path"), required: true)
    ],
    result: .single(GTMWriteModels.syncWorkspaceResult),
    scopes: .tagManagerEditContainers,
    summary: "Syncs a workspace to the latest container version by updating all unmodified "
      + "workspace entities and displaying conflicts for modified entities."
  )

  /// The body is the resolved entity, which carries whichever workspace entity
  /// the conflict is about. Google answers with an empty body.
  static let resolveConflict = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.resolveConflict"),
    field: "gtmResolveConflictWorkspace",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:resolve_conflict",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.workspace), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("entity", .inputObject(GTMWriteInputs.entity), .bodyRoot, required: true)
    ],
    result: .single(GTMWriteModels.acknowledgement),
    scopes: .tagManagerEditContainers,
    summary: "Resolves a merge conflict for a workspace entity by updating it to the resolved "
      + "entity passed in the request."
  )

  static let quickPreview = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.quickPreview"),
    field: "gtmQuickPreviewWorkspace",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:quick_preview",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.workspace), .path("path"), required: true)
    ],
    result: .single(GTMWriteModels.quickPreviewResult),
    scopes: .tagManagerEditContainerVersions,
    summary: "Quick previews a workspace by creating a fake container version from all entities "
      + "in the provided workspace."
  )

  /// Creating a version consumes the workspace: Google deletes it and reports
  /// the replacement it created as `newWorkspacePath`.
  static let createVersion = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.createVersion"),
    field: "gtmCreateVersion",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:create_version",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.workspace), .path("path"), required: true),
      ArgumentDefinition(
        "versionOptions",
        .inputObject(GTMWriteInputs.versionOptions),
        .bodyRoot,
        required: true
      )
    ],
    result: .single(GTMWriteModels.createVersionResult),
    scopes: .tagManagerEditContainerVersions,
    summary: "Creates a Container Version from the entities present in the workspace, deletes the "
      + "workspace, and sets the base container version to the newly created version."
  )

  /// New entities in a bulk change carry ids of the form `new_1`, `new_2`,
  /// which Google replaces with the real ids in the response.
  static let bulkUpdate = CapabilityDefinition(
    id: CapabilityID("gtm.workspaces.bulkUpdate"),
    field: "gtmBulkUpdateWorkspace",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}/bulk_update",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.workspace), .path("path"), required: true),
      ArgumentDefinition(
        "proposedChange",
        .inputObject(GTMWriteInputs.proposedChange),
        .bodyRoot,
        required: true
      )
    ],
    result: .single(GTMWriteModels.bulkUpdateResult),
    scopes: .tagManagerEditContainers,
    summary: "Applies multiple entity changes to a workspace in one call.",
    upstreamRejectionGuidance: "An entity being created in a bulk change must carry an id of the "
      + "form new_1, new_2, unique within the request; Google rejects the change otherwise."
  )
}
