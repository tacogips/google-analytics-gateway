import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Google tag configuration mutations. Google names the collection
/// `gtag_config` in the singular, and the capability ids follow it.
enum GTMGtagConfigWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.gtagConfig.create"),
    field: "gtmCreateGtagConfig",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/gtag_config",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("gtagConfig", .inputObject(GTMWriteInputs.gtagConfig), .bodyRoot, required: true)
    ],
    result: .payload(field: "gtagConfig", GTMModels.gtagConfig),
    scopes: .tagManagerEditContainers,
    summary: "Creates a Google tag config."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.gtagConfig.update"),
    field: "gtmUpdateGtagConfig",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition("path", .resourceName(GTMResourceNames.gtagConfig), .path("path"), required: true),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition("gtagConfig", .inputObject(GTMWriteInputs.gtagConfig), .bodyRoot, required: true)
    ],
    result: .payload(field: "gtagConfig", GTMModels.gtagConfig),
    scopes: .tagManagerEditContainers,
    summary: "Updates a Google tag config."
  )
}
