import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager built-in variable mutations.
///
/// Built-in variables are enabled and reverted by type rather than by body, so
/// neither method sends a request body: `create` repeats the `type` query
/// parameter once per variable it enables and answers with the enabled set,
/// while `revert` takes a single type and answers with whether it is still
/// enabled.
///
/// The type stays a string rather than an enumeration. Google documents 117
/// values today and adds one whenever the product grows a new automatic
/// variable, so a curated list would refuse a type the API accepts.
enum GTMBuiltInVariableWriteCapabilities {
  static let all: [CapabilityDefinition] = [create, revert]

  static let create = CapabilityDefinition(
    id: CapabilityID("gtm.builtInVariables.create"),
    field: "gtmCreateBuiltInVariable",
    tier: .writer,
    operationClass: .create,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{parent}/built_in_variables",
    arguments: [
      ArgumentDefinition("parent", .resourceName(GTMResourceNames.workspace), .path("parent"), required: true),
      ArgumentDefinition("type", .stringList, .queryList("type"))
    ],
    result: .list(collection: "builtInVariable", GTMModels.builtInVariable),
    scopes: .tagManagerEditContainers,
    summary: "Creates one or more GTM Built-In Variables."
  )

  static let revert = CapabilityDefinition(
    id: CapabilityID("gtm.builtInVariables.revert"),
    field: "gtmRevertBuiltInVariable",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:revert",
    arguments: [
      ArgumentDefinition(
        "path",
        .resourceName(GTMResourceNames.builtInVariable),
        .path("path"),
        required: true
      ),
      ArgumentDefinition("type", .string, .query("type"))
    ],
    result: .single(GTMWriteModels.revertedBuiltInVariable),
    scopes: .tagManagerEditContainers,
    summary: "Reverts changes to a GTM Built-In Variables in a GTM Workspace."
  )
}
