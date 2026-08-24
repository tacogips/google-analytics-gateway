import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager tag mutations.
///
/// `update` and `revert` both accept the optimistic-locking `fingerprint`
/// Google returns with the entity: sending the one that was read back refuses
/// the write if the workspace moved on in between.
enum GTMTagWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update, revert]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.tags.create"),
    field: "gtmCreateTag",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/tags",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("tag", .inputObject(GTMWriteInputs.tag), .bodyRoot, required: true)
    ],
    result: .payload(field: "tag", GTMModels.tag),
    scopes: .tagManagerEditContainers,
    summary: "Creates a GTM Tag."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.tags.update"),
    field: "gtmUpdateTag",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.tag), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("tag", .inputObject(GTMWriteInputs.tag), .bodyRoot, required: true)
    ],
    result: .payload(field: "tag", GTMModels.tag),
    scopes: .tagManagerEditContainers,
    summary: "Updates a GTM Tag."
  )

  static let revert = CapabilityDefinition(
    id: CapabilityID("gtm.tags.revert"),
    field: "gtmRevertTag",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:revert",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.tag), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint"))
    ],
    result: .single(GTMWriteModels.revertedTag),
    scopes: .tagManagerEditContainers,
    summary: "Reverts changes to a GTM Tag in a GTM Workspace."
  )
}
