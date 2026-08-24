import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// Tag Manager account user permissions.
///
/// The whole resource sits in the admin tier — reads included — because a user
/// permission is the account's access-control list rather than tag content, and
/// Google gates every one of its methods behind the single
/// `tagmanager.manage.users` scope. Only the admin binary links this file, so
/// the reader and writer executables cannot reach these fields at all.
enum GTMUserPermissionCapabilities {
  /// Tag Manager documents `pageToken` on the user-permission list but neither
  /// a `pageSize` nor a published cap, so the registry bounds what it will
  /// assemble locally, matching the reader's Tag Manager list bound.
  private static let maximumPageSize = 300

  /// The settable half of a `UserPermission`. `path`, `accountId`, and the
  /// fingerprint are assigned by Google, so only the address of the user and
  /// the access they are granted are accepted here.
  static let input = InputObjectShape(
    typeName: "GtmUserPermissionInput",
    fields: [
      ArgumentDefinition("emailAddress", .string, .bodyJSON("emailAddress")),
      ArgumentDefinition("accountAccess", .inputObject(accountAccessInput), .bodyJSON("accountAccess")),
      ArgumentDefinition(
        "containerAccess",
        .inputObjectList(containerAccessInput),
        .bodyJSON("containerAccess")
      )
    ]
  )

  static let accountAccessInput = InputObjectShape(
    typeName: "GtmAccountAccessInput",
    fields: [
      ArgumentDefinition("permission", .string, .bodyJSON("permission"))
    ]
  )

  static let containerAccessInput = InputObjectShape(
    typeName: "GtmContainerAccessInput",
    fields: [
      ArgumentDefinition("containerId", .string, .bodyJSON("containerId")),
      ArgumentDefinition("permission", .string, .bodyJSON("permission"))
    ]
  )

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("gtm.userPermissions.create"),
      field: "gtmCreateUserPermission",
      tier: .admin,
      operationClass: .create,
      method: .post,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{parent}/user_permissions",
      arguments: [
        ArgumentDefinition("parent", .resourceName(GTMResourceNames.account), .path("parent"), required: true),
        ArgumentDefinition("userPermission", .inputObject(input), .bodyRoot, required: true)
      ],
      result: .single(GTMModels.userPermission),
      scopes: .tagManagerManageUsers,
      summary: "Creates a user's Account & Container access."
    ),

    CapabilityDefinition(
      id: CapabilityID("gtm.userPermissions.update"),
      field: "gtmUpdateUserPermission",
      tier: .admin,
      operationClass: .update,
      method: .put,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{path}",
      arguments: [
        ArgumentDefinition(
          "path",
          .resourceName(GTMResourceNames.userPermission),
          .path("path"),
          required: true
        ),
        ArgumentDefinition("userPermission", .inputObject(input), .bodyRoot, required: true)
      ],
      result: .single(GTMModels.userPermission),
      scopes: .tagManagerManageUsers,
      summary: "Updates a user's Account & Container access."
    ),

    // The two reads are admin-tier queries rather than mutations: Google serves
    // them over GET, and `CapabilityCatalog.adminQueryFields` is what lets a
    // reader binary answer `CAPABILITY_DENIED` for them instead of reporting an
    // unknown field.
    CapabilityDefinition(
      id: CapabilityID("gtm.userPermissions.get"),
      field: "gtmUserPermission",
      tier: .admin,
      operationClass: .read,
      method: .get,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{path}",
      arguments: [
        ArgumentDefinition(
          "path",
          .resourceName(GTMResourceNames.userPermission),
          .path("path"),
          required: true
        )
      ],
      result: .single(GTMModels.userPermission),
      scopes: .tagManagerManageUsers,
      summary: "Gets a user's Account & Container access."
    ),

    CapabilityDefinition(
      id: CapabilityID("gtm.userPermissions.list"),
      field: "gtmUserPermissions",
      tier: .admin,
      operationClass: .read,
      method: .get,
      service: .tagManagerV2,
      pathTemplate: "/tagmanager/v2/{parent}/user_permissions",
      arguments: [
        ArgumentDefinition("parent", .resourceName(GTMResourceNames.account), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "userPermission", GTMModels.userPermission),
      scopes: .tagManagerManageUsers,
      maximumPageSize: maximumPageSize,
      summary: "List all users that have access to the account along with Account and Container "
        + "user access granted to each of them."
    )
  ]
}
