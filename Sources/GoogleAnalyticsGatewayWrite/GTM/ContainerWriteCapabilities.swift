import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Container mutations. Container deletion is gated behind its own Google
/// scope and belongs to the admin tier.
enum GTMContainerWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.containers.create"),
    field: "gtmCreateContainer",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/containers",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.account), .path("parent"), required: true),
      ArgumentDefinition("container", .inputObject(GTMWriteInputs.container), .bodyRoot, required: true)
    ],
    result: .payload(field: "container", GTMModels.container),
    scopes: .tagManagerEditContainers,
    summary: "Creates a Container."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.containers.update"),
    field: "gtmUpdateContainer",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.container), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("container", .inputObject(GTMWriteInputs.container), .bodyRoot, required: true)
    ],
    result: .payload(field: "container", GTMModels.container),
    scopes: .tagManagerEditContainers,
    summary: "Updates a Container."
  )
}
