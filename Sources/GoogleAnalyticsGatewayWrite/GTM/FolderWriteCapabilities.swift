import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager folder mutations, plus the two folder methods Google models as
/// custom POST verbs: listing the entities a folder holds, and moving entities
/// into it.
enum GTMFolderWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update, revert, entities, moveEntities]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.folders.create"),
    field: "gtmCreateFolder",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/folders",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("folder", .inputObject(GTMWriteInputs.folder), .bodyRoot, required: true)
    ],
    result: .payload(field: "folder", GTMModels.folder),
    scopes: .tagManagerEditContainers,
    summary: "Creates a GTM Folder."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.folders.update"),
    field: "gtmUpdateFolder",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.folder), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("folder", .inputObject(GTMWriteInputs.folder), .bodyRoot, required: true)
    ],
    result: .payload(field: "folder", GTMModels.folder),
    scopes: .tagManagerEditContainers,
    summary: "Updates a GTM Folder."
  )

  static let revert = CapabilityDefinition(
    id: CapabilityID("gtm.folders.revert"),
    field: "gtmRevertFolder",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:revert",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.folder), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint"))
    ],
    result: .single(GTMWriteModels.revertedFolder),
    scopes: .tagManagerEditContainers,
    summary: "Reverts changes to a GTM Folder in a GTM Workspace."
  )

  /// Google exposes the folder's contents as a POST verb on the folder rather
  /// than as a list method, and the field catalog places it in the writer tier
  /// alongside the folder mutations it accompanies. The body carries three
  /// collections at once — tags, triggers, and variables — so it is projected
  /// as an entity rather than as a connection over a single collection key,
  /// and the page argument exists only to carry the continuation token Google
  /// documents for it.
  static let entities = CapabilityDefinition(
    id: CapabilityID("gtm.folders.entities"),
    field: "gtmFolderEntities",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:entities",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.folder), .path("path"), required: true),
      // A plain token pass-through: the result is not a connection, and Tag
      // Manager documents no pageSize on this method, so the `.page` input
      // (which the planner validates against a connection's page bound) does
      // not apply here.
      ArgumentDefinition("pageToken", .string, .query("pageToken"))
    ],
    result: .single(GTMWriteModels.folderEntities),
    scopes: .tagManagerEditContainers,
    summary: "List all entities in a GTM Folder."
  )

  /// The entity ids are repeated query parameters, one per moved entity, and
  /// Google answers with an empty body.
  static let moveEntities = CapabilityDefinition(
    id: CapabilityID("gtm.folders.moveEntitiesToFolder"),
    field: "gtmMoveEntitiesToFolder",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:move_entities_to_folder",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.folder), .path("path"), required: true),
      ArgumentDefinition("tagId", .stringList, .queryList("tagId")),
      ArgumentDefinition("triggerId", .stringList, .queryList("triggerId")),
      ArgumentDefinition("variableId", .stringList, .queryList("variableId")),
      // Google documents a Folder body for the move, but the folder being moved
      // into is the one in the path, so the body is left optional.
      ArgumentDefinition("folder", .inputObject(GTMWriteInputs.folder), .bodyRoot)
    ],
    result: .single(GTMWriteModels.acknowledgement),
    scopes: .tagManagerEditContainers,
    summary: "Moves entities to a GTM Folder.",
    upstreamRejectionGuidance: "A folder id of 0 in the path moves the named entities out of the "
      + "folder they currently belong to instead of into one."
  )
}
