import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager transformation mutations (server-side containers).
enum GTMTransformationWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, update, revert]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.transformations.create"),
    field: "gtmCreateTransformation",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/transformations",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition(
        "transformation",
        .inputObject(GTMWriteInputs.transformation),
        .bodyRoot,
        required: true
      )
    ],
    result: .payload(field: "transformation", GTMModels.transformation),
    scopes: .tagManagerEditContainers,
    summary: "Creates a GTM Transformation."
  )

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.transformations.update"),
    field: "gtmUpdateTransformation",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition(
        "path",
        .resourceName(GTMResourceNames.transformation),
        .path("path"),
        required: true
      ),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition(
        "transformation",
        .inputObject(GTMWriteInputs.transformation),
        .bodyRoot,
        required: true
      )
    ],
    result: .payload(field: "transformation", GTMModels.transformation),
    scopes: .tagManagerEditContainers,
    summary: "Updates a GTM Transformation."
  )

  static let revert = CapabilityDefinition(
    id: CapabilityID("gtm.transformations.revert"),
    field: "gtmRevertTransformation",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:revert",
    arguments: [
      ArgumentDefinition(
        "path",
        .resourceName(GTMResourceNames.transformation),
        .path("path"),
        required: true
      ),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint"))
    ],
    result: .single(GTMWriteModels.revertedTransformation),
    scopes: .tagManagerEditContainers,
    summary: "Reverts changes to a GTM Transformation in a GTM Workspace."
  )
}
