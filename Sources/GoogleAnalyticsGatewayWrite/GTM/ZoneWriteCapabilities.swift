import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager zone mutations.
enum GTMZoneWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update, revert]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.zones.create"),
    field: "gtmCreateZone",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/zones",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("zone", .inputObject(GTMWriteInputs.zone), .bodyRoot, required: true)
    ],
    result: .payload(field: "zone", GTMModels.zone),
    scopes: .tagManagerEditContainers,
    summary: "Creates a GTM Zone."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.zones.update"),
    field: "gtmUpdateZone",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.zone), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("zone", .inputObject(GTMWriteInputs.zone), .bodyRoot, required: true)
    ],
    result: .payload(field: "zone", GTMModels.zone),
    scopes: .tagManagerEditContainers,
    summary: "Updates a GTM Zone."
  )

  static let revert = CapabilityDefinition(
    id: CapabilityID("gtm.zones.revert"),
    field: "gtmRevertZone",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:revert",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.zone), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint"))
    ],
    result: .single(GTMWriteModels.revertedZone),
    scopes: .tagManagerEditContainers,
    summary: "Reverts changes to a GTM Zone in a GTM Workspace."
  )
}
