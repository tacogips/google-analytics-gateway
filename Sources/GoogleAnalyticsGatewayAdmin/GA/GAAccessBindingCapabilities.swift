import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 Admin API v1alpha access bindings: who may use an account or a property,
/// and in which roles.
///
/// The whole resource sits in the admin tier, reads included. Google exposes the
/// same eight methods twice, once under `accounts` and once under `properties`,
/// with identical bodies and different parent shapes, so each method is written
/// once as a builder and applied to both parents.
///
/// The reads are HTTP GETs in the admin tier on purpose. A principal-and-roles
/// read is administrative whatever its verb — it answers who has access to the
/// property, which is not something a reader credential should be able to ask —
/// and the registry admits admin-tier reads for exactly this case; Tag Manager's
/// `user_permissions` reads are the existing precedent.
///
/// Scopes follow the discovery document: mutations take
/// `analytics.manage.users`, and the reads additionally accept the narrower
/// `analytics.manage.users.readonly`.
enum GAAccessBindingCapabilities {
  private static let account = "accounts/{account}"
  private static let property = "properties/{property}"
  private static let accountBinding = GAAlphaDeleteCapabilities.accountAccessBinding
  private static let propertyBinding = GAAlphaDeleteCapabilities.propertyAccessBinding

  static let all: [CapabilityDefinition] = [
    get(
      id: "ga.accounts.accessBindings.get",
      field: "gaAccountAccessBinding",
      binding: accountBinding
    ),
    get(
      id: "ga.properties.accessBindings.get",
      field: "gaPropertyAccessBinding",
      binding: propertyBinding
    ),

    list(
      id: "ga.accounts.accessBindings.list",
      field: "gaAccountAccessBindings",
      parent: account
    ),
    list(
      id: "ga.properties.accessBindings.list",
      field: "gaPropertyAccessBindings",
      parent: property
    ),

    batchGet(
      id: "ga.accounts.accessBindings.batchGet",
      field: "gaBatchGetAccountAccessBindings",
      parent: account,
      binding: accountBinding
    ),
    batchGet(
      id: "ga.properties.accessBindings.batchGet",
      field: "gaBatchGetPropertyAccessBindings",
      parent: property,
      binding: propertyBinding
    ),

    create(
      id: "ga.accounts.accessBindings.create",
      field: "gaCreateAccountAccessBinding",
      parent: account
    ),
    create(
      id: "ga.properties.accessBindings.create",
      field: "gaCreatePropertyAccessBinding",
      parent: property
    ),

    update(
      id: "ga.accounts.accessBindings.update",
      field: "gaUpdateAccountAccessBinding",
      binding: accountBinding
    ),
    update(
      id: "ga.properties.accessBindings.update",
      field: "gaUpdatePropertyAccessBinding",
      binding: propertyBinding
    ),

    batchCreate(
      id: "ga.accounts.accessBindings.batchCreate",
      field: "gaBatchCreateAccountAccessBindings",
      parent: account
    ),
    batchCreate(
      id: "ga.properties.accessBindings.batchCreate",
      field: "gaBatchCreatePropertyAccessBindings",
      parent: property
    ),

    batchUpdate(
      id: "ga.accounts.accessBindings.batchUpdate",
      field: "gaBatchUpdateAccountAccessBindings",
      parent: account
    ),
    batchUpdate(
      id: "ga.properties.accessBindings.batchUpdate",
      field: "gaBatchUpdatePropertyAccessBindings",
      parent: property
    ),

    batchDelete(
      id: "ga.accounts.accessBindings.batchDelete",
      field: "gaBatchDeleteAccountAccessBindings",
      parent: account
    ),
    batchDelete(
      id: "ga.properties.accessBindings.batchDelete",
      field: "gaBatchDeletePropertyAccessBindings",
      parent: property
    )
  ]

  private static func get(id: String, field: String, binding: String) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(binding), .path("name"), required: true)
      ],
      result: .single(GAAlphaModels.accessBinding),
      scopes: .analyticsManageUsersReadonly,
      summary: "Gets information about an access binding."
    )
  }

  private static func list(id: String, field: String, parent: String) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/accessBindings",
      arguments: [
        ArgumentDefinition("parent", .resourceName(parent), .path("parent"), required: true),
        ArgumentDefinition("page", .page, .page)
      ],
      result: .connection(collection: "accessBindings", GAAlphaModels.accessBinding),
      scopes: .analyticsManageUsersReadonly,
      maximumPageSize: 500,
      summary: "Lists all access bindings on an account or property."
    )
  }

  /// `batchGet` names the bindings it wants in a repeated `names` query
  /// parameter rather than a body, because Google models it as a GET.
  private static func batchGet(
    id: String,
    field: String,
    parent: String,
    binding: String
  ) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .read,
      method: .get,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/accessBindings:batchGet",
      arguments: [
        ArgumentDefinition("parent", .resourceName(parent), .path("parent"), required: true),
        ArgumentDefinition(
          "names",
          .stringList,
          .queryList("names"),
          required: true,
          maximumCount: GAAlphaAdminInputs.maximumBatchSize
        )
      ],
      result: .list(collection: "accessBindings", GAAlphaModels.accessBinding),
      scopes: .analyticsManageUsersReadonly,
      summary: "Gets information about multiple access bindings to an account or property.",
      upstreamRejectionGuidance: "Every requested name must be a binding on the parent the "
        + "request is addressed to; Google refuses the batch if any name belongs elsewhere."
    )
  }

  private static func create(id: String, field: String, parent: String) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/accessBindings",
      arguments: [
        ArgumentDefinition("parent", .resourceName(parent), .path("parent"), required: true),
        ArgumentDefinition(
          "accessBinding",
          .inputObject(GAAlphaAdminInputs.accessBinding),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "accessBinding", GAAlphaModels.accessBinding),
      scopes: .analyticsManageUsers,
      summary: "Creates an access binding on an account or property."
    )
  }

  /// The patch takes no `updateMask`: Google documents none for this method, and
  /// the binding it sends replaces the roles the person currently holds.
  private static func update(id: String, field: String, binding: String) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .update,
      method: .patch,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{name}",
      arguments: [
        ArgumentDefinition("name", .resourceName(binding), .path("name"), required: true),
        ArgumentDefinition(
          "accessBinding",
          .inputObject(GAAlphaAdminInputs.accessBinding),
          .bodyRoot,
          required: true
        )
      ],
      result: .payload(field: "accessBinding", GAAlphaModels.accessBinding),
      scopes: .analyticsManageUsers,
      summary: "Updates an access binding on an account or property."
    )
  }

  private static func batchCreate(id: String, field: String, parent: String) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/accessBindings:batchCreate",
      arguments: [
        ArgumentDefinition("parent", .resourceName(parent), .path("parent"), required: true),
        ArgumentDefinition(
          "requests",
          .inputObjectList(GAAlphaAdminInputs.accessBindingCreateRequest),
          .bodyJSON("requests"),
          required: true,
          maximumCount: GAAlphaAdminInputs.maximumBatchSize
        )
      ],
      result: .list(collection: "accessBindings", GAAlphaModels.accessBinding),
      scopes: .analyticsManageUsers,
      summary: "Creates information about multiple access bindings to an account or property. "
        + "This method is transactional. If any AccessBinding cannot be created, none of the "
        + "AccessBindings will be created."
    )
  }

  private static func batchUpdate(id: String, field: String, parent: String) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/accessBindings:batchUpdate",
      arguments: [
        ArgumentDefinition("parent", .resourceName(parent), .path("parent"), required: true),
        ArgumentDefinition(
          "requests",
          .inputObjectList(GAAlphaAdminInputs.accessBindingUpdateRequest),
          .bodyJSON("requests"),
          required: true,
          maximumCount: GAAlphaAdminInputs.maximumBatchSize
        )
      ],
      result: .list(collection: "accessBindings", GAAlphaModels.accessBinding),
      scopes: .analyticsManageUsers,
      summary: "Updates information about multiple access bindings to an account or property."
    )
  }

  /// `batchDelete` is the one destructive method here that is not a `.delete`.
  ///
  /// It removes a set of bindings named in the body and answers with an empty
  /// object, so it has neither of the two things the delete contract is built
  /// from: a single resource name in the path, and a removed name to confirm
  /// back. Registering it as a delete would mean confirming against the parent —
  /// claiming the account or property itself was removed — which is worse than
  /// not using the contract at all.
  ///
  /// It is therefore an update that carries a required `confirmParent` echo of
  /// the parent it is addressed to. The echo does not name the bindings being
  /// removed, but it does mean a batch delete cannot be issued against a parent
  /// the caller did not deliberately name twice.
  private static func batchDelete(id: String, field: String, parent: String) -> CapabilityDefinition {
    CapabilityDefinition(
      id: CapabilityID(id),
      field: field,
      tier: .admin,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Alpha,
      pathTemplate: "/v1alpha/{parent}/accessBindings:batchDelete",
      arguments: [
        ArgumentDefinition("parent", .resourceName(parent), .path("parent"), required: true),
        ArgumentDefinition(
          "confirmParent",
          .resourceName(parent),
          .confirm("parent"),
          required: true
        ),
        ArgumentDefinition(
          "requests",
          .inputObjectList(GAAlphaAdminInputs.accessBindingDeleteRequest),
          .bodyJSON("requests"),
          required: true,
          maximumCount: GAAlphaAdminInputs.maximumBatchSize
        )
      ],
      result: .single(GAAlphaAdminInputs.accessBindingBatchDeletion),
      scopes: .analyticsManageUsers,
      summary: "Deletes information about multiple users' links to an account or property.",
      upstreamRejectionGuidance: "Every named binding must belong to the parent the request is "
        + "addressed to; Google refuses the batch if any name belongs elsewhere."
    )
  }
}
