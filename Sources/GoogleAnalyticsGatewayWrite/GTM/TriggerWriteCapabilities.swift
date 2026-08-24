import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager trigger mutations.
enum GTMTriggerWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update, revert]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.triggers.create"),
    field: "gtmCreateTrigger",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/triggers",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("trigger", .inputObject(GTMWriteInputs.trigger), .bodyRoot, required: true)
    ],
    result: .payload(field: "trigger", GTMModels.trigger),
    scopes: .tagManagerEditContainers,
    summary: "Creates a GTM Trigger."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.triggers.update"),
    field: "gtmUpdateTrigger",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.trigger), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("trigger", .inputObject(GTMWriteInputs.trigger), .bodyRoot, required: true)
    ],
    result: .payload(field: "trigger", GTMModels.trigger),
    scopes: .tagManagerEditContainers,
    summary: "Updates a GTM Trigger."
  )

  static let revert = CapabilityDefinition(
    id: CapabilityID("gtm.triggers.revert"),
    field: "gtmRevertTrigger",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:revert",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.trigger), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint"))
    ],
    result: .single(GTMWriteModels.revertedTrigger),
    scopes: .tagManagerEditContainers,
    summary: "Reverts changes to a GTM Trigger in a GTM Workspace."
  )
}
