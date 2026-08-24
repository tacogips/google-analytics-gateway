import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead
import GoogleAnalyticsGatewayWrite

/// Tag Manager operations that restructure a container or its published state.
///
/// Combining two containers, moving a tag id out of one, linking a destination
/// away from the container that currently owns it, undeleting a version, and
/// reissuing an environment's authorization code all change what a live site
/// serves without being deletes, which is why they are gated to the admin tier
/// alongside them.
enum GTMContainerOperationCapabilities {
  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("gtm.containers.combine"),
      field: "gtmCombineContainers",
      tier: .admin,
      operationClass: .update,
      method: .post,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{path}:combine",
      arguments: [
        ArgumentDefinition("path", .resourceName(GTMResourceNames.container), .path("path"), required: true),
        ArgumentDefinition("containerId", .string, .query("containerId")),
        ArgumentDefinition(
          "settingSource",
          .enumeration("GtmCombineSettingSource", ["settingSourceUnspecified", "current", "other"]),
          .query("settingSource")
        ),
        ArgumentDefinition(
          "allowUserPermissionFeatureUpdate",
          .boolean,
          .query("allowUserPermissionFeatureUpdate")
        )
      ],
      result: .single(GTMModels.container),
      scopes: .tagManagerEditContainers,
      summary: "Combines Containers.",
      upstreamRejectionGuidance: "Google refuses the combine when it would turn on the "
        + "user-permissions feature unless allowUserPermissionFeatureUpdate is set to true."
    ),

    CapabilityDefinition(
      id: CapabilityID("gtm.containers.moveTagId"),
      field: "gtmMoveTagId",
      tier: .admin,
      operationClass: .update,
      method: .post,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{path}:move_tag_id",
      arguments: [
        ArgumentDefinition("path", .resourceName(GTMResourceNames.container), .path("path"), required: true),
        ArgumentDefinition("tagId", .string, .query("tagId")),
        ArgumentDefinition("tagName", .string, .query("tagName")),
        ArgumentDefinition("copyUsers", .boolean, .query("copyUsers")),
        ArgumentDefinition("copySettings", .boolean, .query("copySettings")),
        ArgumentDefinition("copyTermsOfService", .boolean, .query("copyTermsOfService")),
        ArgumentDefinition(
          "allowUserPermissionFeatureUpdate",
          .boolean,
          .query("allowUserPermissionFeatureUpdate")
        )
      ],
      result: .single(GTMModels.container),
      scopes: .tagManagerEditContainers,
      summary: "Move Tag ID out of a Container.",
      upstreamRejectionGuidance: "Google refuses the move unless copyTermsOfService is set to "
        + "true to accept the terms carried over from the current tag."
    ),

    CapabilityDefinition(
      id: CapabilityID("gtm.destinations.link"),
      field: "gtmLinkDestination",
      tier: .admin,
      operationClass: .create,
      method: .post,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{parent}/destinations:link",
      arguments: [
        ArgumentDefinition("parent", .resourceName(GTMResourceNames.container), .path("parent"), required: true),
        ArgumentDefinition("destinationId", .string, .query("destinationId")),
        ArgumentDefinition(
          "allowUserPermissionFeatureUpdate",
          .boolean,
          .query("allowUserPermissionFeatureUpdate")
        )
      ],
      result: .single(GTMModels.destination),
      scopes: .tagManagerEditContainers,
      summary: "Adds a Destination to this Container and removes it from the Container to which "
        + "it is currently linked."
    ),

    CapabilityDefinition(
      id: CapabilityID("gtm.versions.undelete"),
      field: "gtmUndeleteVersion",
      tier: .admin,
      operationClass: .update,
      method: .post,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{path}:undelete",
      arguments: [
        ArgumentDefinition(
          "path",
          .resourceName(GTMResourceNames.containerVersion),
          .path("path"),
          required: true
        )
      ],
      result: .single(GTMModels.containerVersion),
      scopes: .tagManagerEditContainerVersions,
      summary: "Undeletes a Container Version."
    ),

    // Google gates the reauthorization behind `tagmanager.publish` rather than
    // the container edit scope: reissuing the code changes what an already
    // published environment will serve.
    CapabilityDefinition(
      id: CapabilityID("gtm.environments.reauthorize"),
      field: "gtmReauthorizeEnvironment",
      tier: .admin,
      operationClass: .update,
      method: .post,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{path}:reauthorize",
      arguments: [
        ArgumentDefinition(
          "path",
          .resourceName(GTMResourceNames.environment),
          .path("path"),
          required: true
        ),
        // Google documents the request body as a whole `Environment`, which is
        // the same document the writer's environment create and update send, so
        // the shape is reused rather than restated.
        ArgumentDefinition("environment", .inputObject(GTMWriteInputs.environment), .bodyRoot)
      ],
      result: .single(GTMModels.environment),
      scopes: .tagManagerPublish,
      summary: "Re-generates the authorization code for a GTM Environment."
    )
  ]
}
