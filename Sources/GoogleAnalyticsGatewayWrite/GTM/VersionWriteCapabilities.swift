import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Container version mutations.
///
/// Each method carries the scope Google documents for it rather than one scope
/// for the resource: editing a version is a container-versions edit, marking
/// one as the latest is a container edit, and publishing has its own scope.
/// Version deletion and undeletion belong to the admin tier.
enum GTMVersionWriteCapabilities {
  static let all: [CapabilityDefinition] = [update, publish, setLatest]

  static let update = CapabilityDefinition(
    id: CapabilityID("gtm.versions.update"),
    field: "gtmUpdateVersion",
    tier: .writer,
    operationClass: .update,
    method: .put,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}",
    arguments: [
      ArgumentDefinition(
        "path",
        .resourceName(GTMResourceNames.containerVersion),
        .path("path"),
        required: true
      ),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint")),
      ArgumentDefinition(
        "containerVersion",
        .inputObject(GTMWriteInputs.containerVersion),
        .bodyRoot,
        required: true
      )
    ],
    result: .payload(field: "containerVersion", GTMModels.containerVersion),
    scopes: .tagManagerEditContainerVersions,
    summary: "Updates a Container Version."
  )

  static let publish = CapabilityDefinition(
    id: CapabilityID("gtm.versions.publish"),
    field: "gtmPublishVersion",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:publish",
    arguments: [
      ArgumentDefinition(
        "path",
        .resourceName(GTMResourceNames.containerVersion),
        .path("path"),
        required: true
      ),
      ArgumentDefinition("fingerprint", .string, .query("fingerprint"))
    ],
    result: .single(GTMWriteModels.publishResult),
    scopes: .tagManagerPublish,
    summary: "Publishes a Container Version.",
    upstreamRejectionGuidance: "A version that does not compile is not published; the response "
      + "reports compilerError rather than failing the request."
  )

  static let setLatest = CapabilityDefinition(
    id: CapabilityID("gtm.versions.setLatest"),
    field: "gtmSetLatestVersion",
    tier: .writer,
    operationClass: .update,
    method: .post,
    service: .tagManagerV2,
    pathTemplate: "/tagmanager/v2/{path}:set_latest",
    arguments: [
      ArgumentDefinition(
        "path",
        .resourceName(GTMResourceNames.containerVersion),
        .path("path"),
        required: true
      )
    ],
    result: .payload(field: "containerVersion", GTMModels.containerVersion),
    scopes: .tagManagerEditContainers,
    summary: "Sets the latest version used for synchronization of workspaces when detecting "
      + "conflicts and errors."
  )
}
