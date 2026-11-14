import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager user-defined variable mutations. Built-in variables are a
/// separate collection with its own create and revert methods.
enum GTMVariableWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update, revert]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.variables.create"),
    field: "gtmCreateVariable",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/variables",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("variable", .inputObject(GTMWriteInputs.variable), .bodyRoot, required: true)
    ],
    result: .payload(field: "variable", GTMModels.variable),
    scopes: .tagManagerEditContainers,
    summary: "Creates a GTM Variable."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.variables.update"),
    field: "gtmUpdateVariable",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.variable), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("variable", .inputObject(GTMWriteInputs.variable), .bodyRoot, required: true)
    ],
    result: .payload(field: "variable", GTMModels.variable),
    scopes: .tagManagerEditContainers,
    summary: "Updates a GTM Variable."
  )

  static let revert = CapabilityDefinition(
    id: CapabilityID("gtm.variables.revert"),
    field: "gtmRevertVariable",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:revert",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.variable), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint"))
    ],
    result: .single(GTMWriteModels.revertedVariable),
    scopes: .tagManagerEditContainers,
    summary: "Reverts changes to a GTM Variable in a GTM Workspace."
  )
}
