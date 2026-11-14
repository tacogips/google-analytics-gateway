import GoogleAnalyticsGatewayCore
import GoogleAnalyticsGatewayRead

/// GA4 account provisioning and the property-level user-data-collection
/// acknowledgement.
///
/// Both are account-level acts rather than resource edits — one starts the
/// Terms of Service flow that creates an account, the other records a legal
/// acknowledgement on a property — which is why they sit in the admin tier
/// alongside the deletes rather than with the writer's create methods.
enum GAProvisioningCapabilities {
  private static let property = "properties/{property}"

  /// The `account` half of `ProvisionAccountTicketRequest`. Only the two fields
  /// Google accepts on creation are exposed; everything else on an Account is
  /// output-only, so offering it would invite a request the API discards.
  static let accountInput = InputObjectShape(
    typeName: "GAProvisionAccountInput",
    fields: [
      ArgumentDefinition("displayName", .string, .bodyJSON("displayName"), required: true),
      ArgumentDefinition("regionCode", .string, .bodyJSON("regionCode"))
    ]
  )

  /// `ProvisionAccountTicketResponse`, which carries only the ticket id to pass
  /// into the Terms of Service link.
  static let accountTicket = ModelShape(
    typeName: "GAAccountTicket",
    fields: [
      ModelField("accountTicketId", .string)
    ]
  )

  /// `AcknowledgeUserDataCollectionResponse` is documented with no properties at
  /// all: a `200` with `{}` is the whole answer. A GraphQL type still needs a
  /// field, so the acknowledgement text the caller sent is echoed back as the
  /// shape's single field. Google does not return it, so it projects as null and
  /// the successful response itself is the confirmation.
  static let userDataCollectionAcknowledgement = ModelShape(
    typeName: "GAUserDataCollectionAcknowledgement",
    fields: [
      ModelField("acknowledgement", .string)
    ]
  )

  static let all: [CapabilityDefinition] = [
    CapabilityDefinition(
      id: CapabilityID("ga.accounts.provisionAccountTicket"),
      field: "gaProvisionAccountTicket",
      tier: .admin,
      operationClass: .create,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/accounts:provisionAccountTicket",
      arguments: [
        ArgumentDefinition("account", .inputObject(accountInput), .bodyJSON("account"), required: true),
        ArgumentDefinition("redirectUri", .string, .bodyJSON("redirectUri"))
      ],
      result: .single(accountTicket),
      scopes: .analyticsEdit,
      summary: "Requests a ticket for creating an account.",
      upstreamRejectionGuidance: "Google refuses a redirect URI that is not registered as an "
        + "authorized redirect URI for this OAuth client in the Cloud console."
    ),

    CapabilityDefinition(
      id: CapabilityID("ga.properties.acknowledgeUserDataCollection"),
      field: "gaAcknowledgeUserDataCollection",
      tier: .admin,
      operationClass: .update,
      method: .post,
      service: .analyticsAdminV1Beta,
      pathTemplate: "/v1beta/{property}:acknowledgeUserDataCollection",
      arguments: [
        ArgumentDefinition("property", .resourceName(property), .path("property"), required: true),
        ArgumentDefinition(
          "acknowledgement",
          .string,
          .bodyJSON("acknowledgement"),
          required: true
        )
      ],
      result: .single(userDataCollectionAcknowledgement),
      scopes: .analyticsEdit,
      summary: "Acknowledges the terms of user data collection for the specified property.",
      upstreamRejectionGuidance: "Google accepts only the exact acknowledgement sentence its "
        + "reference documents for this method; any other wording is refused as invalid."
    )
  ]
}
