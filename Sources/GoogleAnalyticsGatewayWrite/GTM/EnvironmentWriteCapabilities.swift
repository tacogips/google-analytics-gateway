import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Container environment mutations. Environments live under the container
/// rather than under a workspace.
enum GTMEnvironmentWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.environments.create"),
    field: "gtmCreateEnvironment",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/environments",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.container), .path("parent"), required: true),
      ArgumentDefinition("environment", .inputObject(GTMWriteInputs.environment), .bodyRoot, required: true)
    ],
    result: .payload(field: "environment", GTMModels.environment),
    scopes: .tagManagerEditContainers,
    summary: "Creates a GTM Environment."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.environments.update"),
    field: "gtmUpdateEnvironment",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.environment), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("environment", .inputObject(GTMWriteInputs.environment), .bodyRoot, required: true)
    ],
    result: .payload(field: "environment", GTMModels.environment),
    scopes: .tagManagerEditContainers,
    summary: "Updates a GTM Environment."
  )
}
