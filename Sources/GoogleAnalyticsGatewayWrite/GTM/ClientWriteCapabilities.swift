import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager client mutations (server-side containers).
enum GTMClientWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update, revert]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.clients.create"),
    field: "gtmCreateClient",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/clients",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("client", .inputObject(GTMWriteInputs.client), .bodyRoot, required: true)
    ],
    result: .payload(field: "client", GTMModels.client),
    scopes: .tagManagerEditContainers,
    summary: "Creates a GTM Client."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.clients.update"),
    field: "gtmUpdateClient",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.client), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("client", .inputObject(GTMWriteInputs.client), .bodyRoot, required: true)
    ],
    result: .payload(field: "client", GTMModels.client),
    scopes: .tagManagerEditContainers,
    summary: "Updates a GTM Client."
  )

  static let revert = CapabilityDefinition(
    id: CapabilityID("gtm.clients.revert"),
    field: "gtmRevertClient",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:revert",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.client), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint"))
    ],
    result: .single(GTMWriteModels.revertedClient),
    scopes: .tagManagerEditContainers,
    summary: "Reverts changes to a GTM Client in a GTM Workspace."
  )
}
