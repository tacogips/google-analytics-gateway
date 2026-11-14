import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager v2 deletes.
///
/// Tag Manager addresses every one of them as `/tagmanager/v2/{path}` and
/// answers with an empty body, so they differ only in the shape of the path and
/// in the scope Google gates them behind. The scopes are not uniform: the
/// workspace entities take the container edit scope, containers and whole
/// workspaces take the separate delete scope, container versions take the
/// container-versions scope, and a user permission takes the user management
/// scope. Each definition below names the one its discovery entry documents.
enum GTMDeleteCapabilities {
  static let all: [CapabilityDefinition] =
    workspaceEntities + containerLevel

  // MARK: - Workspace entities (tagmanager.edit.containers)

  private static let workspaceEntities: [CapabilityDefinition] = [
    delete(
      id: "gtm.builtInVariables.delete",
      field: "gtmDeleteBuiltInVariable",
      pattern: GTMResourceNames.builtInVariable,
      scopes: .tagManagerEditContainers,
      summary: "Deletes one or more GTM Built-In Variables.",
      // Google addresses the built-in variables of a workspace as one
      // collection, so the repeated `type` parameter is what selects which of
      // them the call removes. It is left as a string list rather than a
      // curated enumeration because the writer's create and revert methods take
      // the same 118-value set: a second copy of the list here could drift from
      // theirs, and the schema printer keys enumerations by name.
      extraArguments: [
        ArgumentDefinition("type", .stringList, .queryList("type"))
      ]
    ),

    delete(
      id: "gtm.clients.delete",
      field: "gtmDeleteClient",
      pattern: GTMResourceNames.client,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a GTM Client."
    ),

    delete(
      id: "gtm.folders.delete",
      field: "gtmDeleteFolder",
      pattern: GTMResourceNames.folder,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a GTM Folder."
    ),

    delete(
      id: "gtm.gtagConfig.delete",
      field: "gtmDeleteGtagConfig",
      pattern: GTMResourceNames.gtagConfig,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a Google tag config."
    ),

    delete(
      id: "gtm.tags.delete",
      field: "gtmDeleteTag",
      pattern: GTMResourceNames.tag,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a GTM Tag."
    ),

    delete(
      id: "gtm.templates.delete",
      field: "gtmDeleteTemplate",
      pattern: GTMResourceNames.template,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a GTM Template."
    ),

    delete(
      id: "gtm.transformations.delete",
      field: "gtmDeleteTransformation",
      pattern: GTMResourceNames.transformation,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a GTM Transformation."
    ),

    delete(
      id: "gtm.triggers.delete",
      field: "gtmDeleteTrigger",
      pattern: GTMResourceNames.trigger,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a GTM Trigger."
    ),

    delete(
      id: "gtm.variables.delete",
      field: "gtmDeleteVariable",
      pattern: GTMResourceNames.variable,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a GTM Variable."
    ),

    delete(
      id: "gtm.zones.delete",
      field: "gtmDeleteZone",
      pattern: GTMResourceNames.zone,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a GTM Zone."
    )
  ]

  // MARK: - Container-level resources

  private static let containerLevel: [CapabilityDefinition] = [
    // Google gates a container delete behind `tagmanager.delete.containers`
    // rather than the container edit scope.
    delete(
      id: "gtm.containers.delete",
      field: "gtmDeleteContainer",
      pattern: GTMResourceNames.container,
      scopes: .tagManagerDeleteContainers,
      summary: "Deletes a Container."
    ),

    // A workspace delete takes the same delete scope as its container, not the
    // edit scope its own entities take.
    delete(
      id: "gtm.workspaces.delete",
      field: "gtmDeleteWorkspace",
      pattern: GTMResourceNames.workspace,
      scopes: .tagManagerDeleteContainers,
      summary: "Deletes a Workspace."
    ),

    delete(
      id: "gtm.environments.delete",
      field: "gtmDeleteEnvironment",
      pattern: GTMResourceNames.environment,
      scopes: .tagManagerEditContainers,
      summary: "Deletes a GTM Environment."
    ),

    delete(
      id: "gtm.versions.delete",
      field: "gtmDeleteVersion",
      pattern: GTMResourceNames.containerVersion,
      scopes: .tagManagerEditContainerVersions,
      summary: "Deletes a Container Version."
    ),

    delete(
      id: "gtm.userPermissions.delete",
      field: "gtmDeleteUserPermission",
      pattern: GTMResourceNames.userPermission,
      scopes: .tagManagerManageUsers,
      summary: "Removes a user from the account, revoking access to it and all of its containers."
    )
  ]

  private static func delete(
    id: String,
    field: String,
    pattern: String,
    scopes: ScopeRequirement,
    summary: String,
    extraArguments: [ArgumentDefinition] = []
  ) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .delete,
      method: .delete,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{path}",
      arguments: [
        ArgumentDefinition("path", .resourceName(pattern), .path("path"), required: true),
        ArgumentDefinition("confirmPath", .resourceName(pattern), .confirm("path"), required: true)
      ] + extraArguments,
      result: .deletion,
      scopes: scopes,
      summary: summary
    )
  }
}
